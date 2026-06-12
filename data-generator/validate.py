"""
Dataset integrity validator — runs structural & referential checks on every silo.
Usage:  python validate.py
Exit:   non-zero if any HARD check fails (duplicates, malformed keys, negatives…).
"""
import csv, re, sys, os

try:
    sys.stdout.reconfigure(encoding="utf-8")   # allow ↔ ≥ → etc. on Windows console
except Exception:
    pass

D = os.path.join(os.path.dirname(__file__), "output_full")
load = lambda f: list(csv.DictReader(open(os.path.join(D, f), encoding="utf-8-sig")))

CNIC = re.compile(r"^\d{5}-\d{7}-\d$")   # 13 digits: XXXXX-XXXXXXX-X
IBAN = re.compile(r"^PK\d{2}[A-Z]{4}\d{16}$")
PASSPORT = re.compile(r"^[A-Z]{2}\d{7}$")
NTN = re.compile(r"^\d{7}-\d$")
MOBILE = re.compile(r"^03\d{2}-\d{7}$")

fails, warns = [], []
def hard(cond, msg):
    print(("  OK  " if cond else " FAIL ") + msg)
    if not cond: fails.append(msg)
def soft(cond, msg):
    print(("  OK  " if cond else " WARN ") + msg)
    if not cond: warns.append(msg)
def uniq(rows, col):
    vals = [r[col] for r in rows if r[col].strip()]
    return len(vals) - len(set(vals))

nadra = load("01_nadra.csv")
ncnic = set(r["cnic"] for r in nadra)

print("\n### 01 NADRA")
hard(uniq(nadra, "cnic") == 0, f"CNIC unique ({len(ncnic)} ids)")
hard(all(CNIC.match(r["cnic"]) for r in nadra), "CNIC format")
hard(all(MOBILE.match(r["mobile"]) for r in nadra), "mobile format 03XX-XXXXXXX")
hard(all((int(r["cnic"][-1]) % 2 == 1) == (r["gender"] == "M") for r in nadra), "gender↔last-digit")
hard(all(r["date_of_expiry"] > r["date_of_issue"] for r in nadra), "expiry>issue")
soft(all(len(r["name_en"].split()) >= 2 for r in nadra), "names ≥2 tokens")

print("\n### 02 FBR")
fbr = load("02_fbr.csv")
hard(uniq(fbr, "cnic") == 0, "one return per CNIC")
hard(all(CNIC.match(r["cnic"]) for r in fbr), "CNIC format")
hard(all(r["ntn"] == r["cnic"] for r in fbr), "NTN==CNIC (individuals)")
hard(all(int(r["declared_income"]) >= 0 and int(r["tax_paid"]) >= 0 for r in fbr), "no negatives")
hard(all(int(r["tax_paid"]) <= int(r["declared_income"]) for r in fbr), "tax≤income")
hard(all((r["filer_status"] == "Filer") == (r["atl_status"] == "Active") for r in fbr), "filer↔ATL consistent")
hard(all(r["cnic"] in ncnic for r in fbr), "100% resolve to NADRA")

print("\n### 03 EXCISE VEHICLES")
veh = load("03_excise_vehicles.csv")
hard(uniq(veh, "reg_number") == 0, "reg_number unique")
hard(uniq(veh, "chassis_number") == 0, "chassis unique")
hard(all(len(r["chassis_number"]) == 17 for r in veh), "chassis len 17")
hard(all(int(r["engine_cc"]) > 0 and int(r["vehicle_value"]) > 0 for r in veh), "cc & value > 0")
hard(all((r["owner_type"] == "Company") == bool(r["owner_company_ntn"].strip()) for r in veh),
     "Company⇔company_ntn present")
secp_ntns = set(r["company_ntn"] for r in load("10_secp_companies.csv"))
hard(all(r["owner_company_ntn"] in secp_ntns for r in veh if r["owner_company_ntn"].strip()),
     "company_ntn resolves to SECP")
# every INDIVIDUAL-owned vehicle must carry a present CNIC that resolves to NADRA
ind = [r for r in veh if r["owner_type"] == "Individual"]
hard(all(r["owner_cnic"].strip() for r in ind), "every individual owner has a CNIC (none missing)")
hard(all(r["owner_cnic"] in ncnic for r in ind), "every individual owner CNIC resolves to NADRA")

print("\n### 04 ELECTRICITY")
el = load("04_electricity.csv")
hard(uniq(el, "consumer_id") == 0, "consumer_id unique")
hard(all(len(r["consumer_id"]) == 14 for r in el), "consumer_id len 14")
hard(all(int(r["units_consumed"]) > 0 and int(r["bill_amount"]) > 0 for r in el), "units & bill > 0")
hard(all(r["customer_cnic"] in ncnic for r in el), "every customer CNIC present & resolves")

print("\n### 05 GAS")
gas = load("05_gas.csv")
hard(uniq(gas, "consumer_no") == 0, "consumer_no unique")
hard(all(int(r["units_hm3"]) > 0 and int(r["bill_amount"]) > 0 for r in gas), "units & bill > 0")
hard(all(r["customer_cnic"] in ncnic for r in gas), "every customer CNIC present & resolves")

print("\n### 06 LAND")
land = load("06_land.csv")
hard(all(int(r["market_value"]) >= int(r["dc_valuation"]) for r in land), "market≥DC value")
hard(all(int(r["cvt_stamp_duty_paid"]) >= 0 for r in land), "CVT≥0")
hard(all((r["owner_type"] == "Company") == bool(r["owner_company_ntn"].strip()) for r in land),
     "Company⇔company_ntn present")
hard(all(r["owner_company_ntn"] in secp_ntns for r in land if r["owner_company_ntn"].strip()),
     "company_ntn resolves to SECP")
indL = [r for r in land if r["owner_type"] == "Individual"]
hard(all(r["owner_cnic"] in ncnic for r in indL), "every individual land owner CNIC present & resolves")

print("\n### 07 STOCKS")
stk = load("07_stocks.csv")
hard(uniq(stk, "cdc_investor_account") == 0, "CDC account unique")
hard(all(int(r["shares_held"]) > 0 and int(r["market_value"]) > 0 for r in stk), "shares & value > 0")
hard(all(r["uin"].strip() for r in stk), "UIN present")
hard(all(r["holder_cnic"] in ncnic for r in stk if r["holder_cnic"].strip()), "holder CNIC resolves")
hard(all(r["holder_cnic"].strip() or "(Company)" in r["holder_name"] for r in stk),
     "blank holder CNIC only for company-held")

print("\n### 08 TRAVEL")
trv = load("08_travel.csv")
hard(all(PASSPORT.match(r["passport_no"]) for r in trv), "passport format AB1234567")
hard(all(CNIC.match(r["cnic"]) for r in trv), "CNIC format")
hard(all(int(r["ticket_cost"]) > 0 for r in trv), "ticket_cost > 0")
hard(all(r["cnic"] in ncnic for r in trv), "100% resolve to NADRA")
# one passport per person
p2c = {}
for r in trv: p2c.setdefault(r["passport_no"], set()).add(r["cnic"])
hard(all(len(v) == 1 for v in p2c.values()), "passport↔single CNIC")

print("\n### 09 BANKING")
bnk = load("09_banking.csv")
hard(all(IBAN.match(r["iban"]) for r in bnk), "IBAN format PK+2+4+16 (24)")
hard(uniq(bnk, "iban") == 0, "IBAN unique")
hard(all(int(r["account_balance"]) >= 0 for r in bnk), "balance ≥ 0")
hard(all(MOBILE.match(r["mobile"]) for r in bnk), "mobile format")
hard(all(r["customer_cnic"] in ncnic for r in bnk), "100% resolve to NADRA")

print("\n### 10/11 SECP")
comp = load("10_secp_companies.csv")
dirs = load("11_secp_directorships.csv")
hard(uniq(comp, "company_ntn") == 0, "company_ntn unique")
hard(all(NTN.match(r["company_ntn"]) for r in comp), "company NTN format 7+check")
hard(all(int(r["paid_up_capital"]) > 0 for r in comp), "capital > 0")
hard(all(r["company_ntn"] in secp_ntns for r in dirs), "directorship→company resolves")
hard(all(r["person_cnic"] in ncnic for r in dirs), "director→NADRA resolves")
hard(all(0 < int(r["shareholding_percent"]) <= 100 for r in dirs), "shareholding 1-100%")

print("\n### 00 LABELS")
lab = load("00_LABELS_ground_truth.csv")
hard(uniq(lab, "cnic") == 0, "label CNIC unique")
hard(set(r["cnic"] for r in lab) == ncnic, "labels cover exactly NADRA population")
hard(all(r["true_compliance_band"] in {"Green", "Low", "Medium", "Extreme"} for r in lab), "valid bands")
BAND = {"Green": (0, 15), "Low": (15, 40), "Medium": (40, 70), "Extreme": (70, 100)}
hard(all(BAND[r["true_compliance_band"]][0] <= float(r["true_deviation_score"]) <= BAND[r["true_compliance_band"]][1]
         for r in lab), "deviation score within band range")
fr = [r for r in lab if r["is_front"] == "1"]
hard(all(r["real_principal_cnic"] in ncnic for r in fr), "front→real principal resolves")

print("\n" + "=" * 50)
print(f"RESULT: {len(fails)} hard failures, {len(warns)} warnings")
if fails:
    print("FAILURES:", *fails, sep="\n  - ")
sys.exit(1 if fails else 0)
