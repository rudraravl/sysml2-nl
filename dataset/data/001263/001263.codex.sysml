package StaringArraySystemModel {

    import ScalarValues::*;
    import SI::*;

    attribute def Temperature {
        :> ScalarValues::Real;
        unit = "K";
    }

    attribute def Radiance {
        :> ScalarValues::Real;
        unit = "W/(m^2*sr)";
    }

    attribute def Irradiance {
        :> ScalarValues::Real;
        unit = "W/m^2";
    }

    attribute def Wavelength {
        :> ScalarValues::Real;
        unit = "um";
    }

    attribute def FrameRate {
        :> ScalarValues::Real;
        unit = "Hz";
    }

    attribute def PixelCount {
        :> ScalarValues::Integer;
        unit = "1";
    }

    attribute def Voltage {
        :> ScalarValues::Real;
        unit = "V";
    }

    attribute def Current {
        :> ScalarValues::Real;
        unit = "A";
    }

    attribute def Power {
        :> ScalarValues::Real;
        unit = "W";
    }

    attribute def DataRate {
        :> ScalarValues::Real;
        unit = "bit/s";
    }

    attribute def TimeDuration {
        :> ScalarValues::Real;
        unit = "s";
    }

    attribute def Angle {
        :> ScalarValues::Real;
        unit = "deg";
    }

    item def SceneRadiance {
        attribute spectralBandStart : Wavelength;
        attribute spectralBandEnd : Wavelength;
        attribute apparentRadiance : Radiance;
        attribute sceneTemperature : Temperature;
        attribute fieldAngleX : Angle;
        attribute fieldAngleY : Angle;
    }

    item def FocusedPhotonFlux {
        attribute irradianceAtFocalPlane : Irradiance;
        attribute integrationTime : TimeDuration;
        attribute opticalTransmission : ScalarValues::Real;
    }

    item def PixelChargeFrame {
        attribute rows : PixelCount;
        attribute columns : PixelCount;
        attribute integrationTime : TimeDuration;
        attribute wellFillFraction : ScalarValues::Real;
        attribute frameIndex : ScalarValues::Integer;
    }

    item def AnalogVideoFrame {
        attribute rows : PixelCount;
        attribute columns : PixelCount;
        attribute sampleVoltageMin : Voltage;
        attribute sampleVoltageMax : Voltage;
        attribute frameIndex : ScalarValues::Integer;
    }

    item def DigitalImageFrame {
        attribute rows : PixelCount;
        attribute columns : PixelCount;
        attribute bitsPerPixel : ScalarValues::Integer;
        attribute frameRate : FrameRate;
        attribute frameIndex : ScalarValues::Integer;
        attribute calibrated : ScalarValues::Boolean;
        attribute nonuniformityCorrected : ScalarValues::Boolean;
    }

    item def HealthStatus {
        attribute detectorTemperature : Temperature;
        attribute coolerPower : Power;
        attribute inputVoltage : Voltage;
        attribute frameDropCount : ScalarValues::Integer;
        attribute faultPresent : ScalarValues::Boolean;
    }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute power : Power;
    }

    item def ControlCommand {
        attribute requestedFrameRate : FrameRate;
        attribute requestedIntegrationTime : TimeDuration;
        attribute enableCooling : ScalarValues::Boolean;
        attribute enableAcquisition : ScalarValues::Boolean;
        attribute requestCalibration : ScalarValues::Boolean;
    }

    port def RadianceInPort {
        in scene : SceneRadiance;
    }

    port def PhotonFluxPort {
        out flux : FocusedPhotonFlux;
    }

    port def PhotonFluxInPort {
        in flux : FocusedPhotonFlux;
    }

    port def ChargeFramePort {
        out chargeFrame : PixelChargeFrame;
    }

    port def ChargeFrameInPort {
        in chargeFrame : PixelChargeFrame;
    }

    port def AnalogFramePort {
        out analogFrame : AnalogVideoFrame;
    }

    port def AnalogFrameInPort {
        in analogFrame : AnalogVideoFrame;
    }

    port def DigitalFramePort {
        out imageFrame : DigitalImageFrame;
    }

    port def DigitalFrameInPort {
        in imageFrame : DigitalImageFrame;
    }

    port def PowerInPort {
        in powerInput : ElectricalPower;
    }

    port def PowerOutPort {
        out powerOutput : ElectricalPower;
    }

    port def CommandInPort {
        in command : ControlCommand;
    }

    port def StatusOutPort {
        out status : HealthStatus;
    }

    part def OpticalAssembly {
        attribute apertureDiameter : ScalarValues::Real = 0.05 [m];
        attribute focalLength : ScalarValues::Real = 0.075 [m];
        attribute fNumber : ScalarValues::Real = 1.5;
        attribute transmission : ScalarValues::Real = 0.82;
        attribute fieldOfViewHorizontal : Angle = 24.0 [deg];
        attribute fieldOfViewVertical : Angle = 18.0 [deg];
        attribute bandStart : Wavelength = 3.0 [um];
        attribute bandEnd : Wavelength = 5.0 [um];

        port sceneInput : RadianceInPort;
        port focalPlaneOutput : PhotonFluxPort;

        perform action focusSceneRadiance {
            in scene : SceneRadiance;
            out flux : FocusedPhotonFlux;
        }
    }

    part def StaringFocalPlaneArray {
        attribute rowCount : PixelCount = 1024;
        attribute columnCount : PixelCount = 1280;
        attribute pixelPitch : ScalarValues::Real = 15.0 [um];
        attribute quantumEfficiency : ScalarValues::Real = 0.72;
        attribute fullWellCapacity : ScalarValues::Real = 850000.0;
        attribute darkCurrentAtOperatingTemp : Current = 2.0e-12 [A];
        attribute operatingTemperature : Temperature = 80.0 [K];

        port photonInput : PhotonFluxInPort;
        port chargeOutput : ChargeFramePort;
        port powerInput : PowerInPort;

        perform action integratePhotonFlux {
            in flux : FocusedPhotonFlux;
            out chargeFrame : PixelChargeFrame;
        }

        state def DetectorAcquisitionState {
            state Off;
            state Integrating;
            state HoldingCharge;
            state Saturated;
            state Faulted;

            transition first Off;
            transition Off_to_Integrating
                first Off
                then Integrating
                accept ControlCommand
                if command.enableAcquisition == true;

            transition Integrating_to_HoldingCharge
                first Integrating
                then HoldingCharge
                after flux.integrationTime;

            transition Integrating_to_Saturated
                first Integrating
                then Saturated
                if chargeFrame.wellFillFraction >= 1.0;

            transition HoldingCharge_to_Integrating
                first HoldingCharge
                then Integrating
                accept ControlCommand
                if command.enableAcquisition == true;

            transition Any_to_Faulted
                first Integrating
                then Faulted
                if operatingTemperature > 95.0 [K];
        }
    }

    part def ReadoutIntegratedCircuit {
        attribute parallelOutputChannels : ScalarValues::Integer = 16;
        attribute maximumFrameRate : FrameRate = 120.0 [Hz];
        attribute readNoiseRmsElectrons : ScalarValues::Real = 45.0;
        attribute analogGain : ScalarValues::Real = 2.5;
        attribute sampleVoltageLow : Voltage = 0.2 [V];
        attribute sampleVoltageHigh : Voltage = 2.8 [V];

        port chargeInput : ChargeFrameInPort;
        port analogOutput : AnalogFramePort;
        port powerInput : PowerInPort;

        perform action readPixelArray {
            in chargeFrame : PixelChargeFrame;
            out analogFrame : AnalogVideoFrame;
        }
    }

    part def TimingAndControlElectronics {
        attribute commandedFrameRate : FrameRate = 60.0 [Hz];
        attribute commandedIntegrationTime : TimeDuration = 0.004 [s];
        attribute clockJitter : TimeDuration = 2.0e-9 [s];
        attribute supportsSnapshotIntegration : ScalarValues::Boolean = true;

        port commandInput : CommandInPort;
        port statusOutput : StatusOutPort;
        port detectorPowerOutput : PowerOutPort;
        port readoutPowerOutput : PowerOutPort;
        port processorPowerOutput : PowerOutPort;

        perform action sequenceFrameAcquisition {
            in command : ControlCommand;
            out status : HealthStatus;
        }

        state def ControllerState {
            state Standby;
            state Cooldown;
            state Ready;
            state Acquire;
            state Calibrate;
            state SafeMode;

            transition first Standby;

            transition Standby_to_Cooldown
                first Standby
                then Cooldown
                accept ControlCommand
                if command.enableCooling == true;

            transition Cooldown_to_Ready
                first Cooldown
                then Ready
                if status.detectorTemperature <= 85.0 [K];

            transition Ready_to_Acquire
                first Ready
                then Acquire
                accept ControlCommand
                if command.enableAcquisition == true;

            transition Acquire_to_Calibrate
                first Acquire
                then Calibrate
                accept ControlCommand
                if command.requestCalibration == true;

            transition Calibrate_to_Acquire
                first Calibrate
                then Acquire
                after 2.0 [s];

            transition Acquire_to_Ready
                first Acquire
                then Ready
                accept ControlCommand
                if command.enableAcquisition == false;

            transition Ready_to_SafeMode
                first Ready
                then SafeMode
                if status.faultPresent == true;

            transition Acquire_to_SafeMode
                first Acquire
                then SafeMode
                if status.faultPresent == true;
        }
    }

    part def CryogenicThermalControl {
        attribute targetDetectorTemperature : Temperature = 80.0 [K];
        attribute maximumCoolerLift : Power = 3.5 [W];
        attribute steadyStateCoolerPower : Power = 8.0 [W];
        attribute temperatureStability : Temperature = 0.03 [K];

        port powerInput : PowerInPort;
        port statusOutput : StatusOutPort;

        perform action regulateDetectorTemperature {
            out status : HealthStatus;
        }
    }

    part def ImageSignalProcessor {
        attribute adcResolution : ScalarValues::Integer = 14;
        attribute maximumInputFrameRate : FrameRate = 120.0 [Hz];
        attribute outputBitsPerPixel : ScalarValues::Integer = 16;
        attribute nonuniformityCorrectionEnabled : ScalarValues::Boolean = true;
        attribute badPixelReplacementEnabled : ScalarValues::Boolean = true;
        attribute radiometricCalibrationEnabled : ScalarValues::Boolean = true;

        port analogInput : AnalogFrameInPort;
        port commandInput : CommandInPort;
        port digitalOutput : DigitalFramePort;
        port powerInput : PowerInPort;

        perform action digitizeAnalogFrame {
            in analogFrame : AnalogVideoFrame;
            out imageFrame : DigitalImageFrame;
        }

        perform action correctNonuniformity {
            in rawFrame : DigitalImageFrame;
            out correctedFrame : DigitalImageFrame;
        }

        perform action calibrateRadiance {
            in correctedFrame : DigitalImageFrame;
            out calibratedFrame : DigitalImageFrame;
        }
    }

    part def ExternalHostInterface {
        attribute linkDataRate : DataRate = 3.125e9 [bit/s];
        attribute protocolName : ScalarValues::String = "Camera Link HS";
        attribute commandLatency : TimeDuration = 0.002 [s];

        port commandInput : CommandInPort;
        port imageInput : DigitalFrameInPort;
        port statusInput : StatusOutPort;
        port imageOutput : DigitalFramePort;
        port statusOutput : StatusOutPort;

        perform action transmitImageFrame {
            in imageFrame : DigitalImageFrame;
            out imageFrameToHost : DigitalImageFrame;
        }

        perform action reportHealthStatus {
            in internalStatus : HealthStatus;
            out externalStatus : HealthStatus;
        }
    }

    part def PowerConditioningUnit {
        attribute inputVoltageNominal : Voltage = 28.0 [V];
        attribute detectorRailVoltage : Voltage = 5.0 [V];
        attribute readoutRailVoltage : Voltage = 3.3 [V];
        attribute processorRailVoltage : Voltage = 1.2 [V];
        attribute conversionEfficiency : ScalarValues::Real = 0.88;
        attribute maximumInputPower : Power = 35.0 [W];

        port systemPowerInput : PowerInPort;
        port detectorPowerOutput : PowerOutPort;
        port readoutPowerOutput : PowerOutPort;
        port processorPowerOutput : PowerOutPort;
        port coolerPowerOutput : PowerOutPort;

        perform action conditionElectricalPower {
            in powerInput : ElectricalPower;
            out detectorPower : ElectricalPower;
            out readoutPower : ElectricalPower;
            out processorPower : ElectricalPower;
            out coolerPower : ElectricalPower;
        }
    }

    action def AcquireStaringArrayImage {
        in scene : SceneRadiance;
        in command : ControlCommand;
        out image : DigitalImageFrame;
        out status : HealthStatus;

        action focusScene;
        action integrateArray;
        action readOutCharge;
        action processFrame;
        action publishFrame;

        flow scene to focusScene;
        flow focusScene to integrateArray;
        flow integrateArray to readOutCharge;
        flow readOutCharge to processFrame;
        flow processFrame to publishFrame;
        flow publishFrame to image;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The staring array system shall continuously observe a two-dimensional scene over its full field of view without mechanical scanning and shall convert incident scene radiance into calibrated digital image frames suitable for host processing. */
    }

    requirement def SnapshotAcquisitionRequirement {
        doc /* The focal plane array shall integrate all active detector pixels during a common exposure interval so that each output frame represents the same scene time window. */
        attribute requiredRows : PixelCount = 1024;
        attribute requiredColumns : PixelCount = 1280;
        attribute requiredMinimumFrameRate : FrameRate = 60.0 [Hz];
    }

    requirement def SpectralBandRequirement {
        doc /* The optical and detector chain shall accept scene radiance in the mid-wave infrared band from 3.0 um to 5.0 um. */
        attribute minimumWavelength : Wavelength = 3.0 [um];
        attribute maximumWavelength : Wavelength = 5.0 [um];
    }

    requirement def ThermalStabilityRequirement {
        doc /* The thermal control subsystem shall maintain detector operating temperature at 80 K with stability no worse than 0.05 K during image acquisition. */
        attribute targetTemperature : Temperature = 80.0 [K];
        attribute allowedVariation : Temperature = 0.05 [K];
    }

    requirement def DigitalOutputRequirement {
        doc /* The signal processor shall output corrected and radiometrically calibrated digital image frames with at least 14 effective bits per pixel. */
        attribute minimumEffectiveBits : ScalarValues::Integer = 14;
        attribute minimumFrameRate : FrameRate = 60.0 [Hz];
    }

    requirement def PowerRequirement {
        doc /* The complete staring array system shall operate from a 28 V electrical input and shall not exceed 35 W steady-state input power during nominal acquisition. */
        attribute nominalInputVoltage : Voltage = 28.0 [V];
        attribute maximumSteadyPower : Power = 35.0 [W];
    }

    part def StaringArrayImager {
        doc /* Primary function: collect radiance from a fixed two-dimensional field of view, focus it onto a staring focal plane array, integrate all pixels in parallel, read out the resulting charge pattern, and produce calibrated digital image frames representing the observed scene. */

        attribute systemFrameRate : FrameRate = 60.0 [Hz];
        attribute nominalIntegrationTime : TimeDuration = 0.004 [s];
        attribute totalActivePixels : PixelCount = 1310720;
        attribute nominalInputPower : Power = 28.0 [W];

        port sceneInput : RadianceInPort;
        port commandInput : CommandInPort;
        port powerInput : PowerInPort;
        port imageOutput : DigitalFramePort;
        port statusOutput : StatusOutPort;

        part optics : OpticalAssembly;
        part detector : StaringFocalPlaneArray;
        part readout : ReadoutIntegratedCircuit;
        part controller : TimingAndControlElectronics;
        part cooler : CryogenicThermalControl;
        part processor : ImageSignalProcessor;
        part hostInterface : ExternalHostInterface;
        part powerUnit : PowerConditioningUnit;

        connect sceneInput to optics.sceneInput;
        connect optics.focalPlaneOutput to detector.photonInput;
        connect detector.chargeOutput to readout.chargeInput;
        connect readout.analogOutput to processor.analogInput;
        connect processor.digitalOutput to hostInterface.imageInput;
        connect hostInterface.imageOutput to imageOutput;

        connect commandInput to controller.commandInput;
        connect commandInput to processor.commandInput;
        connect commandInput to hostInterface.commandInput;

        connect powerInput to powerUnit.systemPowerInput;
        connect powerUnit.detectorPowerOutput to detector.powerInput;
        connect powerUnit.readoutPowerOutput to readout.powerInput;
        connect powerUnit.processorPowerOutput to processor.powerInput;
        connect powerUnit.coolerPowerOutput to cooler.powerInput;

        connect controller.statusOutput to statusOutput;
        connect cooler.statusOutput to statusOutput;
        connect hostInterface.statusOutput to statusOutput;

        perform action nominalImaging : AcquireStaringArrayImage;

        satisfy PrimaryFunctionRequirement by StaringArrayImager;
        satisfy SnapshotAcquisitionRequirement by detector;
        satisfy SpectralBandRequirement by optics;
        satisfy ThermalStabilityRequirement by cooler;
        satisfy DigitalOutputRequirement by processor;
        satisfy PowerRequirement by powerUnit;
    }

    analysis def FramePayloadAnalysis {
        in rows : PixelCount;
        in columns : PixelCount;
        in bitsPerPixel : ScalarValues::Integer;
        in frameRate : FrameRate;
        out payloadDataRate : DataRate;

        constraint payloadDataRate == rows * columns * bitsPerPixel * frameRate;
    }

    constraint def FrameRateLimitConstraint {
        in commandedRate : FrameRate;
        in maximumReadoutRate : FrameRate;
        commandedRate <= maximumReadoutRate;
    }

    constraint def PowerBudgetConstraint {
        in opticsPower : Power;
        in detectorPower : Power;
        in readoutPower : Power;
        in processorPower : Power;
        in coolerPower : Power;
        in maximumSystemPower : Power;
        opticsPower + detectorPower + readoutPower + processorPower + coolerPower <= maximumSystemPower;
    }

    concern def StaringArrayPrimaryConcern {
        doc /* The system must image the full scene at once rather than scanning it line-by-line or point-by-point. */
    }

    viewpoint def ImagingPerformanceViewpoint {
        doc /* Viewpoint for assessing field-of-view coverage, snapshot integration, frame rate, calibration quality, thermal stability, and output data rate. */
    }

    view def StaringArrayHighLevelView {
        viewpoint ImagingPerformanceViewpoint;
        expose StaringArrayImager;
        expose OpticalAssembly;
        expose StaringFocalPlaneArray;
        expose ReadoutIntegratedCircuit;
        expose ImageSignalProcessor;
        expose PrimaryFunctionRequirement;
        expose SnapshotAcquisitionRequirement;
        expose DigitalOutputRequirement;
    }
}