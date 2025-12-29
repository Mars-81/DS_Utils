# DS_Utils
DS_Utils is my own homebrew solution to a Roblox DataStore wrapper, its pretty basic can be comined with other scripts for more functionality.


included:

- GetPlayerIdFromNameAsync wrapper

- UpdateAsync wrapper

- RemoveAsync wrapper

- Caching for returned data

# Usage
use this however you'd like from copying to modifying and using it in a game, if you want you can credit me although that'll never be required

## rojo 
Rojo was used to help create this package, if you want to use rojo check out [Rojo](https://github.com/rojo-rbx/rojo) or [the Rojo documentation](https://rojo.space/docs)

# Documentation
## Config
### DataStore Config 
The config requires that you have atleast 1 DataStore set up in a table named "DataStores" that looks like:

    Name {

      Name: string,
   
      RetryOnFailure: boolean,
  
      CacheResults: boolean,
  
      CacheTime: number,
  
    }
if you have RetryOnFailure it will auto attempt to retry a function if it fails, this could increase your read and write usage by a significant margin depending on the data you pass through

### Error Config
The Config requires that you have a table section named "Error" and needs to be setup like this:

    Error {
        PrintMessage: boolean,
        
        LogToStore: boolean,
        
        StoreLogTo: string,
        
        CacheErrors: boolean,
        
        ErrorCacheTime: number,
    }
  
        
The error config will let you option to print error messages to the Developer Console if enabled, it will also allow you to save an error to a specified DataStore with StoreLogTo (Name) and LogToStore (do or do not). Printed or Saved errors are cached if enabled and will not be resaved or printed to a Datastore, I suggest leaving CacheErrors on

### Cache Config
The Config requires that you have a table section named "Cache" which needs to look like:

    Cache = {
        CacheAutoClean: boolean,
		
        MaxCacheSize: number, 


        CacheSize = 0, 
    }

The cache config allows for you to let it auto clean whenever it goes above a set number of caches, this cleaning only happens when you add a new cache to the cache if it is too large, MaxCacheSize lets you set how many caches you're fine with saving at a time. **The auto clean only clears out old caches, if you create lots of long lived caches it will not be able to clear those out,** also leave CacheSize untouched as it is for the module script to see how large the cache is to know when to clean the cache.

## Wrapped DataStore Functions

### LogError
Logs error based on its config with the option to log errors to a DataStore and/or the Developer Console, it takes the input of a message as a string and data as an any type with no return data

    LogError(message: string, Data: any): ()

### GetPlayerIdFromName
wraps GetUserIdFromNameAsync and will cache a key as the players name if caching is configured

    GetPlayerIdFromName(Name: string): number?

### ReturnData
Returns specified data type from a key, when specifying "All" it returns 2 values but only one for "Value" or "Metadata" type, and returns nill on error. It caches data with the key if caching is configured.

    ReturnData(DataStore: Config.DataStoreConfig?, Key: string | number, Type: "Value" | "Metadata" | "All"): (any?, any?)

### SaveData
Saves provided data to key of chosen DataStore (or first in config), When setting all, provide a table with a "Value" and "Metadata" key otherwise just pass in the data you want to save. This function caches data with the key if caching is configured, first table is a good input for a save all function, second is the function call guide:

    local AllData = {
        Value = 100
        Metadata = {
            SaveDate = os.clock(),
			
            ExpireData = os.clock() + 150
        }
    }

    SaveData(DataStore: Config.DataStoreConfig?, Key: string | number, Type: "Value" | "Metadata" | "All", Data: any): ()
    

### RemoveData
Removes data of specified type from key, if Type is "All" it will delete the key, Value type data gets replaced with useless data

    RemoveData(DataStore: Config.DataStoreConfig?, Key: string | number, Type: "Value" | "Metadata" | "All"): ()

## Caching
While generally meant for caching data from DS_Utils functions, all of the functions it needs to run are able to be used through the DS_Utils Modulescript, if you plan on wanting to use caching outside of DS_Utils I have the documentation provided for its usage below.

### AddKey
Adds a key to the cache and if CacheAutoClean is set to true it will clean the cache if it is above the set MaxCacheSize before adding a new key to the cache.

    AddKey(Key: string, Value: any, MetaValue: any, TimeToCache: number): ()

### GetKey
Returns a Cache entry if there is a key matching the input key value, if the cache entry it would return is old too old (past expiration time) it will instead delete it and return nil, it will also return nil if a cache with that key does not exist. The first code segment is a CacheEntry type value which will be returned by GetKey, the second is the function call guide.

    export type CacheEntry = {
	    Value: any?,
		
    	MetaValue: any?,

		TimeStamp: number,
    	
		CacheTime: number
    }

    GetKey(Key: string): CacheEntry?

### RemoveKey
clears a specific key from the cache if it exists, will not log an error if a cache value does not exist

    RemoveKey(Key: string): ()

### ClearCache
Clears the entire cach

    ClearCache(): ()

### ValidateCache
Checks all of the keys in the cache and delete keys that are old 

    ValidateCache(): ()
