# NEXUS iOS SYSTEM TOOLBOX

Swift 6 + SwiftUI 原生 iOS 系统工具箱。主要目标 iOS 26–27，部署目标设为 iOS 18.0，以便 iOS 26 以下自动回退到 Material（回退路径不是真正的 Liquid Glass）。

> **重要：本工程由 AI 生成，生成环境没有 Xcode / Swift 编译器，代码未经编译和真机测试。** 首次编译可能出现少量语法或并发（Swift 6 strict concurrency）报错，按提示修正即可；各处 iOS 26 API（`glassEffect`、`GlassEffectContainer`、`glassEffectID`、`glassEffectTransition`、`.glass`、`.glassProminent`）都用 `#available(iOS 26.0, *)` 包裹。未使用任何我无法核实的 iOS 27 新 API。

## 编译

需要 macOS + Xcode 26 或更新版本。

```bash
brew install xcodegen
xcodegen generate          # 由 project.yml 生成 NEXUS.xcodeproj
open NEXUS.xcodeproj       # 选择你的 Team 后运行
```

没有 XcodeGen 时：在 Xcode 新建 iOS App（SwiftUI、Swift 6），删除模板源文件，把 `NEXUS/Sources` 与 `NEXUS/Resources` 拖入工程，Info.plist 参照 `project.yml` 的 `info.properties`。

GitHub Actions：`.github/workflows/build.yml` 会生成工程并产出**未签名** IPA（runner 名称若变动请自行调整）。未签名 IPA 需要你自己用侧载工具签名。

重新生成图标：`python3 Tools/make_icon.py`（需要 Pillow）。

## 依赖清单

- 第三方 Swift 包 / SDK：**无**
- 系统框架：SwiftUI、UIKit、Metal、Network、CoreMotion、CoreTelephony、AVFoundation、LocalAuthentication、Security
- 构建工具：XcodeGen
- 联网数据源：GitHub REST API、NIST NVD API 2.0、Cloudflare 测速端点

## 模块

| 目录 | 内容 |
|---|---|
| `Core/Compat.swift` | 兼容性引擎：按机型标识符、系统版本、Build 号给出 可用 / 受限 / 不支持 / 未经验证 |
| `Core/DeviceInfo.swift`, `Network.swift` | 系统信息、检测、CPU 基准、测速（公开 API / sysctl） |
| `Core/GitHubService.swift`, `Catalog.swift`, `Research.swift` | 项目元数据实时获取、维护状态判定、GitHub 搜索、NVD CVE |
| `Gestalt/` | plist 模型、编辑、备份、撤销、记录、预设、私有 API 只读探测 |
| `Views/` | 5 个标签页 + 工具页面 + Liquid Glass 实验室 + 设置 |

## 诚实说明（请先读）

1. **不会写入系统 MobileGestalt。** 普通 App 读不到也写不了系统里的 `com.apple.MobileGestalt.plist`；写入需要漏洞利用或特殊权限，你的需求里要求不集成，所以 NEXUS 只编辑你导入的 plist 副本并导出。「写入系统」在兼容矩阵里标为「不支持」，不会假装成功。
2. **MobileGestalt 预设的键名已全部核实，值未经验证。** 键名来自 GitHub 项目 [PoomSmart/MGKeys](https://github.com/PoomSmart/MGKeys) 的 `mapping-gestalt.h`（928 个键）；其混淆算法（`base64(MD5("MGCopyAnswer"+键名))` 去掉末尾 2 字符）我在构建时用 Python 对 61 个键名逐一校验，全部与映射表一致。应用内只存键名，哈希运行时计算，并支持在字段浏览器里直接搜索**明文键名**（如 `DeviceSupportsDynamicIsland`）。预设写入的是布尔能力位的整数 1，这是常见做法，但 Apple 是否接受、值是否正确我无法验证，所以全部标「未经验证」。操作按钮对应的 `RingerButtonCapability` 是枚举值，取值没有文档，因此不提供一键修改；HDR 有两个候选键，也不提供。
3. **实时读取 MobileGestalt** 通过 `dlsym` 调用私有 `MGCopyAnswer`，仅只读，结果未经验证，系统可能返回空，界面显示「不可获取」。使用私有 API 的应用无法上架 App Store。
4. **项目数据全部实时获取**：名称、作者、简介、许可证、更新时间、Release、归档状态都来自 GitHub API；失效（404）、归档、超过 18 个月未推送的项目会被标记。**「支持的 iOS 版本 / 设备型号」无法由 API 得到**，只有我从 README / 公开页面核对过的项目才有声明，其余显示「未标注」。
5. **种子项目里有 4 个 MobileGestalt 编辑器**（GestaltEdit、mond、GestaltX、Nugget）：据 README 它们依赖漏洞或私有 API，且多数仅限 iOS 27 beta。NEXUS 只放链接和元数据，不集成其代码。其中 GestaltX 据公开帖子曾被封号，可能已失效，应用会实时检测。我没有收录以「沙盒逃逸」为卖点的利用类仓库。
6. **「发现」页可搜索 GitHub 上的内核 / 沙盒 / 越狱等主题**，结果可能含利用类仓库；NEXUS 只展示元数据和链接。
7. **CVE 页签** 来自 NVD 最近 110 天、描述含 iPadOS 的条目，按风险等级（CVSS）显示；分类筛选是关键词匹配，不是人工分类。
8. **机型表**收录 iPhone 11 至 iPhone 17 系列（含 SE、16e、Air、17e），标识符来自 GitHub 的机型 ID 列表（adamawolf gist）与 EveryMac；灵动岛 / Always-On 对 iPhone 17 与 Air 已由 Apple 规格页核实。iPhone Air 和 17e 的相机控制 / 操作按钮、17e 的其余规格我没核实到，标「未经验证」。iPhone 18 Pro、iPad 等未收录机型同样标「未经验证」，不会猜测。
9. 无法通过公开 API 获取的项目（序列号、UDID、电池循环次数 / 健康度、温度数值、CPU 主频、运营商名称）均显示「不可获取」。芯片市场名称与市场型号额外尝试用私有 `MGCopyAnswer`（键 `marketing-soc-name` / `marketing-name`）读取，读到则标注「未经验证」，读不到仍显示不可获取。电池循环次数在 App 内没有可行的公开接口；电脑端工具（libimobiledevice、pymobiledevice3，已在研究中心收录）能读诊断信息，但我没有核实具体命令，不在应用里承诺。
10. **本地化**：简体中文 + 英文，覆盖主要界面文案；部分动态文本（兼容性原因、说明文字）目前只有中文。
11. 「更新提醒」为应用内标记（收藏的仓库出现新提交时显示），没有后台推送。
12. 设置里「更新检查仓库」默认 `hmk849/NEXUS`，这个仓库我并不知道是否存在，请改成你自己的发布仓库。
