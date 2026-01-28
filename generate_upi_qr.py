# Example helper to generate a base64 PNG for a UPI URI (use inside a Frappe app or server script)
# Requires: pip install qrcode[pil]

import qrcode
import io
import base64

def generate_upi_qr_dataurl(upi_vpa, amount, invoice_name, payee_name):
    """
    Returns: data:image/png;base64,<base64png>
    Example UPI URI: upi://pay?pa=vpa@bank&pn=Payee+Name&am=123.45&cu=INR&tn=Invoice%20INV-0001
    """
    if not upi_vpa:
        return None

    amount_str = "%.2f" % float(amount or 0.0)
    tn = "Invoice {}".format(invoice_name or "")
    # Build UPI URI
    uri = "upi://pay?pa={pa}&pn={pn}&am={am}&cu=INR&tn={tn}".format(
        pa=upi_vpa, pn=payee_name or "", am=amount_str, tn=tn
    )

    # Generate QR code image
    qr = qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_M, box_size=6, border=2)
    qr.add_data(uri)
    qr.make(fit=True)
    img = qr.make_image(fill_color="black", back_color="white")

    buffer = io.BytesIO()
    img.save(buffer, format="PNG")
    b64 = base64.b64encode(buffer.getvalue()).decode("ascii")
    return "data:image/png;base64," + b64

# Example usage:
# dataurl = generate_upi_qr_dataurl("merchant@upi", 123.45, "SINV-0001", "My Company")
# store dataurl to a custom field doc.upi_qr (Data) or pass it to print context