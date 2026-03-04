#!/usr/bin/env bash
# =============================================================================
# Scenario 1 — General Performance (Base API)
# Goal: Roofline throughput per traffic segment
# Profiles: chat (512/512), doc-analysis (1k/1k), input-heavy (7k/1k), output-heavy (1k/7k)
# Concurrency: sweep 1 → 8 VUs
# Mode: sweep (auto-discovers max rate, then sweeps 0→120%)
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
NUM_RATES="10"
MAX_VUS="8"                            # max batch size for GPT-OSS 120B bundle

PROFILES=("chat-512-512" "doc-1k-1k" "input-heavy-7k-1k" "output-heavy-1k-7k")
TOTAL_PROFILES=${#PROFILES[@]}
PROFILE_NUM=0

# Print full config before starting
log ""
log "╔══════════════════════════════════════════════════════════════╗"
log "║         Scenario 1 — General Performance (Base API)         ║"
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
log "    Mode      : sweep (auto-discovers max rate, then sweeps 0→120%)"
log "    Max VUs   : ${MAX_VUS}"
log "    Rates     : ${NUM_RATES} steps"
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
  log "  Log     : ${RESULTS_DIR}/s1-${profile_name}-${HARDWARE}.log"
  log "  Started : $(date '+%H:%M:%S')"
  log "────────────────────────────────────────────────────────────────"

  docker run --rm \
    -v "${RESULTS_ABS}:/opt/inference-benchmarker/results" \
    "${DOCKER_IMAGE}" \
    inference-benchmarker \
    --url "$URL" \
    --api-key "$API_KEY" \
    --tokenizer-name "$TOKENIZER" \
    --model-name "$MODEL" \
    --benchmark-kind sweep \
    --max-vus "$MAX_VUS" \
    --duration "$DURATION" \
    --warmup "$WARMUP" \
    --num-rates "$NUM_RATES" \
    --prompt-options "$prompt_opts" \
    --decode-options "$decode_opts" \
    --run-id "s1-${profile_name}-${HARDWARE}" \
    --extra-meta "scenario=general,profile=${profile_name},hardware=${HARDWARE}" \
    --no-console \
    2>&1 | tee -a "${RESULTS_ABS}/s1-${profile_name}-${HARDWARE}.log"

  local end_ts elapsed
  end_ts=$(date +%s)
  elapsed=$((end_ts - start_ts))
  log ""
  log "  [${PROFILE_NUM}/${TOTAL_PROFILES}] Done: ${profile_name} (${elapsed}s)"
  log ""
}

# --- Profile: chat (512 in / 512 out) ---
run_profile "chat-512-512" \
  "num_tokens=512,min_tokens=460,max_tokens=560,dist=normal:variance=50" \
  "num_tokens=512,min_tokens=460,max_tokens=560,dist=normal:variance=50"

# --- Profile: doc-analysis (1k in / 1k out) ---
run_profile "doc-1k-1k" \
  "num_tokens=1000,min_tokens=900,max_tokens=1100,dist=normal:variance=100" \
  "num_tokens=1000,min_tokens=900,max_tokens=1100,dist=normal:variance=100"

# --- Profile: input-heavy (7k in / 1k out) ---
run_profile "input-heavy-7k-1k" \
  "num_tokens=7000,min_tokens=4000,max_tokens=7500,dist=normal:variance=500" \
  "num_tokens=1000,min_tokens=900,max_tokens=1100,dist=normal:variance=100"

# --- Profile: output-heavy (1k in / 7k out) ---
run_profile "output-heavy-1k-7k" \
  "num_tokens=1000,min_tokens=900,max_tokens=1100,dist=normal:variance=100" \
  "num_tokens=7000,min_tokens=6500,max_tokens=7500,dist=normal:variance=500"

log "════════════════════════════════════════════════════════════════"
log "  Scenario 1 complete — all ${TOTAL_PROFILES} profiles finished"
log "  Results in: ${RESULTS_DIR}"
log "════════════════════════════════════════════════════════════════"
