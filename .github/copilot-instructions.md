# GitHub Copilot 项目级指令（学生会报销记账系统）

主宪法真源是仓库根目录的 `AGENTS.md`。Copilot 无法直接解析 `@AGENTS.md` 导入，因此本文件是**摘要**；规则冲突、更新与完整细节一律以 `AGENTS.md` 为准，不要在本文件复制整份正文。

## 项目要点

- Vue 3（`<script setup>`）+ Vite + JavaScript + Supabase + Vercel；Windows 下用 `npm.cmd`。
- 角色：执委提交报销，财政审批/打款（不能批自己），管理员一切（可批自己的单）。
- 服务端 RLS 是权限最终边界；前端 `src/lib/auth.js` 的 isAdmin/isFinance 只用于 UX。
- 展示语义唯一真源是 `src/lib/utils.js`；页面（`src/views/`）只消费，不私造业务真相。
- 数据库合同与 RLS 在 `supabase/schema.sql`；改动必须走迁移并保持 README 同步。
- 无 lint/test 脚本；验收 = `npm.cmd run build` 通过 + 浏览器实测。

## 非目标

- 不加回 PDF 导出、xlsx 库；不引入后端服务器；不做公开桶/免登录/i18n。

完整规则见仓库根目录 `AGENTS.md`。