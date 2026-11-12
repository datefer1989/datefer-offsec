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

> 🌱 Se amplía con cada máquina que rooteo. Prioridad: Active Directory puro y pivoting.
