local Watcher = {}
Watcher.__index = Watcher

local M = {}

local function close(handle)
  if not handle then
    return
  end

  if not handle:is_closing() then
    handle:stop()
    handle:close()
  end
end

---@class MacosAppearanceWatcherOptions
---@field path string
---@field debounce_ms integer
---@field retry_ms integer
---@field on_change fun()
---@field on_error? fun(message: string)

---@param opts MacosAppearanceWatcherOptions
function M.new(opts)
  return setmetatable({
    opts = opts,
    fs_event = nil,
    timer = nil,
    running = false,
  }, Watcher)
end

function Watcher:_report(message)
  if self.opts.on_error then
    self.opts.on_error(message)
  end
end

function Watcher:_close_fs_event()
  close(self.fs_event)
  self.fs_event = nil
end

function Watcher:_ensure_timer()
  if not self.timer or self.timer:is_closing() then
    self.timer = vim.uv.new_timer()
  end
  return self.timer
end

function Watcher:_schedule(delay, synchronize)
  local timer = self:_ensure_timer()
  timer:stop()
  timer:start(delay, 0, function()
    vim.schedule(function()
      if not self.running then
        return
      end

      if synchronize then
        self.opts.on_change()
      end

      local ok, err = self:_arm()
      if not ok then
        self:_report(err)
        self:_schedule(self.opts.retry_ms, false)
      end
    end)
  end)
end

function Watcher:_on_event(err)
  if not self.running then
    return
  end

  if err then
    self:_report("file watcher error: " .. tostring(err))
  end

  -- macOS commonly replaces the plist atomically, so the old handle must be
  -- discarded and attached to the new file after the debounce window.
  self:_close_fs_event()
  self:_schedule(self.opts.debounce_ms, true)
end

function Watcher:_arm()
  if not self.running then
    return false, "watcher is stopped"
  end

  self:_close_fs_event()
  local fs_event = vim.uv.new_fs_event()
  if not fs_event then
    return false, "failed to create a file system watcher"
  end

  self.fs_event = fs_event
  local ok, err = fs_event:start(self.opts.path, {}, function(event_err)
    vim.schedule(function()
      self:_on_event(event_err)
    end)
  end)

  if not ok then
    self:_close_fs_event()
    return false, "failed to watch " .. self.opts.path .. ": " .. tostring(err)
  end

  return true
end

---@return boolean started
---@return string? error
function Watcher:start()
  if self.running then
    return true
  end

  self.running = true
  local ok, err = self:_arm()
  if not ok then
    self:_report(err)
    self:_schedule(self.opts.retry_ms, false)
  end
  return ok, err
end

function Watcher:stop()
  self.running = false
  self:_close_fs_event()
  close(self.timer)
  self.timer = nil
end

return M
