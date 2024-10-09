local _ran = false

_properties = {}
_insideProperties = {}

function doPropertyThings(property)
  property.id = property.id
  property._id = property._id
  property.locked = property.locked or true

  if property.location then
    property.location = json.decode(property.location)
    for k, v in pairs(property.location) do
      if v then
        for k2, v2 in pairs(v) do
          property.location[k][k2] = property.location[k][k2] + 0.0
        end
      end
    end
  end

  if property.owner then
    property.owner = json.decode(property.owner)
  end

  if property.keys then
    property.keys = json.decode(property.keys)
  end

  if property.upgrades then
    property.upgrades = json.decode(property.upgrades)
  end

  if property.data then
    property.data = json.decode(property.data)
  end

  return property
end

function Startup()
  if _ran then
    return
  end

  local results = MySQL.query.await('SELECT * FROM properties')

  if not results then
    return
  end

  Logger:Trace("Properties", "Loaded ^2" .. #results .. "^7 Properties", { console = true })

  for k, v in ipairs(results) do
    local p = doPropertyThings(v)

    _properties[v._id] = p
  end

  _ran = true
end
