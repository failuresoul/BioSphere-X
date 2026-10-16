"""
Simplified Combat State Representation for BioSphere-X Boss Encounter.
Models real-time boss-vs-player combat as a discrete adversarial decision space.
Defines state variables, legal actions, state transitions, terminal conditions,
and heuristic evaluation for Minimax, Alpha-Beta, and MCTS algorithms.
"""
from dataclasses import dataclass, field
from typing import List, Dict, Any, Optional
import copy


# Boss Actions
ACTION_TREMOR_SLAM = "TREMOR_SLAM"
ACTION_PLASMA_BARRAGE = "PLASMA_BARRAGE"
ACTION_CHARGE_RUSH = "CHARGE_RUSH"
ACTION_PURSUE_ADVANCE = "PURSUE_ADVANCE"
ACTION_TACTICAL_RETREAT = "TACTICAL_RETREAT"
ACTION_GUARD_STANCE = "GUARD_STANCE"
ACTION_RECOVER_WAIT = "RECOVER_WAIT"

BOSS_ACTIONS = [
    ACTION_TREMOR_SLAM,
    ACTION_PLASMA_BARRAGE,
    ACTION_CHARGE_RUSH,
    ACTION_PURSUE_ADVANCE,
    ACTION_TACTICAL_RETREAT,
    ACTION_GUARD_STANCE,
    ACTION_RECOVER_WAIT,
]

# Player Actions (for adversarial simulation)
ACTION_PLAYER_SHOOT = "PLAYER_SHOOT"
ACTION_PLAYER_DODGE = "PLAYER_DODGE"
ACTION_PLAYER_CLOSE_IN = "PLAYER_CLOSE_IN"
ACTION_PLAYER_FALL_BACK = "PLAYER_FALL_BACK"
ACTION_PLAYER_REST = "PLAYER_REST"

PLAYER_ACTIONS = [
    ACTION_PLAYER_SHOOT,
    ACTION_PLAYER_DODGE,
    ACTION_PLAYER_CLOSE_IN,
    ACTION_PLAYER_FALL_BACK,
    ACTION_PLAYER_REST,
]


@dataclass
class CombatState:
    """
    Simplified discrete representation of the combat state between Goliath Prime and the Player.
    """
    # Turn: 'boss' (MAX) or 'player' (MIN)
    turn: str = "boss"
    
    # Boss parameters
    boss_hp: float = 500.0
    boss_max_hp: float = 500.0
    boss_phase: int = 1
    slam_cooldown: float = 0.0
    barrage_cooldown: float = 0.0
    charge_cooldown: float = 0.0
    is_recovering: bool = False
    recover_timer: float = 0.0
    is_guarding: bool = False
    
    # Player parameters
    player_hp: float = 100.0
    player_max_hp: float = 100.0
    player_energy: float = 100.0
    
    # Spatial parameters
    distance: float = 200.0  # Distance in pixels between Boss and Player
    arena_radius: float = 500.0
    
    # Simulation step depth counter
    step_count: int = 0
    max_steps: int = 20

    def clone(self) -> 'CombatState':
        """Creates a deep copy of the combat state."""
        return copy.deepcopy(self)

    def is_terminal(self) -> bool:
        """
        Terminal conditions:
        - Boss defeated (boss_hp <= 0)
        - Player defeated (player_hp <= 0)
        - Max simulation step limit reached
        """
        if self.boss_hp <= 0.0 or self.player_hp <= 0.0:
            return True
        if self.step_count >= self.max_steps:
            return True
        return False

    def get_legal_actions(self) -> List[str]:
        """
        Returns list of valid actions for the current actor ('boss' or 'player').
        """
        if self.is_terminal():
            return []

        if self.turn == "boss":
            return self._get_legal_boss_actions()
        else:
            return self._get_legal_player_actions()

    def _get_legal_boss_actions(self) -> List[str]:
        # If currently recovering, must wait out recovery
        if self.is_recovering or self.recover_timer > 0.0:
            return [ACTION_RECOVER_WAIT]

        actions: List[str] = []

        # 1. Tremor Slam: close-range area attack
        if self.slam_cooldown <= 0.0 and self.distance <= 145.0:
            actions.append(ACTION_TREMOR_SLAM)

        # 2. Plasma Barrage: mid-range projectile starburst
        if self.barrage_cooldown <= 0.0 and self.distance <= 360.0:
            actions.append(ACTION_PLASMA_BARRAGE)

        # 3. Charge Rush: linear rush across distance
        if self.charge_cooldown <= 0.0 and self.distance >= 90.0 and self.distance <= 320.0:
            actions.append(ACTION_CHARGE_RUSH)

        # 4. Pursue Advance: close distance if not right on top of player
        if self.distance > 40.0:
            actions.append(ACTION_PURSUE_ADVANCE)

        # 5. Tactical Retreat: back up to set up ranged barrage or charge
        if self.distance < 380.0:
            actions.append(ACTION_TACTICAL_RETREAT)

        # 6. Guard Stance: defensive posture
        actions.append(ACTION_GUARD_STANCE)

        return actions if actions else [ACTION_GUARD_STANCE]

    def _get_legal_player_actions(self) -> List[str]:
        actions: List[str] = []

        # Player can shoot if they have energy
        if self.player_energy >= 15.0:
            actions.append(ACTION_PLAYER_SHOOT)

        # Player can dodge/dash if they have energy
        if self.player_energy >= 20.0:
            actions.append(ACTION_PLAYER_DODGE)

        # Positioning actions
        if self.distance > 40.0:
            actions.append(ACTION_PLAYER_CLOSE_IN)
        if self.distance < 450.0:
            actions.append(ACTION_PLAYER_FALL_BACK)

        # Rest to recharge energy
        actions.append(ACTION_PLAYER_REST)

        return actions if actions else [ACTION_PLAYER_REST]

    def apply_action(self, action: str) -> 'CombatState':
        """
        Executes an action and returns the resulting CombatState transition.
        """
        next_state = self.clone()
        next_state.step_count += 1

        if self.turn == "boss":
            next_state._apply_boss_action(action)
            next_state.turn = "player"
        else:
            next_state._apply_player_action(action)
            next_state.turn = "boss"

        # Check phase update (enrage at <= 50% HP)
        if next_state.boss_hp <= (next_state.boss_max_hp * 0.50) and next_state.boss_phase == 1:
            next_state.boss_phase = 2

        # Clamp HP bounds
        next_state.boss_hp = max(0.0, min(next_state.boss_max_hp, next_state.boss_hp))
        next_state.player_hp = max(0.0, min(next_state.player_max_hp, next_state.player_hp))
        next_state.player_energy = max(0.0, min(100.0, next_state.player_energy))
        next_state.distance = max(20.0, min(500.0, next_state.distance))

        return next_state

    def _apply_boss_action(self, action: str) -> None:
        # Tick down existing cooldowns
        tick_time = 0.8
        self.slam_cooldown = max(0.0, self.slam_cooldown - tick_time)
        self.barrage_cooldown = max(0.0, self.barrage_cooldown - tick_time)
        self.charge_cooldown = max(0.0, self.charge_cooldown - tick_time)
        self.is_guarding = False

        if action == ACTION_RECOVER_WAIT:
            self.recover_timer = max(0.0, self.recover_timer - tick_time)
            if self.recover_timer <= 0.0:
                self.is_recovering = False
            return

        if action == ACTION_TREMOR_SLAM:
            dmg = 35.0 if self.boss_phase == 1 else 45.0
            if self.distance <= 145.0:
                self.player_hp -= dmg
            self.slam_cooldown = 3.5
            self.is_recovering = True
            self.recover_timer = 0.8 if self.boss_phase == 1 else 0.5

        elif action == ACTION_PLASMA_BARRAGE:
            dmg = 24.0 if self.boss_phase == 1 else 36.0
            # Barrage hit chance scales inversely with distance
            hit_factor = max(0.4, 1.0 - (self.distance / 500.0))
            self.player_hp -= dmg * hit_factor
            self.barrage_cooldown = 4.0
            self.is_recovering = True
            self.recover_timer = 0.8 if self.boss_phase == 1 else 0.5

        elif action == ACTION_CHARGE_RUSH:
            dmg = 30.0 if self.boss_phase == 1 else 40.0
            self.player_hp -= dmg
            self.distance = max(30.0, self.distance - 180.0)
            self.charge_cooldown = 5.0
            self.is_recovering = True
            self.recover_timer = 1.2 if self.boss_phase == 1 else 0.7

        elif action == ACTION_PURSUE_ADVANCE:
            step = 85.0 if self.boss_phase == 1 else 115.0
            self.distance = max(30.0, self.distance - step)

        elif action == ACTION_TACTICAL_RETREAT:
            step = 70.0
            self.distance = min(450.0, self.distance + step)

        elif action == ACTION_GUARD_STANCE:
            self.is_guarding = True
            # Guarding passively cools down all attacks faster
            self.slam_cooldown = max(0.0, self.slam_cooldown - 0.5)
            self.barrage_cooldown = max(0.0, self.barrage_cooldown - 0.5)
            self.charge_cooldown = max(0.0, self.charge_cooldown - 0.5)

    def _apply_player_action(self, action: str) -> None:
        if action == ACTION_PLAYER_SHOOT:
            dmg = 18.0
            self.player_energy = max(0.0, self.player_energy - 15.0)
            if self.is_guarding:
                dmg *= 0.8  # Guard damage reduction
            elif self.is_recovering:
                dmg *= 1.25  # Vulnerability counterattack window
            self.boss_hp -= dmg

        elif action == ACTION_PLAYER_DODGE:
            self.player_energy = max(0.0, self.player_energy - 20.0)
            self.distance = min(450.0, self.distance + 80.0)

        elif action == ACTION_PLAYER_CLOSE_IN:
            self.distance = max(30.0, self.distance - 65.0)
            self.player_energy = min(100.0, self.player_energy + 5.0)

        elif action == ACTION_PLAYER_FALL_BACK:
            self.distance = min(450.0, self.distance + 65.0)
            self.player_energy = min(100.0, self.player_energy + 5.0)

        elif action == ACTION_PLAYER_REST:
            self.player_energy = min(100.0, self.player_energy + 25.0)


def evaluate_combat_state(state: CombatState) -> float:
    """
    Heuristic evaluation function from Goliath Prime's perspective (MAX player).
    Positive values favor Goliath Prime (boss), negative values favor the Player.
    
    Evaluates:
    1. Health ratio differential
    2. Cooldown availability & combat readiness
    3. Distance alignment with optimal attack profiles
    4. Vulnerability & defensive stance weighting
    5. Phase 2 Enrage pressure
    """
    # 1. Terminal victory / defeat evaluations
    if state.player_hp <= 0.0:
        return 10000.0 - (state.step_count * 10.0)  # Favor faster victory
    if state.boss_hp <= 0.0:
        return -10000.0 + (state.step_count * 10.0)  # Favor slower loss

    score = 0.0

    # 2. Health Differential (Scale: -500 to +500)
    boss_hp_ratio = state.boss_hp / max(1.0, state.boss_max_hp)
    player_hp_ratio = state.player_hp / max(1.0, state.player_max_hp)
    score += (boss_hp_ratio * 300.0) - (player_hp_ratio * 400.0)

    # 3. Cooldown Readiness Bonuses
    if state.slam_cooldown <= 0.0:
        score += 35.0
    if state.barrage_cooldown <= 0.0:
        score += 30.0
    if state.charge_cooldown <= 0.0:
        score += 25.0

    # 4. Tactical Distance Alignment
    # Close range: Tremor Slam is king
    if state.distance <= 140.0:
        if state.slam_cooldown <= 0.0:
            score += 55.0  # Prime position for slam
        else:
            score -= 20.0  # Too close without slam ready

    # Mid range (140 to 300): Great for charge or barrage
    elif 140.0 < state.distance <= 300.0:
        if state.charge_cooldown <= 0.0 or state.barrage_cooldown <= 0.0:
            score += 45.0

    # Long range (> 300): Boss is vulnerable to player kiting unless barrage ready
    else:
        if state.barrage_cooldown > 0.0:
            score -= 30.0

    # 5. Recovery Vulnerability & Guarding
    if state.is_recovering:
        score -= 40.0
    if state.is_guarding:
        score += 15.0

    # 6. Phase 2 Enrage Aggression
    if state.boss_phase == 2:
        score += 20.0  # Phase 2 has heightened damage and projectile density

    # 7. Player Energy Starvation
    player_energy_ratio = state.player_energy / 100.0
    score -= (player_energy_ratio * 25.0)

    return score
