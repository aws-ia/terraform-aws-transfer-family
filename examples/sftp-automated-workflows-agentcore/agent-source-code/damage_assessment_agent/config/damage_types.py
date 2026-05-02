"""Damage type and severity enums for the damage assessment agent."""

from enum import StrEnum


class DamageType(StrEnum):
    WATER_DAMAGE = "water_damage"
    FIRE_DAMAGE = "fire_damage"
    WIND_DAMAGE = "wind_damage"
    COLLISION = "collision"
    VANDALISM = "vandalism"
    THEFT = "theft"
    OTHER = "other"


class Severity(StrEnum):
    MINOR = "minor"
    MODERATE = "moderate"
    SEVERE = "severe"
    TOTAL_LOSS = "total_loss"


DAMAGE_TYPE_DESCRIPTIONS: dict[str, str] = {
    DamageType.WATER_DAMAGE: (
        "Water-related damage including flooding, leaks, burst pipes, and moisture damage to structures or contents."
    ),
    DamageType.FIRE_DAMAGE: "Fire or smoke damage to structures, contents, or surrounding areas.",
    DamageType.WIND_DAMAGE: "Wind-related damage including storm damage, fallen trees, and structural wind damage.",
    DamageType.COLLISION: "Vehicle or object collision damage to property or vehicles.",
    DamageType.VANDALISM: "Intentional damage or defacement of property.",
    DamageType.THEFT: "Evidence of forced entry or stolen property.",
    DamageType.OTHER: "Damage that does not fit the above categories.",
}
