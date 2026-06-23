local M = {}

-- Track which appearance was last applied by the plugin so that
-- base46.theme can be restored after load_all_highlights without
-- breaking the "did the system appearance actually change?" check.
local last_appearance = nil

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

  if last_appearance == appearance then
    return false
  end

  local base46, err = config()
  if not base46 then
    return false, err
  end

  local theme = appearance == "dark" and base46.theme_toggle[2] or base46.theme_toggle[1]
  update_icon(base46, theme)

  -- Guard replace_word so that NO code path can write to chadrc.lua
  -- while we temporarily modify base46.theme for highlight compilation.
  -- load_all_highlights internally reloads the base46 module, which may
  -- trigger downstream callbacks that call toggle_theme → replace_word.
  -- Use a 500ms grace period after restoration to catch async callbacks.
  local ok_utils, nvchad_utils = pcall(require, "nvchad.utils")
  local saved_replace_word
  if ok_utils and type(nvchad_utils.replace_word) == "function" then
    saved_replace_word = nvchad_utils.replace_word
    nvchad_utils.replace_word = function(_old, _new, _filepath)
      -- DEBUG: trace who is trying to write to chadrc.lua
      local trace = debug.traceback("replace_word blocked by macos-appearance", 2)
      vim.notify(trace, vim.log.levels.WARN, { title = "macos-appearance: replace_word BLOCKED" })
    end
  end

  local previous = base46.theme
  base46.theme = theme

  local ok, base46_module = pcall(require, "base46")
  if not ok or type(base46_module.load_all_highlights) ~= "function" then
    base46.theme = previous
    if saved_replace_word then
      nvchad_utils.replace_word = saved_replace_word
    end
    return false, "NvChad base46 module is unavailable"
  end

  local loaded, load_err = pcall(base46_module.load_all_highlights)
  if not loaded then
    base46.theme = previous
    if saved_replace_word then
      nvchad_utils.replace_word = saved_replace_word
    end
    return false, tostring(load_err)
  end

  -- Highlights applied; restore original theme and replace_word
  -- after a grace period to catch any async callbacks.
  base46.theme = previous
  last_appearance = appearance

  if saved_replace_word then
    vim.defer_fn(function()
      nvchad_utils.replace_word = saved_replace_word
    end, 500)
  end

  return true
end

return M
