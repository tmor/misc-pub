#!/usr/bin/env python3
#
# Generate LDAP password hash
#
# Requirements:
#  python 3.x
#  pip3 install passlib
#
# Usage:
#   ldap-password.py <hash type> <password>
#
# Links:
#   https://passlib.readthedocs.io/en/stable/lib/passlib.hash.ldap_std.html
#   https://www.openldap.org/faq/data/cache/347.html
#
# Licence:
#   Apache2.0: https://opensource.org/licenses/Apache-2.0
#

import sys
from passlib.hash import ldap_sha1, ldap_salted_sha1

def usage():
    print("Usage: ldap-password.py <sha1|salted_sha1> <password>")
    exit(1)

def generate_ldap_password_hash(hash_type, password):
    hash = ""
    if hash_type == 'sha1':
        # SHA hash
        hash = ldap_sha1.hash(password)
    elif hash_type == 'salted_sha1':
        # SSHA hash with salt
        hash = ldap_salted_sha1.hash(password)
    else:
        print(f"Unsupported hash type: {hash_type}")
        exit(1)
    return hash

def main():
    if len(sys.argv) < 2:
        usage()

    password = ""
    if len(sys.argv) > 2:
        password = sys.argv[2].strip()
    else:
        password = sys.stdin.read().strip()

    if len(password) <= 0:
        print("password is empty.")
        exit(1)

    hash_type = sys.argv[1].lower().strip()
    hash = generate_ldap_password_hash(hash_type, password)

    print(hash)
    return

if __name__ == '__main__':
    main()
