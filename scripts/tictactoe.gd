extends Control

## 当前玩家 'X' 或 'O'
var current_player: String = "X"

## 棋盘状态，9 个格子，空字符串表示未落子
var board: Array[String] = ["", "", "", "", "", "", "", "", ""]

## 按钮引用缓存
var buttons: Array[Button] = []

@onready var status_label: Label = $StatusLabel


func _ready() -> void:
	# 收集按钮并连接 pressed 信号
	for i in range(9):
		var button: Button = get_node("Board/Button" + str(i))
		buttons.append(button)
		button.pressed.connect(_on_button_pressed.bind(i))


## 按钮点击处理
func _on_button_pressed(index: int) -> void:
	# 格子已被占用或游戏已结束则忽略
	if board[index] != "":
		return

	board[index] = current_player
	buttons[index].text = current_player
	buttons[index].disabled = true

	if _check_win(current_player):
		status_label.text = "玩家 " + current_player + " 获胜！"
		_disable_all_buttons()
		return

	if _check_draw():
		status_label.text = "平局！"
		return

	# 切换玩家
	current_player = "O" if current_player == "X" else "X"
	status_label.text = "玩家 " + current_player + " 的回合"


## 检查指定玩家是否获胜
func _check_win(player: String) -> bool:
	var wins: Array = [
		[0, 1, 2], [3, 4, 5], [6, 7, 8],  # 行
		[0, 3, 6], [1, 4, 7], [2, 5, 8],  # 列
		[0, 4, 8], [2, 4, 6],             # 对角线
	]
	for w in wins:
		if board[w[0]] == player and board[w[1]] == player and board[w[2]] == player:
			return true
	return false


## 检查平局
func _check_draw() -> bool:
	for cell in board:
		if cell == "":
			return false
	return true


## 禁用所有按钮
func _disable_all_buttons() -> void:
	for btn in buttons:
		btn.disabled = true


## 重置游戏
func reset_game() -> void:
	board = ["", "", "", "", "", "", "", "", ""]
	current_player = "X"
	status_label.text = "玩家 X 的回合"
	for i in range(9):
		buttons[i].text = ""
		buttons[i].disabled = false
