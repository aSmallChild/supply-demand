require("util.nut");
require("cargo.nut");

class SupplyDemand extends GSController {
    constructor() {
    }
}

function SupplyDemand::Start() {
    local lastRunDate = GSDate.GetCurrentDate(); // todo save & load this from game state
    GSLog.Info("Script started, game date: " + formatDate(lastRunDate));
    categorizeAllCargoTypes();

    local nextRunDate = getStartOfNextMonth(lastRunDate);
    while (true) {
        this.Sleep(74 * 3) // 3 days
        if (GSGame.IsPaused()) {
            continue;
        }

        local currentDate = GSDate.GetCurrentDate();
        if (nextRunDate > currentDate) {
            continue;
        }
        lastRunDate = nextRunDate;
        nextRunDate = getStartOfNextMonth(nextRunDate);
        GSLog.Info("");
        GSLog.Info("Month: " + formatDate(lastRunDate) + ", started processing on " + formatDate(currentDate));
        logIfBehindSchedule(lastRunDate, currentDate);
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
        // todo store contents of caches when saving and loading game

        local origins = findOriginIndustries(currentDate);
        trackDeliveries(origins);
        local groups = groupDestinationsAndOrigins(origins);
        origins = groups.origins;
//        GSLog.Info(origins.len() + " origins found");
//        foreach (i, origin in origins) {
//            local industryName = GSIndustry.GetName(origin.industryId);
//            local cargoName = GSCargo.GetName(origin.cargoId);
//            local townList = "";
//            foreach (j, townId in origin.destinationTownIds) {
//                local townName = GSTown.GetName(townId);
//                townList += (townList ? "" : ", ") + GSTown.GetName(townId);
//            }
//            townList += ".";
//            GSLog.Info("#" + (i + 1) + " raw " + cargoName + " from " + industryName + " feeds " + origin.destinationTownIds.len() + " town(s): " + townList);
//        }
//
//        local destinations = groups.destinations;
//        GSLog.Info("=== DESTINATION ANALYSIS ===");
//        GSLog.Info("Found " + destinations.len() + " destinations");
//        GSLog.Info("");

//        foreach (i, destination in destinations) {
//            local townName = GSTown.GetName(destination.townId);
//            GSLog.Info("Destination #" + (i + 1) + ": " + townName);
//            GSLog.Info("  Received cargo: " + destination.receivedCargo);
//
//            // Origin industries
//            if (destination.originIndustryIds.len() == 0) {
//                GSLog.Info("  Origin industries: (none)");
//            } else {
//                GSLog.Info("  Origin industries (" + destination.originIndustryIds.len() + "):");
//                foreach (j, industryId in destination.originIndustryIds) {
//                    local industryName = GSIndustry.GetName(industryId);
//                    GSLog.Info("    " + (j + 1) + ". " + industryName + " (ID: " + industryId + ")");
////                    GSIndustry.GetLastMonthTransportedPercentage(industryId, cargo_type) ??
//                    local productionLevel = GSIndustry.GetProductionLevel(industryId);
//                    productionLevel += 2;
//                    if (productionLevel > 128) {
//                        productionLevel = 128;
//                    }
////                    GSIndustry.SetProductionLevel(industryId, productionLevel, false, "");
//                    GSIndustry.SetProductionLevel(industryId, 128, false, "");
//                    foreach (cargoType, _ in GSIndustryType.GetProducedCargo(GSIndustry.GetIndustryType(industryId))) {
//                        local prod = GSIndustry.GetLastMonthProduction(industryId, cargoType);
//                        local cargoName = GSCargo.GetName(cargoType);
//                        GSLog.Info("        Produced " + prod + " " + cargoName);
//                    }
//                    // 540 cargo from level 64
//                    // 1080 cargo from level 128
//                }
//            }
//
//            // Destination stations
//            if (destination.destinationStationIds.len() == 0) {
//                GSLog.Info("  Destination stations: (none)");
//            } else {
//                GSLog.Info("  Destination stations (" + destination.destinationStationIds.len() + "):");
//                foreach (j, stationId in destination.destinationStationIds) {
//                    local stationName = GSStation.GetName(stationId);
//                    GSLog.Info("    " + (j + 1) + ". " + stationName);
//                }
//            }
//
//            // Destination industries
//            if (destination.destinationIndustryIds.len() == 0) {
//                GSLog.Info("  Destination industries: (none)");
//            } else {
//                GSLog.Info("  Destination industries (" + destination.destinationIndustryIds.len() + "):");
//                foreach (j, industryId in destination.destinationIndustryIds) {
//                    local industryName = GSIndustry.GetName(industryId);
//                    GSLog.Info("    " + (j + 1) + ". " + industryName);
//                }
//            }
//
//            // Destination cargo types
//            if (destination.destinationCargoIds.len() == 0) {
//                GSLog.Info("  Destination cargo types: (none)");
//            } else {
//                GSLog.Info("  Destination cargo types (" + destination.destinationCargoIds.len() + "):");
//                foreach (j, cargoId in destination.destinationCargoIds) {
//                    local cargoName = GSCargo.GetName(cargoId);
//                    GSLog.Info("    " + (j + 1) + ". " + cargoName);
//                }
//            }
//
//            GSLog.Info(""); // Empty line between destinations
//        }
//        GSLog.Info("=== END DESTINATION ANALYSIS ===");

        CargoTracker.update(lastRunDate);
        processTowns();

        GSLog.Info("Month: " + formatDate(lastRunDate) + " started on " + formatDate(currentDate) + " and finished processing on: " + formatDate(GSDate.GetCurrentDate()));
    }
}

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
        local stationCargoKey = task.hopStationId + "_" + task.cargoId + "_" + task.originStationId;

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
                addUnique(firstOrigin.destinationTownIds, townId);
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
                    local companyId = GSVehicle.GetOwner(vehicleId);
                    registerDestination(task, recipients, nextStationId, companyId);
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


// then see how much the town is receiving, and deterime how much it should grow
    // add bonus growth if there was a surplus
    // add bonus growth based on the number of origin cargo ids
// then see if it received more than it needs and if not expand the origin industries so they can supply more
