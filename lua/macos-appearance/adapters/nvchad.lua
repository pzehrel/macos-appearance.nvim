local M = {}

-- Module-level state ---------------------------------------------------
-- last_appearance tracks the most recently applied macOS appearance so
-- that redundant apply() calls (same appearance twice in a row) can be
-- short-circuited without relying on base46.theme (which the plugin
-- restores after each apply to keep nvconfig in sync with chadrc.lua).
local last_appearance = nil

-- Saved once on first use; never recaptured, so concurrent / overlapping
-- apply() calls cannot accidentally save the no-op guard as "original".
local saved_replace_word = nil

-- Replace-word guard ----------------------------------------------------

local function install_replace_word_guard()
  if saved_replace_word == nil then
    local ok, utils = pcall(require, "nvchad.utils")
    if ok and type(utils.replace_word) == "function" then
      saved_replace_word = utils.replace_word
    end
  end

  local ok, utils = pcall(require, "nvchad.utils")
  if ok then
    -- DIAGNOSTIC: permanently block replace_word to determine whether
    -- chadrc.lua writes go through this function or bypass it.
    utils.replace_word = function(...)
      local args = { ... }
      local msg = string.format(
        "BLOCKED at %.3fs | old=%s new=%s file=%s",
        vim.uv.hrtime() / 1e9,
        tostring(args[1] or "nil"):sub(1, 80),
        tostring(args[2] or "nil"):sub(1, 80),
        tostring(args[3] or "nil"):sub(1, 80)
      )
      vim.notify(msg, vim.log.levels.WARN, { title = "macos-appearance: replace_word BLOCKED" })
    end
  end
end

-- Configuration ---------------------------------------------------------

local function config()
  local ok, nvconfig = pcall(require, "nvconfig")
  if not ok or type(nvconfig.base46) ~= "table" then
    return nil, "NvChad base46 configuration is unavailable"
  end

  local themes = nvconfig.base46.theme_toggle
  if
    type(themes) ~= "table"
    or type(themes[1]) ~= "string"
    or themes[1] == ""
    or type(themes[2]) ~= "string"
    or themes[2] == ""
  then
    return nil, "nvconfig.base46.theme_toggle must contain { light_theme, dark_theme }"
  end

  return nvconfig.base46
end

local function update_icon(base46, theme)
  local dark = theme == base46.theme_toggle[2]
  vim.g.icon_toggled = dark
  vim.g.toggle_theme_icon = dark and "   " or "   "
end

-- Public API ------------------------------------------------------------

---Apply the NvChad theme associated with a macOS appearance.
---
---Temporarily sets base46.theme to the system-matching theme while
---highlights are compiled and applied, then restores the original
---value so that nvconfig.base46 always reflects chadrc.lua.
---During the operation replace_word is guarded to prevent any code
---path (toggle_theme, autocmd cascade, etc.) from writing to chadrc.lua.
---Manual theme toggles are left to NvChad's native toggle_theme.
---
---@param appearance "dark"|"light"
---@return boolean changed
---@return string? error
function M.apply(appearance)
  if appearance ~= "dark" and appearance ~= "light" then
    return false, "appearance must be 'dark' or 'light'"
  end

  -- System appearance unchanged since last plugin-triggered apply.
  if last_appearance == appearance then
    return false
  end

  local base46, err = config()
  if not base46 then
    return false, err
  end

  local theme = appearance == "dark" and base46.theme_toggle[2] or base46.theme_toggle[1]
  update_icon(base46, theme)

  -- Startup fast-path: the user's configured theme already matches the
  -- system appearance — no need to recompile highlights.
  if last_appearance == nil and base46.theme == theme then
    last_appearance = appearance
    return false
  end

  -- Block any file writes to chadrc.lua while we temporarily modify
  -- base46.theme for highlight compilation.  load_all_highlights
  -- internally reloads the base46 module, triggering downstream
  -- callbacks that may reach toggle_theme → replace_word.
  -- DIAGNOSTIC: guard is NOT restored — stays permanent.
  install_replace_word_guard()

  -- DIAGNOSTIC: also wrap io.open to catch writes that bypass replace_word
  local chadrc_path = vim.fn.stdpath("config") .. "/lua/chadrc.lua"
  local original_open = io.open
  io.open = function(path, mode)
    if path == chadrc_path and mode == "w" then
      local trace = debug.traceback("chadrc.lua WRITE via io.open", 2)
      vim.notify(trace, vim.log.levels.ERROR, { title = "macos-appearance: io.open WRITE" })
    end
    return original_open(path, mode)
  end

  local previous = base46.theme
  base46.theme = theme

  local ok, base46_module = pcall(require, "base46")
  if not ok or type(base46_module.load_all_highlights) ~= "function" then
    base46.theme = previous
    io.open = original_open
    return false, "NvChad base46 module is unavailable"
  end

  local loaded, load_err = pcall(base46_module.load_all_highlights)
  if not loaded then
    base46.theme = previous
    io.open = original_open
    return false, tostring(load_err)
  end

  -- Highlights are applied via compiled cache files.  Restore the
  -- original theme so that nvconfig stays in sync with chadrc.lua.
  base46.theme = previous
  last_appearance = appearance

  io.open = original_open

  -- DIAGNOSTIC: replace_word guard is NOT restored — it stays permanent.
  -- If chadrc.lua is still modified after this, the write bypasses
  -- replace_word entirely (io.open, shell command, etc.).
  vim.notify(
    "applied " .. appearance .. " | replace_word PERMANENTLY blocked",
    vim.log.levels.INFO,
    { title = "macos-appearance" }
  )

  return true
end

---Reset the internal appearance tracker so that the next apply() call
---performs a full sync regardless of the last applied appearance.
---
---Call this when the adapter state may be stale (e.g. after a plugin
---re-setup or chadrc.lua was edited externally).
function M.reset()
  last_appearance = nil
end

return M
