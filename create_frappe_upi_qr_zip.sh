#!/bin/bash
# Creates the frappe_upi_qr app files and packages them into frappe_upi_qr.zip
# Usage:
#   1. Save this script as create_frappe_upi_qr_zip.sh
#   2. Make executable: chmod +x create_frappe_upi_qr_zip.sh
#   3. Run: ./create_frappe_upi_qr_zip.sh
# Output: frappe_upi_qr.zip in the current directory

set -e
WORKDIR="frappe_upi_qr_tmp"
APPDIR="${WORKDIR}/frappe_upi_qr"
TEMPLATEDIR="${APPDIR}/templates/print_formats"

rm -rf "${WORKDIR}"
mkdir -p "${TEMPLATEDIR}"

# README.md
cat > "${WORKDIR}/README.md" <<'EOF'
# Frappe UPI QR (frappe_upi_qr)

Adds UPI QR support to Sales Invoice print format.

Features
- Company custom field `upi_vpa` (Data)
- Sales Invoice custom field `upi_qr` (Text) to store base64 PNG (optional)
- Print Format "Sales Invoice UPI QR" (HTML) that shows a UPI QR (uses external QR image API by default)
- Server helper to generate base64 QR images (requires `qrcode[pil]`)

Install
1. Push this repository to GitHub.
2. In Frappe Cloud, add the app repository and install it to a site (Cloud UI -> Add App).
   - Alternatively: on a bench environment:
     - bench get-app <git-url>
     - bench --site <site> install-app frappe_upi_qr

Notes
- By default the Print Format uses https://api.qrserver.com to fetch PNG QR images. If you prefer to avoid external requests, enable server-side generation and ensure `qrcode[pil]` and `Pillow` are available (requirements included).
- The app's after_install hook will create the custom fields and Print Format automatically.

Usage
- Set your UPI VPA on Company (new field "UPI VPA") or at Sales Invoice level.
- Open a Sales Invoice and print with Print Format "Sales Invoice UPI QR".
- Optionally call the whitelisted method `frappe_upi_qr.api.get_upi_qr` to generate and save a base64 QR in `doc.upi_qr`.
EOF

# setup.py
cat > "${WORKDIR}/setup.py" <<'EOF'
from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

setup(
    name="frappe_upi_qr",
    version="0.0.1",
    description="UPI QR for Sales Invoice Print Format",
    long_description=long_description,
    long_description_content_type="text/markdown",
    author="You",
    packages=find_packages(),
    zip_safe=False,
    include_package_data=True,
    install_requires=[],
    classifiers=[
        "Framework :: Frappe",
    ],
)
EOF

# requirements.txt
cat > "${WORKDIR}/requirements.txt" <<'EOF'
# Optional server-side QR generation dependency.
qrcode[pil]
Pillow
EOF

# .gitignore
cat > "${WORKDIR}/.gitignore" <<'EOF'
*.pyc
__pycache__/
.env
.DS_Store
.vscode/
EOF

# frappe_upi_qr/__init__.py
mkdir -p "${APPDIR}"
cat > "${APPDIR}/__init__.py" <<'EOF'
from . import __version__  # noqa: F401
EOF

# frappe_upi_qr/__version__.py
cat > "${APPDIR}/__version__.py" <<'EOF'
__version__ = "0.0.1"
EOF

# frappe_upi_qr/hooks.py
cat > "${APPDIR}/hooks.py" <<'EOF'
app_name = "frappe_upi_qr"
app_title = "Frappe UPI QR"
app_publisher = "You"
app_description = "Embed UPI QR in Sales Invoice print format"
app_icon = "octicon octicon-file-directory"
app_color = "grey"
app_email = "you@example.com"
app_license = "MIT"

# After install hook to create custom fields and print format
after_install = "frappe_upi_qr.install.after_install"

# Optionally enable doc_events to auto-generate QR on submit:
# doc_events = {
#     "Sales Invoice": {
#         "on_submit": "frappe_upi_qr.api.maybe_generate_and_save_qr"
#     }
# }
EOF

# frappe_upi_qr/install.py
cat > "${APPDIR}/install.py" <<'EOF'
import frappe
import os

PRINT_FORMAT_NAME = "Sales Invoice UPI QR"

def create_custom_field(dt, fieldname, label, fieldtype="Data", insert_after=None, options=None):
    if not frappe.db.exists("Custom Field", {"dt": dt, "fieldname": fieldname}):
        cf = frappe.get_doc({
            "doctype": "Custom Field",
            "dt": dt,
            "fieldname": fieldname,
            "label": label,
            "fieldtype": fieldtype,
            "insert_after": insert_after or "company_address",
        })
        if options:
            cf.options = options
        cf.insert(ignore_permissions=True)
        frappe.db.commit()
        frappe.msgprint(f"Created Custom Field {dt}.{fieldname}")

def create_print_format():
    if frappe.db.exists("Print Format", PRINT_FORMAT_NAME):
        return

    # Read bundled HTML template
    tmpl_path = os.path.join(frappe.get_app_path("frappe_upi_qr"), "templates", "print_formats", "sales_invoice_upi_qr.html")
    html = ""
    if os.path.exists(tmpl_path):
        with open(tmpl_path, "r", encoding="utf-8") as f:
            html = f.read()

    if not html:
        frappe.msgprint("Print format HTML template not found in app.")
        return

    pf = frappe.get_doc({
        "doctype": "Print Format",
        "print_format_name": PRINT_FORMAT_NAME,
        "doc_type": "Sales Invoice",
        "html": html,
        "standard": "No"
    })
    pf.insert(ignore_permissions=True)
    frappe.db.commit()
    frappe.msgprint(f"Created Print Format '{PRINT_FORMAT_NAME}'")

def after_install():
    try:
        # Company: UPI VPA
        create_custom_field("Company", "upi_vpa", "UPI VPA", fieldtype="Data", insert_after="default_currency")
        # Sales Invoice: UPI QR (text to store base64 if desired)
        create_custom_field("Sales Invoice", "upi_qr", "UPI QR (Base64 PNG)", fieldtype="Text", insert_after="rounded_total")
        # Create Print Format
        create_print_format()
    except Exception:
        frappe.log_error(frappe.get_traceback())
        raise
EOF

# frappe_upi_qr/templates/print_formats/sales_invoice_upi_qr.html
mkdir -p "${TEMPLATEDIR}"
cat > "${TEMPLATEDIR}/sales_invoice_upi_qr.html" <<'EOF'
<!--
Print Format HTML: Sales Invoice UPI QR
This template expects standard 'doc' and 'frappe' context from Frappe print rendering.
It builds a UPI URI and fetches a QR from api.qrserver.com.
If you prefer server-generated base64 PNG, ensure `doc.upi_qr` contains a data URL and the <img> will use it.
-->
<div class="print-format" style="font-family: Arial, sans-serif;">
  <div style="margin-bottom: 8px;">
    <h3 style="margin: 0;">Sales Invoice: {{ doc.name }}</h3>
    <div style="font-size: 12px; color: #555;">Customer: {{ doc.customer_name }}</div>
  </div>

  {% set company_doc = frappe.get_doc("Company", doc.company) %}
  {% set upi_vpa = (doc.get("upi_vpa") or company_doc.get("upi_vpa") or frappe.db.get_value("Company", doc.company, "upi_vpa")) %}
  {% if upi_vpa %}
    {% set amount = ('%.2f' % (doc.grand_total or 0.0)) %}
    {% set payee = (company_doc.get("company_name") or company_doc.get("name") or '') %}
    {% set tn = "Invoice%20" + (doc.name or '') %}
    {% set upi_uri = 'upi://pay?pa=' + upi_vpa + '&pn=' + payee + '&am=' + amount + '&cu=INR&tn=' + tn %}
    <div style="margin-top:20px; text-align:center;">
      <div style="display:inline-block; text-align:center;">
        {% if doc.get("upi_qr") %}
          <!-- Use embedded base64 image if present -->
          <img src="{{ doc.upi_qr }}" alt="UPI QR" style="width:200px; height:200px; display:block; margin:0 auto;" />
        {% else %}
          <!-- Fallback: use public QR image service -->
          <img src="https://api.qrserver.com/v1/create-qr-code/?size=200x200&data={{ upi_uri|urlencode }}" alt="UPI QR" style="width:200px; height:200px; display:block; margin:0 auto;" />
        {% endif %}
        <div style="font-size:12px; margin-top:8px;">
          Pay to: <strong>{{ upi_vpa }}</strong><br>
          Amount: <strong>₹{{ amount }}</strong>
        </div>
      </div>
    </div>
  {% else %}
    <div style="margin-top:20px; color:#a00;">
      UPI VPA is not configured. Please set the Company: UPI VPA custom field or the Sales Invoice UPI VPA field.
    </div>
  {% endif %}
</div>
EOF

# frappe_upi_qr/upi_qr.py
cat > "${APPDIR}/upi_qr.py" <<'EOF'
import io
import base64

import frappe

try:
    import qrcode
    from PIL import Image
    QR_AVAILABLE = True
except Exception:
    QR_AVAILABLE = False


def generate_upi_uri(upi_vpa, amount, invoice_name=None, payee_name=None):
    amount_str = "%.2f" % float(amount or 0.0)
    tn = "Invoice {}".format(invoice_name or "")
    # Basic UPI URI
    parts = {
        "pa": upi_vpa,
        "pn": payee_name or "",
        "am": amount_str,
        "cu": "INR",
        "tn": tn
    }
    uri = "upi://pay?pa={pa}&pn={pn}&am={am}&cu={cu}&tn={tn}".format(**parts)
    return uri


def generate_upi_qr_dataurl(upi_vpa, amount, invoice_name=None, payee_name=None):
    """
    Returns data URL (data:image/png;base64,...) if qrcode is available.
    Otherwise returns None.
    """
    if not QR_AVAILABLE:
        frappe.log("frappe_upi_qr: qrcode library not available; server-side QR generation disabled.")
        return None

    uri = generate_upi_uri(upi_vpa, amount, invoice_name, payee_name)

    qr = qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_M, box_size=6, border=2)
    qr.add_data(uri)
    qr.make(fit=True)
    img = qr.make_image(fill_color="black", back_color="white")

    buffer = io.BytesIO()
    img.save(buffer, format="PNG")
    b64 = base64.b64encode(buffer.getvalue()).decode("ascii")
    return "data:image/png;base64," + b64
EOF

# frappe_upi_qr/api.py
cat > "${APPDIR}/api.py" <<'EOF'
import frappe
from frappe import _

from .upi_qr import generate_upi_qr_dataurl


@frappe.whitelist()
def get_upi_qr(invoice_name):
    """
    Whitelisted method to return a data URL for the invoice UPI QR or save it to the Sales Invoice.

    Usage (client):
      frappe.call('frappe_upi_qr.api.get_upi_qr', { invoice_name: 'SINV-0001' })

    Returns:
      {"dataurl": "<data:image/png;base64,...>"} or {"error": "..."}

    Note: qrcode & pillow must be present for server-side generation.
    """
    if not invoice_name:
        frappe.throw(_("invoice_name is required"))

    doc = frappe.get_doc("Sales Invoice", invoice_name)
    upi_vpa = doc.get("upi_vpa") or frappe.db.get_value("Company", doc.company, "upi_vpa")
    if not upi_vpa:
        return {"error": "UPI VPA not configured on Invoice or Company"}

    amount = doc.get("grand_total") or 0.0
    payee = frappe.db.get_value("Company", doc.company, "company_name") or doc.company

    dataurl = generate_upi_qr_dataurl(upi_vpa, amount, invoice_name, payee)
    if not dataurl:
        return {"error": "Server-side QR generation not available (missing library)."}

    # Optionally store it on the invoice
    try:
        doc.db_set("upi_qr", dataurl)
    except Exception:
        frappe.log_error(frappe.get_traceback(), "frappe_upi_qr: could not save upi_qr")

    return {"dataurl": dataurl}
EOF

# create zip
ZIPNAME="frappe_upi_qr.zip"
rm -f "${ZIPNAME}"
( cd "${WORKDIR}" && zip -r "../${ZIPNAME}" . )

# cleanup temp folder
rm -rf "${WORKDIR}"

echo "Created ${ZIPNAME} in $(pwd)"
echo "Unzip with: unzip ${ZIPNAME}"