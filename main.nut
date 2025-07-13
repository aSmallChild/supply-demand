class SupplyDemand extends GSController {
    constructor() {
    }
}

function SupplyDemand::Start() {
    while (true) {
        // todo detect if game is paused
        this.Sleep(1)
        local allTowns = GSTownList();
        foreach (townId, _ in allTowns) {
            GSTown.ExpandTown(townId, 100)
        }
    }
}
