# To do
- [x] test method that grows a town
- [x] find out how to see logs to see what the code is doing
- [x] create a way to track ticks
- [ ] test the methods that increase a factories production
- [ ] test the methods that track cargo from station to station
	- I can't see a method that looks at cargo delivered last month, only waiting and planned
    - station ratings look like they have this data, but can't find a method to access it
- [ ] when demand is met
	- [ ] grow town
	- [ ] boost production of suppliers
- [ ] when there is excess supplied, boost growth a bit more
- [ ] reset town ratings each month
- [ ] track some stats
  - [ ] display stats
- [ ] internationalization

## Improvements
- [x] optimize script so it doesn't just run every day
- [ ] optimize monitoring for cargo, keep a track of monitored industries and 
e.g. 
```squirrel
function MakeTripletKey(cid, ct, tid) {
    return cid + ":" + ct + ":" + tid;
}

function BuildTripletSet(triplets) {
    local set = {};
    foreach (t in triplets) {
        local key = MakeTripletKey(t.companyId, t.cargoType, t.townId);
        set[key] <- true;
    }
    return set;
}

function FindMissingEntries(oldSet, newSet) {
    local missing = [];
    foreach (key, _ in oldSet) {
        if (!(key in newSet)) missing.append(key);
    }
    return missing;
}

// Example data
local oldMap = [
    { companyId = 1, cargoType = 0, townId = 100 },
    { companyId = 1, cargoType = 1, townId = 101 },
    { companyId = 2, cargoType = 2, townId = 102 },
];

local newMap = [
    { companyId = 1, cargoType = 1, townId = 101 }, // same
    { companyId = 2, cargoType = 2, townId = 102 }, // same
];

local oldSet = BuildTripletSet(oldMap);
local newSet = BuildTripletSet(newMap);
local missing = FindMissingEntries(oldSet, newSet);

// Output missing triplets
foreach (key in missing) {
    GSLog.Info("Missing: " + key);
}
```


# Notes & Ideas
- Save x years of stats?
- most profitable vehicle, break down by plane, ship etc
- account for a ratio, running cost over revenue (revenue not possible)
- have absolute stats and proportional stats.
- graph the stats somehow
- Track cargo by stations
- Boost town growth from delivery, bonus growth if demand exceeded.
- Boost supply from delivery proportional to how much demand was met. Don't grow a factory if demand was exceeded.
- Factory production decays when not all cargo is delivered, and this is counteracted by growth mentioned above.
- Setting for target city population, 750k default?
- Setting for reducing cargo rates since there will be a lot produced. (not possible)
- Profitability per vehicle or better yet, probability per station chain as KPIs
- Setting for resetting the ratings of a town to allow more demolition.
- Aim to capture all changes to things as stats, city & industry growth, delivery route stats including stations & vehicles,

https://docs.openttd.org/gs-api/globals

https://docs.openttd.org/gs-api/classGSDate

refer to this for tick info https://github.com/OpenTTD/OpenTTD/blob/0d599e155f335e922ad2be738a3ab73d1dea346b/src/date_type.h#L34

this list gives pretty good hints as to what types exist

https://docs.openttd.org/gs-api/classGSTown

tested so far, upgrades or builds 100 houses in all towns, even if the game is paused
```squirrel
local allTowns = GSTownList();
foreach (townId, _ in allTowns) {
	GSTown.ExpandTown(townId, 100)
}
```

// since towns will grow a lot it, resetting the ratings to neutral will help with demolishing buildings, roads and bridges that are in the way
static bool GSTown::ChangeRating(TownID town_id, GSCompany::CompanyID company_id, int delta)

delta	How much to change rating by (range -1000 to +1000).
enum GSTown::TownRating



// could be useful for cargo tracking, although need to carefully link the exact factory to a destination
static int GSTown::GetLastMonthProduction(TownID town_id, CargoType cargo_type)
static int GSTown::GetLastMonthReceived(TownID town_id, GSCargo::TownEffect towneffect_id)
static int GSTown::GetLastMonthSupplied(TownID town_id, CargoType cargo_type)


// hopefully wont need this
static bool GSTown::IsWithinTownInfluence(TownID town_id, TileIndex tile)


https://docs.openttd.org/gs-api/classGSIndustry

static int GetProductionLevel(IndustryID industry_id)
static bool GSIndustry::SetProductionLevel(IndustryID industry_id, int prod_level, bool show_news, Text * custom_news)

// this would only apply to intermediates
static GSDate::Date 	GetCargoLastAcceptedDate (IndustryID industry_id, CargoType cargo_type)
 	Get the last economy-date this industry accepted any cargo delivery. 


static int 	GetStockpiledCargo (IndustryID industry_id, CargoType cargo_type)
 	Get the amount of cargo stockpiled for processing.
 
static int 	GetLastMonthProduction (IndustryID industry_id, CargoType cargo_type)
 	Get the total last economy-month's production of the given cargo at an industry.
 
static int 	GetLastMonthTransported (IndustryID industry_id, CargoType cargo_type)
 	Get the total amount of cargo transported from an industry last economy-month.
 
static int 	GetLastMonthTransportedPercentage (IndustryID industry_id, CargoType cargo_type)
 	Get the percentage of cargo transported from an industry last economy-month.

https://docs.openttd.org/gs-api/classGSBaseStation

static TileIndex 	GetLocation (StationID station_id)

https://docs.openttd.org/gs-api/classGSStation

// between the following functions, have to figure out if there is a way to retrospectively figure out where goods were delivered from
static int 	GetCargoWaiting (StationID station_id, CargoType cargo_type)
 	See how much cargo there is waiting on a station.
 
static int 	GetCargoWaitingFrom (StationID station_id, StationID from_station_id, CargoType cargo_type)
 	See how much cargo with a specific source station there is waiting on a station.
 
static int 	GetCargoWaitingVia (StationID station_id, StationID via_station_id, CargoType cargo_type)
 	See how much cargo with a specific via-station there is waiting on a station.
 
static int 	GetCargoWaitingFromVia (StationID station_id, StationID from_station_id, StationID via_station_id, CargoType cargo_type)
 	See how much cargo with a specific via-station and source station there is waiting on a station.
 
static int 	GetCargoPlanned (StationID station_id, CargoType cargo_type)
 	See how much cargo was planned to pass (including production and consumption) this station per month.
 
static int 	GetCargoPlannedFrom (StationID station_id, StationID from_station_id, CargoType cargo_type)
 	See how much cargo from the specified origin was planned to pass (including production and consumption) this station per month.
 
static int 	GetCargoPlannedVia (StationID station_id, StationID via_station_id, CargoType cargo_type)
 	See how much cargo was planned to pass (including production and consumption) this station per month, heading for the specified next hop.
 
static int 	GetCargoPlannedFromVia (StationID station_id, StationID from_station_id, StationID via_station_id, CargoType cargo_type)
 	See how much cargo from the specified origin was planned to pass this station per month, heading for the specified next hop.

https://docs.openttd.org/gs-api/classGSCargo

Using a GSCargoList
```squirrel
// I don't know how to use the list, this doesn't get past item 0
// so many issues with this list, using plain arrays instead unless the list can be gerated by game
// the list seems to start with ten items in it which suggests it might have the cargo types without needing themto be manually set
// setting the item values rather than adding them results in a list of 11 items somehow
function getCargoTypes() {
    local list = GSCargoList();
    local index = 0
    for (local cargoType = 0; cargoType < 64; cargoType++) {
        if (GSCargo.IsValidCargo(cargoType)) {
            GSLog.Info("adding to index " + index + " id " + cargoType)
            list.SetValue(index++, cargoType);
        }
    }
    return list;
}
local cargoTypes = getCargoTypes();
for (local i = 0; i < cargoTypes.Count(); i++) {
	local cargoType = cargoTypes.GetValue(i);
	local label = GSCargo.GetCargoLabel(cargoType);
	GSLog.Info("CargoType " + cargoType + ":" + label);
}
```

https://docs.openttd.org/gs-api/classGSGame
static bool 	IsPaused ()
// bingo

https://docs.openttd.org/gs-api/classGSSign

https://docs.openttd.org/gs-api/classGSVehicle
static Money 	GetRunningCost (VehicleID vehicle_id)
static Money 	GetProfitThisYear (VehicleID vehicle_id)
static Money 	GetProfitLastYear (VehicleID vehicle_id)

https://docs.openttd.org/gs-api/classGSStoryPage

https://docs.openttd.org/gs-api/classGSLog

https://docs.openttd.org/gs-api/annotated

https://docs.openttd.org/gs-api/classGSNews
it's possible to create news



# towns need to be linked to raw industries by stations
# this needs to ignore player, e.g. it doesn't matter which or how many companies delivered the cargo from step to step

plan A (don't like plan A, maybe working in reverse is better. Just cause something is picked up doesn't mean it is delivered)
- for every industry producing something, or which cargo is being shipped from
  - find the number of stations around it
  - get the location of the industry
  - somehow search for stations (could be just get a list of stations receiving that type of cargo produced by that industry)

Plan B
- for every industry producing something
- get the cargo types into a list
- for every cargo type see if there is a town receiving it
- for every town receiving cargo (assuming it counts things like coal and oil which arent technically delivered to the town but a surrounding industry)
- find the station where it was delivered to 
- find which town/local authority it is linked to
  - static TownID GSStation.GetNearestTown(StationID station_id)
  - does it count as being delivered to a town if it is a power station or oil refinery?
- trace it back to an industry

Plan C
- GSCargoMonitor is the only thing that seems to be able to count how much was delivered
- I don't expect it to exactly match production due to these figures being run at different times, and even if they're run at the same time, cargo isn't transported instantly
- find all industries with a station around it
- find the stations where that industry is in its catchment area
- trace the cargo routes (pick a direction) to find links between industries & towns
