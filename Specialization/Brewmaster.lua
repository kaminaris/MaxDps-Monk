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
local staggerAmount
local staggerPercent
local WoOLastUsed

local Brewmaster = {}

local function twoh_check()
   local leftwep = GetInventoryItemLink('player',16)
   local leftwepSubType = leftwep and select(13, C_Item.GetItemInfo(leftwep))
   local rightwep = GetInventoryItemLink('player',17)
   local rightwepSubType = rightwep and select(13, C_Item.GetItemInfo(rightwep))
   if leftwepSubType == (1 or 5 or 6 or 8) then
      return true
   end
end

function Brewmaster:precombat()
    if (MaxDps:CheckSpellUsable(classtable.ChiBurst, 'ChiBurst')) and (talents[classtable.ChiBurst]) and cooldown[classtable.ChiBurst].ready then
        return classtable.ChiBurst
    end
end
function Brewmaster:items()
end
function Brewmaster:rotation_pta()
    if (MaxDps:CheckSpellUsable(classtable.InvokeNiuzaotheBlackOx, 'InvokeNiuzaotheBlackOx')) and cooldown[classtable.InvokeNiuzaotheBlackOx].ready then
        MaxDps:GlowCooldown(classtable.InvokeNiuzaotheBlackOx, cooldown[classtable.InvokeNiuzaotheBlackOx].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.PresstheAdvantageBuff].count <( 7 + (twoh_check() == true and 2 or 1) )) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:CheckSpellUsable(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.PresstheAdvantageBuff].count >9 and targets <= 3 and ( buff[classtable.BlackoutComboBuff].up or not talents[classtable.BlackoutCombo] )) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:CheckSpellUsable(classtable.KegSmash, 'KegSmash')) and (( buff[classtable.PresstheAdvantageBuff].count >9 ) and targets >3) and cooldown[classtable.KegSmash].ready then
        return classtable.KegSmash
    end
    if (MaxDps:CheckSpellUsable(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (targets >5 and buff[classtable.ExplodingKegBuff].up and buff[classtable.CharredPassionsBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackOxBrew, 'BlackOxBrew')) and (Energy + EnergyRegen <= 40) and cooldown[classtable.BlackOxBrew].ready then
        return classtable.BlackOxBrew
    end
    if (MaxDps:CheckSpellUsable(classtable.BreathofFire, 'BreathofFire')) and (buff[classtable.CharredPassionsBuff].remains <cooldown[classtable.BlackoutKick].remains and ( buff[classtable.BlackoutComboBuff].up or not talents[classtable.BlackoutCombo] )) and cooldown[classtable.BreathofFire].ready then
        return classtable.BreathofFire
    end
    if (MaxDps:CheckSpellUsable(classtable.ExplodingKeg, 'ExplodingKeg')) and (( ( buff[classtable.BonedustBrewBuff].up ) or ( cooldown[classtable.BonedustBrew].remains >= 20 ) )) and cooldown[classtable.ExplodingKeg].ready then
        return classtable.ExplodingKeg
    end
    if (MaxDps:CheckSpellUsable(classtable.ExplodingKeg, 'ExplodingKeg')) and (( not talents[classtable.BonedustBrew] )) and cooldown[classtable.ExplodingKeg].ready then
        return classtable.ExplodingKeg
    end
    if (MaxDps:CheckSpellUsable(classtable.BreathofFire, 'BreathofFire')) and (( buff[classtable.BlackoutComboBuff].up or not talents[classtable.BlackoutCombo] )) and cooldown[classtable.BreathofFire].ready then
        return classtable.BreathofFire
    end
    if (MaxDps:CheckSpellUsable(classtable.KegSmash, 'KegSmash')) and (buff[classtable.PresstheAdvantageBuff].count <10) and cooldown[classtable.KegSmash].ready then
        return classtable.KegSmash
    end
    if (MaxDps:CheckSpellUsable(classtable.RushingJadeWind, 'RushingJadeWind')) and (talents[classtable.RushingJadeWind]) and cooldown[classtable.RushingJadeWind].ready then
        return classtable.RushingJadeWind
    end
    if (MaxDps:CheckSpellUsable(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (targets >2) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:CheckSpellUsable(classtable.ChiBurst, 'ChiBurst')) and cooldown[classtable.ChiBurst].ready then
        return classtable.ChiBurst
    end
end
function Brewmaster:rotation_boc()
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:CheckSpellUsable(classtable.WeaponsofOrder, 'WeaponsofOrder')) and (( buff[classtable.RecentPurifiesBuff].up ) and talents[classtable.ImprovedInvokeNiuzaotheBlackOx]) and cooldown[classtable.WeaponsofOrder].ready then
        MaxDps:GlowCooldown(classtable.WeaponsofOrder, cooldown[classtable.WeaponsofOrder].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.InvokeNiuzaotheBlackOx, 'InvokeNiuzaotheBlackOx')) and (( not buff[classtable.InvokeNiuzaotheBlackOxBuff].up and buff[classtable.RecentPurifiesBuff].up and buff[classtable.WeaponsofOrderBuff].remains <14 ) and talents[classtable.ImprovedInvokeNiuzaotheBlackOx]) and cooldown[classtable.InvokeNiuzaotheBlackOx].ready then
        MaxDps:GlowCooldown(classtable.InvokeNiuzaotheBlackOx, cooldown[classtable.InvokeNiuzaotheBlackOx].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.InvokeNiuzaotheBlackOx, 'InvokeNiuzaotheBlackOx')) and (( debuff[classtable.WeaponsofOrderDebuffDeBuff].count >3 ) and not talents[classtable.ImprovedInvokeNiuzaotheBlackOx]) and cooldown[classtable.InvokeNiuzaotheBlackOx].ready then
        MaxDps:GlowCooldown(classtable.InvokeNiuzaotheBlackOx, cooldown[classtable.InvokeNiuzaotheBlackOx].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.InvokeNiuzaotheBlackOx, 'InvokeNiuzaotheBlackOx')) and (( not talents[classtable.WeaponsofOrder] )) and cooldown[classtable.InvokeNiuzaotheBlackOx].ready then
        MaxDps:GlowCooldown(classtable.InvokeNiuzaotheBlackOx, cooldown[classtable.InvokeNiuzaotheBlackOx].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.WeaponsofOrder, 'WeaponsofOrder')) and (( talents[classtable.WeaponsofOrder] ) and not talents[classtable.ImprovedInvokeNiuzaotheBlackOx]) and cooldown[classtable.WeaponsofOrder].ready then
        MaxDps:GlowCooldown(classtable.WeaponsofOrder, cooldown[classtable.WeaponsofOrder].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.KegSmash, 'KegSmash')) and (( timeInCombat - WoOLastUsed <2 )) and cooldown[classtable.KegSmash].ready then
        return classtable.KegSmash
    end
    if (MaxDps:CheckSpellUsable(classtable.KegSmash, 'KegSmash')) and (( buff[classtable.WeaponsofOrderBuff].remains <gcd * 2 and buff[classtable.WeaponsofOrderBuff].up ) and not talents[classtable.ImprovedInvokeNiuzaotheBlackOx]) and cooldown[classtable.KegSmash].ready then
        return classtable.KegSmash
    end
    if (MaxDps:CheckSpellUsable(classtable.KegSmash, 'KegSmash')) and (( buff[classtable.WeaponsofOrderBuff].remains <gcd * 2 ) and talents[classtable.ImprovedInvokeNiuzaotheBlackOx]) and cooldown[classtable.KegSmash].ready then
        return classtable.KegSmash
    end
    if (MaxDps:CheckSpellUsable(classtable.RisingSunKick, 'RisingSunKick')) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackOxBrew, 'BlackOxBrew')) and (( Energy + EnergyRegen <= 40 )) and cooldown[classtable.BlackOxBrew].ready then
        return classtable.BlackOxBrew
    end
    if (MaxDps:CheckSpellUsable(classtable.TigerPalm, 'TigerPalm')) and (( buff[classtable.BlackoutComboBuff].up and targets == 1 )) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (MaxDps:CheckSpellUsable(classtable.BreathofFire, 'BreathofFire')) and (( buff[classtable.CharredPassionsBuff].remains <cooldown[classtable.BlackoutKick].remains )) and cooldown[classtable.BreathofFire].ready then
        return classtable.BreathofFire
    end
    if (MaxDps:CheckSpellUsable(classtable.KegSmash, 'KegSmash')) and (( buff[classtable.WeaponsofOrderBuff].up and debuff[classtable.WeaponsofOrderDebuffDeBuff].count <= 3 )) and cooldown[classtable.KegSmash].ready then
        return classtable.KegSmash
    end
    if (MaxDps:CheckSpellUsable(classtable.ExplodingKeg, 'ExplodingKeg')) and (( buff[classtable.BonedustBrewBuff].up )) and cooldown[classtable.ExplodingKeg].ready then
        return classtable.ExplodingKeg
    end
    if (MaxDps:CheckSpellUsable(classtable.ExplodingKeg, 'ExplodingKeg')) and (( cooldown[classtable.BonedustBrew].remains >= 20 )) and cooldown[classtable.ExplodingKeg].ready then
        return classtable.ExplodingKeg
    end
    if (MaxDps:CheckSpellUsable(classtable.ExplodingKeg, 'ExplodingKeg')) and (( not talents[classtable.BonedustBrew] )) and cooldown[classtable.ExplodingKeg].ready then
        return classtable.ExplodingKeg
    end
    if (MaxDps:CheckSpellUsable(classtable.KegSmash, 'KegSmash')) and cooldown[classtable.KegSmash].ready then
        return classtable.KegSmash
    end
    if (MaxDps:CheckSpellUsable(classtable.RushingJadeWind, 'RushingJadeWind')) and (talents[classtable.RushingJadeWind]) and cooldown[classtable.RushingJadeWind].ready then
        return classtable.RushingJadeWind
    end
    if (MaxDps:CheckSpellUsable(classtable.BreathofFire, 'BreathofFire')) and cooldown[classtable.BreathofFire].ready then
        return classtable.BreathofFire
    end
    if (MaxDps:CheckSpellUsable(classtable.TigerPalm, 'TigerPalm')) and (targets == 1 and not talents[classtable.BlackoutCombo]) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (MaxDps:CheckSpellUsable(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (targets >1) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:CheckSpellUsable(classtable.ChiBurst, 'ChiBurst')) and cooldown[classtable.ChiBurst].ready then
        return classtable.ChiBurst
    end
end

function Brewmaster:callaction()
    if (MaxDps:CheckSpellUsable(classtable.SpearHandStrike, 'SpearHandStrike')) and (UnitCastingInfo('target') and select(8,UnitCastingInfo('target')) == false) and cooldown[classtable.SpearHandStrike].ready then
        MaxDps:GlowCooldown(classtable.SpearHandStrike, ( select(8,UnitCastingInfo('target')) ~= nil and not select(8,UnitCastingInfo('target')) or select(7,UnitChannelInfo('target')) ~= nil and not select(7,UnitChannelInfo('target'))) )
    end
    if (MaxDps:CheckSpellUsable(classtable.DiffuseMagic, 'DiffuseMagic')) and cooldown[classtable.DiffuseMagic].ready then
        MaxDps:GlowCooldown(classtable.DiffuseMagic, cooldown[classtable.DiffuseMagic].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.Vivify, 'Vivify')) and (curentHP <= 65 and buff[classtable.VivaciousVivificationBuff].up) and cooldown[classtable.Vivify].ready then
        MaxDps:GlowCooldown(classtable.Vivify, cooldown[classtable.Vivify].ready)
    end
    --if (MaxDps:CheckSpellUsable(classtable.PurifyingBrew, 'PurifyingBrew')) and ((UnitThreatSituation('player') == 2 or UnitThreatSituation('player') == 3) and true and ( buff[classtable.PurifiedChiBuff].up and buff[classtable.PurifiedChiBuff].remains <1.5 * gcd ) or cooldown[classtable.CelestialBrew].remains <2 * gcd and cooldown[classtable.PurifyingBrew].charges >1.5) and cooldown[classtable.PurifyingBrew].ready then
    --    MaxDps:GlowCooldown(classtable.PurifyingBrew, cooldown[classtable.PurifyingBrew].ready)
    --end
    if (MaxDps:CheckSpellUsable(classtable.CelestialBrew, 'CelestialBrew')) and ((UnitThreatSituation('player') == 2 or UnitThreatSituation('player') == 3) and ( not talents[classtable.ImprovedCelestialBrew] or buff[classtable.PurifiedChiBuff].up ) and ( not buff[classtable.BlackoutComboBuff].up )) and cooldown[classtable.CelestialBrew].ready then
        MaxDps:GlowCooldown(classtable.CelestialBrew, cooldown[classtable.CelestialBrew].ready)
    end
    --if (MaxDps:CheckSpellUsable(classtable.PurifyingBrew, 'PurifyingBrew')) and (( not buff[classtable.BlackoutComboBuff].up ) and staggerPercent >= 12) and cooldown[classtable.PurifyingBrew].ready then
    --    MaxDps:GlowCooldown(classtable.PurifyingBrew, cooldown[classtable.PurifyingBrew].ready)
    --end
    --if (MaxDps:CheckSpellUsable(classtable.PurifyingBrew, 'PurifyingBrew')) and (( not buff[classtable.BlackoutComboBuff].up ) and staggerPercent >= 12 * 0.5) and cooldown[classtable.PurifyingBrew].ready then
    --    MaxDps:GlowCooldown(classtable.PurifyingBrew, cooldown[classtable.PurifyingBrew].ready)
    --end
    --if (MaxDps:CheckSpellUsable(classtable.PurifyingBrew, 'PurifyingBrew')) and (( not buff[classtable.BlackoutComboBuff].up ) and staggerPercent >= 6) and cooldown[classtable.PurifyingBrew].ready then
    --    MaxDps:GlowCooldown(classtable.PurifyingBrew, cooldown[classtable.PurifyingBrew].ready)
    --end
    --if (MaxDps:CheckSpellUsable(classtable.PurifyingBrew, 'PurifyingBrew')) and (( not buff[classtable.BlackoutComboBuff].up ) and staggerPercent >= 6 * 0.5) and cooldown[classtable.PurifyingBrew].ready then
    --    MaxDps:GlowCooldown(classtable.PurifyingBrew, cooldown[classtable.PurifyingBrew].ready)
    --end
    --if (MaxDps:CheckSpellUsable(classtable.PurifyingBrew, 'PurifyingBrew')) and (( not buff[classtable.BlackoutComboBuff].up ) and staggerPercent >20) and cooldown[classtable.PurifyingBrew].ready then
    --    MaxDps:GlowCooldown(classtable.PurifyingBrew, cooldown[classtable.PurifyingBrew].ready)
    --end
    --if (MaxDps:CheckSpellUsable(classtable.PurifyingBrew, 'PurifyingBrew')) and (( not buff[classtable.BlackoutComboBuff].up ) and staggerPercent >10) and cooldown[classtable.PurifyingBrew].ready then
    --    MaxDps:GlowCooldown(classtable.PurifyingBrew, cooldown[classtable.PurifyingBrew].ready)
    --end
    if (MaxDps:CheckSpellUsable(classtable.DampenHarm, 'DampenHarm')) and (curentHP <75 and not buff[classtable.FortifyingBrewBuff].up) and cooldown[classtable.DampenHarm].ready then
        MaxDps:GlowCooldown(classtable.DampenHarm, cooldown[classtable.DampenHarm].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.FortifyingBrew, 'FortifyingBrew')) and (curentHP <50 and ( not buff[classtable.DampenHarmBuff].up )) and cooldown[classtable.FortifyingBrew].ready then
        MaxDps:GlowCooldown(classtable.FortifyingBrew, cooldown[classtable.FortifyingBrew].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.TouchofDeath, 'TouchofDeath')) and cooldown[classtable.TouchofDeath].ready then
        return classtable.TouchofDeath
    end
    local itemsCheck = Brewmaster:items()
    if itemsCheck then
        return itemsCheck
    end
    if (MaxDps:CheckSpellUsable(classtable.ExpelHarm, 'ExpelHarm')) and (buff[classtable.GiftoftheOxBuff].count >4 and curentHP <65) and cooldown[classtable.ExpelHarm].ready then
        MaxDps:GlowCooldown(classtable.ExpelHarm, cooldown[classtable.ExpelHarm].ready)
    end
    if (talents[classtable.PresstheAdvantage]) then
        local rotation_ptaCheck = Brewmaster:rotation_pta()
        if rotation_ptaCheck then
            return Brewmaster:rotation_pta()
        end
    end
    if (not talents[classtable.PresstheAdvantage]) then
        local rotation_bocCheck = Brewmaster:rotation_boc()
        if rotation_bocCheck then
            return Brewmaster:rotation_boc()
        end
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
    staggerAmount = UnitStagger('player')
    staggerPercent = (staggerAmount / maxHP) * 100
    WoOLastUsed = 0
    for spellId in pairs(MaxDps.Flags) do
        self.Flags[spellId] = false
        self:ClearGlowIndependent(spellId, spellId)
    end
    classtable.WeaponsofOrderDebuffDeBuff = 387179
    classtable.PresstheAdvantageBuff = 418361
    classtable.BlackoutComboBuff = 228563
    classtable.ExplodingKegBuff = 325153
    classtable.CharredPassionsBuff = 386963
    classtable.BonedustBrewBuff = 386276
    classtable.RecentPurifiesBuff = 325092
    classtable.InvokeNiuzaotheBlackOxBuff = 132578
    classtable.WeaponsofOrderBuff = 387184
    classtable.VivaciousVivificationBuff = 392883
    classtable.PurifiedChiBuff = 325092
    classtable.FortifyingBrewBuff = 120954
    classtable.DampenHarmBuff = 175395
    classtable.GiftoftheOxBuff = 224863
    classtable.BlackoutKick = MaxDps:FindSpell(100784) and 100784 or MaxDps:FindSpell(205523) and 205523

    local precombatCheck = Brewmaster:precombat()
    if precombatCheck then
        return Brewmaster:precombat()
    end

    local callactionCheck = Brewmaster:callaction()
    if callactionCheck then
        return Brewmaster:callaction()
    end
end
