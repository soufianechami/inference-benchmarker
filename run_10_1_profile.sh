#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${SCRIPT_DIR}/ovh-benchmarking/results"
RESULTS_ABS="$(cd "$RESULTS_DIR" && pwd)"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
RUN_ID="gpt-oss-120b_10to1_${TIMESTAMP}"

docker run --rm -it \
  -v "${RESULTS_ABS}:/opt/inference-benchmarker/results" \
  "${DOCKER_IMAGE:-inference-benchmarker:fabienric}" \
  inference-benchmarker \
  --url "${SAMBANOVA_URL:-https://api-sambastack-dev-4.sambanova.net}" \
  --api-key "${SAMBANOVA_API_KEY}" \
  --tokenizer-name openai/gpt-oss-120b \
  --model-name gpt-oss-120b \
  --dataset-file classification.json \
  --benchmark-kind rate \
  -r 0.2 -r 0.5 -r 1.0 -r 1.5 -r 2.0 -r 2.5 -r 3.0 -r 3.5 -r 4.0 -r 4.5 -r 5.0 -r 5.5 -r 6.0 -r 6.5 -r 7.0 -r 7.5 -r 8.0 -r 8.5 -r 9.0 \
  --warmup 60s \
  --max-vus 2000 \
  --run-id "${RUN_ID}" \
  --prompt-options "num_tokens=10000,min_tokens=10000,max_tokens=30000,dist=normal:variance=500" \
  --decode-options "num_tokens=1000,min_tokens=900,max_tokens=1100,dist=normal:variance=100" \
  --extra-meta "profile=10_1_profile,hardware=sn40l,engine=sambanova,tp=1,device=sn40l"
