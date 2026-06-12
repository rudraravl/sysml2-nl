package OzoneMonitorSystem {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def partsPerBillion :> ScalarValues::Real;
  attribute def microgramsPerCubicMeter :> ScalarValues::Real;
  attribute def percent :> ScalarValues::Real;
  attribute def seconds :> ScalarValues::Real;
  attribute def degreesCelsius :> ScalarValues::Real;
  attribute def pascal :> ScalarValues::Real;
  attribute def volts :> ScalarValues::Real;
  attribute def amperes :> ScalarValues::Real;
  attribute def watts :> ScalarValues::Real;

  item def AmbientAirSample {
    attribute ozoneConcentration : partsPerBillion;
    attribute temperature : degreesCelsius;
    attribute relativeHumidity : percent;
    attribute pressure : pascal;
    attribute sampledAt : seconds;
  }

  item def FilteredAirSample :> AmbientAirSample {
    attribute particulateReduction : percent;
  }

  item def OzoneMeasurement {
    attribute ozoneConcentration : partsPerBillion;
    attribute uncertainty : partsPerBillion;
    attribute averagingPeriod : seconds;
    attribute valid : Boolean;
    attribute measuredAt : seconds;
  }

  item def CalibrationGasSample {
    attribute certifiedOzoneConcentration : partsPerBillion;
    attribute tolerance : percent;
    attribute flowRate : Real;
  }

  item def MonitorStatus {
    attribute sensorReady : Boolean;
    attribute samplingActive : Boolean;
    attribute calibrationDue : Boolean;
    attribute faultActive : Boolean;
    attribute batteryPercent : percent;
    attribute lastMeasurementValid : Boolean;
  }

  item def AlarmNotification {
    attribute ozoneConcentration : partsPerBillion;
    attribute threshold : partsPerBillion;
    attribute severity : AlarmSeverity;
    attribute generatedAt : seconds;
  }

  enum def AlarmSeverity {
    enum none;
    enum advisory;
    enum warning;
    enum critical;
  }

  port def AirIntakePort {
    in item air : AmbientAirSample;
  }

  port def AirOutletPort {
    out item exhaustedAir : FilteredAirSample;
  }

  port def MeasurementOutputPort {
    out item measurement : OzoneMeasurement;
    out item status : MonitorStatus;
    out item alarm : AlarmNotification;
  }

  port def CalibrationInputPort {
    in item calibrationGas : CalibrationGasSample;
  }

  port def ElectricalPowerPort {
    in attribute supplyVoltage : volts;
    in attribute supplyCurrent : amperes;
    out attribute consumedPower : watts;
  }

  port def LocalUserPort {
    out item displayedMeasurement : OzoneMeasurement;
    out item displayedStatus : MonitorStatus;
    in attribute acknowledgeAlarm : Boolean;
    in attribute startCalibration : Boolean;
  }

  part def AirSamplingSubsystem {
    port intake : AirIntakePort;
    port outlet : AirOutletPort;
    port sampleToSensor {
      out item filteredSample : FilteredAirSample;
    }

    part inletScreen {
      attribute meshEfficiency : percent = 85.0;
    }

    part particulateFilter {
      attribute particulateReduction : percent = 95.0;
      attribute serviceLifeHours : Real = 4380.0;
    }

    part samplePump {
      attribute nominalFlowRate : Real = 1.0;
      attribute flowStability : percent = 2.0;
      attribute powerDraw : watts = 3.5;
    }

    action filterAndMoveAir {
      in item rawAir : AmbientAirSample;
      out item conditionedAir : FilteredAirSample;
    }

    perform action filterAndMoveAir;
  }

  part def OzoneSensingSubsystem {
    port sampleInput {
      in item filteredSample : FilteredAirSample;
    }
    port calibrationInput : CalibrationInputPort;
    port measurementOutput {
      out item measurement : OzoneMeasurement;
    }

    attribute measurementRangeMin : partsPerBillion = 0.0;
    attribute measurementRangeMax : partsPerBillion = 500.0;
    attribute detectionLimit : partsPerBillion = 1.0;
    attribute responseTimeT90 : seconds = 30.0;
    attribute accuracy : partsPerBillion = 2.0;

    part ultravioletLamp {
      attribute wavelengthNanometers : Real = 254.0;
      attribute lampIntensityPercent : percent = 100.0;
      attribute warmupTime : seconds = 120.0;
    }

    part absorptionCell {
      attribute pathLengthCentimeters : Real = 15.0;
      attribute cellTemperature : degreesCelsius;
      attribute cellPressure : pascal;
    }

    part photodiodeDetector {
      attribute darkCurrent : amperes = 0.000000002;
      attribute signalVoltage : volts;
    }

    action measureOzone {
      in item sample : FilteredAirSample;
      out item result : OzoneMeasurement;
    }

    action applyCalibration {
      in item calibrationGas : CalibrationGasSample;
      out attribute calibrationAccepted : Boolean;
    }

    perform action measureOzone;
  }

  part def ProcessingAndControlSubsystem {
    port sensorInput {
      in item rawMeasurement : OzoneMeasurement;
    }
    port statusOutput {
      out item status : MonitorStatus;
    }
    port reportingOutput {
      out item processedMeasurement : OzoneMeasurement;
      out item alarm : AlarmNotification;
    }
    port userInput {
      in attribute acknowledgeAlarm : Boolean;
      in attribute startCalibration : Boolean;
    }

    attribute ozoneAdvisoryThreshold : partsPerBillion = 70.0;
    attribute ozoneWarningThreshold : partsPerBillion = 100.0;
    attribute ozoneCriticalThreshold : partsPerBillion = 200.0;
    attribute averagingPeriod : seconds = 60.0;
    attribute calibrationIntervalHours : Real = 720.0;
    attribute lastCalibrationAgeHours : Real;

    part microcontroller {
      attribute clockFrequencyMHz : Real = 120.0;
      attribute memoryKilobytes : Real = 512.0;
    }

    part dataLogger {
      attribute storageCapacityMeasurements : Integer = 100000;
      attribute retainedMeasurementCount : Integer;
    }

    action validateMeasurement {
      in item rawMeasurement : OzoneMeasurement;
      out item validatedMeasurement : OzoneMeasurement;
    }

    action averageMeasurement {
      in item validatedMeasurement : OzoneMeasurement;
      out item averagedMeasurement : OzoneMeasurement;
    }

    action evaluateAlarm {
      in item averagedMeasurement : OzoneMeasurement;
      out item alarm : AlarmNotification;
    }

    state def MonitorOperatingStates {
      entry action initialize;
      state Off;
      state Starting;
      state Sampling;
      state Reporting;
      state Calibrating;
      state Fault;

      transition first Off;
      transition powerApplied from Off to Starting;
      transition warmupComplete from Starting to Sampling;
      transition measurementAvailable from Sampling to Reporting;
      transition reportComplete from Reporting to Sampling;
      transition calibrationRequested from Sampling to Calibrating;
      transition calibrationComplete from Calibrating to Sampling;
      transition unrecoverableError from Starting to Fault;
      transition sensorFailure from Sampling to Fault;
      transition resetCommanded from Fault to Starting;
    }

    perform action validateMeasurement;
    perform action averageMeasurement;
    perform action evaluateAlarm;
  }

  part def UserInterfaceSubsystem {
    port userPort : LocalUserPort;
    port internalInput {
      in item measurement : OzoneMeasurement;
      in item status : MonitorStatus;
      in item alarm : AlarmNotification;
    }

    part display {
      attribute refreshPeriod : seconds = 1.0;
      attribute brightnessPercent : percent = 80.0;
    }

    part alarmIndicator {
      attribute audibleLevelDecibels : Real = 75.0;
      attribute visualFlashRateHz : Real = 2.0;
    }

    action displayOzoneLevel {
      in item measurement : OzoneMeasurement;
      in item status : MonitorStatus;
    }

    action annunciateAlarm {
      in item alarm : AlarmNotification;
    }

    perform action displayOzoneLevel;
    perform action annunciateAlarm;
  }

  part def PowerSubsystem {
    port powerInput : ElectricalPowerPort;
    port regulatedPowerOutput {
      out attribute regulatedVoltage : volts;
      out attribute availableCurrent : amperes;
    }

    attribute inputVoltageMin : volts = 10.0;
    attribute inputVoltageMax : volts = 30.0;
    attribute nominalConsumedPower : watts = 8.0;

    part dcDcConverter {
      attribute outputVoltage : volts = 5.0;
      attribute efficiency : percent = 90.0;
    }

    part backupBattery {
      attribute nominalVoltage : volts = 7.4;
      attribute capacityAmpHours : Real = 2.5;
      attribute stateOfCharge : percent;
    }
  }

  part def OzoneMonitor {
    doc /* The OzoneMonitor continuously samples ambient air, measures ozone concentration, validates and averages the result, reports current ozone level and monitor status, and generates alarms when ozone exceeds configured health or safety thresholds. */

    port ambientAirIn : AirIntakePort;
    port exhaustAirOut : AirOutletPort;
    port powerIn : ElectricalPowerPort;
    port calibrationGasIn : CalibrationInputPort;
    port monitorOutput : MeasurementOutputPort;
    port localUser : LocalUserPort;

    attribute installedHeightMeters : Real = 1.5;
    attribute operatingTemperatureMin : degreesCelsius = -10.0;
    attribute operatingTemperatureMax : degreesCelsius = 50.0;
    attribute operatingHumidityMax : percent = 95.0;
    attribute measurementUpdatePeriod : seconds = 1.0;

    part sampler : AirSamplingSubsystem;
    part sensor : OzoneSensingSubsystem;
    part controller : ProcessingAndControlSubsystem;
    part userInterface : UserInterfaceSubsystem;
    part power : PowerSubsystem;

    connect ambientAirIn to sampler.intake;
    connect sampler.outlet to exhaustAirOut;
    connect sampler.sampleToSensor to sensor.sampleInput;
    connect calibrationGasIn to sensor.calibrationInput;
    connect sensor.measurementOutput to controller.sensorInput;
    connect controller.reportingOutput to monitorOutput;
    connect controller.statusOutput to monitorOutput;
    connect controller.reportingOutput to userInterface.internalInput;
    connect controller.statusOutput to userInterface.internalInput;
    connect localUser to userInterface.userPort;
    connect localUser to controller.userInput;
    connect powerIn to power.powerInput;

    action primaryFunction {
      in item ambientAir : AmbientAirSample;
      out item ozoneLevel : OzoneMeasurement;
      out item monitorStatus : MonitorStatus;
      out item alarmNotice : AlarmNotification;

      first start;
      then sampleAir;
      then filterSample;
      then measureConcentration;
      then validateAndAverage;
      then reportLevel;
      then evaluateThresholds;
      then updateStatus;
      then done;
    }
  }

  requirement def MonitorPrimaryFunctionRequirement {
    doc /* The ozone monitor shall continuously determine ozone concentration in ambient air and provide a valid concentration reading, operating status, and threshold alarm indication. */
    subject monitor : OzoneMonitor;

    require constraint {
      monitor.measurementUpdatePeriod <= 1.0
    }
  }

  requirement def MeasurementRangeRequirement {
    doc /* The ozone monitor shall measure ozone concentrations from 0 ppb through 500 ppb. */
    subject monitor : OzoneMonitor;

    require constraint {
      monitor.sensor.measurementRangeMin <= 0.0 and
      monitor.sensor.measurementRangeMax >= 500.0
    }
  }

  requirement def AccuracyRequirement {
    doc /* The ozone sensing subsystem shall report ozone concentration with uncertainty no greater than 2 ppb under nominal operating conditions. */
    subject monitor : OzoneMonitor;

    require constraint {
      monitor.sensor.accuracy <= 2.0
    }
  }

  requirement def AlarmRequirement {
    doc /* The ozone monitor shall generate advisory, warning, and critical alarm notifications when measured ozone concentration exceeds configured thresholds. */
    subject monitor : OzoneMonitor;

    require constraint {
      monitor.controller.ozoneAdvisoryThreshold < monitor.controller.ozoneWarningThreshold and
      monitor.controller.ozoneWarningThreshold < monitor.controller.ozoneCriticalThreshold
    }
  }

  requirement def EnvironmentalOperatingRequirement {
    doc /* The ozone monitor shall operate across the expected outdoor monitoring environment. */
    subject monitor : OzoneMonitor;

    require constraint {
      monitor.operatingTemperatureMin <= -10.0 and
      monitor.operatingTemperatureMax >= 50.0 and
      monitor.operatingHumidityMax >= 95.0
    }
  }

  requirement def PowerRequirement {
    doc /* The ozone monitor shall consume no more than 10 W during normal sampling and reporting operation. */
    subject monitor : OzoneMonitor;

    require constraint {
      monitor.power.nominalConsumedPower <= 10.0
    }
  }

  satisfy MonitorPrimaryFunctionRequirement by OzoneMonitor::primaryFunction;
  satisfy MeasurementRangeRequirement by OzoneMonitor::sensor;
  satisfy AccuracyRequirement by OzoneMonitor::sensor;
  satisfy AlarmRequirement by OzoneMonitor::controller;
  satisfy EnvironmentalOperatingRequirement by OzoneMonitor;
  satisfy PowerRequirement by OzoneMonitor::power;

}