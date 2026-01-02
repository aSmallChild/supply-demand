require("util.nut");
require("cargo.nut");

class SupplyDemand extends GSController {
    static runIntervalMonths = 3;
    nextRunDate = null;
    constructor() {
    }
}

function SupplyDemand::Start() {
    local lastRunDate = GSDate.GetCurrentDate(); // todo save & load this from game state
    GSLog.Info("Script started, game date: " + formatDate(lastRunDate));
    categorizeAllCargoTypes();

    if (!this.nextRunDate) {
        this.nextRunDate = getStartOfNextMonth(lastRunDate, SupplyDemand.runIntervalMonths);
    }
    while (true) {
        this.Sleep(74 * 3) // 3 days
        if (GSGame.IsPaused()) {
            continue;
        }
        local currentDate = GSDate.GetCurrentDate();
        if (this.nextRunDate > currentDate) {
            continue;
        }
        lastRunDate = this.nextRunDate;
        this.nextRunDate = getStartOfNextMonth(this.nextRunDate, SupplyDemand.runIntervalMonths);
        GSLog.Info("");
        GSLog.Info("Month: " + formatDate(lastRunDate) + ". Started processing on " + formatDate(currentDate) + ". Next run date: " + this.nextRunDate);
        logIfBehindSchedule(lastRunDate, currentDate);

        local origins = findOrigins(currentDate);
        trackDeliveries(origins);
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
        local capacity = GSVehicle.GetCapacity(vehicleId, task.cargoId); // todo test orders with refits

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

function SupplyDemand::Save()
{
	return {
		nextRunDate = this.nextRunDate,
        // todo there is some recursive nesting on this data so it is more than 25 levels of nesting, flatten before saving, reconstruct after loading
//		trackedCargo = CargoTracker.trackedCargo,
//		towns = CargoTracker.towns,
	};
}

function SupplyDemand::Load(version, saveData)
{
    if ("nextRunDate" in saveData) {
        this.nextRunDate = saveData.nextRunDate;
        GSLog.Info("Game loaded, next run date: " + formatDate(this.nextRunDate));
    }

//    if ("trackedCargo" in saveData) {
//        CargoTracker.load(saveData.trackedCargo, saveData.towns);
//    }
}
