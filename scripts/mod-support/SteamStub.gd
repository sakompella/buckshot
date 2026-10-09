extends Node

signal leaderboard_find_result
signal leaderboard_score_uploaded
signal leaderboard_scores_downloaded

const LEADERBOARD_DATA_REQUEST_GLOBAL = 0
const LEADERBOARD_DATA_REQUEST_GLOBAL_AROUND_USER = 1
const LEADERBOARD_DATA_REQUEST_FRIENDS = 2

func _ready() -> void:
	await get_tree().process_frame
	var scene := get_tree().current_scene
	var label := scene.find_child("version", true, false) if scene else null
	print("smoke: scene=", scene.scene_file_path if scene else "<none>")
	print("smoke: version_label=", label.text if label else "<none>")

func steamInit(_retrieve_stats: bool = true) -> Dictionary:
	return {"status": 1, "verbal": "steam stub (no Steam)"}

func run_callbacks() -> void: pass
func setAchievement(_name: String) -> bool: return true
func clearAchievement(_name: String) -> bool: return true
func storeStats() -> bool: return true
func setLeaderboardDetailsMax(max_details: int) -> int: return max_details
func findLeaderboard(_name: String) -> void: pass
func uploadLeaderboardScore(_score: int, _keep_best: bool = true, _details: PackedInt32Array = PackedInt32Array(), _handle: int = 0) -> void: pass
func downloadLeaderboardEntries(_start: int, _end: int, _type: int = 0, _handle: int = 0) -> void: pass
func getLeaderboardEntryCount(_handle: int = 0) -> int: return 0
func getSteamID() -> int: return 0
func getFriendPersonaName(_id: int) -> String: return ""
