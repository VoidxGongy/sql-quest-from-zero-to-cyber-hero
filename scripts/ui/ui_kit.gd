class_name QuestUI
extends RefCounted
const TEXT := Color("e2edf0")
const MUTED := Color("a2b6c8")
const GREEN := Color("94e1b0")
const PANEL := Color("111e30")

static func theme() -> Theme:
    var t := Theme.new()
    t.default_font_size = 16
    for type in ["Label", "Button", "CheckButton", "LineEdit", "TextEdit", "TabContainer", "Tree", "RichTextLabel"]:
        t.set_color("font_color", type, TEXT)
    for type in ["Button", "LineEdit", "TextEdit"]:
        t.set_stylebox("normal", type, style(Color("1f3249"), Color("3e566c")))
        t.set_stylebox("focus", type, style(Color(0, 0, 0, 0), GREEN, 2))
    t.set_stylebox("hover", "Button", style(Color("324b60"), GREEN))
    t.set_stylebox("pressed", "Button", style(Color("3d655e"), GREEN))
    t.set_stylebox("disabled", "Button", style(Color("1b2738"), Color("344052")))
    t.set_color("font_disabled_color", "Button", Color("8b9baa"))
    t.set_stylebox("panel", "PanelContainer", style(PANEL, Color("3c5369")))
    t.set_stylebox("panel", "TabContainer", style(PANEL, Color("3c5369")))
    t.set_stylebox("tab_selected", "TabContainer", style(Color("365b57"), GREEN))
    t.set_stylebox("tab_unselected", "TabContainer", style(Color("21324b"), Color("3e566c")))
    t.set_color("font_placeholder_color", "LineEdit", MUTED)
    t.set_color("font_placeholder_color", "TextEdit", MUTED)
    t.set_color("caret_color", "TextEdit", GREEN)
    return t

static func style(color: Color, border: Color, width: int = 1) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = color
    s.border_color = border
    s.set_border_width_all(width)
    s.set_corner_radius_all(6)
    s.content_margin_left = 12
    s.content_margin_right = 12
    s.content_margin_top = 8
    s.content_margin_bottom = 8
    return s

static func texture_style(texture: Texture2D, margin: int = 18, draw_center: bool = true) -> StyleBoxTexture:
    var s := StyleBoxTexture.new()
    s.texture = texture
    s.draw_center = draw_center
    s.texture_margin_left = margin
    s.texture_margin_right = margin
    s.texture_margin_top = margin
    s.texture_margin_bottom = margin
    s.content_margin_left = margin
    s.content_margin_right = margin
    s.content_margin_top = margin
    s.content_margin_bottom = margin
    return s

static func label(parent: Node, text: String, font_size: int = 16, color: Color = TEXT) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", font_size)
    l.add_theme_color_override("font_color", color)
    parent.add_child(l)
    return l

static func paragraph(parent: Node, text: String, font_size: int = 16) -> Label:
    var l := label(parent, text, font_size)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    return l

static func button(parent: Node, text: String, callback: Callable) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size.y = 38
    b.pressed.connect(callback)
    parent.add_child(b)
    return b

static func editor(parent: Node, height: int = 100) -> CodeEdit:
    var e := CodeEdit.new()
    e.custom_minimum_size.y = height
    e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    e.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
    e.caret_blink = true
    e.add_theme_font_override("font", preload("res://assets/fonts/DejaVuSansMono.ttf"))
    var highlight := CodeHighlighter.new()
    for word in ["SELECT", "FROM", "WHERE", "AND", "OR", "UNION", "INSERT", "INTO", "VALUES", "UPDATE", "SET", "LIKE", "ORDER", "BY", "LIMIT"]:
        highlight.add_keyword_color(word, Color("9ce6bc"))
    highlight.add_color_region("'", "'", Color("ebc589"))
    highlight.add_color_region("--", "", MUTED, true)
    e.syntax_highlighter = highlight
    parent.add_child(e)
    return e

static func scroll_page(tabs: TabContainer, title: String) -> VBoxContainer:
    var scroll := ScrollContainer.new()
    scroll.name = title
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    tabs.add_child(scroll)
    var box := VBoxContainer.new()
    box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    box.add_theme_constant_override("separation", 10)
    scroll.add_child(box)
    return box
