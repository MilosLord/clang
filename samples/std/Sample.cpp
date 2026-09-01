// samples/std/Sample.cpp — referentni fajl za std profil.
// CI ga formatira (--dry-run --Werror), tidy-uje sa --warnings-as-errors=* i pokrece
// SampleTest.cpp. Ako config ili instrukcije istrunu, ovo pukne.
//
// Sta demonstrira:
//   * trailing return + PascalCase + Go-style poravnanje + obavezne viticaste
//   * kontrakt: assert za INTERNI invariant, std::expected za gresku POZIVAOCA
//   * RunOnce je namerno 30..50 linija sa ispravnim one-shot markerom

#include "Sample.h"

#include <array>
#include <cassert>
#include <cstddef>
#include <cstdint>
#include <expected>
#include <limits>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

namespace Demo
{

namespace
{

constexpr std::int32_t MaxRetries  = 3;
constexpr double       Epsilon     = 1e-9;
constexpr double       ExpectedSum = 6.0;

auto IsClose(double A, double B) -> bool { return (A > B ? A - B : B - A) < Epsilon; }

} // namespace

auto Counter::Increment(std::int32_t By) -> std::expected<std::int32_t, CounterError>
{
    if (By < 0) { return std::unexpected(CounterError::NegativeStep); }
    if (Value > std::numeric_limits<std::int32_t>::max() - By) { return std::unexpected(CounterError::Overflow); }
    Value += By;
    assert(Value >= By); // invariant: brojac nikad ne ide unazad
    return Value;
}

auto Counter::GetValue() const -> std::int32_t { return Value; }

auto SumAll(const std::vector<double>& Values) -> double
{
    double Total = 0.0;
    for (const double V : Values)
    {
        Total += V;
    }
    return Total;
}

auto Describe(const std::string& Name, std::int32_t Count) -> std::string
{
    if (Count <= 0) { return Name + ": none"; }
    return Name + ": " + std::to_string(Count);
}

// NOLINTNEXTLINE(readability-function-size) one-shot: linearna tabela koraka — redosled JE test, deljenje bi ga sakrilo
auto RunOnce() -> std::int32_t
{
    Counter C;
    // Svaki red je jedan korak; prvi koji padne vraca svoj 1-based indeks.
    using Step             = std::pair<std::string_view, bool>;
    const std::array Steps = {
        Step{"inc 1 ok", C.Increment(1).has_value()},
        Step{"inc 1 ok", C.Increment(1).has_value()},
        Step{"inc 1 ok", C.Increment(1).has_value()},
        Step{"value == MaxRetries", C.GetValue() == MaxRetries},
        Step{"inc 0 ok (no-op)", C.Increment(0).has_value()},
        Step{"value unchanged", C.GetValue() == MaxRetries},
        Step{"inc -1 rejected", !C.Increment(-1).has_value()},
        Step{"inc -1 is NegativeStep", C.Increment(-1).error() == CounterError::NegativeStep},
        Step{"value unchanged after error", C.GetValue() == MaxRetries},
        Step{"inc max rejected", !C.Increment(std::numeric_limits<std::int32_t>::max()).has_value()},
        Step{"inc max is Overflow",
             C.Increment(std::numeric_limits<std::int32_t>::max()).error() == CounterError::Overflow},
        Step{"value unchanged after overflow", C.GetValue() == MaxRetries},
        Step{"sum {} == 0", IsClose(SumAll({}), 0.0)},
        Step{"sum {1} == 1", IsClose(SumAll({1.0}), 1.0)},
        Step{"sum {1,2,3} == 6", IsClose(SumAll({1.0, 2.0, 3.0}), ExpectedSum)},
        Step{"sum {0.5,0.5} == 1", IsClose(SumAll({0.5, 0.5}), 1.0)},
        Step{"describe 0", Describe("Items", 0) == "Items: none"},
        Step{"describe -1", Describe("Items", -1) == "Items: none"},
        Step{"describe 1", Describe("Items", 1) == "Items: 1"},
        Step{"describe 2", Describe("Items", 2) == "Items: 2"},
        Step{"describe keeps name", Describe("Other", 2) == "Other: 2"},
        Step{"isclose self", IsClose(Epsilon, Epsilon)},
        Step{"isclose zero", IsClose(0.0, 0.0)},
        Step{"not close 0/1", !IsClose(0.0, 1.0)},
    };
    for (std::size_t I = 0; I < Steps.size(); ++I)
    {
        if (!Steps[I].second) { return static_cast<std::int32_t>(I) + 1; }
    }
    return 0;
}

} // namespace Demo
