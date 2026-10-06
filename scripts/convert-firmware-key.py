#!/usr/bin/env python3
"""Convert a MeshCore private key into a key file that openHop Repeater can use.

A MeshCore device's private key is 64 bytes (128 hex characters): a 32-byte scalar followed by a 32-byte
nonce. openHop Repeater keeps its identity in `identity.key`, which holds those bytes base64 encoded. This
tool does that conversion, so the repeater gets the same public key (the same node address) as the device.

The key is read from a hidden prompt, from a file or from standard input, never from the command line, where
other users could see it in the process list. It is never printed. The tool prints the *public* key, so you
can compare it with what your MeshCore app shows before you rely on the result.

  openhop-convert-key -o identity.key                       # prompts for the key (input hidden)
  openhop-convert-key --key-file key.txt -o identity.key
  openhop-convert-key --stdin --check < key.txt             # only show the public key, write nothing
  openhop-convert-key --format hex -o companion-key         # file for companion / room server identities

Uses only the Python standard library.
"""

import argparse
import base64
import getpass
import hashlib
import os
import sys

# --- Ed25519 public key derivation (RFC 8032), enough to show which node a key belongs to -------------

P = 2**255 - 19
D = -121665 * pow(121666, P - 2, P) % P


def _inv(x):
    return pow(x, P - 2, P)


def _recover_x(y, sign):
    x2 = (y * y - 1) * _inv(D * y * y + 1) % P
    x = pow(x2, (P + 3) // 8, P)
    if (x * x - x2) % P:
        x = x * pow(2, (P - 1) // 4, P) % P
    if (x * x - x2) % P:
        raise ValueError("not a point on the curve")
    return P - x if (x & 1) != sign else x


_GY = 4 * _inv(5) % P
_GX = _recover_x(_GY, 0)
BASE = (_GX, _GY, 1, _GX * _GY % P)


def _add(a, b):
    A = (a[1] - a[0]) * (b[1] - b[0]) % P
    B = (a[1] + a[0]) * (b[1] + b[0]) % P
    C = 2 * a[3] * b[3] * D % P
    E = 2 * a[2] * b[2] % P
    F, G, H, I = B - A, E - C, E + C, B + A
    return (F * G % P, H * I % P, G * H % P, F * I % P)


def _multiply(scalar, point):
    result = (0, 1, 1, 0)
    while scalar:
        if scalar & 1:
            result = _add(result, point)
        point = _add(point, point)
        scalar >>= 1
    return result


def _compress(point):
    zinv = _inv(point[2])
    x, y = point[0] * zinv % P, point[1] * zinv % P
    return (y | ((x & 1) << 255)).to_bytes(32, "little")


def public_key(key):
    """Public key of a 32-byte seed or a 64-byte MeshCore key, as openhop_core derives it."""
    if len(key) == 64:
        # MeshCore expanded key: the first 32 bytes are the scalar, used without clamping. Like libsodium's
        # crypto_scalarmult_ed25519_base_noclamp, which openhop_core calls, bit 255 is ignored.
        # (Keys made by MeshCore are clamped, so that bit is already clear in them.)
        scalar = int.from_bytes(key[:32], "little") & ((1 << 255) - 1)
    else:
        expanded = bytearray(hashlib.sha512(key).digest()[:32])
        expanded[0] &= 248
        expanded[31] &= 127
        expanded[31] |= 64
        scalar = int.from_bytes(expanded, "little")
    return _compress(_multiply(scalar, BASE))


# --- command line ---------------------------------------------------------------------------------------


def parse_key(text):
    cleaned = "".join(text.split())
    if cleaned[:2].lower() == "0x":
        cleaned = cleaned[2:]
    try:
        key = bytes.fromhex(cleaned)
    except ValueError:
        sys.exit("error: the key must be hexadecimal characters only (0-9, a-f)")
    if len(key) not in (32, 64):
        sys.exit(
            f"error: expected 64 hex characters (a 32-byte seed) or 128 (a MeshCore key), "
            f"got {len(cleaned)}"
        )
    if not any(key):
        sys.exit("error: that key is all zeros")
    return key


def read_key(args):
    if args.key_file:
        with open(args.key_file) as handle:
            return parse_key(handle.read())
    if args.stdin:
        return parse_key(sys.stdin.read())
    if not sys.stdin.isatty():
        sys.exit("error: no terminal to prompt on; use --stdin or --key-file")
    return parse_key(getpass.getpass("MeshCore private key (hex, input hidden): "))


def write_private(path, data, force):
    if os.path.lexists(path) and not force:
        sys.exit(f"error: {path} already exists; use --force to replace it")
    temporary = f"{path}.tmp"
    if os.path.lexists(temporary):
        os.unlink(temporary)
    descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "wb") as handle:
        handle.write(data)
    os.replace(temporary, path)


def main():
    parser = argparse.ArgumentParser(
        description="Convert a MeshCore private key into an openHop Repeater key file.",
        epilog="The key is never taken as an argument and never printed.",
    )
    source = parser.add_mutually_exclusive_group()
    source.add_argument("--key-file", metavar="FILE", help="read the hex key from FILE")
    source.add_argument("--stdin", action="store_true", help="read the hex key from standard input")
    parser.add_argument("-o", "--output", metavar="PATH", help="file to write (created with mode 0600)")
    parser.add_argument(
        "--format",
        choices=["identity", "hex"],
        default="identity",
        help="identity: base64, for the repeater's own identity.key (default). "
        "hex: for companion and room server key files",
    )
    parser.add_argument("--check", action="store_true", help="only show the public key; write nothing")
    parser.add_argument("--force", action="store_true", help="replace the output file if it exists")
    args = parser.parse_args()

    if not args.check and not args.output:
        parser.error("give -o PATH to write a file, or --check to only show the public key")

    key = read_key(args)
    public = public_key(key)

    kind = "MeshCore firmware key (scalar + nonce)" if len(key) == 64 else "32-byte seed"
    print(f"Key type:    {kind}")
    print(f"Public key:  {public.hex()}")
    print(f"Node hash:   0x{public[0]:02x}")
    if public[0] in (0x00, 0xFF):
        print(
            "warning: MeshCore devices never use a public key starting with 00 or ff, "
            "so this may not be a valid MeshCore key",
            file=sys.stderr,
        )

    if args.check:
        print("Nothing written (--check).")
        return

    if args.format == "identity":
        data = base64.b64encode(key)
    else:
        data = key.hex().encode() + b"\n"
    write_private(args.output, data, args.force)
    print(f"Wrote:       {args.output} (mode 0600, format {args.format})")
    if args.format == "identity":
        print(f'Next:        services.openhop-repeater.repeater.identityKeyFile = "{args.output}";')
    else:
        print(f'Next:        use it as a companion or room server identityKeyFile = "{args.output}";')
    print("Compare the public key above with your MeshCore app before relying on it.")


if __name__ == "__main__":
    main()
