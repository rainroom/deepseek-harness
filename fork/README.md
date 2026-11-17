# Rain Harness fork 修改记录

本目录记录 `rainroom/deepseek-harness` 在 `rain_source_sin_use` 分支上，相对上游
`deepseek-ai/deepseek-harness` 的全部改动，供打包和后续同步上游时逐项核对。

## 目的

产出一个可以长期使用、独立安装的客户端：

- 数据根是 `~/.raindsh`，与官方版的 `~/.dsh` 完全分开。
- Electron 用户数据、单实例锁、安装身份、URL 协议都与官方版不同，因此两者可以同时安装、
  同时运行、互不覆盖。
- 不使用自动更新：每次升级由本仓库重新打包完成。

## 改动清单

改动刻意保持最小，只触碰决定身份、路径和更新策略的位置，避免每次同步上游都大面积冲突。

| # | 文件 | 改动 | 原因 |
|---|---|---|---|
| 1 | `packages/util/home-paths/src/index.ts` | `DSH_HOME_DIR_NAME` 由 `'.dsh'` 改为 `'.raindsh'` | 这是所有 Harness 数据（sessions、profiles、credentials、storages、workspaces）的唯一默认根。改这一行即整体迁移到 `~/.raindsh`。`$DSH_HOME` 仍然优先，显式配置仍然最高优先。 |
| 2 | `packages/experimental/liveshare/src/host/share-host.ts` | `defaultOwnerStateFile()` 的兜底目录由 `'.dsh'` 改为 `'.raindsh'` | 该文件自己硬编码了 home 兜底，不跟随改动 #1。注释已标明它镜像 `DSH_HOME_DIR_NAME`。 |
| 3 | `apps/desktop/scripts/electron-builder-config.mjs` | `extraMetadata.name` 设为 `'@rainroom/dsh-desktop'` | Electron 从打包后的 manifest 取 `app.name`，据此决定 userData 目录与单实例锁名。这一行让两个客户端不再共用 `%APPDATA%\@deepseek-ai\dsh-desktop`。 |
| 4 | 同上 | `productName` 改为 `'Rain Harness'` | electron-builder 用它决定安装目录（`%LOCALAPPDATA%\Programs\<productName>`）、可执行文件名、卸载项显示名。同名会被当作升级覆盖。 |
| 5 | 同上 | `protocols` 改为 `{ name: 'Rain Harness', schemes: ['raindsh'] }` | 两个客户端不再抢同一个 `dsh://` 协议处理器。 |
| 6 | 同上 | unsigned 构建不再解析强制更新策略 | 上游把"无策略"只给了 macOS unsigned，Windows 仍需一个 HTTPS 策略来源。本 fork 从不参与自动更新，这个要求只会挡住本地打包。 |
| 7 | `apps/desktop/scripts/desktop-package-environment.mjs` | `validateDesktopPackageEnvironment` 同样只在非 unsigned 时解析策略 | 跟随改动 #6，否则校验阶段仍会要求填写策略来源。 |
| 8 | `apps/desktop/src/main.ts` | `setAsDefaultProtocolClient('raindsh')`、`raindsh://open` | 跟随改动 #5，注册与解析保持一致。 |
| 9 | `apps/desktop/tests/welcome-startup.spec.ts` | 两处 `dsh://open` 断言改为 `raindsh://open` | 跟随改动 #8。 |
| 10 | `packages/util/home-paths/tests/home-paths.spec.ts` | 默认目录断言改为 `.raindsh` / `~/.raindsh` | 跟随改动 #1。`expandHomePath` 用例仍用任意字面量，与默认值无关，保持不变。 |
| 11 | `apps/desktop/scripts/electron-builder-config.mjs` + `resources/icon-windows.ico` | `win.icon` 改用预生成的多尺寸 ICO，并提交该文件 | electron-builder 的 PNG→ICO 转换会调起 WASM 图标工具，需要 WASM SIMD；不支持 SIMD 的机器（含部分虚拟机）会在打包最后一步失败。用已生成的 ICO 绕开这一步。 |
| 12 | `apps/desktop/scripts/smoke-packaged-runtime.ts` | 用 `PRODUCT_NAME` 常量替代硬编码的 `DeepSeek Harness.exe` / `.app` | 打包后的冒烟测试按固定文件名启动应用；产品名改了之后它找不到 exe，会让整次打包以失败收场。 |

### 刻意未改动

- **产物文件名保持 `deepseek-harness-` 前缀，未改成 `rain-harness-`。** 打包流程用它定位产物：
  `desktop-build-version-discovery.ts` 的正则、`package-target.ts`、`package-macos.ts`、
  `desktop-upload-plan.ts`、`retain-desktop-ci.ts` 都硬编码了该前缀。改名必须同时改这几处，
  冲突面会明显变大，而不影响产品行为——安装后的显示名、安装目录、userData 由 #3/#4 决定。
- **`apps/desktop/package.json` 的 `name` 保持 `@deepseek-ai/dsh-desktop`。** 改它会连带打断根
  `package.json` 里的 `pnpm --filter @deepseek-ai/dsh-desktop` 脚本和仓库的包命名约束。
  身份隔离改由改动 #3 在打包产物中完成，工作区包名保持不变。
- **`~/.agents` 不变。** 它由 `DSH_AGENTS_HOME` 控制，存放用户级 `AGENTS.md` 与 `skills/`，
  官方版与本 fork 共享。要隔离就在启动前设置 `DSH_AGENTS_HOME`。
- **文档里的 `~/.dsh` 文案未同步。** 见"已知限制"。

## 效果对照

| 项 | 官方版 | 本 fork |
|---|---|---|
| Harness 数据根 | `~/.dsh` | `~/.raindsh` |
| 已安装插件 | `~/.dsh/profiles/desktop` | `~/.raindsh/profiles/desktop` |
| Electron userData | `%APPDATA%\@deepseek-ai\dsh-desktop` | `%APPDATA%\@rainroom\dsh-desktop` |
| 单实例锁 | 与官方版互斥 | 独立，可与官方版同时运行 |
| 程序显示名 | DeepSeek Harness | Rain Harness |
| 安装目录 | `%LOCALAPPDATA%\Programs\DeepSeek Harness` | `%LOCALAPPDATA%\Programs\Rain Harness` |
| URL 协议 | `dsh://` | `raindsh://` |
| 自动更新 | 有 | 无（手动重新打包） |
| 共享 agent 配置 | `~/.agents` | `~/.agents`（未隔离） |

## 使用方式（绿色版）

绿色版是一个免安装目录，双击其中的 `Rain Harness.exe` 即可启动，不需要管理员权限，
不会写卸载项。启动后它自己拉起内置 Host 进程，随窗口关闭一起退出，**不需要常驻任何服务**。

数据落在两处，都独立于官方版，重启应用和重启电脑都不会丢：

| 内容 | 位置 |
|---|---|
| 会话、凭据、工作区、日志、缓存、**已安装插件** | `~/.raindsh`（插件在 `~/.raindsh/profiles/desktop`） |
| 窗口设置、快捷键、语言缓存、浏览器存储 | `%APPDATA%\@rainroom\dsh-desktop` |

换到新版本时，只要保留这两个目录，覆盖程序目录即可继续使用原有数据。

### 桌面图标

绿色版不自带快捷方式，用一条命令创建（指向实际的 exe 路径）：

```powershell
$exe = '<绿色版目录>\Rain Harness.exe'
$link = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Rain Harness.lnk'
$shell = New-Object -ComObject WScript.Shell
$s = $shell.CreateShortcut($link)
$s.TargetPath = $exe
$s.WorkingDirectory = Split-Path $exe
$s.IconLocation = $exe
$s.Save()
```

## 打包

只需要一次前置准备：`apps/desktop/.env.windows`（被 git 忽略）必须存在。改动 #6/#7 之后，
unsigned 构建只需其中的安装器身份：

```powershell
Copy-Item fork\windows.env.template apps\desktop\.env.windows
# 或直接写一行：DSH_DESKTOP_APP_ID=com.rainroom.harness
```

### 免安装绿色版（日常使用）

```powershell
cd D:\E\AI_DEV_PROJECT\dsh-use\apps\desktop
pnpm exec tsx scripts/package-target.ts win-x64 --unsigned --dir
```

产物是 `win-unpacked` 目录，里面有 `Rain Harness.exe`。

### 带安装程序的版本（需要开始菜单、卸载项时）

```powershell
pnpm run package:desktop:win:x64:unsigned
```

### 打包前快速校验配置

不构建，只验证配置与工具链，几秒即出结果：

```powershell
cd apps\desktop
pnpm exec tsx scripts/package-target.ts win-x64 --unsigned --check
```

注意：不带 `--unsigned` 的 `--check` 走的是签名发布路径，仍会要求策略来源，因此不要用它
判断本 fork 能否打包。

### 重新生成 Windows 图标

`resources/icon-windows.ico` 由同目录的 `icon-windows.png`（1024×1024）生成，含 16/32/48/64/128/256
六种尺寸。换了矢量/位图源之后要重新生成，否则打包会用旧图标：

```powershell
Add-Type -AssemblyName System.Drawing
$root = 'D:\E\AI_DEV_PROJECT\dsh-use\apps\desktop\resources'
$sizes = @(16,32,48,64,128,256)
$image = [System.Drawing.Image]::FromFile("$root\icon-windows.png")
$pngs = foreach ($s in $sizes) {
  $bmp = New-Object System.Drawing.Bitmap($s,$s)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = 'HighQualityBicubic'; $g.PixelOffsetMode = 'HighQuality'
  $g.DrawImage($image,0,0,$s,$s); $g.Dispose()
  $ms = New-Object System.IO.MemoryStream
  $bmp.Save($ms,[System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
  $ms.ToArray()
}
$image.Dispose()
$fs = [System.IO.File]::Create("$root\icon-windows.ico")
$bw = New-Object System.IO.BinaryWriter($fs)
$bw.Write([UInt16]0); $bw.Write([UInt16]1); $bw.Write([UInt16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
for ($i=0; $i -lt $sizes.Count; $i++) {
  $d = $pngs[$i]; $s = $sizes[$i]
  $dim = if ($s -ge 256) { 0 } else { $s }
  $bw.Write([Byte]$dim); $bw.Write([Byte]$dim); $bw.Write([Byte]0); $bw.Write([Byte]0)
  $bw.Write([UInt16]1); $bw.Write([UInt16]32)
  $bw.Write([UInt32]$d.Length); $bw.Write([UInt32]$offset)
  $offset += $d.Length
}
foreach ($d in $pngs) { $bw.Write($d) }
$bw.Flush(); $bw.Dispose(); $fs.Dispose()
```

## 每次更新的流程

```powershell
cd D:\E\AI_DEV_PROJECT\dsh-use
git fetch upstream master
git merge upstream/master          # 冲突基本只出现在上表文件
pnpm install                       # 依赖有变化时
cd apps\desktop
pnpm exec tsx scripts/package-target.ts win-x64 --unsigned --dir
# 用新的 win-unpacked 覆盖旧的程序目录；不要删 ~/.raindsh 与 %APPDATA%\@rainroom\dsh-desktop
```

## 同步上游后必须复查

1. `DSH_HOME_DIR_NAME` 仍是 `.raindsh`（上游若重命名或移动该常量要跟随）。
2. `electron-builder-config.mjs` 的 `extraMetadata.name`、`productName`、`protocols`
   与 `main.ts` 的协议字符串仍然一致。
3. unsigned 的两处策略例外（改动 #6/#7）仍在，否则打包会重新要求 HTTPS 策略来源。
4. 产品名 `Rain Harness` 出现在两处并需同步：`electron-builder-config.mjs` 的 `productName`
   与 `smoke-packaged-runtime.ts` 的 `PRODUCT_NAME`（打包后的冒烟测试用它定位可执行文件）。

## 已知限制

- **文档与快照仍写着 `~/.dsh`。** 仓库内约 69 处 `~/.dsh` 出现在文档与测试快照里，本 fork
  未同步。因此 `pnpm run doc-sync`、部分快照测试会失败。这是有意的取舍：同步这些文案会
  显著扩大每次上游合并的冲突面，而它们不影响产品行为。
- **没有自动更新。** 应用不带更新源，也不会检查更新；升级只能靠重新打包。
- **`~/.agents` 共享。** 用户级 `AGENTS.md` 与 `skills/` 仍与官方版共用。
- **绿色版不是数据便携版。** 数据写在用户目录（见上表），不是 exe 同级目录；删掉程序目录
  不会删除数据，但也不会把数据带走。

## 待办

- [ ] 首次绿色版构建完成后，逐项验证：桌面图标启动、与官方版同时运行、
      会话写入 `~/.raindsh`、安装的插件落在 `~/.raindsh/profiles/desktop`、重启后数据仍在。
- [ ] 如需数据跟着程序目录走（真正的便携版），需要额外改动：启动时把 `DSH_HOME` 与
      Electron userData 指向 exe 同级目录。
