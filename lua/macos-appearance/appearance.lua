local M = {}

---Return the current macOS appearance.
---@return "dark"|"light"|nil appearance
---@return string? error
function M.get()
  if vim.fn.has "mac" ~= 1 then
    return nil, "macos-appearance.nvim only supports macOS"
  end

  local result = vim.system({ "defaults", "read", "-g", "AppleInterfaceStyle" }, { text = true }):wait()
  if result.code == 0 and vim.trim(result.stdout or "") == "Dark" then
    return "dark"
  end

  return "light"
end

return M
