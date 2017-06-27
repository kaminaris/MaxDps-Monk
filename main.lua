-- Spells
local _KegSmash = 121253;
local _Jab = 100780;
local _ExpelHarm = 115072;
local _TigerPalm = 100787;
local _ElusiveBrew = 115308;
local _PurifyingBrew = 119582;
local _BlackoutKick = 100784;
local _ChiExplosion = 157676;

-- Auras
local _HeavyStagger = 124273;
local _ModerateStagger = 124274;
local _Shuffle = 115307;
local _ElusiveBrewAura = 128939;
local _TigerPower = 125359;

-- New
local _FistsofFury = 113656;
local _StrikeoftheWindlord = 205320;
local _WhirlingDragonPunch = 152175;
local _TigerPalm = 100780;
local _RisingSunKick = 107428;
local _ChiWave = 115098;
local _BlackoutKick = 100784;
local _BlackoutKickAura = 116768;
local _MarkoftheCrane = 228287;
local _SpinningCraneKick = 101546;
local _StormEarthandFire = 137639;
local _Serenity = 152173;
local _RushingJadeWind = 116847;
local _ChiBurst = 123986;
local _TouchofDeath = 115080;
local _Ascension = 115396;
local _MasteryComboStrikes = 115636;
local _Afterlife = 116092;
local _HealingSphere = 125355;
local _TouchofKarma = 122470;
local _EnergizingElixir = 115288;
local _Roll = 109132;
local _Celerity = 115173;
local _HitCombo = 196740;
local _HitComboAura = 196741;
local _Transcendence = 101643;
local _TranscendenceTransfer = 119996;

local _HitComboAbilities = {
	[_BlackoutKick] = 1,
	[_ChiWave] = 1,
	[_FistsofFury] = 1,
	[_RisingSunKick] = 1,
	[_TigerPalm] = 1,
	[_TouchofDeath] = 1,
	[_StrikeoftheWindlord] = 1,
}

MaxDps.Monk = {};

function MaxDps.Monk.CheckTalents()
end

function MaxDps:EnableRotationModule(mode)
	mode = mode or 1;
	self.Description = 'Monk [Windwalker]';
	self.ModuleOnEnable = MaxDps.Monk.CheckTalents;
	if mode == 1 then
		self.NextSpell = MaxDps.Monk.Brewmaster;
	end;
	if mode == 2 then
		self.NextSpell = MaxDps.Monk.Mistweaver;
	end;
	if mode == 3 then
		self.NextSpell = MaxDps.Monk.Windwalker;
	end;
	self:RegisterEvent('UNIT_SPELLCAST_SUCCEEDED');
	self.lastSpellId = 0;
end

function MaxDps:UNIT_SPELLCAST_SUCCEEDED(event, unitID, spell, rank, lineID, spellID)
	if unitID == 'player' and _HitComboAbilities[spellID] == 1 then
		self.lastSpellId = spellID;
	end
end

function MaxDps.Monk.Brewmaster(_, timeShift, currentSpell, gcd, talents)
	return nil;
end

function MaxDps.Monk.Mistweaver(_, timeShift, currentSpell, gcd, talents)
	return nil;
end

function MaxDps.Monk.Windwalker(_, timeShift, currentSpell, gcd, talents)
	local chi = UnitPower('player', SPELL_POWER_CHI);
	local energy = UnitPower('player', SPELL_POWER_ENERGY);
	local energyMax = UnitPowerMax('player', SPELL_POWER_ENERGY);

	local hit, hitCharges = MaxDps:Aura(_HitComboAura, timeShift);

	local rsk = MaxDps:SpellAvailable(_RisingSunKick, timeShift);
	local fotf, fotfCd = MaxDps:SpellAvailable(_FistsofFury, timeShift);

	if talents[_StormEarthandFire] then
		MaxDps:GlowCooldown(_StormEarthandFire, MaxDps:SpellAvailable(_StormEarthandFire, timeShift));
	end

	if talents[_Serenity] then
		MaxDps:GlowCooldown(_Serenity, MaxDps:SpellAvailable(_Serenity, timeShift));
	end

	MaxDps:GlowCooldown(_TouchofDeath, MaxDps:SpellAvailable(_TouchofDeath, timeShift));

	if talents[_WhirlingDragonPunch]
		and not fotf
		and not rsk
		and MaxDps:SpellAvailable(_WhirlingDragonPunch, timeShift)
	then
		return _WhirlingDragonPunch;
	end

	if fotf and chi >= 3 then
		return _FistsofFury;
	end

	if MaxDps:SpellAvailable(_StrikeoftheWindlord, timeShift) and chi >= 2 then
		return _StrikeoftheWindlord;
	end

	if (chi < 4 and (energyMax - energy < 20)) and (not hit or MaxDps.lastSpellId ~= _TigerPalm) then
		return _TigerPalm;
	end

	if (rsk and chi >= 2) and (not hit or MaxDps.lastSpellId ~= _RisingSunKick) then
		return _RisingSunKick;
	end

	if talents[_ChiWave] and MaxDps:SpellAvailable(_ChiWave, timeShift) then
		return _ChiWave;
	end

	local canBlackout = MaxDps:Aura(_BlackoutKickAura, timeShift) or
			(MaxDps:SpellAvailable(_BlackoutKick, timeShift) and chi > 0);
	if
		(canBlackout and (chi > 3 or fotfCd > 3))
		and (not hit or MaxDps.lastSpellId ~= _BlackoutKick)
	then
		return _BlackoutKick;
	end

	if hit and MaxDps.lastSpellId == _TigerPalm then
		return nil;
	else
		return _TigerPalm;
	end
end