-- 清理所有测试数据（上线前执行）
-- 1) 删除测试报销单（含上面流程测试产生的）
delete from public.claims
where submitter_id in (
  select id from public.profiles where student_id = 'test01'
);

-- 2) 删除测试账号 test01（保留 admin）
delete from public.profiles where student_id = 'test01';
delete from auth.users where email = 'test.member@mail.com';

-- 3) 清理历史登录尝试记录（可选）
truncate table public.login_attempts;