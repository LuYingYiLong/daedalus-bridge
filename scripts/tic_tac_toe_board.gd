extends Control

## 井字棋 UI 控制器，持有 TicTacToeGame 实例并驱动棋盘显示。

var _game: TicTacToeGame

@onready var _status_label: Label = %StatusLabel
@onready var _grid_container: GridContainer = %GridContainer
@onready var _replay_button: Button = %ReplayButton


func _ready() -> void:
	_game = TicTacToeGame.new()
	_connect_cells()
	_update_board_display()
	_update_status_label()
	_replay_button.visible = false


func _connect_cells() -> void:
	for i: int in range(3):
		for j: int in range(3):
			var cell: Button = _grid_container.get_node("Cell_" + str(i) + "_" + str(j))
			cell.pressed.connect(_on_cell_pressed.bind(i, j))


func _on_cell_pressed(row: int, col: int) -> void:
	if not _game.place_mark(row, col):
		return
	_update_board_display()
	_update_status_label()
	if _game.get_status() != TicTacToeGame.GameStatus.PLAYING:
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
	for i: int in range(3):
		for j: int in range(3):
			var cell: Button = _grid_container.get_node("Cell_" + str(i) + "_" + str(j))
			match board[i][j]:
				TicTacToeGame.Mark.X:
					cell.text = "X"
				TicTacToeGame.Mark.O:
					cell.text = "O"
				_:
					cell.text = ""


func _update_status_label() -> void:
	match _game.get_status():
		TicTacToeGame.GameStatus.PLAYING:
			var player: String = "X" if _game.get_current_player() == TicTacToeGame.Mark.X else "O"
			_status_label.text = player + " 的回合"
		TicTacToeGame.GameStatus.X_WIN:
			_status_label.text = "X 获胜！"
		TicTacToeGame.GameStatus.O_WIN:
			_status_label.text = "O 获胜！"
		TicTacToeGame.GameStatus.DRAW:
			_status_label.text = "平局！"


func _set_cells_disabled(disabled: bool) -> void:
	var cells: Array[Node] = _grid_container.get_children()
	for cell: Node in cells:
		if cell is Button:
			cell.disabled = disabled
