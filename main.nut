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

//        local towns = GSTownList();
//        foreach (townId, _ in towns) {
////            local received = GSTown.GetLastMonthReceived(townId, GSCargo::TownEffect towneffect_id)
//            foreach (cargoType, _ in cargoTypes) {
//                local supplied = GSTown.GetLastMonthSupplied(townId, cargoType);
//                if (supplied < 1) {
//                    continue;
//                }
//                local production = GSTown.GetLastMonthProduction(townId, cargoType);
////                if (production) {
////                    local townName = GSTown.GetName(townId);
////                    local cargoName = GSCargo.GetName(cargoType);
////                    GSLog.Info(townName + " produced " + production + " " + cargoName)
////                }
//                if (supplied) {
//                    local townName = GSTown.GetName(townId);
//                    local cargoName = GSCargo.GetName(cargoType);
//                    GSLog.Info(townName + " supplied " + supplied + " " + cargoName);
//                }
//
//            }
//        }

        local industries = GSIndustryList();
        local taskQueue = [];
        foreach (industryId, _ in industries) {
            local stations = getIndustryStations(industryId);
            if (stations.len() < 1) {
                continue;
            }

            local industryName = GSIndustry.GetName(industryId);
            foreach (cargoType, _ in cargoTypes) {
                local transported = GSIndustry.GetLastMonthTransported(industryId, cargoType);
                if (transported < 1) {
                    continue;
                }
                local transportedPercent = GSIndustry.GetLastMonthTransportedPercentage(industryId, cargoType);

                foreach (stationId in stations) {
                    local cargoRating = GSStation.GetCargoRating(stationId, cargoType);
                    if (cargoRating < 1) {
                        continue;
                    }
                    taskQueue.append({
                        date = currentDate,
                        origIndustryId = industryId,
                        origCargoId = cargoType,
                        origStationId = stationId,
                        origCargoRating = cargoRating,
                        origTownId = GSStation.GetNearestTown(stationId),
                        transported = transported,
                        transportedPercent = transportedPercent,
                        destIndustryId = null,
                        destStationId = null,
                        destTownId = null
                        destCargoId = null
                    });
                }
            }
        }

        processTaskQueue(taskQueue);
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

function processTaskQueue(queue) {
    foreach (task in queue) {
        processTask(task);
    }
}

function processTask(task) {
    local industryName = GSIndustry.GetName(task.origIndustryId);
    local cargoName = GSCargo.GetName(task.origCargoId);
    local stationName = GSStation.GetName(task.origStationId);

    GSLog.Info("On " + formatDate(task.date) + ", " + industryName + " shipped " + task.transported + " " + cargoName + " from " + stationName + " with a rating of " + task.origCargoRating + "%");
    local vehicles = GSVehicleList_Station(task.origStationId);
    foreach (vehicleId, _ in vehicles) {
        if (GSVehicle.GetCapacity(vehicleId, task.origCargoId) < 1) {
            continue;
        }
        local orderCount = GSOrder.GetOrderCount(vehicleId);
        local startOrderPositions = [];
        for (local i = 0; i < orderCount; i++) {
            local stationId = GSStation.GetStationID(GSOrder.GetOrderDestination(vehicleId, i));
            if (stationId == task.origStationId && canLoad(GSOrder.GetOrderFlags(vehicleId, i))) {
                startOrderPositions.append(i);
            }
        }
        GSLog.Info(GSVehicle.GetName(vehicleId) + " leaves this station with caries said cargo. It has " + orderCount + " orders" + startOrderPositions.len() + " of which is/are to load at this station");
        foreach (startPosition in startOrderPositions) {
            for (local i = 0; i < orderCount - 1; i++) {
                local orderPosition = (i + startPosition + 1) % orderCount;
                local orderFlags = GSOrder.GetOrderFlags(vehicleId, i);
                if (!canUnload(orderFlags)) {
                    continue;
                }
                local stationId = GSStation.GetStationID(GSOrder.GetOrderDestination(vehicleId, orderPosition));
                local cargoAcceptedTile = stationAcceptsCargo(stationId, task.origCargoId);
                if (cargoAcceptedTile) {
                    task.destIndustryId = GSIndustry.GetIndustryID(cargoAcceptedTile); // could technically be a town tile
                    GSLog.Info("This cargo is dropped off and accepted at " + GSStation.GetName(stationId));
                    // todo find industry and or town
                }
            }
            // need to know if it is a town that accepts goods
        }


        // check the order flags to see if there is an unload or transfer
        // for unload check if it is the final destination in which case track deliveries and link to source
        // for transfer, rinse and repeat from that station
        // local otherStations = GSStationList_Vehicle(vehicleId) shouldn't need this
    }
}

function stationAcceptsCargo(stationId, cargoId) {
    // todo I expect this doesn't work correctly for goods
    local coverageTiles = GSTileList_StationCoverage(stationId);
    foreach (tile, _ in coverageTiles) {
        if (GSTile.GetCargoAcceptance(tile, cargoId, 1, 1, 1) > 0) {
            return tile;
        }
    }
    return null;
}

function canLoad(orderFlags) {
    if (orderFlags == GSOrder.OF_NONE) {
        return true;
    }

    if (orderFlags & (GSOrder.OF_NO_LOAD | GSOrder.OF_NON_STOP_DESTINATION)) {
        return false;
    }

    if (orderFlags & (GSOrder.OF_TRANSFER | GSOrder.OF_UNLOAD)) {
        return false;
    }

    return true;
}

function canUnload(orderFlags) {
    if (orderFlags == GSOrder.OF_NONE) {
        return true;
    }

    if (orderFlags & (GSOrder.OF_NO_UNLOAD | GSOrder.OF_NON_STOP_DESTINATION)) {
        return false;
    }

    return true;
}
