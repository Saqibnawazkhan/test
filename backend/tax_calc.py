"""
FBR income-tax calculator — 100% deterministic (no AI in the math).

Slabs verified against PwC Tax Summaries (Pakistan) + multiple sources for
Tax Year 2025 (FY2024-25) and Tax Year 2026 (FY2025-26), salaried and
non-salaried/business (AOP). Each band: (lower_bound, fixed_tax_at_lower, marginal_rate).
"""

INF = float("inf")

SLABS = {
    ("2024-25", "salaried"): [
        (0, 0, 0.0),
        (600_000, 0, 0.05),
        (1_200_000, 30_000, 0.15),
        (2_200_000, 180_000, 0.25),
        (3_200_000, 430_000, 0.30),
        (4_100_000, 700_000, 0.35),
    ],
    ("2025-26", "salaried"): [
        (0, 0, 0.0),
        (600_000, 0, 0.01),
        (1_200_000, 6_000, 0.11),
        (2_200_000, 116_000, 0.23),
        (3_200_000, 346_000, 0.30),
        (4_100_000, 616_000, 0.35),
    ],
    # Non-salaried / business individuals & AOPs — unchanged between the two years.
    ("2024-25", "business"): [
        (0, 0, 0.0),
        (600_000, 0, 0.15),
        (1_200_000, 90_000, 0.20),
        (1_600_000, 170_000, 0.30),
        (3_200_000, 650_000, 0.40),
        (5_600_000, 1_610_000, 0.45),
    ],
    ("2025-26", "business"): [
        (0, 0, 0.0),
        (600_000, 0, 0.15),
        (1_200_000, 90_000, 0.20),
        (1_600_000, 170_000, 0.30),
        (3_200_000, 650_000, 0.40),
        (5_600_000, 1_610_000, 0.45),
    ],
}


def _surcharge_rate(income, year, kind):
    """Surcharge on the income-tax when taxable income exceeds Rs 10,000,000."""
    if income <= 10_000_000:
        return 0.0
    return 0.09 if (year == "2025-26" and kind == "salaried") else 0.10


def compute_tax(income, year="2025-26", kind="salaried"):
    income = max(0.0, float(income or 0))
    key = (year, kind)
    if key not in SLABS:
        key = ("2025-26", "salaried")
    slabs = SLABS[key]

    # locate the band the income falls into
    band = slabs[0]
    for s in slabs:
        if income > s[0]:
            band = s
    lower, fixed, rate = band
    base_tax = fixed + rate * (income - lower)

    # per-bracket breakdown (transparency)
    brackets = []
    for i, s in enumerate(slabs):
        lo = s[0]
        hi = slabs[i + 1][0] if i + 1 < len(slabs) else INF
        r = s[2]
        if income > lo and r > 0:
            taxable = min(income, hi) - lo
            brackets.append({
                "range": "{:,} – {}".format(int(lo), "above" if hi == INF else "{:,}".format(int(hi))),
                "rate": round(r * 100, 1),
                "taxable": round(taxable),
                "tax": round(taxable * r),
            })

    sur_rate = _surcharge_rate(income, year, kind)
    surcharge = base_tax * sur_rate
    total_tax = base_tax + surcharge
    take_home = income - total_tax
    eff = (total_tax / income * 100) if income > 0 else 0.0

    return {
        "income": round(income),
        "year": year,
        "kind": kind,
        "tax": round(base_tax),
        "surcharge": round(surcharge),
        "surcharge_rate": round(sur_rate * 100, 1),
        "total_tax": round(total_tax),
        "effective_rate": round(eff, 2),
        "marginal_rate": round(rate * 100, 1),
        "take_home_annual": round(take_home),
        "monthly_tax": round(total_tax / 12),
        "take_home_monthly": round(take_home / 12),
        "brackets": brackets,
    }
