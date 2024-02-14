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

local Windwalker = {}

local sync_serenity
local hold_xuen
local hold_tp_rsk
local hold_tp_bdb

local function CheckSpellCosts(spell,spellstring)
    --if MaxDps.learnedSpells[spell] == nil then
    --	return false
    --end
    if not IsSpellKnownOrOverridesKnown(spell) then return false end
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
        if UnitPower('player', costtable.type) < costtable.cost then
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

function Windwalker:precombat()
    if (MaxDps:FindSpell(classtable.Flask) and CheckSpellCosts(classtable.Flask, 'Flask')) and cooldown[classtable.Flask].ready then
        return classtable.Flask
    end
    if (MaxDps:FindSpell(classtable.Food) and CheckSpellCosts(classtable.Food, 'Food')) and cooldown[classtable.Food].ready then
        return classtable.Food
    end
    if (MaxDps:FindSpell(classtable.Augmentation) and CheckSpellCosts(classtable.Augmentation, 'Augmentation')) and cooldown[classtable.Augmentation].ready then
        return classtable.Augmentation
    end
    if (MaxDps:FindSpell(classtable.SnapshotStats) and CheckSpellCosts(classtable.SnapshotStats, 'SnapshotStats')) and cooldown[classtable.SnapshotStats].ready then
        return classtable.SnapshotStats
    end
    if ( CheckEquipped('NeltharionsCallToDominance') or CheckEquipped('AshesoftheEmbersoul') or CheckEquipped('MirrorofFracturedTomorrows') or CheckEquipped('WitherbarksBranch') ) and not ( (select(2,IsInInstance()) == 'party') or (select(2,IsInInstance()) == 'party') ) then
        sync_serenity = 1
    end
    if (MaxDps:FindSpell(classtable.SummonWhiteTigerStatue) and CheckSpellCosts(classtable.SummonWhiteTigerStatue, 'SummonWhiteTigerStatue')) and cooldown[classtable.SummonWhiteTigerStatue].ready then
        return classtable.SummonWhiteTigerStatue
    end
    if (MaxDps:FindSpell(classtable.ExpelHarm) and CheckSpellCosts(classtable.ExpelHarm, 'ExpelHarm')) and (Chi <ChiMax) and cooldown[classtable.ExpelHarm].ready then
        return classtable.ExpelHarm
    end
    if (MaxDps:FindSpell(classtable.ChiBurst) and CheckSpellCosts(classtable.ChiBurst, 'ChiBurst') and talents[classtable.ChiBurst]) and (not talents[classtable.JadefireStomp]) and cooldown[classtable.ChiBurst].ready then
        return classtable.ChiBurst
    end
    if (MaxDps:FindSpell(classtable.ChiWave) and CheckSpellCosts(classtable.ChiWave, 'ChiWave')) and cooldown[classtable.ChiWave].ready then
        return classtable.ChiWave
    end
end
function Windwalker:bdb_setup()
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
function Windwalker:cd_sef()
    if (MaxDps:FindSpell(classtable.InvokeXuentheWhiteTiger) and CheckSpellCosts(classtable.InvokeXuentheWhiteTiger, 'InvokeXuentheWhiteTiger') and talents[classtable.InvokeXuentheWhiteTiger]) and (not hold_xuen and ttd >25 and talents[classtable.BonedustBrew] and cooldown[classtable.BonedustBrew].remains <= 5 and ( targets <3 and Chi >= 3 or targets >= 3 and Chi >= 2 ) or ttd <25) and cooldown[classtable.InvokeXuentheWhiteTiger].ready then
        return classtable.InvokeXuentheWhiteTiger
    end
    if (MaxDps:FindSpell(classtable.InvokeXuentheWhiteTiger) and CheckSpellCosts(classtable.InvokeXuentheWhiteTiger, 'InvokeXuentheWhiteTiger') and talents[classtable.InvokeXuentheWhiteTiger]) and (ttd >25 and ttd >120 and ( not CheckTrinketNames('Ashes of the Embersoul') and not CheckTrinketNames('Witherbarks Branch') and not CheckTrinketNames('Ashes of the Embersoul') and not CheckTrinketNames('Witherbarks Branch') or ( CheckTrinketNames('Ashes of the Embersoul') or CheckTrinketNames('Witherbarks Branch') ) and not CheckTrinketCooldown(1) or ( CheckTrinketNames('Ashes of the Embersoul') or CheckTrinketNames('Witherbarks Branch') ) and not CheckTrinketCooldown(2) )) and cooldown[classtable.InvokeXuentheWhiteTiger].ready then
        return classtable.InvokeXuentheWhiteTiger
    end
    if (MaxDps:FindSpell(classtable.InvokeXuentheWhiteTiger) and CheckSpellCosts(classtable.InvokeXuentheWhiteTiger, 'InvokeXuentheWhiteTiger') and talents[classtable.InvokeXuentheWhiteTiger]) and (ttd <60 and ( debuff[classtable.SkyreachExhaustionDeBuff].remains <2 or debuff[classtable.SkyreachExhaustionDeBuff].remains >55 ) and not cooldown[classtable.Serenity].remains and targets <3) and cooldown[classtable.InvokeXuentheWhiteTiger].ready then
        return classtable.InvokeXuentheWhiteTiger
    end
    if (MaxDps:FindSpell(classtable.StormEarthandFire) and CheckSpellCosts(classtable.StormEarthandFire, 'StormEarthandFire') and talents[classtable.StormEarthandFire]) and (talents[classtable.BonedustBrew] and ( ttd <30 and cooldown[classtable.BonedustBrew].remains <4 and Chi >= 4 or buff[classtable.BonedustBrewBuff].up or not (targets==5) and targets >= 3 and cooldown[classtable.BonedustBrew].remains <= 2 and Chi >= 2 ) and ( ( UnitExists('pet') and UnitName('pet')  == 'xuen' ) or cooldown[classtable.InvokeXuentheWhiteTiger].remains >cooldown[classtable.StormEarthandFire].fullRecharge )) and cooldown[classtable.StormEarthandFire].ready then
        return classtable.StormEarthandFire
    end
    if (MaxDps:FindSpell(classtable.StormEarthandFire) and CheckSpellCosts(classtable.StormEarthandFire, 'StormEarthandFire') and talents[classtable.StormEarthandFire]) and (not talents[classtable.BonedustBrew] and ( ( UnitExists('pet') and UnitName('pet')  == 'xuen' ) or ttd >15 and cooldown[classtable.StormEarthandFire].fullRecharge <cooldown[classtable.InvokeXuentheWhiteTiger].remains )) and cooldown[classtable.StormEarthandFire].ready then
        return classtable.StormEarthandFire
    end
    if (MaxDps:FindSpell(classtable.BonedustBrew) and CheckSpellCosts(classtable.BonedustBrew, 'BonedustBrew') and talents[classtable.BonedustBrew]) and (( not buff[classtable.BonedustBrewBuff].up and buff[classtable.StormEarthandFireBuff].up and buff[classtable.StormEarthandFireBuff].remains <11 and (targets==5) ) or ( not buff[classtable.BonedustBrewBuff].up and ttd <30 and ttd >10 and (targets==5) and Chi >= 4 ) or ttd <10 or ( not debuff[classtable.SkyreachExhaustionDeBuff].up and targets >= 4 and (GetSpellCount(101546)) >= 2 ) or ( ( UnitExists('pet') and UnitName('pet')  == 'xuen' ) and (targets==5) and targets >= 4 )) and cooldown[classtable.BonedustBrew].ready then
        return classtable.BonedustBrew
    end
    if (not buff[classtable.BonedustBrewBuff].up and talents[classtable.BonedustBrew] and cooldown[classtable.BonedustBrew].remains <= 2 and ( ttd >60 and ( cooldown[classtable.StormEarthandFire].charges >0 or cooldown[classtable.StormEarthandFire].remains >10 ) and ( ( UnitExists('pet') and UnitName('pet')  == 'xuen' ) or cooldown[classtable.InvokeXuentheWhiteTiger].remains >10 or hold_xuen ) or ( ( ( UnitExists('pet') and UnitName('pet')  == 'xuen' ) or cooldown[classtable.InvokeXuentheWhiteTiger].remains >13 ) and ( cooldown[classtable.StormEarthandFire].charges >0 or cooldown[classtable.StormEarthandFire].remains >13 or buff[classtable.StormEarthandFireBuff].up ) ) )) then
        local bdb_setupCheck = Windwalker:bdb_setup()
        if bdb_setupCheck then
            return Windwalker:bdb_setup()
        end
    end
    if (MaxDps:FindSpell(classtable.StormEarthandFire) and CheckSpellCosts(classtable.StormEarthandFire, 'StormEarthandFire') and talents[classtable.StormEarthandFire]) and (ttd <20 or ( cooldown[classtable.StormEarthandFire].charges == 2 and cooldown[classtable.InvokeXuentheWhiteTiger].remains >cooldown[classtable.StormEarthandFire].fullRecharge ) and cooldown[classtable.FistsofFury].remains <= 9 and Chi >= 2 and cooldown[classtable.WhirlingDragonPunch].remains <= 12) and cooldown[classtable.StormEarthandFire].ready then
        return classtable.StormEarthandFire
    end
    if (MaxDps:FindSpell(classtable.TouchofDeath) and CheckSpellCosts(classtable.TouchofDeath, 'TouchofDeath')) and ((select(2,IsInInstance()) == 'party') and not buff[classtable.SerenityBuff].up and ( IsComboStrike(classtable.TouchofDeath) and targetHP <maxHP ) or ( buff[classtable.HiddenMastersForbiddenTouchBuff].remains <2 ) or ( buff[classtable.HiddenMastersForbiddenTouchBuff].remains >ttd )) and cooldown[classtable.TouchofDeath].ready then
        return classtable.TouchofDeath
    end
    if (MaxDps:FindSpell(classtable.TouchofDeath) and CheckSpellCosts(classtable.TouchofDeath, 'TouchofDeath')) and ((select(2,IsInInstance()) == 'party') and IsComboStrike(classtable.TouchofDeath) and ( ttd >60 or debuff[classtable.BonedustBrewDebuffDeBuff].up or ttd <10 )) and cooldown[classtable.TouchofDeath].ready then
        return classtable.TouchofDeath
    end
    if (MaxDps:FindSpell(classtable.TouchofDeath) and CheckSpellCosts(classtable.TouchofDeath, 'TouchofDeath')) and (not (select(2,IsInInstance()) == 'party') and IsComboStrike(classtable.TouchofDeath)) and cooldown[classtable.TouchofDeath].ready then
        return classtable.TouchofDeath
    end
    --if (MaxDps:FindSpell(classtable.TouchofKarma) and CheckSpellCosts(classtable.TouchofKarma, 'TouchofKarma')) and (ttd >90 or ( UnitExists('pet') and UnitName('pet')  == 'xuen' ) or hold_xuen or ttd <16) and cooldown[classtable.TouchofKarma].ready then
    --    return classtable.TouchofKarma
    --end
end
function Windwalker:cd_serenity()
    if (MaxDps:FindSpell(classtable.InvokeXuentheWhiteTiger) and CheckSpellCosts(classtable.InvokeXuentheWhiteTiger, 'InvokeXuentheWhiteTiger') and talents[classtable.InvokeXuentheWhiteTiger]) and (ttd >16 and not hold_xuen and talents[classtable.BonedustBrew] and cooldown[classtable.BonedustBrew].remains <= 1 or MaxDps:Bloodlust() or ttd <25) and cooldown[classtable.InvokeXuentheWhiteTiger].ready then
        return classtable.InvokeXuentheWhiteTiger
    end
    if (MaxDps:FindSpell(classtable.InvokeXuentheWhiteTiger) and CheckSpellCosts(classtable.InvokeXuentheWhiteTiger, 'InvokeXuentheWhiteTiger') and talents[classtable.InvokeXuentheWhiteTiger]) and (( ttd >16 or ( (select(2,IsInInstance()) == 'party') or (select(2,IsInInstance()) == 'party') ) and cooldown[classtable.Serenity].remains <2 ) and ttd >120 and ( not CheckTrinketNames('Ashes of the Embersoul') and not CheckTrinketNames('Witherbarks Branch') and not CheckTrinketNames('Ashes of the Embersoul') and not CheckTrinketNames('Witherbarks Branch') or ( CheckTrinketNames('Ashes of the Embersoul') or CheckTrinketNames('Witherbarks Branch') ) and not CheckTrinketCooldown(1) or ( CheckTrinketNames('Ashes of the Embersoul') or CheckTrinketNames('Witherbarks Branch') ) and not CheckTrinketCooldown(2) )) and cooldown[classtable.InvokeXuentheWhiteTiger].ready then
        return classtable.InvokeXuentheWhiteTiger
    end
    if (MaxDps:FindSpell(classtable.InvokeXuentheWhiteTiger) and CheckSpellCosts(classtable.InvokeXuentheWhiteTiger, 'InvokeXuentheWhiteTiger') and talents[classtable.InvokeXuentheWhiteTiger]) and (ttd >16 and ttd <60 and ( debuff[classtable.SkyreachExhaustionDeBuff].remains <2 or debuff[classtable.SkyreachExhaustionDeBuff].remains >55 ) and not cooldown[classtable.Serenity].remains and targets <3) and cooldown[classtable.InvokeXuentheWhiteTiger].ready then
        return classtable.InvokeXuentheWhiteTiger
    end
    if (MaxDps:FindSpell(classtable.InvokeXuentheWhiteTiger) and CheckSpellCosts(classtable.InvokeXuentheWhiteTiger, 'InvokeXuentheWhiteTiger') and talents[classtable.InvokeXuentheWhiteTiger]) and ((select(2,IsInInstance()) == 'party') and talents[classtable.BonedustBrew] and ttd >16 and not cooldown[classtable.Serenity].remains and cooldown[classtable.BonedustBrew].remains <2) and cooldown[classtable.InvokeXuentheWhiteTiger].ready then
        return classtable.InvokeXuentheWhiteTiger
    end
    if (MaxDps:FindSpell(classtable.BonedustBrew) and CheckSpellCosts(classtable.BonedustBrew, 'BonedustBrew') and talents[classtable.BonedustBrew]) and (buff[classtable.InvokersDelightBuff].up or not buff[classtable.BonedustBrewBuff].up and cooldown[classtable.XuentheWhiteTiger].remains and not ( UnitExists('pet') and UnitName('pet')  == 'xuen' ) or cooldown[classtable.Serenity].remains >15 or ttd <30 and ttd >10 or ttd <10) and cooldown[classtable.BonedustBrew].ready then
        return classtable.BonedustBrew
    end
    if (MaxDps:FindSpell(classtable.Serenity) and CheckSpellCosts(classtable.Serenity, 'Serenity') and talents[classtable.Serenity]) and (sync_serenity and ( buff[classtable.InvokersDelightBuff].up or hold_xuen and ( talents[classtable.DrinkingHornCover] and ttd >110 or not talents[classtable.DrinkingHornCover] and ttd >105 ) ) or not talents[classtable.InvokeXuentheWhiteTiger] or ttd <15) and cooldown[classtable.Serenity].ready then
        return classtable.Serenity
    end
    if (MaxDps:FindSpell(classtable.Serenity) and CheckSpellCosts(classtable.Serenity, 'Serenity') and talents[classtable.Serenity]) and (not sync_serenity and ( buff[classtable.InvokersDelightBuff].up or cooldown[classtable.InvokeXuentheWhiteTiger].remains >ttd or ttd >( cooldown[classtable.InvokeXuentheWhiteTiger].remains + 10 ) and ttd >90 )) and cooldown[classtable.Serenity].ready then
        return classtable.Serenity
    end
    if (MaxDps:FindSpell(classtable.TouchofDeath) and CheckSpellCosts(classtable.TouchofDeath, 'TouchofDeath')) and ((select(2,IsInInstance()) == 'party') and not buff[classtable.SerenityBuff].up and ( IsComboStrike(classtable.TouchofDeath) and targetHP <maxHP ) or ( buff[classtable.HiddenMastersForbiddenTouchBuff].remains <2 ) or ( buff[classtable.HiddenMastersForbiddenTouchBuff].remains >ttd )) and cooldown[classtable.TouchofDeath].ready then
        return classtable.TouchofDeath
    end
    if (MaxDps:FindSpell(classtable.TouchofDeath) and CheckSpellCosts(classtable.TouchofDeath, 'TouchofDeath')) and ((select(2,IsInInstance()) == 'party') and IsComboStrike(classtable.TouchofDeath) and ( ttd >60 or debuff[classtable.BonedustBrewDebuffDeBuff].up or ttd <10 ) and not buff[classtable.SerenityBuff].up) and cooldown[classtable.TouchofDeath].ready then
        return classtable.TouchofDeath
    end
    if (MaxDps:FindSpell(classtable.TouchofDeath) and CheckSpellCosts(classtable.TouchofDeath, 'TouchofDeath')) and (not (select(2,IsInInstance()) == 'party') and IsComboStrike(classtable.TouchofDeath) and not buff[classtable.SerenityBuff].up) and cooldown[classtable.TouchofDeath].ready then
        return classtable.TouchofDeath
    end
    --if (MaxDps:FindSpell(classtable.TouchofKarma) and CheckSpellCosts(classtable.TouchofKarma, 'TouchofKarma')) and (ttd >90 or ttd <10) and cooldown[classtable.TouchofKarma].ready then
    --    return classtable.TouchofKarma
    --end
end
function Windwalker:default_2t()
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and Chi <2 and ( cooldown[classtable.RisingSunKick].remains <1 or cooldown[classtable.FistsofFury].remains <1 or cooldown[classtable.StrikeoftheWindlord].remains <1 ) and buff[classtable.TeachingsoftheMonasteryBuff].count <3) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (MaxDps:FindSpell(classtable.ExpelHarm) and CheckSpellCosts(classtable.ExpelHarm, 'ExpelHarm')) and (Chi == 1 and ( not cooldown[classtable.RisingSunKick].remains or not cooldown[classtable.StrikeoftheWindlord].remains ) or Chi == 2 and not cooldown[classtable.FistsofFury].remains) and cooldown[classtable.ExpelHarm].ready then
        return classtable.ExpelHarm
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.TeachingsoftheMonasteryBuff].count == 3 and talents[classtable.ShadowboxingTreads]) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (talents[classtable.Thunderfist] and (MaxDps.tier and MaxDps.tier[31].count >= 4)) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (talents[classtable.Thunderfist] and ( cooldown[classtable.InvokeXuentheWhiteTiger].remains >20 or ttd <5 )) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and not buff[classtable.BlackoutReinforcementBuff].up and (MaxDps.tier and MaxDps.tier[31].count >= 2)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (talents[classtable.ShadowboxingTreads] and IsComboStrike(classtable.BlackoutKick) and buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.FistsofFury) and CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and (not (MaxDps.tier and MaxDps.tier[30].count >= 2)) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (MaxDps:FindSpell(classtable.FistsofFury) and CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (not cooldown[classtable.FistsofFury].remains) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and ((MaxDps.tier and MaxDps.tier[30].count >= 2)) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.KicksofFlowingMomentumBuff].up or buff[classtable.PressurePointBuff].up or debuff[classtable.SkyreachExhaustionDeBuff].remains >55) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and not buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
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
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.TeachingsoftheMonasteryBuff].up and ( talents[classtable.ShadowboxingTreads] or cooldown[classtable.RisingSunKick].remains >1 )) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.WhirlingDragonPunch) and CheckSpellCosts(classtable.WhirlingDragonPunch, 'WhirlingDragonPunch') and talents[classtable.WhirlingDragonPunch]) and cooldown[classtable.WhirlingDragonPunch].ready then
        return classtable.WhirlingDragonPunch
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.TeachingsoftheMonasteryBuff].count == 3) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (not talents[classtable.ShadowboxingTreads] and cooldown[classtable.FistsofFury].remains >4 and talents[classtable.XuensBattlegear]) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and cooldown[classtable.RisingSunKick].remains and cooldown[classtable.FistsofFury].remains and ( not buff[classtable.BonedustBrewBuff].up or (GetSpellCount(101546)) <1.5 )) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.RushingJadeWind) and CheckSpellCosts(classtable.RushingJadeWind, 'RushingJadeWind')) and (not buff[classtable.RushingJadeWindBuff].up) and cooldown[classtable.RushingJadeWind].ready then
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
    if (MaxDps:FindSpell(classtable.JadefireStomp) and CheckSpellCosts(classtable.JadefireStomp, 'JadefireStomp') and talents[classtable.JadefireStomp]) and (IsComboStrike(classtable.JadefireStomp)) and cooldown[classtable.JadefireStomp].ready then
        return classtable.JadefireStomp
    end
end
function Windwalker:default_3t()
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and Chi <2 and ( cooldown[classtable.RisingSunKick].remains <1 or cooldown[classtable.FistsofFury].remains <1 or cooldown[classtable.StrikeoftheWindlord].remains <1 ) and buff[classtable.TeachingsoftheMonasteryBuff].count <3) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and not buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (talents[classtable.Thunderfist] and (MaxDps.tier and MaxDps.tier[31].count >= 4)) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (talents[classtable.Thunderfist] and ( cooldown[classtable.InvokeXuentheWhiteTiger].remains >20 or ttd <5 )) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.TeachingsoftheMonasteryBuff].count == 3 and talents[classtable.ShadowboxingTreads]) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (talents[classtable.ShadowboxingTreads] and IsComboStrike(classtable.BlackoutKick) and buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.FistsofFury) and CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.BonedustBrewBuff].up and buff[classtable.PressurePointBuff].up and (MaxDps.tier and MaxDps.tier[30].count >= 2)) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and buff[classtable.BonedustBrewBuff].up and IsComboStrike(classtable.SpinningCraneKick)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (not buff[classtable.BonedustBrewBuff].up and buff[classtable.PressurePointBuff].up) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and ((MaxDps.tier and MaxDps.tier[30].count >= 2)) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.ExpelHarm) and CheckSpellCosts(classtable.ExpelHarm, 'ExpelHarm')) and (Chi == 1 and ( not cooldown[classtable.RisingSunKick].remains or not cooldown[classtable.StrikeoftheWindlord].remains ) or Chi == 2 and not cooldown[classtable.FistsofFury].remains) and cooldown[classtable.ExpelHarm].ready then
        return classtable.ExpelHarm
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.TeachingsoftheMonasteryBuff].count == 2) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.TeachingsoftheMonasteryBuff].up and ( talents[classtable.ShadowboxingTreads] or cooldown[classtable.RisingSunKick].remains >1 )) and cooldown[classtable.BlackoutKick].ready then
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
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and cooldown[classtable.FistsofFury].remains <3 and buff[classtable.ChiEnergyBuff].count >15) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (cooldown[classtable.FistsofFury].remains >4 and Chi >3) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and cooldown[classtable.RisingSunKick].remains and cooldown[classtable.FistsofFury].remains and Chi >4 and ( ( talents[classtable.StormEarthandFire] and not talents[classtable.BonedustBrew] ) or ( talents[classtable.Serenity] ) )) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and cooldown[classtable.FistsofFury].remains) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.RushingJadeWind) and CheckSpellCosts(classtable.RushingJadeWind, 'RushingJadeWind')) and (not buff[classtable.RushingJadeWindBuff].up) and cooldown[classtable.RushingJadeWind].ready then
        return classtable.RushingJadeWind
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and talents[classtable.ShadowboxingTreads] and not (targets==5)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and ( IsComboStrike(classtable.SpinningCraneKick) and Chi >5 and talents[classtable.StormEarthandFire] or IsComboStrike(classtable.SpinningCraneKick) and Chi >4 and talents[classtable.Serenity] )) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
end
function Windwalker:default_4t()
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and Chi <2 and ( cooldown[classtable.FistsofFury].remains <1 or cooldown[classtable.StrikeoftheWindlord].remains <1 ) and buff[classtable.TeachingsoftheMonasteryBuff].count <3) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and (targets==5) and not buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (talents[classtable.Thunderfist]) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.FistsofFury) and CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.BonedustBrewBuff].up and buff[classtable.PressurePointBuff].up and (MaxDps.tier and MaxDps.tier[30].count >= 2)) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (talents[classtable.ShadowboxingTreads] and IsComboStrike(classtable.BlackoutKick) and buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and buff[classtable.BonedustBrewBuff].up and IsComboStrike(classtable.SpinningCraneKick) and (targets==5)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.WhirlingDragonPunch) and CheckSpellCosts(classtable.WhirlingDragonPunch, 'WhirlingDragonPunch') and talents[classtable.WhirlingDragonPunch]) and cooldown[classtable.WhirlingDragonPunch].ready then
        return classtable.WhirlingDragonPunch
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (not buff[classtable.BonedustBrewBuff].up and buff[classtable.PressurePointBuff].up and cooldown[classtable.FistsofFury].remains >5) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.RushingJadeWind) and CheckSpellCosts(classtable.RushingJadeWind, 'RushingJadeWind')) and (not buff[classtable.RushingJadeWindBuff].up) and cooldown[classtable.RushingJadeWind].ready then
        return classtable.RushingJadeWind
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.TeachingsoftheMonasteryBuff].count == 3 and talents[classtable.ShadowboxingTreads]) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and ((MaxDps.tier and MaxDps.tier[30].count >= 2)) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.ExpelHarm) and CheckSpellCosts(classtable.ExpelHarm, 'ExpelHarm')) and (Chi == 1 and ( not cooldown[classtable.RisingSunKick].remains or not cooldown[classtable.StrikeoftheWindlord].remains ) or Chi == 2 and not cooldown[classtable.FistsofFury].remains) and cooldown[classtable.ExpelHarm].ready then
        return classtable.ExpelHarm
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and cooldown[classtable.FistsofFury].remains >3 and buff[classtable.ChiEnergyBuff].count >10) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and (MaxDps.tier and MaxDps.tier[30].count >= 2)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.ChiBurst) and CheckSpellCosts(classtable.ChiBurst, 'ChiBurst') and talents[classtable.ChiBurst]) and (MaxDps:Bloodlust() and Chi <5) and cooldown[classtable.ChiBurst].ready then
        return classtable.ChiBurst
    end
    if (MaxDps:FindSpell(classtable.ChiBurst) and CheckSpellCosts(classtable.ChiBurst, 'ChiBurst') and talents[classtable.ChiBurst]) and (Chi <5 and Energy <50) and cooldown[classtable.ChiBurst].ready then
        return classtable.ChiBurst
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and ( cooldown[classtable.FistsofFury].remains >3 or Chi >4 ) and (targets==5)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.TeachingsoftheMonasteryBuff].count == 3) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and ( cooldown[classtable.FistsofFury].remains >3 or Chi >4 )) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
end
function Windwalker:default_aoe()
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and (targets==5) and not buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
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
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.BonedustBrewBuff].up and buff[classtable.PressurePointBuff].up and (MaxDps.tier and MaxDps.tier[30].count >= 2)) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.TeachingsoftheMonasteryBuff].count == 3 and talents[classtable.ShadowboxingTreads]) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (talents[classtable.ShadowboxingTreads] and IsComboStrike(classtable.BlackoutKick) and buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.WhirlingDragonPunch) and CheckSpellCosts(classtable.WhirlingDragonPunch, 'WhirlingDragonPunch') and talents[classtable.WhirlingDragonPunch]) and (targets >= 5) and cooldown[classtable.WhirlingDragonPunch].ready then
        return classtable.WhirlingDragonPunch
    end
    if (MaxDps:FindSpell(classtable.RushingJadeWind) and CheckSpellCosts(classtable.RushingJadeWind, 'RushingJadeWind')) and (not buff[classtable.RushingJadeWindBuff].up) and cooldown[classtable.RushingJadeWind].ready then
        return classtable.RushingJadeWind
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.PressurePointBuff].up and (MaxDps.tier and MaxDps.tier[30].count >= 2)) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and ((MaxDps.tier and MaxDps.tier[30].count >= 2)) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (talents[classtable.WhirlingDragonPunch] and cooldown[classtable.WhirlingDragonPunch].remains <3 and cooldown[classtable.FistsofFury].remains >3 and not buff[classtable.KicksofFlowingMomentumBuff].up) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.ExpelHarm) and CheckSpellCosts(classtable.ExpelHarm, 'ExpelHarm')) and (Chi == 1 and ( not cooldown[classtable.RisingSunKick].remains or not cooldown[classtable.StrikeoftheWindlord].remains ) or Chi == 2 and not cooldown[classtable.FistsofFury].remains) and cooldown[classtable.ExpelHarm].ready then
        return classtable.ExpelHarm
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and cooldown[classtable.FistsofFury].remains <5 and buff[classtable.ChiEnergyBuff].count >10) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.ChiBurst) and CheckSpellCosts(classtable.ChiBurst, 'ChiBurst') and talents[classtable.ChiBurst]) and (MaxDps:Bloodlust() and Chi <5) and cooldown[classtable.ChiBurst].ready then
        return classtable.ChiBurst
    end
    if (MaxDps:FindSpell(classtable.ChiBurst) and CheckSpellCosts(classtable.ChiBurst, 'ChiBurst') and talents[classtable.ChiBurst]) and (Chi <5 and Energy <50) and cooldown[classtable.ChiBurst].ready then
        return classtable.ChiBurst
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and ( cooldown[classtable.FistsofFury].remains >3 or Chi >2 ) and (targets==5) and MaxDps:Bloodlust() and not buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and ( cooldown[classtable.FistsofFury].remains >3 or Chi >2 ) and (targets==5) and buff[classtable.InvokersDelightBuff].up and not buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (talents[classtable.ShadowboxingTreads] and IsComboStrike(classtable.BlackoutKick) and (MaxDps.tier and MaxDps.tier[30].count >= 2) and not buff[classtable.BonedustBrewBuff].up and targets <15 and not talents[classtable.CraneVortex]) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (talents[classtable.ShadowboxingTreads] and IsComboStrike(classtable.BlackoutKick) and (MaxDps.tier and MaxDps.tier[30].count >= 2) and not buff[classtable.BonedustBrewBuff].up and targets <8) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and ( cooldown[classtable.FistsofFury].remains >3 or Chi >4 ) and (targets==5)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.TeachingsoftheMonasteryBuff].count == 3) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (talents[classtable.ShadowboxingTreads] and IsComboStrike(classtable.BlackoutKick) and not (targets==5)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.ChiBurst) and CheckSpellCosts(classtable.ChiBurst, 'ChiBurst') and talents[classtable.ChiBurst]) and (ChiMax - Chi >= 1 and targets == 1 or ChiMax - Chi >= 2) and cooldown[classtable.ChiBurst].ready then
        return classtable.ChiBurst
    end
end
function Windwalker:default_st()
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and Chi <2 and ( cooldown[classtable.RisingSunKick].remains <1 or cooldown[classtable.FistsofFury].remains <1 or cooldown[classtable.StrikeoftheWindlord].remains <1 ) and buff[classtable.TeachingsoftheMonasteryBuff].count <3) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (MaxDps:FindSpell(classtable.ExpelHarm) and CheckSpellCosts(classtable.ExpelHarm, 'ExpelHarm')) and (Chi == 1 and ( not cooldown[classtable.RisingSunKick].remains or not cooldown[classtable.StrikeoftheWindlord].remains ) or Chi == 2 and not cooldown[classtable.FistsofFury].remains and cooldown[classtable.RisingSunKick].remains) and cooldown[classtable.ExpelHarm].ready then
        return classtable.ExpelHarm
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (buff[classtable.DomineeringArroganceBuff].up and talents[classtable.Thunderfist] and talents[classtable.Serenity] and cooldown[classtable.InvokeXuentheWhiteTiger].remains >20 or ttd <5 or talents[classtable.Thunderfist] and debuff[classtable.SkyreachExhaustionDeBuff].remains >10 and not buff[classtable.DomineeringArroganceBuff].up or talents[classtable.Thunderfist] and debuff[classtable.SkyreachExhaustionDeBuff].remains >35 and not talents[classtable.Serenity]) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and (MaxDps.tier and MaxDps.tier[31].count >= 2) and not buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (not cooldown[classtable.FistsofFury].remains) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.FistsofFury) and CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and (not buff[classtable.PressurePointBuff].up and debuff[classtable.SkyreachExhaustionDeBuff].remains <55 and ( debuff[classtable.JadefireBrandDamageDeBuff].remains >2 or cooldown[classtable.JadefireStomp].remains )) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (MaxDps:FindSpell(classtable.JadefireStomp) and CheckSpellCosts(classtable.JadefireStomp, 'JadefireStomp') and talents[classtable.JadefireStomp]) and (debuff[classtable.SkyreachExhaustionDeBuff].remains <1 and debuff[classtable.JadefireBrandDamageDeBuff].remains <3) and cooldown[classtable.JadefireStomp].ready then
        return classtable.JadefireStomp
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
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.BlackoutReinforcementBuff].up and cooldown[classtable.RisingSunKick].remains and IsComboStrike(classtable.BlackoutKick) and buff[classtable.DanceofChijiBuff].up) and cooldown[classtable.BlackoutKick].ready then
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
    if (MaxDps:FindSpell(classtable.WhirlingDragonPunch) and CheckSpellCosts(classtable.WhirlingDragonPunch, 'WhirlingDragonPunch') and talents[classtable.WhirlingDragonPunch]) and (not buff[classtable.PressurePointBuff].up) and cooldown[classtable.WhirlingDragonPunch].ready then
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
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and not (MaxDps.tier and MaxDps.tier[31].count >= 2)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.TeachingsoftheMonasteryBuff].up and cooldown[classtable.RisingSunKick].remains >1) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and buff[classtable.BonedustBrewBuff].up and IsComboStrike(classtable.SpinningCraneKick) and (GetSpellCount(101546)) >= 2.7) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.WhirlingDragonPunch) and CheckSpellCosts(classtable.WhirlingDragonPunch, 'WhirlingDragonPunch') and talents[classtable.WhirlingDragonPunch]) and cooldown[classtable.WhirlingDragonPunch].ready then
        return classtable.WhirlingDragonPunch
    end
    if (MaxDps:FindSpell(classtable.RushingJadeWind) and CheckSpellCosts(classtable.RushingJadeWind, 'RushingJadeWind')) and (not buff[classtable.RushingJadeWindBuff].up) and cooldown[classtable.RushingJadeWind].ready then
        return classtable.RushingJadeWind
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
end
function Windwalker:fallthru()
    if (MaxDps:FindSpell(classtable.CracklingJadeLightning) and CheckSpellCosts(classtable.CracklingJadeLightning, 'CracklingJadeLightning')) and (buff[classtable.theEmperorsCapacitorBuff].count >19 and EnergyTimeToMax >MaxDps:GetTimeToPct(30) - 1 and cooldown[classtable.RisingSunKick].remains >MaxDps:GetTimeToPct(30) or buff[classtable.theEmperorsCapacitorBuff].count >14 and ( cooldown[classtable.Serenity].remains <5 and talents[classtable.Serenity] or ttd <5 )) and cooldown[classtable.CracklingJadeLightning].ready then
        return classtable.CracklingJadeLightning
    end
    if (MaxDps:FindSpell(classtable.JadefireStomp) and CheckSpellCosts(classtable.JadefireStomp, 'JadefireStomp') and talents[classtable.JadefireStomp]) and (IsComboStrike(classtable.JadefireStomp)) and cooldown[classtable.JadefireStomp].ready then
        return classtable.JadefireStomp
    end
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and ChiMax - Chi >= ( 2 + buff[classtable.PowerStrikesBuff].duration )) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (MaxDps:FindSpell(classtable.ExpelHarm) and CheckSpellCosts(classtable.ExpelHarm, 'ExpelHarm')) and (ChiMax - Chi >= 1 and targets >2) and cooldown[classtable.ExpelHarm].ready then
        return classtable.ExpelHarm
    end
    if (MaxDps:FindSpell(classtable.ChiBurst) and CheckSpellCosts(classtable.ChiBurst, 'ChiBurst') and talents[classtable.ChiBurst]) and (ChiMax - Chi >= 1 and targets == 1 or ChiMax - Chi >= 2 and targets >= 2) and cooldown[classtable.ChiBurst].ready then
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
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.ChiEnergyBuff].count >30 - 5 * targets and not buff[classtable.StormEarthandFireBuff].up and ( cooldown[classtable.RisingSunKick].remains >2 and cooldown[classtable.FistsofFury].remains >2 or cooldown[classtable.RisingSunKick].remains <3 and cooldown[classtable.FistsofFury].remains >3 and Chi >3 or cooldown[classtable.RisingSunKick].remains >3 and cooldown[classtable.FistsofFury].remains <3 and Chi >4 or ChiMax - Chi <= 1 and EnergyTimeToMax <2 ) or buff[classtable.ChiEnergyBuff].count >10 and ttd <7) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    --if (MaxDps:FindSpell(classtable.FlyingSerpentKick) and CheckSpellCosts(classtable.FlyingSerpentKick, 'FlyingSerpentKick')) and cooldown[classtable.FlyingSerpentKick].ready then
    --    return classtable.FlyingSerpentKick
    --end
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
end
function Windwalker:opener()
    if (MaxDps:FindSpell(classtable.SummonWhiteTigerStatue) and CheckSpellCosts(classtable.SummonWhiteTigerStatue, 'SummonWhiteTigerStatue')) and cooldown[classtable.SummonWhiteTigerStatue].ready then
        return classtable.SummonWhiteTigerStatue
    end
    if (MaxDps:FindSpell(classtable.ExpelHarm) and CheckSpellCosts(classtable.ExpelHarm, 'ExpelHarm')) and (talents[classtable.ChiBurst] and ChiMax - Chi >= 3) and cooldown[classtable.ExpelHarm].ready then
        return classtable.ExpelHarm
    end
    if (MaxDps:FindSpell(classtable.JadefireStomp) and CheckSpellCosts(classtable.JadefireStomp, 'JadefireStomp') and talents[classtable.JadefireStomp]) and (debuff[classtable.JadefireBrandDamageDeBuff].remains <2 and not (debuff[classtable.SkyreachExhaustionDeBuff].duration <2) and not debuff[classtable.SkyreachExhaustionDeBuff].up) and cooldown[classtable.JadefireStomp].ready then
        return classtable.JadefireStomp
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
function Windwalker:serenity_2t()
    if (MaxDps:FindSpell(classtable.JadefireStomp) and CheckSpellCosts(classtable.JadefireStomp, 'JadefireStomp') and talents[classtable.JadefireStomp]) and (debuff[classtable.JadefireBrandDamageDeBuff].remains <2 and not (debuff[classtable.SkyreachExhaustionDeBuff].duration <2) and not debuff[classtable.SkyreachExhaustionDeBuff].up) and cooldown[classtable.JadefireStomp].ready then
        return classtable.JadefireStomp
    end
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (not debuff[classtable.SkyreachExhaustionDeBuff].up and IsComboStrike(classtable.TigerPalm)) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and buff[classtable.TeachingsoftheMonasteryBuff].count == 3 and buff[classtable.TeachingsoftheMonasteryBuff].remains <1) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and not buff[classtable.BlackoutReinforcementBuff].up and CheckPrevSpell(classtable.FistsofFury) and (MaxDps.tier and MaxDps.tier[31].count >= 2)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.PressurePointBuff].up or debuff[classtable.SkyreachExhaustionDeBuff].remains >55) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.PressurePointBuff].up and (MaxDps.tier and MaxDps.tier[30].count >= 2)) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and ((MaxDps.tier and MaxDps.tier[30].count >= 2)) and cooldown[classtable.RisingSunKick].ready then
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
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and not buff[classtable.BlackoutReinforcementBuff].up and (MaxDps.tier and MaxDps.tier[31].count >= 2)) and cooldown[classtable.SpinningCraneKick].ready then
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
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and not buff[classtable.BlackoutReinforcementBuff].up and (MaxDps.tier and MaxDps.tier[31].count >= 2)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.BlackoutReinforcementBuff].up and (MaxDps.tier and MaxDps.tier[31].count >= 2)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and (MaxDps.tier and MaxDps.tier[30].count >= 2)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and buff[classtable.TeachingsoftheMonasteryBuff].count == 2) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (cooldown[classtable.FistsofFury].remains >5 and talents[classtable.ShadowboxingTreads] and buff[classtable.TeachingsoftheMonasteryBuff].count == 1 and IsComboStrike(classtable.BlackoutKick)) and cooldown[classtable.BlackoutKick].ready then
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
function Windwalker:serenity_3t()
    if (MaxDps:FindSpell(classtable.JadefireStomp) and CheckSpellCosts(classtable.JadefireStomp, 'JadefireStomp') and talents[classtable.JadefireStomp]) and (debuff[classtable.JadefireBrandDamageDeBuff].remains <1) and cooldown[classtable.JadefireStomp].ready then
        return classtable.JadefireStomp
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and ((MaxDps.tier and MaxDps.tier[31].count >= 2) and IsComboStrike(classtable.BlackoutKick) and buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (not debuff[classtable.SkyreachExhaustionDeBuff].up and IsComboStrike(classtable.TigerPalm)) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and (targets==5) and not buff[classtable.BlackoutReinforcementBuff].up and (MaxDps.tier and MaxDps.tier[31].count >= 2)) and cooldown[classtable.SpinningCraneKick].ready then
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
    if (MaxDps:FindSpell(classtable.FistsofFury) and CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and (buff[classtable.InvokersDelightBuff].up and not (MaxDps.tier and MaxDps.tier[31].count >= 2)) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (MaxDps:FindSpell(classtable.FistsofFuryCancel) and CheckSpellCosts(classtable.FistsofFuryCancel, 'FistsofFuryCancel')) and (not (MaxDps.tier and MaxDps.tier[31].count >= 2) or buff[classtable.FuryofXuenStacksBuff].count >90) and cooldown[classtable.FistsofFuryCancel].ready then
        return classtable.FistsofFuryCancel
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and (targets==5) and not buff[classtable.BlackoutReinforcementBuff].up and (MaxDps.tier and MaxDps.tier[31].count >= 2)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and (targets==5) and buff[classtable.BlackoutReinforcementBuff].up and (MaxDps.tier and MaxDps.tier[31].count >= 2) and CheckPrevSpell(classtable.BlackoutKick) and talents[classtable.CraneVortex]) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and not buff[classtable.PressurePointBuff].up) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.PressurePointBuff].up) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.PressurePointBuff].up and (MaxDps.tier and MaxDps.tier[30].count >= 2)) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and ((MaxDps.tier and MaxDps.tier[30].count >= 2)) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.JadefireStomp) and CheckSpellCosts(classtable.JadefireStomp, 'JadefireStomp') and talents[classtable.JadefireStomp]) and (debuff[classtable.JadefireBrandDamageDeBuff].remains <2) and cooldown[classtable.JadefireStomp].ready then
        return classtable.JadefireStomp
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (talents[classtable.Thunderfist]) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and (targets==5) and not buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and (MaxDps.tier and MaxDps.tier[30].count >= 2)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and buff[classtable.TeachingsoftheMonasteryBuff].count == 2) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (talents[classtable.ShadowboxingTreads] and IsComboStrike(classtable.BlackoutKick)) and cooldown[classtable.BlackoutKick].ready then
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
    if (MaxDps:FindSpell(classtable.RushingJadeWind) and CheckSpellCosts(classtable.RushingJadeWind, 'RushingJadeWind')) and (not buff[classtable.RushingJadeWindBuff].up) and cooldown[classtable.RushingJadeWind].ready then
        return classtable.RushingJadeWind
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (talents[classtable.TeachingsoftheMonastery] and buff[classtable.TeachingsoftheMonasteryBuff].count <3) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
end
function Windwalker:serenity_4t()
    if (MaxDps:FindSpell(classtable.JadefireStomp) and CheckSpellCosts(classtable.JadefireStomp, 'JadefireStomp') and talents[classtable.JadefireStomp]) and (debuff[classtable.JadefireBrandDamageDeBuff].remains <1) and cooldown[classtable.JadefireStomp].ready then
        return classtable.JadefireStomp
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and buff[classtable.SerenityBuff].remains <1.5 and IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.BlackoutReinforcementBuff].up and (MaxDps.tier and MaxDps.tier[31].count >= 2)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and ((MaxDps.tier and MaxDps.tier[31].count >= 4) and talents[classtable.Thunderfist]) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and not buff[classtable.BlackoutReinforcementBuff].up and (MaxDps.tier and MaxDps.tier[31].count >= 2)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.FistsofFuryCancel) and CheckSpellCosts(classtable.FistsofFuryCancel, 'FistsofFuryCancel')) and (not (MaxDps.tier and MaxDps.tier[30].count >= 2) and buff[classtable.FuryofXuenStacksBuff].count >90) and cooldown[classtable.FistsofFuryCancel].ready then
        return classtable.FistsofFuryCancel
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and (MaxDps.tier and MaxDps.tier[31].count >= 2) and not buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and buff[classtable.TeachingsoftheMonasteryBuff].count == 3 and buff[classtable.TeachingsoftheMonasteryBuff].remains <1) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and ((MaxDps.tier and MaxDps.tier[31].count >= 2) and IsComboStrike(classtable.BlackoutKick) and buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and (MaxDps.tier and MaxDps.tier[31].count >= 2) and IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.BlackoutReinforcementBuff].up and talents[classtable.CraneVortex]) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.PressurePointBuff].up and not talents[classtable.BonedustBrew]) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.FistsofFury) and CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and (buff[classtable.InvokersDelightBuff].up and (MaxDps.tier and MaxDps.tier[31].count >= 2) and buff[classtable.TransferthePowerBuff].count >5 and not talents[classtable.CraneVortex] and MaxDps:Bloodlust()) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.PressurePointBuff].up and (MaxDps.tier and MaxDps.tier[30].count >= 2)) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and ((MaxDps.tier and MaxDps.tier[30].count >= 2)) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and (MaxDps.tier and MaxDps.tier[31].count >= 2) and IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (talents[classtable.Thunderfist] and buff[classtable.CallToDominanceBuff].up and debuff[classtable.SkyreachExhaustionDeBuff].remains >buff[classtable.CallToDominanceBuff].remains) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.JadefireStomp) and CheckSpellCosts(classtable.JadefireStomp, 'JadefireStomp') and talents[classtable.JadefireStomp]) and (debuff[classtable.JadefireBrandDamageDeBuff].remains <2) and cooldown[classtable.JadefireStomp].ready then
        return classtable.JadefireStomp
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
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and not buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.PressurePointBuff].up) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and (MaxDps.tier and MaxDps.tier[30].count >= 2)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and (targets==5)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (talents[classtable.ShadowboxingTreads] and IsComboStrike(classtable.BlackoutKick)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.WhirlingDragonPunch) and CheckSpellCosts(classtable.WhirlingDragonPunch, 'WhirlingDragonPunch') and talents[classtable.WhirlingDragonPunch]) and cooldown[classtable.WhirlingDragonPunch].ready then
        return classtable.WhirlingDragonPunch
    end
    if (MaxDps:FindSpell(classtable.RushingJadeWind) and CheckSpellCosts(classtable.RushingJadeWind, 'RushingJadeWind')) and (not buff[classtable.RushingJadeWindBuff].up) and cooldown[classtable.RushingJadeWind].ready then
        return classtable.RushingJadeWind
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (talents[classtable.TeachingsoftheMonastery] and buff[classtable.TeachingsoftheMonasteryBuff].count <3) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
end
function Windwalker:serenity_aoe()
    if (MaxDps:FindSpell(classtable.JadefireStomp) and CheckSpellCosts(classtable.JadefireStomp, 'JadefireStomp') and talents[classtable.JadefireStomp]) and (debuff[classtable.JadefireBrandDamageDeBuff].remains <1) and cooldown[classtable.JadefireStomp].ready then
        return classtable.JadefireStomp
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and ((MaxDps.tier and MaxDps.tier[31].count >= 4) and talents[classtable.Thunderfist]) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and (MaxDps.tier and MaxDps.tier[31].count >= 2)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.BlackoutReinforcementBuff].up and (MaxDps.tier and MaxDps.tier[31].count >= 2) and buff[classtable.BonedustBrewBuff].up and targets >4) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.FistsofFury) and CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and (talents[classtable.JadeIgnition]) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and (MaxDps.tier and MaxDps.tier[31].count >= 2) and IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.FistsofFury) and CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and (buff[classtable.InvokersDelightBuff].up and (MaxDps.tier and MaxDps.tier[31].count >= 2) and ( not buff[classtable.BonedustBrewBuff].up or targets >10 ) and ( buff[classtable.TransferthePowerBuff].count == 10 and not talents[classtable.CraneVortex] or targets >5 and talents[classtable.CraneVortex] and buff[classtable.TransferthePowerBuff].count == 10 or targets >14 or targets >12 and not talents[classtable.CraneVortex] )) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (MaxDps:FindSpell(classtable.FistsofFuryCancel) and CheckSpellCosts(classtable.FistsofFuryCancel, 'FistsofFuryCancel')) and (not (MaxDps.tier and MaxDps.tier[30].count >= 2) and (MaxDps.tier and MaxDps.tier[31].count >= 2) and ( not buff[classtable.BonedustBrewBuff].up or targets >10 ) and ( buff[classtable.TransferthePowerBuff].count == 10 and not talents[classtable.CraneVortex] or targets >5 and talents[classtable.CraneVortex] and buff[classtable.TransferthePowerBuff].count == 10 or targets >14 or targets >12 and not talents[classtable.CraneVortex] ) and not buff[classtable.BonedustBrewBuff].up or buff[classtable.FuryofXuenStacksBuff].count >90) and cooldown[classtable.FistsofFuryCancel].ready then
        return classtable.FistsofFuryCancel
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and not (targets==5) and talents[classtable.ShadowboxingTreads]) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and buff[classtable.TeachingsoftheMonasteryBuff].count == 3 and buff[classtable.TeachingsoftheMonasteryBuff].remains <1) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and not buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and (MaxDps.tier and MaxDps.tier[31].count >= 2) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.BlackoutReinforcementBuff].up and CheckPrevSpell(classtable.BlackoutKick) and buff[classtable.DanceofChijiBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and ((MaxDps.tier and MaxDps.tier[31].count >= 2) and IsComboStrike(classtable.BlackoutKick) and buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and (MaxDps.tier and MaxDps.tier[31].count >= 2) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.BlackoutReinforcementBuff].up and CheckPrevSpell(classtable.BlackoutKick)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.PressurePointBuff].up and (MaxDps.tier and MaxDps.tier[30].count >= 2)) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and ((MaxDps.tier and MaxDps.tier[30].count >= 2)) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (talents[classtable.Thunderfist] and buff[classtable.CallToDominanceBuff].up and debuff[classtable.SkyreachExhaustionDeBuff].remains >buff[classtable.CallToDominanceBuff].remains and targets <10) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.JadefireStomp) and CheckSpellCosts(classtable.JadefireStomp, 'JadefireStomp') and talents[classtable.JadefireStomp]) and (debuff[classtable.JadefireBrandDamageDeBuff].remains <2) and cooldown[classtable.JadefireStomp].ready then
        return classtable.JadefireStomp
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
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (targets <6 and IsComboStrike(classtable.BlackoutKick) and (MaxDps.tier and MaxDps.tier[30].count >= 2)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and (targets==5)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (not debuff[classtable.SkyreachExhaustionDeBuff].up and IsComboStrike(classtable.TigerPalm) and targets == 5) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (MaxDps:FindSpell(classtable.RushingJadeWind) and CheckSpellCosts(classtable.RushingJadeWind, 'RushingJadeWind')) and (not buff[classtable.RushingJadeWindBuff].up) and cooldown[classtable.RushingJadeWind].ready then
        return classtable.RushingJadeWind
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (talents[classtable.ShadowboxingTreads] and targets >= 3 and IsComboStrike(classtable.BlackoutKick)) and cooldown[classtable.BlackoutKick].ready then
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
    if (MaxDps:FindSpell(classtable.RushingJadeWind) and CheckSpellCosts(classtable.RushingJadeWind, 'RushingJadeWind')) and (not buff[classtable.RushingJadeWindBuff].up) and cooldown[classtable.RushingJadeWind].ready then
        return classtable.RushingJadeWind
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (talents[classtable.TeachingsoftheMonastery] and buff[classtable.TeachingsoftheMonasteryBuff].count <3) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (MaxDps:FindSpell(classtable.JadefireStomp) and CheckSpellCosts(classtable.JadefireStomp, 'JadefireStomp') and talents[classtable.JadefireStomp]) and (debuff[classtable.JadefireBrandDamageDeBuff].remains <1) and cooldown[classtable.JadefireStomp].ready then
        return classtable.JadefireStomp
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and ((MaxDps.tier and MaxDps.tier[31].count >= 4) and talents[classtable.Thunderfist]) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and (MaxDps.tier and MaxDps.tier[31].count >= 2)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.FistsofFury) and CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and (talents[classtable.JadeIgnition]) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.BlackoutReinforcementBuff].up and (MaxDps.tier and MaxDps.tier[31].count >= 2) and buff[classtable.BonedustBrewBuff].up and targets >4) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and (MaxDps.tier and MaxDps.tier[31].count >= 2) and IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.FistsofFury) and CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and (buff[classtable.InvokersDelightBuff].up and (MaxDps.tier and MaxDps.tier[31].count >= 2) and ( targets >5 and buff[classtable.TransferthePowerBuff].count >5 or targets >6 or targets >4 and not talents[classtable.CraneVortex] and buff[classtable.TransferthePowerBuff].count >5 )) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (MaxDps:FindSpell(classtable.FistsofFury) and CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and (not (MaxDps.tier and MaxDps.tier[30].count >= 2) and not buff[classtable.InvokersDelightBuff].up and (MaxDps.tier and MaxDps.tier[31].count >= 2) and ( not buff[classtable.BonedustBrewBuff].up or targets >10 ) and ( buff[classtable.TransferthePowerBuff].count == 10 and not talents[classtable.CraneVortex] or targets >5 and talents[classtable.CraneVortex] and buff[classtable.TransferthePowerBuff].count == 10 or targets >14 or targets >12 and not talents[classtable.CraneVortex] )) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and not (targets==5) and talents[classtable.ShadowboxingTreads]) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and buff[classtable.TeachingsoftheMonasteryBuff].count == 3 and buff[classtable.TeachingsoftheMonasteryBuff].remains <1) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and not buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and (MaxDps.tier and MaxDps.tier[31].count >= 2) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.BlackoutReinforcementBuff].up and CheckPrevSpell(classtable.BlackoutKick) and buff[classtable.DanceofChijiBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and ((MaxDps.tier and MaxDps.tier[31].count >= 2) and IsComboStrike(classtable.BlackoutKick) and buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and (MaxDps.tier and MaxDps.tier[31].count >= 2) and IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (targets <6 and IsComboStrike(classtable.BlackoutKick) and (MaxDps.tier and MaxDps.tier[31].count >= 2)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.PressurePointBuff].up and (MaxDps.tier and MaxDps.tier[30].count >= 2)) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and ((MaxDps.tier and MaxDps.tier[30].count >= 2)) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (talents[classtable.Thunderfist] and buff[classtable.CallToDominanceBuff].up and debuff[classtable.SkyreachExhaustionDeBuff].remains >buff[classtable.CallToDominanceBuff].remains and targets <10) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.JadefireStomp) and CheckSpellCosts(classtable.JadefireStomp, 'JadefireStomp') and talents[classtable.JadefireStomp]) and (debuff[classtable.JadefireBrandDamageDeBuff].remains <2) and cooldown[classtable.JadefireStomp].ready then
        return classtable.JadefireStomp
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
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (targets <6 and IsComboStrike(classtable.BlackoutKick) and (MaxDps.tier and MaxDps.tier[30].count >= 2)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and (targets==5)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (not debuff[classtable.SkyreachExhaustionDeBuff].up and IsComboStrike(classtable.TigerPalm) and targets == 5) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (MaxDps:FindSpell(classtable.RushingJadeWind) and CheckSpellCosts(classtable.RushingJadeWind, 'RushingJadeWind')) and (not buff[classtable.RushingJadeWindBuff].up) and cooldown[classtable.RushingJadeWind].ready then
        return classtable.RushingJadeWind
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (talents[classtable.ShadowboxingTreads] and targets >= 3 and IsComboStrike(classtable.BlackoutKick)) and cooldown[classtable.BlackoutKick].ready then
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
    if (MaxDps:FindSpell(classtable.RushingJadeWind) and CheckSpellCosts(classtable.RushingJadeWind, 'RushingJadeWind')) and (not buff[classtable.RushingJadeWindBuff].up) and cooldown[classtable.RushingJadeWind].ready then
        return classtable.RushingJadeWind
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (talents[classtable.TeachingsoftheMonastery] and buff[classtable.TeachingsoftheMonasteryBuff].count <3) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
end
function Windwalker:serenity_aoelust()
    if (MaxDps:FindSpell(classtable.JadefireStomp) and CheckSpellCosts(classtable.JadefireStomp, 'JadefireStomp') and talents[classtable.JadefireStomp]) and (debuff[classtable.JadefireBrandDamageDeBuff].remains <1) and cooldown[classtable.JadefireStomp].ready then
        return classtable.JadefireStomp
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and ((MaxDps.tier and MaxDps.tier[31].count >= 4) and talents[classtable.Thunderfist]) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and (MaxDps.tier and MaxDps.tier[31].count >= 2)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.FistsofFury) and CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and (talents[classtable.JadeIgnition]) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.BlackoutReinforcementBuff].up and (MaxDps.tier and MaxDps.tier[31].count >= 2) and buff[classtable.BonedustBrewBuff].up and targets >4) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and (MaxDps.tier and MaxDps.tier[31].count >= 2) and IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.FistsofFury) and CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and (buff[classtable.InvokersDelightBuff].up and (MaxDps.tier and MaxDps.tier[31].count >= 2) and ( targets >5 and buff[classtable.TransferthePowerBuff].count >5 or targets >6 or targets >4 and not talents[classtable.CraneVortex] and buff[classtable.TransferthePowerBuff].count >5 )) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (MaxDps:FindSpell(classtable.FistsofFury) and CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and (not (MaxDps.tier and MaxDps.tier[30].count >= 2) and not buff[classtable.InvokersDelightBuff].up and (MaxDps.tier and MaxDps.tier[31].count >= 2) and ( not buff[classtable.BonedustBrewBuff].up or targets >10 ) and ( buff[classtable.TransferthePowerBuff].count == 10 and not talents[classtable.CraneVortex] or targets >5 and talents[classtable.CraneVortex] and buff[classtable.TransferthePowerBuff].count == 10 or targets >14 or targets >12 and not talents[classtable.CraneVortex] )) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and not (targets==5) and talents[classtable.ShadowboxingTreads]) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and buff[classtable.TeachingsoftheMonasteryBuff].count == 3 and buff[classtable.TeachingsoftheMonasteryBuff].remains <1) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and not buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and (MaxDps.tier and MaxDps.tier[31].count >= 2) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.BlackoutReinforcementBuff].up and CheckPrevSpell(classtable.BlackoutKick) and buff[classtable.DanceofChijiBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and ((MaxDps.tier and MaxDps.tier[31].count >= 2) and IsComboStrike(classtable.BlackoutKick) and buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and (MaxDps.tier and MaxDps.tier[31].count >= 2) and IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (targets <6 and IsComboStrike(classtable.BlackoutKick) and (MaxDps.tier and MaxDps.tier[31].count >= 2)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.PressurePointBuff].up and (MaxDps.tier and MaxDps.tier[30].count >= 2)) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and ((MaxDps.tier and MaxDps.tier[30].count >= 2)) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (talents[classtable.Thunderfist] and buff[classtable.CallToDominanceBuff].up and debuff[classtable.SkyreachExhaustionDeBuff].remains >buff[classtable.CallToDominanceBuff].remains and targets <10) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.JadefireStomp) and CheckSpellCosts(classtable.JadefireStomp, 'JadefireStomp') and talents[classtable.JadefireStomp]) and (debuff[classtable.JadefireBrandDamageDeBuff].remains <2) and cooldown[classtable.JadefireStomp].ready then
        return classtable.JadefireStomp
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
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (targets <6 and IsComboStrike(classtable.BlackoutKick) and (MaxDps.tier and MaxDps.tier[30].count >= 2)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and (targets==5)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (not debuff[classtable.SkyreachExhaustionDeBuff].up and IsComboStrike(classtable.TigerPalm) and targets == 5) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (MaxDps:FindSpell(classtable.RushingJadeWind) and CheckSpellCosts(classtable.RushingJadeWind, 'RushingJadeWind')) and (not buff[classtable.RushingJadeWindBuff].up) and cooldown[classtable.RushingJadeWind].ready then
        return classtable.RushingJadeWind
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (talents[classtable.ShadowboxingTreads] and targets >= 3 and IsComboStrike(classtable.BlackoutKick)) and cooldown[classtable.BlackoutKick].ready then
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
    if (MaxDps:FindSpell(classtable.RushingJadeWind) and CheckSpellCosts(classtable.RushingJadeWind, 'RushingJadeWind')) and (not buff[classtable.RushingJadeWindBuff].up) and cooldown[classtable.RushingJadeWind].ready then
        return classtable.RushingJadeWind
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (talents[classtable.TeachingsoftheMonastery] and buff[classtable.TeachingsoftheMonasteryBuff].count <3) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
end
function Windwalker:serenity_lust()
    if (MaxDps:FindSpell(classtable.JadefireStomp) and CheckSpellCosts(classtable.JadefireStomp, 'JadefireStomp') and talents[classtable.JadefireStomp]) and (debuff[classtable.JadefireBrandDamageDeBuff].remains <1) and cooldown[classtable.JadefireStomp].ready then
        return classtable.JadefireStomp
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and buff[classtable.SerenityBuff].remains <1.5 and IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.BlackoutReinforcementBuff].up and (MaxDps.tier and MaxDps.tier[31].count >= 2)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and buff[classtable.TeachingsoftheMonasteryBuff].count == 3 and buff[classtable.TeachingsoftheMonasteryBuff].remains <1) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and not buff[classtable.BlackoutReinforcementBuff].up and (MaxDps.tier and MaxDps.tier[31].count >= 2) and targets >2) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (talents[classtable.Thunderfist]) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and buff[classtable.BlackoutReinforcementBuff].up and targets >2) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (IsComboStrike(classtable.RisingSunKick) and ( targets <3 or not (MaxDps.tier and MaxDps.tier[31].count >= 2) )) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and buff[classtable.BlackoutReinforcementBuff].up and CheckPrevSpell(classtable.FistsofFury) and talents[classtable.ShadowboxingTreads] and (MaxDps.tier and MaxDps.tier[31].count >= 2) and not talents[classtable.DanceofChiji]) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and not buff[classtable.BlackoutReinforcementBuff].up and CheckPrevSpell(classtable.FistsofFury) and debuff[classtable.SkyreachExhaustionDeBuff].remains >55 and (MaxDps.tier and MaxDps.tier[31].count >= 2)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.FistsofFury) and CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and (buff[classtable.InvokersDelightBuff].up and ( targets <3 or not (MaxDps.tier and MaxDps.tier[31].count >= 2) )) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and (targets==5) and not buff[classtable.BlackoutReinforcementBuff].up and targets >2 and (MaxDps.tier and MaxDps.tier[31].count >= 2)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and (targets==5) and buff[classtable.BlackoutReinforcementBuff].up and targets >2 and CheckPrevSpell(classtable.BlackoutKick) and (MaxDps.tier and MaxDps.tier[31].count >= 2)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and (targets==5) and buff[classtable.BonedustBrewBuff].up and targets >2 and (MaxDps.tier and MaxDps.tier[31].count >= 2)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.FistsofFuryCancel) and CheckSpellCosts(classtable.FistsofFuryCancel, 'FistsofFuryCancel')) and (targets <3 or not (MaxDps.tier and MaxDps.tier[31].count >= 2)) and cooldown[classtable.FistsofFuryCancel].ready then
        return classtable.FistsofFuryCancel
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and not buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.BlackoutReinforcementBuff].up and buff[classtable.BonedustBrewBuff].up and (MaxDps.tier and MaxDps.tier[31].count >= 2)) and cooldown[classtable.SpinningCraneKick].ready then
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
function Windwalker:serenity_st()
    if (MaxDps:FindSpell(classtable.JadefireStomp) and CheckSpellCosts(classtable.JadefireStomp, 'JadefireStomp') and talents[classtable.JadefireStomp]) and (debuff[classtable.JadefireBrandDamageDeBuff].remains <2 and not debuff[classtable.SkyreachExhaustionDeBuff].up) and cooldown[classtable.JadefireStomp].ready then
        return classtable.JadefireStomp
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and buff[classtable.SerenityBuff].remains <1.5 and IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.BlackoutReinforcementBuff].up and (MaxDps.tier and MaxDps.tier[31].count >= 4)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (not debuff[classtable.SkyreachExhaustionDeBuff].up and IsComboStrike(classtable.TigerPalm)) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and buff[classtable.TeachingsoftheMonasteryBuff].count == 3 and buff[classtable.TeachingsoftheMonasteryBuff].remains <1) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (talents[classtable.Thunderfist] and (MaxDps.tier and MaxDps.tier[31].count >= 4)) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.RisingSunKick) and CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (IsComboStrike(classtable.RisingSunKick)) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (MaxDps:FindSpell(classtable.JadefireStomp) and CheckSpellCosts(classtable.JadefireStomp, 'JadefireStomp') and talents[classtable.JadefireStomp]) and (debuff[classtable.JadefireBrandDamageDeBuff].remains <2) and cooldown[classtable.JadefireStomp].ready then
        return classtable.JadefireStomp
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (talents[classtable.Thunderfist] and buff[classtable.CallToDominanceBuff].up and debuff[classtable.SkyreachExhaustionDeBuff].remains >buff[classtable.CallToDominanceBuff].remains) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (talents[classtable.Thunderfist] and debuff[classtable.SkyreachExhaustionDeBuff].remains >55) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and not buff[classtable.BlackoutReinforcementBuff].up and CheckPrevSpell(classtable.RisingSunKick) and (MaxDps.tier and MaxDps.tier[31].count >= 2)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and (MaxDps.tier and MaxDps.tier[31].count >= 2) and buff[classtable.BlackoutReinforcementBuff].up and CheckPrevSpell(classtable.RisingSunKick)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and not buff[classtable.BlackoutReinforcementBuff].up and CheckPrevSpell(classtable.FistsofFury) and (MaxDps.tier and MaxDps.tier[31].count >= 2)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and buff[classtable.BlackoutReinforcementBuff].up and CheckPrevSpell(classtable.FistsofFury) and (MaxDps.tier and MaxDps.tier[31].count >= 2)) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.BlackoutReinforcementBuff].up and (MaxDps.tier and MaxDps.tier[31].count >= 2) and CheckPrevSpell(classtable.FistsofFury)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.FistsofFury) and CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and (buff[classtable.InvokersDelightBuff].up) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (MaxDps:FindSpell(classtable.FistsofFuryCancel) and CheckSpellCosts(classtable.FistsofFuryCancel, 'FistsofFuryCancel')) and cooldown[classtable.FistsofFuryCancel].ready then
        return classtable.FistsofFuryCancel
    end
    if (MaxDps:FindSpell(classtable.SpinningCraneKick) and CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (ttd >(select(4,GetSpellInfo(classtable.SpinningCraneKick))) and IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.BlackoutReinforcementBuff].up and (MaxDps.tier and MaxDps.tier[31].count >= 2)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (MaxDps:FindSpell(classtable.StrikeoftheWindlord) and CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (debuff[classtable.SkyreachExhaustionDeBuff].remains >buff[classtable.CallToDominanceBuff].remains) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (MaxDps:FindSpell(classtable.BlackoutKick) and CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and (MaxDps.tier and MaxDps.tier[30].count >= 2)) and cooldown[classtable.BlackoutKick].ready then
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
local function trinkets()
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
    classtable.StormEarthandFireBuff = 137639
    classtable.SkyreachExhaustionDeBuff = 393050
    classtable.BonedustBrewBuff = 386276
    classtable.SerenityBuff = 152173
    classtable.HiddenMastersForbiddenTouchBuff = 213114
    classtable.BonedustBrewDebuffDeBuff = 386276
    classtable.InvokersDelightBuff = 388663
    classtable.TeachingsoftheMonasteryBuff = 202090
    classtable.DanceofChijiBuff = 325202
    classtable.BlackoutReinforcementBuff = 424454
    classtable.KicksofFlowingMomentumBuff = 394944
    classtable.PressurePointBuff = 393053
    classtable.RushingJadeWindBuff = 116847
    classtable.ChiEnergyBuff = 393057
    classtable.DomineeringArroganceBuff = 411661
    classtable.theEmperorsCapacitorBuff = 393039
    classtable.PowerStrikesBuff = 129914
    classtable.CallToDominanceBuff = 403380
    classtable.FuryofXuenStacksBuff = 396168
    classtable.TransferthePowerBuff = 195321
    classtable.JadefireBrandDamageDeBuff = 395414
    classtable.XuentheWhiteTiger = classtable.InvokeXuentheWhiteTiger

    --if (MaxDps:FindSpell(classtable.AutoAttack) and CheckSpellCosts(classtable.AutoAttack, 'AutoAttack')) and cooldown[classtable.AutoAttack].ready then
    --    return classtable.AutoAttack
    --end
    --if (MaxDps:FindSpell(classtable.Roll) and CheckSpellCosts(classtable.Roll, 'Roll')) and (movement.distance >5) and cooldown[classtable.Roll].ready then
    --    return classtable.Roll
    --end
    --if (MaxDps:FindSpell(classtable.ChiTorpedo) and CheckSpellCosts(classtable.ChiTorpedo, 'ChiTorpedo')) and (movement.distance >5) and cooldown[classtable.ChiTorpedo].ready then
    --    return classtable.ChiTorpedo
    --end
    --if (MaxDps:FindSpell(classtable.FlyingSerpentKick) and CheckSpellCosts(classtable.FlyingSerpentKick, 'FlyingSerpentKick')) and (movement.distance >5) and cooldown[classtable.FlyingSerpentKick].ready then
    --    return classtable.FlyingSerpentKick
    --end
    --if (MaxDps:FindSpell(classtable.SpearHandStrike) and CheckSpellCosts(classtable.SpearHandStrike, 'SpearHandStrike')) and (target.debuff.casting.up) and cooldown[classtable.SpearHandStrike].ready then
    --    return classtable.SpearHandStrike
    --end
    hold_xuen = not talents[classtable.InvokeXuentheWhiteTiger] or cooldown[classtable.InvokeXuentheWhiteTiger].duration >ttd
    hold_tp_rsk = not (debuff[classtable.SkyreachExhaustionDeBuff].duration <1) and cooldown[classtable.RisingSunKick].remains <1 and ( (MaxDps.tier and MaxDps.tier[30].count >= 2) or targets <5 )
    hold_tp_bdb = not (debuff[classtable.SkyreachExhaustionDeBuff].duration <1) and cooldown[classtable.BonedustBrew].remains <1 and targets == 1
    --if (MaxDps:FindSpell(classtable.Potion) and CheckSpellCosts(classtable.Potion, 'Potion')) and (buff[classtable.SerenityBuff].up or buff[classtable.StormEarthandFireBuff].up and ( UnitExists('pet') and UnitName('pet')  == 'xuen' ) or ttd <= 30) and cooldown[classtable.Potion].ready then
    --    return classtable.Potion
    --end
    if (timeInCombat <4 and Chi <5 and not ( UnitExists('pet') and UnitName('pet')  == 'xuen' ) and not talents[classtable.Serenity]) then
        local openerCheck = Windwalker:opener()
        if openerCheck then
            return Windwalker:opener()
        end
    end
    --local trinketsCheck = Windwalker:trinkets()
    --if trinketsCheck then
    --    return trinketsCheck
    --end
    if (MaxDps:FindSpell(classtable.JadefireStomp) and CheckSpellCosts(classtable.JadefireStomp, 'JadefireStomp') and talents[classtable.JadefireStomp]) and (IsComboStrike(classtable.JadefireStomp) and talents[classtable.JadefireHarmony] and debuff[classtable.JadefireBrandDamageDeBuff].remains <1) and cooldown[classtable.JadefireStomp].ready then
        return classtable.JadefireStomp
    end
    if (MaxDps:FindSpell(classtable.BonedustBrew) and CheckSpellCosts(classtable.BonedustBrew, 'BonedustBrew') and talents[classtable.BonedustBrew]) and (targets == 1 and not debuff[classtable.SkyreachExhaustionDeBuff].up and ( ( UnitExists('pet') and UnitName('pet')  == 'xuen' ) or cooldown[classtable.XuentheWhiteTiger].remains )) and cooldown[classtable.BonedustBrew].ready then
        return classtable.BonedustBrew
    end
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (not buff[classtable.SerenityBuff].up and Energy >50 and buff[classtable.TeachingsoftheMonasteryBuff].count <3 and IsComboStrike(classtable.TigerPalm) and ChiMax - Chi >= ( 2 + buff[classtable.PowerStrikesBuff].duration ) and ( not talents[classtable.InvokeXuentheWhiteTiger] and not talents[classtable.Serenity] or ( ( not talents[classtable.Skyreach] and not talents[classtable.Skytouch] ) or timeInCombat >5 or ( UnitExists('pet') and UnitName('pet')  == 'xuen' ) ) ) and not hold_tp_rsk and ( targets >1 or not talents[classtable.BonedustBrew] or talents[classtable.BonedustBrew] and targets == 1 and cooldown[classtable.BonedustBrew].remains )) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (MaxDps:FindSpell(classtable.TigerPalm) and CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (not buff[classtable.SerenityBuff].up and buff[classtable.TeachingsoftheMonasteryBuff].count <3 and IsComboStrike(classtable.TigerPalm) and ChiMax - Chi >= ( 2 + buff[classtable.PowerStrikesBuff].duration ) and ( not talents[classtable.InvokeXuentheWhiteTiger] and not talents[classtable.Serenity] or ( ( not talents[classtable.Skyreach] and not talents[classtable.Skytouch] ) or timeInCombat >5 or ( UnitExists('pet') and UnitName('pet')  == 'xuen' ) ) ) and not hold_tp_rsk and ( targets >1 or not talents[classtable.BonedustBrew] or talents[classtable.BonedustBrew] and targets == 1 and cooldown[classtable.BonedustBrew].remains )) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (MaxDps:FindSpell(classtable.ChiBurst) and CheckSpellCosts(classtable.ChiBurst, 'ChiBurst') and talents[classtable.ChiBurst]) and (talents[classtable.JadefireStomp] and cooldown[classtable.JadefireStomp].remains and ( ChiMax - Chi >= 1 and targets == 1 or ChiMax - Chi >= 2 and targets >= 2 ) and not talents[classtable.JadefireHarmony]) and cooldown[classtable.ChiBurst].ready then
        return classtable.ChiBurst
    end
    if (not talents[classtable.Serenity]) then
        local cd_sefCheck = Windwalker:cd_sef()
        if cd_sefCheck then
            return Windwalker:cd_sef()
        end
    end
    if (talents[classtable.Serenity]) then
        local cd_serenityCheck = Windwalker:cd_serenity()
        if cd_serenityCheck then
            return Windwalker:cd_serenity()
        end
    end
    if (buff[classtable.SerenityBuff].up and ( ( MaxDps:Bloodlust() and ( buff[classtable.InvokersDelightBuff].up or buff[classtable.PowerInfusionBuff].up ) ) or buff[classtable.InvokersDelightBuff].up and buff[classtable.PowerInfusionBuff].up ) and targets >4) then
        local serenity_aoelustCheck = Windwalker:serenity_aoelust()
        if serenity_aoelustCheck then
            return Windwalker:serenity_aoelust()
        end
    end
    if (buff[classtable.SerenityBuff].up and ( ( MaxDps:Bloodlust() and ( buff[classtable.InvokersDelightBuff].up or buff[classtable.PowerInfusionBuff].up ) ) or buff[classtable.InvokersDelightBuff].up and buff[classtable.PowerInfusionBuff].up ) and targets <4) then
        local serenity_lustCheck = Windwalker:serenity_lust()
        if serenity_lustCheck then
            return Windwalker:serenity_lust()
        end
    end
    if (buff[classtable.SerenityBuff].up and targets >4) then
        local serenity_aoeCheck = Windwalker:serenity_aoe()
        if serenity_aoeCheck then
            return Windwalker:serenity_aoe()
        end
    end
    if (buff[classtable.SerenityBuff].up and targets == 4) then
        local serenity_4tCheck = Windwalker:serenity_4t()
        if serenity_4tCheck then
            return Windwalker:serenity_4t()
        end
    end
    if (buff[classtable.SerenityBuff].up and targets == 3) then
        local serenity_3tCheck = Windwalker:serenity_3t()
        if serenity_3tCheck then
            return Windwalker:serenity_3t()
        end
    end
    if (buff[classtable.SerenityBuff].up and targets == 2) then
        local serenity_2tCheck = Windwalker:serenity_2t()
        if serenity_2tCheck then
            return Windwalker:serenity_2t()
        end
    end
    if (buff[classtable.SerenityBuff].up and targets == 1) then
        local serenity_stCheck = Windwalker:serenity_st()
        if serenity_stCheck then
            return Windwalker:serenity_st()
        end
    end
    if (targets >4) then
        local default_aoeCheck = Windwalker:default_aoe()
        if default_aoeCheck then
            return Windwalker:default_aoe()
        end
    end
    if (targets == 4) then
        local default_4tCheck = Windwalker:default_4t()
        if default_4tCheck then
            return Windwalker:default_4t()
        end
    end
    if (targets == 3) then
        local default_3tCheck = Windwalker:default_3t()
        if default_3tCheck then
            return Windwalker:default_3t()
        end
    end
    if (targets == 2) then
        local default_2tCheck = Windwalker:default_2t()
        if default_2tCheck then
            return Windwalker:default_2t()
        end
    end
    if (targets == 1) then
        local default_stCheck = Windwalker:default_st()
        if default_stCheck then
            return Windwalker:default_st()
        end
    end
    if (MaxDps:FindSpell(classtable.SummonWhiteTigerStatue) and CheckSpellCosts(classtable.SummonWhiteTigerStatue, 'SummonWhiteTigerStatue')) and cooldown[classtable.SummonWhiteTigerStatue].ready then
        return classtable.SummonWhiteTigerStatue
    end
    local fallthruCheck = Windwalker:fallthru()
    if fallthruCheck then
        return fallthruCheck
    end
    if (not buff[classtable.BonedustBrewBuff].up and talents[classtable.BonedustBrew] and cooldown[classtable.BonedustBrew].remains <= 2 and ( ttd >60 and ( cooldown[classtable.StormEarthandFire].charges >0 or cooldown[classtable.StormEarthandFire].remains >10 ) and ( ( UnitExists('pet') and UnitName('pet')  == 'xuen' ) or cooldown[classtable.InvokeXuentheWhiteTiger].remains >10 or hold_xuen ) or ( ( ( UnitExists('pet') and UnitName('pet')  == 'xuen' ) or cooldown[classtable.InvokeXuentheWhiteTiger].remains >13 ) and ( cooldown[classtable.StormEarthandFire].charges >0 or cooldown[classtable.StormEarthandFire].remains >13 or buff[classtable.StormEarthandFireBuff].up ) ) )) then
        local bdb_setupCheck = Windwalker:bdb_setup()
        if bdb_setupCheck then
            return Windwalker:bdb_setup()
        end
    end

end
