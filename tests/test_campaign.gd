extends SceneTree
## Campaign regression suite: every mission is SQL Injection focused.

var failures := 0
var checks := 0
const Campaign = preload("res://scripts/missions/campaign.gd")
const Blocks = preload("res://scripts/missions/code_blocks.gd")

func _init() -> void:
	call_deferred("_run")

func check(value: bool, label: String) -> void:
	checks += 1
	if value:
		print("OK · ", label)
	else:
		failures += 1
		push_error("FAIL · " + label)

func _run() -> void:
	var campaign := Campaign.new()
	check(campaign.missions.size() == 5, "La campaña contiene exactamente cinco misiones")
	for kind in ["login", "search", "order", "blind", "final"]:
		var safe: Array = Blocks.REQUIRED[kind].duplicate()
		check(Blocks.evaluate(kind, safe, campaign.db).ok, "Los bloques seguros pasan la simulación de " + kind)
		var unsafe: Array = safe.duplicate()
		unsafe.append("unsafe_login")
		check(not Blocks.evaluate(kind, unsafe, campaign.db).ok, "Los bloques inseguros se rechazan en " + kind)
	check(campaign.missions.all(func(mission): return mission.get("kind", "") in ["login", "search", "order", "blind", "final"]), "Todas las misiones enseñan SQL Injection")
	check(not str(campaign.mission().objective).to_lower().contains("localiza únicamente"), "La primera misión no es una actividad SQL básica")

	var login := campaign.submit("login", "admin' --", "x")
	check(login.get("attack", false) and campaign.evidence.has("attack"), "Login: admin' -- demuestra el bypass aislado")
	check(campaign.submit("login", "admin' --", "x").rows.size() > 0, "Login: el impacto muestra una sesión simulada")
	check(campaign.test_patches(campaign._default_patch("login")).size() >= 4 and campaign.evidence.has("defense"), "Login: la defensa parametrizada supera la regresión")
	check(campaign.complete() and campaign.current == 1, "Login completa y desbloquea la misión 2")

	var union := campaign.submit("search", "' UNION SELECT id, secret, 0 FROM vault --")
	check(union.get("attack", false) and union.get("message", "").contains("UNION"), "Búsqueda: UNION expone el vault sintético")
	check(campaign.test_patches(campaign._default_patch("search")).size() >= 4 and campaign.evidence.has("defense"), "Búsqueda: LIKE parametrizado supera la regresión")
	check(campaign.complete() and campaign.current == 2, "Búsqueda completa y desbloquea la misión 3")

	var order := campaign.submit("order", "CASE WHEN budget > 0 THEN name END")
	check(order.get("attack", false), "ORDER BY: CASE WHEN altera la estructura simulada")
	check(campaign.test_patches(campaign._default_patch("order")).size() >= 4 and campaign.evidence.has("defense"), "ORDER BY: la lista blanca supera la regresión")
	check(campaign.complete() and campaign.current == 3, "ORDER BY completa y desbloquea la misión 4")

	var blind := campaign.submit("blind", "contenido LIKE 'AURORA%'")
	check(blind.get("attack", false) and blind.rows.is_empty() and blind.get("signal", false), "Blind: la señal positiva no revela filas")
	check(campaign.test_patches(campaign._default_patch("blind")).size() >= 4 and campaign.evidence.has("defense"), "Blind: parámetros y autorización superan la regresión")
	check(campaign.complete() and campaign.current == 4, "Blind completa y desbloquea el incidente final")

	var final_attack := campaign.submit_final("admin' --", "' UNION SELECT id, secret, 0 FROM vault --", "CASE WHEN budget > 0 THEN name END")
	check(final_attack.get("attack", false), "Final: NullSec combina bypass, UNION y ORDER BY")
	check(campaign.test_patches(campaign._default_patch("final")).size() >= 4 and campaign.evidence.has("defense"), "Final: la defensa integral supera la regresión")
	var report := "Evidencia: reproduje el bypass de login, la exposición UNION y la expresión no autorizada de ORDER BY en el laboratorio.\nCausa: la aplicación concatenaba datos de usuario dentro de la estructura SQL sin separar valores ni validar identificadores.\nCorrección: parametrizar valores, poner comodines dentro del parámetro, aplicar lista blanca y comprobar autorización."
	check(campaign.save_report(report) and campaign.evidence.has("report"), "Final: el reporte documenta evidencia, causa y corrección")
	check(campaign.complete() and campaign.current == 5 and campaign.completed.size() == 5, "La campaña completa los cinco incidentes")
	check(campaign.xp > 1400, "Las recompensas y evidencias otorgan progresión")

	print("Campaign SQL Injection: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
