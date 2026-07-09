extends Control

enum Difficulty { EASY, MEDIUM, HARD }

const RANGE_MIN: int = 1
const GUESS_LIMITS: Array = [15, 10, 8]
const RANGE_MAXS: Array = [50, 100, 200]
const SAVE_PATH: String = "user://save.cfg"

var target_number: int = 0
var guess_count: int = 0
var guess_limit: int = 10
var number_range: int = 100
var wins: int = 0
var losses: int = 0
var best_scores: Dictionary = {}

@onready var title_label: Label = %TitleLabel
@onready var hint_label: Label = %HintLabel
@onready var input_line: LineEdit = %InputLine
@onready var guess_button: Button = %GuessButton
@onready var result_label: Label = %ResultLabel
@onready var replay_button: Button = %ReplayButton
@onready var difficulty_option: OptionButton = %DifficultyOption
@onready var score_label: Label = %ScoreLabel
@onready var history_scroll: ScrollContainer = %HistoryScroll
@onready var history_list: ItemList = %HistoryList
@onready var sfx: AudioStreamPlayer = %SfxPlayer


func _ready() -> void:
	# 初始化难度选项
	difficulty_option.add_item("简单 (1~50, 15次)")
	difficulty_option.add_item("中等 (1~100, 10次)")
	difficulty_option.add_item("困难 (1~200, 8次)")

	# 尝试加载存档
	load_game()

	# 结果标签启用自动换行
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	start_new_game()


func start_new_game() -> void:
	target_number = randi_range(RANGE_MIN, number_range)
	guess_count = 0
	title_label.text = "猜数字游戏 ({0} ~ {1})".format([RANGE_MIN, number_range])
	hint_label.text = "猜一个 1~{0} 之间的数字 (最多 {1} 次)".format([number_range, guess_limit])
	input_line.text = ""
	input_line.editable = true
	guess_button.disabled = false
	result_label.text = ""
	result_label.modulate = Color.WHITE
	result_label.scale = Vector2.ONE
	replay_button.visible = false
	history_list.clear()


func _on_guess_button_pressed() -> void:
	var input_text: String = input_line.text.strip_edges()
	if not input_text.is_valid_int():
		result_label.text = "请输入有效整数！"
		return

	var guess: int = input_text.to_int()
	if guess < RANGE_MIN or guess > number_range:
		result_label.text = "数字必须在 {0} 到 {1} 之间！".format([RANGE_MIN, number_range])
		return

	guess_count += 1

	if guess < target_number:
		result_label.text = "第 {0} 次：太小了，再大一点！".format([guess_count])
		var idx: int = history_list.add_item("第 {0} 次: {1} → 太小".format([guess_count, guess]))
		history_list.set_item_custom_fg_color(idx, Color.SKY_BLUE)
		_play_beep(600.0, 0.08)
	elif guess > target_number:
		result_label.text = "第 {0} 次：太大了，再小一点！".format([guess_count])
		var idx: int = history_list.add_item("第 {0} 次: {1} → 太大".format([guess_count, guess]))
		history_list.set_item_custom_fg_color(idx, Color.ORANGE_RED)
		_play_beep(400.0, 0.08)
	else:
		result_label.text = "恭喜！第 {0} 次猜中了，答案就是 {1}！".format([guess_count, target_number])
		var idx: int = history_list.add_item("第 {0} 次: {1} ✅ 猜中！".format([guess_count, guess]))
		history_list.set_item_custom_fg_color(idx, Color.GREEN)
		wins += 1
		_check_new_record()
		_update_score()
		_play_win_animation()
		_play_beep(880.0, 0.3)
		_on_game_over()
		return

	# 检查猜测次数上限
	if guess_count >= guess_limit:
		result_label.text = "次数用尽！答案是 {0}".format([target_number])
		var idx: int = history_list.add_item("❌ 次数用尽！答案: {0}".format([target_number]))
		history_list.set_item_custom_fg_color(idx, Color.RED)
		losses += 1
		_update_score()
		_play_lose_animation()
		_play_beep(200.0, 0.5)
		_on_game_over()
		return

	# 滚动到最新记录
	history_list.ensure_current_is_visible()
	input_line.text = ""
	input_line.grab_focus()


func _on_game_over() -> void:
	input_line.editable = false
	guess_button.disabled = true
	replay_button.visible = true


func _on_replay_button_pressed() -> void:
	start_new_game()


func _on_input_line_text_submitted(_new_text: String) -> void:
	_on_guess_button_pressed()


func _on_difficulty_option_item_selected(index: int) -> void:
	number_range = RANGE_MAXS[index]
	guess_limit = GUESS_LIMITS[index]
	start_new_game()


func _update_score() -> void:
	var diff_key: int = difficulty_option.selected
	var best: int = best_scores.get(diff_key, -1)
	var best_text: String = "最佳: {0} 次".format([best]) if best > 0 else "最佳: --"
	score_label.text = "得分：{0} 胜 {1} 负 | {2}".format([wins, losses, best_text])


func save_game() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("game", "wins", wins)
	config.set_value("game", "losses", losses)
	config.set_value("game", "difficulty", difficulty_option.selected)
	for diff_key: int in best_scores:
		config.set_value("best_scores", str(diff_key), best_scores[diff_key])
	config.save(SAVE_PATH)


func load_game() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		# 无存档时使用默认值
		for d in Difficulty.values():
			best_scores[d] = -1
		difficulty_option.select(Difficulty.MEDIUM)
		return

	wins = config.get_value("game", "wins", 0)
	losses = config.get_value("game", "losses", 0)
	var saved_diff: int = config.get_value("game", "difficulty", Difficulty.MEDIUM)
	difficulty_option.select(saved_diff)
	number_range = RANGE_MAXS[saved_diff]
	guess_limit = GUESS_LIMITS[saved_diff]

	# 加载最佳成绩
	for d in Difficulty.values():
		best_scores[d] = config.get_value("best_scores", str(d), -1)

	_update_score()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


func _check_new_record() -> void:
	var diff_key: int = difficulty_option.selected
	var current_best: int = best_scores.get(diff_key, -1)
	if current_best < 0 or guess_count < current_best:
		best_scores[diff_key] = guess_count
		result_label.text += "\n🏆 新纪录！最少 {0} 次猜中！".format([guess_count])


func _play_win_animation() -> void:
	var tween: Tween = create_tween()
	tween.set_parallel()
	tween.tween_property(result_label, "modulate", Color.GREEN, 0.3)
	tween.tween_property(result_label, "scale", Vector2(1.3, 1.3), 0.3)
	tween.tween_property(result_label, "modulate", Color.WHITE, 0.5).set_delay(0.3)
	tween.tween_property(result_label, "scale", Vector2.ONE, 0.5).set_delay(0.3)


func _play_lose_animation() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(result_label, "modulate", Color.RED, 0.2)
	var orig_x: float = result_label.position.x
	tween.tween_property(result_label, "position:x", orig_x + 8, 0.05)
	tween.tween_property(result_label, "position:x", orig_x - 8, 0.05)
	tween.tween_property(result_label, "position:x", orig_x + 6, 0.05)
	tween.tween_property(result_label, "position:x", orig_x - 6, 0.05)
	tween.tween_property(result_label, "position:x", orig_x, 0.05)
	tween.tween_property(result_label, "modulate", Color.WHITE, 0.3)


func _play_beep(frequency: float, duration: float) -> void:
	if not sfx:
		return
	sfx.stop()
	var generator: AudioStreamGenerator = AudioStreamGenerator.new()
	generator.mix_rate = 44100
	generator.buffer_length = duration + 0.02
	sfx.stream = generator

	var sample_count: int = int(generator.mix_rate * duration)
	var playback: AudioStreamGeneratorPlayback = sfx.get_stream_playback()
	for i in range(sample_count):
		var t: float = float(i) / generator.mix_rate
		var envelope: float = 1.0 - (t / duration)
		var sample: float = sin(2.0 * PI * frequency * t) * envelope * 0.3
		playback.push_frame(Vector2(sample, sample))

	sfx.play()
