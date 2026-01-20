local _, addonTable = ...
local Monk = addonTable.Monk
local MaxDps = _G.MaxDps
if not MaxDps then return end
local LibStub = LibStub
local setSpell

local ceil = ceil
local floor = floor
local fmod = fmod
local format = format
local max = max
local min = min
local pairs = pairs
local select = select
local strsplit = strsplit
local GetTime = GetTime

local UnitAffectingCombat = UnitAffectingCombat
local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitGUID = UnitGUID
local UnitName = UnitName
local UnitSpellHaste = UnitSpellHaste
local UnitThreatSituation = UnitThreatSituation
local UnitPower = UnitPower
local UnitHealth = UnitHealth
local UnitAura = C_UnitAuras.GetAuraDataByIndex
local UnitAuraByName = C_UnitAuras.GetAuraDataBySpellName
local UnitHealthMax = UnitHealthMax
local UnitPowerMax = UnitPowerMax
local SpellHaste
local SpellCrit
local GetSpellInfo = C_Spell.GetSpellInfo
local GetSpellCooldown = C_Spell.GetSpellCooldown
local GetSpellCastCount = C_Spell.GetSpellCastCount
local GetUnitSpeed = GetUnitSpeed
local GetCritChance = GetCritChance
local GetInventoryItemLink = GetInventoryItemLink
local GetItemInfo = C_Item.GetItemInfo
local GetItemSpell = C_Item.GetItemSpell
local GetNamePlates = C_NamePlate.GetNamePlates and C_NamePlate.GetNamePlates or GetNamePlates
local GetPowerRegenForPowerType = GetPowerRegenForPowerType
local GetSpellName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName or GetSpellInfo
local GetTotemInfo = GetTotemInfo
local IsStealthed = IsStealthed
local IsCurrentSpell = C_Spell and C_Spell.IsCurrentSpell
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo

local ManaPT = Enum.PowerType.Mana
local RagePT = Enum.PowerType.Rage
local FocusPT = Enum.PowerType.Focus
local EnergyPT = Enum.PowerType.Energy
local ComboPointsPT = Enum.PowerType.ComboPoints
local RunesPT = Enum.PowerType.Runes
local RunicPowerPT = Enum.PowerType.RunicPower
local SoulShardsPT = Enum.PowerType.SoulShards
local DemonicFuryPT = Enum.PowerType.DemonicFury
local BurningEmbersPT = Enum.PowerType.BurningEmbers
local LunarPowerPT = Enum.PowerType.LunarPower
local HolyPowerPT = Enum.PowerType.HolyPower
local MaelstromPT = Enum.PowerType.Maelstrom
local ChiPT = Enum.PowerType.Chi
local InsanityPT = Enum.PowerType.Insanity
local ArcaneChargesPT = Enum.PowerType.ArcaneCharges
local FuryPT = Enum.PowerType.Fury
local PainPT = Enum.PowerType.Pain
local EssencePT = Enum.PowerType.Essence
local RuneBloodPT = Enum.PowerType.RuneBlood
local RuneFrostPT = Enum.PowerType.RuneFrost
local RuneUnholyPT = Enum.PowerType.RuneUnholy

local fd
local ttd
local timeShift
local gcd
local cooldown
local buff
local debuff
local talents
local targets
local targetHP
local targetmaxHP
local targethealthPerc
local curentHP
local maxHP
local healthPerc
local timeInCombat
local className, classFilename, classId = UnitClass('player')
local classtable
local LibRangeCheck = LibStub('LibRangeCheck-3.0', true)

local Energy
local EnergyMax
local EnergyDeficit
local EnergyPerc
local EnergyRegen
local EnergyRegenCombined
local EnergyTimeToMax
local Chi
local ChiMax
local ChiDeficit
local ChiPerc
local ChiRegen
local ChiRegenCombined
local ChiTimeToMax
local Mana
local ManaMax
local ManaDeficit
local ManaPerc
local ManaRegen
local ManaRegenCombined
local ManaTimeToMax
local staggerAmount
local staggerPercent
local WoOLastUsed

local Brewmaster = {}



local function GetTotemInfoByName(name)
    local info = {
        duration = 0,
        remains = 0,
        up = false,
    }
    for index=1,MAX_TOTEMS do
        local arg1, totemName, startTime, duration, icon = GetTotemInfo(index)
        local remains = math.floor(startTime+duration-GetTime())
        if (totemName == name ) then
            info.duration = duration
            info.up = true
            info.remains = remains
            break
        end
    end
    return info
end

local function GetTotemInfoById(sSpellID)
    local info = {
        duration = 0,
        remains = 0,
        up = false,
    }
    for index=1,MAX_TOTEMS do
        local arg1, totemName, startTime, duration, icon, modRate, spellID = GetTotemInfo(index)
        local sName = sSpellID and GetSpellInfo(sSpellID).name or ''
        local remains = math.floor(startTime+duration-GetTime())
        if (spellID == sSpellID) or (totemName == sName ) then
            info.duration = duration
            info.up = true
            info.remains = remains
            break
        end
    end
    return info
end

local function GetTotemTypeActive(i)
   local arg1, totemName, startTime, duration, icon = GetTotemInfo(i)
   return duration > 0
end




local function twoh_check()
   local leftwep = GetInventoryItemLink('player',16)
   local leftwepSubType = leftwep and select(13, C_Item.GetItemInfo(leftwep))
   local rightwep = GetInventoryItemLink('player',17)
   local rightwepSubType = rightwep and select(13, C_Item.GetItemInfo(rightwep))
   if leftwepSubType == (1 or 5 or 6 or 8) then
      return true
   end
end


local function IsComboStrike(spell)
    if MaxDps and MaxDps.spellHistory then
        if MaxDps.spellHistory[1] then
            if MaxDps.spellHistory[1] ~= spell then
                return true
            end
            if MaxDps.spellHistory[1] == spell then
                return false
            end
        end
    end
    return true
end



function Brewmaster:precombat()
    if (MaxDps:CheckSpellUsable(classtable.ChiBurst, 'ChiBurst') and talents[classtable.ChiBurst]) and ((talents[classtable.ChiBurst] and true or false)) and cooldown[classtable.ChiBurst].ready and not UnitAffectingCombat('player') then
        MaxDps:GlowCooldown(classtable.ChiBurst, cooldown[classtable.ChiBurst].ready)
    end
end


local function ClearCDs()
    MaxDps:GlowCooldown(classtable.ChiBurst, false)
    MaxDps:GlowCooldown(classtable.SpearHandStrike, false)
    MaxDps:GlowCooldown(classtable.DiffuseMagic, false)
    MaxDps:GlowCooldown(classtable.Vivify, false)
    MaxDps:GlowCooldown(classtable.PurifyingBrew, false)
    MaxDps:GlowCooldown(classtable.CelestialBrew, false)
    MaxDps:GlowCooldown(classtable.DampenHarm, false)
    MaxDps:GlowCooldown(classtable.FortifyingBrew, false)
    MaxDps:GlowCooldown(classtable.ExpelHarm, false)
    MaxDps:GlowCooldown(classtable.trinket1, false)
    MaxDps:GlowCooldown(classtable.trinket2, false)
    MaxDps:GlowCooldown(classtable.WeaponsofOrder, false)
end

function Brewmaster:callaction()
    if (MaxDps:CheckSpellUsable(classtable.SpearHandStrike, 'SpearHandStrike')) and (UnitCastingInfo('target') and select(8,UnitCastingInfo('target')) == false) and cooldown[classtable.SpearHandStrike].ready then
        MaxDps:GlowCooldown(classtable.SpearHandStrike, ( select(8,UnitCastingInfo('target')) ~= nil and not select(8,UnitCastingInfo('target')) or select(7,UnitChannelInfo('target')) ~= nil and not select(7,UnitChannelInfo('target'))) )
    end
    if (MaxDps:CheckSpellUsable(classtable.DiffuseMagic, 'DiffuseMagic')) and cooldown[classtable.DiffuseMagic].ready then
        MaxDps:GlowCooldown(classtable.DiffuseMagic, cooldown[classtable.DiffuseMagic].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.Vivify, 'Vivify')) and (healthPerc <= 65 and buff[classtable.VivaciousVivificationBuff].up) and cooldown[classtable.Vivify].ready then
        MaxDps:GlowCooldown(classtable.Vivify, cooldown[classtable.Vivify].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.PurifyingBrew, 'PurifyingBrew')) and ((UnitThreatSituation('player') == 2 or UnitThreatSituation('player') == 3) and false and (cooldown[classtable.PurifyingBrew].fullRecharge <gcd or buff[classtable.PurifiedChiBuff].up and buff[classtable.PurifiedChiBuff].remains <1.5*gcd) or cooldown[classtable.CelestialBrew].remains <2*gcd and cooldown[classtable.PurifyingBrew].charges >1.5) and cooldown[classtable.PurifyingBrew].ready then
        MaxDps:GlowCooldown(classtable.PurifyingBrew, cooldown[classtable.PurifyingBrew].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.CelestialBrew, 'CelestialBrew')) and ((UnitThreatSituation('player') == 2 or UnitThreatSituation('player') == 3) and not buff[classtable.CelestialBrewBuff].up and (not talents[classtable.ImprovedCelestialBrew] or buff[classtable.PurifiedChiBuff].up) and (not false or not buff[classtable.BlackoutComboBuff].up)) and cooldown[classtable.CelestialBrew].ready then
        MaxDps:GlowCooldown(classtable.CelestialBrew, cooldown[classtable.CelestialBrew].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.PurifyingBrew, 'PurifyingBrew')) and (MaxDps:NumGroupFriends() >1 and (not false or not buff[classtable.BlackoutComboBuff].up) and 12 >0 and staggerPercent >= 12) and cooldown[classtable.PurifyingBrew].ready then
        MaxDps:GlowCooldown(classtable.PurifyingBrew, cooldown[classtable.PurifyingBrew].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.PurifyingBrew, 'PurifyingBrew')) and (MaxDps:NumGroupFriends() <= 1 and (not false or not buff[classtable.BlackoutComboBuff].up) and 12 >0 and staggerPercent >= 12*0.5) and cooldown[classtable.PurifyingBrew].ready then
        MaxDps:GlowCooldown(classtable.PurifyingBrew, cooldown[classtable.PurifyingBrew].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.PurifyingBrew, 'PurifyingBrew')) and (MaxDps:NumGroupFriends() >1 and (false and not buff[classtable.BlackoutComboBuff].up) and 6 >0 and staggerPercent >= 6) and cooldown[classtable.PurifyingBrew].ready then
        MaxDps:GlowCooldown(classtable.PurifyingBrew, cooldown[classtable.PurifyingBrew].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.PurifyingBrew, 'PurifyingBrew')) and (MaxDps:NumGroupFriends() <= 1 and (not false or not buff[classtable.BlackoutComboBuff].up) and 6 >0 and staggerPercent >= 6*0.5) and cooldown[classtable.PurifyingBrew].ready then
        MaxDps:GlowCooldown(classtable.PurifyingBrew, cooldown[classtable.PurifyingBrew].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.PurifyingBrew, 'PurifyingBrew')) and (MaxDps:NumGroupFriends() >1 and (not false or not buff[classtable.BlackoutComboBuff].up) and 12 == 0 and 6 == 0 and staggerPercent >20) and cooldown[classtable.PurifyingBrew].ready then
        MaxDps:GlowCooldown(classtable.PurifyingBrew, cooldown[classtable.PurifyingBrew].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.PurifyingBrew, 'PurifyingBrew')) and (MaxDps:NumGroupFriends() <= 1 and (not false or not buff[classtable.BlackoutComboBuff].up) and 12 == 0 and 6 == 0 and staggerPercent >10) and cooldown[classtable.PurifyingBrew].ready then
        MaxDps:GlowCooldown(classtable.PurifyingBrew, cooldown[classtable.PurifyingBrew].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.DampenHarm, 'DampenHarm')) and (healthPerc <75 and MaxDps.incoming_damage_3 >curentHP*(0.2+(0.2 * MaxDps:NumGroupFriends() >1 and 1 or 0)) and not buff[classtable.FortifyingBrewBuff].up) and cooldown[classtable.DampenHarm].ready then
        MaxDps:GlowCooldown(classtable.DampenHarm, cooldown[classtable.DampenHarm].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.FortifyingBrew, 'FortifyingBrew')) and (healthPerc <50 and MaxDps.incoming_damage_3 >curentHP*(0.2+(0.2 * MaxDps:NumGroupFriends() >1 and 1 or 0)) and (not buff[classtable.DampenHarmBuff].up)) and cooldown[classtable.FortifyingBrew].ready then
        MaxDps:GlowCooldown(classtable.FortifyingBrew, cooldown[classtable.FortifyingBrew].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.TouchofDeath, 'TouchofDeath')) and cooldown[classtable.TouchofDeath].ready then
        if not setSpell then setSpell = classtable.TouchofDeath end
    end
    if (MaxDps:CheckSpellUsable(classtable.ExpelHarm, 'ExpelHarm')) and (buff[classtable.GiftoftheOxBuff].count >4 and healthPerc <65) and cooldown[classtable.ExpelHarm].ready then
        MaxDps:GlowCooldown(classtable.ExpelHarm, cooldown[classtable.ExpelHarm].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.trinket1, 'trinket1')) and cooldown[classtable.trinket1].ready then
        MaxDps:GlowCooldown(classtable.trinket1, cooldown[classtable.trinket1].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.trinket2, 'trinket2')) and cooldown[classtable.trinket2].ready then
        MaxDps:GlowCooldown(classtable.trinket2, cooldown[classtable.trinket2].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackOxBrew, 'BlackOxBrew')) and (Energy <40) and cooldown[classtable.BlackOxBrew].ready then
        if not setSpell then setSpell = classtable.BlackOxBrew end
    end
    if (MaxDps:CheckSpellUsable(classtable.CelestialBrew, 'CelestialBrew')) and ((not false or not buff[classtable.BlackoutComboBuff].up) and buff[classtable.AspectofHarmonyAccumulatorBuff].value >0.3*curentHP and buff[classtable.WeaponsofOrderBuff].up and not debuff[classtable.AspectofHarmonyDamageDeBuff].up) and cooldown[classtable.CelestialBrew].ready then
        MaxDps:GlowCooldown(classtable.CelestialBrew, cooldown[classtable.CelestialBrew].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.CelestialBrew, 'CelestialBrew')) and ((not false or not buff[classtable.BlackoutComboBuff].up) and buff[classtable.AspectofHarmonyAccumulatorBuff].value >0.3*curentHP and not (talents[classtable.WeaponsofOrder] and true or false) and not debuff[classtable.AspectofHarmonyDamageDeBuff].up) and cooldown[classtable.CelestialBrew].ready then
        MaxDps:GlowCooldown(classtable.CelestialBrew, cooldown[classtable.CelestialBrew].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.CelestialBrew, 'CelestialBrew')) and ((not false or not buff[classtable.BlackoutComboBuff].up) and ttd <20 and ttd >14 and buff[classtable.AspectofHarmonyAccumulatorBuff].value >0.2*curentHP) and cooldown[classtable.CelestialBrew].ready then
        MaxDps:GlowCooldown(classtable.CelestialBrew, cooldown[classtable.CelestialBrew].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.CelestialBrew, 'CelestialBrew')) and ((not false or not buff[classtable.BlackoutComboBuff].up) and buff[classtable.AspectofHarmonyAccumulatorBuff].value >0.3*curentHP and cooldown[classtable.WeaponsofOrder].remains >20 and not debuff[classtable.AspectofHarmonyDamageDeBuff].up) and cooldown[classtable.CelestialBrew].ready then
        MaxDps:GlowCooldown(classtable.CelestialBrew, cooldown[classtable.CelestialBrew].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and cooldown[classtable.BlackoutKick].ready then
        if not setSpell then setSpell = classtable.BlackoutKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.ChiBurst, 'ChiBurst') and talents[classtable.ChiBurst]) and cooldown[classtable.ChiBurst].ready then
        MaxDps:GlowCooldown(classtable.ChiBurst, cooldown[classtable.ChiBurst].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.WeaponsofOrder, 'WeaponsofOrder') and talents[classtable.WeaponsofOrder]) and cooldown[classtable.WeaponsofOrder].ready then
        MaxDps:GlowCooldown(classtable.WeaponsofOrder, cooldown[classtable.WeaponsofOrder].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.RisingSunKick, 'RisingSunKick')) and (not (talents[classtable.FluidityofMotion] and true or false)) and cooldown[classtable.RisingSunKick].ready then
        if not setSpell then setSpell = classtable.RisingSunKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.TigerPalm, 'TigerPalm')) and (buff[classtable.BlackoutComboBuff].up) and cooldown[classtable.TigerPalm].ready then
        if not setSpell then setSpell = classtable.TigerPalm end
    end
    if (MaxDps:CheckSpellUsable(classtable.KegSmash, 'KegSmash')) and ((talents[classtable.ScaldingBrew] and true or false)) and cooldown[classtable.KegSmash].ready then
        if not setSpell then setSpell = classtable.KegSmash end
    end
    if (MaxDps:CheckSpellUsable(classtable.SpinningCraneKick, 'SpinningCraneKick')) and ((talents[classtable.CharredPassions] and true or false) and (talents[classtable.ScaldingBrew] and true or false) and buff[classtable.CharredPassionsBuff].up and buff[classtable.CharredPassionsBuff].remains <3 and debuff[classtable.BreathofFireDeBuff].remains <9 and targets >4) and cooldown[classtable.SpinningCraneKick].ready then
        if not setSpell then setSpell = classtable.SpinningCraneKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.RisingSunKick, 'RisingSunKick')) and ((talents[classtable.FluidityofMotion] and true or false)) and cooldown[classtable.RisingSunKick].ready then
        if not setSpell then setSpell = classtable.RisingSunKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.PurifyingBrew, 'PurifyingBrew')) and (not buff[classtable.BlackoutComboBuff].up) and cooldown[classtable.PurifyingBrew].ready then
        MaxDps:GlowCooldown(classtable.PurifyingBrew, cooldown[classtable.PurifyingBrew].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.BreathofFire, 'BreathofFire')) and ((not buff[classtable.CharredPassionsBuff].up and (not (talents[classtable.ScaldingBrew] and true or false) or targets <5)) or not (talents[classtable.CharredPassions] and true or false) or (debuff[classtable.BreathofFireDeBuff].remains <3 and (talents[classtable.ScaldingBrew] and true or false))) and cooldown[classtable.BreathofFire].ready then
        if not setSpell then setSpell = classtable.BreathofFire end
    end
    if (MaxDps:CheckSpellUsable(classtable.ExplodingKeg, 'ExplodingKeg')) and cooldown[classtable.ExplodingKeg].ready then
        if not setSpell then setSpell = classtable.ExplodingKeg end
    end
    if (MaxDps:CheckSpellUsable(classtable.KegSmash, 'KegSmash')) and cooldown[classtable.KegSmash].ready then
        if not setSpell then setSpell = classtable.KegSmash end
    end
    if (MaxDps:CheckSpellUsable(classtable.RushingJadeWind, 'RushingJadeWind')) and cooldown[classtable.RushingJadeWind].ready then
        if not setSpell then setSpell = classtable.RushingJadeWind end
    end
    if (MaxDps:CheckSpellUsable(classtable.InvokeNiuzao, 'InvokeNiuzao')) and cooldown[classtable.InvokeNiuzao].ready then
        if not setSpell then setSpell = classtable.InvokeNiuzao end
    end
    if (MaxDps:CheckSpellUsable(classtable.TigerPalm, 'TigerPalm')) and (Energy >40-cooldown[classtable.KegSmash].remains * EnergyRegen) and cooldown[classtable.TigerPalm].ready then
        if not setSpell then setSpell = classtable.TigerPalm end
    end
    if (MaxDps:CheckSpellUsable(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (Energy >40-cooldown[classtable.KegSmash].remains * EnergyRegen) and cooldown[classtable.SpinningCraneKick].ready then
        if not setSpell then setSpell = classtable.SpinningCraneKick end
    end
end
function Monk:Brewmaster()
    fd = MaxDps.FrameData
    ttd = (fd.timeToDie and fd.timeToDie) or 500
    timeShift = fd.timeShift
    gcd = fd.gcd
    cooldown = fd.cooldown
    buff = fd.buff
    debuff = fd.debuff
    talents = fd.talents
    targets = MaxDps:SmartAoe()
    targetHP = UnitHealth('target')
    targetmaxHP = UnitHealthMax('target')
    targethealthPerc = (targetHP >0 and targetmaxHP >0 and (targetHP / targetmaxHP) * 100) or 100
    curentHP = UnitHealth('player')
    maxHP = UnitHealthMax('player')
    healthPerc = (curentHP / maxHP) * 100
    timeInCombat = MaxDps.combatTime or 0
    classtable = MaxDps.SpellTable
    local trinket1ID = GetInventoryItemID('player', 13)
    local trinket2ID = GetInventoryItemID('player', 14)
    local MHID = GetInventoryItemID('player', 16)
    classtable.trinket1 = (trinket1ID and select(2,GetItemSpell(trinket1ID)) ) or 0
    classtable.trinket2 = (trinket2ID and select(2,GetItemSpell(trinket2ID)) ) or 0
    classtable.main_hand = (MHID and select(2,GetItemSpell(MHID)) ) or 0
    Energy = UnitPower('player', EnergyPT)
    EnergyMax = UnitPowerMax('player', EnergyPT)
    EnergyDeficit = EnergyMax - Energy
    EnergyPerc = (Energy / EnergyMax) * 100
    EnergyRegen = GetPowerRegenForPowerType(EnergyPT)
    EnergyTimeToMax = EnergyDeficit / EnergyRegen
    Chi = UnitPower('player', ChiPT)
    ChiMax = UnitPowerMax('player', ChiPT)
    ChiDeficit = ChiMax - Chi
    ChiPerc = (Chi / ChiMax) * 100
    ChiRegen = GetPowerRegenForPowerType(ChiPT)
    ChiTimeToMax = ChiDeficit / ChiRegen
    Mana = UnitPower('player', ManaPT)
    ManaMax = UnitPowerMax('player', ManaPT)
    ManaDeficit = ManaMax - Mana
    ManaPerc = (Mana / ManaMax) * 100
    ManaRegen = GetPowerRegenForPowerType(ManaPT)
    ManaTimeToMax = ManaDeficit / ManaRegen
    SpellHaste = UnitSpellHaste('player')
    SpellCrit = GetCritChance()
    staggerAmount = UnitStagger('player')
    staggerPercent = (staggerAmount / maxHP) * 100
    WoOLastUsed = 0
    --for spellId in pairs(MaxDps.Flags) do
    --    self.Flags[spellId] = false
    --    self:ClearGlowIndependent(spellId, spellId)
    --end
    classtable.VivaciousVivificationBuff = 392883
    classtable.PurifiedChiBuff = 325092
    classtable.CelestialBrewBuff = 322507
    classtable.BlackoutComboBuff = 228563
    classtable.FortifyingBrewBuff = 120954
    classtable.DampenHarmBuff = 122278
    classtable.GiftoftheOxBuff = 124502
    classtable.AspectofHarmonyAccumulatorBuff = 450521
    classtable.WeaponsofOrderBuff = 387184
    classtable.CharredPassionsBuff = 386963
    classtable.AspectofHarmonyDamageDeBuff = 450763
    classtable.BreathofFireDeBuff = 123725
    classtable.InvokeNiuzao = 322740

    local function debugg()
        talents[classtable.ChiBurst] = 1
        talents[classtable.ImprovedCelestialBrew] = 1
        talents[classtable.WeaponsofOrder] = 1
        talents[classtable.FluidityofMotion] = 1
        talents[classtable.ScaldingBrew] = 1
        talents[classtable.CharredPassions] = 1
    end


    --if MaxDps.db.global.debugMode then
    --   debugg()
    --end

    setSpell = nil
    ClearCDs()

    Brewmaster:precombat()

    Brewmaster:callaction()
    if setSpell then return setSpell end
end
