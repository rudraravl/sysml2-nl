package MicrowaveRadiometerSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Frequency :> Real {
        unit = "GHz";
    }

    attribute def Bandwidth :> Real {
        unit = "MHz";
    }

    attribute def Temperature :> Real {
        unit = "K";
    }

    attribute def NoiseTemperature :> Temperature;

    attribute def BrightnessTemperature :> Temperature;

    attribute def PowerFluxDensity :> Real {
        unit = "W/m^2/Hz";
    }

    attribute def Voltage :> Real {
        unit = "V";
    }

    attribute def Gain :> Real {
        unit = "dB";
    }

    attribute def IntegrationTime :> Real {
        unit = "s";
    }

    attribute def DataRate :> Real {
        unit = "Mb/s";
    }

    attribute def PointingAngle :> Real {
        unit = "deg";
    }

    attribute def AngularResolution :> Real {
        unit = "deg";
    }

    attribute def CalibrationError :> Real {
        unit = "K";
    }

    item def MicrowaveRadiation {
        attribute centerFrequency : Frequency;
        attribute bandwidth : Bandwidth;
        attribute spectralPowerFlux : PowerFluxDensity;
        attribute polarization : String;
        attribute sourceScene : String;
    }

    item def AnalogRadiometerSignal {
        attribute voltage : Voltage;
        attribute gainApplied : Gain;
        attribute equivalentNoiseTemperature : NoiseTemperature;
        attribute bandId : String;
    }

    item def DigitizedRadiometerSample {
        attribute sampleIndex : Integer;
        attribute rawCounts : Integer;
        attribute channelFrequency : Frequency;
        attribute integrationTime : IntegrationTime;
        attribute receiverTemperature : NoiseTemperature;
        attribute timestamp : String;
    }

    item def CalibratedBrightnessMeasurement {
        attribute brightnessTemperature : BrightnessTemperature;
        attribute uncertainty : CalibrationError;
        attribute channelFrequency : Frequency;
        attribute polarization : String;
        attribute geolocationLatitude : Real;
        attribute geolocationLongitude : Real;
        attribute observationTime : String;
    }

    item def RadiometerHealthStatus {
        attribute receiverTemperature : Temperature;
        attribute localOscillatorLocked : Boolean;
        attribute detectorNominal : Boolean;
        attribute calibrationTargetStable : Boolean;
        attribute faultCode : String;
    }

    port def MicrowaveAperturePort {
        in item incidentRadiation : MicrowaveRadiation;
    }

    port def WaveguidePort {
        out item guidedRadiation : MicrowaveRadiation;
    }

    port def AnalogSignalPort {
        out item analogSignal : AnalogRadiometerSignal;
    }

    port def DigitalSamplePort {
        out item digitalSample : DigitizedRadiometerSample;
    }

    port def MeasurementPort {
        out item brightnessMeasurement : CalibratedBrightnessMeasurement;
    }

    port def HealthPort {
        out item healthStatus : RadiometerHealthStatus;
    }

    port def CommandPort {
        in item command : String;
    }

    port def TelemetryPort {
        out item telemetryPacket : String;
    }

    part def MicrowaveRadiometer {
        attribute operatingFrequencyLow : Frequency = 18.7;
        attribute operatingFrequencyHigh : Frequency = 89.0;
        attribute radiometricResolution : Temperature = 0.3;
        attribute nominalIntegrationTime : IntegrationTime = 0.05;
        attribute angularResolution : AngularResolution = 1.2;
        attribute requiredPointingStability : PointingAngle = 0.05;

        port aperture : MicrowaveAperturePort;
        port commandInput : CommandPort;
        port measurementOutput : MeasurementPort;
        port healthOutput : HealthPort;
        port telemetryOutput : TelemetryPort;

        part antenna : OffsetParabolicAntenna;
        part feedAssembly : MultiBandFeedAssembly;
        part receiver : MicrowaveReceiver;
        part detector : SquareLawDetector;
        part digitizer : AnalogToDigitalConverter;
        part calibrationSubsystem : CalibrationSubsystem;
        part processor : RadiometerSignalProcessor;
        part thermalControl : ThermalControlSubsystem;
        part pointingReference : PointingReferenceUnit;
        part powerConditioning : PowerConditioningUnit;

        connect aperture.incidentRadiation to antenna.aperture.incidentRadiation;
        connect antenna.waveguide.guidedRadiation to feedAssembly.input.guidedRadiation;
        connect feedAssembly.selectedBand.guidedRadiation to receiver.input.guidedRadiation;
        connect receiver.output.analogSignal to detector.inputSignal.analogSignal;
        connect detector.detectedSignal.analogSignal to digitizer.analogInput.analogSignal;
        connect digitizer.sampleOutput.digitalSample to processor.sampleInput.digitalSample;
        connect calibrationSubsystem.calibrationReference.digitalSample to processor.calibrationInput.digitalSample;
        connect processor.measurementOutput.brightnessMeasurement to measurementOutput.brightnessMeasurement;
        connect processor.healthOutput.healthStatus to healthOutput.healthStatus;
        connect processor.telemetryOutput.telemetryPacket to telemetryOutput.telemetryPacket;
        connect commandInput.command to processor.commandInput.command;
    }

    part def OffsetParabolicAntenna {
        attribute apertureDiameter : Real = 1.2 {
            unit = "m";
        }
        attribute antennaGain : Gain = 42.0;
        attribute sidelobeLevel : Gain = -28.0;
        attribute beamEfficiency : Real = 0.92;

        port aperture : MicrowaveAperturePort;
        port waveguide : WaveguidePort;

        action focusIncidentMicrowaveEnergy {
            in item incident : MicrowaveRadiation;
            out item focused : MicrowaveRadiation;
            first start;
            then collectEnergy;
            then rejectOutOfBeamEnergy;
            then emitGuidedRadiation;
            then done;
        }
    }

    part def MultiBandFeedAssembly {
        attribute channelCount : Integer = 5;
        attribute supportedFrequencies : String = "18.7, 23.8, 36.5, 50.3, 89.0 GHz";
        attribute polarizationModes : String = "horizontal, vertical";

        port input : WaveguidePort;
        port selectedBand : WaveguidePort;

        state def FeedSelectionState {
            state Idle;
            state Select18GHz;
            state Select23GHz;
            state Select36GHz;
            state Select50GHz;
            state Select89GHz;
            transition first Idle;
            transition Idle to Select18GHz accept "select_18_7_GHz";
            transition Idle to Select23GHz accept "select_23_8_GHz";
            transition Idle to Select36GHz accept "select_36_5_GHz";
            transition Idle to Select50GHz accept "select_50_3_GHz";
            transition Idle to Select89GHz accept "select_89_0_GHz";
            transition Select18GHz to Idle accept "band_complete";
            transition Select23GHz to Idle accept "band_complete";
            transition Select36GHz to Idle accept "band_complete";
            transition Select50GHz to Idle accept "band_complete";
            transition Select89GHz to Idle accept "band_complete";
        }
    }

    part def MicrowaveReceiver {
        attribute lowNoiseAmplifierGain : Gain = 32.0;
        attribute receiverNoiseTemperature : NoiseTemperature = 85.0;
        attribute intermediateFrequencyBandwidth : Bandwidth = 400.0;
        attribute localOscillatorFrequency : Frequency = 10.0;
        attribute gainStability : Real = 0.02 {
            unit = "dB/hour";
        }

        port input : WaveguidePort;
        port output : AnalogSignalPort;

        part lowNoiseAmplifier : LowNoiseAmplifier;
        part mixer : FrequencyMixer;
        part bandpassFilter : IntermediateFrequencyFilter;

        connect input.guidedRadiation to lowNoiseAmplifier.input.guidedRadiation;
        connect lowNoiseAmplifier.output.analogSignal to mixer.radioFrequencyInput.analogSignal;
        connect mixer.intermediateFrequencyOutput.analogSignal to bandpassFilter.inputSignal.analogSignal;
        connect bandpassFilter.outputSignal.analogSignal to output.analogSignal;
    }

    part def LowNoiseAmplifier {
        attribute gain : Gain = 32.0;
        attribute noiseFigure : Gain = 1.2;
        port input : WaveguidePort;
        port output : AnalogSignalPort;
    }

    part def FrequencyMixer {
        attribute conversionLoss : Gain = 6.0;
        attribute oscillatorLocked : Boolean = true;
        port radioFrequencyInput : AnalogSignalPort;
        port intermediateFrequencyOutput : AnalogSignalPort;
    }

    part def IntermediateFrequencyFilter {
        attribute bandwidth : Bandwidth = 400.0;
        attribute centerFrequency : Frequency = 1.4;
        port inputSignal : AnalogSignalPort;
        port outputSignal : AnalogSignalPort;
    }

    part def SquareLawDetector {
        attribute detectorResponsivity : Real = 1200.0 {
            unit = "V/W";
        }
        attribute linearityError : Real = 0.5 {
            unit = "%";
        }

        port inputSignal : AnalogSignalPort;
        port detectedSignal : AnalogSignalPort;

        action convertPowerToVoltage {
            in item amplifiedSignal : AnalogRadiometerSignal;
            out item detectedVoltage : AnalogRadiometerSignal;
        }
    }

    part def AnalogToDigitalConverter {
        attribute resolutionBits : Integer = 16;
        attribute samplingRate : Real = 50000.0 {
            unit = "samples/s";
        }
        attribute inputVoltageRange : Voltage = 5.0;

        port analogInput : AnalogSignalPort;
        port sampleOutput : DigitalSamplePort;

        action sampleAndQuantize {
            in item detectorVoltage : AnalogRadiometerSignal;
            out item digitalCounts : DigitizedRadiometerSample;
        }
    }

    part def CalibrationSubsystem {
        attribute coldSkyReferenceTemperature : Temperature = 2.7;
        attribute internalHotLoadTemperature : Temperature = 300.0;
        attribute calibrationCyclePeriod : Real = 120.0 {
            unit = "s";
        }
        attribute maximumCalibrationError : CalibrationError = 0.5;

        port calibrationReference : DigitalSamplePort;

        part hotLoad : InternalHotCalibrationLoad;
        part coldReferenceView : ColdSkyReferenceView;
        part noiseDiode : InjectedNoiseSource;

        state def CalibrationMode {
            state Standby;
            state ViewScene;
            state ViewColdReference;
            state ViewHotLoad;
            state InjectNoise;
            state ComputeGainOffset;

            transition first Standby;
            transition Standby to ViewScene accept "start_observation";
            transition ViewScene to ViewColdReference accept "calibration_due";
            transition ViewColdReference to ViewHotLoad accept "cold_sample_complete";
            transition ViewHotLoad to InjectNoise accept "hot_sample_complete";
            transition InjectNoise to ComputeGainOffset accept "noise_sample_complete";
            transition ComputeGainOffset to ViewScene accept "calibration_updated";
            transition ViewScene to Standby accept "stop_observation";
        }
    }

    part def InternalHotCalibrationLoad {
        attribute physicalTemperature : Temperature = 300.0;
        attribute emissivity : Real = 0.995;
    }

    part def ColdSkyReferenceView {
        attribute referenceTemperature : Temperature = 2.7;
        attribute spilloverCorrection : Temperature = 0.4;
    }

    part def InjectedNoiseSource {
        attribute excessNoiseRatio : Gain = 15.0;
        attribute stability : Real = 0.1 {
            unit = "dB";
        }
    }

    part def RadiometerSignalProcessor {
        attribute outputDataRate : DataRate = 2.0;
        attribute brightnessTemperatureRangeLow : BrightnessTemperature = 3.0;
        attribute brightnessTemperatureRangeHigh : BrightnessTemperature = 330.0;
        attribute calibrationPolynomialOrder : Integer = 2;

        port sampleInput : DigitalSamplePort;
        port calibrationInput : DigitalSamplePort;
        port commandInput : CommandPort;
        port measurementOutput : MeasurementPort;
        port healthOutput : HealthPort;
        port telemetryOutput : TelemetryPort;

        action calibrateBrightnessTemperature {
            in item rawSample : DigitizedRadiometerSample;
            in item calibrationSample : DigitizedRadiometerSample;
            out item measurement : CalibratedBrightnessMeasurement;
            first validateRawCounts;
            then subtractReceiverOffset;
            then applyGainCalibration;
            then correctAntennaLoss;
            then estimateUncertainty;
            then publishMeasurement;
        }

        action generateTelemetry {
            in item measurement : CalibratedBrightnessMeasurement;
            in item health : RadiometerHealthStatus;
            out item packet : String;
        }

        state def ProcessingState {
            state Off;
            state Initialization;
            state SelfTest;
            state Observing;
            state Calibrating;
            state Degraded;
            state Fault;

            transition first Off;
            transition Off to Initialization accept "power_on";
            transition Initialization to SelfTest accept "boot_complete";
            transition SelfTest to Observing accept "self_test_passed";
            transition SelfTest to Fault accept "self_test_failed";
            transition Observing to Calibrating accept "calibration_due";
            transition Calibrating to Observing accept "calibration_valid";
            transition Observing to Degraded accept "minor_fault_detected";
            transition Degraded to Observing accept "fault_recovered";
            transition Observing to Fault accept "critical_fault_detected";
            transition Degraded to Fault accept "critical_fault_detected";
            transition Fault to Off accept "power_off";
            transition Observing to Off accept "power_off";
        }
    }

    part def ThermalControlSubsystem {
        attribute receiverSetPoint : Temperature = 290.0;
        attribute allowableReceiverVariation : Temperature = 0.2;
        attribute hotLoadSetPoint : Temperature = 300.0;
        attribute heaterPower : Real = 12.0 {
            unit = "W";
        }

        action regulateTemperature {
            in receiverTemperature : Temperature;
            out heaterDutyCycle : Real;
        }
    }

    part def PointingReferenceUnit {
        attribute boresightAzimuth : PointingAngle = 0.0;
        attribute boresightElevation : PointingAngle = 45.0;
        attribute pointingKnowledgeError : PointingAngle = 0.02;
        attribute scanRate : Real = 6.0 {
            unit = "deg/s";
        }

        action tagObservationGeometry {
            in measurementTime : String;
            out latitude : Real;
            out longitude : Real;
            out incidenceAngle : PointingAngle;
        }
    }

    part def PowerConditioningUnit {
        attribute inputVoltage : Voltage = 28.0;
        attribute regulatedDigitalVoltage : Voltage = 5.0;
        attribute regulatedAnalogVoltage : Voltage = 12.0;
        attribute maximumPowerConsumption : Real = 75.0 {
            unit = "W";
        }
    }

    part def RadiometerMissionContext {
        part environment : ObservedScene;
        part radiometer : MicrowaveRadiometer;
        part groundProcessor : ScienceDataConsumer;

        connect environment.emissionOutput.incidentRadiation to radiometer.aperture.incidentRadiation;
        connect radiometer.measurementOutput.brightnessMeasurement to groundProcessor.measurementInput.brightnessMeasurement;
    }

    part def ObservedScene {
        attribute surfaceTemperature : Temperature = 285.0;
        attribute atmosphericWaterVapor : Real = 20.0 {
            unit = "kg/m^2";
        }
        attribute cloudLiquidWater : Real = 0.1 {
            unit = "kg/m^2";
        }
        attribute oceanWindSpeed : Real = 8.0 {
            unit = "m/s";
        }

        port emissionOutput : MicrowaveAperturePort;
    }

    part def ScienceDataConsumer {
        port measurementInput : MeasurementPort;

        action deriveEnvironmentalProduct {
            in item brightness : CalibratedBrightnessMeasurement;
            out seaSurfaceTemperature : Temperature;
            out waterVaporColumn : Real;
            out precipitationIndicator : Boolean;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject radiometer : MicrowaveRadiometer;

        doc /* The microwave radiometer shall passively receive naturally emitted microwave radiation from an observed scene and convert it into calibrated brightness temperature measurements that characterize the scene at multiple microwave frequency channels. */

        require constraint {
            radiometer.operatingFrequencyLow <= 18.7 and
            radiometer.operatingFrequencyHigh >= 89.0 and
            radiometer.radiometricResolution <= 0.3
        }
    }

    requirement def PassiveSensingRequirement {
        subject radiometer : MicrowaveRadiometer;

        doc /* The system shall perform passive sensing without transmitting microwave energy toward the observed scene. */

        require constraint {
            radiometer.powerConditioning.maximumPowerConsumption <= 75.0
        }
    }

    requirement def CalibrationAccuracyRequirement {
        subject calibrationSubsystem : CalibrationSubsystem;

        doc /* The calibration subsystem shall maintain brightness temperature calibration uncertainty below 0.5 K using cold reference, hot load, and injected noise references. */

        require constraint {
            calibrationSubsystem.maximumCalibrationError <= 0.5
        }
    }

    requirement def ObservationResolutionRequirement {
        subject radiometer : MicrowaveRadiometer;

        doc /* The radiometer shall produce geolocated brightness temperature measurements with angular resolution suitable for high-level environmental observation. */

        require constraint {
            radiometer.angularResolution <= 1.2 and
            radiometer.requiredPointingStability <= 0.05
        }
    }

    requirement def ReceiverSensitivityRequirement {
        subject receiver : MicrowaveReceiver;

        doc /* The receiver shall amplify weak microwave emissions while adding sufficiently low receiver noise to preserve radiometric sensitivity. */

        require constraint {
            receiver.receiverNoiseTemperature <= 85.0 and
            receiver.lowNoiseAmplifierGain >= 32.0
        }
    }

    requirement def DataProductRequirement {
        subject processor : RadiometerSignalProcessor;

        doc /* The signal processor shall output calibrated brightness temperature measurements with observation time, frequency channel, polarization, uncertainty, and geolocation metadata. */

        require constraint {
            processor.outputDataRate >= 2.0 and
            processor.brightnessTemperatureRangeLow <= 3.0 and
            processor.brightnessTemperatureRangeHigh >= 330.0
        }
    }

    satisfy PrimaryFunctionRequirement by MicrowaveRadiometer;
    satisfy PassiveSensingRequirement by MicrowaveRadiometer;
    satisfy CalibrationAccuracyRequirement by CalibrationSubsystem;
    satisfy ObservationResolutionRequirement by MicrowaveRadiometer;
    satisfy ReceiverSensitivityRequirement by MicrowaveReceiver;
    satisfy DataProductRequirement by RadiometerSignalProcessor;
}