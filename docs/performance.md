# Performance baseline

Measured 2026-09-30 on MacBook Air (Apple M1, 8 CPU cores, 8 GB RAM), macOS 26.5.2 (25F84), macOS SDK 26.2. The standalone harness uses Swift 6 complete strict concurrency checking, `-O`, arm64, and macOS 26.0 deployment. Run `bash scripts/benchmark.sh`. It selects the Xcode SDK, runs three fresh processes with a 180-second bound each, and writes raw allowlisted samples and a summary under `build/measurements/`. No selected or translated text is recorded.

English→Italian was installed. English→French and English→German were supported but missing models. No models were downloaded. Input lengths were 34 and 236 UTF-16 units. Times include current availability, preparation, and translation; they exclude launch, Accessibility capture, detection, UI, and replacement. Missing-model rows measure availability only. Each process performs ten trials per group; p95 uses nearest rank over thirty samples.

| Pair | Session ownership | Workload | n | Median ms | p95 ms | Outcome |
| --- | --- | --- | ---: | ---: | ---: | --- |
| en-it | fresh | short | 30 | 38.35 | 98.18 | success |
| en-it | fresh | paragraph | 30 | 124.51 | 135.03 | success |
| en-it | retained | short | 30 | 36.14 | 39.19 | success |
| en-it | retained | paragraph | 30 | 124.69 | 133.91 | success |
| en-fr | availability only | pair switch | 30 | 2.64 | 2.83 | missing models |
| en-de | availability only | pair switch | 30 | 2.86 | 3.10 | missing models |

First translation after each harness process launch took 506.84, 98.18, and 97.12 ms (n=3; insufficient for meaningful p95). These are process-cold measurements. System models may already have been resident; none is claimed to be model-cold. Initial availability queries are separately retained in raw reports.

Fresh-session groups precede retained-session groups in each process. Ordering and system warmup confound a causal comparison. Small median differences do not establish a reuse speedup; no app cache or idle preparation is justified by these data. The retained session stays in one nonisolated async function and is never shared between actors. Both strategies still check current availability and prepare each request. An unusable session is discarded.

## Acceptance targets and gaps

Visible acknowledgement within 100 ms is a target, **not verified**. The complete shortcut→capture→detection→availability→preparation→translation→presentation/replacement path requires live permission-granted testing. The app provides allowlisted stage timings for those measurements; isolated translation timings cannot establish end-to-end latency.

Provisional targets on this reference machine with installed, warm English→Italian models are 250 ms for short selections and 750 ms for paragraphs from shortcut to visible result. These leave room above the isolated baseline for cross-process capture and UI delivery. Neither end-to-end target is verified. No model-cold target can be set from these samples.

Pending: installed-pair switching (only one tested pair installed), actual model download/setup, uncertain source detection, translation failure, cancellation and superseded-request latency, focus validation and replacement latency, memory/startup/background costs, and a balanced randomized fresh-versus-retained experiment. Behavioral cancellation tests do not supply latency measurements. Missing-model query timing is not a measurement of the visible model-setup flow.

An exploratory run before explicitly selecting the Xcode SDK reported an installed pair followed by missing availability. It is excluded from this baseline. The finalized harness pins its SDK and retains current outcomes without treating past success as permanent readiness. Reproduction also depends on current system model state, which changes independently of the app.

## Retained evidence and UI smoke test

The measured runs are checked in at [run 1](measurements/translation-run-1.json), [run 2](measurements/translation-run-2.json), [run 3](measurements/translation-run-3.json), and [summary](measurements/summary.json). They contain only allowlisted fields and fixture text lengths.

One Debug packaged-app menu invocation without app Accessibility permission reached failure at 61.50 ms and presented its persistent error window at 265.18 ms (n=1; no percentile inference). This validates a visible failure path, not translation latency or the hardware shortcut target. Reopening the same result originally logged presentation a second time; the final implementation suppresses repeated presentation milestones for that request. `acknowledgement_submitted` records an explicit status-button display submission, not physical screen visibility. Real-key/display latency remains pending.
