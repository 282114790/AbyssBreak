# Locale.gd (AutoLoad: "Locale")
# 多语言本地化（#30）— 所有UI文本集中管理
# 当前支持：zh_CN（默认）/ en_US
extends Node

var _lang: String = "zh_CN"

const _STRINGS := {
	"zh_CN": {
		# 角色选择
		"ui.char_select.title": "选择你的角色",
		"ui.char_select.confirm": "出发！",
		# HUD
		"hud.wave": "第 %d 波",
		"hud.time": "存活 %02d:%02d",
		"hud.score": "得分 %d",
		"hud.hp": "HP",
		"hud.souls": "💎 %d",
		"hud.elite_warning": "⚠ 精英波来袭！",
		"hud.boss_warning": "👹 深渊魔王降临！",
		# 升级
		"upgrade.title": "选择升级（第1次）",
		"upgrade.title2": "选择升级（第2次）",
		"upgrade.curse_hint": "☠ 含诅咒选项 — 高风险高回报",
		# 遗物
		"relic.select.title": "选择遗物",
		# 暂停
		"pause.title": "⏸ 已暂停",
		"pause.skills": "⚔ 当前技能",
		"pause.relics": "💎 当前遗物",
		"pause.curses": "☠ 诅咒",
		"pause.resume": "▶ 继续游戏 (ESC/P)",
		"pause.restart": "🔄 重新开始",
		# 结算
		"result.win": "✨ 深渊突破！",
		"result.lose": "💀 深渊吞噬了你",
		"result.wave": "🌊 到达波次",
		"result.time": "⏱ 存活时长",
		"result.kills": "💀 击杀数",
		"result.score": "⭐ 得分",
		"result.souls_earned": "💎 获得魂石",
		"result.souls_total": "当前魂石总量：%d",
		"result.best_wave": "🏆 历史最高波次",
		"result.best_score": "🏅 历史最高分",
		"result.build": "📋 本局 Build",
		"result.unlock": "💎 解锁强化",
		"result.restart": "🔄 再来一局",
		# 商人
		"merchant.title": "🧙 神秘商人出现了！",
		"merchant.souls": "💎 当前魂石：%d",
		"merchant.leave": "离开",
		# 随机事件
		"event.choose": "做出你的选择",
		# 路线
		"route.title": "🗺 选择你的路线",
		"route.select": "选择此路线",
		# 新手引导
		"tutorial.move": "🎮 新手引导（1/4）：用 WASD 移动角色",
		"tutorial.skill_up": "⬆ 新手引导（2/4）：等待升级 → 选一个技能",
		"tutorial.cast": "⚡ 新手引导（3/4）：按 Q 或 E 释放主动技能！",
		"tutorial.kill_elite": "💀 新手引导（4/4）：击败一个精英敌人！",
		"tutorial.done": "✅ 引导完成！享受冒险吧！",
	},
	"en_US": {
		"ui.char_select.title": "Choose Your Character",
		"ui.char_select.confirm": "Let's Go!",
		"hud.wave": "Wave %d",
		"hud.time": "%02d:%02d",
		"hud.score": "Score %d",
		"hud.hp": "HP",
		"hud.souls": "💎 %d",
		"hud.elite_warning": "⚠ Elite Wave!",
		"hud.boss_warning": "👹 Abyss Boss Incoming!",
		"upgrade.title": "Level Up! (Pick 1 of 5)",
		"upgrade.title2": "Level Up! (Pick 2nd)",
		"upgrade.curse_hint": "☠ Contains Curse — High Risk, High Reward",
		"relic.select.title": "Choose a Relic",
		"pause.title": "⏸ Paused",
		"pause.skills": "⚔ Current Skills",
		"pause.relics": "💎 Current Relics",
		"pause.curses": "☠ Curses",
		"pause.resume": "▶ Resume (ESC/P)",
		"pause.restart": "🔄 Restart",
		"result.win": "✨ Abyss Broken!",
		"result.lose": "💀 Swallowed by the Abyss",
		"result.wave": "🌊 Wave Reached",
		"result.time": "⏱ Survival Time",
		"result.kills": "💀 Kills",
		"result.score": "⭐ Score",
		"result.souls_earned": "💎 Souls Earned",
		"result.souls_total": "Total Souls: %d",
		"result.best_wave": "🏆 Best Wave",
		"result.best_score": "🏅 Best Score",
		"result.build": "📋 Run Build",
		"result.unlock": "💎 Unlock",
		"result.restart": "🔄 Play Again",
		"merchant.title": "🧙 A Merchant Appears!",
		"merchant.souls": "💎 Souls: %d",
		"merchant.leave": "Leave",
		"route.title": "🗺 Choose Your Route",
		"route.select": "Select",
		"tutorial.move": "🎮 Tutorial (1/4): Move with WASD",
		"tutorial.skill_up": "⬆ Tutorial (2/4): Level up and pick a skill",
		"tutorial.cast": "⚡ Tutorial (3/4): Press Q or E to cast!",
		"tutorial.kill_elite": "💀 Tutorial (4/4): Kill an Elite enemy!",
		"tutorial.done": "✅ Tutorial Complete! Have fun!",
	}
}

func set_lang(lang: String) -> void:
	if _STRINGS.has(lang):
		_lang = lang

func get_lang() -> String:
	return _lang

func t(key: String, args: Array = []) -> String:
	var dict = _STRINGS.get(_lang, _STRINGS["zh_CN"])
	var text = dict.get(key, _STRINGS["zh_CN"].get(key, key))
	if args.is_empty(): return text
	return text % args
