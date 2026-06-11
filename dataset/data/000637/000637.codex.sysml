package IcePackSystemModel {

  import ScalarValues::*;
  import ISQ::*;

  private attribute def TemperatureCelsius :> Real {
    unit = "degC";
  }

  private attribute def HeatEnergyJoule :> Real {
    unit = "J";
  }

  private attribute def MassKilogram :> Real {
    unit = "kg";
  }

  private attribute def TimeMinute :> Real {
    unit = "min";
  }

  private attribute def AreaSquareMeter :> Real {
    unit = "m^2";
  }

  private attribute def HeatTransferRateWatt :> Real {
    unit = "W";
  }

  private attribute def PressurePascal :> Real {
    unit = "Pa";
  }

  item def ThermalEnergy {
    attribute quantity : HeatEnergyJoule;
    attribute sourceTemperature : TemperatureCelsius;
    attribute sinkTemperature : TemperatureCelsius;
  }

  item def CoolingRequest {
    attribute targetTemperature : TemperatureCelsius;
    attribute requiredDuration : TimeMinute;
    attribute maximumSkinContactTemperature : TemperatureCelsius;
  }

  item def UserHandlingForce {
    attribute contactPressure : PressurePascal;
  }

  item def MeltWater {
    attribute mass : MassKilogram;
    attribute temperature : TemperatureCelsius;
  }

  port def ThermalContactPort {
    in item absorbedHeat : ThermalEnergy;
    out item conductedCooling : ThermalEnergy;
  }

  port def UserInterfacePort {
    in item request : CoolingRequest;
    in item handlingForce : UserHandlingForce;
  }

  port def ContainmentPort {
    out item leakage : MeltWater;
  }

  part def IcePack {
    attribute packMass : MassKilogram = 0.55;
    attribute externalSurfaceArea : AreaSquareMeter = 0.045;
    attribute initialCoreTemperature : TemperatureCelsius = -12.0;
    attribute safeContactTemperatureLimit : TemperatureCelsius = 0.0;
    attribute nominalCoolingDuration : TimeMinute = 45.0;
    attribute peakHeatAbsorptionRate : HeatTransferRateWatt = 18.0;

    port userPort : UserInterfacePort;
    port therapySurface : ThermalContactPort;
    port environmentSurface : ThermalContactPort;
    port containmentMonitor : ContainmentPort;

    part outerFilm : PolymerEnvelope {
      attribute thickness = 0.00018;
      attribute puncturePressureLimit = 180000.0;
    }

    part gelCore : PhaseChangeGel {
      attribute mass = 0.50;
      attribute freezingPoint = -4.0;
      attribute latentHeatCapacity = 165000.0;
      attribute currentTemperature = -12.0;
      attribute frozenFraction = 1.0;
    }

    part seam : HeatSealedBoundary {
      attribute sealWidth = 0.008;
      attribute burstPressureLimit = 160000.0;
    }

    part fabricSleeve : ProtectiveSleeve {
      attribute insulationFactor = 0.35;
      attribute washable = true;
    }

    part cooledObject : TreatmentSite {
      attribute initialTemperature = 32.0;
      attribute minimumAllowedTemperature = 5.0;
      attribute desiredTemperatureReduction = 10.0;
    }

    connect therapySurface to fabricSleeve.innerThermalPort;
    connect fabricSleeve.outerThermalPort to cooledObject.contactPort;
    connect gelCore.thermalPort to therapySurface;
    connect gelCore.environmentPort to environmentSurface;
    connect outerFilm.containmentPort to containmentMonitor;
    connect seam.containmentPort to containmentMonitor;

    action def AbsorbHeat {
      in item incomingHeat : ThermalEnergy;
      out item storedHeat : ThermalEnergy;
      attribute heatAbsorptionRate : HeatTransferRateWatt;

      first start;
      then conductThroughSleeve;
      then conductThroughEnvelope;
      then storeInGelCore;
      then updateCoreTemperature;
      then done;

      flow incomingHeat to storedHeat;
    }

    action def ProvideColdTherapy {
      in item coolingRequest : CoolingRequest;
      out item coolingDelivered : ThermalEnergy;

      first receiveRequest;
      then verifySafeSurfaceTemperature;
      then placePackOnTreatmentSite;
      then absorbThermalEnergy : AbsorbHeat;
      then maintainCoolingUntilDurationOrThaw;
      then removePack;
      then completeTherapy;

      flow coolingRequest to receiveRequest;
      flow absorbThermalEnergy.storedHeat to coolingDelivered;
    }

    state def OperatingState {
      entry action initializeTemperatureEstimate;

      state StoredFrozen {
        entry action keepBelowFreezing;
      }

      state ReadyForUse {
        entry action confirmFlexibleButCold;
      }

      state CoolingActive {
        entry action absorbHeatFromTreatmentSite;
        do action regulateContactThroughSleeve;
        exit action reportRemainingCoolingCapacity;
      }

      state PartiallyThawed {
        entry action reduceExpectedCoolingRate;
      }

      state FullyThawed {
        entry action stopTherapeuticCooling;
      }

      state Damaged {
        entry action isolateLeakingPack;
      }

      transition first StoredFrozen;
      transition StoredFrozen to ReadyForUse
        accept CoolingRequest
        if gelCore.currentTemperature <= safeContactTemperatureLimit;

      transition ReadyForUse to CoolingActive
        accept UserHandlingForce
        if outerFilm.integrityOk and seam.integrityOk;

      transition CoolingActive to PartiallyThawed
        if gelCore.frozenFraction < 0.50;

      transition PartiallyThawed to FullyThawed
        if gelCore.frozenFraction <= 0.02;

      transition CoolingActive to Damaged
        if not outerFilm.integrityOk or not seam.integrityOk;

      transition PartiallyThawed to Damaged
        if not outerFilm.integrityOk or not seam.integrityOk;
    }
  }

  part def PhaseChangeGel {
    attribute mass : MassKilogram;
    attribute freezingPoint : TemperatureCelsius;
    attribute latentHeatCapacity : HeatEnergyJoule;
    attribute currentTemperature : TemperatureCelsius;
    attribute frozenFraction : Real;

    port thermalPort : ThermalContactPort;
    port environmentPort : ThermalContactPort;
  }

  part def PolymerEnvelope {
    attribute thickness : Real;
    attribute puncturePressureLimit : PressurePascal;
    attribute integrityOk : Boolean = true;

    port containmentPort : ContainmentPort;
  }

  part def HeatSealedBoundary {
    attribute sealWidth : Real;
    attribute burstPressureLimit : PressurePascal;
    attribute integrityOk : Boolean = true;

    port containmentPort : ContainmentPort;
  }

  part def ProtectiveSleeve {
    attribute insulationFactor : Real;
    attribute washable : Boolean;

    port innerThermalPort : ThermalContactPort;
    port outerThermalPort : ThermalContactPort;

    connect innerThermalPort to outerThermalPort;
  }

  part def TreatmentSite {
    attribute initialTemperature : TemperatureCelsius;
    attribute minimumAllowedTemperature : TemperatureCelsius;
    attribute desiredTemperatureReduction : TemperatureCelsius;

    port contactPort : ThermalContactPort;
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The ice pack shall provide portable, passive cooling by absorbing heat from a treatment site or object through a contained phase-change gel core. */
  }

  requirement def CoolingDurationRequirement {
    attribute minimumCoolingDuration : TimeMinute = 30.0;
    doc /* The ice pack shall maintain useful cooling for at least the minimum cooling duration under normal room-temperature use. */
  }

  requirement def ContainmentRequirement {
    attribute maximumAllowedLeakageMass : MassKilogram = 0.0;
    doc /* The ice pack shall contain gel and meltwater during normal handling, compression, and thawing. */
  }

  requirement def SkinSafetyRequirement {
    attribute minimumSafeSkinTemperature : TemperatureCelsius = 0.0;
    doc /* The ice pack shall use its sleeve and envelope to reduce the risk of unsafe direct skin cooling during intended use. */
  }

  requirement def ReusabilityRequirement {
    attribute minimumFreezeThawCycles : Integer = 100;
    doc /* The ice pack shall support repeated freeze-thaw cycles without loss of containment or primary cooling function. */
  }

  part icePackSystem : IcePack;

  satisfy PrimaryFunctionRequirement by icePackSystem;
  satisfy CoolingDurationRequirement by icePackSystem.gelCore;
  satisfy ContainmentRequirement by icePackSystem.outerFilm;
  satisfy ContainmentRequirement by icePackSystem.seam;
  satisfy SkinSafetyRequirement by icePackSystem.fabricSleeve;
  satisfy ReusabilityRequirement by icePackSystem;

  requirement usage primaryFunction : PrimaryFunctionRequirement;
  requirement usage coolingDuration : CoolingDurationRequirement;
  requirement usage containment : ContainmentRequirement;
  requirement usage skinSafety : SkinSafetyRequirement;
  requirement usage reusability : ReusabilityRequirement;
}