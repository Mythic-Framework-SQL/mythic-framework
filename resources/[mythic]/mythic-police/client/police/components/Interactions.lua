function RegisterInteractions()
  local _pdModels = GlobalState["PoliceCars"]
  Interaction:RegisterMenu("police", false, "siren-on", function(data)
    Interaction:ShowMenu({
      {
        icon = "siren-on",
        label = "13-A",
        action = function()
          Interaction:Hide()
          TriggerServerEvent("Police:Server:Panic", true)
        end,
        shouldShow = function()
          return LocalPlayer.state.isDead
        end,
      },
      {
        icon = "siren",
        label = "13-B",
        action = function()
          Interaction:Hide()
          TriggerServerEvent("Police:Server:Panic", false)
        end,
        shouldShow = function()
          return LocalPlayer.state.isDead
        end,
      },
    })
  end, function()
    return LocalPlayer.state.onDuty == "police" and LocalPlayer.state.isDead
  end)

  Interaction:RegisterMenu("police-raid-biz", "Search Inventory", "magnifying-glass", function(data)
    Interaction:Hide()
    Progress:ProgressWithTickEvent({
      name = 'pd_raid_biz',
      duration = 8000,
      label = "Searching",
      tickrate = 250,
      useWhileDead = false,
      canCancel = true,
      vehicle = false,
      controlDisables = {
        disableMovement = true,
        disableCarMovement = true,
        disableCombat = true,
      },
      animation = {
        animDict = "anim@gangops@facility@servers@bodysearch@",
        anim = "player_search",
        flags = 49,
      },
    }, function()
      if LocalPlayer.state.onDuty == "police" and not LocalPlayer.state.isDead and LocalPlayer.state._inInvPoly ~= nil then
        return
      end
      Progress:Cancel()
    end, function(cancelled)
      _doing = false
      if not cancelled then
        Callbacks:ServerCallback("Inventory:Raid", LocalPlayer.state._inInvPoly.inventory, function(owner) end)
      end
    end)
  end, function()
    return LocalPlayer.state.onDuty == "police"
        and not LocalPlayer.state.isDead
        and LocalPlayer.state._inInvPoly ~= nil
        and LocalPlayer.state._inInvPoly?.business ~= nil
  end)

  Interaction:RegisterMenu("pd-locked-veh", "Secured Compartment", "shield-keyhole", function(data)
    Interaction:Hide()
    Progress:Progress({
      name = "pd_rack_prog",
      duration = 5000,
      label = "Unlocking Compartment",
      useWhileDead = false,
      canCancel = true,
      animation = false,
    }, function(status)
      if not status then
        Callbacks:ServerCallback("Police:AccessRifleRack")
      end
    end)
  end, function()
    local v = GetVehiclePedIsIn(LocalPlayer.state.ped, false)
    return LocalPlayer.state.onDuty == "police" and not LocalPlayer.state.isDead and v ~= 0 and
        _pdModels[GetEntityModel(v)] and Vehicles:HasAccess(v)
  end)

  Interaction:RegisterMenu("police-utils", "Police Utilities", "tablet-rugged", function(data)
    Interaction:ShowMenu({
      {
        icon = "lock-keyhole-open",
        label = "Slimjim Vehicle",
        action = function()
          Interaction:Hide()
          TriggerServerEvent("Police:Server:Slimjim")
        end,
        shoudlShow = function()
          local target = Targeting:GetEntityPlayerIsLookingAt()
          return target
              and target.entity
              and DoesEntityExist(target.entity)
              and IsEntityAVehicle(target.entity)
              and #(GetEntityCoords(target.entity) - GetEntityCoords(LocalPlayer.state.ped)) <= 2.0
        end,
      },
      {
        icon = "tablet-screen-button",
        label = "MDT",
        action = function()
          Interaction:Hide()
          TriggerEvent("MDT:Client:Toggle")
        end,
        shoudlShow = function()
          return LocalPlayer.state.onDuty == "police"
        end,
      },
      {
        icon = "camera-security",
        label = "Toggle Body Cam",
        action = function()
          Interaction:Hide()
          TriggerEvent("MDT:Client:ToggleBodyCam")
        end,
        shoudlShow = function()
          return LocalPlayer.state.onDuty == "police"
        end,
      },
    })
  end, function()
    return LocalPlayer.state.onDuty == "police"
  end)

  Interaction:RegisterMenu("pd-breach", "Breach", "bomb", function(data)
    local prop = Properties:Get(data.propertyId)
    Interaction:ShowMenu({
      {
        icon = "house",
        label = "Breach Property",
        action = function()
          Interaction:Hide()
          Callbacks:ServerCallback("Police:Breach", {
            type = "property",
            property = data.propertyId,
          }, function(s)
            if s then

            end
          end)
        end,
        shouldShow = function()
          return prop ~= nil and prop.sold
        end,
      },
      {
        icon = "window-frame-open",
        label = "Breach Apartment",
        action = function()
          Interaction:Hide()
          Input:Show("Breaching", "Unit Number (Owner State ID)", {
            {
              id = "unit",
              type = "number",
              options = {},
            },
          }, "Police:Client:DoApartmentBreach", data.id)
        end,
        shouldShow = function()
          return Apartment:GetNearApartment()
        end,
      },
    })
  end, function()
    if LocalPlayer.state.onDuty and LocalPlayer.state.onDuty == "police" then
      return Properties:GetNearHouse() or Apartment:GetNearApartment()
    else
      return nil
    end
  end)

  Interaction:RegisterMenu("pd-breach-robbery", "Breach House Robbery", "bomb", function(data)
    local bruh = GlobalState["Robbery:InProgress"]
    for k, v in ipairs(bruh) do
      local fuck = GlobalState[string.format("Robbery:InProgress:%s", v)]
      if fuck then
        local dist = #(vector3(LocalPlayer.state.myPos.x, LocalPlayer.state.myPos.y, LocalPlayer.state.myPos.z) - vector3(fuck.x, fuck.y, fuck.z))
        if dist <= 3.0 then
          Callbacks:ServerCallback("Police:Breach", {
            type = "robbery",
            property = v,
          })

          return
        end
      end
    end
    Interaction:Hide()
  end, function()
    if LocalPlayer.state.onDuty and LocalPlayer.state.onDuty == "police" then
      local bruh = GlobalState["Robbery:InProgress"]
      for k, v in ipairs(bruh) do
        local fuck = GlobalState[string.format("Robbery:InProgress:%s", v)]
        if fuck then
          local dist = #(vector3(LocalPlayer.state.myPos.x, LocalPlayer.state.myPos.y, LocalPlayer.state.myPos.z) - vector3(fuck.x, fuck.y, fuck.z))
          return dist <= 3.0
        end
      end
    end
    return false
  end)
end
