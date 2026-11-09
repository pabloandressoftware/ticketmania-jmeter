#!/usr/bin/env bash
# Inicia la API de TicketMania en http://127.0.0.1:8080 (Ctrl+C para detener)
cd "$(dirname "$0")/../api" && exec python3 ticketmania_simple.py "$@"
