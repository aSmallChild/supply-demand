//enum CARGO_CATEGORIES {
//    SERVICE = "service",
//    ESSENTIAL = "essential",
//    INDUSTRIAL = "industrial"
//}

class CargoCategory {
    ESSENTIAL = "ESSENTIAL";
    SERVICE = "SERVICE";
    INDUSTRIAL = "INDUSTRIAL";
    order = [
        "ESSENTIAL",
        "SERVICE",
        "INDUSTRIAL",
    ];
    map = {};
    sets = {};
    townCargoTypes = {};

    static function getTotalCategories() {
        return CargoCategory.order.len();
    }
}

function categorizeAllCargoTypes() {
    local cargoList = GSCargoList();
    foreach (cargoId, _ in cargoList) {
        local townEffect = GSCargo.GetTownEffect(cargoId);
        local category = getActualCargoCategory(cargoId, townEffect);
        CargoCategory.map[cargoId] <- category;
        if (!(category in CargoCategory.sets)) {
            CargoCategory.sets[category] <- {};
        }
        CargoCategory.sets[category][cargoId] <- true;
        if (isTownCargo(townEffect)) {
            CargoCategory.townCargoTypes[cargoId] <- true;
        }
    }
}

function getActualCargoCategory(cargoId, townEffect) {
    if (townEffect == GSCargo.TE_FOOD ||
        townEffect == GSCargo.TE_GOODS ||
        townEffect == GSCargo.TE_WATER) {
        return CargoCategory.ESSENTIAL;
    }

    if (isTownCargo(townEffect) || GSCargo.GetDistributionType(cargoId) == GSCargo.DT_SYMMETRIC) {
        return CargoCategory.SERVICE;
    }

    return CargoCategory.INDUSTRIAL;
}

function isTownCargo(townEffect) {
    return townEffect == GSCargo.TE_PASSENGERS || townEffect == GSCargo.TE_MAIL;
}

function getCargoCategory(cargoId) {
    return CargoCategory.map[cargoId];
}

function buildCategoryCargoTable(initialValue = function () {return {}}) {
    local cargoTable = {};
    foreach (cargoId, _ in CargoCategory.sets) {
        cargoTable[cargoId] <- initialValue();
    }
    return cargoTable;
}
