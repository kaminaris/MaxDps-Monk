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

local Windwalker = {}


local function CheckSpellCosts(spell,spellstring)
    if not IsSpellKnown(spell) then return false end
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



local function CheckTrinketNames(checkName)
    --if slot == 1 then
    --    slot = 13
    --end
    --if slot == 2 then
    --    slot = 14
    --end
    for i=13,14 do
        local itemID = GetInventoryItemID('player', i)
        local itemName = C_Item.GetItemInfo(itemID)
        if checkName == itemName then
            return true
        end
    end
    return false
end


local function CheckTrinketCooldown(slot)
    if slot == 1 then
        slot = 13
    end
    if slot == 2 then
        slot = 14
    end
    if slot == 13 or slot == 14 then
        local itemID = GetInventoryItemID('player', slot)
        local _, duration, _ = C_Item.GetItemCooldown(itemID)
        if duration == 0 then return true else return false end
    else
        local tOneitemID = GetInventoryItemID('player', 13)
        local tTwoitemID = GetInventoryItemID('player', 14)
        local tOneitemName = C_Item.GetItemInfo(tOneitemID)
        local tTwoitemName = C_Item.GetItemInfo(tTwoitemID)
        if tOneitemName == slot then
            local _, duration, _ = C_Item.GetItemCooldown(tOneitemID)
            if duration == 0 then return true else return false end
        end
        if tTwoitemName == slot then
            local _, duration, _ = C_Item.GetItemCooldown(tTwoitemID)
            if duration == 0 then return true else return false end
        end
    end
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


function Windwalker:trinkets()
end
function Windwalker:cooldowns()
    if (CheckSpellCosts(classtable.InvokeXuentheWhiteTiger, 'InvokeXuentheWhiteTiger')) and (( targets >2 or debuff[classtable.AcclamationDeBuff].up ) and ( CheckPrevSpell(classtable.TigerPalm) or Energy <60 and not talents[classtable.InnerPeace] or Energy <55 and talents[classtable.InnerPeace] or Chi >3 )) and cooldown[classtable.InvokeXuentheWhiteTiger].ready then
        MaxDps:GlowCooldown(classtable.InvokeXuentheWhiteTiger, cooldown[classtable.InvokeXuentheWhiteTiger].ready)
    end
    if (CheckSpellCosts(classtable.StormEarthandFire, 'StormEarthandFire')) and (( buff[classtable.InvokersDelightBuff].up or ttd >15 and cooldown[classtable.StormEarthandFire].fullRecharge <cooldown[classtable.InvokeXuentheWhiteTiger].remains and cooldown[classtable.StrikeoftheWindlord].remains <2 ) or boss and ttd <= 30 or MaxDps:Bloodlust() and cooldown[classtable.InvokeXuentheWhiteTiger].remains) and cooldown[classtable.StormEarthandFire].ready then
        MaxDps:GlowCooldown(classtable.StormEarthandFire, cooldown[classtable.StormEarthandFire].ready)
    end
    if (CheckSpellCosts(classtable.TouchofKarma, 'TouchofKarma')) and cooldown[classtable.TouchofKarma].ready then
        MaxDps:GlowCooldown(classtable.TouchofKarma, cooldown[classtable.TouchofKarma].ready)
    end
end
function Windwalker:default_aoe()
    if (CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (( Energy >55 and talents[classtable.InnerPeace] or Energy >60 and not talents[classtable.InnerPeace] ) and IsComboStrike(classtable.TigerPalm) and ChiMax - Chi >= 2 and buff[classtable.TeachingsoftheMonasteryBuff].count <4 and not buff[classtable.OrderedElementsBuff].up and ( not (MaxDps.tier and MaxDps.tier[30].count >= 2) or (MaxDps.tier and MaxDps.tier[30].count >= 2) and buff[classtable.DanceofChijiBuff].up and not buff[classtable.BlackoutReinforcementBuff].up and talents[classtable.EnergyBurst] ) or buff[classtable.StormEarthandFireBuff].remains >3 and cooldown[classtable.FistsofFury].remains <3 and Chi <2) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (CheckSpellCosts(classtable.TouchofDeath, 'TouchofDeath')) and cooldown[classtable.TouchofDeath].ready then
        return classtable.TouchofDeath
    end
    if (CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (buff[classtable.DanceofChijiBuff].count == 2 and IsComboStrike(classtable.SpinningCraneKick)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.OrderedElementsBuff].remains <2 and buff[classtable.StormEarthandFireBuff].up and talents[classtable.OrderedElements]) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (CheckSpellCosts(classtable.CelestialConduit, 'CelestialConduit')) and (buff[classtable.StormEarthandFireBuff].up and buff[classtable.OrderedElementsBuff].up and cooldown[classtable.StrikeoftheWindlord].remains) and cooldown[classtable.CelestialConduit].ready then
        return classtable.CelestialConduit
    end
    if (CheckSpellCosts(classtable.ChiBurst, 'ChiBurst')) and (IsComboStrike(classtable.ChiBurst)) and cooldown[classtable.ChiBurst].ready then
        return classtable.ChiBurst
    end
    if (CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (buff[classtable.DanceofChijiBuff].count == 2 or buff[classtable.DanceofChijiBuff].up and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.StormEarthandFireBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (CheckSpellCosts(classtable.WhirlingDragonPunch, 'WhirlingDragonPunch')) and cooldown[classtable.WhirlingDragonPunch].ready then
        return classtable.WhirlingDragonPunch
    end
    if (CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.TeachingsoftheMonasteryBuff].count == 8 and talents[classtable.ShadowboxingTreads]) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (talents[classtable.XuensBattlegear] or cooldown[classtable.WhirlingDragonPunch].remains <3) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (IsComboStrike(classtable.SpinningCraneKick)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (not talents[classtable.KnowledgeoftheBrokenTemple] and buff[classtable.TeachingsoftheMonasteryBuff].count == 4 and talents[classtable.ShadowboxingTreads]) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and ChiDeficit >= 2 and ( not buff[classtable.OrderedElementsBuff].up or EnergyTimeToMax <= gcd * 3 )) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (CheckSpellCosts(classtable.CracklingJadeLightning, 'CracklingJadeLightning')) and (buff[classtable.TheEmperorsCapacitorBuff].count >19 and not buff[classtable.OrderedElementsBuff].up and IsComboStrike(classtable.CracklingJadeLightning) and talents[classtable.PoweroftheThunderKing]) and cooldown[classtable.CracklingJadeLightning].ready then
        return classtable.CracklingJadeLightning
    end
    if (CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and talents[classtable.ShadowboxingTreads]) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (CheckSpellCosts(classtable.CracklingJadeLightning, 'CracklingJadeLightning')) and (buff[classtable.TheEmperorsCapacitorBuff].count >19 and not buff[classtable.OrderedElementsBuff].up and IsComboStrike(classtable.CracklingJadeLightning)) and cooldown[classtable.CracklingJadeLightning].ready then
        return classtable.CracklingJadeLightning
    end
    if (CheckSpellCosts(classtable.JadefireStomp, 'JadefireStomp')) and cooldown[classtable.JadefireStomp].ready then
        return classtable.JadefireStomp
    end
    if (CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and buff[classtable.OrderedElementsBuff].up and ChiDeficit >= 1) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
end
function Windwalker:default_st()
    if (CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (( Energy >55 and talents[classtable.InnerPeace] or Energy >60 and not talents[classtable.InnerPeace] ) and IsComboStrike(classtable.TigerPalm) and ChiMax - Chi >= 2 and buff[classtable.TeachingsoftheMonasteryBuff].count <4 and not buff[classtable.OrderedElementsBuff].up and ( not (MaxDps.tier and MaxDps.tier[30].count >= 2) or (MaxDps.tier and MaxDps.tier[30].count >= 2) and buff[classtable.DanceofChijiBuff].up and not buff[classtable.BlackoutReinforcementBuff].up and talents[classtable.EnergyBurst] )) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (CheckSpellCosts(classtable.TouchofDeath, 'TouchofDeath')) and cooldown[classtable.TouchofDeath].ready then
        return classtable.TouchofDeath
    end
    if (CheckSpellCosts(classtable.CelestialConduit, 'CelestialConduit')) and (buff[classtable.StormEarthandFireBuff].up and buff[classtable.OrderedElementsBuff].up and cooldown[classtable.StrikeoftheWindlord].remains) and cooldown[classtable.CelestialConduit].ready then
        return classtable.CelestialConduit
    end
    if (CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (not ( UnitExists('pet') and UnitName('pet')  == 'xuen' ) and CheckPrevSpell(classtable.TigerPalm) or buff[classtable.StormEarthandFireBuff].up and talents[classtable.OrderedElements]) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (talents[classtable.GaleForce] and buff[classtable.InvokersDelightBuff].up) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and (buff[classtable.PowerInfusionBuff].up and MaxDps:Bloodlust()) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.PowerInfusionBuff].up and MaxDps:Bloodlust()) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.TeachingsoftheMonasteryBuff].count == 8) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (CheckSpellCosts(classtable.WhirlingDragonPunch, 'WhirlingDragonPunch')) and cooldown[classtable.WhirlingDragonPunch].ready then
        return classtable.WhirlingDragonPunch
    end
    if (CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (timeInCombat >5) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and (MaxDps.tier and MaxDps.tier[30].count >= 2) and not buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and (buff[classtable.OrderedElementsBuff].remains >timeShift or not buff[classtable.OrderedElementsBuff].up or buff[classtable.OrderedElementsBuff].remains <= gcd) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and (MaxDps.tier and MaxDps.tier[30].count >= 2) and not buff[classtable.BlackoutReinforcementBuff].up and talents[classtable.EnergyBurst]) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and ChiDeficit >= 2 and ( not buff[classtable.OrderedElementsBuff].up or EnergyTimeToMax <= gcd * 3 )) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (CheckSpellCosts(classtable.JadefireStomp, 'JadefireStomp')) and (talents[classtable.SingularlyFocusedJade] or talents[classtable.JadefireHarmony]) and cooldown[classtable.JadefireStomp].ready then
        return classtable.JadefireStomp
    end
    if (CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (CheckSpellCosts(classtable.ChiBurst, 'ChiBurst')) and (not buff[classtable.OrderedElementsBuff].up) and cooldown[classtable.ChiBurst].ready then
        return classtable.ChiBurst
    end
    if (CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and ( buff[classtable.OrderedElementsBuff].up or buff[classtable.BokProcBuff].up and ChiDeficit >= 1 and talents[classtable.EnergyBurst] )) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and ( buff[classtable.OrderedElementsBuff].up or EnergyTimeToMax >= gcd * 3 and talents[classtable.SequencedStrikes] and talents[classtable.EnergyBurst] or not talents[classtable.SequencedStrikes] or not talents[classtable.EnergyBurst] or buff[classtable.DanceofChijiBuff].count == 2 or buff[classtable.DanceofChijiBuff].remains <= gcd * 3 )) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (CheckSpellCosts(classtable.CracklingJadeLightning, 'CracklingJadeLightning')) and (buff[classtable.TheEmperorsCapacitorBuff].count >19 and not buff[classtable.OrderedElementsBuff].up and IsComboStrike(classtable.CracklingJadeLightning)) and cooldown[classtable.CracklingJadeLightning].ready then
        return classtable.CracklingJadeLightning
    end
    if (CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (CheckSpellCosts(classtable.JadefireStomp, 'JadefireStomp')) and cooldown[classtable.JadefireStomp].ready then
        return classtable.JadefireStomp
    end
    if (CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and buff[classtable.OrderedElementsBuff].up and ChiDeficit >= 1) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (CheckSpellCosts(classtable.ChiBurst, 'ChiBurst')) and cooldown[classtable.ChiBurst].ready then
        return classtable.ChiBurst
    end
    if (CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.OrderedElementsBuff].up and talents[classtable.HitCombo]) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.OrderedElementsBuff].up and not talents[classtable.HitCombo]) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
end

function Windwalker:callaction()
    if (CheckSpellCosts(classtable.SpearHandStrike, 'SpearHandStrike')) and (UnitCastingInfo('target') and select(8,UnitCastingInfo('target')) == false) and cooldown[classtable.SpearHandStrike].ready then
        MaxDps:GlowCooldown(classtable.SpearHandStrike, ( select(8,UnitCastingInfo('target')) ~= nil and not select(8,UnitCastingInfo('target')) or select(7,UnitChannelInfo('target')) ~= nil and not select(7,UnitChannelInfo('target'))) )
    end
    local trinketsCheck = Windwalker:trinkets()
    if trinketsCheck then
        return trinketsCheck
    end
    if (talents[classtable.StormEarthandFire]) then
        local cooldownsCheck = Windwalker:cooldowns()
        if cooldownsCheck then
            return Windwalker:cooldowns()
        end
    end
    if (targets >= 3) then
        local default_aoeCheck = Windwalker:default_aoe()
        if default_aoeCheck then
            return Windwalker:default_aoe()
        end
    end
    if (targets <3) then
        local default_stCheck = Windwalker:default_st()
        if default_stCheck then
            return Windwalker:default_st()
        end
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
    classtable.AcclamationDeBuff = 451433
    classtable.InvokersDelightBuff = 388663
    classtable.bloodlust = 0
    classtable.TeachingsoftheMonasteryBuff = 202090
    classtable.OrderedElementsBuff = 0
    classtable.DanceofChijiBuff = 325202
    classtable.BlackoutReinforcementBuff = 424454
    classtable.StormEarthandFireBuff = 137639
    classtable.TheEmperorsCapacitorBuff = 0
    classtable.PowerInfusionBuff = 10060
    classtable.BokProcBuff = 116768

    local callactionCheck = Windwalker:callaction()
    if callactionCheck then
        return Windwalker:callaction()
    end
end
