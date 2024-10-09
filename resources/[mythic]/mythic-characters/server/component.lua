AddEventHandler('Characters:Shared:DependencyUpdate', RetrieveComponents)
function RetrieveComponents()
  Middleware = exports['mythic-base']:FetchComponent('Middleware')

  Callbacks = exports['mythic-base']:FetchComponent('Callbacks')
  DataStore = exports['mythic-base']:FetchComponent('DataStore')
  Logger = exports['mythic-base']:FetchComponent('Logger')

  Fetch = exports['mythic-base']:FetchComponent('Fetch')
  Logger = exports['mythic-base']:FetchComponent('Logger')
  Chat = exports['mythic-base']:FetchComponent('Chat')
  GlobalConfig = exports['mythic-base']:FetchComponent('Config')
  Routing = exports['mythic-base']:FetchComponent('Routing')
  Sequence = exports['mythic-base']:FetchComponent('Sequence')
  Reputation = exports['mythic-base']:FetchComponent('Reputation')
  Apartment = exports['mythic-base']:FetchComponent('Apartment')
  Utils = exports['mythic-base']:FetchComponent('Utils')
  RegisterCommands()
  _spawnFuncs = {}
end

AddEventHandler('Core:Shared:Ready', function()
  exports['mythic-base']:RequestDependencies('Characters', {
    'Callbacks',

    'Middleware',
    'DataStore',
    'Logger',

    'Fetch',
    'Logger',
    'Chat',
    'Config',
    'Routing',
    'Sequence',
    'Reputation',
    'Apartment',
  }, function(error)
    if #error > 0 then return end -- Do something to handle if not all dependencies loaded
    RetrieveComponents()
    RegisterCallbacks()
    RegisterMiddleware()
    Startup()
  end)
end)

_tablesToDecode = {
  "Origin",
  "Apps",
  "Wardrobe",
  "Jobs",
  "Addiction",
  "PhoneSettings",
  "Crypto",
  "Licenses",
  "Alias",
  "PhonePermissions",
  "LaptopApps",
  "LaptopSettings",
  "LaptopPermissions",
  "Animations",
  "InventorySettings",
  "States",
  "MDTHistory",
  "MDTSuspension",
  "Qualifications",
  "LastClockOn",
  "Salary",
  "TimeClockedOn",
  "Reputations",
  "GangChain",
  "Jailed",
  "ICU",
  "Status",
  "Parole",
  "LSUNDGBan"
}
