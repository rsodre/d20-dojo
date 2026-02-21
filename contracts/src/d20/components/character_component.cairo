#[starknet::component]
pub mod CharacterComponent {
    use starknet::ContractAddress;
    use dojo::world::WorldStorage;
    use dojo::model::ModelStorage;
    use dojo::event::EventStorage;

    use d20::d20::models::adventurer::{
        AbilityScore, Skill, SkillsSet,
        AdventurerStats, AdventurerHealth, AdventurerCombat, AdventurerInventory,
        AdventurerPosition, AdventurerSkills,
    };
    use d20::d20::types::adventurer_class::{AdventurerClass, AdventurerClassTrait};
    use d20::d20::types::attributes::CharacterAttributes;
    use d20::utils::seeder::{Seeder, SeederTrait};
    use d20::utils::dice::{ability_modifier, calculate_ac};
    use d20::events::ExplorerMinted;

    #[storage]
    pub struct Storage {}

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {}

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        fn generate_character(
            ref self: ComponentState<TContractState>,
            ref world: WorldStorage,
            adventurer_id: u128,
            adventurer_class: AdventurerClass,
            caller: ContractAddress,
            ref seeder: Seeder,
        ) {
            // Randomly assign stats from standard array [15,14,13,12,10,8] using VRF
            let abilities = random_stat_assignment(adventurer_class, ref seeder);

            let con_mod: i8 = ability_modifier(abilities.constitution);
            let dex_mod: i8 = ability_modifier(abilities.dexterity);

            // Starting HP: hit die max + CON modifier (minimum 1)
            let hit_die = adventurer_class.hit_die_max();
            let raw_hp: i16 = hit_die.into() + con_mod.into();
            let max_hp: u16 = if raw_hp < 1 { 1 } else { raw_hp.try_into().unwrap() };

            // Starting equipment and AC by class
            let (primary_weapon, secondary_weapon, armor, has_shield) = adventurer_class.starting_equipment();
            let armor_class = calculate_ac(armor, has_shield, dex_mod);

            // Spell slots (level 1)
            let (slots_1, slots_2, slots_3) = adventurer_class.spell_slots_for(1);

            // Randomly pick skills from VRF
            let (skills, expertise_1, expertise_2) = random_skills(adventurer_class, ref seeder);

            // Write all explorer Dojo models
            world.write_model(@AdventurerStats {
                adventurer_id,
                abilities,
                level: 1,
                xp: 0,
                adventurer_class,
                temples_conquered: 0,
            });

            world.write_model(@AdventurerHealth {
                adventurer_id,
                current_hp: max_hp.try_into().unwrap(),
                max_hp,
                is_dead: false,
            });

            world.write_model(@AdventurerCombat {
                adventurer_id,
                armor_class,
                spell_slots_1: slots_1,
                spell_slots_2: slots_2,
                spell_slots_3: slots_3,
                second_wind_used: false,
                action_surge_used: false,
            });

            world.write_model(@AdventurerInventory {
                adventurer_id,
                primary_weapon,
                secondary_weapon,
                armor,
                has_shield,
                gold: 0,
                potions: 0,
            });

            world.write_model(@AdventurerPosition {
                adventurer_id,
                temple_id: 0,
                chamber_id: 0,
                in_combat: false,
                combat_monster_id: 0,
            });

            world.write_model(@AdventurerSkills {
                adventurer_id,
                skills,
                expertise_1,
                expertise_2,
            });

            // Emit Dojo event
            world.emit_event(@ExplorerMinted {
                adventurer_id,
                adventurer_class,
                player: caller,
            });
        }

        fn get_attributes(
            self: @ComponentState<TContractState>,
            ref world: WorldStorage,
            adventurer_id: u128,
        ) -> CharacterAttributes {
            let stats: AdventurerStats = world.read_model(adventurer_id);
            let health: AdventurerHealth = world.read_model(adventurer_id);
            let combat: AdventurerCombat = world.read_model(adventurer_id);

            let class_name: ByteArray = match stats.adventurer_class {
                AdventurerClass::None => "None",
                AdventurerClass::Fighter => "Fighter",
                AdventurerClass::Rogue => "Rogue",
                AdventurerClass::Wizard => "Wizard",
            };

            CharacterAttributes {
                adventurer_class: class_name,
                level: stats.level,
                current_hp: health.current_hp,
                max_hp: health.max_hp,
                armor_class: combat.armor_class,
                strength: stats.abilities.strength,
                dexterity: stats.abilities.dexterity,
                constitution: stats.abilities.constitution,
                intelligence: stats.abilities.intelligence,
                wisdom: stats.abilities.wisdom,
                charisma: stats.abilities.charisma,
                is_dead: health.is_dead,
            }
        }

        fn rest(
            ref self: ComponentState<TContractState>,
            ref world: WorldStorage,
            adventurer_id: u128,
        ) {
            let stats: AdventurerStats = world.read_model(adventurer_id);
            assert(stats.adventurer_class != AdventurerClass::None, 'explorer does not exist');

            let health: AdventurerHealth = world.read_model(adventurer_id);
            assert(!health.is_dead, 'dead explorers cannot rest');

            world.write_model(@AdventurerHealth {
                adventurer_id,
                current_hp: health.max_hp.try_into().unwrap(),
                max_hp: health.max_hp,
                is_dead: false,
            });

            let (slots_1, slots_2, slots_3) = stats.adventurer_class.spell_slots_for(stats.level);
            let combat: AdventurerCombat = world.read_model(adventurer_id);
            world.write_model(@AdventurerCombat {
                adventurer_id,
                armor_class: combat.armor_class,
                spell_slots_1: slots_1,
                spell_slots_2: slots_2,
                spell_slots_3: slots_3,
                second_wind_used: false,
                action_surge_used: false,
            });
        }
    }

    // ── Internal ──────────────────────────────────────────────────────────────

    fn standard_array() -> Span<u8> {
        array![15_u8, 14_u8, 13_u8, 12_u8, 10_u8, 8_u8].span()
    }

    fn random_stat_assignment(self: AdventurerClass, ref seeder: Seeder) -> AbilityScore {
        let order = self.preferred_stat_order();
        let sa = standard_array();

        let mut assign: Array<u8> = array![
            *sa.at((*order.at(0)).into()),
            *sa.at((*order.at(1)).into()),
            *sa.at((*order.at(2)).into()),
            *sa.at((*order.at(3)).into()),
            *sa.at((*order.at(4)).into()),
            *sa.at((*order.at(5)).into()),
        ];

        let r0 = seeder.random_u8();
        let r1 = seeder.random_u8();
        let r2 = seeder.random_u8();
        let r3 = seeder.random_u8();
        let r4 = seeder.random_u8();

        let i0: u32 = (r0 % 6).into();
        let tmp0 = *assign.at(5);
        let v0 = *assign.at(i0);
        let mut assign2: Array<u8> = array![];
        let mut k: u32 = 0;
        while k < 6 {
            if k == i0 { assign2.append(tmp0); }
            else if k == 5 { assign2.append(v0); }
            else { assign2.append(*assign.at(k)); }
            k += 1;
        };

        let i1: u32 = (r1 % 5).into();
        let tmp1 = *assign2.at(4);
        let v1 = *assign2.at(i1);
        let mut assign3: Array<u8> = array![];
        let mut k: u32 = 0;
        while k < 6 {
            if k == i1 { assign3.append(tmp1); }
            else if k == 4 { assign3.append(v1); }
            else { assign3.append(*assign2.at(k)); }
            k += 1;
        };

        let i2: u32 = (r2 % 4).into();
        let tmp2 = *assign3.at(3);
        let v2 = *assign3.at(i2);
        let mut assign4: Array<u8> = array![];
        let mut k: u32 = 0;
        while k < 6 {
            if k == i2 { assign4.append(tmp2); }
            else if k == 3 { assign4.append(v2); }
            else { assign4.append(*assign3.at(k)); }
            k += 1;
        };

        let i3: u32 = (r3 % 3).into();
        let tmp3 = *assign4.at(2);
        let v3 = *assign4.at(i3);
        let mut assign5: Array<u8> = array![];
        let mut k: u32 = 0;
        while k < 6 {
            if k == i3 { assign5.append(tmp3); }
            else if k == 2 { assign5.append(v3); }
            else { assign5.append(*assign4.at(k)); }
            k += 1;
        };

        let i4: u32 = (r4 % 2).into();
        let tmp4 = *assign5.at(1);
        let v4 = *assign5.at(i4);
        let mut assign6: Array<u8> = array![];
        let mut k: u32 = 0;
        while k < 6 {
            if k == i4 { assign6.append(tmp4); }
            else if k == 1 { assign6.append(v4); }
            else { assign6.append(*assign5.at(k)); }
            k += 1;
        };

        AbilityScore {
            strength: *assign6.at(0),
            dexterity: *assign6.at(1),
            constitution: *assign6.at(2),
            intelligence: *assign6.at(3),
            wisdom: *assign6.at(4),
            charisma: *assign6.at(5),
        }
    }

    fn random_skills(
        self: AdventurerClass, ref seeder: Seeder
    ) -> (SkillsSet, Skill, Skill) {
        let mut skills: SkillsSet = Default::default();
        match self {
            AdventurerClass::Fighter => {
                let r = seeder.random_u8();
                let chosen = AdventurerClassTrait::random_fighter_skill(r);
                skills.perception = chosen == Skill::Perception;
                skills.acrobatics = chosen == Skill::Acrobatics;
                skills.athletics = true;
                (skills, Skill::None, Skill::None)
            },
            AdventurerClass::Rogue => {
                let r0 = seeder.random_u8();
                let r1 = seeder.random_u8();
                let (skill0, skill1) = AdventurerClassTrait::random_rogue_skills(r0, r1);
                let r2 = seeder.random_u8();
                let r3 = seeder.random_u8();
                let (exp0, exp1) = AdventurerClassTrait::random_rogue_expertise(r2, r3, skill0, skill1);
                skills.athletics = skill0 == Skill::Athletics || skill1 == Skill::Athletics;
                skills.perception = skill0 == Skill::Perception || skill1 == Skill::Perception;
                skills.persuasion = skill0 == Skill::Persuasion || skill1 == Skill::Persuasion;
                skills.arcana = skill0 == Skill::Arcana || skill1 == Skill::Arcana;
                skills.stealth = true;
                skills.acrobatics = true;
                (skills, exp0, exp1)
            },
            AdventurerClass::Wizard => {
                let r = seeder.random_u8();
                let chosen = AdventurerClassTrait::random_wizard_skill(r);
                skills.perception = chosen == Skill::Perception;
                skills.persuasion = chosen == Skill::Persuasion;
                skills.arcana = true;
                (skills, Skill::None, Skill::None)
            },
            AdventurerClass::None => {
                (skills, Skill::None, Skill::None)
            },
        }
    }
}
