package ABSWheelSpeedSensingUnitModel {
  import ScalarValues::*;
  import SI::*;

  attribute def WheelAngularSpeed :> Real {
    unit = "rad/s";
    doc = "Angular velocity of the sensed wheel.";
  }

  attribute def WheelLinearSpeed :> Real {
    unit = "m/s";
  }

  attribute def ToothPassingFrequency :> Real {
    unit = "Hz";
  }

  attribute def Voltage :> Real {
    unit = "V";
  }

  attribute def Current :> Real {
    unit = "A";
  }

  attribute def Temperature :> Real {
    unit = "degC";
  }

  attribute def TimeDuration :> Real {
    unit = "s";
  }

  attribute def Distance :> Real {
    unit = "mm";
  }

  attribute def ToothCount :> Integer;

  enum def SensingUnitState {
    enum idle;
    enum initializing;
    enum measuring;
    enum degraded;
    enum failed;
  }

  item def MagneticFieldVariation {
    attribute frequency : ToothPassingFrequency;
    attribute amplitude : Real;
  }

  item def PulseTrain {
    attribute frequency : ToothPassingFrequency;
    attribute dutyCycle : Real;
    attribute highVoltage : Voltage;
    attribute lowVoltage : Voltage;
  }

  item def WheelSpeedSample {
    attribute angularSpeed : WheelAngularSpeed;
    attribute linearSpeed : WheelLinearSpeed;
    attribute timestamp : TimeDuration;
    attribute valid : Boolean;
  }

  item def DiagnosticMessage {
    attribute sensorOpenCircuit : Boolean;
    attribute sensorShortCircuit : Boolean;
    attribute signalOutOfRange : Boolean;
    attribute excessiveAirGap : Boolean;
    attribute internalFailure : Boolean;
  }

  port def PowerInputPort {
    in attribute supplyVoltage : Voltage;
    in attribute supplyCurrent : Current;
  }

  port def GroundPort {
    out attribute returnCurrent : Current;
  }

  port def MagneticPickupPort {
    in item fieldVariation : MagneticFieldVariation;
  }

  port def PulseOutputPort {
    out item pulses : PulseTrain;
  }

  port def SpeedDataPort {
    out item speedSample : WheelSpeedSample;
  }

  port def DiagnosticPort {
    out item diagnostic : DiagnosticMessage;
  }

  port def MountingPort {
    attribute airGap : Distance;
    attribute axialOffset : Distance;
    attribute radialOffset : Distance;
  }

  part def ToneRing {
    attribute teeth : ToothCount = 48;
    attribute wheelRadius : Distance = 315.0;
    attribute angularSpeed : WheelAngularSpeed;
    port magneticPatternOut : MagneticPickupPort;
  }

  part def ABSSensor {
    attribute supplyVoltageNominal : Voltage = 12.0;
    attribute supplyVoltageMinimum : Voltage = 8.0;
    attribute supplyVoltageMaximum : Voltage = 16.0;
    attribute operatingTemperatureMinimum : Temperature = -40.0;
    attribute operatingTemperatureMaximum : Temperature = 125.0;
    attribute airGapMinimum : Distance = 0.4;
    attribute airGapMaximum : Distance = 1.8;
    attribute detectedFrequency : ToothPassingFrequency;
    attribute sensorHealthy : Boolean;

    port power : PowerInputPort;
    port ground : GroundPort;
    port magneticInput : MagneticPickupPort;
    port pulseOutput : PulseOutputPort;
    port diagnostics : DiagnosticPort;
    port mount : MountingPort;

    action def ConvertMagneticFieldToPulses {
      in item magneticInput : MagneticFieldVariation;
      out item pulseOutput : PulseTrain;

      assert constraint {
        pulseOutput.frequency == magneticInput.frequency
      }
    }

    state def SensorOperationalState {
      state off;
      state selfTest;
      state active;
      state degraded;
      state failed;

      transition first off;
      transition off_to_selfTest
        first off then selfTest
        accept PowerApplied;

      transition selfTest_to_active
        first selfTest then active
        if sensorHealthy;

      transition selfTest_to_failed
        first selfTest then failed
        if not sensorHealthy;

      transition active_to_degraded
        first active then degraded
        if mount.airGap > airGapMaximum;

      transition degraded_to_active
        first degraded then active
        if mount.airGap <= airGapMaximum;

      transition active_to_failed
        first active then failed
        if power.supplyVoltage < supplyVoltageMinimum or power.supplyVoltage > supplyVoltageMaximum;
    }
  }

  part def SignalConditioner {
    attribute inputFrequency : ToothPassingFrequency;
    attribute outputFrequency : ToothPassingFrequency;
    attribute debounceTime : TimeDuration = 0.00002;
    attribute minimumDetectableFrequency : ToothPassingFrequency = 1.0;
    attribute maximumDetectableFrequency : ToothPassingFrequency = 2500.0;

    port rawPulseIn : PulseOutputPort;
    port conditionedPulseOut : PulseOutputPort;
    port diagnostics : DiagnosticPort;

    action def FilterAndShapePulseTrain {
      in item rawPulse : PulseTrain;
      out item conditionedPulse : PulseTrain;

      assert constraint {
        conditionedPulse.frequency == rawPulse.frequency
      }
    }
  }

  part def WheelSpeedProcessor {
    attribute teethPerRevolution : ToothCount = 48;
    attribute wheelRadius : Distance = 315.0;
    attribute measuredFrequency : ToothPassingFrequency;
    attribute computedAngularSpeed : WheelAngularSpeed;
    attribute computedLinearSpeed : WheelLinearSpeed;
    attribute samplePeriod : TimeDuration = 0.010;

    port pulseIn : PulseOutputPort;
    port speedOut : SpeedDataPort;
    port diagnostics : DiagnosticPort;

    action def CalculateWheelSpeed {
      in item pulseTrain : PulseTrain;
      out item sample : WheelSpeedSample;

      assert constraint {
        sample.angularSpeed == 6.283185307 * pulseTrain.frequency / teethPerRevolution
      }

      assert constraint {
        sample.linearSpeed == sample.angularSpeed * wheelRadius / 1000.0
      }
    }
  }

  part def SensingUnitHousing {
    attribute ingressProtectionRating : String = "IP67";
    attribute minimumOperatingTemperature : Temperature = -40.0;
    attribute maximumOperatingTemperature : Temperature = 125.0;
    port mounting : MountingPort;
  }

  part def ABSWheelSpeedSensingUnit {
    attribute state : SensingUnitState;
    attribute nominalSupplyVoltage : Voltage = 12.0;
    attribute maximumCurrentDraw : Current = 0.025;
    attribute measurementUpdatePeriod : TimeDuration = 0.010;
    attribute requiredAirGap : Distance = 1.0;

    port powerIn : PowerInputPort;
    port ground : GroundPort;
    port mountingInterface : MountingPort;
    port speedOutput : SpeedDataPort;
    port diagnosticOutput : DiagnosticPort;

    part toneRing : ToneRing;
    part absSensor : ABSSensor;
    part conditioner : SignalConditioner;
    part processor : WheelSpeedProcessor;
    part housing : SensingUnitHousing;

    connect powerIn to absSensor.power;
    connect ground to absSensor.ground;
    connect mountingInterface to absSensor.mount;
    connect mountingInterface to housing.mounting;
    connect toneRing.magneticPatternOut to absSensor.magneticInput;
    connect absSensor.pulseOutput to conditioner.rawPulseIn;
    connect conditioner.conditionedPulseOut to processor.pulseIn;
    connect processor.speedOut to speedOutput;
    connect absSensor.diagnostics to diagnosticOutput;
    connect conditioner.diagnostics to diagnosticOutput;
    connect processor.diagnostics to diagnosticOutput;

    action def MeasureWheelSpeed {
      in attribute wheelAngularSpeed : WheelAngularSpeed;
      out item measuredSpeed : WheelSpeedSample;

      first start;
      then senseMagneticPattern;
      then generatePulseTrain;
      then conditionPulseTrain;
      then computeWheelSpeed;
      then publishSpeedSample;
      then done;
    }

    state def UnitStateMachine {
      state idle;
      state initializing;
      state measuring;
      state degraded;
      state failed;

      transition initial_to_idle first idle;

      transition idle_to_initializing
        first idle then initializing
        accept PowerApplied;

      transition initializing_to_measuring
        first initializing then measuring
        if absSensor.sensorHealthy;

      transition initializing_to_failed
        first initializing then failed
        if not absSensor.sensorHealthy;

      transition measuring_to_degraded
        first measuring then degraded
        if mountingInterface.airGap > absSensor.airGapMaximum;

      transition degraded_to_measuring
        first degraded then measuring
        if mountingInterface.airGap <= absSensor.airGapMaximum;

      transition measuring_to_failed
        first measuring then failed
        if powerIn.supplyVoltage < absSensor.supplyVoltageMinimum or powerIn.supplyVoltage > absSensor.supplyVoltageMaximum;
    }
  }

  requirement def MeasureWheelSpeedUsingABSSensor {
    subject sensingUnit : ABSWheelSpeedSensingUnit;

    require constraint {
      sensingUnit.processor.computedAngularSpeed ==
      6.283185307 * sensingUnit.processor.measuredFrequency /
      sensingUnit.processor.teethPerRevolution
    }
  }

  requirement def MeasurementRangeRequirement {
    subject sensingUnit : ABSWheelSpeedSensingUnit;

    require constraint {
      sensingUnit.conditioner.minimumDetectableFrequency <= sensingUnit.processor.measuredFrequency and
      sensingUnit.processor.measuredFrequency <= sensingUnit.conditioner.maximumDetectableFrequency
    }
  }

  requirement def AirGapRequirement {
    subject sensingUnit : ABSWheelSpeedSensingUnit;

    require constraint {
      sensingUnit.absSensor.airGapMinimum <= sensingUnit.mountingInterface.airGap and
      sensingUnit.mountingInterface.airGap <= sensingUnit.absSensor.airGapMaximum
    }
  }

  requirement def SupplyVoltageRequirement {
    subject sensingUnit : ABSWheelSpeedSensingUnit;

    require constraint {
      sensingUnit.absSensor.supplyVoltageMinimum <= sensingUnit.powerIn.supplyVoltage and
      sensingUnit.powerIn.supplyVoltage <= sensingUnit.absSensor.supplyVoltageMaximum
    }
  }

  requirement def UpdateRateRequirement {
    subject sensingUnit : ABSWheelSpeedSensingUnit;

    require constraint {
      sensingUnit.measurementUpdatePeriod <= 0.010
    }
  }

  requirement def DiagnosticRequirement {
    subject sensingUnit : ABSWheelSpeedSensingUnit;

    require constraint {
      sensingUnit.diagnosticOutput.diagnostic.sensorOpenCircuit or
      sensingUnit.diagnosticOutput.diagnostic.sensorShortCircuit or
      sensingUnit.diagnosticOutput.diagnostic.signalOutOfRange or
      sensingUnit.diagnosticOutput.diagnostic.excessiveAirGap or
      sensingUnit.diagnosticOutput.diagnostic.internalFailure or
      sensingUnit.speedOutput.speedSample.valid
    }
  }

  part absWheelSpeedSensingUnit : ABSWheelSpeedSensingUnit;
}