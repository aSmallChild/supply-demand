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
        GSLog.Info("");
        GSLog.Info("Running for month: " + formatDate(lastRunDate));

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
        origins = pruneDeadEnds(origins);
        GSLog.Info(origins.len() + " origins found");
        foreach (i, origin in origins) {
            local industryName = GSIndustry.GetName(origin.industryId);
            local cargoName = GSCargo.GetName(origin.cargoId);
            local townList = "";
            foreach (j, townId in origin.destinationTownIds) {
                local townName = GSTown.GetName(townId);
                townList += (townList ? "" : ", ") + GSTown.GetName(townId);
            }
            townList += ".";
            GSLog.Info("#" + i + " raw " + cargoName + " from " + industryName + " feeds " + origin.destinationTownIds.len() + " town(s): " + townList);
        }
    }
}

//GSCargoMonitor.GetTownDeliveryAmount(companyId, cargoType, townId, true)
//GSCargoMonitor.GetIndustryDeliveryAmount(companyId, cargoType, industryId, true)
//GSCargoMonitor.GetTownPickupAmount(companyId, cargoType, townId, true)
//GSCargoMonitor.GetIndustryPickupAmount(companyId, cargoType, industryId, true)

function trackDeliveries(origins) {
    local taskQueue = [];
    foreach (origin in origins) {
        foreach (stationId in origin.possibleStationIds) {
            addTask(taskQueue, origin, stationId, origin.cargoId, stationId);
        }
    }

    local processedStationCargos = {};
    while (taskQueue.len() > 0) {
        local task = taskQueue.pop();
        local stationCargoKey = task.hopStationId + "_" + task.cargoId;

        if (stationCargoKey in processedStationCargos) {
            processedStationCargos[stationCargoKey].origins.append(task.origin);
            continue;
        }
        processedStationCargos[stationCargoKey] <- {
            cargoId = task.cargoId,
            origins = [task.origin]
        };
        trackDeliveryHop(task, taskQueue);
    }

    foreach (key, cacheEntry in processedStationCargos) {
        if (cacheEntry.origins.len() < 2) {
            continue;
        }
        local firstOrigin = cacheEntry.origins[0];
        for (local i = 1; i < cacheEntry.origins.len(); i++) {
            foreach (townId in cacheEntry.origins[i].destinationTownIds) {
                if (!listContains(firstOrigin.destinationTownIds, townId)) {
                    firstOrigin.destinationTownIds.append(townId);
                }
            }
        }
    }
}

function trackDeliveryHop(task, taskQueue) {
    local vehicles = GSVehicleList_Station(task.hopStationId);
    foreach (vehicleId, _ in vehicles) {
        local capacity = GSVehicle.GetCapacity(vehicleId, task.cargoId);

        if (capacity < 1) {
            continue;
        }
        local orderCount = GSOrder.GetOrderCount(vehicleId);
        local startOrderPositions = [];
        for (local i = 0; i < orderCount; i++) {
            local orderStationId = GSStation.GetStationID(GSOrder.GetOrderDestination(vehicleId, i));
            if (orderStationId == task.hopStationId && canLoad(GSOrder.GetOrderFlags(vehicleId, i))) {
                startOrderPositions.append(i);
            }
        }

        foreach (startPosition in startOrderPositions) {
            for (local i = 0; i < orderCount - 1; i++) {
                local orderPosition = (startPosition + i + 1) % orderCount;
                local orderFlags = GSOrder.GetOrderFlags(vehicleId, orderPosition);
                local nextStationId = GSStation.GetStationID(GSOrder.GetOrderDestination(vehicleId, orderPosition));
                if (isTransfer(orderFlags)) {
                    addTask(taskQueue, task.origin, nextStationId, task.cargoId, task.originStationId);
                    break;
                }

                if (!canUnload(orderFlags)) {
                    continue;
                }

                local recipients = stationCargoRecipients(nextStationId, task.cargoId);
                if (!recipients) {
                    if (isForceUnload(orderFlags)) {
                        break;
                    }
                    continue;
                }

                if (recipients.townIds) {
                    foreach (townId in recipients.townIds) {
                        if (!listContains(task.origin.destinationTownIds, townId)) {
                            task.origin.destinationTownIds.append(townId);
                        }
                        if (!listContains(task.origin.originStationIds, task.originStationId)) {
                            task.origin.originStationIds.append(task.originStationId);
                        }
                        if (!listContains(task.origin.destinationStationIds, nextStationId)) {
                            task.origin.destinationStationIds.append(nextStationId);
                        }
                    }
                    break;
                }

                if (recipients.nextCargoIds && recipients.nextIndustryIds) {
                    foreach (industryId in recipients.nextIndustryIds) {
                        local industryStationIds = getIndustryStations(industryId);
                        foreach (industryStationId in industryStationIds) {
                            foreach (nextCargoId in recipients.nextCargoIds) {
                                addTask(taskQueue, task.origin, industryStationId, nextCargoId, task.originStationId);
                            }
                        }
                    }
                    break;
                }
            }
        }
    }
}
