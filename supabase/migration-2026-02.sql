-- ============================================================
-- 学生会报销记账系统 · 增量迁移（针对已上线数据库）
-- 在 Supabase 控制台 → SQL Editor 中整体粘贴执行
-- 内容：① profiles 加 position 职位列 ② 允许驳回后修改重新提交
-- ============================================================

-- 1. profiles 增加职位列
alter table public.profiles add column if not exists position text not null default '';

-- 2. 注册触发器：新用户档案带上 position
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

-- 3. 本人修改姓名/职位的安全函数
create or replace function public.update_my_profile(p_name text, p_position text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception '未登录'; end if;
  update public.profiles set name = p_name, position = p_position where id = auth.uid();
end;
$$;

-- 4. 允许提交人在 submitted 或 rejected 状态下修改自己的单；
--    只能保持 submitted 或被驳回后改回 submitted，不能改成 approved/paid/rejected
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