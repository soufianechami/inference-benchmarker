#!/usr/bin/env bash
# Reproduces Fabien Ric's original benchmark profile for GPT-OSS 120B.
# Uses log-normal distributions for prompt/decode token counts.
#
# Usage:
#   export SAMBANOVA_URL=https://your-endpoint
#   export SAMBANOVA_API_KEY=your-key
#   bash benchmarks/run_fabien_profile.sh
#
# Requires: Docker with a built inference-benchmarker image.
#   docker build -t inference-benchmarker:local .
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${SCRIPT_DIR}/../results"
mkdir -p "$RESULTS_DIR"
RESULTS_ABS="$(cd "$RESULTS_DIR" && pwd)"

URL="${SAMBANOVA_URL:?Set SAMBANOVA_URL}"
API_KEY="${SAMBANOVA_API_KEY:?Set SAMBANOVA_API_KEY}"
DOCKER_IMAGE="${DOCKER_IMAGE:-inference-benchmarker:local}"

docker run --rm \
  -v "${RESULTS_ABS}:/opt/inference-benchmarker/results" \
  "${DOCKER_IMAGE}" \
  inference-benchmarker \
  --url "$URL" \
  --api-key "$API_KEY" \
  --tokenizer-name openai/gpt-oss-120b \
  --model-name gpt-oss-120b \
  --benchmark-kind rate \
  -r 0.2 -r 0.5 -r 1.0 -r 2.0 -r 3.0 -r 5.0 -r 10.0 \
  --warmup 30s \
  --max-vus 2000 \
  --run-id fabien-custom \
  --prompt-options "num_tokens=4000,min_tokens=500,max_tokens=5000,dist=log_normal:log_mean=7.1935,log_std=1.4366" \
  --decode-options "num_tokens=400,min_tokens=200,max_tokens=1000,dist=log_normal:log_mean=5.9396,log_std=1.1612" \
  --extra-meta "profile=fabien-custom,engine=sambanova,tp=1"
