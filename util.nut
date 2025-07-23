function listContains(haystack, needle) {
    foreach (k, v in haystack) {
        if (v == needle) {
            return true;
        }
    }
    return false;
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

/**
 * return the towns that are the final destination for this cargo, or the industries that are intermediarys
 */
function stationAcceptingTowns(stationId, cargoId) {
    if (!GSCargoList_StationAccepting(stationId).HasItem(cargoId)) {
        return null;
    }

    local cargoLabel = GSCargo.GetCargoLabel(cargoId);
    if (cargoLabel == "GOOD" || cargoLabel == "MAIL" || cargoLabel == "FOOD" ||
        cargoLabel == "WATR" || cargoLabel == "PASS") {
        return {
            townIds = [GSStation.GetNearestTown(stationId)],
            industryIds = null
        };
    }

    local acceptingTowns = [];
    local acceptingIndustries = [];
    local producingIndustries = [];
    local coverageTiles = GSTileList_StationCoverage(stationId);
    foreach (tile, _ in coverageTiles) {
        local industryId = GSIndustry.GetIndustryID(tile);
        if (!listContains(acceptingIndustries, industryId) && GSIndustry.IsCargoAccepted(industryId, cargoId) == GSIndustry.CAS_ACCEPTED) {
            acceptingIndustries.append(industryId);
            local industryType = GSIndustry.GetIndustryType(industryId);
            local producedCargos = GSIndustryType.GetProducedCargo(industryType);
            if (producedCargos.Count() > 0) {
                producingIndustries.append(industryId);
            }
        }
    }

    if (producingIndustries.len() > 0) {
        return {
            townIds = null,
            industryIds = producingIndustries
        };
    }

    foreach (industryId in acceptingIndustries) {
        local townId = GSIndustry.GetNearestTown(industryId);
        if (!listContains(acceptingTowns, townId)) {
            acceptingTowns.append(townId);
        }
    }

    return {
        townIds = acceptingTowns,
        industryIds = null
    };
}

function findNextUnloadStationInOrders(vehicleId, originStationId, cargoType) {
    local orderCount = GSOrder.GetOrderCount(vehicleId);
    local unloadStations = [];

    local startOrderPositions = [];
    for (local i = 0; i < orderCount; i++) {
        local stationId = GSStation.GetStationID(GSOrder.GetOrderDestination(vehicleId, i));
        if (stationId == originStationId && canLoad(GSOrder.GetOrderFlags(vehicleId, i))) {
            startOrderPositions.append(i);
        }
    }

    foreach (i, startPosition in startOrderPositions) {
        for (local j = 1; j < orderCount; j++) {
            local orderPosition = (startPosition + j) % orderCount;
            local orderFlags = GSOrder.GetOrderFlags(vehicleId, orderPosition);

            if (!canUnload(orderFlags)) {
                continue;
            }

            local unloadStationId = GSStation.GetStationID(GSOrder.GetOrderDestination(vehicleId, orderPosition));
            local acceptingIndustries = stationAcceptsCargo(unloadStationId, cargoType);
            if (acceptingIndustries.len() > 0) {
                unloadStations.append(unloadStationId);
                break;
            }
        }
    }

    return unloadStations;
}

function findOriginIndustries(currentDate) {
    local industries = GSIndustryList();
    local origins = [];
    foreach (industryId, _ in industries) {
        local industryType = GSIndustry.GetIndustryType(industryId);
        if (!GSIndustryType.IsRawIndustry(industryType)) {
            continue;
        }

        if (!GSIndustryType.ProductionCanIncrease(industryType)) {
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

            local label = GSCargo.GetCargoLabel(cargoType);
            if (label == "PASS" || label == "MAIL") {
                continue;
            }

            local transportedPercent = GSIndustry.GetLastMonthTransportedPercentage(industryId, cargoType);
            foreach (stationId in stations) {
                local cargoRating = GSStation.GetCargoRating(stationId, cargoType);
                if (cargoRating < 1) {
                    continue;
                }
                origins.append({
                    date = currentDate,
                    industryId = industryId,
                    cargoId = cargoType,
                    stationId = stationId,
                    cargoRating = cargoRating,
                    townId = GSStation.GetNearestTown(stationId),
                    transported = transported,
                    transportedPercent = transportedPercent,
                    destinations = []
                });
            }
        }
    }

    return origins;
}
