-- 创建测试执委账号（邮箱已确认，密码 test123456，学号 test01）
-- 用完后可在 Authentication → Users 里删除，或直接跑后面的清理语句
do $$
declare v_uid uuid := gen_random_uuid();
begin
  if not exists (select 1 from auth.users where email = 'test.member@mail.com') then
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, email_change, email_change_token_new, recovery_token
    ) values (
      '00000000-0000-0000-0000-000000000000',
      v_uid,
      'authenticated', 'authenticated',
      'test.member@mail.com',
      crypt('test123456', gen_salt('bf')),
      now(),
      '{"provider":"email","providers":["email"]}',
      '{"student_id":"test01","name":"测试执委"}',
      now(), now(),
      '', '', '', ''
    );
  end if;
end $$;

-- 将该测试账号设为 active（跳过管理员审核这一步，直接测提交/权限）
update public.profiles
set status = 'active'
where student_id = 'test01';

-- ===== 测试完成后，清理测试账号（可选） =====
-- delete from public.profiles where student_id = 'test01';
-- delete from auth.users where email = 'test.member@mail.com';