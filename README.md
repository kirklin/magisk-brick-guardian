# Brick Guardian (自动防砖守护)

[![GitHub release](https://img.shields.io/github/release/kirklin/magisk-brick-guardian.svg)](https://github.com/kirklin/magisk-brick-guardian/releases)
[![GitHub license](https://img.shields.io/github/license/kirklin/magisk-brick-guardian.svg)](https://github.com/kirklin/magisk-brick-guardian/blob/main/LICENSE)

一个 Root 模块，用于防止您的设备因模块导致的启动问题而变砖。支持主流 Root 管理器。

## 特性

- 🛡️ 自动检测并防止模块导致的系统无法启动
- 📝 支持智能白名单机制
- 🔄 OTA升级保护
- 🖥️ 模块状态查看
- 🔔 在线更新支持
- ⚡ 快速恢复：当检测到启动异常时，系统将自动进行修复
- 💪 稳定可靠：经过严格测试，确保您的设备安全

## 兼容性

本模块支持以下 Root 管理器：

| Root 管理器 | 最低版本 | 状态 |
|------------|---------|------|
| [Magisk](https://github.com/topjohnwu/Magisk) | v20.4+ | ✅ 完全支持 |
| [KernelSU](https://github.com/tiann/KernelSU) | v0.6.0+ | ✅ 完全支持 |
| [KSU Next](https://github.com/KernelSU-Next/KernelSU-Next) | v1.0.0+ | ✅ 完全支持 |
| [APatch](https://github.com/bmax121/APatch) | v10763+ | ✅ 完全支持 |

## 安装要求

- Android 10.0+

## 安装方法

1. 在对应的 Root 管理器中下载并安装此模块
2. 重启设备
3. 首次启动后请等待1.5分钟，以确认模块正常运行

## 使用说明

- 模块安装后会自动运行，无需额外配置
- 如需自定义白名单，请编辑 `/data/adb/modules/magisk-brick-guardian/白名单.conf` 文件
- 如遇到无法开机的情况，系统将自动进行修复
- 模块状态查看：在管理器中点击模块的 action 按钮可查看模块状态信息
- 在线更新：在管理器中可直接检查和安装模块更新

### 模块状态信息

点击 action 按钮后，您可以查看以下信息：

1. 模块基本信息（名称、版本、作者）
2. 模块运行状态
3. 救砖脚本状态
4. 白名单状态
5. 救砖统计和启动次数
6. Root 管理器信息
7. 系统信息
8. 最近的日志记录

## 注意事项

- ⚠️ 安全警告：请仅从本项目的 [GitHub Releases](https://github.com/kirklin/magisk-brick-guardian/releases) 页面下载模块，以防止下载到被恶意篡改的版本
- 首次安装后请耐心等待1.5分钟，让模块完成初始化
- 建议在安装其他模块前先安装本模块，以获得最佳保护
- 如果您修改了白名单配置，请重启设备以使更改生效

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

## 作者

[Kirk Lin](https://github.com/kirklin)

## 致谢

感谢所有为此项目做出贡献的开发者！ 
