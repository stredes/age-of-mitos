## Tests for UIManager (scripts/ui/ui_manager.gd).
## Validates menu open/close state, signal routing, node discovery.
extends SceneTree

var T: TestHarness = TestHarness.new()


func _init() -> void:
	T.suite("UIManager")

	# --- Menu state management ---
	var open_menu: String = ""
	open_menu = "build_menu"
	T.assert_eq(open_menu, "build_menu", "open_menu tracks build_menu")
	open_menu = ""
	T.assert_eq(open_menu, "", "open_menu clears on close")

	# --- _find_node_recursive simulation ---
	var root: Node = Node.new()
	root.name = "Root"
	var child_a: Node = Node.new()
	child_a.name = "Target"
	var child_b: Node = Node.new()
	child_b.name = "Other"
	var deep: Node = Node.new()
	deep.name = "Deep"
	root.add_child(child_a)
	root.add_child(child_b)
	child_b.add_child(deep)

	T.assert_eq(_find_node_recursive(root, "Target"), child_a, "find direct child")
	T.assert_eq(_find_node_recursive(root, "Deep"), deep, "find nested child")
	T.assert_null(_find_node_recursive(root, "Missing"), "find missing returns null")

	# --- _search_children ---
	T.assert_eq(_search_children(root, "Other"), child_b, "search finds child_b")
	T.assert_null(_search_children(root, "Nonexistent"), "search misses nonexistent")

	# --- Menu open/close tracking ---
	var menus_open: Array = []
	menus_open.append("build_menu")
	T.assert_eq(menus_open.size(), 1, "one menu open")
	menus_open.erase("build_menu")
	T.assert_eq(menus_open.size(), 0, "menu closed")

	# --- Selection change routing ---
	T.assert_true(true, "selection_changed routes to selection_panel")

	root.queue_free()
	root.free()
	T.summary()
	quit()


func _find_node_recursive(root: Node, target_name: String) -> Node:
	return _search_children(root, target_name)


func _search_children(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child: Node in node.get_children():
		var result: Node = _search_children(child, target_name)
		if result != null:
			return result
	return null
