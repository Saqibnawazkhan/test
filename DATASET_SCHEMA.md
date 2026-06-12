# Dataset Schema — Realistic Pakistani Civic/Financial Silos

Per-silo field specification for synthetic data generation. Formats verified against public sources (June 2026).
**Legend:** 🔑 = cross-silo linking key · ⭐ = recommended addition (needs approval) · `format` = exact pattern.

---

## Shared Format Reference (use everywhere)

| Element | Format | Rule |
|---|---|---|
| **CNIC** 🔑 | `XXXXX-XXXXXXX-X` (13 digits) | First 5 = locality (province/division/district), next 7 = family/individual serial, **last digit = gender (odd=male, even=female)** |
| **Mobile** 🔑 | `03XX-XXXXXXX` (11 digits) | Prefixes: Jazz `0300–0309/0320–0329`, Zong `0310–0319`, Ufone `0330–0339`, Telenor `0340–0349`, SCOM `0355` |
| **Landline** | `0XX-XXXXXXX` | Area codes: Islamabad `051`, Lahore `042`, Karachi `021`, Faisalabad `041`, Peshawar `091` |
| **IBAN** 🔑 | `PK` + 2 check digits + 4-letter bank code + 16 alphanumeric = **24 chars** | e.g. `PK36SCBL0000001123456702` |
| **Passport** 🔑 | 2 letters + 7 digits (`AB1234567`, 9 chars) | MRP since 2004 |
| **NTN** 🔑 | Individual = **CNIC (13 digits)**; Company/AOP = `1234567-8` (7 digits + check) | Post-2021 individuals use CNIC as NTN |
| **Name** 🔑 | Urdu + romanized English | Plant spelling variants (محمد / Muhammad / Mohammad / Md.) |

---

## 1. NADRA (Identity Master)

| Field | Format / Type | Notes |
|---|---|---|
| cnic 🔑 | 13 digits | Primary identity key |
| name_en / name_ur 🔑 | text | Both scripts |
| father_husband_name | text | Linking for family graph |
| gender | M/F/X | Must match CNIC last digit |
| date_of_birth | DATE | |
| date_of_issue | DATE | |
| date_of_expiry | DATE | ~10 yrs after issue |
| present_address 🔑 | text | "Current" address |
| permanent_address 🔑 | text | Often differs from present |
| place_of_birth | district | |
| marital_status | enum | |
| religion | enum | |
| ⭐ mobile 🔑 | 11 digits | NADRA holds registered SIM/contact — strong ER key |
| ⭐ family_tree_id | id | Links spouse/children/parents (NADRA actually stores this — powers benami detection) |

## 2. FBR (Tax Records)

| Field | Format / Type | Notes |
|---|---|---|
| ntn 🔑 | CNIC (individual) / 7-digit (company) | |
| cnic 🔑 | 13 digits | |
| taxpayer_name 🔑 | text | |
| registration_type | Individual / AOP / Company | |
| business_job_description | text | |
| declared_income | PKR (annual) | The "declared" figure to deviate against |
| tax_paid | PKR | |
| filer_status | Filer / Non-Filer | |
| atl_status | Active / Inactive | Active Taxpayer List |
| tax_year | YYYY | |
| rto | text | Regional Tax Office |
| ⭐ source_of_income | enum (salary/business/property/ag) | Ag-income = exemption-abuse flag |
| ⭐ withholding_tax_collected | PKR | Tax deducted at source (feeds tax-adjustment math) |

## 3. Excise & Taxation (Vehicles)

| Field | Format / Type | Notes |
|---|---|---|
| reg_number 🔑 | Province plate (`LEA-1234`, `ABC-123`; ICT `ABC-123`) | |
| engine_cc | int | Bands: 660/800/1000/1300/1600/1800/2000/2500+ |
| make / model / variant | text | Suzuki, Toyota, Honda, etc. |
| manufacturing_year | YYYY | |
| color | text | |
| chassis_number | 17-char VIN | |
| engine_number | alphanumeric | |
| registration_date | DATE | |
| token_tax | PKR | Annual; scales with cc |
| owner_cnic 🔑 | 13 digits | |
| owner_name 🔑 | text | |
| owner_present_address 🔑 | text | |
| owner_permanent_address 🔑 | text | |
| ⭐ transfer_history | list of {cnic, date} | Benami/ring signal |
| ⭐ vehicle_value | PKR | Asset valuation for deviation |

## 4. Electricity (DISCO: IESCO/LESCO/…)

| Field | Format / Type | Notes |
|---|---|---|
| consumer_id / reference_no 🔑 | 14-digit reference number | |
| customer_name 🔑 | text | |
| customer_cnic 🔑 | 13 digits | Sometimes missing → ER fallback |
| service_address 🔑 | text | Strong address-based ER key |
| meter_number | alphanumeric | |
| tariff_type | Domestic/Commercial/Industrial | |
| sanctioned_load | kW | |
| units_consumed | int (monthly) | |
| bill_amount | PKR | The lifestyle signal (e.g. 300k/mo) |
| billing_month | YYYY-MM | |
| due_date | DATE | |

## 5. Gas (SNGPL/SSGC)
Mirror of electricity: `consumer_no` 🔑, customer_name 🔑, cnic 🔑, service_address 🔑, meter_no, units (HM³/MMBTU), bill_amount, billing_month.

## 6. Land / Revenue (Punjab BOR / PLRA)

| Field | Format / Type | Notes |
|---|---|---|
| khewat_no | `current/previous` | Owner/ownership account ID |
| khatooni_no | number | Cultivation/possession |
| khasra_no | number | Plot/survey number |
| mauza / tehsil / district 🔑 | text | Location hierarchy |
| fard_registry_no | id | Jamabandi extract / deed no. |
| property_type | Residential/Commercial/Agricultural/Plot | |
| area | Kanal / Marla (1 Kanal = 20 Marla) | |
| dc_valuation | PKR | Official rate |
| market_value | PKR | Real value (≫ DC value) |
| owner_cnic 🔑 | 13 digits | |
| owner_name 🔑 | text | |
| mutation_no (intiqal) | id + date | Transfer history |
| ⭐ cvt_stamp_duty_paid | PKR | Tax at transfer |

## 7. Stocks / Securities (PSX + CDC)

| Field | Format / Type | Notes |
|---|---|---|
| cdc_investor_account 🔑 | 12-digit relationship no. (IAS ID + account) | |
| uin 🔑 | = CNIC for individuals | Direct CNIC link |
| sub_account_id | under broker | |
| broker_participant_id | id | |
| holder_name 🔑 | text | |
| holder_cnic 🔑 | 13 digits | |
| scrip_symbol | text (e.g. OGDC, HBL) | |
| shares_held | int | |
| market_value | PKR | |
| dividend_income | PKR | Income vs zero-return flag |
| capital_gains_tax | PKR | |

## 8. Air Travel / Passport (FIA/Airlines)

| Field | Format / Type | Notes |
|---|---|---|
| passport_no 🔑 | `AB1234567` (2 letters + 7 digits) | |
| cnic 🔑 | 13 digits | Passport links to CNIC |
| full_name 🔑 | text | |
| nationality | PAK | |
| passport_issue / expiry | DATE | |
| pnr / booking_ref | 6-char alphanumeric | |
| flight_no / airline | text (PK, EK, QR…) | |
| departure / arrival_airport | IATA (ISB, LHE, KHI, DXB…) | |
| travel_date | DATE | |
| destination_country | text | |
| ticket_cost | PKR | Lifestyle signal |
| ⭐ travel_frequency | int/year | Frequent luxury travel vs low income |

## 9. Banking

| Field | Format / Type | Notes |
|---|---|---|
| account_number 🔑 | bank-specific (10–16 digits) | |
| iban 🔑 | 24-char `PK…` | |
| bank_name | text (HBL, UBL, MCB, Meezan…) | |
| branch_code | 4-digit | |
| customer_cnic 🔑 | 13 digits | |
| customer_name 🔑 | text | |
| customer_address 🔑 | text | |
| account_type | Current/Savings/Roshan Digital | |
| account_balance | PKR | Income reality check |
| annual_turnover | PKR | Inflow vs declared income |
| ⭐ mobile 🔑 | 11 digits | KYC contact — ER key |

---

## Cross-Silo Linking Keys (ER backbone)
**Primary:** CNIC (when present). **Fallbacks/reinforcers:** name (fuzzy, cross-script), present/permanent address, mobile number, father/husband name, passport↔CNIC, NTN↔CNIC, IBAN→CNIC.

## Recommended additions awaiting your approval (⭐ above)
1. NADRA: mobile + family_tree_id  2. FBR: source_of_income + withholding_tax  3. Vehicles: transfer_history + value  4. Land: CVT/stamp duty  5. Travel: frequency  6. Banking: mobile.
**Rationale:** each is either a real field in that database OR a strong ER/fraud signal.

## Sources
- CDC Pakistan — investor account / UIN: https://www.cdcpakistan.com/businesses/investor-account-services/faqs-2/
- FBR / NTN format — OECD TIN & FBR: https://www.oecd.org/content/dam/oecd/en/topics/policy-issue-focus/aeoi/pakistan-tin.pdf
- Punjab land records (khewat/khasra/khatooni/fard): https://www.landeed.com/post/punjab-jamabandi-complete-guide-to-check-land-records-online
- Pakistani passport format — Wikipedia: https://en.wikipedia.org/wiki/Pakistani_passport
