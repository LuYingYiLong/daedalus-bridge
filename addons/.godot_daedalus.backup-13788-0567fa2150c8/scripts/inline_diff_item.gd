@tool
extends MarginContainer

@onready var path_label: Label = %PathLabel
@onready var inline_diff_label: Label = %InlineDiffLabel


func setup(path_text: String, additions: int, deletions: int) -> void:
	path_label.text = path_text
	inline_diff_label.text = "+%d -%d" % [maxi(additions, 0), maxi(deletions, 0)]
