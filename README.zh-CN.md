# macos-appearance.nvim

[English](README.md) | [简体中文](README.zh-CN.md)

让 Neovim 配色自动跟随 macOS 浅色 / 深色外观。

插件通过 `vim.uv.new_fs_event()` 监听 `~/Library/Preferences/.GlobalPreferences.plist`。
`setup()` 时同步一次，之后通过文件事件响应变化，无需定时轮询。

## 环境要求

- macOS
- Neovim 0.10+

## 安装

```lua
{
  "pzehrel/macos-appearance.nvim",
  event = "UIEnter",
  config = function()
    require("macos-appearance").setup {
      callback = function(appearance)
        -- 在此处编写切换主题的逻辑
      end,
    }
  end,
}
```

系统外观变化时（以及启动时首次同步），`callback` 会收到 `"dark"` 或 `"light"`。
它可以是普通函数或适配器对象 `{ apply = fun(appearance), reset? = fun() }`。

如需更细粒度的控制，不传 `callback`，直接监听 `User MacosAppearanceChanged` 事件，
`data = { appearance = "dark" | "light" }`。

## 工作方式

`setup()` 执行时：

1. 检测当前 macOS 外观。
2. 调用 `callback`（如果已设置）并触发 `User MacosAppearanceChanged`。
3. 开始监听 plist 变化。
4. 注册 `VimLeavePre` 清理资源。

插件不会写入 `chadrc.lua` 或任何其他配置文件。文件事件默认防抖 100 毫秒（可配置）。

## 配置项

| 配置项        | 默认值                                     | 说明                     |
| ---           | ---:                                       | ---                      |
| `debounce_ms` | `100`                                      | 文件事件防抖延迟         |
| `retry_ms`    | `250`                                      | plist 无法监听时的重试间隔|
| `notify`      | `true`                                     | 显示提示消息             |
| `path`        | `~/Library/Preferences/.GlobalPreferences.plist` | 覆盖监听路径     |
| `callback`    | `nil`                                      | 外观变化时调用           |

## API

```lua
local ma = require "macos-appearance"

ma.get()   -- "dark" | "light"
ma.sync()  -- 立即检测并触发 callback / 事件
ma.start() -- 启动文件监听
ma.stop()  -- 停止监听并释放句柄
```

`setup()` 等价于 `sync()` + `start()`。可安全重复调用。

## NvChad 适配器

内置 NvChad Base46 适配器。在 `chadrc.lua` 中配置 `theme_toggle`
（第一个为亮色主题，第二个为暗色主题）：

```lua
-- chadrc.lua
M.base46 = {
  theme = "tokyodark",
  theme_toggle = { "flexoki-light", "tokyodark" },
}
```

将适配器作为 callback 传入：

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

`UIEnter` 确保 Base46 初始化完成后再执行首次同步。

适配器也支持直接调用：

```lua
local nvchad = require("macos-appearance.adapters.nvchad")
nvchad.apply("dark")  -- 切换至暗色主题
nvchad.reset()        -- 清除内部状态（re-setup 前使用）
```

## 开发

```sh
make check   # 格式化、lint、测试
```

测试在 headless Neovim 中运行，不会修改真实的偏好设置 plist。

## 许可证

MIT
