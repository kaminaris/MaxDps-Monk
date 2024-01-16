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

local sync_serenity
local hold_xuen
local hold_tp_rsk
local hold_tp_bdb

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



local function CheckEquipped(checkName)
    for i=1,14 do
        local itemID = GetInventoryItemID('player', i)
        local itemName = itemID and GetItemInfo(itemID) or ''
        if checkName == itemName then
            return true
        end
    end
    return false
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
        local itemName = GetItemInfo(itemID)
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
    local itemID = GetInventoryItemID('player', slot)
    local startTime, duration, enable = GetItemCooldown(itemID)
    if duration == 0 then return true else return false end
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


local function PreCombatUpdate()
if ( CheckEquipped('NeltharionsCallToDominance') or CheckEquipped('AshesoftheEmbersoul') or CheckEquipped('MirrorofFracturedTomorrows') or CheckEquipped('WitherbarksBranch') ) and not ( (select(2,IsInInstance()) == 'party') or (select(2,IsInInstance()) == 'party') ) then
    sync_serenity = 1
else
    sync_serenity = 0
end
hold_xuen = not talents[classtable.InvokeXuentheWhiteTiger] or cooldown[classtable.InvokeXuentheWhiteTiger].duration >ttd
hold_tp_rsk = not (debuff[classtable.SkyreachExhaustionDeBuff].duration <1) and cooldown[classtable.RisingSunKick].duration <1 and ( MaxDps.tier and MaxDps.tier[30].count >= 2 or targets <5 )
hold_tp_bdb = not (debuff[classtable.SkyreachExhaustionDeBuff].duration <1) and cooldown[classtable.BonedustBrew].duration <1 and targets == 1
end

local function opener()
    if (MaxDps:FindSpell(classtable.SummonWhiteTigerStatue) and CheckSpellCosts(classtable.SummonWhiteTigerStatue, 'SummonWhiteTigerStatue')) and cooldown[classtable.SummonWhiteTigerStatue].ready then
        return classtable.SummonWhiteTigerStatue
    end
    if (MaxDps:FindSpell(classtable.ExpelHarm) and CheckSpellCosts(classtable.ExpelHarm, 'ExpelHarm')) and (talents[classtable.ChiBurst] and ChiMax - Chi >= 3) and cooldown[classtable.ExpelHarm].ready then
        return classtable.ExpelHarm
    end
    if (MaxDps:FindSpell(classtable.FaelineStomp) and CheckSpellCosts(classtable.FaelineStomp, 'FaelineStomp') and talents[classtable.FaelineStomp]) and (debuff[classtable.FaeExposureDamageDeBuff].remains <2 and not (debuff[classtable.SkyreachExhaustionDeBuff].duration <2) and not debuff[classtable.SkyreachExhaustionDeBuff].up) and cooldown[classtable.FaelineStomp].ready then
        return classtable.FaelineStomp
    end
    if (MaxDps:FindSpell(classtable.ExpelHarm) and CheckSpellCosts(classtable.ExpelHarm, 'ExpelHarm')) and (talents[classtable.ChiBurst] and Chi == 3) and cooldown[classtable.ExpelHarm].ready then
        return classtable.ExpelHarm
    end
    if (MaxDps:FindSpell(classtable.ChiWave) and CheckSpellCosts(classtable.ChiWave, 'ChiWave')) and (ChiMax - Chi == 2) and cooldown[classtable.ChiWave].ready then
        return classtable.ChiWave
    end
    if (MaxDps:FindSpell(classtable.ExpelHarm) and CheckSpellCosts(classtable.ExpelHarm, 'ExpelHarm')) and cooldown[classtable.ExpelHarm].ready then
        return classtable.ExpelHarm
    end
    if (MaxDps:FindSpell(classtable.ChiBurst) and CheckSpellCosts(classtable.ChiBurst, 'ChiBurst') and talents[classtable.ChiBurst]) and (Chi >1 and ChiMax - Chi >= 2) and cooldown[classtable.ChiBurst].ready then
        return classtable.ChiBurst
    end
end
local function trinkets()
end
local function cd_sef()
    if (MaxDps:FindSpell(classtable.InvokeXuentheWhiteTiger) and CheckSpellCosts(classtable.InvokeXuentheWhiteTiger, 'InvokeXuentheWhiteTiger') and talents[classtable.InvokeXuentheWhiteTiger]) and (not hold_xuen and ttd >25 and talents[classtable.BonedustBrew] and cooldown[classtable.BonedustBrew].duration <= 5 and ( targets <3 and Chi >= 3 or targets >= 3 and Chi >= 2 ) or ttd <25) and cooldown[classtable.InvokeXuentheWhiteTiger].ready then
        return classtable.InvokeXuentheWhiteTiger
    end
    if (MaxDps:FindSpell(classtable.InvokeXuentheWhiteTiger) and CheckSpellCosts(classtable.InvokeXuentheWhiteTiger, 'InvokeXuentheWhiteTiger') and talents[classtable.InvokeXuentheWhiteTiger]) and (ttd >25 and ttd >120 and ( not CheckTrinketNames('Ashes of the Embersoul') and not CheckTrinketNames('Witherbarks Branch') and not CheckTrinketNames('Ashes of the Embersoul') and not CheckTrinketNames('Witherbarks Branch') or ( CheckTrinketNames('Ashes of the Embersoul') or CheckTrinketNames('Witherbarks Branch') ) and not CheckTrinketCooldown(1) or ( CheckTrinketNames('Ashes of the Embersoul') or CheckTrinketNames('Witherbarks Branch') ) and not CheckTrinketCooldown(2) )) and cooldown[classtable.InvokeXuentheWhiteTiger].ready then
        return classtable.InvokeXuentheWhiteTiger
    end
    if (MaxDps:FindSpell(classtable.InvokeXuentheWhiteTiger) and CheckSpellCosts(classtable.InvokeXuentheWhiteTiger, 'InvokeXuentheWhiteTiger') and talents[classtable.InvokeXuentheWhiteTiger]) and (ttd <60 and ( debuff[classtable.SkyreachExhaustionDeBuff].remains <2 or debuff[classtable.SkyreachExhaustionDeBuff].remains >55 ) and not cooldown[classtable.Serenity].duration and targets <3) and cooldown[classtable.InvokeXuentheWhiteTiger].ready then
        return classtable.InvokeXuentheWhiteTiger
    end
    if (MaxDps:FindSpell(classtable.StormEarthandFire) and CheckSpellCosts(classtable.StormEarthandFire, 'StormEarthandFire') and talents[classtable.StormEarthandFire]) and (talents[classtable.BonedustBrew] and ( ttd <30 and cooldown[classtable.BonedustBrew].duration <4 and Chi >= 4 or buff[classtable.BonedustBrewBuff].up or not (targets==5) and targets >= 3 and cooldown[classtable.BonedustBrew].duration <= 2 and Chi >= 2 ) and ( ( UnitExists('pet') and UnitName('pet')  == 'xuen' ) or cooldown[classtable.InvokeXuentheWhiteTiger].duration >cooldown[classtable.StormEarthandFire].fullRecharge )) and cooldown[classtable.StormEarthandFire].ready then
        return classtable.StormEarthandFire
    end
    if (MaxDps:FindSpell(classtable.StormEarthandFire) and CheckSpellCosts(classtable.StormEarthandFire, 'StormEarthandFire') and talents[classtable.StormEarthandFire]) and (not talents[classtable.BonedustBrew] and ( ( UnitExists('pet') and UnitName('pet')  == 'xuen' ) or ttd >15 and cooldown[classtable.StormEarthandFire].fullRecharge <cooldown[classtable.InvokeXuentheWhiteTiger].duration )) and cooldown[classtable.StormEarthandFire].ready then
        return classtable.StormEarthandFire
    end
    if (MaxDps:FindSpell(classtable.BonedustBrew) and CheckSpellCosts(classtable.BonedustBrew, 'BonedustBrew') and talents[classtable.BonedustBrew]) and (( not buff[classtable.BonedustBrewBuff] and buff[classtable.StormEarthandFireBuff].up and buff[classtable.StormEarthandFireBuff].remains <11 and (targets==5) ) or ( not buff[classtable.BonedustBrewBuff] and ttd <30 and ttd >10 and (targets==5) and Chi >= 4 ) or ttd <10 or ( not debuff[classtable.SkyreachExhaustionDeBuff].up and targets >= 4 and (GetSpellCount(101546)) >= 2 ) or ( ( UnitExists('pet') and UnitName('pet')  == 'xuen' ) and (targets==5) and targets >= 4 )) and cooldown[classtable.BonedustBrew].ready then
        return classtable.BonedustBrew
    end
    --local bdb_setupCheck = bdb_setup()
    --if (not buff[classtable.BonedustBrewBuff] and talents[classtable.BonedustBrew] and cooldown[classtable.BonedustBrew].duration <= 2 and ( ttd >60 and ( cooldown[classtable.StormEarthandFire].charges >0 or cooldown[classtable.StormEarthandFire].duration >10 ) and ( ( UnitExists('pet') and UnitName('pet')  == 'xuen' ) or cooldown[classtable.InvokeXuentheWhiteTiger].duration >10 or hold_xuen ) or ( ( ( UnitExists('pet') and UnitName('pet')  == 'xuen' ) or cooldown[classtable.InvokeXuentheWhiteTiger].duration >13 ) and ( cooldown[classtable.StormEarthandFire].charges >0 or cooldown[classtable.StormEarthandFire].duration >13 or buff[classtable.StormEarthandFireBuff].up ) ) )) then
    --    if bdb_setupCheck then
    --        return bdb_setup()
    --    end
    --end
    if (MaxDps:FindSpell(classtable.StormEarthandFire) and CheckSpellCosts(classtable.StormEarthandFire, 'StormEarthandFire') and talents[classtable.StormEarthandFire]) and (ttd <20 or ( cooldown[classtable.StormEarthandFire].charges == 2 and cooldown[classtable.InvokeXuentheWhiteTiger].duration >cooldown[classtable.StormEarthandFire].fullRecharge ) and cooldown[classtable.FistsofFury].duration <= 9 and Chi >= 2 and cooldown[classtable.WhirlingDragonPunch].duration <= 12) and cooldown[classtable.StormEarthandFire].ready then
        return classtable.StormEarthandFire
    end
    if (MaxDps:FindSpell(classtable.TouchofDeath) and CheckSpellCosts(classtable.TouchofDeath, 'TouchofDeath')) and ((select(2,IsInInstance()) == 'party') and not buff[classtable.SerenityBuff] and ( IsComboStrike(classtable.TouchofDeath) and targetHP <maxHP ) or ( buff[classtable.HiddenMastersForbiddenTouchBuff].remains <2 ) or ( buff[classtable.HiddenMastersForbiddenTouchBuff].remains >ttd )) and cooldown[classtable.TouchofDeath].ready then
        return classtable.TouchofDeath
    end
    if (MaxDps:FindSpell(classtable.TouchofDeath) and CheckSpellCosts(classtable.TouchofDeath, 'TouchofDeath')) and ((select(2,IsInInstance()) == 'party') and IsComboStrike(classtable.TouchofDeath) and ( ttd >60 or debuff[classtable.BonedustBrewDebuffDeBuff].up or ttd <10 )) and cooldown[classtable.TouchofDeath].ready then
        return classtable.TouchofDeath
    end
    if (MaxDps:FindSpell(classtable.TouchofDeath) and CheckSpellCosts(classtable.TouchofDeath, 'TouchofDeath')) and (not (select(2,IsInInstance()) == 'party') and IsComboStrike(classtable.TouchofDeath)) and cooldown[classtable.TouchofDeath].ready then
        return classtable.TouchofDeath
    end
    if (MaxDps:FindSpell(classtable.TouchofKarma) and CheckSpellCosts(classtable.TouchofKarma, 'TouchofKarma')) and (ttd >90 or ( UnitExists('pet') and UnitName('pet')  == 'xuen' ) or hold_xuen or ttd <16) and cooldown[classtable.TouchofKarma].ready then
        return classtable.TouchofKarma
    end
end
local function cd_serenity()
    if (MaxDps:FindSpell(classtable.InvokeXuentheWhiteTiger) and CheckSpellCosts(classtable.InvokeXuentheWhiteTiger, 'InvokeXuentheWhiteTiger') and talents[classtable.InvokeXuentheWhiteTiger]) and (ttd >16 and not hold_xuen and talents[classtable.BonedustBrew] and cooldown[classtable.BonedustBrew].duration <= 1 or MaxDps:Bloodlust() or ttd <25) and cooldown[classtable.InvokeXuentheWhiteTiger].ready then
        return classtable.InvokeXuentheWhiteTiger
    end
    if (MaxDps:FindSpell(classtable.InvokeXuentheWhiteTiger) and CheckSpellCosts(classtable.InvokeXuentheWhiteTiger, 'InvokeXuentheWhiteTiger') and talents[classtable.InvokeXuentheWhiteTiger]) and (( ttd >16 or ( (select(2,IsInInstance()) == 'party') or (select(2,IsInInstance()) == 'party') ) and cooldown[classtable.Serenity].duration <2 ) and ttd >120 and ( not CheckTrinketNames('Ashes of the Embersoul') and not CheckTrinketNames('Witherbarks Branch') and not CheckTrinketNames('Ashes of the Embersoul') and not CheckTrinketNames('Witherbarks Branch') or ( CheckTrinketNames('Ashes of the Embersoul') or CheckTrinketNames('Witherbarks Branch') ) and not CheckTrinketCooldown(1) or ( CheckTrinketNames('Ashes of the Embersoul') or CheckTrinketNames('Witherbarks Branch') ) and not CheckTrinketCooldown(2) )) and cooldown[classtable.InvokeXuentheWhiteTiger].ready then
        return classtable.InvokeXuentheWhiteTiger
    end
    if (MaxDps:FindSpell(classtable.InvokeXuentheWhiteTiger) and CheckSpellCosts(classtable.InvokeXuentheWhiteTiger, 'InvokeXuentheWhiteTiger') and talents[classtable.InvokeXuentheWhiteTiger]) and (ttd >16 and ttd <60 and ( debuff[classtable.SkyreachExhaustionDeBuff].remains <2 or debuff[classtable.SkyreachExhaustionDeBuff].remains >55 ) and not cooldown[classtable.Serenity].duration and targets <3) and cooldown[classtable.InvokeXuentheWhiteTiger].ready then
        return classtable.InvokeXuentheWhiteTiger
    end
    if (MaxDps:FindSpell(classtable.InvokeXuentheWhiteTiger) and CheckSpellCosts(classtable.InvokeXuentheWhiteTiger, 'InvokeXuentheWhiteTiger') and talents[classtable.InvokeXuentheWhiteTiger]) and ((select(2,IsInInstance()) == 'party') and talents[classtable.BonedustBrew] and ttd >16 and not cooldown[classtable.Serenity].duration and cooldown[classtable.BonedustBrew].duration <2) and cooldown[classtable.InvokeXuentheWhiteTiger].ready then
        return classtable.InvokeXuentheWhiteTiger
    end
    if (MaxDps:FindSpell(classtable.BonedustBrew) and CheckSpellCosts(classtable.BonedustBrew, 'BonedustBrew') and talents[classtable.BonedustBrew]) and (buff[classtable.InvokersDelightBuff].up or not buff[classtable.BonedustBrewBuff] and cooldown[classtable.XuentheWhiteTiger].duration and not ( UnitExists('pet') and UnitName('pet')  == 'xuen' ) or cooldown[classtable.Serenity].duration >15 or ttd <30 and ttd >10 or ttd <10) and cooldown[classtable.BonedustBrew].ready then
        return classtable.BonedustBrew
    end
    if (MaxDps:FindSpell(classtable.Serenity) and CheckSpellCosts(classtable.Serenity, 'Serenity') and talents[classtable.Serenity]) and (sync_serenity and ( buff[classtable.InvokersDelightBuff].up or hold_xuen and ( talents[classtable.DrinkingHornCover] and ttd >110 or not talents[classtable.DrinkingHornCover] and ttd >105 ) ) or not talents[classtable.InvokeXuentheWhiteTiger] or ttd <15) and cooldown[classtable.Serenity].ready then
        return classtable.Serenity
    end
    if (MaxDps:FindSpell(classtable.Serenity) and CheckSpellCosts(classtable.Serenity, 'Serenity') and talents[classtable.Serenity]) and (not sync_serenity and ( buff[classtable.InvokersDelightBuff].up or cooldown[classtable.InvokeXuentheWhiteTiger].duration >ttd or ttd >( cooldown[classtable.InvokeXuentheWhiteTiger].duration + 10 ) and ttd >90 )) and cooldown[classtable.Serenity].ready then
        return classtable.Serenity
    end
    if (MaxDps:FindSpell(classtable.TouchofDeath) and CheckSpellCosts(classtable.TouchofDeath, 'TouchofDeath')) and ((select(2,IsInInstance()) == 'party') and not buff[classtable.SerenityBuff] and ( IsComboStrike(classtable.TouchofDeath) and targetHP <maxHP ) or ( buff[classtable.HiddenMastersForbiddenTouchBuff].remains <2 ) or ( buff[classtable.HiddenMastersForbiddenTouchBuff].remains >ttd )) and cooldown[classtable.TouchofDeath].ready then
        return classtable.TouchofDeath
    end
    if (MaxDps:FindSpell(classtable.TouchofDeath) and CheckSpellCosts(classtable.TouchofDeath, 'TouchofDeath')) and ((select(2,IsInInstance()) == 'party') and IsComboStrike(classtable.TouchofDeath) and ( ttd >60 or debuff[classtable.BonedustBrewDebuffDeBuff].up or ttd <10 ) and not buff[classtable.SerenityBuff]) and cooldown[classtable.TouchofDeath].ready then
        return classtable.TouchofDeath
    end
    if (MaxDps:FindSpell(classtable.TouchofDeath) and CheckSpellCosts(classtable.TouchofDeath, 'TouchofDeath')) and (not (select(2,IsInInstance()) == 'party') and IsComboStrike(classtable.TouchofDeath) and not buff[classtable.SerenityBuff]) and cooldown[classtable.TouchofDeath].ready then
        return classtable.TouchofDeath
    end
    if (MaxDps:FindSpell(classtable.TouchofKarma) and CheckSpellCosts(classtable.TouchofKarma, 'TouchofKarma')) and (ttd >90 or ttd <10) and cooldown[classtable.TouchofKarma].ready then
        return classtable.TouchofKarma
    end
end
local function serenity_aoelust()
    if (MaxDps:FindSpell(classtable.FaelineStomp) and CheckSpellCosts(classtable.FaelineStomp, 'FaelineStomp') and talents[classtable.FaelineStomp]) and (debuff[classtable.FaeExposureDamageDeBuff].remains <1) and cooldown[classtable.FaelineStomp].ready then
        return classtable.FaelineStomp
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (MaxDps.tier and MaxDps.tier[31].count >= 4 and talents[classtable.Thunderfist]) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and MaxDps.tier and MaxDps.tier[31].count >= 2) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.FistsofFury) and CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and (talents[classtable.JadeIgnition]) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.BlackoutReinforcementBuff] and MaxDps.tier and MaxDps.tier[31].count >= 2 and buff[classtable.BonedustBrewBuff].up and targets >4) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and MaxDps.tier and MaxDps.tier[31].count >= 2 and IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.BlackoutReinforcementBuff]) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.FistsofFury) and CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and (buff[classtable.InvokersDelightBuff].up and MaxDps.tier and MaxDps.tier[31].count >= 2 and ( targets >5 and buff[classtable.TransferthePowerBuff].count >5 or targets >6 or targets >4 and not talents[classtable.CraneVortex] and buff[classtable.TransferthePowerBuff].count >5 )) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (MaxDps:FindSpell(classtable.FistsofFury) and CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and (not MaxDps.tier and MaxDps.tier[30].count >= 2 and not buff[classtable.InvokersDelightBuff] and MaxDps.tier and MaxDps.tier[31].count >= 2 and ( not buff[classtable.BonedustBrewBuff] or targets >10 ) and ( buff[classtable.TransferthePowerBuff].count == 10 and not talents[classtable.CraneVortex] or targets >5 and talents[classtable.CraneVortex] and buff[classtable.TransferthePowerBuff].count == 10 or targets >14 or targets >12 and not talents[classtable.CraneVortex] )) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and not (targets==5) and talents[classtable.ShadowboxingTreads]) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and buff[classtable.TeachingsoftheMonasteryBuff].count == 3 and buff[classtable.TeachingsoftheMonasteryBuff].remains <1) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and not buff[classtable.BlackoutReinforcementBuff]) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and MaxDps.tier and MaxDps.tier[31].count >= 2 and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.BlackoutReinforcementBuff].up and CheckPrevSpell(classtable.BlackoutKick) and buff[classtable.DanceofChijiBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (MaxDps.tier and MaxDps.tier[31].count >= 2 and IsComboStrike(classtable.BlackoutKick) and buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and MaxDps.tier and MaxDps.tier[31].count >= 2 and IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.BlackoutReinforcementBuff]) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (targets <6 and IsComboStrike(classtable.BlackoutKick) and MaxDps.tier and MaxDps.tier[31].count >= 2) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.PressurePointBuff].up and MaxDps.tier and MaxDps.tier[30].count >= 2) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (MaxDps.tier and MaxDps.tier[30].count >= 2) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (talents[classtable.Thunderfist] and buff[classtable.CallToDominanceBuff].up and debuff[classtable.SkyreachExhaustionDeBuff].remains >buff[classtable.CallToDominanceBuff].remains and targets <10) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.FaelineStomp) and CheckSpellCosts(classtable.FaelineStomp, 'FaelineStomp') and talents[classtable.FaelineStomp]) and (debuff[classtable.FaeExposureDamageDeBuff].remains <2) and cooldown[classtable.FaelineStomp].ready then
        return classtable.FaelineStomp
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (talents[classtable.Thunderfist]) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.FistsofFury) and CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and (buff[classtable.InvokersDelightBuff].up) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (MaxDps:FindSpell(classtable.FistsofFuryCancel) and CheckSpellCosts(classtable.FistsofFuryCancel, 'FistsofFuryCancel')) and cooldown[classtable.FistsofFuryCancel].ready then
        return classtable.FistsofFuryCancel
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (targets <6 and IsComboStrike(classtable.BlackoutKick) and MaxDps.tier and MaxDps.tier[30].count >= 2) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and (targets==5)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (not debuff[classtable.SkyreachExhaustionDeBuff].up and IsComboStrike(classtable.TigerPalm) and targets == 5) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (MaxDps:FindSpell(classtable.RushingJadeWind) and CheckSpellCosts(classtable.RushingJadeWind, 'RushingJadeWind')) and (not buff[classtable.RushingJadeWindBuff]) and cooldown[classtable.RushingJadeWind].ready then
        return classtable.RushingJadeWind
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (talents[classtable.ShadowboxingTreads] and targets >= 3 and IsComboStrike(classtable.ShadowboxingTreads)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.WhirlingDragonPunch) and CheckSpellCosts(classtable.WhirlingDragonPunch, 'WhirlingDragonPunch') and talents[classtable.WhirlingDragonPunch]) and cooldown[classtable.WhirlingDragonPunch].ready then
        return classtable.WhirlingDragonPunch
    end
    if (MaxDps:FindSpell(classtable.RushingJadeWind) and CheckSpellCosts(classtable.RushingJadeWind, 'RushingJadeWind')) and (not buff[classtable.RushingJadeWindBuff]) and cooldown[classtable.RushingJadeWind].ready then
        return classtable.RushingJadeWind
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (talents[classtable.TeachingsoftheMonastery] and buff[classtable.TeachingsoftheMonasteryBuff].count <3) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
end
local function serenity_lust()
    if (MaxDps:FindSpell(classtable.FaelineStomp) and CheckSpellCosts(classtable.FaelineStomp, 'FaelineStomp') and talents[classtable.FaelineStomp]) and (debuff[classtable.FaeExposureDamageDeBuff].remains <1) and cooldown[classtable.FaelineStomp].ready then
        return classtable.FaelineStomp
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and buff[classtable.SerenityBuff].remains <1.5 and IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.BlackoutReinforcementBuff] and MaxDps.tier and MaxDps.tier[31].count >= 2) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and buff[classtable.TeachingsoftheMonasteryBuff].count == 3 and buff[classtable.TeachingsoftheMonasteryBuff].remains <1) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and not buff[classtable.BlackoutReinforcementBuff] and MaxDps.tier and MaxDps.tier[31].count >= 2 and targets >2) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (talents[classtable.Thunderfist]) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and buff[classtable.BlackoutReinforcementBuff].up and targets >2) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (IsComboStrike(classtable.RisingSunKick) and ( targets <3 or not MaxDps.tier and MaxDps.tier[31].count >= 2 )) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and buff[classtable.BlackoutReinforcementBuff].up and CheckPrevSpell(classtable.FistsofFury) and talents[classtable.ShadowboxingTreads] and MaxDps.tier and MaxDps.tier[31].count >= 2 and not talents[classtable.DanceofChiji]) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and not buff[classtable.BlackoutReinforcementBuff] and CheckPrevSpell(classtable.FistsofFury) and debuff[classtable.SkyreachExhaustionDeBuff].remains >55 and MaxDps.tier and MaxDps.tier[31].count >= 2) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.FistsofFury) and CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and (buff[classtable.InvokersDelightBuff].up and ( targets <3 or not MaxDps.tier and MaxDps.tier[31].count >= 2 )) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and (targets==5) and not buff[classtable.BlackoutReinforcementBuff] and targets >2 and MaxDps.tier and MaxDps.tier[31].count >= 2) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and (targets==5) and buff[classtable.BlackoutReinforcementBuff].up and targets >2 and CheckPrevSpell(classtable.BlackoutKick) and MaxDps.tier and MaxDps.tier[31].count >= 2) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and (targets==5) and buff[classtable.BonedustBrewBuff].up and targets >2 and MaxDps.tier and MaxDps.tier[31].count >= 2) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.FistsofFuryCancel) and CheckSpellCosts(classtable.FistsofFuryCancel, 'FistsofFuryCancel')) and (targets <3 or not MaxDps.tier and MaxDps.tier[31].count >= 2) and cooldown[classtable.FistsofFuryCancel].ready then
        return classtable.FistsofFuryCancel
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and not buff[classtable.BlackoutReinforcementBuff]) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.BlackoutReinforcementBuff] and buff[classtable.BonedustBrewBuff].up and MaxDps.tier and MaxDps.tier[31].count >= 2) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.WhirlingDragonPunch) and CheckSpellCosts(classtable.WhirlingDragonPunch, 'WhirlingDragonPunch') and talents[classtable.WhirlingDragonPunch]) and cooldown[classtable.WhirlingDragonPunch].ready then
        return classtable.WhirlingDragonPunch
    end
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (talents[classtable.TeachingsoftheMonastery] and buff[classtable.TeachingsoftheMonasteryBuff].count <3) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
end
local function serenity_aoe()
    if (MaxDps:FindSpell(classtable.FaelineStomp) and CheckSpellCosts(classtable.FaelineStomp, 'FaelineStomp') and talents[classtable.FaelineStomp]) and (debuff[classtable.FaeExposureDamageDeBuff].remains <1) and cooldown[classtable.FaelineStomp].ready then
        return classtable.FaelineStomp
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (MaxDps.tier and MaxDps.tier[31].count >= 4 and talents[classtable.Thunderfist]) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and MaxDps.tier and MaxDps.tier[31].count >= 2) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.BlackoutReinforcementBuff] and MaxDps.tier and MaxDps.tier[31].count >= 2 and buff[classtable.BonedustBrewBuff].up and targets >4) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.FistsofFury) and CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and (talents[classtable.JadeIgnition]) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and MaxDps.tier and MaxDps.tier[31].count >= 2 and IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.BlackoutReinforcementBuff]) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.FistsofFury) and CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and (buff[classtable.InvokersDelightBuff].up and MaxDps.tier and MaxDps.tier[31].count >= 2 and ( not buff[classtable.BonedustBrewBuff] or targets >10 ) and ( buff[classtable.TransferthePowerBuff].count == 10 and not talents[classtable.CraneVortex] or targets >5 and talents[classtable.CraneVortex] and buff[classtable.TransferthePowerBuff].count == 10 or targets >14 or targets >12 and not talents[classtable.CraneVortex] )) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (MaxDps:FindSpell(classtable.FistsofFuryCancel) and CheckSpellCosts(classtable.FistsofFuryCancel, 'FistsofFuryCancel')) and (not MaxDps.tier and MaxDps.tier[30].count >= 2 and MaxDps.tier and MaxDps.tier[31].count >= 2 and ( not buff[classtable.BonedustBrewBuff] or targets >10 ) and ( buff[classtable.TransferthePowerBuff].count == 10 and not talents[classtable.CraneVortex] or targets >5 and talents[classtable.CraneVortex] and buff[classtable.TransferthePowerBuff].count == 10 or targets >14 or targets >12 and not talents[classtable.CraneVortex] ) and not buff[classtable.BonedustBrewBuff] or buff[classtable.FuryofXuenStacksBuff].count >90) and cooldown[classtable.FistsofFuryCancel].ready then
        return classtable.FistsofFuryCancel
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and not (targets==5) and talents[classtable.ShadowboxingTreads]) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and buff[classtable.TeachingsoftheMonasteryBuff].count == 3 and buff[classtable.TeachingsoftheMonasteryBuff].remains <1) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and not buff[classtable.BlackoutReinforcementBuff]) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and MaxDps.tier and MaxDps.tier[31].count >= 2 and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.BlackoutReinforcementBuff].up and CheckPrevSpell(classtable.BlackoutKick) and buff[classtable.DanceofChijiBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (MaxDps.tier and MaxDps.tier[31].count >= 2 and IsComboStrike(classtable.BlackoutKick) and buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and MaxDps.tier and MaxDps.tier[31].count >= 2 and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.BlackoutReinforcementBuff].up and CheckPrevSpell(classtable.BlackoutKick)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.PressurePointBuff].up and MaxDps.tier and MaxDps.tier[30].count >= 2) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (MaxDps.tier and MaxDps.tier[30].count >= 2) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (talents[classtable.Thunderfist] and buff[classtable.CallToDominanceBuff].up and debuff[classtable.SkyreachExhaustionDeBuff].remains >buff[classtable.CallToDominanceBuff].remains and targets <10) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.FaelineStomp) and CheckSpellCosts(classtable.FaelineStomp, 'FaelineStomp') and talents[classtable.FaelineStomp]) and (debuff[classtable.FaeExposureDamageDeBuff].remains <2) and cooldown[classtable.FaelineStomp].ready then
        return classtable.FaelineStomp
    end
    if (MaxDps:FindSpell(classtable.FistsofFury) and CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and (buff[classtable.InvokersDelightBuff].up) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (MaxDps:FindSpell(classtable.FistsofFuryCancel) and CheckSpellCosts(classtable.FistsofFuryCancel, 'FistsofFuryCancel')) and cooldown[classtable.FistsofFuryCancel].ready then
        return classtable.FistsofFuryCancel
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (talents[classtable.Thunderfist]) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (targets <6 and IsComboStrike(classtable.BlackoutKick) and MaxDps.tier and MaxDps.tier[30].count >= 2) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and (targets==5)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (not debuff[classtable.SkyreachExhaustionDeBuff].up and IsComboStrike(classtable.TigerPalm) and targets == 5) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (MaxDps:FindSpell(classtable.RushingJadeWind) and CheckSpellCosts(classtable.RushingJadeWind, 'RushingJadeWind')) and (not buff[classtable.RushingJadeWindBuff]) and cooldown[classtable.RushingJadeWind].ready then
        return classtable.RushingJadeWind
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (talents[classtable.ShadowboxingTreads] and targets >= 3 and IsComboStrike(classtable.ShadowboxingTreads)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.WhirlingDragonPunch) and CheckSpellCosts(classtable.WhirlingDragonPunch, 'WhirlingDragonPunch') and talents[classtable.WhirlingDragonPunch]) and cooldown[classtable.WhirlingDragonPunch].ready then
        return classtable.WhirlingDragonPunch
    end
    if (MaxDps:FindSpell(classtable.RushingJadeWind) and CheckSpellCosts(classtable.RushingJadeWind, 'RushingJadeWind')) and (not buff[classtable.RushingJadeWindBuff]) and cooldown[classtable.RushingJadeWind].ready then
        return classtable.RushingJadeWind
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (talents[classtable.TeachingsoftheMonastery] and buff[classtable.TeachingsoftheMonasteryBuff].count <3) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (MaxDps:FindSpell(classtable.FaelineStomp) and CheckSpellCosts(classtable.FaelineStomp, 'FaelineStomp') and talents[classtable.FaelineStomp]) and (debuff[classtable.FaeExposureDamageDeBuff].remains <1) and cooldown[classtable.FaelineStomp].ready then
        return classtable.FaelineStomp
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (MaxDps.tier and MaxDps.tier[31].count >= 4 and talents[classtable.Thunderfist]) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and MaxDps.tier and MaxDps.tier[31].count >= 2) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.FistsofFury) and CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and (talents[classtable.JadeIgnition]) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.BlackoutReinforcementBuff] and MaxDps.tier and MaxDps.tier[31].count >= 2 and buff[classtable.BonedustBrewBuff].up and targets >4) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and MaxDps.tier and MaxDps.tier[31].count >= 2 and IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.BlackoutReinforcementBuff]) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.FistsofFury) and CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and (buff[classtable.InvokersDelightBuff].up and MaxDps.tier and MaxDps.tier[31].count >= 2 and ( targets >5 and buff[classtable.TransferthePowerBuff].count >5 or targets >6 or targets >4 and not talents[classtable.CraneVortex] and buff[classtable.TransferthePowerBuff].count >5 )) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (MaxDps:FindSpell(classtable.FistsofFury) and CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and (not MaxDps.tier and MaxDps.tier[30].count >= 2 and not buff[classtable.InvokersDelightBuff] and MaxDps.tier and MaxDps.tier[31].count >= 2 and ( not buff[classtable.BonedustBrewBuff] or targets >10 ) and ( buff[classtable.TransferthePowerBuff].count == 10 and not talents[classtable.CraneVortex] or targets >5 and talents[classtable.CraneVortex] and buff[classtable.TransferthePowerBuff].count == 10 or targets >14 or targets >12 and not talents[classtable.CraneVortex] )) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and not (targets==5) and talents[classtable.ShadowboxingTreads]) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and buff[classtable.TeachingsoftheMonasteryBuff].count == 3 and buff[classtable.TeachingsoftheMonasteryBuff].remains <1) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and not buff[classtable.BlackoutReinforcementBuff]) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and MaxDps.tier and MaxDps.tier[31].count >= 2 and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.BlackoutReinforcementBuff].up and CheckPrevSpell(classtable.BlackoutKick) and buff[classtable.DanceofChijiBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (MaxDps.tier and MaxDps.tier[31].count >= 2 and IsComboStrike(classtable.BlackoutKick) and buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and MaxDps.tier and MaxDps.tier[31].count >= 2 and IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.BlackoutReinforcementBuff]) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (targets <6 and IsComboStrike(classtable.BlackoutKick) and MaxDps.tier and MaxDps.tier[31].count >= 2) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.PressurePointBuff].up and MaxDps.tier and MaxDps.tier[30].count >= 2) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (MaxDps.tier and MaxDps.tier[30].count >= 2) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (talents[classtable.Thunderfist] and buff[classtable.CallToDominanceBuff].up and debuff[classtable.SkyreachExhaustionDeBuff].remains >buff[classtable.CallToDominanceBuff].remains and targets <10) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.FaelineStomp) and CheckSpellCosts(classtable.FaelineStomp, 'FaelineStomp') and talents[classtable.FaelineStomp]) and (debuff[classtable.FaeExposureDamageDeBuff].remains <2) and cooldown[classtable.FaelineStomp].ready then
        return classtable.FaelineStomp
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (talents[classtable.Thunderfist]) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.FistsofFury) and CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and (buff[classtable.InvokersDelightBuff].up) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (MaxDps:FindSpell(classtable.FistsofFuryCancel) and CheckSpellCosts(classtable.FistsofFuryCancel, 'FistsofFuryCancel')) and cooldown[classtable.FistsofFuryCancel].ready then
        return classtable.FistsofFuryCancel
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (targets <6 and IsComboStrike(classtable.BlackoutKick) and MaxDps.tier and MaxDps.tier[30].count >= 2) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and (targets==5)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (not debuff[classtable.SkyreachExhaustionDeBuff].up and IsComboStrike(classtable.TigerPalm) and targets == 5) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (MaxDps:FindSpell(classtable.RushingJadeWind) and CheckSpellCosts(classtable.RushingJadeWind, 'RushingJadeWind')) and (not buff[classtable.RushingJadeWindBuff]) and cooldown[classtable.RushingJadeWind].ready then
        return classtable.RushingJadeWind
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (talents[classtable.ShadowboxingTreads] and targets >= 3 and IsComboStrike(classtable.ShadowboxingTreads)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.WhirlingDragonPunch) and CheckSpellCosts(classtable.WhirlingDragonPunch, 'WhirlingDragonPunch') and talents[classtable.WhirlingDragonPunch]) and cooldown[classtable.WhirlingDragonPunch].ready then
        return classtable.WhirlingDragonPunch
    end
    if (MaxDps:FindSpell(classtable.RushingJadeWind) and CheckSpellCosts(classtable.RushingJadeWind, 'RushingJadeWind')) and (not buff[classtable.RushingJadeWindBuff]) and cooldown[classtable.RushingJadeWind].ready then
        return classtable.RushingJadeWind
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (talents[classtable.TeachingsoftheMonastery] and buff[classtable.TeachingsoftheMonasteryBuff].count <3) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
end
local function serenity_4t()
    if (MaxDps:FindSpell(classtable.FaelineStomp) and CheckSpellCosts(classtable.FaelineStomp, 'FaelineStomp') and talents[classtable.FaelineStomp]) and (debuff[classtable.FaeExposureDamageDeBuff].remains <1) and cooldown[classtable.FaelineStomp].ready then
        return classtable.FaelineStomp
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and buff[classtable.SerenityBuff].remains <1.5 and IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.BlackoutReinforcementBuff] and MaxDps.tier and MaxDps.tier[31].count >= 2) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (MaxDps.tier and MaxDps.tier[31].count >= 4 and talents[classtable.Thunderfist]) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and not buff[classtable.BlackoutReinforcementBuff] and MaxDps.tier and MaxDps.tier[31].count >= 2) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.FistsofFuryCancel) and CheckSpellCosts(classtable.FistsofFuryCancel, 'FistsofFuryCancel')) and (not MaxDps.tier and MaxDps.tier[30].count >= 2 and buff[classtable.FuryofXuenStacksBuff].count >90) and cooldown[classtable.FistsofFuryCancel].ready then
        return classtable.FistsofFuryCancel
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and MaxDps.tier and MaxDps.tier[31].count >= 2 and not buff[classtable.BlackoutReinforcementBuff]) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and buff[classtable.TeachingsoftheMonasteryBuff].count == 3 and buff[classtable.TeachingsoftheMonasteryBuff].remains <1) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (MaxDps.tier and MaxDps.tier[31].count >= 2 and IsComboStrike(classtable.BlackoutKick) and buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and MaxDps.tier and MaxDps.tier[31].count >= 2 and IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.BlackoutReinforcementBuff] and talents[classtable.CraneVortex]) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.PressurePointBuff].up and not talents[classtable.BonedustBrew]) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.FistsofFury) and CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and (buff[classtable.InvokersDelightBuff].up and MaxDps.tier and MaxDps.tier[31].count >= 2 and buff[classtable.TransferthePowerBuff].count >5 and not talents[classtable.CraneVortex] and MaxDps:Bloodlust()) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.PressurePointBuff].up and MaxDps.tier and MaxDps.tier[30].count >= 2) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (MaxDps.tier and MaxDps.tier[30].count >= 2) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and MaxDps.tier and MaxDps.tier[31].count >= 2 and IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.BlackoutReinforcementBuff]) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (talents[classtable.Thunderfist] and buff[classtable.CallToDominanceBuff].up and debuff[classtable.SkyreachExhaustionDeBuff].remains >buff[classtable.CallToDominanceBuff].remains) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.FaelineStomp) and CheckSpellCosts(classtable.FaelineStomp, 'FaelineStomp') and talents[classtable.FaelineStomp]) and (debuff[classtable.FaeExposureDamageDeBuff].remains <2) and cooldown[classtable.FaelineStomp].ready then
        return classtable.FaelineStomp
    end
    if (MaxDps:FindSpell(classtable.FistsofFury) and CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and (buff[classtable.InvokersDelightBuff].up) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (MaxDps:FindSpell(classtable.FistsofFuryCancel) and CheckSpellCosts(classtable.FistsofFuryCancel, 'FistsofFuryCancel')) and cooldown[classtable.FistsofFuryCancel].ready then
        return classtable.FistsofFuryCancel
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (talents[classtable.Thunderfist]) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and not buff[classtable.BlackoutReinforcementBuff]) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.PressurePointBuff].up) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and MaxDps.tier and MaxDps.tier[30].count >= 2) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and (targets==5)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (talents[classtable.ShadowboxingTreads] and IsComboStrike(classtable.ShadowboxingTreads)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.BlackoutReinforcementBuff]) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.WhirlingDragonPunch) and CheckSpellCosts(classtable.WhirlingDragonPunch, 'WhirlingDragonPunch') and talents[classtable.WhirlingDragonPunch]) and cooldown[classtable.WhirlingDragonPunch].ready then
        return classtable.WhirlingDragonPunch
    end
    if (MaxDps:FindSpell(classtable.RushingJadeWind) and CheckSpellCosts(classtable.RushingJadeWind, 'RushingJadeWind')) and (not buff[classtable.RushingJadeWindBuff]) and cooldown[classtable.RushingJadeWind].ready then
        return classtable.RushingJadeWind
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (talents[classtable.TeachingsoftheMonastery] and buff[classtable.TeachingsoftheMonasteryBuff].count <3) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
end
local function serenity_3t()
    if (MaxDps:FindSpell(classtable.FaelineStomp) and CheckSpellCosts(classtable.FaelineStomp, 'FaelineStomp') and talents[classtable.FaelineStomp]) and (debuff[classtable.FaeExposureDamageDeBuff].remains <1) and cooldown[classtable.FaelineStomp].ready then
        return classtable.FaelineStomp
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (MaxDps.tier and MaxDps.tier[31].count >= 2 and IsComboStrike(classtable.BlackoutKick) and buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (not debuff[classtable.SkyreachExhaustionDeBuff].up and IsComboStrike(classtable.TigerPalm)) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and (targets==5) and not buff[classtable.BlackoutReinforcementBuff] and MaxDps.tier and MaxDps.tier[31].count >= 2) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (talents[classtable.Thunderfist] and buff[classtable.CallToDominanceBuff].up and debuff[classtable.SkyreachExhaustionDeBuff].remains >buff[classtable.CallToDominanceBuff].remains) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (talents[classtable.Thunderfist] and debuff[classtable.SkyreachExhaustionDeBuff].remains >55) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.FistsofFury) and CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and (buff[classtable.InvokersDelightBuff].up and not MaxDps.tier and MaxDps.tier[31].count >= 2) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (MaxDps:FindSpell(classtable.FistsofFuryCancel) and CheckSpellCosts(classtable.FistsofFuryCancel, 'FistsofFuryCancel')) and (not MaxDps.tier and MaxDps.tier[31].count >= 2 or buff[classtable.FuryofXuenStacksBuff].count >90) and cooldown[classtable.FistsofFuryCancel].ready then
        return classtable.FistsofFuryCancel
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and (targets==5) and not buff[classtable.BlackoutReinforcementBuff] and MaxDps.tier and MaxDps.tier[31].count >= 2) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and (targets==5) and buff[classtable.BlackoutReinforcementBuff].up and MaxDps.tier and MaxDps.tier[31].count >= 2 and CheckPrevSpell(classtable.BlackoutKick) and talents[classtable.CraneVortex]) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and not buff[classtable.PressurePointBuff]) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.PressurePointBuff].up) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.PressurePointBuff].up and MaxDps.tier and MaxDps.tier[30].count >= 2) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (MaxDps.tier and MaxDps.tier[30].count >= 2) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.FaelineStomp) and CheckSpellCosts(classtable.FaelineStomp, 'FaelineStomp') and talents[classtable.FaelineStomp]) and (debuff[classtable.FaeExposureDamageDeBuff].remains <2) and cooldown[classtable.FaelineStomp].ready then
        return classtable.FaelineStomp
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (talents[classtable.Thunderfist]) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and (targets==5) and not buff[classtable.BlackoutReinforcementBuff]) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and MaxDps.tier and MaxDps.tier[30].count >= 2) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.BlackoutReinforcementBuff]) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and buff[classtable.TeachingsoftheMonasteryBuff].count == 2) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (talents[classtable.ShadowboxingTreads] and IsComboStrike(classtable.ShadowboxingTreads)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.WhirlingDragonPunch) and CheckSpellCosts(classtable.WhirlingDragonPunch, 'WhirlingDragonPunch') and talents[classtable.WhirlingDragonPunch]) and cooldown[classtable.WhirlingDragonPunch].ready then
        return classtable.WhirlingDragonPunch
    end
    if (MaxDps:FindSpell(classtable.RushingJadeWind) and CheckSpellCosts(classtable.RushingJadeWind, 'RushingJadeWind')) and (not buff[classtable.RushingJadeWindBuff]) and cooldown[classtable.RushingJadeWind].ready then
        return classtable.RushingJadeWind
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (talents[classtable.TeachingsoftheMonastery] and buff[classtable.TeachingsoftheMonasteryBuff].count <3) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
end
local function serenity_2t()
    if (MaxDps:FindSpell(classtable.FaelineStomp) and CheckSpellCosts(classtable.FaelineStomp, 'FaelineStomp') and talents[classtable.FaelineStomp]) and (debuff[classtable.FaeExposureDamageDeBuff].remains <2 and not (debuff[classtable.SkyreachExhaustionDeBuff].duration <2) and not debuff[classtable.SkyreachExhaustionDeBuff].up) and cooldown[classtable.FaelineStomp].ready then
        return classtable.FaelineStomp
    end
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (not debuff[classtable.SkyreachExhaustionDeBuff].up and IsComboStrike(classtable.TigerPalm)) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and buff[classtable.TeachingsoftheMonasteryBuff].count == 3 and buff[classtable.TeachingsoftheMonasteryBuff].remains <1) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and not buff[classtable.BlackoutReinforcementBuff] and CheckPrevSpell(classtable.FistsofFury) and MaxDps.tier and MaxDps.tier[31].count >= 2) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.PressurePointBuff].up or debuff[classtable.SkyreachExhaustionDeBuff].remains >55) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.PressurePointBuff].up and MaxDps.tier and MaxDps.tier[30].count >= 2) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (MaxDps.tier and MaxDps.tier[30].count >= 2) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (talents[classtable.Thunderfist] and buff[classtable.CallToDominanceBuff].up and debuff[classtable.SkyreachExhaustionDeBuff].remains >buff[classtable.CallToDominanceBuff].remains) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (talents[classtable.Thunderfist] and debuff[classtable.SkyreachExhaustionDeBuff].remains >55) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and not buff[classtable.BlackoutReinforcementBuff] and MaxDps.tier and MaxDps.tier[31].count >= 2) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.FistsofFury) and CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and (buff[classtable.InvokersDelightBuff].up) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (MaxDps:FindSpell(classtable.FistsofFuryCancel) and CheckSpellCosts(classtable.FistsofFuryCancel, 'FistsofFuryCancel')) and cooldown[classtable.FistsofFuryCancel].ready then
        return classtable.FistsofFuryCancel
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (talents[classtable.Thunderfist]) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and not buff[classtable.BlackoutReinforcementBuff] and MaxDps.tier and MaxDps.tier[31].count >= 2) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.BlackoutReinforcementBuff] and MaxDps.tier and MaxDps.tier[31].count >= 2) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and MaxDps.tier and MaxDps.tier[30].count >= 2) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and buff[classtable.TeachingsoftheMonasteryBuff].count == 2) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (cooldown[classtable.FistsofFury].duration >5 and talents[classtable.ShadowboxingTreads] and buff[classtable.TeachingsoftheMonasteryBuff].count == 1 and IsComboStrike(classtable.ShadowboxingTreads)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.WhirlingDragonPunch) and CheckSpellCosts(classtable.WhirlingDragonPunch, 'WhirlingDragonPunch') and talents[classtable.WhirlingDragonPunch]) and cooldown[classtable.WhirlingDragonPunch].ready then
        return classtable.WhirlingDragonPunch
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (talents[classtable.TeachingsoftheMonastery] and buff[classtable.TeachingsoftheMonasteryBuff].count <3) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
end
local function serenity_st()
    if (MaxDps:FindSpell(classtable.FaelineStomp) and CheckSpellCosts(classtable.FaelineStomp, 'FaelineStomp') and talents[classtable.FaelineStomp]) and (debuff[classtable.FaeExposureDamageDeBuff].remains <2 and not debuff[classtable.SkyreachExhaustionDeBuff].up) and cooldown[classtable.FaelineStomp].ready then
        return classtable.FaelineStomp
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and buff[classtable.SerenityBuff].remains <1.5 and IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.BlackoutReinforcementBuff] and MaxDps.tier and MaxDps.tier[31].count >= 4) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (not debuff[classtable.SkyreachExhaustionDeBuff].up and IsComboStrike(classtable.TigerPalm)) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and buff[classtable.TeachingsoftheMonasteryBuff].count == 3 and buff[classtable.TeachingsoftheMonasteryBuff].remains <1) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (talents[classtable.Thunderfist] and MaxDps.tier and MaxDps.tier[31].count >= 4) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (IsComboStrike(classtable.RisingSunKick)) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.FaelineStomp) and CheckSpellCosts(classtable.FaelineStomp, 'FaelineStomp') and talents[classtable.FaelineStomp]) and (debuff[classtable.FaeExposureDamageDeBuff].remains <2) and cooldown[classtable.FaelineStomp].ready then
        return classtable.FaelineStomp
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (talents[classtable.Thunderfist] and buff[classtable.CallToDominanceBuff].up and debuff[classtable.SkyreachExhaustionDeBuff].remains >buff[classtable.CallToDominanceBuff].remains) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (talents[classtable.Thunderfist] and debuff[classtable.SkyreachExhaustionDeBuff].remains >55) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and not buff[classtable.BlackoutReinforcementBuff] and CheckPrevSpell(classtable.RisingSunKick) and MaxDps.tier and MaxDps.tier[31].count >= 2) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and MaxDps.tier and MaxDps.tier[31].count >= 2 and buff[classtable.BlackoutReinforcementBuff].up and CheckPrevSpell(classtable.RisingSunKick)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and not buff[classtable.BlackoutReinforcementBuff] and CheckPrevSpell(classtable.FistsofFury) and MaxDps.tier and MaxDps.tier[31].count >= 2) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and buff[classtable.BlackoutReinforcementBuff].up and CheckPrevSpell(classtable.FistsofFury) and MaxDps.tier and MaxDps.tier[31].count >= 2) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.BlackoutReinforcementBuff] and MaxDps.tier and MaxDps.tier[31].count >= 2 and CheckPrevSpell(classtable.FistsofFury)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.FistsofFury) and CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and (buff[classtable.InvokersDelightBuff].up) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (MaxDps:FindSpell(classtable.FistsofFuryCancel) and CheckSpellCosts(classtable.FistsofFuryCancel, 'FistsofFuryCancel')) and cooldown[classtable.FistsofFuryCancel].ready then
        return classtable.FistsofFuryCancel
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.BlackoutReinforcementBuff] and MaxDps.tier and MaxDps.tier[31].count >= 2) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (debuff[classtable.SkyreachExhaustionDeBuff].remains >buff[classtable.CallToDominanceBuff].remains) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and MaxDps.tier and MaxDps.tier[30].count >= 2) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.WhirlingDragonPunch) and CheckSpellCosts(classtable.WhirlingDragonPunch, 'WhirlingDragonPunch') and talents[classtable.WhirlingDragonPunch]) and cooldown[classtable.WhirlingDragonPunch].ready then
        return classtable.WhirlingDragonPunch
    end
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (talents[classtable.TeachingsoftheMonastery] and buff[classtable.TeachingsoftheMonasteryBuff].count <3) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
end
local function default_aoe()
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and (targets==5) and not buff[classtable.BlackoutReinforcementBuff]) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and not talents[classtable.HitCombo] and (targets==5) and buff[classtable.BonedustBrewBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (talents[classtable.Thunderfist]) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.WhirlingDragonPunch) and CheckSpellCosts(classtable.WhirlingDragonPunch, 'WhirlingDragonPunch') and talents[classtable.WhirlingDragonPunch]) and (targets >8) and cooldown[classtable.WhirlingDragonPunch].ready then
        return classtable.WhirlingDragonPunch
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and buff[classtable.BonedustBrewBuff].up and IsComboStrike(classtable.SpinningCraneKick) and (targets==5)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.FistsofFury) and CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.BonedustBrewBuff].up and buff[classtable.PressurePointBuff].up and MaxDps.tier and MaxDps.tier[30].count >= 2) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.TeachingsoftheMonasteryBuff].count == 3 and talents[classtable.ShadowboxingTreads]) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (talents[classtable.ShadowboxingTreads] and IsComboStrike(classtable.ShadowboxingTreads) and buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.WhirlingDragonPunch) and CheckSpellCosts(classtable.WhirlingDragonPunch, 'WhirlingDragonPunch') and talents[classtable.WhirlingDragonPunch]) and (targets >= 5) and cooldown[classtable.WhirlingDragonPunch].ready then
        return classtable.WhirlingDragonPunch
    end
    if (MaxDps:FindSpell(classtable.RushingJadeWind) and CheckSpellCosts(classtable.RushingJadeWind, 'RushingJadeWind')) and (not buff[classtable.RushingJadeWindBuff]) and cooldown[classtable.RushingJadeWind].ready then
        return classtable.RushingJadeWind
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.PressurePointBuff].up and MaxDps.tier and MaxDps.tier[30].count >= 2) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (MaxDps.tier and MaxDps.tier[30].count >= 2) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (talents[classtable.WhirlingDragonPunch] and cooldown[classtable.WhirlingDragonPunch].duration <3 and cooldown[classtable.FistsofFury].duration >3 and not buff[classtable.KicksofFlowingMomentumBuff]) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.ExpelHarm) and CheckSpellCosts(classtable.ExpelHarm, 'ExpelHarm')) and (Chi == 1 and ( not cooldown[classtable.RisingSunKick].duration or not cooldown[classtable.StrikeoftheWindlord].duration ) or Chi == 2 and not cooldown[classtable.FistsofFury].duration) and cooldown[classtable.ExpelHarm].ready then
        return classtable.ExpelHarm
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and cooldown[classtable.FistsofFury].duration <5 and buff[classtable.ChiEnergyBuff].count >10) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.ChiBurst) and CheckSpellCosts(classtable.ChiBurst, 'ChiBurst') and talents[classtable.ChiBurst]) and (MaxDps:Bloodlust() and Chi <5) and cooldown[classtable.ChiBurst].ready then
        return classtable.ChiBurst
    end
    if (MaxDps:FindSpell(classtable.ChiBurst) and CheckSpellCosts(classtable.ChiBurst, 'ChiBurst') and talents[classtable.ChiBurst]) and (Chi <5 and Energy <50) and cooldown[classtable.ChiBurst].ready then
        return classtable.ChiBurst
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and ( cooldown[classtable.FistsofFury].duration >3 or Chi >2 ) and (targets==5) and MaxDps:Bloodlust() and not buff[classtable.BlackoutReinforcementBuff]) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and ( cooldown[classtable.FistsofFury].duration >3 or Chi >2 ) and (targets==5) and buff[classtable.InvokersDelightBuff].up and not buff[classtable.BlackoutReinforcementBuff]) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (talents[classtable.ShadowboxingTreads] and IsComboStrike(classtable.ShadowboxingTreads) and MaxDps.tier and MaxDps.tier[30].count >= 2 and not buff[classtable.BonedustBrewBuff] and targets <15 and not talents[classtable.CraneVortex]) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (talents[classtable.ShadowboxingTreads] and IsComboStrike(classtable.ShadowboxingTreads) and MaxDps.tier and MaxDps.tier[30].count >= 2 and not buff[classtable.BonedustBrewBuff] and targets <8) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and ( cooldown[classtable.FistsofFury].duration >3 or Chi >4 ) and (targets==5)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.TeachingsoftheMonasteryBuff].count == 3) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (talents[classtable.ShadowboxingTreads] and IsComboStrike(classtable.ShadowboxingTreads) and not (targets==5)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.ChiBurst) and CheckSpellCosts(classtable.ChiBurst, 'ChiBurst') and talents[classtable.ChiBurst]) and (ChiMax - Chi >= 2) and cooldown[classtable.ChiBurst].ready then
        return classtable.ChiBurst
    end
end
local function default_4t()
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and Chi <2 and ( cooldown[classtable.FistsofFury].duration <1 or cooldown[classtable.StrikeoftheWindlord].duration <1 ) and buff[classtable.TeachingsoftheMonasteryBuff].count <3) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and (targets==5) and not buff[classtable.BlackoutReinforcementBuff]) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (talents[classtable.Thunderfist]) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.FistsofFury) and CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.BonedustBrewBuff].up and buff[classtable.PressurePointBuff].up and MaxDps.tier and MaxDps.tier[30].count >= 2) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (talents[classtable.ShadowboxingTreads] and IsComboStrike(classtable.ShadowboxingTreads) and buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and buff[classtable.BonedustBrewBuff].up and IsComboStrike(classtable.SpinningCraneKick) and (targets==5)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.WhirlingDragonPunch) and CheckSpellCosts(classtable.WhirlingDragonPunch, 'WhirlingDragonPunch') and talents[classtable.WhirlingDragonPunch]) and cooldown[classtable.WhirlingDragonPunch].ready then
        return classtable.WhirlingDragonPunch
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (not buff[classtable.BonedustBrewBuff] and buff[classtable.PressurePointBuff].up and cooldown[classtable.FistsofFury].duration >5) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.RushingJadeWind) and CheckSpellCosts(classtable.RushingJadeWind, 'RushingJadeWind')) and (not buff[classtable.RushingJadeWindBuff]) and cooldown[classtable.RushingJadeWind].ready then
        return classtable.RushingJadeWind
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.TeachingsoftheMonasteryBuff].count == 3 and talents[classtable.ShadowboxingTreads]) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (MaxDps.tier and MaxDps.tier[30].count >= 2) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.ExpelHarm) and CheckSpellCosts(classtable.ExpelHarm, 'ExpelHarm')) and (Chi == 1 and ( not cooldown[classtable.RisingSunKick].duration or not cooldown[classtable.StrikeoftheWindlord].duration ) or Chi == 2 and not cooldown[classtable.FistsofFury].duration) and cooldown[classtable.ExpelHarm].ready then
        return classtable.ExpelHarm
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and cooldown[classtable.FistsofFury].duration >3 and buff[classtable.ChiEnergyBuff].count >10) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and MaxDps.tier and MaxDps.tier[30].count >= 2) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.ChiBurst) and CheckSpellCosts(classtable.ChiBurst, 'ChiBurst') and talents[classtable.ChiBurst]) and (MaxDps:Bloodlust() and Chi <5) and cooldown[classtable.ChiBurst].ready then
        return classtable.ChiBurst
    end
    if (MaxDps:FindSpell(classtable.ChiBurst) and CheckSpellCosts(classtable.ChiBurst, 'ChiBurst') and talents[classtable.ChiBurst]) and (Chi <5 and Energy <50) and cooldown[classtable.ChiBurst].ready then
        return classtable.ChiBurst
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and ( cooldown[classtable.FistsofFury].duration >3 or Chi >4 ) and (targets==5)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.TeachingsoftheMonasteryBuff].count == 3) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and ( cooldown[classtable.FistsofFury].duration >3 or Chi >4 )) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
end
local function default_3t()
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and Chi <2 and ( cooldown[classtable.RisingSunKick].duration <1 or cooldown[classtable.FistsofFury].duration <1 or cooldown[classtable.StrikeoftheWindlord].duration <1 ) and buff[classtable.TeachingsoftheMonasteryBuff].count <3) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and not buff[classtable.BlackoutReinforcementBuff]) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (talents[classtable.Thunderfist] and MaxDps.tier and MaxDps.tier[31].count >= 4) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (talents[classtable.Thunderfist] and ( cooldown[classtable.InvokeXuentheWhiteTiger].duration >20 or ttd <5 )) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.TeachingsoftheMonasteryBuff].count == 3 and talents[classtable.ShadowboxingTreads]) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (talents[classtable.ShadowboxingTreads] and IsComboStrike(classtable.ShadowboxingTreads) and buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.FistsofFury) and CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.BonedustBrewBuff].up and buff[classtable.PressurePointBuff].up and MaxDps.tier and MaxDps.tier[30].count >= 2) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and buff[classtable.BonedustBrewBuff].up and IsComboStrike(classtable.SpinningCraneKick)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (not buff[classtable.BonedustBrewBuff] and buff[classtable.PressurePointBuff].up) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (MaxDps.tier and MaxDps.tier[30].count >= 2) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.ExpelHarm) and CheckSpellCosts(classtable.ExpelHarm, 'ExpelHarm')) and (Chi == 1 and ( not cooldown[classtable.RisingSunKick].duration or not cooldown[classtable.StrikeoftheWindlord].duration ) or Chi == 2 and not cooldown[classtable.FistsofFury].duration) and cooldown[classtable.ExpelHarm].ready then
        return classtable.ExpelHarm
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.TeachingsoftheMonasteryBuff].count == 2) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.TeachingsoftheMonasteryBuff].up and ( talents[classtable.ShadowboxingTreads] or cooldown[classtable.RisingSunKick].duration >1 )) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.WhirlingDragonPunch) and CheckSpellCosts(classtable.WhirlingDragonPunch, 'WhirlingDragonPunch') and talents[classtable.WhirlingDragonPunch]) and cooldown[classtable.WhirlingDragonPunch].ready then
        return classtable.WhirlingDragonPunch
    end
    if (MaxDps:FindSpell(classtable.ChiBurst) and CheckSpellCosts(classtable.ChiBurst, 'ChiBurst') and talents[classtable.ChiBurst]) and (MaxDps:Bloodlust() and Chi <5) and cooldown[classtable.ChiBurst].ready then
        return classtable.ChiBurst
    end
    if (MaxDps:FindSpell(classtable.ChiBurst) and CheckSpellCosts(classtable.ChiBurst, 'ChiBurst') and talents[classtable.ChiBurst]) and (Chi <5 and Energy <50) and cooldown[classtable.ChiBurst].ready then
        return classtable.ChiBurst
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.TeachingsoftheMonasteryBuff].count == 3) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and cooldown[classtable.FistsofFury].duration <3 and buff[classtable.ChiEnergyBuff].count >15) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (cooldown[classtable.FistsofFury].duration >4 and Chi >3) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and cooldown[classtable.RisingSunKick].duration and cooldown[classtable.FistsofFury].duration and Chi >4 and ( ( talents[classtable.StormEarthandFire] and not talents[classtable.BonedustBrew] ) or ( talents[classtable.Serenity] ) )) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and cooldown[classtable.FistsofFury].duration) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.RushingJadeWind) and CheckSpellCosts(classtable.RushingJadeWind, 'RushingJadeWind')) and (not buff[classtable.RushingJadeWindBuff]) and cooldown[classtable.RushingJadeWind].ready then
        return classtable.RushingJadeWind
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and talents[classtable.ShadowboxingTreads] and not (targets==5)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and ( IsComboStrike(classtable.SpinningCraneKick) and Chi >5 and talents[classtable.StormEarthandFire] or IsComboStrike(classtable.StormEarthandFire) and Chi >4 and talents[classtable.Serenity] )) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
end
local function default_2t()
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and Chi <2 and ( cooldown[classtable.RisingSunKick].duration <1 or cooldown[classtable.FistsofFury].duration <1 or cooldown[classtable.StrikeoftheWindlord].duration <1 ) and buff[classtable.TeachingsoftheMonasteryBuff].count <3) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (MaxDps:FindSpell(classtable.ExpelHarm) and CheckSpellCosts(classtable.ExpelHarm, 'ExpelHarm')) and (Chi == 1 and ( not cooldown[classtable.RisingSunKick].duration or not cooldown[classtable.StrikeoftheWindlord].duration ) or Chi == 2 and not cooldown[classtable.FistsofFury].duration) and cooldown[classtable.ExpelHarm].ready then
        return classtable.ExpelHarm
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.TeachingsoftheMonasteryBuff].count == 3 and talents[classtable.ShadowboxingTreads]) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (talents[classtable.Thunderfist] and MaxDps.tier and MaxDps.tier[31].count >= 4) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (talents[classtable.Thunderfist] and ( cooldown[classtable.InvokeXuentheWhiteTiger].duration >20 or ttd <5 )) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and not buff[classtable.BlackoutReinforcementBuff] and MaxDps.tier and MaxDps.tier[31].count >= 2) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (talents[classtable.ShadowboxingTreads] and IsComboStrike(classtable.ShadowboxingTreads) and buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.FistsofFury) and CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and (not MaxDps.tier and MaxDps.tier[30].count >= 2) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (MaxDps:FindSpell(classtable.FistsofFury) and CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (not cooldown[classtable.FistsofFury].duration) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (MaxDps.tier and MaxDps.tier[30].count >= 2) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.KicksofFlowingMomentumBuff].up or buff[classtable.PressurePointBuff].up or debuff[classtable.SkyreachExhaustionDeBuff].remains >55) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and not buff[classtable.BlackoutReinforcementBuff]) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.ChiBurst) and CheckSpellCosts(classtable.ChiBurst, 'ChiBurst') and talents[classtable.ChiBurst]) and (MaxDps:Bloodlust() and Chi <5) and cooldown[classtable.ChiBurst].ready then
        return classtable.ChiBurst
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.TeachingsoftheMonasteryBuff].count == 2) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.PressurePointBuff].remains and Chi >2 and CheckPrevSpell(classtable.RisingSunKick)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.ChiBurst) and CheckSpellCosts(classtable.ChiBurst, 'ChiBurst') and talents[classtable.ChiBurst]) and (Chi <5 and Energy <50) and cooldown[classtable.ChiBurst].ready then
        return classtable.ChiBurst
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.TeachingsoftheMonasteryBuff].up and ( talents[classtable.ShadowboxingTreads] or cooldown[classtable.RisingSunKick].duration >1 )) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.WhirlingDragonPunch) and CheckSpellCosts(classtable.WhirlingDragonPunch, 'WhirlingDragonPunch') and talents[classtable.WhirlingDragonPunch]) and cooldown[classtable.WhirlingDragonPunch].ready then
        return classtable.WhirlingDragonPunch
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.TeachingsoftheMonasteryBuff].count == 3) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (not talents[classtable.ShadowboxingTreads] and cooldown[classtable.FistsofFury].duration >4 and talents[classtable.XuensBattlegear]) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and cooldown[classtable.RisingSunKick].duration and cooldown[classtable.FistsofFury].duration and ( not buff[classtable.BonedustBrewBuff] or (GetSpellCount(101546)) <1.5 )) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.RushingJadeWind) and CheckSpellCosts(classtable.RushingJadeWind, 'RushingJadeWind')) and (not buff[classtable.RushingJadeWindBuff]) and cooldown[classtable.RushingJadeWind].ready then
        return classtable.RushingJadeWind
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and buff[classtable.BonedustBrewBuff].up and IsComboStrike(classtable.SpinningCraneKick) and (GetSpellCount(101546)) >= 2.7) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.FaelineStomp) and CheckSpellCosts(classtable.FaelineStomp, 'FaelineStomp') and talents[classtable.FaelineStomp]) and (IsComboStrike(classtable.FaelineStomp)) and cooldown[classtable.FaelineStomp].ready then
        return classtable.FaelineStomp
    end
end
local function default_st()
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and Chi <2 and ( cooldown[classtable.RisingSunKick].duration <1 or cooldown[classtable.FistsofFury].duration <1 or cooldown[classtable.StrikeoftheWindlord].duration <1 ) and buff[classtable.TeachingsoftheMonasteryBuff].count <3) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (MaxDps:FindSpell(classtable.ExpelHarm) and CheckSpellCosts(classtable.ExpelHarm, 'ExpelHarm')) and (Chi == 1 and ( not cooldown[classtable.RisingSunKick].duration or not cooldown[classtable.StrikeoftheWindlord].duration ) or Chi == 2 and not cooldown[classtable.FistsofFury].duration and cooldown[classtable.RisingSunKick].duration) and cooldown[classtable.ExpelHarm].ready then
        return classtable.ExpelHarm
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (buff[classtable.DomineeringArroganceBuff].up and talents[classtable.Thunderfist] and talents[classtable.Serenity] and cooldown[classtable.InvokeXuentheWhiteTiger].duration >20 or ttd <5 or talents[classtable.Thunderfist] and debuff[classtable.SkyreachExhaustionDeBuff].remains >10 and not buff[classtable.DomineeringArroganceBuff] or talents[classtable.Thunderfist] and debuff[classtable.SkyreachExhaustionDeBuff].remains >35 and not talents[classtable.Serenity]) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and MaxDps.tier and MaxDps.tier[31].count >= 2 and not buff[classtable.BlackoutReinforcementBuff]) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (not cooldown[classtable.FistsofFury].duration) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.FistsofFury) and CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and (not buff[classtable.PressurePointBuff] and debuff[classtable.SkyreachExhaustionDeBuff].remains <55 and ( debuff[classtable.FaeExposureDamageDeBuff].remains >2 or cooldown[classtable.FaelineStomp].duration )) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (MaxDps:FindSpell(classtable.FaelineStomp) and CheckSpellCosts(classtable.FaelineStomp, 'FaelineStomp') and talents[classtable.FaelineStomp]) and (debuff[classtable.SkyreachExhaustionDeBuff].remains <1 and debuff[classtable.FaeExposureDamageDeBuff].remains <3) and cooldown[classtable.FaelineStomp].ready then
        return classtable.FaelineStomp
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.PressurePointBuff].up or debuff[classtable.SkyreachExhaustionDeBuff].remains >55) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.PressurePointBuff].remains and Chi >2 and CheckPrevSpell(classtable.RisingSunKick)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.TeachingsoftheMonasteryBuff].count == 3) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.BlackoutReinforcementBuff].up and cooldown[classtable.RisingSunKick].duration and IsComboStrike(classtable.BlackoutKick) and buff[classtable.DanceofChijiBuff].up) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.BlackoutReinforcementBuff].up and IsComboStrike(classtable.BlackoutKick)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.FistsofFury) and CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (MaxDps:FindSpell(classtable.WhirlingDragonPunch) and CheckSpellCosts(classtable.WhirlingDragonPunch, 'WhirlingDragonPunch') and talents[classtable.WhirlingDragonPunch]) and (not buff[classtable.PressurePointBuff]) and cooldown[classtable.WhirlingDragonPunch].ready then
        return classtable.WhirlingDragonPunch
    end
    if (MaxDps:FindSpell(classtable.ChiBurst) and CheckSpellCosts(classtable.ChiBurst, 'ChiBurst') and talents[classtable.ChiBurst]) and (MaxDps:Bloodlust() and Chi <5) and cooldown[classtable.ChiBurst].ready then
        return classtable.ChiBurst
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.TeachingsoftheMonasteryBuff].count == 2 and debuff[classtable.SkyreachExhaustionDeBuff].remains >1) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.ChiBurst) and CheckSpellCosts(classtable.ChiBurst, 'ChiBurst') and talents[classtable.ChiBurst]) and (Chi <5 and Energy <50) and cooldown[classtable.ChiBurst].ready then
        return classtable.ChiBurst
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (debuff[classtable.SkyreachExhaustionDeBuff].remains >30 or ttd <5) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and not MaxDps.tier and MaxDps.tier[31].count >= 2) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.TeachingsoftheMonasteryBuff].up and cooldown[classtable.RisingSunKick].duration >1) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and buff[classtable.BonedustBrewBuff].up and IsComboStrike(classtable.SpinningCraneKick) and (GetSpellCount(101546)) >= 2.7) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.WhirlingDragonPunch) and CheckSpellCosts(classtable.WhirlingDragonPunch, 'WhirlingDragonPunch') and talents[classtable.WhirlingDragonPunch]) and cooldown[classtable.WhirlingDragonPunch].ready then
        return classtable.WhirlingDragonPunch
    end
    if (MaxDps:FindSpell(classtable.RushingJadeWind) and CheckSpellCosts(classtable.RushingJadeWind, 'RushingJadeWind')) and (not buff[classtable.RushingJadeWindBuff]) and cooldown[classtable.RushingJadeWind].ready then
        return classtable.RushingJadeWind
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
end
local function fallthru()
    if (MaxDps:FindSpell(classtable.CracklingJadeLightning) and CheckSpellCosts(classtable.CracklingJadeLightning, 'CracklingJadeLightning')) and (buff[classtable.theEmperorsCapacitorBuff].count >19 and EnergyTimeToMax >MaxDps:GetTimeToPct(30) - 1 and cooldown[classtable.RisingSunKick].duration >MaxDps:GetTimeToPct(30) or buff[classtable.theEmperorsCapacitorBuff].count >14 and ( cooldown[classtable.Serenity].duration <5 and talents[classtable.Serenity] or ttd <5 )) and cooldown[classtable.CracklingJadeLightning].ready then
        return classtable.CracklingJadeLightning
    end
    if (MaxDps:FindSpell(classtable.FaelineStomp) and CheckSpellCosts(classtable.FaelineStomp, 'FaelineStomp') and talents[classtable.FaelineStomp]) and (IsComboStrike(classtable.FaelineStomp)) and cooldown[classtable.FaelineStomp].ready then
        return classtable.FaelineStomp
    end
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and ChiMax - Chi >= ( 2 + buff[classtable.PowerStrikesBuff].duration )) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (MaxDps:FindSpell(classtable.ExpelHarm) and CheckSpellCosts(classtable.ExpelHarm, 'ExpelHarm')) and (ChiMax - Chi >= 1 and targets >2) and cooldown[classtable.ExpelHarm].ready then
        return classtable.ExpelHarm
    end
    if (MaxDps:FindSpell(classtable.ChiBurst) and CheckSpellCosts(classtable.ChiBurst, 'ChiBurst') and talents[classtable.ChiBurst]) and (ChiMax - Chi >= 2 and targets >= 2) and cooldown[classtable.ChiBurst].ready then
        return classtable.ChiBurst
    end
    if (MaxDps:FindSpell(classtable.ChiWave) and CheckSpellCosts(classtable.ChiWave, 'ChiWave')) and cooldown[classtable.ChiWave].ready then
        return classtable.ChiWave
    end
    if (MaxDps:FindSpell(classtable.ExpelHarm) and CheckSpellCosts(classtable.ExpelHarm, 'ExpelHarm')) and (ChiMax - Chi >= 1) and cooldown[classtable.ExpelHarm].ready then
        return classtable.ExpelHarm
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and targets >= 5) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.ChiEnergyBuff].count >30 - 5 * targets and buff[classtable.StormEarthandFireBuff].down and ( cooldown[classtable.RisingSunKick].duration >2 and cooldown[classtable.FistsofFury].duration >2 or cooldown[classtable.RisingSunKick].duration <3 and cooldown[classtable.FistsofFury].duration >3 and Chi >3 or cooldown[classtable.RisingSunKick].duration >3 and cooldown[classtable.FistsofFury].duration <3 and Chi >4 or ChiMax - Chi <= 1 and EnergyTimeToMax <2 ) or buff[classtable.ChiEnergyBuff].count >10 and ttd <7) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.FlyingSerpentKick) and CheckSpellCosts(classtable.FlyingSerpentKick, 'FlyingSerpentKick')) and cooldown[classtable.FlyingSerpentKick].ready then
        return classtable.FlyingSerpentKick
    end
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
end
local function bdb_setup()
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (talents[classtable.Thunderfist] and targets >3) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.BonedustBrew) and CheckSpellCosts(classtable.BonedustBrew, 'BonedustBrew') and talents[classtable.BonedustBrew]) and ((targets==5) and Chi >= 4) and cooldown[classtable.BonedustBrew].ready then
        return classtable.BonedustBrew
    end
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and ChiMax - Chi >= 2 and buff[classtable.StormEarthandFireBuff].up) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and not talents[classtable.WhirlingDragonPunch] and not (targets==5)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (IsComboStrike(classtable.RisingSunKick) and Chi >= 5 and talents[classtable.WhirlingDragonPunch]) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (IsComboStrike(classtable.RisingSunKick) and targets >= 2 and talents[classtable.WhirlingDragonPunch]) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
end

function Monk:Windwalker()
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
    classtable.SkyreachExhaustionDeBuff = 393050
    classtable.FaeExposureDamageDeBuff = 395414
    classtable.BonedustBrewBuff = 386276
    classtable.StormEarthandFireBuff = 137639
    classtable.SerenityBuff = 152173
    classtable.HiddenMastersForbiddenTouchBuff = 213114
    classtable.BonedustBrewDebuffDeBuff = 386276
    classtable.InvokersDelightBuff = 388663
    classtable.DanceofChijiBuff = 325202
    classtable.BlackoutReinforcementBuff = 424454
    classtable.TransferthePowerBuff = 195321
    classtable.TeachingsoftheMonasteryBuff = 202090
    classtable.PressurePointBuff = 393053
    classtable.CallToDominanceBuff = 403380
    classtable.RushingJadeWindBuff = 116847
    classtable.FuryofXuenStacksBuff = 396168
    classtable.KicksofFlowingMomentumBuff = 394944
    classtable.ChiEnergyBuff = 393057
    classtable.DomineeringArroganceBuff = 411661
    classtable.theEmperorsCapacitorBuff = 393039
    classtable.PowerStrikesBuff = 129914
    PreCombatUpdate()
    local openerCheck = opener()
    if (timeInCombat <4 and Chi <5 and not ( UnitExists('pet') and UnitName('pet')  == 'xuen' ) and not talents[classtable.Serenity]) then
        if openerCheck then
            return opener()
        end
    end
    local trinketsCheck = trinkets()
    if trinketsCheck then
        return trinketsCheck
    end
    local cd_sefCheck = cd_sef()
    if (not talents[classtable.Serenity]) then
        if cd_sefCheck then
            return cd_sef()
        end
    end
    local cd_serenityCheck = cd_serenity()
    if (talents[classtable.Serenity]) then
        if cd_serenityCheck then
            return cd_serenity()
        end
    end
    local serenity_aoelustCheck = serenity_aoelust()
    if (buff[classtable.SerenityBuff].up and ( ( MaxDps:Bloodlust() and ( buff[classtable.InvokersDelightBuff].up or buff[classtable.PowerInfusionBuff].up ) ) or buff[classtable.InvokersDelightBuff].up and buff[classtable.PowerInfusionBuff].up ) and targets >4) then
        if serenity_aoelustCheck then
            return serenity_aoelust()
        end
    end
    local serenity_lustCheck = serenity_lust()
    if (buff[classtable.SerenityBuff].up and ( ( MaxDps:Bloodlust() and ( buff[classtable.InvokersDelightBuff].up or buff[classtable.PowerInfusionBuff].up ) ) or buff[classtable.InvokersDelightBuff].up and buff[classtable.PowerInfusionBuff].up ) and targets <4) then
        if serenity_lustCheck then
            return serenity_lust()
        end
    end
    local serenity_aoeCheck = serenity_aoe()
    if (buff[classtable.SerenityBuff].up and targets >4) then
        if serenity_aoeCheck then
            return serenity_aoe()
        end
    end
    local serenity_4tCheck = serenity_4t()
    if (buff[classtable.SerenityBuff].up and targets == 4) then
        if serenity_4tCheck then
            return serenity_4t()
        end
    end
    local serenity_3tCheck = serenity_3t()
    if (buff[classtable.SerenityBuff].up and targets == 3) then
        if serenity_3tCheck then
            return serenity_3t()
        end
    end
    local serenity_2tCheck = serenity_2t()
    if (buff[classtable.SerenityBuff].up and targets == 2) then
        if serenity_2tCheck then
            return serenity_2t()
        end
    end
    local serenity_stCheck = serenity_st()
    if (buff[classtable.SerenityBuff].up and targets == 1) then
        if serenity_stCheck then
            return serenity_st()
        end
    end
    local default_aoeCheck = default_aoe()
    if (targets >4) then
        if default_aoeCheck then
            return default_aoe()
        end
    end
    local default_4tCheck = default_4t()
    if (targets == 4) then
        if default_4tCheck then
            return default_4t()
        end
    end
    local default_3tCheck = default_3t()
    if (targets == 3) then
        if default_3tCheck then
            return default_3t()
        end
    end
    local default_2tCheck = default_2t()
    if (targets == 2) then
        if default_2tCheck then
            return default_2t()
        end
    end
    local default_stCheck = default_st()
    if (targets == 1) then
        if default_stCheck then
            return default_st()
        end
    end
    local fallthruCheck = fallthru()
    if fallthruCheck then
        return fallthruCheck
    end
    local bdb_setupCheck = bdb_setup()
    if (not buff[classtable.BonedustBrewBuff] and talents[classtable.BonedustBrew] and cooldown[classtable.BonedustBrew].duration <= 2 and ( ttd >60 and ( cooldown[classtable.StormEarthandFire].charges >0 or cooldown[classtable.StormEarthandFire].duration >10 ) and ( ( UnitExists('pet') and UnitName('pet')  == 'xuen' ) or cooldown[classtable.InvokeXuentheWhiteTiger].duration >10 or hold_xuen ) or ( ( ( UnitExists('pet') and UnitName('pet')  == 'xuen' ) or cooldown[classtable.InvokeXuentheWhiteTiger].duration >13 ) and ( cooldown[classtable.StormEarthandFire].charges >0 or cooldown[classtable.StormEarthandFire].duration >13 or buff[classtable.StormEarthandFireBuff].up ) ) )) then
        if bdb_setupCheck then
            return bdb_setup()
        end
    end
end
