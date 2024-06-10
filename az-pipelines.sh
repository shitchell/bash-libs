function _az_logging() {
  command="${1}" && shift
  printf '%s\n' "${@}" \
    | awk -v cmd="${command}" '{print "##[" cmd "]" $0}' >&2
}
function az-error() { _az_logging error "${@}"; }
function az-errorlog() {
  echo "##vso[task.logissue type=error]${*}" >&2
}
function az-warning() { _az_logging warning "${@}"; }
function az-info() { _az_logging info "${@}"; }
function az-section() { _az_logging section "${@}"; }
function az-group() { _az_logging group "${*}"; }
function az-endgroup() { _az_logging endgroup "${*}"; }
