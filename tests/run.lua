package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local failures = 0
local tests = 0

local function equal(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. (": expected %s, got %s"):format(vim.inspect(expected), vim.inspect(actual)))
  end
end

local function truthy(value, message)
  if not value then
    error(message or "expected a truthy value")
  end
end

local function test(name, callback)
  tests = tests + 1
  local ok, err = xpcall(callback, debug.traceback)
  if ok then
    print("ok - " .. name)
  else
    failures = failures + 1
    print("not ok - " .. name)
    print(err)
  end
end

local function unload(prefix)
  for name in pairs(package.loaded) do
    if name:find(prefix, 1, true) == 1 then
      package.loaded[name] = nil
    end
  end
end

test("appearance maps defaults output to dark and failures to light", function()
  unload "macos-appearance.appearance"
  local original_system = vim.system
  local result = { code = 0, stdout = "Dark\n" }
  vim.system = function()
    return {
      wait = function()
        return result
      end,
    }
  end

  local appearance = require "macos-appearance.appearance"
  equal(appearance.get(), "dark")

  result = { code = 1, stdout = "" }
  equal(appearance.get(), "light")
  vim.system = original_system
end)

test("NvChad adapter maps theme_toggle and avoids redundant reloads", function()
  unload "macos-appearance.adapters.nvchad"
  local loads = 0
  local base46_config = {
    theme = "light-theme",
    theme_toggle = { "light-theme", "dark-theme" },
  }
  package.loaded.nvconfig = { base46 = base46_config }
  package.loaded.base46 = {
    load_all_highlights = function()
      loads = loads + 1
    end,
  }

  local adapter = require "macos-appearance.adapters.nvchad"

  -- Startup: theme already matches → fast path, no reload.
  local changed, err = adapter.apply "light"
  equal(changed, false)
  equal(err, nil)
  equal(loads, 0)
  equal(vim.g.icon_toggled, false)

  -- Different appearance triggers a real apply.
  changed, err = adapter.apply "dark"
  equal(changed, true)
  equal(err, nil)
  equal(base46_config.theme, "light-theme")
  equal(loads, 1)
  equal(vim.g.icon_toggled, true)

  -- Same appearance again is a no-op (tracked by last_appearance).
  changed, err = adapter.apply "dark"
  equal(changed, false)
  equal(loads, 1)

  -- Different appearance triggers a real apply.
  changed, err = adapter.apply "light"
  equal(changed, true)
  equal(err, nil)
  equal(base46_config.theme, "light-theme")
  equal(loads, 2)
  equal(vim.g.icon_toggled, false)

  -- Back to dark — still works after a different appearance.
  changed, err = adapter.apply "dark"
  equal(changed, true)
  equal(loads, 3)
end)

test("NvChad adapter reports an invalid theme_toggle", function()
  unload "macos-appearance.adapters.nvchad"
  package.loaded.nvconfig = { base46 = { theme = "anything", theme_toggle = { "only-one" } } }
  package.loaded.base46 = { load_all_highlights = function() end }

  local adapter = require "macos-appearance.adapters.nvchad"
  local changed, err = adapter.apply "dark"
  equal(changed, false)
  truthy(err:find("theme_toggle", 1, true))
end)

test("watcher debounces events, synchronizes, and attaches a fresh handle", function()
  unload "macos-appearance.watcher"
  local original_new_fs_event = vim.uv.new_fs_event
  local original_new_timer = vim.uv.new_timer
  local original_schedule = vim.schedule

  local handles = {}
  local timer_callback
  local syncs = 0

  vim.schedule = function(callback)
    callback()
  end
  vim.uv.new_fs_event = function()
    local handle = { closing = false, stopped = false }
    function handle:start(path, _, callback)
      self.path = path
      self.callback = callback
      return true
    end
    function handle:stop()
      self.stopped = true
    end
    function handle:close()
      self.closing = true
    end
    function handle:is_closing()
      return self.closing
    end
    handles[#handles + 1] = handle
    return handle
  end
  vim.uv.new_timer = function()
    local timer = { closing = false }
    function timer.start(_, _, _, callback)
      timer_callback = callback
      return true
    end
    function timer.stop(_) end
    function timer:close()
      self.closing = true
    end
    function timer.is_closing(_)
      return timer.closing
    end
    return timer
  end

  local watcher = require("macos-appearance.watcher").new {
    path = "/tmp/preferences.plist",
    debounce_ms = 100,
    retry_ms = 250,
    on_change = function()
      syncs = syncs + 1
    end,
  }

  truthy(watcher:start())
  equal(handles[1].path, "/tmp/preferences.plist")
  handles[1].callback()
  truthy(handles[1].closing)
  equal(syncs, 0)

  timer_callback()
  equal(syncs, 1)
  equal(#handles, 2)
  equal(handles[2].path, "/tmp/preferences.plist")

  watcher:stop()
  truthy(handles[2].closing)

  vim.uv.new_fs_event = original_new_fs_event
  vim.uv.new_timer = original_new_timer
  vim.schedule = original_schedule
end)

test("setup synchronizes before starting and repeated setup stops the old watcher", function()
  unload "macos-appearance"
  local order = {}
  local stop_count = 0

  package.loaded["macos-appearance.appearance"] = {
    get = function()
      order[#order + 1] = "detect"
      return "dark"
    end,
  }
  package.loaded["macos-appearance.adapters.nvchad"] = {
    apply = function(value)
      order[#order + 1] = "apply-" .. value
      return true
    end,
  }
  package.loaded["macos-appearance.watcher"] = {
    new = function()
      return {
        start = function()
          order[#order + 1] = "start"
          return true
        end,
        stop = function()
          stop_count = stop_count + 1
        end,
      }
    end,
  }

  local plugin = require "macos-appearance"
  plugin.setup { notify = false }
  equal(table.concat(order, ","), "detect,apply-dark,start")

  order = {}
  plugin.setup { notify = false }
  equal(stop_count, 1)
  equal(table.concat(order, ","), "detect,apply-dark,start")
  plugin.stop()
end)

print(("%d tests, %d failures"):format(tests, failures))
if failures > 0 then
  vim.cmd "cquit 1"
else
  vim.cmd "quit"
end
