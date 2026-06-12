package BiochipSystemModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Temperature :> Real {
    unit = "degC";
  }

  attribute def Volume :> Real {
    unit = "uL";
  }

  attribute def FlowRate :> Real {
    unit = "uL/s";
  }

  attribute def Voltage :> Real {
    unit = "V";
  }

  attribute def Current :> Real {
    unit = "mA";
  }

  attribute def Concentration :> Real {
    unit = "ng/uL";
  }

  attribute def TimeDuration :> Real {
    unit = "s";
  }

  attribute def OpticalIntensity :> Real {
    unit = "a.u.";
  }

  attribute def Probability :> Real {
    unit = "1";
  }

  item def BiologicalSample {
    attribute sampleVolume : Volume;
    attribute analyteConcentration : Concentration;
    attribute temperature : Temperature;
    attribute contaminationRisk : Probability;
  }

  item def Reagent {
    attribute reagentVolume : Volume;
    attribute targetTemperature : Temperature;
    attribute expirationMargin : TimeDuration;
  }

  item def WasteFluid {
    attribute wasteVolume : Volume;
    attribute biohazardLevel : Integer;
  }

  item def AssayResult {
    attribute targetDetected : Boolean;
    attribute signalIntensity : OpticalIntensity;
    attribute confidence : Probability;
    attribute processedAt : TimeDuration;
  }

  item def ElectricalPower {
    attribute supplyVoltage : Voltage;
    attribute supplyCurrent : Current;
  }

  item def ControlCommand {
    attribute commandId : Integer;
    attribute requestedFlowRate : FlowRate;
    attribute requestedTemperature : Temperature;
    attribute duration : TimeDuration;
  }

  item def SensorReading {
    attribute measuredTemperature : Temperature;
    attribute measuredSignal : OpticalIntensity;
    attribute measuredFlowRate : FlowRate;
    attribute valid : Boolean;
  }

  port def SampleInputPort {
    in item sample : BiologicalSample;
  }

  port def ReagentInputPort {
    in item reagent : Reagent;
  }

  port def WasteOutputPort {
    out item waste : WasteFluid;
  }

  port def ResultOutputPort {
    out item result : AssayResult;
  }

  port def PowerInputPort {
    in item power : ElectricalPower;
  }

  port def CommandPort {
    in item command : ControlCommand;
  }

  port def ReadingPort {
    out item reading : SensorReading;
  }

  part def MicrofluidicChannel {
    attribute channelVolume : Volume = 12.0;
    attribute nominalFlowRate : FlowRate = 0.8;
    attribute maxPressure_kPa : Real = 120.0;

    port sampleIn : SampleInputPort;
    port reagentIn : ReagentInputPort;
    port mixedFluidOut : WasteOutputPort;
  }

  part def Micropump {
    attribute commandedFlowRate : FlowRate;
    attribute maxFlowRate : FlowRate = 5.0;
    attribute actuationVoltage : Voltage = 3.3;

    port powerIn : PowerInputPort;
    port commandIn : CommandPort;
    port fluidOut : WasteOutputPort;
  }

  part def MicrovalveArray {
    attribute valveCount : Integer = 16;
    attribute openValveCount : Integer;
    attribute switchingTime : TimeDuration = 0.05;

    port commandIn : CommandPort;
  }

  part def ReactionChamber {
    attribute chamberVolume : Volume = 25.0;
    attribute incubationTemperature : Temperature = 37.0;
    attribute incubationDuration : TimeDuration = 180.0;
    attribute mixingEfficiency : Probability = 0.95;

    port sampleIn : SampleInputPort;
    port reagentIn : ReagentInputPort;
    port wasteOut : WasteOutputPort;
  }

  part def ThermalController {
    attribute setPoint : Temperature = 37.0;
    attribute measuredTemperature : Temperature;
    attribute controlTolerance : Temperature = 0.5;
    attribute heaterPower_W : Real = 2.5;

    port powerIn : PowerInputPort;
    port commandIn : CommandPort;
    port readingOut : ReadingPort;
  }

  part def BiosensorArray {
    attribute sensorCount : Integer = 64;
    attribute detectionLimit : Concentration = 0.01;
    attribute saturationIntensity : OpticalIntensity = 10000.0;
    attribute baselineNoise : OpticalIntensity = 12.0;

    port readingOut : ReadingPort;
  }

  part def OpticalDetector {
    attribute excitationWavelength_nm : Real = 525.0;
    attribute emissionWavelength_nm : Real = 620.0;
    attribute integrationTime : TimeDuration = 1.0;
    attribute darkCurrent : Current = 0.01;

    port powerIn : PowerInputPort;
    port readingIn : ReadingPort;
    port readingOut : ReadingPort;
  }

  part def SignalProcessor {
    attribute minimumConfidence : Probability = 0.95;
    attribute calibrationFactor : Real = 1.0;
    attribute decisionThreshold : OpticalIntensity = 250.0;

    port readingIn : ReadingPort;
    port resultOut : ResultOutputPort;
  }

  part def EmbeddedController {
    attribute firmwareVersion : String = "2.1.0";
    attribute sampleProcessingTimeout : TimeDuration = 600.0;
    attribute safeTemperatureLimit : Temperature = 45.0;

    port powerIn : PowerInputPort;
    port commandOut : CommandPort;
    port readingIn : ReadingPort;
    port resultIn : ResultOutputPort;
  }

  part def BiochipCartridge {
    attribute cartridgeId : String;
    attribute sterile : Boolean = true;
    attribute maximumSampleVolume : Volume = 50.0;
    attribute minimumSampleVolume : Volume = 5.0;

    port sampleInput : SampleInputPort;
    port reagentInput : ReagentInputPort;
    port wasteOutput : WasteOutputPort;
    port resultOutput : ResultOutputPort;
    port powerInput : PowerInputPort;

    part pump : Micropump;
    part valves : MicrovalveArray;
    part channels : MicrofluidicChannel;
    part chamber : ReactionChamber;
    part heater : ThermalController;
    part sensors : BiosensorArray;
    part detector : OpticalDetector;
    part processor : SignalProcessor;
    part controller : EmbeddedController;

    connect sampleInput to channels.sampleIn;
    connect reagentInput to channels.reagentIn;
    connect channels.mixedFluidOut to chamber.wasteOut;
    connect chamber.wasteOut to wasteOutput;

    connect powerInput to pump.powerIn;
    connect powerInput to heater.powerIn;
    connect powerInput to detector.powerIn;
    connect powerInput to controller.powerIn;

    connect controller.commandOut to pump.commandIn;
    connect controller.commandOut to valves.commandIn;
    connect controller.commandOut to heater.commandIn;

    connect sensors.readingOut to detector.readingIn;
    connect detector.readingOut to processor.readingIn;
    connect processor.resultOut to resultOutput;
    connect heater.readingOut to controller.readingIn;
  }

  action def LoadSample {
    in item sample : BiologicalSample;
    out item acceptedSample : BiologicalSample;

    objective {
      doc /* Introduce a biological sample into the biochip cartridge while verifying volume and contamination constraints. */
    }
  }

  action def MixWithReagent {
    in item sample : BiologicalSample;
    in item reagent : Reagent;
    out item assayMixture : BiologicalSample;

    objective {
      doc /* Combine sample and reagent in controlled microfluidic proportions to prepare the assay reaction. */
    }
  }

  action def IncubateReaction {
    in item assayMixture : BiologicalSample;
    in attribute targetTemperature : Temperature;
    in attribute duration : TimeDuration;
    out item incubatedMixture : BiologicalSample;

    objective {
      doc /* Maintain the assay mixture at a controlled temperature long enough for target binding or amplification. */
    }
  }

  action def DetectSignal {
    in item incubatedMixture : BiologicalSample;
    out item reading : SensorReading;

    objective {
      doc /* Convert biochemical interaction at the sensor array into optical or electrochemical measurement data. */
    }
  }

  action def InterpretAssay {
    in item reading : SensorReading;
    out item result : AssayResult;

    objective {
      doc /* Process calibrated sensor data and determine whether the target analyte is present with sufficient confidence. */
    }
  }

  action def DisposeWaste {
    in item residualFluid : BiologicalSample;
    out item waste : WasteFluid;

    objective {
      doc /* Route remaining biofluid to an isolated waste reservoir after detection is complete. */
    }
  }

  action def ExecuteBiochipAssay {
    in item sample : BiologicalSample;
    in item reagent : Reagent;
    out item result : AssayResult;
    out item waste : WasteFluid;

    first start;
    then load : LoadSample {
      in sample = sample;
    }
    then mix : MixWithReagent {
      in sample = load.acceptedSample;
      in reagent = reagent;
    }
    then incubate : IncubateReaction {
      in assayMixture = mix.assayMixture;
      in targetTemperature = 37.0;
      in duration = 180.0;
    }
    then detect : DetectSignal {
      in incubatedMixture = incubate.incubatedMixture;
    }
    then interpret : InterpretAssay {
      in reading = detect.reading;
    }
    then dispose : DisposeWaste {
      in residualFluid = incubate.incubatedMixture;
    }
    then done;

    bind result = interpret.result;
    bind waste = dispose.waste;
  }

  state def BiochipOperationalState {
    entry action initializeController;

    state Idle;
    state SampleLoaded;
    state RoutingFluid;
    state Incubating;
    state Measuring;
    state Processing;
    state Reporting;
    state Flushing;
    state Fault;

    transition initial then Idle;

    transition Idle_to_SampleLoaded
      first Idle
      accept item sample : BiologicalSample
      then SampleLoaded;

    transition SampleLoaded_to_RoutingFluid
      first SampleLoaded
      if sample.sampleVolume >= 5.0 and sample.sampleVolume <= 50.0
      then RoutingFluid;

    transition SampleLoaded_to_Fault
      first SampleLoaded
      if sample.sampleVolume < 5.0 or sample.sampleVolume > 50.0
      then Fault;

    transition RoutingFluid_to_Incubating
      first RoutingFluid
      after 10.0
      then Incubating;

    transition Incubating_to_Measuring
      first Incubating
      after 180.0
      then Measuring;

    transition Measuring_to_Processing
      first Measuring
      after 5.0
      then Processing;

    transition Processing_to_Reporting
      first Processing
      if true
      then Reporting;

    transition Reporting_to_Flushing
      first Reporting
      after 2.0
      then Flushing;

    transition Flushing_to_Idle
      first Flushing
      after 20.0
      then Idle;

    transition Any_to_Fault_Overtemperature
      first Incubating
      if measuredTemperature > 45.0
      then Fault;
  }

  requirement def PrimaryFunctionRequirement {
    subject biochip : BiochipCartridge;

    require constraint {
      biochip.processor.minimumConfidence >= 0.95
    }

    doc /* The biochip system shall accept a small biological sample, combine it with assay reagents, control microfluidic transport and reaction conditions, detect a biochemical response, and produce a digital diagnostic assay result. */
  }

  requirement def SampleVolumeRequirement {
    subject biochip : BiochipCartridge;

    require constraint {
      biochip.minimumSampleVolume <= 5.0 and biochip.maximumSampleVolume >= 50.0
    }

    doc /* The biochip cartridge shall support biological sample volumes from 5 uL through 50 uL. */
  }

  requirement def TemperatureControlRequirement {
    subject controller : ThermalController;

    require constraint {
      controller.controlTolerance <= 0.5 and controller.setPoint == 37.0
    }

    doc /* The thermal controller shall maintain the reaction chamber at 37 degC within plus or minus 0.5 degC during incubation. */
  }

  requirement def DetectionSensitivityRequirement {
    subject sensors : BiosensorArray;

    require constraint {
      sensors.detectionLimit <= 0.01
    }

    doc /* The biosensor array shall detect target analyte concentrations at or below 0.01 ng/uL. */
  }

  requirement def WasteIsolationRequirement {
    subject biochip : BiochipCartridge;

    require constraint {
      biochip.sterile == true
    }

    doc /* The cartridge shall isolate post-assay biological waste from sample and reagent inputs during and after operation. */
  }

  requirement def ProcessingTimeRequirement {
    subject controller : EmbeddedController;

    require constraint {
      controller.sampleProcessingTimeout <= 600.0
    }

    doc /* The biochip system shall complete sample processing and result generation within 600 seconds from accepted sample loading. */
  }

  part biochipDiagnosticSystem : BiochipCartridge {
    cartridgeId = "BIOCHIP-DX-001";
    sterile = true;
    maximumSampleVolume = 50.0;
    minimumSampleVolume = 5.0;

    part pump {
      commandedFlowRate = 0.8;
      maxFlowRate = 5.0;
      actuationVoltage = 3.3;
    }

    part valves {
      valveCount = 16;
      openValveCount = 0;
      switchingTime = 0.05;
    }

    part channels {
      channelVolume = 12.0;
      nominalFlowRate = 0.8;
      maxPressure_kPa = 120.0;
    }

    part chamber {
      chamberVolume = 25.0;
      incubationTemperature = 37.0;
      incubationDuration = 180.0;
      mixingEfficiency = 0.95;
    }

    part heater {
      setPoint = 37.0;
      measuredTemperature = 25.0;
      controlTolerance = 0.5;
      heaterPower_W = 2.5;
    }

    part sensors {
      sensorCount = 64;
      detectionLimit = 0.01;
      saturationIntensity = 10000.0;
      baselineNoise = 12.0;
    }

    part detector {
      excitationWavelength_nm = 525.0;
      emissionWavelength_nm = 620.0;
      integrationTime = 1.0;
      darkCurrent = 0.01;
    }

    part processor {
      minimumConfidence = 0.95;
      calibrationFactor = 1.0;
      decisionThreshold = 250.0;
    }

    part controller {
      firmwareVersion = "2.1.0";
      sampleProcessingTimeout = 600.0;
      safeTemperatureLimit = 45.0;
    }
  }

  satisfy PrimaryFunctionRequirement by biochipDiagnosticSystem;
  satisfy SampleVolumeRequirement by biochipDiagnosticSystem;
  satisfy TemperatureControlRequirement by biochipDiagnosticSystem.heater;
  satisfy DetectionSensitivityRequirement by biochipDiagnosticSystem.sensors;
  satisfy WasteIsolationRequirement by biochipDiagnosticSystem;
  satisfy ProcessingTimeRequirement by biochipDiagnosticSystem.controller;

}