class_name Chunk
extends Node3D
## One 50 m slice of the slope with its terrain, decor and gameplay objects.

var index := 0
var obstacles: Array[Obstacle] = []
var movers: Array[Obstacle] = []
var pickups: Array[Pickup] = []
var roads: Array[RoadCrossing] = []
var birds: Array[AmbientBird] = []


func tick(delta: float, observers := PackedVector3Array(), speeds := PackedFloat32Array()) -> void:
	for bird in birds:
		bird.tick(delta, observers, speeds)
	for mover in movers:
		mover.tick(delta)
	for road in roads:
		road.tick(delta)
	for pickup in pickups:
		pickup.tick(delta)
