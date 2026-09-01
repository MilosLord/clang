// samples/std/Sample.h — referentni header za std profil. Prati llm/AGENTS.md doslovno:
// [[nodiscard]] tamo gde rezultat nosi informaciju, trailing return, PascalCase, kontrakti.
#pragma once

#include <cstdint>
#include <expected>
#include <string>
#include <vector>

namespace Demo
{

enum class CounterError : std::uint8_t
{
    NegativeStep,
    Overflow,
};

class Counter
{
public:
    // Precondition (proveravana, ne assertovana — By dolazi od pozivaoca): By >= 0.
    [[nodiscard]] auto Increment(std::int32_t By) -> std::expected<std::int32_t, CounterError>;
    [[nodiscard]] auto GetValue() const -> std::int32_t;

private:
    std::int32_t Value = 0;
};

[[nodiscard]] auto SumAll(const std::vector<double>& Values) -> double;
[[nodiscard]] auto Describe(const std::string& Name, std::int32_t Count) -> std::string;
[[nodiscard]] auto RunOnce() -> std::int32_t;

} // namespace Demo
