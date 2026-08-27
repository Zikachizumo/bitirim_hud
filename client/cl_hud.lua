--[[
    bitirim_hud / client
    Qbox (qbx_core) + ox_lib. Veriyi toplar, DEĞİŞTİĞİNDE NUI'ye yollar.
    FPS dostu: her tick sadece okur; NUI mesajı yalnızca bir grup değiştiyse gider.
]]

local qbx = exports.qbx_core

-- Son gönderilen değerler (change-detection)
local last = { status = {}, money = {}, info = {}, street = {}, vehicle = {} }

-- ------------------------------------------------------------------ helpers
local function round(v) return math.floor((v or 0) + 0.5) end
local function send(action, data) SendNUIMessage({ action = action, data = data }) end

-- İki düz tablonun alanları aynı mı?
local function same(a, b)
    for k, v in pairs(a) do if b[k] ~= v then return false end end
    for k, v in pairs(b) do if a[k] ~= v then return false end end
    return true
end

local function getPlayerData()
    local ok, pd = pcall(function() return qbx:GetPlayerData() end)
    if ok and type(pd) == 'table' then return pd end
    return nil
end

-- ------------------------------------------------------------------ elektrik
-- Elektrikli araçların benzin deposu yok: handling'deki fPetrolTankVolume 0.
-- Model listesi tutmaya gerek yok, kural genel. (Ölçüm: Khamelion -> depo 0.0,
-- native fuel 0.0, ox_fuel statebag'i nil.)
local fuelTypeCache = {}

-- Motoru olmayan araçlar: yakıt da şarj da göstermeyiz. Bisikletlerin benzin
-- deposu yok, o yüzden depo hacmi kuralına takılıp "elektrikli" görünüyorlardı.
local NO_FUEL_CLASSES = { [13] = true }   -- 13 = Cycles (bisikletler)

--- 'none' | 'electric' | 'petrol'
local function getFuelType(veh)
    local cached = fuelTypeCache[veh]
    if cached ~= nil then return cached end

    local result
    if NO_FUEL_CLASSES[GetVehicleClass(veh)] then
        result = 'none'
    elseif (GetVehicleHandlingFloat(veh, 'CHandlingData', 'fPetrolTankVolume') or 0.0) <= 0.0 then
        result = 'electric'
    else
        result = 'petrol'
    end

    fuelTypeCache[veh] = result
    return result
end

-- Araç yok olunca önbelleği bırak, entity id'leri geri dönüştürülüyor.
AddEventHandler('entityRemoved', function(entity)
    fuelTypeCache[entity] = nil
end)

-- ------------------------------------------------------------------ fuel
local function getPetrolFuel(veh)
    local sb = Entity(veh).state.fuel
    if sb ~= nil then return sb + 0.0 end
    for _, res in ipairs(Config.FuelResources) do
        if res ~= 'ox_fuel' and GetResourceState(res) == 'started' then
            local ok, val = pcall(function() return exports[res]:GetFuel(veh) end)
            if ok and val then return val + 0.0 end
        end
    end
    return GetVehicleFuelLevel(veh) + 0.0
end

local function getFuel(veh, ftype)
    -- Elektrikli: ox_fuel bu araçları takip etmiyor, native de 0 döner.
    -- bitirim_vehicles şarjı statebag'e yazıyor; henüz yazmadıysa (araç ilk
    -- kez görülüyor) config'teki başlangıç değeri gösterilir.
    if ftype == 'electric' then
        -- Kendi anahtarımız — 'fuel' değil. ox_fuel elektrikli araçlarda
        -- 'fuel'i 100'e geri çekiyor ve tüketimi eziyordu.
        local sb = Entity(veh).state[Config.ElectricStateKey]
        if sb ~= nil then return sb + 0.0 end
        return Config.ElectricCharge + 0.0
    end

    return getPetrolFuel(veh)
end

-- Hız sabitleme: statebag'den oku (kendi cruise scriptin set edebilir)
local function getCruise()
    return LocalPlayer.state[Config.CruiseStateKey] == true
end
exports('SetCruise', function(v) LocalPlayer.state:set(Config.CruiseStateKey, v == true, true) end)

-- ------------------------------------------------------------------ STATUS loop
CreateThread(function()
    while true do
        local ped = cache.ped
        local pd  = getPlayerData()
        local meta = (pd and pd.metadata) or {}

        -- Can / zırh / yemek / su
        if Config.Show.status then
            local st = {
                health = round(((GetEntityHealth(ped) - 100) / 100) * 100), -- 100..200 -> 0..100
                armor  = round(GetPedArmour(ped)),
                hunger = round(meta.hunger or 100),
                thirst = round(meta.thirst or 100),
            }
            if st.health < 0 then st.health = 0 end
            if not same(st, last.status) then last.status = st; send('status', st) end
        end

        -- Para
        if Config.Show.money then
            local money = (pd and pd.money) or {}
            local m = { cash = round(money.cash or 0), bank = round(money.bank or 0) }
            if not same(m, last.money) then last.money = m; send('money', m) end
        end

        -- Bilgi: ID + aktif oyuncu + saat
        if Config.Show.info then
            local info = {
                id      = LocalPlayer.state.bitirimId or '—',
                players = GlobalState.bitirimPlayers or 0,
                -- Saat bilerek burada YOK. #timeVal'i client/clock.lua besliyor
                -- (VPS sistem saati). Buradan oyun saatini de gönderirsek iki
                -- kaynak aynı alana yazar ve saat zıplar.
            }
            if not same(info, last.info) then last.info = info; send('info', info) end
        end

        -- Cadde ismi
        if Config.Show.street then
            local p = GetEntityCoords(ped)
            local s = GetStreetNameFromHashKey(GetStreetNameAtCoord(p.x, p.y, p.z))
            local street = { name = s ~= '' and s or '—' }
            if not same(street, last.street) then last.street = street; send('street', street) end
        end

        Wait(Config.StatusTick)
    end
end)

-- ------------------------------------------------------------------ VEHICLE loop
CreateThread(function()
    while true do
        local veh  = cache.vehicle
        local wait = Config.VehicleTick

        if Config.Show.vehicle and veh and cache.seat == -1 then
            local mps   = GetEntitySpeed(veh)
            local speed = Config.SpeedUnit == 'mph' and (mps * 2.236936) or (mps * 3.6)
            local ftype = getFuelType(veh)

            local vd = {
                visible  = true,
                speed    = round(speed),
                unit     = Config.SpeedUnit,
                -- Kemer OYUNCUDA tutuluyor, araçta değil. Araç statebag'i
                -- kullanıldığında önceki sürücünün kemeri yeni binene ait
                -- görünüyor, yolcu ile sürücü de birbirini eziyordu.
                seatbelt = (LocalPlayer.state.seatbelt == true),
                engineOn = GetIsVehicleEngineRunning(veh) == 1 or GetIsVehicleEngineRunning(veh) == true,
                locked   = GetVehicleDoorLockStatus(veh) == 2,
                cruise   = getCruise(),
                fuel     = ftype ~= 'none' and round(getFuel(veh, ftype)) or 0,
                fuelType = ftype,
                health   = round((GetVehicleEngineHealth(veh) / 1000) * 100),
            }
            if vd.health < 0 then vd.health = 0 end
            if vd.health > 100 then vd.health = 100 end
            if not same(vd, last.vehicle) then last.vehicle = vd; send('vehicle', vd) end
        else
            if last.vehicle.visible ~= false then
                last.vehicle = { visible = false }
                send('vehicle', { visible = false })
                wait = Config.StatusTick
            end
        end

        Wait(wait)
    end
end)

-- ------------------------------------------------------------------ HOTKEYS
-- Araç butonlarının altında gösterilen tuşlar. bitirim_vehicles yolluyor;
-- o resource yoksa hiçbir şey gelmez ve tuşlar gizli kalır.
-- Oyuncu tuşunu değiştirirse bitirim_vehicles güncelini tekrar gönderir.
AddEventHandler('bitirim_hud:hotkeys:set', function(keys)
    if type(keys) ~= 'table' then return end
    send('hotkeys', keys)
end)

-- ------------------------------------------------------------------ init
CreateThread(function()
    Wait(500)
    send('config', { show = Config.Vehicle, unit = Config.SpeedUnit,
                     fuelLow = Config.FuelLowAt, engLow = Config.EngineLowAt,
                     groups = Config.Show })

    -- Tuşları iste — HUD, bitirim_vehicles'tan sonra başlamış olabilir.
    TriggerEvent('bitirim_hud:hotkeys:request')
end)

-- Varsayılan GTA HUD parçalarını gizle (para + araç adı + bölge adı). Kendi verimiz NUI'de.
if Config.HideDefaultCash or Config.HideVehicleName or Config.HideAreaNames then
    CreateThread(function()
        while true do
            if Config.HideDefaultCash then
                HideHudComponentThisFrame(3)  -- HUD_CASH
                HideHudComponentThisFrame(4)  -- HUD_MP_CASH
            end
            if Config.HideVehicleName then
                HideHudComponentThisFrame(6)  -- HUD_VEHICLE_NAME
                HideHudComponentThisFrame(8)  -- HUD_VEHICLE_CLASS
            end
            if Config.HideAreaNames then
                HideHudComponentThisFrame(7)  -- HUD_AREA_NAME (bölge/mahalle)
            end
            Wait(0)
        end
    end)
end

-- GTA can/zırh çubuklarını gizle — minimap boyutuna dokunmaz (bigmap yenilemesi YOK)
if Config.HideDefaultHealthArmor then
    CreateThread(function()
        local mm = RequestScaleformMovie('minimap')
        while not HasScaleformMovieLoaded(mm) do Wait(0); mm = RequestScaleformMovie('minimap') end
        while true do
            BeginScaleformMovieMethod(mm, 'SETUP_HEALTH_ARMOUR')
            ScaleformMovieMethodAddParamInt(3)  -- 3 = can+zırh gizli
            EndScaleformMovieMethod()
            Wait(0)
        end
    end)
end

-- Bitirim: let other resources (e.g. bitirim_spawn) hide the entire HUD.
-- Reuses the existing .hidden utility class on the #hud wrapper.
AddEventHandler('bitirim_hud:client:setVisible', function(visible)
    send('visible', { visible = visible ~= false })
end)

-- ------------------------------------------------------------------ bitirim_cinematic entegrasyonu
-- Artık hepsini birden değil, /cinesettings'te seçilen HUD gruplarına
-- göre BÖLÜM BÖLÜM gizliyoruz/gösteriyoruz. bitirim_cinematic kurulu
-- değilse bu event'ler hiç tetiklenmez, zararsız (fxmanifest'e
-- dependency olarak eklemiyoruz — opsiyonel entegrasyon).
local BH_GROUP_MAP = {
    hud_status  = 'status',
    hud_money   = 'money',
    hud_info    = 'info',
    hud_street  = 'street',
    hud_vehicle = 'vehicle',
}

local function ApplyHudGroupState(hidden)
    if type(hidden) ~= 'table' then return end
    for cinematicId, localSection in pairs(BH_GROUP_MAP) do
        send('sectionVisible', { section = localSection, visible = hidden[cinematicId] ~= true })
    end
end

AddEventHandler('bitirim_cinematic:hudGroupsChanged', function(hidden)
    ApplyHudGroupState(hidden)
end)

AddEventHandler('bitirim_cinematic:started', function()
    local ok, hidden = pcall(function() return exports.bitirim_cinematic:GetHudGroupsHidden() end)
    if ok then ApplyHudGroupState(hidden) end
end)

AddEventHandler('bitirim_cinematic:stopped', function()
    -- Cinematic mod komple bitince kontrolü bitirim_hud'un kendi
    -- Config.Show ayarlarına geri bırak — hepsini görünür yap.
    for _, localSection in pairs(BH_GROUP_MAP) do
        send('sectionVisible', { section = localSection, visible = true })
    end
end)

-- bitirim_hud, sinematik mod ZATEN aktifken (yeniden) başlarsa
-- (örn. canlı restart), mevcut durumla senkronize ol.
CreateThread(function()
    Wait(500)
    if GetResourceState('bitirim_cinematic') ~= 'started' then return end
    local ok, isCinematic = pcall(function() return exports.bitirim_cinematic:IsCinematicMode() end)
    if ok and isCinematic then
        local ok2, hidden = pcall(function() return exports.bitirim_cinematic:GetHudGroupsHidden() end)
        if ok2 then ApplyHudGroupState(hidden) end
    end
end)
