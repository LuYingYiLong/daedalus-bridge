extends Control

## 五子棋 UI 控制器，持有 GomokuGame 实例并驱动棋盘显示。
## 15×15 棋盘按钮在 _ready() 中动态生成，不依赖场景预置。

var _game: GomokuGame
var _cell_buttons: Array[Array] = []  ## [row][col] → Button

@onready var _status_label: Label = %StatusLabel
@onready var _board_container: GridContainer = %BoardContainer
@onready var _replay_button: Button = %ReplayButton


func _ready() -> void:
	_game = GomokuGame.new(15)
	_build_board()
	_update_board_display()
	_update_status_label()
	_replay_button.visible = false


func _build_board() -> void:
	var board_size: int = _game.get_board_size()
	_cell_buttons = []
	_cell_buttons.resize(board_size)
	for row: int in range(board_size):
		_cell_buttons[row] = []
		_cell_buttons[row].resize(board_size)
		for col: int in range(board_size):
			var btn: Button = Button.new()
			btn.custom_minimum_size = Vector2(40, 40)
			btn.pressed.connect(_on_cell_pressed.bind(row, col))
			_board_container.add_child(btn)
			_cell_buttons[row][col] = btn


func _on_cell_pressed(row: int, col: int) -> void:
	if not _game.place_stone(row, col):
		return
	_update_board_display()
	_update_status_label()
	if _game.get_status() != GomokuGame.GameStatus.PLAYING:
		_set_cells_disabled(true)
		_replay_button.visible = true


func _on_replay_pressed() -> void:
	_game.reset()
	_set_cells_disabled(false)
	_replay_button.visible = false
	_update_board_display()
	_update_status_label()


func _update_board_display() -> void:
	var board: Array[Array] = _game.get_board()
	var board_size: int = _game.get_board_size()
	for row: int in range(board_size):
		for col: int in range(board_size):
			var btn: Button = _cell_buttons[row][col]
			match board[row][col]:
				GomokuGame.Stone.BLACK:
					btn.text = "●"
				GomokuGame.Stone.WHITE:
					btn.text = "○"
				_:
					btn.text = ""


func _update_status_label() -> void:
	match _game.get_status():
		GomokuGame.GameStatus.PLAYING:
			var player: String = "黑棋" if _game.get_current_player() == GomokuGame.Stone.BLACK else "白棋"
			_status_label.text = player + "的回合"
		GomokuGame.GameStatus.BLACK_WIN:
			_status_label.text = "黑棋获胜！"
		GomokuGame.GameStatus.WHITE_WIN:
			_status_label.text = "白棋获胜！"
		GomokuGame.GameStatus.DRAW:
			_status_label.text = "平局！"


func _set_cells_disabled(disabled: bool) -> void:
	for row: int in range(_cell_buttons.size()):
		for col: int in range(_cell_buttons[row].size()):
			_cell_buttons[row][col].disabled = disabled
