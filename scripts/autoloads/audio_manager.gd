extends Node
## Central Audio Management Subsystem for BioSphere-X.
## Provides lightweight, procedural 16-bit PCM sound synthesis and ambient space audio.
## Ensures 100% self-contained operation without external file dependencies,
## synchronized with volume settings and Godot AudioServer buses.

signal sfx_played(sfx_name: String)
signal ambient_started(track_name: String)
signal ambient_stopped()

# Audio Bus Identifiers
const BUS_MASTER: String = "Master"

# Stream Caches
var _sfx_streams: Dictionary = {}
var _ambient_stream: AudioStreamWAV = null

# Audio Players
var _ambient_player: AudioStreamPlayer = null
var _sfx_players: Array[AudioStreamPlayer] = []
const MAX_CONCURRENT_SFX: int = 8

# Current Volumes (Linear 0.0 to 1.0)
var master_volume: float = 1.0
var sfx_volume: float = 0.8
var ambient_volume: float = 0.6


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_players()
	_synthesize_all_audio()
	_apply_initial_volumes()


func _setup_players() -> void:
	# Dedicated Ambient Music & Drone Player
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.name = "AmbientPlayer"
	_ambient_player.bus = BUS_MASTER
	add_child(_ambient_player)
	
	# SFX Voice Pool
	for i in MAX_CONCURRENT_SFX:
		var p := AudioStreamPlayer.new()
		p.name = "SFXPlayer_%d" % i
		p.bus = BUS_MASTER
		add_child(p)
		_sfx_players.append(p)


# ---------------------------------------------------------------------------
# Procedural Audio Synthesizer (16-bit PCM WAV)
# ---------------------------------------------------------------------------
func _synthesize_all_audio() -> void:
	_sfx_streams["laser_fire"] = _synth_laser_fire()
	_sfx_streams["laser_hit"] = _synth_laser_hit()
	_sfx_streams["player_hurt"] = _synth_player_hurt()
	_sfx_streams["enemy_death"] = _synth_enemy_death()
	_sfx_streams["pickup"] = _synth_pickup_chime()
	_sfx_streams["oxygen_warning"] = _synth_oxygen_warning()
	_sfx_streams["mission_complete"] = _synth_mission_complete()
	_sfx_streams["ui_click"] = _synth_ui_click()
	_sfx_streams["build"] = _synth_build_chime()
	_sfx_streams["demolish"] = _synth_demolish_tone()
	
	# Ambient Space Drone
	_ambient_stream = _synth_ambient_drone()


func _create_pcm_wav(sample_rate: int, samples: Array[float], is_looping: bool = false) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.mix_rate = sample_rate
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD if is_looping else AudioStreamWAV.LOOP_DISABLED
	
	var count := samples.size()
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	
	for i in count:
		var s: float = clampf(samples[i], -1.0, 1.0)
		var val: int = int(s * 32000.0)
		var u_val: int = val if val >= 0 else (65536 + val)
		bytes[i * 2] = u_val & 0xFF
		bytes[i * 2 + 1] = (u_val >> 8) & 0xFF
		
	wav.data = bytes
	return wav


func _synth_laser_fire() -> AudioStreamWAV:
	# Downward pitch sweep 950Hz -> 180Hz over 140ms with exponential decay
	var rate := 22050
	var dur := 0.14
	var count := int(rate * dur)
	var samples: Array[float] = []
	samples.resize(count)
	
	var phase := 0.0
	for i in count:
		var t := float(i) / float(rate)
		var progress := t / dur
		var freq := lerpf(950.0, 180.0, progress * progress)
		phase += freq * (1.0 / rate) * TAU
		var env := exp(-progress * 6.5)
		samples[i] = sin(phase) * env * 0.75
		
	return _create_pcm_wav(rate, samples)


func _synth_laser_hit() -> AudioStreamWAV:
	# Crisp noise burst blended with 120Hz sub-punch over 90ms
	var rate := 22050
	var dur := 0.09
	var count := int(rate * dur)
	var samples: Array[float] = []
	samples.resize(count)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	
	for i in count:
		var t := float(i) / float(rate)
		var progress := t / dur
		var env := exp(-progress * 8.0)
		var sub := sin(t * 120.0 * TAU) * 0.6
		var noise := rng.randf_range(-0.5, 0.5)
		samples[i] = (sub + noise) * env * 0.8
		
	return _create_pcm_wav(rate, samples)


func _synth_player_hurt() -> AudioStreamWAV:
	# Heavy low trauma impact: 85Hz thud + harsh noise transient over 180ms
	var rate := 22050
	var dur := 0.18
	var count := int(rate * dur)
	var samples: Array[float] = []
	samples.resize(count)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	
	for i in count:
		var t := float(i) / float(rate)
		var progress := t / dur
		var env := exp(-progress * 5.0)
		var thud := sin(t * 75.0 * TAU) * 0.85
		var crunch := rng.randf_range(-0.35, 0.35) * (1.0 - progress)
		samples[i] = (thud + crunch) * env * 0.9
		
	return _create_pcm_wav(rate, samples)


func _synth_enemy_death() -> AudioStreamWAV:
	# Descending alien dissipation screech 420Hz -> 60Hz with noise fade over 260ms
	var rate := 22050
	var dur := 0.26
	var count := int(rate * dur)
	var samples: Array[float] = []
	samples.resize(count)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 123
	var phase := 0.0
	for i in count:
		var t := float(i) / float(rate)
		var progress := t / dur
		var freq := lerpf(420.0, 60.0, progress)
		phase += freq * (1.0 / rate) * TAU
		var env := (1.0 - progress)
		var tone := sin(phase) * 0.5
		var hiss := rng.randf_range(-0.3, 0.3)
		samples[i] = (tone + hiss) * env * 0.7
		
	return _create_pcm_wav(rate, samples)


func _synth_pickup_chime() -> AudioStreamWAV:
	# Ascending 3-note crystal chime: C5 (523Hz), E5 (659Hz), G5 (784Hz)
	var rate := 22050
	var dur := 0.22
	var count := int(rate * dur)
	var samples: Array[float] = []
	samples.resize(count)
	
	var note_len := dur / 3.0
	for i in count:
		var t := float(i) / float(rate)
		var freq := 523.25
		var local_t := t
		if t >= note_len * 2.0:
			freq = 783.99
			local_t = t - note_len * 2.0
		elif t >= note_len:
			freq = 659.25
			local_t = t - note_len
			
		var note_env := exp(-local_t * 9.0)
		var main_sine := sin(t * freq * TAU)
		var harmonic := sin(t * freq * 2.0 * TAU) * 0.3
		samples[i] = (main_sine + harmonic) * note_env * 0.65
		
	return _create_pcm_wav(rate, samples)


func _synth_oxygen_warning() -> AudioStreamWAV:
	# Pulsed dual-tone alert beep (880Hz / 440Hz) over 320ms
	var rate := 22050
	var dur := 0.32
	var count := int(rate * dur)
	var samples: Array[float] = []
	samples.resize(count)
	
	for i in count:
		var t := float(i) / float(rate)
		var pulse := 1.0 if fmod(t, 0.16) < 0.10 else 0.0
		var tone1 := sin(t * 880.0 * TAU) * 0.6
		var tone2 := sin(t * 440.0 * TAU) * 0.4
		samples[i] = (tone1 + tone2) * pulse * 0.7
		
	return _create_pcm_wav(rate, samples)


func _synth_mission_complete() -> AudioStreamWAV:
	# Triumphant triad chord fanfare: 440Hz + 554.37Hz + 659.25Hz over 450ms
	var rate := 22050
	var dur := 0.45
	var count := int(rate * dur)
	var samples: Array[float] = []
	samples.resize(count)
	
	for i in count:
		var t := float(i) / float(rate)
		var progress := t / dur
		var env := exp(-progress * 3.5)
		var n1 := sin(t * 440.0 * TAU) * 0.4
		var n2 := sin(t * 554.37 * TAU) * 0.3
		var n3 := sin(t * 659.25 * TAU) * 0.3
		samples[i] = (n1 + n2 + n3) * env * 0.8
		
	return _create_pcm_wav(rate, samples)


func _synth_ui_click() -> AudioStreamWAV:
	# Clean, crisp 30ms mechanical click
	var rate := 22050
	var dur := 0.03
	var count := int(rate * dur)
	var samples: Array[float] = []
	samples.resize(count)
	
	for i in count:
		var t := float(i) / float(rate)
		var env := exp(-t * 90.0)
		samples[i] = sin(t * 1400.0 * TAU) * env * 0.5
		
	return _create_pcm_wav(rate, samples)


func _synth_build_chime() -> AudioStreamWAV:
	# Harmonic construction deployment sweep 220Hz -> 660Hz over 220ms
	var rate := 22050
	var dur := 0.22
	var count := int(rate * dur)
	var samples: Array[float] = []
	samples.resize(count)
	
	var phase := 0.0
	for i in count:
		var t := float(i) / float(rate)
		var progress := t / dur
		var freq := lerpf(220.0, 660.0, progress)
		phase += freq * (1.0 / rate) * TAU
		var env := exp(-progress * 4.0)
		samples[i] = sin(phase) * env * 0.6
		
	return _create_pcm_wav(rate, samples)


func _synth_demolish_tone() -> AudioStreamWAV:
	# Deconstruction recycle drop 350Hz -> 90Hz over 200ms
	var rate := 22050
	var dur := 0.20
	var count := int(rate * dur)
	var samples: Array[float] = []
	samples.resize(count)
	
	var phase := 0.0
	for i in count:
		var t := float(i) / float(rate)
		var progress := t / dur
		var freq := lerpf(350.0, 90.0, progress)
		phase += freq * (1.0 / rate) * TAU
		var env := exp(-progress * 5.0)
		samples[i] = sin(phase) * env * 0.65
		
	return _create_pcm_wav(rate, samples)


func _synth_ambient_drone() -> AudioStreamWAV:
	# Looping atmospheric space wind / reactor drone (2.5 seconds loop)
	var rate := 22050
	var dur := 2.5
	var count := int(rate * dur)
	var samples: Array[float] = []
	samples.resize(count)
	
	for i in count:
		var t := float(i) / float(rate)
		# 55Hz sub-bass tone
		var sub := sin(t * 55.0 * TAU) * 0.35
		# 110Hz warm 2nd harmonic with gentle breathing pulse
		var lfo := (sin(t * 0.8 * TAU) + 1.0) * 0.5
		var harm := sin(t * 110.0 * TAU) * 0.15 * lfo
		# Soft filtered low wind
		var wind := sin(t * 82.5 * TAU) * 0.12 * (1.0 - lfo * 0.5)
		samples[i] = (sub + harm + wind) * 0.5
		
	return _create_pcm_wav(rate, samples, true)


# ---------------------------------------------------------------------------
# Public Playback API
# ---------------------------------------------------------------------------
func play_sfx(sfx_name: String, pitch_scale: float = 1.0, volume_offset_db: float = 0.0) -> void:
	if not _sfx_streams.has(sfx_name) or sfx_volume <= 0.001 or master_volume <= 0.001:
		return
		
	# Find available player from pool
	var player: AudioStreamPlayer = null
	for p in _sfx_players:
		if not p.playing:
			player = p
			break
			
	if not player:
		player = _sfx_players[0] # Steal oldest
		
	player.stream = _sfx_streams[sfx_name]
	player.pitch_scale = clampf(pitch_scale, 0.5, 2.0)
	var total_vol: float = master_volume * sfx_volume
	player.volume_db = (linear_to_db(total_vol) if total_vol > 0.001 else -80.0) + volume_offset_db
	player.play()
	sfx_played.emit(sfx_name)


func play_ambient(track_name: String = "space_ambient") -> void:
	if not _ambient_player:
		return
	_ambient_player.stream = _ambient_stream
	_update_ambient_volume()
	if not _ambient_player.playing:
		_ambient_player.play()
	ambient_started.emit(track_name)


func stop_ambient() -> void:
	if _ambient_player and _ambient_player.playing:
		_ambient_player.stop()
		ambient_stopped.emit()


# ---------------------------------------------------------------------------
# Volume & Audio Bus Synchronization
# ---------------------------------------------------------------------------
func set_master_volume(linear: float) -> void:
	master_volume = clampf(linear, 0.0, 1.0)
	_apply_master_bus_volume()
	_update_ambient_volume()


func set_sfx_volume(linear: float) -> void:
	sfx_volume = clampf(linear, 0.0, 1.0)


func set_ambient_volume(linear: float) -> void:
	ambient_volume = clampf(linear, 0.0, 1.0)
	_update_ambient_volume()


func _update_ambient_volume() -> void:
	if _ambient_player:
		var effective: float = master_volume * ambient_volume
		_ambient_player.volume_db = linear_to_db(effective) if effective > 0.001 else -80.0


func _apply_master_bus_volume() -> void:
	if AudioServer.get_bus_count() > 0:
		var idx := AudioServer.get_bus_index(BUS_MASTER)
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, linear_to_db(master_volume) if master_volume > 0.001 else -80.0)


func _apply_initial_volumes() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	if sm and "current_settings" in sm:
		var cfg: Dictionary = sm.current_settings
		master_volume = float(cfg.get("master_volume", 1.0))
		sfx_volume = float(cfg.get("sfx_volume", 0.8))
		ambient_volume = float(cfg.get("ambient_volume", 0.6))
	_apply_master_bus_volume()
	_update_ambient_volume()
