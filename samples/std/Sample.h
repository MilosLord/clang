#pragma once

#include <cstdint>
#include <string>
#include <vector>

namespace Demo
{

class Counter
{
public:
    auto               Increment(std::int32_t By) -> std::int32_t;
    [[nodiscard]] auto GetValue() const -> std::int32_t;

private:
    std::int32_t Value = 0;
};

auto SumAll(const std::vector<double>& Values) -> double;
auto Describe(const std::string& Name, std::int32_t Count) -> std::string;
auto RunOnce() -> std::int32_t;

} // namespace Demo
