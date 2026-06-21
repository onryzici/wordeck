extends RefCounted
# Kanca (hook) sistemi — src/engine/hooks.js portu. Jokerler SOLDAN SAĞA işlenir;
# patron köre EN SON iletilir. Çip/çarpan değiştiren kaynak _fired'a + (kelime
# skorlamasıysa) _timeline'a sıralı bir adım yazar.

static func fire_hook(source: Dictionary, hook: Callable, ctx, event_name: String) -> void:
	var op_start: int = ctx._ops.size()
	var c0: int = ctx.chips
	var m0: float = ctx.mult
	hook.call(ctx)
	var changed: bool = ctx.chips != c0 or ctx.mult != m0
	if not changed:
		return
	ctx._fired[source["id"]] = true
	if ctx._timeline != null and event_name == "onWordScored":
		ctx._timeline.append({
			"kind": "boss" if source.get("_boss", false) else "joker",
			"id": source["id"],
			"name": source.get("name", ""),
			"icon": source.get("icon", ""),
			"ops": ctx._ops.slice(op_start),
			"chips": ctx.chips,
			"mult": ctx.mult,
		})

static func run_hooks(state: Dictionary, event_name: String, ctx) -> void:
	for joker in state["run"]["jokers"]:
		var hooks: Dictionary = joker.get("hooks", {})
		if hooks.has(event_name):
			fire_hook(joker, hooks[event_name], ctx, event_name)
	var boss = state["round"].get("boss", null)
	if boss != null:
		var bhooks: Dictionary = boss.get("hooks", {})
		if bhooks.has(event_name):
			var src: Dictionary = boss.duplicate()
			src["_boss"] = true
			fire_hook(src, bhooks[event_name], ctx, event_name)
