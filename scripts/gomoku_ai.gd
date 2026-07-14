class_name GomokuAI
extends RefCounted


## 简单五子棋 AI —— 基于空位四方向评分策略
## 遍历棋盘所有空位，对每个空位计算四个方向上的攻防加权分，返回最高分位置


## 方向向量（四个方向：水平、垂直、主对角线、副对角线）
const DIRECTIONS: Array[Array] = [
	[0, 1],   ## 水平
	[1, 0],   ## 垂直
	[1, 1],   ## 主对角线
	[1, -1],  ## 副对角线
]


func get_best_move(board: Array[Array], board_size: int, ai_stone: GomokuGame.Stone) -> Array[int]:
	var best_score: int = -999999
	var best_moves: Array[Array] = []   ## type: Array[Array[int]]（int 坐标对）

	var opponent_stone: GomokuGame.Stone = (
		GomokuGame.Stone.WHITE if ai_stone == GomokuGame.Stone.BLACK
		else GomokuGame.Stone.BLACK
	)

	for row: int in range(board_size):
		for col: int in range(board_size):
			if board[row][col] != GomokuGame.Stone.EMPTY:
				continue

			var score: int = _evaluate_position(board, board_size, row, col, ai_stone, opponent_stone)

			if score > best_score:
				best_score = score
				best_moves = [[row, col]]
			elif score == best_score:
				best_moves.append([row, col])

	## 最高分有多个候选时随机选一个，避免每次走同一边
	if best_moves.size() > 0:
		return best_moves[randi() % best_moves.size()]

	## 理论上不会走到这里（棋盘总有空位），兜底返回中心
	return [board_size / 2, board_size / 2]


func _evaluate_position(
	board: Array[Array],
	board_size: int,
	row: int,
	col: int,
	ai_stone: GomokuGame.Stone,
	opponent_stone: GomokuGame.Stone
) -> int:
	var total_score: int = 0

	for dir_vec: Array in DIRECTIONS:
		var dr: int = dir_vec[0]
		var dc: int = dir_vec[1]

		var ai_count: int = 1    ## 假设此处落 AI 子，自身算 1
		var opp_count: int = 0
		var open_ends: int = 0

		## 正方向扫描
		var r: int = row + dr
		var c: int = col + dc
		while r >= 0 and r < board_size and c >= 0 and c < board_size:
			if board[r][c] == ai_stone:
				ai_count += 1
			else:
				if board[r][c] == GomokuGame.Stone.EMPTY:
					open_ends += 1
				break
			r += dr
			c += dc

		## 反方向扫描
		r = row - dr
		c = col - dc
		while r >= 0 and r < board_size and c >= 0 and c < board_size:
			if board[r][c] == ai_stone:
				ai_count += 1
			else:
				if board[r][c] == GomokuGame.Stone.EMPTY:
					open_ends += 1
				break
			r -= dr
			c -= dc

		## 对方方向扫描（用于防守评分）
		var opp_scan_count: int = 0
		var opp_open_ends: int = 0
		r = row + dr
		c = col + dc
		while r >= 0 and r < board_size and c >= 0 and c < board_size:
			if board[r][c] == opponent_stone:
				opp_scan_count += 1
			else:
				if board[r][c] == GomokuGame.Stone.EMPTY:
					opp_open_ends += 1
				break
			r += dr
			c += dc
		r = row - dr
		c = col - dc
		while r >= 0 and r < board_size and c >= 0 and c < board_size:
			if board[r][c] == opponent_stone:
				opp_scan_count += 1
			else:
				if board[r][c] == GomokuGame.Stone.EMPTY:
					opp_open_ends += 1
				break
			r -= dr
			c -= dc

		## --- 攻击评分 ---
		total_score += _score_line(ai_count, open_ends)

		## --- 防守评分（如果对方在这条线上有威胁） ---
		if opp_scan_count >= 2:
			total_score += _score_line(opp_scan_count + 1, opp_open_ends) * 8 / 10

	return total_score


## 根据连续子数和开放端数返回该方向的分数
func _score_line(count: int, open_ends: int) -> int:
	if count >= 5:
		return 100000                     ## 五连 / 超过五连，直接获胜
	match count:
		4:
			if open_ends == 2:  return 50000   ## 活四
			elif open_ends == 1: return 5000   ## 冲四
		3:
			if open_ends == 2:  return 5000    ## 活三
			elif open_ends == 1: return 500    ## 眠三
		2:
			if open_ends == 2:  return 500     ## 活二
			elif open_ends == 1: return 50     ## 眠二
		1:
			if open_ends == 2:  return 50      ## 活一
			elif open_ends == 1: return 10     ## 眠一
	return 0
