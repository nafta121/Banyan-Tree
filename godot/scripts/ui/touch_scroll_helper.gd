class_name TouchScrollHelper
extends RefCounted

## Configures Godot 4 ScrollContainers and their descendant Controls for responsive
## Android one-handed touch scrolling without swallowing drag gestures or causing
## accidental button taps during vertical/horizontal swipes.

const _SSSGraphCanvas := preload("res://godot/scripts/ui/widgets/sss_graph_canvas.gd")
const MOBILE_SCROLL_DEADZONE := 8


static func configure_subtree(root: Node) -> void:
	if root == null or not is_instance_valid(root):
		return
	configure_node(root)
	for child in root.get_children():
		configure_subtree(child)


static func configure_node(node: Node) -> void:
	if node == null or not is_instance_valid(node) or not (node is Control):
		return

	# Never alter internal VScrollBar / HScrollBar managed by ScrollContainer itself.
	if node is ScrollBar:
		return

	# Never alter controls inside SSSGraphCanvas (which handles custom 2D pan & tap).
	if _is_inside_custom_pan_canvas(node):
		return

	if node is ScrollContainer:
		var sc := node as ScrollContainer
		sc.scroll_deadzone = maxi(sc.scroll_deadzone, MOBILE_SCROLL_DEADZONE)
		sc.mouse_filter = Control.MOUSE_FILTER_PASS
		return

	if not _is_inside_scroll_container(node):
		return

	var ctrl := node as Control

	# Horizontal sliders & text inputs keep MOUSE_FILTER_STOP for direct thumb/caret manipulation,
	# while disabling wheel-scroll value mutation on Sliders.
	if ctrl is Slider:
		(ctrl as Slider).scrollable = false
		return
	if ctrl is LineEdit or ctrl is TextEdit or ctrl is SpinBox:
		return

	# OptionButton defaults to ACTION_MODE_BUTTON_PRESS, which pops open its modal menu
	# on touch-down before any swipe can begin. Switching to ACTION_MODE_BUTTON_RELEASE + PASS
	# lets vertical swipes scroll cleanly while taps still open the menu on release.
	if ctrl is OptionButton:
		var ob := ctrl as OptionButton
		ob.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		if ob.mouse_filter == Control.MOUSE_FILTER_STOP:
			ob.mouse_filter = Control.MOUSE_FILTER_PASS
		return

	# Interactive buttons/checkboxes pass touch events up to ScrollContainer; once drag exceeds
	# MOBILE_SCROLL_DEADZONE (8px), ScrollContainer cancels the button press and scrolls smoothly.
	if ctrl is BaseButton:
		if ctrl.mouse_filter == Control.MOUSE_FILTER_STOP:
			ctrl.mouse_filter = Control.MOUSE_FILTER_PASS
		return

	# Non-scrolling RichTextLabels default to MOUSE_FILTER_STOP in Godot 4 and block touch drag.
	if ctrl is RichTextLabel:
		var rtl := ctrl as RichTextLabel
		if not rtl.scroll_active:
			rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		elif rtl.mouse_filter == Control.MOUSE_FILTER_STOP:
			rtl.mouse_filter = Control.MOUSE_FILTER_PASS
		return

	# Pure display/decorative nodes never handle pointer clicks inside ScrollContainers.
	if (
		ctrl is Label
		or ctrl is TextureRect
		or ctrl is ColorRect
		or ctrl is ProgressBar
		or ctrl is Separator
		or ctrl is Panel
	):
		ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return

	# Layout containers & card wrappers (PanelContainer, StatCardWidget, BoxContainer, etc.)
	# pass pointer/drag events up to their enclosing ScrollContainer.
	if ctrl.mouse_filter == Control.MOUSE_FILTER_STOP:
		ctrl.mouse_filter = Control.MOUSE_FILTER_PASS


static func _is_inside_scroll_container(node: Node) -> bool:
	var cur := node.get_parent()
	while cur != null:
		if cur is ScrollContainer:
			return true
		if cur is Window:
			return false
		cur = cur.get_parent()
	return false


static func _is_inside_custom_pan_canvas(node: Node) -> bool:
	var cur: Node = node
	while cur != null:
		if is_instance_of(cur, _SSSGraphCanvas):
			return true
		if cur is Window:
			return false
		cur = cur.get_parent()
	return false
