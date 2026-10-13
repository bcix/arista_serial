#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${DIST_DIR:-${ROOT_DIR}/dist}"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/arista-serial-build.XXXXXX")"
trap 'rm -rf "${BUILD_DIR}"' EXIT

for tool in rpmbuild zip swi-tools; do
	if ! command -v "${tool}" >/dev/null 2>&1; then
		printf 'Missing build dependency: %s\n' "${tool}" >&2
		exit 1
	fi
done

TOP_DIR="${BUILD_DIR}/rpmbuild"
mkdir -p "${TOP_DIR}" "${DIST_DIR}"

rpmbuild \
	--define "_topdir ${TOP_DIR}" \
	--define "_sourcedir ${ROOT_DIR}" \
	-bb "${ROOT_DIR}/packaging/arista-serial.spec"

RPM_FILE="${TOP_DIR}/RPMS/noarch/arista-serial-1.0.0-1.noarch.rpm"
swi-tools create \
	--info "${ROOT_DIR}/packaging/manifest.yaml" \
	--force \
	"${DIST_DIR}/arista-serial-1.0.0.swix" \
	"${RPM_FILE}"

printf 'Built %s\n' "${DIST_DIR}/arista-serial-1.0.0.swix"
