# Scrutiny (Proving Grounds) — vhost por certificado + TeamCity auth bypass + lateral encadenado + pager de sudo

> **Writeup sanitizado.** Flags y credenciales redactadas. Metodología y razonamiento, sin regalar la sala.

**Tipo:** Linux (Ubuntu 20.04) · Intermediate
**Cadena:** `cert/web → vhost → TeamCity auth bypass (CVE-2024-27198) → clave SSH crackeada → correo local → fichero oculto + GECOS → sudo systemctl status (CVE-2023-26604) → root`

---

## 1. Recon — el dominio está en los metadatos
Tres puertos: SSH, SMTP (Postfix) y HTTP (nginx). Lo que desbloquea la caja no es un servicio ruidoso, es un **dato**: el `commonName` del **certificado TLS del SMTP** y el título de la web apuntan al mismo dominio.

> **Lección — lee el certificado.** El cert de un servicio (SMTP, HTTPS, IMAP…) suele regalar el dominio interno. Con el dominio, el acceso real está en un **virtual host** que hay que añadir a `/etc/hosts` para resolver; sin eso, el navegador no llega. Ese vhost servía un **TeamCity**.

## 2. Foothold — TeamCity (bypass de autenticación)
La versión de TeamCity es vulnerable a un **bypass de autenticación (CVE-2024-27198)**: un fallo en el manejo de rutas permite alcanzar handlers privilegiados sin sesión y **crear un administrador**.

> **Lección — "auth bypass" ≠ "RCE a pelo".** El PoC crea una cuenta admin (una puerta, no una cuenta legítima del sistema). Con ella entras al panel. Y aquí está el matiz que ahorra trabajo:

> **Lección — en un panel admin, mira los PERFILES antes de montar un RCE.** El camino más limpio no fue un build step que ejecutara una reverse, sino que un usuario tenía una **clave SSH privada subida a su perfil**. Descargada y con passphrase → se craquea offline (`ssh2john` + `john` con rockyou, cae al instante) y se entra por SSH como ese usuario. Menos ruido, shell estable directa.

## 3. Movimiento lateral — encadenado, no vertical
Al entrar por SSH, el **MOTD** avisa `You have mail.` — la caja te está señalando el siguiente paso.

> **Lección — el correo local es fuente nº1 de credenciales.** `/var/mail/<user>` (mbox) tenía un email de un **ex-empleado** cuyas credenciales seguían activas (fallo de offboarding). Con ellas, `su` al segundo usuario.

> **Lección — un NOMBRE PROPIO en el loot no es un login: mapéalo por GECOS.** En el home del segundo usuario, un **fichero oculto con nombre engañoso** (`.~`, permisos `-r--------`) revelaba la contraseña de *"Dach"*. "Dach" no es una cuenta. El **5º campo de `/etc/passwd` (GECOS)** guarda el nombre completo:
> ```bash
> getent passwd | grep -i dach      # Brian Dach -> login briand
> ```
> Resultado: tercer usuario, miembro de un grupo con sudo interesante.

## 4. Escalada a root — el pager de sudo (CVE-2023-26604)
`sudo -l` dejaba algo que parece inofensivo: `(root) NOPASSWD: /usr/bin/systemctl status <servicio>`.

> **Lección — cualquier `sudo` que abra un PAGINADOR es un escape a shell.** `systemctl status` pagina con `less`, y dentro de `less` el comando `!cmd` lanza un shell **como el dueño del proceso = root**. En **systemd < 247** no se fuerza `LESSSECURE=1`, así que el escape sigue vivo (CVE-2023-26604). Generaliza a `sudo journalctl`, `sudo git log/help`, `sudo man`, etc.

> **Lección — la trampa del paginador: solo abre `less` si la salida NO cabe en pantalla.** Con una ventana grande, `status` imprime todo de golpe y parece que "no funciona". La solución es **achicar la ventana del terminal** (pocas filas) para forzar el paginado; entonces `!bash` da root.

## Qué me llevo
- **Lee el certificado TLS** de los servicios: regala dominios y **vhosts** (añádelos a `/etc/hosts`).
- **TeamCity 2023.x → CVE-2024-27198** (auth bypass); una vez admin, **los perfiles pueden tener claves SSH** — más limpio que un RCE por build step.
- **Clave SSH con passphrase → `ssh2john` + John** (no hashcat para OpenSSH moderno).
- **Lateral encadenado**: correo local → fichero oculto → **GECOS** (`getent passwd | grep -i <apellido>`) → `su`. Cuando la privesc vertical no da, enumera correo + homes ajenos + `sudo -l` **en cada salto**.
- **`sudo` + paginador = root** (CVE-2023-26604 con `systemctl status`): `!bash` en `less`, y **achica el terminal** para forzar el pager.

<sub>⚠️ Contenido educativo sobre un laboratorio autorizado. Flags y credenciales redactadas.</sub>
