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

local Mana
local ManaMax
local ManaDeficit
local ManaPerc
local Chi
local ChiMax
local ChiDeficit

local Mistweaver = {}

function Mistweaver:precombat()
end

local function ClearCDs()
end

function Mistweaver:callaction()
    -- AoE logic
    if targets >= 3 then
        if (MaxDps:CheckSpellUsable(classtable.SpinningCraneKick, 'SpinningCraneKick')) and cooldown[classtable.SpinningCraneKick].ready then
            if not setSpell then setSpell = classtable.SpinningCraneKick end
        end
    end

    if (MaxDps:CheckSpellUsable(classtable.RisingSunKick, 'RisingSunKick')) and cooldown[classtable.RisingSunKick].ready then
        if not setSpell then setSpell = classtable.RisingSunKick end
    end

    if Chi >= 2 and (MaxDps:CheckSpellUsable(classtable.BlackoutKick, 'BlackoutKick')) and cooldown[classtable.BlackoutKick].ready then
        if not setSpell then setSpell = classtable.BlackoutKick end
    end

    if (MaxDps:CheckSpellUsable(classtable.TigerPalm, 'TigerPalm')) and cooldown[classtable.TigerPalm].ready then
        if not setSpell then setSpell = classtable.TigerPalm end
    end

    if (MaxDps:CheckSpellUsable(classtable.Jab, 'Jab')) and cooldown[classtable.Jab].ready then
        if not setSpell then setSpell = classtable.Jab end
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
    Chi = UnitPower('player', ChiPT)
    ChiMax = UnitPowerMax('player', ChiPT)
    ChiDeficit = ChiMax - Chi
    targetHP = UnitHealth('target')
    targetmaxHP = UnitHealthMax('target')
    targethealthPerc = (targetHP > 0 and targetmaxHP > 0 and (targetHP / targetmaxHP) * 100) or 100
    curentHP = UnitHealth('player')
    maxHP = UnitHealthMax('player')
    healthPerc = (curentHP / maxHP) * 100
    timeInCombat = MaxDps.combatTime or 0
    classtable = MaxDps.SpellTable
    SpellHaste = UnitSpellHaste('player')
    SpellCrit = GetCritChance()
    ManaPerc = (Mana / ManaMax) * 100

    setSpell = nil
    ClearCDs()

    Mistweaver:precombat()
    Mistweaver:callaction()

    if setSpell then return setSpell end
end