#!/usr/bin/env python3
"""Setup script for opencli"""

from setuptools import setup, find_packages

setup(
    name="opencli",
    version="0.1.0",
    description="AI-assisted programming CLI tool",
    author="Your Name",
    author_email="your.email@example.com",
    packages=find_packages(),
    py_modules=["cli", "config"],
    python_requires=">=3.8",
    install_requires=[
        "anthropic>=0.25.0",
        "pyyaml>=6.0",
    ],
    entry_points={
        "console_scripts": [
            "opencli=cli:main",
        ],
    },
    classifiers=[
        "Development Status :: 3 - Alpha",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
    ],
)
