extends RefCounted
## Thirty authored jobs; only the director knows the rolled complication.
## hunt = hunter kills, kill = eliminate threats. Search fields remain zero
## for compatibility with shared mission snapshots; there are no finding objectives.
static var cache: Dictionary = {}
static func wave(number: int, hunters: int = 1) -> Dictionary:
	var cache_key:=number*5+clampi(hunters,1,4)
	if cache.has(cache_key): return cache[cache_key].duplicate(true)
	var jobs: Array = [
		["First Supper", {"deer":1}, {}, 0,0, 0,0,0, ["none"]],
		["Enough for Tomorrow", {"deer":2}, {}, 0,0, 0,0,0, ["rain"]],
		["Across the Water", {"goose":1}, {}, 0,0, 0,0,0, ["wind"]],
		["Something at the Treeline", {}, {"wolf":2}, 0,0, 6,0,0, ["wolves"]],
		["First Blood Moon", {}, {"werewolf":1}, 0,0, 2,1,0, []],
		["Restock", {"deer":2,"goose":1}, {}, 0,0, 0,0,0, ["carcass_pack"]],
		["A Quiet Shore", {"goose":1}, {}, 0,0, 0,0,0, ["patrol"]],
		["The Missing Hunter", {}, {"wolf":3}, 0,0, 3,0,0, ["wolves"]],
		["A Bigger Animal", {}, {"bear":1}, 0,0, 0,0,0, ["fog"]],
		["Across the Narrows", {}, {"werewolf":1}, 0,0, 4,1,0, []],
		["Three Clean Kills", {"deer":3}, {}, 0,0, 0,0,0, ["carcass_pack"]],
		["Unwelcome Guests", {}, {}, 0,0, 0,0,3, ["scout"]],
		["Tea Before Dark", {"goose":2}, {}, 0,0, 0,0,0, ["fever"]],
		["Two Packs", {}, {"wolf":6}, 0,0, 6,0,0, ["migration"]],
		["Red Water", {}, {"werewolf":1}, 0,0, 5,1,0, []],
		["Follow the Blood", {}, {"bear":1}, 0,0, 0,0,0, ["carcass_pack"]],
		["The Empty Pantry", {"deer":2,"waterbird":2}, {}, 0,0, 0,0,0, ["scent_pack"]],
		["Crossfire", {}, {}, 0,0, 0,0,4, ["crossfire"]],
		["Check the Cabins", {}, {}, 0,0, 0,0,0, ["bear"]],
		["Two Howls", {}, {"werewolf":2}, 0,0, 6,2,0, []],
		["Lean Hunting", {"deer":3}, {}, 0,0, 4,0,0, ["bear_claim"]],
		["The Roadblock", {}, {}, 0,0, 0,0,5, ["patrol"]],
		["Pack Country", {}, {"wolf":8}, 0,0, 8,0,0, ["scent_pack"]],
		["Nothing Complicated", {"goose":1}, {}, 0,0, 0,0,0, ["patrol","bear"]],
		["The Red Hunt", {}, {"werewolf":2}, 0,0, 8,2,0, []],
		["Keep the Fire Going", {}, {}, 0,0, 0,0,0, ["rain","wolves"]],
		["Claimed Ground", {}, {"bear":1}, 0,0, 0,0,4, ["pursuit"]],
		["The Scattered Pack", {}, {"wolf":10}, 0,0, 10,0,0, ["fog"]],
		["Last Provisions", {"deer":2,"goose":2}, {}, 0,0, 0,0,0, ["patrol","bear_claim","fever"]],
		["Until Morning", {}, {"werewolf":3}, 0,0, 6,3,0, []]
	]
	var row: Array = jobs[clampi(number,1,30)-1]
	var job := {"number":number,"title":row[0],"hunt":row[1].duplicate(),"kill":row[2].duplicate(),"sites":row[3],"search":row[4],"wolves":row[5],"bosses":row[6],"raiders":row[7],"events":row[8].duplicate(),"moon":number%5==0}
	# Searches were removed: every round has a hunting or combat objective.
	job.sites=0; job.search=0
	if number in [12,18,22]: job.kill={"raider":int(job.raiders)}
	if number==19: job.title="The Forest Feast"; job.hunt={"deer":2,"rabbit":3}
	if number==26: job.title="Winter Provisions"; job.hunt={"deer":2,"rabbit":4}
	if number==7: job.title="Rabbit Stew"; job.hunt={"rabbit":3}
	if number==13: job.hunt={"goose":1,"rabbit":2}
	# Extra hunters add responsibilities, not extra hit points. Never change the intro.
	if hunters>1 and number>3:
		for key in job.hunt: job.hunt[key] += hunters-1
		if job.kill.has("wolf"): job.kill.wolf += hunters-1; job.wolves += hunters-1
		elif int(job.wolves)>0: job.wolves += hunters-1
		if int(job.raiders)>0:
			job.raiders += hunters-1
			if job.kill.has("raider"): job.kill.raider += hunters-1
	cache[cache_key]=job.duplicate(true)
	return job

static func total(job: Dictionary) -> int:
	var count := int(job.sites)+int(job.search)
	for n in job.hunt.values(): count+=int(n)
	for n in job.kill.values(): count+=int(n)
	return count

static func encounter_chance(level: int) -> float:
	return lerpf(.25,.85,clampf((level-1)/29.0,0,1))
static func large_pack_chance(level: int) -> float:
	return lerpf(.08,.55,clampf((level-1)/29.0,0,1))
static func pack_size(level: int,rng: RandomNumberGenerator) -> int:
	if level<=7: return rng.randi_range(3,4) if rng.randf()<.05 else rng.randi_range(2,3)
	if level<=10: return rng.randi_range(4,6) if rng.randf()<.12 else rng.randi_range(2,4)
	return rng.randi_range(5,7+mini(5,level/6)) if rng.randf()<large_pack_chance(level) else rng.randi_range(2,3+mini(3,level/8))

static func wolf_budget(level: int,hunters: int=1) -> int:
	if level<=3: return 3
	if level<=7: return (6 if level==4 else 4)+maxi(0,hunters-1)
	if level<=10: return 7+maxi(0,hunters-1)
	return mini(32,9+(level-10)+maxi(0,hunters-1))
