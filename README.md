# Taller de pruebas de carga con JMeter — TicketMania (Colombia vs Chile)

Curso: Automatización de Pruebas 2026-2.

Este repo contiene las pruebas de la API de compra de boletas que entregó la profesora:

1. Pruebas funcionales de los endpoints con **Postman**.
2. Pruebas de carga con **JMeter** (plan parametrizado, ejecución por consola y reportes HTML).
3. Resultados con 10, 50, 100, 500 y 1000 usuarios, y su análisis.

## Estructura

```
api/            API de la profesora (ticketmania_simple.py), sin modificar
postman/        Colección de Postman (flujo feliz y casos negativos)
jmeter/         Plan de pruebas ticketmania.jmx
data/           compras.csv con las combinaciones tarifa,cantidad
scripts/        iniciar_api.sh, correr_pruebas.sh, resumen.py
resultados/     Un reporte HTML y un .jtl por escenario, más resumen.md
```

## 1. Cómo correrlo

Requisitos: Python 3.8+, Java 11+ y [JMeter 5.6.x](https://jmeter.apache.org/download_jmeter.cgi).

```bash
# Terminal 1: levantar la API (queda en http://127.0.0.1:8080)
./scripts/iniciar_api.sh

# Terminal 2: correr los escenarios (por defecto 10 50 100 500 1000 usuarios)
export JMETER_HOME=/ruta/a/apache-jmeter-5.6.3      # o tener jmeter en el PATH
./scripts/correr_pruebas.sh
./scripts/correr_pruebas.sh 200 2000                # o escenarios propios
python3 scripts/resumen.py                          # tabla resumen en Markdown
```

Variables opcionales: `RAMPUP` (segundos, por defecto 10), `ITER` (compras por usuario, por defecto 1), `HOST`, `PUERTO`.

Para abrir el plan en la interfaz gráfica: `jmeter -t jmeter/ticketmania.jmx`. Dentro de la GUI, ejecuta siempre con las propiedades por defecto (10 usuarios) y deja las cargas grandes para la consola.

## 2. Pruebas funcionales con Postman

Importa `postman/ticketmania.postman_collection.json` y ejecuta la colección completa (Runner). La variable `reserva` se guarda sola en el paso 1 y se usa en el paso 2.

| Prueba | Esperado | Verificado contra la API |
|---|---|---|
| GET `/api/salud` | 200 | ✅ |
| GET `/api/tarifas` | 200 y 4 tarifas | ✅ |
| POST `/api/seleccion` (general × 2) | 201, total 160000 | ✅ |
| POST `/api/pago` con esa reserva | 200, `APROBADO` | ✅ |
| POST `/api/pago` con la misma reserva | 404 (ya se consumió) | ✅ |
| POST `/api/seleccion` con tarifa `palco` | 400 | ✅ |
| POST `/api/seleccion` con cantidad 0 | 400 | ✅ |

Los resultados de la última fila se comprobaron con `curl`. No abrí Postman ni corrí la colección dentro de él.

## 3. Plan de JMeter

Estructura de `jmeter/ticketmania.jmx`:

```
Test Plan
├── HTTP Request Defaults      localhost:8080  (host y puerto salen de -Jhost / -Jpuerto)
├── HTTP Header Manager        Content-Type: application/json
├── CSV Data Set Config        data/compras.csv -> ${tarifa}, ${cantidad}
└── Thread Group               usuarios, rampup e iteraciones vienen de -Jusuarios, -Jrampup, -Jiteraciones
    ├── 00 GET  /api/tarifas        Assertion: código 200
    ├── 01 POST /api/seleccion      cuerpo {"tarifa":"${tarifa}","cantidad":${cantidad}}
    │                               Assertion: 201. JSON Extractor: $.reserva -> ${reserva}
    ├── 02 POST /api/pago           cuerpo {"reserva":"${reserva}"}
    │                               Assertions: 200 y "estado": "APROBADO"
    ├── Summary Report
    └── View Results Tree
```

- El cuerpo `{"tarifa":"${tarifa}","cantidad":${cantidad}}` es el que la profesora escribió en el chat. Cada usuario toma una fila distinta del CSV, así la carga mezcla tarifas y cantidades.
- La reserva se extrae con un **JSON Extractor**. El README original usaba una expresión regular y esto es equivalente.
- Los *listeners* quedan en el plan para la GUI. En consola se corre con `-n` y se genera el reporte con `-e -o`.

## 4. Resultados

Cada usuario hace 3 peticiones (tarifas, selección y pago), con rampa de 10 s. Todo se corrió en una sola máquina, y JMeter y la API compartían CPU.

| Usuarios | Peticiones | Promedio (ms) | P90 (ms) | P95 (ms) | Máx (ms) | % Error | Peticiones/s |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 10 | 30 | 4.5 | 4 | 4 | 41 | 0.00 | 3.4 |
| 50 | 150 | 3.4 | 4 | 4 | 32 | 0.00 | 15.6 |
| 100 | 300 | 3.2 | 4 | 4 | 41 | 0.00 | 31.0 |
| 500 | 1500 | 13.0 | 3 | 4 | 1279 | 0.00 | 157.2 |
| 1000 | 3000 | 26.3 | 2 | 5 | 2149 | 0.00 | 313.1 |

Los reportes completos (gráficas de tiempos, throughput y percentiles) están en `resultados/<N>-usuarios/reporte-html/index.html`.

### Análisis

- **Cero errores en todos los escenarios.** Las 4980 peticiones (1660 pagos) salieron bien y todas las aserciones pasaron. Es lo esperado, porque la API no tiene límites, ni cola, ni rechazos.
- **El throughput crece de forma lineal con los usuarios** (de 3.4 a 313 peticiones/s). Esto pasa porque la carga la fija la rampa de 10 s. No significa que la API haya alcanzado su límite.
- **El P90 y el P95 se mantienen en 2–5 ms**, pero el **máximo sube a 1.3 s con 500 usuarios y a 2.1 s con 1000**, y el promedio de 1000 usuarios se va a 26 ms. Hay unas pocas peticiones muy lentas que no se ven en los percentiles. Es probable que sean las primeras conexiones, cuando se abren muchos hilos al mismo tiempo. Esto no lo comprobé, es una hipótesis.
- **Conclusión:** con esta carga la API responde bien. Para encontrar su punto de quiebre hay que subir la presión, por ejemplo con `RAMPUP=1`, `ITER=10` y 2000 usuarios o más.

### Contraste con la simulación

`simulacion_pasarela_ticketmania_v8.html` muestra lo que esta API simple **no** modela: capacidad limitada de la tienda, cola virtual y pasarela con hilos y cola finitos. En una venta real de boletas esos límites sí existen, y de ahí salen los errores y las esperas que esta prueba no ve.

## 5. Limitaciones

- La API es en memoria y el pago siempre se aprueba al instante (ver `api/README.md`).
- Las pruebas corrieron en un solo equipo, por lo que los números son solo de referencia.
- Las pruebas de carga se hicieron con un plan creado desde el resumen de la clase. Si la profesora pidió algo distinto, por ejemplo otras métricas, un Constant Timer o un número de usuarios específico, se ajusta con las propiedades del plan.
