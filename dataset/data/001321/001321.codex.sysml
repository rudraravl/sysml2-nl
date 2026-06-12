package YawRateSensingUnitModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def RadianPerSecond :> SI::Unit {
    doc /* Unit for angular velocity, rad/s. */
  }

  attribute def DegreePerSecond :> SI::Unit {
    doc /* Unit for angular velocity, deg/s. */
  }

  attribute def Hertz :> SI::Unit {
    doc /* Unit for sampling frequency. */
  }

  attribute def Millisecond :> SI::Unit {
    doc /* Unit for timing latency. */
  }

  attribute def Volt :> SI::Unit {
    doc /* Unit for electrical potential. */
  }

  attribute def Milliampere :> SI::Unit {
    doc /* Unit for current. */
  }

  attribute def Celsius :> SI::Unit {
    doc /* Unit for temperature. */
  }

  attribute def AngularVelocityValue {
    attribute value : Real;
    attribute unit : SI::Unit = RadianPerSecond;
  }

  attribute def YawRateValue :> AngularVelocityValue {
    attribute value : Real;
    attribute unit : SI::Unit = RadianPerSecond;
  }

  attribute def FilteredYawRateValue :> YawRateValue;

  attribute def SensorBiasValue :> AngularVelocityValue;

  attribute def TemperatureValue {
    attribute value : Real;
    attribute unit : SI::Unit = Celsius;
  }

  attribute def VoltageValue {
    attribute value : Real;
    attribute unit : SI::Unit = Volt;
  }

  attribute def CurrentValue {
    attribute value : Real;
    attribute unit : SI::Unit = Milliampere;
  }

  attribute def FrequencyValue {
    attribute value : Real;
    attribute unit : SI::Unit = Hertz;
  }

  attribute def TimeValue {
    attribute value : Real;
    attribute unit : SI::Unit = Millisecond;
  }

  attribute def DiagnosticStatus {
    attribute sensorHealthy : Boolean;
    attribute calibrated : Boolean;
    attribute dataValid : Boolean;
    attribute faultCode : String;
  }

  item def RawYawRateSample {
    attribute yawRate : YawRateValue;
    attribute dieTemperature : TemperatureValue;
    attribute sampleCounter : Integer;
    attribute timestamp : TimeValue;
  }

  item def CorrectedYawRateSample {
    attribute yawRate : FilteredYawRateValue;
    attribute biasEstimate : SensorBiasValue;
    attribute dieTemperature : TemperatureValue;
    attribute quality : Real;
    attribute timestamp : TimeValue;
  }

  item def PowerSupply {
    attribute voltage : VoltageValue;
    attribute currentLimit : CurrentValue;
  }

  item def ConfigurationCommand {
    attribute enableMeasurement : Boolean;
    attribute requestedSampleRate : FrequencyValue;
    attribute filterCutoffFrequency : FrequencyValue;
    attribute performCalibration : Boolean;
  }

  item def DiagnosticMessage {
    attribute status : DiagnosticStatus;
    attribute measuredSupplyVoltage : VoltageValue;
    attribute measuredTemperature : TemperatureValue;
    attribute lastValidSampleCounter : Integer;
  }

  port def PowerInputPort {
    in item supply : PowerSupply;
  }

  port def ConfigurationPort {
    in item command : ConfigurationCommand;
  }

  port def RawSensorDataPort {
    out item rawSample : RawYawRateSample;
  }

  port def CorrectedYawRatePort {
    out item correctedSample : CorrectedYawRateSample;
  }

  port def DiagnosticPort {
    out item diagnostic : DiagnosticMessage;
  }

  part def YawRateSensor {
    attribute measurementRange : YawRateValue = (value = 8.72665, unit = RadianPerSecond);
    attribute noiseDensity : YawRateValue = (value = 0.00035, unit = RadianPerSecond);
    attribute biasInstability : SensorBiasValue = (value = 0.002, unit = RadianPerSecond);
    attribute sampleRate : FrequencyValue = (value = 200.0, unit = Hertz);
    attribute operatingTemperatureMin : TemperatureValue = (value = -40.0, unit = Celsius);
    attribute operatingTemperatureMax : TemperatureValue = (value = 125.0, unit = Celsius);
    attribute supplyVoltageNominal : VoltageValue = (value = 5.0, unit = Volt);

    port powerIn : PowerInputPort;
    port configIn : ConfigurationPort;
    port rawOut : RawSensorDataPort;
    port diagOut : DiagnosticPort;

    action readAngularRate {
      in item supply : PowerSupply;
      out item rawSample : RawYawRateSample;
    }

    action runSelfTest {
      out item diagnostic : DiagnosticMessage;
    }

    state sensorState {
      entry; then initializing;

      state initializing;
      state selfTesting;
      state ready;
      state measuring;
      state faulted;

      transition initializing_to_selfTesting
        first initializing
        then selfTesting;

      transition selfTesting_to_ready
        first selfTesting
        if selfTestPassed
        then ready;

      transition selfTesting_to_faulted
        first selfTesting
        if not selfTestPassed
        then faulted;

      transition ready_to_measuring
        first ready
        if measurementEnabled
        then measuring;

      transition measuring_to_ready
        first measuring
        if not measurementEnabled
        then ready;

      transition measuring_to_faulted
        first measuring
        if supplyOutOfRange or temperatureOutOfRange
        then faulted;

      transition faulted_to_selfTesting
        first faulted
        if resetRequested
        then selfTesting;
    }
  }

  part def BiasEstimator {
    attribute initialBias : SensorBiasValue = (value = 0.0, unit = RadianPerSecond);
    attribute convergenceTime : TimeValue = (value = 500.0, unit = Millisecond);
    attribute zeroRateThreshold : YawRateValue = (value = 0.01, unit = RadianPerSecond);

    port rawIn : RawSensorDataPort;

    action estimateBias {
      in item rawSample : RawYawRateSample;
      out attribute estimatedBias : SensorBiasValue;
    }

    state estimatorState {
      entry; then uninitialized;

      state uninitialized;
      state collectingZeroRateSamples;
      state biasLocked;
      state trackingBias;

      transition start_collection
        first uninitialized
        then collectingZeroRateSamples;

      transition lock_bias
        first collectingZeroRateSamples
        if enoughStableSamples
        then biasLocked;

      transition track_bias
        first biasLocked
        if measurementActive
        then trackingBias;

      transition recalibrate
        first trackingBias
        if calibrationRequested
        then collectingZeroRateSamples;
    }
  }

  part def DigitalLowPassFilter {
    attribute cutoffFrequency : FrequencyValue = (value = 25.0, unit = Hertz);
    attribute updateRate : FrequencyValue = (value = 200.0, unit = Hertz);
    attribute groupDelay : TimeValue = (value = 8.0, unit = Millisecond);

    action filterYawRate {
      in item rawSample : RawYawRateSample;
      in attribute estimatedBias : SensorBiasValue;
      out item correctedSample : CorrectedYawRateSample;
    }
  }

  part def HealthMonitor {
    attribute minimumSupplyVoltage : VoltageValue = (value = 4.75, unit = Volt);
    attribute maximumSupplyVoltage : VoltageValue = (value = 5.25, unit = Volt);
    attribute maximumAllowedLatency : TimeValue = (value = 20.0, unit = Millisecond);
    attribute minimumQuality : Real = 0.8;

    port diagnosticOut : DiagnosticPort;

    action evaluateHealth {
      in item rawSample : RawYawRateSample;
      in item correctedSample : CorrectedYawRateSample;
      in item supply : PowerSupply;
      out item diagnostic : DiagnosticMessage;
    }

    state healthState {
      entry; then unknown;

      state unknown;
      state healthy;
      state degraded;
      state failed;

      transition unknown_to_healthy
        first unknown
        if diagnosticsValid and sensorHealthy
        then healthy;

      transition healthy_to_degraded
        first healthy
        if qualityBelowLimit or temporarySupplyDeviation
        then degraded;

      transition degraded_to_healthy
        first degraded
        if qualityRecovered and supplyNominal
        then healthy;

      transition degraded_to_failed
        first degraded
        if persistentFault
        then failed;

      transition healthy_to_failed
        first healthy
        if sensorInternalFault
        then failed;
    }
  }

  part def YawRateSensingUnit {
    attribute outputSampleRate : FrequencyValue = (value = 200.0, unit = Hertz);
    attribute endToEndLatency : TimeValue = (value = 12.0, unit = Millisecond);
    attribute yawRateAccuracy : YawRateValue = (value = 0.005, unit = RadianPerSecond);
    attribute measurementRange : YawRateValue = (value = 8.72665, unit = RadianPerSecond);

    port powerIn : PowerInputPort;
    port configurationIn : ConfigurationPort;
    port yawRateOut : CorrectedYawRatePort;
    port diagnosticOut : DiagnosticPort;

    part sensor : YawRateSensor;
    part estimator : BiasEstimator;
    part filter : DigitalLowPassFilter;
    part monitor : HealthMonitor;

    connect powerIn to sensor.powerIn;
    connect configurationIn to sensor.configIn;
    connect sensor.rawOut to estimator.rawIn;
    connect monitor.diagnosticOut to diagnosticOut;

    action acquireYawRate {
      in item supply : PowerSupply;
      in item command : ConfigurationCommand;
      out item correctedYawRate : CorrectedYawRateSample;
      out item diagnostic : DiagnosticMessage;

      first start;
      then sensor.readAngularRate;
      then estimator.estimateBias;
      then filter.filterYawRate;
      then monitor.evaluateHealth;
      then done;
    }

    state unitState {
      entry; then off;

      state off;
      state poweringUp;
      state calibrating;
      state standby;
      state measuringYawRate;
      state degradedMeasurement;
      state failed;

      transition off_to_poweringUp
        first off
        if validPowerApplied
        then poweringUp;

      transition poweringUp_to_calibrating
        first poweringUp
        if electronicsInitialized
        then calibrating;

      transition calibrating_to_standby
        first calibrating
        if calibrationComplete
        then standby;

      transition standby_to_measuring
        first standby
        if enableMeasurementCommanded
        then measuringYawRate;

      transition measuring_to_standby
        first measuringYawRate
        if measurementDisabled
        then standby;

      transition measuring_to_degraded
        first measuringYawRate
        if diagnosticQualityLow
        then degradedMeasurement;

      transition degraded_to_measuring
        first degradedMeasurement
        if diagnosticQualityRecovered
        then measuringYawRate;

      transition measuring_to_failed
        first measuringYawRate
        if unrecoverableSensorFault
        then failed;

      transition degraded_to_failed
        first degradedMeasurement
        if unrecoverableSensorFault
        then failed;

      transition failed_to_poweringUp
        first failed
        if resetCommanded
        then poweringUp;
    }
  }

  requirement def MeasureYawRateRequirement {
    doc /* The sensing unit shall measure yaw rate using a yaw-rate sensor and provide a corrected yaw-rate output. */
    attribute requiredRange : YawRateValue = (value = 8.72665, unit = RadianPerSecond);
    attribute requiredAccuracy : YawRateValue = (value = 0.005, unit = RadianPerSecond);
    attribute requiredSampleRate : FrequencyValue = (value = 200.0, unit = Hertz);
  }

  requirement def BiasCompensationRequirement {
    doc /* The sensing unit shall compensate sensor bias before publishing the yaw-rate value. */
    attribute maximumResidualBias : SensorBiasValue = (value = 0.003, unit = RadianPerSecond);
  }

  requirement def LatencyRequirement {
    doc /* The sensing unit shall publish corrected yaw-rate data within the maximum allowed end-to-end latency. */
    attribute maximumLatency : TimeValue = (value = 20.0, unit = Millisecond);
  }

  requirement def DiagnosticRequirement {
    doc /* The sensing unit shall report sensor health, calibration state, data validity, and fault status. */
    attribute diagnosticUpdateRate : FrequencyValue = (value = 10.0, unit = Hertz);
  }

  requirement def EnvironmentalRequirement {
    doc /* The sensing unit shall operate across the specified temperature range. */
    attribute minimumOperatingTemperature : TemperatureValue = (value = -40.0, unit = Celsius);
    attribute maximumOperatingTemperature : TemperatureValue = (value = 85.0, unit = Celsius);
  }

  part yawRateSensingUnit : YawRateSensingUnit;

  satisfy MeasureYawRateRequirement by yawRateSensingUnit;
  satisfy BiasCompensationRequirement by yawRateSensingUnit.estimator;
  satisfy LatencyRequirement by yawRateSensingUnit;
  satisfy DiagnosticRequirement by yawRateSensingUnit.monitor;
  satisfy EnvironmentalRequirement by yawRateSensingUnit.sensor;

  assert constraint yawRateRangeSatisfied {
    yawRateSensingUnit.measurementRange.value >= MeasureYawRateRequirement.requiredRange.value
  }

  assert constraint yawRateAccuracySatisfied {
    yawRateSensingUnit.yawRateAccuracy.value <= MeasureYawRateRequirement.requiredAccuracy.value
  }

  assert constraint sampleRateSatisfied {
    yawRateSensingUnit.outputSampleRate.value >= MeasureYawRateRequirement.requiredSampleRate.value
  }

  assert constraint latencySatisfied {
    yawRateSensingUnit.endToEndLatency.value <= LatencyRequirement.maximumLatency.value
  }
}