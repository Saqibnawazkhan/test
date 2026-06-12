"""
Email delivery via Resend (notices + broadcasts). Cloudflare in front of the API
blocks the default urllib user-agent, so we always send a proper one. FROM uses
the verified domain (RESEND_FROM). A global cap (EMAIL_SEND_CAP) guards cost.
"""
import os
import json
import base64
import urllib.request


def _key():
    return os.environ.get("RESEND_API_KEY", "")


def send_email(to, subject, html, pdf_bytes=None, pdf_name="document.pdf"):
    if not _key():
        raise RuntimeError("no_resend_key")
    payload = {
        "from": os.environ.get("RESEND_FROM", "onboarding@resend.dev"),
        "to": [to] if isinstance(to, str) else to,
        "subject": subject,
        "html": html,
    }
    if pdf_bytes:
        payload["attachments"] = [{"filename": pdf_name, "content": base64.b64encode(pdf_bytes).decode()}]
    req = urllib.request.Request("https://api.resend.com/emails", data=json.dumps(payload).encode(),
                                 headers={"Authorization": "Bearer " + _key(),
                                          "Content-Type": "application/json",
                                          "User-Agent": "TaxNet/1.0 (+https://orbitpk.com)"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode())


def notice_html(name, cnic, notice_text):
    """Wrap the show-cause notice text in a simple branded HTML email."""
    body = notice_text.replace("\n", "<br>")
    return (
        "<div style='font-family:Segoe UI,Arial,sans-serif;max-width:640px;margin:auto'>"
        "<div style='background:#1AA978;color:#fff;padding:16px 20px'>"
        "<h2 style='margin:0'>Federal Board of Revenue</h2>"
        "<div style='font-size:13px;opacity:.9'>Inland Revenue &mdash; Show-Cause Notice</div></div>"
        "<div style='padding:20px;color:#101926;font-size:14px;line-height:1.5'>"
        "<p>Dear {name},</p>{body}"
        "<p style='margin-top:18px;color:#667;font-size:12px'>The full statutory notice is attached as a PDF. "
        "If you believe this is in error, you may respond through FBR (fbr.gov.pk) within the stated period.</p>"
        "</div></div>"
    ).format(name=name or "Taxpayer", body=body)


def broadcast_html(title, message):
    return (
        "<div style='font-family:Segoe UI,Arial,sans-serif;max-width:640px;margin:auto'>"
        "<div style='background:#2E6FE0;color:#fff;padding:16px 20px'>"
        "<h2 style='margin:0'>Federal Board of Revenue</h2>"
        "<div style='font-size:13px;opacity:.9'>Public Announcement</div></div>"
        "<div style='padding:20px;color:#101926;font-size:14px;line-height:1.5'>"
        "<h3 style='margin-top:0'>{title}</h3><p>{message}</p>"
        "<p style='color:#667;font-size:12px'>&mdash; Federal Board of Revenue</p>"
        "</div></div>"
    ).format(title=title, message=message)
