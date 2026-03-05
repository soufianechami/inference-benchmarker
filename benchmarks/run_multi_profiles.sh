#!/usr/bin/env bash
# Runs 4 benchmark profiles against GPT-OSS 120B to cover different workloads:
#
#   chat-512-512       Typical chat / Q&A (512 in, 512 out)
#   doc-1k-1k          Document analysis  (1k in, 1k out)
#   input-heavy-7k-1k  Long doc, short answer (7k in, 1k out)
#   output-heavy-1k-7k Long generation (1k in, 7k out)
#
# Usage:
#   export BASE_URL=https://your-endpoint
#   export API_KEY=your-key
#   bash benchmarks/run_multi_profiles.sh
#
# Requires: Docker with a built inference-benchmarker image.
#   docker build -t inference-benchmarker:local .
set -euo pipefail

log() { echo "$@" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${SCRIPT_DIR}/../results"
mkdir -p "$RESULTS_DIR"
RESULTS_ABS="$(cd "$RESULTS_DIR" && pwd)"

URL="${BASE_URL:?Set BASE_URL}"
API_KEY="${API_KEY:?Set API_KEY}"
DOCKER_IMAGE="${DOCKER_IMAGE:-inference-benchmarker:local}"
MODEL="gpt-oss-120b"
TOKENIZER="openai/gpt-oss-120b"
# metadata
ENGINE="default"    # e.g. vllm, sglang..
TP=1                # tensor parallel size

WARMUP="30s"
MAX_VUS="2000"
TOTAL=4
NUM=0

log ""
log "  GPT-OSS 120B — Multi-Profile Rate Benchmark (${TOTAL} profiles)"
log ""

run_profile() {
  local profile="$1"
  local prompt_opts="$2"
  local decode_opts="$3"
  NUM=$((NUM + 1))

  local start_ts
  start_ts=$(date +%s)

  log "────────────────────────────────────────────────────────────────"
  log "  [${NUM}/${TOTAL}] ${profile}"
  log "  Started: $(date '+%H:%M:%S')"
  log "────────────────────────────────────────────────────────────────"

  docker run --rm \
    -v "${RESULTS_ABS}:/opt/inference-benchmarker/results" \
    "${DOCKER_IMAGE}" \
    inference-benchmarker \
    --url "$URL" \
    --api-key "$API_KEY" \
    --tokenizer-name "$TOKENIZER" \
    --model-name "$MODEL" \
    --benchmark-kind rate \
    -r 0.2 -r 0.5 -r 1.0 -r 2.0 -r 3.0 -r 5.0 -r 10.0 \
    --warmup "$WARMUP" \
    --max-vus "$MAX_VUS" \
    --run-id "$profile" \
    --prompt-options "$prompt_opts" \
    --decode-options "$decode_opts" \
    --extra-meta "profile=${profile},engine=${ENGINE},tp=${TP}" \
    --no-console \
    2>&1 | tee -a "${RESULTS_ABS}/${profile}.log"

  local end_ts elapsed
  end_ts=$(date +%s)
  elapsed=$((end_ts - start_ts))
  log "  [${NUM}/${TOTAL}] Done: ${profile} (${elapsed}s)"
  log ""
}

# 1. Chat: 512 in / 512 out
run_profile "chat-512-512" \
  "num_tokens=512,min_tokens=460,max_tokens=560,dist=normal:variance=50" \
  "num_tokens=512,min_tokens=460,max_tokens=560,dist=normal:variance=50"

# 2. Doc analysis: 1k in / 1k out
run_profile "doc-1k-1k" \
  "num_tokens=1000,min_tokens=900,max_tokens=1100,dist=normal:variance=100" \
  "num_tokens=1000,min_tokens=900,max_tokens=1100,dist=normal:variance=100"

# 3. Input heavy: 7k in / 1k out
run_profile "input-heavy-7k-1k" \
  "num_tokens=7000,min_tokens=4000,max_tokens=7500,dist=normal:variance=500" \
  "num_tokens=1000,min_tokens=900,max_tokens=1100,dist=normal:variance=100"

# 4. Output heavy: 1k in / 7k out
run_profile "output-heavy-1k-7k" \
  "num_tokens=1000,min_tokens=900,max_tokens=1100,dist=normal:variance=100" \
  "num_tokens=7000,min_tokens=6500,max_tokens=7500,dist=normal:variance=500"

log "════════════════════════════════════════════════════════════════"
log "  All ${TOTAL} profiles complete!"
log "  Results: ${RESULTS_ABS}"
log ""
log "  View results:"
log "    cd extra/dashboard"
log "    python app.py --from-results-dir ${RESULTS_DIR} --port 7860"
log "════════════════════════════════════════════════════════════════"
