#!/usr/bin/env sh

set -m

: "${DO_CHMOD:=true}"
: "${DO_CHOWN:=true}"

__info() {
  if [ "${1}" = "-q" ]; then
    shift 1; echo "${*}"
  else
    echo "INFO: ${*}"
  fi
}
__warning() {
  echo "WARNING: ${*}" >&2
}
__error() {
  echo "ERROR: ${*}" >&2; exit 1
}


if echo "${PUID}" | grep -q -E '^[0-9][0-9]*$' && echo "${PGID}" | grep -q -E '^[0-9][0-9]*$' && [ ${PUID} -ne 0 ] && [ ${PGID} -ne 0 ]; then
    { [ $(getent group elements | cut -d ':' -f 3) -eq ${PGID} ] || groupmod --non-unique --gid ${PGID} elements; } && \
      { [ $(getent passwd elements | cut -d ':' -f 3) -eq ${PUID} ] || usermod --non-unique --uid ${PUID} elements; } || \
      __error "Failed to change uid or gid or \"elements\" user."
fi

__info "$0: assuming uid:gid for elements:elements of $(id -u elements):$(id -g elements)"

if [ $(echo "$1" | cut -c1) = "-" ]; then
  __info "$0: assuming supplied arguments are for elementsd"
  set -- elementsd "$@"
fi

if [ "$1" = "elementsd" ]; then
  mkdir -p "$LIQUIDV1_DATA" && { \
    pgrep -f "^/usr/bin/elementsd -printtoconsole( .+|\$)" > /dev/null || { \
      rm -f "$LIQUIDV1_DATA/.pid" || __error "Failed to remove old pidfile!"
      rm -f "$LIQUIDV1_DATA/.cookie" || __error "Failed to remove cookie file!"
      cat /dev/null > "$LIQUIDV1_DATA/debug.log"
      [ "${DO_CHOWN}" != "true" ] || chown -R elements "$LIQUIDV1_DATA" || __error "chown failed!"
      [ "${DO_CHMOD}" != "true" ] || { chmod -R o-rwx "$LIQUIDV1_DATA" && chmod -R g-w "$LIQUIDV1_DATA"; } || __error "chmod failed!"
    }
  } || __error "$0: Failed to operate on data directory!"

  if [ -s "$ELEMENTSD_CONFIG/elements.conf" ]; then
    __info "$0: setting config file to \"$ELEMENTSD_CONFIG/elements.conf\""
    set -- "$@" -conf="\"$ELEMENTSD_CONFIG/elements.conf\""
  elif [ -s "$ELEMENTSD_HOME/elements.conf" ]; then
    __info "$0: setting config file to \"$ELEMENTSD_HOME/elements.conf\""
    set -- "$@" -conf="\"$ELEMENTSD_HOME/elements.conf\""
  fi
  __info "$0: setting data directory to \"$ELEMENTSD_HOME\""
  set -- "$@" -datadir="\"$ELEMENTSD_HOME\""
fi

if [ "$1" = "elementsd" ] || [ "$1" = "elements-cli" ] || [ "$1" = "elements-tx" ] || [ "$1" = "elements-wallet" ]; then
  if [ "$1" = "elementsd" ]; then
    if [ -d "$LIQUIDV1_DATA/.pre_start.d" ]; then
      for f in "$LIQUIDV1_DATA/.pre-start.d"/*.sh; do
        if [ -s "$f" ] && [ -x "$f" ]; then
          __info "$0: --- Executing \"$f\":"
          "$f" || __warning "$0: \"$f\" exited with error code $?."
          __info "$0: --- Finished executing \"$f\"."
        fi
      done
    fi
    __info "$0: launching elementsd as a background job"; echo
    shift 1; su -s /bin/sh -c "exec /usr/bin/elementsd -printtoconsole $*" elements $(: elementsd) &
    T=$(( $(date '+%s') + 10))
    while true; do
      elementsd_pid=$(pgrep -f "^/usr/bin/elementsd -printtoconsole( .+|\$)")
      [ -z "$elementsd_pid" ] || break
      [ $(date '+%s') -lt ${T} ] || { __error "$0: Failed to launch Elements Daemon."; break; }
      sleep 1
    done
    if [ -n "$elementsd_pid" ]; then
      [ -s "$LIQUIDV1_DATA/.cookie" ] || {
        T=$(( $(date '+%s') + 900))
        while true; do
          t=$(( T - $(date '+%s') )); [ ${t} -lt 10 ] || t=10
          i=$(inotifywait --event create,open --format '%f' --timeout ${t} --quiet "$LIQUIDV1_DATA")
          kill -0 $elementsd_pid > /dev/null 2>&1 || __error "$0: Elements Daemon died unexpectidly."
          if [ "${i}" = ".cookie" ] || [ -s "$LIQUIDV1_DATA/.cookie" ]; then break; fi
          [ $(date '+%s') -lt ${T} ] || { __warning "$0: Failed to get notification for Elements Daemon cookie file."; break; }
        done; }
      [ ! -s "$LIQUIDV1_DATA/.cookie" ] || chmod g+r "$LIQUIDV1_DATA/.cookie"
      __info "$0: launched elementsd as a background job"; su -s /bin/sh -c "echo $elementsd_pid > \"$LIQUIDV1_DATA/.pid\"" elements; echo
      if [ -d "$LIQUIDV1_DATA/.post_start.d" ]; then
        for f in "$LIQUIDV1_DATA/.post-start.d"/*.sh; do
          if [ -s "$f" ] && [ -x "$f" ]; then
            __info "$0: --- Executing \"$f\":"
            "$f" || __warning "$0: \"$f\" exited with error code $?."
            __info "$0: --- Finished executing \"$f\"."
          fi
        done
      fi
      kill -0 $elementsd_pid > /dev/null 2>&1 || __error "$0: Failed to start Elements Daemon."
      __info "$0: Foregrounding Elements Daemon."; fg '%?elementsd'
    else
      __error "$0: Failed to launch Elements Daemon."
    fi
  else
    echo; sudo -u elements -- "$@"
  fi
else
  echo; exec "$@"
fi
