import 'dart:math';

import 'package:a_blade_in_the_abyss/game/components/entities/item.dart';

class ItemModifier {
  final String name; 
  final String id; 
  final double powerMultiplier;
  final double valueMultiplier;
  final double staMultiplier;
  final int weightModifier;
  final int strModifier;

  const ItemModifier({
    required this.name,
    required this.id,
    this.powerMultiplier = 1.0,
    this.valueMultiplier = 1.0,
    this.weightModifier = 0,
    this.strModifier = 0,
    this.staMultiplier = 1.0,
  });

  // Lista de modificadores possíveis
  static const ItemModifier normal = ItemModifier(name: "", id: "mod_normal");
  
  static const ItemModifier rusty = ItemModifier(
    name: "Enferrujado", id: "mod_rusty", 
    powerMultiplier: 0.7, valueMultiplier: 0.5, weightModifier: 1
  );
  
  static const ItemModifier sharp = ItemModifier(
    name: "Afiado", id: "mod_sharp", 
    powerMultiplier: 1.2, valueMultiplier: 1.5
  );
  
  static const ItemModifier balanced = ItemModifier(
    name: "Balanceado", id: "mod_balanced", 
    powerMultiplier: 1.1, strModifier: -1, valueMultiplier: 1.3
    ,staMultiplier: 0.8
  );
  
  static const ItemModifier unbalanced = ItemModifier(
    name: "Desbalanceado", id: "mod_unbalanced"
    ,staMultiplier: 1.2
  );

  static const ItemModifier heavy = ItemModifier(
    name: "Pesado", id: "mod_heavy", 
    powerMultiplier: 1.3, weightModifier: 1, strModifier: 1, valueMultiplier: 1.2,staMultiplier: 1.1
  );
  
  static const ItemModifier light = ItemModifier(
    name: "Leve", id: "mod_light", 
    powerMultiplier: 0.9, weightModifier: -1, strModifier: -1, valueMultiplier: 1.2,staMultiplier: 0.9
  );
  
  static const ItemModifier broken = ItemModifier(
    name: "Quebrado", id: "mod_broken", 
    powerMultiplier: 0.4, valueMultiplier: 0.2
  );
  
  static const ItemModifier masterwork = ItemModifier(
    name: "Obra-prima", id: "mod_masterwork", 
    powerMultiplier: 1.5, valueMultiplier: 3.0, weightModifier: -1
  );

  static const ItemModifier magical = ItemModifier(
    name: "Mágico", id: "mod_magical", 
    powerMultiplier: 1.4, valueMultiplier: 2.0
  );

  static const ItemModifier reinforced = ItemModifier(
    name: "Reforçado", id: "mod_reinforced", 
    powerMultiplier: 1.3, weightModifier: 1, valueMultiplier: 1.5
  );

  static const ItemModifier impenetrable = ItemModifier(
    name: "Impenetrável", id: "mod_impenetrable", 
    powerMultiplier: 1.6, weightModifier: 2, staMultiplier: 1.2, valueMultiplier: 2.0
  );

   // === LISTAS SEPARADAS POR TIPO ===
  
  // Pool de Armas (Inclui Afiado, Balanceado, etc)
  static const List<ItemModifier> _weaponPool = [
    rusty, sharp, balanced, unbalanced, heavy, light, broken, masterwork, magical,
  ];

  // Pool de Defesa (Inclui Reforçado, Impenetrável, etc)
  static const List<ItemModifier> _armorShieldPool = [
    rusty, heavy, light, broken, masterwork, magical, reinforced, impenetrable,
  ];

  // Função atualizada para receber o ItemType
  static ItemModifier getRandomModifier(ItemType type, {double chanceForNormal = 0.4}) {
    final rand = Random();
    if (rand.nextDouble() < chanceForNormal) {
      return normal;
    }
    
    // Escolhe a lista correta baseada no tipo do item
    List<ItemModifier> pool;
    if (type == ItemType.weapon) {
      pool = _weaponPool;
    } else if (type == ItemType.armor || type == ItemType.shield) {
      pool = _armorShieldPool;
    } else {
      return normal; // Prevenção de erros para consumíveis/outros
    }

    return pool[rand.nextInt(pool.length)];
  }
}