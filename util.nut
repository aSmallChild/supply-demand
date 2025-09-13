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
            if (origin.industryId) {
                destination.originIndustryIds.append(origin.industryId);
            }
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
        local key = origin.industryId ? "i" + origin.industryId : "t" + origin.townId;
        tracking.origins[key] <- origin;
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
            cargoReceived = 0,
        };
        town.deliveredCargo[key] <- params;
        return params;
    }

    static function update(date) {
        GSLog.Info("Total tracked items: " + CargoTracker.trackedCargo.len());

        local keysToRemove = [];
        local keptCount = 0;
        local removedCount = 0;

        foreach (key, value in CargoTracker.trackedCargo) {
            local keepTracking = value.date >= date;
            if (!keepTracking) {
//                GSLog.Info("REMOVING: " + key + " (date: " + formatDate(value.date) + " < " + formatDate(date) + ")");
                keysToRemove.append(key);
                removedCount++;
            } else {
                keptCount++;
            }

//            local cargoName = GSCargo.GetName(value.cargoId);
//            local companyName = GSCompany.GetName(value.companyId);
            if (value.industryId) {
                value.cargoReceived += GSCargoMonitor.GetIndustryDeliveryAmount(
                value.companyId,
                    value.cargoId,
                    value.industryId,
                    keepTracking
                );
//                if (value.cargoReceived) {
//                    local industryName = GSIndustry.GetName(value.industryId);
//                    GSLog.Info("INDUSTRY: " + companyName + " delivered " + value.cargoReceived + " " + cargoName + " to " + industryName + " (keep: " + keepTracking + ")");
//                }
                continue;
            }

            value.cargoReceived += GSCargoMonitor.GetTownDeliveryAmount(
            value.companyId,
                value.cargoId,
                value.townId,
                keepTracking
            );
//            if (value.cargoReceived) {
//                local townName = GSTown.GetName(value.townId);
//                GSLog.Info("TOWN: " + companyName + " delivered " + value.cargoReceived + " " + cargoName + " to " + townName + " (keep: " + keepTracking + ")");
//            }
        }

        foreach (key in keysToRemove) {
//            GSLog.Info("Deleting: " + key);
            local trackedCargo = CargoTracker.trackedCargo[key];
            local town = CargoTracker.towns[trackedCargo.townId];
            delete town.deliveredCargo[key];
            delete CargoTracker.trackedCargo[key];
        }

//        GSLog.Info("Summary: " + keptCount + " kept, " + removedCount + " removed");
//        GSLog.Info("Remaining tracked items: " + CargoTracker.trackedCargo.len());
//        GSLog.Info("=== CargoTracker Update Complete ===");
    }
}

function processTowns() {
    foreach (town in CargoTracker.towns) {
        processTown(town);
    }
}

function buildTown(townId) {
    return {
        townId = townId,
        deliveredCargo = {},
    }
}

function getTownCargoDemand(population) {
    local req = {
        categories = 1,
        target = 120,
        maxGrowth = 100,
    }

    return req;

//    if (population < 1e4) {
//        return req;
//    }
//
//    if (population < 1e5) {
//        req.categories = 2;
//        req.target = 600;
//        return req;
//    }
//
//    if (population < 3e5) {
//        req.categories = 2;
//        req.target = 900;
//        return req;
//    }
//
//    if (population < 6e5) {
//        req.categories = 2;
//        req.target = 1200;
//        return req;
//    }
//
//    if (population < 9e5) {
//        req.categories = 2;
//        req.target = 1800;
//        return req;
//    }
//
//    req.categories = 3;
//    req.target = 2400;
//    return req;
}

function analyzeTownCargo(townData) {
    local population = GSTown.GetPopulation(townData.townId);
    local demand = getTownCargoDemand(population);
    local analysis = {
        population = population,
        demand = demand,
        totalDeliveryAmount = 0,
        categoryReceived = buildCategoryCargoTable(), // cargoId -> sum
        categoryOrigins = buildCategoryCargoTable(), // category -> key -> true
        originIndustryIds = {}, // cargoId -> industryIds
        categoryTotals = buildCategoryCargoTable(function() {
            return 0
        }),
        cargoTotals = {}, // cargoId -> sum
        companyCargoTotals = {}, // [companyId][cargoId] -> sum,
        categoryScores = {},
    };

    foreach (key, delivery in townData.deliveredCargo) {
        local cargoId = delivery.cargoId;
        local companyId = delivery.companyId;
        local amount = delivery.cargoReceived;
        local category = getCargoCategory(cargoId);
        analysis.categoryOrigins[category][key] <- true;

        if (!(cargoId in analysis.categoryReceived[category])) {
            analysis.categoryReceived[category][cargoId] <- 0;
        }
        if (!(cargoId in analysis.originIndustryIds)) {
            analysis.originIndustryIds[cargoId] <- {};
        }

        analysis.totalDeliveryAmount += amount;
        analysis.categoryReceived[category][cargoId] += amount;
        analysis.categoryTotals[category] += amount;
        foreach (origin in delivery.origins) {
            if (origin.industryId) {
                analysis.originIndustryIds[cargoId][origin.industryId] <- true;
            }
        }

        if (!(cargoId in analysis.cargoTotals)) {
            analysis.cargoTotals[cargoId] <- 0;
        }
        analysis.cargoTotals[cargoId] += amount;

        if (!(companyId in analysis.companyCargoTotals)) {
            analysis.companyCargoTotals[companyId] <- {};
        }
        if (!(cargoId in analysis.companyCargoTotals[companyId])) {
            analysis.companyCargoTotals[companyId][cargoId] <- 0;
        }
        analysis.companyCargoTotals[companyId][cargoId] += amount;
    }

    foreach (category in CargoCategories) {
        local score = {
            totalCargo = 0,
            totalCargos = CargoCategory.sets[category].len(),
            fulfilledCargoIds = [],
            surplus = 0,
        }
        analysis.categoryScores[category] <- score;
        foreach (cargoId, _ in CargoCategory.sets[category]) {
            if (!(cargoId in analysis.cargoTotals) || !analysis.cargoTotals[cargoId]) {
                continue;
            }
            local amount = analysis.cargoTotals[cargoId];
            if (amount >= demand.target) {
                score.surplus += amount - demand.target;
                score.totalCargo += amount;
                score.fulfilledCargoIds.append(cargoId);
                continue;
            }
            increaseSupply(townData, analysis, cargoId, demand.target - amount);
        }
    }

    return analysis;
}

function processTown(townData) {
    local analysis = analyzeTownCargo(townData);
    local population = analysis.population;
    local demand = analysis.demand;

    local growthSnapshot = {
        population = population,
        totalSurplus = 0,
        consumedCount = 0,
    };

    local essential = analysis.categoryScores[CargoCategories.ESSENTIAL];
    local fulfilledCategories = [];
    foreach (category in analysis.categoryScores) {
        if (category.fulfilledCargoIds.len() >= category.totalCargos) {
            fulfilledCategories.append(category);
        }
    }

    if (essential.fulfilledCargoIds.len() < essential.totalCargos || fulfilledCategories.len() < demand.categories) {
        return;
    }

    // function processCategory(growthSnapshot), consume cargo
    // ignore services, they count toward hitting targets but
    // process essentials
    // process industrial
    // todo replace ready for growth with category scores
    // todo trigger this at a regular interval, e.g. 6 months
    // todo allow stockpiling to trigger more rapidly if targets are met before the end of the 6 month cycle
    // todo make it so having more fulfilled cargo types is better than just lots of just one


    foreach (category, score in analysis.categoryScores) {
        growthSnapshot.totalSurplus += score.surplus;
        growthSnapshot.consumedCount += score.fulfilledCargoIds.len();
        foreach (cargoId in score.fulfilledCargoIds) {
            resetCargoAmount(townData, cargoId);
        }
    }

    local townName = GSTown.GetName(townData.townId);
    local numberOfNewHouses = growthSnapshot.totalSurplus / 10;
    GSLog.Info("Growing town: " + townName + " (Pop: " + population + ") by " + numberOfNewHouses + " houses");
    GSTown.ExpandTown(townData.townId, numberOfNewHouses);
    GSTown.SetText(townData.townId, buildGrowthMessage(growthSnapshot, analysis, townData, fulfilledCategories.len()));
}

function increaseSupply(townData, analysis, cargoId, shortage) {
    if (CargoCategories.SERVICE == getCargoCategory(cargoId)) {
        // service category is for passengers and mail which increasw with town growth
        // there is an edge case with oil rigs which produce passengers
        // oil rigs should scale based on oil not passengers
        return;
    }
    local targetDemand = analysis.demand.target;
    local currentSupply = analysis.cargoTotals[cargoId] || 0;
    local maxProduction = 128;

    local bestIndustry = null;
    local bestScore = -1;
    local bestProductionLevel = 0;
    foreach (industryId, _ in analysis.originIndustryIds[cargoId]) {
        if (!GSIndustry.IsValidIndustry(industryId)) {
            continue;
        }

        local productionLevel = GSIndustry.GetProductionLevel(industryId);
        if (productionLevel >= maxProduction) {
            continue;
        }
        local transported = GSIndustry.GetLastMonthTransportedPercentage(industryId, cargoId);
        local growthPotential = maxProduction - productionLevel;
        local score = (transported * growthPotential) / 100;

        if (score > bestScore) {
            bestScore = score;
            bestIndustry = industryId;
            bestProductionLevel = productionLevel;
        }
    }

    if (!bestIndustry) {
        return;
    }
    local targetIncrease = max(1, min(8, max(shortage, targetDemand - currentSupply) / 100));
    targetIncrease = targetIncrease.tointeger();
    local newProductionLevel = min(maxProduction, bestProductionLevel + targetIncrease);
    local success = GSIndustry.SetProductionLevel(bestIndustry, newProductionLevel, false, null);

    local industryName = GSIndustry.GetName(bestIndustry);
    local cargoName = GSCargo.GetName(cargoId);
        GSLog.Info("Increased " + cargoName + " production at " + industryName +
                  " to address shortage of " + shortage + " units");

    return bestIndustry;
}

function resetCargoAmount(townData, cargoId) {
    foreach (key, delivery in townData.deliveredCargo) {
        if (delivery.cargoId == cargoId) {
            delivery.cargoReceived = 0;
        }
    }
}

function buildGrowthMessage(growthSnapshot, analysis, townData, fulfilledCategories) {
    local categorizedCargo = buildCategoryCargoTable();
    local message = GSText(GSText.STR_TOWN_CARGO_SUMMARY);
    message.AddParam(fulfilledCategories);
    message.AddParam(analysis.demand.categories);
    foreach (category in CargoCategories) {
        local score = analysis.categoryScores[category];
        // todo category titles are in the wrong order
        message.AddParam(score.totalCargo);
        message.AddParam(score.fulfilledCargoIds.len());
        message.AddParam(score.totalCargos);
        message.AddParam(analysis.categoryOrigins[category].len());
    }
//    message.AddParam(analysis.categoryScores[CargoCategories.SERVICE].totalCargo);
//    message.AddParam(categoryStats[CargoCategories.SERVICE].cargoTypes);
//    message.AddParam(analysis.categoryOrigins[CargoCategories.SERVICE].len());
//    message.AddParam(analysis.categoryScores[CargoCategories.INDUSTRIAL].totalCargo);
//    message.AddParam(categoryStats[CargoCategories.INDUSTRIAL].cargoTypes);
//    message.AddParam(analysis.categoryOrigins[CargoCategories.INDUSTRIAL].len());
    return message;
}
