#!/usr/bin/env bash
# =============================================================================
# Scenario 2 — Low Latency (Fast Inference / Premium API)
# Goal: Per-request latency SLAs — TTFT and tok/s at p99
# Profiles: short (100/100), medium (256/256), standard (512/512)
# Concurrency: 1, 2, 4 (do NOT sweep to 8)
# Mode: rate (explicit QPS steps — fairer for dynamic batching than sweep mode)
# Note: sweep mode derives rates from VU saturation which inflates peak for
#       dynamic batching servers. Rate mode tests specific operating points.
# =============================================================================

set -euo pipefail

# All progress output goes to stderr so it doesn't mix with the benchmarker's stdout
log() { echo "$@" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${SCRIPT_DIR}/../results"
mkdir -p "$RESULTS_DIR"
RESULTS_ABS="$(cd "$RESULTS_DIR" && pwd)"

URL="${SAMBANOVA_URL:?Set SAMBANOVA_URL}"
API_KEY="${SAMBANOVA_API_KEY:?Set SAMBANOVA_API_KEY}"
TOKENIZER="${TOKENIZER:-openai/gpt-oss-120b}"
MODEL="${MODEL:-gpt-oss-120b}"
HARDWARE="${HARDWARE:-sn40l}"          # sn40l | h200 | b200 — tag in results
DOCKER_IMAGE="${DOCKER_IMAGE:-inference-benchmarker:local}"

DURATION="120s"
WARMUP="30s"
MAX_VUS="4"                            # hard cap — premium tier does not scale to 8

# Explicit QPS steps: 1, 2, 4 req/s — maps to concurrency 1/2/4 at target latency
# Adjust these if the server's sustained throughput at low concurrency is known
RATES="1.0 2.0 4.0"

PROFILES=("short-100-100" "medium-256-256" "standard-512-512")
TOTAL_PROFILES=${#PROFILES[@]}
PROFILE_NUM=0

# Print full config before starting
log ""
log "╔══════════════════════════════════════════════════════════════╗"
log "║      Scenario 2 — Low Latency (Fast Inference / Premium)    ║"
log "╚══════════════════════════════════════════════════════════════╝"
log ""
log "  Config:"
log "    URL       : ${URL}"
log "    Model     : ${MODEL}"
log "    Tokenizer : ${TOKENIZER}"
log "    Hardware  : ${HARDWARE}"
log "    Results   : ${RESULTS_ABS}"
log "    Image     : ${DOCKER_IMAGE}"
log ""
log "  Benchmark params:"
log "    Mode      : rate (explicit QPS steps — fairer for dynamic batching)"
log "    Max VUs   : ${MAX_VUS}"
log "    Rates     : ${RATES} req/s"
log "    Duration  : ${DURATION} per step"
log "    Warmup    : ${WARMUP}"
log ""
log "  Profiles to run (${TOTAL_PROFILES} total):"
for p in "${PROFILES[@]}"; do log "    • ${p}"; done
log ""

run_profile() {
  local profile_name="$1"
  local prompt_opts="$2"
  local decode_opts="$3"
  PROFILE_NUM=$((PROFILE_NUM + 1))

  local start_ts
  start_ts=$(date +%s)

  log "────────────────────────────────────────────────────────────────"
  log "  [${PROFILE_NUM}/${TOTAL_PROFILES}] Starting profile: ${profile_name}"
  log "  Prompt  : ${prompt_opts}"
  log "  Decode  : ${decode_opts}"
  log "  Rates   : ${RATES} req/s"
  log "  Log     : ${RESULTS_DIR}/s2-${profile_name}-${HARDWARE}.log"
  log "  Started : $(date '+%H:%M:%S')"
  log "────────────────────────────────────────────────────────────────"

  # Build --rates flags from space-separated list
  local rate_flags=""
  for r in $RATES; do
    rate_flags="$rate_flags --rates $r"
  done

  # shellcheck disable=SC2086
  docker run --rm \
    -v "${RESULTS_ABS}:/opt/inference-benchmarker/results" \
    "${DOCKER_IMAGE}" \
    inference-benchmarker \
    --url "$URL" \
    --api-key "$API_KEY" \
    --tokenizer-name "$TOKENIZER" \
    --model-name "$MODEL" \
    --benchmark-kind rate \
    --max-vus "$MAX_VUS" \
    --duration "$DURATION" \
    --warmup "$WARMUP" \
    $rate_flags \
    --prompt-options "$prompt_opts" \
    --decode-options "$decode_opts" \
    --run-id "s2-${profile_name}-${HARDWARE}" \
    --extra-meta "scenario=low-latency,profile=${profile_name},hardware=${HARDWARE}" \
    --no-console \
    2>&1 | tee -a "${RESULTS_ABS}/s2-${profile_name}-${HARDWARE}.log"

  local end_ts elapsed
  end_ts=$(date +%s)
  elapsed=$((end_ts - start_ts))
  log ""
  log "  [${PROFILE_NUM}/${TOTAL_PROFILES}] Done: ${profile_name} (${elapsed}s)"
  log ""
}

# --- Profile: short (100 in / 100 out) ---
run_profile "short-100-100" \
  "num_tokens=100,min_tokens=90,max_tokens=110,dist=normal:variance=10" \
  "num_tokens=100,min_tokens=90,max_tokens=110,dist=normal:variance=10"

# --- Profile: medium (256 in / 256 out) ---
run_profile "medium-256-256" \
  "num_tokens=256,min_tokens=230,max_tokens=280,dist=normal:variance=25" \
  "num_tokens=256,min_tokens=230,max_tokens=280,dist=normal:variance=25"

# --- Profile: standard (512 in / 512 out) ---
run_profile "standard-512-512" \
  "num_tokens=512,min_tokens=460,max_tokens=560,dist=normal:variance=50" \
  "num_tokens=512,min_tokens=460,max_tokens=560,dist=normal:variance=50"

log "════════════════════════════════════════════════════════════════"
log "  Scenario 2 complete — all ${TOTAL_PROFILES} profiles finished"
log "  Results in: ${RESULTS_DIR}"
log ""
log "  Key metrics to review (see success-criteria.md):"
log "    • Output tok/s p50 per profile  → target ≥ 100 tok/s"
log "    • TTFT p99 per profile"
log "    • ITL p99 per profile"
log "════════════════════════════════════════════════════════════════"
