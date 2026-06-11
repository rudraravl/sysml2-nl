package ShirleyDrainModel {
  import ScalarValues::*;

  attribute def FlowRate_L_per_min :> Real;
  attribute def Volume_L :> Real;
  attribute def Pressure_kPa :> Real;
  attribute def Length_mm :> Real;
  attribute def Mass_kg :> Real;
  attribute def Time_s :> Real;
  attribute def Percent :> Real;

  item def InfluentWater {
    attribute suspendedSolidsPercent : Percent;
    attribute temperatureC : Real;
  }

  item def DrainedWater {
    attribute suspendedSolidsPercent : Percent;
  }

  item def CapturedDebris {
    attribute mass : Mass_kg;
    attribute particleSize_mm : Length_mm;
  }

  port def WetInletPort {
    in item influent : InfluentWater;
  }

  port def DrainOutletPort {
    out item effluent : DrainedWater;
  }

  port def DebrisServicePort {
    out item retainedDebris : CapturedDebris;
  }

  port def VentPort {
    out item displacedAir : Air;
  }

  item def Air;

  part def ShirleyDrain {
    attribute nominalInletDiameter : Length_mm = 100.0;
    attribute nominalOutletDiameter : Length_mm = 50.0;
    attribute sumpCapacity : Volume_L = 6.0;
    attribute designFlowRate : FlowRate_L_per_min = 35.0;
    attribute maximumHeadPressure : Pressure_kPa = 12.0;
    attribute minimumDebrisRetentionEfficiency : Percent = 95.0;

    port inlet : WetInletPort;
    port outlet : DrainOutletPort;
    port cleanout : DebrisServicePort;
    port vent : VentPort;

    part inletStrainer : InletStrainer;
    part taperedBody : TaperedDrainBody;
    part sedimentCup : SedimentCup;
    part waterSealTrap : WaterSealTrap;
    part outletAdapter : OutletAdapter;
    part overflowRelief : OverflowRelief;
    part inspectionCover : InspectionCover;
    part levelSensor : LevelSensor;
    part blockageIndicator : BlockageIndicator;

    connection inletToStrainer connect inlet to inletStrainer.wetEntry;
    connection strainerToBody connect inletStrainer.filteredExit to taperedBody.upperChamber;
    connection bodyToCup connect taperedBody.sedimentDrop to sedimentCup.captureEntry;
    connection bodyToTrap connect taperedBody.lowerChamber to waterSealTrap.trapEntry;
    connection trapToOutlet connect waterSealTrap.trapExit to outletAdapter.pipeExit;
    connection outletToSystem connect outletAdapter.pipeExit to outlet;
    connection bodyToVent connect taperedBody.airRelief to vent;
    connection bodyToOverflow connect taperedBody.highLevelBypass to overflowRelief.bypassEntry;
    connection overflowToOutlet connect overflowRelief.bypassExit to outletAdapter.pipeEntry;
    connection cupToCleanout connect sedimentCup.serviceExit to cleanout;

    action drainInfluent {
      in item incoming : InfluentWater;
      out item outgoing : DrainedWater;
      out item debris : CapturedDebris;

      first start;
      then receiveWater;
      then separateDebris;
      then settleHeavySolids;
      then maintainWaterSeal;
      then dischargeEffluent;
      then done;

      action receiveWater {
        in item incoming : InfluentWater;
      }

      action separateDebris {
        in item incoming : InfluentWater;
        out item screenedWater : InfluentWater;
        out item coarseDebris : CapturedDebris;
      }

      action settleHeavySolids {
        in item screenedWater : InfluentWater;
        out item clarifiedWater : DrainedWater;
        out item settledDebris : CapturedDebris;
      }

      action maintainWaterSeal {
        in item clarifiedWater : DrainedWater;
      }

      action dischargeEffluent {
        in item clarifiedWater : DrainedWater;
        out item outgoing : DrainedWater;
      }
    }

    state def OperatingState {
      state idle;
      state receivingFlow;
      state draining;
      state highLevelRelief;
      state blocked;
      state serviceRequired;

      initial then idle;

      transition idle_to_receiving
        first idle
        accept FlowDetected
        then receivingFlow;

      transition receiving_to_draining
        first receivingFlow
        accept StableFlow
        then draining;

      transition draining_to_idle
        first draining
        accept FlowStopped
        then idle;

      transition draining_to_relief
        first draining
        accept WaterLevelHigh
        then highLevelRelief;

      transition relief_to_draining
        first highLevelRelief
        accept WaterLevelNormal
        then draining;

      transition draining_to_blocked
        first draining
        accept OutletBackPressureHigh
        then blocked;

      transition blocked_to_service
        first blocked
        accept ManualIsolationComplete
        then serviceRequired;

      transition service_to_idle
        first serviceRequired
        accept CleanoutCompleted
        then idle;
    }
  }

  part def InletStrainer {
    attribute openAreaPercent : Percent = 62.0;
    attribute apertureWidth : Length_mm = 4.0;
    attribute retentionEfficiency : Percent = 97.0;

    port wetEntry : WetInletPort;
    port filteredExit : WetInletPort;
  }

  part def TaperedDrainBody {
    attribute chamberVolume : Volume_L = 4.0;
    attribute wallThickness : Length_mm = 3.0;
    attribute internalSlopePercent : Percent = 8.0;

    port upperChamber : WetInletPort;
    port lowerChamber : DrainOutletPort;
    port sedimentDrop : DebrisServicePort;
    port airRelief : VentPort;
    port highLevelBypass : DrainOutletPort;
  }

  part def SedimentCup {
    attribute debrisCapacity : Volume_L = 1.5;
    attribute maximumServiceMass : Mass_kg = 3.0;

    port captureEntry : DebrisServicePort;
    port serviceExit : DebrisServicePort;
  }

  part def WaterSealTrap {
    attribute sealDepth : Length_mm = 50.0;
    attribute retainedWaterVolume : Volume_L = 0.8;

    port trapEntry : DrainOutletPort;
    port trapExit : DrainOutletPort;
  }

  part def OutletAdapter {
    attribute pipeDiameter : Length_mm = 50.0;

    port pipeEntry : DrainOutletPort;
    port pipeExit : DrainOutletPort;
  }

  part def OverflowRelief {
    attribute activationLevel : Volume_L = 5.2;
    attribute bypassFlowRate : FlowRate_L_per_min = 45.0;

    port bypassEntry : DrainOutletPort;
    port bypassExit : DrainOutletPort;
  }

  part def InspectionCover {
    attribute clearOpeningDiameter : Length_mm = 120.0;
    attribute gasketCompressionPercent : Percent = 20.0;
  }

  part def LevelSensor {
    attribute lowLevelThreshold : Volume_L = 0.5;
    attribute highLevelThreshold : Volume_L = 5.0;
    attribute samplePeriod : Time_s = 1.0;
  }

  part def BlockageIndicator {
    attribute backPressureAlarmThreshold : Pressure_kPa = 8.0;
    attribute alarmDelay : Time_s = 5.0;
  }

  requirement def PrimaryFunctionRequirement {
    subject drain : ShirleyDrain;

    doc /* The Shirley drain shall receive wet inflow, separate retained debris and sediment, preserve a water seal, and discharge clarified drain water to the connected outlet. */

    require constraint {
      drain.designFlowRate >= 30.0
    }
  }

  requirement def DebrisRetentionRequirement {
    subject drain : ShirleyDrain;

    require constraint {
      drain.minimumDebrisRetentionEfficiency >= 95.0
    }
  }

  requirement def SealRequirement {
    subject drain : ShirleyDrain;

    require constraint {
      drain.waterSealTrap.sealDepth >= 50.0
    }
  }

  requirement def OverflowProtectionRequirement {
    subject drain : ShirleyDrain;

    require constraint {
      drain.overflowRelief.bypassFlowRate >= drain.designFlowRate
    }
  }

  requirement def ServiceabilityRequirement {
    subject drain : ShirleyDrain;

    require constraint {
      drain.sedimentCup.maximumServiceMass <= 3.0
    }
  }

  part shirleyDrainSystem : ShirleyDrain {
    attribute designFlowRate = 35.0;
    attribute sumpCapacity = 6.0;
  }
}