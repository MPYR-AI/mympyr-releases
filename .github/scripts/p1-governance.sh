#!/usr/bin/env bash
set -euo pipefail

base_sha="${MPYR_BASE_SHA:-}"
head_sha="${MPYR_HEAD_SHA:-${GITHUB_SHA:-HEAD}}"
zero_sha='0000000000000000000000000000000000000000'

if [[ -z "$base_sha" || "$base_sha" == "$zero_sha" ]]; then
  echo "No comparable commit range; repository checks still apply."
  exit 0
fi

git cat-file -e "$base_sha^{commit}"
git cat-file -e "$head_sha^{commit}"
range="$base_sha..$head_sha"
link_pattern='(Closes|Fixes|Resolves|Part of|Ref|Related to)[[:space:]]+MPYR-[0-9]+'
commit_count=0
merge_count=0
missing=''
while IFS= read -r commit; do
  commit_count=$((commit_count + 1))
  if git rev-parse --verify "$commit^2" >/dev/null 2>&1; then
    merge_count=$((merge_count + 1))
    continue
  fi
  if ! git show -s --format=%B "$commit" | grep -Eiq "$link_pattern"; then
    missing="$missing ${commit:0:12}"
  fi
done < <(git rev-list --reverse "$range")

if [[ $commit_count -eq 0 ]]; then
  echo "No commits in governance range."
  exit 0
fi

if [[ -n "$missing" ]]; then
  printf 'Missing Linear magic-word linkage:%s\n' "$missing" >&2
  exit 1
fi

diff_file="$(mktemp)"
trap 'rm -f "$diff_file"' EXIT
git diff --no-ext-diff --unified=0 "$range" > "$diff_file"

secret_pattern='(-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{50,}|glpat-[A-Za-z0-9_-]{20,}|sk-ant-[A-Za-z0-9_-]{40,}|sk-(proj|live|svcacct)-[A-Za-z0-9_-]{40,}|sk_(live|test)_[A-Za-z0-9]{20,}|ops_[A-Za-z0-9_=-]{40,}|GOCSPX-[A-Za-z0-9_-]{20,}|AIza[0-9A-Za-z_-]{35}|xox[baprs]-[A-Za-z0-9-]{20,}|(AKIA|ASIA)[A-Z0-9]{16})'
if sed -n '/^+/p' "$diff_file" | LC_ALL=C grep -Eq "$secret_pattern"; then
  echo 'Credential-like material detected in added lines; value suppressed.' >&2
  exit 1
fi

sensitive_paths=''
while IFS= read -r -d '' path; do
  case "$path" in
    *.env.example|*.env.sample|*.env.template|*.pem.example|*.key.example)
      ;;
    .env|.env.*|*/.env|*/.env.*|*.pem|*.key|*.p12|*.pfx|id_rsa|*/id_rsa|id_ed25519|*/id_ed25519|secrets.json|*/secrets.json|secrets.yaml|*/secrets.yaml|secrets.yml|*/secrets.yml|secrets.toml|*/secrets.toml|credentials.json|*/credentials.json|credentials.yaml|*/credentials.yaml|credentials.yml|*/credentials.yml|credentials.toml|*/credentials.toml)
      sensitive_paths="$sensitive_paths $path"
      ;;
  esac
done < <(git diff --name-only -z --diff-filter=ACMR "$range")

if [[ -n "$sensitive_paths" ]]; then
  printf 'Sensitive-path additions or modifications rejected:%s\n' "$sensitive_paths" >&2
  exit 1
fi

echo "Governance PASS: $commit_count commit(s), $merge_count merge commit(s) exempted from duplicate Linear linkage, diff secret guard."
