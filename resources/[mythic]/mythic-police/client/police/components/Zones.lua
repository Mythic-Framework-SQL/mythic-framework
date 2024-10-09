local policeDutyPoint = {
  {
    icon = "clipboard-check",
    text = "Go On Duty",
    event = "Police:Client:OnDuty",
    jobPerms = {
      {
        job = "police",
        reqOffDuty = true,
      },
    },
  },
  {
    icon = "clipboard",
    text = "Go Off Duty",
    event = "Police:Client:OffDuty",
    jobPerms = {
      {
        job = "police",
        reqDuty = true,
      },
    },
  },
}

local _pdStationPolys = {
  {
    points = {
      vector2(419.16091918945, -966.34405517578),
      vector2(419.2200012207, -1016.196105957),
      vector2(409.74496459961, -1016.0508422852),
      vector2(410.03247070312, -1033.0327148438),
      vector2(489.80380249023, -1026.6353759766),
      vector2(488.85284423828, -966.38427734375),
    },
    options = {
      name = "pdstation_missionrow",
      minZ = 25.36417388916,
      maxZ = 45.414678573608,
    },
    data = { pdstation = true },
  },
  {
    points = {
      vector2(411.00393676758, -1661.6872558594),
      vector2(424.06509399414, -1645.6456298828),
      vector2(424.70223999023, -1640.4389648438),
      vector2(423.83392333984, -1627.9958496094),
      vector2(360.71951293945, -1574.7712402344),
      vector2(339.02374267578, -1600.73046875),
    },
    options = {
      name = "pdstation_davis",
      minZ = 25.36417388916,
      maxZ = 45.414678573608,
    },
    data = { pdstation = true },
  },
  {
    points = {
      vector2(818.44097900391, -1249.2879638672),
      vector2(836.80029296875, -1252.8927001953),
      vector2(860.4052734375, -1278.6043701172),
      vector2(862.82849121094, -1296.5511474609),
      vector2(877.03753662109, -1297.9116210938),
      vector2(878.47839355469, -1328.7099609375),
      vector2(878.81671142578, -1361.5606689453),
      vector2(848.46789550781, -1417.4731445312),
      vector2(816.15045166016, -1417.8415527344),
    },
    options = {
      name = "pdstation_popular",
      minZ = 25.36417388916,
      maxZ = 45.414678573608,
    },
    data = { pdstation = true },
  },
  {
    points = {
      vector2(1889.2142333984, 3691.6762695312),
      vector2(1851.7814941406, 3668.3894042969),
      vector2(1830.3732910156, 3704.9562988281),
      vector2(1868.1072998047, 3727.1462402344),
    },
    options = {
      name = "pdstation_sandy",
      minZ = 29.36417388916,
      maxZ = 49.414678573608,
    },
    data = { pdstation = true },
  },
  {
    points = {
      vector2(-442.38430786133, 6062.9243164062),
      vector2(-416.13342285156, 6005.0458984375),
      vector2(-415.57186889648, 5998.3540039062),
      vector2(-439.16738891602, 5975.2041015625),
      vector2(-449.66729736328, 5985.3481445312),
      vector2(-472.04858398438, 5963.1728515625),
      vector2(-500.68542480469, 5991.81640625),
      vector2(-478.4963684082, 6014.41796875),
      vector2(-488.33645629883, 6024.4272460938),
      vector2(-460.89733886719, 6051.8681640625),
    },
    options = {
      name = "pdstation_paleto",
      minZ = 29.36417388916,
      maxZ = 49.414678573608,
    },
    data = { pdstation = true },
  },
  {
    points = {
      vector2(-127.90340423584, -1157.5145263672),
      vector2(-128.29985046387, -1186.4349365234),
      vector2(-249.06109619141, -1184.8615722656),
      vector2(-247.67953491211, -1157.8649902344),
    },
    options = {
      name = "pdstation_impound",
      heading = 0,
      --debugPoly=true,
      minZ = 22.04,
      maxZ = 34.04
    },
    data = { pdstation = true },
  },
}

local locker = {
  {
    icon = "user-lock",
    text = "Open Personal Locker",
    event = "Police:Client:OpenLocker",
    jobPerms = {
      {
        job = "police",
        reqDuty = false,
      },
    },
  },
}

function CreatePDZones()
  Targeting.Zones:AddBox("pd-clockinoff-mrpd", "siren-on", vector3(450.38, -984.09, 30.69), 0.8, 0.4, {
    heading = 0,
    minZ = 30.69,
    maxZ = 31.29
  }, policeDutyPoint, 1.0, true)

  Targeting.Zones:AddBox("pd-clockinoff-sandy", "siren-on", vector3(1833.55, 3678.69, 34.19), 1.0, 3.0, {
    heading = 30,
    --debugPoly=true,
    minZ = 33.79,
    maxZ = 35.59
  }, policeDutyPoint, 1.0, true)

  Targeting.Zones:AddBox("pd-clockinoff-pbpd", "siren-on", vector3(-447.18, 6013.36, 32.29), 0.8, 1.6, {
    heading = 45,
    minZ = 32.29,
    maxZ = 32.89,
  }, policeDutyPoint, 1.0, true)

  Targeting.Zones:AddBox("pd-clockinoff-davis", "siren-on", vector3(381.37, -1595.84, 30.05), 2.0, 1.0, {
    heading = 320,
    minZ = 29.85,
    maxZ = 31.05,
  }, policeDutyPoint, 1.0, true)

  Targeting.Zones:AddBox("pd-clockinoff-lamesa", "siren-on", vector3(837.23, -1289.2, 28.24), 0.8, 2.2, {
    heading = 0,
    --debugPoly=true,
    minZ = 27.24,
    maxZ = 29.04,
  }, policeDutyPoint, 1.0, true)

  Targeting.Zones:AddBox("pd-clockinoff-courthouse", "siren-on", vector3(-528.46, -189.44, 38.23), 1.0, 1.0, {
    heading = 30,
    --debugPoly=true,
    minZ = 37.63,
    maxZ = 39.23
  }, policeDutyPoint, 1.0, true)

  for k, v in ipairs(_pdStationPolys) do
    --print(v.options.name)
    Polyzone.Create:Poly(v.options.name, v.points, v.options, v.data)
  end


  Targeting.Zones:AddBox("prison-clockinoff", "clipboard", vector3(1838.94, 2578.14, 46.01), 2.0, 0.8, {
    heading = 305,
    --debugPoly=true,
    minZ = 45.81,
    maxZ = 46.61,
  }, {
    {
      icon = "clipboard-check",
      text = "Go On Duty",
      event = "Corrections:Client:OnDuty",
      jobPerms = {
        {
          job = "prison",
          reqOffDuty = true,
        },
      },
    },
    {
      icon = "clipboard",
      text = "Go Off Duty",
      event = "Corrections:Client:OffDuty",
      jobPerms = {
        {
          job = "prison",
          reqDuty = true,
        },
      },
    },
    {
      icon = "clipboard-check",
      text = "Go On Duty (Medical)",
      event = "EMS:Client:OnDuty",
      jobPerms = {
        {
          job = "ems",
          workplace = "prison",
          reqOffDuty = true,
        },
      },
    },
    {
      icon = "clipboard",
      text = "Go Off Duty (Medical)",
      event = "EMS:Client:OffDuty",
      jobPerms = {
        {
          job = "ems",
          workplace = "prison",
          reqDuty = true,
        },
      },
    },
  }, 1.0, true)


  Targeting.Zones:AddBox("mrpd-male-lockers-1", "siren-on", vector3(480.52, -1007.07, 30.69), 0.6, 5.3, {
    heading = 0,
    --debugPoly=true,
    minZ = 30.09,
    maxZ = 31.89
  }, locker, 2.0, true)

  Targeting.Zones:AddBox("mrpd-male-lockers-2", "siren-on", vector3(484.18, -1009.49, 30.69), 0.6, 5.3, {
    heading = 270,
    --debugPoly=true,
    minZ = 30.09,
    maxZ = 31.89
  }, locker, 2.0, true)

  Targeting.Zones:AddBox("mrpd-male-lockers-3", "siren-on", vector3(480.51, -1015.49, 30.69), 0.6, 5.3, {
    heading = 180,
    --debugPoly=true,
    minZ = 30.09,
    maxZ = 31.89
  }, locker, 2.0, true)

  Targeting.Zones:AddBox("mrpd-male-lockers-3", "siren-on", vector3(480.73, -1012.5, 30.69), 2.8, 1.7, {
    heading = 180,
    --debugPoly=true,
    minZ = 30.09,
    maxZ = 31.89
  }, locker, 2.0, true)

  -- Targeting.Zones:AddBox("police-shitty-locker", "siren-on", vector3(461.59, -1000.0, 30.69), 1.0, 3.8, {
  --   heading = 0,
  --   --debugPoly=true,
  --   minZ = 29.69,
  --   maxZ = 32.69,
  -- }, locker, 3.0, true)

  -- Targeting.Zones:AddBox("police-shitty-locker-2", "siren-on", vector3(1841.51, 3682.08, 34.19), 2.0, 1, {
  --   heading = 30,
  --   --debugPoly=true,
  --   minZ = 33.19,
  --   maxZ = 35.59
  -- }, locker, 3.0, true)

  -- Targeting.Zones:AddBox("police-shitty-locker-3", "siren-on", vector3(-436.32, 6009.79, 37.0), 0.2, 2.2, {
  --   heading = 45,
  --   --debugPoly=true,
  --   minZ = 36.3,
  --   maxZ = 38.1,
  -- }, locker, 3.0, true)

  -- Targeting.Zones:AddBox("police-shitty-locker-4", "siren-on", vector3(360.08, -1592.9, 25.45), 0.5, 2.8, {
  --   heading = 50,
  --   --debugPoly=true,
  --   minZ = 24.45,
  --   maxZ = 27.45,
  -- }, locker, 3.0, true)

  -- Targeting.Zones:AddBox("police-shitty-locker-5", "siren-on", vector3(844.8, -1286.55, 28.24), 2.0, 1.2, {
  --   heading = 0,
  --   --debugPoly=true,
  --   minZ = 27.24,
  --   maxZ = 29.84,
  -- }, locker, 3.0, true)

  --! Why is EMS using the police locker?
  Targeting.Zones:AddBox("ems-shitty-locker-2", "siren-on", vector3(-439.04, -309.88, 34.91), 0.8, 0.8, {
    heading = 20,
    --debugPoly=true,
    minZ = 33.71,
    maxZ = 36.11,
  }, {
    {
      icon = "user-lock",
      text = "Open Personal Locker",
      event = "Police:Client:OpenLocker",
      jobPerms = {
        {
          job = "ems",
          reqDuty = false,
        },
      },
    },
  }, 3.0, true)
end
