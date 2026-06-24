# macos-appearance.nvim

[English](README.md) | [简体中文](README.zh-CN.md)

让 Neovim 配色自动跟随 macOS 的浅色或深色外观。

插件使用 `vim.uv.new_fs_event()` 监听
`~/Library/Preferences/.GlobalPreferences.plist`。执行 `setup()` 时会先同步一次系统外观，之后通过文件事件响应变化，无需定时轮询。

内置 NvChad Base46 适配器。其他配色框架用户可传入自定义 callback 或监听
`User MacosAppearanceChanged` 事件。

## 环境要求

- macOS
- Neovim 0.10 或更高版本

## NvChad 配置

第一个主题视为亮色主题，第二个主题视为暗色主题：

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

## 安装

### NvChad（内置适配器）

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

### 自定义配色方案

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

### 纯事件模式

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

`UIEnter` 等待初始化后再同步主题。也可以使用 `VeryLazy`，但 Neovim 启动时可能短暂显示错误的主题。

## 工作方式

调用 `setup()` 时，插件会：

1. 检测当前 macOS 外观。
2. 触发 `User MacosAppearanceChanged` 事件，附带 `data = { appearance = "dark" | "light" }`。
3. 调用 `callback` 函数（如果已配置）。
4. 开始监听 macOS 全局偏好设置 plist。
5. 注册 `VimLeavePre`，在 Neovim 退出时清理资源。

自动切换只影响当前 Neovim 进程，插件不会改写 `chadrc.lua`。

文件事件默认使用 100 毫秒防抖。由于 macOS 可能采用原子替换方式更新偏好文件，插件会在每次事件后丢弃旧文件句柄，并重新建立监听。

## 配置项

```lua
require("macos-appearance").setup {
  debounce_ms = 100,
  retry_ms = 250,
  notify = true,
  callback = require("macos-appearance.adapters.nvchad"),
}
```

| 配置项 | 默认值 | 说明 |
| --- | ---: | --- |
| `debounce_ms` | `100` | 合并连续文件事件的延迟时间 |
| `retry_ms` | `250` | 无法监听 plist 时的重试延迟 |
| `notify` | `true` | 是否显示提示消息 |
| `path` | macOS 全局偏好设置 plist | 覆盖监听路径，主要用于测试 |
| `callback` | `nil` | 外观变化时调用的函数或适配器对象 |

`callback` 可以是普通函数 `fun(appearance: "dark"|"light")` 或适配器对象
`{ apply = fun(appearance), reset? = fun() }`。适配器对象在 re-setup 时会调用 `reset()` 清除内部状态。

## API

```lua
local appearance = require "macos-appearance"

appearance.get()   -- 返回 "light" 或 "dark"
appearance.sync()  -- 检测并触发事件 / 调用 callback
appearance.start() -- 开始监听
appearance.stop()  -- 停止监听并释放 libuv 句柄
```

重复调用 `setup()` 是安全的：创建新监听器前会先停止旧监听器。

`setup()` 返回 `started, error`；平台或配置错误会阻止监听器启动。

## NvChad 适配器

```lua
local nvchad = require("macos-appearance.adapters.nvchad")

nvchad.apply("dark")   -- 应用暗色主题，返回 (changed, error?)
nvchad.reset()         -- 清除内部状态，用于 re-setup 场景
```

## 开发

```sh
make check
```

测试套件在无头 Neovim 中运行，不会切换系统外观，也不会修改真实的偏好设置 plist。

## 许可证

MIT
