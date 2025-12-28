-- config file for the DS_Util module, if unusued a default config will be used

type DataStoreConfig = {
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
        StoreLogTo = "ExampleDataStore",
        KeyToStore = "ErrorLog",
    }
}

return Config 