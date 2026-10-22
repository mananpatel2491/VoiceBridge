# Contract: Dashboards (FR-013)

Created by hand in each PostHog project (debug and release), so the owner never writes a query.

| Dashboard | Insight | Definition |
|---|---|---|
| Health | Crashes | `$exception`, count per day, breakdown `$exception_types`; link to Error tracking |
| Health | Failures by stage | `stage_failed`, count per day, breakdown `stage`, then `category` |
| Health | Failure detail | table of `stage_failed`: time, `stage`, `category`, `http_status`, `error_reason`, `release_tag`, `$device_model` |
| Stage latency | Median per stage | `stage_completed`, property `duration_ms`, median, breakdown `stage`, filter `release_tag` |
| Stage latency | p95 per stage | same, 95th percentile |
| Stage latency | Versions side by side | `stage_completed` `duration_ms` median, breakdown `release_tag`, filter `stage` |
| Recognition | Confidence | `stage_completed` where `stage = transcribe`: `stt_conf_mean` average, `stt_low_conf_words` sum, per day |
| Recognition | Shaky runs | table where `stt_low_conf_words ≥ 5`: time, `run_id`, `audio_ms`, `stt_conf_min` |

`run_id` in "Shaky runs" matches `run.json` in a debug evidence bundle.
