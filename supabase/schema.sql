-- ============================================================
-- 学生会报销记账系统 · Supabase 数据库初始化
-- 在 Supabase 控制台 → SQL Editor 中整体粘贴执行
-- 角色：member(执委) / finance(财政) / admin(管理员)
-- 状态：pending(待审核) / active(已通过) / banned(已禁用)
-- ============================================================

-- ---------- 1. 扩展 ----------
create extension if not exists "pgcrypto";

-- ---------- 2. 表结构 ----------

-- 用户档案（与 auth.users 一一对应，由触发器自动创建）
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  student_id text not null unique,
  name text not null default '',
  position text not null default '',
  email text not null default '',
  role text not null default 'member' check (role in ('member','finance','admin')),
  status text not null default 'pending' check (status in ('pending','active','banned')),
  must_change_password boolean not null default false,
  created_at timestamptz not null default now()
);

-- 报销单
create table if not exists public.claims (
  id uuid primary key default gen_random_uuid(),
  submitter_id uuid not null references public.profiles(id) on delete restrict,
  title text not null,
  category text not null default '其他',
  amount numeric(10,2) not null check (amount > 0),
  invoice_no text default '',
  reason text default '',
  receipt_path text default '',
  status text not null default 'submitted' check (status in ('submitted','approved','paid','rejected')),
  approved_by uuid references public.profiles(id),
  approved_at timestamptz,
  paid_by uuid references public.profiles(id),
  paid_at timestamptz,
  reject_reason text default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 审计日志（管理员/财政的删改、审批动作，由触发器写入）
-- actor_id 可为 NULL（种子/系统操作无登录会话时为 NULL）
create table if not exists public.audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid,
  action text not null,
  target_type text not null default 'claim',
  target_id text not null default '',
  detail jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- 登录限速记录（学号维度，连续错5次锁15分钟）
create table if not exists public.login_attempts (
  id bigint generated always as identity primary key,
  identifier text not null,
  success boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists idx_login_attempts_identifier on public.login_attempts (identifier, created_at desc);

-- ---------- 3. 触发器辅助函数 ----------

-- 新用户注册 → 自动创建档案（status=pending 待管理员审核）
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, student_id, name, position, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'student_id', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data->>'name', ''),
    coalesce(new.raw_user_meta_data->>'position', ''),
    new.email
  );
  return new;
end;
$$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 记录操作日志（谁改了谁、改成什么）
create or replace function public.log_action()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_actor uuid := auth.uid();
  v_claim_before jsonb;
  v_claim_after jsonb;
begin
  -- 删除事件
  if (tg_op = 'DELETE') then
    insert into public.audit_logs (actor_id, action, target_type, target_id, detail)
    values (v_actor, 'delete', 'claim', old.id::text,
            jsonb_build_object('title', old.title, 'amount', old.amount, 'reason', '删除报销单'));
    return old;
  end if;

  -- 更新事件（仅记录状态变更）
  if (tg_op = 'UPDATE') then
    if (new.status is distinct from old.status) then
      v_claim_before := jsonb_build_object('status', old.status);
      v_claim_after := jsonb_build_object('status', new.status, 'reject_reason', new.reject_reason);
      insert into public.audit_logs (actor_id, action, target_type, target_id, detail)
      values (v_actor, 'status_change', 'claim', new.id::text,
              jsonb_build_object('before', v_claim_before, 'after', v_claim_after));
    end if;
  end if;

  return new;
end;
$$;
drop trigger if exists trg_claims_log on public.claims;
create trigger trg_claims_log
  after update or delete on public.claims
  for each row execute function public.log_action();

-- 记录成员角色/状态变更日志
create or replace function public.log_profile_change()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (new.role is distinct from old.role or new.status is distinct from old.status) then
    insert into public.audit_logs (actor_id, action, target_type, target_id, detail)
    values (auth.uid(), 'member_change', 'member', new.id::text,
            jsonb_build_object('before', jsonb_build_object('role', old.role, 'status', old.status),
                               'after', jsonb_build_object('role', new.role, 'status', new.status)));
  end if;
  return new;
end;
$$;
drop trigger if exists trg_profiles_log on public.profiles;
create trigger trg_profiles_log
  after update on public.profiles
  for each row execute function public.log_profile_change();

-- updated_at 自动刷新
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
drop trigger if exists trg_claims_touch on public.claims;
create trigger trg_claims_touch
  before update on public.claims
  for each row execute function public.touch_updated_at();

-- ---------- 4. RLS 策略 ----------

alter table public.profiles enable row level security;
alter table public.claims enable row level security;
alter table public.audit_logs enable row level security;
alter table public.login_attempts enable row level security;

-- profiles：登录用户可读全员（账本需要显示提交人姓名）
drop policy if exists "profiles_select" on public.profiles;
create policy "profiles_select" on public.profiles
  for select using (auth.role() = 'authenticated');

-- profiles：仅管理员可修改（角色/状态/禁用等），杜绝自提权
drop policy if exists "profiles_update_self" on public.profiles;
drop policy if exists "profiles_update_admin" on public.profiles;
create policy "profiles_update_admin" on public.profiles
  for update using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));

-- 本人修改自己的姓名/职位（安全函数，只允许改 name/position 字段）
create or replace function public.update_my_profile(p_name text, p_position text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception '未登录'; end if;
  update public.profiles set name = p_name, position = p_position where id = auth.uid();
end;
$$;

-- 修改密码后清除强制改密标记
create or replace function public.finish_password_change()
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception '未登录'; end if;
  update public.profiles set must_change_password = false where id = auth.uid();
end;
$$;

-- claims：登录用户可读全部（公开账本）
drop policy if exists "claims_select" on public.claims;
create policy "claims_select" on public.claims
  for select using (auth.role() = 'authenticated');

-- claims：仅 active 状态的执委本人可提交
drop policy if exists "claims_insert" on public.claims;
create policy "claims_insert" on public.claims
  for insert with check (
    auth.uid() = submitter_id
    and exists (select 1 from public.profiles p where p.id = auth.uid() and p.status = 'active')
  );

-- claims：提交人在 submitted/rejected 状态下可修改内容；
-- 只能保持 submitted，或被驳回后改回 submitted（重新提交），不能改成 approved/paid/rejected
drop policy if exists "claims_update_own" on public.claims;
create policy "claims_update_own" on public.claims
  for update using (
    auth.uid() = submitter_id
    and status in ('submitted','rejected')
  )
  with check (
    auth.uid() = submitter_id
    and status = 'submitted'
  );

-- claims：财政/管理员审批（通过/驳回），不能批自己的单
drop policy if exists "claims_update_approve" on public.claims;
create policy "claims_update_approve" on public.claims
  for update using (
    auth.uid() <> submitter_id
    and status = 'submitted'
    and exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('finance','admin'))
  )
  with check (
    auth.uid() <> submitter_id
    and status in ('approved','rejected')
    and exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('finance','admin'))
  );

-- claims：财政/管理员打款（approved → paid），不能打自己的
drop policy if exists "claims_update_pay" on public.claims;
create policy "claims_update_pay" on public.claims
  for update using (
    auth.uid() <> submitter_id
    and status = 'approved'
    and exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('finance','admin'))
  )
  with check (
    auth.uid() <> submitter_id
    and status = 'paid'
    and exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('finance','admin'))
  );

-- claims：管理员可删除任何单
drop policy if exists "claims_delete_admin" on public.claims;
create policy "claims_delete_admin" on public.claims
  for delete using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));

-- audit_logs：管理员、财政可查看
drop policy if exists "audit_logs_select" on public.audit_logs;
create policy "audit_logs_select" on public.audit_logs
  for select using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','finance')));

-- login_attempts：仅通过安全函数访问
drop policy if exists "login_attempts_no_access" on public.login_attempts;
create policy "login_attempts_no_access" on public.login_attempts
  for all using (false);

-- ---------- 5. 登录限速安全函数 ----------

-- 登录前按学号查邮箱（未登录态无法查 profiles 表，用安全函数绕过 RLS）
create or replace function public.get_email_by_student_id(p_student_id text)
returns text language sql security definer set search_path = public as $$
  select email from public.profiles where student_id = p_student_id limit 1;
$$;

-- 查询是否允许登录：最近15分钟内连续失败>=5次则锁定
create or replace function public.check_login_allowed(p_identifier text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_count int;
  v_first timestamptz;
  v_lock_until timestamptz;
begin
  select count(*) into v_count
  from public.login_attempts
  where identifier = p_identifier and success = false
    and created_at > now() - interval '15 minutes';

  if v_count >= 5 then
    select min(created_at) into v_first
    from public.login_attempts
    where identifier = p_identifier and success = false
      and created_at > now() - interval '15 minutes';
    v_lock_until := v_first + interval '15 minutes';
    return jsonb_build_object(
      'allowed', false,
      'locked_for', round(extract(epoch from (v_lock_until - now()))),
      'message', '尝试次数过多，已锁定。请在 ' || to_char(v_lock_until, 'HH24:MI:SS') || ' 后重试'
    );
  end if;

  return jsonb_build_object('allowed', true);
end;
$$;

-- 记录登录结果（成功/失败）
create or replace function public.record_login_attempt(p_identifier text, p_success boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  -- 防滥用：同一学号每 5 秒最多记 1 次，阻止刷失败记录造成他人锁号
  if exists (
    select 1 from public.login_attempts
    where identifier = p_identifier and created_at > now() - interval '5 seconds'
  ) then
    return;
  end if;
  insert into public.login_attempts (identifier, success) values (p_identifier, p_success);
  -- 清理 24 小时前的记录
  delete from public.login_attempts where created_at < now() - interval '1 day';
end;
$$;

-- ---------- 6. 种子管理员账号 ----------
-- 学号：admin ｜ 密码：whumsu2627（首次登录强制改密）
-- ⚠️ 把 admin@whumsu.student 换成你自己的真实邮箱，否则找回密码收不到邮件
do $$
begin
  if not exists (select 1 from auth.users where email = 'admin@whumsu.student') then
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, email_change, email_change_token_new, recovery_token
    ) values (
      '00000000-0000-0000-0000-000000000000',
      gen_random_uuid(),
      'authenticated', 'authenticated',
      'whumsu@gmail.com',
      crypt('whumsu2627', gen_salt('bf')),
      now(),
      '{"provider":"email","providers":["email"]}',
      '{"student_id":"admin","name":"系统管理员"}',
      now(), now(),
      '', '', '', ''
    );
  end if;
end $$;

-- 将管理员档案设为 admin / active / 强制改密
update public.profiles
set role = 'admin', status = 'active', must_change_password = true
where student_id = 'admin';

-- ---------- 7. 发票存储桶 ----------
-- 私有桶 receipts：发票图片
insert into storage.buckets (id, name, public)
values ('receipts', 'receipts', false)
on conflict (id) do nothing;

-- 登录用户可读所有发票图（账本全员可见）
drop policy if exists "receipts_read" on storage.objects;
create policy "receipts_read" on storage.objects
  for select using (bucket_id = 'receipts' and auth.role() = 'authenticated');

-- active 成员可上传自己的发票（路径含本人 id）
drop policy if exists "receipts_insert" on storage.objects;
create policy "receipts_insert" on storage.objects
  for insert with check (
    bucket_id = 'receipts'
    and (storage.foldername(name))[1] = auth.uid()::text
    and exists (select 1 from public.profiles p where p.id = auth.uid() and p.status = 'active')
  );

-- 管理员可删除发票
drop policy if exists "receipts_delete_admin" on storage.objects;
create policy "receipts_delete_admin" on storage.objects
  for delete using (
    bucket_id = 'receipts'
    and exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
  );