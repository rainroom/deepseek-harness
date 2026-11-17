# Rain Harness fork 修改记录

本目录记录 `rainroom/deepseek-harness` 在 `rain_source_sin_use` 分支上，相对上游
`deepseek-ai/deepseek-harness` 的全部改动，供打包和后续同步上游时逐项核对。

## 目的

产出一个可以长期使用、独立安装的客户端：数据目录、Electron 用户数据、单实例锁、
安装身份、URL 协议都与官方 DeepSeek Harness 不同。因此两个客户端可以同时安装、
同时运行、互不覆盖数据。

## 改动清单

改动刻意保持最小，只触碰决定身份和路径的位置，避免每次同步上游都大面积冲突。

| # | 文件 | 改动 | 原因 |
|---|---|---|---|
| 1 | `packages/util/home-paths/src/index.ts` | `DSH_HOME_DIR_NAME` 由 `'.dsh'` 改为 `'.raindsh'` | 这是所有 Harness 数据（sessions、profiles、credentials、storages、workspaces）的唯一默认根。改这一行即整体迁移到 `~/.raindsh`。`$DSH_HOME` 环境变量仍然优先，显式配置仍然最高优先。 |
| 2 | `packages/experimental/liveshare/src/host/share-host.ts` | `defaultOwnerStateFile()` 的兜底目录由 `'.dsh'` 改为 `'.raindsh'` | 该文件自己硬编码了 home 兜底，不跟随改动 #1。注释已标明它镜像 `DSH_HOME_DIR_NAME`。 |
| 3 | `apps/desktop/scripts/electron-builder-config.mjs` | `extraMetadata.name` 设为 `'@rainroom/dsh-desktop'` | Electron 从打包后的 manifest 取 `app.name`，据此决定 userData 目录、单实例锁名。上一行是让两个客户端不共用 `%APPDATA%\@deepseek-ai\dsh-desktop` 的关键。 |
| 4 | 同上 | `productName` 改为 `'Rain Harness'` | electron-builder 用它决定安装目录（Windows 为 `%LOCALAPPDATA%\Programs\<productName>`）和卸载项显示名。同名会被当作升级覆盖。 |
| 5 | 同上 | `protocols` 改为 `{ name: 'Rain Harness', schemes: ['raindsh'] }` | 两个客户端不再抢同一个 `dsh://` 协议处理器。 |
| 6 | `apps/desktop/src/main.ts` | `setAsDefaultProtocolClient('raindsh')`、`raindsh://open` | 跟随改动 #5，注册与解析保持一致。 |
| 7 | `apps/desktop/tests/welcome-startup.spec.ts` | 两处 `dsh://open` 断言改为 `raindsh://open` | 跟随改动 #6。 |
| 8 | `packages/util/home-paths/tests/home-paths.spec.ts` | 默认目录断言改为 `.raindsh` / `~/.raindsh` | 跟随改动 #1。`expandHomePath` 用例仍用任意字面量，与默认值无关，保持不变。 |

### 刻意未改动

- **产物文件名保持 `deepseek-harness-` 前缀，未改成 `rain-harness-`。** 打包流程用它定位产物：
  `desktop-build-version-discovery.ts` 的正则、`package-target.ts`、`package-macos.ts`、
  `desktop-upload-plan.ts`、`retain-desktop-ci.ts` 都硬编码了该前缀。改名必须同时改这几处，
  冲突面会明显变大，而不影响产品行为——安装后的显示名、安装目录、userData 由 #3/#4 决定。
- **`apps/desktop/package.json` 的 `name` 保持 `@deepseek-ai/dsh-desktop`。** 改它会连带打断根
  `package.json` 里的 `pnpm --filter @deepseek-ai/dsh-desktop` 脚本和仓库的包命名约束。
  身份隔离改由改动 #3 的 `extraMetadata.name` 在打包产物中完成，工作区包名保持不变。
- **`~/.agents` 不变。** 它由 `DSH_AGENTS_HOME` 控制，存放用户级 `AGENTS.md` 与 `skills/`，
  官方版与本 fork 共享。要隔离就在启动前设置 `DSH_AGENTS_HOME`。
- **文档里的 `~/.dsh` 文案未同步。** 见"已知限制"。

## 效果对照

| 项 | 官方版 | 本 fork |
|---|---|---|
| Harness 数据根 | `~/.dsh` | `~/.raindsh` |
| Electron userData | `%APPDATA%\@deepseek-ai\dsh-desktop` | `%APPDATA%\@rainroom\dsh-desktop` |
| 单实例锁 | 与官方版互斥 | 独立，可与官方版同时运行 |
| 安装目录 | `%LOCALAPPDATA%\Programs\DeepSeek Harness` | `%LOCALAPPDATA%\Programs\Rain Harness` |
| 安装器标识 | 由 `DSH_DESKTOP_APP_ID` 决定 | `fork/windows.env.template` 中的 `com.rainroom.harness` |
| URL 协议 | `dsh://` | `raindsh://` |
| 共享 agent 配置 | `~/.agents` | `~/.agents`（未隔离） |

## 打包（Windows）

上游强制要求一份 `apps/desktop/.env.windows`（被 git 忽略），其中包含安装器标识和
强制更新策略来源。本 fork 用模板生成它：

```powershell
cd D:\E\AI_DEV_PROJECT\dsh-use
Copy-Item fork\windows.env.template apps\desktop\.env.windows
# 按文件内注释填好 DOWNLOAD_TEST_ORIGIN 等占位项
pnpm install
pnpm run package:desktop:win:x64:unsigned
```

产物在 `apps/desktop/.desktop-build/` 下的输出目录，文件名形如
`rain-harness-<version>-win-x64.exe`。

`--unsigned` 变体不需要签名证书，但它仍然会校验强制更新来源（
`DSH_DESKTOP_MANDATORY_UPDATE_TEST_ORIGIN` / `_PROD_ORIGIN`，必须是合法的 HTTPS
origin），缺失会直接报错退出。见"已知限制"。

### 安装后的验证

1. `%APPDATA%` 下应出现 `@rainroom\dsh-desktop`，官方的 `@deepseek-ai\dsh-desktop` 不受影响。
2. 帮助菜单的"关于"显示 Rain Harness，版本号正常。
3. 两个客户端同时启动：都能保持打开，互不退出（单实例锁已分离）。
4. 新建一个会话，确认写入 `~/.raindsh/sessions`，`~/.dsh/sessions` 的修改时间不变。
5. 设置项（快捷键、语言、主题）互不影响。

## 同步上游

```powershell
git fetch upstream master
git merge upstream/master        # 或 git rebase upstream/master
```

冲突几乎只会出现在上表 9 个文件里。逐个按下表核对即可；若上游改动了同一处语义，
优先保留上游结构、把 fork 的值重新填进去，并更新本表。

同步后必须重新确认的两件事：

1. `DSH_HOME_DIR_NAME` 仍是 `.raindsh`（上游若重命名或移动该常量要跟随）。
2. `electron-builder-config.mjs` 的 `extraMetadata.name` / `productName` / `protocols`
   与 `main.ts` 的协议字符串仍然一致。

## 已知限制

- **文档与快照仍写着 `~/.dsh`。** 仓库内约 69 处 `~/.dsh` 出现在文档与测试快照里，
  本 fork 未同步。因此 `pnpm run doc-sync`、部分快照测试会失败。这是有意的取舍：
  同步这些文案会显著扩大每次上游合并的冲突面，而它们不影响产品行为。
- **`pnpm run test:coverage` 不会全绿。** 同上的文档/快照差异。
- **自动更新未改指向。** 产物带的是上游的更新通道配置。若要让本 fork 自行更新，需要
  自己的发布源；共享上游更新源会导致本 fork 被官方版本覆盖。见改动记录后续待办。
- **未验证实际安装。** 本次只完成源码改动与记录，尚未执行 `pnpm install` 与打包，
  上表"安装后的验证"步骤待首次打包后逐条确认。

## 待办

- [ ] 首次 `pnpm install` + 打包，跑完"安装后的验证"五项。
- [ ] 决定自动更新策略：禁用、改指向，或保留（接受被官方版本替换）。
- [ ] 若需要 workspace/skills 也隔离，在启动脚本里设置 `DSH_AGENTS_HOME`。
