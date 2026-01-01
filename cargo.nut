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
}

function categorizeAllCargoTypes() {
    local cargoList = GSCargoList();
    foreach (cargoId, _ in cargoList) {
        local category = getActualCargoCategory(cargoId);
        CargoCategoryCache.map[cargoId] <- category;
        if (!(category in CargoCategoryCache.sets)) {
            CargoCategoryCache.sets[category] <- {};
        }
        CargoCategoryCache.sets[category][cargoId] <- true;
    }
}

function getActualCargoCategory(cargoId) {
    if (GSCargo.HasCargoClass(cargoId, GSCargo.CC_MAIL) ||
        GSCargo.HasCargoClass(cargoId, GSCargo.CC_PASSENGERS)) {
        return CargoCategories.SERVICE;
    }

    local townEffect = GSCargo.GetTownEffect(cargoId);
    if (townEffect == GSCargo.TE_FOOD ||
        townEffect == GSCargo.TE_GOODS ||
        townEffect == GSCargo.TE_WATER) {
        return CargoCategories.ESSENTIAL;
    }

    return CargoCategories.INDUSTRIAL;
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
