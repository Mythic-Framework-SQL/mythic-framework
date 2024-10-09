function RegisterBallisticsCallbacks()
    Callbacks:RegisterServerCallback('Evidence:Ballistics:FileGun', function(source, data, cb)
        local player = Fetch:Source(source)
        if player and data and data.slotNum and data.serial then
            local char = player:GetData('Character')
            if char then
                local charId = char:GetData('ID')
                -- Files a Gun So Evidence Can Be Found
        
                local item = Inventory:GetSlot(charId, data.slotNum, 1)
                if item and item.MetaData and (item.MetaData.ScratchedSerialNumber or item.MetaData.SerialNumber) then
                    local firearmRecord, policeWeapId

                    if item.MetaData.ScratchedSerialNumber and item.MetaData.ScratchedSerialNumber == data.serial then
                        firearmRecord = GetFirearmsRecord(item.MetaData.ScratchedSerialNumber, true)
                    elseif item.MetaData.SerialNumber and item.MetaData.SerialNumber == data.serial then
                        firearmRecord = GetFirearmsRecord(item.MetaData.SerialNumber, false)
                    end

                    if firearmRecord then
                        if not firearmRecord.FiledByPolice then
                            local updateQuery, updateParams
                            if item.MetaData.ScratchedSerialNumber then
                                policeWeapId = string.format('PWI-%s', Sequence:Get('PoliceWeaponId'))

                                updateQuery = [[
                                    UPDATE firearms
                                    SET police_filed = ?, police_id = ?
                                    WHERE serial = ?
                                ]]
                                updateParams = {true, policeWeapId, firearmRecord.Serial}

                                Inventory:SetMetaDataKey(item.id, 'PoliceWeaponId', policeWeapId)
                            elseif item.MetaData.SerialNumber then
                                updateQuery = [[
                                    UPDATE firearms
                                    SET police_filed = ?
                                    WHERE serial = ?
                                ]]
                                updateParams = {true, firearmRecord.Serial}
                            end

                            if updateQuery then
                                local affectedRows = MySQL.Sync.execute(updateQuery, updateParams)
                                if affectedRows > 0 then
                                    cb(true, false, GetMatchingEvidenceProjectiles(firearmRecord.Serial), policeWeapId)
                                else
                                    cb(false)
                                end
                            end
                        else
                            return cb(true, true, GetMatchingEvidenceProjectiles(firearmRecord.Serial), firearmRecord.PoliceWeaponId)
                        end
                    else
                        cb(false)
                    end
                else
                    cb(false)
                end
                return
            end
        end
        cb(false)
    end)
end

function RegisterBallisticsItemUses()
    Inventory.Items:RegisterUse('evidence-projectile', 'Evidence', function(source, itemData)
        if itemData and itemData.MetaData and itemData.MetaData.EvidenceId and itemData.MetaData.EvidenceWeapon then
            Callbacks:ClientCallback(source, 'Polyzone:IsCoordsInZone', {
                coords = GetEntityCoords(GetPlayerPed(source)),
                key = 'ballistics',
                val = true,
            }, function(inZone)
                if inZone then
                    if not itemData.MetaData.EvidenceDegraded then
                        local filedEvidence = GetEvidenceProjectileRecord(itemData.MetaData.EvidenceId)
                        local matchingWeapon = GetFirearmsRecord(itemData.MetaData.EvidenceWeapon.serial, nil, true)
    
                        if filedEvidence then -- Already Exists
                            TriggerClientEvent('Evidence:Client:FiledProjectile', source, false, true, true, filedEvidence, matchingWeapon, itemData.MetaData.EvidenceId)
                        else
                            local newFiledEvidence = CreateEvidenceProjectileRecord({
                                Id = itemData.MetaData.EvidenceId,
                                Weapon = itemData.MetaData.EvidenceWeapon,
                                Coords = itemData.MetaData.EvidenceCoords,
                                AmmoType = itemData.MetaData.EvidenceAmmoType,
                            })
    
                            if newFiledEvidence then
                                TriggerClientEvent('Evidence:Client:FiledProjectile', source, false, true, false, newFiledEvidence, matchingWeapon, itemData.MetaData.EvidenceId)
                            else
                                TriggerClientEvent('Evidence:Client:FiledProjectile', source, false, false)
                            end
                        end
                    else
                        TriggerClientEvent('Evidence:Client:FiledProjectile', source, true)
                    end
                end
            end)
        end
    end)

    Inventory.Items:RegisterUse('evidence-dna', 'Evidence', function(source, itemData)
        if itemData and itemData.MetaData and itemData.MetaData.EvidenceId and itemData.MetaData.EvidenceDNA then
            Callbacks:ClientCallback(source, 'Polyzone:IsCoordsInZone', {
                coords = GetEntityCoords(GetPlayerPed(source)),
                key = 'dna',
                val = true,
            }, function(inZone)
                if inZone then
                    if not itemData.MetaData.EvidenceDegraded then
                        local char = GetCharacter(itemData.MetaData.EvidenceDNA)
                        if char then
                            TriggerClientEvent('Evidence:Client:RanDNA', source, false, char, itemData.MetaData.EvidenceId)
                        else
                            TriggerClientEvent('Evidence:Client:RanDNA', source, false, false)
                        end
                    else
                        TriggerClientEvent('Evidence:Client:RanDNA', source, true)
                    end
                end
            end)
        end
    end)
end

function GetFirearmsRecord(serialNumber, scratched, filedOnly)
    if not serialNumber then
        return false
    end

    local query = "SELECT * FROM firearms WHERE serial = ? AND scratched = ?"
    local params = {serialNumber, scratched}

    if filedOnly then
        query = query .. " AND police_filed = ?"
        table.insert(params, true)
    end

    local results = MySQL.query.await(query, params)
    if results and #results > 0 then
        return results[1]
    else
        return false
    end
end

function GetEvidenceProjectileRecord(evidenceId)
    local query = "SELECT * FROM firearms_projectiles WHERE Id = ?"
    local results = MySQL.query.await(query, {evidenceId})
    if results and #results > 0 then
        return results[1]
    else
        return false
    end
end

function CreateEvidenceProjectileRecord(document)
    local query = "INSERT INTO firearms_projectiles (Id, Weapon, Coords, AmmoType) VALUES (?, ?, ?, ?)"
    local params = {document.Id, document.Weapon, document.Coords, document.AmmoType}
    local insertId = MySQL.insert.await(query, params)
    if insertId then
        return document
    else
        return false
    end
end

function GetMatchingEvidenceProjectiles(weaponSerial)
    local query = "SELECT Id FROM firearms_projectiles WHERE WeaponSerial = ?"
    local results = MySQL.single.await(query, {weaponSerial})
    if results and #results > 0 then
        local foundEvidence = {}
        for k, v in ipairs(results) do
            table.insert(foundEvidence, v.Id)
        end
        return foundEvidence
    else
        return {}
    end
end

function GetCharacter(stateId)
    local query = "SELECT * FROM characters WHERE SID = ?"
    local results = MySQL.query.await(query, {stateId})
    if results and #results > 0 then
        local char = results[1]
        if char and char.SID and char.First and char.Last then
            return {
                SID = char.SID,
                First = char.First,
                Last = char.Last,
                Age = math.floor((os.time() - char.DOB) / 3.156e+7),
            }
        end
    else
        return false
    end
end