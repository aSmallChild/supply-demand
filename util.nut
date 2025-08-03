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
        local tile = GSIndustry.GetLocation(industryId);
        local townId = GSTile.GetClosestTown(tile);
        if (!listContains(acceptingTowns, townId)) {
            acceptingTowns.append(townId);
        }
        local industryType = GSIndustry.GetIndustryType(industryId);
        local producedCargos = GSIndustryType.GetProducedCargo(industryType);
        if (producedCargos.Count() < 1) {
            continue;
        }
        foreach (producedCargoId, _ in producedCargos) {
            if (!listContains(nextCargoIds, producedCargoId)) {
                nextCargoIds.append(producedCargoId);
            }
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
                sentCargo = 0, // todo sum of monitoring for this month
                originStationIds = [],
                destinationStationIds = [],
                destinationIndustryIds = [],
                destinationTownIds = [],
                destinationCargoIds = [],
            });
        }
    }

    return origins;
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
                destination = {
                    townId = townId,
                    originIndustryIds = [],
                    destinationStationIds = [],
                    destinationIndustryIds = [],
                    destinationCargoIds = [],
                    receivedCargo = 0, // todo sum of monitoring for this month
                }
                destinations.append(destination);
            }
            destination.originIndustryIds.append(origin.industryId);
            foreach (stationId in origin.destinationStationIds) {
                if (!listContains(destination.destinationStationIds, stationId)) {
                    destination.destinationStationIds.append(stationId);
                }
            }
            foreach (cargo in origin.destinationCargoIds) {
                if (!listContains(destination.destinationCargoIds, cargo)) {
                    destination.destinationCargoIds.append(cargo);
                }
            }
            foreach (industryId in origin.destinationIndustryIds) {
                if (!listContains(destination.destinationIndustryIds, industryId)) {
                    destination.destinationIndustryIds.append(industryId);
                }
            }
        }
    }
    return {
        origins = prunedOrigins,
        destinations = destinations
    };
}

