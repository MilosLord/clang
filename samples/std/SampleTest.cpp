// samples/std/SampleTest.cpp — test po svakoj grani iz Sample.cpp, bez framework-a (assert).
// CI: c++ -std=c++23 -UNDEBUG Sample.cpp SampleTest.cpp && ./a.out
//
// Pokrivene grane:
//   Counter::Increment  ok / NegativeStep / Overflow
//   SumAll              prazno / vise elemenata
//   Describe            Count<=0 / Count>0
//   RunOnce             0 (sve ostale grane RunOnce-a su greske u ovom fajlu, ne u kodu)

#include "Sample.h"

#include <cassert>
#include <cstdint>
#include <limits>
#include <vector>

namespace
{

auto TestIncrement() -> void
{
    Demo::Counter C;
    const auto    R1 = C.Increment(5);
    assert(R1.has_value() && *R1 == 5);
    assert(C.GetValue() == 5);

    const auto R2 = C.Increment(-1);
    assert(!R2.has_value() && R2.error() == Demo::CounterError::NegativeStep);
    assert(C.GetValue() == 5); // greska ne menja stanje

    const auto R3 = C.Increment(std::numeric_limits<std::int32_t>::max());
    assert(!R3.has_value() && R3.error() == Demo::CounterError::Overflow);
    assert(C.GetValue() == 5);
}

auto TestSumAll() -> void
{
    assert(Demo::SumAll({}) == 0.0);
    constexpr double          Expected = 4.0;
    const std::vector<double> V        = {1.5, 2.5};
    assert(Demo::SumAll(V) == Expected);
}

auto TestDescribe() -> void
{
    assert(Demo::Describe("X", 0) == "X: none");
    assert(Demo::Describe("X", -3) == "X: none");
    assert(Demo::Describe("X", 7) == "X: 7");
}

} // namespace

auto main() -> int
{
    TestIncrement();
    TestSumAll();
    TestDescribe();
    assert(Demo::RunOnce() == 0);
    return 0;
}
