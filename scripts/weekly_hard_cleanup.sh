#!/usr/bin/env bash
set -euo pipefail

# Ejecuta limpieza semanal real:
# - Foro (posts + comentarios)
# - Objetos perdidos entregados/devueltos
#
# Uso recomendado por cron (domingo 23:30):
# 30 23 * * 0 /bin/bash /ruta/a/check_system/scripts/weekly_hard_cleanup.sh >> /var/log/coyolabs_weekly_cleanup.log 2>&1

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

if [[ -f ".venv/bin/activate" ]]; then
  # shellcheck disable=SC1091
  source ".venv/bin/activate"
fi

export FLASK_APP="${FLASK_APP:-run.py}"
flask weekly-hard-cleanup
