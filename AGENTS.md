# 学生会报销记账系统 · Agent 宪法

## 项目定位

- 项目：学生会报销记账系统（`student-council`），给学生会执委报销、财政记账、全员看账本的一体化系统。
- 技术栈：Vue 3（`<script setup>`）+ Vite + JavaScript（无 TypeScript）+ Supabase（Auth/Postgres/RLS/Storage/RPC）+ Vercel（SPA 静态托管）。
- 平台：Windows，PowerShell 禁脚本，Node 命令一律用 `npm.cmd` / `npx.cmd`。

## 真源清单与优先级

事实冲突时按此顺序：

1. 当前源码、`supabase/schema.sql`（数据合同 + RLS + 触发器 + RPC）、迁移、运行证据、当前 git 状态。
2. 本宪法（`AGENTS.md`）及工具入口文件（`CLAUDE.md`、`GEMINI.md`、`.github/copilot-instructions.md`）。
3. `README.md`（部署与使用说明，须与实现一致）。
4. 历史提交、issue、用户确认。

本仓库**无** dev-docs/ADR/CONTRIBUTING/CI 等其它真源；`supabase/archive/` 内为一次性脚本，不是真源。

## Owner Map（唯一 owner）

- 报销单合同与审批状态机：`supabase/schema.sql` 的 `claims` 表 + 三条 update 策略（`claims_update_own` / `claims_update_approve` / `claims_update_pay`）。
- 权限与授权：**服务端 RLS 是最终边界**；`src/lib/auth.js` 的前端 computed（isAdmin/isFinance/isApprover）仅用于 UX，不得当作安全边界。
- 认证/登录限速/改密：`src/lib/auth.js` + `schema.sql` 的 RPC（`get_email_by_student_id`、`check_login_allowed`、`record_login_attempt`、`finish_password_change`、`update_my_profile`）。
- 展示语义（金额/科目/状态/角色名/配色）：`src/lib/utils.js`（跨视图唯一真源）。
- 页面/表单/审批 UI：`src/views/*.vue`（薄 adapter 层，只消费 utils 与后端状态，不私造业务真相）。
- 路由与页面守卫：`src/router/index.js`。
- 全局样式/移动端适配：`src/style.css` + `src/App.vue`。
- 发票存储权限：`schema.sql` 的 `receipts_read` / `receipts_insert` / `receipts_delete_admin`（私有桶）。
- 审计日志：`audit_logs` 表 + 触发器 `log_action` / `log_profile_change`；admin/finance 可读。
- 环境变量：本地 `.env`、Vercel 环境变量；`.env` 已从 git 移除，禁止入库。
- 部署面：`vercel.json`（SPA rewrites）+ Vercel CLI。

## 角色与权限模型（事实）

- `member`（执委）→ `finance`（财政）→ `admin`（管理员）；成员状态 `pending/active/banned`。
- 所有登录用户可读全部 `claims`（公开账本）、全部发票图、全部 `profiles`。
- 执委：只能提交自己的单；`submitted`/`rejected` 下可改，只能改回 `submitted`（不能自驳回/自审批/自打款）。
- 财政：审批/打款任意 submitted/approved 单，但**不能审批或打款自己的单**。
- 管理员：一切；**可审批/打款自己的单**；可改成员角色/状态、删除单与发票。
- 审计日志：admin、finance 可查看。

## 非目标与拒绝方向

- **禁止**重新引入 PDF 导出（已移除）或 xlsx 库（已被 exceljs 取代，commit `f5e44e7`）。
- **禁止**引入后端服务器/Node API：系统是纯 Supabase 无服务器形态。
- **禁止**公开桶、免登录访问、i18n、设计系统、移动 App、商业产品化。
- 不为了速度删除对账、权限、审计、发票、数据完整性字段。

## 必需工作流

```text
当前真源审计 -> 推理闸 -> 唯一 owner 与合同设计
  -> 测试/验证计划 -> 核心实现 -> 薄 adapter/UI 接线
  -> 针对性验收 -> 文档回写 -> git 边界复核
```

- 半路接管：先只读审计，禁止把已有项目当空项目重写。
- 编码前推理闸：问题是什么？owner 是谁？真源在哪？更简单的方案？最大回归风险与验证手段？
- 跨入口（页面/路由/导出/日志）复用的语义必须进 `utils.js` 或数据合同，不散落。

## 命令与验收

| 命令 | 用途 | 说明 |
|---|---|---|
| `npm.cmd run dev` | 本地开发 | http://localhost:5173 |
| `npm.cmd run build` | 生产构建 | 改动后**必须**通过 |
| `npm.cmd run preview` | 预览构建产物 | 可选 |
| `npx.cmd vercel --prod` | 生产部署 | 仅用户明确要求时执行 |

- 项目**无** lint / typecheck / unit / e2e 脚本，不得虚构或假装这些命令存在。
- 验收强度：任何代码改动 = `npm run build` 通过 + 浏览器实测（登录/关键路径/移动端）。DB/权限改动 = 迁移 SQL + RLS 实测 + 清理测试数据。生成物（`dist/`）不手改。
- warning、控制台报错、生成物漂移、文档与实际不符，按缺陷处理，不得带着声称完成。

## 实现规则

- 从合同、schema、`utils.js` 开始，不从 UI 倒推核心。
- 遵守 Vue 3 + Vite 既有目录与 `src/style.css` 既有风格；禁止另起并行体系。
- 错误处理：前端用 `alert()` 呈现明确错误文案；后端失败原因不得静默吞掉。
- 用户可见文案统一简体中文（`utils.js` 的 roleName/statusName/category 为准），禁止临时硬编码。
- 密钥/URL 只走环境变量；不得硬编码、不得写日志明文输出敏感信息。
- 修改代码、接口、权限、产品语义后必须同步 `README.md`。

## Git 规则

- 提交前确认 `git status --short`；**禁止 `git add .`**，只 stage 本任务相关文件。
- dirty worktree 中不得回滚、覆盖或吸入用户未授权的改动。
- 不手改 `package-lock.json` 之外的锁文件内容（安装依赖用 `npm.cmd install`）。
- 破坏性 git 命令须用户明确确认。

## 必须停止并询问

- 需求、代码、宪法、真源互相冲突。
- 需要删除旧 API/字段/路由/权限模型/迁移历史，或改动 RLS/schema 且影响线上数据。
- 需要同时支持互斥路线或无意义兼容。
- 上下文不足以判断 owner 边界，且猜测会造成不可逆或大范围影响。
- 停止时必须给出：冲突证据、推荐方向、需要用户确认的问题，不能只说"无法继续"。

## 交接规则

上下文过大、换窗口或交给另一 agent 时，必须产出可复制交接文本：当前目标与边界、git 状态与已改文件、已完成工作与验收结果、未闭合风险、下一步最安全命令与停止条件。