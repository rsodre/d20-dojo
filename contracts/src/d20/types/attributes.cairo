#[derive(Drop)]
pub struct CharacterAttributes {
    pub explorer_class: ByteArray,
    pub level: u8,
    pub current_hp: i16,
    pub max_hp: u16,
    pub armor_class: u8,
    pub strength: u8,
    pub dexterity: u8,
    pub constitution: u8,
    pub intelligence: u8,
    pub wisdom: u8,
    pub charisma: u8,
    pub is_dead: bool,
}
