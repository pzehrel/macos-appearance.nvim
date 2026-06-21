# macos-appearance.nvim

[English](README.md) | [简体中文](README.zh-CN.md)

让 Neovim 配色自动跟随 macOS 的浅色或深色外观。

插件使用 `vim.uv.new_fs_event()` 监听
`~/Library/Preferences/.GlobalPreferences.plist`。执行 `setup()` 时会先同步一次系统外观，之后通过文件事件响应变化，无需定时轮询。

目前默认适配 NvChad Base46，并直接复用 `theme_toggle` 中已有的主题配置。

## 环境要求

- macOS
- Neovim 0.10 或更高版本
- 使用 Base46 的 NvChad
- 在 `base46.theme_toggle` 中配置两个主题

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

使用 lazy.nvim：

```lua
{
  "pzehrel/macos-appearance.nvim",
  event = "UIEnter",
  config = function()
    require("macos-appearance").setup()
  end,
}
```

`UIEnter` 会等待 Base46 初始化后再同步主题。也可以使用 `VeryLazy`，但 Neovim 启动时可能短暂显示错误的主题。

## 工作方式

调用 `setup()` 时，插件会：

1. 为 `require("base46").toggle_theme` 安装一个仅影响当前进程的替代实现。
2. 检测当前 macOS 外观。
3. 浅色模式使用 `theme_toggle[1]`，深色模式使用 `theme_toggle[2]`。
4. 开始监听 macOS 全局偏好设置 plist。
5. 注册 `VimLeavePre`，在 Neovim 退出时清理资源。

自动和手动切换都只影响当前 Neovim 进程，插件不会改写 `chadrc.lua`。

文件事件默认使用 100 毫秒防抖。由于 macOS 可能采用原子替换方式更新偏好文件，插件会在每次事件后丢弃旧文件句柄，并重新建立监听。

## 配置项

```lua
require("macos-appearance").setup {
  debounce_ms = 100,
  retry_ms = 250,
  notify = true,
}
```

| 配置项 | 默认值 | 说明 |
| --- | ---: | --- |
| `debounce_ms` | `100` | 合并连续文件事件的延迟时间 |
| `retry_ms` | `250` | 无法监听 plist 时的重试延迟 |
| `notify` | `true` | 是否显示适配器和监听器消息 |
| `path` | macOS 全局偏好设置 plist | 覆盖监听路径，主要用于测试 |
| `adapter` | NvChad 适配器 | 覆盖主题应用逻辑 |

## API

```lua
local appearance = require "macos-appearance"

appearance.get()   -- 返回 "light" 或 "dark"
appearance.sync()  -- 检测并应用一次
appearance.start() -- 开始监听
appearance.stop()  -- 停止监听并释放 libuv 句柄
```

重复调用 `setup()` 是安全的：创建新监听器前会先停止旧监听器。

`setup()` 返回 `started, error`；平台或配置错误会阻止监听器启动。

## 开发

```sh
make check
```

测试套件在无头 Neovim 中运行，不会切换系统外观，也不会修改真实的偏好设置 plist。

## 许可证

MIT
