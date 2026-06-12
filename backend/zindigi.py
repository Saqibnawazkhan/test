"""
Zindigi IPG (JS Bank) payment integration. The backend keeps the Secured Key,
fetches the access token server-side, builds the self-submitting checkout form,
and verifies the SHA-256 validation hash on return. LIVE gateway — real money.
"""
import os
import json
import html
import hashlib
import urllib.request
import urllib.parse


def _env(k, d=""):
    return os.environ.get(k, d)


def get_access_token(basket_id, amount):
    """Server-to-server token request (no charge). Empty user-agents are rejected."""
    data = urllib.parse.urlencode({
        "MERCHANT_ID": _env("ZINDIGI_MERCHANT_ID"),
        "SECURED_KEY": _env("ZINDIGI_SECURED_KEY"),
        "BASKET_ID": basket_id,
        "TXNAMT": str(amount),
    }).encode()
    req = urllib.request.Request(_env("ZINDIGI_TOKEN_URL"), data=data,
                                 headers={"User-Agent": "TaxNet/1.0",
                                          "Content-Type": "application/x-www-form-urlencoded"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode()).get("ACCESS_TOKEN", "")


def checkout_html(psid, token, amount, name, email, mobile, desc, order_date):
    """A page that auto-POSTs the transaction form to the Zindigi checkout."""
    base = _env("ZINDIGI_RETURN_BASE")
    ret = base + "/payments/return?psid=" + urllib.parse.quote(psid)
    fields = {
        "CURRENCY_CODE": "PKR",
        "MERCHANT_ID": _env("ZINDIGI_MERCHANT_ID"),
        "MERCHANT_NAME": _env("ZINDIGI_MERCHANT_NAME", "TaxNet"),
        "TOKEN": token,
        "PROCCODE": "00",
        "TXNAMT": str(amount),
        "CUSTOMER_MOBILE_NO": mobile or "03000000000",
        "CUSTOMER_EMAIL_ADDRESS": email or "taxpayer@taxnet.pk",
        "SIGNATURE": "TAXNET-" + psid,
        "VERSION": "TAXNET-1.0",
        "TXNDESC": desc or "FBR tax payment",
        "SUCCESS_URL": ret + "&r=ok",
        "FAILURE_URL": ret + "&r=fail",
        "CHECKOUT_URL": ret + "&ipn=1",
        "BASKET_ID": psid,
        "ORDER_DATE": order_date,
        "TRAN_TYPE": "ECOMM_PURCHASE",
        "CUSTOMER_NAME": name or "Taxpayer",
    }
    inputs = "".join('<input type="hidden" name="{}" value="{}">'.format(k, html.escape(str(v), quote=True))
                     for k, v in fields.items())
    action = html.escape(_env("ZINDIGI_TXN_URL"), quote=True)
    return (
        "<!doctype html><html><head><meta name='viewport' content='width=device-width,initial-scale=1'>"
        "<title>Redirecting to Zindigi…</title></head>"
        "<body style='font-family:sans-serif;text-align:center;padding:40px' onload='document.forms[0].submit()'>"
        "<p>Redirecting to the secure Zindigi payment page…</p>"
        "<form method='post' action='{}'>{}</form></body></html>".format(action, inputs)
    )


def verify_hash(basket_id, err_code, received):
    """validation_hash = sha256("basket|secured_key|merchant_id|err_code")."""
    s = "{}|{}|{}|{}".format(basket_id, _env("ZINDIGI_SECURED_KEY"), _env("ZINDIGI_MERCHANT_ID"), err_code)
    calc = hashlib.sha256(s.encode()).hexdigest()
    return calc.lower() == (received or "").strip().lower()
