import base64
import hashlib
import os
import stat
import subprocess
import tempfile

from openhop_core import LocalIdentity
from repeater.config import _load_or_create_identity_key

BIN = os.environ["BIN"]


def run(args, key_hex=None, ok=True):
    result = subprocess.run(
        [BIN, *args], input=key_hex, capture_output=True, text=True, check=False
    )
    assert (result.returncode == 0) == ok, f"{args}: exit {result.returncode}\n{result.stdout}{result.stderr}"
    return result


def vector(n):
    return hashlib.sha512(f"openhop-convert-key-{n}".encode()).digest()


# random 64-byte keys include scalars with the top bit set
for n in range(60):
    for key in (vector(n), vector(n)[:32]):
        want = LocalIdentity(seed=key).get_public_key().hex()
        out = run(["--stdin", "--check"], key.hex()).stdout
        assert f"Public key:  {want}" in out, f"public key mismatch for vector {n} ({len(key)} bytes)"
        assert f"0x{int(want[:2], 16):02x}" in out
        assert key.hex() not in out, "the private key must never be printed"
print("public keys match openhop_core for 120 keys")

key = vector(1000)
with tempfile.TemporaryDirectory() as tmp:
    path = os.path.join(tmp, "identity.key")
    out = run(["--stdin", "-o", path], key.hex() + "\n").stdout
    assert key.hex() not in out and base64.b64encode(key).decode() not in out
    assert stat.S_IMODE(os.stat(path).st_mode) == 0o600, "identity file must be mode 0600"
    assert _load_or_create_identity_key(path=path) == key, "the repeater reads back a different key"
    assert LocalIdentity(seed=_load_or_create_identity_key(path=path)).get_public_key().hex() in out

    run(["--stdin", "-o", path], vector(1001).hex(), ok=False)
    assert _load_or_create_identity_key(path=path) == key, "an existing file was overwritten"
    run(["--stdin", "-o", path, "--force"], vector(1001).hex())
    assert _load_or_create_identity_key(path=path) == vector(1001)
    assert stat.S_IMODE(os.stat(path).st_mode) == 0o600

    hexpath = os.path.join(tmp, "companion-key")
    run(["--stdin", "--format", "hex", "-o", hexpath], key.hex())
    assert open(hexpath).read().strip() == key.hex()
    assert stat.S_IMODE(os.stat(hexpath).st_mode) == 0o600

    keyfile = os.path.join(tmp, "key.txt")
    with open(keyfile, "w") as handle:
        handle.write("  0x" + key.hex().upper() + "\n")
    run(["--key-file", keyfile, "--check"])
    assert not os.path.exists(os.path.join(tmp, "identity.key.tmp")), "temporary file left behind"
print("identity and hex files are written correctly, with mode 0600, and never overwrite by accident")

with tempfile.TemporaryDirectory() as tmp:
    target = os.path.join(tmp, "out")
    for bad in ("", "xyz", "ab" * 31, "ab" * 33, "ab" * 65, "00" * 64, "gg" * 64):
        result = run(["--stdin", "-o", target], bad, ok=False)
        assert "error:" in result.stderr, f"no clear error for {bad[:8]!r}"
        assert not os.path.exists(target)
    run(["--stdin"], "ab" * 64, ok=False)
print("bad input is rejected")
