"""
Verified FBR knowledge base for the grounded chatbot. Reference: FY2025-26
(Tax Year 2026), Income Tax Ordinance 2001 as amended by Finance Act 2025.
Every entry carries its legal citation. The chatbot may ONLY answer from this
content; anything else it must defer to FBR. Numbers that are slab/province
dependent are stated as principles (defer for the exact figure) to avoid guessing.
"""

KB = [
    {
        "topic": "Income tax slabs (salaried & business)",
        "content": (
            "Income tax is charged on annual taxable income under progressive slabs (First Schedule, "
            "Part I, Income Tax Ordinance 2001; Finance Act 2025). FY2025-26 SALARIED: up to Rs 600,000 = 0%; "
            "600,001-1,200,000 = 1%; 1,200,001-2,200,000 = Rs 6,000 + 11%; 2,200,001-3,200,000 = Rs 116,000 + 23%; "
            "3,200,001-4,100,000 = Rs 346,000 + 30%; above 4,100,000 = Rs 616,000 + 35%. "
            "FY2025-26 BUSINESS/non-salaried: 0% up to 600,000; then 15%, 20%, 30%, 40%, 45% across higher slabs. "
            "A surcharge applies where taxable income exceeds Rs 10,000,000 (9% for salaried, 10% otherwise). "
            "For an exact figure use the in-app Tax Calculator."
        ),
        "cite": "First Schedule Part I, ITO 2001; Finance Act 2025",
    },
    {
        "topic": "Filer vs non-filer and the Active Taxpayers List (ATL)",
        "content": (
            "Filers (persons on the ATL who file their annual return) pay significantly LOWER withholding/advance "
            "tax on property, vehicles, banking and many transactions. Non-filers pay much higher rates (often "
            "double) under the Tenth Schedule. To be on the ATL you must file your income tax return for the year."
        ),
        "cite": "Tenth Schedule, ITO 2001; Section 181A (ATL)",
    },
    {
        "topic": "Gift",
        "content": (
            "A genuine gift is NOT taxable income for the recipient ONLY if it is received from a close relative "
            "(parents, spouse, children, siblings, grandparents) through proper banking channels (cross-cheque / "
            "bank transfer) and is properly documented. A gift of cash, or from a non-relative, or without a banking "
            "trail, is treated as unexplained income and added to the recipient's income under Section 39(3)/111. "
            "There is no separate 'gift tax', but undocumented gifts are taxed as income."
        ),
        "cite": "Sections 39(3), 111, ITO 2001",
    },
    {
        "topic": "Inheritance",
        "content": (
            "Pakistan has NO inheritance tax or estate duty. Assets inherited from a deceased relative are NOT "
            "taxable income to the heir. They must be substantiated (succession certificate / legal heirship / the "
            "deceased's record). Any future income earned from inherited assets (rent, profit, gain) is taxable normally."
        ),
        "cite": "ITO 2001 (no estate/inheritance tax provision)",
    },
    {
        "topic": "Property purchase - advance tax (buyer)",
        "content": (
            "The buyer pays advance income tax under Section 236K at the time of transfer, calculated on the "
            "property's fair market value. Filers pay much lower rates than non-filers (late-filers pay an "
            "intermediate rate). This advance tax is ADJUSTABLE against the buyer's final tax liability for the year. "
            "The exact percentage depends on the value slab and filing status - confirm the precise figure with FBR."
        ),
        "cite": "Section 236K, ITO 2001",
    },
    {
        "topic": "Property sale - advance tax and capital gains (seller)",
        "content": (
            "The seller pays advance tax under Section 236C at the time of transfer, and separately Capital Gains "
            "Tax (CGT) under Section 37(1A) on any gain, where the CGT rate depends on the holding period and the "
            "acquisition date. Filers pay lower advance-tax rates than non-filers. Confirm the exact rate for the "
            "specific value and holding period with FBR."
        ),
        "cite": "Sections 236C, 37(1A), ITO 2001",
    },
    {
        "topic": "Motor vehicle - transfer/registration and token tax",
        "content": (
            "Advance income tax is collected at registration/transfer of a motor vehicle under Section 231B, and "
            "annual token tax under Section 234, based on engine capacity. Filers pay roughly HALF of what "
            "non-filers pay. The withholding is reduced by 10% for each year since first registration, and vehicles "
            "10 years or older are exempt from this advance tax. Exact amounts depend on engine capacity and the "
            "province - confirm with the provincial Excise & Taxation Department."
        ),
        "cite": "Sections 231B, 234, ITO 2001",
    },
    {
        "topic": "Filing the return and wealth statement",
        "content": (
            "Every taxable person must file an annual income tax return under Section 114, and individuals must also "
            "file a wealth statement under Section 116 reconciling assets and income. Filing keeps you on the ATL "
            "(lower taxes). Failure to file attracts penalties under Section 182."
        ),
        "cite": "Sections 114, 116, 182, ITO 2001",
    },
    {
        "topic": "Unexplained income or assets",
        "content": (
            "Under Section 111, if a person's assets, expenditure or lifestyle exceed their declared income and the "
            "difference is not satisfactorily explained, the unexplained amount is added to income and taxed, and "
            "penalties under Section 182 may apply. This is how undeclared wealth is brought into the tax net."
        ),
        "cite": "Sections 111, 182, ITO 2001",
    },
    {
        "topic": "Audit and amendment of assessment",
        "content": (
            "FBR may select a taxpayer for audit under Section 177 (or via automated risk selection under Section "
            "214C) and require records. Where income has escaped assessment, the Commissioner may amend the "
            "assessment under Section 122 and issue a show-cause notice."
        ),
        "cite": "Sections 177, 214C, 122, ITO 2001",
    },
]

# Flattened text block injected into the model's system prompt.
KB_TEXT = "\n\n".join(
    "[{}]\n{}\n(Legal basis: {})".format(e["topic"], e["content"], e["cite"]) for e in KB
)
