// What a native host needs to run MicropolisCore's engine outside the browser.
// Shared by the smoke program and the GDExtension; it has no Godot dependency.
//
// Part of Metrobits, which is GPLv3 with Electronic Arts' additional terms
// (see LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).

#pragma once

#include "micropolis.h"

#include <climits>
#include <string>
#include <unistd.h>

namespace metrobits {

// Micropolis's constructor leaves most members, including `callback`, to init()
// or to nothing at all, and setCallback() deletes a non-null `callback`. The
// WebAssembly build gets away with it because a fresh wasm heap is zeroed; a
// native heap reuses memory. Value-initialising a subclass whose default
// constructor is implicit zero-fills every member before Micropolis() runs, so
// the engine starts from the state it assumes, with no edit to the engine.
// ~Micropolis isn't virtual, so always delete through this type.
struct ZeroedMicropolis : public Micropolis {};

inline ZeroedMicropolis *new_micropolis() {
    return new ZeroedMicropolis();
}

// Every Callback method as a no-op, so a host overrides only what it uses.
// The engine owns its callback and deletes it in setCallback() and ~Micropolis.
class NoopCallback : public Callback {
public:
    using V = emscripten::val;
    void autoGoto(Micropolis *, V, int, int, std::string) override {}
    void didGenerateMap(Micropolis *, V, int) override {}
    void didLoadCity(Micropolis *, V, std::string) override {}
    void didLoadScenario(Micropolis *, V, std::string, std::string) override {}
    void didLoseGame(Micropolis *, V) override {}
    void didSaveCity(Micropolis *, V, std::string) override {}
    void didTool(Micropolis *, V, std::string, int, int) override {}
    void didWinGame(Micropolis *, V) override {}
    void didntLoadCity(Micropolis *, V, std::string) override {}
    void didntSaveCity(Micropolis *, V, std::string) override {}
    void makeSound(Micropolis *, V, std::string, std::string, int, int) override {}
    void newGame(Micropolis *, V) override {}
    void saveCityAs(Micropolis *, V, std::string) override {}
    void sendMessage(Micropolis *, V, int, int, int, bool, bool) override {}
    void showBudgetAndWait(Micropolis *, V) override {}
    void showZoneStatus(Micropolis *, V, int, int, int, int, int, int, int, int) override {}
    void simulateRobots(Micropolis *, V) override {}
    void simulateChurch(Micropolis *, V, int, int, int) override {}
    void startEarthquake(Micropolis *, V, int) override {}
    void startGame(Micropolis *, V) override {}
    void startScenario(Micropolis *, V, int) override {}
    void updateBudget(Micropolis *, V) override {}
    void updateCityName(Micropolis *, V, std::string) override {}
    void updateDate(Micropolis *, V, int, int) override {}
    void updateDemand(Micropolis *, V, float, float, float) override {}
    void updateEvaluation(Micropolis *, V) override {}
    void updateFunds(Micropolis *, V, int) override {}
    void updateGameLevel(Micropolis *, V, int) override {}
    void updateHistory(Micropolis *, V) override {}
    void updateMap(Micropolis *, V) override {}
    void updateOptions(Micropolis *, V) override {}
    void updatePasses(Micropolis *, V, int) override {}
    void updatePaused(Micropolis *, V, bool) override {}
    void updateSpeed(Micropolis *, V, int) override {}
    void updateTaxRate(Micropolis *, V, int) override {}
};

// The engine opens scenario files by the relative path "cities/<name>.cty",
// which the web build satisfies with a preloaded virtual filesystem. Natively,
// the working directory has to be the content folder for the duration of the
// call. The change is process-wide, so keep the scope to the one engine call.
class ScopedCwd {
public:
    explicit ScopedCwd(const std::string &dir) {
        char buf[PATH_MAX];
        if (getcwd(buf, sizeof(buf)) != nullptr) {
            previous_ = buf;
        }
        ok_ = !dir.empty() && chdir(dir.c_str()) == 0;
    }
    ~ScopedCwd() {
        if (ok_ && !previous_.empty()) {
            (void)chdir(previous_.c_str());
        }
    }
    bool ok() const { return ok_; }

private:
    std::string previous_;
    bool ok_ = false;
};

} // namespace metrobits
