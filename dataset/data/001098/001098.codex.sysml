package InclinometerSystemModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Angle {
    :> real;
    unit = deg;
  }

  attribute def AngularRate {
    :> real;
    unit = deg / s;
  }

  attribute def Acceleration {
    :> real;
    unit = m / s^2;
  }

  attribute def Voltage {
    :> real;
    unit = V;
  }

  attribute def Current {
    :> real;
    unit = A;
  }

  attribute def Temperature {
    :> real;
    unit = degC;
  }

  attribute def TimeDuration {
    :> real;
    unit = s;
  }

  attribute def Percent {
    :> real;
    unit = one;
  }

  item def RawAccelerationSample {
    attribute ax : Acceleration;
    attribute ay : Acceleration;
    attribute az : Acceleration;
    attribute sampleTime : TimeDuration;
    attribute sensorTemperature : Temperature;
  }

  item def FilteredTiltSample {
    attribute pitch : Angle;
    attribute roll : Angle;
    attribute confidence : Percent;
    attribute sampleTime : TimeDuration;
  }

  item def CalibratedTiltMeasurement {
    attribute pitch : Angle;
    attribute roll : Angle;
    attribute zeroOffsetPitch : Angle;
    attribute zeroOffsetRoll : Angle;
    attribute accuracy : Angle;
    attribute sampleTime : TimeDuration;
  }

  item def PowerInput {
    attribute supplyVoltage : Voltage;
    attribute supplyCurrent : Current;
  }

  item def DisplayCommand {
    attribute displayedPitch : Angle;
    attribute displayedRoll : Angle;
    attribute alarmActive : Boolean;
  }

  item def UserCommand {
    attribute zeroRequest : Boolean;
    attribute holdRequest : Boolean;
    attribute unitsSelectDegrees : Boolean;
  }

  item def AlarmSignal {
    attribute alarmActive : Boolean;
    attribute thresholdExceeded : Boolean;
    attribute thresholdAngle : Angle;
  }

  port def PowerPort {
    in item power : PowerInput;
  }

  port def AccelerationDataPort {
    out item sample : RawAccelerationSample;
  }

  port def TiltDataPort {
    out item measurement : CalibratedTiltMeasurement;
  }

  port def DisplayPort {
    in item command : DisplayCommand;
  }

  port def UserInputPort {
    out item command : UserCommand;
  }

  port def AlarmPort {
    out item alarm : AlarmSignal;
  }

  part def MEMSTiltSensor {
    port powerPort : PowerPort;
    port accelerationOut : AccelerationDataPort;

    attribute measurementRange : Angle = 90 [deg];
    attribute noiseDensity : Acceleration = 0.002 [m / s^2];
    attribute operatingTemperatureMin : Temperature = -20 [degC];
    attribute operatingTemperatureMax : Temperature = 70 [degC];

    action senseGravityVector {
      in item supply : PowerInput;
      out item rawSample : RawAccelerationSample;
    }
  }

  part def SignalConditioner {
    port accelerationIn : AccelerationDataPort;
    port filteredTiltOut : TiltDataPort;

    attribute lowPassCutoffFrequency : Real = 5.0;
    attribute samplePeriod : TimeDuration = 0.02 [s];

    action convertAccelerationToTilt {
      in item rawSample : RawAccelerationSample;
      out item tiltSample : FilteredTiltSample;
    }

    action rejectVibrationNoise {
      in item tiltSample : FilteredTiltSample;
      out item filteredTilt : FilteredTiltSample;
    }
  }

  part def CalibrationProcessor {
    port filteredTiltIn : TiltDataPort;
    port calibratedTiltOut : TiltDataPort;
    port userCommandIn : UserInputPort;

    attribute storedZeroPitch : Angle = 0 [deg];
    attribute storedZeroRoll : Angle = 0 [deg];
    attribute maximumCalibrationOffset : Angle = 10 [deg];

    action applyZeroOffset {
      in item filteredTilt : FilteredTiltSample;
      in item command : UserCommand;
      out item calibratedTilt : CalibratedTiltMeasurement;
    }

    action updateZeroReference {
      in item filteredTilt : FilteredTiltSample;
      out item zeroPitch : Angle;
      out item zeroRoll : Angle;
    }
  }

  part def DisplayUnit {
    port displayIn : DisplayPort;

    attribute resolution : Angle = 0.1 [deg];
    attribute refreshPeriod : TimeDuration = 0.1 [s];

    action renderTilt {
      in item command : DisplayCommand;
    }
  }

  part def UserInterface {
    port userCommandOut : UserInputPort;

    attribute hasZeroButton : Boolean = true;
    attribute hasHoldButton : Boolean = true;

    action readButtons {
      out item command : UserCommand;
    }
  }

  part def AlarmEvaluator {
    port tiltIn : TiltDataPort;
    port alarmOut : AlarmPort;

    attribute alarmThreshold : Angle = 45 [deg];
    attribute hysteresis : Angle = 2 [deg];

    action evaluateThreshold {
      in item measurement : CalibratedTiltMeasurement;
      out item alarm : AlarmSignal;
    }
  }

  part def PowerRegulator {
    port powerInput : PowerPort;
    port regulatedSensorPower : PowerPort;
    port regulatedLogicPower : PowerPort;

    attribute inputVoltageMin : Voltage = 9 [V];
    attribute inputVoltageMax : Voltage = 32 [V];
    attribute regulatedVoltage : Voltage = 3.3 [V];
    attribute maximumCurrent : Current = 0.2 [A];

    action regulateInputPower {
      in item externalPower : PowerInput;
      out item regulatedPower : PowerInput;
    }
  }

  part def Inclinometer {
    port externalPower : PowerPort;
    port userInput : UserInputPort;
    port tiltOutput : TiltDataPort;
    port alarmOutput : AlarmPort;
    port displayCommandOutput : DisplayPort;

    part powerRegulator : PowerRegulator;
    part tiltSensor : MEMSTiltSensor;
    part signalConditioner : SignalConditioner;
    part calibrationProcessor : CalibrationProcessor;
    part alarmEvaluator : AlarmEvaluator;
    part displayUnit : DisplayUnit;
    part userInterface : UserInterface;

    attribute pitchMeasurementRange : Angle = 90 [deg];
    attribute rollMeasurementRange : Angle = 90 [deg];
    attribute staticAccuracy : Angle = 0.5 [deg];
    attribute startupTime : TimeDuration = 2 [s];
    attribute updatePeriod : TimeDuration = 0.1 [s];

    connect externalPower to powerRegulator.powerInput;
    connect powerRegulator.regulatedSensorPower to tiltSensor.powerPort;
    connect tiltSensor.accelerationOut to signalConditioner.accelerationIn;
    connect signalConditioner.filteredTiltOut to calibrationProcessor.filteredTiltIn;
    connect userInterface.userCommandOut to calibrationProcessor.userCommandIn;
    connect calibrationProcessor.calibratedTiltOut to alarmEvaluator.tiltIn;
    connect calibrationProcessor.calibratedTiltOut to tiltOutput;
    connect alarmEvaluator.alarmOut to alarmOutput;
    connect userInterface.userCommandOut to userInput;

    action measureInclination {
      in item rawSample : RawAccelerationSample;
      out item measurement : CalibratedTiltMeasurement;

      first start;
      then senseGravity;
      then filterTilt;
      then calibrateTilt;
      then publishTilt;
      then done;

      action senseGravity {
        out item rawSample : RawAccelerationSample;
      }

      action filterTilt {
        in item rawSample : RawAccelerationSample;
        out item filteredTilt : FilteredTiltSample;
      }

      action calibrateTilt {
        in item filteredTilt : FilteredTiltSample;
        out item measurement : CalibratedTiltMeasurement;
      }

      action publishTilt {
        in item measurement : CalibratedTiltMeasurement;
      }
    }

    state def OperatingStateMachine {
      entry action initializeElectronics;
      exit action storeLastMeasurement;

      state Off;
      state Starting;
      state Measuring;
      state Zeroing;
      state Hold;
      state Fault;

      transition initial then Off;
      transition Off_to_Starting
        first Off
        accept when externalPower.power.supplyVoltage >= 9 [V]
        then Starting;

      transition Starting_to_Measuring
        first Starting
        accept after 2 [s]
        then Measuring;

      transition Measuring_to_Zeroing
        first Measuring
        accept when userInterface.userCommandOut.command.zeroRequest == true
        then Zeroing;

      transition Zeroing_to_Measuring
        first Zeroing
        accept after 0.5 [s]
        then Measuring;

      transition Measuring_to_Hold
        first Measuring
        accept when userInterface.userCommandOut.command.holdRequest == true
        then Hold;

      transition Hold_to_Measuring
        first Hold
        accept when userInterface.userCommandOut.command.holdRequest == false
        then Measuring;

      transition Measuring_to_Fault
        first Measuring
        accept when calibrationProcessor.calibratedTiltOut.measurement.confidence < 0.5
        then Fault;

      transition Fault_to_Starting
        first Fault
        accept when externalPower.power.supplyVoltage >= 9 [V]
        then Starting;
    }
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The inclinometer shall determine the angular inclination of its body relative to the gravity vector and provide calibrated pitch and roll measurements for display, output, and alarm evaluation. */

    subject inclinometer : Inclinometer;

    require constraint {
      inclinometer.staticAccuracy <= 0.5 [deg]
    }
  }

  requirement def MeasurementRangeRequirement {
    doc /* The inclinometer shall measure pitch and roll over at least plus or minus 90 degrees. */

    subject inclinometer : Inclinometer;

    require constraint {
      inclinometer.pitchMeasurementRange >= 90 [deg] and
      inclinometer.rollMeasurementRange >= 90 [deg]
    }
  }

  requirement def UpdateRateRequirement {
    doc /* The inclinometer shall update calibrated inclination output at least every 100 milliseconds during normal measuring operation. */

    subject inclinometer : Inclinometer;

    require constraint {
      inclinometer.updatePeriod <= 0.1 [s]
    }
  }

  requirement def AlarmRequirement {
    doc /* The inclinometer shall assert an alarm when the absolute value of pitch or roll exceeds the configured alarm threshold. */

    subject alarmEvaluator : AlarmEvaluator;

    require constraint {
      alarmEvaluator.alarmThreshold == 45 [deg]
    }
  }

  requirement def StartupRequirement {
    doc /* The inclinometer shall become ready to measure inclination within two seconds after valid input power is applied. */

    subject inclinometer : Inclinometer;

    require constraint {
      inclinometer.startupTime <= 2 [s]
    }
  }

  requirement def PowerRequirement {
    doc /* The inclinometer shall operate from an external direct-current supply between 9 volts and 32 volts. */

    subject regulator : PowerRegulator;

    require constraint {
      regulator.inputVoltageMin <= 9 [V] and
      regulator.inputVoltageMax >= 32 [V]
    }
  }

  part inclinometerSystem : Inclinometer;

  satisfy PrimaryFunctionRequirement by inclinometerSystem;
  satisfy MeasurementRangeRequirement by inclinometerSystem;
  satisfy UpdateRateRequirement by inclinometerSystem;
  satisfy StartupRequirement by inclinometerSystem;
  satisfy AlarmRequirement by inclinometerSystem.alarmEvaluator;
  satisfy PowerRequirement by inclinometerSystem.powerRegulator;
}