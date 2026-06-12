package InfraredPointSensingUnitModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Distance :> ISQ::length {
    unit = SI::metre;
  }

  attribute def Angle :> ISQ::planeAngle {
    unit = SI::radian;
  }

  attribute def Irradiance :> ISQ::irradiance {
    unit = SI::wattPerSquareMetre;
  }

  attribute def Voltage :> ISQ::electricPotential {
    unit = SI::volt;
  }

  attribute def Current :> ISQ::electricCurrent {
    unit = SI::ampere;
  }

  attribute def Power :> ISQ::power {
    unit = SI::watt;
  }

  attribute def Temperature :> ISQ::thermodynamicTemperature {
    unit = SI::kelvin;
  }

  attribute def Time :> ISQ::time {
    unit = SI::second;
  }

  attribute def Frequency :> ISQ::frequency {
    unit = SI::hertz;
  }

  attribute def Probability :> ScalarValues::Real {
    range = "0..1";
  }

  item def OpticalEmission {
    attribute wavelength : ISQ::length;
    attribute radiantPower : Power;
    attribute modulationFrequency : Frequency;
    attribute beamHalfAngle : Angle;
  }

  item def ReflectedInfraredSignal {
    attribute irradiance : Irradiance;
    attribute phaseDelay : Time;
    attribute backgroundIrradiance : Irradiance;
    attribute incidenceAngle : Angle;
  }

  item def AnalogSensorSignal {
    attribute voltage : Voltage;
    attribute noiseRms : Voltage;
    attribute sampleTime : Time;
  }

  item def DigitalSample {
    attribute adcCount : Integer;
    attribute voltage : Voltage;
    attribute timestamp : Time;
  }

  item def DistanceMeasurement {
    attribute measuredDistance : Distance;
    attribute uncertainty : Distance;
    attribute confidence : Probability;
    attribute timestamp : Time;
  }

  item def HealthStatus {
    attribute emitterOperational : Boolean;
    attribute detectorOperational : Boolean;
    attribute electronicsOperational : Boolean;
    attribute temperatureWithinLimits : Boolean;
    attribute faultCode : Integer;
  }

  port def PowerPort {
    in item supplyVoltage : Voltage;
    in item supplyCurrent : Current;
  }

  port def OpticalTransmitPort {
    out item emittedBeam : OpticalEmission;
  }

  port def OpticalReceivePort {
    in item reflectedBeam : ReflectedInfraredSignal;
  }

  port def AnalogSignalPort {
    out item signal : AnalogSensorSignal;
  }

  port def DigitalSignalPort {
    out item sample : DigitalSample;
  }

  port def MeasurementOutputPort {
    out item distance : DistanceMeasurement;
    out item status : HealthStatus;
  }

  port def ControlPort {
    in item enable : Boolean;
    in item reset : Boolean;
    in item calibrationRequest : Boolean;
  }

  part def InfraredEmitter {
    attribute nominalWavelength : ISQ::length = 940 [SI::nanometre];
    attribute radiantPowerNominal : Power = 45 [SI::milliwatt];
    attribute beamHalfAngle : Angle = 0.21 [SI::radian];
    attribute modulationFrequency : Frequency = 38 [SI::kilohertz];
    attribute forwardVoltage : Voltage = 1.35 [SI::volt];
    attribute driveCurrent : Current = 80 [SI::milliampere];

    port power : PowerPort;
    port opticalOut : OpticalTransmitPort;
    port control : ControlPort;

    action emitModulatedInfrared {
      in enableEmitter : Boolean;
      out opticalEmission : OpticalEmission;

      first start;
      then decide;
      if enableEmitter then generateBeam;
      else noEmission;
      then done;

      action generateBeam {
        opticalEmission.wavelength = nominalWavelength;
        opticalEmission.radiantPower = radiantPowerNominal;
        opticalEmission.modulationFrequency = modulationFrequency;
        opticalEmission.beamHalfAngle = beamHalfAngle;
      }

      action noEmission {
        opticalEmission.wavelength = nominalWavelength;
        opticalEmission.radiantPower = 0 [SI::watt];
        opticalEmission.modulationFrequency = modulationFrequency;
        opticalEmission.beamHalfAngle = beamHalfAngle;
      }
    }
  }

  part def InfraredPhotodetector {
    attribute peakSensitivityWavelength : ISQ::length = 940 [SI::nanometre];
    attribute responsivity : Real = 0.55;
    attribute darkCurrent : Current = 25 [SI::nanoampere];
    attribute fieldOfViewHalfAngle : Angle = 0.26 [SI::radian];
    attribute saturationIrradiance : Irradiance = 120 [SI::wattPerSquareMetre];

    port opticalIn : OpticalReceivePort;
    port analogOut : AnalogSignalPort;
    port power : PowerPort;

    action convertOpticalToAnalog {
      in reflectedSignal : ReflectedInfraredSignal;
      out analogSignal : AnalogSensorSignal;

      first evaluateRange;
      then produceVoltage;
      then done;

      action evaluateRange {
        assert reflectedSignal.irradiance <= saturationIrradiance;
      }

      action produceVoltage {
        analogSignal.voltage = reflectedSignal.irradiance * 0.018 [SI::volt];
        analogSignal.noiseRms = 0.004 [SI::volt];
        analogSignal.sampleTime = reflectedSignal.phaseDelay;
      }
    }
  }

  part def AnalogFrontEnd {
    attribute transimpedanceGain : Real = 220000;
    attribute bandPassCenterFrequency : Frequency = 38 [SI::kilohertz];
    attribute bandPassBandwidth : Frequency = 6 [SI::kilohertz];
    attribute outputMinVoltage : Voltage = 0 [SI::volt];
    attribute outputMaxVoltage : Voltage = 3.3 [SI::volt];

    port analogIn : AnalogSignalPort;
    port analogOut : AnalogSignalPort;
    port power : PowerPort;

    action filterAndAmplify {
      in rawSignal : AnalogSensorSignal;
      out conditionedSignal : AnalogSensorSignal;

      first rejectAmbient;
      then amplify;
      then limitOutput;
      then done;

      action rejectAmbient {
        conditionedSignal.noiseRms = rawSignal.noiseRms * 0.35;
      }

      action amplify {
        conditionedSignal.voltage = rawSignal.voltage * 14.0;
        conditionedSignal.sampleTime = rawSignal.sampleTime;
      }

      action limitOutput {
        if conditionedSignal.voltage > outputMaxVoltage {
          conditionedSignal.voltage = outputMaxVoltage;
        }
        if conditionedSignal.voltage < outputMinVoltage {
          conditionedSignal.voltage = outputMinVoltage;
        }
      }
    }
  }

  part def AnalogToDigitalConverter {
    attribute resolutionBits : Integer = 12;
    attribute referenceVoltage : Voltage = 3.3 [SI::volt];
    attribute sampleRate : Frequency = 2 [SI::kilohertz];
    attribute conversionTime : Time = 12 [SI::microsecond];

    port analogIn : AnalogSignalPort;
    port digitalOut : DigitalSignalPort;
    port power : PowerPort;

    action sampleSignal {
      in conditionedSignal : AnalogSensorSignal;
      out sample : DigitalSample;

      first acquire;
      then quantize;
      then timestamp;
      then done;

      action acquire {
        sample.voltage = conditionedSignal.voltage;
      }

      action quantize {
        sample.adcCount = Integer((conditionedSignal.voltage / referenceVoltage) * 4095);
      }

      action timestamp {
        sample.timestamp = conditionedSignal.sampleTime + conversionTime;
      }
    }
  }

  part def ProcessingController {
    attribute minimumValidDistance : Distance = 0.04 [SI::metre];
    attribute maximumValidDistance : Distance = 1.50 [SI::metre];
    attribute measurementPeriod : Time = 0.010 [SI::second];
    attribute calibrationOffset : Distance = 0.0 [SI::metre];
    attribute conversionSlope : Real = 0.00042;
    attribute faultCodeNone : Integer = 0;
    attribute faultCodeNoSignal : Integer = 11;
    attribute faultCodeSaturated : Integer = 12;
    attribute faultCodeOutOfRange : Integer = 13;

    port digitalIn : DigitalSignalPort;
    port measurementOut : MeasurementOutputPort;
    port control : ControlPort;
    port power : PowerPort;

    state def ControllerStateMachine {
      state off;
      state initializing;
      state selfTest;
      state calibrating;
      state measuring;
      state reporting;
      state fault;

      initial then off;

      transition off_to_initializing
        first off
        accept control.enable
        then initializing;

      transition initializing_to_selfTest
        first initializing
        after 20 [SI::millisecond]
        then selfTest;

      transition selfTest_to_calibrating
        first selfTest
        if selfTestPassed
        then calibrating;

      transition selfTest_to_fault
        first selfTest
        if not selfTestPassed
        then fault;

      transition calibrating_to_measuring
        first calibrating
        after 50 [SI::millisecond]
        then measuring;

      transition measuring_to_reporting
        first measuring
        after measurementPeriod
        then reporting;

      transition reporting_to_measuring
        first reporting
        then measuring;

      transition measuring_to_fault
        first measuring
        if measurementFaultDetected
        then fault;

      transition fault_to_initializing
        first fault
        accept control.reset
        then initializing;
    }

    action computeDistance {
      in sample : DigitalSample;
      out measurement : DistanceMeasurement;
      out status : HealthStatus;

      first validateSignal;
      then convertSample;
      then applyCalibration;
      then evaluateConfidence;
      then publishHealth;
      then done;

      action validateSignal {
        if sample.adcCount <= 8 {
          status.faultCode = faultCodeNoSignal;
        }
        if sample.adcCount >= 4088 {
          status.faultCode = faultCodeSaturated;
        }
      }

      action convertSample {
        measurement.measuredDistance = (conversionSlope * Real(sample.adcCount)) [SI::metre];
        measurement.timestamp = sample.timestamp;
      }

      action applyCalibration {
        measurement.measuredDistance = measurement.measuredDistance + calibrationOffset;
      }

      action evaluateConfidence {
        if measurement.measuredDistance < minimumValidDistance or measurement.measuredDistance > maximumValidDistance {
          status.faultCode = faultCodeOutOfRange;
          measurement.confidence = 0.10;
          measurement.uncertainty = 0.08 [SI::metre];
        } else {
          status.faultCode = faultCodeNone;
          measurement.confidence = 0.95;
          measurement.uncertainty = 0.015 [SI::metre];
        }
      }

      action publishHealth {
        status.emitterOperational = true;
        status.detectorOperational = true;
        status.electronicsOperational = true;
        status.temperatureWithinLimits = true;
      }
    }
  }

  part def PowerConditioner {
    attribute inputVoltageNominal : Voltage = 5.0 [SI::volt];
    attribute regulatedVoltage : Voltage = 3.3 [SI::volt];
    attribute maxOutputCurrent : Current = 250 [SI::milliampere];
    attribute efficiency : Real = 0.86;

    port externalPower : PowerPort;
    port regulatedPower : PowerPort;
  }

  part def InfraredPointSensor {
    attribute targetDistance : Distance;
    attribute ambientIrradiance : Irradiance;
    attribute surfaceReflectance : Real;
    attribute operatingTemperature : Temperature;

    port power : PowerPort;
    port control : ControlPort;
    port measurement : MeasurementOutputPort;
    port opticalTransmit : OpticalTransmitPort;
    port opticalReceive : OpticalReceivePort;

    part emitter : InfraredEmitter;
    part detector : InfraredPhotodetector;
    part analogFrontEnd : AnalogFrontEnd;
    part adc : AnalogToDigitalConverter;
    part controller : ProcessingController;
    part powerConditioner : PowerConditioner;

    connect power to powerConditioner.externalPower;
    connect powerConditioner.regulatedPower to emitter.power;
    connect powerConditioner.regulatedPower to detector.power;
    connect powerConditioner.regulatedPower to analogFrontEnd.power;
    connect powerConditioner.regulatedPower to adc.power;
    connect powerConditioner.regulatedPower to controller.power;

    connect control to emitter.control;
    connect control to controller.control;

    connect emitter.opticalOut to opticalTransmit;
    connect opticalReceive to detector.opticalIn;
    connect detector.analogOut to analogFrontEnd.analogIn;
    connect analogFrontEnd.analogOut to adc.analogIn;
    connect adc.digitalOut to controller.digitalIn;
    connect controller.measurementOut to measurement;

    action performMeasurementCycle {
      in enable : Boolean;
      in reflectedSignal : ReflectedInfraredSignal;
      out result : DistanceMeasurement;
      out health : HealthStatus;

      first driveEmitter;
      then receiveReflection;
      then conditionSignal;
      then digitizeSignal;
      then calculateDistance;
      then done;

      action driveEmitter : emitter.emitModulatedInfrared {
        in enableEmitter = enable;
      }

      action receiveReflection : detector.convertOpticalToAnalog {
        in reflectedSignal = reflectedSignal;
      }

      action conditionSignal : analogFrontEnd.filterAndAmplify {
        in rawSignal = receiveReflection.analogSignal;
      }

      action digitizeSignal : adc.sampleSignal {
        in conditionedSignal = conditionSignal.conditionedSignal;
      }

      action calculateDistance : controller.computeDistance {
        in sample = digitizeSignal.sample;
        out measurement = result;
        out status = health;
      }
    }
  }

  part def SensingUnit {
    attribute enclosureIngressProtection : String = "IP54";
    attribute operatingTemperatureMin : Temperature = 253.15 [SI::kelvin];
    attribute operatingTemperatureMax : Temperature = 343.15 [SI::kelvin];
    attribute nominalSupplyVoltage : Voltage = 5.0 [SI::volt];
    attribute maximumPowerConsumption : Power = 0.85 [SI::watt];

    port powerInput : PowerPort;
    port commandInput : ControlPort;
    port distanceOutput : MeasurementOutputPort;

    part pointSensor : InfraredPointSensor;

    connect powerInput to pointSensor.power;
    connect commandInput to pointSensor.control;
    connect pointSensor.measurement to distanceOutput;
  }

  requirement def MeasureRelevantQuantityRequirement {
    subject sensingUnit : SensingUnit;
    require constraint {
      sensingUnit.pointSensor.controller.minimumValidDistance <=
      sensingUnit.distanceOutput.distance.measuredDistance and
      sensingUnit.distanceOutput.distance.measuredDistance <=
      sensingUnit.pointSensor.controller.maximumValidDistance
    }
  }

  requirement def InfraredPointSensorRequirement {
    subject sensingUnit : SensingUnit;
    require constraint {
      sensingUnit.pointSensor.emitter.nominalWavelength >= 850 [SI::nanometre] and
      sensingUnit.pointSensor.emitter.nominalWavelength <= 950 [SI::nanometre]
    }
  }

  requirement def MeasurementAccuracyRequirement {
    subject sensingUnit : SensingUnit;
    require constraint {
      sensingUnit.distanceOutput.distance.uncertainty <= 0.02 [SI::metre]
    }
  }

  requirement def MeasurementUpdateRateRequirement {
    subject sensingUnit : SensingUnit;
    require constraint {
      sensingUnit.pointSensor.controller.measurementPeriod <= 0.020 [SI::second]
    }
  }

  requirement def PowerRequirement {
    subject sensingUnit : SensingUnit;
    require constraint {
      sensingUnit.maximumPowerConsumption <= 1.0 [SI::watt]
    }
  }

  requirement def HealthReportingRequirement {
    subject sensingUnit : SensingUnit;
    require constraint {
      sensingUnit.distanceOutput.status.emitterOperational and
      sensingUnit.distanceOutput.status.detectorOperational and
      sensingUnit.distanceOutput.status.electronicsOperational
    }
  }

  satisfy MeasureRelevantQuantityRequirement by SensingUnit;
  satisfy InfraredPointSensorRequirement by InfraredPointSensor;
  satisfy MeasurementAccuracyRequirement by ProcessingController;
  satisfy MeasurementUpdateRateRequirement by ProcessingController;
  satisfy PowerRequirement by PowerConditioner;
  satisfy HealthReportingRequirement by ProcessingController;

  part sensingUnit : SensingUnit {
    attribute pointSensor.targetDistance = 0.75 [SI::metre];
    attribute pointSensor.ambientIrradiance = 8 [SI::wattPerSquareMetre];
    attribute pointSensor.surfaceReflectance = 0.60;
    attribute pointSensor.operatingTemperature = 298.15 [SI::kelvin];
  }
}