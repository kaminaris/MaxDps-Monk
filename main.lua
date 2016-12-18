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

-- Talents
local _isChiExplosion = false;
local _isChiBurst = false;
local _isChiWave = false;
local _isSerenity = false;
local _isHitCombo = false;
local _isWhirlingDragonPunch = false;

MaxDps.Monk = {};

function MaxDps.Monk.CheckTalents()
	MaxDps:CheckTalents();
	_isChiExplosion = MaxDps:HasTalent(_ChiExplosion);
	_isChiBurst = MaxDps:HasTalent(_ChiBurst);
	_isChiWave = MaxDps:HasTalent(_ChiWave);
	_isSerenity = MaxDps:HasTalent(_Serenity);
	_isHitCombo = MaxDps:HasTalent(_HitCombo);
	_isWhirlingDragonPunch = MaxDps:HasTalent(_WhirlingDragonPunch);
	-- other checking functions
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
	if unitID == 'player' then
		self.lastSpellId = spellID;
	end
end

function MaxDps.Monk.Brewmaster()
	local timeShift, currentSpell, gcd = MaxDps:EndCast();

--	local chi = UnitPower('player', SPELL_POWER_CHI);
	--	local energy = UnitPower('player', SPELL_POWER_ENERGY);
	--	local stagger = UnitStagger('player');
	--
	--	local keg = MaxDps:SpellAvailable(_KegSmash, timeShift);
	--	local harm = MaxDps:SpellAvailable(_ExpelHarm, timeShift);
	--	local heavyStag = MaxDps:Aura(_HeavyStagger, timeShift);
	--	local modStag = MaxDps:Aura(_ModerateStagger, timeShift);
	--	local shuffle = MaxDps:Aura(_Shuffle, timeShift);
	--
	--	local eb, ebCharges = MaxDps:Aura(_ElusiveBrewAura);
	--
	--	if eb and ebCharges > 9 then
	--		return _ElusiveBrew;
	--	end
	--
	--	if heavyStag or modStag and chi > 1 then
	--		return _PurifyingBrew;
	--	end
	--
	--	if _isChiExplosion then
	--		if chi >= 1 and not shuffle then
	--			return _ChiExplosion;
	--		end
	--		if chi >= 4 then
	--			return _ChiExplosion;
	--		end
	--	else
	--		if chi >= 1 and not shuffle then
	--			return _BlackoutKick;
	--		end
	--	end
	--
	--	if keg and energy > 35 then
	--		return _KegSmash;
	--	end
	--
	--	if harm and energy > 35 then
	--		return _ExpelHarm;
	--	end
	--
	--	if energy > 35 then
	--		return _Jab;
	--	end
	--
	--	return _TigerPalm;
	return nil;
end

function MaxDps.Monk.Mistweaver()
	local timeShift, currentSpell, gcd = MaxDps:EndCast();

	return nil;
end

function MaxDps.Monk.Windwalker()
	local timeShift, currentSpell, gcd = MaxDps:EndCast();

	local chi = UnitPower('player', SPELL_POWER_CHI);
	local energy = UnitPower('player', SPELL_POWER_ENERGY);
	local energyMax = UnitPowerMax('player', SPELL_POWER_ENERGY);

	local hit, hitCharges = MaxDps:Aura(_HitComboAura, timeShift);

	local rsk = MaxDps:SpellAvailable(_RisingSunKick, timeShift);
	local fotf, fotfCd = MaxDps:SpellAvailable(_FistsofFury, timeShift);

	MaxDps:GlowCooldown(_StormEarthandFire, MaxDps:SpellAvailable(_StormEarthandFire, timeShift));
	MaxDps:GlowCooldown(_TouchofDeath, MaxDps:SpellAvailable(_TouchofDeath, timeShift));

	if _isWhirlingDragonPunch and not fotf and not rsk and MaxDps:SpellAvailable(_WhirlingDragonPunch, timeShift) then
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

	if _isChiWave and MaxDps:SpellAvailable(_ChiWave, timeShift) then
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