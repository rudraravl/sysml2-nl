package LiquidCapacitiveInclinometerModel {
  import ScalarValues::*;

  attribute def Angle {
    attribute value : Real;
    attribute unit : String = "degree";
  }

  attribute def AngularRate {
    attribute value : Real;
    attribute unit : String = "degree/second";
  }

  attribute def Capacitance {
    attribute value : Real;
    attribute unit : String = "picofarad";
  }

  attribute def Voltage {
    attribute value : Real;
    attribute unit : String = "volt";
  }

  attribute def Temperature {
    attribute value : Real;
    attribute unit : String = "degreeCelsius";
  }

  attribute def Time {
    attribute value : Real;
    attribute unit : String = "millisecond";
  }

  attribute def Accuracy {
    attribute value : Real;
    attribute unit : String = "degree";
  }

  item def ExcitationSignal {
    attribute amplitude : Voltage;
    attribute frequencyHz : Real;
  }

  item def DifferentialCapacitance {
    attribute positiveElectrodeCapacitance : Capacitance;
    attribute negativeElectrodeCapacitance : Capacitance;
    attribute deltaCapacitance : Capacitance;
  }

  item def RawTiltSample {
    attribute sampleTime : Time;
    attribute differentialCapacitance : DifferentialCapacitance;
    attribute temperature : Temperature;
  }

  item def TiltEstimate {
    attribute angleX : Angle;
    attribute angleY : Angle;
    attribute angularRateX : AngularRate;
    attribute angularRateY : AngularRate;
    attribute confidence : Real;
    attribute sampleAge : Time;
  }

  item def HealthStatus {
    attribute electronicsOk : Boolean;
    attribute liquidCellOk : Boolean;
    attribute calibrationValid : Boolean;
    attribute temperatureInRange : Boolean;
    attribute diagnosticCode : String;
  }

  port def PowerPort {
    in item supplyVoltage : Voltage;
  }

  port def DiagnosticPort {
    out item status : HealthStatus;
  }

  port def TiltDataPort {
    out item tilt : TiltEstimate;
  }

  port def ExcitationPort {
    out item signal : ExcitationSignal;
  }

  port def CapacitanceSensePort {
    in item capacitance : DifferentialCapacitance;
  }

  port def TemperaturePort {
    out item temperature : Temperature;
  }

  part def LiquidCapacitiveInclinometerSystem {
    attribute measurementRange : Angle;
    attribute nominalAccuracy : Accuracy;
    attribute responseTime : Time;
    attribute operatingTemperatureMin : Temperature;
    attribute operatingTemperatureMax : Temperature;

    port powerIn : PowerPort;
    port tiltOut : TiltDataPort;
    port diagnosticsOut : DiagnosticPort;

    part sensingCell : LiquidCapacitiveSensingCell;
    part excitationElectronics : ExcitationElectronics;
    part capacitanceConverter : CapacitanceToDigitalConverter;
    part temperatureSensor : TemperatureSensor;
    part signalProcessor : TiltSignalProcessor;
    part calibrationStore : CalibrationMemory;
    part healthMonitor : HealthMonitor;
    part enclosure : SealedEnclosure;

    connection powerToExcitation connect powerIn to excitationElectronics.powerIn;
    connection excitationToCell connect excitationElectronics.excitationOut to sensingCell.excitationIn;
    connection cellToConverter connect sensingCell.capacitanceOut to capacitanceConverter.capacitanceIn;
    connection temperatureToProcessor connect temperatureSensor.temperatureOut to signalProcessor.temperatureIn;
    connection converterToProcessor connect capacitanceConverter.rawSampleOut to signalProcessor.rawSampleIn;
    connection calibrationToProcessor connect calibrationStore.parametersOut to signalProcessor.calibrationIn;
    connection processorToOutput connect signalProcessor.tiltOut to tiltOut;
    connection healthToDiagnostics connect healthMonitor.diagnosticsOut to diagnosticsOut;
  }

  part def LiquidCapacitiveSensingCell {
    attribute fillLiquidDielectricConstant : Real;
    attribute plateGap : Real;
    attribute dampingViscosity : Real;
    attribute usableTiltRange : Angle;

    port excitationIn : ExcitationPort;
    port capacitanceOut : CapacitanceSensePort;

    part liquidCavity : DielectricLiquidCavity;
    part electrodeArray : DifferentialElectrodeArray;
    part mechanicalReferencePlane : ReferencePlane;
  }

  part def DielectricLiquidCavity {
    attribute liquidVolumeMl : Real;
    attribute bubbleVolumeMl : Real;
    attribute settlingTime : Time;
    attribute densityGPerCm3 : Real;
  }

  part def DifferentialElectrodeArray {
    attribute electrodeCount : Integer = 4;
    attribute nominalCapacitance : Capacitance;
    attribute capacitanceSensitivity : Real;
  }

  part def ReferencePlane {
    attribute mountingFlatnessMm : Real;
    attribute axisOrthogonalityError : Angle;
  }

  part def ExcitationElectronics {
    port powerIn : PowerPort;
    port excitationOut : ExcitationPort;

    attribute excitationAmplitude : Voltage;
    attribute excitationFrequencyHz : Real;
    attribute amplitudeStabilityPercent : Real;
  }

  part def CapacitanceToDigitalConverter {
    port capacitanceIn : CapacitanceSensePort;
    out item rawSampleOut : RawTiltSample;

    attribute resolutionBits : Integer;
    attribute conversionTime : Time;
    attribute inputNoise : Capacitance;
  }

  part def TemperatureSensor {
    port temperatureOut : TemperaturePort;

    attribute accuracy : Temperature;
    attribute updatePeriod : Time;
  }

  item def CalibrationParameters {
    attribute zeroOffsetX : Angle;
    attribute zeroOffsetY : Angle;
    attribute scaleFactorX : Real;
    attribute scaleFactorY : Real;
    attribute crossAxisCompensation : Real;
    attribute temperatureCoefficientX : Real;
    attribute temperatureCoefficientY : Real;
  }

  part def CalibrationMemory {
    out item parametersOut : CalibrationParameters;

    attribute retentionYears : Real;
    attribute writeProtected : Boolean;
  }

  part def TiltSignalProcessor {
    in item rawSampleIn : RawTiltSample;
    in item temperatureIn : Temperature;
    in item calibrationIn : CalibrationParameters;
    port tiltOut : TiltDataPort;

    attribute filterCutoffHz : Real;
    attribute samplePeriod : Time;
    attribute outputLatency : Time;

    action computeTilt {
      in item raw : RawTiltSample;
      in item calibration : CalibrationParameters;
      in item temperature : Temperature;
      out item estimate : TiltEstimate;

      action convertCapacitanceToRatio;
      action applyZeroAndScaleCalibration;
      action compensateTemperatureDrift;
      action filterDynamicLiquidMotion;
      action estimateConfidence;
      action publishTiltEstimate;

      first start then convertCapacitanceToRatio;
      then applyZeroAndScaleCalibration;
      then compensateTemperatureDrift;
      then filterDynamicLiquidMotion;
      then estimateConfidence;
      then publishTiltEstimate;
    }

    state measurementState {
      state initializing;
      state selfTesting;
      state calibratingZero;
      state measuring;
      state degraded;
      state faulted;

      transition initialToInitializing first initializing;
      transition initialized then selfTesting;
      transition selfTestPassed then measuring;
      transition zeroCommanded then calibratingZero;
      transition zeroComplete then measuring;
      transition diagnosticWarning then degraded;
      transition warningCleared then measuring;
      transition diagnosticFault then faulted;
      transition resetCommanded then initializing;
    }
  }

  part def HealthMonitor {
    port diagnosticsOut : DiagnosticPort;

    attribute minimumSupplyVoltage : Voltage;
    attribute maximumSupplyVoltage : Voltage;
    attribute maximumAllowedNoise : Capacitance;
    attribute maximumTemperature : Temperature;
    attribute minimumTemperature : Temperature;

    action runDiagnostics {
      out item status : HealthStatus;

      action verifySupplyRange;
      action verifyElectrodeContinuity;
      action verifyLiquidCellResponse;
      action verifyCalibrationChecksum;
      action verifyTemperatureRange;
      action emitHealthStatus;

      first start then verifySupplyRange;
      then verifyElectrodeContinuity;
      then verifyLiquidCellResponse;
      then verifyCalibrationChecksum;
      then verifyTemperatureRange;
      then emitHealthStatus;
    }
  }

  part def SealedEnclosure {
    attribute ingressProtectionRating : String = "IP67";
    attribute material : String = "anodized aluminum";
    attribute connectorType : String = "sealed industrial M12";
    attribute mountingHoleCount : Integer = 4;
  }

  requirement def PrimaryFunction {
    subject system : LiquidCapacitiveInclinometerSystem;

    doc /* The system shall measure static or slowly varying inclination by detecting liquid-level-dependent differential capacitance inside a sealed sensing cell, converting it to a calibrated tilt estimate, and outputting compensated angle data with diagnostic health status. */

    require constraint {
      system.measurementRange.value >= 45.0
    }

    require constraint {
      system.nominalAccuracy.value <= 0.1
    }

    require constraint {
      system.responseTime.value <= 100.0
    }
  }

  requirement def LiquidSensingRequirement {
    subject cell : LiquidCapacitiveSensingCell;

    require constraint {
      cell.usableTiltRange.value >= 45.0
    }

    doc /* The sensing cell shall vary differential capacitance monotonically with inclination relative to the reference plane. */
  }

  requirement def TemperatureCompensationRequirement {
    subject processor : TiltSignalProcessor;

    require constraint {
      processor.outputLatency.value <= 50.0
    }

    doc /* The signal processor shall compensate measured tilt for liquid dielectric variation, electronics drift, and stored calibration parameters across the operating temperature range. */
  }

  requirement def DiagnosticRequirement {
    subject monitor : HealthMonitor;

    doc /* The health monitor shall detect supply faults, electrode faults, calibration corruption, abnormal cell response, and out-of-range temperature conditions. */
  }

  part inclinometer : LiquidCapacitiveInclinometerSystem {
    attribute measurementRange : Angle = (value = 60.0, unit = "degree");
    attribute nominalAccuracy : Accuracy = (value = 0.05, unit = "degree");
    attribute responseTime : Time = (value = 75.0, unit = "millisecond");
    attribute operatingTemperatureMin : Temperature = (value = -40.0, unit = "degreeCelsius");
    attribute operatingTemperatureMax : Temperature = (value = 85.0, unit = "degreeCelsius");

    part sensingCell {
      attribute fillLiquidDielectricConstant = 2.3;
      attribute plateGap = 0.50;
      attribute dampingViscosity = 18.0;
      attribute usableTiltRange : Angle = (value = 60.0, unit = "degree");
    }

    part excitationElectronics {
      attribute excitationAmplitude : Voltage = (value = 3.3, unit = "volt");
      attribute excitationFrequencyHz = 32000.0;
      attribute amplitudeStabilityPercent = 0.2;
    }

    part capacitanceConverter {
      attribute resolutionBits = 24;
      attribute conversionTime : Time = (value = 5.0, unit = "millisecond");
      attribute inputNoise : Capacitance = (value = 0.002, unit = "picofarad");
    }

    part signalProcessor {
      attribute filterCutoffHz = 8.0;
      attribute samplePeriod : Time = (value = 10.0, unit = "millisecond");
      attribute outputLatency : Time = (value = 30.0, unit = "millisecond");
    }

    part enclosure {
      attribute ingressProtectionRating = "IP67";
      attribute material = "anodized aluminum";
      attribute connectorType = "sealed industrial M12";
      attribute mountingHoleCount = 4;
    }
  }

  satisfy PrimaryFunction by inclinometer;
  satisfy LiquidSensingRequirement by inclinometer.sensingCell;
  satisfy TemperatureCompensationRequirement by inclinometer.signalProcessor;
  satisfy DiagnosticRequirement by inclinometer.healthMonitor;
}