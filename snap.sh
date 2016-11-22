#!/bin/ksh

set -eu

red="\033[01;31m"
yellow="\033[01;33m"
green="\033[01;32m"
bold="\033[01;39m"
white="\033[0m"

bsds=''
sets=''
xsets=''

set -A bsds 'bsd' 'bsd.mp' 'bsd.rd'
set -A sets 'comp' 'man' 'base'
set -A xsets 'xbase' 'xfont' 'xshare'
base_sig='SHA256.sig'
build_info='BUILDINFO'

spath=$(dirname -- "$(command -v -- "$0")")
sname="${0##*/}"

function usage {
  cat <<EOF

snap options:

  -s force snap to use snapshots.
  -S do not check signatures.
  -c specify location of config file (default is ~/.snaprc)
  -e just extract sets in DST.
  -m <machine> use <machine> instead of what 'machine' returns.
  -v <version> used to force snap to use <version> (examples: snapshots or 5.3).
  -V <setversion> used to force snap to use <setversion> for sets (example: -V 5.3). Note: this will only append 53 to sets, ie base53.tgz.
  -r run sysmerge after extracting {x}sets. (May dump core if the snapshots have introduced ABI changes. Not recommended.)
  -x do not extract x11 sets.
  -i interactive with colors.
  -n force using bsd.mp as bsd.
  -k only install kernels and exit.
  -K install only the sets without the kernel.
  -b device to install bootstrap to.
  -R reboot after installation.
  -h help.

  Examples:
    To update to the latest snapshot using the fastest mirror for your
    region:

      snap -s -M ftp3.usa.openbsd.org

    To update to the latest version of 5.3 without updating xsets:

      snap -v 5.3 -V 5.3 -x -M ftp3.usa.openbsd.org

  Example ~/.snaprc
    INTERACTIVE:true
    DST:/tmp/upgrade
    MERGE:true
    MIRROR:ftp3.usa.openbsd.org
    NO_X11:true
    FTP_OPTS:-C -V

EOF
  exit 0
}

function get_conf_var {
  RET=''
  if [[ -e $CONF_FILE ]]; then
    RET=$(grep $1 $CONF_FILE | awk -F : '{if ($1 !~ /^#/) {print $2}}')
  fi
  if [[ "${RET}X" == "X" ]]; then
    return 1
  fi
  echo $RET
}

function msg {
  if [[ $INTERACTIVE == true ]]; then
    echo "${green}${1}${white}"
  fi
}

function warn {
  if [[ $INTERACTIVE == true ]]; then
    echo "${yellow}${1}${white}"
  fi
}

function error {
  if [[ $INTERACTIVE == true ]]; then
    >&2 echo "${red}${1}${white}"
  else
    >&2 echo "${sname}: $1"
  fi

  if [[ $2 == true ]]; then
    rollback
  fi

  exit 1
}

function backup {
  FAIL=0
  cp -p /bsd /obsd || FAIL=1
  cp -p /bsd.rd /obsd.rd || FAIL=1
  cp -p /sbin/reboot /sbin/oreboot || FAIL=1

  if [ -e /bsd.sp ]; then
    cp -p /bsd.sp /obsd.sp || FAIL=1
  fi

  if [ $FAIL == 1 ]; then
    error "Failed to backup" false
  else
    msg "Backed up the following:
    ${bold}/bsd => /obsd
    /bsd.rd => /obsd.rd
    /sbin/reboot => /sbin/oreboot${green}"
  fi
}

function rollback {
  FAIL=0
  cp /obsd /bsd || FAIL=1
  cp /obsd.rd /bsd.rd || FAIL=1

  if [ -e /obsd.sp ]; then
    cp /obsd.sp /bsd.sp || FAIL=1
  fi

  cp /sbin/oreboot /sbin/reboot || FAIL=1

  if [ $FAIL == 1 ]; then
    error "Failed to rollback" false
  else
    msg "Restored the old files for the following:
    ${bold}/bsd => /obsd
    /bsd.rd => /obsd.rd
    /sbin/reboot => /sbin/oreboot${green}"
  fi
}

function verisigs {
  KEY=/etc/signify/openbsd-${SETVER}-base.pub
  VALID=true

  if [ -f "$KEY" ]; then
    for i in "$@"; do
      signify -V -e -p ${KEY} -x SHA256.sig -m - | sha256 -C - ${i} || VALID=false
    done

    if [ $VALID == false ]; then
      error "Invalid signature found! They are after you!" true
    fi
  else
    error "No pub key found for this release! (${KEY})" false
  fi
}

function update_kernel {
  FAIL=0

  verisigs "bsd*"

  cp ${KERNEL} /bsd || FAIL=1
  cp ${RD} /bsd.rd || FAIL=1

  if [[ "${KERNEL}" == 'bsd.mp' ]]; then
    cp bsd /bsd.sp || FAIL=1
  fi

  if [ $FAIL == 1 ]; then
    error 'Failed to copy new kernel' false
  else
    msg "Set primary kernel to ${KERNEL}:
    ${KERNEL} => /bsd"
  fi
}

function fetch {
  DF=$(echo $1 | awk -F/ '{print $NF}')
  TDF="${DF}.out"
  R=0

  # this check may cause signature issues.. if old files exist in
  # the DEST directory.
  if [ ! -e $DF ]; then
    /usr/bin/ftp $FTP_OPTS -o $TDF $1
    R=$?
    # move the tmp file to actual file name so we can use -C
    mv $TDF $DF
  fi

  return $R
}

function extract {
  ftp -D Extracting -Vmo - "file://${1}" | tar -C / -xzphf - \
    || error "Failed to extract ${1}" false
}

CONF_FILE=~/.snaprc
USE_BUILDINFO=true
INTERACTIVE=$(get_conf_var 'INTERACTIVE' || echo 'false')
DST=$(get_conf_var 'DST' || echo '/tmp/upgrade')
FTP_OPTS=$(get_conf_var 'FTP_OPTS' || echo " -4V ")
INSTBOOT=$(get_conf_var 'INSTBOOT' || echo 'sd0')
MACHINE=$(machine)
MERGE=$(get_conf_var 'MERGE' || echo 'false')
SETVER=$(uname -r | tr -d \.)
VER=$(get_conf_var 'VER' || echo "$(uname -r)")
REBOOT=$(get_conf_var 'REBOOT' || echo 'false')
AFTER=$(get_conf_var 'AFTER' || echo 'false')

MIRROR=$(get_conf_var 'MIRROR' || echo 'http://ftp.eu.openbsd.org')

while getopts "b:Bc:ehiIkKm:M:nrRsSuUv:V:x" arg; do
  case $arg in
    c)
      CONF_FILE=$OPTARG
      ;;
    h)
      usage
      ;;
    i)
      INTERACTIVE=true
      ;;
    m)
      MACHINE=$OPTARG
      ;;
    r)
      MERGE=true
      ;;
    R)
      REBOOT=true
      ;;
    s)
      VER='snapshots'
      ;;
    v)
      VER=$OPTARG
      ;;
    V)
      SETVER=$(echo $OPTARG | tr -d \.)
      ;;
    *)
      exit 1
  esac
done

# [[ $(id -u) -ne 0 ]] && error "need root privileges" false

if [ $VER != "snapshots" ]; then
  kern_ver=$(sysctl kern.version | grep -oE "\-(current|beta)")
  if [ $? == 0 ]; then
    msg "kern.version: ${white}reporting as $kern_ver on ${MACHINE}"
    VER='snapshots'
  fi
fi

mkdir -p -- "$DST" || exit 1

case "${MIRROR}" in
  http://* | ftp://* | https://*)
    URL="${MIRROR}/pub/OpenBSD/${VER}/${MACHINE}"
    ;;
  *)
    URL="http://${MIRROR}/pub/OpenBSD/${VER}/${MACHINE}"
    ;;
esac

msg "${white}Fetching from: ${green}${URL}"

(
  cd -- "$DST" || exit 1

  RD=${bsds[2]}

  fetch "${URL}/${base_sig}" || error "Can't fetch signature file!" false
  fetch "${URL}/${build_info}" || error "Can't fetch buildinfo file!" false

  if [ -e ~/.last_snap ]; then
    last_snap=$(cat ~/.last_snap)
    msg "last snap: ${white}${last_snap}"
    if [ $USE_BUILDINFO ]; then
      current_snap=$(awk -F- '{print $2}' "$build_info" | sed 's/^ //')
      if [ "${last_snap}" == "$current_snap" ]; then
        warn "No new snaps available, mirror has: ${current_snap}!"
        exit 1
      fi
    fi
  fi

  msg "Fetching bsds"
  for bsd in "${bsds[@]}"; do
    fetch "${URL}/${bsd}" || error "Can't find bsds at ${URL}" false
  done
  if [ "$(sysctl -n hw.ncpufound)" == "1" ]; then
    msg "${white}Using ${green}bsd.."
    KERNEL=${bsds[0]}
  else
    msg "${white}Using ${green}bsd.mp.."
    KERNEL=${bsds[1]}
  fi
  backup
  update_kernel

  msg "Fetching sets"
  for set in "${sets[@]}"; do
    fetch "${URL}/${set}${SETVER}.tgz" || error "Perhaps you need to specify -V to set version. Example 5.2" true
  done

  msg "Fetching xsets"
  for set in "${xsets[@]}"; do
    fetch "${URL}/${set}${SETVER}.tgz" || error "Perhaps you need to specify -V to set version. Example -V 5.2" true
  done

  verisigs "*.tgz"

  msg "Remounting filesystems (rw)"
  mount -o rw -u /usr || error "Can't remount /usr partition!" false
  mount -o rw -u /usr/X11R6 || error "Can't remount /usr/X11R6 partition!" false

  msg "Extracting sets"
  for set in "${sets[@]}"; do
    extract "${DST}/${set}${SETVER}.tgz"

    if [ "${set}" == "man" ]; then
      msg "Extracting xsets ${white}will continue with sets after. ${green}"

      for xset in "${xsets[@]}"; do
        extract "${DST}/${xset}${SETVER}.tgz"
      done
    fi
  done

  msg "Rebuilding whatis databases:"
  makewhatis -Q

  msg "Remounting filesystems (ro)"
  mount -o ro -u /usr || error "Can't remount /usr partition!" false
  mount -o ro -u /usr/X11R6 || error "Can't remount /usr/X11R6 partition!" false

  if [ $MERGE == true ]; then
    msg "Running sysmerge"
    sysmerge || error 'Failed to sysmerge!' false
  else
    echo '/usr/sbin/sysmerge -b' >/etc/rc.sysmerge
    chmod +x /etc/rc.sysmerge
    echo "Don't forget to run sysmerge!"
  fi

  msg "Installing bootstrap on ${INSTBOOT}"
  installboot -v $INSTBOOT || error "Something bad happened - check your boot disk!" false

  if [ $USE_BUILDINFO ]; then
    awk -F- '{print $2}' "$build_info" | sed 's/^ //' > ~/.last_snap
  else
    date > ~/.last_snap
  fi

  echo 'cd /dev && sh MAKEDEV all' >/etc/rc.firsttime
  echo '/usr/sbin/fw_update' >>/etc/rc.firsttime
  chmod +x /etc/rc.firsttime

  if [ $REBOOT == true ]; then
    msg 'Rebooting'
    /sbin/oreboot || error "Something really bad happened - Can't reboot!" false
  fi
)
