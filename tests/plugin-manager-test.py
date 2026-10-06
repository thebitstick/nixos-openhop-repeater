import json
import socket
import sys

sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
sock.settimeout(10)
sock.connect(sys.argv[1])
sock.sendall(json.dumps({"id": 1, "op": "list"}).encode() + b"\n")
reply = json.loads(sock.makefile("rb").readline())

assert reply.get("ok") is True and reply.get("id") == 1, reply
assert reply["result"]["plugins"] == [], reply
print("plugin manager answered the dashboard's list request")
