package ShackHartmannWavefrontSensingUnitModel {

  import ScalarValues::*;
  import SI::*;

  attribute def LengthValue;
  attribute def AngleValue;
  attribute def TimeValue;
  attribute def FrequencyValue;
  attribute def IrradianceValue;
  attribute def VoltageValue;
  attribute def CurrentValue;
  attribute def TemperatureValue;
  attribute def CountValue;
  attribute def RatioValue;

  item def IncidentWavefront {
    attribute wavelength : LengthValue;
    attribute apertureDiameter : LengthValue;
    attribute opticalIrradiance : IrradianceValue;
    attribute meanIncidenceAngleX : AngleValue;
    attribute meanIncidenceAngleY : AngleValue;
  }

  item def SpotImageFrame {
    attribute exposureTime : TimeValue;
    attribute framePeriod : TimeValue;
    attribute pixelCountX : CountValue;
    attribute pixelCountY : CountValue;
    attribute bitDepth : CountValue;
    attribute sensorTemperature : TemperatureValue;
  }

  item def CentroidMap {
    attribute centroidCount : CountValue;
    attribute validCentroidCount : CountValue;
    attribute meanSpotRadius : LengthValue;
    attribute saturationFraction : RatioValue;
  }

  item def LocalSlopeMap {
    attribute sampleCountX : CountValue;
    attribute sampleCountY : CountValue;
    attribute slopeX : AngleValue;
    attribute slopeY : AngleValue;
    attribute residualSlopeNoise : AngleValue;
  }

  item def WavefrontMeasurement {
    attribute rmsWavefrontError : LengthValue;
    attribute peakToValleyWavefrontError : LengthValue;
    attribute zernikeDefocus : LengthValue;
    attribute zernikeAstigmatism0 : LengthValue;
    attribute zernikeAstigmatism45 : LengthValue;
    attribute zernikeComaX : LengthValue;
    attribute zernikeComaY : LengthValue;
    attribute measurementTimestamp : TimeValue;
    attribute confidence : RatioValue;
  }

  item def ElectricalPower {
    attribute supplyVoltage : VoltageValue;
    attribute supplyCurrent : CurrentValue;
  }

  item def ThermalLoad {
    attribute dissipatedPower : VoltageValue;
    attribute componentTemperature : TemperatureValue;
  }

  port def OpticalInputPort {
    in item wavefront : IncidentWavefront;
  }

  port def OpticalPort {
    in item wavefrontIn : IncidentWavefront;
    out item wavefrontOut : IncidentWavefront;
  }

  port def ImageDataPort {
    out item frame : SpotImageFrame;
  }

  port def CentroidDataPort {
    in item frameIn : SpotImageFrame;
    out item centroids : CentroidMap;
  }

  port def SlopeDataPort {
    in item centroidsIn : CentroidMap;
    out item slopes : LocalSlopeMap;
  }

  port def MeasurementDataPort {
    in item slopesIn : LocalSlopeMap;
    out item measurement : WavefrontMeasurement;
  }

  port def TelemetryPort {
    out item measurementOut : WavefrontMeasurement;
  }

  port def PowerPort {
    in item power : ElectricalPower;
  }

  port def ThermalPort {
    out item heat : ThermalLoad;
  }

  part def EntranceAperture {
    attribute clearApertureDiameter : LengthValue = 8.0 [mm];
    attribute fieldOfView : AngleValue = 2.0 [deg];
    port opticalIn : OpticalInputPort;
    port opticalOut : OpticalPort;
  }

  part def BandpassFilter {
    attribute centerWavelength : LengthValue = 635.0 [nm];
    attribute bandwidth : LengthValue = 10.0 [nm];
    attribute transmission : RatioValue = 0.92;
    port opticalIn : OpticalPort;
    port opticalOut : OpticalPort;
  }

  part def LensletArray {
    attribute lensletPitch : LengthValue = 150.0 [um];
    attribute focalLength : LengthValue = 6.0 [mm];
    attribute lensletCountX : CountValue = 48;
    attribute lensletCountY : CountValue = 48;
    attribute fillFactor : RatioValue = 0.98;
    port opticalIn : OpticalPort;
    port opticalOut : OpticalPort;
  }

  part def ImageSensor {
    attribute pixelPitch : LengthValue = 5.5 [um];
    attribute activePixelsX : CountValue = 2048;
    attribute activePixelsY : CountValue = 2048;
    attribute fullWellCapacity : CountValue = 30000;
    attribute readNoiseRms : CountValue = 3;
    attribute maximumFrameRate : FrequencyValue = 500 [Hz];
    attribute nominalExposureTime : TimeValue = 1.0 [ms];
    port opticalIn : OpticalPort;
    port imageOut : ImageDataPort;
    port powerIn : PowerPort;
    port thermalOut : ThermalPort;
  }

  part def TimingController {
    attribute commandedFrameRate : FrequencyValue = 200 [Hz];
    attribute exposureTime : TimeValue = 1.0 [ms];
    attribute synchronizationJitter : TimeValue = 100 [ns];
    port powerIn : PowerPort;
  }

  part def WavefrontProcessor {
    attribute centroidWindowSize : CountValue = 9;
    attribute darkFrameUpdateInterval : TimeValue = 60 [s];
    attribute reconstructionModeCount : CountValue = 35;
    attribute outputRate : FrequencyValue = 200 [Hz];
    port imageIn : CentroidDataPort;
    port centroidOut : SlopeDataPort;
    port measurementOut : MeasurementDataPort;
    port powerIn : PowerPort;
    port thermalOut : ThermalPort;
  }

  part def TelemetryInterface {
    attribute packetRate : FrequencyValue = 200 [Hz];
    attribute linkLatency : TimeValue = 2.0 [ms];
    port measurementIn : MeasurementDataPort;
    port telemetryOut : TelemetryPort;
    port powerIn : PowerPort;
  }

  action def AcquireSpotFrame {
    in item incomingWavefront : IncidentWavefront;
    out item frame : SpotImageFrame;
  }

  action def EstimateCentroids {
    in item frame : SpotImageFrame;
    out item centroids : CentroidMap;
  }

  action def ComputeLocalSlopes {
    in item centroids : CentroidMap;
    out item slopes : LocalSlopeMap;
  }

  action def ReconstructWavefront {
    in item slopes : LocalSlopeMap;
    out item measurement : WavefrontMeasurement;
  }

  action def PublishMeasurement {
    in item measurement : WavefrontMeasurement;
    out item transmittedMeasurement : WavefrontMeasurement;
  }

  state def SensingUnitStateMachine {
    state off;
    state initializing;
    state darkCalibration;
    state waitingForWavefront;
    state acquiring;
    state processing;
    state publishing;
    state fault;

    transition initial then off;
    transition off_to_initializing first off then initializing;
    transition initializing_to_darkCalibration first initializing then darkCalibration;
    transition darkCalibration_to_waiting first darkCalibration then waitingForWavefront;
    transition waiting_to_acquiring first waitingForWavefront then acquiring;
    transition acquiring_to_processing first acquiring then processing;
    transition processing_to_publishing first processing then publishing;
    transition publishing_to_waiting first publishing then waitingForWavefront;
    transition any_to_fault first off then fault;
  }

  part def ShackHartmannWavefrontSensingUnit {
    attribute measuredQuantity : String = "optical wavefront phase error";
    attribute designWavelength : LengthValue = 635.0 [nm];
    attribute measurementRate : FrequencyValue = 200 [Hz];
    attribute rmsAccuracy : LengthValue = 15.0 [nm];
    attribute dynamicRange : LengthValue = 5.0 [um];
    attribute operatingTemperatureMin : TemperatureValue = 273.15 [K];
    attribute operatingTemperatureMax : TemperatureValue = 323.15 [K];

    port opticalInput : OpticalInputPort;
    port powerInput : PowerPort;
    port telemetryOutput : TelemetryPort;
    port thermalOutput : ThermalPort;

    part aperture : EntranceAperture;
    part filter : BandpassFilter;
    part lenslets : LensletArray;
    part sensor : ImageSensor;
    part timing : TimingController;
    part processor : WavefrontProcessor;
    part telemetry : TelemetryInterface;

    perform action acquire : AcquireSpotFrame;
    perform action estimateCentroids : EstimateCentroids;
    perform action computeSlopes : ComputeLocalSlopes;
    perform action reconstruct : ReconstructWavefront;
    perform action publish : PublishMeasurement;

    exhibit state behavior : SensingUnitStateMachine;

    connect opticalInput.wavefront to aperture.opticalIn.wavefront;
    connect aperture.opticalOut.wavefrontOut to filter.opticalIn.wavefrontIn;
    connect filter.opticalOut.wavefrontOut to lenslets.opticalIn.wavefrontIn;
    connect lenslets.opticalOut.wavefrontOut to sensor.opticalIn.wavefrontIn;
    connect sensor.imageOut.frame to processor.imageIn.frameIn;
    connect processor.imageIn.centroids to processor.centroidOut.centroidsIn;
    connect processor.centroidOut.slopes to processor.measurementOut.slopesIn;
    connect processor.measurementOut.measurement to telemetry.measurementIn.slopesIn;
    connect telemetry.telemetryOut.measurementOut to telemetryOutput.measurementOut;
    connect powerInput.power to sensor.powerIn.power;
    connect powerInput.power to timing.powerIn.power;
    connect powerInput.power to processor.powerIn.power;
    connect powerInput.power to telemetry.powerIn.power;
    connect sensor.thermalOut.heat to thermalOutput.heat;
    connect processor.thermalOut.heat to thermalOutput.heat;
  }

  requirement def MeasureWavefrontRequirement {
    subject unit : ShackHartmannWavefrontSensingUnit;
    require constraint {
      unit.measuredQuantity == "optical wavefront phase error"
    }
  }

  requirement def AccuracyRequirement {
    subject unit : ShackHartmannWavefrontSensingUnit;
    require constraint {
      unit.rmsAccuracy <= 20.0 [nm]
    }
  }

  requirement def RateRequirement {
    subject unit : ShackHartmannWavefrontSensingUnit;
    require constraint {
      unit.measurementRate >= 100 [Hz]
    }
  }

  requirement def DynamicRangeRequirement {
    subject unit : ShackHartmannWavefrontSensingUnit;
    require constraint {
      unit.dynamicRange >= 4.0 [um]
    }
  }

  requirement def LensletSamplingRequirement {
    subject unit : ShackHartmannWavefrontSensingUnit;
    require constraint {
      unit.lenslets.lensletCountX >= 32 and unit.lenslets.lensletCountY >= 32
    }
  }

  requirement def SpectralCompatibilityRequirement {
    subject unit : ShackHartmannWavefrontSensingUnit;
    require constraint {
      unit.filter.centerWavelength == unit.designWavelength
    }
  }

  requirement def ExposureRequirement {
    subject unit : ShackHartmannWavefrontSensingUnit;
    require constraint {
      unit.sensor.nominalExposureTime <= 2.0 [ms]
    }
  }

  requirement def ThermalOperatingRequirement {
    subject unit : ShackHartmannWavefrontSensingUnit;
    require constraint {
      unit.operatingTemperatureMin <= 273.15 [K] and unit.operatingTemperatureMax >= 323.15 [K]
    }
  }

  part sensingUnit : ShackHartmannWavefrontSensingUnit;

  satisfy MeasureWavefrontRequirement by sensingUnit;
  satisfy AccuracyRequirement by sensingUnit;
  satisfy RateRequirement by sensingUnit;
  satisfy DynamicRangeRequirement by sensingUnit;
  satisfy LensletSamplingRequirement by sensingUnit;
  satisfy SpectralCompatibilityRequirement by sensingUnit;
  satisfy ExposureRequirement by sensingUnit;
  satisfy ThermalOperatingRequirement by sensingUnit;
}