"""
High-Volume Synthetic Pakistani Tax-Net Dataset Generator
=========================================================
Economic model with engineered compliance bands + graph-hiding fraud.

Design (locked with stakeholder):
  * Population: N primary people (default 200,000) + generated benami fronts.
  * Compliance bands over PRIMARY people: 55% Green / 20% Low / 15% Medium / 10% Extreme.
  * REAL wealth (assets) is separate from DECLARED income (FBR). Deviation = the gap.
  * Green includes HONEST RICH (wealthy + proportionate tax) so the model learns
    'income-vs-assets gap', not 'rich = guilty'.
  * Hiding mechanisms (benami / shell-company / ring) are biased to MEDIUM & EXTREME,
    so a plain CNIC-join cannot catch them — the graph must.
  * Ground-truth labels written to a SEPARATE file (not model input) -> preserves
    the 'unsupervised-in-production' story while enabling precision/recall.

Usage:   python generate_full.py [N]          (N defaults to 200000)
Output:  ./output_full/*.csv
"""

import csv
import os
import random
import sys
from datetime import date, timedelta

SEED = 42
random.seed(SEED)

N = int(sys.argv[1]) if len(sys.argv) > 1 else 200_000
OUT = os.path.join(os.path.dirname(__file__), "output_full")
os.makedirs(OUT, exist_ok=True)

BAND_WEIGHTS = {"Green": 0.55, "Low": 0.20, "Medium": 0.15, "Extreme": 0.10}

# ---------------------------------------------------------------------------
# Reference data
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

URDU = {
    "Muhammad": "محمد", "Ahmed": "احمد", "Ali": "علی", "Hassan": "حسن",
    "Hussain": "حسین", "Bilal": "بلال", "Usman": "عثمان", "Hamza": "حمزہ",
    "Faizan": "فیضان", "Saad": "سعد", "Zain": "زین", "Imran": "عمران",
    "Asad": "اسد", "Kamran": "کامران", "Adnan": "عدنان", "Tariq": "طارق",
    "Rizwan": "رضوان", "Junaid": "جنید", "Farhan": "فرحان", "Waqas": "وقاص",
    "Shahzad": "شہزاد", "Nauman": "نعمان", "Fahad": "فہد", "Danish": "دانش",
    "Salman": "سلمان", "Abdullah": "عبداللہ", "Umar": "عمر", "Bilawal": "بلاول",
    "Ayesha": "عائشہ", "Fatima": "فاطمہ", "Maryam": "مریم", "Zainab": "زینب",
    "Sana": "ثناء", "Hira": "حرا", "Amna": "آمنہ", "Sadia": "سعدیہ",
    "Iqra": "اقراء", "Nimra": "نمرہ", "Rabia": "رابعہ", "Sobia": "ثوبیہ",
    "Kiran": "کرن", "Mehwish": "مہوش", "Noor": "نور", "Sidra": "سدرہ",
    "Areeba": "عریبہ", "Aqsa": "اقصیٰ", "Hina": "حنا", "Komal": "کومل", "Saba": "صبا",
    "Khan": "خان", "Malik": "ملک", "Cheema": "چیمہ", "Butt": "بٹ",
    "Awan": "اعوان", "Chaudhry": "چوہدری", "Sheikh": "شیخ", "Qureshi": "قریشی",
    "Bhatti": "بھٹی", "Gondal": "گوندل", "Raja": "راجہ", "Mughal": "مغل",
    "Dar": "ڈار", "Mir": "میر", "Abbasi": "عباسی", "Satti": "ستی",
    "Janjua": "جنجوعہ", "Rana": "رانا", "Warraich": "ورائچ", "Sandhu": "سندھو",
    "Tarar": "تارڑ",
}

DISTRICTS = {
    "Islamabad":  ("61101", "051", ["F-6", "F-7", "F-8", "F-10", "G-9", "G-10", "G-11", "I-8", "Bahria Town", "DHA-II"]),
    "Lahore":     ("35202", "042", ["DHA Phase 5", "Gulberg III", "Model Town", "Johar Town", "Bahria Town", "Cantt", "Wapda Town"]),
    "Karachi":    ("42101", "021", ["Clifton", "DHA Phase 6", "Gulshan-e-Iqbal", "PECHS", "North Nazimabad", "Bahadurabad"]),
    "Rawalpindi": ("37405", "051", ["Bahria Town", "Satellite Town", "Chaklala Scheme 3", "Westridge", "DHA-I"]),
    "Faisalabad": ("33100", "041", ["D Ground", "Madina Town", "Peoples Colony", "Jaranwala Road"]),
    "Multan":     ("36302", "061", ["Cantt", "Gulgasht Colony", "Shah Rukn-e-Alam", "Model Town"]),
    "Peshawar":   ("17301", "091", ["Hayatabad", "University Town", "Cantt", "Gulbahar"]),
    "Sialkot":    ("34603", "052", ["Cantt", "Model Town", "Paris Road", "Kashmir Road"]),
    "Gujranwala": ("34101", "055", ["Satellite Town", "DC Colony", "Model Town", "Peoples Colony"]),
}
DISTRICT_LIST = list(DISTRICTS.keys())
MAUZAS = ["Chak 45", "Mauza Kot", "Mauza Saggian", "Chak 12-L", "Mauza Manga", "Chak 88-NB", "Mauza Bhamba"]

MOBILE_PREFIX = ["0300", "0301", "0302", "0321", "0333", "0345", "0312", "0314", "0331", "0346", "0307", "0322"]

BANKS = [("HBL", "HABB"), ("UBL", "UNIL"), ("MCB", "MUCB"), ("Allied Bank", "ABPA"),
         ("Meezan Bank", "MEZN"), ("Bank Alfalah", "ALFH"), ("Standard Chartered", "SCBL"),
         ("Faysal Bank", "FAYS"), ("Askari Bank", "ASCM"), ("Bank of Punjab", "BPUN")]

VEHICLES = [  # (make, model, variant, cc, value)
    ("Suzuki", "Mehran", "VX", 800, 900_000), ("Suzuki", "Alto", "VXL", 660, 2_600_000),
    ("Suzuki", "Cultus", "VXL", 1000, 3_500_000), ("Suzuki", "WagonR", "VXL", 1000, 3_100_000),
    ("Suzuki", "Swift", "GLX", 1300, 4_500_000), ("Toyota", "Corolla", "GLi", 1300, 5_800_000),
    ("Toyota", "Corolla", "Altis", 1800, 7_200_000), ("Toyota", "Yaris", "ATIV", 1300, 5_200_000),
    ("Honda", "City", "Aspire", 1500, 6_000_000), ("Honda", "Civic", "Oriel", 1500, 9_500_000),
    ("Toyota", "Fortuner", "Sigma", 2800, 22_000_000), ("Toyota", "Land Cruiser", "ZX", 3500, 75_000_000),
    ("Toyota", "Prado", "TX", 2700, 45_000_000), ("Honda", "BR-V", "S", 1500, 6_500_000),
    ("Kia", "Sportage", "AWD", 2000, 11_500_000), ("Hyundai", "Tucson", "Ultimate", 2000, 10_500_000),
    ("MG", "HS", "Essence", 1500, 9_000_000), ("Kia", "Picanto", "AT", 1000, 3_400_000),
    ("Mercedes", "C200", "AMG", 2000, 35_000_000), ("BMW", "X5", "xDrive", 3000, 90_000_000),
]
LUX_VEH_IDX = [10, 11, 12, 14, 15, 18, 19]  # higher-end picks
COLORS = ["White", "Silver", "Black", "Grey", "Pearl White", "Blue", "Red", "Beige"]

SCRIPS = [("OGDC", 120), ("HBL", 95), ("ENGRO", 280), ("LUCK", 650), ("PSO", 180),
          ("MARI", 1900), ("MEBL", 190), ("FFC", 110), ("PPL", 105), ("SYS", 580)]

AIRLINES = [("PK", "PIA"), ("EK", "Emirates"), ("QR", "Qatar Airways"),
            ("EY", "Etihad"), ("TK", "Turkish"), ("SV", "Saudia")]
AIRPORTS_PK = ["ISB", "LHE", "KHI", "PEW", "MUX"]
DEST = [("DXB", "UAE"), ("LHR", "UK"), ("JFK", "USA"), ("IST", "Turkey"),
        ("JED", "Saudi Arabia"), ("DOH", "Qatar"), ("KUL", "Malaysia"), ("BKK", "Thailand")]
DISCOS = {"Islamabad": "IESCO", "Rawalpindi": "IESCO", "Lahore": "LESCO", "Faisalabad": "FESCO",
          "Multan": "MEPCO", "Peshawar": "PESCO", "Karachi": "K-Electric", "Sialkot": "GEPCO",
          "Gujranwala": "GEPCO"}
JOBS = ["Salaried - IT", "Salaried - Bank", "Retail Trader", "Property Dealer", "Doctor",
        "Textile Business", "Govt Servant", "Importer", "Consultant", "Pharma Distributor",
        "Real Estate Developer", "Restaurant Owner", "Contractor"]
BUSINESS_TYPES = ["Trading", "Real Estate", "Textile", "Construction", "IT Services",
                  "Import/Export", "Pharmaceuticals", "Food & Beverage", "Logistics"]

# True annual income (PKR) by real wealth level
WEALTH_INCOME = {
    "low":   (300_000, 1_500_000),
    "mid":   (1_500_000, 6_000_000),
    "high":  (6_000_000, 25_000_000),
    "ultra": (25_000_000, 300_000_000),
}
WEALTH_LEVELS = ["low", "mid", "high", "ultra"]
WEALTH_WEIGHTS = [0.45, 0.35, 0.15, 0.05]

# Wealth conditioned on band: severe evaders skew WEALTHY (real assets to hide),
# Green spans all levels (includes honest rich AND honest poor).
BAND_WEALTH = {
    "Green":   [0.45, 0.35, 0.15, 0.05],
    "Low":     [0.35, 0.40, 0.20, 0.05],
    "Medium":  [0.10, 0.30, 0.40, 0.20],
    "Extreme": [0.05, 0.20, 0.40, 0.35],
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def rand_date(y0, y1):
    s = date(y0, 1, 1)
    return s + timedelta(days=random.randint(0, (date(y1, 12, 31) - s).days))

def plus_years(d, yrs):
    try:
        return d.replace(year=d.year + yrs)
    except ValueError:              # Feb 29 -> non-leap year
        return d.replace(year=d.year + yrs, day=28)

def make_cnic(prefix, gender):
    # real Pakistani CNIC = 13 digits: XXXXX-XXXXXXX-X (5 locality, 7 serial, 1 gender)
    mid = "".join(str(random.randint(0, 9)) for _ in range(7))
    last = random.choice([1, 3, 5, 7, 9]) if gender == "M" else random.choice([0, 2, 4, 6, 8])
    return f"{prefix}-{mid}-{last}"

def make_mobile():
    return f"{random.choice(MOBILE_PREFIX)}-{random.randint(1000000, 9999999)}"

def make_iban(code):
    acct = "".join(str(random.randint(0, 9)) for _ in range(16))
    return f"PK{random.randint(10,99)}{code}{acct}"

def address(district):
    areas = DISTRICTS[district][2]
    return f"House {random.randint(1,999)}, Street {random.randint(1,60)}, {random.choice(areas)}, {district}"

def urdu_name(name_en):
    return " ".join(URDU.get(t, t) for t in name_en.split())

def name_variant(name):
    """Realistic spelling messiness — operates WITHIN a token (never moves spaces)."""
    r = random.random()
    if r < 0.40 and name.startswith("Muhammad"):
        return name.replace("Muhammad", random.choice(["Mohammad", "Mohammed", "Md.", "M."]))
    if r < 0.60 and name.startswith("Muhammad "):
        return name.replace("Muhammad ", "")
    if r < 0.80:                                    # transpose two letters inside one token
        toks = name.split()
        ti = random.randrange(len(toks))
        t = toks[ti]
        if len(t) > 3:
            i = random.randint(1, len(t) - 2)
            toks[ti] = t[:i] + t[i + 1] + t[i] + t[i + 2:]
            return " ".join(toks)
    return name

def messy_cnic(cnic, heavy=False):
    """CNIC is ALWAYS present and correct (clean primary key everywhere)."""
    return cnic

def tier_amt(level, low, mid, high, ultra):
    return {"low": low, "mid": mid, "high": high, "ultra": ultra}[level]

def approx_tax(income):
    """Rough progressive salaried tax (PKR)."""
    if income <= 600_000: return 0
    if income <= 1_200_000: return int((income - 600_000) * 0.05)
    if income <= 2_400_000: return int(30_000 + (income - 1_200_000) * 0.15)
    if income <= 4_800_000: return int(210_000 + (income - 2_400_000) * 0.25)
    return int(810_000 + (income - 4_800_000) * 0.35)

# ---------------------------------------------------------------------------
# 1. Build PRIMARY population
# ---------------------------------------------------------------------------
print(f"Building population N={N:,} (seed={SEED})…")
people = []          # list of dicts
labels = {}          # cnic -> label dict
family_low = {}      # family_id -> [idx of low-wealth members]
used_cnics = set()   # guarantees CNIC uniqueness (it is the identity key)
used_plates = set()  # vehicle registration plates are unique
used_passports = set()

def new_person(band, force_wealth=None, family_id=None, is_front=False, force_gender=None):
    district = random.choice(DISTRICT_LIST)
    prefix = DISTRICTS[district][0]
    gender = force_gender or random.choice(["M", "M", "M", "F"])
    first = random.choice(MALE_NAMES if gender == "M" else FEMALE_NAMES)
    if gender == "M" and random.random() < 0.4 and first != "Muhammad":
        first = "Muhammad " + first
    surname = random.choice(SURNAMES)
    full = f"{first} {surname}"
    while True:                          # ensure globally-unique CNIC
        cnic = make_cnic(prefix, gender)
        if cnic not in used_cnics:
            used_cnics.add(cnic)
            break
    issue = rand_date(2015, 2023)
    wealth = force_wealth or random.choices(WEALTH_LEVELS, WEALTH_WEIGHTS)[0]
    lo, hi = WEALTH_INCOME[wealth]
    true_income = random.randint(lo, hi)
    fam = family_id if family_id is not None else f"FT-{1000 + len(people)//random.choice([2,3,4])}"
    p = {
        "cnic": cnic, "name_en": full, "name_ur": urdu_name(full),
        "father_husband_name": f"{random.choice(MALE_NAMES)} {surname}",
        "gender": gender, "dob": rand_date(1955, 2003).isoformat(),
        "date_of_issue": issue.isoformat(),
        "date_of_expiry": plus_years(issue, 10).isoformat(),
        "present_address": address(district),
        "permanent_address": address(random.choice(DISTRICT_LIST)),
        "place_of_birth": district, "district": district,
        "marital_status": random.choice(["Single", "Married", "Married", "Married"]),
        "religion": random.choices(["Islam", "Christianity", "Hinduism"], [0.96, 0.025, 0.015])[0],
        "mobile": make_mobile(), "family_tree_id": fam,
        "wealth": wealth, "true_income": true_income, "band": band,
        "is_front": is_front, "archetype": "none",
        "hidden_via": "", "ring_id": "", "shell_ntn": "", "real_principal_cnic": "",
        "relationship": "",
    }
    return p

# assign bands to N primary people
band_pool = []
for b, w in BAND_WEIGHTS.items():
    band_pool += [b] * round(w * N)
while len(band_pool) < N:
    band_pool.append("Green")
random.shuffle(band_pool)

for b in band_pool:
    wl = random.choices(WEALTH_LEVELS, BAND_WEALTH[b])[0]
    people.append(new_person(b, force_wealth=wl))

# index low-wealth members per family (potential fronts)
for idx, p in enumerate(people):
    if p["wealth"] == "low":
        family_low.setdefault(p["family_tree_id"], []).append(idx)

# ---------------------------------------------------------------------------
# 2. Assign archetypes + hiding (bias to Medium/Extreme) and create fronts/shells
# ---------------------------------------------------------------------------
companies = []        # SECP companies
directorships = []    # company_ntn, person_cnic, role, pct
shell_for = {}        # evader cnic -> shell ntn
front_usage = {}
RINGS = []

def make_company(owner_p, shell=False):
    while True:
        ntn = f"{random.randint(1000000,9999999)}-{random.randint(0,9)}"
        if ntn not in used_cnics:      # reuse the global id-uniqueness set
            used_cnics.add(ntn)
            break
    inc = rand_date(2008, 2023)
    name_core = random.choice(["Star", "Crescent", "United", "Premier", "Allied", "Global",
                               "Capital", "Metro", "Pak", "Royal", "Summit", "Apex"])
    suffix = random.choice(["Enterprises", "Traders", "Industries", "Builders",
                            "International", "Associates", "Holdings", "(Pvt) Ltd"])
    companies.append({
        "company_ntn": ntn, "company_name": f"{name_core} {suffix}",
        "incorporation_date": inc.isoformat(),
        "registered_address": owner_p["present_address"],
        "principal_business": random.choice(BUSINESS_TYPES),
        "status": "Active",
        "paid_up_capital": tier_amt(owner_p["wealth"], 1_000_000, 5_000_000, 50_000_000, 500_000_000),
    })
    directorships.append({"company_ntn": ntn, "person_cnic": owner_p["cnic"],
                          "person_name": owner_p["name_en"], "role": "CEO/Director",
                          "shareholding_percent": random.choice([51, 60, 75, 100])})
    return ntn

def make_fronts(evader_idx):
    """Create 1-3 low-income FAMILY fronts (wife/daughter/son…) to hold the evader's
    hidden assets. Fronts share the evader's surname and carry the evader as their
    father/husband -> a real graph signal. Returns list of person indices."""
    ev = people[evader_idx]
    ev_surname = ev["name_en"].split()[-1]
    ev_year = int(ev["dob"][:4])
    # bias toward the wife/daughter scenario; spouse term follows evader gender
    spouse = "Wife" if ev["gender"] == "M" else "Husband"
    rels = [spouse] + random.choice([["Daughter"], ["Daughter", "Son"],
                                     ["Daughter", "Daughter"], ["Son"], ["Daughter", "Son"]])
    rels = rels[:random.choice([1, 2, 2, 3])]      # mostly 2 fronts
    idxs = []
    for rel in rels:
        g = "F" if rel in ("Wife", "Daughter") else "M"
        fp = new_person("Green", force_wealth="low", family_id=ev["family_tree_id"],
                        is_front=True, force_gender=g)
        first = fp["name_en"].split()[0]
        fp["name_en"] = f"{first} {ev_surname}"            # share evader surname
        fp["name_ur"] = urdu_name(fp["name_en"])
        fp["father_husband_name"] = ev["name_en"]          # evader is the father/husband
        fp["relationship"] = rel
        fp["real_principal_cnic"] = ev["cnic"]
        fp["archetype"] = "front"
        fp["marital_status"] = "Married" if rel in ("Wife", "Husband") else "Single"
        if rel in ("Daughter", "Son"):                     # children are younger
            yr = min(2004, ev_year + random.randint(20, 30))
            fp["dob"] = f"{yr}-{fp['dob'][5:]}"
        people.append(fp)
        idxs.append(len(people) - 1)
    return idxs

# legitimate companies for some honest high/ultra business owners (so SECP isn't all shells)
for idx, p in enumerate(people):
    if p["band"] == "Green" and p["wealth"] in ("high", "ultra") and random.random() < 0.35:
        make_company(p, shell=False)

# assign fraud mechanisms
ring_bucket = []
for idx in range(N):                       # only primary people are evaders
    p = people[idx]
    band = p["band"]
    if band == "Green":
        continue
    if band == "Low":
        p["archetype"] = random.choices(["mismatch", "fragmentation"], [0.7, 0.3])[0]
    else:
        wealthy = p["wealth"] in ("high", "ultra")
        # graph-hiding needs real assets -> mostly wealthy evaders; poor severe
        # evaders just blatantly under-declare (rule-catchable).
        base = 0.5 if band == "Medium" else 0.8
        hide_prob = base if wealthy else 0.10
        if random.random() < hide_prob:
            mech = random.choices(["benami", "shell", "ring"], [0.5, 0.3, 0.2])[0]
            p["archetype"] = mech
            if mech == "shell":
                shell_for[p["cnic"]] = make_company(p, shell=True)
                p["shell_ntn"] = shell_for[p["cnic"]]
            elif mech == "ring":
                ring_bucket.append(idx)
        else:
            p["archetype"] = random.choices(["mismatch", "fragmentation"], [0.6, 0.4])[0]

# build rings: each ring CO-OWNS one shared high-value property (same khewat/khasra/
# mauza/district) so members each hold a fragmented share -> a real graph clique.
RING_PROPERTY = {}
random.shuffle(ring_bucket)
for i in range(0, len(ring_bucket) - 2, random.choice([3, 4, 5])):
    group = ring_bucket[i:i + random.choice([3, 4, 5])]
    if len(group) < 3:
        break
    rid = f"RING-{1000 + len(RINGS)}"
    for gi in group:
        people[gi]["ring_id"] = rid
    dist = random.choice(DISTRICT_LIST)
    marla = random.choice([40, 80, 80, 160])            # big plot, split among members
    market = marla * int(4_000_000 * random.uniform(0.8, 1.3))
    RING_PROPERTY[rid] = {
        "khewat": f"{random.randint(50,900)}/{random.randint(40,800)}",
        "khasra": random.randint(200, 5000), "mauza": random.choice(MAUZAS),
        "district": dist, "market": market, "marla": marla, "n": len(group),
    }
    RINGS.append(group)

# pre-create benami fronts NOW (before labels) so they exist as real people
_front_cache = {}
cnic_to_idx = {p["cnic"]: i for i, p in enumerate(people)}
for idx in range(N):
    if people[idx]["archetype"] == "benami":
        _front_cache[people[idx]["cnic"]] = make_fronts(idx)   # list of front indices

print(f"  population incl. fronts: {len(people):,}  | companies: {len(companies):,} "
      f"| rings: {len(RINGS):,}")

# ---------------------------------------------------------------------------
# 3. Declared income / deviation labels
# ---------------------------------------------------------------------------
BAND_DEV = {"Green": (0, 15), "Low": (15, 40), "Medium": (40, 70), "Extreme": (70, 100)}
BAND_DIV = {"Green": (0.9, 1.1), "Low": (1.5, 3), "Medium": (3, 10), "Extreme": (10, 50)}

for p in people:
    band = p["band"]
    lo, hi = BAND_DIV[band]
    declared = p["true_income"] * random.uniform(0.9, 1.1) if band == "Green" \
        else p["true_income"] / random.uniform(lo, hi)
    p["declared_income"] = int(declared)
    # extreme evaders frequently non-filers
    p["is_filer"] = not (band == "Extreme" and random.random() < 0.5) and not (
        band == "Medium" and random.random() < 0.25)
    d0, d1 = BAND_DEV[band]
    p["true_deviation_score"] = round(random.uniform(d0, d1), 1)
    labels[p["cnic"]] = {
        "cnic": p["cnic"], "name_en": p["name_en"], "family_tree_id": p["family_tree_id"],
        "true_wealth_level": p["wealth"], "true_income": p["true_income"],
        "declared_income": p["declared_income"],
        "true_compliance_band": band, "true_deviation_score": p["true_deviation_score"],
        "archetype": p["archetype"], "is_front": int(p["is_front"]),
        "real_principal_cnic": p["real_principal_cnic"],
        "relationship": p.get("relationship", ""),
        "hidden_via": p["shell_ntn"] or "", "ring_id": p["ring_id"],
    }

# ---------------------------------------------------------------------------
# 4. Asset-ownership resolver (applies hiding)
# ---------------------------------------------------------------------------
def owner_for(p, registrable=True):
    """Return (owner_cnic, owner_name, owner_type, owner_company_ntn, identity_cnic).
    identity_cnic = the clean CNIC of WHO the record actually represents (ER truth):
      benami registrable -> the FRONT (the record legitimately bears the front's identity)
      shell  registrable -> 'COMPANY:<ntn>' (a company entity, not a person)
      else               -> the person p (even when their own data is messy)
    registrable assets (cars/land/stocks) can be hidden; bills follow the property."""
    a = p["archetype"]
    if registrable and a == "benami":
        f = people[random.choice(_front_cache[p["cnic"]])]      # spread assets across fronts
        return (messy_cnic(f["cnic"]), f["name_en"], "Individual", "", f["cnic"],
                f["present_address"], f["permanent_address"])   # car bears the FRONT's address
    if registrable and a == "shell":
        return ("", p["shell_ntn"] + " (Company)", "Company", p["shell_ntn"], "COMPANY:" + p["shell_ntn"],
                p["present_address"], p["permanent_address"])
    if a == "fragmentation":
        return (messy_cnic(p["cnic"], heavy=True), name_variant(p["name_en"]), "Individual", "", p["cnic"],
                p["present_address"], p["permanent_address"])
    # mismatch / none / ring / front -> own name (lightly messy)
    return (messy_cnic(p["cnic"]), name_variant(p["name_en"]), "Individual", "", p["cnic"],
            p["present_address"], p["permanent_address"])

# ---------------------------------------------------------------------------
# 5. Stream-write silos
# ---------------------------------------------------------------------------
def writer(name, fields):
    f = open(os.path.join(OUT, name), "w", newline="", encoding="utf-8-sig")
    w = csv.DictWriter(f, fieldnames=fields)
    w.writeheader()
    return f, w

order = list(range(len(people)))
def shuffled():
    random.shuffle(order)
    return order

# ER ground truth: (source, natural_key) -> identity_cnic (clean) of who the record represents
er_truth = []
used_fard = set()
def uniq_fard():
    while True:
        v = f"FRD-{random.randint(100000, 999999)}"
        if v not in used_fard:
            used_fard.add(v)
            return v

# 5.1 NADRA (all people, incl. fronts)
f, w = writer("01_nadra.csv", ["cnic", "name_en", "name_ur", "father_husband_name", "gender",
        "dob", "date_of_issue", "date_of_expiry", "present_address", "permanent_address",
        "place_of_birth", "marital_status", "religion", "mobile", "family_tree_id"])
for i in shuffled():
    p = people[i]
    w.writerow({k: p[k] for k in ["cnic", "name_en", "name_ur", "father_husband_name", "gender",
        "dob", "date_of_issue", "date_of_expiry", "present_address", "permanent_address",
        "place_of_birth", "marital_status", "religion", "mobile", "family_tree_id"]})
    er_truth.append(("NADRA", p["cnic"], p["cnic"]))
f.close()

# 5.2 FBR (filers only appear with full record; non-filers absent or inactive)
f, w = writer("02_fbr.csv", ["ntn", "cnic", "taxpayer_name", "registration_type",
        "business_job_description", "declared_income", "tax_paid", "filer_status",
        "atl_status", "tax_year", "rto", "source_of_income", "withholding_tax_collected"])
fbr_n = 0
for i in shuffled():
    p = people[i]
    if not p.get("is_filer", True) and random.random() < 0.6:
        continue                                   # many non-filers simply absent
    tax = approx_tax(p["declared_income"]) if p.get("is_filer", True) else 0
    src = "Agriculture" if (p["archetype"] in ("mismatch",) and random.random() < 0.3) \
        else random.choice(["Salary", "Business", "Property", "Agriculture"])
    w.writerow({"ntn": p["cnic"], "cnic": p["cnic"], "taxpayer_name": p["name_en"],
                "registration_type": "Individual",
                "business_job_description": random.choice(JOBS),
                "declared_income": p["declared_income"], "tax_paid": tax,
                "filer_status": "Filer" if p.get("is_filer", True) else "Non-Filer",
                "atl_status": "Active" if p.get("is_filer", True) else "Inactive",
                "tax_year": 2024, "rto": f"RTO {p['district']}",
                "source_of_income": src,
                "withholding_tax_collected": int(tax * random.uniform(0.3, 0.8))})
    er_truth.append(("FBR", p["cnic"], p["cnic"]))
    fbr_n += 1
f.close()

def plate():                          # unique realistic plate: ABC-1234
    while True:
        v = "".join(random.choice("ABCDEFGHJKLMNPQR") for _ in range(3)) + f"-{random.randint(1000,9999)}"
        if v not in used_plates:
            used_plates.add(v)
            return v

# 5.3 Excise vehicles
f, w = writer("03_excise_vehicles.csv", ["reg_number", "engine_cc", "make", "model", "variant",
        "manufacturing_year", "color", "chassis_number", "engine_number", "registration_date",
        "token_tax", "owner_type", "owner_cnic", "owner_company_ntn", "owner_name",
        "owner_present_address", "owner_permanent_address", "vehicle_value"])
veh_n = 0
for i in shuffled():
    p = people[i]
    if p["is_front"]:           # fronts hold assets via resolver, not on their own
        continue
    n = tier_amt(p["wealth"], random.randint(0, 1), random.randint(0, 1),
                 random.randint(1, 2), random.randint(1, 3))
    for _ in range(n):
        pool = [VEHICLES[k] for k in LUX_VEH_IDX] if p["wealth"] == "ultra" else \
               (VEHICLES[6:] if p["wealth"] == "high" else VEHICLES[:8])   # high -> upmarket
        mk, md, var, cc, val = random.choice(pool)
        rd = rand_date(2016, 2024)
        oc, on, ot, octn, ident, paddr, perm = owner_for(p, registrable=True)
        reg = plate()
        w.writerow({"reg_number": reg, "engine_cc": cc,
                    "make": mk, "model": md, "variant": var, "manufacturing_year": rd.year,
                    "color": random.choice(COLORS),
                    "chassis_number": "".join(random.choice("ABCDEFGHJKLMNPRSTUVWXYZ0123456789") for _ in range(17)),
                    "engine_number": "".join(random.choice("ABCDEFGHJKLMNP0123456789") for _ in range(11)),
                    "registration_date": rd.isoformat(),
                    "token_tax": int(cc * random.uniform(1.5, 4.0) * 100),
                    "owner_type": ot, "owner_cnic": oc, "owner_company_ntn": octn,
                    "owner_name": on, "owner_present_address": paddr,
                    "owner_permanent_address": perm, "vehicle_value": val})
        er_truth.append(("VEH", reg, ident))
        veh_n += 1
f.close()

# 5.4 Electricity
f, w = writer("04_electricity.csv", ["consumer_id", "customer_name", "customer_cnic",
        "service_address", "disco", "meter_number", "tariff_type", "sanctioned_load_kw",
        "units_consumed", "bill_amount", "billing_month", "due_date"])
elec_n = 0
for i in shuffled():
    p = people[i]
    if p["is_front"] or random.random() > 0.85:
        continue
    units = tier_amt(p["wealth"], random.randint(150, 400), random.randint(400, 900),
                     random.randint(900, 2500), random.randint(2500, 6000))
    oc, on, ot, octn, ident, paddr, perm = owner_for(p, registrable=False)
    cid = "".join(str(random.randint(0, 9)) for _ in range(14))
    w.writerow({"consumer_id": cid,
                "customer_name": on, "customer_cnic": oc, "service_address": p["present_address"],
                "disco": DISCOS.get(p["district"], "IESCO"),
                "meter_number": "".join(str(random.randint(0, 9)) for _ in range(10)),
                "tariff_type": random.choices(["Domestic", "Commercial"], [0.85, 0.15])[0],
                "sanctioned_load_kw": random.choice([2, 3, 5, 7, 10, 15]),
                "units_consumed": units, "bill_amount": int(units * random.uniform(28, 45)),
                "billing_month": "2024-05", "due_date": "2024-06-15"})
    er_truth.append(("ELE", cid, ident))
    elec_n += 1
f.close()

# 5.5 Gas
f, w = writer("05_gas.csv", ["consumer_no", "customer_name", "customer_cnic", "service_address",
        "company", "meter_number", "units_hm3", "bill_amount", "billing_month"])
gas_n = 0
for i in shuffled():
    p = people[i]
    if p["is_front"] or random.random() > 0.7:
        continue
    units = tier_amt(p["wealth"], random.randint(30, 90), random.randint(90, 180),
                     random.randint(180, 400), random.randint(400, 900))
    oc, on, ot, octn, ident, paddr, perm = owner_for(p, registrable=False)
    cno = "".join(str(random.randint(0, 9)) for _ in range(11))
    w.writerow({"consumer_no": cno,
                "customer_name": on, "customer_cnic": oc, "service_address": p["present_address"],
                "company": "SNGPL" if p["district"] != "Karachi" else "SSGC",
                "meter_number": "".join(str(random.randint(0, 9)) for _ in range(8)),
                "units_hm3": units, "bill_amount": int(units * random.uniform(120, 250)),
                "billing_month": "2024-05"})
    er_truth.append(("GAS", cno, ident))
    gas_n += 1
f.close()

# 5.6 Land
f, w = writer("06_land.csv", ["khewat_no", "khatooni_no", "khasra_no", "mauza", "tehsil",
        "district", "fard_registry_no", "property_type", "area", "dc_valuation", "market_value",
        "owner_type", "owner_cnic", "owner_company_ntn", "owner_name", "mutation_no",
        "cvt_stamp_duty_paid"])
ptypes = ["Residential Plot", "Residential House", "Commercial", "Agricultural"]
land_n = 0
for i in shuffled():
    p = people[i]
    if p["is_front"]:
        continue
    # ring members first co-own the shared ring property (fragmented share)
    parcels = []
    if p["ring_id"]:
        rp = RING_PROPERTY[p["ring_id"]]
        share_marla = max(3, rp["marla"] // rp["n"])
        parcels.append({"khewat": rp["khewat"], "khasra": rp["khasra"], "mauza": rp["mauza"],
                        "district": rp["district"], "marla": share_marla,
                        "market": rp["market"] // rp["n"], "shared": True})
    n = tier_amt(p["wealth"], 0, random.randint(0, 1), random.randint(1, 2), random.randint(1, 3))
    for _ in range(n):
        marla = random.choice([3, 5, 7, 10, 20, 40])
        per = tier_amt(p["wealth"], 800_000, 1_500_000, 4_000_000, 9_000_000)
        parcels.append({"khewat": f"{random.randint(50,900)}/{random.randint(40,800)}",
                        "khasra": random.randint(200, 5000), "mauza": random.choice(MAUZAS),
                        "district": p["district"], "marla": marla,
                        "market": marla * int(per * random.uniform(0.8, 1.3)), "shared": False})
    for pc in parcels:
        market = pc["market"]
        oc, on, ot, octn, ident, paddr, perm = owner_for(p, registrable=True)
        fard = uniq_fard()
        w.writerow({"khewat_no": pc["khewat"], "khatooni_no": random.randint(100, 1500),
                    "khasra_no": pc["khasra"], "mauza": pc["mauza"], "tehsil": pc["district"],
                    "district": pc["district"], "fard_registry_no": fard,
                    "property_type": "Commercial" if pc["shared"] else random.choice(ptypes),
                    "area": f"{pc['marla']} Marla" if pc["marla"] < 20 else f"{pc['marla']//20} Kanal",
                    "dc_valuation": int(market * random.uniform(0.3, 0.6)), "market_value": market,
                    "owner_type": ot, "owner_cnic": oc, "owner_company_ntn": octn, "owner_name": on,
                    "mutation_no": f"INT-{random.randint(1000,9999)}",
                    "cvt_stamp_duty_paid": int(market * 0.03)})
        er_truth.append(("LND", fard, ident))
        land_n += 1
f.close()

# 5.7 Stocks
f, w = writer("07_stocks.csv", ["cdc_investor_account", "uin", "sub_account_id",
        "broker_participant_id", "holder_name", "holder_cnic", "scrip_symbol", "shares_held",
        "market_value", "dividend_income", "capital_gains_tax"])
stk_n = 0
for i in shuffled():
    p = people[i]
    if p["is_front"]:
        continue
    if random.random() < (0.05 if p["wealth"] == "low" else 0.2 if p["wealth"] == "mid"
                          else 0.5 if p["wealth"] == "high" else 0.75):
        scrip, price = random.choice(SCRIPS)
        shares = tier_amt(p["wealth"], random.randint(50, 500), random.randint(500, 3000),
                          random.randint(3000, 30000), random.randint(30000, 200000))
        mv = shares * price
        div = int(mv * random.uniform(0.02, 0.08))
        # stocks can be held via shell for shell-archetype evaders
        is_shell = p["archetype"] == "shell"
        hc, hn = ("", p["shell_ntn"] + " (Company)") if is_shell else (p["cnic"], p["name_en"])
        ident = "COMPANY:" + p["shell_ntn"] if is_shell else p["cnic"]
        cdc = "".join(str(random.randint(0, 9)) for _ in range(12))
        w.writerow({"cdc_investor_account": cdc,
                    "uin": hc or p["shell_ntn"], "sub_account_id": f"SUB-{random.randint(10000,99999)}",
                    "broker_participant_id": f"BRK-{random.randint(100,999)}", "holder_name": hn,
                    "holder_cnic": hc, "scrip_symbol": scrip, "shares_held": shares,
                    "market_value": mv, "dividend_income": div, "capital_gains_tax": int(div * 0.15)})
        er_truth.append(("STK", cdc, ident))
        stk_n += 1
f.close()

# 5.8 Travel (always own passport — NOT hideable; strong detection signal)
f, w = writer("08_travel.csv", ["passport_no", "cnic", "full_name", "nationality", "pnr",
        "airline", "flight_no", "departure_airport", "arrival_airport", "destination_country",
        "travel_date", "ticket_cost", "travel_frequency_year"])
trv_n = 0
for i in shuffled():
    p = people[i]
    if p["is_front"]:
        continue
    n = tier_amt(p["wealth"], random.randint(0, 1), random.randint(0, 1),
                 random.randint(1, 3), random.randint(2, 6))
    if n == 0:
        continue
    while True:                       # one unique passport per traveller
        passport = f"{random.choice('ABCDEFGHJKLMNP')}{random.choice('ABCDEFGHJKLMNP')}{random.randint(1000000,9999999)}"
        if passport not in used_passports:
            used_passports.add(passport)
            break
    er_truth.append(("TRV", passport, p["cnic"]))
    for _ in range(n):
        ac, al = random.choice(AIRLINES)
        dac, dco = random.choice(DEST)
        cost = tier_amt(p["wealth"], random.randint(80_000, 150_000), random.randint(150_000, 350_000),
                        random.randint(350_000, 900_000), random.randint(900_000, 3_000_000))
        w.writerow({"passport_no": passport, "cnic": p["cnic"], "full_name": p["name_en"],
                    "nationality": "PAK",
                    "pnr": "".join(random.choice("ABCDEFGHJKLMNPQRSTUVWXYZ0123456789") for _ in range(6)),
                    "airline": al, "flight_no": f"{ac}-{random.randint(200,899)}",
                    "departure_airport": random.choice(AIRPORTS_PK), "arrival_airport": dac,
                    "destination_country": dco, "travel_date": rand_date(2023, 2024).isoformat(),
                    "ticket_cost": cost, "travel_frequency_year": n})
        trv_n += 1
f.close()

# 5.9 Banking
f, w = writer("09_banking.csv", ["account_number", "iban", "bank_name", "branch_code",
        "customer_cnic", "customer_name", "customer_address", "account_type", "account_balance",
        "annual_turnover", "mobile"])
bnk_n = 0
for i in shuffled():
    p = people[i]
    if random.random() > 0.9:
        continue
    bname, bcode = random.choice(BANKS)
    bal = tier_amt(p["wealth"], random.randint(20_000, 400_000), random.randint(400_000, 3_000_000),
                   random.randint(3_000_000, 25_000_000), random.randint(25_000_000, 200_000_000))
    if p["is_front"]:
        bal = random.randint(10_000, 150_000)      # fronts genuinely poor in their own account
    iban = make_iban(bcode)
    w.writerow({"account_number": "".join(str(random.randint(0, 9)) for _ in range(14)),
                "iban": iban, "bank_name": bname, "branch_code": f"{random.randint(1000,9999)}",
                "customer_cnic": p["cnic"], "customer_name": p["name_en"],
                "customer_address": p["present_address"],
                "account_type": random.choice(["Current", "Savings", "Savings"]),
                "account_balance": bal, "annual_turnover": int(bal * random.uniform(1.5, 6.0)),
                "mobile": p["mobile"]})
    er_truth.append(("BNK", iban, p["cnic"]))
    bnk_n += 1
f.close()

# 5.10 SECP companies + directorships
f, w = writer("10_secp_companies.csv", ["company_ntn", "company_name", "incorporation_date",
        "registered_address", "principal_business", "status", "paid_up_capital"])
for c in companies:
    w.writerow(c)
f.close()
f, w = writer("11_secp_directorships.csv", ["company_ntn", "person_cnic", "person_name",
        "role", "shareholding_percent"])
for d in directorships:
    w.writerow(d)
    er_truth.append(("DIR", d["company_ntn"] + "|" + d["person_cnic"], d["person_cnic"]))
f.close()

# 5.x ER GROUND TRUTH (separate — maps every silo record to the clean identity it represents)
f, w = writer("12_er_ground_truth.csv", ["source", "record_key", "true_identity_cnic"])
for src, key, ident in er_truth:
    w.writerow({"source": src, "record_key": key, "true_identity_cnic": ident})
f.close()

# 5.11 GROUND-TRUTH LABELS (separate — NOT model input)
f, w = writer("00_LABELS_ground_truth.csv", ["cnic", "name_en", "family_tree_id",
        "true_wealth_level", "true_income", "declared_income", "true_compliance_band",
        "true_deviation_score", "archetype", "is_front", "real_principal_cnic",
        "relationship", "hidden_via", "ring_id"])
for cnic in [p["cnic"] for p in people]:
    w.writerow(labels[cnic])
f.close()

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
from collections import Counter
bands = Counter(p["band"] for p in people[:N])
arches = Counter(p["archetype"] for p in people if p["archetype"] != "none")
print("\n=== SUMMARY ===")
print(f"People (incl fronts): {len(people):,}  (primary {N:,} + fronts {len(people)-N:,})")
print("Bands (primary):", dict(bands))
print("Archetypes:", dict(arches))
print(f"Rows -> FBR {fbr_n:,} | Vehicles {veh_n:,} | Elec {elec_n:,} | Gas {gas_n:,} | "
      f"Land {land_n:,} | Stocks {stk_n:,} | Travel {trv_n:,} | Bank {bnk_n:,} | "
      f"Companies {len(companies):,} | Directorships {len(directorships):,}")
print("Output:", OUT)
