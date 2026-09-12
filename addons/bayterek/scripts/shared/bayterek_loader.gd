@tool
extends Node
## Autoload: BayterekLoader. Registry yükleme ve tree API'si.

const Bayterek = preload("res://addons/bayterek/scripts/shared/bayterek.gd")

var _registry: BayterekRegistry

func _init() -> void:
	_load_registry()

# --- Public API ---

func get_registry() -> BayterekRegistry:
	return _registry

func load_tree(path: String, as_unique: bool = false) -> BayterekTree:
	if not _registry:
		push_error("Bayterek: registry yüklü değil.")
		return null

	var lower: String = path.to_lower()
	for group: BayterekGroup in _registry.groups:
		for tree: BayterekTree in group.trees:
			var key: String = "%s/%s" % [group.name.to_lower(), tree.name.to_lower()]
			if key == lower:
				if as_unique:
					return tree.duplicate(true) as BayterekTree
				return tree

	push_error("Bayterek: '%s' yolu registry'de bulunamadı." % path)
	return null

func add_tree_to_registry(group: BayterekGroup, tree: BayterekTree) -> void:
	if not _registry:
		return
	if not _registry.groups.has(group):
		_registry.groups.append(group)
	if not group.trees.has(tree):
		group.trees.append(tree)

func reload_registry() -> void:
	_load_registry()

# --- Private ---

func _load_registry() -> void:
	var path: String = Bayterek.get_registry_path()

	if not ResourceLoader.exists(path):
		if OS.has_feature("editor"):
			_create_registry()
		else:
			push_error("Bayterek: registry dosyası yok: %s" % path)
			return

	_registry = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as BayterekRegistry
	if not _registry:
		push_error("Bayterek: registry yüklenemedi: %s" % path)

func _create_registry() -> void:
	var root: String = Bayterek.get_root_path()
	DirAccess.make_dir_recursive_absolute(root)

	_registry = BayterekRegistry.new()
	var err: Error = ResourceSaver.save(_registry, Bayterek.get_registry_path())
	if err != OK:
		push_error("Bayterek: registry oluşturulamadı (hata=%d)" % err)
	else:
		print("Bayterek: registry oluşturuldu: ", Bayterek.get_registry_path())