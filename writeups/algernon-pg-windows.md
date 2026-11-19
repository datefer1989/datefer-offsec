# Algernon (Proving Grounds) — SmarterMail .NET deserialization (CVE-2019-7214)

> **Writeup sanitizado.** Flags redactadas. Metodología y razonamiento, sin regalar la sala.

**Tipo:** Windows · Easy
**Cadena:** `recon completo → SmarterMail en puerto secundario (.NET Remoting) → CVE-2019-7214 → NT AUTHORITY\SYSTEM`

---

## 1. Recon — la lección está aquí
Superficie Windows típica (FTP anónimo, IIS en 80, SMB, RPC) **más dos puertos que marcan el camino**:
- **9998** → **SmarterMail** (webmail).
- **17001** → **.NET Remoting** (acompaña a SmarterMail).

Buscar un exploit por la **web** de SmarterMail no dio nada directo. La clave fue **no quedarse en el puerto obvio**: el servicio vulnerable estaba en el **puerto secundario** (17001).

> **Lección — en Windows, enumera TODOS los puertos y relaciona servicios.** Un producto (SmarterMail) + un puerto de apoyo (.NET Remoting en 17001) + su versión → te lleva al CVE correcto. El vector no tiene por qué estar en el puerto "principal".

## 2. Foothold = SYSTEM — CVE-2019-7214
Las versiones afectadas de SmarterMail exponen un servicio **.NET Remoting** que **deserializa datos sin validarlos** → ejecución de código remoto. Como el servicio corre con privilegios de **SYSTEM**, el acceso inicial **ya es la cuenta más alta**: no hay fase de escalada.

Tras un pequeño ajuste del exploit (IP/puerto de retorno y comando), la reverse shell cae directamente como **NT AUTHORITY\SYSTEM**.

> **Lección — la deserialización insegura es un clásico de RCE en apps .NET/Java antiguas.** Un `.NET Remoting` o un endpoint que acepta objetos serializados del cliente es casi siempre un vector a mirar.

## Qué me llevo
- **No te quedes en el puerto obvio:** el web de SmarterMail no tenía exploit; el bueno estaba en el **.NET Remoting (17001)**. Enumerar todo y pivotar la búsqueda por **producto + versión**.
- **Deserialización .NET = RCE.** Patrón recurrente.
- **Servicio como SYSTEM → el foothold ya es root**, sin privesc. Reconócelo y no pierdas tiempo buscando escalada.

<sub>⚠️ Contenido educativo sobre un laboratorio autorizado. Flags redactadas.</sub>
