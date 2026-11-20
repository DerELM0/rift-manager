class_name TraitChip
extends Label
## Ein Trait als Chip mit Tooltip. Text und Art kommen aus data/default/traits.csv
## (über TraitRules). Positive Traits: Theme-Variante "TraitPositiveChip",
## negative "TraitNegativeChip", gemischte und unbekannte "ChipLabel".


func setup(trait_name: String) -> void:
	text = trait_name
	var info: TraitDef = TraitRules.get_trait(trait_name)
	if info == null:
		tooltip_text = "Unbekannter Trait (fehlt in traits.csv)."
		theme_type_variation = &"ChipLabel"
		return
	tooltip_text = info.tooltip if not info.tooltip.is_empty() else "Noch keine Beschreibung."
	match info.art:
		"positiv":
			theme_type_variation = &"TraitPositiveChip"
		"negativ":
			theme_type_variation = &"TraitNegativeChip"
		_:
			theme_type_variation = &"ChipLabel"
