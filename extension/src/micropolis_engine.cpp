// MicropolisEngine: MicropolisCore's C++ engine as a Godot class.
//
// Part of Metrobits, which is GPLv3 with Electronic Arts' additional terms
// (see LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).

#include "micropolis_engine.h"

#include "engine_host.h"
#include "godot_callback.h"

#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>

#include <sys/stat.h>

namespace godot {

namespace {

// Copied from tool.cpp, where gCostOf and gToolSize are file-static. A GUT test
// checks the costs against what the engine actually charges.
const int kToolCost[MicropolisEngine::TOOL_COUNT] = {
    100, 100, 100, 500,    // residential, commercial, industrial, fire station
    500, 0, 5, 1,          // police station, query, wire, bulldozer
    20, 10, 5000, 10,      // railroad, road, stadium, park
    3000, 3000, 5000, 10000, // seaport, coal, nuclear, airport
    100, 0, 0, 0,          // network, water, land, forest
};
const int kToolSize[MicropolisEngine::TOOL_COUNT] = {
    3, 3, 3, 3,
    3, 1, 1, 1,
    1, 1, 4, 1,
    4, 4, 4, 6,
    1, 1, 1, 1,
};

std::string std_str(const String &s) {
    return std::string(s.utf8().get_data());
}

bool is_dir(const std::string &path) {
    struct stat st;
    return stat(path.c_str(), &st) == 0 && S_ISDIR(st.st_mode);
}

template <typename M>
PackedInt32Array overlay_data(M &map) {
    // The engine stores a cluster at x * MAP_H + y; return row-major.
    PackedInt32Array out;
    out.resize(map.MAP_W * map.MAP_H);
    int32_t *w = out.ptrw();
    for (int y = 0; y < map.MAP_H; y++) {
        for (int x = 0; x < map.MAP_W; x++) {
            w[y * map.MAP_W + x] = map.get(x, y);
        }
    }
    return out;
}

template <typename M>
Vector2i overlay_size(M &map) {
    return Vector2i(map.MAP_W, map.MAP_H);
}

} // namespace

MicropolisEngine::MicropolisEngine() {
    sim_ = metrobits::new_micropolis();
    callback_ = new metrobits::GodotCallback(this);
    sim_->setCallback(callback_, emscripten::val::null());
    sim_->init();
    callback_->set_live(true);
}

MicropolisEngine::~MicropolisEngine() {
    delete sim_; // deletes callback_ too
}

// Content ----------------------------------------------------------------

void MicropolisEngine::set_content_dir(const String &path) {
    content_dir_ = path.begins_with("res://") || path.begins_with("user://")
                       ? ProjectSettings::get_singleton()->globalize_path(path).simplify_path()
                       : path.simplify_path();
}

String MicropolisEngine::get_content_dir() const {
    return content_dir_;
}

String MicropolisEngine::resolve_path(const String &path) const {
    if (path.begins_with("res://") || path.begins_with("user://")) {
        return ProjectSettings::get_singleton()->globalize_path(path);
    }
    if (path.is_absolute_path()) {
        return path;
    }
    return content_dir_.path_join(path);
}

// Cities -----------------------------------------------------------------

bool MicropolisEngine::load_scenario(int scenario) {
    if (scenario <= SCENARIO_NONE || scenario >= SCENARIO_COUNT) {
        return false;
    }
    // The engine opens "cities/<scenario>.cty" relative to the working directory.
    const std::string dir = std_str(content_dir_);
    if (!is_dir(dir + "/cities")) {
        return false;
    }
    metrobits::ScopedCwd cwd(dir);
    if (!cwd.ok()) {
        return false;
    }
    sim_->loadScenario(static_cast<::Scenario>(scenario));
    return true;
}

bool MicropolisEngine::load_city(const String &path) {
    return sim_->loadCity(std_str(resolve_path(path)));
}

bool MicropolisEngine::save_city(const String &path) {
    const std::string file = std_str(resolve_path(path));
    const bool ok = sim_->saveFile(file);
    if (ok) {
        callback_->didSaveCity(sim_, emscripten::val::null(), file);
    } else {
        callback_->didntSaveCity(sim_, emscripten::val::null(), file);
    }
    return ok;
}

void MicropolisEngine::generate_map(int seed) {
    sim_->generateSomeCity(seed);
}

void MicropolisEngine::generate_random_map() {
    sim_->generateSomeRandomCity();
}

void MicropolisEngine::seed_random(int seed) {
    sim_->seedRandom(seed);
}

void MicropolisEngine::set_fixed_seed(int seed) {
    sim_->setFixedRandomSeed(seed);
}

void MicropolisEngine::clear_fixed_seed() {
    sim_->clearFixedRandomSeed();
}

// Simulation -------------------------------------------------------------

void MicropolisEngine::tick() {
    sim_->simTick();
}

void MicropolisEngine::set_speed(int speed) {
    sim_->setSpeed(static_cast<short>(speed));
}

int MicropolisEngine::get_speed() const {
    // The speed chosen, which pausing keeps: the engine runs at 0 while paused
    // and holds the chosen speed in simPausedSpeed.
    return sim_->simPaused ? sim_->simPausedSpeed : sim_->simSpeedMeta;
}

void MicropolisEngine::pause() {
    sim_->pause();
}

void MicropolisEngine::resume() {
    sim_->resume();
}

bool MicropolisEngine::is_paused() const {
    return sim_->simPaused;
}

void MicropolisEngine::set_passes(int passes) {
    sim_->setPasses(passes);
}

int MicropolisEngine::get_passes() const {
    return sim_->simPasses;
}

// Numbers ----------------------------------------------------------------

int MicropolisEngine::get_funds() const {
    return static_cast<int>(sim_->totalFunds);
}

void MicropolisEngine::set_funds(int funds) {
    sim_->setFunds(funds);
}

int MicropolisEngine::get_city_time() const {
    return static_cast<int>(sim_->cityTime);
}

int MicropolisEngine::get_year() const {
    return static_cast<int>(sim_->cityYear);
}

int MicropolisEngine::get_month() const {
    return static_cast<int>(sim_->cityMonth);
}

int MicropolisEngine::get_population() const {
    return static_cast<int>(sim_->cityPop);
}

int MicropolisEngine::get_residential_population() const {
    return sim_->resPop;
}

int MicropolisEngine::get_commercial_population() const {
    return sim_->comPop;
}

int MicropolisEngine::get_industrial_population() const {
    return sim_->indPop;
}

Vector3i MicropolisEngine::get_demand() const {
    return Vector3i(sim_->resValve, sim_->comValve, sim_->indValve);
}

String MicropolisEngine::get_city_name() const {
    return String::utf8(sim_->cityName.c_str());
}

void MicropolisEngine::set_city_name(const String &name) {
    sim_->setCityName(std_str(name));
}

int MicropolisEngine::get_game_level() const {
    return sim_->gameLevel;
}

void MicropolisEngine::set_game_level(int level) {
    sim_->setGameLevel(static_cast<GameLevel>(level));
}

int MicropolisEngine::get_scenario() const {
    return sim_->scenario;
}

// Options ----------------------------------------------------------------

void MicropolisEngine::set_disasters_enabled(bool enabled) {
    sim_->setEnableDisasters(enabled);
}

bool MicropolisEngine::get_disasters_enabled() const {
    return sim_->enableDisasters;
}

void MicropolisEngine::set_auto_budget(bool enabled) {
    sim_->setAutoBudget(enabled);
}

bool MicropolisEngine::get_auto_budget() const {
    return sim_->autoBudget;
}

void MicropolisEngine::set_auto_bulldoze(bool enabled) {
    sim_->setAutoBulldoze(enabled);
}

bool MicropolisEngine::get_auto_bulldoze() const {
    return sim_->autoBulldoze;
}

void MicropolisEngine::set_auto_goto(bool enabled) {
    sim_->setAutoGoto(enabled);
}

bool MicropolisEngine::get_auto_goto() const {
    return sim_->autoGoto;
}

// The OLPC's Animation, Messages and Notices options (sim DoAnimation,
// DoMessages, DoNotices). The engine uses only doAnimation, for static
// rubble; the front end reads the other two.
void MicropolisEngine::set_animation(bool enabled) {
    sim_->setDoAnimation(enabled);
}

bool MicropolisEngine::get_animation() const {
    return sim_->doAnimation;
}

void MicropolisEngine::set_messages(bool enabled) {
    sim_->setDoMessages(enabled);
}

bool MicropolisEngine::get_messages() const {
    return sim_->doMessages;
}

void MicropolisEngine::set_notices(bool enabled) {
    sim_->setDoNotices(enabled);
}

bool MicropolisEngine::get_notices() const {
    return sim_->doNotices;
}

// The words the OLPC's editor watched for in its last four keys (w_keys.c's
// doKeyDown), done here so they draw the engine's own random numbers, as the
// OLPC's did. Written for this port from what the OLPC's did; returns
// whether the word was one of them.
bool MicropolisEngine::cheat(const String &word) {
    const std::string w = std_str(word);
    Micropolis *m = sim_;
    if (w == "fund") {
        // $10,000, and an earthquake every fifth time, as punishment.
        m->spend(-10000);
        if (++punish_count_ == 5) {
            punish_count_ = 0;
            m->makeEarthquake();
        }
    } else if (w == "fart") {
        m->makeSound("city", "Explosion-High");
        m->makeSound("city", "Explosion-Low");
        m->makeFire();
        m->makeFlood();
        m->makeTornado();
        m->makeEarthquake();
        m->makeMonster();
    } else if (w == "nuke") {
        // Everything built turns to explosions, except the churches; bridges
        // and roads and rails over water fall into the river.
        m->makeSound("city", "Explosion-High");
        m->makeSound("city", "Explosion-Low");
        for (int x = 0; x < WORLD_W; x++) {
            for (int y = 0; y < WORLD_H; y++) {
                const int tile = m->map[x][y] & LOMASK;
                if (tile < RUBBLE || (tile >= CHURCH - 4 && tile <= CHURCH + 4)) {
                    continue;
                }
                const bool over_water = (tile >= HBRIDGE && tile <= VBRIDGE) ||
                    (tile >= BRWH && tile <= LTRFBASE + 1) || (tile >= BRWV && tile <= BRWV + 2) ||
                    (tile >= BRWXXX1 && tile <= BRWXXX1 + 2) || (tile >= BRWXXX2 && tile <= BRWXXX2 + 2) ||
                    (tile >= BRWXXX3 && tile <= BRWXXX3 + 2) || (tile >= BRWXXX4 && tile <= BRWXXX4 + 2) ||
                    (tile >= BRWXXX5 && tile <= BRWXXX5 + 2) || (tile >= BRWXXX6 && tile <= BRWXXX6 + 2) ||
                    (tile >= BRWXXX7 && tile <= BRWXXX7 + 2);
                m->map[x][y] = over_water ? RIVER : (TINYEXP + ANIMBIT + BULLBIT + m->getRandom(2));
            }
        }
    } else if (w == "stop") {
        m->heatSteps = 0;
    } else if (w == "will") {
        // 500 tiles swapped at random.
        for (int i = 0; i < 500; i++) {
            const int x1 = m->getRandom(WORLD_W - 1);
            const int y1 = m->getRandom(WORLD_H - 1);
            const int x2 = m->getRandom(WORLD_W - 1);
            const int y2 = m->getRandom(WORLD_H - 1);
            const unsigned short temp = m->map[x1][y1];
            m->map[x1][y1] = m->map[x2][y2];
            m->map[x2][y2] = temp;
        }
    } else if (w == "bobo" || w == "boss" || w == "mack" || w == "donh" || w == "patb" || w == "lucb") {
        // The heat automaton, run over the map instead of the city.
        m->heatSteps = 1;
        m->heatRule = (w == "donh") ? 1 : 0;
        if (w == "bobo" || w == "donh") {
            m->heatFlow = -1;
        } else if (w == "boss") {
            m->heatFlow = 1;
        } else if (w == "mack") {
            m->heatFlow = 0;
        } else if (w == "patb") {
            m->heatFlow = m->getRandom(40) - 20;
        } else {
            m->heatFlow = m->getRandom(1000) - 500;
        }
    } else if (w == "olpc") {
        m->spend(-1000000);
    } else {
        return false;
    }
    m->invalidateMaps();
    return true;
}

// Tools ------------------------------------------------------------------

int MicropolisEngine::do_tool(int tool, int x, int y) {
    if (tool < 0 || tool >= TOOL_COUNT) {
        return TOOL_RESULT_FAILED;
    }
    return sim_->doTool(static_cast<EditingTool>(tool), static_cast<short>(x), static_cast<short>(y));
}

void MicropolisEngine::tool_down(int tool, int x, int y) {
    if (tool < 0 || tool >= TOOL_COUNT) {
        return;
    }
    sim_->toolDown(static_cast<EditingTool>(tool), static_cast<short>(x), static_cast<short>(y));
}

void MicropolisEngine::tool_drag(int tool, int from_x, int from_y, int to_x, int to_y) {
    if (tool < 0 || tool >= TOOL_COUNT) {
        return;
    }
    sim_->toolDrag(static_cast<EditingTool>(tool), static_cast<short>(from_x), static_cast<short>(from_y),
                   static_cast<short>(to_x), static_cast<short>(to_y));
}

int MicropolisEngine::get_tool_cost(int tool) {
    return tool >= 0 && tool < TOOL_COUNT ? kToolCost[tool] : 0;
}

int MicropolisEngine::get_tool_size(int tool) {
    return tool >= 0 && tool < TOOL_COUNT ? kToolSize[tool] : 0;
}

// Budget -----------------------------------------------------------------

int MicropolisEngine::get_tax_rate() const {
    return sim_->cityTax;
}

void MicropolisEngine::set_tax_rate(int rate) {
    sim_->setCityTax(static_cast<short>(rate));
}

// A funding level applies at once, through the engine's own setters (local
// edit 8), which do what the 1989 budget sliders did.
void MicropolisEngine::set_road_percent(float percent) {
    sim_->setRoadPercent(percent);
}

void MicropolisEngine::set_fire_percent(float percent) {
    sim_->setFirePercent(percent);
}

void MicropolisEngine::set_police_percent(float percent) {
    sim_->setPolicePercent(percent);
}

Dictionary MicropolisEngine::get_budget() const {
    Dictionary d;
    d["tax_rate"] = sim_->cityTax;
    d["tax_income"] = static_cast<int64_t>(sim_->taxFund);
    d["cash_flow"] = sim_->cashFlow;
    d["road_percent"] = sim_->roadPercent;
    d["fire_percent"] = sim_->firePercent;
    d["police_percent"] = sim_->policePercent;
    d["road_requested"] = static_cast<int64_t>(sim_->roadFund);
    d["fire_requested"] = static_cast<int64_t>(sim_->fireFund);
    d["police_requested"] = static_cast<int64_t>(sim_->policeFund);
    d["road_spent"] = static_cast<int64_t>(sim_->roadSpend);
    d["fire_spent"] = static_cast<int64_t>(sim_->fireSpend);
    d["police_spent"] = static_cast<int64_t>(sim_->policeSpend);
    d["auto_budget"] = sim_->autoBudget;
    return d;
}

void MicropolisEngine::request_budget() {
    sim_->doBudgetFromMenu();
}

// Evaluation -------------------------------------------------------------

void MicropolisEngine::evaluate() {
    sim_->cityEvaluation();
}

Dictionary MicropolisEngine::get_evaluation() const {
    Dictionary d;
    d["score"] = sim_->cityScore;
    d["score_delta"] = sim_->cityScoreDelta;
    d["approval"] = sim_->cityYes;
    d["population"] = static_cast<int64_t>(sim_->cityPop);
    d["population_delta"] = static_cast<int64_t>(sim_->cityPopDelta);
    d["assessed_value"] = static_cast<int64_t>(sim_->cityAssessedValue);
    d["city_class"] = static_cast<int>(sim_->cityClass);
    d["game_level"] = static_cast<int>(sim_->gameLevel);
    // The top complaints, worst first: [{problem, votes}]. The engine marks an
    // unused slot with CVP_NUMPROBLEMS.
    Array problems;
    for (int i = 0; i < CVP_PROBLEM_COMPLAINTS; i++) {
        const int problem = sim_->problemOrder[i];
        if (problem < 0 || problem >= CVP_NUMPROBLEMS) {
            continue;
        }
        Dictionary p;
        p["problem"] = problem;
        p["votes"] = sim_->problemVotes[problem];
        problems.push_back(p);
    }
    d["problems"] = problems;
    return d;
}

// Disasters --------------------------------------------------------------

void MicropolisEngine::make_earthquake() { sim_->makeEarthquake(); }
void MicropolisEngine::make_fire() { sim_->makeFire(); }
void MicropolisEngine::make_flood() { sim_->makeFlood(); }
void MicropolisEngine::make_meltdown() { sim_->makeMeltdown(); }
void MicropolisEngine::make_monster() { sim_->makeMonster(); }
void MicropolisEngine::make_tornado() { sim_->makeTornado(); }
void MicropolisEngine::make_air_crash() { sim_->makeAirCrash(); }
void MicropolisEngine::make_fire_bombs() { sim_->makeFireBombs(); }
void MicropolisEngine::make_explosion(int x, int y) { sim_->makeExplosion(x, y); }

// Sprites ----------------------------------------------------------------

Array MicropolisEngine::get_sprites() const {
    // The live sprites, in the engine's list order, which is the order 1989
    // drew them in (DrawObjects in w_sprite.c). A frame of 0 is a dead one.
    Array out;
    for (SimSprite *sprite = sim_->spriteList; sprite != nullptr; sprite = sprite->next) {
        if (sprite->frame <= 0) {
            continue;
        }
        Dictionary d;
        d["type"] = sprite->type;
        d["frame"] = sprite->frame;
        d["x"] = sprite->x;
        d["y"] = sprite->y;
        d["x_offset"] = sprite->xOffset;
        d["y_offset"] = sprite->yOffset;
        d["width"] = sprite->width;
        d["height"] = sprite->height;
        out.push_back(d);
    }
    return out;
}

// Graph history ----------------------------------------------------------

PackedInt32Array MicropolisEngine::get_history(int type, int scale) const {
    PackedInt32Array out;
    if (type < 0 || type >= HISTORY_TYPE_COUNT || scale < HISTORY_SHORT || scale > HISTORY_LONG) {
        return out;
    }
    out.resize(HISTORY_COUNT);
    for (int i = 0; i < HISTORY_COUNT; i++) {
        out.set(i, sim_->getHistory(type, scale, i));
    }
    return out;
}

// Map data ---------------------------------------------------------------

int MicropolisEngine::get_tile(int x, int y) const {
    return sim_->getTile(x, y) & 0xffff;
}

PackedInt32Array MicropolisEngine::get_map() const {
    PackedInt32Array out;
    out.resize(MAP_WIDTH * MAP_HEIGHT);
    int32_t *w = out.ptrw();
    for (int y = 0; y < MAP_HEIGHT; y++) {
        for (int x = 0; x < MAP_WIDTH; x++) {
            w[y * MAP_WIDTH + x] = sim_->getTile(x, y) & 0xffff;
        }
    }
    return out;
}

PackedInt32Array MicropolisEngine::get_animation_table() {
    // The engine's own table (animate.cpp). It never applies it itself: the
    // 1989 front end called animateTiles() as it drew.
    PackedInt32Array out;
    out.resize(TILE_COUNT);
    for (int i = 0; i < TILE_COUNT; i++) {
        out.set(i, Micropolis::getNextAnimatedTile(i));
    }
    return out;
}

PackedInt32Array MicropolisEngine::get_overlay(int overlay) const {
    switch (overlay) {
        case OVERLAY_POPULATION_DENSITY: return overlay_data(sim_->populationDensityMap);
        case OVERLAY_TRAFFIC_DENSITY: return overlay_data(sim_->trafficDensityMap);
        case OVERLAY_POLLUTION: return overlay_data(sim_->pollutionDensityMap);
        case OVERLAY_LAND_VALUE: return overlay_data(sim_->landValueMap);
        case OVERLAY_CRIME: return overlay_data(sim_->crimeRateMap);
        case OVERLAY_TERRAIN_DENSITY: return overlay_data(sim_->terrainDensityMap);
        case OVERLAY_POWER_GRID: return overlay_data(sim_->powerGridMap);
        case OVERLAY_RATE_OF_GROWTH: return overlay_data(sim_->rateOfGrowthMap);
        case OVERLAY_FIRE_COVERAGE: return overlay_data(sim_->fireStationEffectMap);
        case OVERLAY_POLICE_COVERAGE: return overlay_data(sim_->policeStationEffectMap);
        case OVERLAY_COMMERCIAL_RATE: return overlay_data(sim_->comRateMap);
        default: return PackedInt32Array();
    }
}

Vector2i MicropolisEngine::get_overlay_size(int overlay) const {
    switch (overlay) {
        case OVERLAY_POPULATION_DENSITY: return overlay_size(sim_->populationDensityMap);
        case OVERLAY_TRAFFIC_DENSITY: return overlay_size(sim_->trafficDensityMap);
        case OVERLAY_POLLUTION: return overlay_size(sim_->pollutionDensityMap);
        case OVERLAY_LAND_VALUE: return overlay_size(sim_->landValueMap);
        case OVERLAY_CRIME: return overlay_size(sim_->crimeRateMap);
        case OVERLAY_TERRAIN_DENSITY: return overlay_size(sim_->terrainDensityMap);
        case OVERLAY_POWER_GRID: return overlay_size(sim_->powerGridMap);
        case OVERLAY_RATE_OF_GROWTH: return overlay_size(sim_->rateOfGrowthMap);
        case OVERLAY_FIRE_COVERAGE: return overlay_size(sim_->fireStationEffectMap);
        case OVERLAY_POLICE_COVERAGE: return overlay_size(sim_->policeStationEffectMap);
        case OVERLAY_COMMERCIAL_RATE: return overlay_size(sim_->comRateMap);
        default: return Vector2i();
    }
}

// Bindings ---------------------------------------------------------------

void MicropolisEngine::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_content_dir", "path"), &MicropolisEngine::set_content_dir);
    ClassDB::bind_method(D_METHOD("get_content_dir"), &MicropolisEngine::get_content_dir);

    ClassDB::bind_method(D_METHOD("load_scenario", "scenario"), &MicropolisEngine::load_scenario);
    ClassDB::bind_method(D_METHOD("load_city", "path"), &MicropolisEngine::load_city);
    ClassDB::bind_method(D_METHOD("save_city", "path"), &MicropolisEngine::save_city);
    ClassDB::bind_method(D_METHOD("generate_map", "seed"), &MicropolisEngine::generate_map);
    ClassDB::bind_method(D_METHOD("generate_random_map"), &MicropolisEngine::generate_random_map);
    ClassDB::bind_method(D_METHOD("seed_random", "seed"), &MicropolisEngine::seed_random);
    ClassDB::bind_method(D_METHOD("set_fixed_seed", "seed"), &MicropolisEngine::set_fixed_seed);
    ClassDB::bind_method(D_METHOD("clear_fixed_seed"), &MicropolisEngine::clear_fixed_seed);

    ClassDB::bind_method(D_METHOD("tick"), &MicropolisEngine::tick);
    ClassDB::bind_method(D_METHOD("set_speed", "speed"), &MicropolisEngine::set_speed);
    ClassDB::bind_method(D_METHOD("get_speed"), &MicropolisEngine::get_speed);
    ClassDB::bind_method(D_METHOD("pause"), &MicropolisEngine::pause);
    ClassDB::bind_method(D_METHOD("resume"), &MicropolisEngine::resume);
    ClassDB::bind_method(D_METHOD("is_paused"), &MicropolisEngine::is_paused);
    ClassDB::bind_method(D_METHOD("set_passes", "passes"), &MicropolisEngine::set_passes);
    ClassDB::bind_method(D_METHOD("get_passes"), &MicropolisEngine::get_passes);

    ClassDB::bind_method(D_METHOD("get_funds"), &MicropolisEngine::get_funds);
    ClassDB::bind_method(D_METHOD("set_funds", "funds"), &MicropolisEngine::set_funds);
    ClassDB::bind_method(D_METHOD("get_city_time"), &MicropolisEngine::get_city_time);
    ClassDB::bind_method(D_METHOD("get_year"), &MicropolisEngine::get_year);
    ClassDB::bind_method(D_METHOD("get_month"), &MicropolisEngine::get_month);
    ClassDB::bind_method(D_METHOD("get_population"), &MicropolisEngine::get_population);
    ClassDB::bind_method(D_METHOD("get_residential_population"), &MicropolisEngine::get_residential_population);
    ClassDB::bind_method(D_METHOD("get_commercial_population"), &MicropolisEngine::get_commercial_population);
    ClassDB::bind_method(D_METHOD("get_industrial_population"), &MicropolisEngine::get_industrial_population);
    ClassDB::bind_method(D_METHOD("get_demand"), &MicropolisEngine::get_demand);
    ClassDB::bind_method(D_METHOD("get_city_name"), &MicropolisEngine::get_city_name);
    ClassDB::bind_method(D_METHOD("set_city_name", "name"), &MicropolisEngine::set_city_name);
    ClassDB::bind_method(D_METHOD("get_game_level"), &MicropolisEngine::get_game_level);
    ClassDB::bind_method(D_METHOD("set_game_level", "level"), &MicropolisEngine::set_game_level);
    ClassDB::bind_method(D_METHOD("get_scenario"), &MicropolisEngine::get_scenario);

    ClassDB::bind_method(D_METHOD("set_disasters_enabled", "enabled"), &MicropolisEngine::set_disasters_enabled);
    ClassDB::bind_method(D_METHOD("get_disasters_enabled"), &MicropolisEngine::get_disasters_enabled);
    ClassDB::bind_method(D_METHOD("set_auto_budget", "enabled"), &MicropolisEngine::set_auto_budget);
    ClassDB::bind_method(D_METHOD("get_auto_budget"), &MicropolisEngine::get_auto_budget);
    ClassDB::bind_method(D_METHOD("set_auto_bulldoze", "enabled"), &MicropolisEngine::set_auto_bulldoze);
    ClassDB::bind_method(D_METHOD("get_auto_bulldoze"), &MicropolisEngine::get_auto_bulldoze);
    ClassDB::bind_method(D_METHOD("set_auto_goto", "enabled"), &MicropolisEngine::set_auto_goto);
    ClassDB::bind_method(D_METHOD("get_auto_goto"), &MicropolisEngine::get_auto_goto);
    ClassDB::bind_method(D_METHOD("set_animation", "enabled"), &MicropolisEngine::set_animation);
    ClassDB::bind_method(D_METHOD("get_animation"), &MicropolisEngine::get_animation);
    ClassDB::bind_method(D_METHOD("set_messages", "enabled"), &MicropolisEngine::set_messages);
    ClassDB::bind_method(D_METHOD("get_messages"), &MicropolisEngine::get_messages);
    ClassDB::bind_method(D_METHOD("set_notices", "enabled"), &MicropolisEngine::set_notices);
    ClassDB::bind_method(D_METHOD("get_notices"), &MicropolisEngine::get_notices);
    ClassDB::bind_method(D_METHOD("cheat", "word"), &MicropolisEngine::cheat);

    ClassDB::bind_method(D_METHOD("do_tool", "tool", "x", "y"), &MicropolisEngine::do_tool);
    ClassDB::bind_method(D_METHOD("tool_down", "tool", "x", "y"), &MicropolisEngine::tool_down);
    ClassDB::bind_method(D_METHOD("tool_drag", "tool", "from_x", "from_y", "to_x", "to_y"),
                         &MicropolisEngine::tool_drag);
    ClassDB::bind_static_method("MicropolisEngine", D_METHOD("get_tool_cost", "tool"),
                                &MicropolisEngine::get_tool_cost);
    ClassDB::bind_static_method("MicropolisEngine", D_METHOD("get_tool_size", "tool"),
                                &MicropolisEngine::get_tool_size);

    ClassDB::bind_method(D_METHOD("get_tax_rate"), &MicropolisEngine::get_tax_rate);
    ClassDB::bind_method(D_METHOD("set_tax_rate", "rate"), &MicropolisEngine::set_tax_rate);
    ClassDB::bind_method(D_METHOD("set_road_percent", "percent"), &MicropolisEngine::set_road_percent);
    ClassDB::bind_method(D_METHOD("set_fire_percent", "percent"), &MicropolisEngine::set_fire_percent);
    ClassDB::bind_method(D_METHOD("set_police_percent", "percent"), &MicropolisEngine::set_police_percent);
    ClassDB::bind_method(D_METHOD("get_budget"), &MicropolisEngine::get_budget);
    ClassDB::bind_method(D_METHOD("request_budget"), &MicropolisEngine::request_budget);

    ClassDB::bind_method(D_METHOD("evaluate"), &MicropolisEngine::evaluate);
    ClassDB::bind_method(D_METHOD("get_evaluation"), &MicropolisEngine::get_evaluation);

    ClassDB::bind_method(D_METHOD("make_earthquake"), &MicropolisEngine::make_earthquake);
    ClassDB::bind_method(D_METHOD("make_fire"), &MicropolisEngine::make_fire);
    ClassDB::bind_method(D_METHOD("make_flood"), &MicropolisEngine::make_flood);
    ClassDB::bind_method(D_METHOD("make_meltdown"), &MicropolisEngine::make_meltdown);
    ClassDB::bind_method(D_METHOD("make_monster"), &MicropolisEngine::make_monster);
    ClassDB::bind_method(D_METHOD("make_tornado"), &MicropolisEngine::make_tornado);
    ClassDB::bind_method(D_METHOD("make_air_crash"), &MicropolisEngine::make_air_crash);
    ClassDB::bind_method(D_METHOD("make_fire_bombs"), &MicropolisEngine::make_fire_bombs);
    ClassDB::bind_method(D_METHOD("make_explosion", "x", "y"), &MicropolisEngine::make_explosion);

    ClassDB::bind_method(D_METHOD("get_sprites"), &MicropolisEngine::get_sprites);

    ClassDB::bind_method(D_METHOD("get_history", "type", "scale"), &MicropolisEngine::get_history);

    ClassDB::bind_method(D_METHOD("get_tile", "x", "y"), &MicropolisEngine::get_tile);
    ClassDB::bind_method(D_METHOD("get_map"), &MicropolisEngine::get_map);
    ClassDB::bind_static_method("MicropolisEngine", D_METHOD("get_animation_table"),
                                &MicropolisEngine::get_animation_table);
    ClassDB::bind_method(D_METHOD("get_overlay", "overlay"), &MicropolisEngine::get_overlay);
    ClassDB::bind_method(D_METHOD("get_overlay_size", "overlay"), &MicropolisEngine::get_overlay_size);

    BIND_CONSTANT(MAP_WIDTH);
    BIND_CONSTANT(MAP_HEIGHT);
    BIND_CONSTANT(TILE_COUNT);

    BIND_ENUM_CONSTANT(TOOL_RESIDENTIAL);
    BIND_ENUM_CONSTANT(TOOL_COMMERCIAL);
    BIND_ENUM_CONSTANT(TOOL_INDUSTRIAL);
    BIND_ENUM_CONSTANT(TOOL_FIRE_STATION);
    BIND_ENUM_CONSTANT(TOOL_POLICE_STATION);
    BIND_ENUM_CONSTANT(TOOL_QUERY);
    BIND_ENUM_CONSTANT(TOOL_WIRE);
    BIND_ENUM_CONSTANT(TOOL_BULLDOZER);
    BIND_ENUM_CONSTANT(TOOL_RAILROAD);
    BIND_ENUM_CONSTANT(TOOL_ROAD);
    BIND_ENUM_CONSTANT(TOOL_STADIUM);
    BIND_ENUM_CONSTANT(TOOL_PARK);
    BIND_ENUM_CONSTANT(TOOL_SEAPORT);
    BIND_ENUM_CONSTANT(TOOL_COAL_POWER);
    BIND_ENUM_CONSTANT(TOOL_NUCLEAR_POWER);
    BIND_ENUM_CONSTANT(TOOL_AIRPORT);
    BIND_ENUM_CONSTANT(TOOL_NETWORK);
    BIND_ENUM_CONSTANT(TOOL_WATER);
    BIND_ENUM_CONSTANT(TOOL_LAND);
    BIND_ENUM_CONSTANT(TOOL_FOREST);
    BIND_ENUM_CONSTANT(TOOL_COUNT);

    BIND_ENUM_CONSTANT(TOOL_RESULT_NO_MONEY);
    BIND_ENUM_CONSTANT(TOOL_RESULT_NEED_BULLDOZE);
    BIND_ENUM_CONSTANT(TOOL_RESULT_FAILED);
    BIND_ENUM_CONSTANT(TOOL_RESULT_OK);

    BIND_ENUM_CONSTANT(SCENARIO_NONE);
    BIND_ENUM_CONSTANT(SCENARIO_DULLSVILLE);
    BIND_ENUM_CONSTANT(SCENARIO_SAN_FRANCISCO);
    BIND_ENUM_CONSTANT(SCENARIO_HAMBURG);
    BIND_ENUM_CONSTANT(SCENARIO_BERN);
    BIND_ENUM_CONSTANT(SCENARIO_TOKYO);
    BIND_ENUM_CONSTANT(SCENARIO_DETROIT);
    BIND_ENUM_CONSTANT(SCENARIO_BOSTON);
    BIND_ENUM_CONSTANT(SCENARIO_RIO);
    BIND_ENUM_CONSTANT(SCENARIO_COUNT);

    BIND_ENUM_CONSTANT(HISTORY_RESIDENTIAL);
    BIND_ENUM_CONSTANT(HISTORY_COMMERCIAL);
    BIND_ENUM_CONSTANT(HISTORY_INDUSTRIAL);
    BIND_ENUM_CONSTANT(HISTORY_MONEY);
    BIND_ENUM_CONSTANT(HISTORY_CRIME);
    BIND_ENUM_CONSTANT(HISTORY_POLLUTION);
    BIND_ENUM_CONSTANT(HISTORY_TYPE_COUNT);
    BIND_ENUM_CONSTANT(HISTORY_SHORT);
    BIND_ENUM_CONSTANT(HISTORY_LONG);

    BIND_ENUM_CONSTANT(SPRITE_NONE);
    BIND_ENUM_CONSTANT(SPRITE_TRAIN);
    BIND_ENUM_CONSTANT(SPRITE_HELICOPTER);
    BIND_ENUM_CONSTANT(SPRITE_AIRPLANE);
    BIND_ENUM_CONSTANT(SPRITE_SHIP);
    BIND_ENUM_CONSTANT(SPRITE_MONSTER);
    BIND_ENUM_CONSTANT(SPRITE_TORNADO);
    BIND_ENUM_CONSTANT(SPRITE_EXPLOSION);
    BIND_ENUM_CONSTANT(SPRITE_BUS);
    BIND_ENUM_CONSTANT(SPRITE_TYPE_COUNT);

    BIND_ENUM_CONSTANT(OVERLAY_POPULATION_DENSITY);
    BIND_ENUM_CONSTANT(OVERLAY_TRAFFIC_DENSITY);
    BIND_ENUM_CONSTANT(OVERLAY_POLLUTION);
    BIND_ENUM_CONSTANT(OVERLAY_LAND_VALUE);
    BIND_ENUM_CONSTANT(OVERLAY_CRIME);
    BIND_ENUM_CONSTANT(OVERLAY_TERRAIN_DENSITY);
    BIND_ENUM_CONSTANT(OVERLAY_POWER_GRID);
    BIND_ENUM_CONSTANT(OVERLAY_RATE_OF_GROWTH);
    BIND_ENUM_CONSTANT(OVERLAY_FIRE_COVERAGE);
    BIND_ENUM_CONSTANT(OVERLAY_POLICE_COVERAGE);
    BIND_ENUM_CONSTANT(OVERLAY_COMMERCIAL_RATE);
    BIND_ENUM_CONSTANT(OVERLAY_COUNT);

    // One signal per engine callback the front end uses (godot_callback.cpp).
    ADD_SIGNAL(MethodInfo("funds_changed", PropertyInfo(Variant::INT, "funds")));
    ADD_SIGNAL(MethodInfo("date_changed", PropertyInfo(Variant::INT, "year"), PropertyInfo(Variant::INT, "month")));
    ADD_SIGNAL(MethodInfo("demand_changed", PropertyInfo(Variant::FLOAT, "residential"),
                          PropertyInfo(Variant::FLOAT, "commercial"), PropertyInfo(Variant::FLOAT, "industrial")));
    ADD_SIGNAL(MethodInfo("message_sent", PropertyInfo(Variant::INT, "index"), PropertyInfo(Variant::INT, "x"),
                          PropertyInfo(Variant::INT, "y"), PropertyInfo(Variant::BOOL, "picture"),
                          PropertyInfo(Variant::BOOL, "important")));
    ADD_SIGNAL(MethodInfo("budget_requested"));
    ADD_SIGNAL(MethodInfo("zone_status_shown", PropertyInfo(Variant::INT, "category"),
                          PropertyInfo(Variant::INT, "population_density"), PropertyInfo(Variant::INT, "land_value"),
                          PropertyInfo(Variant::INT, "crime"), PropertyInfo(Variant::INT, "pollution"),
                          PropertyInfo(Variant::INT, "growth"), PropertyInfo(Variant::INT, "x"),
                          PropertyInfo(Variant::INT, "y")));
    ADD_SIGNAL(MethodInfo("sound_requested", PropertyInfo(Variant::STRING, "channel"),
                          PropertyInfo(Variant::STRING, "sound"), PropertyInfo(Variant::INT, "x"),
                          PropertyInfo(Variant::INT, "y")));
    ADD_SIGNAL(MethodInfo("auto_goto_requested", PropertyInfo(Variant::INT, "x"), PropertyInfo(Variant::INT, "y"),
                          PropertyInfo(Variant::STRING, "message")));
    ADD_SIGNAL(MethodInfo("city_loaded", PropertyInfo(Variant::STRING, "path")));
    ADD_SIGNAL(MethodInfo("scenario_loaded", PropertyInfo(Variant::STRING, "name"),
                          PropertyInfo(Variant::STRING, "path")));
    ADD_SIGNAL(MethodInfo("city_load_failed", PropertyInfo(Variant::STRING, "path")));
    ADD_SIGNAL(MethodInfo("city_saved", PropertyInfo(Variant::STRING, "path")));
    ADD_SIGNAL(MethodInfo("city_save_failed", PropertyInfo(Variant::STRING, "path")));
    ADD_SIGNAL(MethodInfo("save_city_as_requested", PropertyInfo(Variant::STRING, "path")));
    ADD_SIGNAL(MethodInfo("map_generated", PropertyInfo(Variant::INT, "seed")));
    ADD_SIGNAL(MethodInfo("new_game_requested"));
    ADD_SIGNAL(MethodInfo("game_started"));
    ADD_SIGNAL(MethodInfo("scenario_started", PropertyInfo(Variant::INT, "scenario")));
    ADD_SIGNAL(MethodInfo("game_won"));
    ADD_SIGNAL(MethodInfo("game_lost"));
    ADD_SIGNAL(MethodInfo("tool_applied", PropertyInfo(Variant::STRING, "name"), PropertyInfo(Variant::INT, "x"),
                          PropertyInfo(Variant::INT, "y")));
    ADD_SIGNAL(MethodInfo("earthquake_started", PropertyInfo(Variant::INT, "strength")));
    ADD_SIGNAL(MethodInfo("budget_changed"));
    ADD_SIGNAL(MethodInfo("tax_rate_changed", PropertyInfo(Variant::INT, "rate")));
    ADD_SIGNAL(MethodInfo("evaluation_changed"));
    ADD_SIGNAL(MethodInfo("history_changed"));
    ADD_SIGNAL(MethodInfo("map_changed"));
    ADD_SIGNAL(MethodInfo("options_changed"));
    ADD_SIGNAL(MethodInfo("city_name_changed", PropertyInfo(Variant::STRING, "name")));
    ADD_SIGNAL(MethodInfo("game_level_changed", PropertyInfo(Variant::INT, "level")));
    ADD_SIGNAL(MethodInfo("speed_changed", PropertyInfo(Variant::INT, "speed")));
    ADD_SIGNAL(MethodInfo("paused_changed", PropertyInfo(Variant::BOOL, "paused")));
    ADD_SIGNAL(MethodInfo("passes_changed", PropertyInfo(Variant::INT, "passes")));
}

} // namespace godot
