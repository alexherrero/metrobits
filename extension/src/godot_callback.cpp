// The engine's Callback interface, turned into Godot signals on MicropolisEngine.
//
// Part of Metrobits, which is GPLv3 with Electronic Arts' additional terms
// (see LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).

#include "godot_callback.h"

#include <godot_cpp/variant/string.hpp>

using godot::String;

namespace metrobits {

namespace {
String str(const std::string &s) {
    return String::utf8(s.c_str());
}
} // namespace

template <typename... Args>
void GodotCallback::emit(const char *signal, const Args &...args) {
    if (live_ && owner_ != nullptr) {
        owner_->emit_signal(signal, args...);
    }
}

void GodotCallback::autoGoto(Micropolis *, V, int x, int y, std::string message) {
    emit("auto_goto_requested", x, y, str(message));
}
void GodotCallback::didGenerateMap(Micropolis *, V, int seed) { emit("map_generated", seed); }
void GodotCallback::didLoadCity(Micropolis *, V, std::string filename) { emit("city_loaded", str(filename)); }
void GodotCallback::didLoadScenario(Micropolis *, V, std::string name, std::string fname) {
    emit("scenario_loaded", str(name), str(fname));
}
void GodotCallback::didLoseGame(Micropolis *, V) { emit("game_lost"); }
void GodotCallback::didSaveCity(Micropolis *, V, std::string filename) { emit("city_saved", str(filename)); }
void GodotCallback::didTool(Micropolis *, V, std::string name, int x, int y) {
    emit("tool_applied", str(name), x, y);
}
void GodotCallback::didWinGame(Micropolis *, V) { emit("game_won"); }
void GodotCallback::didntLoadCity(Micropolis *, V, std::string filename) {
    emit("city_load_failed", str(filename));
}
void GodotCallback::didntSaveCity(Micropolis *, V, std::string filename) {
    emit("city_save_failed", str(filename));
}
void GodotCallback::makeSound(Micropolis *, V, std::string channel, std::string sound, int x, int y) {
    emit("sound_requested", str(channel), str(sound), x, y);
}
void GodotCallback::newGame(Micropolis *, V) { emit("new_game_requested"); }
void GodotCallback::saveCityAs(Micropolis *, V, std::string filename) {
    emit("save_city_as_requested", str(filename));
}
void GodotCallback::sendMessage(Micropolis *, V, int index, int x, int y, bool picture, bool important) {
    emit("message_sent", index, x, y, picture, important);
}
void GodotCallback::showBudgetAndWait(Micropolis *, V) { emit("budget_requested"); }
void GodotCallback::showZoneStatus(Micropolis *, V, int category, int population_density, int land_value,
                                   int crime, int pollution, int growth, int x, int y) {
    emit("zone_status_shown", category, population_density, land_value, crime, pollution, growth, x, y);
}
void GodotCallback::startEarthquake(Micropolis *, V, int strength) { emit("earthquake_started", strength); }
void GodotCallback::startGame(Micropolis *, V) { emit("game_started"); }
void GodotCallback::startScenario(Micropolis *, V, int scenario) { emit("scenario_started", scenario); }
void GodotCallback::updateBudget(Micropolis *, V) { emit("budget_changed"); }
void GodotCallback::updateCityName(Micropolis *, V, std::string name) { emit("city_name_changed", str(name)); }
void GodotCallback::updateDate(Micropolis *, V, int year, int month) { emit("date_changed", year, month); }
void GodotCallback::updateDemand(Micropolis *, V, float r, float c, float i) {
    emit("demand_changed", r, c, i);
}
void GodotCallback::updateEvaluation(Micropolis *, V) { emit("evaluation_changed"); }
void GodotCallback::updateFunds(Micropolis *, V, int funds) { emit("funds_changed", funds); }
void GodotCallback::updateGameLevel(Micropolis *, V, int level) { emit("game_level_changed", level); }
void GodotCallback::updateHistory(Micropolis *, V) { emit("history_changed"); }
void GodotCallback::updateMap(Micropolis *, V) { emit("map_changed"); }
void GodotCallback::updateOptions(Micropolis *, V) { emit("options_changed"); }
void GodotCallback::updatePasses(Micropolis *, V, int passes) { emit("passes_changed", passes); }
void GodotCallback::updatePaused(Micropolis *, V, bool paused) { emit("paused_changed", paused); }
void GodotCallback::updateSpeed(Micropolis *, V, int speed) { emit("speed_changed", speed); }
void GodotCallback::updateTaxRate(Micropolis *, V, int rate) { emit("tax_rate_changed", rate); }

} // namespace metrobits
