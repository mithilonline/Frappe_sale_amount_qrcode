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
- The app's after_install hook will create the custom fields and print format automatically.

Usage
- Set your UPI VPA on Company (new field "UPI VPA") or at Sales Invoice level.
- Open a Sales Invoice and print with Print Format "Sales Invoice UPI QR".
- Optionally call the whitelisted method `frappe_upi_qr.api.get_upi_qr` to generate and save a base64 QR in `doc.upi_qr`.