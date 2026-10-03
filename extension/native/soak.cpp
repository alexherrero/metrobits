// The soak: long runs of MicropolisCore's engine. Each of the 8
// scenarios, and the city the game's own soak built on a generated map
// (game/tools/soak.gd, which writes the build file), runs for 50 game years:
//
// - a scenario's end (won or lost, from doScenarioScore) is recorded at the
//   moment its message is sent, in the same form the game's soak records it,
//   so .harness/soak.sh can check the two agree;
// - the built city replays the game's tools on the ticks the game used them,
//   and must match every checkpoint the game recorded;
// - half way, the city is saved: saving must leave it as it was, and the saved
//   file must carry on alike whether a used engine or a new one loads it.
//
// `scons soak` builds it twice: as the game builds the engine, and with clang's
// AddressSanitizer and UndefinedBehaviorSanitizer (micropolis_soak_san).
//
//   micropolis_soak <content-dir> <out-dir> [--years=50] [--build=<file>] [--only=<name>]
//
// Standard output has only what repeats run to run; timings go to standard
// error. Exits 1 if a check fails.
//
// Part of Metrobits, which is GPLv3 with Electronic Arts' additional terms
// (see LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).

#include "engine_host.h"

#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <memory>
#include <sstream>
#include <string>
#include <vector>

namespace {

const int kFixedSeed = 1989;
const int kTicksPerYear = 16 * 48; // a phase a tick at speed 3; 48 city times a year
const char *const kMonths[] = {"Jan", "Feb", "Mar", "Apr", "May", "Jun",
                               "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"};
const char *const kScenarioNames[] = {"", "dullsville", "san_francisco", "hamburg", "bern",
                                      "tokyo", "detroit", "boston", "rio"};
const int kMessageScenarioWon = 47;
const int kMessageScenarioLost = 48;

int failures = 0;

void check(bool ok, const std::string &what) {
    if (!ok) {
        std::printf("FAIL: %s\n", what.c_str());
        failures++;
    }
}

// FNV-1a, 32 bits, over the tile map by rows, as game/tools/soak.gd hashes it.
unsigned map_hash(Micropolis *m) {
    unsigned h = 2166136261u;
    for (int y = 0; y < WORLD_H; y++) {
        for (int x = 0; x < WORLD_W; x++) {
            h = (h ^ (unsigned)(m->getTile(x, y) & 0xffff)) * 16777619u;
        }
    }
    return h;
}

// What a city is at a moment, as both soaks print it.
std::string state(Micropolis *m) {
    char buf[200];
    std::snprintf(buf, sizeof(buf), "%s %ld time=%ld pop=%ld funds=%ld score=%d map=%08x",
                  kMonths[m->cityMonth % 12], (long)m->cityYear, (long)m->cityTime, (long)m->cityPop,
                  (long)m->totalFunds, (int)m->cityScore, map_hash(m));
    return buf;
}

// The state and the random numbers' state, which the game can't see.
std::string fingerprint(Micropolis *m) {
    char buf[64];
    std::snprintf(buf, sizeof(buf), " random=%llx", (unsigned long long)m->nextRandom);
    return state(m) + buf;
}

// Records the scenario's end, from inside the engine's message.
class SoakCallback : public metrobits::NoopCallback {
public:
    Micropolis *engine = nullptr;
    std::string ended;
    int won = 0, lost = 0;
    void sendMessage(Micropolis *, V, int index, int, int, bool, bool) override {
        if ((index == kMessageScenarioWon || index == kMessageScenarioLost) && ended.empty()) {
            ended = std::string(index == kMessageScenarioWon ? "won " : "lost ") + state(engine);
        }
    }
    void didWinGame(Micropolis *, V) override { won++; }
    void didLoseGame(Micropolis *, V) override { lost++; }
};

struct Engine {
    std::unique_ptr<metrobits::ZeroedMicropolis> m;
    SoakCallback *cb = nullptr; // owned by the engine
};

Engine make_engine() {
    Engine e;
    e.m.reset(metrobits::new_micropolis());
    e.cb = new SoakCallback();
    e.cb->engine = e.m.get();
    e.m->setCallback(e.cb, emscripten::val::null());
    e.m->init();
    e.m->setFixedRandomSeed(kFixedSeed);
    return e;
}

// As the game starts every city (main.gd's _started): speed 3, running.
void start(Micropolis *m) {
    m->setSpeed(3);
    m->resume();
}

// Runs until the city's time reaches `time`, with a cap in case it stops.
long run_to(Micropolis *m, long time) {
    long ticks = 0;
    const long cap = (time - m->cityTime + 48) * 16 * 2;
    while (m->cityTime < time && ticks < cap) {
        m->simTick();
        ticks++;
    }
    return ticks;
}

// Half way, saves the city: saving must leave it as it was.
bool save_mid(const std::string &label, Micropolis *m, const std::string &file) {
    const std::string before = fingerprint(m);
    const bool saved = m->saveFile(file);
    check(saved, label + ": the city saves");
    check(fingerprint(m) == before, label + ": saving leaves the city as it was");
    return saved;
}

// The file saved half way must carry on alike whether a new engine or the
// used one (`a`, which ran the city) loads it.
void reload_both(const std::string &label, Engine &a, const std::string &file, long end) {
    Engine b = make_engine();
    check(b.m->loadCity(file), label + ": a new engine loads the saved city");
    start(b.m.get());
    run_to(b.m.get(), end);
    check(a.m->loadCity(file), label + ": the used engine loads the saved city");
    start(a.m.get());
    run_to(a.m.get(), end);
    std::printf("%s reloaded %s\n", label.c_str(), state(b.m.get()).c_str());
    check(fingerprint(a.m.get()) == fingerprint(b.m.get()),
          label + ": the saved city carries on alike in a used engine and a new one");
}

// A scenario for `years` from its start.
void soak_scenario(const std::string &content, const std::string &out, int scenario, int years) {
    const std::string name = kScenarioNames[scenario];
    Engine a = make_engine();
    {
        metrobits::ScopedCwd cwd(content);
        check(cwd.ok(), "the content folder opens");
        a.m->loadScenario(static_cast<Scenario>(scenario));
    }
    start(a.m.get());
    const long begin = a.m->cityTime;
    const std::string file = out + "/" + name + "-mid.cty";
    run_to(a.m.get(), begin + years * 48 / 2);
    const bool saved = save_mid(name, a.m.get(), file);
    run_to(a.m.get(), begin + years * 48);
    check(!a.cb->ended.empty(), name + ": the scenario ended");
    check(a.cb->won == 0 && a.cb->lost == (a.cb->ended.rfind("lost", 0) == 0 ? 1 : 0),
          name + ": a loss calls didLoseGame, and a win nothing more (doScenarioScore)");
    std::printf("%s ends %s\n", name.c_str(), a.cb->ended.c_str());
    std::printf("%s ran %s\n", name.c_str(), state(a.m.get()).c_str());
    if (saved) {
        reload_both(name, a, file, begin + years * 48);
    }
}

// The game's build, replayed: the file names the map and the new city's
// settings, then each tool, option and checkpoint with the tick it came on,
// in the order the game did them.
struct Event {
    long tick = 0;
    std::string kind; // down, drag, auto_budget, auto_bulldoze, disasters, check
    std::vector<int> args;
    std::string expected; // a checkpoint's state
};

void soak_build(const std::string &file, const std::string &out, int years) {
    std::ifstream in(file);
    check(in.good(), "the build file opens: " + file);
    if (!in.good()) {
        return;
    }
    int map_seed = 0, level = 0, funds = 0, tax = 7, auto_goto = 1;
    std::string name = "NowHere";
    std::vector<Event> events;
    std::string line;
    while (std::getline(in, line)) {
        std::istringstream words(line);
        std::string key;
        if (!(words >> key) || key[0] == '#') {
            continue;
        }
        if (key == "map_seed") words >> map_seed;
        else if (key == "name") words >> name;
        else if (key == "level") words >> level;
        else if (key == "funds") words >> funds;
        else if (key == "tax") words >> tax;
        else if (key == "auto_goto") words >> auto_goto;
        else if (key == "op") {
            Event op;
            words >> op.tick >> op.kind;
            int n;
            while (words >> n) op.args.push_back(n);
            events.push_back(op);
        } else if (key == "check") {
            Event check;
            check.kind = "check";
            words >> check.tick;
            std::getline(words, check.expected);
            check.expected = check.expected.substr(check.expected.find_first_not_of(' '));
            events.push_back(check);
        }
    }
    // As main.gd's new_city: the map, then _play_new_map, then _started.
    Engine a = make_engine();
    Micropolis *m = a.m.get();
    m->generateSomeCity(map_seed);
    m->setCityName(name);
    m->setGameLevel(static_cast<GameLevel>(level));
    m->setFunds(funds);
    m->setCityTax(tax);
    start(m);
    m->setAutoGoto(auto_goto != 0);
    const long begin = m->cityTime;
    const long end = begin + years * 48;
    const std::string mid_file = out + "/built-mid.cty";
    size_t next = 0;
    long tick = 0;
    bool passed = false, saved = false, save_ok = false;
    // On to the end, and to the game's last checkpoint, which can be a few
    // ticks past it (the game runs 7 loops a frame).
    while ((m->cityTime < end || next < events.size()) && tick < (long)years * kTicksPerYear * 2) {
        for (; next < events.size() && events[next].tick == tick; next++) {
            const Event &e = events[next];
            const std::vector<int> &x = e.args;
            if (e.kind == "check") {
                check(state(m) == e.expected,
                      "built city at tick " + std::to_string(tick) + ": " + state(m) + " is the game's " + e.expected);
            } else if (e.kind == "down" && x.size() == 3) {
                m->toolDown(static_cast<EditingTool>(x[0]), x[1], x[2]);
            } else if (e.kind == "drag" && x.size() == 5) {
                m->toolDrag(static_cast<EditingTool>(x[0]), x[1], x[2], x[3], x[4]);
            } else if (e.kind == "auto_budget" && x.size() == 1) {
                m->setAutoBudget(x[0] != 0);
            } else if (e.kind == "auto_bulldoze" && x.size() == 1) {
                m->setAutoBulldoze(x[0] != 0);
            } else if (e.kind == "disasters" && x.size() == 1) {
                m->setEnableDisasters(x[0] != 0);
            } else {
                check(false, "a known op: " + e.kind);
            }
        }
        if (m->cityTime >= end && next == events.size()) {
            break;
        }
        if (!passed && m->cityPop > 10000) {
            passed = true;
            std::printf("built passes 10000 %s\n", state(m).c_str());
        }
        if (!saved && m->cityTime >= begin + years * 48 / 2) {
            saved = true;
            save_ok = save_mid("built", m, mid_file);
        }
        m->simTick();
        tick++;
    }
    check(next == events.size(), "every tool and checkpoint of the game's was replayed");
    check(passed, "the built city passed 10,000 people");
    std::printf("built ran %s\n", state(m).c_str());
    if (save_ok) {
        reload_both("built", a, mid_file, end);
    }
}

} // namespace

int main(int argc, char **argv) {
    if (argc < 3) {
        std::fprintf(stderr, "usage: %s <content-dir> <out-dir> [--years=50] [--build=<file>] [--only=<name>]\n",
                     argv[0]);
        return 2;
    }
    // A line at a time, so a sanitizer that stops the program keeps what came before.
    std::setvbuf(stdout, nullptr, _IOLBF, 0);
    const std::string content = argv[1];
    const std::string out = argv[2];
    int years = 50;
    std::string build, only;
    for (int i = 3; i < argc; i++) {
        if (std::strncmp(argv[i], "--years=", 8) == 0) years = std::atoi(argv[i] + 8);
        else if (std::strncmp(argv[i], "--build=", 8) == 0) build = argv[i] + 8;
        else if (std::strncmp(argv[i], "--only=", 7) == 0) only = argv[i] + 7;
    }
    std::printf("soak: %d years each, seed %d\n", years, kFixedSeed);
    for (int scenario = 1; scenario <= 8; scenario++) {
        if (!only.empty() && only != kScenarioNames[scenario]) {
            continue;
        }
        const auto started = std::chrono::steady_clock::now();
        soak_scenario(content, out, scenario, years);
        std::fprintf(stderr, "%s: %.1f s\n", kScenarioNames[scenario],
                     std::chrono::duration<double>(std::chrono::steady_clock::now() - started).count());
    }
    if (!build.empty() && (only.empty() || only == "built")) {
        const auto started = std::chrono::steady_clock::now();
        soak_build(build, out, years);
        std::fprintf(stderr, "built: %.1f s\n",
                     std::chrono::duration<double>(std::chrono::steady_clock::now() - started).count());
    }
    std::printf(failures ? "SOAK FAILED (%d)\n" : "SOAK OK\n", failures);
    return failures ? 1 : 0;
}
