package SpecialMicrowaveImagerSensingUnitModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Power {
        :> ScalarValues::Real;
        unit = "W";
    }

    attribute def Voltage {
        :> ScalarValues::Real;
        unit = "V";
    }

    attribute def Current {
        :> ScalarValues::Real;
        unit = "A";
    }

    attribute def Temperature {
        :> ScalarValues::Real;
        unit = "K";
    }

    attribute def Frequency {
        :> ScalarValues::Real;
        unit = "GHz";
    }

    attribute def Bandwidth {
        :> ScalarValues::Real;
        unit = "MHz";
    }

    attribute def Angle {
        :> ScalarValues::Real;
        unit = "deg";
    }

    attribute def TimeDuration {
        :> ScalarValues::Real;
        unit = "s";
    }

    attribute def DataRate {
        :> ScalarValues::Real;
        unit = "Mb/s";
    }

    attribute def NoiseEquivalentDeltaTemperature {
        :> ScalarValues::Real;
        unit = "K";
    }

    attribute def SpatialResolution {
        :> ScalarValues::Real;
        unit = "m";
    }

    attribute def ImageDimension {
        :> ScalarValues::Integer;
        unit = "pixel";
    }

    attribute def Percent {
        :> ScalarValues::Real;
        unit = "%";
    }

    item def MicrowaveRadiance {
        attribute centerFrequency : Frequency;
        attribute bandwidth : Bandwidth;
        attribute polarization : PolarizationKind;
        attribute brightnessTemperature : Temperature;
        attribute incidenceAngle : Angle;
    }

    item def RawMicrowaveSample {
        attribute sampleTime : TimeDuration;
        attribute channelFrequency : Frequency;
        attribute inPhaseVoltage : Voltage;
        attribute quadratureVoltage : Voltage;
        attribute detectorTemperature : Temperature;
    }

    item def CalibratedBrightnessPixel {
        attribute row : ImageDimension;
        attribute column : ImageDimension;
        attribute brightnessTemperature : Temperature;
        attribute uncertainty : NoiseEquivalentDeltaTemperature;
        attribute polarization : PolarizationKind;
        attribute incidenceAngle : Angle;
    }

    item def MicrowaveImageFrame {
        attribute frameTime : TimeDuration;
        attribute rows : ImageDimension;
        attribute columns : ImageDimension;
        attribute groundSampleDistance : SpatialResolution;
        attribute swathWidth : SpatialResolution;
        attribute channelCount : ScalarValues::Integer;
        part pixels : CalibratedBrightnessPixel[0..*];
    }

    item def HealthReport {
        attribute receiverTemperature : Temperature;
        attribute calibrationTargetTemperature : Temperature;
        attribute supplyVoltage : Voltage;
        attribute consumedPower : Power;
        attribute linkMargin : Percent;
        attribute valid : Boolean;
    }

    item def PowerFeed {
        attribute busVoltage : Voltage;
        attribute availablePower : Power;
    }

    item def CommandMessage {
        attribute commandId : ScalarValues::Integer;
        attribute requestedMode : SensingModeKind;
        attribute requestedIntegrationTime : TimeDuration;
    }

    item def TelemetryPacket {
        attribute packetTime : TimeDuration;
        attribute dataRate : DataRate;
        attribute validChecksum : Boolean;
        part image : MicrowaveImageFrame[0..1];
        part health : HealthReport[0..1];
    }

    enum def PolarizationKind {
        enum H;
        enum V;
        enum RHCP;
        enum LHCP;
    }

    enum def SensingModeKind {
        enum Off;
        enum Standby;
        enum Calibrate;
        enum Image;
        enum Safe;
    }

    port def MicrowaveAperturePort {
        in radiance : MicrowaveRadiance;
    }

    port def PowerInputPort {
        in feed : PowerFeed;
    }

    port def CommandInputPort {
        in command : CommandMessage;
    }

    port def TelemetryOutputPort {
        out telemetry : TelemetryPacket;
    }

    port def SamplePort {
        out sample : RawMicrowaveSample;
    }

    port def CalibratedPixelPort {
        out pixel : CalibratedBrightnessPixel;
    }

    port def ThermalPort {
        inout heatFlow : Power;
        inout interfaceTemperature : Temperature;
    }

    action def ReceiveMicrowaveRadiance {
        in sceneRadiance : MicrowaveRadiance;
        out capturedRadiance : MicrowaveRadiance;
    }

    action def DownconvertMicrowaveSignal {
        in capturedRadiance : MicrowaveRadiance;
        in localOscillatorFrequency : Frequency;
        out rawSample : RawMicrowaveSample;
    }

    action def CalibrateSample {
        in rawSample : RawMicrowaveSample;
        in coldTargetTemperature : Temperature;
        in hotTargetTemperature : Temperature;
        out calibratedPixel : CalibratedBrightnessPixel;
    }

    action def AssembleImageFrame {
        in pixel : CalibratedBrightnessPixel[1..*];
        in frameTime : TimeDuration;
        out frame : MicrowaveImageFrame;
    }

    action def TransmitTelemetry {
        in image : MicrowaveImageFrame;
        in health : HealthReport;
        out packet : TelemetryPacket;
    }

    state def SensingUnitOperatingStates {
        entry action initializeElectronics;
        state off;
        state standby;
        state calibrating;
        state imaging;
        state safe;

        transition first off;
        transition off_to_standby
            first off
            then standby
            accept CommandMessage
            if command.requestedMode == SensingModeKind::Standby;

        transition standby_to_calibrate
            first standby
            then calibrating
            accept CommandMessage
            if command.requestedMode == SensingModeKind::Calibrate;

        transition calibrate_to_image
            first calibrating
            then imaging
            accept CommandMessage
            if command.requestedMode == SensingModeKind::Image;

        transition image_to_standby
            first imaging
            then standby
            accept CommandMessage
            if command.requestedMode == SensingModeKind::Standby;

        transition any_to_safe_from_overtemp
            first standby
            then safe
            if receiverTemperature > 325.0 [K];

        transition imaging_to_safe_from_low_power
            first imaging
            then safe
            if supplyVoltage < 22.0 [V];

        transition safe_to_standby
            first safe
            then standby
            accept CommandMessage
            if command.requestedMode == SensingModeKind::Standby and receiverTemperature < 315.0 [K];
    }

    part def MicrowaveImagerSensor {
        attribute centerFrequency : Frequency = 37.0 [GHz];
        attribute bandwidth : Bandwidth = 800.0 [MHz];
        attribute noiseEquivalentDeltaTemperature : NoiseEquivalentDeltaTemperature = 0.45 [K];
        attribute horizontalFieldOfView : Angle = 42.0 [deg];
        attribute verticalFieldOfView : Angle = 28.0 [deg];
        attribute integrationTime : TimeDuration = 0.012 [s];
        attribute detectorTemperature : Temperature;
        attribute consumedPower : Power;

        port aperture : MicrowaveAperturePort;
        port sampleOut : SamplePort;
        port thermal : ThermalPort;

        perform action receive : ReceiveMicrowaveRadiance;
        perform action downconvert : DownconvertMicrowaveSignal;

        bind receive.sceneRadiance = aperture.radiance;
        bind receive.capturedRadiance = downconvert.capturedRadiance;
        bind sampleOut.sample = downconvert.rawSample;

        constraint sensorSensitivity {
            noiseEquivalentDeltaTemperature <= 0.50 [K]
        }

        constraint operatingThermalLimit {
            detectorTemperature >= 250.0 [K] and detectorTemperature <= 325.0 [K]
        }
    }

    part def CalibrationSubsystem {
        attribute coldTargetTemperature : Temperature = 77.0 [K];
        attribute hotTargetTemperature : Temperature = 300.0 [K];
        attribute calibrationStability : NoiseEquivalentDeltaTemperature = 0.08 [K];
        attribute consumedPower : Power;

        port sampleIn : SamplePort;
        port pixelOut : CalibratedPixelPort;
        port thermal : ThermalPort;

        perform action calibrate : CalibrateSample;

        bind calibrate.rawSample = sampleIn.sample;
        bind calibrate.coldTargetTemperature = coldTargetTemperature;
        bind calibrate.hotTargetTemperature = hotTargetTemperature;
        bind pixelOut.pixel = calibrate.calibratedPixel;

        constraint calibrationAccuracy {
            calibrationStability <= 0.10 [K]
        }
    }

    part def ImageProcessor {
        attribute frameRows : ImageDimension = 512 [pixel];
        attribute frameColumns : ImageDimension = 512 [pixel];
        attribute outputDataRate : DataRate = 120.0 [Mb/s];
        attribute groundSampleDistance : SpatialResolution = 500.0 [m];
        attribute swathWidth : SpatialResolution = 260000.0 [m];
        attribute consumedPower : Power;

        port pixelIn : CalibratedPixelPort;
        port telemetryOut : TelemetryOutputPort;
        port commandIn : CommandInputPort;

        perform action assemble : AssembleImageFrame;
        perform action transmit : TransmitTelemetry;

        bind assemble.pixel = pixelIn.pixel;
        bind transmit.image = assemble.frame;
        bind telemetryOut.telemetry = transmit.packet;

        constraint imageSize {
            frameRows == 512 [pixel] and frameColumns == 512 [pixel]
        }

        constraint dataRateLimit {
            outputDataRate <= 150.0 [Mb/s]
        }
    }

    part def PowerConditioner {
        attribute inputVoltage : Voltage;
        attribute regulatedVoltage : Voltage = 28.0 [V];
        attribute maximumOutputPower : Power = 85.0 [W];
        attribute efficiency : Percent = 91.0 [%];

        port powerIn : PowerInputPort;
        port sensorPowerOut : PowerInputPort;
        port processorPowerOut : PowerInputPort;
        port calibrationPowerOut : PowerInputPort;

        constraint busVoltageRange {
            powerIn.feed.busVoltage >= 22.0 [V] and powerIn.feed.busVoltage <= 34.0 [V]
        }

        constraint powerCapacity {
            maximumOutputPower >= 70.0 [W]
        }
    }

    part def ThermalController {
        attribute radiatorInterfaceTemperature : Temperature = 285.0 [K];
        attribute receiverTemperature : Temperature;
        attribute maximumRejectedHeat : Power = 60.0 [W];

        port sensorThermal : ThermalPort;
        port calibrationThermal : ThermalPort;
        port chassisThermal : ThermalPort;

        constraint thermalRejection {
            maximumRejectedHeat >= 45.0 [W]
        }

        constraint receiverThermalRange {
            receiverTemperature >= 250.0 [K] and receiverTemperature <= 325.0 [K]
        }
    }

    part def CommandAndDataInterface {
        attribute commandLatency : TimeDuration = 0.050 [s];
        attribute telemetryRate : DataRate = 120.0 [Mb/s];

        port commandIn : CommandInputPort;
        port telemetryIn : TelemetryOutputPort;
        port telemetryOut : TelemetryOutputPort;

        bind telemetryOut.telemetry = telemetryIn.telemetry;

        constraint commandLatencyLimit {
            commandLatency <= 0.100 [s]
        }
    }

    part def SpecialMicrowaveImagerSensingUnit {
        attribute mode : SensingModeKind;
        attribute supplyVoltage : Voltage;
        attribute totalPower : Power;
        attribute receiverTemperature : Temperature;
        attribute measuredQuantity : Temperature;
        attribute requiredSpatialResolution : SpatialResolution = 500.0 [m];

        port microwaveSceneInput : MicrowaveAperturePort;
        port powerInput : PowerInputPort;
        port commandInput : CommandInputPort;
        port telemetryOutput : TelemetryOutputPort;
        port chassisThermal : ThermalPort;

        part sensor : MicrowaveImagerSensor;
        part calibration : CalibrationSubsystem;
        part processor : ImageProcessor;
        part power : PowerConditioner;
        part thermal : ThermalController;
        part cdi : CommandAndDataInterface;

        perform state operatingState : SensingUnitOperatingStates;

        connect microwaveSceneInput to sensor.aperture;
        connect sensor.sampleOut to calibration.sampleIn;
        connect calibration.pixelOut to processor.pixelIn;
        connect processor.telemetryOut to cdi.telemetryIn;
        connect cdi.telemetryOut to telemetryOutput;

        connect commandInput to cdi.commandIn;
        connect cdi.commandIn to processor.commandIn;

        connect powerInput to power.powerIn;
        connect sensor.thermal to thermal.sensorThermal;
        connect calibration.thermal to thermal.calibrationThermal;
        connect thermal.chassisThermal to chassisThermal;

        bind receiverTemperature = thermal.receiverTemperature;
        bind measuredQuantity = calibration.pixelOut.pixel.brightnessTemperature;
        bind supplyVoltage = power.powerIn.feed.busVoltage;
        bind totalPower = sensor.consumedPower + calibration.consumedPower + processor.consumedPower;

        constraint totalPowerBudget {
            totalPower <= 70.0 [W]
        }

        constraint measurementRange {
            measuredQuantity >= 50.0 [K] and measuredQuantity <= 350.0 [K]
        }

        constraint spatialResolutionPerformance {
            processor.groundSampleDistance <= requiredSpatialResolution
        }

        constraint fieldOfViewCoverage {
            sensor.horizontalFieldOfView >= 40.0 [deg] and sensor.verticalFieldOfView >= 25.0 [deg]
        }
    }

    requirement def MeasureMicrowaveBrightnessTemperature {
        subject sensingUnit : SpecialMicrowaveImagerSensingUnit;
        require constraint {
            sensingUnit.measuredQuantity >= 50.0 [K] and sensingUnit.measuredQuantity <= 350.0 [K]
        }
    }

    requirement def UseSpecialMicrowaveImagerSensor {
        subject sensingUnit : SpecialMicrowaveImagerSensingUnit;
        require constraint {
            sensingUnit.sensor.centerFrequency == 37.0 [GHz] and
            sensingUnit.sensor.bandwidth >= 800.0 [MHz]
        }
    }

    requirement def ImagingResolutionRequirement {
        subject sensingUnit : SpecialMicrowaveImagerSensingUnit;
        require constraint {
            sensingUnit.processor.groundSampleDistance <= 500.0 [m] and
            sensingUnit.processor.frameRows >= 512 [pixel] and
            sensingUnit.processor.frameColumns >= 512 [pixel]
        }
    }

    requirement def RadiometricSensitivityRequirement {
        subject sensingUnit : SpecialMicrowaveImagerSensingUnit;
        require constraint {
            sensingUnit.sensor.noiseEquivalentDeltaTemperature <= 0.50 [K]
        }
    }

    requirement def PowerRequirement {
        subject sensingUnit : SpecialMicrowaveImagerSensingUnit;
        require constraint {
            sensingUnit.totalPower <= 70.0 [W] and
            sensingUnit.supplyVoltage >= 22.0 [V] and
            sensingUnit.supplyVoltage <= 34.0 [V]
        }
    }

    requirement def ThermalRequirement {
        subject sensingUnit : SpecialMicrowaveImagerSensingUnit;
        require constraint {
            sensingUnit.receiverTemperature >= 250.0 [K] and
            sensingUnit.receiverTemperature <= 325.0 [K]
        }
    }

    requirement def TelemetryRequirement {
        subject sensingUnit : SpecialMicrowaveImagerSensingUnit;
        require constraint {
            sensingUnit.processor.outputDataRate <= 150.0 [Mb/s]
        }
    }

    satisfy MeasureMicrowaveBrightnessTemperature by SpecialMicrowaveImagerSensingUnit;
    satisfy UseSpecialMicrowaveImagerSensor by MicrowaveImagerSensor;
    satisfy ImagingResolutionRequirement by ImageProcessor;
    satisfy RadiometricSensitivityRequirement by MicrowaveImagerSensor;
    satisfy PowerRequirement by PowerConditioner;
    satisfy ThermalRequirement by ThermalController;
    satisfy TelemetryRequirement by CommandAndDataInterface;

    part operationalSensingUnit : SpecialMicrowaveImagerSensingUnit {
        attribute mode = SensingModeKind::Standby;
        attribute supplyVoltage = 28.0 [V];
        attribute receiverTemperature = 285.0 [K];
        attribute totalPower = 62.0 [W];

        part sensor {
            attribute centerFrequency = 37.0 [GHz];
            attribute bandwidth = 800.0 [MHz];
            attribute noiseEquivalentDeltaTemperature = 0.45 [K];
            attribute detectorTemperature = 285.0 [K];
            attribute consumedPower = 32.0 [W];
        }

        part calibration {
            attribute coldTargetTemperature = 77.0 [K];
            attribute hotTargetTemperature = 300.0 [K];
            attribute calibrationStability = 0.08 [K];
            attribute consumedPower = 8.0 [W];
        }

        part processor {
            attribute frameRows = 512 [pixel];
            attribute frameColumns = 512 [pixel];
            attribute outputDataRate = 120.0 [Mb/s];
            attribute groundSampleDistance = 500.0 [m];
            attribute swathWidth = 260000.0 [m];
            attribute consumedPower = 22.0 [W];
        }

        part power {
            attribute regulatedVoltage = 28.0 [V];
            attribute maximumOutputPower = 85.0 [W];
            attribute efficiency = 91.0 [%];
        }

        part thermal {
            attribute radiatorInterfaceTemperature = 285.0 [K];
            attribute receiverTemperature = 285.0 [K];
            attribute maximumRejectedHeat = 60.0 [W];
        }
    }
}