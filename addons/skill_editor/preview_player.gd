# preview_player.gd
# 技能编辑器预览用的简易 Player 代理，提供技能系统所需的最小接口
@tool
extends Node2D

var hp: float = 500.0
var damage_multiplier: float = 1.0
var attack_speed_multiplier: float = 1.0
var move_speed: float = 240.0
