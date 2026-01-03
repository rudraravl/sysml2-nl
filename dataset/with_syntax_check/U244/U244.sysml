package HomeUltrasoundSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def FrequencyValue :> ISQ::FrequencyValue;
    attribute def TemperatureValue :> ISQ::TemperatureValue;
    attribute def PowerValue :> ISQ::PowerValue;
    attribute def VoltageValue :> ISQ::VoltageValue;
    attribute def DepthValue :> ISQ::LengthValue;
    attribute def ResolutionValue :> ISQ::LengthValue;

    enum def SystemMode {
        powerOff;
        standby;
        imaging;
        freeze;
        review;
    }

    enum def ImagingMode {
        bMode;
        mMode;
        colorDoppler;
    }

    enum def SafetyLevel {
        normal;
        warning;
        critical;
    }

    item def AcousticSignal {
        attribute frequency : FrequencyValue;
        attribute amplitude : Real;
        attribute timestamp : Real;
    }

    item def RawEchoData {
        attribute signalStrength : Real;
        attribute timeOfFlight : Real;
        attribute depth : DepthValue;
    }

    item def ProcessedImageData {
        attribute resolution : ResolutionValue;
        attribute contrast : Real;
        attribute brightness : Real;
    }

    item def DiagnosticImage {
        attribute imageMode : ImagingMode;
        attribute timestamp : Real;
        attribute imageMetadata : String;
    }

    port def PowerInputPort {
        in voltage : VoltageValue;
        in current : Real;
    }

    port def SignalOutputPort {
        out signal : AcousticSignal;
    }

    port def EchoInputPort {
        in echoData : RawEchoData;
    }

    port def DataOutputPort {
        out imageData : ProcessedImageData;
    }

    port def DisplayInputPort {
        in displayData : DiagnosticImage;
    }

    port def ControlPort {
        in command : String;
        out status : String;
    }

    part def TransducerArray {
        attribute operatingFrequency : FrequencyValue;
        attribute elementCount : Integer;
        attribute surfaceTemperature : TemperatureValue;
        attribute maxPenetrationDepth : DepthValue;
        
        port signalOut : SignalOutputPort;
        port echoIn : EchoInputPort;
        port powerIn : PowerInputPort;
        port control : ControlPort;
    }

    part def BeamFormer {
        attribute channelCount : Integer;
        attribute focusDepth : DepthValue;
        
        port rawSignalIn : EchoInputPort;
        port beamformedOut : DataOutputPort;
        port powerIn : PowerInputPort;
    }

    part def SignalProcessor {
        attribute processingPower : PowerValue;
        attribute filterBandwidth : FrequencyValue;
        
        port dataIn : DataOutputPort;
        port processedOut : DataOutputPort;
        port powerIn : PowerInputPort;
    }

    part def ImageProcessor {
        attribute frameRate : Real;
        attribute imageBuffer : Integer;
        
        port signalIn : DataOutputPort;
        port imageOut : DisplayInputPort;
        port powerIn : PowerInputPort;
    }

    part def DisplayModule {
        attribute screenSize : Real;
        attribute displayResolution : String;
        attribute brightness : Real;
        
        port imageIn : DisplayInputPort;
        port powerIn : PowerInputPort;
    }

    part def PowerManagement {
        attribute batteryCapacity : Real;
        attribute outputVoltage : VoltageValue;
        attribute maxOutputCurrent : Real;
        attribute batteryLevel : Real;
        
        port mainsInput : PowerInputPort;
        port powerOut1 : PowerInputPort;
        port powerOut2 : PowerInputPort;
        port powerOut3 : PowerInputPort;
        port powerOut4 : PowerInputPort;
        port powerOut5 : PowerInputPort;
    }

    part def ControlInterface {
        attribute buttonCount : Integer;
        attribute touchscreenEnabled : Boolean;
        
        port userInput : ControlPort;
        port systemControl : ControlPort;
        port powerIn : PowerInputPort;
    }

    part def ThermalMonitor {
        attribute maxSafeTemperature : TemperatureValue;
        attribute currentTemperature : TemperatureValue;
        attribute coolingActive : Boolean;
        
        port temperatureSensor : ControlPort;
        port safetyAlert : ControlPort;
    }

    part def HomeUltrasoundDevice {
        doc /* A portable diagnostic ultrasound imaging system designed for home healthcare use,
             * providing real-time visualization of internal anatomical structures through
             * acoustic imaging technology. */

        attribute systemMode : SystemMode;
        attribute activeImagingMode : ImagingMode;
        attribute safetyStatus : SafetyLevel;
        attribute totalMass : ISQ::MassValue;
        attribute operationalTime : Time::DurationValue;

        part transducer : TransducerArray {
            attribute :>> operatingFrequency = 3500000.0 [SI::Hz];
            attribute :>> elementCount = 128;
            attribute :>> surfaceTemperature : TemperatureValue;
            attribute :>> maxPenetrationDepth = 0.25 [SI::m];
        }

        part beamformer : BeamFormer {
            attribute :>> channelCount = 128;
            attribute :>> focusDepth = 0.08 [SI::m];
        }

        part signalProc : SignalProcessor {
            attribute :>> processingPower = 25.0 [SI::W];
            attribute :>> filterBandwidth = 5000000.0 [SI::Hz];
        }

        part imageProc : ImageProcessor {
            attribute :>> frameRate = 30.0;
            attribute :>> imageBuffer = 60;
        }

        part display : DisplayModule {
            attribute :>> screenSize = 10.1;
            attribute :>> displayResolution = "1920x1200";
            attribute :>> brightness = 400.0;
        }

        part powerMgmt : PowerManagement {
            attribute :>> batteryCapacity = 8000.0;
            attribute :>> outputVoltage = 12.0 [SI::V];
            attribute :>> maxOutputCurrent = 8.0;
            attribute :>> batteryLevel = 100.0;
        }

        part controlPanel : ControlInterface {
            attribute :>> buttonCount = 15;
            attribute :>> touchscreenEnabled = true;
        }

        part thermalMon : ThermalMonitor {
            attribute :>> maxSafeTemperature = 314.15 [SI::K];
            attribute :>> currentTemperature : TemperatureValue;
            attribute :>> coolingActive = false;
        }

        connection transducerToBeamformer connect transducer.echoIn to beamformer.rawSignalIn;
        connection beamformerToSignalProc connect beamformer.beamformedOut to signalProc.dataIn;
        connection signalProcToImageProc connect signalProc.processedOut to imageProc.signalIn;
        connection imageProcToDisplay connect imageProc.imageOut to display.imageIn;
        connection controlToTransducer connect controlPanel.systemControl to transducer.control;
        connection thermalToTransducer connect thermalMon.temperatureSensor to transducer;

        connection powerToTransducer connect powerMgmt.powerOut1 to transducer.powerIn;
        connection powerToBeamformer connect powerMgmt.powerOut2 to beamformer.powerIn;
        connection powerToSignalProc connect powerMgmt.powerOut3 to signalProc.powerIn;
        connection powerToImageProc connect powerMgmt.powerOut4 to imageProc.powerIn;
        connection powerToDisplay connect powerMgmt.powerOut5 to display.powerIn;

        perform action imagingSequence[*] ordered references performUltrasoundImaging;
        exhibit state operationalStates : deviceStateMachine;
    }

    action def InitializeDevice {
        in device : HomeUltrasoundDevice;
        out initialized : Boolean;
    }

    action def ConfigureImaging {
        in mode : ImagingMode;
        in depth : DepthValue;
        in frequency : FrequencyValue;
        out configured : Boolean;
    }

    action def TransmitPulse {
        in frequency : FrequencyValue;
        in power : PowerValue;
        out acousticWave : AcousticSignal;
    }

    action def ReceiveEchoes {
        in echoSignals : AcousticSignal;
        out rawData : RawEchoData;
    }

    action def FormBeam {
        in rawEchoData : RawEchoData;
        in focusDepth : DepthValue;
        out beamformedData : ProcessedImageData;
    }

    action def ProcessSignals {
        in beamData : ProcessedImageData;
        out filteredData : ProcessedImageData;
    }

    action def GenerateImage {
        in processedData : ProcessedImageData;
        in imagingMode : ImagingMode;
        out diagnosticImage : DiagnosticImage;
    }

    action def RenderDisplay {
        in image : DiagnosticImage;
        out displayed : Boolean;
    }

    action def MonitorSafety {
        in temperature : TemperatureValue;
        in exposureTime : Time::DurationValue;
        in acousticPower : PowerValue;
        out safetyLevel : SafetyLevel;
    }

    action performUltrasoundImaging {
        first start;

        then action initialize : InitializeDevice {
            in device : HomeUltrasoundDevice;
            out ready : Boolean;
        }

        then action configure : ConfigureImaging {
            in mode = ImagingMode::bMode;
            in depth = 0.15 [SI::m];
            in frequency = 3500000.0 [SI::Hz];
            out setup : Boolean;
        }

        then merge imagingCycle;

        then action transmit : TransmitPulse {
            in frequency = configure.frequency;
            in power = 5.0 [SI::W];
            out pulse : AcousticSignal;
        }

        then action receive : ReceiveEchoes {
            in echoSignals = transmit.pulse;
            out echoes : RawEchoData;
        }

        then action beamform : FormBeam {
            in rawEchoData = receive.echoes;
            in focusDepth = configure.depth;
            out beamData : ProcessedImageData;
        }

        then action process : ProcessSignals {
            in beamData = beamform.beamData;
            out filtered : ProcessedImageData;
        }

        then action generateImg : GenerateImage {
            in processedData = process.filtered;
            in imagingMode = configure.mode;
            out image : DiagnosticImage;
        }

        then action render : RenderDisplay {
            in image = generateImg.image;
            out shown : Boolean;
        }

        then action monitor : MonitorSafety {
            in temperature : TemperatureValue;
            in exposureTime : Time::DurationValue;
            in acousticPower = transmit.power;
            out safety : SafetyLevel;
        }

        then decide;
            if monitor.safety == SafetyLevel::normal then imagingCycle;
            if monitor.safety == SafetyLevel::warning then imagingCycle;
            if monitor.safety == SafetyLevel::critical then shutdown;

        action shutdown {
            out systemOff : Boolean;
        }

        then done;
    }

    state deviceStateMachine {
        entry; then off;

        state off;
        transition powerOn
            first off
            accept PowerOnEvent
            then standby;

        state standby;
        transition activateImaging
            first standby
            accept StartImagingEvent
            then imaging;

        state imaging {
            entry; then acquiring;

            state acquiring;
            transition toProcessing
                first acquiring
                accept EchoReceivedEvent
                then processing;

            state processing;
            transition toRendering
                first processing
                accept ProcessingCompleteEvent
                then rendering;

            state rendering;
            transition continueAcquiring
                first rendering
                accept NextFrameEvent
                then acquiring;

            transition freezeImage
                first rendering
                accept FreezeEvent
                then frozen;

            state frozen;
            transition resumeImaging
                first frozen
                accept ResumeEvent
                then acquiring;
        }

        transition imagingToStandby
            first imaging
            accept StopImagingEvent
            then standby;

        transition standbyToOff
            first standby
            accept PowerOffEvent
            then off;

        transition emergencyShutdown
            accept EmergencyEvent
            then off;
    }

    requirement <'REQ-HUS-001'> primaryFunction {
        doc /* The Home Ultrasound System shall provide real-time diagnostic ultrasound imaging
             * capability for visualization of internal anatomical structures in a home healthcare
             * setting, enabling non-invasive medical assessment and monitoring. */
        subject device : HomeUltrasoundDevice;
    }

    requirement <'REQ-HUS-002'> imagingDepth {
        doc /* The system shall provide imaging capability to a minimum depth of 200mm
             * to enable visualization of deep anatomical structures. */
        subject transducer :>> HomeUltrasoundDevice::transducer;
        assert constraint {
            transducer.maxPenetrationDepth >= 0.2 [SI::m]
        }
    }

    requirement <'REQ-HUS-003'> imagingFrequency {
        doc /* The transducer shall operate at a frequency between 2 MHz and 10 MHz
             * to balance penetration depth and image resolution. */
        subject transducer :>> HomeUltrasoundDevice::transducer;
        assert constraint {
            transducer.operatingFrequency >= 2000000.0 [SI::Hz] and
            transducer.operatingFrequency <= 10000000.0 [SI::Hz]
        }
    }

    requirement <'REQ-HUS-004'> thermalSafety {
        doc /* The system shall maintain transducer surface temperature below 41 degrees Celsius
             * to ensure patient safety during extended imaging sessions. */
        subject monitor :>> HomeUltrasoundDevice::thermalMon;
        assert constraint {
            monitor.maxSafeTemperature <= 314.15 [SI::K]
        }
    }

    requirement <'REQ-HUS-005'> portability {
        doc /* The system shall have a total mass not exceeding 3.5 kg
             * to ensure portability for home healthcare applications. */
        subject device :>> HomeUltrasoundDevice;
        assert constraint {
            device.totalMass <= 3.5 [SI::kg]
        }
    }

    requirement <'REQ-HUS-006'> batteryOperation {
        doc /* The system shall provide minimum 3 hours of continuous imaging operation
             * on battery power to support extended home healthcare sessions. */
        subject power :>> HomeUltrasoundDevice::powerMgmt;
        assert constraint {
            power.batteryCapacity >= 8000.0
        }
    }

    requirement <'REQ-HUS-007'> frameRate {
        doc /* The system shall maintain a minimum frame rate of 15 frames per second
             * during real-time imaging to provide smooth visualization. */
        subject imageProc :>> HomeUltrasoundDevice::imageProc;
        assert constraint {
            imageProc.frameRate >= 15.0
        }
    }

    part homeUltrasound : HomeUltrasoundDevice {
        attribute :>> systemMode = SystemMode::standby;
        attribute :>> activeImagingMode = ImagingMode::bMode;
        attribute :>> safetyStatus = SafetyLevel::normal;
        attribute :>> totalMass = 3.2 [SI::kg];
        attribute :>> operationalTime = 0.0 [SI::s];
    }

    satisfy primaryFunction by homeUltrasound;
    satisfy imagingDepth by homeUltrasound.transducer;
    satisfy imagingFrequency by homeUltrasound.transducer;
    satisfy thermalSafety by homeUltrasound.thermalMon;
    satisfy portability by homeUltrasound;
    satisfy batteryOperation by homeUltrasound.powerMgmt;
    satisfy frameRate by homeUltrasound.imageProc;
}
