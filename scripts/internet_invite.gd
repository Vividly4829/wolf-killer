extends Node
## Optional, account-free public playtest relay. No inbound public listener.
const VERSION:="2026.9.1"
const URL:="https://github.com/cloudflare/cloudflared/releases/download/2026.9.1/cloudflared-windows-amd64.exe"
const SHA:="2837888cc0f5d58f15b6dc478376de90b4d3ba5241c7947455d1e0a0df429712"
var coop: Node
var helper_pid:=-1
var invite:=""
var token:=""
var helper_path:="user://relay/cloudflared-2026.9.1.exe"
var log_path:=""
var starting:=false
var deadline:=0
var request: HTTPRequest
var epoch:=0
func _ready() -> void:
	coop.multiplayer.peer_authenticating.connect(auth_begin)
	coop.multiplayer.peer_authentication_failed.connect(func(_id):
		if not coop.server() and coop.active: coop.fail_connection("Invite authentication failed or session is full. Ask the host for a fresh invite."))
func stop() -> void:
	epoch+=1; starting=false; invite=""; token=""
	if is_instance_valid(request): request.cancel_request(); request.queue_free()
	if helper_pid>0 and OS.is_process_running(helper_pid): OS.kill(helper_pid)
	helper_pid=-1
func _exit_tree() -> void: stop()
func host() -> void:
	if is_instance_valid(coop.game.split_session): return
	coop.leave(); coop.requested_host=true; coop.internet_host_requested=true
	coop.game.set_mode("connecting"); coop.status="Preparing experimental internet invite..."
	starting=true; deadline=Time.get_ticks_msec()+180000
	var current:=epoch
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://relay"))
	if not FileAccess.file_exists(helper_path) or FileAccess.get_sha256(helper_path)!=SHA:
		coop.status="Downloading internet relay (55 MB, first host only)..."
		request=HTTPRequest.new(); add_child(request); request.download_file=helper_path+".part"; request.timeout=150
		if request.request(URL)!=OK: coop.fail_connection("Relay download could not start."); return
		var result: Array=await request.request_completed
		if current!=epoch: return
		if result[0]!=HTTPRequest.RESULT_SUCCESS or result[1]!=200 or FileAccess.get_sha256(helper_path+".part")!=SHA:
			coop.fail_connection("Relay download failed verification. Please retry with an internet connection."); return
		DirAccess.rename_absolute(ProjectSettings.globalize_path(helper_path+".part"),ProjectSettings.globalize_path(helper_path))
	if current!=epoch: return
	token=Crypto.new().generate_random_bytes(24).hex_encode()
	var peer:=WebSocketMultiplayerPeer.new()
	var result:=ERR_CANT_CREATE
	var listen_port:=0
	for attempt in 12:
		listen_port=randi_range(30000,55000); result=peer.create_server(listen_port,"127.0.0.1")
		if result==OK: break
	if result!=OK: coop.fail_connection("Could not create local relay listener."); return
	configure_auth(); coop.multiplayer.multiplayer_peer=peer; coop.active=true
	coop.local_area=coop.Avatar.hitbox(coop.game.player,1)
	log_path="user://relay/session-%d.log"%Time.get_ticks_msec()
	helper_pid=OS.create_process(ProjectSettings.globalize_path(helper_path),["tunnel","--no-autoupdate","--protocol","http2","--url","http://127.0.0.1:%d"%listen_port,"--logfile",ProjectSettings.globalize_path(log_path)],false)
	if helper_pid<=0: coop.fail_connection("Could not launch the relay helper."); return
	coop.status="Opening public invite..."; deadline=Time.get_ticks_msec()+60000
func configure_auth() -> void:
	coop.multiplayer.auth_timeout=15
	coop.multiplayer.server_relay=false
	coop.multiplayer.auth_callback=authenticate
func auth_begin(id: int) -> void:
	if token.is_empty(): return
	if coop.server() and coop.avatars.size()>=3: coop.multiplayer.disconnect_peer(id); return
	coop.multiplayer.send_auth(id,("wolf-island-v1" if coop.server() else token).to_utf8_buffer())
func authenticate(id: int,data: PackedByteArray) -> void:
	if data==(token if coop.server() else "wolf-island-v1").to_utf8_buffer() and not token.is_empty() and (not coop.server() or coop.avatars.size()<3): coop.multiplayer.complete_auth(id)
	else: coop.multiplayer.disconnect_peer(id)
func join_invite(link: String) -> void:
	var parts:=link.strip_edges().split("#")
	if parts.size()!=2 or parts[1].length()!=48:
		coop.fail_connection("Paste the complete invite, including its # code."); return
	var host_name: String=parts[0].trim_prefix("https://").trim_prefix("wss://").trim_suffix("/")
	if not host_name.ends_with(".trycloudflare.com") or "/" in host_name or "@" in host_name:
		coop.fail_connection("This is not a Wolf Island internet invite."); return
	token=parts[1]; configure_auth()
	coop.status="Joining internet session..."; coop.awaiting_spawn=true; coop.join_deadline=Time.get_ticks_msec()+45000
	coop.game.set_mode("connecting")
	var peer:=WebSocketMultiplayerPeer.new()
	var result:=peer.create_client("wss://"+host_name)
	if result!=OK: coop.fail_connection("Could not open the invite: "+error_string(result)); return
	coop.multiplayer.multiplayer_peer=peer; coop.active=true
func copy_invite() -> void:
	if not invite.is_empty():
		DisplayServer.clipboard_set(invite); coop.game.show_notice("Invite copied. Friends paste it into JOIN in the same game version.",6)
func _process(_delta: float) -> void:
	if not starting: return
	if Time.get_ticks_msec()>deadline: coop.fail_connection("Internet relay timed out. Retry hosting; the free playtest service may be unavailable."); return
	if helper_pid<=0 or not FileAccess.file_exists(log_path): return
	var log:=FileAccess.get_file_as_string(log_path)
	var pattern:=RegEx.new(); pattern.compile("https://[a-z0-9-]+\\.trycloudflare\\.com")
	var found:=pattern.search(log)
	if found and "Registered tunnel connection" in log:
		invite=found.get_string()+"#"+token; starting=false
		coop.status="INTERNET INVITE / 1 OF 4"; coop.game.start_from_menu(); copy_invite()
