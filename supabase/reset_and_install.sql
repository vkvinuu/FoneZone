-- DESTRUCTIVE RESET: this removes the old FoneZone application tables and their data.
-- Before running: export/download the current table data locally and keep a database backup.
-- Existing Supabase Auth accounts (auth.users) are retained; old shop/repair records are NOT retained by this reset.
-- Run only after you have confirmed your backup is usable.
drop trigger if exists on_auth_user_created on auth.users;
drop trigger if exists on_auth_user_created_fonezone on auth.users;
drop table if exists public.notifications, public.audit_events, public.signing_keys, public.certificates,
  public.repair_events, public.technician_reviews, public.quality_checks, public.warranties,
  public.manual_payments, public.repair_parts, public.part_transfers, public.stock_movements,
  public.inventory_items, public.suppliers, public.estimates, public.repair_tickets,
  public.devices, public.customers, public.branches, public.shop_memberships,
  public.shop_applications, public.inventory_events, public.inventory, public.repairs,
  public.shop_members, public.shops, public.profiles, public.audit_logs cascade;
drop sequence if exists public.shop_code_seq cascade;
-- FoneZone simplified Supabase schema (8 core tables; no blockchain).
-- BACK UP your existing database before replacing its schema. See docs/SUPABASE_MIGRATION.md.
create extension if not exists pgcrypto;
create sequence if not exists public.shop_code_seq start 1;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  email text not null default '',
  phone text not null default '',
  recovery_code_hash text,
  platform_role text not null default 'USER' check (platform_role in ('USER','PLATFORM_ADMIN')),
  created_at timestamptz not null default now()
);

create table if not exists public.shops (
  id uuid primary key default gen_random_uuid(),
  shop_code text not null unique,
  name text not null,
  owner_user_id uuid references public.profiles(id) on delete set null,
  status text not null default 'PENDING' check (status in ('PENDING','ACTIVE','REJECTED','SUSPENDED')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.shop_members (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check (role in ('owner','technician')),
  status text not null default 'PENDING' check (status in ('PENDING','APPROVED','REJECTED','DISABLED')),
  recovery_code_hash text,
  created_at timestamptz not null default now(),
  approved_at timestamptz,
  approved_by uuid references public.profiles(id) on delete set null,
  unique (shop_id,user_id)
);

create table if not exists public.repairs (
  id uuid primary key default gen_random_uuid(),
  tracking_id text not null unique default ('FZ-' || upper(substr(encode(gen_random_bytes(6),'hex'),1,10))),
  shop_id uuid not null references public.shops(id) on delete restrict,
  created_by uuid references public.profiles(id) on delete set null,
  customer_name text not null,
  customer_phone text not null,
  device_description text not null,
  issue_summary text not null,
  status text not null default 'RECEIVED' check (status in ('RECEIVED','DIAGNOSIS','WAITING_APPROVAL','IN_REPAIR','QUALITY_CHECK','READY','DELIVERED','CANCELLED')),
  certificate_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.inventory (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  part_name text not null,
  sku text,
  quantity integer not null default 0 check (quantity >= 0),
  low_stock_threshold integer not null default 2 check (low_stock_threshold >= 0),
  unit_cost numeric(12,2) not null default 0 check (unit_cost >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(shop_id,sku)
);

create table if not exists public.inventory_events (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  inventory_id uuid not null references public.inventory(id) on delete restrict,
  repair_id uuid references public.repairs(id) on delete set null,
  actor_id uuid references public.profiles(id) on delete set null,
  event_type text not null check (event_type in ('PART_USED','STOCK_ADDED','ADJUSTMENT','CORRECTION')),
  quantity_delta integer not null check (quantity_delta <> 0),
  reason text not null,
  approval_status text not null default 'APPROVED' check (approval_status in ('PENDING','APPROVED','REJECTED')),
  previous_hash text not null default 'GENESIS',
  event_hash text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.certificates (
  id uuid primary key default gen_random_uuid(),
  repair_id uuid not null unique references public.repairs(id) on delete restrict,
  shop_id uuid not null references public.shops(id) on delete cascade,
  certificate_hash text not null,
  signature text,
  public_summary jsonb not null default '{}'::jsonb,
  issued_at timestamptz not null default now()
);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid references public.shops(id) on delete set null,
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id text,
  details jsonb not null default '{}'::jsonb,
  previous_hash text not null default 'GENESIS',
  event_hash text not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_shops_owner on public.shops(owner_user_id);
create index if not exists idx_members_user_status on public.shop_members(user_id,status);
create index if not exists idx_members_shop_role_status on public.shop_members(shop_id,role,status);
create index if not exists idx_repairs_shop_created on public.repairs(shop_id,created_at desc);
create index if not exists idx_repairs_tracking on public.repairs(tracking_id);
create index if not exists idx_repairs_phone on public.repairs(customer_phone);
create index if not exists idx_inventory_shop on public.inventory(shop_id);
create index if not exists idx_inventory_events_shop_time on public.inventory_events(shop_id,created_at desc);
create index if not exists idx_audit_logs_shop_time on public.audit_logs(shop_id,created_at desc);

create or replace function public.is_platform_admin() returns boolean
language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.profiles p where p.id=auth.uid() and p.platform_role='PLATFORM_ADMIN') $$;

create or replace function public.is_approved_shop_member(target_shop uuid, allowed_roles text[] default array['owner','technician']) returns boolean
language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.shop_members m join public.shops s on s.id=m.shop_id where m.shop_id=target_shop and m.user_id=auth.uid() and m.status='APPROVED' and m.role=any(allowed_roles) and s.status='ACTIVE') $$;

create or replace function public.can_view_shop_profile(target_user uuid) returns boolean
language sql stable security definer set search_path=public
as $$ select public.is_platform_admin() or exists(select 1 from public.shop_members mine join public.shop_members theirs on theirs.shop_id=mine.shop_id where mine.user_id=auth.uid() and mine.role='owner' and mine.status='APPROVED' and theirs.user_id=target_user) $$;

create or replace function public.review_technician_membership(p_member_id uuid, p_approve boolean) returns boolean
language plpgsql security definer set search_path=public
as $$
declare v_shop uuid;
begin
  select shop_id into v_shop from public.shop_members where id=p_member_id and role='technician' and status='PENDING';
  if v_shop is null or not public.is_approved_shop_member(v_shop,array['owner']) then raise exception 'Not authorized to review this technician request'; end if;
  update public.shop_members set status=case when p_approve then 'APPROVED' else 'REJECTED' end, approved_at=case when p_approve then now() else null end, approved_by=auth.uid() where id=p_member_id and role='technician' and status='PENDING';
  return true;
end; $$;
revoke all on function public.review_technician_membership(uuid,boolean) from public, anon;
grant execute on function public.review_technician_membership(uuid,boolean) to authenticated;

create or replace function public.review_shop_application(p_shop_id uuid, p_approve boolean) returns boolean
language plpgsql security definer set search_path=public
as $$
begin
  if not public.is_platform_admin() then raise exception 'Platform Admin access required'; end if;
  update public.shops set status=case when p_approve then 'ACTIVE' else 'REJECTED' end, updated_at=now() where id=p_shop_id and status='PENDING';
  if not found then raise exception 'Pending shop application not found'; end if;
  update public.shop_members set status=case when p_approve then 'APPROVED' else 'REJECTED' end, approved_at=case when p_approve then now() else null end, approved_by=auth.uid() where shop_id=p_shop_id and role='owner';
  return true;
end; $$;
revoke all on function public.review_shop_application(uuid,boolean) from public, anon;
grant execute on function public.review_shop_application(uuid,boolean) to authenticated;

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path=public
as $$
declare v_role text; v_shop_id uuid; v_shop_code text; v_shop_name text;
begin
  insert into public.profiles(id,full_name,email,phone,platform_role)
  values(new.id, coalesce(new.raw_user_meta_data->>'full_name',''), coalesce(new.email,''), coalesce(new.raw_user_meta_data->>'phone',''), 'USER')
  on conflict (id) do nothing;
  v_role := coalesce(new.raw_user_meta_data->>'account_type','');
  if v_role='owner' and nullif(trim(new.raw_user_meta_data->>'shop_name'),'') is not null then
    v_shop_name := trim(new.raw_user_meta_data->>'shop_name');
    v_shop_code := 'FZ-' || lpad(nextval('public.shop_code_seq')::text,3,'0');
    insert into public.shops(shop_code,name,owner_user_id,status) values(v_shop_code,v_shop_name,new.id,'PENDING') returning id into v_shop_id;
    insert into public.shop_members(shop_id,user_id,role,status,recovery_code_hash) values(v_shop_id,new.id,'owner','PENDING',nullif(new.raw_user_meta_data->>'recovery_code_hash','')) on conflict do nothing;
  elsif v_role='technician' and nullif(trim(new.raw_user_meta_data->>'shop_code'),'') is not null then
    select id into v_shop_id from public.shops where shop_code=upper(trim(new.raw_user_meta_data->>'shop_code')) and status='ACTIVE' limit 1;
    if v_shop_id is not null then
      insert into public.shop_members(shop_id,user_id,role,status) values(v_shop_id,new.id,'technician','PENDING') on conflict do nothing;
    end if;
  end if;
  return new;
end; $$;

drop trigger if exists on_auth_user_created_fonezone on auth.users;
create trigger on_auth_user_created_fonezone after insert on auth.users for each row execute procedure public.handle_new_user();

-- Customer lookup intentionally requires BOTH the tracking ID and registered phone.
-- It returns only minimal progress information, not customer name, full phone, issue details, or prices.
create or replace function public.track_repair(p_tracking_id text, p_phone text)
returns table(tracking_id text, shop_name text, device_description text, status text, updated_at timestamptz)
language sql stable security definer set search_path=public
as $$
  select r.tracking_id, s.name, r.device_description, r.status, r.updated_at
  from public.repairs r join public.shops s on s.id=r.shop_id
  where upper(r.tracking_id)=upper(trim(p_tracking_id))
    and right(regexp_replace(r.customer_phone,'[^0-9]','','g'),10)=right(regexp_replace(coalesce(p_phone,''),'[^0-9]','','g'),10)
    and s.status='ACTIVE'
  limit 1;
$$;
grant execute on function public.track_repair(text,text) to anon, authenticated;
grant select on public.shops to anon, authenticated;
grant update on public.shops to authenticated;
grant select, insert, update on public.profiles, public.shop_members, public.repairs, public.inventory, public.inventory_events, public.certificates, public.audit_logs to authenticated;

create or replace function public.verify_certificate(p_certificate_id text)
returns table(certificate_id uuid, certificate_hash text, signature text, tracking_id text, shop_name text, device_description text, repair_status text, issued_at timestamptz)
language sql stable security definer set search_path=public
as $$
  select c.id, c.certificate_hash, c.signature, r.tracking_id, s.name, r.device_description, r.status, c.issued_at
  from public.certificates c join public.repairs r on r.id=c.repair_id join public.shops s on s.id=c.shop_id
  where c.id::text=p_certificate_id or c.certificate_hash=p_certificate_id
  limit 1;
$$;
grant execute on function public.verify_certificate(text) to anon, authenticated;

create or replace function public.record_inventory_event(p_inventory_id uuid, p_quantity_delta integer, p_event_type text, p_reason text, p_repair_id uuid default null) returns boolean
language plpgsql security definer set search_path=public
as $$
declare v_shop uuid; v_qty integer; v_role text; v_previous text; v_hash text; v_payload jsonb;
begin
  if p_quantity_delta=0 or nullif(trim(p_reason),'') is null then raise exception 'A non-zero quantity and reason are required'; end if;
  select shop_id,quantity into v_shop,v_qty from public.inventory where id=p_inventory_id for update;
  if v_shop is null then raise exception 'Inventory item not found'; end if;
  select role into v_role from public.shop_members where shop_id=v_shop and user_id=auth.uid() and status='APPROVED' limit 1;
  if v_role is null or not public.is_approved_shop_member(v_shop,array['owner','technician']) then raise exception 'Not authorized for this shop'; end if;
  if p_event_type='PART_USED' then
    if p_quantity_delta >= 0 then raise exception 'Part usage must reduce stock'; end if;
  elsif p_event_type in ('STOCK_ADDED','ADJUSTMENT','CORRECTION') then
    if v_role <> 'owner' then raise exception 'Only the shop owner can approve stock increases or corrections'; end if;
  else raise exception 'Unsupported inventory event type'; end if;
  if v_qty+p_quantity_delta < 0 then raise exception 'Insufficient stock'; end if;
  select event_hash into v_previous from public.inventory_events where shop_id=v_shop order by created_at desc limit 1;
  v_previous := coalesce(v_previous,'GENESIS');
  v_payload := jsonb_build_object('shop_id',v_shop,'inventory_id',p_inventory_id,'repair_id',p_repair_id,'actor_id',auth.uid(),'event_type',p_event_type,'quantity_delta',p_quantity_delta,'reason',trim(p_reason),'previous_hash',v_previous,'created_at',now());
  v_hash := encode(digest(convert_to(v_payload::text,'UTF8'),'sha256'),'hex');
  update public.inventory set quantity=v_qty+p_quantity_delta,updated_at=now() where id=p_inventory_id;
  insert into public.inventory_events(shop_id,inventory_id,repair_id,actor_id,event_type,quantity_delta,reason,approval_status,previous_hash,event_hash) values(v_shop,p_inventory_id,p_repair_id,auth.uid(),p_event_type,p_quantity_delta,trim(p_reason),'APPROVED',v_previous,v_hash);
  insert into public.audit_logs(shop_id,actor_id,action,entity_type,entity_id,details,previous_hash,event_hash) values(v_shop,auth.uid(),'INVENTORY_EVENT',p_event_type,p_inventory_id::text,v_payload,v_previous,v_hash);
  return true;
end; $$;
revoke all on function public.record_inventory_event(uuid,integer,text,text,uuid) from public, anon;
grant execute on function public.record_inventory_event(uuid,integer,text,text,uuid) to authenticated;

alter table public.profiles enable row level security;
alter table public.shops enable row level security;
alter table public.shop_members enable row level security;
alter table public.repairs enable row level security;
alter table public.inventory enable row level security;
alter table public.inventory_events enable row level security;
alter table public.certificates enable row level security;
alter table public.audit_logs enable row level security;

create policy profiles_read_self_or_admin_or_same_shop on public.profiles for select using (id=auth.uid() or public.can_view_shop_profile(id));
create policy shops_public_active_select on public.shops for select using (status='ACTIVE');
create policy shops_read_member_or_admin on public.shops for select using (public.is_platform_admin() or owner_user_id=auth.uid() or public.is_approved_shop_member(id));
create policy shops_admin_all on public.shops for all using (public.is_platform_admin()) with check (public.is_platform_admin());
create policy members_read_self_shop_owner_or_admin on public.shop_members for select using (user_id=auth.uid() or public.is_platform_admin() or public.is_approved_shop_member(shop_id,array['owner']));
create policy members_technician_request_insert on public.shop_members for insert with check (user_id=auth.uid() and role='technician' and status='PENDING');
create policy members_admin_all on public.shop_members for all using (public.is_platform_admin()) with check (public.is_platform_admin());
create policy repairs_read_shop on public.repairs for select using (public.is_platform_admin() or public.is_approved_shop_member(shop_id));
create policy repairs_insert_shop on public.repairs for insert with check (public.is_approved_shop_member(shop_id));
create policy repairs_update_shop on public.repairs for update using (public.is_approved_shop_member(shop_id)) with check (public.is_approved_shop_member(shop_id));
create policy inventory_read_shop on public.inventory for select using (public.is_platform_admin() or public.is_approved_shop_member(shop_id));
create policy inventory_insert_owner on public.inventory for insert with check (public.is_approved_shop_member(shop_id,array['owner']));
create policy inventory_update_owner on public.inventory for update using (public.is_approved_shop_member(shop_id,array['owner'])) with check (public.is_approved_shop_member(shop_id,array['owner']));
create policy inventory_events_read_shop on public.inventory_events for select using (public.is_platform_admin() or public.is_approved_shop_member(shop_id));
create policy inventory_events_insert_shop on public.inventory_events for insert with check (public.is_approved_shop_member(shop_id));
create policy certificates_read_shop on public.certificates for select using (public.is_platform_admin() or public.is_approved_shop_member(shop_id));
create policy certificates_insert_shop on public.certificates for insert with check (public.is_approved_shop_member(shop_id));
create policy audit_logs_read_shop on public.audit_logs for select using (public.is_platform_admin() or (shop_id is not null and public.is_approved_shop_member(shop_id)));
create policy audit_logs_insert_shop on public.audit_logs for insert with check (actor_id=auth.uid() and (shop_id is null or public.is_approved_shop_member(shop_id) or public.is_platform_admin()));

-- No UPDATE or DELETE policies are intentionally defined for inventory_events or audit_logs.
-- Set up the initial Platform Admin manually after registering your account:
-- update public.profiles set platform_role='PLATFORM_ADMIN' where id='<YOUR_AUTH_USER_UUID>';

-- Recreate profiles for existing Auth accounts. Existing accounts need a new shop application/membership.
insert into public.profiles(id,full_name,email,phone,platform_role)
select id, coalesce(raw_user_meta_data->>'full_name',''), coalesce(email,''), coalesce(raw_user_meta_data->>'phone',''), 'USER'
from auth.users
on conflict (id) do nothing;
