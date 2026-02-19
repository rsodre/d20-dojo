use d20::types::index::Skill;
use d20::types::explorer_class::{ExplorerClass, ExplorerClassTrait};
use d20::utils::seeder::{Seeder, SeederTrait};
use d20::models::explorer::AbilityScore;

// ── Standard array ───────────────────────────────────────────────────────────

/// The standard array values in descending order: [15, 14, 13, 12, 10, 8]
pub fn standard_array() -> Span<u8> {
    array![15_u8, 14_u8, 13_u8, 12_u8, 10_u8, 8_u8].span()
}

// ── Trait ────────────────────────────────────────────────────────────────────

#[generate_trait]
pub impl ExplorerClassGeneratorImpl of ExplorerClassGeneratorTrait {
    /// Returns AbilityScore.
    fn random_stat_assignment(self: ExplorerClass, ref seeder: Seeder) -> AbilityScore {
        // preferred_stat_order returns [STR_idx, DEX_idx, CON_idx, INT_idx, WIS_idx, CHA_idx]
        // Each value is which position in the sorted array (0=15, 1=14, ..., 5=8) to assign.
        let order = self.preferred_stat_order();
        let sa = standard_array();

        // Build assignment array: assign[ability] = stat_value
        let mut assign: Array<u8> = array![
            *sa.at((*order.at(0)).into()),
            *sa.at((*order.at(1)).into()),
            *sa.at((*order.at(2)).into()),
            *sa.at((*order.at(3)).into()),
            *sa.at((*order.at(4)).into()),
            *sa.at((*order.at(5)).into()),
        ];

        // Full Fisher-Yates shuffle (5 swaps) using VRF bytes
        let r0 = seeder.random_u8();
        let r1 = seeder.random_u8();
        let r2 = seeder.random_u8();
        let r3 = seeder.random_u8();
        let r4 = seeder.random_u8();

        // Swap [5] with [r0 % 6]
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

        // Swap [4] with [r1 % 5]
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

        // Swap [3] with [r2 % 4]
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

        // Swap [2] with [r3 % 3]
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

        // Swap [1] with [r4 % 2]
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

    /// Randomly pick skills (and expertise for Rogue) using VRF.
    /// Returns (athletics, stealth, perception, persuasion, arcana, acrobatics, expertise_1, expertise_2).
    fn random_skills(
        self: ExplorerClass, ref seeder: Seeder
    ) -> (bool, bool, bool, bool, bool, bool, Skill, Skill) {
        match self {
            ExplorerClass::Fighter => {
                let r = seeder.random_u8();
                let chosen = ExplorerClassTrait::random_fighter_skill(r);
                let perception = chosen == Skill::Perception;
                let acrobatics = chosen == Skill::Acrobatics;
                // Fighter always has Athletics; no expertise
                (true, false, perception, false, false, acrobatics, Skill::None, Skill::None)
            },
            ExplorerClass::Rogue => {
                let r0 = seeder.random_u8();
                let r1 = seeder.random_u8();
                let (skill0, skill1) = ExplorerClassTrait::random_rogue_skills(r0, r1);
                let r2 = seeder.random_u8();
                let r3 = seeder.random_u8();
                let (exp0, exp1) = ExplorerClassTrait::random_rogue_expertise(r2, r3, skill0, skill1);
                let athletics = skill0 == Skill::Athletics || skill1 == Skill::Athletics;
                let perception = skill0 == Skill::Perception || skill1 == Skill::Perception;
                let persuasion = skill0 == Skill::Persuasion || skill1 == Skill::Persuasion;
                let arcana = skill0 == Skill::Arcana || skill1 == Skill::Arcana;
                // Rogue always has Stealth and Acrobatics
                (athletics, true, perception, persuasion, arcana, true, exp0, exp1)
            },
            ExplorerClass::Wizard => {
                let r = seeder.random_u8();
                let chosen = ExplorerClassTrait::random_wizard_skill(r);
                let perception = chosen == Skill::Perception;
                let persuasion = chosen == Skill::Persuasion;
                // Wizard always has Arcana; no expertise
                (false, false, perception, persuasion, true, false, Skill::None, Skill::None)
            },
            ExplorerClass::None => {
                (false, false, false, false, false, false, Skill::None, Skill::None)
            },
        }
    }
}
