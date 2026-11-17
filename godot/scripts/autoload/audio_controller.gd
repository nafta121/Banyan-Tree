extends Node

signal track_changed(track: MusicTrackData)

const GENRES := ["all", "national", "critique", "pop", "international"]
const SFX_POOL_SIZE := 4
const MAX_HISTORY_SIZE := 64
const SILENCE_DB := -80.0

var current_track_index: int = 0
var is_playing: bool = false
var active_genre: String = "all"
var weighted_shuffle: bool = false
var music_enabled: bool = true
var music_volume: float = 0.3
var sfx_enabled: bool = true
var sfx_volume: float = 0.8

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _music_player: AudioStreamPlayer = null
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cursor: int = 0
var _sfx_cache: Dictionary = {}
var _track_history: Array[int] = []
var _virtual_playback_pos: float = 0.0


static func _is_headless_dummy_audio() -> bool:
	return DisplayServer.get_name() == "headless" or AudioServer.get_driver_name() == "Dummy"


func _init() -> void:
	rng.randomize()


func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = &"Music"
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)

	for i in range(SFX_POOL_SIZE):
		var sp := AudioStreamPlayer.new()
		sp.name = "SFXPlayer_%d" % i
		sp.bus = &"SFX"
		add_child(sp)
		_sfx_players.append(sp)

	if DisplayServer.get_name() != "headless":
		_apply_bus_state("Music", music_enabled, music_volume)
		_apply_bus_state("SFX", sfx_enabled, sfx_volume)

	var ach := get_node_or_null("/root/AchievementService")
	if ach != null and ach.has_signal("achievement_unlocked"):
		var cb := Callable(self, "_on_achievement_unlocked")
		if not ach.is_connected("achievement_unlocked", cb):
			ach.connect("achievement_unlocked", cb)


func _on_achievement_unlocked(_ach_id: String) -> void:
	play_sfx("achievement")


func _get_music_tracks() -> Array[MusicTrackData]:
	var empty: Array[MusicTrackData] = []
	if ContentDB == null or ContentDB.catalog == null:
		return empty
	return ContentDB.catalog.music_tracks


func get_current_track() -> MusicTrackData:
	var tracks := _get_music_tracks()
	if tracks.is_empty():
		return null
	var idx := clampi(current_track_index, 0, tracks.size() - 1)
	return tracks[idx]


func get_genre_track_indices(genre: String = "") -> Array[int]:
	var target_genre := active_genre if genre.is_empty() else genre
	var tracks := _get_music_tracks()
	var indices: Array[int] = []
	for i in range(tracks.size()):
		if target_genre == "all" or tracks[i].genre == target_genre:
			indices.append(i)
	return indices


func _get_playable_genre_indices() -> Array[int]:
	var list := get_genre_track_indices(active_genre)
	if not list.is_empty():
		return list
	var all_list: Array[int] = []
	for i in range(_get_music_tracks().size()):
		all_list.append(i)
	return all_list


func _compute_current_quadrant_tag() -> String:
	var stab_val := 25
	var ref_val := 40
	var cm := get_node_or_null("/root/CampaignManager")
	if cm != null and "stats" in cm:
		var s: Variant = cm.get("stats")
		if s is Dictionary:
			stab_val = int((s as Dictionary).get("stab", 25))
			ref_val = int((s as Dictionary).get("ref", 40))
	var order_part := "highorder" if stab_val >= 50 else "loworder"
	var reform_part := "highreform" if ref_val >= 50 else "lowreform"
	return order_part + "_" + reform_part


func _pick_candidate_index(exclude_idx: int) -> int:
	var tracks := _get_music_tracks()
	if tracks.is_empty():
		return 0
	var genre_pool := _get_playable_genre_indices()
	if genre_pool.is_empty():
		return 0

	var pool: Array[int] = genre_pool
	if weighted_shuffle:
		var q_tag := _compute_current_quadrant_tag()
		var intersected: Array[int] = []
		for idx in genre_pool:
			if tracks[idx].weighted_tags.has(q_tag):
				intersected.append(idx)
		if not intersected.is_empty():
			pool = intersected

	if pool.size() == 1:
		return pool[0]

	var filtered: Array[int] = []
	for idx in pool:
		if idx != exclude_idx:
			filtered.append(idx)
	if filtered.is_empty():
		return pool[0]
	return filtered[rng.randi() % filtered.size()]


func play_track(index: int) -> bool:
	var tracks := _get_music_tracks()
	if tracks.is_empty() or _music_player == null:
		is_playing = false
		return false

	var total := tracks.size()
	var start_idx := ((index % total) + total) % total

	# Build bounded candidate sequence (<= total attempts): start_idx -> active_genre -> remaining tracks
	var ordered_candidates: Array[int] = [start_idx]
	var seen := {start_idx: true}

	var genre_pool := get_genre_track_indices(active_genre)
	if not genre_pool.is_empty():
		var pivot := genre_pool.find(start_idx)
		for offset in range(genre_pool.size()):
			var g_pos := (maxi(0, pivot) + offset) % genre_pool.size()
			var cand := genre_pool[g_pos]
			if not seen.has(cand):
				seen[cand] = true
				ordered_candidates.append(cand)

	for offset in range(1, total):
		var cand := (start_idx + offset) % total
		if not seen.has(cand):
			seen[cand] = true
			ordered_candidates.append(cand)

	var dummy_audio := _is_headless_dummy_audio()
	for cand_idx in ordered_candidates:
		var track_data := tracks[cand_idx]
		if track_data == null:
			continue
		var stream := _load_audio_stream_safe(track_data.file_path, true)
		if stream == null:
			continue
		if not dummy_audio:
			_music_player.stop()
		_music_player.stream = stream
		_music_player.stream_paused = false
		_virtual_playback_pos = 0.0
		current_track_index = cand_idx
		if music_enabled:
			if not dummy_audio:
				_music_player.play()
			is_playing = true
		else:
			is_playing = false
		track_changed.emit(track_data)
		return true

	if not dummy_audio:
		_music_player.stop()
	_music_player.stream = null
	_virtual_playback_pos = 0.0
	is_playing = false
	return false


func next_track() -> void:
	var tracks := _get_music_tracks()
	if tracks.is_empty():
		return
	_push_history(current_track_index)
	var next_idx := _pick_candidate_index(current_track_index)
	play_track(next_idx)


func prev_track() -> void:
	var tracks := _get_music_tracks()
	if tracks.is_empty():
		return
	if is_playing and get_playback_position() > 3.0:
		seek_to(0.0)
		return
	var prev_idx := _pick_candidate_index(current_track_index)
	if not _track_history.is_empty():
		prev_idx = int(_track_history.pop_back())
	play_track(prev_idx)


func toggle_play_pause() -> void:
	if _music_player == null:
		return
	var tracks := _get_music_tracks()
	if tracks.is_empty():
		return
	if not music_enabled:
		is_playing = false
		return
	if _music_player.stream == null:
		play_track(current_track_index)
		return
	var dummy_audio := _is_headless_dummy_audio()
	if is_playing:
		if not dummy_audio:
			_music_player.stream_paused = true
		is_playing = false
	else:
		if not dummy_audio:
			if _music_player.stream_paused:
				_music_player.stream_paused = false
			else:
				_music_player.play(_virtual_playback_pos)
		is_playing = true


func set_genre(genre: String) -> void:
	var clean := genre.strip_edges().to_lower()
	active_genre = clean if GENRES.has(clean) else "all"
	_sync_setting("active_genre", active_genre)


func set_weighted_shuffle(enabled: bool) -> void:
	weighted_shuffle = enabled
	_sync_setting("weighted_shuffle", weighted_shuffle)


func set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled
	_apply_bus_state("Music", music_enabled, music_volume)
	if not music_enabled and _music_player != null and is_playing:
		if not _is_headless_dummy_audio():
			_music_player.stream_paused = true
		is_playing = false
	_sync_setting("music_enabled", music_enabled)


func set_sfx_enabled(enabled: bool) -> void:
	sfx_enabled = enabled
	_apply_bus_state("SFX", sfx_enabled, sfx_volume)
	_sync_setting("sfx_enabled", sfx_enabled)


func set_music_volume(linear: float) -> void:
	music_volume = clampf(linear, 0.0, 1.0)
	_apply_bus_state("Music", music_enabled, music_volume)
	_sync_setting("music_volume", music_volume)


func set_sfx_volume(linear: float) -> void:
	sfx_volume = clampf(linear, 0.0, 1.0)
	_apply_bus_state("SFX", sfx_enabled, sfx_volume)
	_sync_setting("sfx_volume", sfx_volume)


func play_sfx(sfx_id: String) -> void:
	if not sfx_enabled or sfx_volume <= 0.0001 or _sfx_players.is_empty():
		return
	if ContentDB == null or ContentDB.catalog == null:
		return
	var sfx_path := String(ContentDB.catalog.sfx_paths.get(sfx_id, ""))
	if sfx_path.is_empty():
		return

	var stream: AudioStream = null
	if _sfx_cache.has(sfx_path):
		stream = _sfx_cache[sfx_path] as AudioStream
	else:
		stream = _load_audio_stream_safe(sfx_path, false)
		if stream != null:
			_sfx_cache[sfx_path] = stream
	if stream == null:
		return

	var player := _sfx_players[_sfx_cursor % _sfx_players.size()]
	_sfx_cursor = (_sfx_cursor + 1) % _sfx_players.size()
	if not _is_headless_dummy_audio():
		player.stop()
		player.stream = stream
		player.play()
	else:
		player.stream = stream


func seek_to(seconds: float) -> void:
	if _music_player == null or _music_player.stream == null:
		return
	var max_len := get_stream_length()
	var clamped := clampf(seconds, 0.0, maxf(0.0, max_len - 0.01)) if max_len > 0.0 else maxf(0.0, seconds)
	_virtual_playback_pos = clamped
	if _is_headless_dummy_audio():
		if music_enabled and not is_playing:
			is_playing = true
		return
	if not _music_player.playing and not _music_player.stream_paused and music_enabled:
		_music_player.play(clamped)
		is_playing = true
	else:
		_music_player.seek(clamped)


func get_playback_position() -> float:
	if _music_player == null or _music_player.stream == null:
		return 0.0
	if _is_headless_dummy_audio():
		return maxf(0.0, _virtual_playback_pos)
	return maxf(0.0, _music_player.get_playback_position())


func get_stream_length() -> float:
	if _music_player == null or _music_player.stream == null:
		return 0.0
	return maxf(0.0, _music_player.stream.get_length())


func _exit_tree() -> void:
	stop_all()


func stop_all() -> void:
	var dummy_audio := _is_headless_dummy_audio()
	if _music_player != null:
		if not dummy_audio:
			_music_player.stop()
		_music_player.stream_paused = false
		_music_player.stream = null
	for sp in _sfx_players:
		if sp != null:
			if not dummy_audio:
				sp.stop()
			sp.stream = null
	_sfx_cache.clear()
	_virtual_playback_pos = 0.0
	is_playing = false
	_track_history.clear()


func _on_music_finished() -> void:
	if not music_enabled:
		is_playing = false
		return
	var pool := _get_playable_genre_indices()
	if pool.size() == 1:
		play_track(pool[0])
	else:
		next_track()


func _push_history(idx: int) -> void:
	if idx < 0:
		return
	_track_history.append(idx)
	while _track_history.size() > MAX_HISTORY_SIZE:
		_track_history.pop_front()


func _apply_bus_state(bus_name: String, enabled: bool, linear: float) -> void:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx < 0:
		return
	var clamped := clampf(linear, 0.0, 1.0)
	if not enabled or clamped <= 0.0001:
		AudioServer.set_bus_mute(bus_idx, true)
		AudioServer.set_bus_volume_db(bus_idx, SILENCE_DB)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(clamped))


func _sync_setting(prop_name: String, value: Variant) -> void:
	var save_svc := get_node_or_null("/root/SaveAndSettingsService")
	if save_svc == null or not ("settings" in save_svc):
		return
	var s: UserSettingsData = save_svc.get("settings") as UserSettingsData
	if s != null and prop_name in s:
		s.set(prop_name, value)


func _load_audio_stream_safe(path: String, is_music: bool) -> AudioStream:
	var clean_path := path.strip_edges()
	if clean_path.is_empty():
		return null

	var has_raw_file := FileAccess.file_exists(clean_path)
	var has_imported := (
		FileAccess.file_exists(clean_path + ".import")
		or FileAccess.file_exists(clean_path + ".remap")
		or (not has_raw_file and ResourceLoader.exists(clean_path))
	)

	if not has_imported and not has_raw_file:
		return null

	var stream: AudioStream = null
	if has_imported and ResourceLoader.exists(clean_path):
		var loaded := ResourceLoader.load(clean_path)
		if loaded is AudioStream:
			stream = loaded as AudioStream

	if stream == null and has_raw_file:
		stream = _decode_raw_audio_file(clean_path)

	if stream == null:
		return null
	if stream.get_length() <= 0.0:
		return null

	if is_music and stream is AudioStreamMP3 and (stream as AudioStreamMP3).loop:
		var mp3_copy := (stream as AudioStreamMP3).duplicate() as AudioStreamMP3
		mp3_copy.loop = false
		stream = mp3_copy

	return stream


static func _decode_raw_audio_file(path: String) -> AudioStream:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 16:
		return null

	var lower := path.to_lower()
	if lower.ends_with(".mp3"):
		if not _looks_like_valid_mp3(bytes):
			return null
		var mp3 := AudioStreamMP3.new()
		mp3.data = bytes
		mp3.loop = false
		if mp3.get_length() <= 0.0:
			return null
		return mp3

	if lower.ends_with(".wav"):
		if not _looks_like_valid_wav(bytes):
			return null
		var wav := AudioStreamWAV.load_from_file(path)
		if wav == null or wav.get_length() <= 0.0:
			return null
		return wav

	return null


static func _looks_like_valid_mp3(bytes: PackedByteArray) -> bool:
	if bytes.size() < 16:
		return false
	# Check for ID3v2 header ("ID3") at byte 0
	if bytes[0] == 0x49 and bytes[1] == 0x44 and bytes[2] == 0x33:
		return true
	# Scan first 4096 bytes for a valid MPEG audio frame sync header
	var limit := mini(bytes.size() - 4, 4096)
	for i in range(limit):
		if bytes[i] == 0xFF and (bytes[i + 1] & 0xE0) == 0xE0:
			var version_bits := (bytes[i + 1] >> 3) & 0x03
			var layer_bits := (bytes[i + 1] >> 1) & 0x03
			var bitrate_idx := (bytes[i + 2] >> 4) & 0x0F
			var sample_idx := (bytes[i + 2] >> 2) & 0x03
			if version_bits != 1 and layer_bits != 0 and bitrate_idx != 0 and bitrate_idx != 15 and sample_idx != 3:
				return true
	return false


static func _looks_like_valid_wav(bytes: PackedByteArray) -> bool:
	if bytes.size() < 44:
		return false
	# "RIFF" .... "WAVE"
	return (
		bytes[0] == 0x52 and bytes[1] == 0x49 and bytes[2] == 0x46 and bytes[3] == 0x46
		and bytes[8] == 0x57 and bytes[9] == 0x41 and bytes[10] == 0x56 and bytes[11] == 0x45
	)
