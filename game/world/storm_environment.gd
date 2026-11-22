class_name StormEnvironment
extends WorldEnvironment
## Stil B: dark storm night, moonlight, volumetric fog that bright lights (the beam) light up.

const FOG_COLOR := Color("#0b1220")

var moon: DirectionalLight3D
var fill: DirectionalLight3D
var base_ambient: float = 0.7


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = FOG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#33476a")
	env.ambient_light_energy = base_ambient
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.fog_enabled = true
	env.fog_light_color = FOG_COLOR
	env.fog_density = 0.006
	env.fog_sky_affect = 0.0
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color("#2a3a55")
	env.volumetric_fog_emission = Color("#05080f")
	env.volumetric_fog_length = 160.0
	env.volumetric_fog_gi_inject = 0.0
	environment = env

	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color("#9fb8ff")
	moon.light_energy = 0.65
	moon.light_volumetric_fog_energy = 0.3
	moon.light_specular = 0.3
	moon.rotation_degrees = Vector3(-50.0, 155.0, 0.0)
	moon.shadow_enabled = true
	add_child(moon)

	# Cool key/fill from the camera side so hull facets read against the dark sea.
	fill = DirectionalLight3D.new()
	fill.name = "Fill"
	fill.light_color = Color("#8fa6d8")
	fill.light_energy = 0.8
	fill.light_specular = 0.25
	fill.light_volumetric_fog_energy = 0.0
	fill.rotation_degrees = Vector3(-38.0, -35.0, 0.0)
	add_child(fill)


## Lightning flash: 0..1, called every frame by Weather.
func set_flash(amount: float) -> void:
	environment.ambient_light_energy = base_ambient + amount * 2.5
	environment.background_color = FOG_COLOR.lerp(Color("#5a6f92"), amount * 0.8)
	environment.fog_light_color = environment.background_color
