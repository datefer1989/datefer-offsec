# Jacko (Proving Grounds) — H2 Console RCE (native lib) + GodPotato

> **Writeup sanitizado.** Flags redactadas. Metodología y razonamiento, sin regalar la sala.

**Tipo:** Windows · Intermediate
**Cadena:** `H2 Database console → RCE (DLL nativo, sin javac) → SeImpersonate → GodPotato → SYSTEM`

---

## 1. Recon
- **8082** → **H2 Database Console** (web). **9092** → H2 TCP server. El **:80** (IIS) redirige a H2 y es distracción.
- La consola de H2 permite conectar con `sa` sin contraseña → vista SQL. `SELECT H2VERSION()` → **1.4.199**.

## 2. Foothold — H2 console RCE sin `javac`
El RCE clásico de H2 por consola es `CREATE ALIAS ... AS $$ <java> $$`, que **compila Java en el target**. Aquí falla:
```
Cannot run program "javac"
```

> **Lección — el target solo tiene JRE (no JDK), así que no compila Java inline.** La salida es la técnica del **DLL nativo** (`JNIScriptEngine`): se carga una librería con `java.lang.System.load` (un método **ya compilado**, sin `javac`) que expone una función `eval` desde la que ejecutar comandos.

> **Lección operativa — pelearse con un exploit "gigante".** El PoC de referencia es un **fichero de instrucciones** cuya línea que incrusta el DLL pesa cientos de KB (el binario byte a byte). Abrirlo en un editor gráfico o manejarlo por el portapapeles **lo rompe**. Se trabaja desde la terminal: leer el resto del fichero saltando esa línea, y volcar solo esa línea al portapapeles por CLI para pegarla una vez. El resto son comandos cortos que se teclean. **Dominar `sed`/`xclip` para esto ahorra muchísimo tiempo y frustración.**

Con el DLL cargado y el alias `eval` creado, se obtiene ejecución de comandos como el usuario de servicio (`tony`), y desde ahí una reverse shell (descarga con `certutil` + ejecución). Detalle: **el PATH del proceso está recortado**, así que hay que usar **rutas absolutas** (`C:\Windows\System32\...`).

## 3. Privesc — SeImpersonate → GodPotato
```
whoami /priv    → SeImpersonatePrivilege: Enabled
```
Cuenta de servicio con **SeImpersonate** = se puede robar un token de SYSTEM (familia *Potato*).

> **Lección — por qué PrintSpoofer falla y GodPotato funciona.** Ambos abusan de SeImpersonate, pero por **gatillos distintos**: PrintSpoofer usa el **Print Spooler**; si el servicio está parado/deshabilitado, **da timeout**. GodPotato usa **DCOM/RPC (RPCSS)**, que está **siempre activo** → funciona donde PrintSpoofer no. (Evolución de la familia: JuicyPotato → RoguePotato → PrintSpoofer → GodPotato, cada uno cubre casos que el anterior no.)

GodPotato, lanzando el comando **a través de `cmd /c`** (su `-cmd` crea el proceso directo, sin shell, así que sin `cmd /c` fallan los argumentos/PATH), devuelve una shell como **NT AUTHORITY\SYSTEM**.

## Qué me llevo
- **H2 console sin javac → DLL nativo**, no `CREATE ALIAS $$ $$`. Confirma la versión y el entorno antes de elegir método.
- **Manejar exploits enormes desde terminal** (`sed`/`xclip`), no en editores gráficos.
- **PATH recortado → rutas absolutas.**
- **SeImpersonate:** si PrintSpoofer da timeout (Spooler off), **GodPotato** (RPCSS). Y su `-cmd` siempre con `cmd /c`.

<sub>⚠️ Contenido educativo sobre un laboratorio autorizado. Flags redactadas.</sub>
