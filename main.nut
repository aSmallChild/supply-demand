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
//        findDestinations(origins);
    }
}

function processOrigins(origins) {
    local processedStations = {};
    foreach (origin in origins) {
        local stationCargoKey = origin.stationId + "_" + origin.cargoId;
        if (stationCargoKey in processedStations) {
            origin.destinations.extend(processedStations[stationCargoKey]);
        } else {
            // todo use stationAcceptingTowns to help find destinations
            local destinations = findDestinations(origin.stationId, origin.cargoId);
            processedStations[stationCargoKey] <- destinations;
            origin.destinations.extend(destinations);
        }
    }
    return origins;
}

//GSCargoMonitor.GetTownDeliveryAmount(companyId, cargoType, townId, true)
//GSCargoMonitor.GetIndustryDeliveryAmount(companyId, cargoType, industryId, true)
//GSCargoMonitor.GetTownPickupAmount(companyId, cargoType, townId, true)
//GSCargoMonitor.GetIndustryPickupAmount(companyId, cargoType, industryId, true)

function processTask(task, industryDeliverySources) {
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
        GSLog.Info(GSVehicle.GetName(vehicleId) + " leaves this station with caries said cargo. It has " + orderCount + " orders " + startOrderPositions.len() + " of which is/are to load at this station");
        foreach (startPosition in startOrderPositions) {
            for (local i = 0; i < orderCount - 1; i++) {
                local orderPosition = (i + startPosition + 1) % orderCount;
                local orderFlags = GSOrder.GetOrderFlags(vehicleId, orderPosition);
                if (!canUnload(orderFlags)) {
                    continue;
                }
                local stationId = GSStation.GetStationID(GSOrder.GetOrderDestination(vehicleId, orderPosition));
                local acceptingTowns = stationAcceptingTowns(stationId, cargoId);
                if (acceptingTowns.len() < 1) {
                    continue;
                }

                // if it is an intermediatry, find the next cargo types
                // for each industry see if it is the end of a chain
            }
        }


        // check the order flags to see if there is an unload or transfer
        // for unload check if it is the final destination in which case track deliveries and link to source
        // for transfer, rinse and repeat from that station
        // local otherStations = GSStationList_Vehicle(vehicleId) shouldn't need this
    }
}
