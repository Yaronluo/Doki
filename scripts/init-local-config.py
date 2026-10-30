#!/usr/bin/env python3
"""Create a private local Hub config without printing or overwriting secrets."""
import argparse
import base64
import os
from pathlib import Path

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, default=root / '.env')
args = parser.parse_args()
values = {
    'HUB_PORT': '18080',
    'HUB_BASE_URL': 'http://127.0.0.1:18080',
    'DATABASE_URL': 'postgres://postgres@127.0.0.1:55432/doki_hub',
    'BGM_REDIRECT_URI': '',
    'CREDENTIAL_ENCRYPTION_KEY': base64.b64encode(os.urandom(32)).decode(),
    'STREAM_SIGNING_KEY': base64.b64encode(os.urandom(32)).decode(),
}
lines = []
for line in (root / '.env.example').read_text().splitlines():
    key = line.partition('=')[0]
    lines.append(key + '=' + values[key] if key in values and not line.startswith('#') else line)
# Exclusive creation and private mode: an existing configuration is never touched.
fd = os.open(args.output, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
with os.fdopen(fd, 'w') as handle:
    handle.write('\n'.join(lines) + '\n')
print(f'Created private local configuration: {args.output.resolve()}')
print('Provider credentials remain empty. Edit locally; do not paste them into chat.')
