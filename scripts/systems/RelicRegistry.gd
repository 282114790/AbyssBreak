# RelicRegistry.gd
# 所有遗物的定义库（静态数据）
extends Node
class_name RelicRegistry

# 遗物池（按稀有度分）
static func get_all() -> Array:
	return [
		# ── 普通 ──────────────────────────────────────────
		_make("blood_stone",    "🩸 血石",      "最大血量+150",                        1, {hp_bonus=150.0}),
		_make("swift_boots",   "👟 疾风靴",    "移动速度+30",                          1, {speed_bonus=30.0}),
		_make("magnet_core",   "🧲 磁核",      "拾取范围+80",                          1, {pickup_bonus=80.0}),
		_make("thorn_ring",    "🌿 荆棘戒",    "伤害+10%",                             1, {damage_bonus=0.10}),
		_make("gold_coin",     "🪙 金币",      "经验获取+20%",                         1, {exp_mult=1.20}),
		_make("herb_pouch",    "🌱 草药袋",    "每秒回血+3",                           1, {regen_bonus=3.0}),
		_make("speed_rune",    "⚡ 速冲符文",  "冷却时间-10%",                         1, {cooldown_mult=0.90}),
		_make("dodge_charm",   "💨 闪避符",    "翻滚冷却-0.15s",                       1, {dodge_recharge=0.15}),
		# ── 稀有 ──────────────────────────────────────────
		_make("void_crystal",  "🔮 虚空晶石",  "伤害+25%，冷却-15%",                   2, {damage_bonus=0.25, cooldown_mult=0.85}),
		_make("dragon_heart",  "🐉 龙之心",    "最大血量+300，每秒回血+5",             2, {hp_bonus=300.0, regen_bonus=5.0}),
		_make("shadow_cloak",  "🌑 暗影披风",  "移动速度+50，翻滚冷却-0.2s",           2, {speed_bonus=50.0, dodge_recharge=0.20}),
		_make("exp_catalyst",  "⚗️ 经验催化剂","经验获取+40%",                         2, {exp_mult=1.40}),
		_make("crit_gem",      "💎 暴击宝石",  "暴击率+15%，暴击伤害×1.3",             2, {crit_chance=0.15, crit_mult=1.30}),
		_make("extra_bolt",    "➕ 额外弹道",  "所有投射技能额外+1弹",                 2, {projectile_bonus=1}),
		# ── 史诗 ──────────────────────────────────────────
		_make("abyss_fragment","🌀 深渊碎片",  "伤害+40%，最大血量+200",               3, {damage_bonus=0.40, hp_bonus=200.0}),
		_make("time_jewel",    "⏳ 时间宝石",  "冷却时间-30%",                         3, {cooldown_mult=0.70}),
		_make("phoenix_ash",   "🔥 凤凰灰",    "最大血量×1.5，每秒回血+8",             3, {hp_mult=1.50, regen_bonus=8.0}),
		_make("omni_core",     "✨ 全能核心",  "全属性+15%（血/速/伤/经验）",          3, {hp_mult=1.15, damage_bonus=0.15, speed_bonus=24.0, exp_mult=1.15}),
	]

static func get_pool(rarity: int) -> Array:
	return get_all().filter(func(r): return r.rarity == rarity)

static func get_random_choices(count: int = 3, owned_ids: Array = []) -> Array:
	# 按权重随机：普通60% 稀有30% 史诗10%
	var pool: Array = []
	var all = get_all().filter(func(r): return not owned_ids.has(r.id))
	# 打权重标签
	for r in all:
		var w = 6 if r.rarity == 1 else (3 if r.rarity == 2 else 1)
		for _i in range(w):
			pool.append(r)
	pool.shuffle()
	var result: Array = []
	var seen_ids: Array = []
	for item in pool:
		if not seen_ids.has(item.id):
			result.append(item)
			seen_ids.append(item.id)
		if result.size() >= count:
			break
	return result

static func _make(id: String, name: String, desc: String, rarity: int, props: Dictionary) -> RelicData:
	var r = RelicData.new()
	r.id           = id
	r.display_name = name
	r.description  = desc
	r.rarity       = rarity
	for k in props:
		r.set(k, props[k])
	match rarity:
		1: r.icon_emoji = "📦"
		2: r.icon_emoji = "💜"
		3: r.icon_emoji = "🌟"
	return r
