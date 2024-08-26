local _, addonTable = ...
local Monk = addonTable.Monk
local MaxDps = _G.MaxDps
if not MaxDps then return end

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
local currentSpec = GetSpecialization()
local currentSpecName = currentSpec and select(2, GetSpecializationInfo(currentSpec)) or 'None'
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

local Mistweaver = {}

function Mistweaver:precombat()
    if (MaxDps:CheckSpellUsable(classtable.ChiBurst, 'ChiBurst')) and cooldown[classtable.ChiBurst].ready then
        return classtable.ChiBurst
    end
end
function Mistweaver:st()
    if (MaxDps:CheckSpellUsable(classtable.ThunderFocusTea, 'ThunderFocusTea')) and cooldown[classtable.ThunderFocusTea].ready then
        return classtable.ThunderFocusTea
    end
    if (MaxDps:CheckSpellUsable(classtable.RisingSunKick, 'RisingSunKick')) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and (not talents[classtable.TeachingsoftheMonastery] or ( not talents[classtable.AwakenedFaeline] and buff[classtable.TeachingsoftheMonasteryBuff].up or buff[classtable.TeachingsoftheMonasteryBuff].count >3 ) and cooldown[classtable.RisingSunKick].remains >gcd) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    --if (MaxDps:CheckSpellUsable(classtable.Vivify, 'Vivify')) and (buff[classtable.ZenPulseBuff].up) and cooldown[classtable.Vivify].ready then
    --    MaxDps:GlowCooldown(classtable.Vivify, cooldown[classtable.Vivify].ready)
    --end
    if (MaxDps:CheckSpellUsable(classtable.ChiBurst, 'ChiBurst')) and cooldown[classtable.ChiBurst].ready then
        return classtable.ChiBurst
    end
    if (MaxDps:CheckSpellUsable(classtable.TigerPalm, 'TigerPalm')) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
end
function Mistweaver:aoe()
    if (MaxDps:CheckSpellUsable(classtable.ThunderFocusTea, 'ThunderFocusTea')) and (targets <= 3) and cooldown[classtable.ThunderFocusTea].ready then
        return classtable.ThunderFocusTea
    end
    --if (MaxDps:CheckSpellUsable(classtable.Vivify, 'Vivify')) and (buff[classtable.ZenPulseBuff].up) and cooldown[classtable.Vivify].ready then
    --    MaxDps:GlowCooldown(classtable.Vivify, cooldown[classtable.Vivify].ready)
    --end
    if (MaxDps:CheckSpellUsable(classtable.RisingSunKick, 'RisingSunKick')) and (targets <= 3) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and (not talents[classtable.TeachingsoftheMonastery] or buff[classtable.TeachingsoftheMonasteryBuff].up and targets <= 3) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:CheckSpellUsable(classtable.ChiBurst, 'ChiBurst')) and cooldown[classtable.ChiBurst].ready then
        return classtable.ChiBurst
    end
    if (MaxDps:CheckSpellUsable(classtable.SpinningCraneKick, 'SpinningCraneKick')) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
end
function Mistweaver:crane()
    if (MaxDps:CheckSpellUsable(classtable.RenewingMist, 'RenewingMist')) and (cooldown[classtable.RenewingMist].fullRecharge <= gcd) and cooldown[classtable.RenewingMist].ready then
        return classtable.RenewingMist
    end
    if (MaxDps:CheckSpellUsable(classtable.ThunderFocusTea, 'ThunderFocusTea')) and (talents[classtable.AncientTeachings] and buff[classtable.AncientTeachingsBuff].remains <gcd) and cooldown[classtable.ThunderFocusTea].ready then
        return classtable.ThunderFocusTea
    end
    --if (MaxDps:CheckSpellUsable(classtable.EssenceFont, 'EssenceFont')) and (talents[classtable.AncientTeachings] and buff[classtable.AncientTeachingsBuff].remains <gcd) and cooldown[classtable.EssenceFont].ready then
    --    return classtable.EssenceFont
    --end
    if (MaxDps:CheckSpellUsable(classtable.JadefireStomp, 'JadefireStomp')) and (talents[classtable.AncientTeachings] and buff[classtable.AncientTeachingsBuff].remains <gcd) and cooldown[classtable.JadefireStomp].ready then
        return classtable.JadefireStomp
    end
    if (MaxDps:CheckSpellUsable(classtable.EnvelopingMist, 'EnvelopingMist')) and (buff[classtable.InvokeChijiBuff].count >1) and cooldown[classtable.EnvelopingMist].ready then
        return classtable.EnvelopingMist
    end
    if (MaxDps:CheckSpellUsable(classtable.RisingSunKick, 'RisingSunKick')) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:CheckSpellUsable(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (targets >3 or targets >1 and not talents[classtable.AncientConcordance] and not talents[classtable.AwakenedJadefire]) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:CheckSpellUsable(classtable.TigerPalm, 'TigerPalm')) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
end

function Mistweaver:callaction()
    if (MaxDps:CheckSpellUsable(classtable.SpearHandStrike, 'SpearHandStrike')) and cooldown[classtable.SpearHandStrike].ready then
        MaxDps:GlowCooldown(classtable.SpearHandStrike, ( select(8,UnitCastingInfo('target')) ~= nil and not select(8,UnitCastingInfo('target')) or select(7,UnitChannelInfo('target')) ~= nil and not select(7,UnitChannelInfo('target'))) )
    end
    --if (pet.chiji.up) then
        local craneCheck = Mistweaver:crane()
        if craneCheck then
            return Mistweaver:crane()
        end
    --end
    if (MaxDps:CheckSpellUsable(classtable.JadefireStomp, 'JadefireStomp')) and (true or talents[classtable.AncientConcordance] and not buff[classtable.AncientConcordanceBuff].up or talents[classtable.AwakenedFaeline] and not buff[classtable.AwakenedFaelineBuff].up or talents[classtable.AncientTeachings] and not buff[classtable.AncientTeachingsBuff].up) and cooldown[classtable.JadefireStomp].ready then
        return classtable.JadefireStomp
    end
    if (targets >= 3) then
        local aoeCheck = Mistweaver:aoe()
        if aoeCheck then
            return Mistweaver:aoe()
        end
    end
    if (targets <3) then
        local stCheck = Mistweaver:st()
        if stCheck then
            return Mistweaver:st()
        end
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
    Mana = UnitPower('player', ManaPT)
    ManaMax = UnitPowerMax('player', ManaPT)
    ManaDeficit = ManaMax - Mana
    targetHP = UnitHealth('target')
    targetmaxHP = UnitHealthMax('target')
    targethealthPerc = (targetHP / targetmaxHP) * 100
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
    for spellId in pairs(MaxDps.Flags) do
        self.Flags[spellId] = false
        self:ClearGlowIndependent(spellId, spellId)
    end
    classtable.TeachingsoftheMonasteryBuff = 202090
    classtable.ZenPulseBuff = 446334
    classtable.AncientTeachingsBuff = 388026
    classtable.InvokeChijiBuff = 343820
    classtable.AncientConcordanceBuff = 389391
    classtable.AwakenedFaelineBuff = 389387
    classtable.AwakenedFaeline = classtable.AwakenedJadefire

    local precombatCheck = Mistweaver:precombat()
    if precombatCheck then
        return Mistweaver:precombat()
    end

    local callactionCheck = Mistweaver:callaction()
    if callactionCheck then
        return Mistweaver:callaction()
    end
end
