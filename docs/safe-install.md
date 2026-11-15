# Installing from a script

Don't tell users to run `curl ... | bash`. They run whatever the server sends at that moment, and a dropped connection
can run half a script. Publish the script's SHA-256 with each release and have the docs check it before running. Background:
[A Safer curl | bash](https://awalsh128.com/safer-curl-bash/).

## Publish the hash

Upload `install.sh` as a release asset and put its hash in the release notes, so the hash lives on the release page, not
beside a copy of the script that someone could change along with it.

```bash
sha256sum install.sh | awk '{print $1}'
```

## Docs layout (progressive discovery)

Show the shortest safe path first, then add detail only for readers who need it.

1. **Install**: the check-then-run command below, with the hash copied from the release notes.
2. **Options**: the same command with arguments after `install.sh`.
3. **Read it first**: drop the last line, then `less install.sh` once the check passes.

```bash
PUB_SHA256="<install.sh SHA-256 from the release notes>"
curl -q --proto '=https' --tlsv1.2 -fsSLO https://github.com/OWNER/REPO/releases/download/TAG/install.sh &&
printf '%s  %s\n' "$PUB_SHA256" 'install.sh' | sha256sum --check &&
bash install.sh
```

On macOS use `shasum -a 256 --check`. Link the release page so the hash is easy to find.

## One-liner helper

[`scripts/safe_fetch_exec.sh`](../scripts/safe_fetch_exec.sh) does the same in one call, with size and time limits, and
runs the script in a clean `bash`:

```bash
scripts/safe_fetch_exec.sh "$PUB_SHA256" https://github.com/OWNER/REPO/releases/download/TAG/install.sh --prefix "$HOME/.local"
scripts/safe_fetch_exec.sh --dry-run "$PUB_SHA256" https://.../install.sh   # print instead of run
```

The hash only proves you got the bytes the publisher listed. It is not a sandbox; read the script.
