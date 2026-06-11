package OpenFlowMicroperfusionSystem {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def MicroliterPerMinute :> Real {
    unit = "uL/min";
  }

  attribute def Millimeter :> Real {
    unit = "mm";
  }

  attribute def MillimolePerLiter :> Real {
    unit = "mmol/L";
  }

  attribute def Kilopascal :> Real {
    unit = "kPa";
  }

  attribute def Minute :> Real {
    unit = "min";
  }

  attribute def DegreeCelsius :> Real {
    unit = "degC";
  }

  attribute def Percent :> Real {
    unit = "%";
  }

  attribute def Microliter :> Real {
    unit = "uL";
  }

  attribute def Volt :> Real {
    unit = "V";
  }

  item def Perfusate {
    attribute ionicStrength : MillimolePerLiter;
    attribute glucoseConcentration : MillimolePerLiter;
    attribute lactateConcentration : MillimolePerLiter;
    attribute tracerConcentration : MillimolePerLiter;
    attribute temperature : DegreeCelsius;
  }

  item def InterstitialFluidSample {
    attribute volume : Microliter;
    attribute glucoseConcentration : MillimolePerLiter;
    attribute lactateConcentration : MillimolePerLiter;
    attribute inflammatoryMarkerIndex : Real;
    attribute recoveryRatio : Percent;
    attribute collectionTime : Minute;
  }

  item def TissueAnalyte {
    attribute concentration : MillimolePerLiter;
    attribute diffusionCoefficient : Real;
  }

  item def Command {
    attribute requestedFlowRate : MicroliterPerMinute;
    attribute requestedCollectionInterval : Minute;
    attribute startSampling : Boolean;
    attribute flushRequested : Boolean;
  }

  item def Status {
    attribute currentFlowRate : MicroliterPerMinute;
    attribute inletPressure : Kilopascal;
    attribute outletPressure : Kilopascal;
    attribute reservoirRemaining : Microliter;
    attribute probeInserted : Boolean;
    attribute occlusionDetected : Boolean;
    attribute sampleReady : Boolean;
  }

  port def FluidInletPort {
    in item fluid : Perfusate;
  }

  port def FluidOutletPort {
    out item fluid : Perfusate;
  }

  port def SampleOutletPort {
    out item sample : InterstitialFluidSample;
  }

  port def TissueExchangePort {
    in item analyte : TissueAnalyte;
    inout item perfusionMedium : Perfusate;
  }

  port def CommandPort {
    in item command : Command;
  }

  port def StatusPort {
    out item status : Status;
  }

  part def PerfusateReservoir {
    attribute capacity : Microliter = 5000;
    attribute remainingVolume : Microliter;
    attribute sterileBarrierIntegrity : Boolean;
    port outlet : FluidOutletPort;
  }

  part def MicroPump {
    attribute commandedFlowRate : MicroliterPerMinute;
    attribute measuredFlowRate : MicroliterPerMinute;
    attribute minimumFlowRate : MicroliterPerMinute = 0.1;
    attribute maximumFlowRate : MicroliterPerMinute = 10.0;
    attribute flowStability : Percent = 95.0;
    port inlet : FluidInletPort;
    port outlet : FluidOutletPort;

    action def DeliverPerfusate {
      in item incoming : Perfusate;
      in attribute targetFlowRate : MicroliterPerMinute;
      out item outgoing : Perfusate;
      out attribute actualFlowRate : MicroliterPerMinute;
    }
  }

  part def PressureSensor {
    attribute pressure : Kilopascal;
    attribute measurementRangeMin : Kilopascal = -20;
    attribute measurementRangeMax : Kilopascal = 200;
    port fluidPath : FluidInletPort;
  }

  part def TemperatureSensor {
    attribute measuredTemperature : DegreeCelsius;
    attribute accuracy : DegreeCelsius = 0.2;
  }

  part def OpenFlowProbe {
    attribute insertionDepth : Millimeter;
    attribute exchangeLength : Millimeter = 15.0;
    attribute outerDiameter : Millimeter = 0.6;
    attribute poreOpeningWidth : Millimeter = 0.12;
    attribute tissueContactArea : Real;
    attribute openExchangePath : Boolean = true;

    port inlet : FluidInletPort;
    port outlet : FluidOutletPort;
    port tissueInterface : TissueExchangePort;

    action def ExchangeWithInterstitialSpace {
      in item inflowingPerfusate : Perfusate;
      in item localAnalyte : TissueAnalyte;
      in attribute residenceTime : Minute;
      out item analyteEnrichedPerfusate : Perfusate;
      out attribute relativeRecovery : Percent;
    }
  }

  part def SampleFractionCollector {
    attribute vialCount : Integer = 24;
    attribute activeVialIndex : Integer;
    attribute collectionInterval : Minute;
    attribute collectedVolumePerVial : Microliter;

    port inlet : FluidInletPort;
    port sampleOutlet : SampleOutletPort;

    action def CreateTimedSample {
      in item enrichedPerfusate : Perfusate;
      in attribute interval : Minute;
      out item sample : InterstitialFluidSample;
    }
  }

  part def ControlUnit {
    attribute samplingEnabled : Boolean;
    attribute targetFlowRate : MicroliterPerMinute = 1.0;
    attribute targetCollectionInterval : Minute = 10.0;
    attribute pressureAlarmThreshold : Kilopascal = 120.0;
    attribute reservoirLowLimit : Microliter = 250.0;
    attribute batteryVoltage : Volt;

    port commandInput : CommandPort;
    port statusOutput : StatusPort;

    action def RegulateFlow {
      in attribute desiredFlowRate : MicroliterPerMinute;
      in attribute measuredFlowRate : MicroliterPerMinute;
      out attribute pumpCommand : MicroliterPerMinute;
    }

    action def DetectOcclusion {
      in attribute inletPressure : Kilopascal;
      in attribute outletPressure : Kilopascal;
      out attribute occlusionDetected : Boolean;
    }

    state def SamplingController {
      state idle;
      state priming;
      state insertingProbe;
      state perfusing;
      state collecting;
      state flushing;
      state alarm;
      state shutdown;

      transition first idle;

      transition idle_to_priming
        first idle
        then priming;

      transition priming_to_insertingProbe
        first priming
        then insertingProbe;

      transition insertingProbe_to_perfusing
        first insertingProbe
        then perfusing;

      transition perfusing_to_collecting
        first perfusing
        then collecting;

      transition collecting_to_perfusing
        first collecting
        then perfusing;

      transition perfusing_to_flushing
        first perfusing
        then flushing;

      transition flushing_to_idle
        first flushing
        then idle;

      transition any_to_alarm
        first perfusing
        then alarm;

      transition alarm_to_shutdown
        first alarm
        then shutdown;
    }
  }

  part def DataLogger {
    attribute sampleRecordCount : Integer;
    attribute loggingInterval : Minute = 1.0;
    port statusInput : StatusPort;
    port sampleInput : SampleOutletPort;

    action def RecordSampleMetadata {
      in item sample : InterstitialFluidSample;
      in item status : Status;
    }
  }

  part def OpenFlowMicroperfusionDevice {
    attribute primaryFunction : String =
      "Continuously perfuse a sterile physiological solution through an open flow probe placed in tissue so dissolved extracellular analytes diffuse into the moving perfusate and are recovered as timed interstitial fluid samples for biochemical analysis.";

    part reservoir : PerfusateReservoir {
      remainingVolume = 5000;
      sterileBarrierIntegrity = true;
    }

    part pump : MicroPump {
      commandedFlowRate = 1.0;
      measuredFlowRate = 1.0;
    }

    part inletPressureSensor : PressureSensor;
    part outletPressureSensor : PressureSensor;
    part temperatureSensor : TemperatureSensor;

    part probe : OpenFlowProbe {
      insertionDepth = 8.0;
      tissueContactArea = 28.3;
    }

    part collector : SampleFractionCollector {
      activeVialIndex = 1;
      collectionInterval = 10.0;
      collectedVolumePerVial = 10.0;
    }

    part controller : ControlUnit;
    part logger : DataLogger;

    port command : CommandPort;
    port status : StatusPort;
    port tissue : TissueExchangePort;
    port sampleOutput : SampleOutletPort;

    connect reservoir.outlet to pump.inlet;
    connect pump.outlet to inletPressureSensor.fluidPath;
    connect pump.outlet to probe.inlet;
    connect probe.outlet to outletPressureSensor.fluidPath;
    connect probe.outlet to collector.inlet;
    connect collector.sampleOutlet to sampleOutput;
    connect tissue to probe.tissueInterface;
    connect command to controller.commandInput;
    connect controller.statusOutput to status;
    connect controller.statusOutput to logger.statusInput;
    connect collector.sampleOutlet to logger.sampleInput;
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The system shall continuously perfuse an open flow probe with sterile perfusate and collect analyte-enriched fluid that represents local interstitial chemistry. */
    subject device : OpenFlowMicroperfusionDevice;
    require constraint {
      device.primaryFunction != "";
    }
  }

  requirement def FlowRateRequirement {
    doc /* The system shall maintain low flow operation suitable for microperfusion sampling. */
    subject pump : MicroPump;
    require constraint {
      pump.measuredFlowRate >= pump.minimumFlowRate and
      pump.measuredFlowRate <= pump.maximumFlowRate
    }
  }

  requirement def OpenExchangeRequirement {
    doc /* The probe shall provide an open exchange path between flowing perfusate and surrounding tissue fluid without a dialysis membrane. */
    subject probe : OpenFlowProbe;
    require constraint {
      probe.openExchangePath == true and
      probe.poreOpeningWidth > 0.05
    }
  }

  requirement def SampleVolumeRequirement {
    doc /* The collector shall create timed sample fractions with sufficient volume for downstream analysis. */
    subject collector : SampleFractionCollector;
    require constraint {
      collector.collectionInterval >= 1.0 and
      collector.collectedVolumePerVial >= 1.0
    }
  }

  requirement def OcclusionSafetyRequirement {
    doc /* The controller shall detect abnormal pressure rise that indicates possible probe or tubing occlusion. */
    subject controller : ControlUnit;
    require constraint {
      controller.pressureAlarmThreshold <= 150.0
    }
  }

  requirement def ReservoirRequirement {
    doc /* The reservoir shall contain enough sterile perfusate for extended sampling while preserving barrier integrity. */
    subject reservoir : PerfusateReservoir;
    require constraint {
      reservoir.capacity >= 1000.0 and
      reservoir.sterileBarrierIntegrity == true
    }
  }

  requirement def TemperatureMonitoringRequirement {
    doc /* The system shall monitor perfusion temperature to support interpretation of diffusion-dependent analyte recovery. */
    subject sensor : TemperatureSensor;
    require constraint {
      sensor.accuracy <= 0.5
    }
  }

  satisfy PrimaryFunctionRequirement by OpenFlowMicroperfusionDevice;
  satisfy FlowRateRequirement by OpenFlowMicroperfusionDevice::pump;
  satisfy OpenExchangeRequirement by OpenFlowMicroperfusionDevice::probe;
  satisfy SampleVolumeRequirement by OpenFlowMicroperfusionDevice::collector;
  satisfy OcclusionSafetyRequirement by OpenFlowMicroperfusionDevice::controller;
  satisfy ReservoirRequirement by OpenFlowMicroperfusionDevice::reservoir;
  satisfy TemperatureMonitoringRequirement by OpenFlowMicroperfusionDevice::temperatureSensor;

  action def PerformOpenFlowMicroperfusion {
    in item command : Command;
    in item tissueAnalyte : TissueAnalyte;
    out item sample : InterstitialFluidSample;
    out item status : Status;

    first start;
    then primeFluidPath;
    then insertOpenFlowProbe;
    then regulateLowFlowPerfusion;
    then exchangeAnalytes;
    then collectTimedFraction;
    then recordSamplingStatus;
    then done;

    action start;
    action primeFluidPath;
    action insertOpenFlowProbe;
    action regulateLowFlowPerfusion;
    action exchangeAnalytes;
    action collectTimedFraction;
    action recordSamplingStatus;
    action done;
  }

  part system : OpenFlowMicroperfusionDevice;

}