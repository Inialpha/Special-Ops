extends Node3D
class_name ImpactEffect

## Short-lived, self-freeing bullet-impact spark. Kept intentionally
## cheap (one mesh, one light, one tween) so it is safe to spawn on
## every hit on mobile hardware without becoming a particle-count
## problem.

@onready var spark: MeshInstance3D = $Spark
@onready var light: OmniLight3D = $Light

func _ready() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(spark, "scale", Vector3.ZERO, 0.16).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(light, "light_energy", 0.0, 0.1)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
