# Supply & Demand

Another town growth game script for OpenTTD.

Towns grow when cargo is supplied. Not just directly to the town but also any industry owned by the town.
Industries grow if demand is not met. Demand increases as towns grow.
Basically it's about building high capacity logistics networks.

Cargo is only tracked when transported percentages are sufficiently high & it has to deliver across the entire supply chain.
E.g. For Oil to be tracked the refinery has to be supplying goods to a town.

## To do

- [ ] script settings
  - [ ] tiers of towns
  - [ ] run interval
- [ ] fix symmetric delivery tracking e.g. valuables to valuables
- [ ] only process shared orders once
- [ ] tidy up town messages, list cargo types that are tracked even if 0 are delivered
- [ ] include complete list of destinations on the industry text & set industry text even if it hasn't experienced growth

## Creating a Release

This repository uses GitHub Actions to automatically create releases with zipped artifacts.

### How to Create a Release

1. Update [changelog.txt]() with your new version at the top of the file
2. Merge to `main`
3. GitHub Actions will automatically:
   - Extract the version number from the changelog
   - Create a zip file with the configured files
   - Create a GitHub release with the changelog notes

### Changelog Format

Your `changelog.txt` must follow this format for successful release creation [info.nut]() is updated automatically using the version from the change log:

```
v2026-01-05 (optional description here)
- Added new feature
- etc...

v2026-01-04 (previous release)
- Previous changes here
- etc...
```
