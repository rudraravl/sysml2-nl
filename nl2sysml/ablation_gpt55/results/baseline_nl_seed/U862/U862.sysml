package SSMIS_Based_Earth_Observation_System {
  private import ScalarValues::*;

  enum def PolarizationKind {
    enum horizontal;
    enum vertical;
    enum dual;
  }

  enum def ScanModeKind {
    enum conicalEarthScan;
    enum coldSpaceView;
    enum warmLoadView;
    enum safeStowed;
  }

  enum def ProductQualityKind {
    enum nominal;
    enum degraded;
    enum invalid;
  }

  attribute def FrequencyGHz {
    attribute value : Real;
    attribute unit : String = "GHz";
  }

  attribute def BandwidthMHz {
    attribute value : Real;
    attribute unit : String = "MHz";
  }

  attribute def TemperatureK {
    attribute value : Real;
    attribute unit : String = "K";
  }

  attribute def PowerW {
    attribute value : Real;
    attribute unit : String = "W";
  }

  attribute def VoltageV {
    attribute value : Real;
    attribute unit : String = "V";
  }

  attribute def DataRateMbps {
    attribute value : Real;
    attribute unit : String = "Mbit/s";
  }

  attribute def LengthKm {
    attribute value : Real;
    attribute unit : String = "km";
  }

  attribute def AngleDeg {
    attribute value : Real;
    attribute unit : String = "deg";
  }

  attribute def TimeSeconds {
    attribute value : Real;
    attribute unit : String = "s";
  }

  attribute def TimeHours {
    attribute value : Real;
    attribute unit : String = "h";
  }

  attribute def WindSpeedMetersPerSecond {
    attribute value : Real;
    attribute unit : String = "m/s";
  }

  attribute def PrecipitationRateMillimetersPerHour {
    attribute value : Real;
    attribute unit : String = "mm/h";
  }

  attribute def WaterVaporMillimeters {
    attribute value : Real;
    attribute unit : String = "mm";
  }

  item def MicrowaveRadiance {
    attribute centerFrequencyGHz : Real;
    attribute bandwidthMHz : Real;
    attribute polarization : PolarizationKind;
    attribute antennaTemperatureK : Real;
  }

  item def RawDetectorCounts {
    attribute channelId : Integer;
    attribute sampleIndex : Integer;
    attribute detectorCounts : Integer;
    attribute integrationTimeSeconds : Real;
  }

  item def CalibrationReference {
    attribute warmLoadTemperatureK : Real;
    attribute coldSpaceTemperatureK : Real;
    attribute calibrationAgeSeconds : Real;
  }

  item def BrightnessTemperatureSample {
    attribute channelId : Integer;
    attribute scanPosition : Integer;
    attribute brightnessTemperatureK : Real;
    attribute geolocationLatitudeDeg : Real;
    attribute geolocationLongitudeDeg : Real;
    attribute incidenceAngleDeg : Real;
  }

  item def EnvironmentalProductSet {
    attribute surfaceWindSpeedMetersPerSecond : Real;
    attribute totalPrecipitableWaterMillimeters : Real;
    attribute rainRateMillimetersPerHour : Real;
    attribute seaIceConcentrationPercent : Real;
    attribute cloudLiquidWaterMillimeters : Real;
    attribute productQuality : ProductQualityKind;
  }

  item def CommandMessage {
    attribute commandId : Integer;
    attribute requestedScanMode : ScanModeKind;
    attribute enableScienceCollection : Boolean;
  }

  item def TelemetryFrame {
    attribute frameId : Integer;
    attribute instrumentTemperatureK : Real;
    attribute busVoltageV : Real;
    attribute scienceDataRateMbps : Real;
    attribute safeModeActive : Boolean;
  }

  item def ElectricalPower {
    attribute voltageV : Real;
    attribute powerW : Real;
  }

  item def ThermalLoad {
    attribute heatFlowW : Real;
    attribute temperatureK : Real;
  }

  item def ScienceDataPacket {
    attribute packetId : Integer;
    attribute packetLengthBytes : Integer;
    attribute encodedDataRateMbps : Real;
    attribute containsCalibratedBrightnessTemperatures : Boolean;
    attribute containsEnvironmentalProducts : Boolean;
  }

  port def MicrowaveRadiancePort {
    inout item radiance : MicrowaveRadiance;
  }

  port def DetectorDataPort {
    inout item counts : RawDetectorCounts;
  }

  port def CalibrationPort {
    inout item reference : CalibrationReference;
  }

  port def BrightnessTemperaturePort {
    inout item sample : BrightnessTemperatureSample;
  }

  port def ProductPort {
    inout item products : EnvironmentalProductSet;
  }

  port def CommandPort {
    inout item command : CommandMessage;
  }

  port def TelemetryPort {
    inout item telemetry : TelemetryFrame;
  }

  port def PowerPort {
    inout item power : ElectricalPower;
  }

  port def ThermalPort {
    inout item thermalLoad : ThermalLoad;
  }

  port def ScienceDataPort {
    inout item sciencePacket : ScienceDataPacket;
  }

  action def ConicallyScanEarth {
    in item incomingRadiance : MicrowaveRadiance;
    out item sampledCounts : RawDetectorCounts;
  }

  action def CalibrateRadiometerSamples {
    in item rawCounts : RawDetectorCounts;
    in item reference : CalibrationReference;
    out item calibratedSample : BrightnessTemperatureSample;
  }

  action def RetrieveEnvironmentalProducts {
    in item calibratedSample : BrightnessTemperatureSample;
    out item products : EnvironmentalProductSet;
  }

  action def PacketizeAndDownlinkScience {
    in item products : EnvironmentalProductSet;
    out item sciencePacket : ScienceDataPacket;
    out item telemetry : TelemetryFrame;
  }

  action def SSMISPrimaryObservationFunction {
    in item earthMicrowaveRadiance : MicrowaveRadiance;
    in item calibrationReference : CalibrationReference;
    out item environmentalProducts : EnvironmentalProductSet;
    out item telemetry : TelemetryFrame;

    action scan : ConicallyScanEarth;
    action calibrate : CalibrateRadiometerSamples;
    action retrieve : RetrieveEnvironmentalProducts;
    action packetize : PacketizeAndDownlinkScience;
  }

  state def SSMISOperationalStates {
    state poweredOff;
    state standby;
    state internalCalibration;
    state earthObservation;
    state playbackDownlink;
    state safeMode;

    transition initial then poweredOff;
    transition applyPower first poweredOff then standby;
    transition startCalibration first standby then internalCalibration;
    transition calibrationComplete first internalCalibration then earthObservation;
    transition downlinkWindow first earthObservation then playbackDownlink;
    transition resumeObservation first playbackDownlink then earthObservation;
    transition faultDetected first earthObservation then safeMode;
    transition faultDuringCalibration first internalCalibration then safeMode;
    transition resetFromSafe first safeMode then standby;
    transition removePower first standby then poweredOff;
  }

  part def EarthMicrowaveScene {
    attribute sceneLatitudeMinDeg : Real = -90.0;
    attribute sceneLatitudeMaxDeg : Real = 90.0;
    attribute sceneLongitudeMinDeg : Real = -180.0;
    attribute sceneLongitudeMaxDeg : Real = 180.0;
    attribute naturalEmissionTemperatureK : Real = 250.0;

    port microwaveEmission : MicrowaveRadiancePort;
  }

  part def ReflectorAntenna {
    attribute apertureDiameterMeters : Real = 0.6;
    attribute earthIncidenceAngleDeg : Real = 53.1;
    attribute scanConeAngleDeg : Real = 45.0;
    attribute scanPeriodSeconds : Real = 1.9;

    port earthView : MicrowaveRadiancePort;
    port focusedBeam : MicrowaveRadiancePort;
    port thermalInterface : ThermalPort;
  }

  part def FeedHornCluster {
    attribute feedCount : Integer = 6;
    attribute alignmentErrorDeg : Real = 0.02;

    port antennaInput : MicrowaveRadiancePort;
    port channelizedOutput : MicrowaveRadiancePort;
    port thermalInterface : ThermalPort;
  }

  part def RadiometerChannel {
    attribute channelId : Integer;
    attribute centerFrequencyGHz : Real;
    attribute bandwidthMHz : Real;
    attribute polarization : PolarizationKind;
    attribute noiseEquivalentDeltaTemperatureK : Real;
    attribute gainStabilityPercent : Real;

    port rfInput : MicrowaveRadiancePort;
    port detectorOutput : DetectorDataPort;
    port thermalInterface : ThermalPort;
  }

  part def RadiometerAssembly {
    attribute channelCount : Integer = 24;
    attribute receiverPhysicalTemperatureK : Real = 295.0;

    part lowFrequencyImager : RadiometerChannel[7];
    part highFrequencyImager : RadiometerChannel[8];
    part temperatureSounder : RadiometerChannel[5];
    part humiditySounder : RadiometerChannel[4];

    port rfInput : MicrowaveRadiancePort;
    port detectorOutput : DetectorDataPort;
    port thermalInterface : ThermalPort;
  }

  part def CalibrationAssembly {
    attribute warmLoadNominalTemperatureK : Real = 300.0;
    attribute coldSpaceEquivalentTemperatureK : Real = 2.7;
    attribute calibrationCycleSeconds : Real = 16.0;

    port radiometerReference : CalibrationPort;
    port thermalInterface : ThermalPort;
  }

  part def DigitalSignalProcessor {
    attribute processorClockMHz : Real = 80.0;
    attribute internalMemoryMegabytes : Real = 512.0;
    attribute nominalScienceDataRateMbps : Real = 2.4;

    port rawInput : DetectorDataPort;
    port calibrationInput : CalibrationPort;
    port brightnessOutput : BrightnessTemperaturePort;
    port productOutput : ProductPort;
    port scienceDataOutput : ScienceDataPort;
    port telemetryOutput : TelemetryPort;

    perform action primaryProcessing : SSMISPrimaryObservationFunction;
  }

  part def InstrumentThermalControl {
    attribute heaterCapacityW : Real = 65.0;
    attribute radiatorAreaSquareMeters : Real = 0.85;
    attribute controlledElectronicsTemperatureK : Real = 295.0;

    port antennaThermal : ThermalPort;
    port feedThermal : ThermalPort;
    port receiverThermal : ThermalPort;
    port calibrationThermal : ThermalPort;
    port spacecraftThermal : ThermalPort;
  }

  part def InstrumentPowerConditioner {
    attribute inputVoltageV : Real = 28.0;
    attribute regulatedVoltageV : Real = 12.0;
    attribute maximumOutputPowerW : Real = 260.0;
    attribute conversionEfficiencyPercent : Real = 88.0;

    port spacecraftPowerInput : PowerPort;
    port instrumentPowerOutput : PowerPort;
    port telemetryOutput : TelemetryPort;
  }

  part def SSMISInstrument {
    doc /* The instrument is based on the Special Sensor Microwave Imager/Sounder concept. Its high-level primary function is to passively collect microwave radiance from Earth at multiple imaging and sounding channels, calibrate the radiometric measurements, and produce environmental data products for weather and climate users. */

    attribute swathWidthKm : Real = 1700.0;
    attribute altitudeKm : Real = 833.0;
    attribute nominalPowerW : Real = 230.0;
    attribute nominalMassKg : Real = 95.0;
    attribute nominalScienceDataRateMbps : Real = 2.4;
    attribute revisitTimeHours : Real = 12.0;

    part reflector : ReflectorAntenna;
    part feedHornCluster : FeedHornCluster;
    part radiometerAssembly : RadiometerAssembly;
    part calibrationAssembly : CalibrationAssembly;
    part digitalProcessor : DigitalSignalProcessor;
    part thermalControl : InstrumentThermalControl;
    part powerConditioner : InstrumentPowerConditioner;

    port earthViewPort : MicrowaveRadiancePort;
    port powerIn : PowerPort;
    port thermalInterface : ThermalPort;
    port commandIn : CommandPort;
    port telemetryOut : TelemetryPort;
    port scienceDataOut : ScienceDataPort;
    port productOut : ProductPort;

    connect earthViewPort to reflector.earthView;
    connect reflector.focusedBeam to feedHornCluster.antennaInput;
    connect feedHornCluster.channelizedOutput to radiometerAssembly.rfInput;
    connect radiometerAssembly.detectorOutput to digitalProcessor.rawInput;
    connect calibrationAssembly.radiometerReference to digitalProcessor.calibrationInput;
    connect digitalProcessor.productOutput to productOut;
    connect digitalProcessor.scienceDataOutput to scienceDataOut;
    connect digitalProcessor.telemetryOutput to telemetryOut;
    connect powerIn to powerConditioner.spacecraftPowerInput;
    connect thermalInterface to thermalControl.spacecraftThermal;
    connect reflector.thermalInterface to thermalControl.antennaThermal;
    connect feedHornCluster.thermalInterface to thermalControl.feedThermal;
    connect radiometerAssembly.thermalInterface to thermalControl.receiverThermal;
    connect calibrationAssembly.thermalInterface to thermalControl.calibrationThermal;

    exhibit state operatingState : SSMISOperationalStates;
    perform action primaryFunction : SSMISPrimaryObservationFunction;
  }

  part def SpacecraftBus {
    attribute orbitAltitudeKm : Real = 833.0;
    attribute orbitInclinationDeg : Real = 98.8;
    attribute solarArrayPowerW : Real = 1200.0;
    attribute payloadPowerAllocationW : Real = 300.0;
    attribute payloadDataStorageGigabytes : Real = 128.0;
    attribute downlinkDataRateMbps : Real = 150.0;

    port payloadPower : PowerPort;
    port payloadThermal : ThermalPort;
    port payloadCommand : CommandPort;
    port payloadTelemetry : TelemetryPort;
    port payloadScienceData : ScienceDataPort;
    port spaceToGroundTelemetry : TelemetryPort;
    port groundToSpaceCommand : CommandPort;
  }

  part def SSMISSpacecraft {
    attribute missionDesignLifeYears : Real = 7.0;
    attribute attitudeKnowledgeDeg : Real = 0.05;
    attribute geolocationAccuracyKm : Real = 5.0;

    part bus : SpacecraftBus;
    part instrument : SSMISInstrument;

    port earthRadianceInput : MicrowaveRadiancePort;
    port commandUplink : CommandPort;
    port telemetryDownlink : TelemetryPort;
    port scienceDownlink : ScienceDataPort;

    connect earthRadianceInput to instrument.earthViewPort;
    connect bus.payloadPower to instrument.powerIn;
    connect bus.payloadThermal to instrument.thermalInterface;
    connect bus.payloadCommand to instrument.commandIn;
    connect instrument.telemetryOut to bus.payloadTelemetry;
    connect instrument.scienceDataOut to bus.payloadScienceData;
    connect commandUplink to bus.groundToSpaceCommand;
    connect bus.spaceToGroundTelemetry to telemetryDownlink;
    connect bus.payloadScienceData to scienceDownlink;
  }

  part def GroundStation {
    attribute antennaDiameterMeters : Real = 13.0;
    attribute receiveFrequencyGHz : Real = 8.2;
    attribute commandUplinkFrequencyGHz : Real = 2.1;
    attribute minimumElevationAngleDeg : Real = 5.0;

    port spacecraftTelemetryInput : TelemetryPort;
    port spacecraftScienceInput : ScienceDataPort;
    port spacecraftCommandOutput : CommandPort;
    port productOutput : ProductPort;
  }

  part def EnvironmentalProductProcessor {
    attribute productLatencyMinutes : Real = 30.0;
    attribute griddedResolutionKm : Real = 25.0;
    attribute qualityControlThresholdK : Real = 2.0;

    port scienceInput : ScienceDataPort;
    port productOutput : ProductPort;
  }

  part def MissionUser {
    attribute requiredProductLatencyMinutes : Real = 60.0;
    attribute requiredWindSpeedAccuracyMetersPerSecond : Real = 2.0;
    attribute requiredRainRateAccuracyMillimetersPerHour : Real = 1.0;

    port environmentalProducts : ProductPort;
  }

  part def SSMISBasedEarthObservationSystem {
    doc /* This system uses an SSMIS-based passive microwave payload on a polar-orbiting spacecraft to observe Earth scenes, transform calibrated brightness temperatures into environmental products, and deliver those products to mission users. */

    attribute constellationPlaneCount : Integer = 1;
    attribute spacecraftCount : Integer = 1;
    attribute systemRevisitTimeHours : Real = 12.0;
    attribute deliveredProductLatencyMinutes : Real = 30.0;

    part earthScene : EarthMicrowaveScene;
    part spacecraft : SSMISSpacecraft;
    part groundStation : GroundStation;
    part groundProcessor : EnvironmentalProductProcessor;
    part weatherUser : MissionUser;

    connect earthScene.microwaveEmission to spacecraft.earthRadianceInput;
    connect groundStation.spacecraftCommandOutput to spacecraft.commandUplink;
    connect spacecraft.telemetryDownlink to groundStation.spacecraftTelemetryInput;
    connect spacecraft.scienceDownlink to groundStation.spacecraftScienceInput;
    connect groundStation.spacecraftScienceInput to groundProcessor.scienceInput;
    connect groundProcessor.productOutput to groundStation.productOutput;
    connect groundStation.productOutput to weatherUser.environmentalProducts;
  }

  requirement primaryFunctionRequirement {
    doc /* The system shall passively sense naturally emitted and scattered microwave radiance from Earth using an SSMIS-based instrument, calibrate the multi-channel radiometric measurements, and produce high-level environmental products including ocean surface wind speed, atmospheric water vapor, precipitation rate, cloud liquid water, and sea ice concentration. */
    subject system : SSMISBasedEarthObservationSystem;
  }

  requirement coverageRequirement {
    doc /* The SSMIS-based instrument shall provide broad-swath microwave imaging and sounding coverage suitable for global weather observation from low Earth orbit. */
    subject instrument : SSMISInstrument;
    require constraint { instrument.swathWidthKm >= 1700.0 }
    require constraint { instrument.revisitTimeHours <= 12.0 }
  }

  requirement calibrationRequirement {
    doc /* The instrument shall periodically view warm-load and cold-space calibration references to maintain radiometric calibration of brightness temperature products. */
    subject instrument : SSMISInstrument;
    require constraint { instrument.nominalScienceDataRateMbps >= 2.0 }
  }

  requirement powerRequirement {
    doc /* The instrument shall operate within the spacecraft payload power allocation while performing Earth observation, calibration, and science data packetization. */
    subject instrument : SSMISInstrument;
    require constraint { instrument.nominalPowerW <= 300.0 }
  }

  part ssmisBasedSystem : SSMISBasedEarthObservationSystem;

  satisfy primaryFunctionRequirement by ssmisBasedSystem;
  satisfy coverageRequirement by ssmisBasedSystem.spacecraft.instrument;
  satisfy calibrationRequirement by ssmisBasedSystem.spacecraft.instrument;
  satisfy powerRequirement by ssmisBasedSystem.spacecraft.instrument;
}
