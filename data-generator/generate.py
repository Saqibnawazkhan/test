"""
Synthetic Pakistani Civic/Financial Dataset Generator  —  VERIFICATION SAMPLE
============================================================================
Generates ~100 records per silo from a SHARED population so CNICs link across
silos (lets you eyeball entity-resolution too). Self-contained: stdlib only.
Reproducible via fixed SEED. Formats per DATASET_SCHEMA.md (verified June 2026).

Run:  python generate.py
Out:  ./output/*.csv   (one file per silo)
"""

import csv
import os
import random
from datetime import date, timedelta

SEED = 42
random.seed(SEED)

N_PEOPLE = 120          # core population (NADRA). Other silos sample subsets.
SAMPLE = 100            # cap per silo for the verification batch
OUT = os.path.join(os.path.dirname(__file__), "output")
os.makedirs(OUT, exist_ok=True)

# ---------------------------------------------------------------------------
# Reference data (realistic Pakistani values)
# ---------------------------------------------------------------------------
MALE_NAMES = ["Muhammad", "Ahmed", "Ali", "Hassan", "Hussain", "Bilal", "Usman",
              "Hamza", "Faizan", "Saad", "Zain", "Imran", "Asad", "Kamran",
              "Adnan", "Tariq", "Rizwan", "Junaid", "Farhan", "Waqas", "Shahzad",
              "Nauman", "Fahad", "Danish", "Salman", "Abdullah", "Umar", "Bilawal"]
FEMALE_NAMES = ["Ayesha", "Fatima", "Maryam", "Zainab", "Sana", "Hira", "Amna",
                "Sadia", "Iqra", "Nimra", "Rabia", "Sobia", "Kiran", "Mehwish",
                "Noor", "Sidra", "Areeba", "Aqsa", "Hina", "Komal", "Saba"]
SURNAMES = ["Khan", "Malik", "Cheema", "Butt", "Awan", "Chaudhry", "Sheikh",
            "Qureshi", "Bhatti", "Gondal", "Raja", "Mughal", "Dar", "Mir",
            "Abbasi", "Satti", "Janjua", "Rana", "Warraich", "Sandhu", "Tarar"]

# Urdu script for the most common tokens (name fields carry both scripts)
URDU = {
    "Muhammad": "محمد", "Ahmed": "احمد", "Ali": "علی", "Hassan": "حسن",
    "Hussain": "حسین", "Bilal": "بلال", "Usman": "عثمان", "Hamza": "حمزہ",
    "Imran": "عمران", "Asad": "اسد", "Umar": "عمر", "Abdullah": "عبداللہ",
    "Ayesha": "عائشہ", "Fatima": "فاطمہ", "Maryam": "مریم", "Zainab": "زینب",
    "Sana": "ثنا", "Hira": "حرا", "Amna": "آمنہ", "Noor": "نور",
    "Khan": "خان", "Malik": "ملک", "Chaudhry": "چوہدری", "Sheikh": "شیخ",
    "Qureshi": "قریشی", "Butt": "بٹ", "Awan": "اعوان", "Raja": "راجہ",
}

# District -> (CNIC 5-digit prefix, mobile/landline city, sectors/areas)
DISTRICTS = {
    "Islamabad":  ("61101", "051", ["F-6", "F-7", "F-8", "F-10", "G-9", "G-10", "G-11", "I-8", "Bahria Town", "DHA-II"]),
    "Lahore":     ("35202", "042", ["DHA Phase 5", "Gulberg III", "Model Town", "Johar Town", "Bahria Town", "Cantt", "Wapda Town"]),
    "Karachi":    ("42101", "021", ["Clifton", "DHA Phase 6", "Gulshan-e-Iqbal", "PECHS", "North Nazimabad", "Bahadurabad"]),
    "Rawalpindi": ("37405", "051", ["Bahria Town", "Satellite Town", "Chaklala Scheme 3", "Westridge", "DHA-I"]),
    "Faisalabad": ("33100", "041", ["D Ground", "Madina Town", "Peoples Colony", "Jaranwala Road"]),
    "Multan":     ("36302", "061", ["Cantt", "Gulgasht Colony", "Shah Rukn-e-Alam", "Model Town"]),
    "Peshawar":   ("17301", "091", ["Hayatabad", "University Town", "Cantt", "Gulbahar"]),
}
DISTRICT_LIST = list(DISTRICTS.keys())

MOBILE_PREFIX = ["0300", "0301", "0302", "0321", "0333", "0345", "0312", "0314", "0331", "0346", "0307", "0322"]

BANKS = [  # (name, 4-letter IBAN bank code)
    ("HBL", "HABB"), ("UBL", "UNIL"), ("MCB", "MUCB"), ("Allied Bank", "ABPA"),
    ("Meezan Bank", "MEZN"), ("Bank Alfalah", "ALFH"), ("Standard Chartered", "SCBL"),
    ("Faysal Bank", "FAYS"), ("Askari Bank", "ASCM"), ("Bank of Punjab", "BPUN"),
]

VEHICLES = [  # (make, model, variant, cc, approx_value_PKR)
    ("Suzuki", "Mehran", "VX", 800, 900_000), ("Suzuki", "Alto", "VXL", 660, 2_600_000),
    ("Suzuki", "Cultus", "VXL", 1000, 3_500_000), ("Suzuki", "WagonR", "VXL", 1000, 3_100_000),
    ("Suzuki", "Swift", "GLX", 1300, 4_500_000), ("Toyota", "Corolla", "GLi", 1300, 5_800_000),
    ("Toyota", "Corolla", "Altis", 1800, 7_200_000), ("Toyota", "Yaris", "ATIV", 1300, 5_200_000),
    ("Honda", "City", "Aspire", 1500, 6_000_000), ("Honda", "Civic", "Oriel", 1500, 9_500_000),
    ("Toyota", "Fortuner", "Sigma", 2800, 22_000_000), ("Toyota", "Land Cruiser", "ZX", 3500, 75_000_000),
    ("Toyota", "Prado", "TX", 2700, 45_000_000), ("Honda", "BR-V", "S", 1500, 6_500_000),
    ("Kia", "Sportage", "AWD", 2000, 11_500_000), ("Hyundai", "Tucson", "Ultimate", 2000, 10_500_000),
    ("MG", "HS", "Essence", 1500, 9_000_000), ("Kia", "Picanto", "AT", 1000, 3_400_000),
]
COLORS = ["White", "Silver", "Black", "Grey", "Pearl White", "Blue", "Red", "Beige"]

SCRIPS = [("OGDC", 120), ("HBL", 95), ("ENGRO", 280), ("LUCK", 650), ("PSO", 180),
          ("MARI", 1900), ("MEBL", 190), ("FFC", 110), ("PPL", 105), ("SYS", 580)]

AIRLINES = [("PK", "PIA"), ("EK", "Emirates"), ("QR", "Qatar Airways"),
            ("EY", "Etihad"), ("TK", "Turkish"), ("SV", "Saudia")]
AIRPORTS_PK = ["ISB", "LHE", "KHI", "PEW", "MUX"]
DEST = [("DXB", "UAE"), ("LHR", "UK"), ("JFK", "USA"), ("IST", "Turkey"),
        ("JED", "Saudi Arabia"), ("DOH", "Qatar"), ("KUL", "Malaysia"), ("BKK", "Thailand")]

DISCOS = {"Islamabad": "IESCO", "Rawalpindi": "IESCO", "Lahore": "LESCO",
          "Faisalabad": "FESCO", "Multan": "MEPCO", "Peshawar": "PESCO", "Karachi": "K-Electric"}

INCOME_TIERS = ["low", "mid", "high", "ultra"]
TIER_WEIGHTS = [0.45, 0.35, 0.15, 0.05]

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def rand_date(start_year, end_year):
    start = date(start_year, 1, 1)
    end = date(end_year, 12, 31)
    return start + timedelta(days=random.randint(0, (end - start).days))

def make_cnic(prefix, gender):
    middle = "".join(str(random.randint(0, 9)) for _ in range(7))
    last = random.choice([1, 3, 5, 7, 9]) if gender == "M" else random.choice([0, 2, 4, 6, 8])
    return f"{prefix}{random.randint(0,9)}-{middle}-{last}"

def make_mobile():
    return f"{random.choice(MOBILE_PREFIX)}-{random.randint(1000000, 9999999)}"

def make_iban(code):
    acct = "".join(str(random.randint(0, 9)) for _ in range(16))
    check = random.randint(10, 99)
    return f"PK{check}{code}{acct}"

def address(district):
    _, _, areas = DISTRICTS[district]
    house = random.randint(1, 999)
    street = random.randint(1, 60)
    return f"House {house}, Street {street}, {random.choice(areas)}, {district}"

def name_variant(name):
    """Introduce realistic spelling messiness for entity resolution."""
    r = random.random()
    if r < 0.45 and name.startswith("Muhammad"):
        return name.replace("Muhammad", random.choice(["Mohammad", "Mohammed", "Md.", "M."]))
    if r < 0.65:                                   # drop honorific prefix
        return name.replace("Muhammad ", "")
    if r < 0.80 and len(name) > 6:                 # single-char typo
        i = random.randint(1, len(name) - 2)
        if name[i] != " ":
            return name[:i] + name[i + 1] + name[i] + name[i + 2:]
    return name

def maybe_messy_cnic(cnic):
    """~10% missing, ~5% one-digit typo — forces ER fallback."""
    r = random.random()
    if r < 0.10:
        return ""                                  # missing CNIC
    if r < 0.15:
        i = random.choice([0, 1, 2, 7, 8, 9, 15])  # flip a digit (valid CNIC indices)
        ch = cnic[i]
        if ch.isdigit():
            return cnic[:i] + str((int(ch) + 1) % 10) + cnic[i + 1:]
    return cnic

def urdu_name(name_en):
    return " ".join(URDU.get(tok, tok) for tok in name_en.split())

# ---------------------------------------------------------------------------
# Core population (NADRA master)  — everything else derives from this
# ---------------------------------------------------------------------------
people = []
family_counter = 1000
i = 0
while len(people) < N_PEOPLE:
    district = random.choice(DISTRICT_LIST)
    prefix = DISTRICTS[district][0]
    gender = random.choice(["M", "M", "M", "F"])   # skew reflects asset-holder demographics
    first = random.choice(MALE_NAMES if gender == "M" else FEMALE_NAMES)
    if gender == "M" and random.random() < 0.4 and first != "Muhammad":
        first = "Muhammad " + first
    surname = random.choice(SURNAMES)
    full = f"{first} {surname}"
    father = f"{random.choice(MALE_NAMES)} {surname}"
    cnic = make_cnic(prefix, gender)
    dob = rand_date(1955, 2003)
    issue = rand_date(2015, 2023)
    tier = random.choices(INCOME_TIERS, TIER_WEIGHTS)[0]
    fam = family_counter + (i // 3)                # ~3 people share a family id
    people.append({
        "cnic": cnic, "name_en": full, "name_ur": urdu_name(full),
        "father_husband_name": father, "gender": gender, "dob": dob.isoformat(),
        "date_of_issue": issue.isoformat(),
        "date_of_expiry": issue.replace(year=issue.year + 10).isoformat(),
        "present_address": address(district),
        "permanent_address": address(random.choice(DISTRICT_LIST)),
        "place_of_birth": district, "district": district,
        "marital_status": random.choice(["Single", "Married", "Married", "Married"]),
        "religion": random.choices(["Islam", "Christianity", "Hinduism"], [0.96, 0.025, 0.015])[0],
        "mobile": make_mobile(), "family_tree_id": f"FT-{fam}",
        "_tier": tier,
    })
    i += 1

def tier_pick(tier, low, mid, high, ultra):
    return {"low": low, "mid": mid, "high": high, "ultra": ultra}[tier]

def write(name, fieldnames, rows):
    path = os.path.join(OUT, name)
    with open(path, "w", newline="", encoding="utf-8-sig") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        w.writerows(rows)
    print(f"  {name:32s} {len(rows):>4d} rows")

print("Generating verification sample (seed=%d)…" % SEED)

# ---------------------------------------------------------------------------
# 1. NADRA
# ---------------------------------------------------------------------------
nadra_fields = ["cnic", "name_en", "name_ur", "father_husband_name", "gender",
                "dob", "date_of_issue", "date_of_expiry", "present_address",
                "permanent_address", "place_of_birth", "marital_status",
                "religion", "mobile", "family_tree_id"]
write("01_nadra.csv", nadra_fields,
      [{k: p[k] for k in nadra_fields} for p in people[:SAMPLE]])

# ---------------------------------------------------------------------------
# 2. FBR  (not everyone files; non-filers simply absent)
# ---------------------------------------------------------------------------
fbr_rows = []
for p in people:
    if random.random() < 0.55:                     # ~55% appear in FBR
        tier = p["_tier"]
        income = tier_pick(tier, random.randint(300_000, 900_000),
                           random.randint(900_000, 3_000_000),
                           random.randint(3_000_000, 12_000_000),
                           random.randint(12_000_000, 60_000_000))
        filer = random.random() < (0.9 if tier in ("low", "mid") else 0.6)
        tax = int(income * random.uniform(0.02, 0.12)) if filer else 0
        fbr_rows.append({
            "ntn": p["cnic"], "cnic": p["cnic"], "taxpayer_name": p["name_en"],
            "registration_type": "Individual",
            "business_job_description": random.choice(
                ["Salaried - IT", "Salaried - Bank", "Retail Trader", "Property Dealer",
                 "Doctor", "Textile Business", "Govt Servant", "Importer", "Consultant"]),
            "declared_income": income, "tax_paid": tax,
            "filer_status": "Filer" if filer else "Non-Filer",
            "atl_status": "Active" if filer else "Inactive",
            "tax_year": 2024,
            "rto": f"RTO {p['district']}",
            "source_of_income": random.choice(["Salary", "Business", "Property", "Agriculture"]),
            "withholding_tax_collected": int(tax * random.uniform(0.3, 0.8)),
        })
random.shuffle(fbr_rows)
write("02_fbr.csv",
      ["ntn", "cnic", "taxpayer_name", "registration_type", "business_job_description",
       "declared_income", "tax_paid", "filer_status", "atl_status", "tax_year", "rto",
       "source_of_income", "withholding_tax_collected"], fbr_rows[:SAMPLE])

# ---------------------------------------------------------------------------
# 3. Excise (vehicles) — richer tiers own bigger/more cars
# ---------------------------------------------------------------------------
veh_rows = []
plate_letters = lambda: "".join(random.choice("ABCDEFGHJKLMNPQR") for _ in range(3))
for p in people:
    n = tier_pick(p["_tier"], random.randint(0, 1), random.randint(0, 1),
                  random.randint(1, 2), random.randint(1, 3))
    for _ in range(n):
        mk, md, var, cc, val = random.choice(
            VEHICLES[:6] if p["_tier"] in ("low", "mid") else VEHICLES)
        reg_date = rand_date(2016, 2024)
        veh_rows.append({
            "reg_number": f"{plate_letters()}-{random.randint(100,999)}",
            "engine_cc": cc, "make": mk, "model": md, "variant": var,
            "manufacturing_year": reg_date.year, "color": random.choice(COLORS),
            "chassis_number": "".join(random.choice("ABCDEFGHJKLMNPRSTUVWXYZ0123456789") for _ in range(17)),
            "engine_number": "".join(random.choice("ABCDEFGHJKLMNP0123456789") for _ in range(11)),
            "registration_date": reg_date.isoformat(),
            "token_tax": int(cc * random.uniform(1.5, 4.0) * 100),
            "owner_cnic": maybe_messy_cnic(p["cnic"]),
            "owner_name": name_variant(p["name_en"]),
            "owner_present_address": p["present_address"],
            "owner_permanent_address": p["permanent_address"],
            "vehicle_value": val,
        })
random.shuffle(veh_rows)
write("03_excise_vehicles.csv",
      ["reg_number", "engine_cc", "make", "model", "variant", "manufacturing_year",
       "color", "chassis_number", "engine_number", "registration_date", "token_tax",
       "owner_cnic", "owner_name", "owner_present_address", "owner_permanent_address",
       "vehicle_value"], veh_rows[:SAMPLE])

# ---------------------------------------------------------------------------
# 4. Electricity (DISCO)
# ---------------------------------------------------------------------------
elec_rows = []
for p in people:
    if random.random() < 0.85:
        units = tier_pick(p["_tier"], random.randint(150, 400), random.randint(400, 900),
                          random.randint(900, 2500), random.randint(2500, 6000))
        rate = random.uniform(28, 45)
        elec_rows.append({
            "consumer_id": "".join(str(random.randint(0, 9)) for _ in range(14)),
            "customer_name": name_variant(p["name_en"]),
            "customer_cnic": maybe_messy_cnic(p["cnic"]),
            "service_address": p["present_address"],
            "disco": DISCOS.get(p["district"], "IESCO"),
            "meter_number": "".join(str(random.randint(0, 9)) for _ in range(10)),
            "tariff_type": random.choices(["Domestic", "Commercial"], [0.85, 0.15])[0],
            "sanctioned_load_kw": random.choice([2, 3, 5, 7, 10, 15]),
            "units_consumed": units, "bill_amount": int(units * rate),
            "billing_month": "2024-05",
            "due_date": "2024-06-15",
        })
random.shuffle(elec_rows)
write("04_electricity.csv",
      ["consumer_id", "customer_name", "customer_cnic", "service_address", "disco",
       "meter_number", "tariff_type", "sanctioned_load_kw", "units_consumed",
       "bill_amount", "billing_month", "due_date"], elec_rows[:SAMPLE])

# ---------------------------------------------------------------------------
# 5. Gas (SNGPL/SSGC)
# ---------------------------------------------------------------------------
gas_rows = []
for p in people:
    if random.random() < 0.7:
        units = tier_pick(p["_tier"], random.randint(30, 90), random.randint(90, 180),
                          random.randint(180, 400), random.randint(400, 900))
        gas_rows.append({
            "consumer_no": "".join(str(random.randint(0, 9)) for _ in range(11)),
            "customer_name": name_variant(p["name_en"]),
            "customer_cnic": maybe_messy_cnic(p["cnic"]),
            "service_address": p["present_address"],
            "company": "SNGPL" if p["district"] != "Karachi" else "SSGC",
            "meter_number": "".join(str(random.randint(0, 9)) for _ in range(8)),
            "units_hm3": units, "bill_amount": int(units * random.uniform(120, 250)),
            "billing_month": "2024-05",
        })
random.shuffle(gas_rows)
write("05_gas.csv",
      ["consumer_no", "customer_name", "customer_cnic", "service_address", "company",
       "meter_number", "units_hm3", "bill_amount", "billing_month"], gas_rows[:SAMPLE])

# ---------------------------------------------------------------------------
# 6. Land / Revenue (Punjab BOR style)
# ---------------------------------------------------------------------------
land_rows = []
ptypes = ["Residential Plot", "Residential House", "Commercial", "Agricultural"]
for p in people:
    n = tier_pick(p["_tier"], 0, random.randint(0, 1), random.randint(1, 2), random.randint(1, 3))
    for _ in range(n):
        marla = random.choice([3, 5, 7, 10, 20, 40])      # 20 marla = 1 kanal
        per_marla = tier_pick(p["_tier"], 800_000, 1_500_000, 4_000_000, 9_000_000)
        market = marla * int(per_marla * random.uniform(0.8, 1.3))
        land_rows.append({
            "khewat_no": f"{random.randint(50,900)}/{random.randint(40,800)}",
            "khatooni_no": random.randint(100, 1500),
            "khasra_no": random.randint(200, 5000),
            "mauza": random.choice(["Chak 45", "Mauza Kot", "Mauza Saggian", "Chak 12-L", "Mauza Manga"]),
            "tehsil": p["district"], "district": p["district"],
            "fard_registry_no": f"FRD-{random.randint(100000,999999)}",
            "property_type": random.choice(ptypes),
            "area": f"{marla} Marla" if marla < 20 else f"{marla//20} Kanal",
            "dc_valuation": int(market * random.uniform(0.3, 0.6)),
            "market_value": market,
            "owner_cnic": maybe_messy_cnic(p["cnic"]),
            "owner_name": name_variant(p["name_en"]),
            "mutation_no": f"INT-{random.randint(1000,9999)}",
            "cvt_stamp_duty_paid": int(market * 0.03),
        })
random.shuffle(land_rows)
write("06_land.csv",
      ["khewat_no", "khatooni_no", "khasra_no", "mauza", "tehsil", "district",
       "fard_registry_no", "property_type", "area", "dc_valuation", "market_value",
       "owner_cnic", "owner_name", "mutation_no", "cvt_stamp_duty_paid"], land_rows[:SAMPLE])

# ---------------------------------------------------------------------------
# 7. Stocks / Securities (PSX + CDC)
# ---------------------------------------------------------------------------
stock_rows = []
for p in people:
    if random.random() < (0.05 if p["_tier"] == "low" else
                          0.2 if p["_tier"] == "mid" else 0.6):
        scrip, price = random.choice(SCRIPS)
        shares = tier_pick(p["_tier"], random.randint(50, 500), random.randint(500, 3000),
                           random.randint(3000, 30000), random.randint(30000, 200000))
        mv = shares * price
        div = int(mv * random.uniform(0.02, 0.08))
        stock_rows.append({
            "cdc_investor_account": "".join(str(random.randint(0, 9)) for _ in range(12)),
            "uin": p["cnic"], "sub_account_id": f"SUB-{random.randint(10000,99999)}",
            "broker_participant_id": f"BRK-{random.randint(100,999)}",
            "holder_name": p["name_en"], "holder_cnic": p["cnic"],
            "scrip_symbol": scrip, "shares_held": shares, "market_value": mv,
            "dividend_income": div, "capital_gains_tax": int(div * 0.15),
        })
random.shuffle(stock_rows)
write("07_stocks.csv",
      ["cdc_investor_account", "uin", "sub_account_id", "broker_participant_id",
       "holder_name", "holder_cnic", "scrip_symbol", "shares_held", "market_value",
       "dividend_income", "capital_gains_tax"], stock_rows[:SAMPLE])

# ---------------------------------------------------------------------------
# 8. Air Travel / Passport
# ---------------------------------------------------------------------------
travel_rows = []
for p in people:
    n = tier_pick(p["_tier"], random.randint(0, 1), random.randint(0, 1),
                  random.randint(1, 3), random.randint(2, 6))
    if n == 0:
        continue
    passport = f"{random.choice('ABCDEFGHJKLMNP')}{random.choice('ABCDEFGHJKLMNP')}{random.randint(1000000,9999999)}"
    for _ in range(n):
        ac, al = random.choice(AIRLINES)
        dac, dcountry = random.choice(DEST)
        cost = tier_pick(p["_tier"], random.randint(80_000, 150_000),
                         random.randint(150_000, 350_000),
                         random.randint(350_000, 900_000),
                         random.randint(900_000, 3_000_000))
        travel_rows.append({
            "passport_no": passport, "cnic": p["cnic"], "full_name": p["name_en"],
            "nationality": "PAK",
            "pnr": "".join(random.choice("ABCDEFGHJKLMNPQRSTUVWXYZ0123456789") for _ in range(6)),
            "airline": al, "flight_no": f"{ac}-{random.randint(200,899)}",
            "departure_airport": random.choice(AIRPORTS_PK), "arrival_airport": dac,
            "destination_country": dcountry,
            "travel_date": rand_date(2023, 2024).isoformat(),
            "ticket_cost": cost,
            "travel_frequency_year": n,
        })
random.shuffle(travel_rows)
write("08_travel.csv",
      ["passport_no", "cnic", "full_name", "nationality", "pnr", "airline", "flight_no",
       "departure_airport", "arrival_airport", "destination_country", "travel_date",
       "ticket_cost", "travel_frequency_year"], travel_rows[:SAMPLE])

# ---------------------------------------------------------------------------
# 9. Banking
# ---------------------------------------------------------------------------
bank_rows = []
for p in people:
    if random.random() < 0.9:
        bname, bcode = random.choice(BANKS)
        bal = tier_pick(p["_tier"], random.randint(20_000, 400_000),
                        random.randint(400_000, 3_000_000),
                        random.randint(3_000_000, 25_000_000),
                        random.randint(25_000_000, 200_000_000))
        bank_rows.append({
            "account_number": "".join(str(random.randint(0, 9)) for _ in range(14)),
            "iban": make_iban(bcode), "bank_name": bname,
            "branch_code": f"{random.randint(1000,9999)}",
            "customer_cnic": p["cnic"], "customer_name": p["name_en"],
            "customer_address": p["present_address"],
            "account_type": random.choice(["Current", "Savings", "Savings"]),
            "account_balance": bal,
            "annual_turnover": int(bal * random.uniform(1.5, 6.0)),
            "mobile": p["mobile"],
        })
random.shuffle(bank_rows)
write("09_banking.csv",
      ["account_number", "iban", "bank_name", "branch_code", "customer_cnic",
       "customer_name", "customer_address", "account_type", "account_balance",
       "annual_turnover", "mobile"], bank_rows[:SAMPLE])

print("\nDone. Files written to:", OUT)
print("Tip: NADRA is the master; other silos reference the same CNICs (some")
print("deliberately missing/typo'd/with name variants) so you can test ER.")
