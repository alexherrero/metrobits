# Runs after the GUT tests: notes the content files they read, when
# packaging/list-content.sh asks (Content.note_used).
extends GutHookScript


func run() -> void:
	Content.note_used()
