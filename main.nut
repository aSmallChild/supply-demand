class SupplyDemand extends GSController {
    constructor() {
    }
}

function SupplyDemand::Start() {
    local lastRunDate = GSDate.GetCurrentDate();
     GSLog.Info("Script started, game date: " + formatDate(lastRunDate))
    while (true) {
        this.Sleep(74) // 1 day
        if (GSGame.IsPaused()) {
            continue;
        }
        local currentDate = GSDate.GetCurrentDate();
        // GSLog.Info("current date " + formatDate(currentDate))
    }
}

function formatDate(date) {
    local month = GSDate.GetMonth(date);
    local day = GSDate.GetDayOfMonth(date);
    return GSDate.GetYear(date) + "-" + (month < 10 ? "0" : "") + month + "-" + (day < 10 ? "0" : "") + day;
}
