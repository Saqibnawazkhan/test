"""
Grounded TaxNet chatbot. Claude is the NARRATOR only — it answers strictly from
the verified KB, cites the legal basis, calls deterministic tools for any number,
defers to FBR when a question is outside the verified knowledge, and replies in
the user's language (English/Urdu). It never invents rates, sections or amounts.
"""
import os
import json
from anthropic import Anthropic
from tax_calc import compute_tax
from kb import KB_TEXT

MODEL = "claude-haiku-4-5-20251001"

_RULES = """You are "TaxNet AI", an assistant for taxpayers and tax officers in Pakistan (FBR).
Reference year: FY2025-26 (Tax Year 2026), Income Tax Ordinance 2001 as amended by Finance Act 2025.

ABSOLUTE RULES (accuracy is mandatory — do NOT break these):
1. Answer ONLY from the VERIFIED FBR KNOWLEDGE below. NEVER invent or guess rates, sections, thresholds, dates or amounts.
2. ALWAYS cite the legal basis you used (e.g., "Section 236K, Income Tax Ordinance 2001"). Put it at the end of the answer. ONLY cite section numbers that appear in the VERIFIED FBR KNOWLEDGE below — never cite any other section number from memory.
3. For ANY income-tax amount, you MUST call the calculate_income_tax tool. Never compute income tax yourself.
4. For property/vehicle exact figures (which depend on value/engine/province slabs), state the verified principle + citation, then advise confirming the exact amount with FBR — do not fabricate a number.
5. If a question is outside the verified knowledge, say clearly that you do not have verified FBR information on it and advise consulting FBR (fbr.gov.pk) or a qualified tax advisor. Do NOT guess.
6. Reply in the SAME language as the user: if they write in Urdu, answer in Urdu; otherwise English. Keep numbers/sections in figures.
7. AMOUNTS: users often write amounts in lakh/crore — 1 lakh = 100,000; 1 crore = 10,000,000. Convert before calculating. Also tolerate typos (e.g. "selfie"/"salry" likely means "salary").
8. INTENT: if the user gives a salary/income amount and asks how much tax they owe, treat it as an INCOME-TAX question and use calculate_income_tax — do NOT assume property/sale/purchase unless they explicitly mention property, plot, house, sale or purchase. If they do NOT say whether the figure is monthly or annual, show BOTH: (a) treating it as the ANNUAL income, and (b) treating it as a MONTHLY income (multiply by 12 first), giving the tax for each via the tool, so they can pick. Default type is salaried unless they say business.
7. Be concise, factual, and never speculate. End substantive answers with: "For your specific case, please verify with FBR."

VERIFIED FBR KNOWLEDGE:
"""

_TOOLS = [{
    "name": "calculate_income_tax",
    "description": "Compute the exact FBR income tax for a given ANNUAL taxable income. Use for any income-tax amount question.",
    "input_schema": {
        "type": "object",
        "properties": {
            "income": {"type": "number", "description": "annual taxable income in PKR"},
            "year": {"type": "string", "enum": ["2024-25", "2025-26"], "description": "tax year, default 2025-26"},
            "kind": {"type": "string", "enum": ["salaried", "business"], "description": "taxpayer type, default salaried"},
        },
        "required": ["income"],
    },
}]


def _client():
    key = os.environ.get("ANTHROPIC_API_KEY", "")
    if not key or key == "REPLACE_ANTHROPIC_KEY":
        raise RuntimeError("no_api_key")
    return Anthropic(api_key=key)


def chat(messages, system_extra=""):
    """messages: [{role:'user'|'assistant', content:str}]. Returns reply text."""
    client = _client()
    system = _RULES + KB_TEXT + system_extra
    msgs = [{"role": m["role"], "content": m["content"]} for m in messages if m.get("content")]

    for _ in range(4):  # allow a couple of tool-use rounds
        resp = client.messages.create(model=MODEL, max_tokens=1000, system=system, tools=_TOOLS, messages=msgs)
        if resp.stop_reason == "tool_use":
            msgs.append({"role": "assistant", "content": resp.content})
            results = []
            for block in resp.content:
                if block.type == "tool_use" and block.name == "calculate_income_tax":
                    a = block.input or {}
                    out = compute_tax(a.get("income", 0), a.get("year", "2025-26"), a.get("kind", "salaried"))
                    results.append({"type": "tool_result", "tool_use_id": block.id, "content": json.dumps(out)})
            msgs.append({"role": "user", "content": results})
            continue
        return "".join(b.text for b in resp.content if b.type == "text").strip()
    return "Sorry, I could not complete that request."
