// The engine's Callback interface, turned into Godot signals on MicropolisEngine.
//
// Part of Metrobits, which is GPLv3 with Electronic Arts' additional terms
// (see LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).

#pragma once

#include "engine_host.h"

#include <godot_cpp/classes/object.hpp>

namespace metrobits {

// Every engine callback that the front end needs becomes a signal, emitted
// synchronously from inside the engine call that triggered it (tick, do_tool,
// load_scenario, ...). simulateRobots and simulateChurch are hooks for engine
// extensions and stay no-ops.
// The engine owns this object and deletes it.
class GodotCallback : public NoopCallback {
public:
    explicit GodotCallback(godot::Object *owner) : owner_(owner) {}

    // Signals are held back until the owner has finished constructing.
    void set_live(bool live) { live_ = live; }

    void autoGoto(Micropolis *, V, int x, int y, std::string message) override;
    void didGenerateMap(Micropolis *, V, int seed) override;
    void didLoadCity(Micropolis *, V, std::string filename) override;
    void didLoadScenario(Micropolis *, V, std::string name, std::string fname) override;
    void didLoseGame(Micropolis *, V) override;
    void didSaveCity(Micropolis *, V, std::string filename) override;
    void didTool(Micropolis *, V, std::string name, int x, int y) override;
    void didWinGame(Micropolis *, V) override;
    void didntLoadCity(Micropolis *, V, std::string filename) override;
    void didntSaveCity(Micropolis *, V, std::string filename) override;
    void makeSound(Micropolis *, V, std::string channel, std::string sound, int x, int y) override;
    void newGame(Micropolis *, V) override;
    void saveCityAs(Micropolis *, V, std::string filename) override;
    void sendMessage(Micropolis *, V, int index, int x, int y, bool picture, bool important) override;
    void showBudgetAndWait(Micropolis *, V) override;
    void showZoneStatus(Micropolis *, V, int category, int population_density, int land_value, int crime,
                        int pollution, int growth, int x, int y) override;
    void startEarthquake(Micropolis *, V, int strength) override;
    void startGame(Micropolis *, V) override;
    void startScenario(Micropolis *, V, int scenario) override;
    void updateBudget(Micropolis *, V) override;
    void updateCityName(Micropolis *, V, std::string name) override;
    void updateDate(Micropolis *, V, int year, int month) override;
    void updateDemand(Micropolis *, V, float r, float c, float i) override;
    void updateEvaluation(Micropolis *, V) override;
    void updateFunds(Micropolis *, V, int funds) override;
    void updateGameLevel(Micropolis *, V, int level) override;
    void updateHistory(Micropolis *, V) override;
    void updateMap(Micropolis *, V) override;
    void updateOptions(Micropolis *, V) override;
    void updatePasses(Micropolis *, V, int passes) override;
    void updatePaused(Micropolis *, V, bool paused) override;
    void updateSpeed(Micropolis *, V, int speed) override;
    void updateTaxRate(Micropolis *, V, int rate) override;

private:
    template <typename... Args>
    void emit(const char *signal, const Args &...args);

    godot::Object *owner_;
    bool live_ = false;
};

} // namespace metrobits
