# 🧪 PoCs & Exploits

Pruebas de concepto **funcionales** que he escrito o reescrito mientras trabajaba una vulnerabilidad — normalmente porque los exploits públicos no arrancaban (dependencias obsoletas) o no se comportaban como se esperaba. Cada carpeta lleva el **CVE en el nombre** para que sea fácil de encontrar.

> ⚠️ **Solo para pruebas autorizadas y fines educativos** (CTF, laboratorios propios, sistemas con permiso explícito por escrito). Cada PoC incluye su disclaimer.

| CVE | Software | Qué es | Carpeta |
|---|---|---|---|
| CVE-2020-11651 / 11652 | **SaltStack** `salt-master` | Auth bypass + traversal → **RCE root**. Cliente sin dependencias (`pyzmq`+`msgpack`) que reemplaza a los PoC que no compilan en Python moderno. | [`CVE-2020-11651-saltstack-salt-master-unauth-rce`](./CVE-2020-11651-saltstack-salt-master-unauth-rce) |

> 🌱 La carpeta crece cuando una caja me obliga a reescribir un exploit para que funcione.
