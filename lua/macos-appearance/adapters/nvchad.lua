local M = {}

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

---Apply the NvChad theme associated with an appearance.
---@param appearance "dark"|"light"
---@return boolean changed
---@return string? error
function M.apply(appearance)
  if appearance ~= "dark" and appearance ~= "light" then
    return false, "appearance must be 'dark' or 'light'"
  end

  local base46, err = config()
  if not base46 then
    return false, err
  end

  local theme = appearance == "dark" and base46.theme_toggle[2] or base46.theme_toggle[1]
  update_icon(base46, theme)

  if base46.theme == theme then
    return false
  end

  local previous = base46.theme
  base46.theme = theme

  local ok, base46_module = pcall(require, "base46")
  if not ok or type(base46_module.load_all_highlights) ~= "function" then
    base46.theme = previous
    return false, "NvChad base46 module is unavailable"
  end

  local loaded, load_err = pcall(base46_module.load_all_highlights)
  if not loaded then
    base46.theme = previous
    return false, tostring(load_err)
  end

  return true
end

---Toggle between the two configured themes without modifying chadrc.lua.
---@return boolean changed
---@return string? error
function M.toggle()
  local base46, err = config()
  if not base46 then
    return false, err
  end

  if base46.theme ~= base46.theme_toggle[1] and base46.theme ~= base46.theme_toggle[2] then
    return false, "current theme must be one of nvconfig.base46.theme_toggle"
  end

  return M.apply(base46.theme == base46.theme_toggle[1] and "dark" or "light")
end

---Keep NvChad's theme toggle button process-local.
---@return boolean installed
---@return string? error
function M.install_toggle()
  local ok, base46_module = pcall(require, "base46")
  if not ok then
    return false, "NvChad base46 module is unavailable"
  end

  base46_module.toggle_theme = function()
    local _, err = M.toggle()
    if err then
      vim.notify(err, vim.log.levels.WARN, { title = "macos-appearance.nvim" })
    end
  end

  return true
end

return M
