extends SceneTree
## Render the real game into a fixed viewport, independent of a tiling WM.
var viewport: SubViewport
func _init() -> void: call_deferred("_run")
func shot(name: String) -> void:
    await process_frame
    await RenderingServer.frame_post_draw
    viewport.get_texture().get_image().save_png("res://tests/" + name + ".png")
func _run() -> void:
    viewport = SubViewport.new()
    viewport.size = Vector2i(1152, 720)
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    var scene = load("res://scenes/main.tscn").instantiate()
    viewport.add_child(scene)
    await create_timer(0.3).timeout
    await shot("preview_menu")
    scene._new_game()
    await shot("preview_dialogue")
    scene._close_overlay()
    await create_timer(0.3).timeout
    await shot("preview_world")
    scene.hero.position = Vector2(17.5, 8.5) * 32
    scene._interact()
    scene.lab.query_input.text = "SELECT id, nombre FROM estudiantes WHERE carrera = 'Sistemas';"
    scene.lab._run("query", scene.lab.query_input.text)
    await shot("preview_lab")
    scene.lab._run("query", "SELECT * FROM estudiantes WHERE nombre='Nova'")
    scene.campaign.complete()
    await shot("preview_reward")
    scene._close_overlay()
    scene.campaign.current = 5
    scene.campaign.evidence.clear()
    scene.lab.open_lab()
    scene.lab.login_edit.text = "SELECT * FROM usuarios WHERE usuario = ? AND clave = ?"
    scene.lab.document_edit.text = "SELECT id, titulo, contenido FROM documentos WHERE id = ? AND owner_id = ?"
    scene.lab._test_patch()
    await shot("preview_repair")
    # Physical 960x600 with the same logical 1152x720 canvas.
    viewport.size = Vector2i(960, 600)
    viewport.size_2d_override = Vector2i(1152, 720)
    viewport.size_2d_override_stretch = true
    await create_timer(0.3).timeout
    await shot("preview_small")
    scene.queue_free()
    await process_frame
    viewport.queue_free()
    await process_frame
    quit()
