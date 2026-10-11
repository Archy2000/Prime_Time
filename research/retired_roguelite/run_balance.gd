extends RefCounted
const VERSION:="town_balance_01"
## Playtest baseline for the eight-minute town. Cumulative meals, not per-level costs.
const THRESHOLDS:Array[int]=[6,15,27,42,60,82,108,139,175,216]
const FAMILY_PICK_GATES:Array[int]=[1,3,6,9]
const MAX_GROWTH_MEALS:=180
const PRIMARY_BITE_INTERVAL:=0.90
const HYDRA_INTERVAL:=1.20
const HYDRA_BATCH:Array[int]=[0,1,1,2,3]
const KRAKEN_INTERVAL:Array[float]=[0.0,3.2,2.9,2.6,2.3]
const BASE_HEAL:=2.0
const HEAL_PER_RANK:=2.0
const ZOMBIE_HEAL_PER_RANK:=1.0

static func growth_for(meals:int)->float:
	# Keep early building access, but spread large-scale destruction across the run.
	if meals<=27:return lerpf(1.0,1.65,clampf(meals/27.0,0.0,1.0))
	if meals<=82:return lerpf(1.65,2.30,(meals-27)/55.0)
	return lerpf(2.30,3.20,clampf(float(meals-82)/(MAX_GROWTH_MEALS-82),0.0,1.0))
