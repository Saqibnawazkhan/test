"""
Build the local SQLite serving DB from the CSVs + model outputs.
Mirrors supabase/schema.sql so the API can later swap SQLite -> Supabase via env.
Run:  python build_db.py   ->  backend/taxnet.db
"""
import csv, os, sqlite3, sys

HERE = os.path.dirname(__file__)
DATA = os.path.join(HERE, "..", "data-generator", "output_full")
SCOR = os.path.join(HERE, "..", "scoring", "output")
GNN = os.path.join(HERE, "..", "gnn", "output")
GRAPH = os.path.join(HERE, "..", "graph", "output")
DB = os.path.join(HERE, "taxnet.db")
rd = lambda d, f: csv.DictReader(open(os.path.join(d, f), encoding="utf-8-sig"))
num = lambda x: float(x) if str(x).strip() not in ("", "None") else None

if os.path.exists(DB):
    os.remove(DB)
con = sqlite3.connect(DB)
cur = con.cursor()
cur.executescript("""
create table persons(cnic text primary key, name text, name_ur text, father_husband_name text,
  gender text, dob text, present_address text, district text, family_tree_id text, mobile text);
create table tax_returns(cnic text primary key, ntn text, declared_income real, tax_paid real,
  filer_status text, atl_status text, source_of_income text, business_desc text, withholding real);
create table vehicles(reg_number text primary key, owner_cnic text, owner_company_ntn text, owner_name text,
  make text, model text, variant text, engine_cc int, color text, value real);
create table properties(fard text primary key, owner_cnic text, owner_company_ntn text, owner_name text,
  khewat text, khasra text, mauza text, district text, property_type text, area text, market_value real, dc_valuation real);
create table electricity(consumer_id text primary key, customer_cnic text, service_address text,
  disco text, units int, bill_amount real, billing_month text);
create table gas(consumer_no text primary key, customer_cnic text, company text, units int, bill_amount real);
create table stocks(cdc text primary key, holder_cnic text, scrip text, shares int, market_value real, dividend real);
create table travel(id integer primary key autoincrement, cnic text, passport text, airline text,
  destination text, ticket_cost real, travel_date text);
create table bank_accounts(iban text primary key, customer_cnic text, bank text, account_type text,
  balance real, turnover real);
create table companies(ntn text primary key, name text, business text, capital real, status text);
create table directorships(id integer primary key autoincrement, ntn text, person_cnic text, role text, pct real);
create table deviation_scores(cnic text primary key, deviation_score real, zone text, gnn_prob real,
  rule_score real, declared real, own_assets real, hidden_assets real, lifestyle real, audit_trail text);
create table graph_edges(src text, rel text, dst text);
""")

def load(table, cols, rows):
    ph = ",".join("?" * len(cols))
    cur.executemany(f"insert or ignore into {table}({','.join(cols)}) values({ph})", rows)
    print(f"  {table:18s} {cur.rowcount if cur.rowcount>0 else len(rows):>8,}")

print("Loading into SQLite…")
load("persons", ["cnic","name","name_ur","father_husband_name","gender","dob","present_address","district","family_tree_id","mobile"],
     [(r["cnic"],r["name_en"],r["name_ur"],r["father_husband_name"],r["gender"],r["dob"],r["present_address"],r["place_of_birth"],r["family_tree_id"],r["mobile"]) for r in rd(DATA,"01_nadra.csv")])
load("tax_returns", ["cnic","ntn","declared_income","tax_paid","filer_status","atl_status","source_of_income","business_desc","withholding"],
     [(r["cnic"],r["ntn"],num(r["declared_income"]),num(r["tax_paid"]),r["filer_status"],r["atl_status"],r["source_of_income"],r["business_job_description"],num(r["withholding_tax_collected"])) for r in rd(DATA,"02_fbr.csv")])
load("vehicles", ["reg_number","owner_cnic","owner_company_ntn","owner_name","make","model","variant","engine_cc","color","value"],
     [(r["reg_number"],r["owner_cnic"],r["owner_company_ntn"],r["owner_name"],r["make"],r["model"],r["variant"],int(r["engine_cc"]),r["color"],num(r["vehicle_value"])) for r in rd(DATA,"03_excise_vehicles.csv")])
load("properties", ["fard","owner_cnic","owner_company_ntn","owner_name","khewat","khasra","mauza","district","property_type","area","market_value","dc_valuation"],
     [(r["fard_registry_no"],r["owner_cnic"],r["owner_company_ntn"],r["owner_name"],r["khewat_no"],r["khasra_no"],r["mauza"],r["district"],r["property_type"],r["area"],num(r["market_value"]),num(r["dc_valuation"])) for r in rd(DATA,"06_land.csv")])
load("electricity", ["consumer_id","customer_cnic","service_address","disco","units","bill_amount","billing_month"],
     [(r["consumer_id"],r["customer_cnic"],r["service_address"],r["disco"],int(r["units_consumed"]),num(r["bill_amount"]),r["billing_month"]) for r in rd(DATA,"04_electricity.csv")])
load("gas", ["consumer_no","customer_cnic","company","units","bill_amount"],
     [(r["consumer_no"],r["customer_cnic"],r["company"],int(r["units_hm3"]),num(r["bill_amount"])) for r in rd(DATA,"05_gas.csv")])
load("stocks", ["cdc","holder_cnic","scrip","shares","market_value","dividend"],
     [(r["cdc_investor_account"],r["holder_cnic"],r["scrip_symbol"],int(r["shares_held"]),num(r["market_value"]),num(r["dividend_income"])) for r in rd(DATA,"07_stocks.csv")])
load("travel", ["cnic","passport","airline","destination","ticket_cost","travel_date"],
     [(r["cnic"],r["passport_no"],r["airline"],r["destination_country"],num(r["ticket_cost"]),r["travel_date"]) for r in rd(DATA,"08_travel.csv")])
load("bank_accounts", ["iban","customer_cnic","bank","account_type","balance","turnover"],
     [(r["iban"],r["customer_cnic"],r["bank_name"],r["account_type"],num(r["account_balance"]),num(r["annual_turnover"])) for r in rd(DATA,"09_banking.csv")])
load("companies", ["ntn","name","business","capital","status"],
     [(r["company_ntn"],r["company_name"],r["principal_business"],num(r["paid_up_capital"]),r["status"]) for r in rd(DATA,"10_secp_companies.csv")])
load("directorships", ["ntn","person_cnic","role","pct"],
     [(r["company_ntn"],r["person_cnic"],r["role"],num(r["shareholding_percent"])) for r in rd(DATA,"11_secp_directorships.csv")])

# merge fused (GNN) score + rule audit into deviation_scores
rule = {r["cnic"]: r for r in rd(SCOR, "scores.csv")}
ds = []
for r in rd(GNN, "fused_scores.csv"):
    c = r["cnic"]; ru = rule.get(c, {})
    ds.append((c, num(r["fused_score"]), r["zone"], num(r["gnn_prob"]), num(r["rule_score"]),
               num(ru.get("declared")), num(ru.get("own_assets")), num(ru.get("hidden_assets")),
               num(ru.get("lifestyle")), ru.get("audit_trail", "")))
load("deviation_scores", ["cnic","deviation_score","zone","gnn_prob","rule_score","declared","own_assets","hidden_assets","lifestyle","audit_trail"], ds)

load("graph_edges", ["src","rel","dst"], [(r["src"],r["type"],r["dst"]) for r in rd(GRAPH,"kg_edges.csv")])

print("Indexing…")
for stmt in ["create index ix_veh on vehicles(owner_cnic)","create index ix_prop on properties(owner_cnic)",
             "create index ix_elec on electricity(customer_cnic)","create index ix_gas on gas(customer_cnic)",
             "create index ix_stk on stocks(holder_cnic)","create index ix_trv on travel(cnic)",
             "create index ix_bank on bank_accounts(customer_cnic)","create index ix_dir on directorships(person_cnic)",
             "create index ix_zone on deviation_scores(zone)","create index ix_score on deviation_scores(deviation_score desc)",
             "create index ix_pdist on persons(district)","create index ix_esrc on graph_edges(src)"]:
    cur.execute(stmt)
con.commit()
print("\nDB ready:", DB, f"({os.path.getsize(DB)/1e6:.0f} MB)")
con.close()
