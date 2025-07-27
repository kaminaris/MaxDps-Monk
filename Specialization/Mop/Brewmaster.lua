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
local ChiPT = Enum.PowerType.Chi
local EnergyPT = Enum.PowerType.Energy

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

local stance

local Brewmaster = {}

function Brewmaster:precombat()
    if (MaxDps:CheckSpellUsable(classtable.BlackOxStatue, 'BlackOxStatue')) and cooldown[classtable.BlackOxStatue].ready and not UnitAffectingCombat('player') then
        if not setSpell then setSpell = classtable.BlackOxStatue end
    end
end

function Brewmaster:single()
    -- Single Target Priority
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and (not buff[classtable.ShuffleBuff].up) and cooldown[classtable.BlackoutKick].ready then
        if not setSpell then setSpell = classtable.BlackoutKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.ExpelHarm, 'ExpelHarm')) and buff[classtable.DesperateMeasuresBuff].up and cooldown[classtable.ExpelHarm].ready then
        if not setSpell then setSpell = classtable.ExpelHarm end
    end
    if (MaxDps:CheckSpellUsable(classtable.TouchOfDeath, 'TouchOfDeath')) and (targetHP <= curentHP) and cooldown[classtable.TouchOfDeath].ready then
        if not setSpell then setSpell = classtable.TouchOfDeath end
    end
    if (MaxDps:CheckSpellUsable(classtable.KegSmash, 'KegSmash')) and (Chi < 4) and cooldown[classtable.KegSmash].ready then
        if not setSpell then setSpell = classtable.KegSmash end
    end
    if (MaxDps:CheckSpellUsable(classtable.ExpelHarm, 'ExpelHarm')) and (curentHP < maxHP and Chi < 5) and cooldown[classtable.ExpelHarm].ready then
        if not setSpell then setSpell = classtable.ExpelHarm end
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and cooldown[classtable.BlackoutKick].ready then
        if not setSpell then setSpell = classtable.BlackoutKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.ChiWave, 'ChiWave')) and cooldown[classtable.ChiWave].ready then
        if not setSpell then setSpell = classtable.ChiWave end
    end
    if (MaxDps:CheckSpellUsable(classtable.Jab, 'Jab')) and (Energy >= 70 and Chi < 5) and cooldown[classtable.Jab].ready then
        if not setSpell then setSpell = classtable.Jab end
    end
end

function Brewmaster:aoe()
    -- AoE Priority
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and (not buff[classtable.ShuffleBuff].up) and cooldown[classtable.BlackoutKick].ready then
        if not setSpell then setSpell = classtable.BlackoutKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.ExpelHarm, 'ExpelHarm')) and buff[classtable.DesperateMeasuresBuff].up and cooldown[classtable.ExpelHarm].ready then
        if not setSpell then setSpell = classtable.ExpelHarm end
    end
    if (MaxDps:CheckSpellUsable(classtable.TouchOfDeath, 'TouchOfDeath')) and (targetHP <= curentHP) and cooldown[classtable.TouchOfDeath].ready then
        if not setSpell then setSpell = classtable.TouchOfDeath end
    end
    if (MaxDps:CheckSpellUsable(classtable.KegSmash, 'KegSmash')) and (Chi < 4) and cooldown[classtable.KegSmash].ready then
        if not setSpell then setSpell = classtable.KegSmash end
    end
    if (MaxDps:CheckSpellUsable(classtable.ExpelHarm, 'ExpelHarm')) and (curentHP < maxHP and Chi < 5) and cooldown[classtable.ExpelHarm].ready then
        if not setSpell then setSpell = classtable.ExpelHarm end
    end
    if (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and cooldown[classtable.BlackoutKick].ready then
        if not setSpell then setSpell = classtable.BlackoutKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.SpinningCraneKick, 'SpinningCraneKick')) and (Energy >= 70 and targets >= 3 and Chi < 5) and cooldown[classtable.SpinningCraneKick].ready then
        if not setSpell then setSpell = classtable.SpinningCraneKick end
    end
    if (MaxDps:CheckSpellUsable(classtable.ChiWave, 'ChiWave')) and cooldown[classtable.ChiWave].ready then
        if not setSpell then setSpell = classtable.ChiWave end
    end
    if (MaxDps:CheckSpellUsable(classtable.Jab, 'Jab')) and (Energy >= 70 and targets <= 2 and Chi < 5) and cooldown[classtable.Jab].ready then
        if not setSpell then setSpell = classtable.Jab end
    end
    if (MaxDps:CheckSpellUsable(classtable.BreathOfFire, 'BreathOfFire')) and (Chi >= 2 and buff[classtable.ShuffleBuff].up) and cooldown[classtable.BreathOfFire].ready then
        if not setSpell then setSpell = classtable.BreathOfFire end
    end
end

function Brewmaster:callaction()
    if (MaxDps:CheckSpellUsable(classtable.StanceoftheSturdyOx, 'StanceoftheSturdyOx')) and (stance ~= 23) and cooldown[classtable.StanceoftheSturdyOx].ready then
        if not setSpell then setSpell = classtable.StanceoftheSturdyOx end
    end
    --if (MaxDps:CheckSpellUsable(classtable.StanceoftheSturdyOx, 'StanceoftheSturdyOx')) and (not buff[classtable.StanceoftheSturdyOxBuff].up) and cooldown[classtable.StanceoftheSturdyOx].ready then
    --    if not setSpell then setSpell = classtable.StanceoftheSturdyOx end
    --end
    if targets > 1 then
        Brewmaster:aoe()
    end
    Brewmaster:single()
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
    Chi = UnitPower('player', ChiPT)
    ChiMax = UnitPowerMax('player', ChiPT)
    ChiDeficit = ChiMax - Chi
    Energy = UnitPower('player', EnergyPT)
    EnergyMax = UnitPowerMax('player', EnergyPT)
    EnergyDeficit = EnergyMax - Energy
    EnergyRegen = GetPowerRegenForPowerType(Enum.PowerType.Energy)
    EnergyTimeToMax = EnergyDeficit / EnergyRegen
    targetHP = UnitHealth('target')
    targetmaxHP = UnitHealthMax('target')
    targethealthPerc = (targetHP / targetmaxHP) * 100
    curentHP = UnitHealth('player')
    maxHP = UnitHealthMax('player')
    stance = GetShapeshiftFormID()

    classtable = MaxDps.SpellTable

    classtable.BlackoutKick = 100784
    classtable.ExpelHarm = 115072
    classtable.TouchOfDeath = 115080
    classtable.BlackOxStatue = 115315
    classtable.ElusiveBrew = 115308
    classtable.KegSmash = 121253
    classtable.SpinningCraneKick = 101546
    classtable.ChiWave = 115098
    classtable.Jab = 100780
    classtable.BreathOfFire = 115181
    classtable.ShuffleBuff = 115307
    classtable.DesperateMeasuresBuff = 126119
    classtable.StanceoftheSturdyOxBuff = 126119

    setSpell = nil
    Brewmaster:precombat()
    Brewmaster:callaction()
    if setSpell then return setSpell end
end