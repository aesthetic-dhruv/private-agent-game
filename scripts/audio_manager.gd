extends Node
class_name AudioManager
## Placeholder sounds, generated in code so the project runs with no audio
## files. Replace these with real .wav files later:
## - Put break.wav, explosion.wav, alarm.wav in res://audio/
## - In GameManager, replace audio.play_break() etc. with players that use
##   those streams. The call sites already exist, so the swap is one line each.
## Break: short filtered-noise burst. Explosion: longer, louder noise.
## Alarm: a repeating two-tone beep driven by a Timer in GameManager
## (alarm_tick()), not a looping stream, so it stops cleanly on win/lose.

var _sfx_player: AudioStreamPlayer = null
var _alarm_player: AudioStreamPlayer = null
var _break_stream: AudioStreamWAV = null
var _explosion_stream: AudioStreamWAV = null
var _alarm_stream: AudioStreamWAV = null

func _ready() -> void:
	_sfx_player = AudioStreamPlayer.new()
	add_child(_sfx_player)
	_alarm_player = AudioStreamPlayer.new()
	add_child(_alarm_player)
	_break_stream = _make_noise(0.15, 0.5)
	_explosion_stream = _make_noise(0.6, 0.9)
	_alarm_stream = _make_tone(880.0, 0.25)

func _make_noise(duration: float, volume: float) -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in range(count):
		var amp := int(randf_range(-1.0, 1.0) * 12000 * volume * (1.0 - float(i) / float(count)))
		data.encode_s16(i * 2, amp)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav

func _make_tone(freq: float, duration: float) -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in range(count):
		var t := float(i) / float(rate)
		var amp := int(sin(t * freq * 2.0 * PI) * 10000)
		data.encode_s16(i * 2, amp)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav

func play_break() -> void:
	if _sfx_player != null:
		_sfx_player.stream = _break_stream
		_sfx_player.play()

func play_explosion() -> void:
	if _sfx_player != null:
		_sfx_player.stream = _explosion_stream
		_sfx_player.play()

func alarm_tick() -> void:
	if _alarm_player != null:
		_alarm_player.stream = _alarm_stream
		_alarm_player.play()
