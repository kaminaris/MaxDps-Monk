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

local Mistweaver = {}

local tea_up = false


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



function Mistweaver:precombat()
    if (MaxDps:CheckSpellUsable(classtable.ChiBurst, 'ChiBurst')) and cooldown[classtable.ChiBurst].ready and not UnitAffectingCombat('player') then
        MaxDps:GlowCooldown(classtable.ChiBurst, cooldown[classtable.ChiBurst].ready)
    end
    tea_up = buff[classtable.TeaofPlentyRskBuff].up or buff[classtable.TeaofPlentyEmBuff].up or buff[classtable.TeaofPlentyEhBuff].up or buff[classtable.TeaofSerenityEmBuff].up or buff[classtable.TeaofSerenityRmBuff].up or buff[classtable.TeaofSerenityVBuff].up or buff[classtable.ThunderFocusTeaBuff].up
end
function Mistweaver:focus_tea()
    if (MaxDps:CheckSpellUsable(classtable.RenewingMist, 'RenewingMist')) and ((MaxDps:GetPartyState() == 'raid') or buff[classtable.TeaofSerenityRmBuff].up) and cooldown[classtable.RenewingMist].ready then
        if not setSpell then setSpell = classtable.RenewingMist end
    end
    if (MaxDps:CheckSpellUsable(classtable.RisingSunKick, 'RisingSunKick')) and cooldown[classtable.RisingSunKick].ready then
        if not setSpell then setSpell = classtable.RisingSunKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.ExpelHarm, 'ExpelHarm')) and (buff[classtable.TeaofPlentyEhBuff].up) and cooldown[classtable.ExpelHarm].ready then
        MaxDps:GlowCooldown(classtable.ExpelHarm, cooldown[classtable.ExpelHarm].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.Vivify, 'Vivify')) and (buff[classtable.TeaofSerenityVBuff].up) and cooldown[classtable.Vivify].ready then
        MaxDps:GlowCooldown(classtable.Vivify, cooldown[classtable.Vivify].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.EnvelopingMist, 'EnvelopingMist')) and (buff[classtable.TeaofSerenityEmBuff].up or buff[classtable.TeaofPlentyEmBuff].up) and cooldown[classtable.EnvelopingMist].ready then
        if not setSpell then setSpell = classtable.EnvelopingMist end
    end
end
function Mistweaver:st()
    if (MaxDps:CheckSpellUsable(classtable.ThunderFocusTea, 'ThunderFocusTea')) and cooldown[classtable.ThunderFocusTea].ready then
        if not setSpell then setSpell = classtable.ThunderFocusTea end
    end
    if (MaxDps:CheckSpellUsable(classtable.RisingSunKick, 'RisingSunKick')) and cooldown[classtable.RisingSunKick].ready then
        if not setSpell then setSpell = classtable.RisingSunKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.RushingWindKick, 'RushingWindKick') and talents[classtable.RushingWindKick]) and cooldown[classtable.RushingWindKick].ready then
        if not setSpell then setSpell = classtable.RushingWindKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.TigerPalm, 'TigerPalm')) and ((talents[classtable.AwakenedJadefire] and true or false) and buff[classtable.JadefireStompBuff].up and buff[classtable.TeachingsoftheMonasteryBuff].count <4 or buff[classtable.TeachingsoftheMonasteryBuff].count <1) and cooldown[classtable.TigerPalm].ready then
        if not setSpell then setSpell = classtable.TigerPalm end
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and (((not talents[classtable.AwakenedJadefire] or not buff[classtable.JadefireStompBuff].up) and buff[classtable.TeachingsoftheMonasteryBuff].up or buff[classtable.TeachingsoftheMonasteryBuff].count >3) and (not talents[classtable.RushingWindKick] and cooldown[classtable.RisingSunKick].remains >2*gcd or cooldown[classtable.RushingWindKick].remains >2*gcd)) and cooldown[classtable.BlackoutKick].ready then
        if not setSpell then setSpell = classtable.BlackoutKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.Vivify, 'Vivify')) and (false and buff[classtable.ZenPulseBuff].up) and cooldown[classtable.Vivify].ready then
        MaxDps:GlowCooldown(classtable.Vivify, cooldown[classtable.Vivify].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.ChiBurst, 'ChiBurst')) and cooldown[classtable.ChiBurst].ready then
        MaxDps:GlowCooldown(classtable.ChiBurst, cooldown[classtable.ChiBurst].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.TigerPalm, 'TigerPalm')) and cooldown[classtable.TigerPalm].ready then
        if not setSpell then setSpell = classtable.TigerPalm end
    end
end
function Mistweaver:aoe()
    if (MaxDps:CheckSpellUsable(classtable.ThunderFocusTea, 'ThunderFocusTea')) and cooldown[classtable.ThunderFocusTea].ready then
        if not setSpell then setSpell = classtable.ThunderFocusTea end
    end
    if (MaxDps:CheckSpellUsable(classtable.CracklingJadeLightning, 'CracklingJadeLightning')) and (buff[classtable.JadeEmpowermentBuff].up and buff[classtable.JadefireTeachingsBuff].up) and cooldown[classtable.CracklingJadeLightning].ready then
        if not setSpell then setSpell = classtable.CracklingJadeLightning end
    end
    if (MaxDps:CheckSpellUsable(classtable.Vivify, 'Vivify')) and (buff[classtable.ZenPulseBuff].up) and cooldown[classtable.Vivify].ready then
        MaxDps:GlowCooldown(classtable.Vivify, cooldown[classtable.Vivify].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.RisingSunKick, 'RisingSunKick')) and (false) and cooldown[classtable.RisingSunKick].ready then
        if not setSpell then setSpell = classtable.RisingSunKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.RushingWindKick, 'RushingWindKick') and talents[classtable.RushingWindKick]) and (false) and cooldown[classtable.RushingWindKick].ready then
        if not setSpell then setSpell = classtable.RushingWindKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.SpinningCraneKick, 'SpinningCraneKick')) and ((talents[classtable.CelestialConduit] and not talents[classtable.XuensGuidance]) or targets >= 4) and cooldown[classtable.SpinningCraneKick].ready then
        if not setSpell then setSpell = classtable.SpinningCraneKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.TigerPalm, 'TigerPalm')) and ((talents[classtable.AwakenedJadefire] and true or false) and buff[classtable.JadefireStompBuff].up and buff[classtable.TeachingsoftheMonasteryBuff].count <4 or buff[classtable.TeachingsoftheMonasteryBuff].count <1) and cooldown[classtable.TigerPalm].ready then
        if not setSpell then setSpell = classtable.TigerPalm end
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and ((not talents[classtable.RushingWindKick] and cooldown[classtable.RisingSunKick].remains >2*gcd or cooldown[classtable.RushingWindKick].remains >2*gcd) and (buff[classtable.TeachingsoftheMonasteryBuff].count >3)) and cooldown[classtable.BlackoutKick].ready then
        if not setSpell then setSpell = classtable.BlackoutKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.ChiBurst, 'ChiBurst')) and cooldown[classtable.ChiBurst].ready then
        MaxDps:GlowCooldown(classtable.ChiBurst, cooldown[classtable.ChiBurst].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.SpinningCraneKick, 'SpinningCraneKick')) and cooldown[classtable.SpinningCraneKick].ready then
        if not setSpell then setSpell = classtable.SpinningCraneKick end
    end
end
function Mistweaver:crane()
    if (MaxDps:CheckSpellUsable(classtable.ThunderFocusTea, 'ThunderFocusTea')) and (talents[classtable.AncientTeachings] and buff[classtable.AncientTeachingsBuff].remains <gcd) and cooldown[classtable.ThunderFocusTea].ready then
        if not setSpell then setSpell = classtable.ThunderFocusTea end
    end
    --if (MaxDps:CheckSpellUsable(classtable.EssenceFont, 'EssenceFont')) and (talents[classtable.AncientTeachings] and buff[classtable.AncientTeachingsBuff].remains <gcd) and cooldown[classtable.EssenceFont].ready then
    --    if not setSpell then setSpell = classtable.EssenceFont end
    --end
    if (MaxDps:CheckSpellUsable(classtable.JadefireStomp, 'JadefireStomp')) and (talents[classtable.AncientTeachings] and buff[classtable.AncientTeachingsBuff].remains <gcd) and cooldown[classtable.JadefireStomp].ready then
        if not setSpell then setSpell = classtable.JadefireStomp end
    end
    if (MaxDps:CheckSpellUsable(classtable.EnvelopingMist, 'EnvelopingMist')) and (buff[classtable.InvokeChijiBuff].count >1) and cooldown[classtable.EnvelopingMist].ready then
        if not setSpell then setSpell = classtable.EnvelopingMist end
    end
    if (MaxDps:CheckSpellUsable(classtable.RisingSunKick, 'RisingSunKick')) and cooldown[classtable.RisingSunKick].ready then
        if not setSpell then setSpell = classtable.RisingSunKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.RushingWindKick, 'RushingWindKick') and talents[classtable.RushingWindKick]) and cooldown[classtable.RushingWindKick].ready then
        if not setSpell then setSpell = classtable.RushingWindKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and (((not talents[classtable.AwakenedJadefire] or not buff[classtable.JadefireStompBuff].up) and buff[classtable.TeachingsoftheMonasteryBuff].up or buff[classtable.TeachingsoftheMonasteryBuff].count >3) and (not talents[classtable.RushingWindKick] and cooldown[classtable.RisingSunKick].remains >2*gcd or cooldown[classtable.RushingWindKick].remains >2*gcd)) and cooldown[classtable.BlackoutKick].ready then
        if not setSpell then setSpell = classtable.BlackoutKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (targets >3 or targets >1 and not talents[classtable.AncientConcordance] and not talents[classtable.AwakenedJadefire]) and cooldown[classtable.SpinningCraneKick].ready then
        if not setSpell then setSpell = classtable.SpinningCraneKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and cooldown[classtable.BlackoutKick].ready then
        if not setSpell then setSpell = classtable.BlackoutKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.TigerPalm, 'TigerPalm')) and cooldown[classtable.TigerPalm].ready then
        if not setSpell then setSpell = classtable.TigerPalm end
    end
end


local function ClearCDs()
    MaxDps:GlowCooldown(classtable.ChiBurst, false)
    MaxDps:GlowCooldown(classtable.SpearHandStrike, false)
    MaxDps:GlowCooldown(classtable.ExpelHarm, false)
    MaxDps:GlowCooldown(classtable.Vivify, false)
end

function Mistweaver:callaction()
    if (MaxDps:CheckSpellUsable(classtable.SpearHandStrike, 'SpearHandStrike')) and cooldown[classtable.SpearHandStrike].ready then
        MaxDps:GlowCooldown(classtable.SpearHandStrike, ( select(8,UnitCastingInfo('target')) ~= nil and not select(8,UnitCastingInfo('target')) or select(7,UnitChannelInfo('target')) ~= nil and not select(7,UnitChannelInfo('target'))) )
    end
    if (MaxDps:CheckSpellUsable(classtable.RenewingMist, 'RenewingMist')) and (cooldown[classtable.RenewingMist].fullRecharge <= gcd) and cooldown[classtable.RenewingMist].ready then
        if not setSpell then setSpell = classtable.RenewingMist end
    end
    if (tea_up) then
        Mistweaver:focus_tea()
    end
    if (GetTotemInfoById(classtable.ChiJi).up) then
        Mistweaver:crane()
    end
    if (MaxDps:CheckSpellUsable(classtable.JadefireStomp, 'JadefireStomp')) and (not false or talents[classtable.AwakenedJadefire] and not buff[classtable.AwakenedJadefireBuff].up or talents[classtable.JadefireTeachings] and not buff[classtable.JadefireTeachingsBuff].up) and cooldown[classtable.JadefireStomp].ready then
        if not setSpell then setSpell = classtable.JadefireStomp end
    end
    if (targets >= 3) then
        Mistweaver:aoe()
    end
    if (targets <3) then
        Mistweaver:st()
    end
end
function Monk:Mistweaver()
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
    classtable.TeaofPlentyRskBuff = 388525
    classtable.TeaofPlentyEmBuff = 393988
    classtable.TeaofPlentyEhBuff = 388524
    classtable.TeaofSerenityEmBuff = 388519
    classtable.TeaofSerenityRmBuff = 388520
    classtable.TeaofSerenityVBuff = 388518
    classtable.ThunderFocusTeaBuff = 116680
    classtable.AwakenedJadefireBuff = 389387
    classtable.JadefireTeachingsBuff = 388026
    classtable.JadefireStompBuff = 388193
    classtable.TeachingsoftheMonasteryBuff = 202090
    classtable.ZenPulseBuff = 446334
    classtable.JadeEmpowermentBuff = 467317
    classtable.AncientTeachingsBuff = 388026
    classtable.InvokeChijiBuff = 343820

    local function debugg()
        talents[classtable.AwakenedJadefire] = 1
        talents[classtable.JadefireTeachings] = 1
        talents[classtable.RushingWindKick] = 1
        talents[classtable.CelestialConduit] = 1
        talents[classtable.XuensGuidance] = 1
        talents[classtable.AncientTeachings] = 1
        talents[classtable.AncientConcordance] = 1
    end


    --if MaxDps.db.global.debugMode then
    --   debugg()
    --end

    setSpell = nil
    ClearCDs()

    Mistweaver:precombat()

    Mistweaver:callaction()
    if setSpell then return setSpell end
end
