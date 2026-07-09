class_name GomokuGame
extends RefCounted

## 五子棋核心逻辑，无 UI/Node 依赖。
## 标准 15×15 棋盘，双方交替落子，支持胜负判平与重置。

enum Stone { EMPTY = 0, BLACK = 1, WHITE = 2 }
enum GameStatus { PLAYING, BLACK_WIN, WHITE_WIN, DRAW }

const DEFAULT_BOARD_SIZE: int = 15
const WIN_COUNT: int = 5

## 四个检查方向：[dr, dc]，每个方向正反两端扫描
const WIN_DIRECTIONS: Array[Array] = [
	[0, 1],   # 水平
	[1, 0],   # 垂直
	[1, 1],   # 主对角线
	[1, -1],  # 副对角线
]

var _board: Array[Array]
var _board_size: int
var _current_player: Stone
var _status: GameStatus
var _move_count: int


func _init(board_size: int = DEFAULT_BOARD_SIZE) -> void:
	_board_size = board_size
	_init_board()
	_current_player = Stone.BLACK
	_status = GameStatus.PLAYING
	_move_count = 0


func _init_board() -> void:
	_board = []
	_board.resize(_board_size)
	for i: int in range(_board_size):
		_board[i] = []
		_board[i].resize(_board_size)
		for j: int in range(_board_size):
			_board[i][j] = Stone.EMPTY


func reset() -> void:
	for i: int in range(_board_size):
		for j: int in range(_board_size):
			_board[i][j] = Stone.EMPTY
	_current_player = Stone.BLACK
	_status = GameStatus.PLAYING
	_move_count = 0


func place_stone(row: int, col: int) -> bool:
	## 尝试在 (row, col) 落子。成功返回 true，非法落子返回 false。
	if _status != GameStatus.PLAYING:
		return false
	if row < 0 or row >= _board_size or col < 0 or col >= _board_size:
		return false
	if _board[row][col] != Stone.EMPTY:
		return false

	_board[row][col] = _current_player
	_move_count += 1

	if _check_win(row, col):
		_status = GameStatus.BLACK_WIN if _current_player == Stone.BLACK else GameStatus.WHITE_WIN
		return true

	if _move_count >= _board_size * _board_size:
		_status = GameStatus.DRAW
		return true

	_current_player = Stone.WHITE if _current_player == Stone.BLACK else Stone.BLACK
	return true


func _check_win(row: int, col: int) -> bool:
	var stone: Stone = _board[row][col]
	for dir: Array in WIN_DIRECTIONS:
		var dr: int = dir[0]
		var dc: int = dir[1]
		var count: int = 1

		# 正方向扫描
		var r: int = row + dr
		var c: int = col + dc
		while r >= 0 and r < _board_size and c >= 0 and c < _board_size and _board[r][c] == stone:
			count += 1
			r += dr
			c += dc

		# 反方向扫描
		r = row - dr
		c = col - dc
		while r >= 0 and r < _board_size and c >= 0 and c < _board_size and _board[r][c] == stone:
			count += 1
			r -= dr
			c -= dc

		if count >= WIN_COUNT:
			return true

	return false


func get_board() -> Array[Array]:
	return _board


func get_board_size() -> int:
	return _board_size


func get_current_player() -> Stone:
	return _current_player


func get_winner() -> Stone:
	## 返回获胜方 Stone；未分出胜负或平局时返回 Stone.EMPTY。
	match _status:
		GameStatus.BLACK_WIN:
			return Stone.BLACK
		GameStatus.WHITE_WIN:
			return Stone.WHITE
		_:
			return Stone.EMPTY


func get_status() -> GameStatus:
	return _status


func is_draw() -> bool:
	return _status == GameStatus.DRAW
