local _, addonTable = ...
local Monk = addonTable.Monk
local MaxDps = _G.MaxDps
if not MaxDps then return end

local UnitPower = UnitPower
local UnitHealth = UnitHealth
local UnitAura = UnitAura
local GetSpellDescription = GetSpellDescription
local UnitHealthMax = UnitHealthMax
local UnitPowerMax = UnitPowerMax
local SpellHaste
local SpellCrit

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

local Chi
local ChiMax
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


local function CheckSpellCosts(spell,spellstring)
    if spellstring == 'TouchofDeath' then
        if targethealthPerc < 15 then
            return true
        else
            return false
        end
    end
    local costs = GetSpellPowerCost(spell)
    if type(costs) ~= 'table' and spellstring then print('no cost found for ',spellstring) return true end
    for i,costtable in pairs(costs) do
        if UnitPower('player', costtable.type) <= costtable.cost then
            return false
        end
    end
    return true
end

local function twoh_check()
   local leftwep = GetInventoryItemLink('player',16)
   local leftwepSubType = leftwep and select(13,GetItemInfo(leftwep))
   local rightwep = GetInventoryItemLink('player',17)
   local rightwepSubType = rightwep and select(13,GetItemInfo(rightwep))
   if leftwepSubType == (1 or 5 or 6 or 8) then
      return true
   end
end

local function PreCombatUpdate()
end

local function item_actions()
end
local function race_actions()
end
local function rotation_pta()
    if (MaxDps:FindSpell(classtable.InvokeNiuzaotheBlackOx) and CheckSpellCosts(classtable.InvokeNiuzaotheBlackOx, 'InvokeNiuzaotheBlackOx')) and cooldown[classtable.InvokeNiuzaotheBlackOx].ready then
        return classtable.InvokeNiuzaotheBlackOx
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.PresstheAdvantageBuff].count <( 7 + (twoh_check() == true and 2 or 1) )) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.PresstheAdvantageBuff].count >9 and targets <= 3 and ( buff[classtable.BlackoutComboBuff].up or not talents[classtable.BlackoutCombo] )) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.KegSmash) and CheckSpellCosts(classtable.KegSmash, 'KegSmash')) and (( buff[classtable.PresstheAdvantageBuff].count >9 ) and targets >3) and cooldown[classtable.KegSmash].ready then
        return classtable.KegSmash
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (targets >5 and buff[classtable.ExplodingKegBuff].up and buff[classtable.CharredPassionsBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.PurifyingBrew) and CheckSpellCosts(classtable.PurifyingBrew, 'PurifyingBrew')) and (( not buff[classtable.BlackoutComboBuff] )) and cooldown[classtable.PurifyingBrew].ready then
        return classtable.PurifyingBrew
    end
    if (MaxDps:FindSpell(classtable.BlackOxBrew) and CheckSpellCosts(classtable.BlackOxBrew, 'BlackOxBrew')) and (Energy + EnergyRegen <= 40) and cooldown[classtable.BlackOxBrew].ready then
        return classtable.BlackOxBrew
    end
    if (MaxDps:FindSpell(classtable.BreathofFire) and CheckSpellCosts(classtable.BreathofFire, 'BreathofFire')) and (buff[classtable.CharredPassionsBuff].remains <cooldown[classtable.BlackoutKick].duration and ( buff[classtable.BlackoutComboBuff].up or not talents[classtable.BlackoutCombo] )) and cooldown[classtable.BreathofFire].ready then
        return classtable.BreathofFire
    end
    if (MaxDps:FindSpell(classtable.SummonWhiteTigerStatue) and CheckSpellCosts(classtable.SummonWhiteTigerStatue, 'SummonWhiteTigerStatue') and talents[classtable.SummonWhiteTigerStatue]) and cooldown[classtable.SummonWhiteTigerStatue].ready then
        return classtable.SummonWhiteTigerStatue
    end
    if (MaxDps:FindSpell(classtable.BonedustBrew) and CheckSpellCosts(classtable.BonedustBrew, 'BonedustBrew') and talents[classtable.BonedustBrew]) and cooldown[classtable.BonedustBrew].ready then
        return classtable.BonedustBrew
    end
    if (MaxDps:FindSpell(classtable.ExplodingKeg) and CheckSpellCosts(classtable.ExplodingKeg, 'ExplodingKeg')) and (( ( buff[classtable.BonedustBrewBuff].up ) or ( cooldown[classtable.BonedustBrew].duration >= 20 ) )) and cooldown[classtable.ExplodingKeg].ready then
        return classtable.ExplodingKeg
    end
    if (MaxDps:FindSpell(classtable.ExplodingKeg) and CheckSpellCosts(classtable.ExplodingKeg, 'ExplodingKeg')) and (( not talents[classtable.BonedustBrew] )) and cooldown[classtable.ExplodingKeg].ready then
        return classtable.ExplodingKeg
    end
    if (MaxDps:FindSpell(classtable.BreathofFire) and CheckSpellCosts(classtable.BreathofFire, 'BreathofFire')) and (( buff[classtable.BlackoutComboBuff].up or not talents[classtable.BlackoutCombo] )) and cooldown[classtable.BreathofFire].ready then
        return classtable.BreathofFire
    end
    if (MaxDps:FindSpell(classtable.KegSmash) and CheckSpellCosts(classtable.KegSmash, 'KegSmash')) and (buff[classtable.PresstheAdvantageBuff].count <10) and cooldown[classtable.KegSmash].ready then
        return classtable.KegSmash
    end
    if (MaxDps:FindSpell(classtable.RushingJadeWind) and CheckSpellCosts(classtable.RushingJadeWind, 'RushingJadeWind') and talents[classtable.RushingJadeWind]) and (talents[classtable.RushingJadeWind]) and cooldown[classtable.RushingJadeWind].ready then
        return classtable.RushingJadeWind
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (targets >2) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (( 1.1 >( timeInCombat - gcd ) * ( 1 + SpellHaste ) - (twoh_check() == true and 2 or 1) )) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.ExpelHarm) and CheckSpellCosts(classtable.ExpelHarm, 'ExpelHarm')) and cooldown[classtable.ExpelHarm].ready then
        return classtable.ExpelHarm
    end
    if (MaxDps:FindSpell(classtable.ChiWave) and CheckSpellCosts(classtable.ChiWave, 'ChiWave') and talents[classtable.ChiWave]) and cooldown[classtable.ChiWave].ready then
        return classtable.ChiWave
    end
    if (MaxDps:FindSpell(classtable.ChiBurst) and CheckSpellCosts(classtable.ChiBurst, 'ChiBurst') and talents[classtable.ChiBurst]) and cooldown[classtable.ChiBurst].ready then
        return classtable.ChiBurst
    end
end
local function rotation_boc()
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.PurifyingBrew) and CheckSpellCosts(classtable.PurifyingBrew, 'PurifyingBrew')) and (( buff[classtable.BlackoutComboBuff].down and ( buff[classtable.RecentPurifiesBuff].down or cooldown[classtable.PurifyingBrew].charges_fractional >( 1 + talents[classtable.ImprovedPurifyingBrew] - 0.1 ) ) ) and talents[classtable.ImprovedInvokeNiuzaotheBlackOx] and ( cooldown[classtable.WeaponsofOrder].duration >40 or cooldown[classtable.WeaponsofOrder].duration <5 )) and cooldown[classtable.PurifyingBrew].ready then
        return classtable.PurifyingBrew
    end
    if (MaxDps:FindSpell(classtable.WeaponsofOrder) and CheckSpellCosts(classtable.WeaponsofOrder, 'WeaponsofOrder') and talents[classtable.WeaponsofOrder]) and (( buff[classtable.RecentPurifiesBuff].up ) and talents[classtable.ImprovedInvokeNiuzaotheBlackOx]) and cooldown[classtable.WeaponsofOrder].ready then
        return classtable.WeaponsofOrder
    end
    if (MaxDps:FindSpell(classtable.InvokeNiuzaotheBlackOx) and CheckSpellCosts(classtable.InvokeNiuzaotheBlackOx, 'InvokeNiuzaotheBlackOx')) and (( buff[classtable.InvokeNiuzaotheBlackOxBuff].down and buff[classtable.RecentPurifiesBuff].up and buff[classtable.WeaponsofOrderBuff].remains <14 ) and talents[classtable.ImprovedInvokeNiuzaotheBlackOx]) and cooldown[classtable.InvokeNiuzaotheBlackOx].ready then
        return classtable.InvokeNiuzaotheBlackOx
    end
    if (MaxDps:FindSpell(classtable.InvokeNiuzaotheBlackOx) and CheckSpellCosts(classtable.InvokeNiuzaotheBlackOx, 'InvokeNiuzaotheBlackOx')) and (( debuff[classtable.WeaponsofOrderDebuffDeBuff].count >3 ) and not talents[classtable.ImprovedInvokeNiuzaotheBlackOx]) and cooldown[classtable.InvokeNiuzaotheBlackOx].ready then
        return classtable.InvokeNiuzaotheBlackOx
    end
    if (MaxDps:FindSpell(classtable.InvokeNiuzaotheBlackOx) and CheckSpellCosts(classtable.InvokeNiuzaotheBlackOx, 'InvokeNiuzaotheBlackOx')) and (( not talents[classtable.WeaponsofOrder] )) and cooldown[classtable.InvokeNiuzaotheBlackOx].ready then
        return classtable.InvokeNiuzaotheBlackOx
    end
    if (MaxDps:FindSpell(classtable.WeaponsofOrder) and CheckSpellCosts(classtable.WeaponsofOrder, 'WeaponsofOrder') and talents[classtable.WeaponsofOrder]) and (( talents[classtable.WeaponsofOrder] ) and not talents[classtable.ImprovedInvokeNiuzaotheBlackOx]) and cooldown[classtable.WeaponsofOrder].ready then
        return classtable.WeaponsofOrder
    end
    if (MaxDps:FindSpell(classtable.KegSmash) and CheckSpellCosts(classtable.KegSmash, 'KegSmash')) and (( timeInCombat - WoOLastUsed <2 )) and cooldown[classtable.KegSmash].ready then
        return classtable.KegSmash
    end
    if (MaxDps:FindSpell(classtable.KegSmash) and CheckSpellCosts(classtable.KegSmash, 'KegSmash')) and (( buff[classtable.WeaponsofOrderBuff].remains <gcd * 2 and buff[classtable.WeaponsofOrderBuff].up ) and not talents[classtable.ImprovedInvokeNiuzaotheBlackOx]) and cooldown[classtable.KegSmash].ready then
        return classtable.KegSmash
    end
    if (MaxDps:FindSpell(classtable.KegSmash) and CheckSpellCosts(classtable.KegSmash, 'KegSmash')) and (( buff[classtable.WeaponsofOrderBuff].remains <gcd * 2 ) and talents[classtable.ImprovedInvokeNiuzaotheBlackOx]) and cooldown[classtable.KegSmash].ready then
        return classtable.KegSmash
    end
    if (MaxDps:FindSpell(classtable.PurifyingBrew) and CheckSpellCosts(classtable.PurifyingBrew, 'PurifyingBrew')) and (( not buff[classtable.BlackoutComboBuff] ) and not talents[classtable.ImprovedInvokeNiuzaotheBlackOx]) and cooldown[classtable.PurifyingBrew].ready then
        return classtable.PurifyingBrew
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.BlackOxBrew) and CheckSpellCosts(classtable.BlackOxBrew, 'BlackOxBrew')) and (( Energy + EnergyRegen <= 40 )) and cooldown[classtable.BlackOxBrew].ready then
        return classtable.BlackOxBrew
    end
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (( buff[classtable.BlackoutComboBuff].up and targets == 1 )) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (MaxDps:FindSpell(classtable.BreathofFire) and CheckSpellCosts(classtable.BreathofFire, 'BreathofFire')) and (( buff[classtable.CharredPassionsBuff].remains <cooldown[classtable.BlackoutKick].duration )) and cooldown[classtable.BreathofFire].ready then
        return classtable.BreathofFire
    end
    if (MaxDps:FindSpell(classtable.KegSmash) and CheckSpellCosts(classtable.KegSmash, 'KegSmash')) and (( buff[classtable.WeaponsofOrderBuff].up and debuff[classtable.WeaponsofOrderDebuffDeBuff].count <= 3 )) and cooldown[classtable.KegSmash].ready then
        return classtable.KegSmash
    end
    if (MaxDps:FindSpell(classtable.SummonWhiteTigerStatue) and CheckSpellCosts(classtable.SummonWhiteTigerStatue, 'SummonWhiteTigerStatue') and talents[classtable.SummonWhiteTigerStatue]) and (( debuff[classtable.WeaponsofOrderDebuffDeBuff].count >3 )) and cooldown[classtable.SummonWhiteTigerStatue].ready then
        return classtable.SummonWhiteTigerStatue
    end
    if (MaxDps:FindSpell(classtable.SummonWhiteTigerStatue) and CheckSpellCosts(classtable.SummonWhiteTigerStatue, 'SummonWhiteTigerStatue') and talents[classtable.SummonWhiteTigerStatue]) and (( not talents[classtable.WeaponsofOrder] )) and cooldown[classtable.SummonWhiteTigerStatue].ready then
        return classtable.SummonWhiteTigerStatue
    end
    if (MaxDps:FindSpell(classtable.BonedustBrew) and CheckSpellCosts(classtable.BonedustBrew, 'BonedustBrew') and talents[classtable.BonedustBrew]) and (( timeInCombat <10 and debuff[classtable.WeaponsofOrderDebuffDeBuff].count >3 ) or ( timeInCombat >10 and talents[classtable.WeaponsofOrder] )) and cooldown[classtable.BonedustBrew].ready then
        return classtable.BonedustBrew
    end
    if (MaxDps:FindSpell(classtable.BonedustBrew) and CheckSpellCosts(classtable.BonedustBrew, 'BonedustBrew') and talents[classtable.BonedustBrew]) and (( not talents[classtable.WeaponsofOrder] )) and cooldown[classtable.BonedustBrew].ready then
        return classtable.BonedustBrew
    end
    if (MaxDps:FindSpell(classtable.ExplodingKeg) and CheckSpellCosts(classtable.ExplodingKeg, 'ExplodingKeg')) and (( buff[classtable.BonedustBrewBuff].up )) and cooldown[classtable.ExplodingKeg].ready then
        return classtable.ExplodingKeg
    end
    if (MaxDps:FindSpell(classtable.ExplodingKeg) and CheckSpellCosts(classtable.ExplodingKeg, 'ExplodingKeg')) and (( cooldown[classtable.BonedustBrew].duration >= 20 )) and cooldown[classtable.ExplodingKeg].ready then
        return classtable.ExplodingKeg
    end
    if (MaxDps:FindSpell(classtable.ExplodingKeg) and CheckSpellCosts(classtable.ExplodingKeg, 'ExplodingKeg')) and (( not talents[classtable.BonedustBrew] )) and cooldown[classtable.ExplodingKeg].ready then
        return classtable.ExplodingKeg
    end
    if (MaxDps:FindSpell(classtable.KegSmash) and CheckSpellCosts(classtable.KegSmash, 'KegSmash')) and cooldown[classtable.KegSmash].ready then
        return classtable.KegSmash
    end
    if (MaxDps:FindSpell(classtable.RushingJadeWind) and CheckSpellCosts(classtable.RushingJadeWind, 'RushingJadeWind') and talents[classtable.RushingJadeWind]) and (talents[classtable.RushingJadeWind]) and cooldown[classtable.RushingJadeWind].ready then
        return classtable.RushingJadeWind
    end
    if (MaxDps:FindSpell(classtable.BreathofFire) and CheckSpellCosts(classtable.BreathofFire, 'BreathofFire')) and cooldown[classtable.BreathofFire].ready then
        return classtable.BreathofFire
    end
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (targets == 1 and not talents[classtable.BlackoutCombo]) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (targets >1) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.ExpelHarm) and CheckSpellCosts(classtable.ExpelHarm, 'ExpelHarm')) and cooldown[classtable.ExpelHarm].ready then
        return classtable.ExpelHarm
    end
    if (MaxDps:FindSpell(classtable.ChiWave) and CheckSpellCosts(classtable.ChiWave, 'ChiWave') and talents[classtable.ChiWave]) and cooldown[classtable.ChiWave].ready then
        return classtable.ChiWave
    end
    if (MaxDps:FindSpell(classtable.ChiBurst) and CheckSpellCosts(classtable.ChiBurst, 'ChiBurst') and talents[classtable.ChiBurst]) and cooldown[classtable.ChiBurst].ready then
        return classtable.ChiBurst
    end
end

function Monk:Brewmaster()
    fd = MaxDps.FrameData
    ttd = (fd.timeToDie and fd.timeToDie) or 500
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
    SpellHaste = UnitSpellHaste('target')
    SpellCrit = GetCritChance()
    Chi = UnitPower('player', ChiPT)
    ChiMax = UnitPowerMax('player', ChiPT)
    Energy = UnitPower('player', EnergyPT)
    EnergyMax = UnitPowerMax('player', EnergyPT)
    EnergyDeficit = EnergyMax - Energy
    EnergyRegen = GetPowerRegenForPowerType(Enum.PowerType.Energy)
    EnergyTimeToMax = EnergyDeficit / EnergyRegen
    staggerAmount = UnitStagger('player')
    staggerPercent = (staggerAmount / maxHP) * 100
    WoOLastUsed = 0
    classtable.PresstheAdvantageBuff = 418361
    classtable.BlackoutComboBuff = 228563
    classtable.ExplodingKegBuff = 325153
    classtable.CharredPassionsBuff = 386963
    classtable.BonedustBrewBuff = 386276
    classtable.RecentPurifiesBuff = 325092
    classtable.InvokeNiuzaotheBlackOxBuff = 132578
    classtable.WeaponsofOrderBuff = 387184
    classtable.WeaponsofOrderDebuffDeBuff = 387179
    PreCombatUpdate()
    local item_actionsCheck = item_actions()
    if item_actionsCheck then
        return item_actionsCheck
    end
    local race_actionsCheck = race_actions()
    if race_actionsCheck then
        return race_actionsCheck
    end
    local rotation_ptaCheck = rotation_pta()
    if (talents[classtable.PresstheAdvantage]) then
        if rotation_ptaCheck then
            return rotation_pta()
        end
    end
    local rotation_bocCheck = rotation_boc()
    if (not talents[classtable.PresstheAdvantage]) then
        if rotation_bocCheck then
            return rotation_boc()
        end
    end
end
