package Gravimeter {

  import ScalarValues::*;

  // ===== Value Types =====
  attribute def Displacement :> Real;
  attribute def Voltage :> Real;
  attribute def DigitalCode :> Integer;
  attribute def Temperature :> Real;
  attribute def Acceleration :> Real;
  attribute def Gravity :> Acceleration;
  attribute def TimeValue :> Real;
  attribute def Frequency :> Real;
  attribute def Power :> Real;
  attribute def Current :> Real;
  attribute def Resistance :> Real;
  attribute def Gain :> Real;
  attribute def Coefficient :> Real;
  attribute def MassValue :> Real;
  attribute def Stiffness :> Real;
  attribute def SampleRate :> Frequency;
  attribute def Ratio :> Real;

  // ===== Items =====
  item def RawVoltageSignal {
    attribute magnitude : Voltage;
  }
  item def ConditionedVoltageSignal {
    attribute magnitude : Voltage;
  }
  item def DigitalSample {
    attribute code : DigitalCode;
    attribute timestamp : TimeValue;
  }
  item def GravityReading {
    attribute gravity : Gravity;
    attribute timestamp : TimeValue;
    attribute temperature : Temperature;
  }
  item def Command {
    attribute id : String;
    attribute payload : String;
  }
  item def StatusReport {
    attribute operationalState : String;
    attribute uptime : TimeValue;
    attribute lastError : String;
    attribute measurementsLogged : Integer;
  }
  item def PowerRail {
    attribute nominalVoltage : Voltage;
    attribute maxCurrent : Current;
  }
  item def CalibrationParameters {
    attribute scaleCoefficient : Coefficient;
    attribute offsetCoefficient : Coefficient;
    attribute tempCoeffLinear : Coefficient;
    attribute tempCoeffQuadratic : Coefficient;
    attribute referenceTemperature : Temperature;
  }

  // ===== Events =====
  item def PowerOnEvent;
  item def InitCompleteEvent;
  item def InitFailureEvent;
  item def SuspendCommandEvent;
  item def ResumeCommandEvent;
  item def FaultDetectedEvent;
  item def ResetCommandEvent;
  item def RestartCommandEvent;

  // ===== Port Definitions =====
  port def DisplacementOutPort {
    out displacement : Displacement;
  }
  port def DisplacementInPort {
    in displacement : Displacement;
  }
  port def RawVoltageOutPort {
    out signal : RawVoltageSignal;
  }
  port def RawVoltageInPort {
    in signal : RawVoltageSignal;
  }
  port def ConditionedVoltageOutPort {
    out signal : ConditionedVoltageSignal;
  }
  port def ConditionedVoltageInPort {
    in signal : ConditionedVoltageSignal;
  }
  port def DigitalOutPort {
    out sample : DigitalSample;
  }
  port def DigitalInPort {
    in sample : DigitalSample;
  }
  port def ReadingOutPort {
    out reading : GravityReading;
  }
  port def ReadingInPort {
    in reading : GravityReading;
  }
  port def PowerOutPort {
    out rail : PowerRail;
  }
  port def PowerInPort {
    in rail : PowerRail;
  }
  port def CommandInPort {
    in command : Command;
  }
  port def CommandOutPort {
    out command : Command;
  }
  port def StatusOutPort {
    out status : StatusReport;
  }
  port def StatusInPort {
    in status : StatusReport;
  }

  // ===== Action Definitions =====
  action def ComputeGravity {
    in rawSample : DigitalSample;
    in currentTemperature : Temperature;
    in calibration : CalibrationParameters;
    out reading : GravityReading;

    action ConvertCodeToVoltage {
      in code : DigitalCode;
      out voltage : Voltage;
    }
    action ApplyCalibration {
      in voltage : Voltage;
      in coeff : CalibrationParameters;
      out value : Gravity;
    }
    action CompensateTemperature {
      in value : Gravity;
      in temperature : Temperature;
      in coeff : CalibrationParameters;
      out corrected : Gravity;
    }
    action AssembleReading {
      in gravity : Gravity;
      in timestamp : TimeValue;
      in temperature : Temperature;
      out reading : GravityReading;
    }

    flow from rawSample.code to ConvertCodeToVoltage.code;
    flow from ConvertCodeToVoltage.voltage to ApplyCalibration.voltage;
    flow from calibration to ApplyCalibration.coeff;
    flow from ApplyCalibration.value to CompensateTemperature.value;
    flow from currentTemperature to CompensateTemperature.temperature;
    flow from calibration to CompensateTemperature.coeff;
    flow from CompensateTemperature.corrected to AssembleReading.gravity;
    flow from rawSample.timestamp to AssembleReading.timestamp;
    flow from currentTemperature to AssembleReading.temperature;
    flow from AssembleReading.reading to reading;
  }

  // ===== State Machine =====
  state def ControlState {
    state off;
    state initializing;
    state measuring;
    state standby;
    state faulted;

    transition from off to initializing on PowerOnEvent;
    transition from initializing to measuring on InitCompleteEvent;
    transition from initializing to faulted on InitFailureEvent;
    transition from measuring to standby on SuspendCommandEvent;
    transition from standby to measuring on ResumeCommandEvent;
    transition from measuring to faulted on FaultDetectedEvent;
    transition from standby to faulted on FaultDetectedEvent;
    transition from faulted to off on ResetCommandEvent;
    transition from faulted to initializing on RestartCommandEvent;
  }

  // ===== Part Definitions =====
  part def ProofMass {
    attribute mass : MassValue;
    attribute referencePosition : Displacement;
    attribute currentDisplacement : Displacement;
    attribute dampingCoefficient : Coefficient;
    port displacementOut : DisplacementOutPort;
  }

  part def SpringSystem {
    attribute springConstant : Stiffness;
    attribute restLength : Displacement;
    attribute thermalCoefficient : Coefficient;
    port loadIn : DisplacementInPort;
    port displacementOut : DisplacementOutPort;
  }

  part def DisplacementSensor {
    attribute sensitivity : Ratio;
    attribute noiseFloor : Voltage;
    attribute bandwidth : Frequency;
    port displacementIn : DisplacementInPort;
    port rawVoltageOut : RawVoltageOutPort;
    port powerIn : PowerInPort;
    port commandIn : CommandInPort;
    port statusOut : StatusOutPort;

    action Sense {
      in displacement : Displacement;
      out signal : RawVoltageSignal;
    }
    flow from displacementIn.displacement to Sense.displacement;
    flow from Sense.signal to rawVoltageOut.signal;
  }

  part def SignalConditioner {
    attribute gain : Gain;
    attribute lowPassCutoff : Frequency;
    attribute highPassCutoff : Frequency;
    attribute inputImpedance : Resistance;
    port signalIn : RawVoltageInPort;
    port signalOut : ConditionedVoltageOutPort;
    port powerIn : PowerInPort;
    port commandIn : CommandInPort;
    port statusOut : StatusOutPort;

    action Amplify {
      in input : RawVoltageSignal;
      out amplified : Voltage;
    }
    action Filter {
      in input : Voltage;
      out filtered : ConditionedVoltageSignal;
    }
    flow from signalIn.signal to Amplify.input;
    flow from Amplify.amplified to Filter.input;
    flow from Filter.filtered to signalOut.signal;
  }

  part def AnalogToDigitalConverter {
    attribute resolutionBits : Integer;
    attribute sampleRate : SampleRate;
    attribute inputRange : Voltage;
    port analogIn : ConditionedVoltageInPort;
    port digitalOut : DigitalOutPort;
    port powerIn : PowerInPort;
    port commandIn : CommandInPort;
    port statusOut : StatusOutPort;

    action Sample {
      in analog : ConditionedVoltageSignal;
      out digital : DigitalSample;
    }
    flow from analogIn.signal to Sample.analog;
    flow from Sample.digital to digitalOut.sample;
  }

  part def DataProcessor {
    attribute calibration : CalibrationParameters;
    attribute measurementInterval : TimeValue;
    attribute currentTemperature : Temperature;
    attribute measurementPrecision : Gravity;
    port digitalIn : DigitalInPort;
    port readingOut : ReadingOutPort;
    port powerIn : PowerInPort;
    port commandIn : CommandInPort;
    port statusOut : StatusOutPort;

    action compute : ComputeGravity;
    flow from digitalIn.sample to compute.rawSample;
    flow from currentTemperature to compute.currentTemperature;
    flow from calibration to compute.calibration;
    flow from compute.reading to readingOut.reading;
  }

  part def DataLogger {
    attribute storageCapacity : Integer;
    attribute loggedCount : Integer;
    port readingIn : ReadingInPort;
    port powerIn : PowerInPort;
    port commandIn : CommandInPort;
    port statusOut : StatusOutPort;

    action StoreReading {
      in reading : GravityReading;
    }
    flow from readingIn.reading to StoreReading.reading;
  }

  part def PowerSupply {
    attribute inputVoltage : Voltage;
    attribute analogRailVoltage : Voltage;
    attribute digitalRailVoltage : Voltage;
    attribute maxOutputPower : Power;
    attribute efficiency : Ratio;
    port analogRail : PowerOutPort;
    port digitalRail : PowerOutPort;
    port powerIn : PowerInPort;
    port commandIn : CommandInPort;
    port statusOut : StatusOutPort;
  }

  part def ControlUnit {
    attribute sampleInterval : TimeValue;
    attribute watchdogTimeout : TimeValue;
    port commandIn : CommandInPort;
    port statusOut : StatusOutPort;
    port powerIn : PowerInPort;
    port sensorCommand : CommandOutPort;
    port conditionerCommand : CommandOutPort;
    port adcCommand : CommandOutPort;
    port processorCommand : CommandOutPort;
    port loggerCommand : CommandOutPort;
    port powerCommand : CommandOutPort;
    port powerStatus : StatusInPort;
    port loggerStatus : StatusInPort;
    port processorStatus : StatusInPort;

    exhibit state ControlState;
  }

  // ===== Sensing Mechanism (composite) =====
  part def SensingMechanism {
    part proofMass : ProofMass;
    part springSystem : SpringSystem;
    part displacementSensor : DisplacementSensor;

    connect proofMass.displacementOut to springSystem.loadIn;
    connect proofMass.displacementOut to displacementSensor.displacementIn;

    port rawVoltageOut : RawVoltageOutPort;
    connect displacementSensor.rawVoltageOut to rawVoltageOut;

    port powerIn : PowerInPort;
    port commandIn : CommandInPort;
    port statusOut : StatusOutPort;
    connect powerIn to displacementSensor.powerIn;
    connect commandIn to displacementSensor.commandIn;
    connect displacementSensor.statusOut to statusOut;
  }

  // ===== Top-level Gravimeter =====
  part def Gravimeter {
    attribute instrumentId : String;
    attribute nominalGravity : Gravity;
    attribute operatingTemperatureMin : Temperature;
    attribute operatingTemperatureMax : Temperature;
    attribute measurementPrecision : Gravity;
    attribute samplingRate : SampleRate;

    part sensingMechanism : SensingMechanism;
    part signalConditioner : SignalConditioner;
    part adc : AnalogToDigitalConverter;
    part dataProcessor : DataProcessor;
    part dataLogger : DataLogger;
    part powerSupply : PowerSupply;
    part controlUnit : ControlUnit;

    port commandIn : CommandInPort;
    port statusOut : StatusOutPort;
    port dataOut : ReadingOutPort;
    port mainsPowerIn : PowerInPort;

    connect sensingMechanism.rawVoltageOut to signalConditioner.signalIn;
    connect signalConditioner.signalOut to adc.analogIn;
    connect adc.digitalOut to dataProcessor.digitalIn;
    connect dataProcessor.readingOut to dataLogger.readingIn;
    connect dataProcessor.readingOut to dataOut;

    connect mainsPowerIn to powerSupply.powerIn;
    connect powerSupply.analogRail to sensingMechanism.powerIn;
    connect powerSupply.analogRail to signalConditioner.powerIn;
    connect powerSupply.analogRail to adc.powerIn;
    connect powerSupply.digitalRail to dataProcessor.powerIn;
    connect powerSupply.digitalRail to dataLogger.powerIn;
    connect powerSupply.digitalRail to controlUnit.powerIn;

    connect commandIn to controlUnit.commandIn;
    connect controlUnit.sensorCommand to sensingMechanism.commandIn;
    connect controlUnit.conditionerCommand to signalConditioner.commandIn;
    connect controlUnit.adcCommand to adc.commandIn;
    connect controlUnit.processorCommand to dataProcessor.commandIn;
    connect controlUnit.loggerCommand to dataLogger.commandIn;
    connect controlUnit.powerCommand to powerSupply.commandIn;

    connect powerSupply.statusOut to controlUnit.powerStatus;
    connect dataLogger.statusOut to controlUnit.loggerStatus;
    connect dataProcessor.statusOut to controlUnit.processorStatus;
    connect controlUnit.statusOut to statusOut;
  }

  // ===== Requirements =====
  requirement def HighPrecisionMeasurementRequirement {
    subject gravimeter : Gravimeter;
    attribute precisionThreshold : Gravity;
    constraint { gravimeter.measurementPrecision <= precisionThreshold }
  }

  requirement def ContinuousMonitoringRequirement {
    subject gravimeter : Gravimeter;
    attribute minimumDutyCycle : Ratio;
    constraint { gravimeter.samplingRate > 0.0 }
  }

  requirement def TemperatureCompensationRequirement {
    subject processor : DataProcessor;
    attribute compensationAccuracy : Gravity;
    constraint { processor.currentTemperature >= -40.0 and processor.currentTemperature <= 60.0 }
  }

  requirement def RegulatedPowerRequirement {
    subject supply : PowerSupply;
    attribute rippleLimit : Voltage;
    constraint { supply.analogRailVoltage > 0.0 and supply.digitalRailVoltage > 0.0 }
  }

  requirement def CommandAndStatusRequirement {
    subject control : ControlUnit;
    constraint { control.sampleInterval > 0.0 }
  }

  requirement def DataIntegrityRequirement {
    subject logger : DataLogger;
    constraint { logger.storageCapacity > 0 }
  }

  // ===== Top-level instance =====
  part gravimeterInstance : Gravimeter {
    attribute instrumentId = "GRAV-001";
    attribute nominalGravity = 9.80665;
    attribute measurementPrecision = 1.0e-8;
    attribute samplingRate = 1.0;
    attribute operatingTemperatureMin = -10.0;
    attribute operatingTemperatureMax = 50.0;

    part powerSupply : PowerSupply {
      attribute inputVoltage = 12.0;
      attribute analogRailVoltage = 15.0;
      attribute digitalRailVoltage = 3.3;
      attribute maxOutputPower = 5.0;
      attribute efficiency = 0.85;
    }
    part dataProcessor : DataProcessor {
      attribute measurementInterval = 1.0;
      attribute currentTemperature = 22.5;
      attribute measurementPrecision = 1.0e-8;
      attribute calibration : CalibrationParameters {
        attribute scaleCoefficient = 1.0;
        attribute offsetCoefficient = 0.0;
        attribute tempCoeffLinear = 1.0e-7;
        attribute tempCoeffQuadratic = 0.0;
        attribute referenceTemperature = 20.0;
      }
    }
    part controlUnit : ControlUnit {
      attribute sampleInterval = 1.0;
      attribute watchdogTimeout = 30.0;
    }
    part dataLogger : DataLogger {
      attribute storageCapacity = 1000000;
      attribute loggedCount = 0;
    }
    part adc : AnalogToDigitalConverter {
      attribute resolutionBits = 24;
      attribute sampleRate = 1000.0;
      attribute inputRange = 10.0;
    }
    part signalConditioner : SignalConditioner {
      attribute gain = 1000.0;
      attribute lowPassCutoff = 10.0;
      attribute highPassCutoff = 0.001;
      attribute inputImpedance = 1000000.0;
    }
    part sensingMechanism : SensingMechanism {
      part proofMass : ProofMass {
        attribute mass = 0.05;
        attribute referencePosition = 0.0;
        attribute currentDisplacement = 0.0;
        attribute dampingCoefficient = 0.01;
      }
      part springSystem : SpringSystem {
        attribute springConstant = 0.5;
        attribute restLength = 0.1;
        attribute thermalCoefficient = 1.0e-6;
      }
      part displacementSensor : DisplacementSensor {
        attribute sensitivity = 1000.0;
        attribute noiseFloor = 1.0e-9;
        attribute bandwidth = 100.0;
      }
    }
  }

  // ===== Requirement instances =====
  requirement precisionRequirement : HighPrecisionMeasurementRequirement {
    subject gravimeter = gravimeterInstance;
    attribute precisionThreshold = 1.0e-8;
  }

  requirement continuousRequirement : ContinuousMonitoringRequirement {
    subject gravimeter = gravimeterInstance;
    attribute minimumDutyCycle = 0.99;
  }

  requirement tempCompensationRequirement : TemperatureCompensationRequirement {
    subject processor = gravimeterInstance.dataProcessor;
    attribute compensationAccuracy = 1.0e-9;
  }

  requirement regulatedPowerRequirement : RegulatedPowerRequirement {
    subject supply = gravimeterInstance.powerSupply;
    attribute rippleLimit = 1.0e-3;
  }

  requirement commandStatusRequirement : CommandAndStatusRequirement {
    subject control = gravimeterInstance.controlUnit;
  }

  requirement dataIntegrityRequirement : DataIntegrityRequirement {
    subject logger = gravimeterInstance.dataLogger;
  }

}
