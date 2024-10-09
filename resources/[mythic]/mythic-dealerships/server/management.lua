_managementData = {}

DEALERSHIPS.Management = {
  LoadData = function(self)
    local dealerShips = MySQL.query.await('SELECT * FROM dealer_data', {})
    local dealershipData = {}
    if dealerShips and #dealerShips > 0 then
      for k, v in ipairs(dealerShips) do
        if v.dealership then
          dealershipData[v.dealership] = v
        end
      end
    end

    for k, v in pairs(_dealerships) do --? Default Dealership Data, merge with database data
      if dealershipData[k] then
        _managementData[k] = dealershipData[k]
      else
        _managementData[k] = _defaultDealershipSalesData
      end
    end
    return true
  end,

  SetData = function(self, dealerId, key, val)
    local data = _managementData[dealerId]
    if data then
      local dealerData = table.copy(data)
      dealerData.dealership = nil
      dealerData._id = nil
      dealerData[key] = val


      local insertId = MySQL.insert.await(
        'INSERT INTO dealer_data (dealership, data) VALUES (@dealership, @data) ON DUPLICATE KEY UPDATE data = @data', {
          ['@dealership'] = dealerId,
          ['@data'] = json.encode(dealerData)
        })

      if insertId then
        _managementData[dealerId] = dealerData
        return _managementData[dealerId]
      end
      return false
    end
    return false
  end,

  SetMultipleData = function(self, dealerId, updatingData)
    local data = _managementData[dealerId]
    if data then
      local dealerData = table.copy(data)
      dealerData.dealership = nil
      dealerData._id = nil

      for k, v in pairs(updatingData) do
        dealerData[k] = v
      end

      local insertId = MySQL.insert.await(
        'INSERT INTO `dealer_data` (`dealership`, `data`) VALUES (@dealership, @data) ON DUPLICATE KEY UPDATE data = @data',
        {
          ['@dealership'] = dealerId,
          ['@data'] = json.encode(dealerData)
        })

      if insertId then
        _managementData[dealerId] = dealerData
        return _managementData[dealerId]
      end
      return false
    end
    return false
  end,

  GetAllData = function(self, dealerId)
    return _managementData[dealerId]
  end,
  GetData = function(self, dealerId, key)
    local data = _managementData[dealerId]
    if data then
      return data[key]
    end
    return false
  end,
}
