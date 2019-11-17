AddEventHandler('es:playerLoaded', function(source, _player)
	local _source = source
	local tasks   = {}

	local userData = {
		accounts     = {},
		inventory    = {},
		job          = {},
		gang         = {},
		loadout      = {},
		playerName   = GetPlayerName(_source),
		lastPosition = nil,
		nom 		 = nil,
		prenom 		 = nil,
		secretCode   = 0000,
		accountNumber = nil,
	}

	TriggerEvent('es:getPlayerFromId', _source, function(player)
		-- Update user name in DB
		table.insert(tasks, function(cb)
			MySQL.Async.execute('UPDATE users SET name = @name WHERE identifier = @identifier', {
				['@identifier'] = player.getIdentifier(),
				['@name'] = userData.playerName
			}, function(rowsChanged)
				cb()
			end)
		end)

		-- Get accounts
		table.insert(tasks, function(cb)
			MySQL.Async.fetchAll('SELECT name, money FROM user_accounts WHERE identifier = @identifier', {
				['@identifier'] = player.getIdentifier()
			}, function(accounts)
				local validAccounts = ESX.Table.Set(Config.Accounts)
				for k,v in ipairs(accounts) do
					if validAccounts[v.name] then
						table.insert(userData.accounts, {
							name  = v.name,
							money = v.money,
							label = Config.AccountLabels[v.name]
						})
					end
				end

				cb()
			end)
		end)

		-- Get inventory
		table.insert(tasks, function(cb)

			MySQL.Async.fetchAll('SELECT item, count FROM user_inventory WHERE identifier = @identifier', {
				['@identifier'] = player.getIdentifier()
			}, function(inventory)
				local tasks2, foundItems = {}, {}

				for k,v in ipairs(inventory) do
					local item = ESX.Items[v.item]

					if item then
						foundItems[v.item] = true

						table.insert(userData.inventory, {
							name = v.item,
							count = v.count,
							label = item.label,
							limit = item.limit,
							weight = item.weight,
							usable = ESX.UsableItemsCallbacks[v.item] ~= nil,
							rare = item.rare,
							canRemove = item.canRemove
						})
					else
						print(('es_extended: invalid item "%s" ignored!'):format(v.item))
					end
				end

				for itemName,item in pairs(ESX.Items) do
					if not foundItems[itemName] then
						table.insert(userData.inventory, {
							name = itemName,
							count = 0,
							label = item.label,
							limit = item.limit,
							weight = item.weight,
							usable = ESX.UsableItemsCallbacks[itemName] ~= nil,
							rare = item.rare,
							canRemove = item.canRemove
						})

						local scope = function(item, identifier)
							table.insert(tasks2, function(cb2)
								MySQL.Async.execute('INSERT INTO user_inventory (identifier, item, count) VALUES (@identifier, @item, @count)', {
									['@identifier'] = identifier,
									['@item'] = item,
									['@count'] = 0
								}, function(rowsChanged)
									cb2()
								end)
							end)
						end

						scope(itemName, player.getIdentifier())
					end
				end

				Async.parallelLimit(tasks2, 5, function(results) end)

				table.sort(userData.inventory, function(a,b)
					return a.label < b.label
				end)

				cb()
			end)

		end)

		-- Get job and loadout
		table.insert(tasks, function(cb)

			local tasks2 = {}

			-- Get job name, grade and last position
			table.insert(tasks2, function(cb2)

				MySQL.Async.fetchAll('SELECT firstname, lastname, job, job_grade, loadout, position FROM users WHERE identifier = @identifier', {
					['@identifier'] = player.getIdentifier()
				}, function(result)
					local job, grade = result[1].job, tostring(result[1].job_grade)

					userData.prenom  = result[1].firstname
					userData.nom     = result[1].lastname

					if ESX.DoesJobExist(job, grade) then
						local jobObject, gradeObject = ESX.Jobs[job], ESX.Jobs[job].grades[grade]

						userData.job = {}

						userData.job.id    = jobObject.id
						userData.job.name  = jobObject.name
						userData.job.label = jobObject.label

						userData.job.grade        = tonumber(grade)
						userData.job.grade_name   = gradeObject.name
						userData.job.grade_label  = gradeObject.label
						userData.job.grade_salary = gradeObject.salary

						userData.job.skin_male    = {}
						userData.job.skin_female  = {}

						if gradeObject.skin_male ~= nil then
							userData.job.skin_male = json.decode(gradeObject.skin_male)
						end

						if gradeObject.skin_female ~= nil then
							userData.job.skin_female = json.decode(gradeObject.skin_female)
						end
					else
						print(('es_extended: %s had an unknown job [job: %s, grade: %s], setting as unemployed!'):format(player.getIdentifier(), job, grade))

						local job, grade = 'chomeur', '0'
						local jobObject, gradeObject = ESX.Jobs[job], ESX.Jobs[job].grades[grade]

						userData.job = {}

						userData.job.id    = jobObject.id
						userData.job.name  = jobObject.name
						userData.job.label = jobObject.label

						userData.job.grade        = tonumber(grade)
						userData.job.grade_name   = gradeObject.name
						userData.job.grade_label  = gradeObject.label
						userData.job.grade_salary = gradeObject.salary

						userData.job.skin_male    = {}
						userData.job.skin_female  = {}
					end

					if result[1].loadout ~= nil then
						userData.loadout = json.decode(result[1].loadout)

						-- Compatibility with old loadouts prior to components update
						for k,v in ipairs(userData.loadout) do
							if v.components == nil then
								v.components = {}
							end
						end
					end

					if result[1].position ~= nil then
						userData.lastPosition = json.decode(result[1].position)
					end

					cb2()
				end)

			end)

			-- recup code secret carte de credit
			table.insert(tasks2, function(cb2)

				MySQL.Async.fetchAll('SELECT * FROM `creditcard` WHERE `owner` = @identifier', {
					['@identifier'] = player.getIdentifier()
				}, function(result)
					if (result[1]) then
						if (result[1].code ~= nil) then
							userData.secretCode = result[1].code
						end
					end
					cb2()
				end)
			end)

			-- recup le numero de compte
			table.insert(tasks2, function(cb2)

				MySQL.Async.fetchAll('SELECT * FROM `banque_atm` WHERE `identifier` = @identifier', {
					['@identifier'] = player.getIdentifier()
				}, function(result)
					if (result[1]) then
						if (result[1].account ~= nil) then
							userData.accountNumber = result[1].account
						end
					end
					cb2()
				end)
			end)

			Async.series(tasks2, cb)

		end)

		--#### GANG
		-- Get gang and loadout
		table.insert(tasks, function(cb)

			local tasks2 = {}

			-- Get gang name, grade and last position
			table.insert(tasks2, function(cb2)

				MySQL.Async.fetchAll('SELECT firstname, lastname, gang, gang_grade, loadout, position FROM users WHERE identifier = @identifier', {
					['@identifier'] = player.getIdentifier()
				}, function(result)
					local gang, grade = result[1].gang, tostring(result[1].gang_grade)

					userData.prenom  = result[1].firstname
					userData.nom     = result[1].lastname

					if ESX.DoesGangExist(gang, grade) then
						local gangObject, gradeObject = ESX.Gangs[gang], ESX.Gangs[gang].grades[grade]

						userData.gang = {}

						userData.gang.id    = gangObject.id
						userData.gang.name  = gangObject.name
						userData.gang.label = gangObject.label

						userData.gang.grade        = tonumber(grade)
						userData.gang.grade_name   = gradeObject.name
						userData.gang.grade_label  = gradeObject.label
						userData.gang.grade_salary = gradeObject.salary

					--	userData.gang.skin_male    = {}
					--	userData.gang.skin_female  = {}

					--	if gradeObject.skin_male ~= nil then
					--		userData.gang.skin_male = json.decode(gradeObject.skin_male)
					--	end

					--	if gradeObject.skin_female ~= nil then
					--		userData.gang.skin_female = json.decode(gradeObject.skin_female)
					--	end
					else
						print(('es_extended: %s had an unknown gang [gang: %s, grade: %s], setting as unemployed!'):format(player.getIdentifier(), gang, grade))

						local gang, grade = 'aucun', '0'
						local gangObject, gradeObject = ESX.Gangs[gang], ESX.Gangs[gang].grades[grade]

						userData.gang = {}

						userData.gang.id    = gangObject.id
						userData.gang.name  = gangObject.name
						userData.gang.label = gangObject.label

						userData.gang.grade        = tonumber(grade)
						userData.gang.grade_name   = gradeObject.name
						userData.gang.grade_label  = gradeObject.label
						userData.gang.grade_salary = gradeObject.salary

					--	userData.gang.skin_male    = {}
					--	userData.gang.skin_female  = {}
					end

					--if result[1].loadout ~= nil then
					--	userData.loadout = json.decode(result[1].loadout)

						-- Compatibility with old loadouts prior to components update
					--	for k,v in ipairs(userData.loadout) do
					--		if v.components == nil then
					--			v.components = {}
					--		end
					--	end
					--end

					--if result[1].position ~= nil then
					--	userData.lastPosition = json.decode(result[1].position)
					--end

					cb2()
				end)

			end)

			Async.series(tasks2, cb)

		end)
		--#### GANG

		-- Run Tasks
		Async.parallel(tasks, function(results)
			local xPlayer = CreateExtendedPlayer(player, userData.accounts, userData.inventory, userData.job, userData.gang, userData.loadout, userData.playerName, userData.lastPosition, userData.prenom, userData.nom, userData.secretCode, userData.accountNumber)

			xPlayer.getMissingAccounts(function(missingAccounts)
				if #missingAccounts > 0 then
					for i=1, #missingAccounts, 1 do
						table.insert(xPlayer.accounts, {
							name  = missingAccounts[i],
							money = 0,
							label = Config.AccountLabels[missingAccounts[i]]
						})
					end

					xPlayer.createAccounts(missingAccounts)
				end

				ESX.Players[_source] = xPlayer

				TriggerEvent('esx:playerLoaded', _source, xPlayer)

				TriggerClientEvent('esx:playerLoaded', _source, {
					identifier   = xPlayer.identifier,
					accounts     = xPlayer.getAccounts(),
					inventory    = xPlayer.getInventory(),
					job          = xPlayer.getJob(),
					gang         = xPlayer.getGang(),
					loadout      = xPlayer.getLoadout(),
					lastPosition = xPlayer.getLastPosition(),
					money        = xPlayer.getMoney(),
					maxWeight    = xPlayer.maxWeight,
					prenom 		 = xPlayer.prenom,
					nom 		 = xPlayer.nom,
					secretCode   = xPlayer.secretCode,
					accountNumber = xPlayer.accountNumber
				})

				xPlayer.displayMoney(xPlayer.getMoney())
				TriggerClientEvent('esx:createMissingPickups', _source, ESX.Pickups)
			end)
		end)

	end)
end)

AddEventHandler('playerDropped', function(reason)
	local _source = source
	local xPlayer = ESX.GetPlayerFromId(_source)

	if xPlayer then
		TriggerEvent('esx:playerDropped', _source, reason)

		ESX.SavePlayer(xPlayer, function()
			ESX.Players[_source] = nil
			ESX.LastPlayerData[_source] = nil
		end)
	end
end)

RegisterServerEvent('esx:updateLoadout')
AddEventHandler('esx:updateLoadout', function(loadout)
	local xPlayer = ESX.GetPlayerFromId(source)
	xPlayer.loadout = loadout
end)

RegisterServerEvent('esx:updateLastPosition')
AddEventHandler('esx:updateLastPosition', function(position)
	local xPlayer = ESX.GetPlayerFromId(source)
	xPlayer.setLastPosition(position)
end)

RegisterServerEvent('esx:giveInventoryItem')
AddEventHandler('esx:giveInventoryItem', function(target, type, itemName, itemCount)
	local playerId = source
	local sourceXPlayer = ESX.GetPlayerFromId(playerId)
	local targetXPlayer = ESX.GetPlayerFromId(target)

	if type == 'item_standard' then
		local sourceItem = sourceXPlayer.getInventoryItem(itemName)
		local targetItem = targetXPlayer.getInventoryItem(itemName)

		if itemCount > 0 and sourceItem.count >= itemCount then
			if targetXPlayer.canCarryItem(itemName, itemCount) then
				sourceXPlayer.removeInventoryItem(itemName, itemCount)
				targetXPlayer.addInventoryItem   (itemName, itemCount)

				sourceXPlayer.showNotification(_U('gave_item', itemCount, sourceItem.label, targetXPlayer.name))
				targetXPlayer.showNotification(_U('received_item', itemCount, sourceItem.label, sourceXPlayer.name))
			else
				sourceXPlayer.showNotification(_U('ex_inv_lim', targetXPlayer.name))
			end
		else
			sourceXPlayer.showNotification(_U('imp_invalid_quantity'))
		end
	elseif type == 'item_money' then
		if itemCount > 0 and sourceXPlayer.getMoney() >= itemCount then
			sourceXPlayer.removeMoney(itemCount)
			targetXPlayer.addMoney   (itemCount)

			sourceXPlayer.showNotification(_U('gave_money', ESX.Math.GroupDigits(itemCount), targetXPlayer.name))
			targetXPlayer.showNotification(_U('received_money', ESX.Math.GroupDigits(itemCount), sourceXPlayer.name))
		else
			sourceXPlayer.showNotification(_U('imp_invalid_amount'))
		end
	elseif type == 'item_account' then
		if itemCount > 0 and sourceXPlayer.getAccount(itemName).money >= itemCount then
			sourceXPlayer.removeAccountMoney(itemName, itemCount)
			targetXPlayer.addAccountMoney   (itemName, itemCount)

			sourceXPlayer.showNotification(_U('gave_account_money', ESX.Math.GroupDigits(itemCount), Config.AccountLabels[itemName], targetXPlayer.name))
			targetXPlayer.showNotification(_U('received_account_money', ESX.Math.GroupDigits(itemCount), Config.AccountLabels[itemName], sourceXPlayer.name))
		else
			sourceXPlayer.showNotification(_U('imp_invalid_amount'))
		end
	elseif type == 'item_weapon' then
		if not targetXPlayer.hasWeapon(itemName) then
			sourceXPlayer.removeWeapon(itemName)
			targetXPlayer.addWeapon(itemName, itemCount)
			local weaponLabel = ESX.GetWeaponLabel(itemName)

			if itemCount > 0 then
				sourceXPlayer.showNotification(_U('gave_weapon_withammo', weaponLabel, itemCount, targetXPlayer.name))
				targetXPlayer.showNotification(_U('received_weapon_withammo', weaponLabel, itemCount, sourceXPlayer.name))
			else
				sourceXPlayer.showNotification(_U('gave_weapon', weaponLabel, targetXPlayer.name))
				targetXPlayer.showNotification(_U('received_weapon', weaponLabel, sourceXPlayer.name))
			end
		else
			sourceXPlayer.showNotification(_U('gave_weapon_hasalready', targetXPlayer.name, weaponLabel))
			targetXPlayer.showNotification(_U('received_weapon_hasalready', sourceXPlayer.name, weaponLabel))
		end
	elseif type == 'item_ammo' then
		if sourceXPlayer.hasWeapon(itemName) then
			if targetXPlayer.hasWeapon(itemName) then
				local weaponNum, weapon = sourceXPlayer.getWeapon(itemName)

				if weapon.ammo >= itemCount then
					sourceXPlayer.removeWeaponAmmo(itemName, itemCount)
					targetXPlayer.addWeaponAmmo(itemName, itemCount)

					sourceXPlayer.showNotification(_U('gave_weapon_ammo', itemCount, weapon.label, targetXPlayer.name))
					targetXPlayer.showNotification(_U('received_weapon_ammo', itemCount, weapon.label, sourceXPlayer.name))
				end
			else
				sourceXPlayer.showNotification(_U('gave_weapon_noweapon', targetXPlayer.name))
				targetXPlayer.showNotification(_U('received_weapon_noweapon', sourceXPlayer.name, weapon.label))
			end
		end
	end
end)

RegisterServerEvent('esx:removeInventoryItem')
AddEventHandler('esx:removeInventoryItem', function(type, itemName, itemCount)
	local playerId = source
	local xPlayer = ESX.GetPlayerFromId(source)

	if type == 'item_standard' then
		if itemCount == nil or itemCount < 1 then
			xPlayer.showNotification(_U('imp_invalid_quantity'))
		else
			local xItem = xPlayer.getInventoryItem(itemName)

			if (itemCount > xItem.count or xItem.count < 1) then
				xPlayer.showNotification(_U('imp_invalid_quantity'))
			else
				xPlayer.removeInventoryItem(itemName, itemCount)
				local pickupLabel = ('~y~%s~s~ [~b~%s~s~]'):format(xItem.label, itemCount)
				ESX.CreatePickup('item_standard', itemName, itemCount, pickupLabel, playerId)
				xPlayer.showNotification(_U('threw_standard', itemCount, xItem.label))
			end
		end
	elseif type == 'item_money' then
		if itemCount == nil or itemCount < 1 then
			xPlayer.showNotification(_U('imp_invalid_amount'))
		else
			local playerCash = xPlayer.getMoney()

			if (itemCount > playerCash or playerCash < 1) then
				xPlayer.showNotification(_U('imp_invalid_amount'))
			else
				xPlayer.removeMoney(itemCount)
				local pickupLabel = ('~y~%s~s~ [~g~%s~s~]'):format(_U('cash'), _U('locale_currency', ESX.Math.GroupDigits(itemCount)))
				ESX.CreatePickup('item_money', 'money', itemCount, pickupLabel, playerId)
				xPlayer.showNotification(_U('threw_money', ESX.Math.GroupDigits(itemCount)))
			end
		end
	elseif type == 'item_account' then
		if itemCount == nil or itemCount < 1 then
			xPlayer.showNotification(_U('imp_invalid_amount'))
		else
			local account = xPlayer.getAccount(itemName)

			if (itemCount > account.money or account.money < 1) then
				xPlayer.showNotification(_U('imp_invalid_amount'))
			else
				xPlayer.removeAccountMoney(itemName, itemCount)
				local pickupLabel = ('~y~%s~s~ [~g~%s~s~]'):format(account.label, _U('locale_currency', ESX.Math.GroupDigits(itemCount)))
				ESX.CreatePickup('item_account', itemName, itemCount, pickupLabel, playerId)
				xPlayer.showNotification(_U('threw_account', ESX.Math.GroupDigits(itemCount), string.lower(account.label)))
			end
		end
	elseif type == 'item_weapon' then
		if xPlayer.hasWeapon(itemName) then
			local weaponNum, weapon = xPlayer.getWeapon(itemName)
			local weaponPickup = 'PICKUP_' .. string.upper(itemName)
			xPlayer.removeWeapon(itemName)

			if weapon.ammo > 0 then
				TriggerClientEvent('esx:pickupWeapon', playerId, weaponPickup, itemName, weapon.ammo)
				xPlayer.showNotification(_U('threw_weapon_ammo', weapon.label, weapon.ammo))
			else
				-- workaround for CreateAmbientPickup() giving 30 rounds of ammo when you drop the weapon with 0 ammo
				TriggerClientEvent('esx:pickupWeapon', playerId, weaponPickup, itemName, 1)
				xPlayer.showNotification(_U('threw_weapon', weapon.label))
			end
		end
	end
end)

RegisterServerEvent('esx:useItem')
AddEventHandler('esx:useItem', function(itemName)
	local xPlayer = ESX.GetPlayerFromId(source)
	local count = xPlayer.getInventoryItem(itemName).count

	if count > 0 then
		ESX.UseItem(source, itemName)
	else
		xPlayer.showNotification(_U('act_imp'))
	end
end)

RegisterServerEvent('esx:onPickup')
AddEventHandler('esx:onPickup', function(id)
	local _source = source
	local pickup  = ESX.Pickups[id]
	local xPlayer = ESX.GetPlayerFromId(_source)

	if pickup.type == 'item_standard' then
		if xPlayer.canCarryItem(pickup.name, pickup.count) then
			xPlayer.addInventoryItem(pickup.name, pickup.count)
			ESX.Pickups[id] = nil
			TriggerClientEvent('esx:removePickup', -1, id)
		end
	elseif pickup.type == 'item_money' then
		ESX.Pickups[id] = nil
		TriggerClientEvent('esx:removePickup', -1, id)
		xPlayer.addMoney(pickup.count)
	elseif pickup.type == 'item_account' then
		ESX.Pickups[id] = nil
		TriggerClientEvent('esx:removePickup', -1, id)
		xPlayer.addAccountMoney(pickup.name, pickup.count)
	end
end)

ESX.RegisterServerCallback('esx:getPlayerData', function(source, cb)
	local xPlayer = ESX.GetPlayerFromId(source)

	cb({
		identifier   = xPlayer.identifier,
		accounts     = xPlayer.getAccounts(),
		inventory    = xPlayer.getInventory(),
		job          = xPlayer.getJob(),
		gang         = xPlayer.getGang(),
		loadout      = xPlayer.getLoadout(),
		lastPosition = xPlayer.getLastPosition(),
		money        = xPlayer.getMoney()
	})
end)

ESX.RegisterServerCallback('esx:getOtherPlayerData', function(source, cb, target)
	local xPlayer = ESX.GetPlayerFromId(target)

	cb({
		identifier   = xPlayer.identifier,
		accounts     = xPlayer.getAccounts(),
		inventory    = xPlayer.getInventory(),
		job          = xPlayer.getJob(),
		gang         = xPlayer.getGang(),
		loadout      = xPlayer.getLoadout(),
		lastPosition = xPlayer.getLastPosition(),
		money        = xPlayer.getMoney()
	})
end)

TriggerEvent("es:addGroup", "jobmaster", "user", function(group) end)
TriggerEvent("es:addGroup", "gangmaster", "user", function(group) end)

ESX.StartDBSync()
ESX.StartPayCheck()


RegisterServerEvent('esx:updateConnexion')
AddEventHandler('esx:updateConnexion', function()
	local xPlayer        = ESX.GetPlayerFromId(source)
	--local ostime = os.date('%c', os.time())

	MySQL.Async.execute('UPDATE users SET lastconnexion = NOW() WHERE identifier = @identifier', {
		['@identifier'] = xPlayer.identifier,
	}, function()
	end)
end)

ESX.RegisterServerCallback('esx:getplayername', function(source, cb, player)
	local target = player
	local xPlayer = ESX.GetPlayerFromId(target)

	if xPlayer then
		local nom = xPlayer.nom
		local prenom = xPlayer.prenom

		cb(nom, prenom)
	else
		cb('', '')
	end

end)

UseItem = function(source, item)
	UsableItemsCallbacks[item](source)
end

RegisterNetEvent('fivelife:UseItem')
AddEventHandler('fivelife:UseItem', function(item)
	local _source = source
	local xPlayer = ESX.GetPlayerFromId(_source)

	local _item   = xPlayer.getInventoryItem(item.value)
	local _itemCount = _item.count

	if _itemCount > 0 then
		UseItem(_source, item.value)
	else
		TriggerClientEvent('esx:showAdvancedNotification', _source, "Inconnu", "~r~Erreur", "Action impossible. Vous n'en avez plus !", "CHAR_BLOCKED", 8)
	end
end)

ESX.RegisterServerCallback('awesomelife:getplayername', function(source, cb, player)
	local target = player
	local xPlayer = ESX.GetPlayerFromId(target)
	if xPlayer then
		local nom = xPlayer.nom
		local prenom = xPlayer.prenom
		cb(nom, prenom)
	else
		cb(nil, nil)
	end
	cb(nil, nil)
end)

RegisterServerEvent("kickForBeingAnAFKDouchebag")
AddEventHandler("kickForBeingAnAFKDouchebag", function()
	DropPlayer(source, "Expulsion : afk trop longtemps.")
end)
