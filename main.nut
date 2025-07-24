require("util.nut");

class SupplyDemand extends GSController {
    constructor() {
    }
}

function SupplyDemand::Start() {
    local lastRunDate = GSDate.GetCurrentDate(); // todo save & load this from game state
    GSLog.Info("Script started, game date: " + formatDate(lastRunDate));

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

        local origins = findOriginIndustries(currentDate);
        trackDeliveries(origins);
        // todo monitor cargo, and determine how much each industry should grow bearing in mind that meetind demand will lag behind deliveries
    }
}

//GSCargoMonitor.GetTownDeliveryAmount(companyId, cargoType, townId, true)
//GSCargoMonitor.GetIndustryDeliveryAmount(companyId, cargoType, industryId, true)
//GSCargoMonitor.GetTownPickupAmount(companyId, cargoType, townId, true)
//GSCargoMonitor.GetIndustryPickupAmount(companyId, cargoType, industryId, true)

function trackDeliveries(origins) {
    local taskQueue = [];
    foreach (origin in origins) {
        addTask(taskQueue, origin, origin.stationId, origin.cargoId);
    }

    local processedStationCargos = {};
    while (taskQueue.len() > 0) {
        local task = taskQueue.pop();
        local stationCargoKey = task.stationId + "_" + task.cargoId;
        if (stationCargoKey in processedStationCargos) {
            processedStationCargos[stationCargoKey].origins.append(origin);
            continue;
        }

        processedStationCargos[stationCargoKey] <- {
            cargoId = task.cargoId,
            origins = [task.origin]
        };
        trackDeliveryHop(task.origin, task.stationId, task.cargoId, taskQueue);
    }

    foreach (key, cacheEntry in processedStationCargos) {
        if (cacheEntry.origins.len() < 2) {
            continue;
        }
        local firstOrigin = cacheEntry.origins[0];
        for (local i = 1; i < cacheEntry.origins.len(); i++) {
            cacheEntry.origins[i].destinations.extend(firstOrigin.destinations);
        }
    }
}

function trackDeliveryHop(origin, stationId, cargoId, taskQueue) {
    local vehicles = GSVehicleList_Station(stationId);
    foreach (vehicleId, _ in vehicles) {
        if (GSVehicle.GetCapacity(vehicleId, cargoId) < 1) {
            continue;
        }
        local orderCount = GSOrder.GetOrderCount(vehicleId);
        local startOrderPositions = [];
        for (local i = 0; i < orderCount; i++) {
            local orderStationId = GSStation.GetStationID(GSOrder.GetOrderDestination(vehicleId, i));
            if (orderStationId == stationId && canLoad(GSOrder.GetOrderFlags(vehicleId, i))) {
                startOrderPositions.append(i);
            }
        }
        local unloadFound = false;
        foreach (startPosition in startOrderPositions) {
            for (local i = 0; i < orderCount - 1; i++) {
                local orderPosition = (i + startPosition + 1) % orderCount;
                local orderFlags = GSOrder.GetOrderFlags(vehicleId, orderPosition);
                local nextStationId = GSStation.GetStationID(GSOrder.GetOrderDestination(vehicleId, orderPosition));
                if (isTransfer(orderFlags)) {
                    addTask(taskQueue, origin, nextStationId, cargoId);
                    break;
                }

                if (!canUnload(orderFlags)) {
                    continue;
                }

                local recipients = stationCargoRecipients(nextStationId, cargoId);
                if (!recipients) {
                    if (isForceUnload(orderFlags)) {
                        break;
                    }
                    continue;
                }

                if (recipients.townIds) {
                    foreach (townId in recipients.townIds) {
                        if (!listContains(origin.destinations, townId)) {
                            origin.destinations.append(townId);
                        }
                    }
                    break;
                }

                if (recipients.nextCargoIds) {
                    foreach (nextCargoId in recipients.nextCargoIds) {
                        addTask(taskQueue, origin, nextStationId, nextCargoId);
                    }
                    break;
                }
            }
        }
    }
}
