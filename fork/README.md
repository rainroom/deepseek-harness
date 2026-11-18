# Rain Harness fork 修改记录

本目录记录 `rainroom/deepseek-harness` 在 `rain_source_sin_use` 分支上，相对上游
`deepseek-ai/deepseek-harness` 的全部改动，供打包和后续同步上游时逐项核对。

## 目的

产出一个能与官方桌面端**同时安装、同时运行**的独立客户端，并保持第三方插件可用：

- **数据根沿用默认的 `~/.dsh`**。插件生态普遍按这个默认目录取数，改成自定义目录会让它们失效；
  因此这里接受与官方版共享会话、凭据、storages。
- **Desktop profile 改名为 `rain-desktop`**。官方版占用 `profiles/desktop` 并持有其锁，改名后
  两者互不争夺，各自管理自己的插件集合。
- **Electron 用户数据、单实例锁、安装身份、URL 协议保持独立**，这是"能同时开"的关键。
- 不使用自动更新：每次升级由本仓库重新打包完成。

## 改动清单

改动刻意保持最小，只触碰身份、profile 归属和更新策略。

| # | 文件 | 改动 | 原因 |
|---|---|---|---|
| 1 | `apps/desktop/src/paths.ts` | Desktop profile 由 `profiles/desktop` 改为 `profiles/rain-desktop`（含 `lock`） | 官方桌面端独占 `profiles/desktop` 并加锁；不换名就无法并行运行，也会互相污染插件集合。 |
| 2 | `apps/desktop/scripts/electron-builder-config.mjs` | `extraMetadata.name` 设为 `'@rainroom/dsh-desktop'` | Electron 从打包后的 manifest 取 `app.name`，据此决定 userData 目录与单实例锁名。这是两个客户端能同时运行的另一半。 |
| 3 | 同上 | `productName` 改为 `'Rain Harness'` | 决定安装目录、可执行文件名、卸载项显示名。同名会被当作升级覆盖。 |
| 4 | 同上 | `protocols` 改为 `{ name: 'Rain Harness', schemes: ['raindsh'] }` | 两个客户端不再抢同一个 `dsh://` 协议处理器。 |
| 5 | 同上 | unsigned 构建不再解析强制更新策略 | 上游只对 macOS unsigned 免除，Windows 仍强制要求 HTTPS 策略来源。本 fork 不参与自动更新，该要求只会挡住本地打包。 |
| 6 | `apps/desktop/scripts/desktop-package-environment.mjs` | 同上：`validateDesktopPackageEnvironment` 只在非 unsigned 时解析策略 | 跟随改动 #5，否则校验阶段仍会要求策略来源。 |
| 7 | `apps/desktop/src/main.ts` | `setAsDefaultProtocolClient('raindsh')`、`raindsh://open` | 跟随改动 #4。 |
| 8 | `apps/desktop/tests/welcome-startup.spec.ts` | 两处 `dsh://open` 断言改为 `raindsh://open` | 跟随改动 #7。 |
| 9 | `apps/desktop/scripts/electron-builder-config.mjs` + `resources/icon-windows.ico` | `win.icon` 改用预生成的多尺寸 ICO，并提交该文件 | electron-builder 的 PNG→ICO 转换会调起 WASM 图标工具，需要 WASM SIMD；不支持 SIMD 的机器（含部分虚拟机）会在打包最后一步失败。 |
| 10 | `apps/desktop/scripts/smoke-packaged-runtime.ts` | 用 `PRODUCT_NAME` 常量替代硬编码的 `DeepSeek Harness.exe` / `.app` | 打包后的冒烟测试按固定文件名启动应用；产品名改了之后它找不到 exe。 |
| 11 | `apps/desktop/scripts/smoke-runtime.ts` | 两处 profile 名改为 `rain-desktop` | 跟随改动 #1，否则冒烟测试会在错误的 profile 上安装插件。 |

### 刻意未改动

- **`DSH_HOME_DIR_NAME` 保持 `.dsh`。** 早期版本曾改为 `.raindsh` 以彻底隔离数据，但那会让按
  默认目录取数的插件失效，已还原。隔离改由 profile 名与 Electron userData 承担。
- **产物文件名保持 `deepseek-harness-` 前缀。** 打包流程用它定位产物：
  `desktop-build-version-discovery.ts` 的正则、`package-target.ts`、`package-macos.ts`、
  `desktop-upload-plan.ts`、`retain-desktop-ci.ts` 都硬编码了该前缀，改名会让流程找不到输出。
- **`apps/desktop/package.json` 的 `name` 保持 `@deepseek-ai/dsh-desktop`。** 改它会打断根
  `package.json` 里的 `pnpm --filter @deepseek-ai/dsh-desktop` 脚本和仓库命名约束；
  身份隔离由改动 #2 在打包产物里完成。
- **`~/.agents` 不变。** 它由 `DSH_AGENTS_HOME` 控制，与官方版共用用户级 `AGENTS.md` 与 `skills/`。

## 效果对照

| 项 | 官方版 | 本 fork |
|---|---|---|
| Harness 数据根（会话/凭据/storages） | `~/.dsh` | `~/.dsh`（**共享**） |
| Desktop profile（插件集合、运行锁） | `~/.dsh/profiles/desktop` | `~/.dsh/profiles/rain-desktop`（独立） |
| Electron userData | `%APPDATA%\@deepseek-ai\dsh-desktop` | `%APPDATA%\@rainroom\dsh-desktop`（独立） |
| 单实例锁 | 按 userData | 独立，可与官方版同时运行 |
| 程序显示名 | DeepSeek Harness | Rain Harness |
| 安装目录 | `%LOCALAPPDATA%\Programs\DeepSeek Harness` | `%LOCALAPPDATA%\Programs\Rain Harness` |
| URL 协议 | `dsh://` | `raindsh://` |
| 自动更新 | 有 | 无（手动重新打包） |

## 使用须知

- 两个客户端可以同时打开，互不退出。
- **不要在两个客户端里同时操作同一个会话。** 会话目录共享，双开会造成冲突写入。
- 插件各自安装：官方版的插件在 `profiles/desktop`，本 fork 的在 `profiles/rain-desktop`，互不影响，
  但磁盘占用是两份。
- **界面里安装插件不需要指定 profile。** 插件管理器的 pnpm 工作目录就是本应用自己的 profile 目录，即
  `~/.dsh/profiles/rain-desktop`，等价于 `dsh plugin --profile rain-desktop add …`；那条命令只是等价写法。
- 升级本 fork 只替换程序目录，`~/.dsh` 与 `%APPDATA%\@rainroom\dsh-desktop` 都不会被删除。
- **切换 profile 后旧配置不会自动迁移。** 模型、供应商、界面开关都写在
  `~/.dsh/profiles/<profile>/cordis.patch.yml` 里；换 profile 名后需要把旧的那个文件复制到新
  profile 目录，否则会看起来像"配置丢了"。插件目录 `node_modules` 同理，需要重新安装。

### 本机 profile 私有配置（换机或换 profile 时重做）

下面两个文件属于机器配置，不在仓库里；profile 重建后需要重新放置，否则会表现成"配置丢了 / 私服插件装不上"。

| 文件 | 内容 |
|---|---|
| `~/.dsh/profiles/rain-desktop/cordis.patch.yml` | 模型、供应商（如 `provider: sin`、`baseURL`）、界面开关 |
| `~/.dsh/profiles/rain-desktop/.npmrc` | 私服作用域映射，例如 `@sinexcel:registry=…/sinexcel-deepseek-harness-local-npm/` |

私服认证 token 写在 `%USERPROFILE%\.npmrc`，按相同的 host 与路径作键；profile 的 `.npmrc` 只放作用域映射，不放 token。

## 打包

`apps/desktop/.env.windows` 被 git 忽略；改动 #5/#6 之后，unsigned 构建只需要其中的安装器身份。
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

`fork/install-green.ps1` 把构建镜像到稳定目录，并让桌面快捷方式固定指向那里：

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
2. `~/.dsh/profiles/rain-desktop` 存在，`profiles/desktop` 未被创建或修改。
3. 官方客户端仍能同时打开，两者互不退出。
4. 本 fork 装过的插件在 `~/.dsh/profiles/rain-desktop`，官方版插件列表不受影响。
5. 快捷方式目标仍是 `D:\E\AI_DEV_PROJECT\dsh-use-app\Rain Harness.exe`。

## 故障处理

| 现象 | 处理 |
|---|---|
| 打包末尾报 `client build environment differs` | 构建期间动过 git。保持工作树干净后重跑。 |
| 报 `desktop package: cannot read ... .env.windows` | 删掉损坏的文件，重跑脚本会自动重建。 |
| 桌面快捷方式打不开 | 部署目录被移动或删除。重跑 `install-green.ps1 -SkipBuild`。 |
| 两个客户端互相踢下线 | 检查是否 `extraMetadata.name` 丢失（改动 #2），它决定单实例锁。 |
| 想回滚到上一版 | 升级前把 `dsh-use-app` 复制一份；回滚时关闭应用、把副本还原回该路径。 |

## 同步上游后必须复查

1. `apps/desktop/src/paths.ts` 的 profile 仍是 `rain-desktop`；`smoke-runtime.ts` 同步。
2. `electron-builder-config.mjs` 的 `extraMetadata.name`、`productName`、`protocols`
   与 `main.ts` 的协议字符串仍然一致。
3. unsigned 的两处策略例外（改动 #5/#6）仍在，否则打包会重新要求 HTTPS 策略来源。
4. 产品名 `Rain Harness` 出现在两处并需同步：`electron-builder-config.mjs` 的 `productName`
   与 `smoke-packaged-runtime.ts` 的 `PRODUCT_NAME`。
5. `DSH_HOME_DIR_NAME` 仍是 `.dsh`（本 fork 不修改它）。

## 已知限制

- **会话与凭据共享。** 这是换取插件兼容性的代价：两个客户端看到同一份会话列表。
- **同一会话不可双开。** 两端同时操作会造成冲突写入。
- **没有自动更新。** 应用不带更新源，升级只能靠重新打包。
- **`ds-harness-remote` 需要先登录账号，不是接口不兼容。** 未登录时插件宿主连不上
  `https://dsh.r2049.cn`，服务端返回 `401 ACCOUNT_AUTH_REQUIRED`，界面显示为"控制通道仍在启动"。
  在 Remote 设置里登录（或从已登录的 Remote 客户端授权本机）后即可使用。插件日志在
  `~/.dsh/logs/ds-harness-remote/host.log`，身份与凭据在 `~/.dsh/ds-harness-remote/servers/<hash>/`，
  该目录位于 Harness home 下，两个客户端共用同一份登录状态。
- **文档与快照仍写着 `~/.dsh` 的旧描述**，与现状一致，无需同步。

## 已验证

2026-11-17 实测：

- `tsx scripts/package-target.ts win-x64 --unsigned --dir` 完整跑通，退出码 0，含冒烟测试。
- 绿色版部署到 `D:\E\AI_DEV_PROJECT\dsh-use-app`，桌面快捷方式指向该目录。
- 早前版本（`.raindsh` + `profiles/desktop`）已验证过：数据写入自有 home、官方 `~/.dsh` 未被触碰。
  当前版本改为共享 `~/.dsh` 并换用 `rain-desktop` profile，两者的并行运行待本轮构建后复验。

## 待办

- [ ] 本轮构建后验证：`profiles/rain-desktop` 被创建、官方 `profiles/desktop` 不受影响、
      两个客户端可同时运行、插件安装在 `rain-desktop` 下。
- [ ] 如需数据完全隔离又要插件可用，只能逐插件适配其取数逻辑，无法在本 fork 内统一解决。
