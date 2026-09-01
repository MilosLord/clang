#include "SampleActor.h"

#include "Engine/World.h"

ASampleActor::ASampleActor()
{
	PrimaryActorTick.bCanEverTick = true;
}

void ASampleActor::BeginPlay()
{
	Super::BeginPlay();
	TickCount = 0;
}

void ASampleActor::Tick(float DeltaTime)
{
	Super::Tick(DeltaTime);
	if (!bIsActive)
	{
		return;
	}
	++TickCount;
	SetActorLocation(GetActorLocation() + FVector(Speed * DeltaTime, 0.f, 0.f));
}

void ASampleActor::Nudge(int32 Amount)
{
	Speed += static_cast<float>(Amount);
}

float ASampleActor::GetSpeed() const
{
	return Speed;
}
