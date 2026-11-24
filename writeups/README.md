# 📝 Writeups

Writeups **sanitizados**: me centro en la **metodología, el razonamiento y las lecciones**, no en el paso a paso que haga trivial la sala. Credenciales, hashes y flags van **redactados**. El objetivo es enseñar *cómo se piensa la caja*, no regalar la solución.

| Caja | Plataforma | Tipo | Lo que entrena |
|---|---|---|---|
| [Reset](./reset-thm-ad.md) | TryHackMe | Active Directory (standalone) | De `null session` a Domain Admin: cadena de ACLs + delegación constrained |
| [Raz0rblack](./raz0rblack-thm-ad.md) | TryHackMe | Active Directory (standalone) | De `null` a Domain Admin: AS-REP + Kerberoast + abuso de `SeBackupPrivilege` (NTDS → PtH) |
| [SoupedeCode 01](./soupedecode01-thm-ad.md) | TryHackMe | Active Directory (standalone) | De `null` a Domain Admin: password spray (`pass=user`) + Kerberoast + PtH-spray a cuenta de máquina |
| [Enterprise](./enterprise-thm-ad.md) | TryHackMe | Active Directory (dominio hijo) | Foothold por fuga de credencial en historial de Git + Kerberoast → SYSTEM por **Unquoted Service Path** |
| [Kenobi](./kenobi-thm-linux.md) | TryHackMe | Linux | Encadenar SMB + **ProFTPD mod_copy** + **NFS** → SSH → **SUID PATH hijacking** |
| [Twiggy](./twiggy-pg-linux.md) | Proving Grounds | Linux | **SaltStack** CVE-2020-11651 → RCE root; y qué hacer cuando el PoC no compila y MSF no da shell |
| [Exfiltrated](./exfiltrated-pg-linux.md) | Proving Grounds | Linux | Subrion upload → cron de root con **exiftool** sobre dir escribible → **CVE-2021-22204** |
| [Astronaut](./astronaut-pg-linux.md) | Proving Grounds | Linux | **Grav CMS** Scheduler RCE → **SUID php** (`pcntl_exec -p`) → root |
| [Algernon](./algernon-pg-windows.md) | Proving Grounds | Windows | **SmarterMail** .NET Remoting deserialization (**CVE-2019-7214**) → SYSTEM |
| [Jacko](./jacko-pg-windows.md) | Proving Grounds | Windows | **H2 Database** console RCE (DLL nativo, sin javac) → **SeImpersonate → GodPotato** → SYSTEM |
| [Slort](./slort-pg-windows.md) | Proving Grounds | Windows | XAMPP **RFI** → RCE → **tarea programada con binario escribible** → SYSTEM |
| [Nukem](./nukem-pg-linux.md) | Proving Grounds | Linux | WP plugin **upload no-auth** → egress solo-80 (reverse base64 inline) → reuso creds SSH → **SUID solo "File write"** → `/etc/sudoers` → root |
| [Peppo](./peppo-pg-linux.md) | Proving Grounds | Linux | **ident (113)** filtra usuario + **Postgres default creds** → `COPY TO PROGRAM` → reuso `user:user` SSH → escape de **rbash** (`ed`) → **grupo docker** → root |

> 🌱 Se amplía con cada máquina que rooteo. Prioridad: Active Directory puro y pivoting.
