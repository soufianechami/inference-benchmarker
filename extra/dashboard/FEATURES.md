# Dashboard Roadmap

## Current State

Gradio app with a single view: results visualization. Loads JSON results from a directory, converts to Parquet, and displays line plots (ITL, TTFT, E2E, throughput, per-request speed, error rate) with model/run_id filters and percentile selector.

## Goal

A single unified app with two tabs:
1. **Results** — improved version of what we have today
2. **Run Experiments** — configure and launch benchmarks from the UI, with live progress

---

## Tab 1: Results (improvements)

### Chart improvements
- Side-by-side comparison mode: pick two run_ids and overlay their charts
- Tooltip on hover showing exact values (metric, QPS, run_id)
- Export charts as PNG / SVG
- Auto-refresh: watch the results directory and reload when new JSON files appear (useful while experiments are running in Tab 2)

### Table improvements
- Sortable columns
- Highlight best/worst values per metric
- CSV / Excel export button

### Filters
- Multi-model comparison (currently single model dropdown)
- Date range filter (based on result file timestamps)
- Profile filter (chat, doc, input-heavy, output-heavy)

---

## Tab 2: Run Experiments

### Configuration form
- **Endpoint**: URL + API key fields
- **Model**: model name + tokenizer name
- **Benchmark mode**: rate or sweep (radio button)
- **Rates**: for rate mode — comma-separated QPS values (e.g. `0.2, 0.5, 1.0, 2.0`)
- **Max VUs**: slider or number input
- **Duration**: per-step duration (e.g. `120s`)
- **Warmup**: warmup duration (e.g. `30s`)
- **Prompt options**: num_tokens, min_tokens, max_tokens, distribution (normal/log_normal + params)
- **Decode options**: same as prompt options
- **Run ID**: text field
- **Extra metadata**: key=value pairs
- **Docker image**: defaults to `inference-benchmarker:local`

### Preset profiles
- Dropdown to load a preset profile that fills in the form:
  - Chat (512/512)
  - Doc analysis (1k/1k)
  - Input heavy (7k/1k)
  - Output heavy (1k/7k)
  - Fabien custom (log-normal)
  - Custom (blank form)

### Run controls
- **Start** button: launches the Docker benchmark in background
- **Stop** button: kills the running container
- **Queue multiple**: select multiple profiles, run them sequentially
- Progress indicator: which profile is running, how many done / total

### Live logs
- Streaming log output panel (the stderr/stdout from the benchmarker)
- Auto-scroll with option to pause scrolling
- Log panel updates in real-time via Gradio streaming

### After completion
- Auto-refresh the Results tab with new data
- Notification / banner when a run finishes
- Link to jump to Results tab filtered to the new run_id

---

## Technical notes

- Backend: Python subprocess to run `docker run ...` commands
- Log streaming: capture subprocess stdout/stderr and push to Gradio via `gr.Textbox` with `every=` or streaming callback
- Results directory: shared between Tab 1 and Tab 2 — Tab 2 writes results, Tab 1 reads them
- Docker image must be pre-built (`docker build -t inference-benchmarker:local .`)
