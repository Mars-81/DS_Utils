local DataStoreService = game:GetService("DataStoreService")
local Config = require(script.Parent.Config)

type DataStoreConfig = {
	Name: string,
	RetryOnFailure: boolean?,
	CacheResults: boolean?,
	CacheTime: number? -- seconds
} 

local Cache: { [string]: { Data: any, TimeStamp: DateTime?, TimeToCache: number? } } = {}

local function LogError(_message: string, _Data:any): () end

local DS_Util = {
	-- Logs and error if configured to log errors --
	LogError = function(message: string, Data: any): () 
		if Cache["LastError"] and Cache["LastError"].Data == message then
			return
		else
			Cache["LastError"] = { Data = message, TimeStamp = nil, TimeToCache = nil }
		end
		if Config.Error.LogToStore then
			local DataStore, Key: string? = nil, nil
			DataStore = DataStoreService:GetDataStore(
				Config.Error.StoreLogTo or Config.DataStores[1].Name
			)
			Key = Config.Error.KeyToStore or "ErrorLog"

			if Key and DataStore then
				local Success, Err = pcall(function()
					local TimeStamp: string = tostring(DateTime.now())
					local Log: any = DataStore:GetAsync(Key) or {} -- existing or new
					Log[TimeStamp] = {
						Message = message,
						Data = Data,
					}
					DataStore:SetAsync(Key, Log)
				end)
				if (not Success and Config.Error.PrintMessage) or Config.Error.PrintMessage then
					warn("DS_Util LogError failed to log error: " .. tostring(Err))
				end
				return
			else 
				if Config.Error.PrintMessage then
					warn("DS_Util LogError failed: DataStore or Key is nil")
				end
				return
			end
		elseif Config.Error.PrintMessage then
			warn("DS_Util Error: " .. message)
			return 
		else 
			return 
		end
	end,
	-- wraps "GetUserIdFromNameAsync()" --
	GetPlayerKeyFromName = function(Name: string): number?
		local PlayerService = game:GetService("Players")
		local Key: number?
		local sucess, err = pcall(function()
			Key = PlayerService:GetUserIdFromNameAsync(Name)
		end)
		if sucess and Key then
			return Key
		else
			LogError("GetPlayerKeyFromName failed for name: " .. Name, err)
			return nil
		end
	end,

	-- DataStore data functions --

	-- Returns specified data type from a key, returns nill on error --
	ReturnData = function(DataStore: DataStoreConfig?, Key: string | number, Type: "Value" | "Metadata" | "All"): (any?, any?)
		if not DataStore or not Config.DataStores[next(Config.DataStores)] then
			LogError("ReturnData failed: No DataStores configured", nil)
			return
		end
		local Store: DataStore
		if DataStore then 
			Store = DataStoreService:GetDataStore(DataStore.Name)
		else 
			Store = DataStoreService:GetDataStore(Config.DataStores[1].Name)
		end
		if not Store then
			LogError("ReturnData failed: DataStore is nil", nil)
			return
		else 
			local sucess, valueData, metaData: DataStoreKeyInfo = pcall(function()
				return Store:GetAsync(tostring(Key))
			end)
			if sucess then
				local MetaReturn: any
				if not metaData then
					MetaReturn = {}
				else
					MetaReturn = metaData:GetMetadata()
				end
				if Type == "All" then
					return valueData, MetaReturn
				elseif Type == "Value" then
					return valueData
				elseif Type == "Metadata" then
					return MetaReturn
				else
					LogError("ReturnData failed: Bad Data type specified", nil)
					return nil, nil
				end
			else 
				LogError("ReturnData failed: Error getting data from DataStore", nil)
				if Config.DataStores[DataStore or 1].RetryOnFailure then
					local success, ValueData, MetaData = pcall(function()
						return Store:GetAsync(tostring(Key))
					end)
					if success then
						local MetaReturn: any
						if not metaData then
							MetaReturn = nil
						else
							MetaReturn = MetaData:GetMetadata()
						end
						if Type == "All" then
							return ValueData, MetaReturn
						elseif Type == "Value" then
							return ValueData
						elseif Type == "Metadata" then
							return MetaReturn
						else
							LogError("ReturnData failed: Bad Data type specified on retry", nil)
							return nil, nil
						end
					else
						LogError("ReturnData failed: Retry failed getting data from DataStore", nil)
						return nil, nil
					end
				end
				return nil, nil
			end
		end
	end,
	-- Saves provided data to key of chosen DataStore (or first in config) --
	-- When setting all, provide a table with a "Value" and "Metadata" key --
	SaveData = function(DataStore: DataStoreConfig?, Key: string | number, Type: "Value" | "Metadata" | "All", Data: any): () 
		if not DataStore or not Config.DataStores[next(Config.DataStores)] then
			LogError("SaveData failed: No DataStores configured", nil)
			return
		end
		local Store: DataStore
		if DataStore then 
			Store = DataStoreService:GetDataStore(DataStore.Name)
		else 
			Store = DataStoreService:GetDataStore(Config.DataStores[1].Name)
		end
		if not Store then
			LogError("SaveData failed: DataStore is nil", nil)
			return
		end

		if Type == "Value" then
			local FallBackMetaData = Instance.new("DataStoreSetOptions")
			FallBackMetaData:SetMetadata({})
			local sucess, err = pcall(function()
				Store:UpdateAsync(tostring(Key), function(_, OldKeyInfo: DataStoreKeyInfo?)
					if OldKeyInfo then
						local OldMetaData: DataStoreSetOptions = Instance.new("DataStoreSetOptions")
						OldMetaData:SetMetadata(OldKeyInfo:GetMetadata())
						return Data, OldMetaData or FallBackMetaData
					else 
						return Data, FallBackMetaData
					end
				end)
			end)
			if sucess then
				--Cache[tostring(Key) .. "_Value"] = { Data = Data, TimeStamp = DateTime.now(), TimeToCache = Config.DataStores[DataStore or 1].CacheTime or 5}
				return
			else
				LogError("Error saving player data: ", err)
				return
			end
		elseif Type == "Metadata" then
			local FallBackMetaData = Instance.new("DataStoreSetOptions")
			FallBackMetaData:SetMetadata({})
			local metaDataToSave: DataStoreSetOptions = Instance.new("DataStoreSetOptions")
			metaDataToSave:SetMetadata(Data)
			local sucess, err = pcall(function()
				Store:UpdateAsync(tostring(Key), function(OldValue, _: DataStoreKeyInfo?)
					if metaDataToSave then
						return OldValue, nil, metaDataToSave
					else 
						return OldValue, nil, FallBackMetaData
					end
				end)
			end)
			if sucess then
				--Cache[tostring(Key) .. "_Value"] = { Data = Data, TimeStamp = DateTime.now(), TimeToCache = Config.DataStores[DataStore or 1].CacheTime or 5}
				return
			else
				LogError("Error saving player data: ", err)
				return
			end
		elseif Type == "All" then
			local FallBackMetaData = Instance.new("DataStoreSetOptions")
			FallBackMetaData:SetMetadata({})
			local metaDataToSave: DataStoreSetOptions = Instance.new("DataStoreSetOptions")
			metaDataToSave:SetMetadata(Data.Metadata)
			local sucess, err = pcall(function()
				Store:UpdateAsync(tostring(Key), function(_OldValue, _: DataStoreKeyInfo?)
					if Data and metaDataToSave then
						return Data, nil, metaDataToSave
					elseif Data and not metaDataToSave then
						return Data, nil, FallBackMetaData
					elseif metaDataToSave and not Data then
						return _OldValue, nil, metaDataToSave
					else
						return _OldValue, nil, FallBackMetaData
					end
				end)
			end)
			if sucess then
				--Cache[tostring(Key) .. "_Value"] = { Data = Data, TimeStamp = DateTime.now(), TimeToCache = Config.DataStores[DataStore or 1].CacheTime or 5}
				return
			else
				LogError("Error saving player data: ", err)
				return
			end
		else
			LogError("SaveData failed: Invalid Type specified", nil)
			return
		end
	end,
	-- Removes data of specified type from key --
	-- If Type is "All" it will delete the key --
	RemoveData = function(DataStore: DataStoreConfig?, Key: string | number, Type: "Value" | "Metadata" | "All"): ()
		if not DataStore or not Config.DataStores[next(Config.DataStores)] then
			LogError("RemoveData failed: No DataStores configured", nil)
			return
		end
		local Store: DataStore
		if DataStore then 
			Store = DataStoreService:GetDataStore(DataStore.Name)
		else 
			Store = DataStoreService:GetDataStore(Config.DataStores[1].Name)
		end
		if not Store then
			LogError("ReturnData failed: DataStore is nil", nil)
			return
		end

		if Type == "Value" then
			local _sucess, _valueData, metaData: DataStoreKeyInfo = pcall(function()
				return Store:GetAsync(tostring(Key))
			end)
			local MetaSave: any
			if not metaData then MetaSave = {} else MetaSave = metaData:GetMetadata() end
			local metaDataToSave: DataStoreSetOptions = Instance.new("DataStoreSetOptions")
			metaDataToSave:SetMetadata(MetaSave)
			local success, err = pcall(function()
				Store:SetAsync(tostring(Key), nil, nil, metaDataToSave)
			end)
			if success then
				return
			else
				LogError("Error deleting player data: ", err)
				if not next(Config.DataStores) and not DataStore then
					local _success, _err = pcall(function()
						Store:SetAsync(tostring(Key), nil, nil, metaDataToSave)
					end)
					if _success then
						return
					else
						LogError("Error deleting player data on retry: ", _err)
						return
					end
				end
				return
			end
		elseif Type == "Metadata" then
			local _sucess, valueData, _metaData = pcall(function()
				return Store:GetAsync(tostring(Key))
			end)
			local metaDataToSave: DataStoreSetOptions = Instance.new("DataStoreSetOptions")
			metaDataToSave:SetMetadata({})
			local sucess, err = pcall(function()
				Store:SetAsync(tostring(Key), valueData, nil, metaDataToSave)
			end)
			if sucess then
				return
			else
				LogError("Error deleting player metadata: ", err)
				if (DataStore and DataStore.RetryOnFailure) or (Config.DataStores[next(Config.DataStores)].retryOnFailure) then
					local _success, _err = pcall(function()
						Store:SetAsync(tostring(Key), valueData, nil, metaDataToSave)
					end)
					if _success then
						return
					else
						LogError("Error deleting player metadata on retry: ", _err)
						return
					end
				end
				return
			end
		elseif Type == "All" then
			local success, err = pcall(function()
				Store:RemoveAsync(tostring(Key))
			end)
			if success then
				return
			else
				LogError("Error deleting Key: " .. Key .. " error: ", err)
				if Config.DataStores[DataStore or 1].RetryOnFailure then
					local _success, _err = pcall(function()
						Store:RemoveAsync(tostring(Key))
					end)
					if _success then
						return
					else
						LogError("Error deleting Key on retry: " .. Key .. " error: ", err)
						return
					end
				end
				return
			end
		else
			LogError("Invalid Type specified for deleting data.")
			return
		end
	end,
}

LogError = function(message: string, Data: any): () 
	DS_Util.LogError(message, Data)
end


return DS_Util 