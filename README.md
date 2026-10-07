# Remnawave-SelfSteal-Easy

> by [t.me/Sumdevaz](https://t.me/Sumdevaz)

One command sets up the **selfsteal** decoy site (Caddy) for an Xray **VLESS + Reality + Vision** node managed by Remnawave, and generates a ready Xray config. The script asks its questions one at a time.

## Quick start

Before you run it:
1. The A record of your domain (e.g. `nt.example.com`) points to this server. In Cloudflare use **DNS-only** (grey cloud).
2. Port 80 is open from the internet.

Run on the server:

```bash
sudo bash <(curl -fsSL https://raw.githubusercontent.com/sumdevaz1/Remnawave-SelfSteal-Easy/main/install.sh)
```

Then answer the questions:

1. Language (English by default; Русский; Azərbaycanca)
2. Selfsteal domain
3. Local Caddy port (Enter = 9443)
4. Install directory (Enter = /opt/caddy)
5. Confirm

Enter accepts the default in brackets. At the end the script prints the next steps.

**AZ:** yuxarıdakı əmri serverdə işə salın, dili seçin və suallara bir-bir cavab verin. Standart dəyərləri qəbul etmək üçün Enter basın.

**RU:** запустите команду выше на сервере, выберите язык и отвечайте на вопросы по одному. Enter принимает значение по умолчанию.

## What it does

1. Checks that the domain resolves to this server and that port 80 and the local port are free.
2. Installs Docker if missing.
3. Writes `Caddyfile`, `docker-compose.yml`, a placeholder `html/index.html` (an existing one is kept) and `xray-config.generated.json` with a random short ID.
4. Fixes the Docker trap where a missing `Caddyfile` gets created as a directory.
5. Validates the Caddyfile, starts Caddy and waits for the certificate.
6. Optionally prints a fresh x25519 key pair via the `remnanode` container.

Re-running is safe: the old Caddyfile is saved as `Caddyfile.bak.<timestamp>`.

## After install

1. Put your **private** key in `xray-config.generated.json` instead of `<PRIVATE_KEY>`, then paste the JSON into the Remnawave Config Profile for the node.
2. In the Host: SNI = your domain, short ID = the one in the JSON.
3. Refresh the client subscription. The client public key must match the server private key.
4. `curl -I https://nt.example.com` should show your decoy site with a valid certificate.

Replace `html/index.html` with a real-looking site; a bare placeholder is a weak decoy.

## Automation (no questions)

Every question can be answered with a flag; with all flags given nothing is asked:

```bash
sudo bash install.sh --domain nt.example.com --port 9443 --dir /opt/caddy --lang en
```

| Option | Meaning |
|---|---|
| `-d, --domain` | Selfsteal domain (or pass it as the first argument) |
| `-p, --port` | Local Caddy HTTPS port, default `9443` |
| `--dir` | Install directory, default `/opt/caddy` |
| `-l, --lang` | `en` (default), `ru`, `az` |
| `--skip-dns-check` | Do not stop if DNS does not match this server |
| `--files-only` | Only generate files, do not touch Docker |

Without a terminal the script uses defaults (English, port 9443, `/opt/caddy`) and requires `--domain`.

## Invariants

- Xray listens on **443**; Caddy only on `127.0.0.1:<port>` and `:80`.
- `target` = `127.0.0.1:<port>`, `serverNames` = your domain, and the port matches the Caddyfile `https_port`.
- `flow` is `xtls-rprx-vision` on both sides.
- Never use `apple` or `icloud` names in `serverNames`.
- A privateKey that was ever pasted somewhere public must be regenerated.

## Client routing for RU services (optional)

Routing on the node cannot make Russian apps see a Russian IP, because the traffic already exits from the node. Use split routing on the **client**: see `examples/mihomo-ru-routing.yaml`. The `geosite:category-ru` list depends on your mihomo geo database; check the client log if a rule is rejected.

## Files

- `install.sh` - the installer
- `uninstall.sh` - stop Caddy; `--purge` deletes files and volumes (language: `LANG_SEL=ru|az bash uninstall.sh`)
- `examples/xray-config.example.json` - sample Xray config
- `examples/mihomo-ru-routing.yaml` - sample client RU split routing

## Security

Do not commit private keys, `SECRET_KEY`, bot tokens or subscription links. `.gitignore` excludes the generated config.

## License

MIT

---

Author: [t.me/Sumdevaz](https://t.me/Sumdevaz)
