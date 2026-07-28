import 'package:a_blade_in_the_abyss/game/components/core/audio_manager.dart';
import 'package:a_blade_in_the_abyss/game/components/core/palette.dart';
import 'package:a_blade_in_the_abyss/game/components/entities/item.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

enum CombatPhase { idle, walk, guard, windup, active, recovery, entering, exiting, hit, summon, die, windup2, active2, recovery2 }

class PlayerCombatStats {
  double hp = 30, maxHp = 30, mana = 15, essence = 0;
  double stamina = 15.0; 
  double staminaTmr = 0.0; 
  double staminaRegenDelay = 0.5;
  double staminaInfiniteTmr = 0;
  double buffForcaTmr = 0;
  double strafePosition = 0.0; 
  bool isGuarding = false, attackHit = false;
  int comboCount = 0;
  double comboTimer = 0.0, animTimer = 0.0;
  CombatPhase currentPhase = CombatPhase.idle;
  bool reflex = false;

  int str = 5, con = 5, wis = 5, base = 5;

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
  double flashTimer = 0;

  //variaveis da arma
  double windupTime = 0.1;
  double activeTime = 0.1;
  double recoveryTime = 0.1;
  double offYWeapon = 0;
  double critChance = 5;
  double critMultiplier = 1.5;

  //variaveis da armadura
  double staminaRegenBonus = 0;

  //variaveis do escudo
  double staminaBlockCost = 0;
  double moveSpeedPenalty = 0;

  bool cansado = false;

  List<Item> inventory = [];
  int maxInventory = 8;

  Item? equippedWeapon;
  Item? equippedArmor;
  Item? equippedShield;

  bool poison = false;
  int poisonTmr = 0;

  bool isCharging = false;
  double chargeTimer = 0.0;
  double chargeTime = 0.3;
  bool isHeavyAttack = false;

  //List<PlayerProjectile> activeProjectiles = [];
  double vfxTimer = 0.0;
  Color vfxColor = Palette.vermelho;

  double invencibleTmr = 0;

  List<Item> get consumables => inventory.where((i) => i.type == ItemType.consumable || i.type == ItemType.spell).toList();

  void recalculateMaxHp() {
    int pontosAdicionados = con - base;
    int blocosDeTres = pontosAdicionados ~/ 3; 
    double hpBonusPorBloco = 5.0; 
    double vidaBaseOriginal = 30.0;
    double antigaMaxHp = maxHp;

    maxHp = vidaBaseOriginal + (blocosDeTres * hpBonusPorBloco);

    if (maxHp > antigaMaxHp) {
      hp += (maxHp - antigaMaxHp);
    }
  }

  void recalculateMaxInventory() {
    int pontosAdicionados = str - base;
    int blocosDeCinco = pontosAdicionados ~/ 5; 
    int inventarioOriginal = 8;

    if(maxInventory < 10){
      maxInventory = inventarioOriginal + (blocosDeCinco);
    }
    
  }

  void recoverStamina(double dt) {
    if(staminaTmr > 0) {
      staminaTmr -= dt;
      return; 
    }
    if (!isGuarding && stamina < (con*3)) {
      stamina += ((str*3) + staminaRegenBonus) * dt; 
      if (stamina > (con*3)){
        stamina = (con*3);
        if(cansado) {
          cansado = false; 
        }
      } 
    }
  }

  void recoverMana() {
    if (mana < wis*3) {
      mana += (wis * 0.2); 
      if (mana > wis*3){
        mana = wis*3;
      } 
    }
    
  }

  void applyHitStun(double duration) {
    applyEffect(duration, Palette.vermelho);
    currentPhase = CombatPhase.hit; // Interrompe qualquer ação atual
    comboCount = 0; // Quebra o combo
    attackHit = false; // Cancela ataques ativos
    invencibleTmr = duration * 2;
  }

  void applyEffect(double duration, Color cor){
    vfxColor = cor;
    vfxTimer = duration;
  }

  void applyFlashEffect(double duration, Color cor){
    flashColor = cor;
    flashTimer = duration;
  }

  void updatePhase(double dt) {

    if(invencibleTmr > 0) {
      invencibleTmr -= dt;
    }
    
    if(staminaInfiniteTmr > 0) {
      staminaInfiniteTmr -= dt;
    }
    if(buffForcaTmr > 0) {
      buffForcaTmr -= dt;
    }
    /*
    if (cansado){
      if(moveSpeed != moveSpeedIni * 0.75) {
        moveSpeed = moveSpeedIni * 0.75;
      }
    }else{
      if(moveSpeed != moveSpeedIni) {
        moveSpeed = moveSpeedIni;
      }
    }
  */
    if (vfxTimer > 0){
      vfxTimer -= dt;
      if (vfxTimer <= 0 && currentPhase == CombatPhase.hit) {
        currentPhase = CombatPhase.idle; // Acordou da paralisia
      }
      return;
    } 

    if (flashTimer > 0){
      flashTimer -= dt;
    } 
    
    /*
    if (hitFlashTimer > 0) {
      hitFlashTimer -= dt;
      if (hitFlashTimer <= 0 && currentPhase == CombatPhase.hit) {
        currentPhase = CombatPhase.idle; // Acordou da paralisia
      }
      return; // Impede que o resto da lógica continue rodando
    }
    */
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
          case CombatPhase.windup: currentPhase = CombatPhase.active; animTimer = windupTime;  AudioManager.playSfx('sfx/attack.wav'); break;
          case CombatPhase.active: currentPhase = CombatPhase.recovery; animTimer = recoveryTime; break;
          case CombatPhase.recovery: currentPhase = CombatPhase.idle; attackHit = false; break;
          case CombatPhase.entering: currentPhase = CombatPhase.idle; break;
          case CombatPhase.exiting: break; 
          default: currentPhase = CombatPhase.idle; break;
        }
      }
    }
  }

  List<double> _getMetrics(Vector2 screenSize) {
    double aspect = screenSize.x / screenSize.y;
    // Garante que usa a mesma contenção de ecrã que o Combat Overlay
    double viewportWidth = aspect > 0.8 ? screenSize.y * 0.75 : screenSize.x;
    double baseMultiplier = (viewportWidth / 500.0).clamp(0.5, 5.0);
    return [viewportWidth, baseMultiplier];
  }

  Rect getHurtbox(Vector2 screenSize) {
    var metrics = _getMetrics(screenSize);
    double viewportWidth = metrics[0];
    double multiplier = metrics[1];

    double cx = (screenSize.x / 2) + (strafePosition * viewportWidth * 0.35);
    // Centraliza perfeitamente no sprite desenhado (igual ao código do Overlay)
    double cy = screenSize.y - (65 * multiplier) - ((196 * multiplier) / 2); 
    
    return Rect.fromCenter(
      center: Offset(cx, cy + (hurtboxOffsetY * multiplier)), 
      width: hurtboxWidth * multiplier, 
      height: hurtboxHeight * multiplier
    );
  }

  Rect getHitbox(Vector2 screenSize) {
    var metrics = _getMetrics(screenSize);
    double viewportWidth = metrics[0];
    double multiplier = metrics[1];

    double cx = (screenSize.x / 2) + (strafePosition * viewportWidth * 0.35);
    double cy = screenSize.y - (65 * multiplier) - ((196 * multiplier) / 2); 
    
    bool wide = equippedWeapon?.isWide ?? false;
    hitboxWidth = wide ? 140.0 : 70.0;

    return Rect.fromCenter(
      center: Offset(cx + (hitboxOffsetX * multiplier), cy + (hitboxOffsetY * multiplier)), 
      width: hitboxWidth * multiplier, 
      height: hitboxHeight * multiplier
    );
  }

  Rect getHitboxImageSize(Vector2 screenSize) {
    var metrics = _getMetrics(screenSize);
    double viewportWidth = metrics[0];
    double multiplier = metrics[1];

    double cx = (screenSize.x / 2) + (strafePosition * viewportWidth * 0.35);
    double cy = screenSize.y - (65 * multiplier) - ((196 * multiplier) / 2); 
    
    bool wide = equippedWeapon?.isWide ?? false;
    double size = wide ? 192.0 : 144.0;
    
    return Rect.fromCenter(
      center: Offset(cx + (hitboxOffsetX * multiplier), cy + (hitboxOffsetY * multiplier)), 
      width: size * multiplier, 
      height: size * multiplier
    );
  }

}

