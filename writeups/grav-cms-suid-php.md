# Grav CMS Scheduler RCE + SUID php → root

> **Writeup sanitizado.** Flags redactadas. Metodología y razonamiento, sin regalar la sala.

**Tipo:** Linux · Intermediate
**Cadena:** `Grav CMS → Scheduler RCE (cron job inyectado) → www-data → SUID php → root`

---

## 1. Recon
- **22** SSH · **80** Apache → **Grav CMS** (CMS flat-file en PHP/Twig), servido en un subdirectorio.
- `searchsploit grav` → **Grav CMS ≤ 1.10.7 — Scheduler RCE**.

## 2. Foothold — Scheduler RCE
El exploit obtiene el token (`admin-nonce`) de la página de admin e **inyecta un trabajo programado** en el scheduler de Grav que ejecuta PHP. El **cron del sistema dispara el scheduler cada minuto**, momento en el que se lanza la reverse shell (como `www-data`).

> **Lecciones al adaptar un exploit público (esto fue lo valioso de la caja):**
> - **Genera el payload dentro del script, con la IP como variable.** Un reverse shell con la IP en base64 *hardcodeada* se queda obsoleto en cuanto el VPN te asigna otra IP → la shell se va a la nada. Construirlo en el propio código lo hace inmune.
> - **Cuidado con la barra final de la URL base.** `.../app/` + `/admin` = `//admin`: el GET del nonce colaba, pero el POST que guarda el job se iba a una ruta distinta y **no se guardaba**. Sin job, no hay cron, no hay shell.
> - **Latencia del cron-RCE:** la reverse tarda **hasta un minuto** (el scheduler corre cada minuto). No es un fallo; **hay que esperar el tick** en vez de relanzar el exploit a lo loco.

## 3. Privesc — SUID `php`
```bash
find / -perm -4000 -type f 2>/dev/null     # destaca /usr/bin/php*
```
PHP con el bit SUID → GTFOBins. **El detalle que decide el éxito:** en la sección SUID hay varias variantes, y **las que usan `system()`/`passthru()`/`popen()` no escalan**: lanzan una shell hija a través de un wrapper que **descarta el euid**. La que funciona usa **ejecución directa preservando privilegios**:

```
php -r "pcntl_exec('/bin/sh', ['-p']);"
```
`pcntl_exec` reemplaza el proceso (sin wrapper que tire privilegios) y `-p` le dice a la shell que **conserve el euid=0**. Resultado: **root** (`euid=0`).

> **Lección:** `euid=0` **ya es root** — el kernel usa el *effective* uid para los permisos; ver `uid` sin cambiar (por `-p`) es normal. Y para SUID, el payload ganador **siempre preserva privilegios** (`pcntl_exec(...,['-p'])`, `bash -p`), nunca `system()`.

## Qué me llevo
- **Adaptar exploits con cabeza:** payload generado en el script (IP variable), URLs consistentes, y entender la **latencia** de un RCE basado en cron/scheduler.
- **SUID de un intérprete:** ve a la pestaña **SUID** de GTFOBins y usa el payload que **preserva el euid**; `system()` casi nunca escala.
- **`euid=0` es root** a todos los efectos.

<sub>⚠️ Contenido educativo sobre un laboratorio autorizado. Flags redactadas.</sub>
