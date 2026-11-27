extends Reference

# Aura des armes Pack-a-Punchees : on reprend les particules "techno" des
# ennemis meca du jeu, recolorees en cyan, attachees au sprite de l'arme.

const SOURCE_SCENE = "res://effect_behaviors/enemies/meca_enemy_effect_behavior.tscn"
const AURA_NAME = "TinkiluzPapAura"

static func add_to(weapon: Node) -> void:
	if weapon == null or not is_instance_valid(weapon) or weapon.sprite == null:
		return
	if weapon.sprite.has_node(AURA_NAME):
		return

	var source_scene: PackedScene = load(SOURCE_SCENE)
	if source_scene == null:
		return
	var source = source_scene.instance()
	var particles = source.get_node_or_null("CurseParticles")
	if particles == null:
		source.free()
		return
	source.remove_child(particles)
	source.free()

	particles.name = AURA_NAME
	particles.owner = null
	particles.amount = 4
	particles.emission_sphere_radius = 14.0
	# Coordonnees locales : les particules suivent l'arme quand le joueur bouge
	particles.local_coords = true
	var sparks_node = particles.get_node_or_null("CPUParticles2D")
	if sparks_node != null:
		sparks_node.local_coords = true
	particles.color = Color(1, 1, 1, 0.55)

	var ramp: = Gradient.new()
	ramp.offsets = PoolRealArray([0.0, 0.35, 0.6, 1.0])
	ramp.colors = PoolColorArray([
		Color(0.3, 1.0, 1.0, 0.0),
		Color(0.55, 1.0, 1.0, 1.0),
		Color(0.0, 0.85, 1.0, 1.0),
		Color(0.0, 0.45, 0.8, 0.0),
	])
	particles.color_ramp = ramp

	# Petites etincelles (enfant de la scene d'origine)
	var sparks = particles.get_node_or_null("CPUParticles2D")
	if sparks != null:
		sparks.owner = null
		var sparks_ramp: = Gradient.new()
		sparks_ramp.offsets = PoolRealArray([0.0, 0.35, 1.0])
		sparks_ramp.colors = PoolColorArray([
			Color(1, 1, 1, 0),
			Color(0.4, 1.0, 1.0, 1),
			Color(0.0, 0.6, 1.0, 0),
		])
		sparks.color_initial_ramp = sparks_ramp

	weapon.sprite.add_child(particles)
