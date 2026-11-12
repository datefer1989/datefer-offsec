# Twiggy (Proving Grounds) — SaltStack RCE y qué hacer cuando el PoC no arranca

> **Writeup sanitizado.** Flags y claves redactadas. El valor de esta caja no fue el CVE (conocido), sino el **troubleshooting**: qué haces cuando el exploit público no compila y Metasploit no te devuelve la shell.

**Tipo:** Linux · Easy
**Resumen:** `recon → identificar SaltStack en puertos raros → CVE-2020-11651/11652 (auth bypass) → RCE como root`. El `salt-master` corre como root, así que **no hay fase de privesc**.

---

## 1. Recon — el vector está en lo raro, no en el :80
- **4505 / 4506** hablando **ZeroMQ (ZMTP)** → firma de **SaltStack `salt-master`** (publish + request).
- **8000** devolviendo JSON → **salt-api**.
- **80** (Mezzanine CMS) → distracción.

> **Lección — leer el nmap como "1 app + N puertos de plumbing".** Dos puertos altos hablando ZeroMQ no son ruido: son el servicio objetivo. Reconocer la tecnología (SaltStack) es medio exploit.

## 2. El CVE
SaltStack 3000.x es vulnerable a **CVE-2020-11651** (bypass de autenticación en `ClearFuncs` del master) + **CVE-2020-11652** (path traversal). El bypass permite leer la *root key* del master y, con ella, leer/escribir ficheros y ejecutar código **como root** (el servicio corre como root).

## 3. El problema real: hacer que funcione
Aquí es donde la caja enseña de verdad. Tres obstáculos, en orden:

**a) Los PoC públicos no arrancan.** Los exploits de referencia (jasperla, ExploitDB) hacen `import salt`, y la librería `salt==3000.1` (de 2020) **no compila en Python moderno** (3.11+). No es culpa del exploit: es incompatibilidad de entorno.

**b) Metasploit saca la root key pero no da sesión.** El módulo `saltstack_salt_unauth_rce` confirma la vulnerabilidad y ejecuta el payload, pero devuelve `Exploit completed, but no session was created` probando varios puertos. El payload corre **inline en el intérprete de Salt**; con egress filtrado (o un python restringido) la reverse shell nunca vuelve.

> **Lección clave — "exploit completed, no session" ≠ "el exploit falló".** Si ves ejecución confirmada (aquí: la root key + el payload lanzado), **el RCE funciona**; lo que falla es el **canal de vuelta**. Dos salidas: probar egress en 80/443/53, o —mejor— **dejar de depender del callback**.

**c) La solución: un cliente mínimo propio.** En vez de pelear con dependencias de 2020, un cliente de ~60 líneas con solo `pyzmq` + `msgpack` (que instalan limpio en cualquier Python) habla el canal `clear` del master directamente:
- **Leer la flag** como root (`file_roots.read` con ruta absoluta) — independiente de egress.
- **Ejecutar comandos** como root capturando salida (el comando escribe a `/tmp`, se lee de vuelta; el runner de Salt es asíncrono).
- **Shell estable por SSH**: inyectar la clave pública en `/root/.ssh/authorized_keys` y entrar por el puerto 22 (abierto inbound) — sin reverse shell, sin egress.

## Qué me llevo
- **Un bug de "auth" da root** porque el servicio vulnerable ya corre como root.
- **Cuando un PoC no arranca, el 90% es el ENTORNO** (dependencias), no el código. No se leen 400 líneas: se lee el `argparse` y la función que usas.
- **Si el RCE va pero la shell no vuelve:** file-read para la flag, exec-a-fichero para comandos, o **SSH key injection** sobre un puerto abierto. Un payload *inline* puede morir donde uno que *escribe a disco* funciona.
- A veces lo más rápido para el examen es **escribir tu propio cliente mínimo** en vez de reparar un exploit viejo.

<sub>⚠️ Contenido educativo sobre un laboratorio autorizado. Flags redactadas.</sub>
