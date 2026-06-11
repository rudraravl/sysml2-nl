package MedicalScrubsSystem {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Percentage :> Real {
    unit = "%";
  }

  attribute def ThreadCount :> Real {
    unit = "threads/cm";
  }

  attribute def AirPermeability :> Real {
    unit = "L/(m^2*s)";
  }

  attribute def AbsorptionRate :> Real {
    unit = "mL/s";
  }

  attribute def MassDensity :> Real {
    unit = "g/m^2";
  }

  attribute def WashCycleCount :> Integer;

  item def SkinContact;
  item def BodyHeat;
  item def Perspiration;
  item def AirFlow;
  item def ContaminantParticle {
    attribute diameter : Length;
    attribute biologicalRiskLevel : Integer;
  }
  item def FluidSplash {
    attribute volume : Volume;
    attribute impactVelocity : Speed;
  }
  item def LaunderingWater {
    attribute temperature : Temperature;
    attribute detergentConcentration : Percentage;
  }

  port def SkinInterfacePort {
    in item skinContact : SkinContact;
    in item perspiration : Perspiration;
    in item bodyHeat : BodyHeat;
  }

  port def EnvironmentInterfacePort {
    in item air : AirFlow;
    in item particles : ContaminantParticle;
    in item splash : FluidSplash;
    out item evaporatedMoisture : Perspiration;
    out item rejectedParticles : ContaminantParticle;
  }

  port def LaunderingPort {
    in item washWater : LaunderingWater;
    out item removedContaminants : ContaminantParticle;
  }

  port def StoragePort {
    in item personalItems;
    out item personalItems;
  }

  part def FabricPanel {
    attribute fabricMass : Mass;
    attribute area : Area;
    attribute surfaceDensity : MassDensity;
    attribute cottonFraction : Percentage;
    attribute polyesterFraction : Percentage;
    attribute elastaneFraction : Percentage;
    attribute airPermeability : AirPermeability;
    attribute moistureWickingRate : AbsorptionRate;
    attribute particleCaptureEfficiency : Percentage;
    attribute fluidRepellency : Percentage;
    attribute maxWashCycles : WashCycleCount;

    port wearerSide : SkinInterfacePort;
    port environmentSide : EnvironmentInterfacePort;

    perform action WickMoisture;
    perform action ReleaseHeat;
    perform action ResistSplash;
    perform action FilterParticles;
  }

  part def Seam {
    attribute seamStrength : Force;
    attribute stitchDensity : ThreadCount;
    attribute flatlock : Boolean;
    attribute chafeRisk : Percentage;
  }

  part def Closure {
    attribute type : String;
    attribute retentionForce : Force;
    attribute adjustableRange : Length;
  }

  part def Pocket {
    attribute volumeCapacity : Volume;
    attribute loadLimit : Mass;
    attribute hasReinforcedOpening : Boolean;
    port storage : StoragePort;
  }

  part def IdentificationArea {
    attribute visibleArea : Area;
    attribute acceptsBadgeClip : Boolean;
    attribute acceptsEmbroidery : Boolean;
  }

  part def ScrubTop {
    part torsoPanel : FabricPanel;
    part leftSleeve : FabricPanel;
    part rightSleeve : FabricPanel;
    part neckBinding : Seam;
    part shoulderSeams : Seam[2];
    part sideSeams : Seam[2];
    part chestPocket : Pocket;
    part badgeArea : IdentificationArea;

    port wearer : SkinInterfacePort;
    port clinicalEnvironment : EnvironmentInterfacePort;
    port storage : StoragePort;

    connect wearer to torsoPanel.wearerSide;
    connect wearer to leftSleeve.wearerSide;
    connect wearer to rightSleeve.wearerSide;
    connect clinicalEnvironment to torsoPanel.environmentSide;
    connect clinicalEnvironment to leftSleeve.environmentSide;
    connect clinicalEnvironment to rightSleeve.environmentSide;
    connect storage to chestPocket.storage;
  }

  part def ScrubPants {
    part waistPanel : FabricPanel;
    part leftLegPanel : FabricPanel;
    part rightLegPanel : FabricPanel;
    part inseam : Seam[2];
    part outseam : Seam[2];
    part waistband : Closure;
    part drawstring : Closure;
    part cargoPocketLeft : Pocket;
    part cargoPocketRight : Pocket;

    port wearer : SkinInterfacePort;
    port clinicalEnvironment : EnvironmentInterfacePort;
    port storage : StoragePort;

    connect wearer to waistPanel.wearerSide;
    connect wearer to leftLegPanel.wearerSide;
    connect wearer to rightLegPanel.wearerSide;
    connect clinicalEnvironment to waistPanel.environmentSide;
    connect clinicalEnvironment to leftLegPanel.environmentSide;
    connect clinicalEnvironment to rightLegPanel.environmentSide;
    connect storage to cargoPocketLeft.storage;
    connect storage to cargoPocketRight.storage;
  }

  part def ScrubsSet {
    attribute sizeCode : String;
    attribute totalMass : Mass;
    attribute intendedShiftDuration : Time;
    attribute reusable : Boolean;
    attribute colorFastnessAfterWash : Percentage;
    attribute nominalServiceLife : WashCycleCount;

    part top : ScrubTop;
    part pants : ScrubPants;

    port wearer : SkinInterfacePort;
    port clinicalEnvironment : EnvironmentInterfacePort;
    port laundering : LaunderingPort;
    port storage : StoragePort;

    connect wearer to top.wearer;
    connect wearer to pants.wearer;
    connect clinicalEnvironment to top.clinicalEnvironment;
    connect clinicalEnvironment to pants.clinicalEnvironment;
    connect storage to top.storage;
    connect storage to pants.storage;

    perform action SupportClinicalWork;
    perform action ProtectWearer;
    perform action MaintainComfort;
    perform action CarrySmallItems;
    perform action LaunderAndReuse;
  }

  action def SupportClinicalWork {
    in item wearerMotion;
    in item clinicalExposure;
    out item coveredBodySurface;
    out item accessibleStoredItems;

    first start;
    then coverTorsoAndLegs;
    then permitRangeOfMotion;
    then manageMoistureAndHeat;
    then provideItemAccess;
    then done;

    action coverTorsoAndLegs;
    action permitRangeOfMotion;
    action manageMoistureAndHeat;
    action provideItemAccess;
  }

  action def ProtectWearer {
    in item splash : FluidSplash;
    in item particles : ContaminantParticle;
    out item rejectedSplash : FluidSplash;
    out item rejectedParticles : ContaminantParticle;

    first detectExposure;
    then repelFluid;
    then trapOrDeflectParticles;
    then isolateSkinContact;
    then complete;

    action detectExposure;
    action repelFluid;
    action trapOrDeflectParticles;
    action isolateSkinContact;
  }

  action def MaintainComfort {
    in item bodyHeat : BodyHeat;
    in item perspiration : Perspiration;
    in item air : AirFlow;
    out item evaporatedMoisture : Perspiration;

    first receiveHeatAndMoisture;
    then wickMoistureAwayFromSkin;
    then exchangeAirThroughFabric;
    then releaseHeatToEnvironment;
    then finish;

    action receiveHeatAndMoisture;
    action wickMoistureAwayFromSkin;
    action exchangeAirThroughFabric;
    action releaseHeatToEnvironment;
  }

  action def CarrySmallItems {
    in item personalItems;
    out item retainedItems;

    first insertItems;
    then retainDuringMovement;
    then provideRapidAccess;
    then complete;

    action insertItems;
    action retainDuringMovement;
    action provideRapidAccess;
  }

  action def LaunderAndReuse {
    in item washWater : LaunderingWater;
    out item removedContaminants : ContaminantParticle;
    out item restoredScrubs;

    first soak;
    then detergentWash;
    then rinse;
    then dry;
    then readyForReuse;

    action soak;
    action detergentWash;
    action rinse;
    action dry;
  }

  action def WickMoisture {
    in item perspiration : Perspiration;
    out item evaporatedMoisture : Perspiration;
  }

  action def ReleaseHeat {
    in item bodyHeat : BodyHeat;
    out item dissipatedHeat : BodyHeat;
  }

  action def ResistSplash {
    in item splash : FluidSplash;
    out item rejectedSplash : FluidSplash;
  }

  action def FilterParticles {
    in item particles : ContaminantParticle;
    out item rejectedParticles : ContaminantParticle;
  }

  state def ScrubsLifecycle {
    entry action InitializeCleanState;

    state CleanReady;
    state WornInClinicalUse;
    state Contaminated;
    state InLaundering;
    state Drying;
    state Retired;

    transition first CleanReady;
    transition wear from CleanReady to WornInClinicalUse;
    transition exposure from WornInClinicalUse to Contaminated;
    transition endShiftNoExposure from WornInClinicalUse to InLaundering;
    transition removeForWash from Contaminated to InLaundering;
    transition washComplete from InLaundering to Drying;
    transition dryComplete from Drying to CleanReady;
    transition serviceLifeExceeded from CleanReady to Retired;

    action InitializeCleanState;
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The scrubs set shall provide a reusable clinical garment system that covers the wearer's torso and legs while supporting hygienic practice, comfort, identification, and carriage of small work items during healthcare tasks. */
  }

  requirement def CoverageRequirement {
    doc /* The scrubs set shall cover the torso, shoulders, upper arms, waist, hips, and legs during normal standing, sitting, bending, and walking motions. */
    attribute minimumCoveredBodySurface : Percentage = 85 [%];
  }

  requirement def ComfortRequirement {
    doc /* The fabric panels shall allow air exchange and moisture transport sufficient for continuous wear during a typical clinical shift. */
    attribute minimumAirPermeability : AirPermeability = 150 [L/(m^2*s)];
    attribute minimumMoistureWickingRate : AbsorptionRate = 0.25 [mL/s];
    attribute intendedWearTime : Time = 12 [h];
  }

  requirement def BarrierRequirement {
    doc /* The scrubs set shall reduce direct skin contact with incidental droplets and particles encountered during routine non-sterile clinical work. */
    attribute minimumParticleCaptureEfficiency : Percentage = 70 [%];
    attribute minimumFluidRepellency : Percentage = 80 [%];
  }

  requirement def DurabilityRequirement {
    doc /* The scrubs set shall retain functional seams, closures, pocket integrity, and color through repeated laundering. */
    attribute minimumWashCycles : WashCycleCount = 100;
    attribute minimumSeamStrength : Force = 120 [N];
    attribute minimumColorFastness : Percentage = 90 [%];
  }

  requirement def StorageRequirement {
    doc /* The scrubs set shall provide pockets capable of retaining small clinical and personal items without interfering with normal movement. */
    attribute minimumPocketVolume : Volume = 0.00075 [m^3];
    attribute minimumPocketLoad : Mass = 0.5 [kg];
  }

  requirement def FitRequirement {
    doc /* The waistband and garment geometry shall accommodate size variation while avoiding restriction of normal clinical motion. */
    attribute minimumWaistAdjustRange : Length = 0.12 [m];
    attribute maximumChafeRisk : Percentage = 5 [%];
  }

  satisfy PrimaryFunctionRequirement by ScrubsSet;
  satisfy CoverageRequirement by ScrubsSet;
  satisfy ComfortRequirement by FabricPanel;
  satisfy BarrierRequirement by FabricPanel;
  satisfy DurabilityRequirement by Seam;
  satisfy StorageRequirement by Pocket;
  satisfy FitRequirement by Closure;

  part scrubs : ScrubsSet {
    attribute sizeCode = "M";
    attribute totalMass = 0.62 [kg];
    attribute intendedShiftDuration = 12 [h];
    attribute reusable = true;
    attribute colorFastnessAfterWash = 93 [%];
    attribute nominalServiceLife = 120;

    part top {
      part torsoPanel {
        attribute fabricMass = 0.22 [kg];
        attribute area = 1.15 [m^2];
        attribute surfaceDensity = 170 [g/m^2];
        attribute cottonFraction = 55 [%];
        attribute polyesterFraction = 42 [%];
        attribute elastaneFraction = 3 [%];
        attribute airPermeability = 180 [L/(m^2*s)];
        attribute moistureWickingRate = 0.31 [mL/s];
        attribute particleCaptureEfficiency = 74 [%];
        attribute fluidRepellency = 84 [%];
        attribute maxWashCycles = 120;
      }
      part chestPocket {
        attribute volumeCapacity = 0.0008 [m^3];
        attribute loadLimit = 0.6 [kg];
        attribute hasReinforcedOpening = true;
      }
      part badgeArea {
        attribute visibleArea = 0.006 [m^2];
        attribute acceptsBadgeClip = true;
        attribute acceptsEmbroidery = true;
      }
    }

    part pants {
      part waistband {
        attribute type = "elastic waistband";
        attribute retentionForce = 35 [N];
        attribute adjustableRange = 0.14 [m];
      }
      part drawstring {
        attribute type = "internal drawstring";
        attribute retentionForce = 45 [N];
        attribute adjustableRange = 0.18 [m];
      }
      part cargoPocketLeft {
        attribute volumeCapacity = 0.0012 [m^3];
        attribute loadLimit = 0.75 [kg];
        attribute hasReinforcedOpening = true;
      }
      part cargoPocketRight {
        attribute volumeCapacity = 0.0012 [m^3];
        attribute loadLimit = 0.75 [kg];
        attribute hasReinforcedOpening = true;
      }
    }
  }

}