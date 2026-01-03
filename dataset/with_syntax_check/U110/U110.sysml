package RetinalImplantSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    private import Time::*;

    doc /* 
     * This model describes a retinal prosthesis system designed to restore functional vision
     * to individuals with retinal degenerative diseases. The system captures visual information
     * from the environment, processes it into electrical stimulation patterns, and delivers
     * these patterns to remaining retinal neurons to create visual perception.
     */

    // =========================================================================
    // Value and Item Definitions
    // =========================================================================

    attribute def PixelResolution :> Integer;
    attribute def StimulationAmplitude :> Real;
    attribute def DataRateValue :> Real;
    
    enum def SystemMode {
        off;
        initializing;
        operational;
        standby;
        diagnostic;
        fault;
    }

    enum def ProcessingAlgorithm {
        edgeDetection;
        contrastEnhancement;
        motionTracking;
        adaptive;
    }

    item def VisualScene {
        attribute timestamp : TimeValue;
        attribute brightness : Real;
        attribute pixelData : Integer[*];
    }

    item def StimulationPattern {
        attribute electrodeMap : Boolean[60];
        attribute pulseAmplitude : StimulationAmplitude;
        attribute pulseDuration : DurationValue;
        attribute pulseFrequency : Real;
    }

    item def WirelessDataPacket {
        attribute packetID : Integer;
        attribute payload : Integer[*];
        attribute checksum : Integer;
    }

    item def LowPowerSignal;
    item def ResumeSignal;
    item def DiagnosticRequest;
    item def DiagnosticComplete;
    item def SystemError;
    item def FaultCleared;

    // =========================================================================
    // Component Definitions
    // =========================================================================

    part def MiniatureCamera {
        doc /* External camera mounted on eyeglasses to capture visual scene. */
        attribute :>> mass : MassValue;
        attribute resolution : PixelResolution;
        attribute frameRate : Real;
        attribute fieldOfView : Real;
        port videoOutput;
        port powerInput;
    }

    part def ImageProcessingUnit {
        doc /* Processes raw video into optimized stimulation patterns. */
        attribute :>> mass : MassValue;
        attribute processingAlgorithm : ProcessingAlgorithm;
        attribute computationSpeed : Real;
        port videoInput;
        port dataOutput;
        port powerInput;
    }

    part def RadioFrequencyTransmitter {
        doc /* Transmits processed data wirelessly to implanted receiver. */
        attribute :>> mass : MassValue;
        attribute carrierFrequency : Real;
        attribute transmitPower : PowerValue;
        attribute dataRate : DataRateValue;
        port dataInput;
        port antennaOutput;
        port powerInput;
    }

    part def RadioFrequencyReceiver {
        doc /* Receives wireless data inside the eye. */
        attribute :>> mass : MassValue;
        attribute sensitivity : Real;
        attribute operatingFrequency : Real;
        port antennaInput;
        port dataOutput;
        port powerOutput;
    }

    part def SignalDecoder {
        doc /* Decodes received data packets into stimulation commands. */
        attribute :>> mass : MassValue;
        attribute decodingLatency : DurationValue;
        port dataInput;
        port commandOutput;
    }

    part def StimulationController {
        doc /* Generates precise electrical pulses for electrode array. */
        attribute :>> mass : MassValue;
        attribute maxCurrent : Real;
        attribute pulseResolution : DurationValue;
        attribute numberOfChannels : Integer;
        port commandInput;
        port stimulationOutput;
    }

    part def MicroelectrodeArray {
        doc /* Array of electrodes in contact with retinal tissue. */
        attribute :>> mass : MassValue;
        attribute numberOfElectrodes : Integer;
        attribute electrodeSpacing : LengthValue;
        attribute electrodeDiameter : LengthValue;
        port stimulationInput;
        port neuralInterface;
    }

    part def RechargeableBattery {
        doc /* Powers external components. */
        attribute :>> mass : MassValue;
        attribute capacity : Real;
        attribute voltage : Real;
        attribute chargeCycles : Integer;
        port powerOutput;
        port chargingInput;
    }

    part def InductivePowerCoil {
        doc /* Provides wireless power to implanted components. */
        attribute :>> mass : MassValue;
        attribute inductance : Real;
        attribute efficiency : Real;
        port powerInput;
        port magneticCoupling;
    }

    part def RetinalNeurons {
        doc /* Biological retinal ganglion cells that receive stimulation. */
        attribute cellViability : Real;
        attribute responseThreshold : Real;
        port electricalInput;
    }

    // =========================================================================
    // System Assembly
    // =========================================================================

    part def ExternalUnit {
        doc /* Wearable components mounted on eyeglasses. */
        attribute :>> mass : MassValue;
        
        part camera : MiniatureCamera {
            attribute :>> resolution = 640;
            attribute :>> frameRate = 30.0;
            attribute :>> fieldOfView = 60.0;
            attribute :>> mass = 18.0 [g];
        }

        part processor : ImageProcessingUnit {
            attribute :>> processingAlgorithm = ProcessingAlgorithm::adaptive;
            attribute :>> computationSpeed = 120.0;
            attribute :>> mass = 22.0 [g];
        }

        part transmitter : RadioFrequencyTransmitter {
            attribute :>> carrierFrequency = 2450.0;
            attribute :>> transmitPower = 0.8 [W];
            attribute :>> dataRate = 10.0;
            attribute :>> mass = 12.0 [g];
        }

        part battery : RechargeableBattery {
            attribute :>> capacity = 2800.0;
            attribute :>> voltage = 3.7;
            attribute :>> chargeCycles = 500;
            attribute :>> mass = 35.0 [g];
        }

        part powerCoil : InductivePowerCoil {
            attribute :>> inductance = 15.0;
            attribute :>> efficiency = 0.75;
            attribute :>> mass = 8.0 [g];
        }

        connection cameraToPower connect camera.powerInput to battery.powerOutput;
        connection cameraToProcessor connect camera.videoOutput to processor.videoInput;
        connection processorToPower connect processor.powerInput to battery.powerOutput;
        connection processorToTransmitter connect processor.dataOutput to transmitter.dataInput;
        connection transmitterToPower connect transmitter.powerInput to battery.powerOutput;
        connection powerCoilToBattery connect powerCoil.powerInput to battery.powerOutput;
    }

    part def ImplantedUnit {
        doc /* Surgically implanted components inside and on the eye. */
        attribute :>> mass : MassValue;
        
        part receiver : RadioFrequencyReceiver {
            attribute :>> sensitivity = -85.0;
            attribute :>> operatingFrequency = 2450.0;
            attribute :>> mass = 3.5 [g];
        }

        part decoder : SignalDecoder {
            attribute :>> decodingLatency = 0.008 [s];
            attribute :>> mass = 2.0 [g];
        }

        part stimController : StimulationController {
            attribute :>> maxCurrent = 2.5;
            attribute :>> pulseResolution = 0.00001 [s];
            attribute :>> numberOfChannels = 60;
            attribute :>> mass = 4.0 [g];
        }

        part electrodeArray : MicroelectrodeArray {
            attribute :>> numberOfElectrodes = 60;
            attribute :>> electrodeSpacing = 0.25 [mm];
            attribute :>> electrodeDiameter = 0.1 [mm];
            attribute :>> mass = 1.5 [g];
        }

        connection receiverToDecoder connect receiver.dataOutput to decoder.dataInput;
        connection decoderToController connect decoder.commandOutput to stimController.commandInput;
        connection controllerToArray connect stimController.stimulationOutput to electrodeArray.stimulationInput;
    }

    part def BiologicalInterface {
        doc /* Biological tissue interfacing with the implant. */
        
        part retina : RetinalNeurons {
            attribute :>> cellViability = 0.82;
            attribute :>> responseThreshold = 0.15;
        }
    }

    part retinalProsthesisSystem {
        doc /* Complete integrated retinal prosthesis system. */
        attribute :>> mass : MassValue;
        attribute systemMode : SystemMode;
        
        part external : ExternalUnit {
            attribute :>> mass = camera.mass + processor.mass + transmitter.mass + 
                                battery.mass + powerCoil.mass;
        }

        part implant : ImplantedUnit {
            attribute :>> mass = receiver.mass + decoder.mass + stimController.mass + 
                                electrodeArray.mass;
        }

        part biological : BiologicalInterface;

        connection wirelessDataLink connect external.transmitter.antennaOutput to implant.receiver.antennaInput;
        connection wirelessPowerLink connect external.powerCoil.magneticCoupling to implant.receiver.powerOutput;
        connection neuralInterface connect implant.electrodeArray.neuralInterface to biological.retina.electricalInput;

        attribute :>> mass = external.mass + implant.mass;

        perform action visionRestoration[*] ordered references RestoreVision;
    }

    // =========================================================================
    // Behavior Definitions
    // =========================================================================

    action def CaptureVisualScene {
        doc /* Camera captures the visual environment. */
        in ambientLight : Real;
        out scene : VisualScene;
    }

    action def ProcessImageData {
        doc /* Process raw image into optimized stimulation map. */
        in rawScene : VisualScene;
        in algorithm : ProcessingAlgorithm;
        out stimPattern : StimulationPattern;
    }

    action def TransmitWireless {
        doc /* Encode and transmit data wirelessly. */
        in stimPattern : StimulationPattern;
        out dataPacket : WirelessDataPacket;
    }

    action def ReceiveWireless {
        doc /* Receive and validate wireless data. */
        in dataPacket : WirelessDataPacket;
        out validatedData : WirelessDataPacket;
    }

    action def DecodeStimulation {
        doc /* Decode data packet into stimulation commands. */
        in dataPacket : WirelessDataPacket;
        out stimPattern : StimulationPattern;
    }

    action def GenerateElectricalPulses {
        doc /* Generate precise electrical pulses for each electrode. */
        in stimPattern : StimulationPattern;
        out pulseSequence : Integer[*];
    }

    action def StimulateRetinalCells {
        doc /* Deliver electrical stimulation to retinal neurons. */
        in pulseSequence : Integer[*];
        out neuralResponse : Real;
    }

    action def MonitorSystemHealth {
        doc /* Continuously monitor system status and safety parameters. */
        out systemStatus : SystemMode;
        out safetyAlert : Boolean;
    }

    action RestoreVision {
        doc /* 
         * Primary system behavior: The retinal prosthesis captures visual information
         * from the environment, processes it into electrical stimulation patterns,
         * and delivers these patterns to retinal neurons to restore functional vision.
         * This process operates continuously in a feedback loop.
         */

        first start;
        then merge continuousLoop;

        then action monitor : MonitorSystemHealth {
            out status : SystemMode;
            out alert : Boolean;
        }

        then decide;
            if monitor.status == SystemMode::operational then captureScene;
            if monitor.status == SystemMode::standby then continuousLoop;
            if monitor.status == SystemMode::fault then shutdown;

        action captureScene : CaptureVisualScene {
            in ambientLight = 500.0;
            out visualData : VisualScene;
        }

        then action processImage : ProcessImageData {
            in rawScene = captureScene.visualData;
            in algorithm = ProcessingAlgorithm::adaptive;
            out pattern : StimulationPattern;
        }

        then action transmit : TransmitWireless {
            in stimPattern = processImage.pattern;
            out packet : WirelessDataPacket;
        }

        then action receive : ReceiveWireless {
            in dataPacket = transmit.packet;
            out validated : WirelessDataPacket;
        }

        then action decode : DecodeStimulation {
            in dataPacket = receive.validated;
            out decodedPattern : StimulationPattern;
        }

        then action generatePulses : GenerateElectricalPulses {
            in stimPattern = decode.decodedPattern;
            out pulses : Integer[*];
        }

        then action stimulate : StimulateRetinalCells {
            in pulseSequence = generatePulses.pulses;
            out response : Real;
        }

        then continuousLoop;

        action shutdown;
        then done;
    }

    // =========================================================================
    // State Machine
    // =========================================================================

    state def SystemOperationStates {
        doc /* Defines operational states of the retinal prosthesis. */
        
        entry; then powerOn;

        state powerOn {
            doc /* Initial power-up state. */
        }
        transition powerOn_to_initialization
            first powerOn
            then initialization;

        state initialization {
            doc /* System initialization and self-test. */
            entry; then testElectrodes;
            state testElectrodes;
            then verifyConnections;
            state verifyConnections;
            then calibrateSensors;
            state calibrateSensors;
            then done;
        }
        transition initialization_to_operational
            first initialization
            then operational;

        state operational {
            doc /* Normal vision restoration operation. */
            entry; then activeStimulation;
            
            state activeStimulation {
                doc /* Actively processing and stimulating. */
            }

            transition activeStimulation_to_standby
                first activeStimulation
                accept lowPower : LowPowerSignal
                then standby;

            state standby {
                doc /* Low power mode with minimal processing. */
            }

            transition standby_to_activeStimulation
                first standby
                accept resume : ResumeSignal
                then activeStimulation;
        }

        transition operational_to_diagnostic
            first operational
            accept diagRequest : DiagnosticRequest
            then diagnostic;

        state diagnostic {
            doc /* System diagnostic and testing mode. */
            entry; then runDiagnostics;
            state runDiagnostics;
            then done;
        }

        transition diagnostic_to_operational
            first diagnostic
            accept diagComplete : DiagnosticComplete
            then operational;

        transition operational_to_fault
            first operational
            accept sysError : SystemError
            then fault;

        state fault {
            doc /* Fault state requiring intervention. */
        }

        transition fault_to_initialization
            first fault
            accept cleared : FaultCleared
            then initialization;
    }

    // =========================================================================
    // Requirements
    // =========================================================================

    requirement def StakeholderRequirement;
    requirement def FunctionalRequirement;
    requirement def PerformanceRequirement;
    requirement def SafetyRequirement;
    requirement def DesignConstraint;

    requirement <'REQ-SH-001'> restoreVision : StakeholderRequirement {
        doc /* 
         * The retinal prosthesis system shall restore functional vision to patients
         * with retinal degenerative diseases by converting visual information into
         * electrical stimulation of remaining retinal neurons, enabling perception
         * of light, shapes, and motion.
         */
        subject system : retinalProsthesisSystem;
    }

    requirement <'REQ-FN-100'> captureVisualInformation : FunctionalRequirement {
        doc /* 
         * The system shall continuously capture visual information from the environment
         * at a minimum frame rate of 30 frames per second.
         */
        subject camera :>> retinalProsthesisSystem.external.camera;
        assert constraint {
            camera.frameRate >= 30.0
        }
    }

    requirement <'REQ-FN-101'> processImageData : FunctionalRequirement {
        doc /* 
         * The system shall process captured images into optimized stimulation patterns
         * using adaptive algorithms that enhance edges, contrast, and motion.
         */
        subject processor :>> retinalProsthesisSystem.external.processor;
    }

    requirement <'REQ-FN-102'> wirelessDataTransmission : FunctionalRequirement {
        doc /* 
         * The system shall transmit processed stimulation data wirelessly from external
         * to implanted components with a data rate of at least 10 Mbps.
         */
        subject transmitter :>> retinalProsthesisSystem.external.transmitter;
        assert constraint {
            transmitter.dataRate >= 10.0
        }
    }

    requirement <'REQ-PR-200'> electrodeResolution : PerformanceRequirement {
        doc /* 
         * The electrode array shall contain at least 60 individually addressable
         * electrodes to provide sufficient spatial resolution for pattern recognition.
         */
        subject array :>> retinalProsthesisSystem.implant.electrodeArray;
        assert constraint {
            array.numberOfElectrodes >= 60
        }
    }

    requirement <'REQ-PR-201'> processingLatency : PerformanceRequirement {
        doc /* 
         * The end-to-end latency from image capture to retinal stimulation shall
         * not exceed 50 milliseconds to ensure real-time visual perception.
         */
        subject system : retinalProsthesisSystem;
    }

    requirement <'REQ-PR-202'> batteryLife : PerformanceRequirement {
        doc /* 
         * The external battery shall provide at least 8 hours of continuous operation
         * to support full-day usage.
         */
        subject battery :>> retinalProsthesisSystem.external.battery;
        assert constraint {
            battery.capacity >= 2800.0
        }
    }

    requirement <'REQ-SF-300'> stimulationSafety : SafetyRequirement {
        doc /* 
         * The maximum stimulation current delivered to any electrode shall not exceed
         * 2.5 mA to prevent tissue damage and ensure patient safety.
         */
        subject controller :>> retinalProsthesisSystem.implant.stimController;
        assert constraint {
            controller.maxCurrent <= 2.5
        }
    }

    requirement <'REQ-SF-301'> biocompatibility : SafetyRequirement {
        doc /* 
         * All implanted components shall be manufactured from biocompatible materials
         * approved for long-term intraocular use.
         */
        subject implant :>> retinalProsthesisSystem.implant;
    }

    requirement <'REQ-DC-400'> implantMass : DesignConstraint {
        doc /* 
         * The total mass of the implanted unit shall not exceed 15 grams to minimize
         * surgical invasiveness and patient discomfort.
         */
        subject implant :>> retinalProsthesisSystem.implant;
        assert constraint {
            implant.mass <= 15.0 [g]
        }
    }

    requirement <'REQ-DC-401'> externalUnitMass : DesignConstraint {
        doc /* 
         * The total mass of the external unit shall not exceed 100 grams to ensure
         * comfortable all-day wear on eyeglasses.
         */
        subject external :>> retinalProsthesisSystem.external;
        assert constraint {
            external.mass <= 100.0 [g]
        }
    }

    // =========================================================================
    // Requirement Satisfaction
    // =========================================================================

    satisfy restoreVision by retinalProsthesisSystem;
    satisfy captureVisualInformation by retinalProsthesisSystem.external.camera;
    satisfy processImageData by retinalProsthesisSystem.external.processor;
    satisfy wirelessDataTransmission by retinalProsthesisSystem.external.transmitter;
    satisfy electrodeResolution by retinalProsthesisSystem.implant.electrodeArray;
    satisfy processingLatency by retinalProsthesisSystem;
    satisfy batteryLife by retinalProsthesisSystem.external.battery;
    satisfy stimulationSafety by retinalProsthesisSystem.implant.stimController;
    satisfy biocompatibility by retinalProsthesisSystem.implant;
    satisfy implantMass by retinalProsthesisSystem.implant;
    satisfy externalUnitMass by retinalProsthesisSystem.external;
}
