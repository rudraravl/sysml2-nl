package HolographicSensingUnit {

    import ScalarValues::*;

    // ============================= VALUE TYPES =============================

    value type Micrometer :> Real {
        doc "Spatial measurement unit: micrometer (um).";
    }

    value type Nanometer :> Real {
        doc "Optical wavelength unit: nanometer (nm).";
    }

    value type Seconds :> Real {
        doc "Time unit: seconds (s).";
    }

    value type Fraction :> Real {
        doc "Dimensionless fraction in range [0, 1].";
    }

    value type Milliwatt :> Real {
        doc "Optical power unit: milliwatt (mW).";
    }

    value type Hertz :> Real {
        doc "Frequency unit: hertz (Hz).";
    }

    value type Radians :> Real {
        doc "Angular measurement unit: radians (rad).";
    }

    // ============================= ENUMERATIONS =============================

    enum def CommandType {
        literal measure;
        literal reset;
        literal statusQuery;
    }

    enum def SystemStateKind {
        literal idle;
        literal initializing;
        literal capturing;
        literal processing;
        literal error;
    }

    // ============================= ITEM DEFINITIONS =============================

    item def CoherentLight {
        doc "Highly stable, coherent laser light output.";
        attribute wavelength : Nanometer;
        attribute power : Milliwatt;
        attribute coherenceLength : Micrometer;
        attribute stability : Fraction;
    }

    item def ObjectBeam :> CoherentLight {
        doc "Laser beam directed to illuminate the target object surface.";
        attribute beamType : String = "object";
        attribute illuminated : Boolean;
    }

    item def ReferenceBeam :> CoherentLight {
        doc "Laser beam traveling an uninterrupted path directly to the detector.";
        attribute beamType : String = "reference";
        attribute attenuated : Boolean;
    }

    item def ReflectedObjectLight :> CoherentLight {
        doc "Light reflected from the object surface, carrying surface shape and texture information.";
        attribute beamType : String = "reflectedObject";
        attribute surfaceInformation : Boolean;
        attribute textureData : String;
    }

    item def InterferencePattern {
        doc "Raw hologram: complex pattern of light and dark fringes from beam recombination.";
        attribute fringeIntensityArray : Integer[*];
        attribute patternQuality : Fraction;
        attribute captureTimestamp : Seconds;
    }

    item def HologramRecord {
        doc "Digital record of the captured interference pattern.";
        attribute rawPattern : InterferencePattern;
        attribute recordId : Integer;
        attribute captureTimestamp : Seconds;
    }

    item def ReconstructedWave {
        doc "Mathematically reconstructed wavefront derived from the hologram.";
        attribute amplitudeField : Real[*];
        attribute phaseField : Real[*];
        attribute reconstructionQuality : Fraction;
    }

    item def MeasurementData {
        doc "Final reconstructed measurement data with quantifiable spatial properties.";
        attribute spatialCoordinates : Real[*];
        attribute depthMap : Real[*];
        attribute accuracy : Micrometer;
        attribute resolution : Micrometer;
        attribute quality : Fraction;
        attribute reconstructedWave : ReconstructedWave;
        attribute measurementId : Integer;
        attribute timestamp : Seconds;
    }

    item def ControlCommand {
        doc "External command to control the system: measure, reset, or status query.";
        attribute commandType : CommandType;
        attribute timestamp : Seconds;
    }

    item def StatusReport {
        doc "System status output report.";
        attribute currentState : SystemStateKind;
        attribute errorCode : Integer;
        attribute lastMeasurementId : Integer;
        attribute timestamp : Seconds;
        attribute message : String;
    }

    // ============================= PORT DEFINITIONS =============================

    port def LaserOutputPort {
        out beam : CoherentLight;
    }

    port def CoherentLightInputPort {
        in beam : CoherentLight;
    }

    port def BeamSplitterInputPort {
        in inputBeam : CoherentLight;
    }

    port def ObjectBeamOutputPort {
        out objectBeam : CoherentLight;
    }

    port def ReferenceBeamOutputPort {
        out referenceBeam : CoherentLight;
    }

    port def ObjectBeamInputPort {
        in objectBeam : CoherentLight;
    }

    port def ReflectedLightOutputPort {
        out reflectedLight : ReflectedObjectLight;
    }

    port def ReflectedLightInputPort {
        in reflectedLight : ReflectedObjectLight;
    }

    port def ReferenceBeamInputPort {
        in referenceBeam : ReferenceBeam;
    }

    port def PatternOutputPort {
        out pattern : InterferencePattern;
    }

    port def PatternInputPort {
        in pattern : InterferencePattern;
    }

    port def RecordOutputPort {
        out record : HologramRecord;
    }

    port def RecordInputPort {
        in record : HologramRecord;
    }

    port def MeasurementOutputPort {
        out measurementData : MeasurementData;
    }

    port def MeasurementDataInputPort {
        in measurementData : MeasurementData;
    }

    port def CommandInputPort {
        in command : ControlCommand;
    }

    port def StatusOutputPort {
        out status : StatusReport;
    }

    // ============================= PART DEFINITIONS =============================

    part def LaserSource {
        doc "High-stability coherent laser light source for holography.";

        attribute targetWavelength : Nanometer = 632.8;
        attribute outputPower : Milliwatt = 50.0;
        attribute stability : Fraction = 0.999;
        attribute warmupDuration : Seconds = 30.0;
        attribute currentWavelength : Nanometer;
        attribute currentPower : Milliwatt;
        attribute warmedUp : Boolean = false;

        port laserOut : LaserOutputPort;

        action def warmUp {
            doc "Stabilizes laser output over the warmup period.";
        }

        action def emit {
            doc "Emits a coherent beam when warmed up.";
        }

        action def stabilize {
            doc "Monitors and adjusts wavelength stability.";
        }
    }

    part def BeamSplitter {
        doc "Optical beam splitter dividing input into object and reference beams.";

        attribute splittingRatio : Fraction = 0.5;

        port beamIn : BeamSplitterInputPort;
        port objOut : ObjectBeamOutputPort;
        port refOut : ReferenceBeamOutputPort;

        action def split {
            doc "Divides incoming beam into object and reference paths by splitting ratio.";
        }
    }

    part def ObjectIlluminationAssembly {
        doc "Directs object beam onto target surface and collects reflected light.";

        attribute illuminationAngle : Radians = 0.524;
        attribute fieldOfView : Radians = 0.262;
        attribute workingDistance : Micrometer = 100000.0;

        port beamIn : ObjectBeamInputPort;
        port reflectedOut : ReflectedLightOutputPort;

        action def illuminate {
            doc "Directs the object beam onto the target surface.";
        }

        action def collectReflection {
            doc "Collects reflected light carrying surface shape and texture information.";
        }
    }

    part def ReferencePath {
        doc "Uninterrupted optical path for the reference beam to reach the detector.";

        attribute pathLength : Micrometer = 500000.0;
        attribute beamQuality : Fraction = 0.998;
        attribute mirrorCount : Integer = 2;

        port beamIn : CoherentLightInputPort;
        port beamOut : ReferenceBeamOutputPort;

        action def transmit {
            doc "Passes the reference beam through the uninterrupted path to the detector.";
        }
    }

    part def DigitalDetector {
        doc "High-resolution digital detector (CCD-like) for capturing interference patterns.";

        attribute pixelCountX : Integer = 2048;
        attribute pixelCountY : Integer = 2048;
        attribute pixelSize : Micrometer = 5.0;
        attribute dynamicRangeBits : Integer = 16;
        attribute frameRate : Hertz = 30.0;
        attribute quantumEfficiency : Fraction = 0.85;

        port objIn : ReflectedLightInputPort;
        port refIn : ReferenceBeamInputPort;
        port patternOut : PatternOutputPort;

        action def recombineAndInterfere {
            doc "Recombines reflected object light and reference beam to produce interference pattern.";
        }

        action def captureFrame {
            doc "Captures a single frame of the interference pattern at the sensor plane.";
        }
    }

    part def HolographicRecorder {
        doc "Captures the interference pattern as a digital hologram record.";

        attribute captureMode : String = "digital";
        attribute bufferCapacity : Integer = 100;
        attribute currentRecordId : Integer;

        port patternIn : PatternInputPort;
        port recordOut : RecordOutputPort;

        action def capture {
            doc "Digitizes and stores the interference pattern as a hologram record.";
        }
    }

    part def SignalProcessor {
        doc "Computational unit for hologram reconstruction using Fourier Transform algorithms.";

        attribute clockFrequency : Hertz = 3000000000.0;
        attribute reconstructionAlgorithm : String = "FourierTransform";
        attribute processingTime : Seconds = 0.5;
        attribute currentResult : MeasurementData;

        port recordIn : RecordInputPort;
        port dataOut : MeasurementOutputPort;

        action def reconstruct {
            doc "Performs numerical reconstruction of the hologram to obtain measurement data.";
        }

        action def fourierTransform {
            doc "Applies Fast Fourier Transform to the raw interference data.";
        }

        action def extract3DCoordinates {
            doc "Extracts three-dimensional spatial coordinates from the reconstructed wavefront.";
        }

        action def computeQuality {
            doc "Computes the quality metric of the reconstruction.";
        }
    }

    part def CommandInterface {
        doc "External command and status interface for system control and data output.";

        attribute commandTimeout : Seconds = 5.0;
        attribute lastCommandType : CommandType;
        attribute currentMeasurementId : Integer = 0;

        port cmdIn : CommandInputPort;
        port statusOut : StatusOutputPort;
        port dataIn : MeasurementDataInputPort;
        port dataOut : MeasurementOutputPort;

        action def receiveCommand {
            doc "Receives and routes an external command.";
        }

        action def sendStatus {
            doc "Reports the current system status.";
        }

        action def sendData {
            doc "Outputs the final reconstructed measurement data.";
        }
    }

    // ============================= MAIN SYSTEM =============================

    part def HolographicSensingSystem {
        doc "A high-precision, non-contact measurement device using laser holography to capture three-dimensional surface information.";

        attribute systemName : String = "HolographicSensingUnit";
        attribute targetWavelength : Nanometer = 632.8;
        attribute spatialResolution : Micrometer = 1.0;
        attribute measurementAccuracy : Micrometer = 5.0;
        attribute maxWarmupTime : Seconds = 30.0;

        // External interfaces
        port commandPort : CommandInputPort;
        port statusPort : StatusOutputPort;
        port dataPort : MeasurementOutputPort;

        // Internal parts
        part laser : LaserSource {
            attribute targetWavelength = 632.8;
            attribute outputPower = 50.0;
            attribute stability = 0.999;
            attribute warmupDuration = 30.0;
        }

        part splitter : BeamSplitter {
            attribute splittingRatio = 0.5;
        }

        part objectAssembly : ObjectIlluminationAssembly {
            attribute illuminationAngle = 0.524;
            attribute fieldOfView = 0.262;
            attribute workingDistance = 100000.0;
        }

        part refPath : ReferencePath {
            attribute pathLength = 500000.0;
            attribute beamQuality = 0.998;
            attribute mirrorCount = 2;
        }

        part detector : DigitalDetector {
            attribute pixelCountX = 2048;
            attribute pixelCountY = 2048;
            attribute pixelSize = 5.0;
            attribute dynamicRangeBits = 16;
            attribute frameRate = 30.0;
            attribute quantumEfficiency = 0.85;
        }

        part recorder : HolographicRecorder {
            attribute captureMode = "digital";
            attribute bufferCapacity = 100;
        }

        part processor : SignalProcessor {
            attribute clockFrequency = 3000000000.0;
            attribute reconstructionAlgorithm = "FourierTransform";
            attribute processingTime = 0.5;
        }

        part interface : CommandInterface {
            attribute commandTimeout = 5.0;
        }

        // Internal connections — optical path
        connect laser.laserOut to splitter.beamIn;
        connect splitter.objOut to objectAssembly.beamIn;
        connect splitter.refOut to refPath.beamIn;
        connect objectAssembly.reflectedOut to detector.objIn;
        connect refPath.beamOut to detector.refIn;
        connect detector.patternOut to recorder.patternIn;
        connect recorder.recordOut to processor.recordIn;
        connect processor.dataOut to interface.dataIn;

        // Control and data connections
        connect commandPort to interface.cmdIn;
        connect interface.statusOut to statusPort;
        connect interface.dataOut to dataPort;

        // State tracking attributes
        attribute currentCommand : CommandType;
        attribute currentSystemState : SystemStateKind = SystemStateKind::idle;
        attribute initialized : Boolean = false;
        attribute patternCaptured : Boolean = false;
        attribute resultReady : Boolean = false;
        attribute activeMeasurementId : Integer = 0;
        attribute errorCode : Integer = 0;

        // Composite action definitions for state machine activities

        action def warmUpSequence {
            doc "Laser warmup and system self-check.";
            laser.warmUp;
            laser.stabilize;
        }

        action def captureSequence {
            doc "Full optical capture: emit, split, illuminate, collect, transmit, detect, record.";
            laser.emit;
            splitter.split;
            objectAssembly.illuminate;
            objectAssembly.collectReflection;
            refPath.transmit;
            detector.recombineAndInterfere;
            detector.captureFrame;
            recorder.capture;
        }

        action def processSequence {
            doc "Fourier Transform reconstruction of hologram into measurement data.";
            processor.fourierTransform;
            processor.reconstruct;
            processor.extract3DCoordinates;
            processor.computeQuality;
        }

        action def processCommand {
            doc "Processes the incoming command and sets currentCommand.";
            currentCommand = interface.cmdIn.command.commandType;
        }

        action def resetSystem {
            doc "Resets the system to idle state.";
            currentSystemState = SystemStateKind::idle;
            initialized = false;
            patternCaptured = false;
            resultReady = false;
            errorCode = 0;
        }

        action def reportStatus {
            doc "Generates and outputs a status report.";
            interface.sendStatus;
        }

        action def performMeasurement {
            doc "Complete measurement sequence from command to data output.";
            in cmd : ControlCommand;
            out result : MeasurementData;
            out status : StatusReport;

            warmUpSequence;
            captureSequence;
            processSequence;

            result = processor.dataOut.measurementData;
            status = StatusReport {
                currentState = SystemStateKind::idle;
                errorCode = 0;
                lastMeasurementId = activeMeasurementId;
            };
        }

        // State machine
        state machine HolographicUnitStateMachine {

            state idle {
                doc "System idle, awaiting commands.";
                entry { currentSystemState = SystemStateKind::idle; }
                do processCommand;
            }

            state initializing {
                doc "Laser warmup and system self-check.";
                entry { currentSystemState = SystemStateKind::initializing; }
                do warmUpSequence;
                exit { initialized = true; }
            }

            state capturing {
                doc "Illuminating object, splitting beams, detecting interference, recording hologram.";
                entry { currentSystemState = SystemStateKind::capturing; }
                do captureSequence;
                exit { patternCaptured = true; }
            }

            state processing {
                doc "Fourier Transform reconstruction of hologram into measurement data.";
                entry { currentSystemState = SystemStateKind::processing; }
                do processSequence;
                exit { resultReady = true; }
            }

            state error {
                doc "Error state requiring external reset.";
                entry { currentSystemState = SystemStateKind::error; }
            }

            // Transitions
            transition initial to idle;

            transition t_idle_to_init: idle to initializing
                when (currentCommand == CommandType::measure);

            transition t_init_to_capture: initializing to capturing
                when (initialized == true);

            transition t_capture_to_process: capturing to processing
                when (patternCaptured == true);

            transition t_process_to_idle: processing to idle
                when (resultReady == true);

            transition t_idle_reset: idle to idle
                when (currentCommand == CommandType::reset);

            transition t_error_to_idle: error to idle
                when (currentCommand == CommandType::reset);

            transition t_init_error: initializing to error
                when (laser.stability < 0.95);

            transition t_capture_error: capturing to error
                when (detector.patternOut.pattern == null);

            transition t_process_error: processing to error
                when (processor.dataOut == null);
        }

        // Requirement satisfaction
        satisfy MeasurementAccuracyRequirement;
        satisfy SpatialResolutionRequirement;
        satisfy LaserWavelengthRequirement;
        satisfy NonContactMeasurementRequirement;
        satisfy LaserStabilityRequirement;
        satisfy DetectorResolutionRequirement;
        satisfy FourierReconstructionRequirement;
        satisfy MeasurementQualityRequirement;
        satisfy StateMachineRequirement;
        satisfy CommandInterfaceRequirement;
        satisfy StatusOutputRequirement;
    }

    // ============================= REQUIREMENTS =============================

    requirement def MeasurementAccuracyRequirement {
        doc "The system shall achieve measurement accuracy within 5 micrometers.";
        attribute maxAccuracy : Micrometer = 5.0;
        constraint { HolographicSensingSystem.measurementAccuracy <= 5.0 }
    }

    requirement def SpatialResolutionRequirement {
        doc "The system shall achieve spatial resolution at or below 1 micrometer.";
        attribute maxResolution : Micrometer = 1.0;
        constraint { HolographicSensingSystem.spatialResolution <= 1.0 }
    }

    requirement def LaserWavelengthRequirement {
        doc "The system shall use a coherent laser source with a specific wavelength of 632.8 nm.";
        attribute requiredWavelength : Nanometer = 632.8;
        constraint { HolographicSensingSystem.targetWavelength == 632.8 }
    }

    requirement def NonContactMeasurementRequirement {
        doc "The system shall perform all measurements without physical contact with the target object.";
        constraint { HolographicSensingSystem.objectAssembly.workingDistance > 0 }
    }

    requirement def LaserStabilityRequirement {
        doc "The laser source shall maintain coherence stability above 95 percent.";
        attribute minStability : Fraction = 0.95;
        constraint { HolographicSensingSystem.laser.stability >= 0.95 }
    }

    requirement def DetectorResolutionRequirement {
        doc "The digital detector shall have at least 1024 by 1024 pixels for hologram capture.";
        attribute minPixels : Integer = 1024;
        constraint { HolographicSensingSystem.detector.pixelCountX >= 1024 and HolographicSensingSystem.detector.pixelCountY >= 1024 }
    }

    requirement def FourierReconstructionRequirement {
        doc "The signal processor shall reconstruct the hologram using Fourier Transform algorithms.";
        constraint { HolographicSensingSystem.processor.reconstructionAlgorithm == "FourierTransform" }
    }

    requirement def MeasurementQualityRequirement {
        doc "The reconstructed measurement data shall have a quality level above 0.9.";
        attribute minQuality : Fraction = 0.9;
        constraint { MeasurementData.quality >= 0.9 }
    }

    requirement def StateMachineRequirement {
        doc "The system shall operate through idle, initializing, capturing, and processing states.";
        constraint { HolographicSensingSystem.HolographicUnitStateMachine }
    }

    requirement def CommandInterfaceRequirement {
        doc "The system shall accept external commands for measurement initiation and system reset.";
        constraint { HolographicSensingSystem.commandPort.command.commandType == CommandType::measure or HolographicSensingSystem.commandPort.command.commandType == CommandType::reset }
    }

    requirement def StatusOutputRequirement {
        doc "The system shall output its current status and the final reconstructed measurement data.";
        constraint { HolographicSensingSystem.statusPort.status != null and HolographicSensingSystem.dataPort.measurementData != null }
    }
}
