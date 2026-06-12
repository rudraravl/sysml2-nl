package TimeOfFlightCameraSystemModel {
    import ScalarValues::*;
    import SI::*;

    attribute def Distance {
        unit = "m";
        quantityKind = "length";
    }

    attribute def TimeInterval {
        unit = "s";
        quantityKind = "time";
    }

    attribute def Frequency {
        unit = "Hz";
        quantityKind = "frequency";
    }

    attribute def OpticalPower {
        unit = "W";
        quantityKind = "power";
    }

    attribute def Voltage {
        unit = "V";
        quantityKind = "electric potential";
    }

    attribute def Current {
        unit = "A";
        quantityKind = "electric current";
    }

    attribute def Temperature {
        unit = "degC";
        quantityKind = "temperature";
    }

    attribute def FrameRate {
        unit = "frame/s";
    }

    attribute def Resolution {
        unit = "pixel";
    }

    attribute def DataRate {
        unit = "bit/s";
    }

    attribute def FieldOfView {
        unit = "deg";
    }

    attribute def Confidence {
        unit = "percent";
    }

    attribute def Wavelength {
        unit = "nm";
        quantityKind = "length";
    }

    item def ModulationCommand {
        attribute modulationFrequency : Frequency;
        attribute phaseStep : Real;
        attribute exposureTime : TimeInterval;
        attribute opticalPowerLimit : OpticalPower;
    }

    item def InfraredPulse {
        attribute wavelength : Wavelength;
        attribute modulationFrequency : Frequency;
        attribute emittedPower : OpticalPower;
        attribute emissionDuration : TimeInterval;
    }

    item def ReflectedInfraredSignal {
        attribute wavelength : Wavelength;
        attribute receivedPower : OpticalPower;
        attribute phaseShift : Real;
        attribute timeDelay : TimeInterval;
        attribute signalToNoiseRatio : Real;
    }

    item def RawSensorFrame {
        attribute pixelCount : Resolution;
        attribute integrationTime : TimeInterval;
        attribute phaseSampleIndex : Integer;
        attribute adcBitDepth : Integer;
    }

    item def DepthPixel {
        attribute range : Distance;
        attribute confidence : Confidence;
        attribute amplitude : Real;
    }

    item def DepthFrame {
        attribute width : Resolution;
        attribute height : Resolution;
        attribute frameRate : FrameRate;
        attribute maximumRange : Distance;
        attribute minimumRange : Distance;
        attribute averageConfidence : Confidence;
    }

    item def IntensityFrame {
        attribute width : Resolution;
        attribute height : Resolution;
        attribute frameRate : FrameRate;
    }

    item def CameraHealthStatus {
        attribute sensorTemperature : Temperature;
        attribute emitterTemperature : Temperature;
        attribute supplyVoltage : Voltage;
        attribute frameDropRate : Real;
        attribute faultActive : Boolean;
    }

    item def CameraConfiguration {
        attribute requestedFrameRate : FrameRate;
        attribute requestedRangeLimit : Distance;
        attribute requestedExposureTime : TimeInterval;
        attribute illuminationPowerLimit : OpticalPower;
        attribute confidenceThreshold : Confidence;
    }

    port def PowerInputPort {
        in item supplyVoltage : Voltage;
        in item supplyCurrent : Current;
    }

    port def ConfigurationPort {
        in item configuration : CameraConfiguration;
    }

    port def StatusPort {
        out item status : CameraHealthStatus;
    }

    port def OpticalEmitterPort {
        out item emittedLight : InfraredPulse;
    }

    port def OpticalReceiverPort {
        in item reflectedLight : ReflectedInfraredSignal;
    }

    port def SensorControlPort {
        out item command : ModulationCommand;
    }

    port def RawFramePort {
        out item rawFrame : RawSensorFrame;
    }

    port def DepthOutputPort {
        out item depthFrame : DepthFrame;
        out item intensityFrame : IntensityFrame;
    }

    port def ProcessorInputPort {
        in item rawFrame : RawSensorFrame;
        in item reflectedSignal : ReflectedInfraredSignal;
    }

    part def InfraredIlluminator {
        attribute nominalWavelength : Wavelength = 940;
        attribute maximumOpticalPower : OpticalPower = 2.5;
        attribute modulationFrequency : Frequency = 80000000;
        attribute thermalShutdownTemperature : Temperature = 85;

        port power : PowerInputPort;
        port control : SensorControlPort;
        port opticalOut : OpticalEmitterPort;
        port status : StatusPort;

        action emitModulatedInfraredLight {
            in item command : ModulationCommand;
            out item pulse : InfraredPulse;

            assign pulse.wavelength := nominalWavelength;
            assign pulse.modulationFrequency := command.modulationFrequency;
            assign pulse.emittedPower := min(command.opticalPowerLimit, maximumOpticalPower);
            assign pulse.emissionDuration := command.exposureTime;
        }

        state def IlluminatorOperatingState {
            entry; then Off;

            state Off;
            state Armed;
            state Emitting;
            state ThermalLimited;
            state Faulted;

            transition Off_to_Armed
                first Off
                accept CameraConfiguration
                then Armed;

            transition Armed_to_Emitting
                first Armed
                accept ModulationCommand
                then Emitting;

            transition Emitting_to_Armed
                first Emitting
                if status.status.emitterTemperature < thermalShutdownTemperature
                then Armed;

            transition Emitting_to_ThermalLimited
                first Emitting
                if status.status.emitterTemperature >= thermalShutdownTemperature
                then ThermalLimited;

            transition ThermalLimited_to_Armed
                first ThermalLimited
                if status.status.emitterTemperature < 75
                then Armed;

            transition Any_to_Faulted
                first Off, Armed, Emitting, ThermalLimited
                if status.status.faultActive
                then Faulted;
        }

        perform stateMachine : IlluminatorOperatingState;
    }

    part def TimeOfFlightImageSensor {
        attribute width : Resolution = 640;
        attribute height : Resolution = 480;
        attribute adcBitDepth : Integer = 12;
        attribute minimumIntegrationTime : TimeInterval = 0.00005;
        attribute maximumIntegrationTime : TimeInterval = 0.010;
        attribute sensorTemperatureLimit : Temperature = 80;

        port power : PowerInputPort;
        port control : SensorControlPort;
        port opticalIn : OpticalReceiverPort;
        port rawOut : RawFramePort;
        port status : StatusPort;

        action acquirePhaseSamples {
            in item command : ModulationCommand;
            in item reflectedSignal : ReflectedInfraredSignal;
            out item rawFrame0 : RawSensorFrame;
            out item rawFrame1 : RawSensorFrame;
            out item rawFrame2 : RawSensorFrame;
            out item rawFrame3 : RawSensorFrame;

            assign rawFrame0.pixelCount := width * height;
            assign rawFrame0.integrationTime := command.exposureTime;
            assign rawFrame0.phaseSampleIndex := 0;
            assign rawFrame0.adcBitDepth := adcBitDepth;

            assign rawFrame1.pixelCount := width * height;
            assign rawFrame1.integrationTime := command.exposureTime;
            assign rawFrame1.phaseSampleIndex := 1;
            assign rawFrame1.adcBitDepth := adcBitDepth;

            assign rawFrame2.pixelCount := width * height;
            assign rawFrame2.integrationTime := command.exposureTime;
            assign rawFrame2.phaseSampleIndex := 2;
            assign rawFrame2.adcBitDepth := adcBitDepth;

            assign rawFrame3.pixelCount := width * height;
            assign rawFrame3.integrationTime := command.exposureTime;
            assign rawFrame3.phaseSampleIndex := 3;
            assign rawFrame3.adcBitDepth := adcBitDepth;
        }

        state def SensorAcquisitionState {
            entry; then Idle;

            state Idle;
            state Integrating;
            state ReadingOut;
            state Saturated;
            state Faulted;

            transition Idle_to_Integrating
                first Idle
                accept ModulationCommand
                then Integrating;

            transition Integrating_to_ReadingOut
                first Integrating
                after maximumIntegrationTime
                then ReadingOut;

            transition ReadingOut_to_Idle
                first ReadingOut
                then Idle;

            transition Integrating_to_Saturated
                first Integrating
                if opticalIn.reflectedLight.receivedPower > 0.020
                then Saturated;

            transition Saturated_to_Idle
                first Saturated
                then Idle;

            transition Any_to_Faulted
                first Idle, Integrating, ReadingOut, Saturated
                if status.status.sensorTemperature >= sensorTemperatureLimit or status.status.faultActive
                then Faulted;
        }

        perform stateMachine : SensorAcquisitionState;
    }

    part def DepthProcessingUnit {
        attribute speedOfLight : Real = 299792458;
        attribute supportedFrameRate : FrameRate = 30;
        attribute minimumValidConfidence : Confidence = 20;
        attribute maximumDepthRange : Distance = 10.0;
        attribute minimumDepthRange : Distance = 0.15;
        attribute outputDataRate : DataRate = 250000000;

        port input : ProcessorInputPort;
        port configuration : ConfigurationPort;
        port output : DepthOutputPort;
        port status : StatusPort;

        action computeDepthFromPhase {
            in item reflectedSignal : ReflectedInfraredSignal;
            in item configuration : CameraConfiguration;
            out item depthFrame : DepthFrame;
            out item intensityFrame : IntensityFrame;

            assign depthFrame.width := 640;
            assign depthFrame.height := 480;
            assign depthFrame.frameRate := configuration.requestedFrameRate;
            assign depthFrame.maximumRange := min(configuration.requestedRangeLimit, maximumDepthRange);
            assign depthFrame.minimumRange := minimumDepthRange;
            assign depthFrame.averageConfidence := 95;

            assign intensityFrame.width := 640;
            assign intensityFrame.height := 480;
            assign intensityFrame.frameRate := configuration.requestedFrameRate;
        }

        action filterInvalidPixels {
            in item unfilteredDepthFrame : DepthFrame;
            in item configuration : CameraConfiguration;
            out item filteredDepthFrame : DepthFrame;

            assign filteredDepthFrame.width := unfilteredDepthFrame.width;
            assign filteredDepthFrame.height := unfilteredDepthFrame.height;
            assign filteredDepthFrame.frameRate := unfilteredDepthFrame.frameRate;
            assign filteredDepthFrame.maximumRange := unfilteredDepthFrame.maximumRange;
            assign filteredDepthFrame.minimumRange := unfilteredDepthFrame.minimumRange;
            assign filteredDepthFrame.averageConfidence := max(unfilteredDepthFrame.averageConfidence, configuration.confidenceThreshold);
        }

        state def ProcessingState {
            entry; then WaitingForFrames;

            state WaitingForFrames;
            state CalculatingPhase;
            state EstimatingRange;
            state FilteringDepth;
            state PublishingFrames;
            state Faulted;

            transition WaitingForFrames_to_CalculatingPhase
                first WaitingForFrames
                accept RawSensorFrame
                then CalculatingPhase;

            transition CalculatingPhase_to_EstimatingRange
                first CalculatingPhase
                then EstimatingRange;

            transition EstimatingRange_to_FilteringDepth
                first EstimatingRange
                then FilteringDepth;

            transition FilteringDepth_to_PublishingFrames
                first FilteringDepth
                then PublishingFrames;

            transition PublishingFrames_to_WaitingForFrames
                first PublishingFrames
                then WaitingForFrames;

            transition Any_to_Faulted
                first WaitingForFrames, CalculatingPhase, EstimatingRange, FilteringDepth, PublishingFrames
                if status.status.faultActive
                then Faulted;
        }

        perform stateMachine : ProcessingState;
    }

    part def CameraController {
        attribute defaultFrameRate : FrameRate = 30;
        attribute defaultExposureTime : TimeInterval = 0.001;
        attribute defaultModulationFrequency : Frequency = 80000000;
        attribute defaultIlluminationPower : OpticalPower = 1.5;
        attribute warmupTime : TimeInterval = 0.250;

        port configuration : ConfigurationPort;
        port illuminatorCommand : SensorControlPort;
        port sensorCommand : SensorControlPort;
        port status : StatusPort;

        action configureAcquisition {
            in item configuration : CameraConfiguration;
            out item command : ModulationCommand;

            assign command.modulationFrequency := defaultModulationFrequency;
            assign command.phaseStep := 90.0;
            assign command.exposureTime := configuration.requestedExposureTime;
            assign command.opticalPowerLimit := configuration.illuminationPowerLimit;
        }

        state def CameraControlState {
            entry; then PoweredOff;

            state PoweredOff;
            state Booting;
            state Standby;
            state Capturing;
            state Degraded;
            state Shutdown;
            state Faulted;

            transition PoweredOff_to_Booting
                first PoweredOff
                accept Voltage
                then Booting;

            transition Booting_to_Standby
                first Booting
                after warmupTime
                then Standby;

            transition Standby_to_Capturing
                first Standby
                accept CameraConfiguration
                then Capturing;

            transition Capturing_to_Standby
                first Capturing
                accept Shutdown
                then Standby;

            transition Capturing_to_Degraded
                first Capturing
                if status.status.frameDropRate > 0.05
                then Degraded;

            transition Degraded_to_Capturing
                first Degraded
                if status.status.frameDropRate <= 0.01
                then Capturing;

            transition Standby_to_Shutdown
                first Standby
                accept Shutdown
                then Shutdown;

            transition Any_to_Faulted
                first Booting, Standby, Capturing, Degraded
                if status.status.faultActive
                then Faulted;
        }

        perform stateMachine : CameraControlState;
    }

    part def PowerManagementUnit {
        attribute inputVoltageNominal : Voltage = 12.0;
        attribute inputVoltageMinimum : Voltage = 9.0;
        attribute inputVoltageMaximum : Voltage = 16.0;
        attribute maximumInputCurrent : Current = 1.5;
        attribute logicRailVoltage : Voltage = 3.3;
        attribute sensorRailVoltage : Voltage = 1.8;
        attribute emitterRailVoltage : Voltage = 5.0;

        port powerIn : PowerInputPort;
        port status : StatusPort;

        action regulatePower {
            in item supplyVoltage : Voltage;
            in item supplyCurrent : Current;
            out item health : CameraHealthStatus;

            assign health.supplyVoltage := supplyVoltage;
            assign health.faultActive := supplyVoltage < inputVoltageMinimum or supplyVoltage > inputVoltageMaximum or supplyCurrent > maximumInputCurrent;
        }
    }

    part def TimeOfFlightCamera {
        attribute horizontalFieldOfView : FieldOfView = 70;
        attribute verticalFieldOfView : FieldOfView = 55;
        attribute nominalFrameRate : FrameRate = 30;
        attribute operatingRangeMinimum : Distance = 0.15;
        attribute operatingRangeMaximum : Distance = 10.0;
        attribute depthAccuracyAtTwoMeters : Distance = 0.02;

        port powerInput : PowerInputPort;
        port configurationInput : ConfigurationPort;
        port depthOutput : DepthOutputPort;
        port statusOutput : StatusPort;
        port opticalSceneInput : OpticalReceiverPort;
        port opticalSceneOutput : OpticalEmitterPort;

        part powerManagementUnit : PowerManagementUnit;
        part controller : CameraController;
        part illuminator : InfraredIlluminator;
        part imageSensor : TimeOfFlightImageSensor;
        part depthProcessor : DepthProcessingUnit;

        connect powerInput to powerManagementUnit.powerIn;
        connect powerInput to illuminator.power;
        connect powerInput to imageSensor.power;

        connect configurationInput to controller.configuration;
        connect configurationInput to depthProcessor.configuration;

        connect controller.illuminatorCommand to illuminator.control;
        connect controller.sensorCommand to imageSensor.control;

        connect illuminator.opticalOut to opticalSceneOutput;
        connect opticalSceneInput to imageSensor.opticalIn;

        connect imageSensor.rawOut to depthProcessor.input;
        connect opticalSceneInput to depthProcessor.input;

        connect depthProcessor.output to depthOutput;

        connect powerManagementUnit.status to statusOutput;
        connect controller.status to statusOutput;
        connect illuminator.status to statusOutput;
        connect imageSensor.status to statusOutput;
        connect depthProcessor.status to statusOutput;

        action captureDepthImage {
            in item configuration : CameraConfiguration;
            in item reflectedSignal : ReflectedInfraredSignal;
            out item depthFrame : DepthFrame;
            out item intensityFrame : IntensityFrame;

            first controller.configureAcquisition;
            then illuminator.emitModulatedInfraredLight;
            then imageSensor.acquirePhaseSamples;
            then depthProcessor.computeDepthFromPhase;
            then depthProcessor.filterInvalidPixels;

            objective {
                doc /* Emit modulated infrared light, measure the phase delay of returned light at each pixel, and produce a calibrated depth frame representing the distance from the camera to visible scene surfaces. */
            }
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject camera : TimeOfFlightCamera;

        require constraint {
            camera.depthOutput.depthFrame.frameRate >= 30 and
            camera.depthOutput.depthFrame.minimumRange <= 0.15 and
            camera.depthOutput.depthFrame.maximumRange >= 10.0
        }

        doc /* The Time-of-flight camera shall produce real-time depth images by illuminating the scene with modulated infrared light, sensing the reflected signal, estimating per-pixel distance from measured time or phase delay, and publishing depth and intensity frames to downstream perception functions. */
    }

    requirement def IlluminationSafetyRequirement {
        subject emitter : InfraredIlluminator;

        require constraint {
            emitter.maximumOpticalPower <= 2.5 and
            emitter.nominalWavelength == 940
        }

        doc /* The infrared illuminator shall limit emitted optical power while operating at an eye-safer near-infrared wavelength suitable for active depth sensing. */
    }

    requirement def DepthAccuracyRequirement {
        subject camera : TimeOfFlightCamera;

        require constraint {
            camera.depthAccuracyAtTwoMeters <= 0.02
        }

        doc /* The camera shall estimate depth at a two meter target distance with no more than two centimeters nominal error under valid reflectance and ambient-light conditions. */
    }

    requirement def ThermalProtectionRequirement {
        subject camera : TimeOfFlightCamera;

        require constraint {
            camera.illuminator.thermalShutdownTemperature <= 85 and
            camera.imageSensor.sensorTemperatureLimit <= 80
        }

        doc /* The camera shall reduce operation or enter a faulted state before emitter or image sensor temperatures exceed defined thermal limits. */
    }

    requirement def DataOutputRequirement {
        subject processor : DepthProcessingUnit;

        require constraint {
            processor.outputDataRate <= 250000000 and
            processor.supportedFrameRate >= 30
        }

        doc /* The processing unit shall publish depth and intensity frames at the requested frame rate without exceeding the supported output interface data rate. */
    }

    requirement def ConfigurationRequirement {
        subject controller : CameraController;

        require constraint {
            controller.defaultFrameRate == 30 and
            controller.defaultModulationFrequency == 80000000
        }

        doc /* The controller shall configure synchronized illumination and sensor modulation parameters before each acquisition sequence. */
    }

    satisfy PrimaryFunctionRequirement by TimeOfFlightCamera::captureDepthImage;
    satisfy IlluminationSafetyRequirement by InfraredIlluminator::emitModulatedInfraredLight;
    satisfy DepthAccuracyRequirement by DepthProcessingUnit::computeDepthFromPhase;
    satisfy ThermalProtectionRequirement by InfraredIlluminator::IlluminatorOperatingState;
    satisfy ThermalProtectionRequirement by TimeOfFlightImageSensor::SensorAcquisitionState;
    satisfy DataOutputRequirement by DepthProcessingUnit::ProcessingState;
    satisfy ConfigurationRequirement by CameraController::configureAcquisition;

    part tofCameraSystem : TimeOfFlightCamera {
        attribute horizontalFieldOfView = 70;
        attribute verticalFieldOfView = 55;
        attribute nominalFrameRate = 30;
        attribute operatingRangeMinimum = 0.15;
        attribute operatingRangeMaximum = 10.0;
        attribute depthAccuracyAtTwoMeters = 0.02;
    }
}