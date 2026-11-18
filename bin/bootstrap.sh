#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 --name=project_name [--for-docker] [--verbose]"
}

cd "$(dirname "$0")/.."
project_name=""
use_docker=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --name=*) project_name="${1#*=}" ;;
    -n|--name) project_name="${2:?Missing project name}"; shift ;;
    -n?*) project_name="${1#-n}" ;;
    -d|--for-docker) use_docker=true ;;
    -v|--verbose) set -x ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 1 ;;
  esac
  shift
done

if [[ ! "$project_name" =~ ^[a-z][a-z0-9_-]*$ ]]; then
  echo "Use a project name starting with a lowercase letter, followed by letters, digits, underscores or hyphens." >&2
  exit 1
fi

if "$use_docker"; then
  docker compose version >/dev/null
fi

while IFS= read -r -d '' file; do
  PROJECT_NAME="$project_name" perl -pi -e 's/rails_api_template/$ENV{PROJECT_NAME}/g' "$file"
done < <(git grep -Ilz --fixed-strings rails_api_template -- '*.yml' '*.yaml' '*.erb' '*.rb' '*.json' '*.tf' yarn.lock .env.sample)

# Yarn sorts workspace names in its lockfile. Re-serialize it after renaming
# the root package, then use immutable installs for setup and image builds.
if "$use_docker"; then
  docker run --rm --user "$(id -u):$(id -g)" -v "$PWD:/src" -w /src \
    -e COREPACK_HOME=/tmp/corepack -e YARN_CACHE_FOLDER=/tmp/yarn-cache \
    -e YARN_ENABLE_IMMUTABLE_INSTALLS=false "node:$(cat .nvmrc)" \
    corepack yarn install --mode=update-lockfile
else
  YARN_ENABLE_IMMUTABLE_INSTALLS=false yarn install --mode=update-lockfile
fi

[[ -f .env ]] || cp .env.sample .env
if "$use_docker"; then
  if grep -q '^DOCKER_ENABLED=' .env; then
    perl -pi -e 's/^DOCKER_ENABLED=.*/DOCKER_ENABLED=true/' .env
  else
    printf '\nDOCKER_ENABLED=true\n' >> .env
  fi
  docker compose build web
  docker compose run --rm web ./bin/setup --skip-server
  exec docker compose up --detach
fi

exec ./bin/setup --skip-server
