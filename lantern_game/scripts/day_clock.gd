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
var hour := 8.0
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
			var fraction := smoothstep(HOURS[i], HOURS[i + 1], hour)
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
