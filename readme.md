# Supply & Demand

Another town growth game script for OpenTTD.

Towns grow when cargo is supplied. Not just directly to the town but also any industry owned by the town.
Industries grow if demand is not met. Demand increases as towns grow.
Basically it's about building high capacity logistics networks.

Cargo is only tracked when transported percentages are sufficiently high & it has to deliver across the entire supply chain.
E.g. For Oil to be tracked the refinery has to be supplying goods to a town.

# To do

- [x] if monthly average supply is not sufficient for constant growth boost production of suppliers
- [ ] ~~track some stats~~
    - [ ] ~~display stats in game menus (industry window, station window)~~
    - [ ] ~~can the game do graphs?~~
- [ ] script settings
  - [ ] tiers of towns
  - [ ] run interval
- [ ] only process shared orders once
- [ ] delivery tracking works if orders contain a refit at a station
