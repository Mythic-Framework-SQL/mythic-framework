AddEventHandler("Core:Shared:Ready", function()
  local Roles = MySQL.query.await("SELECT * FROM `roles`", {})

  COMPONENTS.Config.Groups = {}
  for k, v in pairs(Roles) do
    v.Permission = json.decode(v.Permission)
    v.Queue = json.decode(v.Queue)
    COMPONENTS.Config.Groups[v.Abv] = v
  end

  COMPONENTS.Logger:Info("Core", string.format("Loaded %s User Groups", #Roles), {
    console = true,
  })
end)
