function listContains(haystack, needle) {
    foreach (k, v in haystack) {
        if (v == needle) {
            return true;
        }
    }
    return false;
}

function addUnique(list, value) {
    if (listContains(list, value)) {
        return false;
    }
    list.append(value);
    return true;
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

function isTransfer(orderFlags) {
    if (orderFlags == GSOrder.OF_NONE) {
        return false;
    }

    if (orderFlags & GSOrder.OF_NON_STOP_DESTINATION) {
        return false;
    }

    if (orderFlags & GSOrder.OF_TRANSFER) {
        return true;
    }

    return false;
}

function isForceUnload(orderFlags) {
    if (orderFlags == GSOrder.OF_NONE) {
        return false;
    }

    if (orderFlags & GSOrder.OF_NON_STOP_DESTINATION) {
        return false;
    }

    if (orderFlags & GSOrder.OF_UNLOAD) {
        return true;
    }

    return false;
}

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

function logIfBehindSchedule(lastRunDate, currentDate) {
    local currentYear = GSDate.GetYear(currentDate);
    local currentMonth = GSDate.GetMonth(currentDate);
    local nextRunYear = GSDate.GetYear(lastRunDate);
    local nextRunMonth = GSDate.GetMonth(lastRunDate);

    local monthsBehind = (currentYear - nextRunYear) * 12 + (currentMonth - nextRunMonth);

    if (monthsBehind > 1) {
        GSLog.Error("Script is running " + monthsBehind + " months behind schedule!");
        GSLog.Error("Current: " + formatDate(currentDate) + " vs Expected: " + formatDate(lastRunDate));
    } else if (monthsBehind > 0) {
        GSLog.Warning("Script is " + monthsBehind + " month behind schedule.");
    }
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

function getTownIdFromIndustryId(industryId) {
    return GSTile.GetClosestTown(GSIndustry.GetLocation(industryId));
}

/**
 * return the towns that are the final destination for this cargo, or the industries that are intermediarys
 */
function stationCargoRecipients(stationId, cargoId) {
    if (!GSCargoList_StationAccepting(stationId).HasItem(cargoId)) {
        return null;
    }

    local acceptingTowns = [];
    local acceptingIndustries = [];
    local nextCargoIds = [];
    local coverageTiles = GSTileList_StationCoverage(stationId);
    foreach (tile, _ in coverageTiles) {
        local industryId = GSIndustry.GetIndustryID(tile);
        if (listContains(acceptingIndustries, industryId) || GSIndustry.IsCargoAccepted(industryId, cargoId) != GSIndustry.CAS_ACCEPTED) {
            continue;
        }
        acceptingIndustries.append(industryId);
        addUnique(acceptingTowns, getTownIdFromIndustryId(industryId));
        local industryType = GSIndustry.GetIndustryType(industryId);
        local producedCargos = GSIndustryType.GetProducedCargo(industryType);
        if (producedCargos.Count() < 1) {
            continue;
        }
        foreach (producedCargoId, _ in producedCargos) {
            addUnique(nextCargoIds, producedCargoId);
        }
    }

    foreach (nextCargoId in nextCargoIds) {
        if (nextCargoId == cargoId) {
            nextCargoIds = [];
            break;
        }
    }

    if (nextCargoIds.len() < 1 && acceptingTowns.len() < 1) {
        return {
            townIds = [GSStation.GetNearestTown(stationId)],
            industryIds = acceptingIndustries,
            nextCargoIds = null,
            nextIndustryIds = null,
        };
    }

    if (nextCargoIds.len() < 1) {
        return {
            townIds = acceptingTowns,
            industryIds = acceptingIndustries,
            nextCargoIds = null,
            nextIndustryIds = null
        };
    }

    return {
        townIds = null,
        industryIds = null,
        nextCargoIds = nextCargoIds,
        nextIndustryIds = acceptingIndustries,
    };
}

function findOriginIndustries(currentDate) {
    local validOriginTypes = getValidOriginIndustryTypes();
    local industries = GSIndustryList();
    local origins = [];
    foreach (industryId, _ in industries) {
        local industryType = GSIndustry.GetIndustryType(industryId);

        local isValid = false;
        foreach (validType in validOriginTypes) {
            if (validType == industryType) {
                isValid = true;
                break;
            }
        }
        if (!isValid) {
            continue;
        }

        local currentLevel = GSIndustry.GetProductionLevel(industryId);
        if (!GSIndustry.SetProductionLevel(industryId, currentLevel, false, "")) {
            continue;
        }

        local stations = getIndustryStations(industryId);
        if (stations.len() < 1) {
            continue;
        }

        local cargoTypes = GSIndustryType.GetProducedCargo(industryType);
        foreach (cargoType, _ in cargoTypes) {
            local transported = GSIndustry.GetLastMonthTransported(industryId, cargoType);
            if (transported < 1) {
                continue;
            }

//            local label = GSCargo.GetCargoLabel(cargoType);
//            if (label == "PASS" || label == "MAIL") {
//                continue;
//            }

            local acceptingStations = [];
            foreach (stationId in stations) {
                if (GSStation.GetCargoRating(stationId, cargoType) < 1) {
                    continue;
                }
                acceptingStations.append(stationId);
            }

            if (!acceptingStations.len()) {
                continue;
            }
            origins.append({
                date = currentDate,
                industryId = industryId,
                cargoId = cargoType,
                possibleStationIds = acceptingStations,
                originStationIds = [],
                destinationStationIds = [],
                destinationIndustryIds = [],
                destinationTownIds = [],
                destinationCargoIds = [],
                destinationTracking = [],
            });
        }
    }

    return origins;
}

function getValidOriginIndustryTypes() {
    local validTypes = [];
    foreach (industryType, _ in GSIndustryTypeList()) {
        if (isValidOriginIndustry(industryType)) {
            validTypes.append(industryType);
        }
    }
    return validTypes;
}

function isValidOriginIndustry(industryType) {
    if (!GSIndustryType.ProductionCanIncrease(industryType)) {
        return false;
    }

    if (GSIndustryType.IsRawIndustry(industryType)) {
        return true;
    }

    local acceptedCargoIds = GSIndustryType.GetAcceptedCargo(industryType);
    foreach (cargoId, _ in acceptedCargoIds) {
        // exception for oil rigs
        if (GSCargo.HasCargoClass(cargoId, GSCargo.CC_PASSENGERS)) {
            continue;
        }

        // exception for banks (works with IsRawIndustry() above)
        if (GSCargo.HasCargoClass(cargoId, GSCargo.CC_ARMOURED)) {
            continue;
        }

        return false;
    }

    return true;
}

function addTask(taskQueue, origin, hopStationId, cargoId, originStationId) {
    taskQueue.append({
        origin = origin,
        hopStationId = hopStationId,
        cargoId = cargoId,
        originStationId = originStationId,
    });
}

function groupDestinationsAndOrigins(origins) {
    local prunedOrigins = [];
    local destinations = [];
    foreach (origin in origins) {
        if (!origin.originStationIds.len()) {
            continue;
        }
        prunedOrigins.append(origin);
        foreach (townId in origin.destinationTownIds) {
            local destination = null;
            foreach (existingDestination in destinations) {
                if (existingDestination.townId == townId) {
                    destination = existingDestination;
                    break;
                }
            }
            if (!destination) {
                // todo phase out destinations, they are only used for logging purposes
                destination = {
                    townId = townId,
                    originIndustryIds = [], // todo remove this
                    destinationStationIds = [], // todo remove this
                    destinationIndustryIds = [], // todo remove this
                    destinationCargoIds = [], // todo remove this
                    receivedCargo = 0, // todo remove this
                }
                destinations.append(destination);
            }
            destination.originIndustryIds.append(origin.industryId);
            foreach (stationId in origin.destinationStationIds) {
                addUnique(destination.destinationStationIds, stationId);
            }
            foreach (cargo in origin.destinationCargoIds) {
                addUnique(destination.destinationCargoIds, cargo);
            }
            foreach (industryId in origin.destinationIndustryIds) {
                addUnique(destination.destinationIndustryIds, industryId);
            }
        }
    }
    return {
        origins = prunedOrigins,
        destinations = destinations
    };
}

function registerDestination(task, recipients, stationId, companyId) {
    foreach (townId in recipients.townIds) {
        addUnique(task.origin.destinationTownIds, townId);
        if (!recipients.industryIds.len()) {
            CargoTracker.track(task.origin, companyId, task.cargoId, townId, null);
        }
    }

    addUnique(task.origin.originStationIds, task.originStationId);
    addUnique(task.origin.destinationStationIds, stationId);
    addUnique(task.origin.destinationCargoIds, task.cargoId);

    foreach (industryId in recipients.industryIds) {
        addUnique(task.origin.destinationIndustryIds, industryId);
        CargoTracker.track(task.origin, companyId, task.cargoId, null, industryId);
    }
}

class CargoTracker {
    static trackedCargo = {};
    static towns = {};

    static function track(origin, companyId, cargoId, townId, industryId) {
        if (industryId) {
            local key = companyId + "_" + cargoId + "_i" + industryId;
            if (key in CargoTracker.trackedCargo) {
                return CargoTracker.linkOrigin(CargoTracker.trackedCargo[key], origin);
            }
            CargoTracker.trackedCargo[key] <- CargoTracker.buildParams(key, companyId, cargoId, null, industryId);
            return CargoTracker.linkOrigin(CargoTracker.trackedCargo[key], origin);
        }

        local key = companyId + "_" + cargoId + "_t" + townId;
        if (key in CargoTracker.trackedCargo) {
            return CargoTracker.linkOrigin(CargoTracker.trackedCargo[key], origin);
        }
        CargoTracker.trackedCargo[key] <- CargoTracker.buildParams(key, companyId, cargoId, townId, null);
        return CargoTracker.linkOrigin(CargoTracker.trackedCargo[key], origin);
    }

    static function linkOrigin(tracking, origin) {
        tracking.date = GSDate.GetCurrentDate();
        local originKey = origin.industryId; // todo allow for passengers & mail with townid where industry is null
        tracking.origins[originKey] <- origin;
        origin.destinationTracking.append(tracking);
        return tracking;
    }

    static function buildParams(key, companyId, cargoId, townId, industryId) {
        if (!townId) {
            townId = getTownIdFromIndustryId(industryId);
        }
        if (!(townId in CargoTracker.towns)) {
            CargoTracker.towns[townId] <- buildTown(townId);
        }
        local town = CargoTracker.towns[townId];
        local params = {
            key = key,
            origins = {},
            companyId = companyId,
            cargoId = cargoId,
            townId = townId,
            industryId = industryId,
            date = GSDate.GetCurrentDate(),
            lastDeliveryAmount = 0,
        };
        town.deliveredCargo[key] <- params;
        return params;
    }

    static function update(date) {
        GSLog.Info("=== CargoTracker Update ===");
        GSLog.Info("Update date: " + formatDate(date));
        GSLog.Info("Total tracked items: " + CargoTracker.trackedCargo.len());

        local keysToRemove = [];
        local keptCount = 0;
        local removedCount = 0;

        foreach (key, value in CargoTracker.trackedCargo) {
            local keepTracking = value.date >= date;
            local cargoName = GSCargo.GetName(value.cargoId);
            local companyName = GSCompany.GetName(value.companyId);

            if (!keepTracking) {
                GSLog.Info("REMOVING: " + key + " (date: " + formatDate(value.date) + " < " + formatDate(date) + ")");
                keysToRemove.append(key);
                removedCount++;
            } else {
                keptCount++;
            }

            if (value.industryId) {
                local industryName = GSIndustry.GetName(value.industryId);
                value.lastDeliveryAmount = GSCargoMonitor.GetIndustryDeliveryAmount(
                    value.companyId,
                    value.cargoId,
                    value.industryId,
                    keepTracking
                );
                GSLog.Info("INDUSTRY: " + companyName + " delivered " + value.lastDeliveryAmount + " " + cargoName + " to " + industryName + " (keep: " + keepTracking + ")");
                continue;
            }

            local townName = GSTown.GetName(value.townId);
            value.lastDeliveryAmount = GSCargoMonitor.GetTownDeliveryAmount(
                value.companyId,
                value.cargoId,
                value.townId,
                keepTracking
            );
            GSLog.Info("TOWN: " + companyName + " delivered " + value.lastDeliveryAmount + " " + cargoName + " to " + townName + " (keep: " + keepTracking + ")");
        }

        foreach (key in keysToRemove) {
            GSLog.Info("Deleting: " + key);
            local trackedCargo = CargoTracker.trackedCargo[key];
            local town = CargoTracker.towns[trackedCargo.townId];
            delete town.deliveredCargo[key];
            delete CargoTracker.trackedCargo[key];
        }

        GSLog.Info("Summary: " + keptCount + " kept, " + removedCount + " removed");
        GSLog.Info("Remaining tracked items: " + CargoTracker.trackedCargo.len());
        GSLog.Info("=== CargoTracker Update Complete ===");
    }
}

function processTowns() {
    foreach (town in CargoTracker.towns) {
        logTownCargoAnalysis(town);
    }
}

function buildTown(townId) {
    return {
        townId = townId,
        deliveredCargo = {},
    }
}


//function calculateDemand() {
//    foreach (townId in towns) {
//        local population = GSTown.GetPopulation(townId);
//        foreach (cargoId in GSCargoTypes()) {
//
//        }
//        // prefer town effects
//    }
//}

function analyzeTownCargo(townData) {
    local analysis = {
        totalDeliveryAmount = 0,
        categoryReceived = buildCategoryCargoTable(), // cargoId -> sum
        categoryOrigins = buildCategoryCargoTable(), // cargoId -> true
        categoryTotals = buildCategoryCargoTable(function () {return 0}),
    };

    foreach (key, delivery in townData.deliveredCargo) {
        local cargoId = delivery.cargoId;
        local amount = delivery.lastDeliveryAmount;
        local category = getCargoCategory(cargoId);
        if (!(cargoId in analysis.categoryReceived[category])) {
            analysis.categoryReceived[category][cargoId] <- 0;
        }
        analysis.totalDeliveryAmount += amount;
        analysis.categoryReceived[category][cargoId] += amount;
        analysis.categoryTotals[category] += amount;

        foreach (origin in delivery.origins) {
            local originCategory = getCargoCategory(origin.cargoId);
            analysis.categoryOrigins[originCategory][origin.cargoId] <- true;
        }
    }

    return analysis;
}

function logTownCargoAnalysis(townData) {
    local analysis = analyzeTownCargo(townData);
    local townName = GSTown.GetName(townData.townId);
    local population = GSTown.GetPopulation(townData.townId);

    GSLog.Info("=== CARGO ANALYSIS: " + townName + " (Pop: " + population + ") ===");
    GSLog.Info("Total origins tracked: " + analysis.totalOrigins);
    GSLog.Info("Received cargo types: " + analysis.totalReceivedTypes);
    GSLog.Info("Origin cargo types: " + analysis.totalOriginTypes);
    GSLog.Info("Total delivery amount: " + analysis.totalDeliveryAmount);

    GSLog.Info("Received cargo breakdown:");
    foreach (cargoId, amount in analysis.receivedCargoTypes) {
        local cargoName = GSCargo.GetName(cargoId);
        GSLog.Info("  " + cargoName + ": " + amount + " units");
    }

    GSLog.Info("Origin cargo breakdown:");
    foreach (cargoId, amount in analysis.originCargoTypes) {
        local cargoName = GSCargo.GetName(cargoId);
        GSLog.Info("  " + cargoName + ": " + amount + " units");
    }

    GSLog.Info("=== END ANALYSIS ===");
}
