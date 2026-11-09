#!/usr/bin/env python3
"""Lee resultados/*/resultados.jtl y arma una tabla en Markdown."""
import csv, glob, os, statistics, sys

def pct(v, p):
    v = sorted(v); return v[min(len(v) - 1, int(len(v) * p / 100))] if v else 0

filas = []
for jtl in sorted(glob.glob("resultados/*-usuarios/resultados.jtl"), key=lambda p: int(os.path.basename(os.path.dirname(p)).split("-")[0])):
    n = os.path.basename(os.path.dirname(jtl)).split("-")[0]
    rows = list(csv.DictReader(open(jtl, encoding="utf-8")))
    t = [int(r["elapsed"]) for r in rows]
    err = sum(r["success"] != "true" for r in rows)
    ini = min(int(r["timeStamp"]) for r in rows); fin = max(int(r["timeStamp"]) + int(r["elapsed"]) for r in rows)
    seg = max((fin - ini) / 1000, 0.001)
    filas.append((n, len(rows), statistics.mean(t), pct(t, 90), pct(t, 95), max(t), 100 * err / len(rows), len(rows) / seg))

print("| Usuarios | Peticiones | Promedio (ms) | P90 (ms) | P95 (ms) | Máx (ms) | % Error | Peticiones/s |")
print("|---:|---:|---:|---:|---:|---:|---:|---:|")
for f in filas:
    print(f"| {f[0]} | {f[1]} | {f[2]:.1f} | {f[3]} | {f[4]} | {f[5]} | {f[6]:.2f} | {f[7]:.1f} |")
