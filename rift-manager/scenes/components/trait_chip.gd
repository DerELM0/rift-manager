class_name TraitChip
extends Label
## Ein Trait als Chip mit Tooltip (Beschreibung aus TraitInfo).
## Positive Traits: Theme-Variante "TraitPositiveChip", negative "TraitNegativeChip",
## sonst "ChipLabel".


func setup(trait_name: String) -> void:
	text = trait_name
	tooltip_text = TraitInfo.description(trait_name)
	match TraitInfo.kind(trait_name):
		"+":
			theme_type_variation = &"TraitPositiveChip"
		"-":
			theme_type_variation = &"TraitNegativeChip"
		_:
			theme_type_variation = &"ChipLabel"
