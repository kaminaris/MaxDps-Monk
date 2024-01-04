local _, addonTable = ...;

--- @type MaxDps
if not MaxDps then
	return
end

local MaxDps = MaxDps;
local UnitPower = UnitPower;
local UnitHealth = UnitHealth;
local UnitHealthMax = UnitHealthMax;
local GetPowerRegen = GetPowerRegen;
local Energy = Enum.PowerType.Energy;
local Monk = addonTable.Monk;

local BR = {
	InvokeNiuzao			= 132578,
	TouchOfDeath			= 322109,
	KegSmash				= 121253,
	BlackoutKick			= 205523,
	BreathofFire			= 115181,
	PurifyingBrew			= 119582,
	RushingJadeWind			= 116847,
	TigerPalm				= 100780,
	CelestialBrew			= 322507,
	SpinningCraneKick		= 322729,
	HealingElixir			= 122281,
	RisingSunKick			= 107428,
	ChiWave					= 115098,
	ChiBurst				= 123986,
	SummonWhiteTigerStatue	= 388686,
	BonedustBrew			= 386276,
	ExplodingKeg			= 325153,
	WeaponsOfOrder			= 387184,
	CharredPassions 		= 386965,
	BlackoutCombo 			= 196736,
	BlackOxBrew				= 115399,
};

function Monk:Brewmaster()
	local fd = MaxDps.FrameData;
	local cooldown = fd.cooldown;
	local buff = fd.buff;
	local debuff = fd.debuff;
	local currentSpell = fd.currentSpell;
	local talents = fd.talents;
	local targets = MaxDps:SmartAoe();
	local gcd = fd.gcd;
	local timeToDie = fd.timeToDie;
	local energy = UnitPower('player', Energy);
	local energyRegen = GetPowerRegen();
	local health = UnitHealth('player');
	local healthMax = UnitHealthMax('player');
	local healthPercent = ( health / healthMax ) * 100
	local targetHealthPercent = MaxDps:TargetPercentHealth();
	local targetHealth = UnitHealth('target');
	local staggerAmount = UnitStagger('player');
	local staggerPercent = (staggerAmount / healthMax) * 100;
	MaxDps:GlowEssences();

	--TOD on CD
	MaxDps:GlowCooldown(BR.TouchOfDeath,cooldown[BR.TouchOfDeath].ready and targetHealthPercent < 15 and targetHealth < health and targetHealth > 0);
	--Niuzao on CD
	MaxDps:GlowCooldown(BR.InvokeNiuzao,cooldown[BR.InvokeNiuzao].ready);
	
	--DEFENSIVE GOES FIRST
	if staggerPercent > 60 and cooldown[BR.CelestialBrew].ready then
		return BR.CelestialBrew;
	end

	if healthPercent <= 50 and cooldown[BR.CelestialBrew].ready then
		return BR.CelestialBrew;
	end

	if talents[BR.HealingElixir] and healthPercent <= 85 and cooldown[BR.HealingElixir].ready then
		return BR.HealingElixir;
	end

	if staggerPercent > 20 and cooldown[BR.PurifyingBrew].charges > 1.5 and cooldown[BR.PurifyingBrew].ready then
		return BR.PurifyingBrew;
	end

	if staggerPercent > 50 and cooldown[BR.PurifyingBrew].ready then
		return BR.PurifyingBrew;
	end

	if buff[BR.BlackoutCombo].up and cooldown[BR.TigerPalm].ready and targets < 2 then
		return BR.TigerPalm;
	end

	if talents[BR.BlackOxBrew] and cooldown[BR.BlackOxBrew].ready and energy + energyRegen <= 40 then
		return BR.BlackOxBrew;
	end

	if talents[BR.WeaponsOfOrder] and cooldown[BR.WeaponsOfOrder].ready then
		return BR.WeaponsOfOrder;
	end

	if talents[BR.SummonWhiteTigerStatue] and cooldown[BR.SummonWhiteTigerStatue].ready then
		return BR.SummonWhiteTigerStatue;
	end

	if talents[BR.BonedustBrew] and cooldown[BR.BonedustBrew].ready then
		return BR.BonedustBrew;
	end

	if talents[BR.ExplodingKeg] and cooldown[BR.ExplodingKeg].ready then
		return BR.ExplodingKeg;
	end

	if cooldown[BR.KegSmash].ready then
		return BR.KegSmash;
	end

	if cooldown[BR.RisingSunKick].ready then
		return BR.RisingSunKick;
	end

	if cooldown[BR.BlackoutKick].ready then
		return BR.BlackoutKick;
	end

	if cooldown[BR.BreathofFire].ready then
		return BR.BreathofFire;
	end

	if talents[BR.RushingJadeWind] and cooldown[BR.RushingJadeWind].ready and buff[BR.RushingJadeWind].remains < 1 then
		return BR.RushingJadeWind;
	end

	if talents[BR.WeaponsOfOrder] and cooldown[BR.TigerPalm].ready and targets < 2 then
		return BR.TigerPalm;
	end

	if energy >=65 and targets >= 2 then
		return BR.SpinningCraneKick;
	end

	if talents[BR.ChiWave] and cooldown[BR.ChiWave].ready then
		return BR.ChiWave;
	end

	if talents[BR.ChiBurst] and cooldown[BR.ChiBurst].ready then
		return BR.ChiBurst;
	end

end
