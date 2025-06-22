local _, addonTable = ...
local Monk = addonTable.Monk
local MaxDps = _G.MaxDps
if not MaxDps then return end
local setSpell

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
local GetSpellCount = C_Spell.GetSpellCastCount

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

local Chi
local ChiMax
local ChiDeficit
local Energy
local EnergyMax
local EnergyDeficit
local EnergyRegen
local EnergyTimeToMax
local Mana
local ManaMax
local ManaDeficit

local Windwalker = {}



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
    --if (MaxDps:CheckSpellUsable(classtable.Stance, 'Stance')) and cooldown[classtable.Stance].ready and not UnitAffectingCombat('player') then
    --    if not setSpell then setSpell = classtable.Stance end
    --end
    --if (MaxDps:CheckSpellUsable(classtable.VirmensBitePotion, 'VirmensBitePotion')) and cooldown[classtable.VirmensBitePotion].ready and not UnitAffectingCombat('player') then
    --    if not setSpell then setSpell = classtable.VirmensBitePotion end
    --end
end
function Windwalker:aoe()
    if (MaxDps:CheckSpellUsable(classtable.RushingJadeWind, 'RushingJadeWind') and talents[classtable.RushingJadeWind]) and ((talents[classtable.RushingJadeWind] and true or false)) and cooldown[classtable.RushingJadeWind].ready then
        if not setSpell then setSpell = classtable.RushingJadeWind end
    end
    if (MaxDps:CheckSpellUsable(classtable.ZenSphere, 'ZenSphere') and talents[classtable.ZenSphere]) and ((talents[classtable.ZenSphere] and true or false) and not debuff[classtable.ZenSphereDeBuff].up) and cooldown[classtable.ZenSphere].ready then
        if not setSpell then setSpell = classtable.ZenSphere end
    end
    if (MaxDps:CheckSpellUsable(classtable.ChiWave, 'ChiWave') and talents[classtable.ChiWave]) and ((talents[classtable.ChiWave] and true or false)) and cooldown[classtable.ChiWave].ready then
        if not setSpell then setSpell = classtable.ChiWave end
    end
    if (MaxDps:CheckSpellUsable(classtable.ChiBurst, 'ChiBurst') and talents[classtable.ChiBurst]) and ((talents[classtable.ChiBurst] and true or false)) and cooldown[classtable.ChiBurst].ready then
        MaxDps:GlowCooldown(classtable.ChiBurst, cooldown[classtable.ChiBurst].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.RisingSunKick, 'RisingSunKick')) and (Chi == ChiMax) and cooldown[classtable.RisingSunKick].ready then
        if not setSpell then setSpell = classtable.RisingSunKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (not (talents[classtable.RushingJadeWind] and true or false)) and cooldown[classtable.SpinningCraneKick].ready then
        if not setSpell then setSpell = classtable.SpinningCraneKick end
    end
end
function Windwalker:single_target()
    if (MaxDps:CheckSpellUsable(classtable.RisingSunKick, 'RisingSunKick')) and cooldown[classtable.RisingSunKick].ready then
        if not setSpell then setSpell = classtable.RisingSunKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.FistsofFury, 'FistsofFury')) and (not buff[classtable.EnergizingBrewBuff].up and EnergyTimeToMax >4 and buff[classtable.TigerPowerBuff].remains >4) and cooldown[classtable.FistsofFury].ready then
        if not setSpell then setSpell = classtable.FistsofFury end
    end
    if (MaxDps:CheckSpellUsable(classtable.ChiWave, 'ChiWave') and talents[classtable.ChiWave]) and ((talents[classtable.ChiWave] and true or false) and EnergyTimeToMax >2) and cooldown[classtable.ChiWave].ready then
        if not setSpell then setSpell = classtable.ChiWave end
    end
    if (MaxDps:CheckSpellUsable(classtable.ChiBurst, 'ChiBurst') and talents[classtable.ChiBurst]) and ((talents[classtable.ChiBurst] and true or false) and EnergyTimeToMax >2) and cooldown[classtable.ChiBurst].ready then
        MaxDps:GlowCooldown(classtable.ChiBurst, cooldown[classtable.ChiBurst].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.ZenSphere, 'ZenSphere') and talents[classtable.ZenSphere]) and ((talents[classtable.ZenSphere] and true or false) and EnergyTimeToMax >2 and not debuff[classtable.ZenSphereDeBuff].up) and cooldown[classtable.ZenSphere].ready then
        if not setSpell then setSpell = classtable.ZenSphere end
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.ComboBreakerBokBuff].up) and cooldown[classtable.BlackoutKick].ready then
        if not setSpell then setSpell = classtable.BlackoutKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.TigerPalm, 'TigerPalm')) and (buff[classtable.ComboBreakerTpBuff].up and ( buff[classtable.ComboBreakerTpBuff].remains <= 2 or EnergyTimeToMax >= 2 )) and cooldown[classtable.TigerPalm].ready then
        if not setSpell then setSpell = classtable.TigerPalm end
    end
    if (MaxDps:CheckSpellUsable(classtable.Jab, 'Jab')) and (ChiMax - Chi >= 2) and cooldown[classtable.Jab].ready then
        if not setSpell then setSpell = classtable.Jab end
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and (Energy + EnergyRegen * cooldown[classtable.RisingSunKick].remains >= 40) and cooldown[classtable.BlackoutKick].ready then
        if not setSpell then setSpell = classtable.BlackoutKick end
    end
end


local function ClearCDs()
    MaxDps:GlowCooldown(classtable.ChiBurst, false)
end

function Windwalker:callaction()
    if (MaxDps:CheckSpellUsable(classtable.ChiSphere, 'ChiSphere')) and ((talents[classtable.PowerStrikes] and true or false) and buff[classtable.ChiSphereBuff].up and Chi <4) and cooldown[classtable.ChiSphere].ready then
        if not setSpell then setSpell = classtable.ChiSphere end
    end
    --if (MaxDps:CheckSpellUsable(classtable.VirmensBitePotion, 'VirmensBitePotion')) and (MaxDps:Bloodlust(1) or ttd <= 60) and cooldown[classtable.VirmensBitePotion].ready then
    --    if not setSpell then setSpell = classtable.VirmensBitePotion end
    --end
    if (MaxDps:CheckSpellUsable(classtable.ChiBrew, 'ChiBrew') and talents[classtable.ChiBrew]) and ((talents[classtable.ChiBrew] and true or false) and Chi <= 2 and ( ( cooldown[classtable.ChiBrew].charges == 1 and cooldown[classtable.ChiBrew].partialRecharge <= 10 ) or cooldown[classtable.ChiBrew].charges == 2 or ttd <cooldown[classtable.ChiBrew].charges * 10 )) and cooldown[classtable.ChiBrew].ready then
        if not setSpell then setSpell = classtable.ChiBrew end
    end
    if (MaxDps:CheckSpellUsable(classtable.TigerPalm, 'TigerPalm')) and (buff[classtable.TigerPowerBuff].remains <= 3) and cooldown[classtable.TigerPalm].ready then
        if not setSpell then setSpell = classtable.TigerPalm end
    end
    if (MaxDps:CheckSpellUsable(classtable.TigereyeBrew, 'TigereyeBrew')) and (not buff[classtable.TigereyeBrewUseBuff].up and buff[classtable.TigereyeBrewBuff].count == 20) and cooldown[classtable.TigereyeBrew].ready then
        if not setSpell then setSpell = classtable.TigereyeBrew end
    end
    if (MaxDps:CheckSpellUsable(classtable.TigereyeBrew, 'TigereyeBrew')) and (not buff[classtable.TigereyeBrewUseBuff].up) and cooldown[classtable.TigereyeBrew].ready then
        if not setSpell then setSpell = classtable.TigereyeBrew end
    end
    if (MaxDps:CheckSpellUsable(classtable.TigereyeBrew, 'TigereyeBrew')) and (not buff[classtable.TigereyeBrewUseBuff].up and Chi >= 2 and ( buff[classtable.TigereyeBrewBuff].count >= 15 or ttd <40 ) and debuff[classtable.RisingSunKickDeBuff].up and buff[classtable.TigerPowerBuff].up) and cooldown[classtable.TigereyeBrew].ready then
        if not setSpell then setSpell = classtable.TigereyeBrew end
    end
    if (MaxDps:CheckSpellUsable(classtable.EnergizingBrew, 'EnergizingBrew')) and (EnergyTimeToMax >5) and cooldown[classtable.EnergizingBrew].ready then
        if not setSpell then setSpell = classtable.EnergizingBrew end
    end
    if (MaxDps:CheckSpellUsable(classtable.RisingSunKick, 'RisingSunKick')) and (not debuff[classtable.RisingSunKickDeBuff].up) and cooldown[classtable.RisingSunKick].ready then
        if not setSpell then setSpell = classtable.RisingSunKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.TigerPalm, 'TigerPalm')) and (not buff[classtable.TigerPowerBuff].up and debuff[classtable.RisingSunKickDeBuff].remains >1 and EnergyTimeToMax >1) and cooldown[classtable.TigerPalm].ready then
        if not setSpell then setSpell = classtable.TigerPalm end
    end
    if (MaxDps:CheckSpellUsable(classtable.InvokeXuen, 'InvokeXuen') and talents[classtable.InvokeXuen]) and ((talents[classtable.InvokeXuen] and true or false)) and cooldown[classtable.InvokeXuen].ready then
        if not setSpell then setSpell = classtable.InvokeXuen end
    end
    if (targets >= 3) then
        Windwalker:aoe()
    end
    if (targets <3) then
        Windwalker:single_target()
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
    Mana = UnitPower('player', ManaPT)
    ManaMax = UnitPowerMax('player', ManaPT)
    ManaDeficit = ManaMax - Mana
    targetHP = UnitHealth('target')
    targetmaxHP = UnitHealthMax('target')
    targethealthPerc = (targetHP >0 and targetmaxHP >0 and (targetHP / targetmaxHP) * 100) or 100
    curentHP = UnitHealth('player')
    maxHP = UnitHealthMax('player')
    healthPerc = (curentHP / maxHP) * 100
    timeInCombat = MaxDps.combatTime or 0
    classtable = MaxDps.SpellTable
    SpellHaste = UnitSpellHaste('player')
    SpellCrit = GetCritChance()
    Chi = UnitPower('player', ChiPT)
    ChiMax = UnitPowerMax('player', ChiPT)
    ChiDeficit = ChiMax - Chi
    Energy = UnitPower('player', EnergyPT)
    EnergyMax = UnitPowerMax('player', EnergyPT)
    EnergyDeficit = EnergyMax - Energy
    EnergyRegen = GetPowerRegenForPowerType(Enum.PowerType.Energy)
    EnergyTimeToMax = EnergyDeficit / EnergyRegen
    --for spellId in pairs(MaxDps.Flags) do
    --    self.Flags[spellId] = false
    --    self:ClearGlowIndependent(spellId, spellId)
    --end

    classtable.RisingSunKickDeBuff = 130320
    classtable.TigerPowerBuff = 125359
    classtable.TigereyeBrewBuff = 1247275
    classtable.TigereyeBrewUseBuff = 1247279

    classtable.ChiSphere = 124081
    classtable.InvokeXuen = 123904

    local function debugg()
        talents[classtable.PowerStrikes] = 1
        talents[classtable.ChiBrew] = 1
        talents[classtable.InvokeXuen] = 1
        talents[classtable.RushingJadeWind] = 1
        talents[classtable.ZenSphere] = 1
        talents[classtable.ChiWave] = 1
        talents[classtable.ChiBurst] = 1
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
