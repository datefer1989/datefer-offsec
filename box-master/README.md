# 🎮 Box Master

**Una herramienta de gamificación para entrenar pentesting** — y, de paso, para entrenar a un LLM a hacer de "máquina vulnerable + coach".

## La idea

Practicar máquinas tipo OSCP tiene un problema: cuando lees un writeup, aprendes la solución pero **no entrenas la decisión** (que es justo donde uno se atasca en el examen). Box Master invierte el flujo:

- **Tú conduces.** Decides cada movimiento (qué enumerar, qué atacar, qué comando lanzar).
- **El LLM hace de máquina.** Renderiza salidas realistas de la caja (nmap, respuestas HTTP, shells…).
- **Y hace de oráculo-coach.** Si te atascas, da pistas **mínimas y escalonadas** (te señala la sección de tu chuleta → nombra la clase de vulnerabilidad → como último recurso, el comando exacto), nunca la solución de golpe.

El objetivo pedagógico: convertir las **fases abiertas** (decidir qué mirar) en un **automatismo entrenado**, que es lo que separa aprobar de no aprobar.

## Qué hay en este directorio

- [`box-master.md`](./box-master.md) — el **prompt del Game Master** + una **librería de cajas simuladas**. Cada caja es una "spec" con: SO, dificultad, servicios, superficie de ataque, cadena de explotación, credenciales, flags, ruido realista y una **lección pedagógica**.

## Cómo se usa

1. Copia el **prompt del Game Master** (al inicio de `box-master.md`) en un LLM.
2. Pégale la **spec de una caja** (o pídele que elija una por dificultad/tags).
3. Empieza a jugar: `nmap -sC -sV <ip>` y a partir de ahí, tú decides.

## Librería actual

14 cajas simuladas cubriendo vectores que **se usan poco y conviene tener frescos**:

| Caja | SO | Vector estrella |
|---|---|---|
| Keystone · Ledger · Cobalt | Linux | SSTI · capabilities · Redis unauth |
| Vault · Sentinel · Relay | Mixto/AD | SMB + SeImpersonate · AD · LD_PRELOAD |
| Mint · Harbor | Linux | LFI + NFS no_root_squash · SQLi + /etc/passwd |
| Onyx · Basalt | AD | spray `pass=user` + PtH-spray a máquina · SeBackupPrivilege → NTDS |
| Thornbury | Linux | LFI → log poisoning → cred reuse → **tar wildcard injection** |
| Marwick | Linux | command injection (bypass filtro) → id_rsa 644 → **PATH hijacking** |
| Blackmoor | Windows | Tomcat default creds → **WAR deploy RCE** → SeImpersonate → PrintSpoofer |
| Quill | Linux | FTP anónimo → id_rsa (passphrase, ssh2john) → **sudo awk (GTFOBins)** |

> 🌱 La librería crece cada vez que juego o rooteo una caja nueva. Siguiente objetivo: añadir specs de cadenas de **Active Directory** más largas (pivoting + delegación).

---

<sub>Cajas **simuladas e inventadas**: no reproducen ninguna máquina real de ninguna plataforma. Es material didáctico original.</sub>
