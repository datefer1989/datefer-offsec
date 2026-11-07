# Reset (TryHackMe) — de null session a Domain Admin

> **Writeup sanitizado.** Credenciales, hashes y flags van redactados (`<redacted>`). Es un recorrido de **metodología y lecciones**, no un walkthrough que trivialice la sala. Si estás haciéndola, úsalo para desatascarte, no para saltártela.

**Tipo:** Active Directory standalone · Windows Server · dominio de ejemplo `corp.local`
**Resumen de la cadena:**
`null → acceso a share por nombre → onboarding (semilla) → robo de NTLM por coacción → AS-REP roast → cadena de ACLs en BloodHound → delegación constrained → Domain Admin`

---

## 1. Recon

DC clásico: Kerberos (88), LDAP (389/636/3268), SMB (445), DNS, RDP, a veces WinRM. Identificar dominio y nombre del DC desde el propio escaneo.

## 2. Enumeración anónima: todo capado (pero NO es callejón)

Null session, pero la enumeración de usuarios/shares/RPC devuelve `ACCESS_DENIED`. Dos ideas que desbloquean:

- **`Null Auth: True` ≠ `guest`.** El null autentica pero mapea a invitado; la cuenta `guest` suele estar deshabilitada. No confundir "me autentica" con "tengo acceso".
- **🔑 La clave de la caja: "no poder LISTAR shares" ≠ "no poder ACCEDER a un share".** El `NetShareEnum` puede estar capado para null y aun así un share **accesible por su nombre** deja entrar. Prueba nombres directamente.

> ⚠️ **Rabbit hole que me comí:** irme a enumeración de usuarios por Kerberos con una wordlist gigante. No hacía falta; el camino era acceder al share directo. El userenum por Kerberos llega **más tarde y con credenciales**.

## 3. Share accesible → material de onboarding (la semilla)

Accediendo al share por su nombre aparece documentación de onboarding (un email de bienvenida) con un **nombre de usuario** y una **contraseña inicial**. Lectura en Linux de PDFs/ficheros: `pdftotext`, `exiftool` para metadatos.

## 4. La credencial de onboarding es una semilla, no una llave

Loguear con ese usuario da un "éxito" engañoso de invitado. El **juez definitivo es Kerberos**:

```bash
impacket-getTGT corp.local/<user>:'<pass>'
```
- `KDC_ERR_C_PRINCIPAL_UNKNOWN` → la cuenta **no existe** (era solo semilla/decoy).
- `KEY_EXPIRED` → pass válida pero caducada (resetear).
- `KDC_ERR_PREAUTH_FAILED` → pass incorrecta.
- TGT guardado → credenciales válidas.

> **Lección:** `getTGT` desambigua el estado de una cuenta mucho mejor que el "(Guest)" de otras herramientas, que es un falso amigo.

## 5. Foothold real: robo de NTLM por coacción

**El disparador** (lo que lo delata sin guía): una carpeta del share es **escribible** y sus ficheros **se regeneran solos con nombres cambiantes** → hay un proceso/usuario que **renderiza la carpeta** → se le puede **coaccionar la autenticación**.

Técnica: dejar en el share escribible un fichero trampa (p. ej. un `.lnk`/`.url` que apunte a mi host) + `Responder` a la escucha → el proceso "visita" la carpeta y suelta un **NetNTLMv2**:

```bash
sudo responder -I <iface> -wv
# ...dejar el fichero trampa en el share...
hashcat -m 5600 <hash_capturado> rockyou.txt
```

Resultado: credenciales de una **cuenta de servicio** → shell de usuario (p. ej. WinRM) → **user flag**.

> **Lección:** share escribible + ficheros que se auto-regeneran = render automático = oportunidad de robo de NTLM. Es un disparador fácil de pasar por alto.

## 6. Escalada en el dominio

### 6.1 AS-REP roast (ya autenticado)
Con la cuenta de servicio, pedir al dominio los usuarios sin preauth. Ya autenticado, la herramienta enumera el dominio sola:
```bash
impacket-GetNPUsers corp.local/<svc>:'<pass>' -request -dc-ip <DC> -format hashcat
hashcat -m 18200 <asrep_hash> rockyou.txt
```
Cae un usuario con una ACL interesante.

### 6.2 BloodHound → la escalera de ACLs
Recolección autenticada (`bloodhound-python -c All`) y *Shortest paths to Domain Admins*. Sale una **cadena de abuso de permisos** encadenados:

```
UserA  --GenericAll-->          UserB
UserB  --ForceChangePassword--> UserC
UserC  --GenericWrite-->        UserD (objetivo)
```

> ⚠️ **Gotcha:** el *display name* de BloodHound **≠ `sAMAccountName`**. Para los comandos necesito el sAMAccountName exacto (lo saco del campo del nodo o con `nxc ... --users | grep`).

### 6.3 Bajar la escalera reseteando contraseñas
`GenericAll`, `ForceChangePassword` y (aquí) `GenericWrite` sobre un usuario permiten **resetear su contraseña** con `bloodyAD`:
```bash
bloodyAD --host <DC> -d corp.local -u <userA> -p '<passA>' set password <userB> '<newpass>'
```
Verifico cada salto con `getTGT` (el juez de nuevo), no con el "(Guest)" mentiroso.

> ⚠️ **Paso con estado:** hazlo del tirón. Si la máquina se reinicia a medias, los resets se deshacen.

### 6.4 El final: delegación **constrained** → Domain Admin
El usuario objetivo tiene el atributo `msDS-AllowedToDelegateTo` poblado hacia un SPN **que apunta al DC** (y *Trusted For Constrained Delegation*). Eso permite pedir un ticket de servicio **impersonando a cualquiera** (S4U) contra ese SPN:

```bash
impacket-getST -spn '<spn_del_DC>' -impersonate 'Administrator' 'corp.local/<userD>:<newpass>' -dc-ip <DC>
export KRB5CCNAME=<fichero.ccache_que_imprime_getST>
impacket-wmiexec -k -no-pass corp.local/Administrator@<DC_FQDN>
```
→ shell como Administrator en el DC → **root flag**.

> **Lección clave:** **delegación constrained ≠ RBCD.** En constrained el permiso vive en la cuenta atacante (lo que ELLA puede delegar). Si el SPN permitido apunta al DC → `getST` impersonando Administrator = **DA**. (Truco extra: `-altservice` reescribe la parte del servicio del ticket sin cambiar el host, p. ej. de `cifs` a `ldap` para DCSync.)

---

## Lecciones transversales

1. `Null Auth: True` ≠ guest, y **listar shares ≠ acceder a un share por su nombre** (la clave del foothold).
2. **`getTGT` es el juez del estado de una cuenta** — muy por encima de un "(Guest)" engañoso.
3. **Share escribible con ficheros que se auto-regeneran = render automático → robo de NTLM.**
4. **Cadena de ACLs = seguir la arista hacia DA y resetear, no pensar.** GenericAll / ForceChangePassword / GenericWrite (sobre usuario) = reset con bloodyAD.
5. **Constrained delegation ≠ RBCD.** SPN hacia el DC + S4U impersonando Administrator = Domain Admin.

> **Meta-lección:** cuando `evil-winrm` dejó de entrar tras un redeploy, no eran las credenciales — el puerto 5985 estaba **filtrado** (el nmap lo decía). No te obceques con las creds: lee el escaneo.
