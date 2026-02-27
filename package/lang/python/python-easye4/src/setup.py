from setuptools import setup, find_packages

setup(
    name="easye4",
    version="1.0.0",
    packages=find_packages(),
    install_requires=[
        "requests",
    ],
    description="Eaton easyE4 API Python Package",
    entry_points={
        "console_scripts": [
            "easye4_service = easye4.service:main",
        ],
    },
)
