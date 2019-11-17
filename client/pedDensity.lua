local pedDensity = 0.8
local scenarioPedDensity = {0.0, 0.2}
local trafficDensity = 0.30
local parkedVehicleDensity = 0.40
local randomVehicleDensity = 0.40

--local pedDensity = 0.0
--local scenarioPedDensity = {0.0, 0.0}
--local trafficDensity = 0.0
--local parkedVehicleDensity = 0.0
--local randomVehicleDensity = 0.0

Citizen.CreateThread(function()
	while true do
		SetVehicleDensityMultiplierThisFrame(trafficDensity)
		SetPedDensityMultiplierThisFrame(pedDensity)
		SetRandomVehicleDensityMultiplierThisFrame(randomVehicleDensity)
		SetParkedVehicleDensityMultiplierThisFrame(parkedVehicleDensity)
	  SetScenarioPedDensityMultiplierThisFrame(0.0, 0.1)

		SetGarbageTrucks(0.40)
		SetRandomBoats(0.20)
		Citizen.Wait(0)
	end
end)

local clothingBlips = {}

local clothingPeds = {
    {model="s_f_y_shop_mid", voice="SHOPASSISTANT", x=73.883, y=-1392.551, z=29.376, heading=258.693},
    {model="s_f_y_shop_mid", voice="SHOPASSISTANT", x=-708.705, y=-152.150, z=37.415, heading=118.490},
    {model="s_f_y_shop_mid", voice="SHOPASSISTANT", x=-164.849, y=-302.719, z=39.733, heading=249.119},
    {model="s_f_y_shop_low", voice="SHOPASSISTANT", x=126.824, y=-224.512, z=54.558, heading=71.926},
    {model="s_f_y_shop_low", voice="SHOPASSISTANT", x=427.069, y=-806.280, z=29.491, heading=84.203},
    {model="s_f_y_shop_low", voice="SHOPASSISTANT", x=-822.872 , y=-1072.162, z=11.328, heading=203.007},
    {model="s_f_y_shop_low", voice="SHOPASSISTANT", x=-1193.691, y=-766.863, z=17.316, heading=216.273},
    {model="s_f_y_shop_mid", voice="SHOPASSISTANT", x=-1448.901, y=-238.138, z=49.814, heading=48.307},
    {model="s_f_y_shop_mid", voice="SHOPASSISTANT", x=5.809, y=6511.428, z=31.878 , heading=40.329},
    {model="s_f_y_shop_low", voice="SHOPASSISTANT", x=1695.387, y=4823.019, z=42.063, heading=96.539},
    {model="s_f_y_shop_low", voice="SHOPASSISTANT", x=613.015, y=2762.577, z=42.088, heading=277.766},
    {model="s_f_y_shop_low", voice="SHOPASSISTANT", x=1196.435, y=2711.634, z=38.223, heading=179.040},
    {model="s_f_y_shop_low", voice="SHOPASSISTANT", x=-3169.260, y=1043.606, z=20.863, heading=57.917},
    {model="s_f_y_shop_low", voice="SHOPASSISTANT", x=-1102.184, y=2711.799, z=19.108, heading=223.387},
    {model="s_f_y_shop_low", voice="SHOPASSISTANT", x=-0.381, y=6510.237, z=31.878, heading=310.662}
  }

  Citizen.CreateThread(function()
    
    for k,v in ipairs(clothingPeds) do
      RequestModel(GetHashKey(v.model))
      while not HasModelLoaded(GetHashKey(v.model)) do
        Wait(0)
      end

      local shopOwner = CreatePed(5, GetHashKey(v.model), v.x, v.y, v.z, v.heading, false, false)
      SetBlockingOfNonTemporaryEvents(shopOwner, true)
      SetAmbientVoiceName(shopOwner, v.voice)
      SetModelAsNoLongerNeeded(GetHashKey(v.model))
    end
  end)

  local coordinates = {}

local underPeds = {
-- Mission Row
-- Frontdesk
  { model="s_f_y_cop_01", voice="GENERIC_HI", scenario="WORLD_HUMAN_COP_IDLES", x=440.9932, y=-978.33416, z=30.68, a=135.000},
-- Armery
  { model="s_m_y_cop_01", voice="GENERIC_HOWS_IT_GOING", scenario="WORLD_HUMAN_COP_IDLES", x=454.2, y=-980.32222, z=30.68, a=100.000},
-- Briefing
  { model="s_m_y_cop_01", voice="GENERIC_HI", scenario="world_human_clipboard", x=437.09, y=-992.4137, z=30.68, a=270.000},
  { model="s_m_y_cop_01", voice="GENERIC_HOWS_IT_GOING", scenario="WORLD_HUMAN_COP_IDLES", x=439.8431, y=-991.4705, z=30.68, a=110.000},
  { model="s_m_y_cop_01", voice="GENERIC_HI", scenario="WORLD_HUMAN_COP_IDLES", x=439.5860, y=-993.0000, z=30.68, a=100.000},
  { model="s_f_y_cop_01", voice="GENERIC_HOWS_IT_GOING", scenario="WORLD_HUMAN_COP_IDLES", x=439.8854, y=-994.6676, z=30.68, a=70.000},
  -- Garage Door
  { model="s_m_y_cop_01", voice="GENERIC_HI", scenario="world_human_aa_coffee", x=449.4908, y=-987.5093, z=26.6742, a=220.000},
  -- Jail
  { model="s_m_y_cop_01", voice="GENERIC_HI", scenario="world_human_clipboard", x=459.6690, y=-989.7947, z=24.91, a=270.000},
  { model="s_m_y_dockwork_01", voice="GENERIC_HI", scenario="world_human_leaning", x=457.4000, y=-1001.5553, z=24.91, a=270.000},
}

Citizen.CreateThread(function()

    for k,v in ipairs(underPeds) do
        RequestModel(GetHashKey(v.model))
        while not HasModelLoaded(GetHashKey(v.model)) do
            Wait(0)
        end

        local shadyPed = CreatePed(4, GetHashKey(v.model), v.x, v.y, v.z, v.a, false, false)
        SetBlockingOfNonTemporaryEvents(shadyPed, true)
        SetAmbientVoiceName(shadyPed, v.voice)
        TaskStartScenarioInPlace(shadyPed, v.scenario, 0, 0)

        SetModelAsNoLongerNeeded(GetHashKey(v.model))
    end
end)

local coordinates = {}

local underPeds = {
  { model="ig_lestercrest", voice="DIA_SHOP", scenario="WORLD_HUMAN_STAND_IMPATIENT", x=1275.27, y=-1710.76, z=54.77, a=135.000},
  { model="A_M_M_Hillbilly_01", voice="DIA_SHOP", scenario="WORLD_HUMAN_SMOKING", x=1961.29, y=5185.05, z=47.96, a=265.000},
  { model="ig_old_man1a", voice="DIA_SHOP", scenario="WORLD_HUMAN_SMOKING", x=-16.6755, y=-2553.8818, z=5.1453, a=135.000},
  { model="IG_Cletus", voice="DIA_SHOP", scenario="WORLD_HUMAN_SMOKING", x=556.7692, y=-2716.5766, z=7.1122, a=135.000},
}

Citizen.CreateThread(function()

    for k,v in ipairs(underPeds) do
        RequestModel(GetHashKey(v.model))
        while not HasModelLoaded(GetHashKey(v.model)) do
            Wait(0)
        end

        local shadyPed = CreatePed(4, GetHashKey(v.model), v.x, v.y, v.z, v.a, false, false)
        SetBlockingOfNonTemporaryEvents(shadyPed, true)
        SetAmbientVoiceName(shadyPed, v.voice)
        TaskStartScenarioInPlace(shadyPed, v.scenario, 0, 0)

        SetModelAsNoLongerNeeded(GetHashKey(v.model))
    end
end)

local coordinates = {
    
}

local barberPeds = {
    {model= "s_f_m_fembarber", voice="S_F_M_FEMBARBER_BLACK_MINI_01", x=-817.349, y=-184.541, z=37.569, h=134.069},
    {model= "s_f_m_fembarber", voice="S_F_M_FEMBARBER_BLACK_MINI_01", x=134.749, y=-1708.106, z=29.292, h=146.281},
    {model= "s_f_m_fembarber", voice="S_F_M_FEMBARBER_BLACK_MINI_01", x=-1284.038, y=-1115.635, z=6.990, h=85.177},
    {model= "s_f_m_fembarber", voice="S_F_M_FEMBARBER_BLACK_MINI_01", x=1930.855, y=3728.141, z=32.844, h=220.243},
    {model= "a_m_y_stbla_02", voice="S_M_M_HAIRDRESSER_01_BLACK_MINI_01", x=1211.521, y=-470.704, z=66.208, h=79.543},
    {model= "a_m_y_stbla_02", voice="S_M_M_HAIRDRESSER_01_BLACK_MINI_01", x=-30.804, y=-151.648, z=57.077, h=349.238},
    {model= "a_m_y_stbla_02", voice="S_M_M_HAIRDRESSER_01_BLACK_MINI_01", x=-278.205, y=6230.279, z=31.696, h=49.216}
}

Citizen.CreateThread(function()
     
    
    for k,v in ipairs(barberPeds) do
        RequestModel(GetHashKey(v.model))
        while not HasModelLoaded(GetHashKey(v.model)) do
            Wait(0)
        end

        barber = CreatePed(4, GetHashKey(v.model), v.x, v.y, v.z, v.h, false, false)
        SetBlockingOfNonTemporaryEvents(barber, true)
        SetAmbientVoiceName(barber, v.voice)
        TaskStartScenarioInPlace(barber, "WORLD_HUMAN_STAND_IMPATIENT_UPRIGHT", 0, 0)

        SetModelAsNoLongerNeeded(GetHashKey(v.model))
    end
end)