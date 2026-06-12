package LabOnChipSystemModel {

  import ScalarValues::*;
  import SI::*;

  item def WholeBloodSample {
    attribute sampleId : String;
    attribute volume : Volume;
    attribute hematocrit : Real;
    attribute collectionTime : Time;
  }

  item def PlasmaFraction {
    attribute volume : Volume;
    attribute purity : Real;
  }

  item def Reagent {
    attribute reagentId : String;
    attribute concentration : Concentration;
    attribute volume : Volume;
    attribute expirationTime : Time;
  }

  item def WasteFluid {
    attribute volume : Volume;
    attribute biohazardLevel : Integer;
  }

  item def AssayResult {
    attribute targetName : String;
    attribute measuredConcentration : Concentration;
    attribute confidence : Real;
    attribute timestamp : Time;
  }

  item def ControlCommand {
    attribute commandId : String;
    attribute targetSubsystem : String;
    attribute setPoint : Real;
  }

  item def DiagnosticStatus {
    attribute subsystem : String;
    attribute healthState : String;
    attribute errorCode : Integer;
  }

  value def Volume :> ISQBase::volume {
    unit = "uL";
  }

  value def FlowRate {
    unit = "uL/min";
    quantityKind = "volume flow rate";
  }

  value def Pressure {
    unit = "kPa";
    quantityKind = "pressure";
  }

  value def Temperature {
    unit = "degC";
    quantityKind = "temperature";
  }

  value def Voltage {
    unit = "V";
    quantityKind = "electric potential";
  }

  value def OpticalIntensity {
    unit = "a.u.";
    quantityKind = "relative optical intensity";
  }

  value def Concentration {
    unit = "ng/mL";
    quantityKind = "mass concentration";
  }

  value def Time {
    unit = "s";
    quantityKind = "time";
  }

  port def FluidInletPort {
    in item sample : WholeBloodSample;
  }

  port def ReagentInletPort {
    in item reagent : Reagent;
  }

  port def FluidOutletPort {
    out item fluid;
  }

  port def WasteOutletPort {
    out item waste : WasteFluid;
  }

  port def DetectionPort {
    in item processedFluid;
    out item result : AssayResult;
  }

  port def CommandPort {
    in item command : ControlCommand;
  }

  port def StatusPort {
    out item status : DiagnosticStatus;
  }

  port def ElectricalPowerPort {
    in attribute supplyVoltage : Voltage;
    in attribute maximumCurrent : Real;
  }

  port def ThermalControlPort {
    in attribute temperatureSetPoint : Temperature;
    out attribute measuredTemperature : Temperature;
  }

  part def MicroPump {
    port commandPort : CommandPort;
    port statusPort : StatusPort;
    port powerPort : ElectricalPowerPort;
    port inlet : FluidInletPort;
    port outlet : FluidOutletPort;

    attribute commandedFlowRate : FlowRate;
    attribute measuredFlowRate : FlowRate;
    attribute maximumPressure : Pressure;
    attribute strokeVolume : Volume;

    action def RegulateFlow {
      in targetFlowRate : FlowRate;
      out actualFlowRate : FlowRate;
      first start;
      then setDriveVoltage;
      then measureFlow;
      then adjustDutyCycle;
      then done;
    }

    state def PumpOperatingState {
      entry action initializePump;
      state Off;
      state Priming;
      state Regulating;
      state Faulted;

      transition Off_to_Priming
        first Off
        accept ControlCommand
        if command.commandId == "prime"
        then Priming;

      transition Priming_to_Regulating
        first Priming
        if measuredFlowRate > 0.0 [uL/min]
        then Regulating;

      transition Regulating_to_Faulted
        first Regulating
        if maximumPressure > 120.0 [kPa]
        then Faulted;

      transition Faulted_to_Off
        first Faulted
        accept ControlCommand
        if command.commandId == "reset"
        then Off;
    }
  }

  part def MicroValve {
    port commandPort : CommandPort;
    port statusPort : StatusPort;
    port inlet : FluidInletPort;
    port outlet : FluidOutletPort;
    port wasteOutlet : WasteOutletPort;

    attribute openFraction : Real;
    attribute switchingTime : Time;
    attribute leakageRate : FlowRate;

    state def ValveState {
      state Closed;
      state RouteToAssay;
      state RouteToWaste;
      state Faulted;

      transition Closed_to_RouteToAssay
        first Closed
        accept ControlCommand
        if command.commandId == "route_assay"
        then RouteToAssay;

      transition Closed_to_RouteToWaste
        first Closed
        accept ControlCommand
        if command.commandId == "route_waste"
        then RouteToWaste;

      transition Any_to_Faulted
        first Closed
        if leakageRate > 0.05 [uL/min]
        then Faulted;
    }
  }

  part def PlasmaSeparator {
    port sampleIn : FluidInletPort;
    port plasmaOut : FluidOutletPort;
    port wasteOut : WasteOutletPort;

    attribute channelWidth : Real;
    attribute membranePoreSize : Real;
    attribute separationEfficiency : Real;
    attribute nominalInputFlowRate : FlowRate;

    action def SeparatePlasma {
      in wholeBlood : WholeBloodSample;
      out plasma : PlasmaFraction;
      out cellularWaste : WasteFluid;
      first receiveSample;
      then hydrodynamicFocus;
      then filterCells;
      then collectPlasma;
      then dischargeCellularWaste;
    }
  }

  part def ReagentReservoir {
    port reagentOut : ReagentInletPort;
    port statusPort : StatusPort;

    attribute storedVolume : Volume;
    attribute reagentTemperature : Temperature;
    attribute remainingAssayCount : Integer;
  }

  part def Mixer {
    port sampleIn : FluidInletPort;
    port reagentIn : ReagentInletPort;
    port mixedOut : FluidOutletPort;

    attribute mixingChannelLength : Real;
    attribute mixingTime : Time;
    attribute mixingCompleteness : Real;

    action def MixSampleAndReagent {
      in plasma : PlasmaFraction;
      in reagent : Reagent;
      out reactionMixture;
      first meterPlasma;
      then meterReagent;
      then combineStreams;
      then diffuseAcrossSerpentineChannel;
      then verifyMixingCompleteness;
    }
  }

  part def ReactionChamber {
    port mixtureIn : FluidInletPort;
    port reactedOut : FluidOutletPort;
    port thermalPort : ThermalControlPort;

    attribute chamberVolume : Volume;
    attribute incubationTemperature : Temperature;
    attribute incubationDuration : Time;
    attribute surfaceCaptureEfficiency : Real;

    state def ReactionState {
      state Empty;
      state Filling;
      state Incubating;
      state Washing;
      state ReadyForDetection;

      transition Empty_to_Filling
        first Empty
        accept ControlCommand
        if command.commandId == "load_reaction"
        then Filling;

      transition Filling_to_Incubating
        first Filling
        if chamberVolume >= 8.0 [uL]
        then Incubating;

      transition Incubating_to_Washing
        first Incubating
        after 300.0 [s]
        then Washing;

      transition Washing_to_ReadyForDetection
        first Washing
        after 45.0 [s]
        then ReadyForDetection;
    }

    action def IncubateAssay {
      in reactionMixture;
      out boundAnalyteMixture;
      first fillChamber;
      then stabilizeTemperature;
      then bindAnalyteToCaptureSurface;
      then washUnboundMaterial;
      then releaseForDetection;
    }
  }

  part def OpticalDetector {
    port detectionPort : DetectionPort;
    port commandPort : CommandPort;
    port statusPort : StatusPort;
    port powerPort : ElectricalPowerPort;

    attribute excitationWavelength : Real;
    attribute emissionWavelength : Real;
    attribute darkCurrent : Real;
    attribute signalIntensity : OpticalIntensity;
    attribute limitOfDetection : Concentration;

    action def MeasureFluorescence {
      in assayFluid;
      out result : AssayResult;
      first illuminateReactionZone;
      then acquireDarkFrame;
      then acquireEmissionFrame;
      then subtractBackground;
      then convertIntensityToConcentration;
      then reportResult;
    }

    state def DetectorState {
      state Standby;
      state Calibrating;
      state Measuring;
      state Reporting;
      state Faulted;

      transition Standby_to_Calibrating
        first Standby
        accept ControlCommand
        if command.commandId == "calibrate_detector"
        then Calibrating;

      transition Calibrating_to_Measuring
        first Calibrating
        if darkCurrent < 0.02
        then Measuring;

      transition Measuring_to_Reporting
        first Measuring
        after 5.0 [s]
        then Reporting;

      transition Measuring_to_Faulted
        first Measuring
        if signalIntensity < 0.0 [a.u.]
        then Faulted;
    }
  }

  part def WasteReservoir {
    port wasteIn : WasteOutletPort;
    port statusPort : StatusPort;

    attribute capacity : Volume;
    attribute storedWasteVolume : Volume;
    attribute fillFraction : Real;
  }

  part def ThermalController {
    port thermalPort : ThermalControlPort;
    port powerPort : ElectricalPowerPort;
    port statusPort : StatusPort;

    attribute heaterVoltage : Voltage;
    attribute measuredTemperature : Temperature;
    attribute controlError : Temperature;

    action def MaintainTemperature {
      in setPoint : Temperature;
      out actualTemperature : Temperature;
      first readTemperatureSensor;
      then computeError;
      then adjustHeaterPower;
      then verifyTemperatureBand;
    }
  }

  part def EmbeddedController {
    port commandPort : CommandPort;
    port statusPort : StatusPort;

    attribute firmwareVersion : String;
    attribute assayProtocolId : String;
    attribute currentStepIndex : Integer;

    action def ExecuteAssayProtocol {
      in sample : WholeBloodSample;
      out result : AssayResult;
      first selfCheck;
      then primeFluidics;
      then loadSample;
      then separatePlasma;
      then meterReagent;
      then mixAndIncubate;
      then detectAnalyte;
      then flushWaste;
      then publishResult;
    }

    state def ControllerState {
      state Idle;
      state SelfTest;
      state RunningAssay;
      state Completed;
      state ErrorRecovery;

      transition Idle_to_SelfTest
        first Idle
        accept ControlCommand
        if command.commandId == "start_assay"
        then SelfTest;

      transition SelfTest_to_RunningAssay
        first SelfTest
        if currentStepIndex == 0
        then RunningAssay;

      transition RunningAssay_to_Completed
        first RunningAssay
        if currentStepIndex >= 8
        then Completed;

      transition RunningAssay_to_ErrorRecovery
        first RunningAssay
        accept DiagnosticStatus
        if status.healthState == "fault"
        then ErrorRecovery;
    }
  }

  part def LabOnChipAnalyzer {
    port sampleInput : FluidInletPort;
    port reagentInput : ReagentInletPort;
    port resultOutput : DetectionPort;
    port wasteOutput : WasteOutletPort;
    port commandInput : CommandPort;
    port statusOutput : StatusPort;
    port powerInput : ElectricalPowerPort;

    attribute totalInternalVolume : Volume = 42.0 [uL];
    attribute nominalAssayDuration : Time = 600.0 [s];
    attribute nominalSampleVolume : Volume = 20.0 [uL];
    attribute maximumOperatingPressure : Pressure = 100.0 [kPa];
    attribute operatingTemperature : Temperature = 37.0 [degC];

    part inletPump : MicroPump {
      attribute commandedFlowRate = 12.0 [uL/min];
      attribute maximumPressure = 100.0 [kPa];
      attribute strokeVolume = 0.25 [uL];
    }

    part routingValve : MicroValve {
      attribute switchingTime = 0.25 [s];
      attribute leakageRate = 0.01 [uL/min];
    }

    part separator : PlasmaSeparator {
      attribute separationEfficiency = 0.92;
      attribute nominalInputFlowRate = 10.0 [uL/min];
    }

    part reagentReservoir : ReagentReservoir {
      attribute storedVolume = 120.0 [uL];
      attribute reagentTemperature = 4.0 [degC];
      attribute remainingAssayCount = 12;
    }

    part mixer : Mixer {
      attribute mixingTime = 30.0 [s];
      attribute mixingCompleteness = 0.97;
    }

    part reactionChamber : ReactionChamber {
      attribute chamberVolume = 8.0 [uL];
      attribute incubationTemperature = 37.0 [degC];
      attribute incubationDuration = 300.0 [s];
      attribute surfaceCaptureEfficiency = 0.88;
    }

    part detector : OpticalDetector {
      attribute excitationWavelength = 488.0;
      attribute emissionWavelength = 520.0;
      attribute darkCurrent = 0.01;
      attribute limitOfDetection = 0.5 [ng/mL];
    }

    part wasteReservoir : WasteReservoir {
      attribute capacity = 250.0 [uL];
      attribute storedWasteVolume = 0.0 [uL];
      attribute fillFraction = 0.0;
    }

    part thermalController : ThermalController {
      attribute heaterVoltage = 3.3 [V];
      attribute measuredTemperature = 37.0 [degC];
      attribute controlError = 0.0 [degC];
    }

    part embeddedController : EmbeddedController {
      attribute firmwareVersion = "3.2.1";
      attribute assayProtocolId = "LOC-IMMUNO-CRP-001";
      attribute currentStepIndex = 0;
    }

    connection sample_to_pump
      connect sampleInput to inletPump.inlet;

    connection pump_to_valve
      connect inletPump.outlet to routingValve.inlet;

    connection valve_to_separator
      connect routingValve.outlet to separator.sampleIn;

    connection separator_to_mixer
      connect separator.plasmaOut to mixer.sampleIn;

    connection reagent_to_mixer
      connect reagentReservoir.reagentOut to mixer.reagentIn;

    connection external_reagent_to_reservoir
      connect reagentInput to reagentReservoir.reagentOut;

    connection mixer_to_reaction
      connect mixer.mixedOut to reactionChamber.mixtureIn;

    connection reaction_to_detector
      connect reactionChamber.reactedOut to detector.detectionPort;

    connection detector_to_result
      connect detector.detectionPort to resultOutput;

    connection separator_waste_to_reservoir
      connect separator.wasteOut to wasteReservoir.wasteIn;

    connection valve_waste_to_reservoir
      connect routingValve.wasteOutlet to wasteReservoir.wasteIn;

    connection waste_to_external
      connect wasteReservoir.wasteIn to wasteOutput;

    connection thermal_control
      connect thermalController.thermalPort to reactionChamber.thermalPort;

    connection controller_command_input
      connect commandInput to embeddedController.commandPort;

    connection controller_status_output
      connect embeddedController.statusPort to statusOutput;

    connection controller_to_pump
      connect embeddedController.commandPort to inletPump.commandPort;

    connection controller_to_valve
      connect embeddedController.commandPort to routingValve.commandPort;

    connection controller_to_detector
      connect embeddedController.commandPort to detector.commandPort;

    connection controller_to_thermal
      connect embeddedController.commandPort to thermalController.thermalPort;

    connection power_to_pump
      connect powerInput to inletPump.powerPort;

    connection power_to_detector
      connect powerInput to detector.powerPort;

    connection power_to_thermal
      connect powerInput to thermalController.powerPort;

    action def PerformHighLevelFunction {
      in patientSample : WholeBloodSample;
      in assayReagent : Reagent;
      out diagnosticResult : AssayResult;

      first acceptDisposableCartridge;
      then receiveMicroliterBloodSample;
      then meterAndTransportFluid;
      then separatePlasmaFromCells;
      then combinePlasmaWithStoredReagent;
      then incubateBiochemicalReaction;
      then opticallyDetectTargetBiomarker;
      then computeQuantitativeAssayResult;
      then isolateBiohazardWaste;
      then reportDiagnosticResult;
    }
  }

  requirement def PrimaryFunctionRequirement {
    doc
    /*
     The lab-on-a-chip system shall accept a microliter-scale whole blood sample,
     perform automated plasma separation, reagent metering, mixing, incubation,
     optical biomarker detection, and waste containment, and shall output a
     quantitative diagnostic result without manual fluid handling.
    */

    subject analyzer : LabOnChipAnalyzer;

    require constraint {
      analyzer.nominalSampleVolume <= 20.0 [uL] and
      analyzer.nominalAssayDuration <= 600.0 [s]
    }
  }

  requirement def FluidContainmentRequirement {
    doc
    /*
     All biological fluids shall remain inside sealed microfluidic channels,
     chambers, or waste storage during normal operation.
    */

    subject analyzer : LabOnChipAnalyzer;

    require constraint {
      analyzer.maximumOperatingPressure <= 100.0 [kPa]
    }
  }

  requirement def DetectionSensitivityRequirement {
    doc
    /*
     The optical detector shall quantify the target biomarker at or below
     0.5 ng/mL concentration under calibrated operating conditions.
    */

    subject detector : OpticalDetector;

    require constraint {
      detector.limitOfDetection <= 0.5 [ng/mL]
    }
  }

  requirement def ThermalControlRequirement {
    doc
    /*
     The reaction chamber shall maintain assay incubation temperature at
     37 degC with a maximum absolute control error of 0.5 degC.
    */

    subject chamber : ReactionChamber;
    subject controller : ThermalController;

    require constraint {
      chamber.incubationTemperature == 37.0 [degC] and
      controller.controlError <= 0.5 [degC]
    }
  }

  requirement def WasteCapacityRequirement {
    doc
    /*
     The waste reservoir shall store all fluid waste from at least ten complete
     assays before replacement.
    */

    subject waste : WasteReservoir;

    require constraint {
      waste.capacity >= 200.0 [uL]
    }
  }

  requirement def SeparationEfficiencyRequirement {
    doc
    /*
     The plasma separator shall recover at least 90 percent of plasma fraction
     while routing retained cells to waste.
    */

    subject separator : PlasmaSeparator;

    require constraint {
      separator.separationEfficiency >= 0.90
    }
  }

  satisfy PrimaryFunctionSatisfaction
    by LabOnChipAnalyzer::PerformHighLevelFunction
    satisfy PrimaryFunctionRequirement;

  satisfy DetectionSensitivitySatisfaction
    by LabOnChipAnalyzer::detector
    satisfy DetectionSensitivityRequirement;

  satisfy ThermalControlSatisfaction
    by LabOnChipAnalyzer::thermalController
    satisfy ThermalControlRequirement;

  satisfy WasteCapacitySatisfaction
    by LabOnChipAnalyzer::wasteReservoir
    satisfy WasteCapacityRequirement;

  satisfy SeparationSatisfaction
    by LabOnChipAnalyzer::separator
    satisfy SeparationEfficiencyRequirement;

}