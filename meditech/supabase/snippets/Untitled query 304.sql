select b.display_id, b.status, b.rejection_reason, a.state
from public.branches b
join public.staff_members s on s.branch_id = b.id and s.role = 'owner'
join public.accounts a on a.id = s.account_id
where b.display_id = 'PHM-000003';