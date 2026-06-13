#!/usr/bin/env bash
# Render the Jinja shell-script templates and run shellcheck on the result.
# (Templates contain Jinja and cannot be shellchecked directly.)
set -euo pipefail
shopt -s nullglob

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
out="$(mktemp -d)"
trap 'rm -rf "${out}"' EXIT

ansible-playbook -i localhost, -c local "${here}/render.yml" -e "render_out=${out}" >/dev/null

scripts=("${out}"/*.sh)
if [ ${#scripts[@]} -eq 0 ]; then
  echo "No shell-script templates found (templates/**/*.sh.j2) — nothing to shellcheck."
  exit 0
fi

echo "Rendered scripts:"
printf '  %s\n' "${scripts[@]##*/}"

shellcheck --severity=warning "${scripts[@]}"
echo "shellcheck passed (severity: warning)"
