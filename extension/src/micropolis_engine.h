// MicropolisEngine: MicropolisCore's C++ engine as a Godot class.
//
// The game never uses this class directly. It talks to the GDScript interface
// CityEngine (game/engine/city_engine.gd), and MicropolisCityEngine implements
// that interface over this class.
//
// Part of Metrobits, which is GPLv3 with Electronic Arts' additional terms
// (see LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).

#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector2i.hpp>
#include <godot_cpp/variant/vector3i.hpp>

namespace metrobits {
struct ZeroedMicropolis;
class GodotCallback;
} // namespace metrobits

namespace godot {

class MicropolisEngine : public RefCounted {
    GDCLASS(MicropolisEngine, RefCounted)

public:
    // Values match the engine's own enums (tool.h, micropolis.h), and the
    // matching enums in CityEngine; a GUT test checks they agree.
    enum Tool {
        TOOL_RESIDENTIAL, TOOL_COMMERCIAL, TOOL_INDUSTRIAL, TOOL_FIRE_STATION,
        TOOL_POLICE_STATION, TOOL_QUERY, TOOL_WIRE, TOOL_BULLDOZER, TOOL_RAILROAD,
        TOOL_ROAD, TOOL_STADIUM, TOOL_PARK, TOOL_SEAPORT, TOOL_COAL_POWER,
        TOOL_NUCLEAR_POWER, TOOL_AIRPORT, TOOL_NETWORK, TOOL_WATER, TOOL_LAND,
        TOOL_FOREST, TOOL_COUNT,
    };
    enum ToolResult {
        TOOL_RESULT_NO_MONEY = -2,
        TOOL_RESULT_NEED_BULLDOZE = -1,
        TOOL_RESULT_FAILED = 0,
        TOOL_RESULT_OK = 1,
    };
    enum Scenario {
        SCENARIO_NONE, SCENARIO_DULLSVILLE, SCENARIO_SAN_FRANCISCO, SCENARIO_HAMBURG,
        SCENARIO_BERN, SCENARIO_TOKYO, SCENARIO_DETROIT, SCENARIO_BOSTON, SCENARIO_RIO,
        SCENARIO_COUNT,
    };
    enum HistoryType {
        HISTORY_RESIDENTIAL, HISTORY_COMMERCIAL, HISTORY_INDUSTRIAL, HISTORY_MONEY,
        HISTORY_CRIME, HISTORY_POLLUTION, HISTORY_TYPE_COUNT,
    };
    // The engine's SpriteType (micropolis.h).
    enum SpriteType {
        SPRITE_NONE, SPRITE_TRAIN, SPRITE_HELICOPTER, SPRITE_AIRPLANE, SPRITE_SHIP,
        SPRITE_MONSTER, SPRITE_TORNADO, SPRITE_EXPLOSION, SPRITE_BUS, SPRITE_TYPE_COUNT,
    };
    enum HistoryScale {
        HISTORY_SHORT, // 10 years
        HISTORY_LONG,  // 120 years
    };
    // Our own numbering: the engine keeps each overlay as a separate member.
    enum Overlay {
        OVERLAY_POPULATION_DENSITY, OVERLAY_TRAFFIC_DENSITY, OVERLAY_POLLUTION,
        OVERLAY_LAND_VALUE, OVERLAY_CRIME, OVERLAY_TERRAIN_DENSITY, OVERLAY_POWER_GRID,
        OVERLAY_RATE_OF_GROWTH, OVERLAY_FIRE_COVERAGE, OVERLAY_POLICE_COVERAGE,
        OVERLAY_COMMERCIAL_RATE, OVERLAY_COUNT,
    };
    static constexpr int MAP_WIDTH = 120;
    static constexpr int MAP_HEIGHT = 100;
    static constexpr int TILE_COUNT = 1024;

    MicropolisEngine();
    ~MicropolisEngine() override;

    // Content
    void set_content_dir(const String &path);
    String get_content_dir() const;

    // Cities
    bool load_scenario(int scenario);
    bool load_city(const String &path);
    bool save_city(const String &path);
    void generate_map(int seed);
    void generate_random_map();
    void seed_random(int seed);
    void set_fixed_seed(int seed);
    void clear_fixed_seed();

    // Simulation
    void tick();
    void set_speed(int speed);
    int get_speed() const;
    void pause();
    void resume();
    bool is_paused() const;
    void set_passes(int passes);
    int get_passes() const;

    // Numbers
    int get_funds() const;
    void set_funds(int funds);
    int get_city_time() const;
    int get_year() const;
    int get_month() const;
    int get_population() const;
    int get_residential_population() const;
    int get_commercial_population() const;
    int get_industrial_population() const;
    Vector3i get_demand() const;
    String get_city_name() const;
    void set_city_name(const String &name);
    int get_game_level() const;
    void set_game_level(int level);
    int get_scenario() const;

    // Options
    void set_disasters_enabled(bool enabled);
    bool get_disasters_enabled() const;
    void set_auto_budget(bool enabled);
    bool get_auto_budget() const;
    void set_auto_bulldoze(bool enabled);
    bool get_auto_bulldoze() const;
    void set_auto_goto(bool enabled);
    bool get_auto_goto() const;
    void set_animation(bool enabled);
    bool get_animation() const;
    void set_messages(bool enabled);
    bool get_messages() const;
    void set_notices(bool enabled);
    bool get_notices() const;

    // The OLPC editor's cheat words
    bool cheat(const String &word);

    // Tools
    int do_tool(int tool, int x, int y);
    void tool_down(int tool, int x, int y);
    void tool_drag(int tool, int from_x, int from_y, int to_x, int to_y);
    static int get_tool_cost(int tool);
    static int get_tool_size(int tool);

    // Budget
    int get_tax_rate() const;
    void set_tax_rate(int rate);
    void set_road_percent(float percent);
    void set_fire_percent(float percent);
    void set_police_percent(float percent);
    Dictionary get_budget() const;
    void request_budget();

    // Evaluation
    void evaluate();
    Dictionary get_evaluation() const;

    // Disasters
    void make_earthquake();
    void make_fire();
    void make_flood();
    void make_meltdown();
    void make_monster();
    void make_tornado();
    void make_air_crash();
    void make_fire_bombs();
    void make_explosion(int x, int y);

    // Sprites
    Array get_sprites() const;

    // Graph history
    PackedInt32Array get_history(int type, int scale) const;

    // Map data, row-major: index = y * MAP_WIDTH + x.
    int get_tile(int x, int y) const;
    PackedInt32Array get_map() const;
    static PackedInt32Array get_animation_table();
    PackedInt32Array get_overlay(int overlay) const;
    Vector2i get_overlay_size(int overlay) const;

protected:
    static void _bind_methods();

private:
    String resolve_path(const String &path) const;

    metrobits::ZeroedMicropolis *sim_ = nullptr;
    // The OLPC's PunishCnt: how many times "fund" has been typed, to 5.
    int punish_count_ = 0;
    metrobits::GodotCallback *callback_ = nullptr; // owned by sim_
    String content_dir_;
};

} // namespace godot

VARIANT_ENUM_CAST(MicropolisEngine::Tool);
VARIANT_ENUM_CAST(MicropolisEngine::ToolResult);
VARIANT_ENUM_CAST(MicropolisEngine::Scenario);
VARIANT_ENUM_CAST(MicropolisEngine::HistoryType);
VARIANT_ENUM_CAST(MicropolisEngine::HistoryScale);
VARIANT_ENUM_CAST(MicropolisEngine::SpriteType);
VARIANT_ENUM_CAST(MicropolisEngine::Overlay);
