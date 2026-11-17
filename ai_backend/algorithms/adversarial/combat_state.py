"""
Combat state shared by Minimax and MCTS.

The fight is a turn-based two-player game:
  BOSS   = the AI that is choosing a move (MAX player)
  PLAYER = its opponent                   (MIN player)
(In AI vs AI mode the fighter that is thinking plays the "boss" role.)

State: both health bars, the distance between them, both energy bars and
both special-move cooldowns. Actions (the same for both sides):
  attack, block, dodge, move_closer, move_away, special
"""
from dataclasses import dataclass, replace

ACTIONS = ["attack", "block", "dodge", "move_closer", "move_away", "special"]

# Simple damage rules
MELEE_RANGE = 120.0      # attack up close: 10 damage (a punch)
BLAST_RANGE = 450.0      # attack from further away: 6 damage (a shot); beyond this it misses
SPECIAL_RANGE = 300.0    # special: 22 damage, costs 50 energy, then 3 turns cooldown
SPECIAL_COST = 50.0
BLOCK_FACTOR = 0.4       # a blocked hit only does 40% damage
GOOD_DISTANCE = 120.0    # the boss likes to stay within punching distance


@dataclass(frozen=True)
class CombatState:
    boss_hp: float = 100.0
    player_hp: float = 100.0
    distance: float = 300.0
    boss_energy: float = 50.0
    player_energy: float = 50.0
    boss_cooldown: int = 0        # turns until the boss can use "special" again
    player_cooldown: int = 0
    boss_guard: str = ""          # "", "block" or "dodge" (lasts until the boss's next turn)
    player_guard: str = ""
    boss_turn: bool = True        # True = the boss moves next

    def is_terminal(self) -> bool:
        return self.boss_hp <= 0 or self.player_hp <= 0

    def legal_actions(self) -> list:
        """Moves for whoever is next. "special" needs 50 energy and no cooldown."""
        if self.boss_turn:
            energy, cooldown = self.boss_energy, self.boss_cooldown
        else:
            energy, cooldown = self.player_energy, self.player_cooldown
        return [a for a in ACTIONS if a != "special" or (energy >= SPECIAL_COST and cooldown == 0)]

    def swapped(self) -> "CombatState":
        """The same state with the two fighters' roles swapped."""
        return CombatState(self.player_hp, self.boss_hp, self.distance, self.player_energy, self.boss_energy,
                           self.player_cooldown, self.boss_cooldown, self.player_guard, self.boss_guard,
                           not self.boss_turn)

    def apply_action(self, action: str) -> "CombatState":
        """Returns the next state after the fighter whose turn it is does `action`."""
        if not self.boss_turn:
            # The player uses exactly the same rules: swap roles, act, swap back.
            return self.swapped().apply_action(action).swapped()

        # From here on the BOSS acts.
        s = replace(self, boss_guard="", boss_cooldown=max(0, self.boss_cooldown - 1))
        damage = 0.0
        if action == "attack":
            if s.distance <= MELEE_RANGE:
                damage = 10.0
            elif s.distance <= BLAST_RANGE:
                damage = 6.0
            s = replace(s, boss_energy=min(100.0, s.boss_energy + 10.0))
        elif action == "special":
            damage = 22.0 if s.distance <= SPECIAL_RANGE else 0.0
            s = replace(s, boss_energy=s.boss_energy - SPECIAL_COST, boss_cooldown=3)
        elif action == "block":
            s = replace(s, boss_guard="block", boss_energy=min(100.0, s.boss_energy + 5.0))
        elif action == "dodge":
            s = replace(s, boss_guard="dodge", distance=min(800.0, s.distance + 80.0),
                        boss_energy=max(0.0, s.boss_energy - 10.0))
        elif action == "move_closer":
            s = replace(s, distance=max(40.0, s.distance - 100.0), boss_energy=min(100.0, s.boss_energy + 5.0))
        elif action == "move_away":
            s = replace(s, distance=min(800.0, s.distance + 100.0), boss_energy=min(100.0, s.boss_energy + 5.0))

        # The player's guard from its last turn reduces (block) or avoids (dodge) the hit.
        if s.player_guard == "block":
            damage *= BLOCK_FACTOR
        elif s.player_guard == "dodge":
            damage = 0.0
        return replace(s, player_hp=max(0.0, s.player_hp - damage), boss_turn=False)


def evaluate(state: CombatState) -> float:
    """How good the state is for the BOSS (higher = better):
    the boss keeps its health, the player loses health, the boss stays at a good distance."""
    if state.player_hp <= 0:
        return 1000.0                                   # boss won
    if state.boss_hp <= 0:
        return -1000.0                                  # boss lost
    score = state.boss_hp - state.player_hp             # health difference
    if state.distance <= GOOD_DISTANCE:
        score += 5.0                                    # good distance: can punch
    elif state.distance > BLAST_RANGE:
        score -= 5.0                                    # too far to hurt the player
    score += 0.1 * (state.boss_energy - state.player_energy)   # small bonus for more energy
    return score
