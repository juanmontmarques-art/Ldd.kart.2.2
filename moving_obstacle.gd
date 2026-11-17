class_name MovingObstacle
extends AnimatableBody3D

# Barreira que desliza de um lado para o outro da pista.

var axis := Vector3.RIGHT
var amplitude := 2.6
var speed := 1.5
var phase := 0.0
var _origin := Vector3.ZERO
var _t := 0.0


func _ready() -> void:
    sync_to_physics = true
    collision_layer = 1
    collision_mask = 0
    _origin = position


func _physics_process(delta: float) -> void:
    _t += delta
    position = _origin + axis * (sin(_t * speed + phase) * amplitude)
