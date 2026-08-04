# RewriteBar 1.2.4 Performance Evaluation

Date: 2026-08-04

## Goal

Reduce perceived rewrite time without weakening output quality, changing the single slider workflow, or increasing runtime complexity.

## Baseline

Three representative level 3 cases passed all 33 quality checks. Warm generation averaged 1.37 seconds.

## Loop 1: Remove avoidable completion latency

Changes kept:

* Removed the intentional 180 millisecond pause before automatic clipboard copy.
* Raised background model warmup from utility priority to user initiated priority.

Result:

* Output quality remained at 100 percent.
* Generation time remained stable at 1.37 seconds.
* Visible completion is 180 milliseconds faster.

## Loop 2: Reduce prompt and prefill cost

Two candidates were tested and rejected:

* A shorter prompt slowed generation to 1.50 seconds and reduced quality to 96.97 percent.
* A 1,024 token prefill step averaged 1.38 seconds and did not improve the 512 token configuration.

The explicit prompt and 512 token prefill step were restored.

## Loop 3: Simplify the resident model lifecycle

Changes kept:

* Removed the unused delayed model release task and its operation tracking.
* Centralized generation parameters so warmup and rewriting use one configuration.
* Kept cache cleanup after each generation while retaining the loaded model.

Result:

* Removed 53 net lines from the runtime path.
* Output quality remained at 100 percent.
* Installed app warmup completed in 0.48 seconds.

## Final quality and latency matrix

Each intensity was tested with a casual message, a plain team update, and a technical incident report.

| Intensity | Average generation | Quality checks |
| --- | ---: | ---: |
| 3 | 1.61 seconds | 33 of 33 |
| 5 | 1.60 seconds | 33 of 33 |
| 10 | 2.97 seconds | 33 of 33 |

Level 10 takes longer because it performs a deeper rewrite. All nine final outputs passed every preservation, style, structure, punctuation, and safety check.

## Release decision

Ship the completion and lifecycle changes. Keep the existing prompt and prefill configuration. Future performance work should target model execution or speculative output, not prompt compression.

The extended release check exposed a separate macOS lifecycle issue after 27 idle minutes. That fix ships in 1.2.5 and does not change the performance results above.
