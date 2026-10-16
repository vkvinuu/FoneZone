-- FoneZone production data-model foundation for Supabase PostgreSQL.
-- Run in a new Supabase project. Review with a database/security engineer before production.
create extension if not exists pgcrypto;

do $$ begin create type public.platform_role as enum ('CUSTOMER','PLATFORM_ADMIN'); exception when duplicate_object then null; end $$;
do $$ begin create type public.shop_role as enum ('SHOP_ADMIN','SHOP_MANAGER','SENIOR_TECH','TECHNICIAN'); exception when duplicate_object then null; end $$;
do $$ begin create type public.shop_status as enum ('PENDING','ACTIVE','SUSPENDED','REJECTED'); exception when duplicate_object then null; end $$;
do $$ begin create type public.repair_status as enum ('BOOKED','RECEIVED','DIAGNOSIS','ESTIMATE_PENDING','ESTIMATE_APPROVED','ESTIMATE_REJECTED','WAITING_FOR_PARTS','IN_REPAIR','QUALITY_CHECK','READY','DELIVERED','CANCELLED'); exception when duplicate_object then null; end $$;
do $$ begin create type public.transfer_status as enum ('REQUESTED','DISPATCHED','RECEIVED','DISCREPANCY','CANCELLED'); exception when duplicate_object then null; end $$;
do $$ begin create type public.payment_method as enum ('CASH','UPI','CARD','OTHER'); exception when duplicate_object then null; end $$;
do $$ begin create type public.payment_status as enum ('PENDING','CONFIRMED','VOIDED','REFUNDED','PARTIALLY_REFUNDED'); exception when duplicate_object then null; end $$;

create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null default '', email text not null,
 phone text, platform_role public.platform_role not null default 'CUSTOMER',
 email_verified_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.shops (
 id uuid primary key default gen_random_uuid(), name text not null, legal_name text,
 owner_user_id uuid not null references public.profiles(id), status public.shop_status not null default 'PENDING',
 gstin text, state_code text, currency text not null default 'INR', timezone text not null default 'Asia/Kolkata',
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.shop_applications (
 id uuid primary key default gen_random_uuid(), applicant_user_id uuid not null references public.profiles(id),
 shop_name text not null, legal_name text, contact_email text not null, contact_phone text not null,
 address text, status public.shop_status not null default 'PENDING', reviewed_by uuid references public.profiles(id),
 reviewed_at timestamptz, review_note text, created_at timestamptz not null default now()
);
create table if not exists public.shop_memberships (
 id uuid primary key default gen_random_uuid(), shop_id uuid not null references public.shops(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade, role public.shop_role not null,
 active boolean not null default true, branch_scope uuid[] not null default '{}',
 can_edit_prices boolean not null default false, can_adjust_stock boolean not null default false,
 can_approve_refunds boolean not null default false, created_by uuid references public.profiles(id),
 created_at timestamptz not null default now(), unique(shop_id,user_id)
);
create table if not exists public.branches (
 id uuid primary key default gen_random_uuid(), shop_id uuid not null references public.shops(id) on delete cascade,
 name text not null, address text not null default '', phone text, opening_hours jsonb not null default '{}'::jsonb,
 active boolean not null default true, created_at timestamptz not null default now(), unique(shop_id,name)
);
create table if not exists public.customers (
 id uuid primary key default gen_random_uuid(), shop_id uuid not null references public.shops(id) on delete cascade,
 auth_user_id uuid references public.profiles(id), full_name text not null, email text, phone text not null,
 address text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index if not exists customers_shop_phone_idx on public.customers(shop_id,phone);
create table if not exists public.devices (
 id uuid primary key default gen_random_uuid(), shop_id uuid not null references public.shops(id) on delete cascade,
 customer_id uuid not null references public.customers(id), brand text not null, series text not null default '', model text not null,
 imei text, serial_number text, color text, storage text, condition_notes text, intake_consent_at timestamptz,
 intake_photo_paths text[] not null default '{}', created_at timestamptz not null default now(),
 check (imei is null or imei ~ '^[0-9]{15}$')
);
create table if not exists public.repair_tickets (
 id uuid primary key default gen_random_uuid(), ticket_number text not null unique,
 shop_id uuid not null references public.shops(id) on delete cascade, branch_id uuid not null references public.branches(id),
 customer_id uuid not null references public.customers(id), device_id uuid not null references public.devices(id),
 assigned_technician uuid references public.profiles(id), status public.repair_status not null default 'BOOKED',
 priority text not null default 'NORMAL' check(priority in ('LOW','NORMAL','HIGH','URGENT')),
 issue_description text not null, diagnosis text, repair_notes text, internal_notes text,
 parts_subtotal numeric(12,2) not null default 0 check(parts_subtotal>=0), labour_subtotal numeric(12,2) not null default 0 check(labour_subtotal>=0),
 tax_rate numeric(5,2) not null default 0 check(tax_rate>=0 and tax_rate<=100), tax_treatment text not null default 'EXCLUSIVE' check(tax_treatment in ('EXCLUSIVE','INCLUSIVE','EXEMPT','UNCONFIGURED')),
 estimate_version integer not null default 0, estimate_approved_at timestamptz, estimate_approved_by uuid references public.profiles(id),
 qc_passed_at timestamptz, delivered_at timestamptz, expected_completion_at timestamptz,
 warranty_labour_days integer not null default 0 check(warranty_labour_days>=0), warranty_parts_days integer not null default 0 check(warranty_parts_days>=0),
 created_by uuid references public.profiles(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index if not exists repairs_shop_status_idx on public.repair_tickets(shop_id,status,created_at desc);
create index if not exists repairs_branch_idx on public.repair_tickets(shop_id,branch_id,status);
create table if not exists public.estimates (
 id uuid primary key default gen_random_uuid(), shop_id uuid not null references public.shops(id) on delete cascade,
 repair_id uuid not null references public.repair_tickets(id) on delete cascade, version integer not null,
 parts_subtotal numeric(12,2) not null default 0 check(parts_subtotal>=0), labour_subtotal numeric(12,2) not null default 0 check(labour_subtotal>=0),
 tax_rate numeric(5,2) not null default 0 check(tax_rate>=0 and tax_rate<=100), tax_amount numeric(12,2) not null default 0,
 total_amount numeric(12,2) not null check(total_amount>=0), status text not null default 'PENDING' check(status in ('PENDING','APPROVED','REJECTED','SUPERSEDED')),
 sent_at timestamptz not null default now(), customer_response_at timestamptz, responded_by uuid references public.profiles(id),
 created_by uuid references public.profiles(id), unique(repair_id,version)
);
create table if not exists public.suppliers (
 id uuid primary key default gen_random_uuid(), shop_id uuid not null references public.shops(id) on delete cascade,
 name text not null, contact_name text, email text, phone text, notes text, created_at timestamptz not null default now()
);
create table if not exists public.inventory_items (
 id uuid primary key default gen_random_uuid(), shop_id uuid not null references public.shops(id) on delete cascade,
 branch_id uuid not null references public.branches(id), sku text not null, name text not null,
 brand text not null default '', series text not null default '', compatible_models text[] not null default '{}',
 quality text not null default 'AFTERMARKET' check(quality in ('ORIGINAL','AFTERMARKET','REFURBISHED','UNKNOWN')),
 supplier_id uuid references public.suppliers(id), supplier_name_snapshot text,
 authenticity_status text not null default 'UNVERIFIED' check(authenticity_status in ('VERIFIED','INVOICE_RECORDED','UNVERIFIED','SUSPECTED_COUNTERFEIT','REFURBISHED_TESTED')),
 authenticity_notes text, batch_number text, cost_price numeric(12,2) not null default 0 check(cost_price>=0),
 selling_price numeric(12,2) not null default 0 check(selling_price>=0), quantity integer not null default 0 check(quantity>=0),
 minimum_stock integer not null default 0 check(minimum_stock>=0), active boolean not null default true,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(shop_id,branch_id,sku)
);
create table if not exists public.stock_movements (
 id uuid primary key default gen_random_uuid(), shop_id uuid not null references public.shops(id) on delete cascade,
 branch_id uuid not null references public.branches(id), inventory_item_id uuid not null references public.inventory_items(id),
 movement_type text not null check(movement_type in ('PURCHASE','REPAIR_USAGE','TRANSFER_OUT','TRANSFER_IN','ADJUSTMENT','RETURN')),
 quantity_delta integer not null check(quantity_delta<>0), unit_cost numeric(12,2), reason text not null,
 related_entity_type text, related_entity_id uuid, actor_id uuid references public.profiles(id), created_at timestamptz not null default now()
);
create table if not exists public.part_transfers (
 id uuid primary key default gen_random_uuid(), shop_id uuid not null references public.shops(id) on delete cascade,
 part_id uuid not null references public.inventory_items(id), from_branch_id uuid not null references public.branches(id), to_branch_id uuid not null references public.branches(id),
 quantity integer not null check(quantity>0), status public.transfer_status not null default 'REQUESTED', note text,
 requested_by uuid references public.profiles(id), dispatched_by uuid references public.profiles(id), received_by uuid references public.profiles(id),
 discrepancy_note text, requested_at timestamptz not null default now(), dispatched_at timestamptz, received_at timestamptz,
 check(from_branch_id<>to_branch_id)
);
create table if not exists public.repair_parts (
 id uuid primary key default gen_random_uuid(), shop_id uuid not null references public.shops(id) on delete cascade,
 repair_id uuid not null references public.repair_tickets(id), inventory_item_id uuid not null references public.inventory_items(id),
 quantity integer not null check(quantity>0), unit_price numeric(12,2) not null check(unit_price>=0), cost_snapshot numeric(12,2) not null default 0,
 status text not null default 'PLANNED' check(status in ('PLANNED','RESERVED','INSTALLED','RETURNED','CANCELLED')),
 recorded_by uuid references public.profiles(id), created_at timestamptz not null default now()
);
create table if not exists public.manual_payments (
 id uuid primary key default gen_random_uuid(), shop_id uuid not null references public.shops(id) on delete cascade,
 repair_id uuid not null references public.repair_tickets(id), amount numeric(12,2) not null check(amount>0),
 method public.payment_method not null, status public.payment_status not null default 'CONFIRMED',
 reference_note text, confirmed_by uuid not null references public.profiles(id), confirmed_at timestamptz not null default now(),
 voided_by uuid references public.profiles(id), void_reason text, refunded_amount numeric(12,2) not null default 0 check(refunded_amount>=0)
);
create table if not exists public.warranties (
 id uuid primary key default gen_random_uuid(), shop_id uuid not null references public.shops(id) on delete cascade,
 repair_id uuid not null references public.repair_tickets(id), certificate_id uuid, scope text not null check(scope in ('LABOUR','PART','REPAIR')),
 inventory_item_id uuid references public.inventory_items(id), terms text not null default '', starts_at timestamptz not null, expires_at timestamptz not null,
 status text not null default 'ACTIVE' check(status in ('ACTIVE','EXPIRED','VOID','CLAIMED')), created_at timestamptz not null default now(), check(expires_at>=starts_at)
);
create table if not exists public.quality_checks (
 id uuid primary key default gen_random_uuid(), shop_id uuid not null references public.shops(id) on delete cascade,
 repair_id uuid not null references public.repair_tickets(id), checklist jsonb not null default '{}'::jsonb, passed boolean not null default false,
 notes text, performed_by uuid not null references public.profiles(id), performed_at timestamptz not null default now()
);
create table if not exists public.technician_reviews (
 id uuid primary key default gen_random_uuid(), shop_id uuid not null references public.shops(id) on delete cascade,
 repair_id uuid not null unique references public.repair_tickets(id), customer_user_id uuid not null references public.profiles(id),
 technician_user_id uuid references public.profiles(id), rating integer not null check(rating between 1 and 5), comment text,
 created_at timestamptz not null default now()
);
create table if not exists public.repair_events (
 id uuid primary key default gen_random_uuid(), shop_id uuid not null references public.shops(id) on delete cascade,
 repair_id uuid not null references public.repair_tickets(id), event_type text not null, previous_status public.repair_status,
 new_status public.repair_status, payload jsonb not null default '{}'::jsonb, actor_id uuid references public.profiles(id),
 occurred_at timestamptz not null default now(), previous_hash text, event_hash text, signature text, signing_key_id uuid
);
create index if not exists repair_events_repair_idx on public.repair_events(repair_id,occurred_at);
create table if not exists public.certificates (
 id uuid primary key default gen_random_uuid(), public_id text not null unique default encode(gen_random_bytes(12),'hex'),
 shop_id uuid not null references public.shops(id) on delete cascade, repair_id uuid not null unique references public.repair_tickets(id),
 schema_version integer not null default 1, payload jsonb not null, payload_hash text not null,
 signature text, signing_key_id uuid, issued_at timestamptz not null default now(), revoked_at timestamptz, revoke_reason text
);
create table if not exists public.signing_keys (
 id uuid primary key default gen_random_uuid(), shop_id uuid references public.shops(id) on delete cascade,
 algorithm text not null default 'Ed25519', public_key text not null, key_fingerprint text not null unique,
 status text not null default 'ACTIVE' check(status in ('ACTIVE','ROTATED','REVOKED')), valid_from timestamptz not null default now(), valid_until timestamptz, revoked_at timestamptz,
 created_at timestamptz not null default now()
);
alter table public.repair_events drop constraint if exists repair_events_signing_key_id_fkey;
alter table public.repair_events add constraint repair_events_signing_key_id_fkey foreign key(signing_key_id) references public.signing_keys(id);
alter table public.certificates drop constraint if exists certificates_signing_key_id_fkey;
alter table public.certificates add constraint certificates_signing_key_id_fkey foreign key(signing_key_id) references public.signing_keys(id);
create table if not exists public.audit_events (
 id uuid primary key default gen_random_uuid(), shop_id uuid references public.shops(id) on delete set null,
 actor_id uuid references public.profiles(id), actor_role text not null, action text not null, entity_type text not null, entity_id text not null,
 details jsonb not null default '{}'::jsonb, previous_hash text, event_hash text not null, occurred_at timestamptz not null default now()
);
create table if not exists public.notifications (
 id uuid primary key default gen_random_uuid(), shop_id uuid references public.shops(id) on delete cascade,
 recipient_user_id uuid references public.profiles(id), recipient_email text, template_key text not null,
 payload jsonb not null default '{}'::jsonb, status text not null default 'QUEUED' check(status in ('QUEUED','SENT','FAILED','CANCELLED')),
 attempts integer not null default 0, last_error text, created_at timestamptz not null default now(), sent_at timestamptz
);

-- Minimal profile bootstrap. Role is always CUSTOMER by default; users cannot self-assign platform roles.
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin
 insert into public.profiles(id,email,full_name,phone,platform_role) values(new.id,coalesce(new.email,''),coalesce(new.raw_user_meta_data->>'full_name',''),new.raw_user_meta_data->>'phone','CUSTOMER') on conflict(id) do nothing;
 if coalesce(new.raw_user_meta_data->>'account_type','customer')='shop' and nullif(trim(new.raw_user_meta_data->>'shop_name'),'') is not null then
   insert into public.shop_applications(applicant_user_id,shop_name,contact_email,contact_phone,status) values(new.id,trim(new.raw_user_meta_data->>'shop_name'),coalesce(new.email,''),coalesce(new.raw_user_meta_data->>'phone',''), 'PENDING') on conflict do nothing;
 end if;
 return new; end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

create or replace function public.is_platform_admin() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.profiles p where p.id=auth.uid() and p.platform_role='PLATFORM_ADMIN') $$;
create or replace function public.is_shop_member(target_shop uuid) returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.shop_memberships m join public.shops s on s.id=m.shop_id where m.shop_id=target_shop and m.user_id=auth.uid() and m.active and s.status='ACTIVE') $$;
create or replace function public.has_shop_role(target_shop uuid, allowed public.shop_role[]) returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.shop_memberships m join public.shops s on s.id=m.shop_id where m.shop_id=target_shop and m.user_id=auth.uid() and m.active and m.role=any(allowed) and s.status='ACTIVE') $$;
create or replace function public.has_branch_scope(target_shop uuid,target_branch uuid) returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.shop_memberships m where m.shop_id=target_shop and m.user_id=auth.uid() and m.active and (cardinality(m.branch_scope)=0 or target_branch=any(m.branch_scope))) $$;

-- RLS is enabled on every tenant-bearing table. Policies deliberately default to deny.
do $$ declare t text; begin foreach t in array array['profiles','shops','shop_applications','shop_memberships','branches','customers','devices','repair_tickets','estimates','suppliers','inventory_items','stock_movements','part_transfers','repair_parts','manual_payments','warranties','quality_checks','technician_reviews','repair_events','certificates','signing_keys','audit_events','notifications'] loop execute format('alter table public.%I enable row level security',t); end loop; end $$;

create policy profiles_select_self_or_admin on public.profiles for select using (id=auth.uid() or public.is_platform_admin());
create policy profiles_update_self_limited on public.profiles for update using(id=auth.uid()) with check(id=auth.uid() and platform_role='CUSTOMER');
create policy shops_select_member_or_platform on public.shops for select using(public.is_platform_admin() or public.is_shop_member(id) or owner_user_id=auth.uid());
create policy shops_platform_manage on public.shops for all using(public.is_platform_admin()) with check(public.is_platform_admin());
create policy applications_insert_self on public.shop_applications for insert with check(applicant_user_id=auth.uid() and status='PENDING');
create policy applications_select_owner_or_platform on public.shop_applications for select using(applicant_user_id=auth.uid() or public.is_platform_admin());
create policy applications_review_platform on public.shop_applications for update using(public.is_platform_admin()) with check(public.is_platform_admin());
create policy memberships_select_member_or_platform on public.shop_memberships for select using(user_id=auth.uid() or public.is_shop_member(shop_id) or public.is_platform_admin());
create policy memberships_manage_shop_admin on public.shop_memberships for all using(public.has_shop_role(shop_id,array['SHOP_ADMIN']::public.shop_role[]) or public.is_platform_admin()) with check(public.has_shop_role(shop_id,array['SHOP_ADMIN']::public.shop_role[]) or public.is_platform_admin());
create policy branches_select_member on public.branches for select using(public.is_platform_admin() or public.is_shop_member(shop_id) or exists(select 1 from public.shops s where s.id=shop_id and s.owner_user_id=auth.uid()));
create policy branches_manage_admin on public.branches for all using(public.has_shop_role(shop_id,array['SHOP_ADMIN','SHOP_MANAGER']::public.shop_role[]) or public.is_platform_admin()) with check(public.has_shop_role(shop_id,array['SHOP_ADMIN','SHOP_MANAGER']::public.shop_role[]) or public.is_platform_admin());

-- Tenant policies. Customer access is scoped through their linked auth user; staff access through shop membership.
create policy customers_select_scoped on public.customers for select using(public.is_platform_admin() or public.is_shop_member(shop_id) or auth_user_id=auth.uid());
create policy customers_insert_scoped on public.customers for insert with check(public.is_platform_admin() or public.is_shop_member(shop_id));
create policy customers_update_scoped on public.customers for update using(public.has_shop_role(shop_id,array['SHOP_ADMIN','SHOP_MANAGER','SENIOR_TECH']::public.shop_role[]) or auth_user_id=auth.uid() or public.is_platform_admin()) with check(public.has_shop_role(shop_id,array['SHOP_ADMIN','SHOP_MANAGER','SENIOR_TECH']::public.shop_role[]) or auth_user_id=auth.uid() or public.is_platform_admin());
create policy devices_select_scoped on public.devices for select using(public.is_platform_admin() or public.is_shop_member(shop_id) or exists(select 1 from public.customers c where c.id=customer_id and c.auth_user_id=auth.uid()));
create policy devices_write_staff on public.devices for all using(public.is_shop_member(shop_id) or public.is_platform_admin()) with check(public.is_shop_member(shop_id) or public.is_platform_admin());
create policy repairs_select_scoped on public.repair_tickets for select using(public.is_platform_admin() or (public.is_shop_member(shop_id) and public.has_branch_scope(shop_id,branch_id)) or exists(select 1 from public.customers c where c.id=customer_id and c.auth_user_id=auth.uid()));
create policy repairs_insert_staff_or_customer on public.repair_tickets for insert with check(public.is_platform_admin() or public.is_shop_member(shop_id));
create policy repairs_update_staff on public.repair_tickets for update using(public.has_shop_role(shop_id,array['SHOP_ADMIN','SHOP_MANAGER','SENIOR_TECH','TECHNICIAN']::public.shop_role[]) or public.is_platform_admin()) with check(public.has_shop_role(shop_id,array['SHOP_ADMIN','SHOP_MANAGER','SENIOR_TECH','TECHNICIAN']::public.shop_role[]) or public.is_platform_admin());
create policy estimates_select_scoped on public.estimates for select using(public.is_platform_admin() or public.is_shop_member(shop_id) or exists(select 1 from public.repair_tickets r join public.customers c on c.id=r.customer_id where r.id=repair_id and c.auth_user_id=auth.uid()));
create policy estimates_staff_insert on public.estimates for insert with check(public.has_shop_role(shop_id,array['SHOP_ADMIN','SHOP_MANAGER','SENIOR_TECH']::public.shop_role[]) or public.is_platform_admin());
create policy estimates_customer_response on public.estimates for update using(public.is_shop_member(shop_id) or public.is_platform_admin() or exists(select 1 from public.repair_tickets r join public.customers c on c.id=r.customer_id where r.id=repair_id and c.auth_user_id=auth.uid())) with check(public.is_shop_member(shop_id) or public.is_platform_admin() or exists(select 1 from public.repair_tickets r join public.customers c on c.id=r.customer_id where r.id=repair_id and c.auth_user_id=auth.uid()));
create policy suppliers_staff on public.suppliers for all using(public.is_shop_member(shop_id) or public.is_platform_admin()) with check(public.has_shop_role(shop_id,array['SHOP_ADMIN','SHOP_MANAGER','SENIOR_TECH']::public.shop_role[]) or public.is_platform_admin());
create policy inventory_select_scoped on public.inventory_items for select using(public.is_platform_admin() or (public.is_shop_member(shop_id) and public.has_branch_scope(shop_id,branch_id)));
create policy inventory_insert_admin on public.inventory_items for insert with check(public.has_shop_role(shop_id,array['SHOP_ADMIN','SHOP_MANAGER']::public.shop_role[]) or public.is_platform_admin());
create policy inventory_update_authorized on public.inventory_items for update using(public.has_shop_role(shop_id,array['SHOP_ADMIN','SHOP_MANAGER']::public.shop_role[]) or exists(select 1 from public.shop_memberships m where m.shop_id=inventory_items.shop_id and m.user_id=auth.uid() and m.active and m.role='SENIOR_TECH' and m.can_edit_prices) or public.is_platform_admin()) with check(public.has_shop_role(shop_id,array['SHOP_ADMIN','SHOP_MANAGER']::public.shop_role[]) or exists(select 1 from public.shop_memberships m where m.shop_id=inventory_items.shop_id and m.user_id=auth.uid() and m.active and m.role='SENIOR_TECH' and m.can_edit_prices) or public.is_platform_admin());
create policy stock_movements_select on public.stock_movements for select using(public.is_platform_admin() or public.is_shop_member(shop_id));
create policy stock_movements_insert_authorized on public.stock_movements for insert with check(public.has_shop_role(shop_id,array['SHOP_ADMIN','SHOP_MANAGER','SENIOR_TECH']::public.shop_role[]) or public.is_platform_admin());
create policy transfers_select on public.part_transfers for select using(public.is_platform_admin() or public.is_shop_member(shop_id));
create policy transfers_insert on public.part_transfers for insert with check(public.has_shop_role(shop_id,array['SHOP_ADMIN','SHOP_MANAGER','SENIOR_TECH']::public.shop_role[]) or public.is_platform_admin());
create policy transfers_update on public.part_transfers for update using(public.has_shop_role(shop_id,array['SHOP_ADMIN','SHOP_MANAGER','SENIOR_TECH']::public.shop_role[]) or public.is_platform_admin()) with check(public.has_shop_role(shop_id,array['SHOP_ADMIN','SHOP_MANAGER','SENIOR_TECH']::public.shop_role[]) or public.is_platform_admin());
create policy repair_parts_select on public.repair_parts for select using(public.is_platform_admin() or public.is_shop_member(shop_id));
create policy repair_parts_staff_write on public.repair_parts for all using(public.has_shop_role(shop_id,array['SHOP_ADMIN','SHOP_MANAGER','SENIOR_TECH','TECHNICIAN']::public.shop_role[]) or public.is_platform_admin()) with check(public.has_shop_role(shop_id,array['SHOP_ADMIN','SHOP_MANAGER','SENIOR_TECH','TECHNICIAN']::public.shop_role[]) or public.is_platform_admin());
create policy payments_select on public.manual_payments for select using(public.is_platform_admin() or public.is_shop_member(shop_id) or exists(select 1 from public.repair_tickets r join public.customers c on c.id=r.customer_id where r.id=repair_id and c.auth_user_id=auth.uid()));
create policy payments_insert_authorized on public.manual_payments for insert with check(public.has_shop_role(shop_id,array['SHOP_ADMIN','SHOP_MANAGER']::public.shop_role[]) or public.is_platform_admin());
create policy payments_update_authorized on public.manual_payments for update using(public.has_shop_role(shop_id,array['SHOP_ADMIN']::public.shop_role[]) or public.is_platform_admin()) with check(public.has_shop_role(shop_id,array['SHOP_ADMIN']::public.shop_role[]) or public.is_platform_admin());
create policy warranties_select_scoped on public.warranties for select using(public.is_platform_admin() or public.is_shop_member(shop_id) or exists(select 1 from public.repair_tickets r join public.customers c on c.id=r.customer_id where r.id=repair_id and c.auth_user_id=auth.uid()));
create policy warranties_staff_write on public.warranties for all using(public.has_shop_role(shop_id,array['SHOP_ADMIN','SHOP_MANAGER']::public.shop_role[]) or public.is_platform_admin()) with check(public.has_shop_role(shop_id,array['SHOP_ADMIN','SHOP_MANAGER']::public.shop_role[]) or public.is_platform_admin());
create policy qc_select on public.quality_checks for select using(public.is_platform_admin() or public.is_shop_member(shop_id) or exists(select 1 from public.repair_tickets r join public.customers c on c.id=r.customer_id where r.id=repair_id and c.auth_user_id=auth.uid()));
create policy qc_write on public.quality_checks for all using(public.has_shop_role(shop_id,array['SHOP_ADMIN','SHOP_MANAGER','SENIOR_TECH','TECHNICIAN']::public.shop_role[]) or public.is_platform_admin()) with check(public.has_shop_role(shop_id,array['SHOP_ADMIN','SHOP_MANAGER','SENIOR_TECH','TECHNICIAN']::public.shop_role[]) or public.is_platform_admin());
create policy reviews_select on public.technician_reviews for select using(public.is_platform_admin() or public.is_shop_member(shop_id) or customer_user_id=auth.uid());
create policy reviews_insert_verified_customer on public.technician_reviews for insert with check(customer_user_id=auth.uid() and exists(select 1 from public.repair_tickets r join public.customers c on c.id=r.customer_id where r.id=technician_reviews.repair_id and r.shop_id=technician_reviews.shop_id and r.status='DELIVERED' and c.auth_user_id=auth.uid()));
create policy repair_events_select on public.repair_events for select using(public.is_platform_admin() or public.is_shop_member(shop_id) or exists(select 1 from public.repair_tickets r join public.customers c on c.id=r.customer_id where r.id=repair_id and c.auth_user_id=auth.uid()));
create policy repair_events_insert_staff on public.repair_events for insert with check(public.is_shop_member(shop_id) or public.is_platform_admin());
create policy certificates_public_minimal_lookup on public.certificates for select using(revoked_at is null); -- expose only through a restricted RPC/view in production; do not grant raw table access to anon.
create policy certificates_staff_manage on public.certificates for all using(public.is_shop_member(shop_id) or public.is_platform_admin()) with check(public.is_shop_member(shop_id) or public.is_platform_admin());
create policy signing_keys_select on public.signing_keys for select using(shop_id is null or public.is_platform_admin() or public.is_shop_member(shop_id));
create policy signing_keys_manage_admin on public.signing_keys for all using(public.has_shop_role(shop_id,array['SHOP_ADMIN']::public.shop_role[]) or public.is_platform_admin()) with check(public.has_shop_role(shop_id,array['SHOP_ADMIN']::public.shop_role[]) or public.is_platform_admin());
create policy audit_events_select on public.audit_events for select using(public.is_platform_admin() or (shop_id is not null and public.is_shop_member(shop_id)));
create policy audit_events_insert on public.audit_events for insert with check(public.is_platform_admin() or (shop_id is not null and public.is_shop_member(shop_id)));
create policy notifications_select on public.notifications for select using(recipient_user_id=auth.uid() or public.is_platform_admin() or (shop_id is not null and public.is_shop_member(shop_id)));
create policy notifications_insert_staff on public.notifications for insert with check(public.is_platform_admin() or (shop_id is not null and public.is_shop_member(shop_id)));

-- Critical production operations (inventory deductions, transfer dispatch/receipt, estimate transitions, refund approvals,
-- certificate signing and audit hashing) should be implemented as SECURITY DEFINER RPCs with explicit role/branch checks,
-- transaction locks, immutable event insertion, and server-side Ed25519 keys. Do not perform these as multi-step client writes.
