local DataStoreService = game:GetService("DataStoreService")
local Config = require(script.Parent.Config)

export type CacheEntry = {
	Value: any?,
	MetaValue: any?,
	TimeStamp: number,
	CacheTime: number
}

local Cache = {} :: {[string]: CacheEntry}

local function LogError(_message: string, _Data:any): () end
local function GetCache(_Name: string): () end
local function SetCache(_Name: string, _Value: any, _MetaValue: any, _TimeToCache: number): () end
local function ValidateCache(): () end

local DS_Util = {
	-- Logs and error if configured to log errors --
	LogError = function(message: string, Data: any): () 
		local LastError: CacheEntry? = GetCache("LastError")
		if LastError and LastError.Value == Data then
			return
		else
			LastError = nil
			if Config.Error.CacheErrors then
				SetCache("LastError", message, nil, Config.Error.ErrorCacheTime or 30)
			end
		end
		if Config.Error.LogToStore then
			local DataStore, Key: string? = nil, nil
			DataStore = DataStoreService:GetDataStore(
				Config.Error.StoreLogTo or Config.DataStores[1].Name
			)
			Key = tostring(DateTime.now():ToIsoDate())

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
	-- will cache a key as the players name if caching is configured --
	GetPlayerIdFromName = function(Name: string): number?
		if Config.DataStores[next(Config.DataStores)] and Config.DataStores[next(Config.DataStores)].CacheResults then
			local CacheEntry: CacheEntry? = GetCache(Name)
			if CacheEntry then
				return CacheEntry.Value
			end
		end
		local PlayerService = game:GetService("Players")
		local Key: number?
		local sucess, err = pcall(function()
			Key = PlayerService:GetUserIdFromNameAsync(Name)
		end)
		if sucess and Key then
			if Config.DataStores[next(Config.DataStores)] and Config.DataStores[next(Config.DataStores)].CacheResults then
				SetCache(Name, Key, nil, Config.DataStores[next(Config.DataStores)].CacheTime or 5)
			end
			return Key
		else
			LogError("GetPlayerKeyFromName failed for name: " .. Name, err)
			return nil
		end
	end,

	-- DataStore data functions --

	-- Returns specified data type from a key, returns nill on error --
	-- caches data with the key if caching is configured --
	ReturnData = function(DataStore: Config.DataStoreConfig?, Key: string | number, Type: "Value" | "Metadata" | "All"): (any?, any?)
		
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
			if (Config.DataStores[next(Config.DataStores)] and Config.DataStores[next(Config.DataStores)].CacheResults) or (DataStore and DataStore.CacheResults) then
				local CacheEntry: CacheEntry? = GetCache(tostring(Key))
				if CacheEntry then
					if Type == "Value" or Type == "Metadata" then
						return CacheEntry.Value
					elseif Type == "All" then
						return CacheEntry.Value, CacheEntry.MetaValue
					end
				end
			end
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
					if DataStore.CacheResults or Config.DataStores[next(Config.DataStores)].CacheResults then
						SetCache(tostring(Key), valueData, MetaReturn, DataStore.CacheTime or Config.DataStores[next(Config.DataStores)].cacheTime)
					end
					return valueData, MetaReturn
				elseif Type == "Value" then
					if DataStore.CacheResults or Config.DataStores[next(Config.DataStores)].CacheResults then
						SetCache(tostring(Key), valueData, nil, DataStore.CacheTime or Config.DataStores[next(Config.DataStores)].cacheTime)
					end
					return valueData
				elseif Type == "Metadata" then
					if DataStore.CacheResults or Config.DataStores[next(Config.DataStores)].CacheResults then
						SetCache(tostring(Key), MetaReturn, nil, DataStore.CacheTime or Config.DataStores[next(Config.DataStores)].cacheTime)
					end
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
							if DataStore.CacheResults or Config.DataStores[next(Config.DataStores)].CacheResults then
								SetCache(tostring(Key), ValueData, MetaReturn, DataStore.CacheTime or Config.DataStores[next(Config.DataStores)].cacheTime)
							end
							return ValueData, MetaReturn
						elseif Type == "Value" then
							if DataStore.CacheResults or Config.DataStores[next(Config.DataStores)].CacheResults then
								SetCache(tostring(Key), ValueData, nil, DataStore.CacheTime or Config.DataStores[next(Config.DataStores)].cacheTime)
							end
							return ValueData
						elseif Type == "Metadata" then
							if DataStore.CacheResults or Config.DataStores[next(Config.DataStores)].CacheResults then
								SetCache(tostring(Key), MetaReturn, nil, DataStore.CacheTime or Config.DataStores[next(Config.DataStores)].cacheTime)
							end
							return MetaReturn
						else
							LogError("ReturnData failed: Bad Data type specified", nil)
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
	-- caches data with the key if caching is configured --
	SaveData = function(DataStore: Config.DataStoreConfig?, Key: string | number, Type: "Value" | "Metadata" | "All", Data: any): () 
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
			local sucess, err = pcall(function()
				Store:UpdateAsync(tostring(Key), function(_, OldKeyInfo: DataStoreKeyInfo)
					if OldKeyInfo then
						-- this may need to be fixed, work with this in a little bit
						local OldMetaData: DataStoreSetOptions = Instance.new("DataStoreSetOptions")
						OldMetaData:SetMetadata(OldKeyInfo:GetMetadata())
						return Data, nil, OldMetaData:GetMetadata() or {}
					else 
						return Data, nil, {}
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
			local sucess, err = pcall(function()
				Store:UpdateAsync(tostring(Key), function(OldValue, _: DataStoreKeyInfo?)
					if Data then
						return OldValue, nil, {Data}
					else 
						return OldValue, nil, {}
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
			local sucess, err = pcall(function()
				Store:UpdateAsync(tostring(Key), function(_OldValue, _: DataStoreKeyInfo?)
					if Data.Value and Data.Metadata then
						return Data.Value, nil, Data.Metadata
					elseif Data.Value and not Data.Metadata then
						return Data, nil, {}
					elseif Data.MetaData and not Data then
						return _OldValue, nil, Data.Metadata
					else
						return _OldValue, nil, {}
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
	RemoveData = function(DataStore: Config.DataStoreConfig?, Key: string | number, Type: "Value" | "Metadata" | "All"): ()
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
			local success, err = pcall(function()
				Store:UpdateAsync(tostring(Key), function(_, OldKeyInfo: DataStoreKeyInfo)
					if OldKeyInfo then
						return {}, nil, OldKeyInfo:GetMetadata() or {}
					else 
						return {}, nil, {}
					end
				end)
			end)
			if success then
				return
			else
				LogError("Error deleting player data: ", err)
				if not next(Config.DataStores) and not DataStore then
					local _success, _err = pcall(function()
						Store:UpdateAsync(tostring(Key), function(_, OldKeyInfo: DataStoreKeyInfo)
							if OldKeyInfo then
								return {}, nil, OldKeyInfo:GetMetadata() or {}
							else 
								return {}, nil, {}
							end
						end)
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
			local success, err = pcall(function()
				Store:UpdateAsync(tostring(Key), function(valueData, _: DataStoreKeyInfo)
						return valueData, nil, {}
				end)
			end)
			if success then
				return
			else
				LogError("Error deleting player metadata: ", err)
				if (DataStore and DataStore.RetryOnFailure) or (Config.DataStores[next(Config.DataStores)].retryOnFailure) then
					local _success, _err = pcall(function()
						Store:UpdateAsync(tostring(Key), function(valueData, _: DataStoreKeyInfo)
								return valueData, nil, {}
						end)
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

	-- cache functions --

	-- Adds a key to the cache --
	AddKey = function(Key: string, Value: any, MetaValue: any, TimeToCache: number): ()
		if Config.Cache.MaxCacheSize and Config.Cache.CacheSize > Config.Cache.MaxCacheSize then
			ValidateCache()
		end
		
		Cache[Key] = {
			Value = Value,
			MetaValue = MetaValue,
			TimeStamp = os.clock(),
			CacheTime = math.max(0, TimeToCache or 1)
		}
		Config.Cache.CacheSize = Config.Cache.CacheSize + 1
	end,

	-- Retrieves cached key if it exists and is valid --
	GetKey = function(Key: string): CacheEntry?
		local CacheEntry: CacheEntry? = Cache[Key]
		if CacheEntry then
			if os.clock() - CacheEntry.TimeStamp <= CacheEntry.CacheTime then
				return CacheEntry
			else
				Config.Cache.CacheSize = Config.Cache.CacheSize - 1
				Cache[Key] = nil
				return nil
			end
		else
			return nil
		end
	end,

	-- clears a specific key from the cache --
	RemoveKey = function(Key: string): ()
		Cache[Key] = nil
	end,

	-- Clears entire cache --
	ClearCache = function(): ()
		table.clear(Cache)
	end,

	-- validates all keys in cache --
	ValidateCache = function(): ()
		local now = os.clock()
		for Key, Entry in pairs(Cache) do
			if now - Entry.TimeStamp > Entry.CacheTime then
				Config.Cache.CacheSize = Config.Cache.CacheSize - 1
				Cache[Key] = nil
			end
		end
	end,
}

LogError = function(message: string, Data: any): () 
	DS_Util.LogError(message, Data)
end

GetCache = function(Name: string): CacheEntry?
	return DS_Util.GetKey(Name)
end

SetCache = function(_Name, _Value, _MetaValue, _TimeToCache) : ()
	DS_Util.AddKey(_Name, _Value, _MetaValue, _TimeToCache)
end

ValidateCache = function(): ()
	DS_Util.ValidateCache()
end

return DS_Util 