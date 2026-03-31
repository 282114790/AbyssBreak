# ObjectPool.gd
# 对象池（#31）— 投射物/粒子/伤害数字复用，减少GC压力
# 用法：
#   ObjectPool.get("DamageNumber", preload("res://scripts/ui/DamageNumber.gd"))
#   ObjectPool.release(node)
extends Node

const POOL_MAX := 64  # 每类最多缓存数量

var _pools: Dictionary = {}  # class_name -> Array[Node]
var _node_class: Dictionary = {}  # node instance_id -> class_key

func _ready() -> void:
	name = "ObjectPool"

# 取出一个对象（优先从池中复用，否则新建）
func get_obj(class_key: String, scene_or_script) -> Node:
	if not _pools.has(class_key):
		_pools[class_key] = []
	var pool: Array = _pools[class_key]
	var node: Node
	if pool.is_empty():
		node = Node2D.new() if scene_or_script is GDScript else scene_or_script.instantiate()
		if scene_or_script is GDScript:
			node.set_script(scene_or_script)
	else:
		node = pool.pop_back()
	_node_class[node.get_instance_id()] = class_key
	node.set_meta("_pooled", false)
	return node

# 归还对象到池（调用前先从场景树移除）
func release(node: Node) -> void:
	if not is_instance_valid(node): return
	if node.get_meta("_pooled", false): return  # 已归还过
	var iid = node.get_instance_id()
	var class_key = _node_class.get(iid, "")
	if class_key == "":
		node.queue_free()
		return
	var pool: Array = _pools.get(class_key, [])
	if pool.size() >= POOL_MAX:
		node.queue_free()
		_node_class.erase(iid)
		return
	node.set_meta("_pooled", true)
	if node.get_parent():
		node.get_parent().remove_child(node)
	# 重置常用属性
	if node.has_method("reset_for_pool"):
		node.reset_for_pool()
	else:
		node.visible = false
		if node is Node2D:
			node.position = Vector2.ZERO
			node.rotation = 0.0
			node.scale = Vector2.ONE
	pool.append(node)
	_node_class[iid] = class_key

# 预热：提前创建N个对象放入池
func prewarm(class_key: String, scene_or_script, count: int) -> void:
	for i in range(count):
		var node = get_obj(class_key, scene_or_script)
		release(node)

# 清空某类对象池
func clear_pool(class_key: String) -> void:
	if _pools.has(class_key):
		for n in _pools[class_key]:
			if is_instance_valid(n): n.queue_free()
		_pools[class_key] = []
