package ImageSensingUnitModel {

    // ================================================================
    // Unit Definitions
    // ================================================================
    unit degC;
    unit lux;
    unit ms;
    unit dB;
    unit Mbps;
    unit W;
    unit V;
    unit MHz;
    unit MB;
    unit rpm;
    unit px;

    // ================================================================
    // Value Type Definitions
    // ================================================================
    value type Temperature :> ScalarValues::Real {
        unit degC;
    }

    value type Illuminance :> ScalarValues::Real {
        unit lux;
    }

    value type ExposureTime :> ScalarValues::Real {
        unit ms;
    }

    value type Gain :> ScalarValues::Real {
        unit dB;
    }

    value type DataRate :> ScalarValues::Real {
        unit Mbps;
    }

    value type Power :> ScalarValues::Real {
        unit W;
    }

    value type Voltage :> ScalarValues::Real {
        unit V;
    }

    value type ClockFrequency :> ScalarValues::Real {
        unit MHz;
    }

    value type StorageCapacity :> ScalarValues::Real {
        unit MB;
    }

    value type FanSpeed :> ScalarValues::Real {
        unit rpm;
    }

    value type PixelResolution :> ScalarValues::Integer {
        unit px;
    }

    // ================================================================
    // Item Definitions
    // ================================================================
    item def Light {
        attribute illuminance : Illuminance;
        attribute wavelengthRange : ScalarValues::Real;
    }

    item def AnalogImageSignal {
        attribute amplitude : Voltage;
        attribute bandwidth : ClockFrequency;
    }

    item def ExposureSettings {
        attribute exposureTime : ExposureTime;
        attribute gain : Gain;
    }

    item def RawImageFrame {
        attribute resolution : PixelResolution;
        attribute bitDepth : ScalarValues::Integer;
        attribute exposure : ExposureTime;
        attribute gain : Gain;
        attribute timestamp : ScalarValues::Integer;
    }

    item def ProcessedImageFrame {
        attribute resolution : PixelResolution;
        attribute bitDepth : ScalarValues::Integer;
        attribute brightness : ScalarValues::Real;
        attribute contrast : ScalarValues::Real;
        attribute noiseLevel : ScalarValues::Real;
        attribute sharpness : ScalarValues::Real;
        attribute timestamp : ScalarValues::Integer;
    }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute maxPower : Power;
    }

    item def CommandMessage {
        attribute commandType : ScalarValues::String;
        attribute targetExposure : ExposureTime;
        attribute targetGain : Gain;
        attribute outputMode : ScalarValues::String;
    }

    item def StatusReport {
        attribute operationalState : ScalarValues::String;
        attribute temperature : Temperature;
        attribute errorCode : ScalarValues::Integer;
        attribute framesCaptured : ScalarValues::Integer;
        attribute framesTransmitted : ScalarValues::Integer;
        attribute currentExposure : ExposureTime;
        attribute currentGain : Gain;
    }

    item def HeatDissipation {
        attribute thermalPower : Power;
        attribute ambientTemperature : Temperature;
    }

    // ================================================================
    // Port Definitions
    // ================================================================
    port def OpticalInPort {
        in light : Light;
    }

    port def OpticalOutPort {
        out light : Light;
    }

    port def AnalogOutPort {
        out analogSignal : AnalogImageSignal;
    }

    port def AnalogInPort {
        in analogSignal : AnalogImageSignal;
    }

    port def RawDataInPort {
        in frame : RawImageFrame;
    }

    port def RawDataOutPort {
        out frame : RawImageFrame;
    }

    port def ProcessedDataInPort {
        in frame : ProcessedImageFrame;
    }

    port def ProcessedDataOutPort {
        out frame : ProcessedImageFrame;
    }

    port def IlluminanceInPort {
        in illuminance : Illuminance;
    }

    port def IlluminanceOutPort {
        out illuminance : Illuminance;
    }

    port def ExposureSettingsOutPort {
        out settings : ExposureSettings;
    }

    port def ExposureSettingsInPort {
        in settings : ExposureSettings;
    }

    port def CommandInPort {
        in command : CommandMessage;
    }

    port def StatusOutPort {
        out status : StatusReport;
    }

    port def PowerInPort {
        in power : ElectricalPower;
    }

    port def PowerOutPort {
        out power : ElectricalPower;
    }

    port def ThermalOutPort {
        out heat : HeatDissipation;
    }

    port def TemperatureOutPort {
        out temperature : Temperature;
    }

    // ================================================================
    // Component Part Definitions
    // ================================================================

    part def LensAssembly {
        attribute focalLength : ScalarValues::Real;
        attribute apertureRange : ScalarValues::Real;
        attribute minFocusDistance : ScalarValues::Real;
        attribute isAutoFocus : ScalarValues::Boolean = true;
        port opticalIn : OpticalInPort;
        port opticalOut : OpticalOutPort;
        flow : Light from opticalIn to opticalOut;
    }

    part def PhotodetectorArray {
        attribute resolution : PixelResolution;
        attribute quantumEfficiency : ScalarValues::Real;
        attribute pixelPitch : ScalarValues::Real;
        attribute currentExposure : ExposureTime;
        attribute currentGain : Gain;
        port opticalIn : OpticalInPort;
        port settingsIn : ExposureSettingsInPort;
        port analogOut : AnalogOutPort;
        port powerIn : PowerInPort;
        flow : Light from opticalIn;
        flow : ExposureSettings from settingsIn;
        flow : AnalogImageSignal from analogOut;
        flow : ElectricalPower from powerIn;
    }

    part def IlluminanceMeter {
        attribute sensitivity : Illuminance;
        attribute measurementRange : Illuminance;
        attribute responseTime : ExposureTime = 5 [ms];
        port opticalIn : OpticalInPort;
        port illuminanceOut : IlluminanceOutPort;
        port powerIn : PowerInPort;
        flow : Light from opticalIn;
        flow : Illuminance from illuminanceOut;
        flow : ElectricalPower from powerIn;
    }

    part def ExposureControlUnit {
        attribute minExposure : ExposureTime = 0.01 [ms];
        attribute maxExposure : ExposureTime = 1000 [ms];
        attribute minGain : Gain = 0 [dB];
        attribute maxGain : Gain = 48 [dB];
        attribute autoExposureEnabled : ScalarValues::Boolean = true;
        attribute computedExposureTime : ExposureTime;
        attribute computedGain : Gain;
        port illuminanceIn : IlluminanceInPort;
        port externalSettingsIn : ExposureSettingsInPort;
        port settingsOut : ExposureSettingsOutPort;
        flow : Illuminance from illuminanceIn;
        flow : ExposureSettings from externalSettingsIn;
        flow : ExposureSettings from settingsOut;
    }

    part def AnalogToDigitalConverter {
        attribute samplingRate : ClockFrequency;
        attribute bitDepth : ScalarValues::Integer = 12;
        attribute signalToNoiseRatio : ScalarValues::Real;
        attribute conversionLatency : ExposureTime = 2 [ms];
        port analogIn : AnalogInPort;
        port digitalOut : RawDataOutPort;
        port powerIn : PowerInPort;
        flow : AnalogImageSignal from analogIn;
        flow : RawImageFrame from digitalOut;
        flow : ElectricalPower from powerIn;
    }

    part def ImageSignalProcessor {
        attribute brightnessCorrection : ScalarValues::Real;
        attribute contrastCorrection : ScalarValues::Real;
        attribute noiseReductionLevel : ScalarValues::Real;
        attribute sharpnessEnhancement : ScalarValues::Real;
        attribute colorCorrectionEnabled : ScalarValues::Boolean = true;
        attribute gammaCorrection : ScalarValues::Real = 2.2;
        attribute processingLatency : ExposureTime = 10 [ms];
        port frameIn : RawDataInPort;
        port frameOut : ProcessedDataOutPort;
        port powerIn : PowerInPort;
        flow : RawImageFrame from frameIn;
        flow : ProcessedImageFrame from frameOut;
        flow : ElectricalPower from powerIn;
    }

    part def PowerManagement {
        attribute inputVoltage : Voltage;
        attribute outputVoltage : Voltage = 3.3 [V];
        attribute maxOutputPower : Power = 15 [W];
        attribute efficiency : ScalarValues::Real = 0.92;
        attribute rippleNoise : Voltage;
        attribute overcurrentProtection : ScalarValues::Boolean = true;
        port powerIn : PowerInPort;
        port sensorPower : PowerOutPort;
        port adcPower : PowerOutPort;
        port ispPower : PowerOutPort;
        port storagePower : PowerOutPort;
        port controlPower : PowerOutPort;
        flow : ElectricalPower from powerIn;
        flow : ElectricalPower from sensorPower;
        flow : ElectricalPower from adcPower;
        flow : ElectricalPower from ispPower;
        flow : ElectricalPower from storagePower;
        flow : ElectricalPower from controlPower;
    }

    part def ThermalRegulation {
        attribute targetTemperature : Temperature = 45 [degC];
        attribute maxOperatingTemp : Temperature = 70 [degC];
        attribute criticalTemp : Temperature = 85 [degC];
        attribute currentFanSpeed : FanSpeed;
        attribute activeCoolingEnabled : ScalarValues::Boolean = true;
        attribute heatsinkArea : ScalarValues::Real;
        port thermalOut : ThermalOutPort;
        port tempOut : TemperatureOutPort;
        state thermalControl {
            initial;
            state idle;
            state cooling;
            state overtempShutdown;
            state failureMode;
            transition initial to idle;
            transition idle to cooling when tempOut.temperature > 50 [degC];
            transition cooling to idle when tempOut.temperature < 40 [degC];
            transition cooling to overtempShutdown when tempOut.temperature > 70 [degC];
            transition overtempShutdown to idle when tempOut.temperature < 35 [degC];
            transition overtempShutdown to failureMode when tempOut.temperature > 85 [degC];
        }
        flow : HeatDissipation from thermalOut;
        flow : Temperature from tempOut;
    }

    part def InternalStorage {
        attribute totalCapacity : StorageCapacity = 8192 [MB];
        attribute usedSpace : StorageCapacity = 0 [MB];
        attribute maxFramesStored : ScalarValues::Integer = 10000;
        attribute framesCurrentlyStored : ScalarValues::Integer = 0;
        attribute writeSpeed : DataRate;
        port rawIn : RawDataInPort;
        port rawOut : RawDataOutPort;
        port processedIn : ProcessedDataInPort;
        port processedOut : ProcessedDataOutPort;
        port powerIn : PowerInPort;
        flow : RawImageFrame from rawIn;
        flow : RawImageFrame from rawOut;
        flow : ProcessedImageFrame from processedIn;
        flow : ProcessedImageFrame from processedOut;
        flow : ElectricalPower from powerIn;
    }

    part def ControlInterface {
        attribute firmwareVersion : ScalarValues::String;
        attribute currentOperationalState : ScalarValues::String;
        attribute lastCommand : CommandMessage;
        attribute commandQueueDepth : ScalarValues::Integer = 0;
        attribute errorFlags : ScalarValues::Integer = 0;
        attribute responseLatency : ExposureTime = 5 [ms];
        port commandIn : CommandInPort;
        port statusOut : StatusOutPort;
        port settingsOut : ExposureSettingsOutPort;
        port powerIn : PowerInPort;
        flow : CommandMessage from commandIn;
        flow : StatusReport from statusOut;
        flow : ExposureSettings from settingsOut;
        flow : ElectricalPower from powerIn;
    }

    // ================================================================
    // Main System: Image Sensing Unit
    // ================================================================
    part def ImageSensingUnit {
        port externalOpticalIn : OpticalInPort;
        port externalCommandIn : CommandInPort;
        port externalStatusOut : StatusOutPort;
        port externalRawOut : RawDataOutPort;
        port externalProcessedOut : ProcessedDataOutPort;
        port externalPowerIn : PowerInPort;
        port externalThermalOut : ThermalOutPort;
        port externalTempOut : TemperatureOutPort;

        part lensAssembly : LensAssembly;
        part sensorChip : PhotodetectorArray;
        part illuminanceMeter : IlluminanceMeter;
        part exposureControl : ExposureControlUnit;
        part adc : AnalogToDigitalConverter;
        part isp : ImageSignalProcessor;
        part powerManagement : PowerManagement;
        part thermalRegulation : ThermalRegulation;
        part internalStorage : InternalStorage;
        part controlInterface : ControlInterface;

        // Optical path connections
        connection externalOpticalIn to lensAssembly.opticalIn;
        connection lensAssembly.opticalOut to sensorChip.opticalIn;
        connection lensAssembly.opticalOut to illuminanceMeter.opticalIn;

        // Exposure control path connections
        connection illuminanceMeter.illuminanceOut to exposureControl.illuminanceIn;
        connection exposureControl.settingsOut to sensorChip.settingsIn;
        connection controlInterface.settingsOut to exposureControl.externalSettingsIn;

        // Image data path connections
        connection sensorChip.analogOut to adc.analogIn;
        connection adc.digitalOut to isp.frameIn;
        connection adc.digitalOut to internalStorage.rawIn;
        connection isp.frameOut to internalStorage.processedIn;

        // Output path connections
        connection internalStorage.rawOut to externalRawOut;
        connection internalStorage.processedOut to externalProcessedOut;

        // Power distribution connections
        connection externalPowerIn to powerManagement.powerIn;
        connection powerManagement.sensorPower to sensorChip.powerIn;
        connection powerManagement.adcPower to adc.powerIn;
        connection powerManagement.ispPower to isp.powerIn;
        connection powerManagement.storagePower to internalStorage.powerIn;
        connection powerManagement.controlPower to controlInterface.powerIn;

        // Thermal connections
        connection thermalRegulation.thermalOut to externalThermalOut;
        connection thermalRegulation.tempOut to externalTempOut;

        // Control interface connections
        connection externalCommandIn to controlInterface.commandIn;
        connection controlInterface.statusOut to externalStatusOut;

        // System-level operational attributes
        attribute currentTemperature : Temperature;
        attribute currentExposure : ExposureTime = 10 [ms];
        attribute currentGain : Gain = 6 [dB];
        attribute operationalState : ScalarValues::String = "power-off";
        attribute framesCaptured : ScalarValues::Integer = 0;
        attribute framesProcessed : ScalarValues::Integer = 0;
        attribute framesTransmitted : ScalarValues::Integer = 0;
        attribute outputMode : ScalarValues::String = "both";
        attribute isPowered : ScalarValues::Boolean = false;
        attribute captureRequested : ScalarValues::Boolean = false;
        attribute transmissionComplete : ScalarValues::Boolean = false;
        attribute errorCode : ScalarValues::Integer = 0;

        // Lifecycle state machine
        state lifecycle {
            initial;

            state powerOff {
                entry { operationalState = "power-off"; isPowered = false; }
            }

            state standby {
                entry { operationalState = "standby"; captureRequested = false; }
            }

            state capturing {
                entry { operationalState = "capturing"; framesCaptured = framesCaptured + 1; }
            }

            state processing {
                entry { operationalState = "processing"; framesProcessed = framesProcessed + 1; }
            }

            state transmitting {
                entry { operationalState = "transmitting"; }
                exit { framesTransmitted = framesTransmitted + 1; transmissionComplete = true; }
            }

            state fault {
                entry { operationalState = "fault"; errorCode = 1; }
            }

            transition initial to powerOff;
            transition powerOff to standby when isPowered;
            transition standby to powerOff when not isPowered;
            transition standby to capturing when captureRequested;
            transition capturing to processing when framesCaptured > 0;
            transition processing to transmitting when framesProcessed > 0;
            transition transmitting to standby when transmissionComplete;
            transition standby to fault when thermalRegulation.tempOut.temperature > 70 [degC];
            transition fault to standby when thermalRegulation.tempOut.temperature < 50 [degC] and not captureRequested;
            transition powerOff to fault when thermalRegulation.tempOut.temperature > 85 [degC];
        }
    }

    // ================================================================
    // Requirement Definitions
    // ================================================================

    requirement def ImageCaptureRequirement {
        doc {
            The Image Sensing Unit shall capture optical light from an external scene
            through a lens assembly and convert it to an analog electrical signal
            using a photodetector array with integrated illuminance measurement
            for automatic exposure control.
        }
        subject sensingUnit : ImageSensingUnit;
        objective {
            assert sensingUnit.sensorChip.resolution > 0 [px];
            assert sensingUnit.lensAssembly.focalLength > 0;
            assert sensingUnit.illuminanceMeter.sensitivity > 0 [lux];
        }
    }

    requirement def ImageProcessingRequirement {
        doc {
            The Image Signal Processor shall enhance raw image frames by performing
            brightness correction, contrast correction, noise reduction, and
            additional enhancement algorithms to produce processed image frames
            suitable for external output.
        }
        subject sensingUnit : ImageSensingUnit;
        objective {
            assert sensingUnit.isp.noiseReductionLevel >= 0;
            assert sensingUnit.isp.brightnessCorrection >= 0;
            assert sensingUnit.isp.contrastCorrection >= 0;
        }
    }

    requirement def ExternalControlRequirement {
        doc {
            The Image Sensing Unit shall accept external commands to adjust exposure
            time, gain settings, and output mode (raw, processed, or both) through
            a dedicated command interface port.
        }
        subject sensingUnit : ImageSensingUnit;
        objective {
            assert sensingUnit.controlInterface.commandQueueDepth >= 0;
        }
    }

    requirement def StatusReportingRequirement {
        doc {
            The Image Sensing Unit shall send detailed status reports including
            operational state, temperature, error codes, and frame statistics
            via the external status port to the controlling external system.
        }
        subject sensingUnit : ImageSensingUnit;
        objective {
            assert sensingUnit.controlInterface.firmwareVersion != "";
        }
    }

    requirement def LifecycleManagementRequirement {
        doc {
            The Image Sensing Unit shall manage its lifecycle through the states:
            power-off, standby, capturing, processing, and transmitting,
            with transitions driven by power state, commands, and processing completion.
        }
        subject sensingUnit : ImageSensingUnit;
    }

    requirement def DualOutputRequirement {
        doc {
            The Image Sensing Unit shall provide both raw sensor data and processed
            image frames as simultaneous outputs, providing flexibility for
            different downstream applications.
        }
        subject sensingUnit : ImageSensingUnit;
        objective {
            assert sensingUnit.internalStorage.totalCapacity >= 1024 [MB];
        }
    }

    requirement def PowerManagementRequirement {
        doc {
            The Image Sensing Unit shall include self-contained power management
            providing regulated electrical power to all internal components with
            overcurrent protection and conversion efficiency above 85 percent.
        }
        subject sensingUnit : ImageSensingUnit;
        objective {
            assert sensingUnit.powerManagement.outputVoltage >= 3.0 [V];
            assert sensingUnit.powerManagement.efficiency >= 0.85;
            assert sensingUnit.powerManagement.maxOutputPower >= 10 [W];
        }
    }

    requirement def ThermalRegulationRequirement {
        doc {
            The Image Sensing Unit shall include active thermal regulation with
            cooling, maintaining internal temperature below 70 degC under normal
            operating conditions and entering protective shutdown above 85 degC.
        }
        subject sensingUnit : ImageSensingUnit;
        objective {
            assert sensingUnit.thermalRegulation.maxOperatingTemp <= 70 [degC];
            assert sensingUnit.thermalRegulation.criticalTemp <= 85 [degC];
        }
    }

    requirement def InternalStorageRequirement {
        doc {
            The Image Sensing Unit shall include internal data storage for buffering
            raw and processed image frames before external transmission, with
            capacity sufficient for at least 1000 frames.
        }
        subject sensingUnit : ImageSensingUnit;
        objective {
            assert sensingUnit.internalStorage.totalCapacity >= 1024 [MB];
            assert sensingUnit.internalStorage.maxFramesStored >= 1000;
        }
    }

    requirement def ExposureControlRequirement {
        doc {
            The Exposure Control Unit shall automatically calculate optimal exposure
            time and gain based on scene illuminance measured by the integrated
            illuminance meter, with manual override capability via external commands.
        }
        subject sensingUnit : ImageSensingUnit;
        objective {
            assert sensingUnit.exposureControl.minExposure >= 0.01 [ms];
            assert sensingUnit.exposureControl.maxExposure <= 1000 [ms];
            assert sensingUnit.exposureControl.autoExposureEnabled == true;
        }
    }

    // ================================================================
    // Requirement Usages
    // ================================================================
    requirement imageCaptureReq : ImageCaptureRequirement {
        subject sensingUnit : ImageSensingUnit;
    }

    requirement imageProcessingReq : ImageProcessingRequirement {
        subject sensingUnit : ImageSensingUnit;
    }

    requirement externalControlReq : ExternalControlRequirement {
        subject sensingUnit : ImageSensingUnit;
    }

    requirement statusReportingReq : StatusReportingRequirement {
        subject sensingUnit : ImageSensingUnit;
    }

    requirement lifecycleMgmtReq : LifecycleManagementRequirement {
        subject sensingUnit : ImageSensingUnit;
    }

    requirement dualOutputReq : DualOutputRequirement {
        subject sensingUnit : ImageSensingUnit;
    }

    requirement powerMgmtReq : PowerManagementRequirement {
        subject sensingUnit : ImageSensingUnit;
    }

    requirement thermalRegulationReq : ThermalRegulationRequirement {
        subject sensingUnit : ImageSensingUnit;
    }

    requirement internalStorageReq : InternalStorageRequirement {
        subject sensingUnit : ImageSensingUnit;
    }

    requirement exposureControlReq : ExposureControlRequirement {
        subject sensingUnit : ImageSensingUnit;
    }
}
