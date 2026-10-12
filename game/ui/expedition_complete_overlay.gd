class_name ExpeditionCompleteOverlay
extends CanvasLayer
## Temporary run-end scaffolding for a COMPLETED expedition -- the success twin of
## FailureOverlay, copied rather than shared (§1.4: this is the second use, not the third).
## The real Emergency Recall / extraction screen (WORLD-CANON framing) is its own M2 gate item.

func show_complete() -> void:
	visible = true
