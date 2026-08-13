#!/usr/bin/env bash
# Fails when app-facing files changed but pubspec.yaml version is unchanged vs base.
set -euo pipefail

BASE_REF="${1:-origin/main}"

if ! git rev-parse --verify "${BASE_REF}" >/dev/null 2>&1; then
  echo "::error::Base ref '${BASE_REF}' not found. Fetch the base branch first."
  exit 1
fi

APP_PATHS='^(lib/|pubspec\.yaml|pubspec\.lock|web/|assets/)'

if ! git diff --name-only "${BASE_REF}...HEAD" | grep -qE "${APP_PATHS}"; then
  echo "No app-facing changes vs ${BASE_REF}; version bump not required."
  exit 0
fi

read_version_from_file() {
  grep -E '^version:' "$1" | head -1 | awk '{print $2}'
}

read_version_from_git() {
  git show "${1}:pubspec.yaml" | grep -E '^version:' | head -1 | awk '{print $2}'
}

base_version="$(read_version_from_git "${BASE_REF}")"
head_version="$(read_version_from_file pubspec.yaml)"

if [[ -z "${base_version}" || -z "${head_version}" ]]; then
  echo "::error::Could not read version from pubspec.yaml (base=${base_version}, head=${head_version})."
  exit 1
fi

if [[ "${base_version}" == "${head_version}" ]]; then
  echo "::error::pubspec.yaml version is still ${head_version}."
  echo "Bump the version before merging (e.g. ${head_version} → next build or patch)."
  echo "Flutter format: version: MAJOR.MINOR.PATCH+BUILD (example: 1.0.0+1 → 1.0.0+2)."
  if [[ -n "${PR_NUMBER:-}" ]]; then
    echo "Tip: you can set BUILD to the PR number: 1.0.0+${PR_NUMBER}"
  fi
  exit 1
fi

echo "Version OK: ${base_version} → ${head_version}"
