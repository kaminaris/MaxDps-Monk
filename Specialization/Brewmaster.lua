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


local function CheckSpellCosts(spell,spellstring)
    if not IsSpellKnownOrOverridesKnown(spell) then return false end
    if not C_Spell.IsSpellUsable(spell) then return false end
    if spellstring == 'TouchofDeath' then
        if targethealthPerc > 15 then
            return false
        end
    end
    if spellstring == 'KillShot' then
        if (classtable.SicEmBuff and not buff[classtable.SicEmBuff].up) or (classtable.HuntersPreyBuff and not buff[classtable.HuntersPreyBuff].up) and targethealthPerc > 15 then
            return false
        end
    end
    if spellstring == 'HammerofWrath' then
        if ( (classtable.AvengingWrathBuff and not buff[classtable.AvengingWrathBuff].up) or (classtable.FinalVerdictBuff and not buff[classtable.FinalVerdictBuff].up) ) and targethealthPerc > 20 then
            return false
        end
    end
    if spellstring == 'Execute' then
        if (classtable.SuddenDeathBuff and not buff[classtable.SuddenDeathBuff].up) and targethealthPerc > 35 then
            return false
        end
    end
    local costs = C_Spell.GetSpellPowerCost(spell)
    if type(costs) ~= 'table' and spellstring then return true end
    for i,costtable in pairs(costs) do
        if UnitPower('player', costtable.type) < costtable.cost then
            return false
        end
    end
    return true
end
local function MaxGetSpellCost(spell,power)
    local costs = C_Spell.GetSpellPowerCost(spell)
    if type(costs) ~= 'table' then return 0 end
    for i,costtable in pairs(costs) do
        if costtable.name == power then
            return costtable.cost
        end
    end
    return 0
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



local function CheckPrevSpell(spell)
    if MaxDps and MaxDps.spellHistory then
        if MaxDps.spellHistory[1] then
            if MaxDps.spellHistory[1] == spell then
                return true
            end
            if MaxDps.spellHistory[1] ~= spell then
                return false
            end
        end
    end
    return true
end


local function boss()
    if UnitExists('boss1')
    or UnitExists('boss2')
    or UnitExists('boss3')
    or UnitExists('boss4')
    or UnitExists('boss5')
    or UnitExists('boss6')
    or UnitExists('boss7')
    or UnitExists('boss8')
    or UnitExists('boss9')
    or UnitExists('boss10') then
        return true
    end
    return false
end


function Brewmaster:precombat()
    if (MaxDps:FindSpell(classtable.ChiBurst) and CheckSpellCosts(classtable.ChiBurst, 'ChiBurst')) and (talents[classtable.ChiBurst]) and cooldown[classtable.ChiBurst].ready then
        return classtable.ChiBurst
    end
end
function Brewmaster:items()
end
function Brewmaster:rotation_pta()
    if (MaxDps:FindSpell(classtable.InvokeNiuzaotheBlackOx) and CheckSpellCosts(classtable.InvokeNiuzaotheBlackOx, 'InvokeNiuzaotheBlackOx')) and cooldown[classtable.InvokeNiuzaotheBlackOx].ready then
        MaxDps:GlowCooldown(classtable.InvokeNiuzaotheBlackOx, cooldown[classtable.InvokeNiuzaotheBlackOx].ready)
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
    --if (MaxDps:FindSpell(classtable.PurifyingBrew) and CheckSpellCosts(classtable.PurifyingBrew, 'PurifyingBrew')) and (( not buff[classtable.BlackoutComboBuff].up )) and cooldown[classtable.PurifyingBrew].ready then
    --    MaxDps:GlowCooldown(classtable.PurifyingBrew, cooldown[classtable.PurifyingBrew].ready)
    --end
    if (MaxDps:FindSpell(classtable.BlackOxBrew) and CheckSpellCosts(classtable.BlackOxBrew, 'BlackOxBrew')) and (Energy + EnergyRegen <= 40) and cooldown[classtable.BlackOxBrew].ready then
        return classtable.BlackOxBrew
    end
    if (MaxDps:FindSpell(classtable.BreathofFire) and CheckSpellCosts(classtable.BreathofFire, 'BreathofFire')) and (buff[classtable.CharredPassionsBuff].remains <cooldown[classtable.BlackoutKick].remains and ( buff[classtable.BlackoutComboBuff].up or not talents[classtable.BlackoutCombo] )) and cooldown[classtable.BreathofFire].ready then
        return classtable.BreathofFire
    end
    if (MaxDps:FindSpell(classtable.BonedustBrew) and CheckSpellCosts(classtable.BonedustBrew, 'BonedustBrew')) and cooldown[classtable.BonedustBrew].ready then
        return classtable.BonedustBrew
    end
    if (MaxDps:FindSpell(classtable.ExplodingKeg) and CheckSpellCosts(classtable.ExplodingKeg, 'ExplodingKeg')) and (( ( buff[classtable.BonedustBrewBuff].up ) or ( cooldown[classtable.BonedustBrew].remains >= 20 ) )) and cooldown[classtable.ExplodingKeg].ready then
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
    if (MaxDps:FindSpell(classtable.RushingJadeWind) and CheckSpellCosts(classtable.RushingJadeWind, 'RushingJadeWind')) and (talents[classtable.RushingJadeWind]) and cooldown[classtable.RushingJadeWind].ready then
        return classtable.RushingJadeWind
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (targets >2) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.ChiBurst) and CheckSpellCosts(classtable.ChiBurst, 'ChiBurst')) and cooldown[classtable.ChiBurst].ready then
        return classtable.ChiBurst
    end
end
function Brewmaster:rotation_boc()
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    --if (MaxDps:FindSpell(classtable.PurifyingBrew) and CheckSpellCosts(classtable.PurifyingBrew, 'PurifyingBrew')) and (( not buff[classtable.BlackoutComboBuff].up and ( not buff[classtable.RecentPurifiesBuff].up or cooldown[classtable.PurifyingBrew].charges >( 1 + (talents[classtable.ImprovedPurifyingBrew] and talents[classtable.ImprovedPurifyingBrew] or 0) - 0.1 ) ) ) and talents[classtable.ImprovedInvokeNiuzaotheBlackOx] and ( cooldown[classtable.WeaponsofOrder].remains >40 or cooldown[classtable.WeaponsofOrder].remains <5 )) and cooldown[classtable.PurifyingBrew].ready then
    --    MaxDps:GlowCooldown(classtable.PurifyingBrew, cooldown[classtable.PurifyingBrew].ready)
    --end
    if (MaxDps:FindSpell(classtable.WeaponsofOrder) and CheckSpellCosts(classtable.WeaponsofOrder, 'WeaponsofOrder')) and (( buff[classtable.RecentPurifiesBuff].up ) and talents[classtable.ImprovedInvokeNiuzaotheBlackOx]) and cooldown[classtable.WeaponsofOrder].ready then
        MaxDps:GlowCooldown(classtable.WeaponsofOrder, cooldown[classtable.WeaponsofOrder].ready)
    end
    if (MaxDps:FindSpell(classtable.InvokeNiuzaotheBlackOx) and CheckSpellCosts(classtable.InvokeNiuzaotheBlackOx, 'InvokeNiuzaotheBlackOx')) and (( not buff[classtable.InvokeNiuzaotheBlackOxBuff].up and buff[classtable.RecentPurifiesBuff].up and buff[classtable.WeaponsofOrderBuff].remains <14 ) and talents[classtable.ImprovedInvokeNiuzaotheBlackOx]) and cooldown[classtable.InvokeNiuzaotheBlackOx].ready then
        MaxDps:GlowCooldown(classtable.InvokeNiuzaotheBlackOx, cooldown[classtable.InvokeNiuzaotheBlackOx].ready)
    end
    if (MaxDps:FindSpell(classtable.InvokeNiuzaotheBlackOx) and CheckSpellCosts(classtable.InvokeNiuzaotheBlackOx, 'InvokeNiuzaotheBlackOx')) and (( debuff[classtable.WeaponsofOrderDebuffDeBuff].count >3 ) and not talents[classtable.ImprovedInvokeNiuzaotheBlackOx]) and cooldown[classtable.InvokeNiuzaotheBlackOx].ready then
        MaxDps:GlowCooldown(classtable.InvokeNiuzaotheBlackOx, cooldown[classtable.InvokeNiuzaotheBlackOx].ready)
    end
    if (MaxDps:FindSpell(classtable.InvokeNiuzaotheBlackOx) and CheckSpellCosts(classtable.InvokeNiuzaotheBlackOx, 'InvokeNiuzaotheBlackOx')) and (( not talents[classtable.WeaponsofOrder] )) and cooldown[classtable.InvokeNiuzaotheBlackOx].ready then
        MaxDps:GlowCooldown(classtable.InvokeNiuzaotheBlackOx, cooldown[classtable.InvokeNiuzaotheBlackOx].ready)
    end
    if (MaxDps:FindSpell(classtable.WeaponsofOrder) and CheckSpellCosts(classtable.WeaponsofOrder, 'WeaponsofOrder')) and (( talents[classtable.WeaponsofOrder] ) and not talents[classtable.ImprovedInvokeNiuzaotheBlackOx]) and cooldown[classtable.WeaponsofOrder].ready then
        MaxDps:GlowCooldown(classtable.WeaponsofOrder, cooldown[classtable.WeaponsofOrder].ready)
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
    --if (MaxDps:FindSpell(classtable.PurifyingBrew) and CheckSpellCosts(classtable.PurifyingBrew, 'PurifyingBrew')) and (( not buff[classtable.BlackoutComboBuff].up ) and not talents[classtable.ImprovedInvokeNiuzaotheBlackOx]) and cooldown[classtable.PurifyingBrew].ready then
    --    MaxDps:GlowCooldown(classtable.PurifyingBrew, cooldown[classtable.PurifyingBrew].ready)
    --end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.BlackOxBrew) and CheckSpellCosts(classtable.BlackOxBrew, 'BlackOxBrew')) and (( Energy + EnergyRegen <= 40 )) and cooldown[classtable.BlackOxBrew].ready then
        return classtable.BlackOxBrew
    end
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (( buff[classtable.BlackoutComboBuff].up and targets == 1 )) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (MaxDps:FindSpell(classtable.BreathofFire) and CheckSpellCosts(classtable.BreathofFire, 'BreathofFire')) and (( buff[classtable.CharredPassionsBuff].remains <cooldown[classtable.BlackoutKick].remains )) and cooldown[classtable.BreathofFire].ready then
        return classtable.BreathofFire
    end
    if (MaxDps:FindSpell(classtable.KegSmash) and CheckSpellCosts(classtable.KegSmash, 'KegSmash')) and (( buff[classtable.WeaponsofOrderBuff].up and debuff[classtable.WeaponsofOrderDebuffDeBuff].count <= 3 )) and cooldown[classtable.KegSmash].ready then
        return classtable.KegSmash
    end
    if (MaxDps:FindSpell(classtable.BonedustBrew) and CheckSpellCosts(classtable.BonedustBrew, 'BonedustBrew')) and (( timeInCombat <10 and debuff[classtable.WeaponsofOrderDebuffDeBuff].count >3 ) or ( timeInCombat >10 and talents[classtable.WeaponsofOrder] )) and cooldown[classtable.BonedustBrew].ready then
        return classtable.BonedustBrew
    end
    if (MaxDps:FindSpell(classtable.BonedustBrew) and CheckSpellCosts(classtable.BonedustBrew, 'BonedustBrew')) and (( not talents[classtable.WeaponsofOrder] )) and cooldown[classtable.BonedustBrew].ready then
        return classtable.BonedustBrew
    end
    if (MaxDps:FindSpell(classtable.ExplodingKeg) and CheckSpellCosts(classtable.ExplodingKeg, 'ExplodingKeg')) and (( buff[classtable.BonedustBrewBuff].up )) and cooldown[classtable.ExplodingKeg].ready then
        return classtable.ExplodingKeg
    end
    if (MaxDps:FindSpell(classtable.ExplodingKeg) and CheckSpellCosts(classtable.ExplodingKeg, 'ExplodingKeg')) and (( cooldown[classtable.BonedustBrew].remains >= 20 )) and cooldown[classtable.ExplodingKeg].ready then
        return classtable.ExplodingKeg
    end
    if (MaxDps:FindSpell(classtable.ExplodingKeg) and CheckSpellCosts(classtable.ExplodingKeg, 'ExplodingKeg')) and (( not talents[classtable.BonedustBrew] )) and cooldown[classtable.ExplodingKeg].ready then
        return classtable.ExplodingKeg
    end
    if (MaxDps:FindSpell(classtable.KegSmash) and CheckSpellCosts(classtable.KegSmash, 'KegSmash')) and cooldown[classtable.KegSmash].ready then
        return classtable.KegSmash
    end
    if (MaxDps:FindSpell(classtable.RushingJadeWind) and CheckSpellCosts(classtable.RushingJadeWind, 'RushingJadeWind')) and (talents[classtable.RushingJadeWind]) and cooldown[classtable.RushingJadeWind].ready then
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
    if (MaxDps:FindSpell(classtable.ChiBurst) and CheckSpellCosts(classtable.ChiBurst, 'ChiBurst')) and cooldown[classtable.ChiBurst].ready then
        return classtable.ChiBurst
    end
end

function Brewmaster:callaction()
    if (MaxDps:FindSpell(classtable.SpearHandStrike) and CheckSpellCosts(classtable.SpearHandStrike, 'SpearHandStrike')) and (UnitCastingInfo('target') and select(8,UnitCastingInfo('target')) == false) and cooldown[classtable.SpearHandStrike].ready then
        MaxDps:GlowCooldown(classtable.SpearHandStrike, select(8,UnitCastingInfo('target') == false) and cooldown[classtable.SpearHandStrike].ready)
    end
    if (MaxDps:FindSpell(classtable.DiffuseMagic) and CheckSpellCosts(classtable.DiffuseMagic, 'DiffuseMagic')) and cooldown[classtable.DiffuseMagic].ready then
        MaxDps:GlowCooldown(classtable.DiffuseMagic, cooldown[classtable.DiffuseMagic].ready)
    end
    if (MaxDps:FindSpell(classtable.Vivify) and CheckSpellCosts(classtable.Vivify, 'Vivify')) and (curentHP <= 65 and buff[classtable.VivaciousVivificationBuff].up) and cooldown[classtable.Vivify].ready then
        MaxDps:GlowCooldown(classtable.Vivify, cooldown[classtable.Vivify].ready)
    end
    --if (MaxDps:FindSpell(classtable.PurifyingBrew) and CheckSpellCosts(classtable.PurifyingBrew, 'PurifyingBrew')) and ((UnitThreatSituation('player') == 2 or UnitThreatSituation('player') == 3) and true and ( buff[classtable.PurifiedChiBuff].up and buff[classtable.PurifiedChiBuff].remains <1.5 * gcd ) or cooldown[classtable.CelestialBrew].remains <2 * gcd and cooldown[classtable.PurifyingBrew].charges >1.5) and cooldown[classtable.PurifyingBrew].ready then
    --    MaxDps:GlowCooldown(classtable.PurifyingBrew, cooldown[classtable.PurifyingBrew].ready)
    --end
    if (MaxDps:FindSpell(classtable.CelestialBrew) and CheckSpellCosts(classtable.CelestialBrew, 'CelestialBrew')) and ((UnitThreatSituation('player') == 2 or UnitThreatSituation('player') == 3) and ( not talents[classtable.ImprovedCelestialBrew] or buff[classtable.PurifiedChiBuff].up ) and ( not buff[classtable.BlackoutComboBuff].up )) and cooldown[classtable.CelestialBrew].ready then
        MaxDps:GlowCooldown(classtable.CelestialBrew, cooldown[classtable.CelestialBrew].ready)
    end
    --if (MaxDps:FindSpell(classtable.PurifyingBrew) and CheckSpellCosts(classtable.PurifyingBrew, 'PurifyingBrew')) and (( not buff[classtable.BlackoutComboBuff].up ) and staggerPercent >= 12) and cooldown[classtable.PurifyingBrew].ready then
    --    MaxDps:GlowCooldown(classtable.PurifyingBrew, cooldown[classtable.PurifyingBrew].ready)
    --end
    --if (MaxDps:FindSpell(classtable.PurifyingBrew) and CheckSpellCosts(classtable.PurifyingBrew, 'PurifyingBrew')) and (( not buff[classtable.BlackoutComboBuff].up ) and staggerPercent >= 12 * 0.5) and cooldown[classtable.PurifyingBrew].ready then
    --    MaxDps:GlowCooldown(classtable.PurifyingBrew, cooldown[classtable.PurifyingBrew].ready)
    --end
    --if (MaxDps:FindSpell(classtable.PurifyingBrew) and CheckSpellCosts(classtable.PurifyingBrew, 'PurifyingBrew')) and (( not buff[classtable.BlackoutComboBuff].up ) and staggerPercent >= 6) and cooldown[classtable.PurifyingBrew].ready then
    --    MaxDps:GlowCooldown(classtable.PurifyingBrew, cooldown[classtable.PurifyingBrew].ready)
    --end
    --if (MaxDps:FindSpell(classtable.PurifyingBrew) and CheckSpellCosts(classtable.PurifyingBrew, 'PurifyingBrew')) and (( not buff[classtable.BlackoutComboBuff].up ) and staggerPercent >= 6 * 0.5) and cooldown[classtable.PurifyingBrew].ready then
    --    MaxDps:GlowCooldown(classtable.PurifyingBrew, cooldown[classtable.PurifyingBrew].ready)
    --end
    --if (MaxDps:FindSpell(classtable.PurifyingBrew) and CheckSpellCosts(classtable.PurifyingBrew, 'PurifyingBrew')) and (( not buff[classtable.BlackoutComboBuff].up ) and staggerPercent >20) and cooldown[classtable.PurifyingBrew].ready then
    --    MaxDps:GlowCooldown(classtable.PurifyingBrew, cooldown[classtable.PurifyingBrew].ready)
    --end
    --if (MaxDps:FindSpell(classtable.PurifyingBrew) and CheckSpellCosts(classtable.PurifyingBrew, 'PurifyingBrew')) and (( not buff[classtable.BlackoutComboBuff].up ) and staggerPercent >10) and cooldown[classtable.PurifyingBrew].ready then
    --    MaxDps:GlowCooldown(classtable.PurifyingBrew, cooldown[classtable.PurifyingBrew].ready)
    --end
    if (MaxDps:FindSpell(classtable.DampenHarm) and CheckSpellCosts(classtable.DampenHarm, 'DampenHarm')) and (curentHP <75 and not buff[classtable.FortifyingBrewBuff].up) and cooldown[classtable.DampenHarm].ready then
        MaxDps:GlowCooldown(classtable.DampenHarm, cooldown[classtable.DampenHarm].ready)
    end
    if (MaxDps:FindSpell(classtable.FortifyingBrew) and CheckSpellCosts(classtable.FortifyingBrew, 'FortifyingBrew')) and (curentHP <50 and ( not buff[classtable.DampenHarmBuff].up )) and cooldown[classtable.FortifyingBrew].ready then
        MaxDps:GlowCooldown(classtable.FortifyingBrew, cooldown[classtable.FortifyingBrew].ready)
    end
    if (MaxDps:FindSpell(classtable.TouchofDeath) and CheckSpellCosts(classtable.TouchofDeath, 'TouchofDeath')) and cooldown[classtable.TouchofDeath].ready then
        return classtable.TouchofDeath
    end
    local itemsCheck = Brewmaster:items()
    if itemsCheck then
        return itemsCheck
    end
    if (MaxDps:FindSpell(classtable.ExpelHarm) and CheckSpellCosts(classtable.ExpelHarm, 'ExpelHarm')) and (buff[classtable.GiftoftheOxBuff].count >4 and curentHP <65) and cooldown[classtable.ExpelHarm].ready then
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
