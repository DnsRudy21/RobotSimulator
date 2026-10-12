extends Node3D
var controller: Node
var pivots: Array[Node3D] = []
var readings: Array[Label] = []
var part_mesh: MeshInstance3D
var source_station: MeshInstance3D
var destination_station: MeshInstance3D
var obstacle_mesh: MeshInstance3D
var fingers: Array[MeshInstance3D] = []
var belt_marks: Array[MeshInstance3D] = []
var sensor_mesh: MeshInstance3D
var tcp_marker: MeshInstance3D

func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.65
	result.metallic = 0.25
	return result

func box(parent: Node3D, size: Vector3, offset: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material(color)
	mesh.position = offset
	parent.add_child(mesh)
	return mesh

func joint(parent: Node3D, index: int) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "J%d" % (index + 1)
	pivot.position = controller.JointOrigin(index)
	parent.add_child(pivot)
	pivots.append(pivot)
	var housing := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.095 if index < 3 else 0.065
	sphere.height = sphere.radius * 2
	housing.mesh = sphere
	housing.material_override = material(Color("263746"))
	pivot.add_child(housing)
	return pivot

func setup(bridge: Node) -> void:
	controller = bridge
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("101c29")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c7def0")
	environment.environment.ambient_light_energy = 0.65
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	light.light_energy = 1.4
	light.shadow_enabled = true
	add_child(light)
	box(self, Vector3(8, 0.08, 8), Vector3(0, -0.04, 0), Color("273443"))
	for i in range(-4,5):
		box(self, Vector3(0.008,0.003,8), Vector3(i,0.002,0), Color("405061"))
		box(self, Vector3(8,0.003,0.008), Vector3(0,0.002,i), Color("405061"))
	box(self, Vector3(0.7,0.12,0.7), Vector3(0,0.06,0), Color("172634"))
	box(self, Vector3(0.32,0.28,0.32), Vector3(0,0.26,0), Color("4c6375"))
	var orange := Color("f3a43b")
	var j1 := joint(self,0)
	var j2_origin: Vector3 = controller.JointOrigin(1)
	box(j1,Vector3(0.26,j2_origin.length(),0.24),j2_origin/2,orange)
	var j2 := joint(j1,1)
	var j3_origin: Vector3 = controller.JointOrigin(2)
	box(j2,Vector3(0.17,j3_origin.length(),0.19),j3_origin/2,orange)
	var j3 := joint(j2,2)
	var j4_origin: Vector3 = controller.JointOrigin(3)
	box(j3,Vector3(j4_origin.length(),0.15,0.16),j4_origin/2,orange)
	var j4 := joint(j3,3)
	var j5_origin: Vector3 = controller.JointOrigin(4)
	box(j4,Vector3(j5_origin.length(),0.10,0.10),j5_origin/2,Color("d7e1e6"))
	var j5 := joint(j4,4)
	var j6_origin: Vector3 = controller.JointOrigin(5)
	box(j5,Vector3(j6_origin.length(),0.08,0.08),j6_origin/2,orange)
	var j6 := joint(j5,5)
	box(j6,Vector3(0.07,0.12,0.12),Vector3(0.035,0,0),Color("d7e1e6"))
	box(j6,Vector3(0.08,0.025,0.025),Vector3(0.04,0.07,0),orange)
	box(j4,Vector3(0.10,0.025,0.025),Vector3(0.05,0.07,0),Color("111e29"))
	box(j6,Vector3(0.08,0.10,0.09),Vector3(0.09,0,0),Color("4c6375"))
	for side in [-1,1]: fingers.append(box(j6,Vector3(0.07,0.018,0.018),Vector3(0.14,side*0.045,0),Color("d7e1e6")))
	part_mesh = box(self,Vector3(0.05,0.05,0.05),controller.PartPosition(),Color("43dac5"))
	source_station = box(self,Vector3(0.22,0.2,0.44),Vector3.ZERO,Color("45596b"))
	for i in range(5): belt_marks.append(box(self,Vector3(0.19,0.006,0.006),Vector3.ZERO,Color("7e95a5")))
	sensor_mesh = box(self,Vector3(0.02,0.02,0.03),Vector3.ZERO,Color("f3a43b"))
	tcp_marker = box(self,Vector3(0.012,0.012,0.012),controller.TcpPosition(),Color("2ae7ff"))
	destination_station = box(self,Vector3(0.22,0.2,0.22),Vector3.ZERO,Color("326f68"))
	obstacle_mesh = box(self,Vector3(0.20,0.20,0.20),controller.ObstaclePosition(),Color("d96552"))
func _process(_delta: float) -> void:
	for i in range(6):
		var angle: float = controller.Angle(i)
		pivots[i].basis = Basis(controller.JointAxis(i),angle)
		if i < readings.size(): readings[i].text = "J%d   %7.2f     [%d, %d]" % [i+1,rad_to_deg(angle),roundi(rad_to_deg(controller.LowerLimit(i))),roundi(rad_to_deg(controller.UpperLimit(i)))]
	part_mesh.visible = controller.PartExists()
	part_mesh.position = controller.PartPosition()
	part_mesh.basis = controller.PartBasis()
	tcp_marker.position = controller.TcpPosition()
	for i in range(belt_marks.size()):
		var source: Vector3 = controller.SourcePosition()
		belt_marks[i].position = source + Vector3(0,-0.042,-0.21+fposmod(i*0.085-controller.BeltTravel(),0.425))
	sensor_mesh.position = controller.SourcePosition() + Vector3(-0.13,0,0)
	sensor_mesh.material_override.albedo_color = Color("43dac5") if controller.Signal("present") else Color("d96552")
	for station in [source_station,destination_station]:
		var point: Vector3 = controller.SourcePosition() if station == source_station else controller.DestinationPosition()
		station.mesh.size.y = maxf(0.01,point.y-0.045)
		station.position = Vector3(point.x,station.mesh.size.y/2,point.z)
	obstacle_mesh.position = controller.ObstaclePosition()
	obstacle_mesh.mesh.size = controller.ObstacleSize()
	obstacle_mesh.visible = controller.ObstacleEnabled()
	for i in range(fingers.size()): fingers[i].position.y = (1 if i == 1 else -1)*(0.022 if controller.Signal("grip") else 0.045)
