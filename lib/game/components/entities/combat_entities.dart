import 'package:dungeon_crawler/game/components/core/palette.dart';
import 'package:dungeon_crawler/game/components/entities/item.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

enum CombatPhase { idle, walk, guard, windup, active, recovery, entering, exiting, hit }

class PlayerCombatStats {
  double hp = 100, maxHp = 100, mana = 50, maxMana = 50, essence = 0;
  double manaRegen = 1 ;
  double stamina = 100.0, maxStamina = 100.0; 
  double staminaTmr = 0.0; 
  double staminaRegenDelay = 1.0;
  double staminaInfiniteTmr = 0;
  double strafePosition = 0.0; 
  bool isGuarding = false, attackHit = false;
  int comboCount = 0;
  double comboTimer = 0.0, animTimer = 0.0;
  CombatPhase currentPhase = CombatPhase.idle;

  double moveSpeed = 2;
  double moveSpeedIni = 2;

  // --- DIMENSÕES E OFFSETS DO PLAYER ---
  // Tamanho do corpo vulnerável do jogador
  double hurtboxWidth = 60.0;
  double hurtboxHeight = 120.0;
  double hurtboxOffsetY = 0.0; 

  // Tamanho do golpe da arma do jogador
  double hitboxWidth = 70.0;
  double hitboxHeight = 120.0;
  // Offset Y negativo sobe a caixa (útil para acertar aranhas e voadores)
  double hitboxOffsetY = -80.0; 
  double hitboxOffsetX = 0.0;

  double hitFlashTimer = 0.0;
  Color flashColor = Palette.vermelho;

  //variaveis da arma
  double windupTime = 0.1;
  double activeTime = 0.1;
  double recoveryTime = 0.1;
  double staminaCost = 20.0;
  double damage = 10;
  double offYWeapon = 0;

  //variaveis da armadura
  double staminaRegenBonus = 0;

  //variaveis do escudo
  double staminaBlockCost = 0;
  double moveSpeedPenalty = 0;

  bool cansado = false;

  List<Item> inventory = [];
  Item? equippedWeapon;
  Item? equippedArmor;
  Item? equippedShield;

  //List<PlayerProjectile> activeProjectiles = [];
  double healVfxTimer = 0.0;
  double explosionVfxTimer = 0.0;
  double manaVfxTimer = 0.0;

  List<Item> get consumables => inventory.where((i) => i.type == ItemType.consumable || i.type == ItemType.spell).toList();

  void recoverStamina(double dt) {
    if(staminaTmr > 0) {
      staminaTmr -= dt;
      return; // Ainda no delay, não regenera
    }
    if (!isGuarding && stamina < maxStamina) {
      stamina += (75.0 + staminaRegenBonus) * dt; 
      if (stamina > maxStamina){
        stamina = maxStamina;
        if(cansado) {
          cansado = false; // Recuperou o fôlego!
        }
      } 
    }
  }

  void recoverMana() {
    if (mana < maxMana) {
      mana += manaRegen; 
      if (mana > maxMana){
        mana = maxMana;
      } 
    }
    
  }

  void applyHitStun(double duration) {
    flashColor = Palette.vermelho;
    hitFlashTimer = duration;
    currentPhase = CombatPhase.hit; // Interrompe qualquer ação atual
    comboCount = 0; // Quebra o combo
    attackHit = false; // Cancela ataques ativos
  }

  void updatePhase(double dt) {
    if(staminaInfiniteTmr > 0) {
      staminaInfiniteTmr -= dt;
    }
    if (cansado){
      if(moveSpeed != moveSpeedIni * 0.75) {
        moveSpeed = moveSpeedIni * 0.75;
      }
    }else{
      if(moveSpeed != moveSpeedIni) {
        moveSpeed = moveSpeedIni;
      }
    }
    if (healVfxTimer > 0) healVfxTimer -= dt;
    if (explosionVfxTimer > 0) explosionVfxTimer -= dt;
    if (manaVfxTimer > 0) manaVfxTimer -= dt;
    if (hitFlashTimer > 0) {
      hitFlashTimer -= dt;
      if (hitFlashTimer <= 0 && currentPhase == CombatPhase.hit) {
        currentPhase = CombatPhase.idle; // Acordou da paralisia
      }
      return; // Impede que o resto da lógica continue rodando
    }
    if (comboCount > 0) {
      comboTimer -= dt;
      if (comboTimer <= 0) {
        comboCount = 0; // O tempo acabou! Reseta o combo para o primeiro golpe.
      }
    }
    if (currentPhase == CombatPhase.windup || currentPhase == CombatPhase.active || currentPhase == CombatPhase.recovery || currentPhase == CombatPhase.entering || currentPhase == CombatPhase.exiting) {
      animTimer -= dt;
      if (animTimer <= 0) {
        switch (currentPhase) {
          case CombatPhase.windup: currentPhase = CombatPhase.active; animTimer = windupTime; break;
          case CombatPhase.active: currentPhase = CombatPhase.recovery; animTimer = recoveryTime; break;
          case CombatPhase.recovery: currentPhase = CombatPhase.idle; attackHit = false; break;
          case CombatPhase.entering: currentPhase = CombatPhase.idle; break;
          case CombatPhase.exiting: break; 
          default: currentPhase = CombatPhase.idle; break;
        }
      }
    }
  }

  Rect getHurtbox(Vector2 screenSize) {
    double scale = screenSize.x * 0.35;
    double cx = (screenSize.x / 2) + (strafePosition * scale);
    double cy = screenSize.y - 70 - 55; // Posição Y base do jogador
    return Rect.fromCenter(center: Offset(cx, cy + hurtboxOffsetY), width: hurtboxWidth, height: hurtboxHeight);
  }

  Rect getHitbox(Vector2 screenSize) {
    double scale = screenSize.x * 0.35;
    double cx = (screenSize.x / 2) + (strafePosition * scale);
    double cy = screenSize.y - 70 - 55;
    return Rect.fromCenter(center: Offset(cx + hitboxOffsetX, cy + hitboxOffsetY), width: hitboxWidth, height: hitboxHeight);
  }

  Rect getHitboxImageSize(Vector2 screenSize) {
    double scale = screenSize.x * 0.35;
    double cx = (screenSize.x / 2) + (strafePosition * scale);
    double cy = screenSize.y - 70 - 55;
    return Rect.fromCenter(center: Offset(cx + hitboxOffsetX, cy + hitboxOffsetY), width: 120, height: 120);
  }

}

