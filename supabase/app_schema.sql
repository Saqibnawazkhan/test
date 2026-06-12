-- ============================================================================
-- TaxNet AI — Supabase transactional + realtime layer
-- (reference/ML data stays in FastAPI; this is the live user-generated layer)
-- ============================================================================

-- ---- notifications (admin <-> citizen, announcements) ----------------------
create table if not exists notifications (
  id          bigint generated always as identity primary key,
  recipient   text not null,           -- 'admin'  OR a citizen CNIC
  audience    text not null default 'citizen',  -- 'admin' | 'citizen' | 'all'
  title       text not null,
  body        text,
  kind        text default 'info',     -- request | approval | rejection | announcement | payment
  ref_id      bigint,                  -- optional FK to a request/declaration
  read        boolean default false,
  created_at  timestamptz default now()
);
create index if not exists ix_notif_recipient on notifications(recipient, created_at desc);

-- ---- correction requests (citizen -> admin) --------------------------------
create table if not exists correction_requests (
  id            bigint generated always as identity primary key,
  cnic          text not null,
  name          text,
  field         text,
  current_value text,
  requested_value text,
  reason        text,
  proof_url     text,
  status        text default 'Pending',  -- Pending | Approved | Rejected
  created_at    timestamptz default now()
);
create index if not exists ix_cr_cnic on correction_requests(cnic);

-- ---- asset declarations (citizen declares -> FBR monitors) -----------------
create table if not exists asset_declarations (
  id          bigint generated always as identity primary key,
  cnic        text not null,
  name        text,
  asset_type  text,                    -- Vehicle | Property | Bank | Stock | Other
  description text,
  value       numeric,
  proof_url   text,
  status      text default 'Pending',
  created_at  timestamptz default now()
);
create index if not exists ix_ad_cnic on asset_declarations(cnic);

-- ---- issue reports (record disputes, with proof upload) --------------------
create table if not exists issue_reports (
  id          bigint generated always as identity primary key,
  cnic        text not null,
  name        text,
  category    text,
  description text,
  proof_url   text,
  status      text default 'Open',     -- Open | Resolved | Rejected
  created_at  timestamptz default now()
);

-- ---- tax payments ----------------------------------------------------------
create table if not exists payments (
  id          bigint generated always as identity primary key,
  cnic        text not null,
  name        text,
  amount      numeric,
  method      text,                    -- card | wallet
  reference   text,
  status      text default 'Initiated',  -- Initiated | Paid | Failed
  created_at  timestamptz default now()
);
create index if not exists ix_pay_cnic on payments(cnic);

-- ---- enable Realtime on all of them ----------------------------------------
do $$
declare t text;
begin
  foreach t in array array['notifications','correction_requests','asset_declarations','issue_reports','payments'] loop
    begin
      execute format('alter publication supabase_realtime add table %I', t);
    exception when duplicate_object then null; end;
  end loop;
end $$;

-- ---- permissive RLS for the demo (publishable key can read/write) ----------
do $$
declare t text;
begin
  foreach t in array array['notifications','correction_requests','asset_declarations','issue_reports','payments'] loop
    execute format('alter table %I enable row level security', t);
    execute format($f$create policy "demo_all" on %I for all using (true) with check (true)$f$, t);
  end loop;
exception when duplicate_object then null;
end $$;
