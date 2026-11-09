#!/usr/bin/env bash
# Corre el plan de JMeter con varias cantidades de usuarios y genera
# un reporte HTML por escenario en resultados/<usuarios>-usuarios/.
# Uso:  ./scripts/correr_pruebas.sh [usuarios...]      (por defecto: 10 50 100 500 1000)
# Requiere: la API arriba (./scripts/iniciar_api.sh) y JMeter en el PATH o JMETER_HOME.
set -euo pipefail
cd "$(dirname "$0")/.."

JMETER="${JMETER_HOME:+$JMETER_HOME/bin/}jmeter"
command -v "$JMETER" >/dev/null || { echo "No encuentro JMeter. Instálalo o define JMETER_HOME."; exit 1; }
curl -sf "http://${HOST:-localhost}:${PUERTO:-8080}/api/salud" >/dev/null \
  || { echo "La API no responde. Inicia la API con ./scripts/iniciar_api.sh"; exit 1; }

ESCENARIOS=("$@"); [ ${#ESCENARIOS[@]} -eq 0 ] && ESCENARIOS=(10 50 100 500 1000)
RAMPUP="${RAMPUP:-10}"        # segundos para subir todos los usuarios
ITER="${ITER:-1}"             # compras por usuario

for U in "${ESCENARIOS[@]}"; do
  OUT="resultados/${U}-usuarios"
  rm -rf "$OUT"; mkdir -p "$OUT"
  echo ">>> $U usuarios, rampup ${RAMPUP}s, ${ITER} iteración(es)"
  "$JMETER" -n -t jmeter/ticketmania.jmx \
    -Jusuarios="$U" -Jrampup="$RAMPUP" -Jiteraciones="$ITER" \
    -Jhost="${HOST:-localhost}" -Jpuerto="${PUERTO:-8080}" -Jcsv="$PWD/data/compras.csv" \
    -l "$OUT/resultados.jtl" -e -o "$OUT/reporte-html" -j "$OUT/jmeter.log"
done
echo "Listo. Abre resultados/<N>-usuarios/reporte-html/index.html"
