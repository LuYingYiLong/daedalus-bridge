class_name TicTacToeGame
extends RefCounted

## 井字棋核心逻辑，无 UI/Node 依赖。
## 3×3 棋盘，双方交替落子，支持胜负判平与重置。

enum Mark { EMPTY = 0, X = 1, O = 2 }
enum GameStatus { PLAYING, X_WIN, O_WIN, DRAW }

const BOARD_SIZE: int = 3

var _board: Array[Array]
var _current_player: Mark
var _status: GameStatus
var _move_count: int


func _init() -> void:
	_init_board()
	_current_player = Mark.X
	_status = GameStatus.PLAYING
	_move_count = 0


func _init_board() -> void:
	_board = []
	_board.resize(BOARD_SIZE)
	for i: int in range(BOARD_SIZE):
		_board[i] = []
		_board[i].resize(BOARD_SIZE)
		for j: int in range(BOARD_SIZE):
			_board[i][j] = Mark.EMPTY


func reset() -> void:
	for i: int in range(BOARD_SIZE):
		for j: int in range(BOARD_SIZE):
			_board[i][j] = Mark.EMPTY
	_current_player = Mark.X
	_status = GameStatus.PLAYING
	_move_count = 0


func place_mark(row: int, col: int) -> bool:
	## 尝试在 (row, col) 落子。成功返回 true，非法落子返回 false。
	if _status != GameStatus.PLAYING:
		return false
	if row < 0 or row >= BOARD_SIZE or col < 0 or col >= BOARD_SIZE:
		return false
	if _board[row][col] != Mark.EMPTY:
		return false

	_board[row][col] = _current_player
	_move_count += 1

	if _check_win(row, col):
		_status = GameStatus.X_WIN if _current_player == Mark.X else GameStatus.O_WIN
		return true

	if _move_count >= BOARD_SIZE * BOARD_SIZE:
		_status = GameStatus.DRAW
		return true

	_current_player = Mark.O if _current_player == Mark.X else Mark.X
	return true


func _check_win(row: int, col: int) -> bool:
	var mark: Mark = _board[row][col]

	# 检查行
	var count: int = 1
	var c: int = col - 1
	while c >= 0 and _board[row][c] == mark:
		count += 1
		c -= 1
	c = col + 1
	while c < BOARD_SIZE and _board[row][c] == mark:
		count += 1
		c += 1
	if count >= 3:
		return true

	# 检查列
	count = 1
	var r: int = row - 1
	while r >= 0 and _board[r][col] == mark:
		count += 1
		r -= 1
	r = row + 1
	while r < BOARD_SIZE and _board[r][col] == mark:
		count += 1
		r += 1
	if count >= 3:
		return true

	# 检查主对角线
	count = 1
	r = row - 1
	c = col - 1
	while r >= 0 and c >= 0 and _board[r][c] == mark:
		count += 1
		r -= 1
		c -= 1
	r = row + 1
	c = col + 1
	while r < BOARD_SIZE and c < BOARD_SIZE and _board[r][c] == mark:
		count += 1
		r += 1
		c += 1
	if count >= 3:
		return true

	# 检查副对角线
	count = 1
	r = row - 1
	c = col + 1
	while r >= 0 and c < BOARD_SIZE and _board[r][c] == mark:
		count += 1
		r -= 1
		c += 1
	r = row + 1
	c = col - 1
	while r < BOARD_SIZE and c >= 0 and _board[r][c] == mark:
		count += 1
		r += 1
		c -= 1
	if count >= 3:
		return true

	return false


func get_board() -> Array[Array]:
	return _board


func get_current_player() -> Mark:
	return _current_player


func get_winner() -> Mark:
	## 返回获胜方 Mark；未分出胜负或平局时返回 Mark.EMPTY。
	match _status:
		GameStatus.X_WIN:
			return Mark.X
		GameStatus.O_WIN:
			return Mark.O
		_:
			return Mark.EMPTY


func get_status() -> GameStatus:
	return _status


func is_draw() -> bool:
	return _status == GameStatus.DRAW
