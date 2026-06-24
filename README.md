# macos-appearance.nvim

[English](README.md) | [简体中文](README.zh-CN.md)

Automatically synchronize Neovim with the current macOS light or dark appearance.

The plugin watches `~/Library/Preferences/.GlobalPreferences.plist` via `vim.uv.new_fs_event()`.
It syncs once during setup, then reacts to file events — no periodic polling.

## Requirements

- macOS
- Neovim 0.10+

## Installation

```lua
{
  "pzehrel/macos-appearance.nvim",
  event = "UIEnter",
  config = function()
    require("macos-appearance").setup {
      callback = function(appearance)
        -- your theme-switching logic here
      end,
    }
  end,
}
```

`callback` receives `"dark"` or `"light"` whenever the system appearance changes
(and once during startup). It can be a plain function or an adapter table
`{ apply = fun(appearance), reset? = fun() }`.

For advanced use, skip `callback` and listen to `User MacosAppearanceChanged`
with `data = { appearance = "dark" | "light" }`.

## Behavior

During `setup()` the plugin:

1. Detects the current macOS appearance.
2. Calls `callback` (if set) and fires `User MacosAppearanceChanged`.
3. Starts watching the plist for changes.
4. Registers cleanup on `VimLeavePre`.

The plugin never writes to `chadrc.lua` or any other config file.
File events are debounced at 100 ms (configurable).

## Options

| Option       | Default                                  | Description                              |
| ---          | ---:                                     | ---                                      |
| `debounce_ms`| `100`                                    | Debounce window for file events          |
| `retry_ms`   | `250`                                    | Retry delay when the plist is unwatchable|
| `notify`     | `true`                                   | Show informational messages              |
| `path`       | `~/Library/Preferences/.GlobalPreferences.plist` | Override the watched file     |
| `callback`   | `nil`                                    | Called on appearance change              |

## API

```lua
local ma = require "macos-appearance"

ma.get()   -- "dark" | "light"
ma.sync()  -- detect now and fire callback / event
ma.start() -- start the file watcher
ma.stop()  -- stop and release handles
```

`setup()` calls `sync()` then `start()`. Repeated calls to `setup()` are safe.

## NvChad adapter

A built-in adapter for NvChad Base46 is included. Configure `theme_toggle` in `chadrc.lua`
(the first theme is light, the second dark):

```lua
-- chadrc.lua
M.base46 = {
  theme = "tokyodark",
  theme_toggle = { "flexoki-light", "tokyodark" },
}
```

Then pass the adapter as the callback:

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

`UIEnter` ensures Base46 is initialized before the first sync.

The adapter exposes `apply(appearance)` and `reset()` for direct use:

```lua
local nvchad = require("macos-appearance.adapters.nvchad")
nvchad.apply("dark")  -- switch to dark theme
nvchad.reset()        -- clear internal state before re-setup
```

## Development

```sh
make check   # format, lint, test
```

Tests run in headless Neovim without touching the real preferences plist.

## License

MIT
