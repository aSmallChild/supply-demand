//enum CARGO_CATEGORIES {
//    SERVICE = "service",
//    ESSENTIAL = "essential",
//    INDUSTRIAL = "industrial"
//}

class CargoCategories {
    static ESSENTIAL = "essential";
    static SERVICE = "service";
    static INDUSTRIAL = "industrial";
}

class CargoCategoryCache {
    total = 3;
    map = {};
    sets = {};
    townCargoTypes = {};
}

function categorizeAllCargoTypes() {
    local cargoList = GSCargoList();
    foreach (cargoId, _ in cargoList) {
        local townEffect = GSCargo.GetTownEffect(cargoId);
        local category = getActualCargoCategory(cargoId, townEffect);
        CargoCategoryCache.map[cargoId] <- category;
        if (!(category in CargoCategoryCache.sets)) {
            CargoCategoryCache.sets[category] <- {};
        }
        CargoCategoryCache.sets[category][cargoId] <- true;
        if (isTownCargo(townEffect)) {
            CargoCategoryCache.townCargoTypes[cargoId] <- true;
        }
    }
}

function getActualCargoCategory(cargoId, townEffect) {
    if (townEffect == GSCargo.TE_FOOD ||
        townEffect == GSCargo.TE_GOODS ||
        townEffect == GSCargo.TE_WATER) {
        return CargoCategories.ESSENTIAL;
    }

    if (isTownCargo(townEffect) || GSCargo.GetDistributionType(cargoId) == GSCargo.DT_SYMMETRIC) {
        return CargoCategories.SERVICE;
    }

    return CargoCategories.INDUSTRIAL;
}

function isTownCargo(townEffect) {
    return townEffect == GSCargo.TE_PASSENGERS || townEffect == GSCargo.TE_MAIL;
}

function getCargoCategory(cargoId) {
    return CargoCategoryCache.map[cargoId];
}

function buildCategoryCargoTable(initialValue = function () {return {}}) {
    local cargoTable = {};
    foreach (cargoId, _ in CargoCategoryCache.sets) {
        cargoTable[cargoId] <- initialValue();
    }
    return cargoTable;
}
