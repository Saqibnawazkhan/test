-- ============================================================================
-- Supabase / Postgres schema  —  National Tax Net
-- Run this in the Supabase SQL editor (or psql) to create all tables + views.
-- Then load the CSVs from data-generator/output_full + scoring/output/scores.csv
-- (via supabase/load_to_supabase.py or Supabase Table Editor CSV import).
-- ============================================================================

-- ---- core identity --------------------------------------------------------
create table if not exists persons (
  cnic                 text primary key,
  name                 text not null,
  name_ur              text,
  father_husband_name  text,
  gender               text,
  dob                  date,
  present_address      text,
  district             text,
  family_tree_id       text,
  mobile               text
);
create index if not exists idx_persons_district on persons(district);
create index if not exists idx_persons_family   on persons(family_tree_id);

-- ---- tax (FBR) ------------------------------------------------------------
create table if not exists tax_returns (
  cnic              text primary key references persons(cnic),
  ntn               text,
  declared_income   numeric,
  tax_paid          numeric,
  filer_status      text,
  atl_status        text,
  source_of_income  text,
  business_desc     text,
  tax_year          int
);

-- ---- assets ---------------------------------------------------------------
create table if not exists vehicles (
  reg_number         text primary key,
  owner_cnic         text,
  owner_company_ntn  text,
  make text, model text, variant text, engine_cc int, color text,
  reg_year int, value numeric
);
create index if not exists idx_veh_owner on vehicles(owner_cnic);

create table if not exists properties (
  fard_registry_no   text primary key,
  owner_cnic         text,
  owner_company_ntn  text,
  khewat_no text, khasra_no text, mauza text, district text,
  property_type text, area text, dc_valuation numeric, market_value numeric
);
create index if not exists idx_prop_owner  on properties(owner_cnic);
create index if not exists idx_prop_khewat on properties(khewat_no, khasra_no, mauza, district);

create table if not exists electricity (
  consumer_id text primary key, customer_cnic text, service_address text,
  disco text, units_consumed int, bill_amount numeric, billing_month text
);
create index if not exists idx_elec_cnic on electricity(customer_cnic);

create table if not exists gas (
  consumer_no text primary key, customer_cnic text, service_address text,
  company text, units_hm3 int, bill_amount numeric, billing_month text
);
create index if not exists idx_gas_cnic on gas(customer_cnic);

create table if not exists stocks (
  cdc_investor_account text primary key, holder_cnic text, uin text,
  scrip_symbol text, shares_held int, market_value numeric, dividend_income numeric
);
create index if not exists idx_stk_holder on stocks(holder_cnic);

create table if not exists travel (
  id bigint generated always as identity primary key,
  passport_no text, cnic text, full_name text, airline text,
  destination_country text, travel_date date, ticket_cost numeric
);
create index if not exists idx_travel_cnic on travel(cnic);

create table if not exists bank_accounts (
  iban text primary key, account_number text, customer_cnic text,
  bank_name text, account_type text, account_balance numeric, annual_turnover numeric, mobile text
);
create index if not exists idx_bank_cnic on bank_accounts(customer_cnic);

create table if not exists companies (
  company_ntn text primary key, company_name text, principal_business text,
  incorporation_date date, paid_up_capital numeric, status text
);

create table if not exists directorships (
  id bigint generated always as identity primary key,
  company_ntn text references companies(company_ntn),
  person_cnic text, role text, shareholding_percent numeric
);
create index if not exists idx_dir_person on directorships(person_cnic);

-- ---- the product: Deviation Score + audit trail ---------------------------
create table if not exists deviation_scores (
  cnic            text primary key references persons(cnic),
  deviation_score numeric,
  zone            text,                       -- Red / Yellow / Green
  declared        numeric, own_assets numeric, hidden_assets numeric, lifestyle numeric,
  asset_sig numeric, struct_sig numeric, life_sig numeric, nonfiler int,
  audit_trail     text
);
create index if not exists idx_scores_zone  on deviation_scores(zone);
create index if not exists idx_scores_score on deviation_scores(deviation_score desc);

-- ---- knowledge-graph edges (for the graph visualisation) ------------------
create table if not exists graph_edges (
  id bigint generated always as identity primary key,
  src text, src_type text, rel text, dst text, dst_type text
);
create index if not exists idx_edges_src on graph_edges(src);
create index if not exists idx_edges_dst on graph_edges(dst);

-- ---- convenience view used by the admin dashboard list --------------------
create or replace view person_overview as
select p.cnic, p.name, p.district, p.gender,
       t.declared_income, t.filer_status,
       s.deviation_score, s.zone, s.own_assets, s.hidden_assets, s.audit_trail
from persons p
left join tax_returns t       on t.cnic = p.cnic
left join deviation_scores s  on s.cnic = p.cnic;
