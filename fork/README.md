# Rain Harness fork 修改记录

本目录记录 `rainroom/deepseek-harness` 在 `rain_source_sin_use` 分支上，相对上游
`deepseek-ai/deepseek-harness` 的全部改动，供打包和后续同步上游时逐项核对。

## 目的

产出能与官方桌面端**同时安装、同时运行**的独立客户端，并保持第三方插件可用：

- **数据根沿用默认的 `~/.dsh`**。插件生态普遍按这个默认目录取数，改成自定义目录会让它们失效；
  因此这里接受与官方版共享会话、凭据、storages。
- **Desktop profile 沿用上游的 `profiles/desktop`**，与官方版是同一个。曾改为 `rain-desktop` 试图
  隔离插件集合，但 `ds-harness-remote` 在两种 profile 下都没能加载，隔离只换来配置迁移成本，已还原。
- **Electron 用户数据、单实例锁、安装身份、URL 协议保持独立**，这是"能同时开"的关键。
- 不使用自动更新：每次升级由本仓库重新打包完成。

## 改动清单

改动刻意保持最小，只触碰身份与更新策略。

| # | 文件 | 改动 | 原因 |
|---|---|---|---|
| 1 | `apps/desktop/scripts/electron-builder-config.mjs` | `extraMetadata.name` 设为 `'@rainroom/dsh-desktop'` | Electron 从打包后的 manifest 取 `app.name`，据此决定 userData 目录与单实例锁名。这是两个客户端能同时运行的唯一机制。 |
| 2 | 同上 | `productName` **保持上游 `'DeepSeek Harness'`** | 运行时资产硬编码了产品名，例如 `resources/runtime/cli/bin/dsh.cmd` 启动 `<app>/DeepSeek Harness.exe`；改名会让内置 CLI 与依赖它的功能失效。共存由 `extraMetadata.name` 负责，不需要改产品名。 |
| 3 | 同上 | `protocols` 改为 `{ name: 'Rain Harness', schemes: ['raindsh'] }` | 两个客户端不再抢同一个 `dsh://` 协议处理器。 |
| 4 | 同上 | unsigned 构建不再解析强制更新策略 | 上游只对 macOS unsigned 免除，Windows 仍强制要求 HTTPS 策略来源。本 fork 不参与自动更新，该要求只会挡住本地打包。 |
| 5 | `apps/desktop/scripts/desktop-package-environment.mjs` | 同上：`validateDesktopPackageEnvironment` 只在非 unsigned 时解析策略 | 跟随改动 #4，否则校验阶段仍会要求策略来源。 |
| 6 | `apps/desktop/src/main.ts` | `setAsDefaultProtocolClient('raindsh')`、`raindsh://open` | 跟随改动 #3。 |
| 7 | `apps/desktop/tests/welcome-startup.spec.ts` | 两处 `dsh://open` 断言改为 `raindsh://open` | 跟随改动 #6。 |
| 8 | `apps/desktop/scripts/electron-builder-config.mjs` + `resources/icon-windows.ico` | `win.icon` 改用预生成的多尺寸 ICO，并提交该文件 | electron-builder 的 PNG→ICO 转换会调起 WASM 图标工具，需要 WASM SIMD；不支持 SIMD 的机器（含部分虚拟机）会在打包最后一步失败。 |
| 9 | `apps/desktop/scripts/smoke-packaged-runtime.ts` | 用 `PRODUCT_NAME` 常量替代硬编码的 `DeepSeek Harness.exe` / `.app` | 打包后的冒烟测试按固定文件名启动应用；产品名改了之后它找不到 exe。 |

### 刻意未改动

- **`DSH_HOME_DIR_NAME` 保持 `.dsh`。** 早期版本曾改为 `.raindsh` 以彻底隔离数据，但那会让按
  默认目录取数的插件失效，已还原。隔离只由 Electron userData 承担。
- **Desktop profile 保持 `profiles/desktop`。** 曾改为 `rain-desktop` 以避开官方版的 profile 锁，
  但那既没解决 `ds-harness-remote` 的加载问题，又多出配置迁移成本。`apps/desktop/src/paths.ts`
  与 `scripts/smoke-runtime.ts` 因此与上游零 diff，升级时不会在这两处产生冲突。
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
| Desktop profile（插件集合、运行锁） | `~/.dsh/profiles/desktop` | `~/.dsh/profiles/desktop`（**共享**） |
| Electron userData | `%APPDATA%\@deepseek-ai\dsh-desktop` | `%APPDATA%\@rainroom\dsh-desktop`（独立） |
| 单实例锁 | 按 userData | 独立，可与官方版同时运行 |
| 程序显示名 | DeepSeek Harness | DeepSeek Harness（未改名） |
| 安装目录 | `%LOCALAPPDATA%\Programs\DeepSeek Harness` | 绿色版目录 `D:\E\AI_DEV_PROJECT\dsh-use-app` |
| URL 协议 | `dsh://` | `raindsh://` |
| 自动更新 | 有 | 无（手动重新打包） |

## 使用须知

- 两个客户端可以同时打开，互不退出。
- **不要在两个客户端里同时操作同一个会话。** 会话目录共享，双开会造成冲突写入。
- 插件集合共享：界面里安装的插件写进 `~/.dsh/profiles/desktop`，两个客户端都会加载；停用或删除
  同理，会同时影响官方版。磁盘上只有一份。
- 升级本 fork 只替换程序目录，`~/.dsh` 与 `%APPDATA%\@rainroom\dsh-desktop` 都不会被删除。
- 早前构建留下过 `~/.dsh/profiles/rain-desktop`，已不再使用；其中的模型配置如需保留，先复制到
  `~/.dsh/profiles/desktop/cordis.patch.yml`，再删除该目录。

### 本机 profile 私有配置（换机时重做）

下面两个文件属于机器配置，不在仓库里；profile 重建后需要重新放置，否则会表现成"配置丢了 / 私服插件装不上"。

| 文件 | 内容 |
|---|---|
| `~/.dsh/profiles/desktop/cordis.patch.yml` | 模型、供应商（如 `provider: sin`、`baseURL`）、界面开关 |
| `~/.dsh/profiles/desktop/.npmrc` | 私服作用域映射，例如 `@sinexcel:registry=…/sinexcel-deepseek-harness-local-npm/` |

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
- 快捷方式：`<桌面>\Rain Harness.lnk` → `dsh-use-app\DeepSeek Harness.exe`（图标名与产品名可以不同）

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
2. 应用使用 `~/.dsh/profiles/desktop`，与官方版是同一个 profile。
3. 官方客户端仍能同时打开，两者互不退出。
4. 快捷方式目标仍是 `D:\E\AI_DEV_PROJECT\dsh-use-app\DeepSeek Harness.exe`。

## 故障处理

| 现象 | 处理 |
|---|---|
| 打包末尾报 `client build environment differs` | 构建期间动过 git。保持工作树干净后重跑。 |
| 报 `desktop package: cannot read ... .env.windows` | 删掉损坏的文件，重跑脚本会自动重建。 |
| 桌面快捷方式打不开 | 部署目录被移动或删除。重跑 `install-green.ps1 -SkipBuild`。 |
| 两个客户端互相踢下线 | 检查是否 `extraMetadata.name` 丢失（改动 #1），它决定单实例锁。 |
| 想回滚到上一版 | 升级前把 `dsh-use-app` 复制一份；回滚时关闭应用、把副本还原回该路径。 |

## 同步上游后必须复查

1. `apps/desktop/src/paths.ts` 与 `scripts/smoke-runtime.ts` 仍与上游一致（不换 profile 名）。
2. `electron-builder-config.mjs` 的 `extraMetadata.name`、`productName`、`protocols`
   与 `main.ts` 的协议字符串仍然一致。
3. unsigned 的两处策略例外（改动 #4/#5）仍在，否则打包会重新要求 HTTPS 策略来源。
4. 产品名两处需同步：`electron-builder-config.mjs` 的 `productName` 与 `smoke-packaged-runtime.ts` 的
   `PRODUCT_NAME`，**都必须是 `'DeepSeek Harness'`**——运行时资产里硬编码了这个名字。
5. `DSH_HOME_DIR_NAME` 仍是 `.dsh`（本 fork 不修改它）。

## 已知限制

- **会话与凭据共享。** 这是换取插件兼容性的代价：两个客户端看到同一份会话列表。
- **同一会话不可双开。** 两端同时操作会造成冲突写入。
- **没有自动更新。** 应用不带更新源，升级只能靠重新打包。
- **`ds-harness-remote` 在本 fork 内未能加载，根因未定。** 已排除插件版本与文件差异、账号授权、
  profile 组成、`@sinexcel` 插件冲突、产品名硬编码；残留症状是 `/ds-harness-remote/status` 返回 404、
  `~/.dsh/logs/ds-harness-remote/host.log` 不更新。官方安装包 `D:\E\develop\ai\dsh`（同为
  `0.2.2-rc.3`）在同一个 profile 下能正常出二维码。需要该插件时先用官方版。
- **文档与快照仍写着 `~/.dsh` 的旧描述**，与现状一致，无需同步。

## 已验证

2026-11-17 实测：

- `tsx scripts/package-target.ts win-x64 --unsigned --dir` 完整跑通，退出码 0，含冒烟测试。
- 绿色版部署到 `D:\E\AI_DEV_PROJECT\dsh-use-app`，桌面快捷方式指向该目录。
- 早前版本（`.raindsh` + `profiles/desktop`）已验证过：数据写入自有 home、官方 `~/.dsh` 未被触碰。
- 绿色版与官方 `D:\E\develop\ai\dsh` 同时运行正常：`@rainroom/dsh-desktop` 与
  `@deepseek-ai/dsh-desktop` 的 userData 与单实例锁互不干扰。

## 待办

- [ ] 本轮构建后确认 `ds-harness-remote` 在共享 `profiles/desktop` 下能否出二维码；若仍不能，
      结论是该插件只在官方发行的安装包里工作，本 fork 不再追这条线。
- [ ] 确认 `~/.dsh/profiles/rain-desktop` 已无用途后删除；磁盘上另有 `~/.raindsh` 属更早实验残留。
- [ ] 如需数据完全隔离又要插件可用，只能逐插件适配其取数逻辑，无法在本 fork 内统一解决。
