RegisterServerEvent('Characters:Server:Spawning', function()
  Middleware:TriggerEvent("Characters:Spawning", source)
end)

RegisterServerEvent('Ped:LeaveCreator', function()
  local plyr = Fetch:Source(source)
  if plyr ~= nil then
    local char = plyr:GetData("Character")
    if char ~= nil then
      if char:GetData("New") then
        print("We're no longer in the char creator")
        char:SetData("New", false)
        print(char:GetData("New"), 'our new status')
      end
    end
  end
end)
