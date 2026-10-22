#!/usr/bin/env python3

"""
Password hashing helpers for the System Matrix dashboard.

Hash format:
    pbkdf2_sha256$<iterations>$<base64 salt>$<base64 derived key>

Every hash uses a random 16-byte salt. Unsalted SHA-256 hashes are accepted
for verification only, so existing installations can migrate. Run
scripts/utilities/change-dashboard-password.sh to replace a legacy hash.

Usage:
    printf '%s' "$PASSWORD" | python3 dashboard_auth.py hash
"""

import base64
import hashlib
import hmac
import secrets
import sys

HASH_PREFIX = "pbkdf2_sha256"
DEFAULT_ITERATIONS = 600_000
SALT_BYTES = 16
MAX_ITERATIONS = 10_000_000


def hash_password(password, iterations=DEFAULT_ITERATIONS, salt=None):
    """Return a salted PBKDF2-HMAC-SHA256 hash for the password."""
    if isinstance(password, str):
        password = password.encode("utf-8")
    if salt is None:
        salt = secrets.token_bytes(SALT_BYTES)
    derived = hashlib.pbkdf2_hmac("sha256", password, salt, iterations)
    salt_b64 = base64.b64encode(salt).decode("ascii")
    hash_b64 = base64.b64encode(derived).decode("ascii")
    return f"{HASH_PREFIX}${iterations}${salt_b64}${hash_b64}"


def is_legacy_hash(stored_hash):
    """Return True for an unsalted SHA-256 hex hash (legacy, migration only)."""
    if not isinstance(stored_hash, str) or len(stored_hash) != 64:
        return False
    return all(character in "0123456789abcdefABCDEF" for character in stored_hash)


def verify_password(password, stored_hash):
    """Verify a password against a PBKDF2 hash or a legacy SHA-256 hash."""
    if isinstance(password, str):
        password = password.encode("utf-8")

    if isinstance(stored_hash, str) and stored_hash.startswith(HASH_PREFIX + "$"):
        try:
            _, iterations_text, salt_b64, hash_b64 = stored_hash.split("$")
            iterations = int(iterations_text)
            if not 1 <= iterations <= MAX_ITERATIONS:
                return False
            salt = base64.b64decode(salt_b64, validate=True)
            expected = base64.b64decode(hash_b64, validate=True)
        except (ValueError, TypeError):
            return False

        derived = hashlib.pbkdf2_hmac("sha256", password, salt, iterations)
        return hmac.compare_digest(derived, expected)

    if is_legacy_hash(stored_hash):
        legacy = hashlib.sha256(password).hexdigest()
        return hmac.compare_digest(legacy, stored_hash.lower())

    return False


def main(argv):
    if len(argv) != 2 or argv[1] != "hash":
        print("Usage: printf '%s' \"$PASSWORD\" | dashboard_auth.py hash", file=sys.stderr)
        return 2

    password = sys.stdin.buffer.read()
    if not password:
        print("ERROR: empty password on stdin", file=sys.stderr)
        return 2

    print(hash_password(password))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
