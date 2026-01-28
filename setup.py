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