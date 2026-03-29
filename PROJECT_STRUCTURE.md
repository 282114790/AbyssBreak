# autoload/EventBus.gd 的注册配置
# 以下是 project.godot 需要追加的 autoload 配置
# 已在 project.godot 中使用，确保 EventBus 和 UpgradeSystem 全局可用

# 项目结构说明
# D:\AbyssBreak\
# ├── project.godot              ← Godot项目配置
# ├── scenes/
# │   ├── world/
# │   │   ├── main.tscn          ← 主游戏场景（含GameManager/WaveManager/Player/HUD）
# │   │   ├── World.gd           ← 地图/背景脚本
# │   │   └── ExperienceGem.tscn ← 经验宝石场景
# │   ├── player/
# │   │   └── Player.tscn        ← 玩家场景
# │   ├── enemies/
# │   │   ├── EnemyBasic.tscn    ← 基础小怪
# │   │   ├── EnemyExplode.tscn  ← 爆炸怪
# │   │   └── EnemyRanged.tscn   ← 远程怪
# │   ├── skills/
# │   │   ├── Projectile.tscn    ← 投射物通用场景
# │   │   ├── SkillFireball.tscn ← 火焰术场景
# │   │   └── SkillOrbital.tscn  ← 绕身旋转场景
# │   └── ui/
# │       └── HUD.tscn           ← 游戏内UI
# ├── scripts/                   ← 所有GDScript
# ├── resources/
# │   ├── skills/
# │   │   ├── fireball.tres      ← 火焰术数据
# │   │   └── orbital.tres       ← 护盾数据
# │   ├── enemies/
# │   │   ├── basic.tres         ← 基础小怪数据
# │   │   └── explode.tres       ← 爆炸怪数据
# │   └── items/
# │       ├── passive_speed.tres ← 移速被动数据
# │       └── passive_dmg.tres   ← 攻击力被动数据
# └── assets/
#     ├── sprites/               ← 精灵图（后期加）
#     ├── sfx/                   ← 音效
#     └── music/                 ← 背景音乐
