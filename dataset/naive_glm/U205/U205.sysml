package DopplerEchocardiographySystem {
    import ScalarValues::*;

    // ===== Value Types =====
    value def Frequency :> Real;
    value def Velocity :> Real;
    value def Pressure :> Real;
    value def Distance :> Real;
    value def Duration :> Real;
    value def Power :> Real;
    value def Gain :> Real;
    value def Area :> Real;
    value def FlowRate :> Real;

    // ===== Units =====
    unit hertz of Frequency;
    unit meterPerSecond of Velocity;
    unit pascal of Pressure;
    unit meter of Distance;
    unit second of Duration;
    unit watt of Power;
    unit decibel of Gain;
    unit squareCentimeter of Area;
    unit literPerMinute of FlowRate;

    // ===== Enumerations =====
    enum def ImagingMode {
        B_MODE;
        M_MODE;
        COLOR_DOPPLER;
        PULSED_WAVE_DOPPLER;
        CONTINUOUS_WAVE_DOPPLER;
    }

    enum def FlowDirection {
        TOWARDS_PROBE;
        AWAY_FROM_PROBE;
        BIDIRECTIONAL;
        TURBULENT;
    }

    enum def ProbeType {
        PHASED_ARRAY;
        LINEAR;
        CONVEX;
        SECTOR;
    }

    // ===== Item Definitions =====
    item def UltrasoundWave {
        attribute frequency : Frequency;
        attribute amplitude : Real;
        attribute phase : Real;
        attribute pulseDuration : Duration;
    }

    item def EchoSignal {
        attribute frequency : Frequency;
        attribute amplitude : Real;
        attribute depth : Distance;
        attribute timestamp : Duration;
        attribute scanLineIndex : Integer;
    }

    item def DopplerData {
        attribute velocity : Velocity;
        attribute direction : FlowDirection;
        attribute turbulenceIndex : Real;
        attribute depth : Distance;
        attribute sampleVolume : Distance;
    }

    item def ImageFrame {
        attribute width : Integer;
        attribute height : Integer;
        attribute pixelData : Real[0..*];
        attribute timestamp : Duration;
        attribute scanDepth : Distance;
    }

    item def ColorFlowOverlay {
        attribute velocityMap : Velocity[0..*];
        attribute directionMap : FlowDirection[0..*];
        attribute frame : ImageFrame;
        attribute colorGain : Gain;
    }

    item def MeasurementResult {
        attribute pressureGradient : Pressure;
        attribute peakVelocity : Velocity;
        attribute meanVelocity : Velocity;
        attribute valveArea : Area;
        attribute cardiacOutput : FlowRate;
        attribute timestamp : Duration;
        attribute measurementMode : ImagingMode;
    }

    item def DisplayContent {
        attribute anatomicalImage : ImageFrame;
        attribute colorOverlay : ColorFlowOverlay;
        attribute dopplerSpectrum : Real[0..*];
        attribute measurements : MeasurementResult[0..*];
        attribute patientId : String;
        attribute studyTimestamp : Duration;
    }

    item def ControlCommand {
        attribute mode : ImagingMode;
        attribute probeGain : Gain;
        attribute probeDepth : Distance;
        attribute freezeFrame : Boolean;
        attribute colorScale : Real;
        attribute spectralBaseline : Real;
    }

    // ===== Part Definitions =====

    part def UltrasoundTransducer {
        attribute serialNumber : String;
        attribute elementCount : Integer;
        attribute centerFrequency : Frequency;
        attribute maxAcousticPower : Power;
        attribute probeType : ProbeType;
        attribute fieldOfView : Real;

        port out transmitPort : UltrasoundWave;
        port in echoPort : EchoSignal;
        port in commandPort : ControlCommand;

        action def TransmitPulse {
            in command : ControlCommand;
            out wave : UltrasoundWave;
            doc /* Generates an ultrasound pulse based on control command settings. */
        }

        action def ReceiveEcho {
            in rawEcho : EchoSignal;
            out processedEcho : EchoSignal;
            doc /* Receives and pre-amplifies returning echo signals from moving blood cells and tissue. */
        }

        action def Beamform {
            in rawSignals : EchoSignal[0..*];
            out beamformedSignal : EchoSignal;
            doc /* Applies delay-and-sum beamforming to focus the ultrasound beam at the desired depth. */
        }

        perform transmit : TransmitPulse;
        perform receive : ReceiveEcho;
        perform beamform : Beamform;
    }

    part def DopplerProcessor {
        attribute samplingRate : Frequency;
        attribute maxDetectableVelocity : Velocity;
        attribute soundSpeed : Velocity;
        attribute wallFilterCutoff : Frequency;

        port in echoInPort : EchoSignal;
        port out dopplerOutPort : DopplerData;
        port in commandPort : ControlCommand;

        action def ApplyWallFilter {
            in echo : EchoSignal;
            out filteredEcho : EchoSignal;
            doc /* Removes low-frequency signals from tissue motion to isolate blood flow echoes. */
        }

        action def AnalyzeFrequencyShift {
            in echo : EchoSignal;
            in referenceFrequency : Frequency;
            in soundSpeedValue : Velocity;
            out dopplerData : DopplerData;
            doc /* Calculates blood flow velocity using the Doppler equation: v = (fd * c) / (2 * f0 * cos(theta)). */
        }

        action def DetectTurbulence {
            in velocitySamples : Velocity[0..*];
            out turbulenceIndex : Real;
            doc /* Computes variance of velocity samples to detect and quantify turbulent flow patterns. */
        }

        perform applyFilter : ApplyWallFilter;
        perform analyze : AnalyzeFrequencyShift;
        perform detectTurbulence : DetectTurbulence;
    }

    part def ImageProcessor {
        attribute frameRate : Frequency;
        attribute spatialResolution : Integer;
        attribute dynamicRange : Gain;

        port in echoInPort : EchoSignal;
        port in dopplerInPort : DopplerData;
        port out imageOutPort : ImageFrame;
        port out overlayOutPort : ColorFlowOverlay;
        port in commandPort : ControlCommand;

        action def ConstructAnatomicalImage {
            in echo : EchoSignal;
            in resolution : Integer;
            out frame : ImageFrame;
            doc /* Constructs a 2D grayscale anatomical image of the heart from echo scan lines. */
        }

        action def GenerateColorFlowOverlay {
            in dopplerData : DopplerData;
            in frame : ImageFrame;
            in colorGain : Gain;
            out overlay : ColorFlowOverlay;
            doc /* Maps Doppler velocity data to color values: red for flow towards probe, blue for flow away. */
        }

        action def CombineImageAndOverlay {
            in frame : ImageFrame;
            in overlay : ColorFlowOverlay;
            out combinedFrame : ImageFrame;
            doc /* Superimposes the color flow overlay onto the anatomical image for simultaneous visualization. */
        }

        perform construct : ConstructAnatomicalImage;
        perform generateOverlay : GenerateColorFlowOverlay;
        perform combine : CombineImageAndOverlay;
    }

    part def MeasurementEngine {
        attribute calculationMode : ImagingMode;
        attribute bloodDensity : Real;
        attribute viscosity : Real;

        port in dopplerInPort : DopplerData;
        port out measurementOutPort : MeasurementResult;
        port in commandPort : ControlCommand;

        action def CalculatePressureGradient {
            in peakVelocity : Velocity;
            out pressureGradient : Pressure;
            doc /* Uses the simplified Bernoulli equation: dP = 4 * v^2 to estimate pressure gradient across a valve. */
        }

        action def CalculateValveArea {
            in velocities : Velocity[0..*];
            in flowRate : FlowRate;
            out area : Area;
            doc /* Uses the continuity equation to estimate valve area from flow rate and velocity. */
        }

        action def CalculateCardiacOutput {
            in velocities : Velocity[0..*];
            in valveArea : Area;
            in heartRate : Frequency;
            out cardiacOutput : FlowRate;
            doc /* Computes cardiac output from velocity-time integral, valve area, and heart rate. */
        }

        perform calcPressure : CalculatePressureGradient;
        perform calcArea : CalculateValveArea;
        perform calcOutput : CalculateCardiacOutput;
    }

    part def DisplaySystem {
        attribute displayResolution : String;
        attribute refreshRate : Frequency;
        attribute brightness : Real;
        attribute contrast : Real;

        port in imageInPort : ImageFrame;
        port in overlayInPort : ColorFlowOverlay;
        port in measurementInPort : MeasurementResult;
        port out displayOutPort : DisplayContent;
        port in commandPort : ControlCommand;

        action def RenderDisplay {
            in image : ImageFrame;
            in overlay : ColorFlowOverlay;
            in measurements : MeasurementResult;
            out content : DisplayContent;
            doc /* Composes the final display content with anatomical image, color overlay, Doppler spectrum, and measurements. */
        }

        action def UpdateDisplayBuffer {
            in content : DisplayContent;
            doc /* Updates the display buffer with new rendered content at the specified refresh rate. */
        }

        perform render : RenderDisplay;
        perform updateBuffer : UpdateDisplayBuffer;
    }

    part def ControlSystem {
        attribute currentMode : ImagingMode = ImagingMode::B_MODE;
        attribute probeGain : Gain = 50;
        attribute probeDepth : Distance = 0.15;
        attribute isFrozen : Boolean = false;
        attribute colorScale : Real = 1.0;
        attribute spectralBaseline : Real = 0.0;

        port out commandOutPort : ControlCommand;
        port in operatorInputPort : ControlCommand;

        action def ProcessOperatorInput {
            in input : ControlCommand;
            out command : ControlCommand;
            doc /* Translates operator input into control commands distributed to all subsystems. */
        }

        action def ValidateCommand {
            in input : ControlCommand;
            out isValid : Boolean;
            doc /* Validates that the operator command parameters are within safe operating limits. */
        }

        perform processInput : ProcessOperatorInput;
        perform validate : ValidateCommand;

        state machine ControlStateMachine {
            state Idle {
                doc /* System powered on but not actively imaging. */
                entry { isFrozen = false; }
            }

            state Imaging {
                doc /* Actively acquiring and processing ultrasound data in the selected imaging mode. */
                entry { isFrozen = false; }
            }

            state Frozen {
                doc /* Image frozen for detailed measurement and analysis. */
                entry { isFrozen = true; }
            }

            state Reviewing {
                doc /* Reviewing stored measurement results from the frozen image. */
            }

            transition initial to Idle;

            transition from Idle to Imaging
                when operatorInputPort.freezeFrame == false
                do processInput;

            transition from Imaging to Frozen
                when operatorInputPort.freezeFrame == true
                do processInput;

            transition from Frozen to Imaging
                when operatorInputPort.freezeFrame == false
                do processInput;

            transition from Frozen to Reviewing
                when operatorInputPort.mode == ImagingMode::B_MODE
                do processInput;

            transition from Reviewing to Idle
                when operatorInputPort.freezeFrame == false
                do processInput;
        }
    }

    // ===== System Composition =====
    part def DopplerEchocardiographySystem {
        attribute systemId : String;
        attribute manufacturer : String;
        attribute model : String;
        attribute firmwareVersion : String;
        attribute maxSafeAcousticPower : Power;

        port in operatorInterface : ControlCommand;
        port out displayInterface : DisplayContent;

        part transducer : UltrasoundTransducer {
            attribute centerFrequency = 2500000;
            attribute elementCount = 128;
            attribute maxAcousticPower = 0.1;
            attribute probeType = ProbeType::PHASED_ARRAY;
            attribute fieldOfView = 90.0;
        }

        part dopplerProcessor : DopplerProcessor {
            attribute samplingRate = 10000;
            attribute maxDetectableVelocity = 2.0;
            attribute soundSpeed = 1540;
            attribute wallFilterCutoff = 200;
        }

        part imageProcessor : ImageProcessor {
            attribute frameRate = 60;
            attribute spatialResolution = 1024;
            attribute dynamicRange = 60;
        }

        part measurementEngine : MeasurementEngine {
            attribute calculationMode = ImagingMode::CONTINUOUS_WAVE_DOPPLER;
            attribute bloodDensity = 1060;
            attribute viscosity = 0.004;
        }

        part displaySystem : DisplaySystem {
            attribute displayResolution = "1920x1080";
            attribute refreshRate = 60;
            attribute brightness = 0.8;
            attribute contrast = 0.7;
        }

        part controlSystem : ControlSystem;

        // Echo signal flow connections
        connection transducerEchoToDoppler
            connect transducer.echoPort to dopplerProcessor.echoInPort;

        connection transducerEchoToImage
            connect transducer.echoPort to imageProcessor.echoInPort;

        connection dopplerToImage
            connect dopplerProcessor.dopplerOutPort to imageProcessor.dopplerInPort;

        connection dopplerToMeasurement
            connect dopplerProcessor.dopplerOutPort to measurementEngine.dopplerInPort;

        connection imageToDisplay
            connect imageProcessor.imageOutPort to displaySystem.imageInPort;

        connection overlayToDisplay
            connect imageProcessor.overlayOutPort to displaySystem.overlayInPort;

        connection measurementToDisplay
            connect measurementEngine.measurementOutPort to displaySystem.measurementInPort;

        // Control distribution connections
        connection controlToTransducer
            connect controlSystem.commandOutPort to transducer.commandPort;

        connection controlToDoppler
            connect controlSystem.commandOutPort to dopplerProcessor.commandPort;

        connection controlToImage
            connect controlSystem.commandOutPort to imageProcessor.commandPort;

        connection controlToMeasurement
            connect controlSystem.commandOutPort to measurementEngine.commandPort;

        connection controlToDisplay
            connect controlSystem.commandOutPort to displaySystem.commandPort;

        // External interface connections
        connection operatorToControl
            connect operatorInterface to controlSystem.operatorInputPort;

        connection displayToInterface
            connect displaySystem.displayOutPort to displayInterface;
    }

    // ===== Requirements =====
    requirement def CardiacAssessmentRequirement {
        doc /* The Doppler echocardiography system shall provide comprehensive non-invasive cardiac assessment capabilities. */

        subject system : DopplerEchocardiographySystem;

        requirement provideRealTimeImaging {
            doc /* The system shall provide real-time 2D imaging of cardiac structures at a minimum frame rate of 30 Hz. */
            assert system.imageProcessor.frameRate >= 30;
        }

        requirement measureBloodFlowVelocity {
            doc /* The system shall measure blood flow velocity using the Doppler effect with a maximum detectable velocity of at least 2.0 m/s. */
            assert system.dopplerProcessor.maxDetectableVelocity >= 2.0;
        }

        requirement calculatePressureGradient {
            doc /* The system shall calculate pressure gradients across heart valves using the simplified Bernoulli equation for diagnosing stenosis. */
            assert system.measurementEngine.calculationMode == ImagingMode::CONTINUOUS_WAVE_DOPPLER
                or system.measurementEngine.calculationMode == ImagingMode::PULSED_WAVE_DOPPLER;
        }

        requirement displayColorFlowOverlay {
            doc /* The system shall display color-coded blood flow overlays on the anatomical image for visualizing flow patterns. */
            assert system.imageProcessor.spatialResolution > 0;
        }

        requirement supportMultipleImagingModes {
            doc /* The system shall support B-Mode, M-Mode, Color Doppler, Pulsed Wave Doppler, and Continuous Wave Doppler imaging modes. */
            assert system.controlSystem.currentMode == ImagingMode::CONTINUOUS_WAVE_DOPPLER
                or system.controlSystem.currentMode == ImagingMode::PULSED_WAVE_DOPPLER
                or system.controlSystem.currentMode == ImagingMode::COLOR_DOPPLER
                or system.controlSystem.currentMode == ImagingMode::M_MODE
                or system.controlSystem.currentMode == ImagingMode::B_MODE;
        }

        requirement nonInvasiveOperation {
            doc /* The system shall perform cardiac assessment non-invasively through the chest wall with acoustic power below safe limits. */
            assert system.transducer.maxAcousticPower <= system.maxSafeAcousticPower;
        }

        requirement provideOperatorControl {
            doc /* The system shall allow the operator to select imaging modes, adjust probe settings, and control the examination procedure. */
            assert system.controlSystem.probeGain > 0 and system.controlSystem.probeDepth > 0;
        }
    }
}
