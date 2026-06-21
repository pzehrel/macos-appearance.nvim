# macos-appearance.nvim

Automatically synchronize Neovim with the current macOS light or dark appearance.

The plugin listens to `~/Library/Preferences/.GlobalPreferences.plist` with `vim.uv.new_fs_event()`.
It performs one synchronization during setup, then reacts to file events without periodic polling.

The initial adapter targets NvChad Base46 and reuses the themes already defined in `theme_toggle`.

## Requirements

- macOS
- Neovim 0.10 or newer
- NvChad with Base46
- Two themes configured in `base46.theme_toggle`

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

With lazy.nvim:

```lua
{
  "pzehrel/macos-appearance.nvim",
  event = "UIEnter",
  config = function()
    require("macos-appearance").setup()
  end,
}
```

`UIEnter` lets Base46 initialize before this plugin synchronizes the theme. `VeryLazy` also works, but may briefly
display the wrong theme before synchronization.

## Behavior

During `setup()`, the plugin:

1. Installs a process-local replacement for `require("base46").toggle_theme`.
2. Detects the current macOS appearance.
3. Applies `theme_toggle[1]` for light mode or `theme_toggle[2]` for dark mode.
4. Starts watching the macOS global preferences plist.
5. Registers cleanup for `VimLeavePre`.

Automatic and manual theme changes only affect the current Neovim process. The plugin never rewrites `chadrc.lua`.

File events are debounced for 100 milliseconds. Because macOS may atomically replace the preferences plist, the
plugin discards the old file handle and attaches a new watcher after each event.

## Options

```lua
require("macos-appearance").setup {
  debounce_ms = 100,
  retry_ms = 250,
  notify = true,
}
```

| Option | Default | Description |
| --- | ---: | --- |
| `debounce_ms` | `100` | Delay used to merge consecutive file events |
| `retry_ms` | `250` | Delay before retrying when the plist cannot be watched |
| `notify` | `true` | Show adapter and watcher messages |
| `path` | macOS global preferences plist | Override the watched file, mainly for testing |
| `adapter` | NvChad adapter | Override theme application behavior |

## API

```lua
local appearance = require "macos-appearance"

appearance.get()   -- "light" or "dark"
appearance.sync()  -- detect and apply once
appearance.start() -- start listening
appearance.stop()  -- stop and release libuv handles
```

Repeated calls to `setup()` are safe: the previous watcher is stopped before a new one is created.
`setup()` returns `started, error`; configuration or platform errors prevent the watcher from starting.

## Development

```sh
make check
```

The test suite runs in headless Neovim and does not change the system appearance or the real preferences plist.

## License

MIT
