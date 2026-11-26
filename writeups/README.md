# 📝 Writeups

Writeups **sanitizados y orientados a técnica**: me centro en la **metodología, el razonamiento y las lecciones** —qué me desatascó y por qué—, no en el paso a paso que haga trivial una máquina concreta. Credenciales, hashes, flags, nombres de host/usuario y nombres de máquina van **fuera**. El objetivo es enseñar *cómo se piensa* un vector, no regalar una solución.

| Writeup | Plataforma | Tipo | Lo que entrena |
|---|---|---|---|
| [Reset](./reset-thm-ad.md) | TryHackMe | Active Directory (standalone) | De `null session` a Domain Admin: cadena de ACLs + delegación constrained |
| [Raz0rblack](./raz0rblack-thm-ad.md) | TryHackMe | Active Directory (standalone) | De `null` a Domain Admin: AS-REP + Kerberoast + abuso de `SeBackupPrivilege` (NTDS → PtH) |
| [SoupedeCode 01](./soupedecode01-thm-ad.md) | TryHackMe | Active Directory (standalone) | De `null` a Domain Admin: password spray (`pass=user`) + Kerberoast + PtH-spray a cuenta de máquina |
| [Enterprise](./enterprise-thm-ad.md) | TryHackMe | Active Directory (dominio hijo) | Foothold por fuga de credencial en historial de Git + Kerberoast → SYSTEM por **Unquoted Service Path** |
| [Kenobi](./kenobi-thm-linux.md) | TryHackMe | Linux | Encadenar SMB + **ProFTPD mod_copy** + **NFS** → SSH → **SUID PATH hijacking** |
| [SaltStack unauth RCE](./saltstack-unauth-rce.md) | Lab | Linux | **SaltStack** CVE-2020-11651 → RCE root; y qué hacer cuando el PoC no compila y MSF no da shell |
| [CMS upload + exiftool cron](./cms-upload-exiftool-cron.md) | Lab | Linux | upload a un CMS → cron de root con **exiftool** sobre dir escribible → **CVE-2021-22204** |
| [Grav CMS + SUID php](./grav-cms-suid-php.md) | Lab | Linux | **Grav CMS** Scheduler RCE → **SUID php** (`pcntl_exec -p`) → root |
| [SmarterMail .NET deserialization](./dotnet-remoting-deserialization.md) | Lab | Windows | **SmarterMail** .NET Remoting deserialization (**CVE-2019-7214**) → SYSTEM |
| [H2 Console RCE + GodPotato](./h2-console-rce-godpotato.md) | Lab | Windows | **H2 Database** console RCE (DLL nativo, sin javac) → **SeImpersonate → GodPotato** → SYSTEM |
| [RFI + tarea programada](./rfi-scheduled-task-writable-binary.md) | Lab | Windows | **RFI** (XAMPP) → RCE → **tarea programada con binario escribible** → SYSTEM |
| [WP upload + SUID "File write"](./wordpress-upload-suid-filewrite.md) | Lab | Linux | WP plugin **upload no-auth** → egress solo-80 (reverse base64 inline) → reuso creds SSH → **SUID solo "File write"** → `/etc/sudoers` → root |
| [Postgres + rbash + docker](./postgres-rce-rbash-docker.md) | Lab | Linux | **ident (113)** filtra usuario + **Postgres default creds** → `COPY TO PROGRAM` → reuso `user:user` SSH → escape de **rbash** (`ed`) → **grupo docker** → root |
| [vhost + TeamCity + pager sudo](./vhost-teamcity-sudo-pager.md) | Lab | Linux | **vhost por cert TLS** → TeamCity **CVE-2024-27198** → clave SSH de perfil crackeada → correo local → **GECOS** → **sudo `systemctl status`** pager (CVE-2023-26604) → root |
| [default creds + Python import hijack](./defaultcreds-python-import-hijack.md) | Lab | Linux | **realm = nombre de app** (servidor≠app) → default creds → consola web → **sudo python + import hijacking** → root |

> 🌱 Se amplía con cada máquina que rooteo. Writeups de **laboratorios de pago** → siempre en modo técnica, sin nombre de máquina (respeto de los términos de la plataforma). Prioridad: Active Directory puro y pivoting.
