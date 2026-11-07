# 🧠 Metodología

No colecciono comandos: colecciono **decisiones**. Esta sección resume cómo ataco una máquina para no quedarme en blanco.

## El principio

> **Me atasco en las fases ABIERTAS (decidir qué mirar); fluyo en las PROCEDIMENTALES (ejecutar una receta).**
> Solución: tratar las fases abiertas como un procedimiento que **ejecuto mecánicamente**, no algo que decido en caliente.

Por eso toda mi metodología son **árboles**: cuando me bloqueo (o estoy cansado en la hora 15 del examen), no pienso — **bajo al árbol y ejecuto en orden**.

## Arranque rápido (primeros 10 min de cualquier caja)

1. **Nmap completo** → `-p-` + versión/scripts, y **no olvidar UDP** (`--top-ports 50`).
2. **Web** → `whatweb`, fuzzing de directorios y ficheros (`.php/.txt/.bak`).
3. **Credenciales que YA tengo → contra TODO** (reutilización = vector nº1 en AD).
4. **Privesc, primer vistazo** → `sudo -l` (Linux) · `whoami /priv` (Windows).

## Protocolo anti-bloqueo (cuando no sé qué hacer)

Se recorre **en orden**, sin saltarse pasos. El 90% de los atascos son enumeración insuficiente, no falta de conocimiento:

1. ¿Enumeré este servicio **a fondo**? (vuelve y aplica su checklist entero)
2. ¿Leí **TODO** el output? (nmap, PEAS, respuesta HTTP — línea por línea)
3. ¿Escaneé **todos** los puertos? ¿UDP?
4. ¿Probé mis credenciales **en todas partes**?
5. ¿Busqué **software + versión exacta** en searchsploit/Google?
6. ¿Enumeré **con credenciales** lo que antes miré sin ellas?
7. 45 min sin idea nueva → **cambio de máquina** y vuelvo.

## El patrón que se repite en todo

> **"Yo escribo / algo privilegiado ejecuta" = escalada.**
> Un fichero/binario/script que **yo** puedo escribir + que lo ejecuta root/SYSTEM/un servicio = shell privilegiada. Da igual el disparador (cron, timer, servicio, BD, GPO). Busca siempre esa combinación.

---

> 🌱 **Próximamente:** iré publicando cheatsheets concretas por área (recon, web, privesc Linux/Windows, Active Directory) a partir de mis notas privadas, limpiadas y ordenadas por esta misma lógica de decisión.
