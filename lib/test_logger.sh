#!/usr/bin/env bash
export GLOBAL_LOG_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../logs/session_test.log"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/logger.sh"

init_logger

log_section "Test logger"
log_info    "Info message"
log_success "Success message"
log_warn    "Warning message"
log_error   "Error message"
log_debug   "Debug hidden (DEBUG=false)"
# Test trap ERR — commande volontairement incorrecte
ls /chemin/qui/nexiste/pas

DEBUG=true
log_debug   "Debug visible (DEBUG=true)"

# Test log_stream
echo "line from pipe" | log_stream

# Test die (commente si tu veux pas que ça exit)
# die "Fatal error test"

finalize_logger

echo ""
echo "Log file: ${LOG_FILE}"
cat "${LOG_FILE}"
