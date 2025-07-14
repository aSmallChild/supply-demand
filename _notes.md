notes
- Save 10 years of stats?
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
this list gives pretty good hints as to what types exist

https://docs.openttd.org/gs-api/classGSTown
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

https://docs.openttd.org/gs-api/classGSGame
static bool 	IsPaused ()
// bingo

https://docs.openttd.org/gs-api/classGSSign

https://docs.openttd.org/gs-api/classGSVehicle
static Money 	GetRunningCost (VehicleID vehicle_id)
static Money 	GetProfitThisYear (VehicleID vehicle_id)
static Money 	GetProfitLastYear (VehicleID vehicle_id)