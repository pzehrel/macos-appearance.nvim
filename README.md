# macos-appearance.nvim

[English](README.md) | [简体中文](README.zh-CN.md)

Automatically synchronize Neovim with the current macOS light or dark appearance.

The plugin listens to `~/Library/Preferences/.GlobalPreferences.plist` with `vim.uv.new_fs_event()`.
It performs one synchronization during setup, then reacts to file events without periodic polling.

A built-in adapter for NvChad Base46 is included. Users of other theme frameworks provide their own
callback or listen to the `User MacosAppearanceChanged` event.

## Requirements

- macOS
- Neovim 0.10 or newer

## NvChad configuration

The first theme is treated as light and the second as dark:

```lua
-- chadrc.lua
M.base46 = {
  theme = "tokyodark",
  theme_toggle = {
    "flexoki-light",
    "tokyodark",
  },
}
```

## Installation

### NvChad (built-in adapter)

```lua
{
  "pzehrel/macos-appearance.nvim",
  event = "UIEnter",
  config = function()
    require("macos-appearance").setup {
      callback = require("macos-appearance.adapters.nvchad"),
    }
  end,
}
```

### Custom theme framework

```lua
{
  "pzehrel/macos-appearance.nvim",
  event = "UIEnter",
  config = function()
    require("macos-appearance").setup {
      callback = function(appearance)
        vim.cmd.colorscheme(appearance == "dark" and "tokyonight" or "github_light")
      end,
    }
  end,
}
```

### Event-based

```lua
{
  "pzehrel/macos-appearance.nvim",
  event = "UIEnter",
  config = function()
    require("macos-appearance").setup()

    vim.api.nvim_create_autocmd("User", {
      pattern = "MacosAppearanceChanged",
      callback = function(ev)
        -- ev.data.appearance → "dark" | "light"
      end,
    })
  end,
}
```

`UIEnter` lets Base46 initialize before this plugin synchronizes the theme. `VeryLazy` also works, but may briefly
display the wrong theme before synchronization.

## Behavior

During `setup()`, the plugin:

1. Detects the current macOS appearance.
2. Fires `User MacosAppearanceChanged` with `data = { appearance = "dark" | "light" }`.
3. Calls the `callback` function (if configured).
4. Starts watching the macOS global preferences plist.
5. Registers cleanup for `VimLeavePre`.

Automatic theme changes only affect the current Neovim process. The plugin never rewrites `chadrc.lua`.

File events are debounced for 100 milliseconds. Because macOS may atomically replace the preferences plist, the
plugin discards the old file handle and attaches a new watcher after each event.

## Options

```lua
require("macos-appearance").setup {
  debounce_ms = 100,
  retry_ms = 250,
  notify = true,
  callback = require("macos-appearance.adapters.nvchad"),
}
```

| Option | Default | Description |
| --- | ---: | --- |
| `debounce_ms` | `100` | Delay used to merge consecutive file events |
| `retry_ms` | `250` | Delay before retrying when the plist cannot be watched |
| `notify` | `true` | Show informational messages |
| `path` | macOS global preferences plist | Override the watched file, mainly for testing |
| `callback` | `nil` | Function or adapter object called on appearance change |

A `callback` can be a plain function `fun(appearance: "dark"|"light")` or an adapter table
`{ apply = fun(appearance), reset? = fun() }`. Adapter objects receive `reset()` during re-setup
to clear internal state.

## API

```lua
local appearance = require "macos-appearance"

appearance.get()   -- "light" or "dark"
appearance.sync()  -- detect and fire event / callback once
appearance.start() -- start listening
appearance.stop()  -- stop and release libuv handles
```

Repeated calls to `setup()` are safe: the previous watcher is stopped before a new one is created.
`setup()` returns `started, error`; configuration or platform errors prevent the watcher from starting.

## NvChad adapter

```lua
local nvchad = require("macos-appearance.adapters.nvchad")

nvchad.apply("dark")   -- apply dark theme and return (changed, error?)
nvchad.reset()         -- clear internal state before re-setup
```

## Development

```sh
make check
```

The test suite runs in headless Neovim and does not change the system appearance or the real preferences plist.

## License

MIT
