DEALERSHIPS.Stock = {
  FetchAll = function(self)
    local p = promise.new()
    MySQL.Async.fetchAll('SELECT * FROM dealer_stock', {}, function(results)
      if results then
        for i, result in ipairs(results) do
          result.data = json.decode(result.data)
        end
        p:resolve(results)
      else
        p:resolve(false)
      end
    end)
    return Citizen.Await(p)
  end,
  FetchDealer = function(self, dealerId)
    local p = promise.new()
    MySQL.Async.fetchAll('SELECT * FROM dealer_stock WHERE dealership = @dealerId', {
      ['@dealerId'] = dealerId
    }, function(results)
      if results then
        for i, result in ipairs(results) do
          result.data = json.decode(result.data)
        end
        p:resolve(results)
      else
        p:resolve(false)
      end
    end)
    return Citizen.Await(p)
  end,
  FetchDealerVehicle = function(self, dealerId, vehModel)
    local results = MySQL.Sync.fetchAll('SELECT * FROM dealer_stock WHERE dealership = @dealerId AND vehicle = @vehModel', {
      ['@dealerId'] = dealerId,
      ['@vehModel'] = vehModel
    })

    if results and #results > 0 then
      results[1].data = json.decode(results[1].data)
      return results[1]
    else
      return false
    end
  end,
  HasVehicle = function(self, dealerId, vehModel)
    local vehicle = Dealerships.Stock:FetchDealerVehicle(dealerId, vehModel)
    if vehicle and vehicle.quantity > 0 then
      return vehicle.quantity
    else
      return false
    end
  end,
  Add = function(self, dealerId, vehModel, modelType, quantity, vehData)
    vehData = ValidateVehicleData(vehData)
    if _dealerships[dealerId] and vehModel and vehData and quantity > 0 then
      local isStocked = Dealerships.Stock:FetchDealerVehicle(dealerId, vehModel)
      local p = promise.new()
      if isStocked then -- The vehicle is already stocked
        MySQL.Async.execute(
          'UPDATE dealer_stock SET quantity = quantity + @quantity, data = @data, lastStocked = @lastStocked WHERE dealership = @dealership AND vehicle = @vehicle',
          {
            ['@quantity'] = quantity,
            ['@data'] = json.encode(vehData),
            ['@lastStocked'] = os.time(),
            ['@dealership'] = dealerId,
            ['@vehicle'] = vehModel
          }, function(affectedRows)
            if affectedRows > 0 then
              p:resolve({
                success = true,
                existed = true,
              })
            else
              p:resolve(false)
            end
          end)
      else
        MySQL.Async.execute(
          'INSERT INTO dealer_stock (dealership, vehicle, modelType, data, quantity, lastStocked) VALUES (@dealership, @vehicle, @modelType, @data, @quantity, @lastStocked)',
          {
            ['@dealership'] = dealerId,
            ['@vehicle'] = vehModel,
            ['@modelType'] = modelType,
            ['@data'] = json.encode(vehData),
            ['@quantity'] = quantity,
            ['@lastStocked'] = os.time()
          }, function(affectedRows)
            if affectedRows > 0 then
              p:resolve({
                success = true,
                existed = false,
              })
            else
              p:resolve(false)
            end
          end)
      end
      return Citizen.Await(p)
    end
    return false
  end,
  Increase = function(self, dealerId, vehModel, amount)
    if _dealerships[dealerId] and vehModel and amount > 0 then
      local isStocked = Dealerships.Stock:FetchDealerVehicle(dealerId, vehModel)
      if isStocked then -- The vehicle is already stocked
        MySQL.Async.execute(
          'UPDATE dealer_stock SET quantity = quantity + @amount, lastStocked = @lastStocked WHERE dealership = @dealerId AND vehicle = @vehModel', {
            ['@amount'] = amount,
            ['@lastStocked'] = os.time(),
            ['@dealerId'] = dealerId,
            ['@vehModel'] = vehModel
          }, function(affectedRows)
            if affectedRows > 0 then
              return { success = true }
            else
              return false
            end
          end)
      else
        return false
      end
    end
    return false
  end,
  Ensure = function(self, dealerId, vehModel, quantity, vehData)
    if _dealerships[dealerId] and vehModel then
      local isStocked = Dealerships.Stock:FetchDealerVehicle(dealerId, vehModel)
      if isStocked then
        local missingQuantity = quantity - isStocked.quantity
        if missingQuantity >= 1 then
          return Dealerships.Stock:Add(dealerId, vehModel, missingQuantity, vehData)
        end
      else
        return Dealerships.Stock:Add(dealerId, vehModel, quantity, vehData)
      end
    end
    return false
  end,
  Remove = function(self, dealerId, vehModel, quantity)
    if _dealerships[dealerId] and vehModel and quantity > 0 then
      local isStocked = Dealerships.Stock:FetchDealerVehicle(dealerId, vehModel)

      if isStocked and isStocked.quantity > 0 then
        local newQuantity = isStocked.quantity - quantity
        if newQuantity >= 0 then
          local updateDealerStock = MySQL.update.await(
          'UPDATE dealer_stock SET quantity = @newQuantity, lastPurchase = @lastPurchase WHERE dealership = @dealerId AND vehicle = @vehModel', {
            ['@newQuantity'] = newQuantity,
            ['@lastPurchase'] = os.time(),
            ['@dealerId'] = dealerId,
            ['@vehModel'] = vehModel
          })

          if updateDealerStock > 0 then
            return newQuantity
          else
            return false
          end
        end
      end
    end
    return false
  end,
}

local requiredAttributes = {
  make = 'string',
  model = 'string',
  class = 'string',
  --category = 'string',
  price = 'number'
}

function ValidateVehicleData(data)
  if type(data) ~= 'table' then
    return false
  end
  for k, v in pairs(requiredAttributes) do
    if data[k] == nil or type(data[k]) ~= v then
      return false
    end
  end

  return data
end
