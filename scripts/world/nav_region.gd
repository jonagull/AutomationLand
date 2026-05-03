extends NavigationRegion2D

func _ready() -> void:
	var poly := NavigationPolygon.new()
	poly.add_outline(PackedVector2Array([
		Vector2(-600, -900),
		Vector2(900, -900),
		Vector2(900, 300),
		Vector2(-600, 300),
	]))
	poly.make_polygons_from_outlines()
	navigation_polygon = poly
