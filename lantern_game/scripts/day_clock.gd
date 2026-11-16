extends RefCounted
# gdlint: disable=max-returns
## Simulation time advances only during play; never tied to shader TIME or wall time.
const HOURS = [0.0, 4.0, 5.5, 7.5, 11.0, 15.0, 18.0, 19.5, 21.0, 24.0]
const TINTS = [
	Color("485979"),
	Color("4c5c7b"),
	Color("9c8496"),
	Color("f4d9ae"),
	Color("ffffff"),
	Color("fff4dd"),
	Color("dba18a"),
	Color("80728f"),
	Color("485979"),
	Color("485979")
]
const START_HOUR := 6.25
var hour := START_HOUR
var day := 1
var cycle_minutes := 24.0
var enabled := true


func advance(delta: float) -> void:
	if not enabled:
		return
	var total := hour + maxf(delta, 0.0) * 24.0 / (cycle_minutes * 60.0)
	day += int(floor(total / 24.0))
	hour = fposmod(total, 24.0)


func tint() -> Color:
	for i in range(HOURS.size() - 1):
		if hour <= HOURS[i + 1]:
			var t := clampf((hour - HOURS[i]) / (HOURS[i + 1] - HOURS[i]), 0, 1)
			var fraction := t * t * t * (t * (t * 6.0 - 15.0) + 10.0)
			return TINTS[i].lerp(TINTS[i + 1], fraction)
	return TINTS[0]


func darkness() -> float:
	return 1.0 - smoothstep(0.42, 0.93, tint().v)


func period() -> String:
	if hour < 4.0 or hour >= 22.0:
		return "Ночь"
	if hour < 6.0:
		return "Предрассветье"
	if hour < 8.0:
		return "Рассвет"
	if hour < 11.0:
		return "Утро"
	if hour < 17.0:
		return "День"
	if hour < 19.0:
		return "Вечер"
	return "Сумерки"


func display_time() -> String:
	var minutes := int(hour * 60.0) % 1440
	return "%02d:%02d" % [int(floor(float(minutes) / 60.0)), minutes % 60]


## Equinox-style inclined great-circle orbit; not a claim of location-specific ephemerides.
## Softened cotangent bounds grazing-angle shadows without a hard length clamp.
func celestial() -> Dictionary:
	var max_slope := 2.2
	var legacy_length := Vector2(0.85, 0.48).length()
	var peak := atan(sqrt(1.0 - pow(legacy_length / max_slope, 2)) / legacy_length)
	var angle := (hour - 6.0) * TAU / 24.0
	var phase := TAU * (float(day - 1) + hour / 24.0) / 29.53059
	var lunar_angle := angle + PI - phase
	var solar_height := sin(angle) * sin(peak)
	var lunar_peak := peak + deg_to_rad(5.14) * sin(phase)
	var lunar_height := sin(lunar_angle) * sin(lunar_peak)
	var rotation := -atan2(0.85, 0.48)
	var sun_planar := Vector2(-cos(angle), sin(angle) * cos(peak)).rotated(rotation)
	var moon_planar := Vector2(-cos(lunar_angle), sin(lunar_angle) * cos(lunar_peak)).rotated(
		rotation
	)
	var sun_slope := (
		sun_planar
		/ sqrt(solar_height * solar_height + sun_planar.length_squared() / (max_slope * max_slope))
	)
	var moon_slope := (
		moon_planar
		/ sqrt(lunar_height * lunar_height + moon_planar.length_squared() / (max_slope * max_slope))
	)
	var sun_power := 0.38 * smoothstep(0.0, 0.16, solar_height)
	var moon_power := 0.055 * smoothstep(0.0, 0.16, lunar_height) * (0.5 + 0.5 * cos(phase))
	var total := sun_power + moon_power
	# Smooth weighted transition even when both light sources touch the horizon.
	var direction := (
		(sun_slope * sun_power + moon_slope * moon_power) / sqrt(total * total + 0.00000001)
	)
	return {
		"slope": direction,
		"opacity": total,
		"softness": (1.0 - smoothstep(0.06, 0.18, total)) * smoothstep(0.0, 0.01, total),
		"sun_altitude": asin(solar_height),
		"moon_altitude": asin(lunar_height),
		"sun_angle": angle,
		"moon_angle": lunar_angle,
		"moon_illumination": 0.5 + 0.5 * cos(phase)
	}
