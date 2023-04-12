import io
import re
from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as readme_file:
    long_description = readme_file.read()

package_name = "enso-nic"
name = "enso"


# Hack to avoid having to define metadata twice. Instead define it in the
# `__init__.py`` file. This is adapted from here:
# https://stackoverflow.com/a/39671214/2027390
def find_meta(meta_name):
    return re.search(
        meta_name
        + r'\s*=\s*[\'"]([^\'"]*)[\'"]',  # It excludes inline comment too
        io.open(f"{name}/__init__.py", encoding="utf_8_sig").read(),
    ).group(1)


setup(
    name=package_name,
    version=find_meta("__version__"),
    description="Python frontend for the Ensō NIC.",
    long_description=long_description,
    long_description_content_type="text/markdown",
    packages=find_packages(),
    url="https://github.com/crossroadsfpga/enso",
    download_url="https://github.com/crossroadsfpga/enso",
    license="BSD",
    author=find_meta("__author__"),
    author_email=find_meta("__email__"),
    keywords=["network", "enso", "nic"],
    python_requires=">=3.9",
    entry_points={"console_scripts": ["enso=enso.__main__:main"]},
    include_package_data=True,
    install_requires=["click>=8.0", "netexp==0.1.17", "scapy"],
    # setup_requires=["pytest-runner"],
    # tests_require=["pytest"],
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Science/Research",
        "License :: OSI Approved :: BSD License",
        "Natural Language :: English",
        "Programming Language :: Python",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Topic :: System :: Networking",
        "Topic :: System :: Systems Administration",
    ],
)
