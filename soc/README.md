# 🛡️ SOC / Defensa

El lado defensivo. Vengo de operar red core en un entorno de telco (turnos, monitorización, troubleshooting en producción 24/7), así que el trabajo de SOC —triage, guardias, no perder la cabeza con una alerta a las 4am— me resulta terreno conocido. Aquí llevo el progreso.

## Roadmap

| Objetivo | Qué cubre | Estado |
|---|---|---|
| **TryHackMe — SOC Level 1 path** | Triage de alertas, análisis de red/endpoint, SIEM, threat intel | 🟡 En curso |
| **Microsoft SC-200** | Security Operations Analyst: Microsoft Sentinel, Defender, KQL | ⚪ Planificado |
| **OSCP** | Base ofensiva (pensar como el atacante para defender mejor) | 🔴 En preparación |

## Por qué ofensiva **y** defensiva

No lo veo como dos caminos separados. Entender la **cadena de ataque** (lo que practico en los writeups y en Box Master) es exactamente lo que necesita un analista SOC para **reconocer** esa cadena en los logs: una AS-REP roast, un robo de NTLM, un abuso de ACLs o una delegación rara dejan huellas concretas. Mi plan es, para cada técnica ofensiva que aprendo, apuntar **qué telemetría la delata**.

> 🌱 **Próximamente:** por cada técnica de los writeups, una nota corta de *"cómo se ve esto desde el lado azul"* (eventos de Windows, consultas KQL, artefactos de red).
