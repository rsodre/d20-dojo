# ai-thon
Cartridge AI Hackathon Project

## Steps

1. [x] Install [Dojo skills](https://book.dojoengine.org/overview#ai-assisted-development): `npx skills add dojoengine/book --yes`
2. [x] Create [`.tool-versions`](.tool-versions)
3. [x] Initialize Dojo project: `sozo init contracts` in `packages/`
4. [x] Review and fix SPEC.md: Dojo model syntax, architecture, game logic inconsistencies
5. [x] Apply user feedback: OZ + cairo-nft-combo NFTs, namespace `d2_0_1`, signed integers for D20, extract TASKS.md
6. [x] Task 1.1: Replace starter code — updated namespace to `d20_0_1`, renamed package to `d20`, updated world name/seed, set up new module structure (types, events, models, systems, utils), removed starter models/systems/tests
7. [x] Tasks 1.2-1.4: Implement all enums (12 types in `types.cairo`), explorer models (6 models in `models/explorer.cairo`), and temple/chamber models (7 models in `models/temple.cairo`)
8. [x] Task 1.5: Implement D20 utility module (`utils/d20.cairo`) with VRF dice rolling (`roll_d20`, `roll_dice`), `ability_modifier`, `proficiency_bonus`, `calculate_ac` — plus local VRF interface (`utils/vrf.cairo`) and 30 unit tests (all passing)
9. [x] Tasks 1.6-1.8: Monster stat lookup (7 monsters with full SRD stats), all 6 Dojo events, and complete D20 math unit tests (41 tests passing — all 18 ability scores, proficiency by level, AC combos, monster stats)
