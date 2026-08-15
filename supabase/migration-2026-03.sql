-- migration-2026-03：管理员可审核/打款自己的报销单（财政仍不能）
-- 在 Supabase SQL Editor 执行

drop policy if exists "claims_update_approve" on public.claims;
create policy "claims_update_approve" on public.claims
  for update using (
    status = 'submitted'
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid()
        and p.role in ('finance','admin')
        and (p.role = 'admin' or p.id <> submitter_id)
    )
  )
  with check (
    status in ('approved','rejected')
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid()
        and p.role in ('finance','admin')
        and (p.role = 'admin' or p.id <> submitter_id)
    )
  );

drop policy if exists "claims_update_pay" on public.claims;
create policy "claims_update_pay" on public.claims
  for update using (
    status = 'approved'
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid()
        and p.role in ('finance','admin')
        and (p.role = 'admin' or p.id <> submitter_id)
    )
  )
  with check (
    status = 'paid'
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid()
        and p.role in ('finance','admin')
        and (p.role = 'admin' or p.id <> submitter_id)
    )
  );