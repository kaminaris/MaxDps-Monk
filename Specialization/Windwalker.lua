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

local has_external_pi

local function CheckSpellCosts(spell,spellstring)
    if not IsSpellKnown(spell) then return false end
    if not C_Spell.IsSpellUsable(spell) then return false end
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
    if (CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (( ttd >14 and boss or ttd >22 ) and not cooldown[classtable.InvokeXuentheWhiteTiger].ready==false and ( Chi <5 and not talents[classtable.OrderedElements] or Chi <3 ) and ( IsComboStrike(classtable.TigerPalm) or not talents[classtable.HitCombo] )) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (CheckSpellCosts(classtable.InvokeXuentheWhiteTiger, 'InvokeXuentheWhiteTiger')) and (cooldown[classtable.StormEarthandFire].ready and ( ttd >14 and boss or ttd >22 ) and ( targets >2 or debuff[classtable.AcclamationDeBuff].up ) and ( Chi >2 and talents[classtable.OrderedElements] or Chi >5 or Chi >3 and Energy <50 or Energy <50 and targets == 1 ) or boss and ttd <30) and cooldown[classtable.InvokeXuentheWhiteTiger].ready then
        MaxDps:GlowCooldown(classtable.InvokeXuentheWhiteTiger, cooldown[classtable.InvokeXuentheWhiteTiger].ready)
    end
    if (CheckSpellCosts(classtable.StormEarthandFire, 'StormEarthandFire')) and (( ttd >14 and boss or ttd >22 ) and ( targets >2 or cooldown[classtable.RisingSunKick].ready==false or not talents[classtable.OrderedElements] ) and ( ( buff[classtable.InvokersDelightBuff].up and not MaxDps:Bloodlust() or MaxDps:Bloodlust() and cooldown[classtable.StormEarthandFire].fullRecharge <1 ) or cooldown[classtable.StormEarthandFire].fullRecharge <cooldown[classtable.InvokeXuentheWhiteTiger].remains and not MaxDps:Bloodlust() and ( targets >1 or cooldown[classtable.StrikeoftheWindlord].remains <2 and ( talents[classtable.FlurryStrikes] or buff[classtable.HeartoftheJadeSerpentBuff].up ) ) and ( Chi >3 or Chi >1 and talents[classtable.OrderedElements] ) or cooldown[classtable.StormEarthandFire].fullRecharge <10 and ( Chi >3 or Chi >1 and talents[classtable.OrderedElements] ) ) or boss and ttd <30 or CheckPrevSpell(classtable.InvokeXuentheWhiteTiger)) and cooldown[classtable.StormEarthandFire].ready then
        MaxDps:GlowCooldown(classtable.StormEarthandFire, cooldown[classtable.StormEarthandFire].ready)
    end
    if (CheckSpellCosts(classtable.TouchofKarma, 'TouchofKarma')) and cooldown[classtable.TouchofKarma].ready then
        MaxDps:GlowCooldown(classtable.TouchofKarma, cooldown[classtable.TouchofKarma].ready)
    end
end
function Windwalker:aoe_opener()
    if (CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (Chi <6) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
end
function Windwalker:normal_opener()
    if (CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (Chi <6 and IsComboStrike(classtable.TigerPalm)) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
end
function Windwalker:default_aoe()
    if (CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (( Energy >55 and talents[classtable.InnerPeace] or Energy >60 and not talents[classtable.InnerPeace] ) and IsComboStrike(classtable.TigerPalm) and ChiMax - Chi >= 2 and buff[classtable.TeachingsoftheMonasteryBuff].count <buff[classtable.TeachingsoftheMonasteryBuff].maxStacks and ( talents[classtable.EnergyBurst] and not buff[classtable.BokProcBuff].up ) and not buff[classtable.OrderedElementsBuff].up and ( not (MaxDps.tier and MaxDps.tier[30].count >= 2) or (MaxDps.tier and MaxDps.tier[30].count >= 2) and buff[classtable.DanceofChijiBuff].up and not buff[classtable.BlackoutReinforcementBuff].up and talents[classtable.EnergyBurst] ) or ( talents[classtable.EnergyBurst] and not buff[classtable.BokProcBuff].up ) and not buff[classtable.OrderedElementsBuff].up and not cooldown[classtable.FistsofFury].ready==false and Chi <3 or ( CheckPrevSpell(classtable.StrikeoftheWindlord) or cooldown[classtable.StrikeoftheWindlord].ready==false ) and cooldown[classtable.CelestialConduit].remains <2 and buff[classtable.OrderedElementsBuff].up and Chi <5 and IsComboStrike(classtable.TigerPalm)) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (CheckSpellCosts(classtable.TouchofDeath, 'TouchofDeath')) and cooldown[classtable.TouchofDeath].ready then
        return classtable.TouchofDeath
    end
    if (CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (buff[classtable.DanceofChijiBuff].count == 2 and IsComboStrike(classtable.SpinningCraneKick)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.ChiEnergyBuff].count >29 and cooldown[classtable.FistsofFury].remains <5) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (CheckSpellCosts(classtable.CelestialConduit, 'CelestialConduit')) and (buff[classtable.StormEarthandFireBuff].up and cooldown[classtable.StrikeoftheWindlord].ready==false and ( talents[classtable.XuensBond] or not talents[classtable.XuensBond] and buff[classtable.InvokersDelightBuff].up ) or boss and ttd <15) and cooldown[classtable.CelestialConduit].ready then
        return classtable.CelestialConduit
    end
    if (CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (not talents[classtable.XuensBattlegear] and not cooldown[classtable.WhirlingDragonPunch].ready==false and cooldown[classtable.FistsofFury].remains >1 and ( not talents[classtable.RevolvingWhirl] or talents[classtable.RevolvingWhirl] and buff[classtable.DanceofChijiBuff].count <2 and targets >2 )) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (CheckSpellCosts(classtable.WhirlingDragonPunch, 'WhirlingDragonPunch')) and (not talents[classtable.RevolvingWhirl] or talents[classtable.RevolvingWhirl] and buff[classtable.DanceofChijiBuff].count <2 and targets >2) and cooldown[classtable.WhirlingDragonPunch].ready then
        return classtable.WhirlingDragonPunch
    end
    if (CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and buff[classtable.BokProcBuff].up and Chi <2 and talents[classtable.EnergyBurst] and Energy <55) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (timeInCombat >5 and ( cooldown[classtable.InvokeXuentheWhiteTiger].remains >15 or talents[classtable.FlurryStrikes] )) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.TeachingsoftheMonasteryBuff].count == 8 and talents[classtable.ShadowboxingTreads]) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (CheckSpellCosts(classtable.CracklingJadeLightning, 'CracklingJadeLightning')) and (buff[classtable.TheEmperorsCapacitorBuff].count >19 and IsComboStrike(classtable.CracklingJadeLightning) and talents[classtable.PoweroftheThunderKing]) and cooldown[classtable.CracklingJadeLightning].ready then
        return classtable.CracklingJadeLightning
    end
    if (CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and EnergyTimeToMax <= gcd * 3 and talents[classtable.FlurryStrikes] and buff[classtable.WisdomoftheWallFlurryBuff].up and Chi <6) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (IsComboStrike(classtable.SpinningCraneKick) and Chi >5) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and buff[classtable.ChiEnergyBuff].count >29 and cooldown[classtable.FistsofFury].remains <5) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.PressurePointBuff].up and cooldown[classtable.FistsofFury].remains >2) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and (targets==5)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.OrderedElementsBuff].up and talents[classtable.CraneVortex] and targets >2 and (targets==5)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and EnergyTimeToMax <= gcd * 3 and talents[classtable.FlurryStrikes] and buff[classtable.OrderedElementsBuff].up) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and ChiDeficit >= 2 and ( not buff[classtable.OrderedElementsBuff].up or EnergyTimeToMax <= gcd * 3 )) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (CheckSpellCosts(classtable.JadefireStomp, 'JadefireStomp')) and (talents[classtable.SingularlyFocusedJade] or talents[classtable.JadefireHarmony]) and cooldown[classtable.JadefireStomp].ready then
        return classtable.JadefireStomp
    end
    if (CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.OrderedElementsBuff].up and talents[classtable.CraneVortex] and targets >2 and Chi >4 and (targets==5)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and cooldown[classtable.FistsofFury].ready==false and ( buff[classtable.TeachingsoftheMonasteryBuff].count >3 or buff[classtable.OrderedElementsBuff].up ) and ( talents[classtable.ShadowboxingTreads] or buff[classtable.BokProcBuff].up )) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (IsComboStrike(classtable.SpinningCraneKick) and ( Chi >3 or Energy >55 )) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and ( buff[classtable.OrderedElementsBuff].up or buff[classtable.BokProcBuff].up and ChiDeficit >= 1 and talents[classtable.EnergyBurst] ) and cooldown[classtable.FistsofFury].remains) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and cooldown[classtable.FistsofFury].ready==false and ( Chi >2 or Energy >60 or buff[classtable.BokProcBuff].up )) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (CheckSpellCosts(classtable.JadefireStomp, 'JadefireStomp')) and cooldown[classtable.JadefireStomp].ready then
        return classtable.JadefireStomp
    end
    if (CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and buff[classtable.OrderedElementsBuff].up and ChiDeficit >= 1) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (CheckSpellCosts(classtable.ChiBurst, 'ChiBurst')) and (not buff[classtable.OrderedElementsBuff].up) and cooldown[classtable.ChiBurst].ready then
        return classtable.ChiBurst
    end
    if (CheckSpellCosts(classtable.ChiBurst, 'ChiBurst')) and cooldown[classtable.ChiBurst].ready then
        return classtable.ChiBurst
    end
    if (CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.OrderedElementsBuff].up and talents[classtable.HitCombo] and (targets==5)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.OrderedElementsBuff].up and not talents[classtable.HitCombo] and cooldown[classtable.FistsofFury].remains) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (CheckPrevSpell(classtable.TigerPalm) and Chi <3 and not cooldown[classtable.FistsofFury].remains) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
end
function Windwalker:default_cleave()
    if (CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.PressurePointBuff].up and targets <4 and cooldown[classtable.FistsofFury].remains >4) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].count == 2 and targets >3) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (( Energy >55 and talents[classtable.InnerPeace] or Energy >60 and not talents[classtable.InnerPeace] ) and IsComboStrike(classtable.TigerPalm) and ChiMax - Chi >= 2 and buff[classtable.TeachingsoftheMonasteryBuff].count <buff[classtable.TeachingsoftheMonasteryBuff].maxStacks and ( talents[classtable.EnergyBurst] and not buff[classtable.BokProcBuff].up or not talents[classtable.EnergyBurst] ) and not buff[classtable.OrderedElementsBuff].up or ( talents[classtable.EnergyBurst] and not buff[classtable.BokProcBuff].up or not talents[classtable.EnergyBurst] ) and not buff[classtable.OrderedElementsBuff].up and not cooldown[classtable.FistsofFury].ready==false and Chi <3 or ( CheckPrevSpell(classtable.StrikeoftheWindlord) or cooldown[classtable.StrikeoftheWindlord].ready==false ) and cooldown[classtable.CelestialConduit].remains <2 and buff[classtable.OrderedElementsBuff].up and Chi <5 and IsComboStrike(classtable.TigerPalm) or ( not buff[classtable.HeartoftheJadeSerpentCdrBuff].up or not buff[classtable.HeartoftheJadeSerpentCdrCelestialBuff].up ) and IsComboStrike(classtable.TigerPalm) and ChiDeficit >= 2 and not buff[classtable.OrderedElementsBuff].up) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (CheckSpellCosts(classtable.TouchofDeath, 'TouchofDeath')) and cooldown[classtable.TouchofDeath].ready then
        return classtable.TouchofDeath
    end
    if (CheckSpellCosts(classtable.CelestialConduit, 'CelestialConduit')) and (buff[classtable.StormEarthandFireBuff].up and cooldown[classtable.StrikeoftheWindlord].ready==false and ( talents[classtable.XuensBond] or not talents[classtable.XuensBond] and buff[classtable.InvokersDelightBuff].up ) or boss and ttd <15) and cooldown[classtable.CelestialConduit].ready then
        return classtable.CelestialConduit
    end
    if (CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (not ( UnitExists('pet') and UnitName('pet')  == 'xuen' ) and CheckPrevSpell(classtable.TigerPalm) and timeInCombat <5 or buff[classtable.HeartoftheJadeSerpentCdrCelestialBuff].up and buff[classtable.PressurePointBuff].up) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and (buff[classtable.HeartoftheJadeSerpentCdrCelestialBuff].up) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (CheckSpellCosts(classtable.WhirlingDragonPunch, 'WhirlingDragonPunch')) and (buff[classtable.HeartoftheJadeSerpentCdrCelestialBuff].up) and cooldown[classtable.WhirlingDragonPunch].ready then
        return classtable.WhirlingDragonPunch
    end
    if (CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (talents[classtable.GaleForce] and buff[classtable.InvokersDelightBuff].up and ( MaxDps:Bloodlust() or cooldown[classtable.CelestialConduit].ready==false and not buff[classtable.HeartoftheJadeSerpentCdrCelestialBuff].up )) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and (buff[classtable.PowerInfusionBuff].up and MaxDps:Bloodlust()) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.PowerInfusionBuff].up and MaxDps:Bloodlust() and targets <3) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.TeachingsoftheMonasteryBuff].count == 8 and ( targets <3 or talents[classtable.ShadowboxingTreads] )) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (CheckSpellCosts(classtable.WhirlingDragonPunch, 'WhirlingDragonPunch')) and (not talents[classtable.RevolvingWhirl] or talents[classtable.RevolvingWhirl] and buff[classtable.DanceofChijiBuff].count <2 and targets >2 or targets <3) and cooldown[classtable.WhirlingDragonPunch].ready then
        return classtable.WhirlingDragonPunch
    end
    if (CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (timeInCombat >5 and ( cooldown[classtable.InvokeXuentheWhiteTiger].remains >15 or talents[classtable.FlurryStrikes] )) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (CheckSpellCosts(classtable.CracklingJadeLightning, 'CracklingJadeLightning')) and (buff[classtable.TheEmperorsCapacitorBuff].count >19 and IsComboStrike(classtable.CracklingJadeLightning) and talents[classtable.PoweroftheThunderKing]) and cooldown[classtable.CracklingJadeLightning].ready then
        return classtable.CracklingJadeLightning
    end
    if (CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and (MaxDps.tier and MaxDps.tier[30].count >= 2) and not buff[classtable.BlackoutReinforcementBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].count == 2) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and EnergyTimeToMax <= gcd * 3 and talents[classtable.FlurryStrikes] and targets <5 and buff[classtable.WisdomoftheWallFlurryBuff].up and targets <4) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and (buff[classtable.OrderedElementsBuff].remains >timeShift or not buff[classtable.OrderedElementsBuff].up or buff[classtable.OrderedElementsBuff].remains <= gcd or targets >2) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and EnergyTimeToMax <= gcd * 3 and talents[classtable.FlurryStrikes] and targets <5 and buff[classtable.WisdomoftheWallFlurryBuff].up) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and buff[classtable.ChiEnergyBuff].count >29) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (Chi >4 and ( targets <3 or talents[classtable.GloryoftheDawn] ) or Chi >2 and Energy >50 and ( targets <3 or talents[classtable.GloryoftheDawn] ) or cooldown[classtable.FistsofFury].remains >2 and ( targets <3 or talents[classtable.GloryoftheDawn] )) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.TeachingsoftheMonasteryBuff].count == 4 and not talents[classtable.KnowledgeoftheBrokenTemple] and talents[classtable.ShadowboxingTreads] and targets <3) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.OrderedElementsBuff].up and talents[classtable.CraneVortex] and targets >2) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and EnergyTimeToMax <= gcd * 3 and talents[classtable.FlurryStrikes] and targets <5) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and ChiDeficit >= 2 and ( not buff[classtable.OrderedElementsBuff].up or EnergyTimeToMax <= gcd * 3 )) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and cooldown[classtable.FistsofFury].ready==false and buff[classtable.TeachingsoftheMonasteryBuff].count >3 and cooldown[classtable.RisingSunKick].remains) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (CheckSpellCosts(classtable.JadefireStomp, 'JadefireStomp')) and (talents[classtable.SingularlyFocusedJade] or talents[classtable.JadefireHarmony]) and cooldown[classtable.JadefireStomp].ready then
        return classtable.JadefireStomp
    end
    if (CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and cooldown[classtable.FistsofFury].ready==false and ( buff[classtable.TeachingsoftheMonasteryBuff].count >3 or buff[classtable.OrderedElementsBuff].up ) and ( talents[classtable.ShadowboxingTreads] or buff[classtable.BokProcBuff].up or buff[classtable.OrderedElementsBuff].up )) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.OrderedElementsBuff].up and talents[classtable.CraneVortex] and targets >2 and Chi >4) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (CheckSpellCosts(classtable.ChiBurst, 'ChiBurst')) and (not buff[classtable.OrderedElementsBuff].up) and cooldown[classtable.ChiBurst].ready then
        return classtable.ChiBurst
    end
    if (CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and ( buff[classtable.OrderedElementsBuff].up or buff[classtable.BokProcBuff].up and ChiDeficit >= 1 and talents[classtable.EnergyBurst] ) and cooldown[classtable.FistsofFury].remains) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and cooldown[classtable.FistsofFury].ready==false and ( Chi >2 or Energy >60 or buff[classtable.BokProcBuff].up )) and cooldown[classtable.BlackoutKick].ready then
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
    if (CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.OrderedElementsBuff].up and not talents[classtable.HitCombo] and cooldown[classtable.FistsofFury].remains) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (CheckPrevSpell(classtable.TigerPalm) and Chi <3 and not cooldown[classtable.FistsofFury].remains) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
end
function Windwalker:default_st()
    if (CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.PressurePointBuff].up or buff[classtable.OrderedElementsBuff].remains <= gcd * 3 and buff[classtable.StormEarthandFireBuff].up) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (( Energy >55 and talents[classtable.InnerPeace] or Energy >60 and not talents[classtable.InnerPeace] ) and IsComboStrike(classtable.TigerPalm) and ChiMax - Chi >= 2 and buff[classtable.TeachingsoftheMonasteryBuff].count <buff[classtable.TeachingsoftheMonasteryBuff].maxStacks and ( talents[classtable.EnergyBurst] and not buff[classtable.BokProcBuff].up or not talents[classtable.EnergyBurst] ) and not buff[classtable.OrderedElementsBuff].up or ( talents[classtable.EnergyBurst] and not buff[classtable.BokProcBuff].up or not talents[classtable.EnergyBurst] ) and not buff[classtable.OrderedElementsBuff].up and not cooldown[classtable.FistsofFury].ready==false and Chi <3 or ( CheckPrevSpell(classtable.StrikeoftheWindlord) or cooldown[classtable.StrikeoftheWindlord].ready==false ) and cooldown[classtable.CelestialConduit].remains <2 and buff[classtable.OrderedElementsBuff].up and Chi <5 and IsComboStrike(classtable.TigerPalm) or ( not buff[classtable.HeartoftheJadeSerpentCdrBuff].up or not buff[classtable.HeartoftheJadeSerpentCdrCelestialBuff].up ) and IsComboStrike(classtable.TigerPalm) and ChiDeficit >= 2 and not buff[classtable.OrderedElementsBuff].up) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (CheckSpellCosts(classtable.TouchofDeath, 'TouchofDeath')) and cooldown[classtable.TouchofDeath].ready then
        return classtable.TouchofDeath
    end
    if (CheckSpellCosts(classtable.CelestialConduit, 'CelestialConduit')) and (buff[classtable.StormEarthandFireBuff].up and buff[classtable.OrderedElementsBuff].up and cooldown[classtable.StrikeoftheWindlord].ready==false and ( talents[classtable.XuensBond] or not talents[classtable.XuensBond] and buff[classtable.InvokersDelightBuff].up ) or boss and ttd <15) and cooldown[classtable.CelestialConduit].ready then
        return classtable.CelestialConduit
    end
    if (CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (not ( UnitExists('pet') and UnitName('pet')  == 'xuen' ) and CheckPrevSpell(classtable.TigerPalm) and timeInCombat <5 or buff[classtable.StormEarthandFireBuff].up and talents[classtable.OrderedElements]) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (talents[classtable.GaleForce] and buff[classtable.InvokersDelightBuff].up and ( MaxDps:Bloodlust() or cooldown[classtable.CelestialConduit].ready==false and not buff[classtable.HeartoftheJadeSerpentCdrCelestialBuff].up )) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (buff[classtable.PowerInfusionBuff].up and MaxDps:Bloodlust()) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and (buff[classtable.PowerInfusionBuff].up and MaxDps:Bloodlust()) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.TeachingsoftheMonasteryBuff].count >3 and buff[classtable.OrderedElementsBuff].up and cooldown[classtable.RisingSunKick].remains >1 and cooldown[classtable.FistsofFury].remains >2) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (buff[classtable.DanceofChijiBuff].count == 2 and IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.PowerInfusionBuff].up and MaxDps:Bloodlust()) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (CheckSpellCosts(classtable.WhirlingDragonPunch, 'WhirlingDragonPunch')) and (buff[classtable.PowerInfusionBuff].up and MaxDps:Bloodlust()) and cooldown[classtable.WhirlingDragonPunch].ready then
        return classtable.WhirlingDragonPunch
    end
    if (CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and EnergyTimeToMax <= gcd * 3 and talents[classtable.FlurryStrikes] and buff[classtable.PowerInfusionBuff].up and MaxDps:Bloodlust()) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.TeachingsoftheMonasteryBuff].count >4 and cooldown[classtable.RisingSunKick].remains >1 and cooldown[classtable.FistsofFury].remains >2) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (CheckSpellCosts(classtable.WhirlingDragonPunch, 'WhirlingDragonPunch')) and (not buff[classtable.HeartoftheJadeSerpentCdrCelestialBuff].up and not buff[classtable.DanceofChijiBuff].up == 2 or buff[classtable.OrderedElementsBuff].up or talents[classtable.KnowledgeoftheBrokenTemple]) and cooldown[classtable.WhirlingDragonPunch].ready then
        return classtable.WhirlingDragonPunch
    end
    if (CheckSpellCosts(classtable.StrikeoftheWindlord, 'StrikeoftheWindlord')) and (timeInCombat >5 and ( cooldown[classtable.InvokeXuentheWhiteTiger].remains >15 or talents[classtable.FlurryStrikes] )) and cooldown[classtable.StrikeoftheWindlord].ready then
        return classtable.StrikeoftheWindlord
    end
    if (CheckSpellCosts(classtable.RisingSunKick, 'RisingSunKick')) and (Chi >4 or Chi >2 and Energy >50 or cooldown[classtable.FistsofFury].remains >2) and cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end
    if (CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and EnergyTimeToMax <= gcd * 3 and talents[classtable.FlurryStrikes] and buff[classtable.WisdomoftheWallFlurryBuff].up) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and ChiDeficit >= 2 and EnergyTimeToMax <= gcd * 3) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.TeachingsoftheMonasteryBuff].count >7 and talents[classtable.MemoryoftheMonastery] and not buff[classtable.MemoryoftheMonasteryBuff].up and cooldown[classtable.FistsofFury].remains) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (CheckSpellCosts(classtable.FistsofFury, 'FistsofFury')) and (buff[classtable.OrderedElementsBuff].remains >timeShift or not buff[classtable.OrderedElementsBuff].up or buff[classtable.OrderedElementsBuff].remains <= gcd) and cooldown[classtable.FistsofFury].ready then
        return classtable.FistsofFury
    end
    if (CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (( buff[classtable.DanceofChijiBuff].count == 2 or buff[classtable.DanceofChijiBuff].remains <2 and buff[classtable.DanceofChijiBuff].up ) and IsComboStrike(classtable.SpinningCraneKick) and not buff[classtable.OrderedElementsBuff].up) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (CheckSpellCosts(classtable.WhirlingDragonPunch, 'WhirlingDragonPunch')) and cooldown[classtable.WhirlingDragonPunch].ready then
        return classtable.WhirlingDragonPunch
    end
    if (CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.TeachingsoftheMonasteryBuff].count == 4 and not talents[classtable.KnowledgeoftheBrokenTemple] and cooldown[classtable.RisingSunKick].remains >1 and cooldown[classtable.FistsofFury].remains >2) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (buff[classtable.DanceofChijiBuff].count == 2 and IsComboStrike(classtable.SpinningCraneKick)) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and buff[classtable.OrderedElementsBuff].up and cooldown[classtable.RisingSunKick].remains >1 and cooldown[classtable.FistsofFury].remains >2) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and EnergyTimeToMax <= gcd * 3 and talents[classtable.FlurryStrikes]) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (CheckSpellCosts(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (IsComboStrike(classtable.SpinningCraneKick) and buff[classtable.DanceofChijiBuff].up and ( buff[classtable.OrderedElementsBuff].up or EnergyTimeToMax >= gcd * 3 and talents[classtable.SequencedStrikes] and talents[classtable.EnergyBurst] or not talents[classtable.SequencedStrikes] or not talents[classtable.EnergyBurst] or buff[classtable.DanceofChijiBuff].remains <= gcd * 3 )) and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end
    if (CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (IsComboStrike(classtable.TigerPalm) and EnergyTimeToMax <= gcd * 3 and talents[classtable.FlurryStrikes]) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
    if (CheckSpellCosts(classtable.JadefireStomp, 'JadefireStomp')) and (talents[classtable.SingularlyFocusedJade] or talents[classtable.JadefireHarmony]) and cooldown[classtable.JadefireStomp].ready then
        return classtable.JadefireStomp
    end
    if (CheckSpellCosts(classtable.ChiBurst, 'ChiBurst')) and (not buff[classtable.OrderedElementsBuff].up) and cooldown[classtable.ChiBurst].ready then
        return classtable.ChiBurst
    end
    if (CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and ( buff[classtable.OrderedElementsBuff].up or buff[classtable.BokProcBuff].up and ChiDeficit >= 1 and talents[classtable.EnergyBurst] ) and cooldown[classtable.FistsofFury].remains) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (CheckSpellCosts(classtable.CracklingJadeLightning, 'CracklingJadeLightning')) and (buff[classtable.TheEmperorsCapacitorBuff].count >19 and not buff[classtable.OrderedElementsBuff].up and IsComboStrike(classtable.CracklingJadeLightning)) and cooldown[classtable.CracklingJadeLightning].ready then
        return classtable.CracklingJadeLightning
    end
    if (CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (IsComboStrike(classtable.BlackoutKick) and cooldown[classtable.FistsofFury].ready==false and ( Chi >2 or Energy >60 or buff[classtable.BokProcBuff].up )) and cooldown[classtable.BlackoutKick].ready then
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
    if (CheckSpellCosts(classtable.BlackoutKick, 'BlackoutKick')) and (buff[classtable.OrderedElementsBuff].up and not talents[classtable.HitCombo] and cooldown[classtable.FistsofFury].remains) and cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end
    if (CheckSpellCosts(classtable.TigerPalm, 'TigerPalm')) and (CheckPrevSpell(classtable.TigerPalm) and Chi <3 and not cooldown[classtable.FistsofFury].remains) and cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end
end

function Windwalker:callaction()
    if (CheckSpellCosts(classtable.SpearHandStrike, 'SpearHandStrike')) and (UnitCastingInfo('target') and select(8,UnitCastingInfo('target')) == false) and cooldown[classtable.SpearHandStrike].ready then
        MaxDps:GlowCooldown(classtable.SpearHandStrike, ( select(8,UnitCastingInfo('target')) ~= nil and not select(8,UnitCastingInfo('target')) or select(7,UnitChannelInfo('target')) ~= nil and not select(7,UnitChannelInfo('target'))) )
    end
    has_external_pi = false
    local trinketsCheck = Windwalker:trinkets()
    if trinketsCheck then
        return trinketsCheck
    end
    if (timeInCombat <3 and targets >2) then
        local aoe_openerCheck = Windwalker:aoe_opener()
        if aoe_openerCheck then
            return Windwalker:aoe_opener()
        end
    end
    if (timeInCombat <4 and targets <3) then
        local normal_openerCheck = Windwalker:normal_opener()
        if normal_openerCheck then
            return Windwalker:normal_opener()
        end
    end
    if (talents[classtable.StormEarthandFire]) then
        local cooldownsCheck = Windwalker:cooldowns()
        if cooldownsCheck then
            return Windwalker:cooldowns()
        end
    end
    if (targets >= 5) then
        local default_aoeCheck = Windwalker:default_aoe()
        if default_aoeCheck then
            return Windwalker:default_aoe()
        end
    end
    if (targets >1 and ( timeInCombat >7 or not talents[classtable.CelestialConduit] ) and targets <5) then
        local default_cleaveCheck = Windwalker:default_cleave()
        if default_cleaveCheck then
            return Windwalker:default_cleave()
        end
    end
    if (targets <2) then
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
    classtable.HeartoftheJadeSerpentBuff = 0
    classtable.TeachingsoftheMonasteryBuff = 202090
    classtable.BokProcBuff = 116768
    classtable.OrderedElementsBuff = 0
    classtable.DanceofChijiBuff = 325202
    classtable.BlackoutReinforcementBuff = 424454
    classtable.ChiEnergyBuff = 393057
    classtable.StormEarthandFireBuff = 137639
    classtable.TheEmperorsCapacitorBuff = 0
    classtable.WisdomoftheWallFlurryBuff = 0
    classtable.PressurePointBuff = 393053
    classtable.HeartoftheJadeSerpentCdrBuff = 0
    classtable.HeartoftheJadeSerpentCdrCelestialBuff = 0
    classtable.PowerInfusionBuff = 10060
    classtable.MemoryoftheMonasteryBuff = 0

    local callactionCheck = Windwalker:callaction()
    if callactionCheck then
        return Windwalker:callaction()
    end
end
