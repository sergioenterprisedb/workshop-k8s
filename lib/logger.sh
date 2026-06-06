#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# lib/logger.sh
# Standalone logging library: leveled console output + plain-text log files.
# Source it, call init_logger early and finalize_logger before exit.
# Compatible with bash 3.2+ (macOS) / 5.x (Amazon Linux) and set -Eeuo pipefail.
# -----------------------------------------------------------------------------

# Configuration (callers may override before or after sourcing).
: "${DEBUG:=false}"
# Resolve project root from logger.sh own location (lib/ is one level below root).
_LOGGER_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LOGGER_PROJECT_ROOT="$(cd "${_LOGGER_LIB_DIR}/.." && pwd)"
: "${LOG_DIR:="${_LOGGER_PROJECT_ROOT}/logs"}"
: "${LOG_FILE:=}"
: "${GLOBAL_LOG_FILE:=}"
: "${LOG_COLORS:=true}"
: "${LOGGING_ENABLED:=true}"

# Private state. Resolved at source time so they exist under set -u.
_LOGGER_START_TIME=""
# BASH_SOURCE[-1] requires bash 4.3+; this form works from bash 3.2.
_LOGGER_SCRIPT_NAME="${BASH_SOURCE[${#BASH_SOURCE[@]}-1]##*/}"
_LOGGER_HOST="${HOSTNAME:-}"
[ -n "${_LOGGER_HOST}" ] || _LOGGER_HOST="$(hostname 2>/dev/null || echo unknown)"

_LOGGER_C_RESET=$'\033[0m'
_LOGGER_C_INFO=$'\033[38;5;117m'
_LOGGER_C_SUCCESS=$'\033[38;5;121m'
_LOGGER_C_WARN=$'\033[38;5;216m'
_LOGGER_C_ERROR=$'\033[38;5;204m'
_LOGGER_C_DEBUG=$'\033[38;5;246m'
_LOGGER_C_SECTION=$'\033[38;5;183m'

# Color only on an interactive stdout, and only when enabled. INFO has none.
_logger_use_color() {
  [ "${LOG_COLORS:-true}" = "true" ] || return 1
  [ -t 1 ] || return 1
  return 0
}

_logger_color_for() {
  case "$1" in
    INFO)    printf '%s' "${_LOGGER_C_INFO}" ;;
    SUCCESS) printf '%s' "${_LOGGER_C_SUCCESS}" ;;
    WARN)    printf '%s' "${_LOGGER_C_WARN}" ;;
    ERROR)   printf '%s' "${_LOGGER_C_ERROR}" ;;
    DEBUG)   printf '%s' "${_LOGGER_C_DEBUG}" ;;
    SECTION) printf '%s' "${_LOGGER_C_SECTION}" ;;
    *)       printf '' ;;
  esac
}

# Single emission point: terminal + script log + global log. Always returns 0
# so callers stay safe under set -e.
_log_emit() {
  [ "${LOGGING_ENABLED:-true}" = "true" ] || return 0

  local level="$1"; shift
  local message="$*"
  local ts
  ts="$(date +'%Y-%m-%d %H:%M:%S')"
  local ts_term="${ts:11:8}"   # extracts HH:MM:SS from the full timestamp
  local ts_file="${ts}"

  if _logger_use_color; then
    local color reset
    color="$(_logger_color_for "${level}")"
    [ -n "${color}" ] && reset="${_LOGGER_C_RESET}" || reset=""
    printf '%s[%s] %-9s %s%s\n' "${color}" "${ts_term}" "[${level}]" "${message}" "${reset}"
  else
    printf '[%s] %-9s %s\n' "${ts_term}" "[${level}]" "${message}"
  fi

  if [ -n "${LOG_FILE:-}" ]; then
    printf '[%s] [%s] %s\n' "${ts_file}" "${level}" "${message}" >> "${LOG_FILE}"
  fi

  if [ -n "${GLOBAL_LOG_FILE:-}" ]; then
    printf '[%s] [HOST=%s] [SCRIPT=%s] [%s] %s\n' \
      "${ts_file}" "${_LOGGER_HOST}" "${_LOGGER_SCRIPT_NAME}" "${level}" "${message}" \
      >> "${GLOBAL_LOG_FILE}"
  fi

  return 0
}

log_debug() {
  [ "${DEBUG:-false}" = "true" ] || return 0
  _log_emit "DEBUG" "$*"
}

log_info()    { _log_emit "INFO"    "$*"; }
log_warn()    { _log_emit "WARN"    "$*"; }
log_error()   { _log_emit "ERROR"   "$*"; }
log_success() { _log_emit "SUCCESS" "$*"; }
log_section() { _log_emit "SECTION" "=== $* ==="; }

die() {
  log_error "$*"
  exit 1
}

# Route piped output (one line per log entry) through the logger.
log_stream() {
  local line level message
  while IFS= read -r line; do
    # Detect lines already formatted by logger.sh:
    # format: [HH:MM:SS] [LEVEL]   message
    # or:     [YYYY-MM-DD HH:MM:SS] [LEVEL] message
    if printf '%s' "${line}" | grep -qE '^\[([0-9]{2}:[0-9]{2}:[0-9]{2}|[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2})\] \[(SECTION|SUCCESS|WARN|ERROR|DEBUG|INFO)\]'; then
      level="$(printf '%s' "${line}" | grep -oE 'SECTION|SUCCESS|WARN|ERROR|DEBUG|INFO' | head -1)"
      message="$(printf '%s' "${line}" | sed 's/^[^]]*\] \[[^]]*\] *//')"
      _log_emit "${level}" "${message}"
    else
      # Raw line (stderr, external command output) — emit as INFO
      _log_emit "INFO" "${line}"
    fi
  done
  return 0
}

# Logs the failing command without masking the original exit code.
_logger_trap() {
  local exit_code=$1
  local command=$2
  local line=$3
  log_error "Command failed (exit ${exit_code}) at line ${line}: ${command}"
}

init_logger() {
  [ "${LOGGING_ENABLED:-true}" = "true" ] || return 0

  mkdir -p "${LOG_DIR}"

  local ts
  ts="$(date +%Y%m%d_%H%M%S)"
  LOG_FILE="${LOG_DIR}/${_LOGGER_SCRIPT_NAME}_${ts}.log"
  : > "${LOG_FILE}"

  if [ -n "${GLOBAL_LOG_FILE:-}" ]; then
    mkdir -p "$(dirname "${GLOBAL_LOG_FILE}")"
    [ -f "${GLOBAL_LOG_FILE}" ] || : > "${GLOBAL_LOG_FILE}"
  fi

  export LOG_FILE
  export GLOBAL_LOG_FILE

  # Capture stderr to the log file(s) while keeping it visible on the terminal.
  # Strip ANSI codes before writing to files so logs stay plain text.
  if [ -n "${GLOBAL_LOG_FILE:-}" ]; then
    exec 2> >(
      while IFS= read -r line; do
        printf '%s\n' "${line}" >&2
        printf '%s\n' "${line}" \
          | sed 's/\x1b\[[0-9;]*m//g' \
          | tee -a "${LOG_FILE}" "${GLOBAL_LOG_FILE}" >/dev/null
      done
    )
  else
    exec 2> >(
      while IFS= read -r line; do
        printf '%s\n' "${line}" >&2
        printf '%s\n' "${line}" \
          | sed 's/\x1b\[[0-9;]*m//g' >> "${LOG_FILE}"
      done
    )
  fi

  _LOGGER_START_TIME="$(date +%s)"
  trap '_logger_trap $? "$BASH_COMMAND" "$LINENO"' ERR
}

finalize_logger() {
  [ "${LOGGING_ENABLED:-true}" = "true" ] || return 0

  local end start duration
  end="$(date +%s)"
  start="${_LOGGER_START_TIME:-${end}}"
  duration=$(( end - start ))
  log_info "Total duration: $(( duration / 60 ))m $(( duration % 60 ))s"

  # Flush and restore stderr
  exec 2>&1

  trap - ERR
}

# -----------------------------------------------------------------------------
# Usage
# -----------------------------------------------------------------------------
# source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/logger.sh"
# init_logger
# log_section "Starting setup"
# log_info    "Installing packages"
# log_success "Done"
# log_warn    "Optional step skipped"
# log_error   "Something failed"
# DEBUG=true log_debug "value=${some_var}"
# die "Fatal: cannot continue"                 # log_error + exit 1
# ssh user@host "bash install.sh" 2>&1 | log_stream
# finalize_logger
# -----------------------------------------------------------------------------
