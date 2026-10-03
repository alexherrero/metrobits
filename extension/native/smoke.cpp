// Native smoke test for MicropolisCore's engine: load a scenario, run ticks,
// print funds, population and date, and fail if the numbers aren't sensible.
//
//   micropolis_smoke <content-dir> [scenario 1-8] [ticks]
//
// Part of Metrobits, which is GPLv3 with Electronic Arts' additional terms
// (see LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).

#include "engine_host.h"

#include <cstdio>
#include <cstdlib>
#include <memory>

namespace {

// Counts the callbacks the smoke test cares about, to show the engine reaches
// its front end natively.
class CountingCallback : public metrobits::NoopCallback {
public:
    int funds = 0, dates = 0, demands = 0, scenarios = 0;
    void updateFunds(Micropolis *, V, int) override { funds++; }
    void updateDate(Micropolis *, V, int, int) override { dates++; }
    void updateDemand(Micropolis *, V, float, float, float) override { demands++; }
    void didLoadScenario(Micropolis *, V, std::string, std::string) override { scenarios++; }
};

const char *const kMonths[] = {"Jan", "Feb", "Mar", "Apr", "May", "Jun",
                               "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"};

void print_state(const char *label, Micropolis *m) {
    std::printf("%-6s %s %ld  funds=$%ld  pop: res=%d com=%d ind=%d city=%ld  score=%d\n",
                label, kMonths[m->cityMonth % 12], (long)m->cityYear, (long)m->totalFunds,
                m->resPop, m->comPop, m->indPop, (long)m->cityPop, m->cityScore);
}

// FNV-1a over the tile map, printed so runs can be compared by eye.
unsigned long long map_hash(Micropolis *m) {
    unsigned long long h = 1469598103934665603ULL;
    for (int x = 0; x < WORLD_W; x++) {
        for (int y = 0; y < WORLD_H; y++) {
            h = (h ^ (unsigned long long)(m->getTile(x, y) & 0xffff)) * 1099511628211ULL;
        }
    }
    return h;
}

struct Result {
    long year = 0, month = 0, funds = 0, city_pop = 0, start_date = 0;
    int zones = 0, score = 0;
    unsigned long long map = 0;
    int cb_funds = 0, cb_dates = 0, cb_demands = 0, cb_loaded = 0;
    bool loaded = false;
};

// Loads the scenario in a fresh engine, runs the ticks and reports. The seed is
// fixed before the load (local engine edit 5), because every load reseeds the
// random numbers and uses them before it returns (initWillStuff, doSimInit).
Result run(const std::string &content_dir, int scenario, int ticks, int seed, bool print) {
    Result r;
    std::unique_ptr<metrobits::ZeroedMicropolis> m(metrobits::new_micropolis());
    auto *cb = new CountingCallback(); // owned by the engine
    m->setCallback(cb, emscripten::val::null());
    m->init();
    m->setFixedRandomSeed(seed);
    {
        metrobits::ScopedCwd cwd(content_dir);
        if (!cwd.ok()) {
            return r;
        }
        m->loadScenario(static_cast<Scenario>(scenario));
    }
    r.loaded = true;
    r.start_date = m->cityYear * 12 + m->cityMonth;
    if (print) {
        std::printf("\n");
        print_state("start", m.get());
    }
    for (int i = 0; i < ticks; i++) {
        m->simTick();
    }
    if (print) {
        print_state("end", m.get());
    }
    r.year = m->cityYear;
    r.month = m->cityMonth;
    r.funds = m->totalFunds;
    r.city_pop = m->cityPop;
    r.zones = m->totalPop;
    r.score = m->cityScore;
    r.map = map_hash(m.get());
    r.cb_funds = cb->funds;
    r.cb_dates = cb->dates;
    r.cb_demands = cb->demands;
    r.cb_loaded = cb->scenarios;
    return r;
}

} // namespace

int main(int argc, char **argv) {
    if (argc < 2) {
        std::fprintf(stderr, "usage: %s <content-dir> [scenario 1-8] [ticks]\n", argv[0]);
        return 2;
    }
    const std::string content_dir = argv[1];
    const int scenario = argc > 2 ? std::atoi(argv[2]) : SC_DETROIT;
    const int ticks = argc > 3 ? std::atoi(argv[3]) : 2000;

    const int seed = 1989;
    const Result a = run(content_dir, scenario, ticks, seed, true);
    const Result b = run(content_dir, scenario, ticks, seed, false);
    if (!a.loaded) {
        std::fprintf(stderr, "FAIL: can't enter content dir %s\n", content_dir.c_str());
        return 1;
    }
    std::printf("ticks=%d  seed=%d  map=%016llx  callbacks: funds=%d date=%d demand=%d loaded=%d\n",
                ticks, seed, a.map, a.cb_funds, a.cb_dates, a.cb_demands, a.cb_loaded);

    int failures = 0;
    auto check = [&](bool ok, const char *what) {
        if (!ok) {
            std::fprintf(stderr, "FAIL: %s\n", what);
            failures++;
        }
    };
    check(a.cb_loaded == 1, "the scenario reported loading once");
    check(a.zones > 0, "the city has zones");
    check(a.city_pop > 0, "the city has people");
    check(a.year * 12 + a.month > a.start_date, "the date moved forward");
    check(a.funds > -1000000 && a.funds < 10000000, "funds are in a plausible range");
    check(a.cb_funds > 0 && a.cb_dates > 0 && a.cb_demands > 0, "the engine called its front end");
    check(b.loaded && a.map == b.map && a.funds == b.funds && a.city_pop == b.city_pop &&
              a.year == b.year && a.month == b.month,
          "a second run with the same seed is identical");

    std::printf(failures ? "SMOKE FAILED\n" : "SMOKE OK\n");
    return failures ? 1 : 0;
}
