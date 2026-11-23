# Slort (Proving Grounds) — RFI (XAMPP) + tarea programada con binario escribible

> **Writeup sanitizado.** Flags redactadas. Metodología y razonamiento, sin regalar la sala.

**Tipo:** Windows · Intermediate
**Cadena:** `XAMPP web → fuzzing → parámetro de inclusión (RFI) → RCE → tarea programada con binario escribible → SYSTEM`

---

## 1. Recon
- Superficie real (ignorando el ruido de Windows: 135/139/445, 5040, 7680, RPC dinámico altos): **FTP (FileZilla), MySQL (MariaDB), y XAMPP (Apache/PHP en dos puertos)**.
- MySQL rechaza conexiones externas (`host not allowed`). Las rutas protegidas de XAMPP (`/dashboard`, `/phpmyadmin`) devuelven *"forbidden, local network only"* — pero eso **solo cubre esas rutas**.

> **Lección — el "forbidden" de XAMPP no es un muro total.** Solo protege rutas concretas. El resto del webroot se enumera igual → **fuzzing** (`ffuf`) revela una página con un parámetro de inclusión (`index.php?page=`).

## 2. Foothold — inclusión de ficheros → RFI
Un parámetro `?page=` que incluye ficheros. Primera comprobación siempre: **RFI** (apuntar la inclusión a un servidor propio) — si está habilitado, es **RCE instantáneo** y te saltas todo el baile de LFI.

> **Lección — RFI se prueba primero, es un test de 5 segundos.** Sirves un fichero desde tu máquina y lo incluyes; si tu servidor recibe la petición y el código se ejecuta, ganaste. (Requiere `allow_url_include=On`, raro en PHP moderno pero habitual en XAMPP antiguo.)

> **Lección — adapta el payload al SO.** Caí en dos trampas de despiste: probar `/etc/passwd` en una máquina **Windows**, y usar una reverse shell `curl | bash` donde **no hay bash**. En Windows el RFI se resuelve con **dos PHP**: uno descarga un ejecutable con `certutil`, otro lo ejecuta. Resultado: shell como el usuario del servicio web.

## 3. Privesc — tarea programada + binario escribible
Enumerando el disco (`dir C:\`) aparece una carpeta no estándar con una nota que describe una **tarea que se ejecuta cada pocos minutos como SYSTEM** y lanza un ejecutable concreto.

> **Lección — "algo que corre como SYSTEM + algo donde yo escribo = SYSTEM".** Comprobé los permisos del ejecutable con `icacls`: el grupo `Users`/`Authenticated Users` tenía control total `(F)` sobre él → **puedo reemplazarlo**. Sustituyo el binario por mi reverse shell (mismo payload de msfvenom, con el nombre que espera la tarea), y en el siguiente tick **la tarea lo ejecuta como SYSTEM**.

> **Lecciones operativas:** (1) ejecutarlo yo mismo = mi usuario; **la tarea ejecutándolo = SYSTEM** → hay que **esperar el intervalo** (latencia, como un cron-RCE). (2) La shell de msfvenom es **cmd**, no PowerShell → los cmdlets fallan ahí (usar `powershell -c` o `wmic`/`sc`). (3) Leer `icacls`: `(F)/(M)/(W)` = escribes; `(RX)/(R)` = no.

## Qué me llevo
- **Recon Windows:** descarta el ruido (5040/7680/RPC altos), ataca lo no estándar.
- **Inclusión de ficheros:** prueba **RFI primero** (RCE directo); LFI como plan B. Y **mira el SO** antes de elegir payload (`/etc/passwd` vs `win.ini`, `bash` vs PowerShell/certutil).
- **Privesc por tarea programada + binario escribible:** `icacls` para confirmar escritura; reemplaza el binario; espera el tick. No todo privesc Windows es unquoted service path.

<sub>⚠️ Contenido educativo sobre un laboratorio autorizado. Flags redactadas.</sub>
