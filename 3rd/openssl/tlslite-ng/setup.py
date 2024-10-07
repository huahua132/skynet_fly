#!/usr/bin/env python

# Author: Trevor Perrin
# See the LICENSE file for legal information regarding use of this file.

from distutils.core import setup
import os

here = os.path.abspath(os.path.dirname(__file__))
with open(os.path.join(here, "README")) as f:
    README = f.read()

setup(name="tlslite-ng",
      version="0.8.0-alpha42",
      author="Hubert Kario",
      author_email="hkario@redhat.com",
      url="https://github.com/tlsfuzzer/tlslite-ng",
      description="Pure python implementation of SSL and TLS.",
      long_description=README,
      license="LGPLv2",
      scripts=["scripts/tls.py", "scripts/tlsdb.py"],
      packages=["tlslite", "tlslite.utils", "tlslite.integration"],
      package_data={
                    'package1': ['LICENSE', 'README.md']},
      install_requires=['ecdsa>=0.18.0b1'],
      obsoletes=["tlslite"],
      python_requires=">=2.6, !=3.0.*, !=3.1.*, !=3.2.*",
      classifiers=[
            'Development Status :: 4 - Beta',
            'Intended Audience :: Developers',
            'License :: OSI Approved :: GNU Lesser General Public License v2 (LGPLv2)',
            'Operating System :: OS Independent',
            'Programming Language :: Python',
            'Programming Language :: Python :: 2',
            'Programming Language :: Python :: 2.6',
            'Programming Language :: Python :: 2.7',
            'Programming Language :: Python :: 3',
            'Programming Language :: Python :: 3.3',
            'Programming Language :: Python :: 3.4',
            'Programming Language :: Python :: 3.5',
            'Programming Language :: Python :: 3.6',
            'Programming Language :: Python :: 3.7',
            'Programming Language :: Python :: 3.8',
            'Programming Language :: Python :: 3.9',
            'Topic :: Security :: Cryptography',
            'Topic :: Software Development :: Libraries :: Python Modules',
            'Topic :: System :: Networking'
          ],
      keywords="ssl, tls, pure-python"
      )
