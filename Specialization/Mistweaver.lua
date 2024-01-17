local _, addonTable = ...

--- @type MaxDps
if not MaxDps then return end

local MaxDps = MaxDps
local Monk = addonTable.Monk
local classtable

function Monk:Mistweaver()
    local fd = MaxDps.FrameData
    local covenantId = fd.covenant.covenantId
    local cooldown = fd.cooldown
    local buff = fd.buff
    local debuff = fd.debuff
    local talents = fd.talents
    local targets = MaxDps:SmartAoe()
    local gcd = fd.gcd
    local targetHp = UnitHealth('target')
    local health = UnitHealth('player')
    local healthMax = UnitHealthMax('player')
    local healthPercent = ( health / healthMax ) * 100
    classtable = MaxDps.SpellTable
    -- Essences
    MaxDps:GlowEssences();

    -- Cooldowns

    --talents

    if talents[classtable.ChiWave] then
        MaxDps:GlowCooldown(classtable.ChiWave, cooldown[classtable.ChiWave].ready)
    end

    if talents[classtable.ChiBurst] then
        MaxDps:GlowCooldown(classtable.ChiBurst, cooldown[classtable.ChiBurst].ready)
    end

    MaxDps:GlowCooldown(classtable.JadefireStomp, cooldown[classtable.JadefireStomp].ready)

	if targetHp < health  and cooldown[classtable.TouchofDeath].ready then
        return classtable.TouchofDeath
    end

    if cooldown[classtable.RisingSunKick].ready then
        return classtable.RisingSunKick
    end

    if cooldown[classtable.BlackoutKick].ready then
        return classtable.BlackoutKick
    end

    if targets > 1 and cooldown[classtable.SpinningCraneKick].ready then
        return classtable.SpinningCraneKick
    end

    if cooldown[classtable.TigerPalm].ready then
        return classtable.TigerPalm
    end

end