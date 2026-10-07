#!/usr/bin/env bash
# Stops the selfsteal Caddy container. Add --purge to delete the install directory and volumes.
# Language: LANG_SEL=ru|az (default en), e.g. LANG_SEL=ru bash uninstall.sh --purge
set -euo pipefail
DIR="${DIR:-/opt/caddy}"
L="${LANG_SEL:-en}"

case "$L" in
  ru) M_ROOT="Запустите от root."; M_PURGED="Удалено: %s и тома Docker."; M_STOPPED="Остановлено. Файлы сохранены в %s (используйте --purge для удаления)."; M_NONE="В %s ничего не найдено." ;;
  az) M_ROOT="Root ilə işə salın."; M_PURGED="%s və Docker volume-ları silindi."; M_STOPPED="Dayandırıldı. Fayllar %s qovluğunda saxlanıldı (silmək üçün --purge)."; M_NONE="%s qovluğunda heç nə tapılmadı." ;;
  *)  M_ROOT="Run as root."; M_PURGED="Removed %s and volumes."; M_STOPPED="Stopped. Files kept in %s (use --purge to delete)."; M_NONE="Nothing found in %s." ;;
esac

[[ $EUID -eq 0 ]] || { echo "$M_ROOT" >&2; exit 1; }
if [[ -f "$DIR/docker-compose.yml" ]]; then
  cd "$DIR"
  if [[ "${1:-}" == "--purge" ]]; then
    docker compose down -v
    cd /
    rm -rf "$DIR"
    # shellcheck disable=SC2059
    printf "$M_PURGED\n" "$DIR"
  else
    docker compose down
    # shellcheck disable=SC2059
    printf "$M_STOPPED\n" "$DIR"
  fi
else
  # shellcheck disable=SC2059
  printf "$M_NONE\n" "$DIR"
fi
