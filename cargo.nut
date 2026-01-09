//enum CARGO_CATEGORIES {
//    SERVICE = "service",
//    ESSENTIAL = "essential",
//    INDUSTRIAL = "industrial"
//}

class CargoCategory {
    ESSENTIAL = "ESSENTIAL";
    SERVICE = "SERVICE";
    INDUSTRIAL = "INDUSTRIAL";
    INTERMEDIATE = "INTERMEDIATE";
    scoreOrder = [
        "ESSENTIAL",
        "SERVICE",
        "INDUSTRIAL",
    ];
    map = {};
    sets = {};
    townCargoTypes = {};

    static function getTotalCategories() {
        return CargoCategory.scoreOrder.len();
    }
}

function categorizeAllCargoTypes() {
    foreach (cargoId, _ in GSCargoList()) {
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

    if (isTownCargo(townEffect) || GSCargo.HasCargoClass(cargoId, GSCargo.CC_ARMOURED)) {
        return CargoCategory.SERVICE;
    }

    if (isRawCargo(cargoId)) {
        return CargoCategory.INDUSTRIAL;
    }

    return CargoCategory.INTERMEDIATE;
}

function isRawCargo(cargoId) {
    foreach (industryTypeId, _ in getProducingIndustryTypes(cargoId)) {
        if (GSIndustryType.IsProcessingIndustry(industryTypeId)) {
            return false;
        }
    }
    return true;
}

function getProducingIndustryTypes(cargoId) {
    local types = GSIndustryTypeList();
    foreach (industryTypeId, _ in GSIndustryTypeList()) {
        local isProduced = false;
        foreach (producedCargoId, _ in GSIndustryType.GetProducedCargo(industryTypeId)) {
            if (producedCargoId == cargoId) {
                isProduced = true;
                break;
            }
        }
        if (!isProduced) {
            types.RemoveItem(industryTypeId);
        }
    }
    return types;
}

function isScoredCargo(cargoId) {
    return listContains(CargoCategory.scoreOrder, getCargoCategory(cargoId));
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
