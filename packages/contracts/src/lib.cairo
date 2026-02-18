pub mod systems {
    pub mod explorer_token;
    pub mod combat_system;
    pub mod temple_token;
}

pub mod models {
    pub mod config;
    pub mod explorer;
    pub mod temple;
}

pub mod types {
    pub mod index;
    pub mod explorer;
    pub mod items;
    pub mod spells;
    pub mod monster;
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
    pub mod test_integration;
    pub mod test_ownership;
}
