enum CARGO_CATEGORIES {
    SERVICE = "service",
    ESSENTIAL = "essential",
    INDUSTRIAL = "industrial"
}

class CARGO_CATEGORY {
    MAP = {};
    SETS = {};
}

function categorizeAllCargoTypes() {
    local cargoList = GSCargoList();
    foreach (cargoId, _ in cargoList) {
        local category = buildCargoCategory(cargoId);
        CARGO_CATEGORY.MAP[cargoId] <- category;
        if (!(category in CARGO_CATEGORY.SETS)) {
            CARGO_CATEGORY.SETS[category] <- {};
        }
        CARGO_CATEGORY.SETS[category][cargoId] <- true;
    }
}

function buildCargoCategory(cargoId) {
    if (GSCargo.HasCargoClass(cargoId, GSCargo.CC_MAIL) ||
        GSCargo.HasCargoClass(cargoId, GSCargo.CC_PASSENGERS)) {
        return CARGO_CATEGORIES.SERVICE;
    }

    local townEffect = GSCargo.GetTownEffect(cargoId);
    if (townEffect == GSCargo.TE_FOOD ||
        townEffect == GSCargo.TE_GOODS ||
        townEffect == GSCargo.TE_WATER) {
        return CARGO_CATEGORIES.ESSENTIAL;
    }

    return CARGO_CATEGORIES.INDUSTRIAL;
}

function getCargoCategory(cargoId) {
    return CARGO_CATEGORY.MAP[cargoId];
}

function buildCategoryCargoTable(initialValue = function () {return {}}) {
    local cargoTable = {};
    foreach (cargoId, _ in CARGO_CATEGORY.SETS) {
        cargoTable[cargoId] <- initialValue();
    }
    return cargoTable;
}
