"""Bidirectional Search: one BFS from the start and one from the goal.
Uninformed. When the two searches meet, the two half-paths are joined."""
import time
from collections import deque
from .common import make_path, neighbors, result


def search(grid, start, goal):
    t0 = time.perf_counter()
    start, goal = tuple(start), tuple(goal)
    if start == goal:
        return result("bidirectional", True, [start], 1, t0)
    queues = [deque([start]), deque([goal])]  # [forward, backward]
    parents = [{start: None}, {goal: None}]
    expanded = 0
    while queues[0] and queues[1]:
        for side in (0, 1):                    # one step forward, one step backward
            cell = queues[side].popleft()
            expanded += 1
            for nxt in neighbors(grid, cell):
                if nxt in parents[side]:
                    continue
                parents[side][nxt] = cell
                queues[side].append(nxt)
                if nxt in parents[1 - side]:   # the two searches meet at nxt
                    front = make_path(parents[0], nxt)          # start ... nxt
                    back = make_path(parents[1], nxt)[::-1]     # nxt ... goal
                    return result("bidirectional", True, front + back[1:], expanded, t0)
            if not queues[side]:
                break
    return result("bidirectional", False, [], expanded, t0)
