package BakriBalloonTamponadeSystem {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Volume_ml :> Real {
    unit = "mL";
  }

  attribute def Pressure_kPa :> Real {
    unit = "kPa";
  }

  attribute def FlowRate_ml_per_min :> Real {
    unit = "mL/min";
  }

  attribute def Force_N :> Real {
    unit = "N";
  }

  attribute def Time_min :> Real {
    unit = "min";
  }

  attribute def Length_mm :> Real {
    unit = "mm";
  }

  attribute def Temperature_C :> Real {
    unit = "degC";
  }

  attribute def BooleanStatus :> Boolean;

  item def SterileFluid {
    attribute volume : Volume_ml;
    attribute temperature : Temperature_C;
  }

  item def Blood {
    attribute flowRate : FlowRate_ml_per_min;
    attribute cumulativeLoss : Volume_ml;
  }

  item def UterineCavityContact {
    attribute contactPressure : Pressure_kPa;
    attribute contactArea : Real;
    attribute tamponadeEffective : BooleanStatus;
  }

  item def DrainageFluid {
    attribute bloodVolume : Volume_ml;
    attribute clotDetected : BooleanStatus;
  }

  item def InflationCommand {
    attribute targetVolume : Volume_ml;
    attribute maximumPressure : Pressure_kPa;
  }

  item def DeflationCommand {
    attribute withdrawVolume : Volume_ml;
  }

  port def FluidTransferPort {
    in item fluidIn : SterileFluid;
    out item fluidOut : SterileFluid;
  }

  port def DrainagePort {
    in item uterineBlood : Blood;
    out item drainage : DrainageFluid;
  }

  port def ContactPort {
    out item uterineContact : UterineCavityContact;
  }

  port def ControlPort {
    in item inflationRequest : InflationCommand;
    in item deflationRequest : DeflationCommand;
  }

  part def BakriBalloonSystem {
    doc /* Primary function: provide temporary intrauterine tamponade by expanding a sterile balloon within the uterine cavity so that controlled pressure is applied to the uterine wall, reducing postpartum hemorrhage while allowing blood drainage and clinical monitoring. */

    attribute maximumFillVolume : Volume_ml = 500.0;
    attribute nominalFillVolume : Volume_ml = 300.0;
    attribute minimumEffectiveFillVolume : Volume_ml = 100.0;
    attribute maximumSafePressure : Pressure_kPa = 13.3;
    attribute recommendedUseDuration : Time_min = 1440.0;
    attribute currentFillVolume : Volume_ml;
    attribute currentBalloonPressure : Pressure_kPa;
    attribute estimatedBloodLoss : Volume_ml;
    attribute activeTamponade : BooleanStatus;
    attribute sterilityMaintained : BooleanStatus;

    port controlPort : ControlPort;
    port inflationPort : FluidTransferPort;
    port drainagePort : DrainagePort;
    port uterineContactPort : ContactPort;

    part balloon : InflatableTamponadeBalloon;
    part catheter : DualLumenCatheter;
    part fillValve : OneWayInflationValve;
    part drainageChannel : UterineDrainageChannel;
    part pressureMonitor : BalloonPressureMonitor;
    part graduatedCollectionBag : DrainageCollectionBag;
    part insertionLimiter : CervicalPositionMarker;
    part clinicianInterface : ClinicalUseInterface;

    connect inflationPort to fillValve.externalFillPort;
    connect fillValve.balloonFillPort to catheter.inflationLumenPort;
    connect catheter.balloonFillExitPort to balloon.fillPort;
    connect balloon.contactPort to uterineContactPort;
    connect catheter.drainageInletPort to drainageChannel.inletPort;
    connect drainageChannel.outletPort to graduatedCollectionBag.collectionPort;
    connect graduatedCollectionBag.statusPort to clinicianInterface.drainageStatusPort;
    connect pressureMonitor.sensingPort to balloon.pressurePort;
    connect pressureMonitor.displayPort to clinicianInterface.pressureStatusPort;
    connect controlPort to clinicianInterface.controlPort;

    perform action DeployAndControlTamponade;
    exhibit state TamponadeLifecycle;
  }

  part def InflatableTamponadeBalloon {
    attribute materialElasticity : Real = 0.82;
    attribute fillVolume : Volume_ml;
    attribute internalPressure : Pressure_kPa;
    attribute expandedDiameter : Length_mm;
    attribute burstPressure : Pressure_kPa = 26.6;
    attribute leakDetected : BooleanStatus = false;
    attribute surfaceSterile : BooleanStatus = true;

    port fillPort : FluidTransferPort;
    port pressurePort : FluidTransferPort;
    port contactPort : ContactPort;

    action expand {
      in item incomingFluid : SterileFluid;
      out item uterineContact : UterineCavityContact;
      attribute resultingPressure : Pressure_kPa;
      attribute resultingVolume : Volume_ml;
    }

    action maintainTamponade {
      in item uterineBleeding : Blood;
      out item reducedBleeding : Blood;
      out item contactState : UterineCavityContact;
    }

    action deflate {
      in item command : DeflationCommand;
      out item removedFluid : SterileFluid;
    }
  }

  part def DualLumenCatheter {
    attribute outerDiameter : Length_mm = 8.0;
    attribute insertionLength : Length_mm = 540.0;
    attribute kinkResistant : BooleanStatus = true;
    attribute radiopaqueMarkerPresent : BooleanStatus = true;

    port inflationLumenPort : FluidTransferPort;
    port balloonFillExitPort : FluidTransferPort;
    port drainageInletPort : DrainagePort;

    part inflationLumen : InflationLumen;
    part drainageLumen : DrainageLumen;

    connect inflationLumenPort to inflationLumen.inletPort;
    connect inflationLumen.outletPort to balloonFillExitPort;
    connect drainageInletPort to drainageLumen.inletPort;
  }

  part def InflationLumen {
    attribute internalDiameter : Length_mm = 2.0;
    attribute maximumFlowRate : FlowRate_ml_per_min = 120.0;
    port inletPort : FluidTransferPort;
    port outletPort : FluidTransferPort;
  }

  part def DrainageLumen {
    attribute internalDiameter : Length_mm = 4.5;
    attribute minimumDrainageFlowRate : FlowRate_ml_per_min = 20.0;
    attribute occlusionDetected : BooleanStatus;
    port inletPort : DrainagePort;
  }

  part def OneWayInflationValve {
    attribute reverseLeakRate : FlowRate_ml_per_min = 0.0;
    attribute valveLocked : BooleanStatus = true;
    port externalFillPort : FluidTransferPort;
    port balloonFillPort : FluidTransferPort;

    action admitFluid {
      in item fluid : SterileFluid;
      out item deliveredFluid : SterileFluid;
    }

    action preventBackflow {
      out item retainedFluid : SterileFluid;
    }
  }

  part def UterineDrainageChannel {
    attribute patencyMaintained : BooleanStatus;
    attribute clotWarning : BooleanStatus;
    port inletPort : DrainagePort;
    port outletPort : DrainagePort;

    action drainBlood {
      in item bloodFromUterus : Blood;
      out item collectedDrainage : DrainageFluid;
    }
  }

  part def BalloonPressureMonitor {
    attribute measuredPressure : Pressure_kPa;
    attribute highPressureAlarmThreshold : Pressure_kPa = 13.3;
    attribute lowPressureAlarmThreshold : Pressure_kPa = 2.0;
    attribute alarmActive : BooleanStatus;

    port sensingPort : FluidTransferPort;
    port displayPort : ControlPort;

    action measurePressure {
      out attribute pressure : Pressure_kPa;
    }

    action evaluatePressure {
      in attribute pressure : Pressure_kPa;
      out attribute alarm : BooleanStatus;
    }
  }

  part def DrainageCollectionBag {
    attribute capacity : Volume_ml = 1000.0;
    attribute collectedVolume : Volume_ml;
    attribute hourlyDrainageRate : FlowRate_ml_per_min;
    attribute overfillAlarm : BooleanStatus;

    port collectionPort : DrainagePort;
    port statusPort : ControlPort;

    action collectDrainage {
      in item drainage : DrainageFluid;
      out attribute totalVolume : Volume_ml;
    }
  }

  part def CervicalPositionMarker {
    attribute markerDistanceFromBalloon : Length_mm = 150.0;
    attribute visibleAtCervix : BooleanStatus;
  }

  part def ClinicalUseInterface {
    attribute fillVolumeDisplayed : Volume_ml;
    attribute pressureDisplayed : Pressure_kPa;
    attribute drainageDisplayed : Volume_ml;
    attribute alertDisplayed : BooleanStatus;

    port controlPort : ControlPort;
    port pressureStatusPort : ControlPort;
    port drainageStatusPort : ControlPort;

    action requestInflation {
      out item command : InflationCommand;
    }

    action requestDeflation {
      out item command : DeflationCommand;
    }

    action displayStatus {
      in attribute pressure : Pressure_kPa;
      in attribute drainedVolume : Volume_ml;
      out attribute alert : BooleanStatus;
    }
  }

  action def DeployAndControlTamponade {
    in item sterileSaline : SterileFluid;
    in item uterineBleeding : Blood;
    out item controlledBleeding : Blood;
    out item drainageOutput : DrainageFluid;

    first start;
    then verifySterility;
    then positionBalloon;
    then inflateIncrementally;
    then evaluateTamponade;
    then monitorDrainageAndPressure;
    then controlledRemoval;
    then done;

    action verifySterility {
      out attribute sterilityAccepted : BooleanStatus;
    }

    action positionBalloon {
      out attribute positionedInUterineCavity : BooleanStatus;
    }

    action inflateIncrementally {
      in item fillFluid : SterileFluid;
      out attribute fillVolume : Volume_ml;
      out attribute pressure : Pressure_kPa;
    }

    action evaluateTamponade {
      in item bleedingBeforeTamponade : Blood;
      out item bleedingAfterTamponade : Blood;
      out attribute tamponadeEffective : BooleanStatus;
    }

    action monitorDrainageAndPressure {
      out item drainage : DrainageFluid;
      out attribute alarmRequired : BooleanStatus;
    }

    action controlledRemoval {
      out item removedFluid : SterileFluid;
      out attribute deviceRemovedIntact : BooleanStatus;
    }
  }

  state def TamponadeLifecycle {
    entry action initializeDevice;

    state PackagedSterile;
    state Inserted;
    state Inflating;
    state TamponadeActive;
    state Monitoring;
    state Deflating;
    state Removed;
    state AlarmCondition;

    transition first PackagedSterile;
    transition PackagedSterile_to_Inserted
      first PackagedSterile
      then Inserted
      accept insertedWhenSterile;
    transition Inserted_to_Inflating
      first Inserted
      then Inflating
      accept inflationStarted;
    transition Inflating_to_TamponadeActive
      first Inflating
      then TamponadeActive
      accept effectivePressureReached;
    transition TamponadeActive_to_Monitoring
      first TamponadeActive
      then Monitoring
      accept stableBleedingReduction;
    transition Monitoring_to_AlarmCondition
      first Monitoring
      then AlarmCondition
      accept pressureHighOrDrainageExcessive;
    transition AlarmCondition_to_Monitoring
      first AlarmCondition
      then Monitoring
      accept clinicalCorrectionCompleted;
    transition Monitoring_to_Deflating
      first Monitoring
      then Deflating
      accept removalCriteriaMet;
    transition Deflating_to_Removed
      first Deflating
      then Removed
      accept balloonFullyDeflatedAndExtracted;
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The system shall temporarily reduce uterine hemorrhage by applying controlled intrauterine balloon pressure while permitting drainage-based assessment of ongoing bleeding. */
    subject system : BakriBalloonSystem;
  }

  requirement def FillVolumeLimitRequirement {
    doc /* The system shall prevent intended filling above 500 mL. */
    subject system : BakriBalloonSystem;
    attribute requiredMaximumVolume : Volume_ml = 500.0;
    require constraint { system.currentFillVolume <= requiredMaximumVolume }
  }

  requirement def PressureSafetyRequirement {
    doc /* The system shall support monitoring so balloon pressure remains at or below the defined safe operating threshold. */
    subject system : BakriBalloonSystem;
    attribute safePressureLimit : Pressure_kPa = 13.3;
    require constraint { system.currentBalloonPressure <= safePressureLimit }
  }

  requirement def DrainageMonitoringRequirement {
    doc /* The system shall provide a drainage path from the uterine cavity to a measurable collection container. */
    subject system : BakriBalloonSystem;
    require constraint { system.graduatedCollectionBag.capacity >= 1000.0 }
  }

  requirement def SterilityRequirement {
    doc /* Patient-contacting components shall remain sterile before clinical deployment. */
    subject system : BakriBalloonSystem;
    require constraint { system.sterilityMaintained == true }
  }

  requirement def TamponadeEffectivenessRequirement {
    doc /* When active, the system shall reduce observed uterine bleeding relative to pre-tamponade flow. */
    subject system : BakriBalloonSystem;
    attribute maximumControlledBleedingRate : FlowRate_ml_per_min = 10.0;
    require constraint { system.activeTamponade == true implies system.graduatedCollectionBag.hourlyDrainageRate <= maximumControlledBleedingRate }
  }

  requirement def RemovalRequirement {
    doc /* The system shall allow controlled deflation before removal to minimize abrupt loss of uterine compression. */
    subject system : BakriBalloonSystem;
    require constraint { system.currentFillVolume == 0.0 implies system.activeTamponade == false }
  }

  satisfy PrimaryFunctionRequirement by BakriBalloonSystem;
  satisfy FillVolumeLimitRequirement by OneWayInflationValve;
  satisfy PressureSafetyRequirement by BalloonPressureMonitor;
  satisfy DrainageMonitoringRequirement by UterineDrainageChannel;
  satisfy SterilityRequirement by InflatableTamponadeBalloon;
  satisfy TamponadeEffectivenessRequirement by InflatableTamponadeBalloon;
  satisfy RemovalRequirement by InflatableTamponadeBalloon;
}