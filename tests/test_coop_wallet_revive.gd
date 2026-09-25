extends SceneTree
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,text: String) -> void:
	print("PASS " if ok else "FAIL ",text)
	if not ok: failures+=1
func run() -> void:
	var first=preload("res://scripts/main.gd").new()
	first.progress.save_path="user://wallet_host_%d.cfg"%OS.get_process_id()
	first.progress.money=1750; first.progress.resume_level=8; first.progress.resume_players=2; first.progress.save_progress()
	root.add_child(first)
	var second=preload("res://scripts/progress_store.gd").new()
	second.save_path="user://wallet_guest_%d.cfg"%OS.get_process_id(); second.money=2500; second.save_progress()
	var session=preload("res://scripts/split_session.gd").new(); session.secondary_save_path=second.save_path; root.add_child(session)
	await session.launch(first,2,true)
	var host=session.games[0]; var guest=session.games[1]
	for game in session.games: game.set_process(false); game.campaign.set_process(false); game.player.set_physics_process(false)
	check(host.level==8 and guest.level==8,"continue resumes the host level in both viewports")
	check(host.progress.money==1750 and guest.progress.money==2500,"different saved wallets survive split-screen launch")
	guest._apply_health_damage(10000); guest.paid_revive()
	check(guest.health==10 and guest.progress.money==1500 and host.coop.avatars[2].health==10,"guest pays own wallet and host confirms revive")
	check(host.progress.money==1750,"guest revive never charges host")
	guest.paid_revive(); check(guest.progress.money==1500,"repeated request cannot double charge")
	host._apply_health_damage(10000); guest._apply_health_damage(10000)
	check(host.mode=="dead" and guest.mode=="dead","team wipe enters defeat for both")
	guest.paid_revive()
	check(guest.health==10 and guest.progress.money==500 and host.level==8 and host.mode=="waiting","paid guest revive reopens wiped round")
	host.paid_revive()
	check(host.health==10 and host.progress.money==750 and host.level==8,"host paid revive returns to same round")
	for game in session.games: game.save_checkpoint()
	second.load_progress(); check(second.money==500 and second.resume_level==8 and second.resume_players==2,"guest wallet and checkpoint persist independently")
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa/paid-revive-split.png")
	session.queue_free(); await process_frame
	print("COOP_WALLET_REVIVE failures=",failures); quit(1 if failures else 0)
