# PostgreSQL default creds + ident como oráculo de usuarios + escape de rbash + grupo docker → root

> **Writeup sanitizado.** Flags y credenciales redactadas. Metodología y razonamiento, sin regalar la sala.
> **Honestidad:** esta caja la resolví **con ayuda de guía** en tres puntos (el pivote de credenciales, el usuario de ident y el grupo docker). La dejo documentada precisamente por las lecciones que me costaron.

**Tipo:** Linux · Intermediate
**Cadena:** `Postgres default creds → RCE (COPY TO PROGRAM) → [atasco] → ident filtra usuario → reuso de patrón user:user → SSH → escape de rbash → grupo docker → root`

---

## 1. Recon — muchos servicios, poco obvio
Superficie amplia: SSH, un servidor web **WEBrick** (app Ruby) con login `admin:admin` pero sin mucho que tocar dentro, **PostgreSQL** expuesto, un portal "en construcción" en un puerto alto, y el **113 (ident/auth)**.

> **Lección — no descartes el 113 (ident) como "no es vector".** Tenía razón en que ident no es un *punto de entrada*… pero es un **oráculo de enumeración de usuarios**: con `auth-owners` te dice **qué usuario del SO corre cada servicio**. Ese nombre es oro para el reuso de credenciales. Lo ignoré al principio y fue el error que me atascó.

## 2. Foothold — PostgreSQL por credenciales por defecto → RCE
La trampa mental: "Postgres sin credenciales no es prometedor". Falso.

> **Lección — PostgreSQL cae por default creds, y eso es el PRIMER disparo, no el último.** `postgres:postgres` (y variantes `admin:admin`, `postgres:password`…) antes que cualquier exploit. Un Postgres expuesto se prueba así en segundos.

Dentro, lo único que importa es **qué rol eres**:
```sql
SELECT current_setting('is_superuser');   -- 'on' => game over
```
Siendo superusuario, PostgreSQL deja de ser una base de datos y pasa a ser **ejecución de comandos en el SO** vía `COPY ... TO PROGRAM`. Reverse shell (ojo al egress: aquí volvió por 443). Shell como el usuario del servicio.

> **Lección — `COPY FROM/TO PROGRAM` es el vector de Postgres, no crackear hashes.** Los hashes de `pg_shadow` solo valen para reuso fuera de la DB; para RCE, si eres superuser, ejecutas y punto.

## 3. Pivote lateral — ident + patrón de credenciales
Desde la shell de Postgres, la escalada directa no salía. Aquí volví al recon y até el cabo que había dejado suelto: el **113 me había dado un nombre de usuario**.

> **Lección — encadena las dos señales débiles.** (1) ident me da un usuario válido (dato duro). (2) La caja ya había caído dos veces con el patrón `user == pass` (`admin:admin`, `postgres:postgres`) → hipótesis razonable: `usuario:usuario` en SSH. No es adivinar a ciegas; el nombre no me lo inventé, me lo dio el 113.

Funcionó: SSH como ese usuario.

## 4. Escape de rbash
El SSH cae en una **shell restringida (rbash)**: `$PATH` apunta a un único directorio con symlinks a comandos "inofensivos" (`chmod`, `chown`, `mv`, `touch`…), `cd` prohibido.

> **Lección — rbash no restringe lo que un binario permitido hace por dentro.** Entre los symlinks permitidos habían colado **`ed`**. El editor `ed` ejecuta comandos del sistema con `!` → `!/bin/bash` y fuera de la jaula. (Alternativa igual de válida: no entrar nunca en rbash, forzando `ssh user@IP -t "/bin/bash"` en la conexión.) Tras escapar, hay que **rehacer el `PATH`** porque se hereda recortado.

> **Patrón de diseño que me llevo:** cuando te dan un puñado de binarios para *manipular ficheros* y uno solo con capacidad de *lanzar procesos* (`ed`, `vi`, `less`, `awk`…), ese último es la salida.

## 5. Privesc — grupo docker
Con shell de verdad, el `id` lo cantaba: el usuario estaba en el grupo **`docker`**.

> **Lección — lee el `id`/`groups` ANTES de `sudo -l`.** `sudo -l` no me habría enseñado nada; el vector estaba en los grupos. **Grupo `docker` = root de facto:** lanzas un contenedor montando `/` del host y, como dentro eres root, escribes el host como root:
> ```bash
> docker run -v /:/mnt --rm -it <imagen_local> chroot /mnt sh
> ```
> (Usa una imagen que **ya esté** en la caja — `docker images` —; el sistema de ficheros de la imagen da igual porque `chroot` salta al del host.) Me salté esto por ir rápido enumerando: la prisa me costó la caja.

## Qué me llevo
- **ident (113) = enumeración de usuarios**, aunque no sea entrada. Nunca lo taches del recon.
- **Postgres = default creds primero** (`postgres:postgres`), y el RCE es **`COPY TO PROGRAM`**, no crackear.
- **Patrón `user:user`** entre servicios: encadena señales débiles (un nombre de ident + un patrón ya visto) en una hipótesis concreta.
- **rbash** se rompe en la conexión (`ssh -t`) o con un binario permitido con escape a shell (**`ed`**, vi, less, awk…). Rehaz el `PATH` después.
- **Lee el `id` entero antes de sudo -l**: `docker`/`lxd`/`disk`/`adm` = root casi directo y **no** aparecen en `sudo -l`.

<sub>⚠️ Contenido educativo sobre un laboratorio autorizado. Flags y credenciales redactadas.</sub>
