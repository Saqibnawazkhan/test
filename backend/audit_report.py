"""
Findings-driven FBR audit report (PDF).

Mirrors a real Section-177 income-tax audit report: identity, basis of
selection, scope, records examined, a DYNAMIC findings list (each discrepancy
tagged with the contravened section of the Income Tax Ordinance, 2001),
quantification, and a recommendation. The findings list is data-driven, so a
non-filer, a benami case and an under-declarer each get a different report from
the same engine. No AI / external calls — fully deterministic and offline.
"""
import datetime
from fpdf import FPDF

GREEN = (26, 169, 120)
INK = (16, 25, 38)
GREY = (110, 120, 132)
LINE = (210, 216, 224)
RED = (200, 60, 60)


def money(x):
    try:
        return "PKR {:,}".format(int(x or 0))
    except (TypeError, ValueError):
        return "PKR 0"


# ----------------------------------------------------------------------------
# Findings engine — maps a taxpayer's data to case-specific findings.
# ----------------------------------------------------------------------------
def build_findings(d):
    declared = d["declared"] or 0
    assets = (d["own_assets"] or 0) + (d["hidden_assets"] or 0)
    footprint = d["lifestyle"] or 0
    unexplained = max(0, assets + footprint - declared)
    a = d["assets"]
    veh = a["vehicles"]
    lux = [v for v in veh if (v.get("engine_cc") or 0) >= 2000]
    props = a["properties"]
    trips = a["travel_count"]
    elec_m = a["electricity_monthly"]
    is_filer = (d.get("filer_status") or "").lower() == "filer"
    zone = (d.get("zone") or "").lower()
    flagged = zone in ("red", "yellow") or (d.get("score") or 0) >= 22
    # "Material" only when assets dwarf declared means (a house > 1yr income is normal).
    material = unexplained > 0 and ((declared == 0 and (assets + footprint) > 1_000_000)
                                    or (declared > 0 and (assets + footprint) > declared * 3))

    f = []

    def add(observation, provision, declared_s="-", identified_s="-", diff_s="-", narrative=""):
        f.append({"no": len(f) + 1, "observation": observation, "provision": provision,
                  "declared": declared_s, "identified": identified_s, "difference": diff_s,
                  "narrative": narrative})

    # 1. Filing status — a factual compliance gap, reported regardless of zone
    if not is_filer:
        add("Return of income not filed for the tax year under audit", "Sec 114 / 182",
            narrative="The taxpayer is a non-filer. A notice under Section 114 to furnish the "
                      "return, and penal action under Section 182, are warranted.")
        add("Statement of assets/liabilities (wealth statement) not on record", "Sec 116",
            narrative="No wealth statement under Section 116 is available to reconcile assets "
                      "against declared income.")

    # The mismatch / means findings only stand where the case is genuinely flagged.
    if flagged and material:
        # 2. Core mismatch — unexplained assets / expenditure
        add("Assets and expenditure materially exceed declared means", "Sec 111",
            declared_s=money(declared), identified_s=money(assets + footprint),
            diff_s=money(unexplained),
            narrative="Identified assets and lifestyle expenditure exceed the income declared. "
                      "The differential of {} is treated as unexplained income/assets under "
                      "Section 111 unless satisfactorily explained.".format(money(unexplained)))

        # 3. Under-declaration by an existing filer -> amend assessment
        if is_filer:
            add("Declared income understated; assessment requires amendment", "Sec 122(5A)",
                declared_s=money(declared), identified_s=money(assets + footprint),
                diff_s=money(unexplained),
                narrative="Definite information indicates income chargeable to tax has escaped "
                          "assessment; the assessment is liable to amendment under Section 122(5A).")

        # 4. Means evidence — vehicles
        if veh:
            detail = "{} vehicle(s) on record{}".format(
                len(veh), ", incl. {} of engine capacity >= 2000cc".format(len(lux)) if lux else "")
            add("Motor vehicle ownership inconsistent with declared income", "Sec 111 (means)",
                narrative=detail + ". Acquisition cost is not reconciled with declared income.")

        # 5. Means evidence — multiple properties
        if len(props) > 1:
            add("Ownership of multiple immovable properties", "Sec 111 (means)",
                narrative="{} immovable properties identified via Land Revenue records, indicating "
                          "investment beyond declared capacity.".format(len(props)))

        # 6. Utility consumption
        if elec_m and elec_m > 30000:
            add("Utility consumption indicates undeclared expenditure", "Sec 111 (means)",
                narrative="Average electricity billing of {}/month is inconsistent with the declared "
                          "income.".format(money(elec_m)))

        # 7. Foreign travel
        if trips and trips > 2:
            add("Frequency of foreign travel inconsistent with declared income", "Sec 111 (means)",
                narrative="{} international trips recorded against declared income of {}."
                          .format(trips, money(declared)))

    return f, (unexplained if (flagged and material) else 0)


# ----------------------------------------------------------------------------
# PDF rendering
# ----------------------------------------------------------------------------
class _Doc(FPDF):
    subtitle = "Inland Revenue  -  Income Tax Audit Report  (Section 177, Income Tax Ordinance, 2001)"

    def header(self):
        self.set_fill_color(*GREEN)
        self.rect(0, 0, self.w, 22, "F")
        self.set_xy(10, 5)
        self.set_text_color(255, 255, 255)
        self.set_font("helvetica", "B", 14)
        self.cell(0, 6, "FEDERAL BOARD OF REVENUE", align="L")
        self.set_xy(10, 12)
        self.set_font("helvetica", "", 9)
        self.cell(0, 5, self.subtitle, align="L")
        self.set_xy(-60, 6)
        self.set_font("helvetica", "B", 9)
        self.cell(50, 5, "CONFIDENTIAL", align="R")
        self.set_y(28)
        self.set_text_color(*INK)

    def footer(self):
        self.set_y(-15)
        self.set_draw_color(*LINE)
        self.line(10, self.get_y(), self.w - 10, self.get_y())
        self.set_y(-12)
        self.set_font("helvetica", "", 7)
        self.set_text_color(*GREY)
        self.multi_cell(0, 3,
            "System-generated by TaxNet AI (Graph-AI tax-net engine). Entity resolution F1 = 1.00, "
            "GNN anomaly model AUC = 0.93. This is a system-generated draft subject to review by the "
            "assessing officer. Page {} ".format(self.page_no()), align="C")


def _section(pdf, title):
    pdf.ln(2)
    pdf.set_font("helvetica", "B", 11)
    pdf.set_text_color(*GREEN)
    pdf.cell(0, 7, title, new_x="LMARGIN", new_y="NEXT")
    pdf.set_draw_color(*LINE)
    pdf.line(10, pdf.get_y(), pdf.w - 10, pdf.get_y())
    pdf.ln(1.5)
    pdf.set_text_color(*INK)


def _kv_row(pdf, k, v, kw=55):
    pdf.set_font("helvetica", "B", 9)
    pdf.cell(kw, 5.5, k)
    pdf.set_font("helvetica", "", 9)
    pdf.multi_cell(0, 5.5, str(v), new_x="LMARGIN", new_y="NEXT")


def build_audit_pdf(d):
    findings, unexplained = build_findings(d)
    declared = d["declared"] or 0
    assets = (d["own_assets"] or 0) + (d["hidden_assets"] or 0)
    footprint = d["lifestyle"] or 0
    recovery = d["recovery"] or 0
    year = d.get("tax_year", 2024)
    today = datetime.date.today().strftime("%d %B %Y")
    digits = "".join(ch for ch in d["cnic"] if ch.isdigit())
    report_no = "FBR/AUD/{}/{}".format(year, digits[-6:] if len(digits) >= 6 else digits)

    pdf = _Doc()
    pdf.set_auto_page_break(True, margin=18)
    pdf.add_page()

    # Title strip
    pdf.set_font("helvetica", "B", 13)
    pdf.cell(0, 7, "AUDIT REPORT - TAX YEAR {}".format(year), new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("helvetica", "", 9)
    pdf.set_text_color(*GREY)
    pdf.cell(0, 5, "Report No: {}        Date: {}".format(report_no, today), new_x="LMARGIN", new_y="NEXT")
    pdf.set_text_color(*INK)

    # 1. Taxpayer particulars
    _section(pdf, "1.  Taxpayer Particulars")
    _kv_row(pdf, "Name", d["name"] or "-")
    _kv_row(pdf, "CNIC", d["cnic"])
    _kv_row(pdf, "NTN", d.get("ntn") or "Not registered")
    _kv_row(pdf, "Father / Husband", d.get("father") or "-")
    _kv_row(pdf, "Address", d.get("address") or "-")
    _kv_row(pdf, "District", d.get("district") or "-")
    _kv_row(pdf, "Filing status", d.get("filer_status") or "Non-Filer")

    # 2. Basis of selection
    _section(pdf, "2.  Basis of Selection for Audit")
    pdf.set_font("helvetica", "", 9)
    pdf.multi_cell(0, 5,
        "Case selected through automated, risk-based parametric analysis (akin to Section 214C) "
        "by the TaxNet cross-departmental intelligence engine. The system fuses 14 data silos "
        "(NADRA, FBR, Excise, Land Revenue, DISCOs/SNGPL, banking, NCCPL/CDC, SECP, FIA travel) "
        "via entity resolution and a graph neural network.", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(1)
    _kv_row(pdf, "Deviation score", "{} / 100".format(d.get("score", 0)))
    _kv_row(pdf, "Risk zone", d.get("zone", "N/A"))
    _kv_row(pdf, "GNN anomaly probability", "{:.0%}".format(d.get("gnn_prob") or 0))

    # 3. Scope & period
    _section(pdf, "3.  Scope and Period")
    pdf.set_font("helvetica", "", 9)
    pdf.multi_cell(0, 5,
        "Audit covers the income, assets, expenditure and financial affairs for Tax Year {}, with a "
        "look-back of up to six (6) preceding tax years as permitted under the Ordinance.".format(year),
        new_x="LMARGIN", new_y="NEXT")

    # 4. Records examined
    _section(pdf, "4.  Records and Information Examined")
    a = d["assets"]
    examined = [
        "Identity & family record (NADRA)",
        "Income tax return / filer status (FBR-IRIS)",
        "Motor vehicle registration (Excise & Taxation): {} record(s)".format(len(a["vehicles"])),
        "Immovable property (Land Revenue): {} record(s)".format(len(a["properties"])),
        "Bank accounts & turnover: {} record(s)".format(len(a["bank_accounts"])),
        "Securities holdings (NCCPL/CDC): {} record(s)".format(len(a["stocks"])),
        "Utility consumption (DISCOs/SNGPL)",
        "Foreign travel (FIA): {} trip(s)".format(a["travel_count"]),
    ]
    pdf.set_font("helvetica", "", 9)
    for e in examined:
        pdf.cell(4)
        pdf.cell(0, 5, "-  " + e, new_x="LMARGIN", new_y="NEXT")

    # 5. Findings (dynamic)
    _section(pdf, "5.  Audit Findings and Discrepancies")
    if not findings:
        pdf.set_font("helvetica", "", 9)
        pdf.multi_cell(0, 5, "No material discrepancy noted. Declared income reasonably reconciles "
                             "with identified assets and expenditure. Case appears compliant.",
                       new_x="LMARGIN", new_y="NEXT")
    else:
        for fnd in findings:
            # title row: number + observation + provision (full width, robust)
            pdf.set_font("helvetica", "B", 9)
            pdf.set_fill_color(238, 242, 246)
            pdf.multi_cell(0, 5.5, "{}.  {}   [{}]".format(fnd["no"], fnd["observation"], fnd["provision"]),
                           border="LTRB", fill=True, new_x="LMARGIN", new_y="NEXT")
            # figures line (only when there is a quantified difference)
            if fnd["difference"] != "-":
                pdf.set_font("helvetica", "", 8)
                pdf.set_text_color(*GREY)
                pdf.multi_cell(0, 4.4,
                    "    Declared: {}      Identified: {}      Difference: {}".format(
                        fnd["declared"], fnd["identified"], fnd["difference"]),
                    border="LR", new_x="LMARGIN", new_y="NEXT")
                pdf.set_text_color(*INK)
            # narrative
            pdf.set_font("helvetica", "", 8.5)
            pdf.multi_cell(0, 4.4, "    " + fnd["narrative"], border="LRB", new_x="LMARGIN", new_y="NEXT")
            pdf.ln(1.5)

    # 6. Quantification
    _section(pdf, "6.  Quantification")
    _kv_row(pdf, "Declared income", money(declared), kw=70)
    _kv_row(pdf, "Identified assets", money(assets), kw=70)
    _kv_row(pdf, "Indicative annual expenditure", money(footprint), kw=70)
    pdf.set_text_color(*RED)
    _kv_row(pdf, "Unexplained amount (Sec 111)", money(unexplained), kw=70)
    _kv_row(pdf, "Estimated recoverable tax", money(recovery), kw=70)
    pdf.set_text_color(*INK)

    # 7. Conclusion & recommendation
    _section(pdf, "7.  Conclusion and Recommendation")
    pdf.set_font("helvetica", "", 9)
    if findings:
        sections = []
        for fnd in findings:
            for part in fnd["provision"].replace("(means)", "").split("/"):
                s = part.strip()
                if s and s not in sections:
                    sections.append(s)
        sec_str = ", ".join(sections)
        pdf.multi_cell(0, 5,
            "In view of the discrepancies above, it is recommended that proceedings be initiated to "
            "amend the assessment for Tax Year {} under Section 122 of the Income Tax Ordinance, 2001. "
            "A show-cause notice citing {} should be issued requiring the taxpayer to explain, within "
            "fifteen (15) days, the source of the unexplained assets and expenditure aggregating {}. "
            "Estimated recoverable revenue: {}.".format(year, sec_str, money(unexplained), money(recovery)),
            new_x="LMARGIN", new_y="NEXT")
    else:
        pdf.multi_cell(0, 5,
            "No further action recommended at this stage. The case is filed as compliant, subject to "
            "routine monitoring.", new_x="LMARGIN", new_y="NEXT")

    pdf.ln(8)
    pdf.set_font("helvetica", "", 9)
    pdf.cell(0, 5, "_______________________", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("helvetica", "", 8)
    pdf.set_text_color(*GREY)
    pdf.cell(0, 4, "Inland Revenue Officer / Auditor", new_x="LMARGIN", new_y="NEXT")
    pdf.cell(0, 4, "Federal Board of Revenue, Government of Pakistan", new_x="LMARGIN", new_y="NEXT")

    out = pdf.output()
    return bytes(out)


# ----------------------------------------------------------------------------
# Show-Cause Notice — the statutory letter issued TO the taxpayer.
# Same findings engine; formatted as a formal notice citing the real sections.
# ----------------------------------------------------------------------------
def _sections_from(findings):
    """Unique, ordered list of statutory sections referenced by the findings."""
    secs = []
    for f in findings:
        for part in f["provision"].replace("(means)", "").split("/"):
            s = part.strip()
            if s and s not in secs:
                secs.append(s)
    return secs


def build_notice_pdf(d):
    findings, unexplained = build_findings(d)
    declared = d["declared"] or 0
    assets = (d["own_assets"] or 0) + (d["hidden_assets"] or 0)
    footprint = d["lifestyle"] or 0
    recovery = d["recovery"] or 0
    year = d.get("tax_year", 2024)
    today = datetime.date.today().strftime("%d %B %Y")
    digits = "".join(ch for ch in d["cnic"] if ch.isdigit())
    notice_no = "FBR/SCN/{}/{}".format(year, digits[-6:] if len(digits) >= 6 else digits)
    is_filer = (d.get("filer_status") or "").lower() == "filer"
    sections = _sections_from(findings)
    primary = "122(5A)" if (is_filer and unexplained > 0) else ("114" if not is_filer else (sections[0] if sections else "111"))

    pdf = _Doc()
    pdf.subtitle = "Inland Revenue  -  Show-Cause Notice  (Income Tax Ordinance, 2001)"
    pdf.set_auto_page_break(True, margin=18)
    pdf.add_page()

    # Title
    pdf.set_font("helvetica", "B", 13)
    pdf.cell(0, 7, "SHOW-CAUSE NOTICE UNDER SECTION {}".format(primary), new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("helvetica", "", 9)
    pdf.set_text_color(*GREY)
    pdf.cell(0, 5, "Notice No: {}        Date: {}".format(notice_no, today), new_x="LMARGIN", new_y="NEXT")
    pdf.set_text_color(*INK)
    pdf.ln(3)

    # Addressee
    pdf.set_font("helvetica", "", 10)
    pdf.multi_cell(0, 5.5, "To:  {}\nCNIC:  {}\nNTN:  {}\nAddress:  {}".format(
        d["name"] or "-", d["cnic"], d.get("ntn") or "Not registered", d.get("address") or "-"),
        new_x="LMARGIN", new_y="NEXT")
    pdf.ln(2)
    pdf.set_font("helvetica", "B", 10)
    subject = ("Failure to file return of income and unexplained assets/expenditure"
               if not is_filer else "Amendment of assessment - unexplained assets/expenditure")
    pdf.multi_cell(0, 5.5, "Subject:  {} - Tax Year {}".format(subject, year),
                   new_x="LMARGIN", new_y="NEXT")
    pdf.ln(2)

    pdf.set_font("helvetica", "", 9.5)
    pdf.multi_cell(0, 5,
        "Whereas a cross-departmental analysis of records held by Excise & Taxation, Land Revenue, "
        "DISCOs/SNGPL, NCCPL/CDC, SECP, banking companies and FIA (immigration) has been carried out "
        "in respect of your tax affairs, yielding a Tax Compliance Deviation Score of {}/100 ({} risk); "
        "and whereas the following discrepancies have been noted:".format(
            d.get("score", 0), d.get("zone", "N/A")),
        new_x="LMARGIN", new_y="NEXT")
    pdf.ln(2)

    if findings:
        pdf.set_font("helvetica", "", 9.5)
        for f in findings:
            pdf.multi_cell(0, 5, "{}.  {}  (Section {}).".format(f["no"], f["observation"], f["provision"]),
                           new_x="LMARGIN", new_y="NEXT")
        pdf.ln(2)
        # figures
        pdf.set_font("helvetica", "B", 9.5)
        pdf.multi_cell(0, 5,
            "Declared income: {}    |    Identified assets & expenditure: {}    |    "
            "Unexplained amount: {}    |    Estimated recoverable tax: {}".format(
                money(declared), money(assets + footprint), money(unexplained), money(recovery)),
            new_x="LMARGIN", new_y="NEXT")
        pdf.ln(3)
        pdf.set_font("helvetica", "", 9.5)
        sec_str = ", ".join("Section " + s for s in sections) if sections else "Section 111"
        pdf.multi_cell(0, 5,
            "Now, therefore, you are hereby called upon to SHOW CAUSE in writing within fifteen (15) days "
            "of receipt of this notice as to why, in respect of the discrepancies noted above under {}, "
            "your assessment for Tax Year {} should not be amended under Section 122 of the Income Tax "
            "Ordinance, 2001, the unexplained amount be added to your income under Section 111, and "
            "penalty proceedings be initiated under Section 182. You may furnish your written explanation "
            "together with documentary evidence (including the source and tax status of the assets, and "
            "where applicable, evidence of gift/inheritance through proper channels). In the absence of a "
            "satisfactory reply, the matter shall be decided on the basis of available record.".format(
                sec_str, year),
            new_x="LMARGIN", new_y="NEXT")
    else:
        pdf.set_font("helvetica", "", 9.5)
        pdf.multi_cell(0, 5,
            "No material discrepancy has been noted between your declared income and the assets and "
            "expenditure identified. This communication is issued for record purposes only and requires "
            "no action on your part.", new_x="LMARGIN", new_y="NEXT")

    pdf.ln(10)
    pdf.set_font("helvetica", "", 9)
    pdf.cell(0, 5, "_______________________", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("helvetica", "", 8)
    pdf.set_text_color(*GREY)
    pdf.cell(0, 4, "Inland Revenue Officer", new_x="LMARGIN", new_y="NEXT")
    pdf.cell(0, 4, "Federal Board of Revenue, Government of Pakistan", new_x="LMARGIN", new_y="NEXT")

    out = pdf.output()
    return bytes(out)
