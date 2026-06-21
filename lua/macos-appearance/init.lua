local appearance = require "macos-appearance.appearance"
local nvchad = require "macos-appearance.adapters.nvchad"
local watcher = require "macos-appearance.watcher"

local M = {}

local defaults = {
  debounce_ms = 100,
  retry_ms = 250,
  path = vim.fn.expand "~/Library/Preferences/.GlobalPreferences.plist",
  adapter = nvchad,
  notify = true,
}

local state = {
  options = vim.deepcopy(defaults),
  appearance = nil,
  watcher = nil,
}

local function notify(message, level)
  if state.options.notify then
    vim.notify(message, level or vim.log.levels.WARN, { title = "macos-appearance.nvim" })
  end
end

---Return the current macOS appearance.
---@return "dark"|"light"|nil appearance
---@return string? error
function M.get()
  return appearance.get()
end

---Detect and apply the current macOS appearance.
---@return boolean changed
---@return string? error
function M.sync()
  local current, err = appearance.get()
  if not current then
    notify(err)
    return false, err
  end

  if state.appearance == current then
    return false
  end

  local changed, apply_err = state.options.adapter.apply(current)
  if apply_err then
    notify(apply_err)
    return false, apply_err
  end

  state.appearance = current
  return changed
end

---Start watching the macOS global preferences file.
---@return boolean started
---@return string? error
function M.start()
  if state.watcher then
    return true
  end

  state.watcher = watcher.new {
    path = state.options.path,
    debounce_ms = state.options.debounce_ms,
    retry_ms = state.options.retry_ms,
    on_change = M.sync,
    on_error = function(message)
      notify(message, vim.log.levels.DEBUG)
    end,
  }

  return state.watcher:start()
end

---Stop watching and release libuv resources.
function M.stop()
  if state.watcher then
    state.watcher:stop()
    state.watcher = nil
  end
end

---@class MacosAppearanceOptions
---@field debounce_ms? integer
---@field retry_ms? integer
---@field path? string
---@field adapter? table
---@field notify? boolean

---Synchronize once, then start listening for changes.
---@param opts? MacosAppearanceOptions
---@return boolean started
---@return string? error
function M.setup(opts)
  M.stop()
  state.options = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  state.appearance = nil

  if type(state.options.adapter.install_toggle) == "function" then
    local _, err = state.options.adapter.install_toggle()
    if err then
      notify(err)
    end
  end

  local _, sync_err = M.sync()
  if sync_err then
    return false, sync_err
  end

  local group = vim.api.nvim_create_augroup("MacosAppearance", { clear = true })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = M.stop,
  })

  return M.start()
end

return M
