package MaterialsScienceMicrostructureControlSystem {

  import ScalarValues::*;
  import SI::*;

  attribute def Celsius :> Real;
  attribute def Seconds :> Real;
  attribute def Percent :> Real;
  attribute def Micrometer :> Real;
  attribute def Watts :> Real;
  attribute def LitersPerMinute :> Real;

  item def AluminumAlloyBatch {
    attribute mass_kg : Real;
    attribute alloyDesignation : String;
    attribute initialGrainSize_um : Micrometer;
    attribute soluteMg_percent : Percent;
    attribute soluteSi_percent : Percent;
  }

  item def HeatTreatedAlloyBatch :> AluminumAlloyBatch {
    attribute finalGrainSize_um : Micrometer;
    attribute precipitateRadius_nm : Real;
    attribute hardness_HV : Real;
    attribute yieldStrength_MPa : Real;
    attribute residualStress_MPa : Real;
  }

  item def ThermalEnergy {
    attribute power_W : Watts;
    attribute temperature_C : Celsius;
  }

  item def CoolingMedium {
    attribute flowRate_Lpm : LitersPerMinute;
    attribute inletTemperature_C : Celsius;
  }

  item def MicrostructureMeasurement {
    attribute grainSize_um : Micrometer;
    attribute precipitateRadius_nm : Real;
    attribute hardness_HV : Real;
    attribute phaseFraction_percent : Percent;
  }

  item def ProcessCommand {
    attribute targetAlloyDesignation : String;
    attribute targetGrainSize_um : Micrometer;
    attribute targetHardness_HV : Real;
    attribute targetYieldStrength_MPa : Real;
  }

  item def ProcessReport {
    attribute accepted : Boolean;
    attribute cycleTime_s : Seconds;
    attribute peakTemperature_C : Celsius;
    attribute finalHardness_HV : Real;
    attribute finalYieldStrength_MPa : Real;
  }

  port def MaterialInPort {
    in item batch : AluminumAlloyBatch;
  }

  port def MaterialOutPort {
    out item batch : HeatTreatedAlloyBatch;
  }

  port def CommandPort {
    in item command : ProcessCommand;
  }

  port def ReportPort {
    out item report : ProcessReport;
  }

  port def ThermalPort {
    out item heat : ThermalEnergy;
  }

  port def CoolantPort {
    in item coolantIn : CoolingMedium;
    out item coolantOut : CoolingMedium;
  }

  port def MeasurementPort {
    out item measurement : MicrostructureMeasurement;
  }

  part def FurnaceModule {
    port thermalOutput : ThermalPort;
    attribute chamberTemperature_C : Celsius;
    attribute rampRate_C_per_s : Real;
    attribute uniformity_C : Celsius;
    attribute maxPower_W : Watts;

    action heatSoak {
      in item batchIn : AluminumAlloyBatch;
      out item batchOut : AluminumAlloyBatch;
      in targetTemperature_C : Celsius;
      in soakTime_s : Seconds;
    }
  }

  part def QuenchModule {
    port coolant : CoolantPort;
    attribute quenchSeverity_H : Real;
    attribute bathTemperature_C : Celsius;
    attribute agitationSpeed_rpm : Real;

    action quench {
      in item batchIn : AluminumAlloyBatch;
      out item batchOut : AluminumAlloyBatch;
      in transferDelay_s : Seconds;
    }
  }

  part def AgingModule {
    port thermalOutput : ThermalPort;
    attribute agingTemperature_C : Celsius;
    attribute agingTime_s : Seconds;

    action agePrecipitates {
      in item batchIn : AluminumAlloyBatch;
      out item batchOut : HeatTreatedAlloyBatch;
      in targetPrecipitateRadius_nm : Real;
    }
  }

  part def MicrostructureSensor {
    port measurementOutput : MeasurementPort;
    attribute scanResolution_um : Micrometer;
    attribute hardnessUncertainty_HV : Real;

    action inspect {
      in item specimen : HeatTreatedAlloyBatch;
      out item result : MicrostructureMeasurement;
    }
  }

  part def ProcessController {
    port commandInput : CommandPort;
    port reportOutput : ReportPort;

    attribute solutionTemperatureSetpoint_C : Celsius = 540.0;
    attribute solutionSoakTime_s : Seconds = 3600.0;
    attribute agingTemperatureSetpoint_C : Celsius = 175.0;
    attribute agingTimeSetpoint_s : Seconds = 28800.0;
    attribute maxTransferDelay_s : Seconds = 8.0;

    action computeThermalRecipe {
      in item command : ProcessCommand;
      out solutionTemperature_C : Celsius;
      out solutionTime_s : Seconds;
      out agingTemperature_C : Celsius;
      out agingTime_s : Seconds;
      out targetPrecipitateRadius_nm : Real;
    }
  }

  part def AlloyHeatTreatmentCell {
    port rawMaterialInput : MaterialInPort;
    port finishedMaterialOutput : MaterialOutPort;
    port commandInput : CommandPort;
    port reportOutput : ReportPort;
    port coolantSupply : CoolantPort;

    part furnace : FurnaceModule;
    part quenchTank : QuenchModule;
    part agingOven : AgingModule;
    part sensor : MicrostructureSensor;
    part controller : ProcessController;

    connection commandBus connect commandInput to controller.commandInput;
    connection reportBus connect controller.reportOutput to reportOutput;
    connection coolantLine connect coolantSupply to quenchTank.coolant;

    perform action transformAlloyMicrostructure {
      in item rawBatch : AluminumAlloyBatch;
      in item command : ProcessCommand;
      out item treatedBatch : HeatTreatedAlloyBatch;
      out item report : ProcessReport;

      action recipe : controller.computeThermalRecipe;
      action solutionize : furnace.heatSoak;
      action rapidQuench : quenchTank.quench;
      action artificialAge : agingOven.agePrecipitates;
      action verify : sensor.inspect;

      flow command to recipe.command;
      flow rawBatch to solutionize.batchIn;
      flow recipe.solutionTemperature_C to solutionize.targetTemperature_C;
      flow recipe.solutionTime_s to solutionize.soakTime_s;
      flow solutionize.batchOut to rapidQuench.batchIn;
      flow rapidQuench.batchOut to artificialAge.batchIn;
      flow recipe.targetPrecipitateRadius_nm to artificialAge.targetPrecipitateRadius_nm;
      flow artificialAge.batchOut to verify.specimen;
      flow artificialAge.batchOut to treatedBatch;
    }

    state processState {
      state Idle;
      state Loaded;
      state Solutionizing;
      state Quenching;
      state Aging;
      state Inspecting;
      state Accepted;
      state ReworkRequired;
      state Faulted;

      transition initial then Idle;
      transition Idle then Loaded accept batchReceived;
      transition Loaded then Solutionizing accept recipeValidated;
      transition Solutionizing then Quenching accept solutionSoakComplete;
      transition Quenching then Aging accept quenchComplete;
      transition Aging then Inspecting accept agingComplete;
      transition Inspecting then Accepted accept microstructureWithinTolerance;
      transition Inspecting then ReworkRequired accept hardnessBelowTarget;
      transition ReworkRequired then Aging accept reAgeAuthorized;
      transition Solutionizing then Faulted accept overTemperatureDetected;
      transition Quenching then Faulted accept coolantFlowLost;
      transition Faulted then Idle accept operatorReset;
    }
  }

  constraint def GrainSizeAcceptance {
    in measuredGrainSize_um : Micrometer;
    in targetGrainSize_um : Micrometer;
    in tolerance_um : Micrometer;
    measuredGrainSize_um >= targetGrainSize_um - tolerance_um and
    measuredGrainSize_um <= targetGrainSize_um + tolerance_um
  }

  constraint def HardnessAcceptance {
    in measuredHardness_HV : Real;
    in targetHardness_HV : Real;
    measuredHardness_HV >= targetHardness_HV
  }

  constraint def TransferDelayLimit {
    in transferDelay_s : Seconds;
    in maxTransferDelay_s : Seconds;
    transferDelay_s <= maxTransferDelay_s
  }

  requirement def PrimaryFunctionRequirement {
    subject cell : AlloyHeatTreatmentCell;
    require constraint {
      cell transforms AluminumAlloyBatch into HeatTreatedAlloyBatch by controlled solution heat treatment, rapid quenching, artificial aging, and microstructure verification
    }
  }

  requirement def SolutionTemperatureRequirement {
    subject furnace : FurnaceModule;
    require constraint {
      furnace.chamberTemperature_C >= 520.0 and furnace.chamberTemperature_C <= 560.0
    }
  }

  requirement def FurnaceUniformityRequirement {
    subject furnace : FurnaceModule;
    require constraint {
      furnace.uniformity_C <= 3.0
    }
  }

  requirement def QuenchTransferRequirement {
    subject controller : ProcessController;
    require constraint {
      controller.maxTransferDelay_s <= 8.0
    }
  }

  requirement def MicrostructureRequirement {
    subject batch : HeatTreatedAlloyBatch;
    require constraint {
      batch.finalGrainSize_um <= 45.0 and
      batch.precipitateRadius_nm >= 4.0 and
      batch.precipitateRadius_nm <= 12.0
    }
  }

  requirement def MechanicalPropertyRequirement {
    subject batch : HeatTreatedAlloyBatch;
    require constraint {
      batch.hardness_HV >= 105.0 and
      batch.yieldStrength_MPa >= 275.0 and
      batch.residualStress_MPa <= 80.0
    }
  }

  part alloyMicrostructureCell : AlloyHeatTreatmentCell {
    attribute primaryFunction : String =
      "Convert precipitation-hardenable aluminum alloy batches into verified heat-treated material with target grain size, precipitate distribution, hardness, yield strength, and residual stress.";

    part furnace {
      attribute chamberTemperature_C = 25.0;
      attribute rampRate_C_per_s = 2.5;
      attribute uniformity_C = 2.0;
      attribute maxPower_W = 48000.0;
    }

    part quenchTank {
      attribute quenchSeverity_H = 0.85;
      attribute bathTemperature_C = 22.0;
      attribute agitationSpeed_rpm = 900.0;
    }

    part agingOven {
      attribute agingTemperature_C = 175.0;
      attribute agingTime_s = 28800.0;
    }

    part sensor {
      attribute scanResolution_um = 0.5;
      attribute hardnessUncertainty_HV = 1.5;
    }
  }
}