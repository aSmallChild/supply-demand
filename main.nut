local MAX_CARGOTYPES = 64;
class SupplyDemand extends GSController {
    constructor() {
    }
}

function SupplyDemand::Start() {
    local lastRunDate = GSDate.GetCurrentDate(); // todo save & load this from game state
    GSLog.Info("Script started, game date: " + formatDate(lastRunDate));
    local cargoTypes = GSCargoList();
//    foreach (cargoType, _ in cargoTypes) {
//        GSLog.Info(cargoType + " - " + GSCargo.GetCargoLabel(cargoType) + " - " + GSCargo.GetName(cargoType));
//    }

    local nextRunDate = getStartOfNextMonth(lastRunDate);
    while (true) {
        this.Sleep(74 * 3) // 3 days
        if (GSGame.IsPaused()) {
            continue;
        }

        local currentDate = GSDate.GetCurrentDate();
        if (nextRunDate > currentDate) {
            // todo log and error if it's more than a month behind the games current date
            continue;
        }
        lastRunDate = nextRunDate;
        nextRunDate = getStartOfNextMonth(nextRunDate);
        GSLog.Info(" ### ");
        GSLog.Info("Running for month: " + formatDate(lastRunDate));
        GSLog.Info(" ### ");

        local towns = GSTownList();
        foreach (townId, _ in towns) {
//            local received = GSTown.GetLastMonthReceived(townId, GSCargo::TownEffect towneffect_id)
            foreach (cargoType, _ in cargoTypes) {
                local supplied = GSTown.GetLastMonthSupplied(townId, cargoType);
                if (supplied < 1) {
                    continue;
                }
                local production = GSTown.GetLastMonthProduction(townId, cargoType);
                if (production) {
                    local townName = GSTown.GetName(townId);
                    local cargoName = GSCargo.GetName(cargoType);
                    GSLog.Info(townName + " produced " + production + " " + cargoName)
                }
                if (supplied) {
                    local townName = GSTown.GetName(townId);
                    local cargoName = GSCargo.GetName(cargoType);
                    GSLog.Info(townName + " supplied " + supplied + " " + cargoName)
                }

            }
        }

        local industries = GSIndustryList();
        foreach (industryId, _ in industries) {
            local stations = getIndustryStations(industryId);
            if (stations.len() < 1) {
                continue;
            }

            local industryName = GSIndustry.GetName(industryId);
            local hasTransported = false;
            foreach (cargoType, _ in cargoTypes) {
                local transported = GSIndustry.GetLastMonthTransported(industryId, cargoType);
                if (transported < 1) {
                    continue;
                }
                hasTransported = true;
                local production = GSIndustry.GetLastMonthProduction(industryId, cargoType);
                local transportedPercentage = GSIndustry.GetLastMonthTransportedPercentage(industryId, cargoType);
                local cargoName = GSCargo.GetName(cargoType);
                if (production > 0) {
                    GSLog.Info(industryName + " produced " + production + " " + cargoName)
                }
                if (transported > 0) {
                    GSLog.Info(industryName + " transported " + transported + "(" + transportedPercentage + "%) " + cargoName)
                }
            }

            if (!hasTransported) {
                continue;
            }

            GSLog.Info(industryName + " has " + stations.len() + " stations that could be delivering this cargo")
            foreach (i, stationId in stations) {
                GSLog.Info("station " + i + " - " + GSStation.GetName(stationId))
            }
        }
    }
}

//GSCargoMonitor.GetTownDeliveryAmount(companyId, cargoType, townId, true)
//GSCargoMonitor.GetIndustryDeliveryAmount(companyId, cargoType, industryId, true)
//GSCargoMonitor.GetTownPickupAmount(companyId, cargoType, townId, true)
//GSCargoMonitor.GetIndustryPickupAmount(companyId, cargoType, industryId, true)

function formatDate(date) {
    local month = GSDate.GetMonth(date);
    local day = GSDate.GetDayOfMonth(date);
    return GSDate.GetYear(date) + "-" + (month < 10 ? "0" : "") + month + "-" + (day < 10 ? "0" : "") + day;
}

function getStartOfNextMonth(date) {
    local year = GSDate.GetYear(date);
    local month = GSDate.GetMonth(date) + 1;
    if (month > 12) {
        month = 1;
        year++;
    }
    return GSDate.GetDate(year, month, 1);
}

function getIndustryStations(industryId) {
    local stationCount = GSIndustry.GetAmountOfStationsAround(industryId);
    if (stationCount < 1) {
        return [];
    }

    local industryTile = GSIndustry.GetLocation(industryId);
    local stations = GSStationList(GSStation.STATION_ANY);
    local stationDistances = [];
    foreach (stationId, _ in stations) {
        local distance = GSStation.GetDistanceManhattanToTile(stationId, industryTile);
        stationDistances.append({
            id = stationId,
            distance = distance
        });
    }

    stationDistances.sort(function(a, b) {
        if (a.distance > b.distance) return 1;
        if (a.distance < b.distance) return -1;
        return 0;
    });

    local sortedList = [];
    foreach (entry in stationDistances) {
        local coverageTiles = GSTileList_StationCoverage(entry.id);
        foreach (tile, _ in coverageTiles) {
            if (GSIndustry.GetIndustryID(tile) == industryId) {
                sortedList.append(entry.id);
                if (sortedList.len() >= stationCount) {
                    return sortedList;
                }
                break;
            }
        }
    }
    return sortedList;
}
