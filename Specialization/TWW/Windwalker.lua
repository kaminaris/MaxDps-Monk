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

local Windwalker = {}

local sef_condition = false
local xuen_condition = false


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



function Windwalker:precombat()
    if (MaxDps:CheckSpellUsable(classtable.imperfect_ascendancy_serum, 'imperfect_ascendancy_serum')) and cooldown[classtable.imperfect_ascendancy_serum].ready and not UnitAffectingCombat('player') then
        MaxDps:GlowCooldown(classtable.imperfect_ascendancy_serum, cooldown[classtable.imperfect_ascendancy_serum].ready)
    end
    sef_condition = ttd >6 and (not cooldown[classtable.RisingSunKick].ready or targets >2 or not talents[classtable.OrderedElements]) and (MaxDps:CheckPrevSpell(classtable.InvokeXuentheWhiteTiger) or (talents[classtable.CelestialConduit] or not talents[classtable.LastEmperorsCapacitor]) and MaxDps:Bloodlust(1) and (cooldown[classtable.StrikeoftheWindlord].remains <5 or not talents[classtable.StrikeoftheWindlord]) and talents[classtable.SequencedStrikes] or buff[classtable.InvokersDelightBuff].remains >15 or (cooldown[classtable.StrikeoftheWindlord].remains <5 or not talents[classtable.StrikeoftheWindlord]) and cooldown[classtable.StormEarthandFire].fullRecharge <cooldown[classtable.InvokeXuentheWhiteTiger].remains and cooldown[classtable.FistsofFury].remains <5 and (not talents[classtable.LastEmperorsCapacitor] or talents[classtable.CelestialConduit]) or talents[classtable.LastEmperorsCapacitor] and buff[classtable.TheEmperorsCapacitorBuff].count >17 and cooldown[classtable.InvokeXuentheWhiteTiger].remains >cooldown[classtable.StormEarthandFire].fullRecharge) or MaxDps:boss() and ttd <30 or buff[classtable.InvokersDelightBuff].remains >15 and (not cooldown[classtable.RisingSunKick].ready or targets >2 or not talents[classtable.OrderedElements]) or MaxDps:boss() and MaxDps:Bloodlust(1) and (not cooldown[classtable.RisingSunKick].ready or targets >2 or not talents[classtable.OrderedElements]) and talents[classtable.CelestialConduit] and timeInCombat >10
    xuen_condition = (targets == 1 and (timeInCombat <10 or talents[classtable.XuensBond] and talents[classtable.CelestialConduit]) or targets >1) and cooldown[classtable.StormEarthandFire].ready and (ttd >14) and (targets >2 or debuff[classtable.AcclamationDeBuff].up or not talents[classtable.OrderedElements] and timeInCombat <5) and (Chi >2 and talents[classtable.OrderedElements] or Chi >5 or Chi >3 and Energy <50 or Energy <50 and targets == 1 or MaxDps:CheckPrevSpell(classtable.TigerPalm) and not talents[classtable.OrderedElements] and timeInCombat <5) or MaxDps:boss() and ttd <30
end
function Windwalker:aoe_opener()
    if (MaxDps:CheckSpellUsable(classtable.SlicingWinds, 'SlicingWinds') and talents[classtable.SlicingWinds]) and cooldown[classtable.SlicingWinds].ready then
        if not setSpell then setSpell = classtable.SlicingWinds end
    end
    if (MaxDps:CheckSpellUsable(classtable.TigerPalm, 'TigerPalm')) and (Chi <6 and (IsComboStrike(classtable.TigerPalm) or not talents[classtable.HitCombo])) and cooldown[classtable.TigerPalm].ready then
        if not setSpell then setSpell = classtable.TigerPalm end
    end
end
function Windwalker:cooldowns()
    if (MaxDps:CheckSpellUsable(classtable.TigerPalm, 'TigerPalm')) and ((ttd >14) and cooldown[classtable.InvokeXuentheWhiteTiger].ready and (Chi <5 and not talents[classtable.OrderedElements] or Chi <3) and (IsComboStrike(classtable.TigerPalm) or not talents[classtable.HitCombo])) and cooldown[classtable.TigerPalm].ready then
        if not setSpell then setSpell = classtable.TigerPalm end
    end
    if (MaxDps:CheckSpellUsable(classtable.InvokeXuentheWhiteTiger, 'InvokeXuentheWhiteTiger') and talents[classtable.InvokeXuentheWhiteTiger]) and (xuen_condition) and cooldown[classtable.InvokeXuentheWhiteTiger].ready then
        MaxDps:GlowCooldown(classtable.InvokeXuentheWhiteTiger, cooldown[classtable.InvokeXuentheWhiteTiger].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.StormEarthandFire, 'StormEarthandFire') and talents[classtable.StormEarthandFire]) and (sef_condition) and cooldown[classtable.StormEarthandFire].ready then
        MaxDps:GlowCooldown(classtable.StormEarthandFire, cooldown[classtable.StormEarthandFire].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.TouchofKarma, 'TouchofKarma')) and cooldown[classtable.TouchofKarma].ready then
        MaxDps:GlowCooldown(classtable.TouchofKarma, cooldown[classtable.TouchofKarma].ready)
    end
end
function Windwalker:default_aoe()
    if (MaxDps:CheckSpellUsable(classtable.TigerPalm, 'TigerPalm')) and ((Energy >55 and talents[classtable.InnerPeace] or Energy >60 and not talents[classtable.InnerPeace]) and IsComboStrike(classtable.TigerPalm) and ChiMax - Chi>=2 and buff[classtable.TeachingsoftheMonasteryBuff].count <buff[classtable.TeachingsoftheMonasteryBuff].maxStacks and (talents[classtable.EnergyBurst] and not buff[classtable.BokProcBuff].up) and not buff[classtable.OrderedElementsBuff].up or (talents[classtable.EnergyBurst] and not buff[classtable.BokProcBuff].up) and not buff[classtable.OrderedElementsBuff].up and cooldown[classtable.FistsofFury].ready and Chi <3 or (MaxDps:CheckPrevSpell(classtable.StrikeoftheWindlord) or not cooldown[classtable.StrikeoftheWindlord].ready) and cooldown[classtable.CelestialConduit].remains <2 and buff[classtable.OrderedElementsBuff].up and Chi <5 and IsComboStrike(classtable.TigerPalm)) and cooldown[classtable.TigerPalm].ready then
        if not setSpell then setSpell = classtable.TigerPalm end
    end
    if (MaxDps:CheckSpellUsable(classtable.TouchofDeath, 'TouchofDeath')) and (not buff[classtable.HeartoftheJadeSerpentCdrBuff].up and not buff[classtable.HeartoftheJadeSerpentCdrCelestialBuff].up) and cooldown[classtable.TouchofDeath].ready then
        if not setSpell then setSpell = classtable.TouchofDeath end
    end
    if (MaxDps:CheckSpellUsable(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (IsComboStrike(classtable.SpinningCraneKick) and ((buff[classtable.ChiEnergyBuff].count >29 and cooldown[classtable.FistsofFury].remains <5) or (buff[classtable.DanceofChijiBuff].count == 2))) and cooldown[classtable.SpinningCraneKick].ready then
        if not setSpell then setSpell = classtable.SpinningCraneKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.WhirlingDragonPunch, 'WhirlingDragonPunch')) and (buff[classtable.HeartoftheJadeSerpentCdrBuff].up and buff[classtable.DanceofChijiBuff].count <2) and cooldown[classtable.WhirlingDragonPunch].ready then
        if not setSpell then setSpell = classtable.WhirlingDragonPunch end
    end
    if (MaxDps:CheckSpellUsable(classtable.WhirlingDragonPunch, 'WhirlingDragonPunch')) and (buff[classtable.DanceofChijiBuff].count <2) and cooldown[classtable.WhirlingDragonPunch].ready then
        if not setSpell then setSpell = classtable.WhirlingDragonPunch end
    end
    if (MaxDps:CheckSpellUsable(classtable.SlicingWinds, 'SlicingWinds') and talents[classtable.SlicingWinds]) and (buff[classtable.HeartoftheJadeSerpentCdrBuff].up or buff[classtable.HeartoftheJadeSerpentCdrCelestialBuff].up) and cooldown[classtable.SlicingWinds].ready then
        if not setSpell then setSpell = classtable.SlicingWinds end
    end
    if (MaxDps:CheckSpellUsable(classtable.CelestialConduit, 'CelestialConduit') and talents[classtable.CelestialConduit]) and (buff[classtable.StormEarthandFireBuff].up and not cooldown[classtable.StrikeoftheWindlord].ready and (not buff[classtable.HeartoftheJadeSerpentCdrBuff].up or debuff[classtable.GaleForceDeBuff].remains <5) and (talents[classtable.XuensBond] or not talents[classtable.XuensBond] and buff[classtable.InvokersDelightBuff].up) or MaxDps:boss() and ttd <15) and cooldown[classtable.CelestialConduit].ready then
        if not setSpell then setSpell = classtable.CelestialConduit end
    end
    if (MaxDps:CheckSpellUsable(classtable.RisingSunKick, 'RisingSunKick')) and (cooldown[classtable.WhirlingDragonPunch].remains <2 and cooldown[classtable.FistsofFury].remains >1 and buff[classtable.DanceofChijiBuff].count <2 or not buff[classtable.StormEarthandFireBuff].up and buff[classtable.PressurePointBuff].up) and cooldown[classtable.RisingSunKick].ready then
        if not setSpell then setSpell = classtable.RisingSunKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.WhirlingDragonPunch, 'WhirlingDragonPunch')) and (not talents[classtable.RevolvingWhirl] or talents[classtable.RevolvingWhirl] and buff[classtable.DanceofChijiBuff].count <2 and targets >2) and cooldown[classtable.WhirlingDragonPunch].ready then
        if not setSpell then setSpell = classtable.WhirlingDragonPunch end
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and buff[classtable.BokProcBuff].up and Chi <2 and talents[classtable.EnergyBurst] and Energy <55) and cooldown[classtable.BlackoutKick].ready then
        if not setSpell then setSpell = classtable.BlackoutKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord') and talents[classtable.StrikeoftheWindlord]) and ((timeInCombat >5 or buff[classtable.InvokersDelightBuff].up and buff[classtable.StormEarthandFireBuff].up) and (cooldown[classtable.InvokeXuentheWhiteTiger].remains >15 or talents[classtable.FlurryStrikes])) and cooldown[classtable.StrikeoftheWindlord].ready then
        if not setSpell then setSpell = classtable.StrikeoftheWindlord end
    end
    if (MaxDps:CheckSpellUsable(classtable.SlicingWinds, 'SlicingWinds') and talents[classtable.SlicingWinds]) and cooldown[classtable.SlicingWinds].ready then
        if not setSpell then setSpell = classtable.SlicingWinds end
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.TeachingsoftheMonasteryBuff].count == 8 and talents[classtable.ShadowboxingTreads]) and cooldown[classtable.BlackoutKick].ready then
        if not setSpell then setSpell = classtable.BlackoutKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.CracklingJadeLightning, 'CracklingJadeLightning')) and (buff[classtable.TheEmperorsCapacitorBuff].count >19 and IsComboStrike(classtable.CracklingJadeLightning) and talents[classtable.PoweroftheThunderKing] and cooldown[classtable.InvokeXuentheWhiteTiger].remains >10) and cooldown[classtable.CracklingJadeLightning].ready then
        if not setSpell then setSpell = classtable.CracklingJadeLightning end
    end
    if (MaxDps:CheckSpellUsable(classtable.FistsofFury, 'FistsofFury')) and ((talents[classtable.FlurryStrikes] or talents[classtable.XuensBattlegear] and (cooldown[classtable.InvokeXuentheWhiteTiger].remains >5 and MaxDps:boss() or cooldown[classtable.InvokeXuentheWhiteTiger].remains >9) or cooldown[classtable.InvokeXuentheWhiteTiger].remains >10)) and cooldown[classtable.FistsofFury].ready then
        if not setSpell then setSpell = classtable.FistsofFury end
    end
    if (MaxDps:CheckSpellUsable(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and EnergyTimeToMax <= gcd*3 and talents[classtable.FlurryStrikes] and buff[classtable.WisdomoftheWallFlurryBuff].up and Chi <6) and cooldown[classtable.TigerPalm].ready then
        if not setSpell then setSpell = classtable.TigerPalm end
    end
    if (MaxDps:CheckSpellUsable(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (IsComboStrike(classtable.SpinningCraneKick) and Chi >5) and cooldown[classtable.SpinningCraneKick].ready then
        if not setSpell then setSpell = classtable.SpinningCraneKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and buff[classtable.ChiEnergyBuff].count >29 and cooldown[classtable.FistsofFury].remains <5) and cooldown[classtable.SpinningCraneKick].ready then
        if not setSpell then setSpell = classtable.SpinningCraneKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.PressurePointBuff].up and cooldown[classtable.FistsofFury].remains >2) and cooldown[classtable.RisingSunKick].ready then
        if not setSpell then setSpell = classtable.RisingSunKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and (talents[classtable.ShadowboxingTreads] and talents[classtable.CourageousImpulse] and IsComboStrike(classtable.BlackoutKick) and buff[classtable.BokProcBuff].count == 2) and cooldown[classtable.BlackoutKick].ready then
        if not setSpell then setSpell = classtable.BlackoutKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        if not setSpell then setSpell = classtable.SpinningCraneKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.OrderedElementsBuff].up and talents[classtable.CraneVortex] and targets >2) and cooldown[classtable.SpinningCraneKick].ready then
        if not setSpell then setSpell = classtable.SpinningCraneKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and EnergyTimeToMax <= gcd*3 and talents[classtable.FlurryStrikes] and buff[classtable.OrderedElementsBuff].up) and cooldown[classtable.TigerPalm].ready then
        if not setSpell then setSpell = classtable.TigerPalm end
    end
    if (MaxDps:CheckSpellUsable(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and ChiDeficit >= 2 and (not buff[classtable.OrderedElementsBuff].up or EnergyTimeToMax <= gcd*3)) and cooldown[classtable.TigerPalm].ready then
        if not setSpell then setSpell = classtable.TigerPalm end
    end
    if (MaxDps:CheckSpellUsable(classtable.JadefireStomp, 'JadefireStomp')) and (talents[classtable.SingularlyFocusedJade] or talents[classtable.JadefireHarmony]) and cooldown[classtable.JadefireStomp].ready then
        if not setSpell then setSpell = classtable.JadefireStomp end
    end
    if (MaxDps:CheckSpellUsable(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.OrderedElementsBuff].up and talents[classtable.CraneVortex] and targets >2 and Chi >4) and cooldown[classtable.SpinningCraneKick].ready then
        if not setSpell then setSpell = classtable.SpinningCraneKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and not cooldown[classtable.FistsofFury].ready and (buff[classtable.TeachingsoftheMonasteryBuff].count >3 or buff[classtable.OrderedElementsBuff].up) and (talents[classtable.ShadowboxingTreads] or buff[classtable.BokProcBuff].up)) and cooldown[classtable.BlackoutKick].ready then
        if not setSpell then setSpell = classtable.BlackoutKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and cooldown[classtable.FistsofFury].ready and Chi <3) and cooldown[classtable.BlackoutKick].ready then
        if not setSpell then setSpell = classtable.BlackoutKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and (talents[classtable.ShadowboxingTreads] and talents[classtable.CourageousImpulse] and IsComboStrike(classtable.BlackoutKick) and buff[classtable.BokProcBuff].up) and cooldown[classtable.BlackoutKick].ready then
        if not setSpell then setSpell = classtable.BlackoutKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (IsComboStrike(classtable.SpinningCraneKick) and (Chi >3 or Energy >55)) and cooldown[classtable.SpinningCraneKick].ready then
        if not setSpell then setSpell = classtable.SpinningCraneKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and (buff[classtable.OrderedElementsBuff].up or buff[classtable.BokProcBuff].up and ChiDeficit >= 1 and talents[classtable.EnergyBurst]) and not cooldown[classtable.FistsofFury].ready) and cooldown[classtable.BlackoutKick].ready then
        if not setSpell then setSpell = classtable.BlackoutKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and not cooldown[classtable.FistsofFury].ready and (Chi >2 or Energy >60 or buff[classtable.BokProcBuff].up)) and cooldown[classtable.BlackoutKick].ready then
        if not setSpell then setSpell = classtable.BlackoutKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.JadefireStomp, 'JadefireStomp')) and cooldown[classtable.JadefireStomp].ready then
        if not setSpell then setSpell = classtable.JadefireStomp end
    end
    if (MaxDps:CheckSpellUsable(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and buff[classtable.OrderedElementsBuff].up and ChiDeficit >= 1) and cooldown[classtable.TigerPalm].ready then
        if not setSpell then setSpell = classtable.TigerPalm end
    end
    if (MaxDps:CheckSpellUsable(classtable.ChiBurst, 'ChiBurst')) and (not buff[classtable.OrderedElementsBuff].up) and cooldown[classtable.ChiBurst].ready then
        MaxDps:GlowCooldown(classtable.ChiBurst, cooldown[classtable.ChiBurst].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.ChiBurst, 'ChiBurst')) and cooldown[classtable.ChiBurst].ready then
        MaxDps:GlowCooldown(classtable.ChiBurst, cooldown[classtable.ChiBurst].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.OrderedElementsBuff].up and talents[classtable.HitCombo]) and cooldown[classtable.SpinningCraneKick].ready then
        if not setSpell then setSpell = classtable.SpinningCraneKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.OrderedElementsBuff].up and not talents[classtable.HitCombo] and not cooldown[classtable.FistsofFury].ready) and cooldown[classtable.BlackoutKick].ready then
        if not setSpell then setSpell = classtable.BlackoutKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.TigerPalm, 'TigerPalm')) and (not IsComboStrike(classtable.TigerPalm) and Chi <3 and not cooldown[classtable.FistsofFury].remains) and cooldown[classtable.TigerPalm].ready then
        if not setSpell then setSpell = classtable.TigerPalm end
    end
end
function Windwalker:default_cleave()
    if (MaxDps:CheckSpellUsable(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (buff[classtable.DanceofChijiBuff].count == 2 and IsComboStrike(classtable.SpinningCraneKick)) and cooldown[classtable.SpinningCraneKick].ready then
        if not setSpell then setSpell = classtable.SpinningCraneKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.RisingSunKick, 'RisingSunKick')) and ((buff[classtable.PressurePointBuff].up and targets <4 and cooldown[classtable.FistsofFury].remains >4) or (cooldown[classtable.WhirlingDragonPunch].remains <2 and cooldown[classtable.FistsofFury].remains >1 and buff[classtable.DanceofChijiBuff].count <2)) and cooldown[classtable.RisingSunKick].ready then
        if not setSpell then setSpell = classtable.RisingSunKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].count == 2 and targets >3) and cooldown[classtable.SpinningCraneKick].ready then
        if not setSpell then setSpell = classtable.SpinningCraneKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.TigerPalm, 'TigerPalm')) and ((Energy >55 and talents[classtable.InnerPeace] or Energy >60 and not talents[classtable.InnerPeace]) and IsComboStrike(classtable.TigerPalm) and ChiMax - Chi>=2 and buff[classtable.TeachingsoftheMonasteryBuff].count <buff[classtable.TeachingsoftheMonasteryBuff].maxStacks and (talents[classtable.EnergyBurst] and not buff[classtable.BokProcBuff].up or not talents[classtable.EnergyBurst]) and not buff[classtable.OrderedElementsBuff].up or (talents[classtable.EnergyBurst] and not buff[classtable.BokProcBuff].up or not talents[classtable.EnergyBurst]) and not buff[classtable.OrderedElementsBuff].up and cooldown[classtable.FistsofFury].ready and Chi <3 or (MaxDps:CheckPrevSpell(classtable.StrikeoftheWindlord) or not cooldown[classtable.StrikeoftheWindlord].ready) and cooldown[classtable.CelestialConduit].remains <2 and buff[classtable.OrderedElementsBuff].up and Chi <5 and IsComboStrike(classtable.TigerPalm) or (not buff[classtable.HeartoftheJadeSerpentCdrBuff].up or not buff[classtable.HeartoftheJadeSerpentCdrCelestialBuff].up) and IsComboStrike(classtable.TigerPalm) and ChiDeficit >= 2 and not buff[classtable.OrderedElementsBuff].up) and cooldown[classtable.TigerPalm].ready then
        if not setSpell then setSpell = classtable.TigerPalm end
    end
    if (MaxDps:CheckSpellUsable(classtable.TouchofDeath, 'TouchofDeath')) and (not buff[classtable.HeartoftheJadeSerpentCdrBuff].up and not buff[classtable.HeartoftheJadeSerpentCdrCelestialBuff].up) and cooldown[classtable.TouchofDeath].ready then
        if not setSpell then setSpell = classtable.TouchofDeath end
    end
    if (MaxDps:CheckSpellUsable(classtable.WhirlingDragonPunch, 'WhirlingDragonPunch')) and (buff[classtable.HeartoftheJadeSerpentCdrBuff].up and buff[classtable.DanceofChijiBuff].count <2) and cooldown[classtable.WhirlingDragonPunch].ready then
        if not setSpell then setSpell = classtable.WhirlingDragonPunch end
    end
    if (MaxDps:CheckSpellUsable(classtable.WhirlingDragonPunch, 'WhirlingDragonPunch')) and (buff[classtable.DanceofChijiBuff].count <2) and cooldown[classtable.WhirlingDragonPunch].ready then
        if not setSpell then setSpell = classtable.WhirlingDragonPunch end
    end
    if (MaxDps:CheckSpellUsable(classtable.SlicingWinds, 'SlicingWinds') and talents[classtable.SlicingWinds]) and (buff[classtable.HeartoftheJadeSerpentCdrBuff].up or buff[classtable.HeartoftheJadeSerpentCdrCelestialBuff].up) and cooldown[classtable.SlicingWinds].ready then
        if not setSpell then setSpell = classtable.SlicingWinds end
    end
    if (MaxDps:CheckSpellUsable(classtable.CelestialConduit, 'CelestialConduit') and talents[classtable.CelestialConduit]) and (buff[classtable.StormEarthandFireBuff].up and not cooldown[classtable.StrikeoftheWindlord].ready and (not buff[classtable.HeartoftheJadeSerpentCdrBuff].up or debuff[classtable.GaleForceDeBuff].remains <5) and (talents[classtable.XuensBond] or not talents[classtable.XuensBond] and buff[classtable.InvokersDelightBuff].up) or MaxDps:boss() and ttd <15) and cooldown[classtable.CelestialConduit].ready then
        if not setSpell then setSpell = classtable.CelestialConduit end
    end
    if (MaxDps:CheckSpellUsable(classtable.RisingSunKick, 'RisingSunKick')) and (not ( UnitExists('pet') and UnitName('pet')  == 'Xuen' ) and MaxDps:CheckPrevSpell(classtable.TigerPalm) and timeInCombat <5 or buff[classtable.HeartoftheJadeSerpentCdrCelestialBuff].up and buff[classtable.PressurePointBuff].up and not cooldown[classtable.FistsofFury].ready and (talents[classtable.GloryoftheDawn] or targets <3)) and cooldown[classtable.RisingSunKick].ready then
        if not setSpell then setSpell = classtable.RisingSunKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.FistsofFury, 'FistsofFury')) and (buff[classtable.HeartoftheJadeSerpentCdrCelestialBuff].up) and cooldown[classtable.FistsofFury].ready then
        if not setSpell then setSpell = classtable.FistsofFury end
    end
    if (MaxDps:CheckSpellUsable(classtable.WhirlingDragonPunch, 'WhirlingDragonPunch')) and (buff[classtable.HeartoftheJadeSerpentCdrCelestialBuff].up) and cooldown[classtable.WhirlingDragonPunch].ready then
        if not setSpell then setSpell = classtable.WhirlingDragonPunch end
    end
    if (MaxDps:CheckSpellUsable(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord') and talents[classtable.StrikeoftheWindlord]) and (talents[classtable.GaleForce] and buff[classtable.InvokersDelightBuff].up and (MaxDps:Bloodlust(1) or not buff[classtable.HeartoftheJadeSerpentCdrCelestialBuff].up)) and cooldown[classtable.StrikeoftheWindlord].ready then
        if not setSpell then setSpell = classtable.StrikeoftheWindlord end
    end
    if (MaxDps:CheckSpellUsable(classtable.FistsofFury, 'FistsofFury')) and (buff[classtable.PowerInfusionBuff].up and MaxDps:Bloodlust(1)) and cooldown[classtable.FistsofFury].ready then
        if not setSpell then setSpell = classtable.FistsofFury end
    end
    if (MaxDps:CheckSpellUsable(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.PowerInfusionBuff].up and MaxDps:Bloodlust(1) and targets <3) and cooldown[classtable.RisingSunKick].ready then
        if not setSpell then setSpell = classtable.RisingSunKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.TeachingsoftheMonasteryBuff].count == 8 and (targets <3 or talents[classtable.ShadowboxingTreads])) and cooldown[classtable.BlackoutKick].ready then
        if not setSpell then setSpell = classtable.BlackoutKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.WhirlingDragonPunch, 'WhirlingDragonPunch')) and (not talents[classtable.RevolvingWhirl] or talents[classtable.RevolvingWhirl] and buff[classtable.DanceofChijiBuff].count <2 and targets >2 or targets <3) and cooldown[classtable.WhirlingDragonPunch].ready then
        if not setSpell then setSpell = classtable.WhirlingDragonPunch end
    end
    if (MaxDps:CheckSpellUsable(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord') and talents[classtable.StrikeoftheWindlord]) and (timeInCombat >5 and (cooldown[classtable.InvokeXuentheWhiteTiger].remains >15 or talents[classtable.FlurryStrikes]) and (cooldown[classtable.FistsofFury].remains <2 or cooldown[classtable.CelestialConduit].remains <10)) and cooldown[classtable.StrikeoftheWindlord].ready then
        if not setSpell then setSpell = classtable.StrikeoftheWindlord end
    end
    if (MaxDps:CheckSpellUsable(classtable.SlicingWinds, 'SlicingWinds') and talents[classtable.SlicingWinds]) and cooldown[classtable.SlicingWinds].ready then
        if not setSpell then setSpell = classtable.SlicingWinds end
    end
    if (MaxDps:CheckSpellUsable(classtable.CracklingJadeLightning, 'CracklingJadeLightning')) and (buff[classtable.TheEmperorsCapacitorBuff].count >19 and IsComboStrike(classtable.CracklingJadeLightning) and talents[classtable.PoweroftheThunderKing] and cooldown[classtable.InvokeXuentheWhiteTiger].remains >10) and cooldown[classtable.CracklingJadeLightning].ready then
        if not setSpell then setSpell = classtable.CracklingJadeLightning end
    end
    if (MaxDps:CheckSpellUsable(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].count == 2) and cooldown[classtable.SpinningCraneKick].ready then
        if not setSpell then setSpell = classtable.SpinningCraneKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and EnergyTimeToMax <= gcd*3 and talents[classtable.FlurryStrikes] and targets <5 and buff[classtable.WisdomoftheWallFlurryBuff].up and targets <4) and cooldown[classtable.TigerPalm].ready then
        if not setSpell then setSpell = classtable.TigerPalm end
    end
    if (MaxDps:CheckSpellUsable(classtable.FistsofFury, 'FistsofFury')) and ((talents[classtable.FlurryStrikes] or talents[classtable.XuensBattlegear] or not talents[classtable.XuensBattlegear] and (cooldown[classtable.StrikeoftheWindlord].remains >1 or buff[classtable.HeartoftheJadeSerpentCdrBuff].up or buff[classtable.HeartoftheJadeSerpentCdrCelestialBuff].up)) and (talents[classtable.FlurryStrikes] or talents[classtable.XuensBattlegear] and (cooldown[classtable.InvokeXuentheWhiteTiger].remains >5 and MaxDps:boss() or cooldown[classtable.InvokeXuentheWhiteTiger].remains >9) or cooldown[classtable.InvokeXuentheWhiteTiger].remains >10)) and cooldown[classtable.FistsofFury].ready then
        if not setSpell then setSpell = classtable.FistsofFury end
    end
    if (MaxDps:CheckSpellUsable(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and EnergyTimeToMax <= gcd*3 and talents[classtable.FlurryStrikes] and targets <5 and buff[classtable.WisdomoftheWallFlurryBuff].up) and cooldown[classtable.TigerPalm].ready then
        if not setSpell then setSpell = classtable.TigerPalm end
    end
    if (MaxDps:CheckSpellUsable(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and buff[classtable.ChiEnergyBuff].count >29) and cooldown[classtable.SpinningCraneKick].ready then
        if not setSpell then setSpell = classtable.SpinningCraneKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.RisingSunKick, 'RisingSunKick')) and (Chi >4 and (targets <3 or talents[classtable.GloryoftheDawn]) or Chi >2 and Energy >50 and (targets <3 or talents[classtable.GloryoftheDawn]) or cooldown[classtable.FistsofFury].remains >2 and (targets <3 or talents[classtable.GloryoftheDawn])) and cooldown[classtable.RisingSunKick].ready then
        if not setSpell then setSpell = classtable.RisingSunKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and (talents[classtable.ShadowboxingTreads] and talents[classtable.CourageousImpulse] and IsComboStrike(classtable.BlackoutKick) and buff[classtable.BokProcBuff].count == 2) and cooldown[classtable.BlackoutKick].ready then
        if not setSpell then setSpell = classtable.BlackoutKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.TeachingsoftheMonasteryBuff].count == 4 and not talents[classtable.KnowledgeoftheBrokenTemple] and talents[classtable.ShadowboxingTreads] and targets <3) and cooldown[classtable.BlackoutKick].ready then
        if not setSpell then setSpell = classtable.BlackoutKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        if not setSpell then setSpell = classtable.SpinningCraneKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and (talents[classtable.ShadowboxingTreads] and talents[classtable.CourageousImpulse] and IsComboStrike(classtable.BlackoutKick) and buff[classtable.BokProcBuff].up) and cooldown[classtable.BlackoutKick].ready then
        if not setSpell then setSpell = classtable.BlackoutKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and EnergyTimeToMax <= gcd*3 and talents[classtable.FlurryStrikes] and targets <5) and cooldown[classtable.TigerPalm].ready then
        if not setSpell then setSpell = classtable.TigerPalm end
    end
    if (MaxDps:CheckSpellUsable(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and ChiDeficit >= 2 and (not buff[classtable.OrderedElementsBuff].up or EnergyTimeToMax <= gcd*3)) and cooldown[classtable.TigerPalm].ready then
        if not setSpell then setSpell = classtable.TigerPalm end
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and not cooldown[classtable.FistsofFury].ready and buff[classtable.TeachingsoftheMonasteryBuff].count >3 and not cooldown[classtable.RisingSunKick].ready) and cooldown[classtable.BlackoutKick].ready then
        if not setSpell then setSpell = classtable.BlackoutKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.JadefireStomp, 'JadefireStomp')) and (talents[classtable.SingularlyFocusedJade] or talents[classtable.JadefireHarmony]) and cooldown[classtable.JadefireStomp].ready then
        if not setSpell then setSpell = classtable.JadefireStomp end
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and not cooldown[classtable.FistsofFury].ready and (buff[classtable.TeachingsoftheMonasteryBuff].count >3 or buff[classtable.OrderedElementsBuff].up) and (talents[classtable.ShadowboxingTreads] or buff[classtable.BokProcBuff].up or buff[classtable.OrderedElementsBuff].up)) and cooldown[classtable.BlackoutKick].ready then
        if not setSpell then setSpell = classtable.BlackoutKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.OrderedElementsBuff].up and talents[classtable.CraneVortex] and targets >2 and Chi >4) and cooldown[classtable.SpinningCraneKick].ready then
        if not setSpell then setSpell = classtable.SpinningCraneKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.ChiBurst, 'ChiBurst')) and (not buff[classtable.OrderedElementsBuff].up) and cooldown[classtable.ChiBurst].ready then
        MaxDps:GlowCooldown(classtable.ChiBurst, cooldown[classtable.ChiBurst].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and (buff[classtable.OrderedElementsBuff].up or buff[classtable.BokProcBuff].up and ChiDeficit >= 1 and talents[classtable.EnergyBurst]) and not cooldown[classtable.FistsofFury].ready) and cooldown[classtable.BlackoutKick].ready then
        if not setSpell then setSpell = classtable.BlackoutKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and not cooldown[classtable.FistsofFury].ready and (Chi >2 or Energy >60 or buff[classtable.BokProcBuff].up)) and cooldown[classtable.BlackoutKick].ready then
        if not setSpell then setSpell = classtable.BlackoutKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.JadefireStomp, 'JadefireStomp')) and cooldown[classtable.JadefireStomp].ready then
        if not setSpell then setSpell = classtable.JadefireStomp end
    end
    if (MaxDps:CheckSpellUsable(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and buff[classtable.OrderedElementsBuff].up and ChiDeficit >= 1) and cooldown[classtable.TigerPalm].ready then
        if not setSpell then setSpell = classtable.TigerPalm end
    end
    if (MaxDps:CheckSpellUsable(classtable.ChiBurst, 'ChiBurst')) and cooldown[classtable.ChiBurst].ready then
        MaxDps:GlowCooldown(classtable.ChiBurst, cooldown[classtable.ChiBurst].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.OrderedElementsBuff].up and talents[classtable.HitCombo]) and cooldown[classtable.SpinningCraneKick].ready then
        if not setSpell then setSpell = classtable.SpinningCraneKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.OrderedElementsBuff].up and not talents[classtable.HitCombo] and not cooldown[classtable.FistsofFury].ready) and cooldown[classtable.BlackoutKick].ready then
        if not setSpell then setSpell = classtable.BlackoutKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.TigerPalm, 'TigerPalm')) and (not IsComboStrike(classtable.TigerPalm) and Chi <3 and not cooldown[classtable.FistsofFury].remains) and cooldown[classtable.TigerPalm].ready then
        if not setSpell then setSpell = classtable.TigerPalm end
    end
end
function Windwalker:default_st()
    if (MaxDps:CheckSpellUsable(classtable.FistsofFury, 'FistsofFury')) and (buff[classtable.HeartoftheJadeSerpentCdrCelestialBuff].up or buff[classtable.HeartoftheJadeSerpentCdrBuff].up) and cooldown[classtable.FistsofFury].ready then
        if not setSpell then setSpell = classtable.FistsofFury end
    end
    if (MaxDps:CheckSpellUsable(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.PressurePointBuff].up and not buff[classtable.HeartoftheJadeSerpentCdrBuff].up and buff[classtable.HeartoftheJadeSerpentCdrCelestialBuff].up or buff[classtable.InvokersDelightBuff].up or MaxDps:Bloodlust(1) or buff[classtable.PressurePointBuff].up and not cooldown[classtable.FistsofFury].ready or buff[classtable.PowerInfusionBuff].up) and cooldown[classtable.RisingSunKick].ready then
        if not setSpell then setSpell = classtable.RisingSunKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.WhirlingDragonPunch, 'WhirlingDragonPunch')) and (not buff[classtable.HeartoftheJadeSerpentCdrCelestialBuff].up and not buff[classtable.DanceofChijiBuff].count == 2) and cooldown[classtable.WhirlingDragonPunch].ready then
        if not setSpell then setSpell = classtable.WhirlingDragonPunch end
    end
    if (MaxDps:CheckSpellUsable(classtable.SlicingWinds, 'SlicingWinds') and talents[classtable.SlicingWinds]) and (buff[classtable.HeartoftheJadeSerpentCdrBuff].up or buff[classtable.HeartoftheJadeSerpentCdrCelestialBuff].up) and cooldown[classtable.SlicingWinds].ready then
        if not setSpell then setSpell = classtable.SlicingWinds end
    end
    if (MaxDps:CheckSpellUsable(classtable.CelestialConduit, 'CelestialConduit') and talents[classtable.CelestialConduit]) and (buff[classtable.StormEarthandFireBuff].up and (not buff[classtable.HeartoftheJadeSerpentCdrBuff].up or debuff[classtable.GaleForceDeBuff].remains <5) and not cooldown[classtable.StrikeoftheWindlord].ready and (talents[classtable.XuensBond] or not talents[classtable.XuensBond] and buff[classtable.InvokersDelightBuff].up) or MaxDps:boss() and ttd <15) and cooldown[classtable.CelestialConduit].ready then
        if not setSpell then setSpell = classtable.CelestialConduit end
    end
    if (MaxDps:CheckSpellUsable(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (buff[classtable.DanceofChijiBuff].count == 2 and IsComboStrike(classtable.SpinningCraneKick)) and cooldown[classtable.SpinningCraneKick].ready then
        if not setSpell then setSpell = classtable.SpinningCraneKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.TigerPalm, 'TigerPalm')) and ((Energy >55 and talents[classtable.InnerPeace] or Energy >60 and not talents[classtable.InnerPeace]) and IsComboStrike(classtable.TigerPalm) and ChiMax - Chi>=2 and buff[classtable.TeachingsoftheMonasteryBuff].count <buff[classtable.TeachingsoftheMonasteryBuff].maxStacks and (talents[classtable.EnergyBurst] and not buff[classtable.BokProcBuff].up or not talents[classtable.EnergyBurst]) and not buff[classtable.OrderedElementsBuff].up) and cooldown[classtable.TigerPalm].ready then
        if not setSpell then setSpell = classtable.TigerPalm end
    end
    if (MaxDps:CheckSpellUsable(classtable.TigerPalm, 'TigerPalm')) and ((talents[classtable.EnergyBurst] and not buff[classtable.BokProcBuff].up or not talents[classtable.EnergyBurst]) and not buff[classtable.OrderedElementsBuff].up and cooldown[classtable.FistsofFury].ready and Chi <3) and cooldown[classtable.TigerPalm].ready then
        if not setSpell then setSpell = classtable.TigerPalm end
    end
    if (MaxDps:CheckSpellUsable(classtable.TigerPalm, 'TigerPalm')) and ((MaxDps:CheckPrevSpell(classtable.StrikeoftheWindlord) or not buff[classtable.HeartoftheJadeSerpentCdrCelestialBuff].up) and IsComboStrike(classtable.TigerPalm) and ChiDeficit >= 2 and not buff[classtable.OrderedElementsBuff].up) and cooldown[classtable.TigerPalm].ready then
        if not setSpell then setSpell = classtable.TigerPalm end
    end
    if (MaxDps:CheckSpellUsable(classtable.TouchofDeath, 'TouchofDeath')) and cooldown[classtable.TouchofDeath].ready then
        if not setSpell then setSpell = classtable.TouchofDeath end
    end
    if (MaxDps:CheckSpellUsable(classtable.RisingSunKick, 'RisingSunKick')) and (not ( UnitExists('pet') and UnitName('pet')  == 'Xuen' ) and MaxDps:CheckPrevSpell(classtable.TigerPalm) and timeInCombat <5 or buff[classtable.StormEarthandFireBuff].up and talents[classtable.OrderedElements]) and cooldown[classtable.RisingSunKick].ready then
        if not setSpell then setSpell = classtable.RisingSunKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord') and talents[classtable.StrikeoftheWindlord]) and (talents[classtable.CelestialConduit] and not buff[classtable.InvokersDelightBuff].up and not buff[classtable.HeartoftheJadeSerpentCdrCelestialBuff].up and cooldown[classtable.FistsofFury].remains <5 and cooldown[classtable.InvokeXuentheWhiteTiger].remains >15 or MaxDps:boss() and ttd <12) and cooldown[classtable.StrikeoftheWindlord].ready then
        if not setSpell then setSpell = classtable.StrikeoftheWindlord end
    end
    if (MaxDps:CheckSpellUsable(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord') and talents[classtable.StrikeoftheWindlord]) and (talents[classtable.GaleForce] and buff[classtable.InvokersDelightBuff].up and (MaxDps:Bloodlust(1) or not buff[classtable.HeartoftheJadeSerpentCdrCelestialBuff].up)) and cooldown[classtable.StrikeoftheWindlord].ready then
        if not setSpell then setSpell = classtable.StrikeoftheWindlord end
    end
    if (MaxDps:CheckSpellUsable(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord') and talents[classtable.StrikeoftheWindlord]) and (timeInCombat >5 and talents[classtable.FlurryStrikes]) and cooldown[classtable.StrikeoftheWindlord].ready then
        if not setSpell then setSpell = classtable.StrikeoftheWindlord end
    end
    if (MaxDps:CheckSpellUsable(classtable.FistsofFury, 'FistsofFury')) and (buff[classtable.PowerInfusionBuff].up and MaxDps:Bloodlust(1) and timeInCombat >5) and cooldown[classtable.FistsofFury].ready then
        if not setSpell then setSpell = classtable.FistsofFury end
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.TeachingsoftheMonasteryBuff].count >3 and buff[classtable.OrderedElementsBuff].up and cooldown[classtable.RisingSunKick].remains >1 and cooldown[classtable.FistsofFury].remains >2) and cooldown[classtable.BlackoutKick].ready then
        if not setSpell then setSpell = classtable.BlackoutKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and EnergyTimeToMax <= gcd*3 and talents[classtable.FlurryStrikes] and buff[classtable.PowerInfusionBuff].up and MaxDps:Bloodlust(1)) and cooldown[classtable.TigerPalm].ready then
        if not setSpell then setSpell = classtable.TigerPalm end
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.TeachingsoftheMonasteryBuff].count >4 and cooldown[classtable.RisingSunKick].remains >1 and cooldown[classtable.FistsofFury].remains >2) and cooldown[classtable.BlackoutKick].ready then
        if not setSpell then setSpell = classtable.BlackoutKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.WhirlingDragonPunch, 'WhirlingDragonPunch')) and (not buff[classtable.HeartoftheJadeSerpentCdrCelestialBuff].up and not buff[classtable.DanceofChijiBuff].count == 2 or buff[classtable.OrderedElementsBuff].up or talents[classtable.KnowledgeoftheBrokenTemple]) and cooldown[classtable.WhirlingDragonPunch].ready then
        if not setSpell then setSpell = classtable.WhirlingDragonPunch end
    end
    if (MaxDps:CheckSpellUsable(classtable.CracklingJadeLightning, 'CracklingJadeLightning')) and (buff[classtable.TheEmperorsCapacitorBuff].count >19 and not buff[classtable.HeartoftheJadeSerpentCdrBuff].up and not buff[classtable.HeartoftheJadeSerpentCdrCelestialBuff].up and IsComboStrike(classtable.CracklingJadeLightning) and cooldown[classtable.InvokeXuentheWhiteTiger].remains >10 or buff[classtable.TheEmperorsCapacitorBuff].count >15 and not buff[classtable.HeartoftheJadeSerpentCdrBuff].up and not buff[classtable.HeartoftheJadeSerpentCdrCelestialBuff].up and IsComboStrike(classtable.CracklingJadeLightning) and (MaxDps:boss() or ttd >20) and cooldown[classtable.InvokeXuentheWhiteTiger].remains <10 and cooldown[classtable.InvokeXuentheWhiteTiger].remains >2) and cooldown[classtable.CracklingJadeLightning].ready then
        if not setSpell then setSpell = classtable.CracklingJadeLightning end
    end
    if (MaxDps:CheckSpellUsable(classtable.SlicingWinds, 'SlicingWinds') and talents[classtable.SlicingWinds]) and (ttd >10) and cooldown[classtable.SlicingWinds].ready then
        if not setSpell then setSpell = classtable.SlicingWinds end
    end
    if (MaxDps:CheckSpellUsable(classtable.FistsofFury, 'FistsofFury')) and ((talents[classtable.XuensBattlegear] or not talents[classtable.XuensBattlegear] and (cooldown[classtable.StrikeoftheWindlord].remains >1 or buff[classtable.HeartoftheJadeSerpentCdrBuff].up or buff[classtable.HeartoftheJadeSerpentCdrCelestialBuff].up)) and (talents[classtable.XuensBattlegear] and cooldown[classtable.InvokeXuentheWhiteTiger].remains >5 or cooldown[classtable.InvokeXuentheWhiteTiger].remains >10) and (not buff[classtable.InvokersDelightBuff].up or buff[classtable.InvokersDelightBuff].up and cooldown[classtable.StrikeoftheWindlord].remains >4 and not cooldown[classtable.CelestialConduit].ready) or ttd <5 or talents[classtable.FlurryStrikes]) and cooldown[classtable.FistsofFury].ready then
        if not setSpell then setSpell = classtable.FistsofFury end
    end
    if (MaxDps:CheckSpellUsable(classtable.RisingSunKick, 'RisingSunKick')) and (Chi >4 or Chi >2 and Energy >50 or cooldown[classtable.FistsofFury].remains >2) and cooldown[classtable.RisingSunKick].ready then
        if not setSpell then setSpell = classtable.RisingSunKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and EnergyTimeToMax <= gcd*3 and talents[classtable.FlurryStrikes] and buff[classtable.WisdomoftheWallFlurryBuff].up) and cooldown[classtable.TigerPalm].ready then
        if not setSpell then setSpell = classtable.TigerPalm end
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and talents[classtable.EnergyBurst] and buff[classtable.BokProcBuff].up and Chi <5 and (buff[classtable.HeartoftheJadeSerpentCdrBuff].up or buff[classtable.HeartoftheJadeSerpentCdrCelestialBuff].up)) and cooldown[classtable.BlackoutKick].ready then
        if not setSpell then setSpell = classtable.BlackoutKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (IsComboStrike(classtable.SpinningCraneKick) and MaxDps:Bloodlust(1) and buff[classtable.HeartoftheJadeSerpentCdrBuff].up and buff[classtable.DanceofChijiBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        if not setSpell then setSpell = classtable.SpinningCraneKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and ChiDeficit >= 2 and EnergyTimeToMax <= gcd*3) and cooldown[classtable.TigerPalm].ready then
        if not setSpell then setSpell = classtable.TigerPalm end
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.TeachingsoftheMonasteryBuff].count >7 and talents[classtable.MemoryoftheMonastery] and not buff[classtable.MemoryoftheMonasteryBuff].up and not cooldown[classtable.FistsofFury].ready) and cooldown[classtable.BlackoutKick].ready then
        if not setSpell then setSpell = classtable.BlackoutKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.SpinningCraneKick, 'SpinningCraneKick')) and ((buff[classtable.DanceofChijiBuff].count == 2 or buff[classtable.DanceofChijiBuff].remains <2 and buff[classtable.DanceofChijiBuff].up) and IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.OrderedElementsBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        if not setSpell then setSpell = classtable.SpinningCraneKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.WhirlingDragonPunch, 'WhirlingDragonPunch')) and cooldown[classtable.WhirlingDragonPunch].ready then
        if not setSpell then setSpell = classtable.WhirlingDragonPunch end
    end
    if (MaxDps:CheckSpellUsable(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (buff[classtable.DanceofChijiBuff].count == 2 and IsComboStrike(classtable.SpinningCraneKick)) and cooldown[classtable.SpinningCraneKick].ready then
        if not setSpell then setSpell = classtable.SpinningCraneKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and (talents[classtable.CourageousImpulse] and IsComboStrike(classtable.BlackoutKick) and buff[classtable.BokProcBuff].count == 2) and cooldown[classtable.BlackoutKick].ready then
        if not setSpell then setSpell = classtable.BlackoutKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and buff[classtable.OrderedElementsBuff].up and cooldown[classtable.RisingSunKick].remains >1 and cooldown[classtable.FistsofFury].remains >2) and cooldown[classtable.BlackoutKick].ready then
        if not setSpell then setSpell = classtable.BlackoutKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and EnergyTimeToMax <= gcd*3 and talents[classtable.FlurryStrikes]) and cooldown[classtable.TigerPalm].ready then
        if not setSpell then setSpell = classtable.TigerPalm end
    end
    if (MaxDps:CheckSpellUsable(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and (buff[classtable.OrderedElementsBuff].up or EnergyTimeToMax >= gcd*3 and talents[classtable.SequencedStrikes] and talents[classtable.EnergyBurst] or not talents[classtable.SequencedStrikes] or not talents[classtable.EnergyBurst] or buff[classtable.DanceofChijiBuff].remains <= gcd*3)) and cooldown[classtable.SpinningCraneKick].ready then
        if not setSpell then setSpell = classtable.SpinningCraneKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and EnergyTimeToMax <= gcd*3 and talents[classtable.FlurryStrikes]) and cooldown[classtable.TigerPalm].ready then
        if not setSpell then setSpell = classtable.TigerPalm end
    end
    if (MaxDps:CheckSpellUsable(classtable.JadefireStomp, 'JadefireStomp')) and (talents[classtable.SingularlyFocusedJade] or talents[classtable.JadefireHarmony]) and cooldown[classtable.JadefireStomp].ready then
        if not setSpell then setSpell = classtable.JadefireStomp end
    end
    if (MaxDps:CheckSpellUsable(classtable.ChiBurst, 'ChiBurst')) and (not buff[classtable.OrderedElementsBuff].up) and cooldown[classtable.ChiBurst].ready then
        MaxDps:GlowCooldown(classtable.ChiBurst, cooldown[classtable.ChiBurst].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and (buff[classtable.OrderedElementsBuff].up or buff[classtable.BokProcBuff].up and ChiDeficit >= 1 and talents[classtable.EnergyBurst]) and not cooldown[classtable.FistsofFury].ready) and cooldown[classtable.BlackoutKick].ready then
        if not setSpell then setSpell = classtable.BlackoutKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and not cooldown[classtable.FistsofFury].ready and (Chi >2 or Energy >60 or buff[classtable.BokProcBuff].up)) and cooldown[classtable.BlackoutKick].ready then
        if not setSpell then setSpell = classtable.BlackoutKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.JadefireStomp, 'JadefireStomp')) and cooldown[classtable.JadefireStomp].ready then
        if not setSpell then setSpell = classtable.JadefireStomp end
    end
    if (MaxDps:CheckSpellUsable(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and buff[classtable.OrderedElementsBuff].up and ChiDeficit >= 1) and cooldown[classtable.TigerPalm].ready then
        if not setSpell then setSpell = classtable.TigerPalm end
    end
    if (MaxDps:CheckSpellUsable(classtable.ChiBurst, 'ChiBurst')) and cooldown[classtable.ChiBurst].ready then
        MaxDps:GlowCooldown(classtable.ChiBurst, cooldown[classtable.ChiBurst].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.OrderedElementsBuff].up and talents[classtable.HitCombo]) and cooldown[classtable.SpinningCraneKick].ready then
        if not setSpell then setSpell = classtable.SpinningCraneKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.OrderedElementsBuff].up and not talents[classtable.HitCombo] and not cooldown[classtable.FistsofFury].ready) and cooldown[classtable.BlackoutKick].ready then
        if not setSpell then setSpell = classtable.BlackoutKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.TigerPalm, 'TigerPalm')) and (MaxDps:CheckPrevSpell(classtable.TigerPalm) and Chi <3 and not cooldown[classtable.FistsofFury].remains) and cooldown[classtable.TigerPalm].ready then
        if not setSpell then setSpell = classtable.TigerPalm end
    end
end
function Windwalker:fallback()
    if (MaxDps:CheckSpellUsable(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (Chi >5 and IsComboStrike(classtable.SpinningCraneKick)) and cooldown[classtable.SpinningCraneKick].ready then
        if not setSpell then setSpell = classtable.SpinningCraneKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and Chi >3) and cooldown[classtable.BlackoutKick].ready then
        if not setSpell then setSpell = classtable.BlackoutKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and Chi >5) and cooldown[classtable.TigerPalm].ready then
        if not setSpell then setSpell = classtable.TigerPalm end
    end
end
function Windwalker:normal_opener()
    if (MaxDps:CheckSpellUsable(classtable.TigerPalm, 'TigerPalm')) and (Chi <6 and (IsComboStrike(classtable.TigerPalm) or not talents[classtable.HitCombo])) and cooldown[classtable.TigerPalm].ready then
        if not setSpell then setSpell = classtable.TigerPalm end
    end
    if (MaxDps:CheckSpellUsable(classtable.RisingSunKick, 'RisingSunKick')) and (talents[classtable.OrderedElements]) and cooldown[classtable.RisingSunKick].ready then
        if not setSpell then setSpell = classtable.RisingSunKick end
    end
end
function Windwalker:trinkets()
end


local function ClearCDs()
    MaxDps:GlowCooldown(classtable.imperfect_ascendancy_serum, false)
    MaxDps:GlowCooldown(classtable.SpearHandStrike, false)
    MaxDps:GlowCooldown(classtable.InvokeXuentheWhiteTiger, false)
    MaxDps:GlowCooldown(classtable.StormEarthandFire, false)
    MaxDps:GlowCooldown(classtable.TouchofKarma, false)
    MaxDps:GlowCooldown(classtable.ChiBurst, false)
    MaxDps:GlowCooldown(classtable.algethar_puzzle_box, false)
end

function Windwalker:callaction()
    if (MaxDps:CheckSpellUsable(classtable.SpearHandStrike, 'SpearHandStrike')) and cooldown[classtable.SpearHandStrike].ready then
        MaxDps:GlowCooldown(classtable.SpearHandStrike, ( select(8,UnitCastingInfo('target')) ~= nil and not select(8,UnitCastingInfo('target')) or select(7,UnitChannelInfo('target')) ~= nil and not select(7,UnitChannelInfo('target'))) )
    end
    Windwalker:trinkets()
    if (timeInCombat <3 and targets >2 and ChiDeficit >0) then
        Windwalker:aoe_opener()
    end
    if (timeInCombat <4 and targets <3 and ChiDeficit >0) then
        Windwalker:normal_opener()
    end
    if (talents[classtable.StormEarthandFire]) then
        Windwalker:cooldowns()
    end
    if (targets >= 5) then
        Windwalker:default_aoe()
    end
    if (targets >1 and (not MaxDps:boss() or ChiDeficit == 0 or timeInCombat >7 or not talents[classtable.CelestialConduit]) and targets <5) then
        Windwalker:default_cleave()
    end
    if (targets <2) then
        Windwalker:default_st()
    end
    Windwalker:fallback()
    if (MaxDps:CheckSpellUsable(classtable.Haymaker, 'Haymaker')) and (not buff[classtable.StormEarthandFireBuff].up) and cooldown[classtable.Haymaker].ready then
        if not setSpell then setSpell = classtable.Haymaker end
    end
    if (MaxDps:CheckSpellUsable(classtable.RocketBarrage, 'RocketBarrage')) and (not buff[classtable.StormEarthandFireBuff].up) and cooldown[classtable.RocketBarrage].ready then
        if not setSpell then setSpell = classtable.RocketBarrage end
    end
    if (MaxDps:CheckSpellUsable(classtable.ArcanePulse, 'ArcanePulse')) and (not buff[classtable.StormEarthandFireBuff].up) and cooldown[classtable.ArcanePulse].ready then
        if not setSpell then setSpell = classtable.ArcanePulse end
    end
end
function Monk:Windwalker()
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
    --for spellId in pairs(MaxDps.Flags) do
    --    self.Flags[spellId] = false
    --    self:ClearGlowIndependent(spellId, spellId)
    --end
    classtable.BloodlustBuff = 2825
    classtable.InvokersDelightBuff = 388663
    classtable.TheEmperorsCapacitorBuff = 393039
    classtable.StormEarthandFireBuff = 137639
    classtable.InvokeXuentheWhiteTigerBuff = 123904
    classtable.TeachingsoftheMonasteryBuff = 202090
    classtable.BokProcBuff = 116768
    classtable.OrderedElementsBuff = 451462
    classtable.HeartoftheJadeSerpentCdrBuff = 443421
    classtable.HeartoftheJadeSerpentCdrCelestialBuff = 443616
    classtable.ChiEnergyBuff = 393057
    classtable.DanceofChijiBuff = 325202
    classtable.PressurePointBuff = 393053
    classtable.WisdomoftheWallFlurryBuff = 452688
    classtable.PowerInfusionBuff = 10060
    classtable.MemoryoftheMonasteryBuff = 454970
    classtable.AcclamationDeBuff = 451433
    classtable.GaleForceDeBuff = 451582
    classtable.InvokeXuen = 123904
    classtable.ArcanePulse = 260369

    local function debugg()
        talents[classtable.InvokeXuen] = 1
        talents[classtable.StormEarthandFire] = 1
        talents[classtable.CelestialConduit] = 1
        talents[classtable.HitCombo] = 1
        talents[classtable.OrderedElements] = 1
        talents[classtable.InvokeXuentheWhiteTiger] = 1
        talents[classtable.StrikeoftheWindlord] = 1
        talents[classtable.InnerPeace] = 1
        talents[classtable.EnergyBurst] = 1
        talents[classtable.XuensBond] = 1
        talents[classtable.RevolvingWhirl] = 1
        talents[classtable.FlurryStrikes] = 1
        talents[classtable.ShadowboxingTreads] = 1
        talents[classtable.PoweroftheThunderKing] = 1
        talents[classtable.XuensBattlegear] = 1
        talents[classtable.CourageousImpulse] = 1
        talents[classtable.CraneVortex] = 1
        talents[classtable.SingularlyFocusedJade] = 1
        talents[classtable.JadefireHarmony] = 1
        talents[classtable.GloryoftheDawn] = 1
        talents[classtable.GaleForce] = 1
        talents[classtable.KnowledgeoftheBrokenTemple] = 1
        talents[classtable.MemoryoftheMonastery] = 1
        talents[classtable.SequencedStrikes] = 1
    end


    --if MaxDps.db.global.debugMode then
    --   debugg()
    --end

    setSpell = nil
    ClearCDs()

    Windwalker:precombat()

    Windwalker:callaction()
    if setSpell then return setSpell end
end
