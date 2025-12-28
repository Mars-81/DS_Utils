-- config file for the DS_Util module, if unusued a default config will be used

export type DataStoreConfig = {
    Name: string,
    RetryOnFailure: boolean?,
    CacheResults: boolean?,
    CacheTime: number? -- seconds
}
type ErrorOut = {
    PrintMessage: boolean?, -- if true it will print the error message to output console
    LogToStore: boolean?, -- if true it will log errors to a datastore
    StoreLogTo: string?, -- will default to the first datastore if LogToStore is true
    KeyToStore: string?, -- if this is nil or false it will find or create an "ErrorLog" Key and then store a new value entry under a DateTime.now() name
}?

local Config = {
    DataStores = {
        -- the first datastore is used as a default if a datastore isnt specified in a function, so ensure atleast 1 real datastore exists or else you could lose some functionality --
        ExampleDataStore = {
            Name = "ExampleDataStore",
            retryOnFailure = true,
            CacheResults = false,
            CacheTime = 0,
        },
    },
    Error = {
        PrintMessage = true,
        LogToStore = false,
        StoreLogTo = "ExampleErrorDataStore", -- to help with not throttling other datastores, I recomend using a dedicated datastore or not logging errors in a datastore
        ErrorCacheTime = 30, -- seconds
    },
    Cache = {
        CacheAutoClean = true, -- if true caching is enabled
        MaxCacheSize = 50, -- max number of entries in cache, do keep in mind if you have large CacheTimes then it cant clean it if you create alot of them

        CacheSize = 0, -- do not edit, used for tracking current cache size 
    }
}

return Config 