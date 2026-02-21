pub mod d20 {
    pub mod components {
        pub mod character_component;
        pub mod combat_component;
        pub mod dungeon_component;
    }
    pub mod models {
        pub mod adventurer;
        pub mod dungeon;
        pub mod monster;
    }
    pub mod types {
        pub mod adventurer_class;
        pub mod attributes;
        pub mod damage;
        pub mod index;
        pub mod items;
        pub mod spells;
    }
}

pub mod systems {
    pub mod explorer_token;
    pub mod combat_system;
    pub mod temple_token;
}

pub mod models {
    pub mod config;
}

pub mod events;

pub mod constants;

pub mod utils {
    pub mod dice;
    pub mod vrf;
    pub mod seeder;
    pub mod dns;
}

#[cfg(test)]
pub mod tests {
    pub mod mock_vrf;
    pub mod test_explorer_token;
    pub mod test_combat_system;
    pub mod tester;
    pub mod test_temple_lifecycle;
    pub mod test_exploration;
    pub mod test_combat_and_progression;
    pub mod test_traps;
    pub mod test_looting;
    pub mod test_permadeath;
    pub mod test_boss_mechanics;
    pub mod test_cross_temple;
    pub mod test_multiplayer;
    pub mod test_full_flows;
}
