- **File:** lib/ui/zed/zed_home.dart — **Function:** `_BentoHero.build` (`chips` list)  
  **Failure scenario:** `spec.on == false` but `spec.elapsed` still contains a non-empty string (e.g. “00:00” or the previous session timer) → the session timer chip is rendered while disconnected. Other designs gate the elapsed display on `spec.on` (`_GlassHero` does), so this is inconsistent state handling.  
  **Evidence:** `if (prefs.homeChips && prefs.homeSession && spec.elapsed.isNotEmpty) (Icons.schedule_rounded, spec.elapsed),` lacks a `spec.on` guard.

- **File:** lib/ui/zed/zed_home.dart — **Function:** `_TrafficStripState.didUpdateWidget` and `_TrafficStripState.build` (graph branch)  
  **Failure scenario:** In `TrafficCardStyle.graph`, `_history` is initially empty and is only appended when the incoming rates differ from the previous widget. With non-zero initial rates, the first graph frame shows only the down text instead of bars. With steady traffic where `downRate`/`upRate` remain equal across polls, no new samples are added, so the graph freezes and does not represent the last 24 samples.  
  **Evidence:** `_history` is mutated only inside `didUpdateWidget` under `if (old.downRate != widget.downRate || old.upRate != widget.upRate) { _history.add(...); }`, while `build` renders `_history` and falls back to `value(widget.downText, ...)` when it is empty.

TOTAL FINDINGS: 2