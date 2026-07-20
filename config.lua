Config = {}

-- Hız birimi: 'kmh' | 'mph'
Config.SpeedUnit = 'kmh'

-- Güncelleme aralıkları (ms). Sadece veri değişince NUI güncellenir; bu sadece okuma sıklığı.
Config.StatusTick  = 300   -- can / zırh / açlık / susuzluk / para / bilgi / cadde
Config.VehicleTick = 90    -- araç paneli

-- Görünürlük
Config.Show = {
    status  = true,   -- can / zırh / yemek / su (minimap yanı)
    money   = true,   -- bank / cash (sağ üst)
    info    = true,   -- ID + oyuncu + saat (sağ üst)
    street  = true,   -- cadde ismi (minimap üstü)
    vehicle = true,   -- araç paneli (sağ alt)
}

-- Araç panelinde hangi ikonlar görünsün
Config.Vehicle = {
    seatbelt = true,  -- kemer (istemezsen false yap)
    engine   = true,  -- motor açık/kapalı
    lock     = true,  -- kapı kilidi
    cruise   = true,  -- hız sabitleme
    fuel     = true,  -- yakıt %
    health   = true,  -- motor sağlığı %
}

-- Eşikler (%)
Config.FuelLowAt   = 15    -- altı kırmızı
Config.EngineLowAt = 30    -- altı kırmızı

-- Varsayılan GTA para HUD'ını (yeşil cash/bank) gizle — kendi paramız NUI'de
Config.HideDefaultCash = true

-- Araca binince çıkan varsayılan araç adı/sınıfı yazısını gizle
Config.HideVehicleName = true

-- Bölge/mahalle adı (zone değişince çıkan yazı) gizle
Config.HideAreaNames = true

-- Minimap altındaki GTA can/zırh çubuklarını gizle (minimap boyutuna DOKUNMAZ)
Config.HideDefaultHealthArmor = true

-- Yakıt kaynakları (sırayla denenir; statebag/ox_fuel önceliklidir)
Config.FuelResources = { 'ox_fuel', 'cdn-fuel', 'ps-fuel', 'LegacyFuel' }

-- Elektrikli araçlarda (benzin deposu olmayan modeller) yakıt bidonu yerine
-- şimşek ikonu gösterilir. ox_fuel bu araçları takip etmediği için gerçek bir
-- şarj değeri yok — aşağıdaki sabit gösterilir.
-- İleride bir şarj sistemi Entity(veh).state.fuel'i doldurursa HUD otomatik
-- olarak onu kullanmaya başlar, burayı değiştirmene gerek kalmaz.
Config.ElectricCharge = 100

-- Hız sabitleme statebag anahtarı (kendi cruise scriptin bunu set edebilir,
-- ya da exports.bitirim_hud:SetCruise(true/false) çağırabilirsin)
Config.CruiseStateKey = 'cruise'
