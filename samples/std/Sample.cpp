// samples/std/Sample.cpp — referentni fajl za std profil.
// CI ga formatira (--dry-run --Werror) i tidy-uje; ako config istrune, ovo pukne.
// Ovde je sve ONAKO kako treba da izgleda: trailing return, PascalCase, <=30 linija,
// obavezne viticaste, west const, Go-style poravnanje, include grupe.

#include "Sample.h"

#include <cstdint>
#include <string>
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

auto Counter::Increment(std::int32_t By) -> std::int32_t
{
    Value += By;
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

// NOLINTNEXTLINE(readability-function-size) one-shot: sekvencijalni setup, nema sta da se razbije
auto RunOnce() -> std::int32_t
{
    Counter      C;
    std::int32_t Attempts = 0;
    while (Attempts < MaxRetries)
    {
        C.Increment(1);
        ++Attempts;
    }
    const std::vector<double> Vals = {1.0, 2.0, 3.0};
    if (!IsClose(SumAll(Vals), ExpectedSum)) { return 1; }
    return C.GetValue() == MaxRetries ? 0 : 1;
}

} // namespace Demo

auto main() -> int { return Demo::RunOnce(); }
