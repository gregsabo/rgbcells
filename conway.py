import itertools

def make_neighbors(in_tuple):
    x = in_tuple[0]
    y = in_tuple[1]
    yield x+1, y+1
    yield x+1, y
    yield x+1, y-1
    yield x, y+1
    yield x, y-1
    yield x-1, y+1
    yield x-1, y
    yield x-1, y-1

def step_world(old_world):
    possible_lives = set(generate_possible_lives(old_world))
    new_world = set()
    for coordinate in possible_lives:
        num_live_neighbors = count_neighbors(old_world, coordinate)
        if num_live_neighbors == 3:
            new_world.add(coordinate)
        if num_live_neighbors in (4, 5) and coordinate in old_world:
            new_world.add(coordinate)
    return new_world

def generate_possible_lives(world):
    for coordinate in world:
        for neighbor in make_neighbors(coordinate):
            yield neighbor

def count_neighbors(world, coordinate):
    neighbors = set(make_neighbors(coordinate))
    return sum(neighbor in world for neighbor in neighbors)

print step_world(step_world(set((
    (0, 0), (1, 1), (1, 2), (0, 2), (-1, 2)
))))