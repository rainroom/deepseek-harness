# Rain Harness fork 修改记录

本目录记录 `rainroom/deepseek-harness` 在 `rain_source_sin_use` 分支上，相对上游
`deepseek-ai/deepseek-harness` 的全部改动，供打包和后续同步上游时逐项核对。

## 目的

产出一个能与官方桌面端**同时安装、同时运行**的客户端，并且完整沿用默认环境：

- **数据根、Desktop profile 全部沿用默认**：`~/.dsh` 与 `~/.dsh/profiles/desktop`。
  插件生态按默认路径取数，自定义目录或自定义 profile 都会让部分插件失效，因此这里不做改动。
- **只隔离 Electron 身份**：userData 目录、单实例锁、安装身份、显示名、URL 协议。
  这是"两个客户端能同时开"的唯一依据。
- 不使用自动更新：每次升级由本仓库重新打包完成。

## 改动清单

改动刻意保持最小，只触碰身份与更新策略。

| # | 文件 | 改动 | 原因 |
|---|---|---|---|
| 1 | `apps/desktop/scripts/electron-builder-config.mjs` | `extraMetadata.name` 设为 `'@rainroom/dsh-desktop'` | Electron 从打包后的 manifest 取 `app.name`，据此决定 userData 目录与单实例锁名。**这是两个客户端能同时运行的唯一依据。** |
| 2 | 同上 | `productName` 改为 `'Rain Harness'` | 决定安装目录、可执行文件名、卸载项显示名。同名会被当作升级覆盖。 |
| 3 | 同上 | `protocols` 改为 `{ name: 'Rain Harness', schemes: ['raindsh'] }` | 两个客户端不再抢同一个 `dsh://` 协议处理器。 |
| 4 | 同上 | unsigned 构建不再解析强制更新策略 | 上游只对 macOS unsigned 免除，Windows 仍强制要求 HTTPS 策略来源。本 fork 不参与自动更新，该要求只会挡住本地打包。 |
| 5 | `apps/desktop/scripts/desktop-package-environment.mjs` | 同上：`validateDesktopPackageEnvironment` 只在非 unsigned 时解析策略 | 跟随改动 #4。 |
| 6 | `apps/desktop/src/main.ts` | `setAsDefaultProtocolClient('raindsh')`、`raindsh://open` | 跟随改动 #3。 |
| 7 | `apps/desktop/tests/welcome-startup.spec.ts` | 两处 `dsh://open` 断言改为 `raindsh://open` | 跟随改动 #6。 |
| 8 | `apps/desktop/scripts/electron-builder-config.mjs` + `resources/icon-windows.ico` | `win.icon` 改用预生成的多尺寸 ICO，并提交该文件 | electron-builder 的 PNG→ICO 转换会调起 WASM 图标工具，需要 WASM SIMD；不支持 SIMD 的机器（含部分虚拟机）会在打包最后一步失败。 |
| 9 | `apps/desktop/scripts/smoke-packaged-runtime.ts` | 用 `PRODUCT_NAME` 常量替代硬编码的 `DeepSeek Harness.exe` / `.app` | 打包后的冒烟测试按固定文件名启动应用；产品名改了之后它找不到 exe。 |

### 刻意未改动

- **`DSH_HOME_DIR_NAME` 保持 `.dsh`，Desktop profile 保持 `profiles/desktop`。**
  两者都曾改过（`.raindsh`、`rain-desktop`），但那样会让按默认路径取数的插件失效，已全部还原。
- **产物文件名保持 `deepseek-harness-` 前缀。** 打包流程用它定位产物：
  `desktop-build-version-discovery.ts` 的正则、`package-target.ts`、`package-macos.ts`、
  `desktop-upload-plan.ts`、`retain-desktop-ci.ts` 都硬编码了该前缀，改名会让流程找不到输出。
- **`apps/desktop/package.json` 的 `name` 保持 `@deepseek-ai/dsh-desktop`。** 改它会打断根
  `package.json` 里的 `pnpm --filter @deepseek-ai/dsh-desktop` 脚本和仓库命名约束；
  身份隔离由改动 #1 在打包产物里完成。
- **`~/.agents` 不变。** 与官方版共用用户级 `AGENTS.md` 与 `skills/`。

## 效果对照

| 项 | 官方版 | 本 fork |
|---|---|---|
| 数据根（会话/凭据/storages） | `~/.dsh` | `~/.dsh`（**共享**） |
| Desktop profile（插件、配置） | `~/.dsh/profiles/desktop` | `~/.dsh/profiles/desktop`（**共享**） |
| Electron userData | `%APPDATA%\@deepseek-ai\dsh-desktop` | `%APPDATA%\@rainroom\dsh-desktop`（独立） |
| 单实例锁 | 按 userData | **独立，可与官方版同时运行** |
| 程序显示名 | DeepSeek Harness | Rain Harness |
| 安装目录 | `%LOCALAPPDATA%\Programs\DeepSeek Harness` | `%LOCALAPPDATA%\Programs\Rain Harness` |
| URL 协议 | `dsh://` | `raindsh://` |
| 自动更新 | 有 | 无（手动重新打包） |

## 使用须知

- 两个客户端可以同时打开，互不退出——依据是 Electron userData 与单实例锁分开。
- **插件与配置完全共享**：两个客户端读同一份 `profiles/desktop`。在任意一边安装、禁用或配置插件，
  另一边同样生效。这是换取"默认插件环境可用"的代价。
- **两个构建的 DSH 版本应保持一致。** 同一 profile 的 core package set 来自应用自身；版本不同时
  可能出现"一边能启动、另一边报不匹配"。
- **不要在两个客户端里同时操作同一个会话**，会话目录共享，双开会冲突写入。
- 升级本 fork 只替换程序目录，`~/.dsh` 与 `%APPDATA%\@rainroom\dsh-desktop` 都不会被删除。

## 打包

`apps/desktop/.env.windows` 被 git 忽略；改动 #4/#5 之后，unsigned 构建只需要其中的安装器身份。
`fork/install-green.ps1` 会在它缺失时按 `fork/windows.env.template` 自动生成，通常不必手动准备。

### 免安装绿色版（日常使用）

一条命令完成"构建 → 关闭旧实例 → 镜像到稳定目录 → 修好快捷方式"：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File D:\E\AI_DEV_PROJECT\dsh-use\fork\install-green.ps1
```

只重新部署现有构建（跳过约 16–20 分钟的构建）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File D:\E\AI_DEV_PROJECT\dsh-use\fork\install-green.ps1 -SkipBuild
```

### 部署位置

- 程序目录：`D:\E\AI_DEV_PROJECT\dsh-use-app`
- 快捷方式：`<桌面>\Rain Harness.lnk` → `dsh-use-app\Rain Harness.exe`

重新打包只替换程序目录里的文件，路径不变，快捷方式因此一直有效。可用参数覆盖默认值：
`-Repo`、`-InstallDir`、`-ProductName`、`-SkipBuild`、`-NoShortcut`。

### 打包前快速校验配置

```powershell
cd apps\desktop
pnpm exec tsx scripts/package-target.ts win-x64 --unsigned --check
```

注意：不带 `--unsigned` 的 `--check` 走签名发布路径，仍会要求策略来源。

## 升级前准备（只需一次）

- Node ≥ 24.9 与仓库自带的 pnpm；首次克隆后先执行 `pnpm install`（约 5 分钟）。
- 磁盘占用：构建目录约 3 GB，部署目录约 1.1 GB。
- **构建期间不要改动 git**（提交、切分支、改工作树）。构建会把 commit/脏标记写进客户端产物记录，
  中途变化会让打包在最后阶段判定"构建环境与产物不一致"而失败。

## 每次更新的流程

```powershell
cd D:\E\AI_DEV_PROJECT\dsh-use
git fetch upstream master
git merge upstream/master          # 冲突基本只出现在上表文件
pnpm install                       # 依赖有变化时

# 构建 + 部署 + 修好快捷方式（会先关闭正在运行的旧实例；约 16-20 分钟）
powershell -NoProfile -ExecutionPolicy Bypass -File fork\install-green.ps1
```

只想重新部署现有构建：加 `-SkipBuild`。

## 升级后验证

1. 双击桌面 `Rain Harness`，帮助菜单的"关于"里版本号是新的。
2. `~/.dsh/profiles/desktop` 被正常使用，插件列表与官方版一致。
3. 官方客户端仍能同时打开，两者互不退出。
4. 快捷方式目标仍是 `D:\E\AI_DEV_PROJECT\dsh-use-app\Rain Harness.exe`。

## 故障处理

| 现象 | 处理 |
|---|---|
| 打包末尾报 `client build environment differs` | 构建期间动过 git。保持工作树干净后重跑。 |
| 报 `desktop package: cannot read ... .env.windows` | 删掉损坏的文件，重跑脚本会自动重建。 |
| 桌面快捷方式打不开 | 部署目录被移动或删除。重跑 `install-green.ps1 -SkipBuild`。 |
| 两个客户端互相踢下线 | 检查 `extraMetadata.name`（改动 #1）是否丢失，它决定单实例锁。 |
| 一边启动报 profile 不匹配 | 两个构建的 DSH 版本不一致，统一到同一版本后重打。 |
| 想回滚到上一版 | 升级前把 `dsh-use-app` 复制一份；回滚时关闭应用、把副本还原回该路径。 |

## 同步上游后必须复查

1. `electron-builder-config.mjs` 的 `extraMetadata.name`、`productName`、`protocols`
   与 `main.ts` 的协议字符串仍然一致。
2. unsigned 的两处策略例外（改动 #4/#5）仍在，否则打包会重新要求 HTTPS 策略来源。
3. 产品名 `Rain Harness` 出现在两处并需同步：`electron-builder-config.mjs` 的 `productName`
   与 `smoke-packaged-runtime.ts` 的 `PRODUCT_NAME`。
4. `DSH_HOME_DIR_NAME` 仍是 `.dsh`、profile 仍是 `profiles/desktop`（本 fork 不修改它们）。

## 已知限制

- **数据与插件完全共享。** 两个客户端是同一份 `~/.dsh` 的两个外壳，谈不上互相隔离。
- **同一会话不可双开。** 两端同时操作会造成冲突写入。
- **版本漂移有风险。** 共享 profile 时，两个构建的 DSH 版本差异会导致 core package set 不匹配。
- **没有自动更新。** 应用不带更新源，升级只能靠重新打包。
- **`ds-harness-remote` 类插件仍不可用。** 它们要求 Desktop 宿主暴露 `webServer` 服务；
  当前 DSH 在桌面宿主下取不到，属于插件与宿主的能力不匹配，与本 fork 改动无关。

## 已验证

2026-11-17 实测：

- `install-green.ps1` 完整跑通（构建 + 冒烟 + 镜像 + 快捷方式），退出码 0。
- 绿色版部署到 `D:\E\AI_DEV_PROJECT\dsh-use-app`，桌面快捷方式指向该目录。
- 早期版本验证过：自定义 home（`~/.raindsh`）与自定义 profile（`rain-desktop`）都能正常启动，
  官方 profile 不受影响；两种方案均已按需求还原为默认值。

## 待办

- [ ] 与官方客户端**同时运行**的实测：需要官方安装路径（本机未在常见位置找到）。
- [ ] 共享 profile 后，确认官方版原本可用的插件在本 fork 中同样可用。
