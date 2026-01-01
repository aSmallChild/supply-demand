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

function getStartOfNextMonth(date, increment) {
    local year = GSDate.GetYear(date);
    local month = GSDate.GetMonth(date) + increment % 12;
    if (increment > 12) {
        year += increment / 12;
    }

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

function findOrigins(currentDate) {
    local origins = [];
    local validOriginIndustryTypes = getValidOriginIndustryTypes();
    local originTownIds = {};
    local originIndustryIds = {};
    foreach (stationId, _ in GSStationList(GSStation.STATION_ANY)) {
        foreach (cargoType, _ in CargoCategoryCache.townCargoTypes) {
            local townId = GSStation.GetNearestTown(stationId);
            local transported = GSTown.GetLastMonthSupplied(townId, cargoType);
            if (transported < 1) {
                continue;
            }

            if (!(townId in originTownIds)) {
                originTownIds[townId] <- {};
            }
            originTownIds[townId][stationId] <- true;
        }

        local coverageTiles = GSTileList_StationCoverage(stationId);
        foreach (tile, _ in coverageTiles) {
            local industryId = GSIndustry.GetIndustryID(tile);
            if (isValidOriginIndustry(industryId, validOriginIndustryTypes)) {
                if (!(industryId in originIndustryIds)) {
                    originIndustryIds[industryId] <- {};
                }
                originIndustryIds[industryId][stationId] <- true;
            }
        }
    }

    foreach (industryId, stationIds in originIndustryIds) {
        local industryType = GSIndustry.GetIndustryType(industryId);
        local cargoTypes = GSIndustryType.GetProducedCargo(industryType);
        foreach (cargoType, _ in cargoTypes) {
            local transported = GSIndustry.GetLastMonthTransported(industryId, cargoType);
            if (transported < 1) {
                continue;
            }

            local acceptingStations = [];
            foreach (stationId, _ in stationIds) {
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
                townId = null,
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

    foreach (townId, stationIds in originTownIds) {
        foreach (cargoType, _ in CargoCategoryCache.townCargoTypes) {
            local acceptingStations = [];
            foreach (stationId, _ in stationIds) {
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
                townId = townId,
                industryId = null,
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

function isValidOriginIndustry(industryId, validOriginIndustryTypes) {
    if (!GSIndustry.IsValidIndustry(industryId)) {
        return false;
    }

    local industryType = GSIndustry.GetIndustryType(industryId);
    local isValid = false;
    foreach (validType in validOriginIndustryTypes) {
        if (validType == industryType) {
            isValid = true;
            break;
        }
    }
    if (!isValid) {
        return false;
    }

    local currentLevel = GSIndustry.GetProductionLevel(industryId);
    if (!GSIndustry.SetProductionLevel(industryId, currentLevel, false, "")) {
        return false;
    }

    return true;
}

function getValidOriginIndustryTypes() {
    local validTypes = [];
    foreach (industryType, _ in GSIndustryTypeList()) {
        if (isValidOriginIndustryType(industryType)) {
            validTypes.append(industryType);
        }
    }
    return validTypes;
}

function isValidOriginIndustryType(industryType) {
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
//        foreach (townId in origin.destinationTownIds) {
//            local destination = null;
//            foreach (existingDestination in destinations) {
//                if (existingDestination.townId == townId) {
//                    destination = existingDestination;
//                    break;
//                }
//            }
//            if (!destination) {
//                destination = {
//                    townId = townId,
//                    originIndustryIds = [],
//                    destinationStationIds = [],
//                    destinationIndustryIds = [],
//                    destinationCargoIds = [],
//                    receivedCargo = 0,
//                }
//                destinations.append(destination);
//            }
//            if (origin.industryId) {
//                destination.originIndustryIds.append(origin.industryId);
//            }
//            foreach (stationId in origin.destinationStationIds) {
//                addUnique(destination.destinationStationIds, stationId);
//            }
//            foreach (cargo in origin.destinationCargoIds) {
//                addUnique(destination.destinationCargoIds, cargo);
//            }
//            foreach (industryId in origin.destinationIndustryIds) {
//                addUnique(destination.destinationIndustryIds, industryId);
//            }
//        }
    }
    return {
        origins = prunedOrigins,
//        destinations = destinations
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
        categories = 0,
        target = 100 * SupplyDemand.runIntervalMonths,
        maxGrowth = 20 * SupplyDemand.runIntervalMonths,
    }

    if (population < 2500) {
        return req;
    }

    if (population < 10000) {
        req.categories = 1;
        req.target = 200 * SupplyDemand.runIntervalMonths;
        req.maxGrowth = 40 * SupplyDemand.runIntervalMonths;
        return req;
    }

    req.categories = 2;
    if (population < 33000) {
        req.target = 400 * SupplyDemand.runIntervalMonths;
        req.maxGrowth = 60 * SupplyDemand.runIntervalMonths;
        return req;
    }

    if (population < 67000) {
        req.target = 800 * SupplyDemand.runIntervalMonths;
        req.maxGrowth = 80 * SupplyDemand.runIntervalMonths;
        return req;
    }

    req.maxGrowth = 100 * SupplyDemand.runIntervalMonths;
    if (population < 300000) {
        req.target = 1200 * SupplyDemand.runIntervalMonths;
        return req;
    }

    req.categories = 3;
    req.target = 2400 * SupplyDemand.runIntervalMonths;
    return req;
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
            totalCargos = CargoCategoryCache.sets[category].len(),
            fulfilledCargoIds = [],
            surplus = 0,
        }
        analysis.categoryScores[category] <- score;
        foreach (cargoId, _ in CargoCategoryCache.sets[category]) {
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
        population = analysis.population,
        totalSurplus = 0,
        consumedCount = 0,
        numberOfNewHouses = 0,
        totalCargoTypes = 0,
        fulfilledCargoTypes = 0,
    };

    local essential = analysis.categoryScores[CargoCategories.ESSENTIAL];
    local fulfilledCategories = [];
    foreach (category in analysis.categoryScores) {
        growthSnapshot.fulfilledCargoTypes += category.fulfilledCargoIds.len();
        growthSnapshot.totalCargoTypes += category.totalCargos;
        if (category.fulfilledCargoIds.len() >= category.totalCargos) {
            fulfilledCategories.append(category);
        }
    }

    if (demand.categories < 1) {
        growTierZeroTown(growthSnapshot, analysis, townData, fulfilledCategories);
    }
    else if (essential.fulfilledCargoIds.len() < essential.totalCargos || fulfilledCategories.len() < demand.categories) {
        GSTown.SetText(townData.townId, buildGrowthMessage(growthSnapshot, analysis, townData, fulfilledCategories.len()));
        return;
    }
    else {
        growTown(growthSnapshot, analysis, townData, fulfilledCategories);
    }

    local townName = GSTown.GetName(townData.townId);
    GSLog.Info("Growing town: " + townName + " (Pop: " + analysis.population + ") by " + growthSnapshot.numberOfNewHouses + " houses");
    GSTown.ExpandTown(townData.townId, growthSnapshot.numberOfNewHouses);
    GSTown.SetGrowthRate(townData.townId, GSTown.TOWN_GROWTH_NONE);
    GSTown.SetText(townData.townId, buildGrowthMessage(growthSnapshot, analysis, townData, fulfilledCategories.len()));

    // function processCategory(growthSnapshot), consume cargo
    // ignore services, they count toward hitting targets but
    // process essentials
    // process industrial
    // todo replace ready for growth with category scores
    // todo trigger this at a regular interval, e.g. 6 months
    // todo allow stockpiling to trigger more rapidly if targets are met before the end of the 6 month cycle
}

function growTierZeroTown(growthSnapshot, analysis, townData, fulfilledCategories) {
    local demand = analysis.demand;
    foreach (category, score in analysis.categoryScores) {
        foreach (cargoId in score.fulfilledCargoIds) {
            resetCargoAmount(townData, cargoId);
        }
    }
    growthSnapshot.numberOfNewHouses = demand.maxGrowth * growthSnapshot.fulfilledCargoTypes / growthSnapshot.totalCargoTypes;
}

function growTown(growthSnapshot, analysis, townData, fulfilledCategories) {
    foreach (category, score in analysis.categoryScores) {
        growthSnapshot.totalSurplus += score.surplus;
        growthSnapshot.consumedCount += score.fulfilledCargoIds.len();
        foreach (cargoId in score.fulfilledCargoIds) {
            resetCargoAmount(townData, cargoId);
        }
    }
    growthSnapshot.numberOfNewHouses = demand.maxGrowth * fulfilledCategories.len() / CargoCategoryCache.total;
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
        if (transported < 70) {
            continue;
        }
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
    GSLog.Info("Increased " + cargoName + " production at " + industryName + " to address shortage of " + shortage + " units");

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
    local message = GSText(GSText.STR_TOWN_SUMMARY);
    message.AddParam(fulfilledCategories + "/" + analysis.demand.categories);
    message.AddParam(analysis.demand.target);
    message.AddParam(growthSnapshot.numberOfNewHouses + "/" + analysis.demand.maxGrowth);

    foreach (key, category in CargoCategories) {
        local score = analysis.categoryScores[category];
        local categoryLine = GSText(GSText["STR_TOWN_" + key + "_LINE"]);
        categoryLine.AddParam(score.totalCargo);
        categoryLine.AddParam(analysis.categoryOrigins[category].len());
        local cargoList = "";
        foreach (cargoId, _ in CargoCategoryCache.sets[category]) {
            if (!(cargoId in analysis.cargoTotals) || !analysis.cargoTotals[cargoId]) {
                continue;
            }
            local amount = analysis.cargoTotals[cargoId];
            cargoList += (cargoList != "" ? ", " : "") + GSCargo.GetName(cargoId) + ": " + amount;
        }
        categoryLine.AddParam(score.fulfilledCargoIds.len() + "/" + score.totalCargos + (cargoList != "" ? " - " + cargoList : ""));
        message.AddParam(categoryLine);
    }
    return message;
}
