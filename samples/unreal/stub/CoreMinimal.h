// Fejk UE za CI. Dovoljno da samples/unreal/*.cpp prodje clang-tidy bez engine-a.
// NE koristiti van samples/.
#pragma once

#include <cstdint>

using int32 = std::int32_t;

#define UCLASS(...)
#define USTRUCT(...)
#define UENUM(...)
#define UPROPERTY(...)
#define UFUNCTION(...)
#define GENERATED_BODY()

struct FVector
{
	double X = 0.0;
	double Y = 0.0;
	double Z = 0.0;

	FVector() = default;

	FVector(double InX, double InY, double InZ)
		: X(InX)
		, Y(InY)
		, Z(InZ)
	{
	}

	FVector operator+(const FVector& Other) const { return {X + Other.X, Y + Other.Y, Z + Other.Z}; }
};

struct FActorTickFunction
{
	bool bCanEverTick = false;
};

class AActor
{
public:
	virtual ~AActor() = default;

	virtual void BeginPlay() {}

	virtual void Tick(float /*DeltaTime*/) {}

	FVector GetActorLocation() const { return Location; }

	void SetActorLocation(const FVector& NewLocation) { Location = NewLocation; }

	FActorTickFunction PrimaryActorTick;

protected:
	using Super = AActor;

private:
	FVector Location;
};
