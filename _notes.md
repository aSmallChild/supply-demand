# To do

- [x] test method that grows a town
- [x] find out how to see logs to see what the code is doing
- [x] create a way to track ticks
- [x] test the methods that increase a factories production
- [x] test the methods that track cargo from station to station
    - I can't see a method that looks at cargo delivered last month, only waiting and planned
    - station ratings look like they have this data, but can't find a method to access it
- [ ] when demand is met
    - [ ] grow town
    - [ ] boost production of suppliers
- [ ] when there is excess supplied, boost growth a bit more
- [ ] reset town ratings each month
- [ ] track some stats
    - [ ] display stats in game menus (industry window, station window)
    - [ ] can the game do graphs?
- [ ] internationalization

## Improvements

- [x] optimize script so it doesn't just run every day
- [ ] optimize monitoring for cargo, keep a track of monitored industries (see triplets in snippets)
- [ ] figure out how to handle passengers mail and valuables
- [ ] figure out how to handle food goods and water
- [ ] prune stations that lead to dead ends
    - when stations are found for an origin, it's not known if there are cargo routes all the way to a town
    - pruning would be a good addition to not track cargo that goes down dead ends
    - dead ends include force unloads, transfers to nowhere, and routes that terminate at an intermediary
    - may need some singly linked lists from origins to destinations to help with pruning

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
- Aim to capture all changes to things as stats, city & industry growth, delivery route stats including stations &
  vehicles,

https://docs.openttd.org/gs-api/globals

https://docs.openttd.org/gs-api/classGSDate

refer to this for tick
info https://github.com/OpenTTD/OpenTTD/blob/0d599e155f335e922ad2be738a3ab73d1dea346b/src/date_type.h#L34

this list gives pretty good hints as to what types exist

https://docs.openttd.org/gs-api/classGSTown

tested so far, upgrades or builds 100 houses in all towns, even if the game is paused

```squirrel
local allTowns = GSTownList();
foreach (townId, _ in allTowns) {
    GSTown.ExpandTown(townId, 100)
}
```

// since towns will grow a lot it, resetting the ratings to neutral will help with demolishing buildings, roads and
bridges that are in the way
static bool GSTown::ChangeRating(TownID town_id, GSCompany::CompanyID company_id, int delta)

delta How much to change rating by (range -1000 to +1000).
enum GSTown::TownRating

// could be useful for cargo tracking, although need to carefully link the exact factory to a destination
static int GSTown::GetLastMonthProduction(TownID town_id, CargoType cargo_type)
static int GSTown::GetLastMonthReceived(TownID town_id, GSCargo::TownEffect towneffect_id)
static int GSTown::GetLastMonthSupplied(TownID town_id, CargoType cargo_type)

https://docs.openttd.org/gs-api/classGSIndustry

static int GetProductionLevel(IndustryID industry_id)
static bool GSIndustry::SetProductionLevel(IndustryID industry_id, int prod_level, bool show_news, Text * custom_news)

https://docs.openttd.org/gs-api/classGSBaseStation
https://docs.openttd.org/gs-api/classGSStation
https://docs.openttd.org/gs-api/classGSCargo
https://docs.openttd.org/gs-api/classGSGame
https://docs.openttd.org/gs-api/classGSSign
https://docs.openttd.org/gs-api/classGSVehicle
static Money GetRunningCost (VehicleID vehicle_id)
static Money GetProfitThisYear (VehicleID vehicle_id)
static Money GetProfitLastYear (VehicleID vehicle_id)
https://docs.openttd.org/gs-api/classGSStoryPage
https://docs.openttd.org/gs-api/annotated
https://docs.openttd.org/gs-api/classGSNews
it's possible to create news

# Allocating cargo to towns

- With cargo monitoring, find how much each industry supplied and how much each town received.
- Use the route data above to which industry supplied each portion.
    - If multiple industries ship to multiple towns it will be impossible to calculate exactly how much went to each
      town
    - It will have to be approximated (see if it's possible to access station ratings)
- Grow each town based on how much was delivered (regardless of where it was from)
- If demand at a town was exceeded (come up with some formula for demand, make it configurable) expand the original
  industries
    - sort the industries by which supplied the most to the town
    - grow the first industry with more than 80% transported

Plan A

- [x] when tracking cargo hops, keep origin station id that it started from
- [x] when tracking to a destination in the hop tracking, add it as a confirmed station
- [ ] also when tracking to a destination add origins to destinations???
- [x] then destinations will have the correct mapping to use for cargo tracking, both from origins and to destinations
    - [x] to make that work it will need
        - [x] origins: stationId, industryId
        - [x] destinations: stationId, townId
    - [x] in both cases stationId gives companyId
- [ ] with that mapping in place use cargo monitoring to get a count of how much was sent and received
    - [ ] prior to expanding towns and industries, accounting needs to be done
        - [ ] use cargo monitoring to get the exact amounts in the last month
            - [ ] this is not going to be 100% accurate as there is latency between sending and receiving
        - [ ] accounting: add cargo shipped, subtract cargo received
            - [ ] hopefully it's impossible for this to be negative
            - [ ] assume cargo is evenly distributed between destinations
                - [ ] this assumption may be necessary until I find a way to track how much cargo passes through each
                  station at each hop
            - [ ] due to the latency between sending and receiving, the overall balance may always be positive
            - [ ] where demand is lacking, grow industries evenly (so with a bias toward smaller industries so they catch up
              to larger producers)
        - [ ] example scenario:
            - [ ] industry A produces 4 cargo & supplies town A & B
            - [ ] industry B produces 2 cargo & supplies town A
            - [ ] industry C produces 1 cargo & supplies town B
            - [ ] town A receives 5/6
            - [ ] town B receives 2/5
            - [ ] overall 7 produced, and 7 received
            - [ ] if demand is not met in town A, then industry A and B should scale up, starting with industry B since it's smaller
              - [ ] in a following cycle, given that industry production doubles when it is increased, industry A & B would be equal in size, and either could scale
            - [ ] if demand is not met in town B, then industry A and C should scale up, starting with industry C since it's smaller
              - [ ] in a following cycle, given that industry production doubles when it is increased, industry C would still be smaller than A, and remains the preferred industry for growth
            - [ ] if demand is met in either town, the town should expand, and this will increase the demand for the next cycle
    
Plan B (or step 2)
    - factor in transport percentages before deciding what industry to expand
        - example scenario (WIP account for numbers being inaccurate between monitoring and transport percentages)
            - industry A produces 4 cargo (100% is transported) & supplies town A & B
            - industry B produces 3 cargo (67% is transported) & supplies town A
            - industry C produces 4 cargo (25% is transported) & supplies town B
            - overall 7 produced, and 7 received
            - if demand is not met in town A, then industry A and B should scale up, starting with industry A since it that delivery route is not fully saturated with cargo
            - if demand is not met in town B, then industry A and C should scale up, starting with industry A since it that delivery route is not fully saturated with cargo