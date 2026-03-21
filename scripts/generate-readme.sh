#!/usr/bin/env bash
# generate-readme.sh
# Queries GitHub topic API for repos tagged roebi-agent-skills
# and generates README.md listing them.
#
# Usage: generate-readme.sh [github_user]
#   github_user  optional filter — only list repos owned by this user
#                default: roebi
#
# Requires: curl, jq
# Exit 0 = success, 1 = user error, 2 = system error

set -euo pipefail

GITHUB_USER="${1:-roebi}"
TOPIC="roebi-agent-skills"
API_URL="https://api.github.com/search/repositories?q=topic:${TOPIC}&per_page=100"
OUTPUT="README.md"

# ── helpers ──────────────────────────────────────────────────────────────────

log()  { echo "[generate-readme] $*" >&2; }
fail() { echo "[generate-readme] ERROR: $*" >&2; exit 2; }

# ── validate dependencies ─────────────────────────────────────────────────────

command -v curl >/dev/null || fail "curl not found"
command -v jq   >/dev/null || fail "jq not found"

# ── query GitHub API ──────────────────────────────────────────────────────────

log "Querying topic: ${TOPIC} (user filter: ${GITHUB_USER})"

AUTH_HEADER=""
if [[ -n "${GH_TOKEN:-}" ]]; then
  AUTH_HEADER="Authorization: Bearer ${GH_TOKEN}"
fi

response=$(curl -sf \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  ${AUTH_HEADER:+-H "$AUTH_HEADER"} \
  "$API_URL") || fail "GitHub API request failed"

# ── filter by user and extract fields ─────────────────────────────────────────

repos=$(echo "$response" | jq -r \
  --arg user "$GITHUB_USER" \
  '.items[]
   | select(.owner.login == $user)
   | [.full_name, .html_url, .description // "—", .stargazers_count, .updated_at]
   | @tsv')

repo_count=$(echo "$repos" | grep -c . || true)
log "Found ${repo_count} repos for user ${GITHUB_USER}"

# ── generate README.md ────────────────────────────────────────────────────────

generated_at=$(date -u '+%Y-%m-%d %H:%M UTC')

cat > "$OUTPUT" << HEADER
# roebi-agent-skills

Hub for all repositories tagged with the
[roebi-agent-skills](https://github.com/topics/roebi-agent-skills) topic.

> *"The LLM reflects — the user evaluates."* — roebi
>
> *"I ask for skills, I get skills."* — roebi

This README is generated automatically by a GitHub Action.
No manual editing. Algorithm first, no Skill needed.

**User filter:** \`${GITHUB_USER}\`
**Topic:** [\`${TOPIC}\`](https://github.com/topics/${TOPIC})
**Last updated:** ${generated_at}

---

## Repositories (${repo_count})

| Repository | Description | ★ | Updated |
|---|---|---|---|
HEADER

# append one table row per repo
while IFS=$'\t' read -r full_name html_url description stars updated_at; do
  updated_short="${updated_at:0:10}"
  echo "| [${full_name}](${html_url}) | ${description} | ${stars} | ${updated_short} |" >> "$OUTPUT"
done <<< "$repos"

cat >> "$OUTPUT" << FOOTER

---

## How this works

The GitHub Action \`.github/workflows/generate-hub-readme.yml\` runs daily
and on manual trigger. It calls \`scripts/generate-readme.sh\` with a
\`github_user\` parameter, queries the GitHub Search API for repos tagged
\`${TOPIC}\`, and writes this file.

**To tag your repo:** add \`${TOPIC}\` as a GitHub topic.
It will appear here on the next run.

### Run locally

\`\`\`bash
# default user: roebi
bash scripts/generate-readme.sh

# custom user
bash scripts/generate-readme.sh <github-username>
\`\`\`

---

## License

See [LICENSE](LICENSE).
FOOTER

log "Written: ${OUTPUT}"
