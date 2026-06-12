package NeutronDetectionSystemModel {

  package Quantities {
    attribute def Count;
    attribute def CountRate;
    attribute def Energy;
    attribute def Voltage;
    attribute def Current;
    attribute def Time;
    attribute def Temperature;
    attribute def Probability;
    attribute def Length;
    attribute def DataSize;

    item def ThermalNeutron {
      attribute kineticEnergy : Energy;
      attribute arrivalTime : Time;
    }

    item def GammaPhoton {
      attribute photonEnergy : Energy;
      attribute arrivalTime : Time;
    }

    item def IonizationPulse {
      attribute charge : Current;
      attribute duration : Time;
      attribute peakVoltage : Voltage;
      attribute timestamp : Time;
    }

    item def DetectionEvent {
      attribute eventId : Count;
      attribute eventTime : Time;
      attribute pulseHeight : Voltage;
      attribute estimatedNeutronEnergy : Energy;
      attribute gammaRejectionConfidence : Probability;
    }

    item def HealthStatus {
      attribute detectorTemperature : Temperature;
      attribute highVoltage : Voltage;
      attribute eventRate : CountRate;
      attribute faultCode : Count;
    }

    item def AlarmMessage {
      attribute alarmTime : Time;
      attribute neutronCountRate : CountRate;
      attribute threshold : CountRate;
      attribute confidence : Probability;
    }

    item def EventRecord {
      attribute eventCount : Count;
      attribute recordSize : DataSize;
      attribute startTime : Time;
      attribute endTime : Time;
    }
  }

  package Interfaces {
    import Quantities::*;

    port def NeutronRadiationPort {
      in item neutron : ThermalNeutron;
      in item gamma : GammaPhoton;
    }

    port def PulsePort {
      out item pulse : IonizationPulse;
    }

    port def SignalPort {
      in item rawPulse : IonizationPulse;
      out item event : DetectionEvent;
    }

    port def EventPort {
      out item event : DetectionEvent;
    }

    port def HealthPort {
      out item status : HealthStatus;
    }

    port def AlarmPort {
      out item alarm : AlarmMessage;
    }

    port def DataPort {
      out item record : EventRecord;
    }

    port def PowerPort {
      in attribute supplyVoltage : Voltage;
      in attribute supplyCurrent : Current;
    }

    port def ControlPort {
      in attribute acquisitionEnabled : Boolean;
      in attribute alarmThreshold : CountRate;
      in attribute integrationWindow : Time;
    }
  }

  package Behaviors {
    import Quantities::*;

    action def CaptureThermalNeutron {
      in item incomingNeutron : ThermalNeutron;
      out item ionizationPulse : IonizationPulse;
    }

    action def ShapeAndDigitizePulse {
      in item rawPulse : IonizationPulse;
      out item digitizedEvent : DetectionEvent;
    }

    action def RejectGammaBackground {
      in item candidateEvent : DetectionEvent;
      out item neutronEvent : DetectionEvent;
      out attribute accepted : Boolean;
    }

    action def ComputeNeutronRate {
      in item neutronEvent : DetectionEvent;
      in attribute integrationWindow : Time;
      out attribute neutronRate : CountRate;
    }

    action def AnnunciateAlarm {
      in attribute neutronRate : CountRate;
      in attribute threshold : CountRate;
      out item alarm : AlarmMessage;
    }

    state def DetectionOperatingState {
      entry action InitializeDetector;

      state Off;
      state Warmup;
      state BackgroundCalibration;
      state Monitoring;
      state Alarm;
      state Fault;
      state Maintenance;

      transition InitialToOff first Off;

      transition PowerApplied
        first Off
        then Warmup;

      transition WarmupComplete
        first Warmup
        then BackgroundCalibration;

      transition CalibrationComplete
        first BackgroundCalibration
        then Monitoring;

      transition ElevatedNeutronRate
        first Monitoring
        then Alarm;

      transition RateReturnedToNormal
        first Alarm
        then Monitoring;

      transition FaultDetected
        first Monitoring
        then Fault;

      transition FaultDuringAlarm
        first Alarm
        then Fault;

      transition ServiceRequested
        first Fault
        then Maintenance;

      transition ServiceComplete
        first Maintenance
        then Warmup;
    }
  }

  package Requirements {
    import Quantities::*;

    requirement def DetectNeutronsRequirement {
      doc /* The system shall detect thermal neutron radiation and generate validated neutron detection events. */
      attribute minimumDetectionEfficiency : Probability;
      attribute maximumGammaFalseAlarmProbability : Probability;
    }

    requirement def AlarmRequirement {
      doc /* The system shall issue an alarm when the validated neutron count rate exceeds the configured threshold over the integration window. */
      attribute responseTimeLimit : Time;
      attribute minimumConfidence : Probability;
    }

    requirement def HealthMonitoringRequirement {
      doc /* The system shall continuously report detector health, high voltage status, temperature, and event rate. */
      attribute healthUpdatePeriod : Time;
    }

    requirement def DataLoggingRequirement {
      doc /* The system shall store time-tagged neutron event records for later review and traceability. */
      attribute minimumRetentionTime : Time;
    }
  }

  package Structure {
    import Quantities::*;
    import Interfaces::*;
    import Behaviors::*;
    import Requirements::*;

    part def NeutronDetectorTube {
      port radiationInput : NeutronRadiationPort;
      port pulseOutput : PulsePort;
      port highVoltageInput : PowerPort;

      attribute fillGasPressure : Pressure;
      attribute converterMaterialThickness : Length;
      attribute operatingVoltage : Voltage;
      attribute detectorTemperature : Temperature;
      attribute intrinsicThermalNeutronEfficiency : Probability;

      perform action capture : CaptureThermalNeutron;
    }

    attribute def Pressure;

    part def ModeratorAssembly {
      port incidentRadiation : NeutronRadiationPort;
      port thermalizedRadiation : NeutronRadiationPort;

      attribute moderatorThickness : Length;
      attribute thermalizationEfficiency : Probability;
      attribute gammaAttenuationFactor : Probability;
    }

    part def HighVoltageSupply {
      port powerInput : PowerPort;
      port detectorBiasOutput : PowerPort;
      port healthOutput : HealthPort;

      attribute commandedVoltage : Voltage;
      attribute measuredVoltage : Voltage;
      attribute rippleVoltage : Voltage;
      attribute maximumOutputCurrent : Current;
    }

    part def AnalogFrontEnd {
      port pulseInput : SignalPort;
      port eventOutput : EventPort;
      port powerInput : PowerPort;

      attribute preamplifierGain : Real;
      attribute shapingTime : Time;
      attribute discriminatorThreshold : Voltage;
      attribute saturationVoltage : Voltage;

      perform action digitize : ShapeAndDigitizePulse;
    }

    part def DigitalSignalProcessor {
      port eventInput : SignalPort;
      port validatedEventOutput : EventPort;
      port healthOutput : HealthPort;

      attribute gammaRejectionThreshold : Probability;
      attribute deadTime : Time;
      attribute validatedCount : Count;
      attribute rejectedGammaCount : Count;

      perform action rejectBackground : RejectGammaBackground;
      perform action computeRate : ComputeNeutronRate;
    }

    part def AlarmController {
      port eventInput : SignalPort;
      port controlInput : ControlPort;
      port alarmOutput : AlarmPort;
      port healthInput : HealthPort;

      attribute configuredThreshold : CountRate;
      attribute integrationWindow : Time;
      attribute currentNeutronRate : CountRate;
      attribute alarmLatched : Boolean;

      perform action raiseAlarm : AnnunciateAlarm;
      exhibit state operatingState : DetectionOperatingState;
    }

    part def DataLogger {
      port eventInput : SignalPort;
      port recordOutput : DataPort;
      port healthInput : HealthPort;

      attribute storedEventCount : Count;
      attribute availableStorage : DataSize;
      attribute recordRetentionTime : Time;
    }

    part def OperatorDisplay {
      port alarmInput : AlarmPort;
      port healthInput : HealthPort;
      port dataInput : DataPort;
      port controlOutput : ControlPort;

      attribute displayedRate : CountRate;
      attribute displayedThreshold : CountRate;
      attribute alarmVisible : Boolean;
      attribute acquisitionCommand : Boolean;
    }

    part def NeutronDetectionSystem {
      doc /* Primary function: detect neutron radiation, discriminate neutron events from gamma background, estimate neutron count rate, alarm on elevated neutron presence, and log validated detection data. */

      port externalRadiation : NeutronRadiationPort;
      port externalPower : PowerPort;
      port operatorAlarm : AlarmPort;
      port operatorData : DataPort;
      port operatorControl : ControlPort;
      port systemHealth : HealthPort;

      part moderator : ModeratorAssembly {
        attribute moderatorThickness = 75.0;
        attribute thermalizationEfficiency = 0.82;
        attribute gammaAttenuationFactor = 0.65;
      }

      part detector : NeutronDetectorTube {
        attribute fillGasPressure = 4.0;
        attribute converterMaterialThickness = 0.0025;
        attribute operatingVoltage = 1200.0;
        attribute detectorTemperature = 293.15;
        attribute intrinsicThermalNeutronEfficiency = 0.68;
      }

      part highVoltageSupply : HighVoltageSupply {
        attribute commandedVoltage = 1200.0;
        attribute measuredVoltage = 1200.0;
        attribute rippleVoltage = 0.5;
        attribute maximumOutputCurrent = 0.00001;
      }

      part analogFrontEnd : AnalogFrontEnd {
        attribute preamplifierGain = 42.0;
        attribute shapingTime = 0.000002;
        attribute discriminatorThreshold = 0.075;
        attribute saturationVoltage = 5.0;
      }

      part signalProcessor : DigitalSignalProcessor {
        attribute gammaRejectionThreshold = 0.95;
        attribute deadTime = 0.00001;
        attribute validatedCount = 0;
        attribute rejectedGammaCount = 0;
      }

      part alarmController : AlarmController {
        attribute configuredThreshold = 20.0;
        attribute integrationWindow = 10.0;
        attribute currentNeutronRate = 0.0;
        attribute alarmLatched = false;
      }

      part dataLogger : DataLogger {
        attribute storedEventCount = 0;
        attribute availableStorage = 64000000000.0;
        attribute recordRetentionTime = 31536000.0;
      }

      part operatorDisplay : OperatorDisplay {
        attribute displayedRate = 0.0;
        attribute displayedThreshold = 20.0;
        attribute alarmVisible = false;
        attribute acquisitionCommand = true;
      }

      connection radiationToModerator
        connect externalRadiation to moderator.incidentRadiation;

      connection moderatorToDetector
        connect moderator.thermalizedRadiation to detector.radiationInput;

      connection powerToHighVoltage
        connect externalPower to highVoltageSupply.powerInput;

      connection biasToDetector
        connect highVoltageSupply.detectorBiasOutput to detector.highVoltageInput;

      connection detectorPulseToAnalog
        connect detector.pulseOutput to analogFrontEnd.pulseInput;

      connection analogToProcessor
        connect analogFrontEnd.eventOutput to signalProcessor.eventInput;

      connection processorToAlarm
        connect signalProcessor.validatedEventOutput to alarmController.eventInput;

      connection processorToLogger
        connect signalProcessor.validatedEventOutput to dataLogger.eventInput;

      connection alarmToOperator
        connect alarmController.alarmOutput to operatorDisplay.alarmInput;

      connection loggerToOperator
        connect dataLogger.recordOutput to operatorDisplay.dataInput;

      connection displayControlToController
        connect operatorDisplay.controlOutput to alarmController.controlInput;

      connection externalControlToDisplay
        connect operatorControl to operatorDisplay.controlOutput;

      connection alarmExternal
        connect alarmController.alarmOutput to operatorAlarm;

      connection dataExternal
        connect dataLogger.recordOutput to operatorData;

      connection healthHighVoltage
        connect highVoltageSupply.healthOutput to systemHealth;

      connection healthProcessor
        connect signalProcessor.healthOutput to systemHealth;

      satisfy DetectNeutronsRequirement by detector;
      satisfy DetectNeutronsRequirement by signalProcessor;
      satisfy AlarmRequirement by alarmController;
      satisfy HealthMonitoringRequirement by highVoltageSupply;
      satisfy HealthMonitoringRequirement by signalProcessor;
      satisfy DataLoggingRequirement by dataLogger;
    }

    requirement neutronDetectionPerformance : DetectNeutronsRequirement {
      attribute minimumDetectionEfficiency = 0.60;
      attribute maximumGammaFalseAlarmProbability = 0.0001;
    }

    requirement elevatedRateAlarmPerformance : AlarmRequirement {
      attribute responseTimeLimit = 2.0;
      attribute minimumConfidence = 0.95;
    }

    requirement healthReportingPerformance : HealthMonitoringRequirement {
      attribute healthUpdatePeriod = 1.0;
    }

    requirement eventRetentionPerformance : DataLoggingRequirement {
      attribute minimumRetentionTime = 31536000.0;
    }
  }
}