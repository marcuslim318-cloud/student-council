# 学生会报销记账系统

给学生会执委报销、财政记账、全员看账本的一体化系统。

- **技术栈**：Vue 3 + Vite + Supabase（免费云）
- **权限三角色**：执委（提交报销）· 财政（审批/打款）· 管理员（一切）
- **审批流**：提交 → 审核通过 → 已打款；任一审核人可批，但不能批自己
- **公开账本**：全员实时可见，支持 Excel / PDF 导出，含发票图片
- **安全**：学号登录、登录失败 5 次锁 15 分钟、邮箱找回密码、RLS 行级权限、审计日志

## 目录

```
student-council/
├── src/
│   ├── lib/          # supabase 客户端、认证、工具函数
│   ├── router/       # 路由 + 权限守卫
│   ├── views/        # 登录/注册/提交/审核/账本/管理/设置
│   └── App.vue
├── supabase/
│   └── schema.sql    # 数据库初始化（表 + RLS + 触发器 + 种子管理员）
└── .env.example      # Supabase 环境变量模板
```

## 部署步骤（约 15 分钟）

### 1. 创建 Supabase 项目

1. 打开 https://supabase.com/dashboard ，用 GitHub 登录，创建新项目（地区选 Singapore）
2. 创建完成后，进入 **SQL Editor**，把 `supabase/schema.sql` 全部内容粘贴进去并运行

> ⚠️ schema.sql 里的种子管理员默认邮箱是 `admin@whumsu.student`。
> **记得把它改成你自己的真实邮箱**，否则管理员无法用邮箱找回密码。

### 2. 配置环境变量

1. 项目设置 → **API**，复制 URL 和 anon public key
2. 复制 `.env.example` 为 `.env`，填入两个值

```
VITE_SUPABASE_URL=https://你的项目.supabase.co
VITE_SUPABASE_ANON_KEY=你的anon-public-key
```

### 3. 本地运行（可选）

```bash
npm install
npm run dev
```

浏览器打开 http://localhost:5173

### 4. 部署到 Vercel（手机可访问）

1. 把项目推到 GitHub（或用 Vercel CLI）
2. 在 https://vercel.com 导入仓库，Framework 选 **Vite**
3. 在项目设置里添加环境变量：
   - `VITE_SUPABASE_URL`
   - `VITE_SUPABASE_ANON_KEY`
4. 部署完成后所有人就能用网址访问了

### 5. 首次登录

- 管理员账号：学号 `admin`，密码 `whumsu2627`
- 登录后**强制修改密码**（务必修改，密码已在上文出现过）
- 在「管理」→ 成员管理中通过执委的注册申请

## 使用流程

1. 执委注册 → 管理员审核通过
2. 执委提交报销单（事由 + 金额 + 发票图）
3. 财政/管理员审核：通过或驳回（不能批自己的单）
4. 通过后财政/管理员打款
5. 全员在「公开账本」看到实时记录，可导出 Excel/PDF

## 安全说明

- 所有数据访问受 **Postgres RLS** 保护，前端无法越权
- 审批、打款、删除、角色变更都写 **审计日志**，管理员可在后台查看
- 登录限速通过数据库 RPC 实现（`check_login_allowed` / `record_login_attempt`）
- 发票图片存私有存储桶，仅登录用户可查看
- 首次登录强制改密由 `profiles.must_change_password` 标志驱动

## 常见问题

**注册后不能提交报销？** 需要管理员在「管理 → 成员管理」通过审核。

**管理员忘了密码？** 用邮箱走忘记密码流程（前提是改过种子邮箱）。

**登录被锁 15 分钟？** 连续输错 5 次触发，等待即可，无需操作。