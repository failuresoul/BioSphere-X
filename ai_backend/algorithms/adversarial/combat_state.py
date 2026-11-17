"""
Simple combat state shared by Minimax and MCTS.

The fight is modelled as a turn-based two-player game:
  "me"    = the AI that is choosing an action (MAX player)
  "enemy" = its opponent                       (MIN player)

State variables: health, energy and special-move cooldown for both sides,
the distance between them, and a short-lived guard flag ("block"/"dodge").
"""
from dataclasses import dataclass, replace

ACTIONS = ["attack", "block", "dodge", "move_closer", "move_away", "special"]

MELEE_RANGE = 120.0     # punch range (pixels)
BLAST_RANGE = 450.0     # blaster range (pixels)
SPECIAL_RANGE = 300.0   # special move range (pixels)
SPECIAL_COST = 50.0     # energy needed for a special move


@dataclass(frozen=True)
class CombatState:
    my_hp: float = 100.0
    enemy_hp: float = 100.0
    distance: float = 300.0
    my_energy: float = 50.0
    enemy_energy: float = 50.0
    my_cooldown: int = 0         # turns until "special" is ready again
    enemy_cooldown: int = 0
    my_guard: str = ""           # "", "block" or "dodge"
    enemy_guard: str = ""
    my_turn: bool = True         # True = "me" moves next

    def is_terminal(self) -> bool:
        return self.my_hp <= 0 or self.enemy_hp <= 0

    def legal_actions(self) -> list:
        """Actions for whoever moves next. Special needs energy and no cooldown."""
        energy, cooldown = (self.my_energy, self.my_cooldown) if self.my_turn else (self.enemy_energy, self.enemy_cooldown)
        return [a for a in ACTIONS if a != "special" or (energy >= SPECIAL_COST and cooldown == 0)]

    def flipped(self) -> "CombatState":
        """Same state seen from the other fighter's point of view."""
        return CombatState(self.enemy_hp, self.my_hp, self.distance, self.enemy_energy, self.my_energy,
                           self.enemy_cooldown, self.my_cooldown, self.enemy_guard, self.my_guard, not self.my_turn)

    def apply(self, action: str) -> "CombatState":
        """Returns the next state after the player to move performs `action`."""
        if not self.my_turn:
            # Let the enemy act by flipping the view, acting as "me", and flipping back.
            return self.flipped().apply(action).flipped()

        s = replace(self, my_guard="", my_cooldown=max(0, self.my_cooldown - 1))
        damage = 0.0
        if action == "attack":
            damage = 10.0 if s.distance <= MELEE_RANGE else (6.0 if s.distance <= BLAST_RANGE else 0.0)
            s = replace(s, my_energy=min(100.0, s.my_energy + 10.0))
        elif action == "special":
            damage = 22.0 if s.distance <= SPECIAL_RANGE else 0.0
            s = replace(s, my_energy=s.my_energy - SPECIAL_COST, my_cooldown=3)
        elif action == "block":
            s = replace(s, my_guard="block", my_energy=min(100.0, s.my_energy + 5.0))
        elif action == "dodge":
            s = replace(s, my_guard="dodge", distance=min(800.0, s.distance + 80.0),
                        my_energy=max(0.0, s.my_energy - 10.0))
        elif action == "move_closer":
            s = replace(s, distance=max(40.0, s.distance - 100.0), my_energy=min(100.0, s.my_energy + 5.0))
        elif action == "move_away":
            s = replace(s, distance=min(800.0, s.distance + 100.0), my_energy=min(100.0, s.my_energy + 5.0))

        # The enemy's guard from its last turn reduces (block) or avoids (dodge) the hit.
        if s.enemy_guard == "block":
            damage *= 0.4
        elif s.enemy_guard == "dodge":
            damage = 0.0
        return replace(s, enemy_hp=max(0.0, s.enemy_hp - damage), my_turn=False)


def evaluate(state: CombatState) -> float:
    """Score from "me"'s point of view: (my_hp - enemy_hp) + small bonuses."""
    if state.enemy_hp <= 0:
        return 1000.0
    if state.my_hp <= 0:
        return -1000.0
    score = state.my_hp - state.enemy_hp
    score += 0.1 * (state.my_energy - state.enemy_energy)       # more energy is good
    if state.my_cooldown == 0 and state.my_energy >= SPECIAL_COST:
        score += 3.0                                             # special move is ready
    if state.distance <= MELEE_RANGE:
        score += 2.0                                             # pressure the enemy
    return score
