#!/usr/bin/env bash
# Remnawave-SelfSteal-Easy
# One-command selfsteal Caddy setup for Xray Reality nodes (Remnawave).
# Languages: English (default), Russian, Azerbaijani.
# Author: t.me/Sumdevaz
# Usage: sudo bash install.sh        (interactive: asks one question at a time)
#        sudo bash install.sh --domain nt.example.com [--lang en|ru|az] [--port 9443] [--dir /opt/caddy]
set -euo pipefail

DOMAIN=""
PORT=""
DIR=""
CONTAINER="caddy-selfsteal"
FILES_ONLY=0
SKIP_DNS=0
SHOW_HELP=0
LANG_SEL=""

c_red=$'\033[31m'; c_grn=$'\033[32m'; c_ylw=$'\033[33m'; c_cyn=$'\033[36m'; c_bld=$'\033[1m'; c_off=$'\033[0m'

# ---------------------------------------------------------------- i18n
declare -A T

load_en() {
  T[welcome_sub]="Set up a selfsteal decoy site (Caddy) for your Xray Reality node in a few minutes."
  T[lang_prompt]="Select language / Выберите язык / Dil seçin"
  T[lang_choice]="Choice [1]: "
  T[usage]="Usage:
  install.sh --domain nt.example.com [options]
  install.sh nt.example.com

Options:
  -d, --domain <domain>   Selfsteal domain (A record -> this server, DNS-only)
  -p, --port <port>       Local Caddy HTTPS port used as Xray target (default 9443)
      --dir <path>        Install directory (default /opt/caddy)
  -l, --lang <en|ru|az>   Language (default: en)
      --skip-dns-check    Do not abort if the domain does not resolve to this server
      --files-only        Only generate files; no Docker, no DNS check, no start
  -h, --help              Show this help"
  T[wizard_intro]="I will ask a few questions. Press Enter to accept the value in brackets."
  T[q_domain]="Selfsteal domain (e.g. nt.example.com)"
  T[q_port]="Local Caddy port (Xray target)"
  T[q_dir]="Install directory"
  T[err_invalid_dir]="Use an absolute path, e.g. /opt/caddy"
  T[summary]="Summary:
  Domain:    %s
  Port:      %s
  Directory: %s"
  T[q_continue]="Continue?"
  T[aborted]="Aborted."
  T[warn_dns_mismatch]="%s does not point to this server (%s). The certificate cannot be issued until the A record is fixed (DNS-only / grey cloud in Cloudflare)."
  T[q_dns_continue]="Continue anyway?"
  T[q_keys]="Generate an x25519 key pair via remnanode now?"
  T[err_unknown_opt]="Unknown option: %s"
  T[err_domain_required]="Domain is required."
  T[prompt_domain]="Selfsteal domain (e.g. nt.example.com): "
  T[err_invalid_domain]="Invalid domain: %s"
  T[err_invalid_port]="Invalid port: %s (use 1024-65535)"
  T[err_root]="Run as root (sudo)."
  T[info_ips]="Server IP: %s   %s resolves to: %s"
  T[none]="nothing"
  T[unknown]="unknown"
  T[err_no_ip]="Could not detect the public IP. Re-run with --skip-dns-check if you are sure."
  T[err_dns_mismatch]="%s does not point to this server (%s). Fix the A record (DNS-only / grey cloud in Cloudflare), wait for DNS, then re-run."
  T[err_port80]="Port 80 is already in use (nginx/apache/certbot?). Caddy needs it for ACME. Check: ss -tlnp | grep ':80'"
  T[err_port_used]="Port %s is already in use. Choose another with --port."
  T[info_docker]="Docker not found, installing via get.docker.com ..."
  T[err_compose]="Docker Compose is missing. Install the docker-compose-plugin package."
  T[warn_caddy_dir]="%s is a directory (Docker artifact) - removing it."
  T[info_files]="Files written to %s"
  T[files_only_done]="Files-only mode: nothing started. Generated: Caddyfile, docker-compose.yml, html/index.html, xray-config.generated.json"
  T[info_validating]="Validating Caddyfile ..."
  T[err_validate]="Caddyfile validation failed. Run: docker run --rm -v %s/Caddyfile:/etc/caddy/Caddyfile:ro caddy:2 caddy validate --config /etc/caddy/Caddyfile"
  T[info_starting]="Starting Caddy ..."
  T[info_wait_cert]="Waiting for the certificate (up to ~2 min) ..."
  T[info_cert_ok]="Certificate obtained for %s."
  T[warn_cert_fail]="Certificate not confirmed yet. Check: docker logs %s --tail 50"
  T[warn_cert_hint]="Common causes: wrong A record, Cloudflare orange cloud, port 80 blocked by the provider firewall."
  T[warn_not_listening]="Caddy is not listening on 80/%s yet."
  T[info_keys]="Generating an x25519 key pair via remnanode (copy it; it is shown only here):"
  T[warn_key_fail]="Could not run xray x25519 in remnanode."
  T[warn_no_node]="remnanode is not running here. Generate keys where Xray runs: docker exec remnanode xray x25519"
  T[done]="Done."
  T[next]="Next steps
  1. Open %s/xray-config.generated.json and put your PRIVATE key instead of <PRIVATE_KEY>.
  2. Paste it into the Remnawave Config Profile for this node and apply.
  3. In the Host: SNI = %s, address = %s (or the server IP), short ID = %s.
  4. Refresh the subscription in the client; the public key must match the private key.
  5. Check the decoy site: curl -I https://%s

Never commit or share private keys."
}

load_ru() {
  T[welcome_sub]="Установка selfsteal-сайта (Caddy) для вашей ноды Xray Reality за пару минут."
  T[lang_choice]="Выбор [1]: "
  T[usage]="Использование:
  install.sh --domain nt.example.com [опции]
  install.sh nt.example.com

Опции:
  -d, --domain <домен>    Selfsteal-домен (A-запись -> этот сервер, только DNS)
  -p, --port <порт>       Локальный HTTPS-порт Caddy, он же target для Xray (по умолчанию 9443)
      --dir <путь>        Каталог установки (по умолчанию /opt/caddy)
  -l, --lang <en|ru|az>   Язык (по умолчанию: en)
      --skip-dns-check    Не прерываться, если домен не указывает на этот сервер
      --files-only        Только создать файлы; без Docker, проверки DNS и запуска
  -h, --help              Показать справку"
  T[wizard_intro]="Я задам несколько вопросов. Нажмите Enter, чтобы принять значение в скобках."
  T[q_domain]="Selfsteal-домен (например, nt.example.com)"
  T[q_port]="Локальный порт Caddy (target для Xray)"
  T[q_dir]="Каталог установки"
  T[err_invalid_dir]="Укажите абсолютный путь, например /opt/caddy"
  T[summary]="Итог:
  Домен:     %s
  Порт:      %s
  Каталог:   %s"
  T[q_continue]="Продолжить?"
  T[aborted]="Отменено."
  T[warn_dns_mismatch]="%s не указывает на этот сервер (%s). Сертификат не выпустится, пока не исправлена A-запись (DNS-only / серое облако в Cloudflare)."
  T[q_dns_continue]="Всё равно продолжить?"
  T[q_keys]="Сгенерировать пару ключей x25519 через remnanode сейчас?"
  T[err_unknown_opt]="Неизвестная опция: %s"
  T[err_domain_required]="Нужно указать домен."
  T[prompt_domain]="Selfsteal-домен (например, nt.example.com): "
  T[err_invalid_domain]="Некорректный домен: %s"
  T[err_invalid_port]="Некорректный порт: %s (допустимо 1024-65535)"
  T[err_root]="Запустите от root (sudo)."
  T[info_ips]="IP сервера: %s   %s резолвится в: %s"
  T[none]="ничего"
  T[unknown]="неизвестно"
  T[err_no_ip]="Не удалось определить публичный IP. Запустите с --skip-dns-check, если уверены."
  T[err_dns_mismatch]="%s не указывает на этот сервер (%s). Исправьте A-запись (DNS-only / серое облако в Cloudflare), дождитесь обновления DNS и запустите снова."
  T[err_port80]="Порт 80 уже занят (nginx/apache/certbot?). Он нужен Caddy для ACME. Проверьте: ss -tlnp | grep ':80'"
  T[err_port_used]="Порт %s уже занят. Выберите другой через --port."
  T[info_docker]="Docker не найден, устанавливаю через get.docker.com ..."
  T[err_compose]="Docker Compose не найден. Установите пакет docker-compose-plugin."
  T[warn_caddy_dir]="%s — это каталог (артефакт Docker), удаляю."
  T[info_files]="Файлы записаны в %s"
  T[files_only_done]="Режим files-only: ничего не запущено. Созданы: Caddyfile, docker-compose.yml, html/index.html, xray-config.generated.json"
  T[info_validating]="Проверяю Caddyfile ..."
  T[err_validate]="Caddyfile не прошёл проверку. Выполните: docker run --rm -v %s/Caddyfile:/etc/caddy/Caddyfile:ro caddy:2 caddy validate --config /etc/caddy/Caddyfile"
  T[info_starting]="Запускаю Caddy ..."
  T[info_wait_cert]="Жду сертификат (до ~2 минут) ..."
  T[info_cert_ok]="Сертификат для %s получен."
  T[warn_cert_fail]="Сертификат пока не подтверждён. Проверьте: docker logs %s --tail 50"
  T[warn_cert_hint]="Частые причины: неверная A-запись, оранжевое облако Cloudflare, порт 80 закрыт файрволом провайдера."
  T[warn_not_listening]="Caddy пока не слушает порты 80/%s."
  T[info_keys]="Генерирую пару ключей x25519 через remnanode (скопируйте её, она показана только здесь):"
  T[warn_key_fail]="Не удалось выполнить xray x25519 в remnanode."
  T[warn_no_node]="remnanode здесь не запущен. Сгенерируйте ключи там, где работает Xray: docker exec remnanode xray x25519"
  T[done]="Готово."
  T[next]="Дальнейшие шаги
  1. Откройте %s/xray-config.generated.json и вставьте ПРИВАТНЫЙ ключ вместо <PRIVATE_KEY>.
  2. Вставьте конфиг в Config Profile этой ноды в Remnawave и примените.
  3. В Host: SNI = %s, адрес = %s (или IP сервера), short ID = %s.
  4. Обновите подписку в клиенте; публичный ключ должен соответствовать приватному.
  5. Проверьте сайт-заглушку: curl -I https://%s

Никогда не публикуйте и не коммитьте приватные ключи."
}

load_az() {
  T[welcome_sub]="Xray Reality nodunuz üçün selfsteal saytını (Caddy) bir neçə dəqiqəyə qurun."
  T[lang_choice]="Seçim [1]: "
  T[usage]="İstifadə:
  install.sh --domain nt.example.com [seçimlər]
  install.sh nt.example.com

Seçimlər:
  -d, --domain <domen>    Selfsteal domeni (A qeydi -> bu server, yalnız DNS)
  -p, --port <port>       Caddy-nin lokal HTTPS portu, Xray üçün target (standart 9443)
      --dir <yol>         Quraşdırma qovluğu (standart /opt/caddy)
  -l, --lang <en|ru|az>   Dil (standart: en)
      --skip-dns-check    Domen bu serverə baxmasa da dayanma
      --files-only        Yalnız fayllar yaradılsın; Docker, DNS yoxlaması və start olmasın
  -h, --help              Bu köməyi göstər"
  T[wizard_intro]="Bir neçə sual verəcəyəm. Mötərizədəki dəyəri qəbul etmək üçün Enter basın."
  T[q_domain]="Selfsteal domeni (məs. nt.example.com)"
  T[q_port]="Caddy-nin lokal portu (Xray target)"
  T[q_dir]="Quraşdırma qovluğu"
  T[err_invalid_dir]="Mütləq yol yazın, məs. /opt/caddy"
  T[summary]="Xülasə:
  Domen:     %s
  Port:      %s
  Qovluq:    %s"
  T[q_continue]="Davam edək?"
  T[aborted]="Ləğv edildi."
  T[warn_dns_mismatch]="%s bu serverə baxmır (%s). A qeydi düzəlmədikcə sertifikat alınmayacaq (DNS-only / Cloudflare-də boz bulud)."
  T[q_dns_continue]="Yenə də davam edək?"
  T[q_keys]="İndi remnanode vasitəsilə x25519 açar cütü yaradaq?"
  T[err_unknown_opt]="Naməlum seçim: %s"
  T[err_domain_required]="Domen tələb olunur."
  T[prompt_domain]="Selfsteal domeni (məs. nt.example.com): "
  T[err_invalid_domain]="Yanlış domen: %s"
  T[err_invalid_port]="Yanlış port: %s (1024-65535 olmalıdır)"
  T[err_root]="Root ilə işə salın (sudo)."
  T[info_ips]="Server IP: %s   %s həll olunur: %s"
  T[none]="heç nə"
  T[unknown]="naməlum"
  T[err_no_ip]="Public IP aşkar edilmədi. Əminsinizsə --skip-dns-check ilə yenidən işə salın."
  T[err_dns_mismatch]="%s bu serverə baxmır (%s). A qeydini düzəldin (DNS-only / Cloudflare-də boz bulud), DNS-in yenilənməsini gözləyin və yenidən işə salın."
  T[err_port80]="Port 80 artıq istifadə olunur (nginx/apache/certbot?). Caddy ACME üçün ona ehtiyac duyur. Yoxlayın: ss -tlnp | grep ':80'"
  T[err_port_used]="Port %s artıq istifadə olunur. --port ilə başqasını seçin."
  T[info_docker]="Docker tapılmadı, get.docker.com vasitəsilə quraşdırılır ..."
  T[err_compose]="Docker Compose tapılmadı. docker-compose-plugin paketini quraşdırın."
  T[warn_caddy_dir]="%s qovluqdur (Docker artefaktı) - silinir."
  T[info_files]="Fayllar %s qovluğuna yazıldı"
  T[files_only_done]="files-only rejimi: heç nə başladılmadı. Yaradıldı: Caddyfile, docker-compose.yml, html/index.html, xray-config.generated.json"
  T[info_validating]="Caddyfile yoxlanılır ..."
  T[err_validate]="Caddyfile yoxlamadan keçmədi. İcra edin: docker run --rm -v %s/Caddyfile:/etc/caddy/Caddyfile:ro caddy:2 caddy validate --config /etc/caddy/Caddyfile"
  T[info_starting]="Caddy başladılır ..."
  T[info_wait_cert]="Sertifikat gözlənilir (~2 dəqiqəyə qədər) ..."
  T[info_cert_ok]="%s üçün sertifikat alındı."
  T[warn_cert_fail]="Sertifikat hələ təsdiqlənməyib. Yoxlayın: docker logs %s --tail 50"
  T[warn_cert_hint]="Tez-tez səbəblər: yanlış A qeydi, Cloudflare-in narıncı buludu, provayderin firewall-u 80 portunu bağlayıb."
  T[warn_not_listening]="Caddy hələ 80/%s portlarını dinləmir."
  T[info_keys]="remnanode vasitəsilə x25519 açar cütü yaradılır (kopyalayın, yalnız burada göstərilir):"
  T[warn_key_fail]="remnanode-da xray x25519 icra edilə bilmədi."
  T[warn_no_node]="remnanode burada işləmir. Açarları Xray işləyən yerdə yaradın: docker exec remnanode xray x25519"
  T[done]="Hazırdır."
  T[next]="Növbəti addımlar
  1. %s/xray-config.generated.json faylını açın və <PRIVATE_KEY> yerinə PRIVATE açarı yazın.
  2. Onu Remnawave-də bu nodun Config Profile-ına yapışdırıb tətbiq edin.
  3. Host-da: SNI = %s, ünvan = %s (və ya server IP), short ID = %s.
  4. Klientdə subscription-u yeniləyin; public key private key ilə uyğun olmalıdır.
  5. Decoy saytı yoxlayın: curl -I https://%s

Private açarları heç vaxt paylaşmayın və commit etməyin."
}

set_lang() {
  load_en
  case "$1" in
    ru) load_ru; LANG_SEL=ru ;;
    az) load_az; LANG_SEL=az ;;
    *)  LANG_SEL=en ;;
  esac
}

# tf KEY [args...]  -> printf-formatted message
tf() {
  local fmt="${T[$1]}"; shift
  # shellcheck disable=SC2059
  printf "$fmt" "$@"
}

info() { echo "${c_grn}[+]${c_off} $*"; }
warn() { echo "${c_ylw}[!]${c_off} $*"; }
die()  { echo "${c_red}[x]${c_off} $*" >&2; exit 1; }

INTERACTIVE=0
if [[ -t 1 ]] && { : < /dev/tty; } 2> /dev/null; then INTERACTIVE=1; fi

# ask VAR "question" default  -> reads one answer (Enter = default)
ask() {
  local __var="$1" __q="$2" __def="${3:-}" __ans=""
  if (( INTERACTIVE == 1 )); then
    if [[ -n "$__def" ]]; then
      read -r -p "${c_bld}${__q}${c_off} [${__def}]: " __ans < /dev/tty || __ans=""
    else
      read -r -p "${c_bld}${__q}${c_off}: " __ans < /dev/tty || __ans=""
    fi
  fi
  printf -v "$__var" '%s' "${__ans:-$__def}"
}

# yesno "question" y|n  -> exit 0 on yes (Enter = default; no terminal = default)
yesno() {
  local __ans="" __def="$2" __hint="[Y/n]"
  [[ "$__def" == n ]] && __hint="[y/N]"
  if (( INTERACTIVE == 1 )); then
    read -r -p "${c_bld}$1${c_off} ${__hint} " __ans < /dev/tty || __ans=""
  fi
  __ans="${__ans:-$__def}"
  [[ "${__ans,,}" =~ ^(y|yes|д|да|b|bəli|beli)$ || "$__ans" =~ ^(Д|Да|Bəli|B)$ ]]
}

norm_domain() { echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's#^https\?://##; s#/.*$##'; }
valid_domain() { [[ "$1" =~ ^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}$ ]]; }
valid_port() { [[ "$1" =~ ^[0-9]+$ ]] && (( $1 >= 1024 && $1 <= 65535 )); }

# ---------------------------------------------------------------- args
ARGS=("$@")
# first pass: only --lang, so every later message is localized
i=0
while (( i < ${#ARGS[@]} )); do
  case "${ARGS[$i]}" in
    -l|--lang) LANG_SEL="${ARGS[$((i+1))]:-}"; i=$((i+2)) ;;
    *) i=$((i+1)) ;;
  esac
done
LANG_GIVEN=0
case "$LANG_SEL" in en|ru|az) LANG_GIVEN=1 ;; *) LANG_SEL="" ;; esac

# ---------------------------------------------------------------- welcome
banner() {
  echo "${c_cyn}${c_bld}"
  echo "  ╔══════════════════════════════════════════╗"
  echo "  ║        Remnawave-SelfSteal-Easy          ║"
  echo "  ╚══════════════════════════════════════════╝"
  echo "${c_off}${c_cyn}                         t.me/Sumdevaz${c_off}"
  echo
}

set_lang "$LANG_SEL"   # English first, so the language prompt can be shown
banner

if (( LANG_GIVEN == 0 )); then
  CH=""
  if [[ -t 1 ]]; then
    echo "  ${T[lang_prompt]}"
    echo "    1) English (default)"
    echo "    2) Русский"
    echo "    3) Azərbaycanca"
    read -r -t 30 -p "  ${T[lang_choice]}" CH < /dev/tty 2> /dev/null || CH=""
    echo
  fi
  case "${CH,,}" in
    2|ru) set_lang ru ;;
    3|az) set_lang az ;;
    *)    set_lang en ;;
  esac
else
  set_lang "$LANG_SEL"
fi
echo "  ${T[welcome_sub]}"
echo

# ---------------------------------------------------------------- parse
set -- "${ARGS[@]}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--domain) DOMAIN="${2:-}"; shift 2 ;;
    -p|--port) PORT="${2:-}"; shift 2 ;;
    --dir) DIR="${2:-}"; shift 2 ;;
    -l|--lang) shift 2 ;;
    --skip-dns-check) SKIP_DNS=1; shift ;;
    --files-only) FILES_ONLY=1; shift ;;
    -h|--help) SHOW_HELP=1; shift ;;
    -*) echo "${T[usage]}"; die "$(tf err_unknown_opt "$1")" ;;
    *) DOMAIN="$1"; shift ;;
  esac
done

if (( SHOW_HELP == 1 )); then echo "${T[usage]}"; exit 0; fi

if (( FILES_ONLY == 0 )) && [[ $EUID -ne 0 ]]; then
  die "${T[err_root]}"
fi

ASKED=0
if (( INTERACTIVE == 1 )) && { [[ -z "$DOMAIN" ]] || [[ -z "$PORT" ]] || [[ -z "$DIR" ]]; }; then
  echo "${c_cyn}${T[wizard_intro]}${c_off}"
  echo
fi

# 1/3 domain
DOMAIN="$(norm_domain "$DOMAIN")"
if [[ -z "$DOMAIN" ]]; then
  ASKED=1
  while true; do
    ask DOMAIN "[1/3] ${T[q_domain]}" ""
    DOMAIN="$(norm_domain "$DOMAIN")"
    if valid_domain "$DOMAIN"; then break; fi
    if (( INTERACTIVE == 0 )); then echo "${T[usage]}"; die "${T[err_domain_required]}"; fi
    if [[ -z "$DOMAIN" ]]; then warn "${T[err_domain_required]}"; else warn "$(tf err_invalid_domain "$DOMAIN")"; fi
    DOMAIN=""
  done
fi
valid_domain "$DOMAIN" || die "$(tf err_invalid_domain "$DOMAIN")"

# 2/3 port
if [[ -z "$PORT" ]]; then
  ASKED=1
  while true; do
    ask PORT "[2/3] ${T[q_port]}" "9443"
    if valid_port "$PORT"; then break; fi
    if (( INTERACTIVE == 0 )); then die "$(tf err_invalid_port "$PORT")"; fi
    warn "$(tf err_invalid_port "$PORT")"
    PORT=""
  done
fi
valid_port "$PORT" || die "$(tf err_invalid_port "$PORT")"

# 3/3 directory
if [[ -z "$DIR" ]]; then
  ASKED=1
  while true; do
    ask DIR "[3/3] ${T[q_dir]}" "/opt/caddy"
    if [[ "$DIR" == /* ]]; then break; fi
    if (( INTERACTIVE == 0 )); then die "${T[err_invalid_dir]}"; fi
    warn "${T[err_invalid_dir]}"
    DIR=""
  done
fi
[[ "$DIR" == /* ]] || die "${T[err_invalid_dir]}"

if (( ASKED == 1 && INTERACTIVE == 1 )); then
  echo
  tf summary "$DOMAIN" "$PORT" "$DIR"
  echo
  yesno "${T[q_continue]}" y || die "${T[aborted]}"
  echo
fi

listening() { ss -tln 2>/dev/null | awk '{print $4}' | grep -Eq "[:.]$1\$"; }

# ---------------------------------------------------------------- checks
if (( FILES_ONLY == 0 )); then
  PUBLIC_IP="$(curl -4 -fsS --max-time 8 https://api.ipify.org 2>/dev/null || curl -4 -fsS --max-time 8 https://ifconfig.me 2>/dev/null || true)"
  RESOLVED="$(getent ahostsv4 "$DOMAIN" 2>/dev/null | awk '{print $1}' | sort -u | tr '\n' ' ' || true)"
  info "$(tf info_ips "${PUBLIC_IP:-${T[unknown]}}" "$DOMAIN" "${RESOLVED:-${T[none]}}")"
  if (( SKIP_DNS == 0 )); then
    [[ -n "$PUBLIC_IP" ]] || die "${T[err_no_ip]}"
    if ! grep -qw "$PUBLIC_IP" <<< "$RESOLVED"; then
      if (( INTERACTIVE == 0 )); then die "$(tf err_dns_mismatch "$DOMAIN" "$PUBLIC_IP")"; fi
      warn "$(tf warn_dns_mismatch "$DOMAIN" "$PUBLIC_IP")"
      yesno "${T[q_dns_continue]}" n || die "${T[aborted]}"
    fi
  fi

  RUNNING="$(docker ps --format '{{.Names}}' 2>/dev/null | grep -x "$CONTAINER" || true)"
  if [[ -z "$RUNNING" ]]; then
    if listening 80; then die "${T[err_port80]}"; fi
    if listening "$PORT"; then die "$(tf err_port_used "$PORT")"; fi
  fi

  if ! command -v docker > /dev/null 2>&1; then
    info "${T[info_docker]}"
    curl -fsSL https://get.docker.com | sh
  fi
  if docker compose version > /dev/null 2>&1; then
    COMPOSE=(docker compose)
  elif command -v docker-compose > /dev/null 2>&1; then
    COMPOSE=(docker-compose)
  else
    die "${T[err_compose]}"
  fi
fi

# ---------------------------------------------------------------- files
mkdir -p "$DIR/html"

# Docker creates a DIRECTORY when a bind-mounted file is missing; clean that up.
if [[ -d "$DIR/Caddyfile" ]]; then
  warn "$(tf warn_caddy_dir "$DIR/Caddyfile")"
  rm -rf "$DIR/Caddyfile"
fi
if [[ -f "$DIR/Caddyfile" ]]; then
  cp "$DIR/Caddyfile" "$DIR/Caddyfile.bak.$(date +%Y%m%d%H%M%S)"
fi

cat > "$DIR/Caddyfile" << EOF
{
    https_port ${PORT}
    default_bind 127.0.0.1
    servers {
        listener_wrappers {
            proxy_protocol {
                allow 127.0.0.1/32
            }
            tls
        }
    }
    auto_https disable_redirects
}

http://${DOMAIN} {
    bind 0.0.0.0
    redir https://${DOMAIN}{uri} permanent
}

https://${DOMAIN} {
    root * /var/www/html
    try_files {path} /index.html
    file_server
}

:${PORT} {
    tls internal
    respond 204
}

:80 {
    bind 0.0.0.0
    respond 204
}
EOF

cat > "$DIR/docker-compose.yml" << EOF
services:
  caddy:
    image: caddy:2
    container_name: ${CONTAINER}
    restart: unless-stopped
    network_mode: host
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - ./html:/var/www/html:ro
      - caddy_data:/data
      - caddy_config:/config

volumes:
  caddy_data:
  caddy_config:
EOF

if [[ ! -f "$DIR/html/index.html" ]]; then
  cat > "$DIR/html/index.html" << 'EOF'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Welcome</title>
<style>
  body { margin: 0; min-height: 100vh; display: grid; place-items: center;
         font-family: system-ui, sans-serif; background: #f5f6f8; color: #222; }
  main { text-align: center; padding: 2rem; }
  h1 { font-weight: 600; margin: 0 0 .5rem; }
  p { color: #666; margin: 0; }
</style>
</head>
<body>
<main>
  <h1>Welcome</h1>
  <p>This site is under construction.</p>
</main>
</body>
</html>
EOF
fi

SHORT_ID="$(openssl rand -hex 8 2>/dev/null || head -c 8 /dev/urandom | od -An -tx1 | tr -d ' \n')"

cat > "$DIR/xray-config.generated.json" << EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "tag": "reality-selfsteal",
      "port": 443,
      "listen": "0.0.0.0",
      "protocol": "vless",
      "settings": { "clients": [], "decryption": "none" },
      "sniffing": { "enabled": true, "destOverride": ["http", "tls", "quic"] },
      "streamSettings": {
        "network": "raw",
        "security": "reality",
        "realitySettings": {
          "target": "127.0.0.1:${PORT}",
          "xver": 1,
          "shortIds": ["${SHORT_ID}"],
          "privateKey": "<PRIVATE_KEY>",
          "serverNames": ["${DOMAIN}"]
        }
      }
    }
  ],
  "outbounds": [
    { "tag": "DIRECT", "protocol": "freedom" },
    { "tag": "BLOCK", "protocol": "blackhole" }
  ],
  "routing": {
    "rules": [
      { "ip": ["geoip:private"], "outboundTag": "BLOCK" },
      { "domain": ["geosite:private"], "outboundTag": "BLOCK" },
      { "protocol": ["bittorrent"], "outboundTag": "BLOCK" }
    ]
  }
}
EOF

info "$(tf info_files "$DIR")"

if (( FILES_ONLY == 1 )); then
  echo "${T[files_only_done]}"
  exit 0
fi

# ---------------------------------------------------------------- start
info "${T[info_validating]}"
docker run --rm -v "$DIR/Caddyfile:/etc/caddy/Caddyfile:ro" caddy:2 \
  caddy validate --config /etc/caddy/Caddyfile > /dev/null 2>&1 \
  || die "$(tf err_validate "$DIR")"

info "${T[info_starting]}"
( cd "$DIR" && "${COMPOSE[@]}" up -d )

info "${T[info_wait_cert]}"
OK=0
for _ in $(seq 1 60); do
  if docker logs "$CONTAINER" 2>&1 | grep -qi "certificate obtained successfully"; then OK=1; break; fi
  sleep 2
done
if (( OK == 1 )); then
  info "$(tf info_cert_ok "$DOMAIN")"
else
  warn "$(tf warn_cert_fail "$CONTAINER")"
  warn "${T[warn_cert_hint]}"
fi

echo
ss -tlnp 2>/dev/null | grep -E ":(80|${PORT})\b" || warn "$(tf warn_not_listening "$PORT")"

echo
if docker ps --format '{{.Names}}' | grep -qx remnanode; then
  if yesno "${T[q_keys]}" y; then
    info "${T[info_keys]}"
    docker exec remnanode xray x25519 || warn "${T[warn_key_fail]}"
  fi
else
  warn "${T[warn_no_node]}"
fi

echo
echo "${c_bld}${T[done]}${c_off}"
echo
tf next "$DIR" "$DOMAIN" "$DOMAIN" "$SHORT_ID" "$DOMAIN"
echo
echo "${c_cyn}t.me/Sumdevaz${c_off}"
echo
