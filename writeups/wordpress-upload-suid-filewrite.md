# WordPress plugin: unauth upload + egress solo-80 + SUID con solo "File write" → root

> **Writeup sanitizado.** Flags y credenciales redactadas. Metodología y razonamiento, sin regalar la sala.

**Tipo:** Linux · Intermediate
**Cadena:** `WordPress → plugin vulnerable (upload no autenticado) → webshell PHP → egress filtrado solo-80 → reverse por 80 → reuso de credenciales a SSH → servicio local-only (ssh -L) → SUID sin "Shell" pero con "File write" → root`

---

## 1. Recon
- Superficie amplia: SSH, **WordPress** (web principal), un servidor **Flask/Werkzeug** en un puerto alto, un portal de login en otro, y SMB.
- Plan: WordPress primero → `wpscan -e vp,u` (el core estaba parcheado; el valor está en los **plugins**).

> **Lección — en WordPress, el core suele estar al día; el agujero casi siempre es un plugin.** Enumerar plugins (`-e vp`) antes que perseguir el CMS.

## 2. Foothold — plugin con subida no autenticada → RCE
`wpscan` saca un plugin de gestión de ficheros con una versión vieja: **subida de ficheros sin autenticación** conocida → RCE.

> **Lección — "unauthenticated / pre-auth" es luz verde, no un obstáculo.** Significa que NO necesitas credenciales. Me frenó un segundo leerlo como si fuera un requisito; es justo lo contrario.

El exploit deja un webshell `.php`. Un detalle que me costó: el `cmd` del webshell **no ejecuta shell directamente, ejecuta PHP** → los comandos van dentro de `system('...')`.

> **Lección — identifica qué interpreta el webshell.** Si el parámetro entra en un `eval()`, tienes que envolver tú la ejecución (`system(...)`). No es lo mismo un webshell que mete tu input en `system($_GET[...])` que uno que lo mete en `eval($_POST[...])`.

### Egress filtrado — solo el puerto 80
La reverse shell no volvía. Diagnóstico: servir un fichero en mi máquina y ver en el log del `http.server` que la víctima **sí** hacía el GET al puerto 80 → el fetch funciona, pero las reverse a 4444/443/8080 morían. **Egress filtrado a solo-80.**

> **Lección — "magic rev shell v2" (base64 inline) por el 80.** Cuando solo sale un puerto: reverse inline (sin descargar un `.sh` previo) codificada en base64 — `echo <B64> | base64 -d | bash` — apuntando al 80, con `nc -lvnp 80` escuchando. El base64 evita que los `>&`, `|` y redirecciones se rompan al pasar por `eval → system → sh`. De lo más limpio que he montado.

## 3. Escalada — reuso de credenciales → servicio local → SUID
- `wp-config.php` tiene las credenciales de la base de datos. **No se quedan en la DB: valen para SSH** → shell estable como usuario normal.

> **Lección — las credenciales de `wp-config.php` son candidatas a reuso.** Pruébalas en SSH; la gente reutiliza.

- `netstat -anlp` muestra un servicio escuchando **solo en `127.0.0.1`** (un VNC). No es accesible desde fuera.

> **Lección — servicio local-only → `ssh -L`, no pivoting pesado.** Si ya tienes SSH y es **un** puerto, un local forward (`ssh -L 5901:127.0.0.1:5901 user@victima`) lo trae a tu máquina. ligolo/chisel es para redes enteras, aquí sobra. El VNC dio la primera flag — pero **aún no era root**.

### Privesc final — SUID con solo "File write"
Un binario con SUID **no estándar**. En GTFOBins ese binario **no tiene sección "Shell"** — solo **"File write"**.

> **Lección clave — si en GTFOBins no hay "Shell" pero sí "File write", sigues llegando a root.** Escribir como root = ganar:
> - **File write** → añadir una línea a **`/etc/sudoers`** (`user ALL=(ALL:ALL) ALL`) y luego `sudo su -`; o escribir un usuario uid 0 en **`/etc/passwd`**.
> - **File read** → leer `/etc/shadow`, claves SSH, ficheros de root.
>
> Primero probé `/etc/passwd` y falló: ese binario (un emulador DOS) escribe con **finales de línea Windows `\r\n`**, así que el shell quedó `/bin/bash\r` y `su` rompía. La vía **`/etc/sudoers`** esquiva el problema (o `su -s /bin/bash`). Línea a `/etc/sudoers` → `sudo su -` → **root**.

## Qué me llevo
- **WordPress = plugins.** Core parcheado no cierra la caja; enumera plugins.
- **"Unauth" es luz verde.** Lee los títulos de exploit al derecho.
- **Egress filtrado se diagnostica**, no se adivina: el log del `http.server` confirma el fetch; si la reverse no vuelve, ese puerto está filtrado → prueba 80/443 e inline-base64.
- **`wp-config.php` → credenciales reutilizables en SSH.**
- **Servicio local-only → `ssh -L`** (un puerto, ya tengo SSH → no necesito ligolo).
- **GTFOBins "File write" sin "Shell" = root igual** vía `/etc/sudoers` o `/etc/passwd`. Y ojo al `\r\n` de las herramientas tipo DOS.

<sub>⚠️ Contenido educativo sobre un laboratorio autorizado. Flags y credenciales redactadas.</sub>
