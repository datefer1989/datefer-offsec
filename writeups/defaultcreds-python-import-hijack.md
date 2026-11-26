# Servidor ≠ aplicación + default creds + import hijacking de Python → root

> **Writeup sanitizado.** Flags y credenciales redactadas. Metodología y razonamiento, sin regalar la sala.

**Tipo:** Linux · Intermediate
**Cadena:** `panel web (realm identifica la app) → credenciales por defecto → consola = www-data → sudo python + import hijacking → root`

---

## 1. Recon — leer el nombre, no la versión
Entre varios puertos (tres SSH con la misma host key = un mismo servicio repetido; telnet; SMTP; DNS), la superficie real es un **panel web** en un puerto alto, servido por un servidor web ligero, que responde con **HTTP 401 Basic Auth**.

> **Lección — servidor ≠ aplicación.** Es fácil fijarse en la versión del *servidor web* y ponerse a buscar exploits de él. Pero el servidor es solo el contenedor. El dato que importa está en la cabecera de autenticación: **`WWW-Authenticate: Basic realm="<Nombre>"`**. El `realm` es una etiqueta que el servidor elige, y casi siempre **es el nombre de la aplicación**. Regla transferible: **un `realm` que no es una palabra genérica ("Restricted", "Admin") es un nombre de producto → búscalo** (`searchsploit <nombre>`, credenciales por defecto, CVEs). El reflejo no es *conocer* el producto; es tratar cualquier nombre propio que te da el escáner como una pista que hay que buscar.

## 2. Foothold — un muro de auth se prueba, no se explota (todavía)
El panel pide usuario y contraseña.

> **Lección — ante un Basic Auth, credenciales por defecto PRIMERO.** Antes de buscar bypasses o exploits, el disparo de 10 segundos son las credenciales documentadas del producto. Entraron. El panel, además, incluía una **consola web** que ejecuta comandos como el usuario del servicio web.

> **Lección — una consola web es un webshell (HTTP, sin TTY).** Para trabajar de verdad hace falta una reverse shell. Detalle de campo: **no estaba `curl`, pero sí `wget`** — y con ejecución de comandos ya en mano, la reverse se lanza igual (fetch con wget, o directamente *inline* con el intérprete que haya: bash `/dev/tcp`, python, perl, nc). "No hay curl" no es un muro; es cambiar de herramienta.

## 3. Privesc — `sudo -l`, el mismo binario con otro significado
```
(ALL) NOPASSWD: /usr/bin/python /home/<user>/<script>.py
(ALL) NOPASSWD: systemctl start|stop|restart <servicios>
```

> **Lección — el mismo binario en `sudo -l` no es el mismo privesc.** Aquí vuelve a aparecer `systemctl` (como en otra caja reciente), pero es `start/stop/restart` de servicios concretos — **no `status`**, que es el que pagina su salida con `less` y permite el escape a shell. Sin paginador, no hay vector ahí. **Lo que manda es el subcomando y qué hace** (¿lee? ¿escribe? ¿pagina? ¿ejecuta algo que yo controlo?).

El vector real es el **script de Python ejecutado como root**. No se puede editar (es de root), pero solo hace `import <modulo>` de un módulo que **no existe**.

> **Lección — import hijacking: no editas el script, le DAS el módulo que le falta.** Cuando un script que corre como root importa un módulo local, Python lo busca en su `sys.path`, y la primera entrada es **el directorio del propio script**. Si puedes **crear un fichero en ese directorio**, creas `<modulo>.py` con el **nombre exacto del import**, y el código a nivel de módulo se ejecuta **en el propio import** — como root. Payload mínimo: `os.setuid(0); pty.spawn("/bin/bash")`.

> **Lección — al leer permisos, mira TU triada.** El directorio del script parecía "no escribible" a primera vista, pero su **propietario** era justo el usuario del servicio web: los bits de *owner* (`rwx`) son los que aplican, no el `r-x` de grupo/otros. Identifica siempre qué triada te corresponde antes de concluir que no puedes escribir.

## Qué me llevo
- **Lee el nombre, no solo la versión.** `realm="<producto>"` → busca el producto, no el servidor web que lo sirve.
- **Basic Auth → credenciales por defecto primero**, antes que exploits.
- **Falta una herramienta de descarga → usa otra** (wget/python/perl/nc), o lanza la reverse inline; no es un bloqueo.
- **Mismo binario en `sudo -l` ≠ mismo vector:** el subcomando lo cambia todo (`status` pagina → escape; `restart` no).
- **Import hijacking:** script root con `import <local>` + directorio escribible → módulo con el nombre exacto, payload a nivel de módulo (corre en el import). No se edita el script de root.
- **Permisos: identifica tu propia triada** (owner/grupo/otros) antes de decir "no puedo".

<sub>⚠️ Contenido educativo sobre un laboratorio autorizado. Flags y credenciales redactadas.</sub>
