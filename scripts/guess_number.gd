extends Control

const MIN_NUMBER: int = 1
const MAX_NUMBER: int = 100

var target_number: int = 0
var guess_count: int = 0

@onready var title_label: Label = %TitleLabel
@onready var hint_label: Label = %HintLabel
@onready var input_line: LineEdit = %InputLine
@onready var guess_button: Button = %GuessButton
@onready var result_label: Label = %ResultLabel
@onready var replay_button: Button = %ReplayButton


func _ready() -> void:
	start_new_game()


func start_new_game() -> void:
	target_number = randi_range(MIN_NUMBER, MAX_NUMBER)
	guess_count = 0
	title_label.text = "猜数字游戏 (%d ~ %d)" % [MIN_NUMBER, MAX_NUMBER]
	hint_label.text = "请输入你猜的数字"
	input_line.text = ""
	input_line.editable = true
	guess_button.disabled = false
	result_label.text = ""
	replay_button.visible = false


func _on_guess_button_pressed() -> void:
	var input_text: String = input_line.text.strip_edges()
	if not input_text.is_valid_int():
		result_label.text = "请输入有效整数！"
		return

	var guess: int = input_text.to_int()
	if guess < MIN_NUMBER or guess > MAX_NUMBER:
		result_label.text = "数字必须在 %d 到 %d 之间！" % [MIN_NUMBER, MAX_NUMBER]
		return

	guess_count += 1

	if guess < target_number:
		result_label.text = "第 %d 次：太小了，再大一点！" % guess_count
	elif guess > target_number:
		result_label.text = "第 %d 次：太大了，再小一点！" % guess_count
	else:
		result_label.text = "恭喜！第 %d 次猜中了，答案就是 %d！" % [guess_count, target_number]
		_on_game_won()


func _on_game_won() -> void:
	input_line.editable = false
	guess_button.disabled = true
	replay_button.visible = true


func _on_replay_button_pressed() -> void:
	start_new_game()


func _on_input_line_text_submitted(_new_text: String) -> void:
	_on_guess_button_pressed()
