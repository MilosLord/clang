// samples/unreal/SampleActor.h — referentni UE header za unreal profil.
// Kompajlira se standalone preko UEStub.h (fejk makroi) da CI ne mora da ima engine.
// Bitno sto CI proverava: tabovi, Allman, .generated.h POSLEDNJI, UPROPERTY blokovi
// neporemeceni, klasicni return tip (ne trailing — UHT), <=30 linija.

#pragma once

#include "CoreMinimal.h"

#include "GameFramework/Actor.h"

#include "SampleActor.generated.h"

UCLASS()
class ASampleActor : public AActor
{
	GENERATED_BODY()

public:
	ASampleActor();

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Sample")
	float Speed = 600.f;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Sample")
	bool bIsActive = true;

	UFUNCTION(BlueprintCallable, Category = "Sample")
	void Nudge(int32 Amount);

	UFUNCTION(BlueprintPure, Category = "Sample")
	float GetSpeed() const;

protected:
	virtual void BeginPlay() override;
	virtual void Tick(float DeltaTime) override;

private:
	int32 TickCount = 0;
};
