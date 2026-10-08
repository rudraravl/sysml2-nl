#!/usr/bin/env bash
# Fetch the pinned OpenZeppelin releases used by sol_imports.py (import-resolved Solidity scoring).
# npm verifies each tarball against the registry; we additionally check it against the integrity below.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p tgz
while read -r spec integrity; do
  name=${spec#@openzeppelin/}; name=openzeppelin-${name/@/-}
  [ -f "tgz/$name.tgz" ] || (cd tgz && npm pack "$spec" >/dev/null)
  got="sha512-$(openssl dgst -sha512 -binary "tgz/$name.tgz" | openssl base64 -A)"
  [ "$got" = "$integrity" ] || { echo "integrity mismatch for $spec" >&2; exit 1; }
  rm -rf "$name" && mkdir -p "$name" && tar -xzf "tgz/$name.tgz" -C "$name" --strip-components=1
  echo "ok $spec -> vendor/$name"
done <<'EOF'
@openzeppelin/contracts@4.9.6 sha512-xSmezSupL+y9VkHZJGDoCBpmnB2ogM13ccaYDWqJTfS3dbuHkgjuwDFUmaFauBCboQMGB/S5UqUl2y54X99BmA==
@openzeppelin/contracts-upgradeable@4.9.6 sha512-m4iHazOsOCv1DgM7eD7GupTJ+NFVujRZt1wzddDPSVGpWdKq1SKkla5htKG7+IS4d2XOCtzkUNwRZ7Vq5aEUMA==
@openzeppelin/contracts@5.6.1 sha512-Ly6SlsVJ3mj+b18W3R8gNufB7dTICT105fJhodGAGgyC2oqnBAhqSiNDJ8V8DLY05cCz81GLI0CU5vNYA1EC/w==
@openzeppelin/contracts-upgradeable@5.6.1 sha512-n4a/vfRs114lXyUdYg7pyY8LvFKWvCDF5lEcRRAVxap8g6ZEdLqm+9tmt2zTtRHcNMxTYp9y5t6KBof4tHp7Og==
EOF
