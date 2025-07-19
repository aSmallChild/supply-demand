local MAX_CARGOTYPES = 64;
class SupplyDemand extends GSController {
    constructor() {
    }
}

function SupplyDemand::Start() {
    local lastRunDate = GSDate.GetCurrentDate(); // todo save & load this from game state
    GSLog.Info("Script started, game date: " + formatDate(lastRunDate));
    GSLog.Info("Cargo types:");
    local cargoTypes = getCargoTypes();
    foreach (cargoType in cargoTypes) {
        local label = GSCargo.GetCargoLabel(cargoType);
        GSLog.Info(cargoType + " - " + GSCargo.GetCargoLabel(cargoType) + " - " + GSCargo.GetName(cargoType));
    }

    local nextRunDate = getStartOfNextMonth(lastRunDate);
    while (true) {
        this.Sleep(74 * 3) // 3 days
        if (GSGame.IsPaused()) {
            continue;
        }

        local currentDate = GSDate.GetCurrentDate();
        if (nextRunDate > currentDate) {
            continue;
        }
        lastRunDate = nextRunDate;
        nextRunDate = getStartOfNextMonth(nextRunDate);
        GSLog.Info("Running for month: " + formatDate(lastRunDate));
    }
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

function getCargoTypes() {
    local list = [];
    for (local cargoType = 0; cargoType < 64; cargoType++) {
        if (GSCargo.IsValidCargo(cargoType)) {
            list.append(cargoType);
        }
    }
    return list;
}
