# Advanced Fight Library - API Documentation

The `advanced_fight_lib` mod provides a comprehensive library for implementing advanced combat systems in Luanti. It integrates hitbox detection with attribute effects, supports both players and entities (including mobs), and provides sophisticated damage calculation, armor handling, and effect management.

## Key Features

- **Hitbox-based Combat:** Precise hit detection for different body parts
- **Body Part Health:** Individual health tracking for each body part
- **Dynamic Effects:** Attribute effects based on damage to specific body parts
- **Point Hit System:** Granular damage tracking for specific points within body parts
- **Player Support:** Full player combat with 3D Armor integration
- **Mob Support:** Integration with Mobs Redo API (version >= 20251117)
- **Shield System:** Angle-based shield blocking with recovery mechanics
- **Storage System:** Persistent combat data for players and entities

## Global Namespace

All API functions are available under the `advanced_fight_lib` global table.

## Core Functions

### Storage Management

#### `advanced_fight_lib.get_object_storage(obj)`

Get the storage data for an object (player or entity).

**Parameters:**
- `obj` (ObjectRef): The player or entity object

**Returns:**
- `table`: Storage table containing combat-related data
  - For players: Stored in player metadata and cached
  - For entities: Returns the luaentity table directly

**Example:**
```lua
local storage = advanced_fight_lib.get_object_storage(player)
if storage._parts_health then
    print("Player has body part health tracking")
end
```

---

#### `advanced_fight_lib.set_object_storage(obj, data)`

Save the storage data for an object (players only).

**Parameters:**
- `obj` (ObjectRef): The player object
- `data` (table): Storage data to save

**Note:** For entities, this is a no-op as they use their luaentity table directly.

**Example:**
```lua
local storage = advanced_fight_lib.get_object_storage(player)
storage.my_custom_data = "value"
advanced_fight_lib.set_object_storage(player, storage)
```

---

### Entity and Object Management

#### `advanced_fight_lib.get_entity(name_list)`

Find a registered entity by name from a list of candidates.

**Parameters:**
- `name_list` (table): Array of entity names to search

**Returns:**
- `string, table`: Entity name and entity definition, or `nil, nil` if not found

**Example:**
```lua
local ent_name, ent_def = advanced_fight_lib.get_entity({
    "mobs_monster:dirt_monster",
    "mobs_monster:tree_monster"
})
```

---

### Body Part Health System

#### `advanced_fight_lib.object_body_parts_health(obj, storage, parts)`

Initialize health tracking for all body parts of an object.

**Parameters:**
- `obj` (ObjectRef): The object to initialize
- `storage` (table): Storage table for the object
- `parts` (table): Hitbox group definition from `hitboxes_lib`

**Side Effects:**
- Initializes `storage._parts_health[part_name]` for each body part with:
  - `max_health`: Maximum health for this part
  - `health`: Current health for this part

**Example:**
```lua
local hitgroup = hitboxes_lib.hitbox_groups["mobs_monster:dirt_monster"]
advanced_fight_lib.object_body_parts_health(obj, storage, hitgroup)
```

---

### Damage Calculation

#### `advanced_fight_lib.calculate_damage(obj, puncher, tflp, tool_caps, dir)`

Calculate damage for a hit, including hitbox detection and modifiers.

**Parameters:**
- `obj` (ObjectRef): Target object being hit
- `puncher` (ObjectRef): Attacking object
- `tflp` (number): Time from last punch
- `tool_caps` (table): Tool capabilities from weapon
- `dir` (vector): Attack direction

**Returns:**
- `number`: Final damage amount (if no hitbox detected)
- `table`: Hit data table (if hitbox detected) containing:
  - `damage` (number): Calculated damage
  - `target` (ObjectRef): The hit object
  - `attacker` (ObjectRef): The puncher
  - `details` (table): Hit details from `hitboxes_lib.detect_hits`
    - `name` (string): Name of hit body part
    - `hit_axis` (string): Axis of hit ("+x", "-x", "+y", "-y", "+z", "-z")
    - `hit_relative` (vector): Hit position relative to hitbox
    - `orig` (table): Original hitbox definition
    - `armor_index` (number, optional): Index of armor piece that protected
    - `shield_index` (number, optional): Index of shield that blocked
  - `ref_pos`, `hitbox_pos`, `hitbox_rot`, `hit_from_pos`, `hit_from_dir`: Position/rotation data
  - `tool_caps`, `tflp`, `dir`: Attack parameters

**Features:**
- Automatic hitbox detection via `hitboxes_lib`
- Handles rotations for both player and entity targets/attackers
- Miss chance calculation
- Damage multipliers per body part
- Custom armor calculation via `cb_get_armor` callback
- Plays miss sound effect when attacks miss

**Example:**
```lua
local hit_data = advanced_fight_lib.calculate_damage(
    target, player, time_from_last_punch, tool_capabilities, direction
)
if type(hit_data) == "table" then
    print("Hit " .. hit_data.details.name .. " for " .. hit_data.damage .. " damage")
end
```

---

#### `advanced_fight_lib.random_round(num)`

Round a number randomly (useful for damage calculations).

**Parameters:**
- `num` (number): Number to round

**Returns:**
- `number`: Either `math.floor(num)` or `math.ceil(num)` based on fractional probability

**Example:**
```lua
local damage = advanced_fight_lib.random_round(10.7)  -- 30% chance of 10, 70% chance of 11
```

---

### Effect System

#### `advanced_fight_lib.compute_effect(damage, data)`

Compute effect value based on damage using a curve formula.

**Parameters:**
- `damage` (number): Damage amount (0.0 to 1.0 typically)
- `data` (table): Effect curve definition with:
  - `threshold_start` (number): Damage threshold where effect starts
  - `threshold_peak` (number): Damage threshold where effect reaches peak
  - `base_value` (number): Effect value below threshold_start
  - `peak_value` (number): Effect value at threshold_peak
  - `over_value` (number): Maximum effect value (approached asymptotically)
  - `curve` (number): Exponential decay factor for overshoot

**Returns:**
- `number`: Calculated effect value

**Formula:**
- Below `threshold_start`: returns `base_value`
- Between `threshold_start` and `threshold_peak`: linear interpolation
- Above `threshold_peak`: exponential approach to `over_value`

**Example:**
```lua
local effect_value = advanced_fight_lib.compute_effect(0.7, {
    threshold_start = 0.3,
    threshold_peak = 0.6,
    base_value = 0,
    peak_value = 0.5,
    over_value = 1.0,
    curve = 2.0
})
```

---

#### `advanced_fight_lib.create_effects_group_from_values(obj, label, values)`

Create an attribute effects group from value definitions.

**Parameters:**
- `obj` (ObjectRef): Target object
- `label` (string): Unique label for the effects group
- `values` (table): Map of effect name to effect data:
  - `name` (string): Body part name (for default damage calculation)
  - `value` (number): Base effect value
  - `rule` (string): Effect rule ("multiply", "add", "post_sum", etc.)
  - `privilege` (number): Effect priority
  - `threshold_start`, `threshold_peak`, `base_value`, `peak_value`, `over_value`, `curve`: See `compute_effect`
  - `cb_calculate_damage` (function, optional): Custom damage calculation
  - `cb_on_update` (function, optional): Called when effect updates

**Returns:**
- `string`: Effects group ID

**Example:**
```lua
advanced_fight_lib.create_effects_group_from_values(player, "head_injury", {
    speed = {
        name = "head",
        value = -0.3,
        rule = "add",
        privilege = 50,
        threshold_start = 0.3,
        threshold_peak = 0.7,
        base_value = 0,
        peak_value = 1,
        over_value = 1,
        curve = 2.0
    }
})
```

---

### Hit Handling

#### `advanced_fight_lib.object_on_hit(self, obj, storage, hit_data)`

Handle a hit to an object, updating body part health.

**Parameters:**
- `self` (table): Hitbox definition (from `hitboxes_lib`)
- `obj` (ObjectRef): Hit object
- `storage` (table): Object storage
- `hit_data` (table): Hit data from `calculate_damage`

**Side Effects:**
- Reduces health of the hit body part
- Initializes `_parts_health` if not present
- Updates storage

---

#### `advanced_fight_lib.object_on_update(self, obj, storage, hit_data)`

Apply effects after a hit.

**Parameters:**
- `self` (table): Hitbox definition with optional:
  - `values` (table): Value-based effects (see `create_effects_group_from_values`)
  - `effects_group_label` (string): Label for effects group
  - `effects` (table): Custom effects with `cb_apply` and `cb_add_effect`
  - `cb_on_update` (function): Custom update callback
- `obj` (ObjectRef): Hit object
- `storage` (table): Object storage
- `hit_data` (table): Hit data

**Side Effects:**
- Creates or updates effects groups
- Applies custom effects

---

#### `advanced_fight_lib.object_on_respawn(obj, storage)`

Reset body part health and effects on respawn.

**Parameters:**
- `obj` (ObjectRef): Respawned object
- `storage` (table): Object storage

**Side Effects:**
- Resets all body part health to maximum
- Calls `cb_on_respawn` on hitbox effects
- Clears part-specific damage tracking

---

#### `advanced_fight_lib.object_on_heal(obj, storage, heal_amount, heal_data)`

Heal body parts.

**Parameters:**
- `obj` (ObjectRef): Object to heal
- `storage` (table): Object storage
- `heal_amount` (number): Amount to heal
- `heal_data` (table): Additional heal data

**Side Effects:**
- Heals all body parts proportionally (using `heal_multiplier` or `damage_multiplier`)
- Calls `cb_on_heal` on hitbox effects

---

### Point Hit System

#### `advanced_fight_lib.create_point_hit_effect(data)`

Create a point-based hit effect for granular damage tracking.

**Parameters:**
- `data` (table): Effect definition with:
  - `points` (table): Array of point positions (vectors)
  - `points_size` (number or table): Radius for each point
  - `points_axis` (string or table): Axis for hit detection (e.g., "x", "+y", "-z")
  - `points_max_health` (number or table): Max health per point
  - `part_damage_key` (string): Key for storing point damage in storage
  - `effects_group_label` (string): Label for effects group
  - `values` (table): Value effects (see `create_effects_group_from_values`)
  - `cb_on_update` (function, optional): Update callback

**Returns:**
- `table`: Effect definition with `cb_add_effect` callback, or `nil` on error

**Example:**
```lua
local eye_damage_effect = advanced_fight_lib.create_point_hit_effect({
    points = {
        vector.new(-0.15, 0.05, 0),  -- left eye
        vector.new(0.15, 0.05, 0),   -- right eye
    },
    points_size = 0.08,
    points_axis = "+z",
    points_max_health = 20,
    part_damage_key = "eye_damage",
    effects_group_label = "eye_injury",
    values = {
        view_range = {
            name = "head",
            cb_calculate_damage = advanced_fight_lib.point_hit_effect_view_range_calculate_damage,
            -- ... effect curve parameters
        }
    }
})
```

---

#### `advanced_fight_lib.point_hit_effect_view_range_calculate_damage(self, obj)`

Calculate damage for point hit effects using minimum point damage.

**Parameters:**
- `self` (table): Effect definition
- `obj` (ObjectRef): Target object

**Returns:**
- `number`: Minimum damage across all points

---

#### `advanced_fight_lib.point_hit_effect_inaccurate_calculate_damage(self, obj)`

Calculate damage for point hit effects using weighted average.

**Parameters:**
- `self` (table): Effect definition with:
  - `edge_point_damage` (number): Threshold for edge point weighting
  - `undamage_point_weight` (number): Weight for undamaged points
- `obj` (ObjectRef): Target object

**Returns:**
- `number`: Weighted average damage

---

### Miss Chance

#### `advanced_fight_lib.calculate_get_miss_chance(self, hit_data)`

Calculate miss chance based on angle between defender and attacker.

**Parameters:**
- `self` (table): Hitbox definition with:
  - `miss_chance` (number): Base miss chance (0.0-1.0)
  - `miss_chance_angles` (table, optional): Map of angle (degrees) to miss chance
- `hit_data` (table): Hit data with target and attacker

**Returns:**
- `number`: Final miss chance (0.0-1.0)

**Example:**
```lua
-- In hitbox definition
miss_chance = 0.1,
miss_chance_angles = {
    [0] = 0.8,    -- 80% miss if attacking from front
    [90] = 0.3,   -- 30% miss from side
    [180] = 0.1,  -- 10% miss from behind
}
```

---

## Entity API

Functions under `advanced_fight_lib.entity` namespace.

### `advanced_fight_lib.entity_on_hit(self, obj, hit_data)`

Handle entity hit (simplified wrapper).

**Parameters:**
- `self` (table): Hitbox definition
- `obj` (ObjectRef): Hit entity
- `hit_data` (table): Hit data

**Side Effects:**
- Calls `object_on_hit` and `object_on_update`

---

## Player API

Functions under `advanced_fight_lib.player` namespace.

### `advanced_fight_lib.player.on_hit(self, player, hit_data)`

Handle player hit with storage persistence.

**Parameters:**
- `self` (table): Hitbox definition
- `player` (ObjectRef): Hit player
- `hit_data` (table): Hit data

**Side Effects:**
- Updates body part health
- Applies effects
- Saves to player metadata

---

### `advanced_fight_lib.player.on_respawn(player)`

Handle player respawn, resetting combat state.

**Parameters:**
- `player` (ObjectRef): Respawned player

**Side Effects:**
- Resets all body part health
- Clears effects
- Saves to player metadata

---

### `advanced_fight_lib.player.on_heal(player, heal_amount, heal_data)`

Handle player healing.

**Parameters:**
- `player` (ObjectRef): Player to heal
- `heal_amount` (number): Amount to heal
- `heal_data` (table): Additional data

---

### `advanced_fight_lib.player.on_punch(player, hitter, tflp, tool_caps, dir, damage)`

Main player punch handler (integrates with game engine).

**Parameters:**
- Standard Luanti `on_punch` parameters

**Returns:**
- `boolean`: Whether punch was handled

**Features:**
- Full hitbox detection
- 3D Armor integration
- Shield blocking
- Body part-specific armor

---

### `advanced_fight_lib.player.get_armor(self, hit_data)`

Get armor values for a specific hit (3D Armor integration).

**Parameters:**
- `self` (table): Hitbox definition with `armor_element` field
- `hit_data` (table): Hit data

**Returns:**
- `table`: Armor groups for this hit

**Armor Elements:**
- `"head"`, `"torso"`, `"legs"`, `"feet"`

**Example:**
```lua
-- In hitbox definition
armor_element = "head"
```

---

### `advanced_fight_lib.player.default_use_shield(def, hit_data)`

Default shield usage calculation.

**Parameters:**
- `def` (table): Shield item definition with:
  - `use_chance` (number): Base use chance (0.0-1.0)
  - `use_chance_angles` (table, optional): Angle-based use chance
  - `full_use_interval` (number, optional): Time between full uses (default 0.6)
  - `shield_speed` (number, optional): Rotation speed in degrees/second (default 45)
- `hit_data` (table): Hit data

**Returns:**
- `boolean`: Whether shield blocks the hit

**Features:**
- Angle-based blocking (better from front)
- Recovery time mechanics
- Shield rotation speed limiting

---

### Player Effects

#### `advanced_fight_lib.player.effect_disarm_right(self, player, hit_data)`

Effect to disarm player's right hand (wielded item).

**Parameters:**
- `self` (table): Effect definition with optional `hit_area` field
- `player` (ObjectRef): Target player
- `hit_data` (table): Hit data

**Side Effects:**
- Drops wielded item if `diarm_chance` succeeds

---

#### `advanced_fight_lib.player.effect_disarm_left(self, player, hit_data)`

Effect to disarm player's left hand (not implemented).

---

## Mobs API

Functions under `advanced_fight_lib.mobs` namespace (requires `mobs` mod).

### `advanced_fight_lib.mobs.cmi_calculate_damage(obj, puncher, tflp, tool_caps, dir)`

CMI (Common Mob Interface) damage calculation override.

**Parameters:**
- Standard CMI parameters

**Returns:**
- `number`: Damage amount

**Usage:**
```lua
-- Override CMI damage calculation
cmi.calculate_damage = advanced_fight_lib.mobs.cmi_calculate_damage
```

---

### `advanced_fight_lib.mobs.mobs_do_punch(ent)`

Process stored hit data after mob punch.

**Parameters:**
- `ent` (table): Mob luaentity

**Side Effects:**
- Calls `on_hit` callbacks for detected hits

---

### `advanced_fight_lib.mobs.replace_do_punch(ent_def)`

Replace mob entity's `do_punch` function to integrate hit handling.

**Parameters:**
- `ent_def` (table): Entity definition

**Side Effects:**
- Wraps original `do_punch` with hit processing

---

### `advanced_fight_lib.mobs.inaccuracy_arrow_override(self, shooter_ent)`

Apply shooting inaccuracy to fired arrows.

**Parameters:**
- `self` (table): Arrow luaentity
- `shooter_ent` (table): Shooter mob entity with `shoot_inaccuracy` field

**Side Effects:**
- Applies random velocity deviation after 0.01 seconds

---

### `advanced_fight_lib.mobs.replace_override_arrow(ent_def)`

Replace mob entity's `arrow_override` to add inaccuracy.

**Parameters:**
- `ent_def` (table): Entity definition

---

### `advanced_fight_lib.mobs.point_hit_effects_group_on_update(self, obj, hit_data)`

Update mob textures based on point hit damage.

**Parameters:**
- `self` (table): Point hit effect definition with:
  - `texture_hit_point` (string): Format string for overlay texture (e.g., "mob_hit_%d.png")
- `obj` (ObjectRef): Mob object
- `hit_data` (table): Hit data

**Side Effects:**
- Adds texture overlays when points are fully damaged

**Example:**
```lua
texture_hit_point = "dirt_monster_eye_hit_%d.png"  -- %d replaced with point index
```

---

### `advanced_fight_lib.apply_inaccuracy_to_arrow(guid, inaccuracy)`

Apply inaccuracy to arrow by GUID.

**Parameters:**
- `guid` (string): Arrow object GUID
- `inaccuracy` (number): Inaccuracy in degrees

**Side Effects:**
- Rotates arrow velocity randomly within inaccuracy cone

---

## Registered Attribute Effects

### `mobs:shoot_inaccuracy`

Attribute effect for mob shooting inaccuracy.

**Object Type:** Mobs only

**Usage:**
```lua
-- Applied to mob entity
ent.shoot_inaccuracy = 5.0  -- 5 degrees inaccuracy
```

---

## Callbacks and Extension Points

### Hitbox Definition Callbacks

When defining hitboxes with `hitboxes_lib`, you can use these callbacks:

#### `on_hit(obj, hit_data)`

Called when a hitbox is hit.

**Parameters:**
- `obj` (ObjectRef): Hit object
- `hit_data` (table): Hit data from `calculate_damage`

**Returns:**
- `boolean` (optional): Return `false` to prevent default handling

---

#### `cb_calculate_damage(hit_data)`

Custom damage calculation for this hitbox.

**Parameters:**
- `hit_data` (table): Hit data (modifiable)

**Side Effects:**
- Should set `hit_data.damage`

---

#### `cb_get_armor(hit_data, default_armor)`

Custom armor calculation for this hitbox.

**Parameters:**
- `hit_data` (table): Hit data
- `default_armor` (table): Default armor groups

**Returns:**
- `table`: Modified armor groups

---

#### `cb_get_damage_multiplier(hit_data)`

Dynamic damage multiplier for this hitbox.

**Parameters:**
- `hit_data` (table): Hit data

**Returns:**
- `number`: Damage multiplier

---

#### `cb_get_miss_chance(hit_data)`

Dynamic miss chance for this hitbox.

**Parameters:**
- `hit_data` (table): Hit data

**Returns:**
- `number`: Miss chance (0.0-1.0)

**Note:** Use `advanced_fight_lib.calculate_get_miss_chance` for angle-based calculation.

---

### Weapon Definition Extensions

When defining tools/weapons, you can add these fields:

#### `_hit_range`

Hit range for this weapon (default: 4.0).

#### `_hit_box`

Hit box definition for area attacks:
```lua
_hit_box = {
    {-0.5, -0.5, -0.5},  -- min corner
    {0.5, 0.5, 0.5}      -- max corner
}
```

#### `_hit_sphere_radius`

Hit sphere radius for area attacks.

#### `cb_set_hit_attributes(hit_data)`

Custom hit attribute setup.

**Parameters:**
- `hit_data` (table): Hit data (modifiable)

**Side Effects:**
- Can set `hit_data.range`, `hit_data.mode`, `hit_data.box`, etc.

---

### Shield Item Definition Extensions

#### `cb_use_shield(hit_data)`

Custom shield usage logic.

**Parameters:**
- `hit_data` (table): Hit data

**Returns:**
- `boolean`: Whether shield blocks the hit

#### Standard Shield Fields

- `use_chance` (number): Base chance to use shield (0.0-1.0)
- `use_chance_angles` (table): Map of angle to use chance
- `full_use_interval` (number): Cooldown between full uses
- `shield_speed` (number): Shield rotation speed (degrees/sec)

---

### Armor Item Definition Extensions

#### `armor_element`

Body part protected: `"head"`, `"torso"`, `"legs"`, or `"feet"`

#### `full_armor_groups`

Armor groups for all damage types:
```lua
full_armor_groups = {
    fleshy = 10,
    fire = 5
}
```

---

## Storage Structure

### Player Storage

Stored in player metadata under key `"advanced_fight:storage"` as JSON.

**Structure:**
```lua
{
    _parts_health = {
        ["part_name"] = {
            max_health = 20,
            health = 15,
            ["damage_key"] = {  -- from point hit effects
                [1] = 0.5,  -- point 1 damage
                [2] = 0.3,  -- point 2 damage
            }
        }
    },
    shield_last_use_time = 12345.67,
    shield_last_use_angle = 45.0,
    -- custom fields
}
```

### Entity Storage

Stored directly in luaentity table.

---

## Integration Examples

### Basic Hitbox with Effects

```lua
hitboxes_lib.register_hitboxes("mymod:monster", {
    head = {
        box = {x_min = -0.25, y_min = 1.5, z_min = -0.25,
               x_max = 0.25, y_max = 2.0, z_max = 0.25},
        part_of_health = 0.2,  -- 20% of total HP
        damage_multiplier = 1.5,
        on_hit = advanced_fight_lib.entity_on_hit,
        values = {
            view_range = {
                name = "head",
                value = -5,
                rule = "add",
                privilege = 50,
                threshold_start = 0.3,
                threshold_peak = 0.7,
                base_value = 0,
                peak_value = 1,
                over_value = 1,
                curve = 2.0
            }
        },
        effects_group_label = "head_injury"
    }
})
```

---

### Player with Armor Support

```lua
hitboxes_lib.register_hitboxes("player:player", {
    head = {
        box = {x_min = -0.25, y_min = 1.4, z_min = -0.25,
               x_max = 0.25, y_max = 1.9, z_max = 0.25},
        part_of_health = 0.15,
        damage_multiplier = 1.5,
        armor_element = "head",
        cb_get_armor = advanced_fight_lib.player.get_armor,
        on_hit = advanced_fight_lib.player.on_hit,
    }
})

-- Register player punch handler
core.register_on_punchplayer(function(player, hitter, tflp, tool_caps, dir, damage)
    return advanced_fight_lib.player.on_punch(player, hitter, tflp, tool_caps, dir, damage)
end)
```

---

### Mob with CMI Integration

```lua
-- Override CMI damage calculation
if core.get_modpath("mobs") then
    cmi.calculate_damage = advanced_fight_lib.mobs.cmi_calculate_damage
    
    -- For each mob with hitboxes
    local mob_def = core.registered_entities["mobs:zombie"]
    advanced_fight_lib.mobs.replace_do_punch(mob_def)
end
```

---

### Point Hit System (Eyes)

```lua
local eye_effect = advanced_fight_lib.create_point_hit_effect({
    points = {
        vector.new(-0.15, 0.05, 0),
        vector.new(0.15, 0.05, 0),
    },
    points_size = 0.08,
    points_axis = "+z",
    points_max_health = 20,
    part_damage_key = "eye_damage",
    effects_group_label = "blinded",
    values = {
        view_range = {
            name = "head",
            value = -10,
            rule = "add",
            privilege = 100,
            cb_calculate_damage = advanced_fight_lib.point_hit_effect_view_range_calculate_damage,
            threshold_start = 0.0,
            threshold_peak = 0.8,
            base_value = 0,
            peak_value = 1,
            over_value = 1,
            curve = 3.0
        }
    },
    cb_on_update = advanced_fight_lib.mobs.point_hit_effects_group_on_update,
    texture_hit_point = "monster_eye_damaged_%d.png"
})

-- Add to hitbox definition
hitboxes_lib.register_hitboxes("mymod:monster", {
    head = {
        -- ... basic hitbox definition
        effects = {
            eye_damage = eye_effect
        }
    }
})
```

---

## Best Practices

1. **Always Initialize Storage:** Call `object_body_parts_health` when registering new hitboxes
2. **Use Effect Groups:** Leverage `effects_group_label` to prevent duplicate effects
3. **Persist Player Data:** Always call `set_object_storage` after modifying player storage
4. **Test Miss Chances:** Balance `miss_chance` and `miss_chance_angles` for fair gameplay
5. **CMI Integration:** Override CMI for mobs early in mod initialization
6. **Damage Curves:** Use `compute_effect` for smooth, realistic damage effects
7. **Point Hit Precision:** Use small `points_size` for precise targeting (like eyes)
8. **Shield Mechanics:** Balance `shield_speed` and `full_use_interval` for responsive blocking

---

## Compatibility Notes

- **Mobs Redo:** Requires version >= 20251117
- **3D Armor:** Optional but recommended for full player armor support
- **Player Attributes:** Integrates with `players_effects` for attribute management
- **Luanti Version:** Minimum 5.13

---

## Troubleshooting

### Hitboxes Not Detected
- Ensure `hitboxes_lib.register_hitboxes` is called with correct entity name
- Check hitbox coordinates match entity collision box
- Verify `_hit_range` is sufficient for weapon

### Effects Not Applying
- Check `effects_group_label` is unique or properly reused
- Verify `cb_update` returns `true` to keep effect active
- Ensure `attributes_effects` has registered the value type

### Player Storage Not Persisting
- Always call `advanced_fight_lib.set_object_storage(player, storage)` after modifications
- Check for errors in JSON serialization

### Mobs Not Using Hitboxes
- Verify CMI override is called: `cmi.calculate_damage = advanced_fight_lib.mobs.cmi_calculate_damage`
- Ensure `replace_do_punch` is called on entity definition
- Check mobs_redo version >= 20251117

