class_name TestCardManager
# 炸金花比牌逻辑测试
# 运行方式：在 Godot 编辑器中将此脚本挂载到任意节点，运行场景即可在输出看到结果
extends Node

# 牌字符串格式: "suit-point-frame"
# suit: 1=Heart 2=Diamond 3=Spade 4=Club
# 构造辅助：只需 suit 和 point，frame 从 CardManager.CARDS 取
static func c(suit: int, point: String) -> String:
	return "%d-%s-%d" % [suit, point, CardManager.CARDS[suit][point]]

var _pass := 0
var _fail := 0

func _ready() -> void:
	_run_all()
	print("=============================")
	print("测试完成  通过: %d  失败: %d" % [_pass, _fail])

func _run_all() -> void:
	_test_evaluate_hand()
	_test_special_235()
	_test_compare_hands()

# ─── 牌型识别 ────────────────────────────────────────────────
func _test_evaluate_hand() -> void:
	_section("牌型识别")

	# 豹子
	_assert_rank([c(1, "A"), c(2, "A"), c(3, "A")],
		CardManager.HAND_RANK.LEOPARD, "AAA 豹子")

	# 同花顺
	_assert_rank([c(1, "A"), c(1, "2"), c(1, "3")],
		CardManager.HAND_RANK.STRAIGHT_FLUSH, "同花顺 A23 (Heart)")

	_assert_rank([c(2, "J"), c(2, "Q"), c(2, "K")],
		CardManager.HAND_RANK.STRAIGHT_FLUSH, "同花顺 JQK (Diamond)")

	# 同花（非顺）
	_assert_rank([c(3, "2"), c(3, "5"), c(3, "9")],
		CardManager.HAND_RANK.FLUSH, "同花 259 (Spade)")

	# 顺子（非同花）
	_assert_rank([c(1, "3"), c(2, "4"), c(3, "5")],
		CardManager.HAND_RANK.STRAIGHT, "顺子 345 杂色")

	# A-2-3 特殊顺子
	_assert_rank([c(1, "A"), c(2, "2"), c(3, "3")],
		CardManager.HAND_RANK.STRAIGHT, "顺子 A23 杂色")

	# 对子
	_assert_rank([c(1, "K"), c(2, "K"), c(3, "7")],
		CardManager.HAND_RANK.PAIR, "对子 KK7")

	# 散牌
	_assert_rank([c(1, "2"), c(2, "5"), c(3, "9")],
		CardManager.HAND_RANK.HIGH_CARD, "散牌 259 杂色")

# ─── 235 特殊牌型 ─────────────────────────────────────────────
func _test_special_235() -> void:
	_section("235 特殊牌型")

	var hand_235_mixed: Array[String] = [c(1, "2"), c(2, "3"), c(3, "5")]
	var hand_235_flush: Array[String] = [c(1, "2"), c(1, "3"), c(1, "5")]

	# 杂色 235 是 SPECIAL_235
	_assert_rank(hand_235_mixed, CardManager.HAND_RANK.SPECIAL_235, "杂色 235 = SPECIAL_235")

	# 同花 235 是同花（不触发特殊）
	_assert_rank(hand_235_flush, CardManager.HAND_RANK.FLUSH, "同花 235 = FLUSH（不触发特殊）")

	# 235 赢豹子
	var leopard: Array[String] = [c(1, "K"), c(2, "K"), c(3, "K")]
	_assert_gt(CardManager.compare_hands(hand_235_mixed, leopard), 0, "235 赢 KKK 豹子")

	# 235 输给同花顺
	var sf: Array[String] = [c(1, "J"), c(1, "Q"), c(1, "K")]
	_assert_lt(CardManager.compare_hands(hand_235_mixed, sf), 0, "235 输给同花顺")

	# 235 输给同花
	_assert_lt(CardManager.compare_hands(hand_235_mixed, hand_235_flush), 0, "235 输给同花 235")

	# 235 输给顺子
	var straight: Array[String] = [c(1, "3"), c(2, "4"), c(3, "5")]
	_assert_lt(CardManager.compare_hands(hand_235_mixed, straight), 0, "235 输给顺子")

	# 235 输给对子
	var pair: Array[String] = [c(1, "2"), c(2, "2"), c(3, "9")]
	_assert_lt(CardManager.compare_hands(hand_235_mixed, pair), 0, "235 输给对子")

	# 235 输给散牌
	var high: Array[String] = [c(1, "A"), c(2, "7"), c(3, "3")]
	_assert_lt(CardManager.compare_hands(hand_235_mixed, high), 0, "235 输给散牌")

	# 235 vs 235 平局
	var hand_235_b: Array[String] = [c(2, "2"), c(3, "3"), c(4, "5")]
	_assert_eq(CardManager.compare_hands(hand_235_mixed, hand_235_b), 0, "235 vs 235 平局")

# ─── 两人比牌 ─────────────────────────────────────────────────
func _test_compare_hands() -> void:
	_section("两人比牌")

	# 豹子 > 同花顺
	var leopard_a: Array[String] = [c(1, "A"), c(2, "A"), c(3, "A")]
	var sf_k: Array[String] = [c(1, "J"), c(1, "Q"), c(1, "K")]
	_assert_gt(CardManager.compare_hands(leopard_a, sf_k), 0, "AAA 豹子 > 同花顺 JQK")

	# 同花顺 > 同花
	var flush_high: Array[String] = [c(1, "A"), c(1, "K"), c(1, "9")]
	_assert_gt(CardManager.compare_hands(sf_k, flush_high), 0, "同花顺 JQK > 同花 AK9")

	# 同花 > 顺子
	var straight_high: Array[String] = [c(1, "Q"), c(2, "K"), c(3, "A")]
	_assert_gt(CardManager.compare_hands(flush_high, straight_high), 0, "同花 AK9 > 顺子 QKA")

	# 顺子 > 对子
	var pair_aa: Array[String] = [c(1, "A"), c(2, "A"), c(3, "2")]
	_assert_gt(CardManager.compare_hands(straight_high, pair_aa), 0, "顺子 QKA > 对子 AA2")

	# 对子 > 散牌
	var high_card: Array[String] = [c(1, "A"), c(2, "K"), c(3, "J")]
	_assert_gt(CardManager.compare_hands(pair_aa, high_card), 0, "对子 AA2 > 散牌 AKJ")

	# 同牌型比点数：豹子 AAA > KKK
	var leopard_k: Array[String] = [c(1, "K"), c(2, "K"), c(3, "K")]
	_assert_gt(CardManager.compare_hands(leopard_a, leopard_k), 0, "AAA > KKK 豹子点数比较")

	# 同牌型比点数：对子 AA2 > AA 对子但带 K
	var pair_aa_k: Array[String] = [c(1, "A"), c(2, "A"), c(3, "K")]
	_assert_gt(CardManager.compare_hands(pair_aa_k, pair_aa), 0, "对子 AAK > AA2 踢脚牌比较")

	# 散牌比最大牌：AKJ > AKQ? 不对，AKQ > AKJ
	var high_akq: Array[String] = [c(1, "A"), c(2, "K"), c(3, "Q")]
	_assert_gt(CardManager.compare_hands(high_akq, high_card), 0, "散牌 AKQ > AKJ")

	# 完全相同点数平局
	var hand_a: Array[String] = [c(1, "A"), c(2, "K"), c(3, "J")]
	var hand_b: Array[String] = [c(2, "A"), c(3, "K"), c(4, "J")]
	_assert_eq(CardManager.compare_hands(hand_a, hand_b), 0, "相同点数平局")

# ─── 断言工具 ─────────────────────────────────────────────────
func _section(title: String) -> void:
	print("\n── %s ──" % title)

func _assert_rank(cards: Array[String], expected: CardManager.HAND_RANK, label: String) -> void:
	var result: int = CardManager.evaluate_hand(cards)["rank"]
	if result == expected:
		_pass += 1
		print("  ✓ %s" % label)
	else:
		_fail += 1
		print("  ✗ %s  期望=%s  实际=%s" % [label,
			CardManager.HAND_RANK.keys()[expected],
			CardManager.HAND_RANK.keys()[result]])

func _assert_gt(val: int, than: int, label: String) -> void:
	if val > than:
		_pass += 1
		print("  ✓ %s" % label)
	else:
		_fail += 1
		print("  ✗ %s  期望 >%d  实际=%d" % [label, than, val])

func _assert_lt(val: int, than: int, label: String) -> void:
	if val < than:
		_pass += 1
		print("  ✓ %s" % label)
	else:
		_fail += 1
		print("  ✗ %s  期望 <%d  实际=%d" % [label, than, val])

func _assert_eq(val, expected, label: String) -> void:
	if val == expected:
		_pass += 1
		print("  ✓ %s" % label)
	else:
		_fail += 1
		print("  ✗ %s  期望=%s  实际=%s" % [label, str(expected), str(val)])
