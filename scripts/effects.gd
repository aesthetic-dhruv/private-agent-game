extends Node
class_name DestructionEffects
## v0.3 feedback + performance cap.
## MAX_ACTIVE_EFFECTS is a strict cap on live effect nodes (particle
## bursts + flying debris + falling voxels registered by VoxelWorld).
## When a new effect would push the count over the cap, the oldest
## effects are freed immediately, before the new one is added. This is
## the safeguard for Android frame rates when a big explosion drops
## many voxels at once: old debris disappears faster instead of piling up.
## Particles are still one-shot GPUParticles3D, debris is 3 small cubes.

const USE_PARTICLES: bool = true
const MAX_ACTIVE_EFFECTS: int = 40

static var _active: Array[Node] = []

static func register_effect(node: Node) -> void:
	# Prune oldest first until we have room for this one.
	while _active.size() >= MAX_ACTIVE_EFFECTS:
		var oldest: Node = _active.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	_active.append(node)

static func unregister_effect(node: Node) -> void:
	_active.erase(node)

static func active_count() -> int:
	return _active.size()

static func spawn_burst(parent: Node3D, pos: Vector3, mat: Material) -> void:
	if USE_PARTICLES:
		var particles := GPUParticles3D.new()
		particles.position = pos
		particles.amount = 20
		particles.lifetime = 0.6
		particles.one_shot = true
		particles.emitting = true
		particles.draw_pass_1 = BoxMesh.new()
		var proc := ParticleProcessMaterial.new()
		proc.direction = Vector3(0, 1, 0)
		proc.spread = 45.0
		proc.initial_velocity_min = 2.0
		proc.initial_velocity_max = 5.0
		proc.gravity = Vector3(0, -9.8, 0)
		proc.scale_min = 0.15
		proc.scale_max = 0.35
		particles.process_material = proc
		parent.add_child(particles)
		register_effect(particles)
		var timer := parent.get_tree().create_timer(1.0)
		timer.timeout.connect(func(): unregister_effect(particles); if is_instance_valid(particles): particles.queue_free())
	for i in range(3):
		var body := RigidBody3D.new()
		body.position = pos
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.25, 0.25, 0.25)
		mesh.mesh = box
		mesh.material_override = mat
		body.add_child(mesh)
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(0.25, 0.25, 0.25)
		shape.shape = box_shape
		body.add_child(shape)
		parent.add_child(body)
		register_effect(body)
		body.linear_velocity = Vector3(
			randf_range(-3.0, 3.0), randf_range(2.0, 5.0), randf_range(-3.0, 3.0)
		)
		body.angular_velocity = Vector3(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0), 0)
		var t := parent.get_tree().create_timer(2.0)
		t.timeout.connect(func(): unregister_effect(body); if is_instance_valid(body): body.queue_free())
