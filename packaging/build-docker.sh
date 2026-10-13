#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="${IMAGE_NAME:-arista-serial-builder:local}"


docker build \
	--tag "${IMAGE_NAME}" \
	--file "${ROOT_DIR}/packaging/Dockerfile" \
	"${ROOT_DIR}"

docker run --rm \
	--volume "${ROOT_DIR}:/workspace" \
	--workdir /workspace \
	"${IMAGE_NAME}"
