# 🛠️ Tools

Herramientas pequeñas, en un solo fichero y sin dependencias, que me escribo para ir más rápido en enumeración. Filosofía: **triar, no sustituir** — no pretenden reemplazar a LinPEAS/GTFOBins, sino decirme *dónde mirar primero* con cero ruido y entendiendo cada línea de lo que ejecuto.

| Herramienta | Qué hace |
|---|---|
| [`suid-triage.sh`](./suid-triage.sh) | Clasifica los binarios SUID de la máquina en 3 cubos para privesc |

---

## `suid-triage.sh`

El problema nunca es *sacar* los SUID (`find / -perm -4000`), es **saber cuál de los que salen es el bueno** sin ir uno a uno a GTFOBins. Este script coge esa lista y la reparte:

- `[!]` **EXPLOTABLE CONOCIDO** — está en GTFOBins, con la **pista de la técnica** (`bash -p`, `find -exec`, `dosbox → /etc/sudoers`…). Empieza por aquí.
- `[?]` **NO ESTÁNDAR** — no es un SUID del sistema base → **investiga su versión** (`searchsploit`, `--help`, `strings`). Aquí caen los binarios *custom* con nombre propio, que suelen ser el vector diseñado de la caja.
- `[.]` **Normal del sistema** — `su`, `sudo`, `ping`, `mount`… ignóralos. (Avisa aparte si `pkexec` está presente → posible **PwnKit CVE-2021-4034**.)

### Uso
```bash
./suid-triage.sh            # busca en /
./suid-triage.sh /var       # acota la búsqueda
./suid-triage.sh -n /       # sin colores (para redirigir a fichero)
```
Bash puro, corre en cualquier víctima Linux. Transfiérelo como cualquier otro (`wget`/`curl` desde tu http.server, o pégalo).

### Por qué existe (y sus límites)
LinPEAS hace esto y mucho más, pero **entierra el dato entre miles de líneas**. Para el triaje de SUID en concreto, prefiero una salida de 10 líneas que entiendo entera. No cubre capabilities, cron, ni kernel exploits — para eso, LinPEAS o la metodología completa del repo. Es una navaja, no un taller.

<sub>⚠️ Úsalo solo en sistemas donde tengas autorización (laboratorios, CTFs, pentests contratados).</sub>
