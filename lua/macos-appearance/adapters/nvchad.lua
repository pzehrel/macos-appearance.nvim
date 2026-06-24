local M = {}

-- Track which appearance was last applied by the plugin so that
-- redundant apply() calls (same appearance twice in a row) can be
-- short-circuited without relying on base46.theme (which the plugin
-- restores after each apply to keep nvconfig in sync with chadrc.lua).
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

---Apply the NvChad theme for a given macOS appearance.
---
---Same approach as NvChad's built-in reload_theme: temporarily sets
---base46.theme, calls load_all_highlights, then restores the original
---value.  chadrc.lua is never modified.
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

  -- Startup fast-path: already matching, no reload needed.
  if last_appearance == nil and base46.theme == theme then
    last_appearance = appearance
    return false
  end

  local previous = base46.theme
  base46.theme = theme

  local ok, base46_module = pcall(require, "base46")
  if not ok or type(base46_module.load_all_highlights) ~= "function" then
    base46.theme = previous
    return false, "NvChad base46 module is unavailable"
  end

  -- Same approach as NvChad's built-in reload_theme: set nvconfig theme
  -- and call load_all_highlights.  Restore afterwards so nvconfig stays
  -- in sync with chadrc.lua.
  local loaded, load_err = pcall(base46_module.load_all_highlights)
  if not loaded then
    base46.theme = previous
    return false, tostring(load_err)
  end

  base46.theme = previous
  last_appearance = appearance

  return true
end

---Register this adapter to listen for MacosAppearanceChanged events.
function M.listen()
  local group = vim.api.nvim_create_augroup("MacosAppearanceNvChad", { clear = true })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "MacosAppearanceChanged",
    callback = function(ev)
      M.apply(ev.data.appearance)
    end,
  })
end

return M
