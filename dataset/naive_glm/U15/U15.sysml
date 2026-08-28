package SmartphoneModel {

    import ScalarValues::*;

    package Units {
        value type GHz;
        value type GHz2;
        value type GB;
        value type MB;
        value type mAh;
        value type Percent;
        value type Hz;
        value type ms;
        value type dB;
        value type Cd;
        value type G;
        value type Mbps;
        value type Celsius;
    }
    import Units::*;

    // ============================================================
    // Value Types
    // ============================================================
    value type ClockSpeed :> Real { unit GHz; }
    value type MemorySize :> Real { unit GB; }
    value type Capacity :> Real { unit mAh; }
    value type ChargeLevel :> Real { unit Percent; }
    value type BrightnessLevel :> Real { unit Percent; }
    value type CoreCount :> Integer;
    value type ResolutionWidth :> Integer;
    value type ResolutionHeight :> Integer;
    value type TemperatureValue :> Real { unit Celsius; }
    value type DataRate :> Real { unit Mbps; }
    value type AccelerationValue :> Real { unit G; }
    value type LuminanceValue :> Real { unit Cd; }
    value type RefreshFrequency :> Real { unit Hz; }
    value type DurationValue :> Real { unit ms; }
    value type AudioLevel :> Real { unit dB; }

    // ============================================================
    // Item Types
    // ============================================================
    item def Instruction;
    item def RenderFrame;
    item def MemoryData;
    item def DisplayFrame;
    item def TouchEvent;
    item def SensorData;
    item def MotionData;
    item def NetworkPacket;
    item def AudioStream;
    item def BatteryStatus;
    item def PowerCommand;
    item def ProcessData;
    item def SensorReading;

    // ============================================================
    // Port Definitions
    // ============================================================
    port def ProcessorPort {
        in item instruction : Instruction;
        out item frame : RenderFrame;
    }

    port def MemoryPort {
        in item writeData : MemoryData;
        out item readData : MemoryData;
    }

    port def DisplayPort {
        in item frame : DisplayFrame;
    }

    port def TouchPort {
        out item event : TouchEvent;
    }

    port def SensorDataPort {
        out item reading : SensorReading;
    }

    port def NetworkPort {
        in item rxPacket : NetworkPacket;
        out item txPacket : NetworkPacket;
    }

    port def AudioPort {
        in item input : AudioStream;
        out item output : AudioStream;
    }

    port def PowerPort {
        out item status : BatteryStatus;
        in item command : PowerCommand;
    }

    port def RenderInputPort {
        in item renderFrame : RenderFrame;
        out item displayFrame : DisplayFrame;
    }

    // ============================================================
    // Component Part Definitions
    // ============================================================

    part def ApplicationProcessor {
        attribute clockSpeed : ClockSpeed = 3.0 [GHz];
        attribute numCores : CoreCount = 8;
        attribute currentLoad : BrightnessLevel = 0 [%];

        port execPort : ProcessorPort;
        port memAccess : MemoryPort;

        action def ExecuteInstructions {
            in instruction : Instruction;
            out data : MemoryData;
        }

        action def RunApplication {
            in instruction : Instruction;
            out frame : RenderFrame;
        }

        action execute : ExecuteInstructions;
        action runApp : RunApplication;
    }

    part def GraphicsProcessor {
        attribute clockSpeed : ClockSpeed = 1.0 [GHz];
        attribute numCores : CoreCount = 6;

        port renderInput : RenderInputPort;
        port displayOutput : DisplayPort;

        action def Render {
            in frame : RenderFrame;
            out display : DisplayFrame;
        }

        action render : Render;
    }

    part def SystemMemory {
        attribute size : MemorySize = 12 [GB];
        attribute accessLatency : DurationValue = 15 [ms];

        port writePort : MemoryPort;
        port readPort : MemoryPort;

        action def Access {
            in dataIn : MemoryData;
            out dataOut : MemoryData;
        }

        action access : Access;
    }

    part def DisplayPanel {
        attribute resolutionWidth : ResolutionWidth = 1440;
        attribute resolutionHeight : ResolutionHeight = 3088;
        attribute brightness : BrightnessLevel = 80 [%];
        attribute refreshRate : RefreshFrequency = 120 [Hz];

        port displayInput : DisplayPort;

        action def Show {
            in frame : DisplayFrame;
        }

        action update : Show;
    }

    part def TouchSensor {
        attribute sensitivity : Real = 0.1;
        attribute multiTouch : Boolean = true;

        port touchOutput : TouchPort;

        action def Capture {
            out event : TouchEvent;
        }

        action capture : Capture;
    }

    part def Accelerometer {
        attribute maxRange : AccelerationValue = 16 [G];

        port motionOutput : SensorDataPort;

        action def DetectMotion {
            out data : MotionData;
        }

        action detect : DetectMotion;
    }

    part def SensorHub {
        attribute numSensors : CoreCount = 6;

        port sensorInput : SensorDataPort;
        port aggregatedOutput : SensorDataPort;
        part accelerometer : Accelerometer;

        action def Aggregate {
            in data : SensorReading;
            out aggregated : SensorReading;
        }

        action aggregate : Aggregate;
    }

    part def WirelessModem {
        attribute supported5G : Boolean = true;
        attribute supportedLTE : Boolean = true;
        attribute supportedWiFi : Boolean = true;
        attribute maxDataRate : DataRate = 2000 [Mbps];

        port networkPort : NetworkPort;

        action def Transmit {
            in packet : NetworkPacket;
            out txPacket : NetworkPacket;
        }

        action def Receive {
            in rxPacket : NetworkPacket;
            out packet : NetworkPacket;
        }

        action transmit : Transmit;
        action receive : Receive;
    }

    part def AudioCodec {
        attribute outputLevel : AudioLevel = 80 [dB];

        port audioInterface : AudioPort;

        action def Encode {
            in stream : AudioStream;
            out encoded : AudioStream;
        }

        action def Decode {
            in encoded : AudioStream;
            out stream : AudioStream;
        }

        action encode : Encode;
        action decode : Decode;
    }

    part def BatteryPack {
        attribute capacity : Capacity = 4500 [mAh];
        attribute chargeLevel : ChargeLevel = 100 [%];
        attribute temperature : TemperatureValue = 25 [Celsius];
        attribute isCharging : Boolean = false;

        port powerOutput : PowerPort;

        action def Monitor {
            out status : BatteryStatus;
        }

        action def Discharge {
            in rate : Real;
        }

        action def Charge {
            in rate : Real;
        }

        action monitor : Monitor;
        action discharge : Discharge;
        action charge : Charge;
    }

    // ============================================================
    // Software Layer Definitions
    // ============================================================

    part def AndroidOS {
        attribute version : String = "14.0";
        attribute kernelVersion : String = "6.1";

        port touchInput : TouchPort;
        port sensorInput : SensorDataPort;
        port networkInput : NetworkPort;
        port displayOutput : DisplayPort;
        port batteryInput : PowerPort;
        port powerCommandOutput : PowerPort;
        port appInput : ProcessorPort;
        port appOutput : RenderInputPort;

        action def ScheduleProcesses {
            in process : Instruction;
            out scheduled : Instruction;
        }

        action def ManageResources {
            in data : MemoryData;
            out allocation : MemoryData;
        }

        action def HandleInput {
            in touch : TouchEvent;
            in sensor : SensorReading;
            in packet : NetworkPacket;
            out displayUpdate : DisplayFrame;
        }

        action schedule : ScheduleProcesses;
        action manage : ManageResources;
        action handle : HandleInput;
    }

    part def ApplicationFramework {
        attribute installedApps : CoreCount = 0;

        port appInstruction : ProcessorPort;
        port appRender : RenderInputPort;

        action def RunApp {
            in app : Instruction;
            out frame : RenderFrame;
        }

        action run : RunApp;
    }

    // ============================================================
    // Main Smartphone System
    // ============================================================

    part def Smartphone {
        part cpu : ApplicationProcessor;
        part gpu : GraphicsProcessor;
        part ram : SystemMemory;
        part display : DisplayPanel;
        part touch : TouchSensor;
        part sensorHub : SensorHub;
        part modem : WirelessModem;
        part codec : AudioCodec;
        part battery : BatteryPack;
        part os : AndroidOS;
        part framework : ApplicationFramework;

        // Connections
        connection cpuToRam connect cpu.memAccess to ram.writePort;
        connection ramToCpu connect ram.readPort to cpu.memAccess;
        connection cpuToGpu1 connect cpu.execPort to gpu.renderInput;
        connection gpuToDisplay connect gpu.displayOutput to display.displayInput;
        connection touchToOs connect touch.touchOutput to os.touchInput;
        connection sensorHubToOs connect sensorHub.aggregatedOutput to os.sensorInput;
        connection modemToOs connect modem.networkPort to os.networkInput;
        connection batteryToOs connect battery.powerOutput to os.batteryInput;
        connection osToDisplay connect os.displayOutput to display.displayIn;
        connection frameworkToOs connect framework.appInstruction to os.appInput;
        connection osToFramework connect os.appOutput to framework.appRender;

        // Operational loop behavior
        action def OperatingLoop {
            in batteryStatus : BatteryStatus;
            in touchEvents : TouchEvent;
            in networkPackets : NetworkPacket;
            in sensorReadings : SensorReading;
            out displayUpdates : DisplayFrame;

            then captureTouchInput;
            then processNetwork;
            then readSensors;
            then updateDisplay;
        }

        action captureTouchInput {
            in touchEvents : TouchEvent;
            out capturedEvent : TouchEvent;
        }

        action processNetwork {
            in networkPackets : NetworkPacket;
            out processedPackets : NetworkPacket;
        }

        action readSensors {
            out sensorReadings : SensorReading;
        }

        action updateDisplay {
            in touchEvents : TouchEvent;
            in sensorReadings : SensorReading;
            in networkPackets : NetworkPacket;
            out displayUpdates : DisplayFrame;
        }

        action mainLoop : OperatingLoop;

        // Power Management State Machine
        state def PowerManagementState {
            attribute lowThreshold : ChargeLevel = 15 [%];
            attribute criticalThreshold : ChargeLevel = 5 [%];
            attribute recoveryThreshold : ChargeLevel = 25 [%];

            initial Initial;
            state Normal {
                entry { os.schedule(); }
                do { mainLoop(); }
                exit { /* prepare for power saving */ }
            }
            state PowerSaving {
                entry {
                    cpu.clockSpeed = 1.5 [GHz];
                    display.brightness = 30 [%];
                }
                do { mainLoop(); }
                exit {
                    cpu.clockSpeed = 3.0 [GHz];
                    display.brightness = 80 [%];
                }
            }
            state Shutdown {
                entry { /* controlled shutdown */ }
                do { /* save state, close apps, power off */ }
            }

            transition Initial to Normal;
            transition from Normal to PowerSaving
                when battery.chargeLevel <= lowThreshold;
            transition from PowerSaving to Shutdown
                when battery.chargeLevel <= criticalThreshold;
            transition from PowerSaving to Normal
                when battery.chargeLevel >= recoveryThreshold;
        }

        state powerManagement : PowerManagementState;
    }

    // ============================================================
    // Requirements
    // ============================================================

    requirement def PowerManagementRequirement {
        doc "The system must manage power based on battery charge level, "
            "transitioning through normal, power-saving, and shutdown states.";
        subject smartphone : Smartphone;
        requireNormalOperation : Boolean;
        requirePowerSavingAtLowBattery : Boolean;
        requireControlledShutdownAtCritical : Boolean;
        requireRecoveryFromPowerSaving : Boolean;
    }

    requirement def ConnectivityRequirement {
        doc "The system must support 5G, LTE, and Wi-Fi connectivity "
            "for data transmission and reception.";
        subject modem : WirelessModem;
        requireCellular5G : Boolean;
        requireLTE : Boolean;
        requireWiFi : Boolean;
    }

    requirement def DisplayRequirement {
        doc "The display must provide high-resolution visual feedback "
            "with multi-touch sensitivity.";
        subject display : DisplayPanel;
        requireHighResolution : Boolean;
        requireMultiTouch : Boolean;
        requireBrightnessAdjustment : Boolean;
    }

    requirement def ProcessingRequirement {
        doc "The system must execute instructions with a multi-core CPU "
            "and render graphics with a dedicated GPU, supported by "
            "high-speed system memory.";
        subject smartphone : Smartphone;
        requireMultiCoreCPU : Boolean;
        requireDedicatedGPU : Boolean;
        requireSystemMemory : Boolean;
    }

    requirement def SensorRequirement {
        doc "The system must aggregate sensor data including accelerometer "
            "readings for motion and orientation detection.";
        subject sensorHub : SensorHub;
        requireAccelerometer : Boolean;
        requireDataAggregation : Boolean;
    }

    requirement def AudioRequirement {
        doc "The system must process audio for calls, media playback, "
            "and recording through an audio codec.";
        subject codec : AudioCodec;
        requireEncode : Boolean;
        requireDecode : Boolean;
    }

    requirement powerReq : PowerManagementRequirement {
        requireNormalOperation = true;
        requirePowerSavingAtLowBattery = true;
        requireControlledShutdownAtCritical = true;
        requireRecoveryFromPowerSaving = true;
    }

    requirement connReq : ConnectivityRequirement {
        requireCellular5G = true;
        requireLTE = true;
        requireWiFi = true;
    }

    requirement dispReq : DisplayRequirement {
        requireHighResolution = true;
        requireMultiTouch = true;
        requireBrightnessAdjustment = true;
    }

    requirement procReq : ProcessingRequirement {
        requireMultiCoreCPU = true;
        requireDedicatedGPU = true;
        requireSystemMemory = true;
    }

    requirement sensorReq : SensorRequirement {
        requireAccelerometer = true;
        requireDataAggregation = true;
    }

    requirement audioReq : AudioRequirement {
        requireEncode = true;
        requireDecode = true;
    }

    // ============================================================
    // Verification Actions
    // ============================================================

    action def VerifyPowerManagement {
        in smartphone : Smartphone;
        out result : Boolean;
    }

    action def VerifyConnectivity {
        in modem : WirelessModem;
        out result : Boolean;
    }

    action def VerifyDisplay {
        in display : DisplayPanel;
        in touch : TouchSensor;
        out result : Boolean;
    }

    action def VerifyProcessing {
        in cpu : ApplicationProcessor;
        in gpu : GraphicsProcessor;
        in ram : SystemMemory;
        out result : Boolean;
    }

    action def VerifySensors {
        in sensorHub : SensorHub;
        out result : Boolean;
    }

    action def VerifyAudio {
        in codec : AudioCodec;
        out result : Boolean;
    }

    verification verifyPowerMgmt : VerifyPowerManagement {
        subject smartphone : Smartphone;
    }

    verification verifyConn : VerifyConnectivity {
        subject modem : WirelessModem;
    }

    verification verifyDisp : VerifyDisplay {
        subject display : DisplayPanel;
        subject touch : TouchSensor;
    }

    verification verifyProc : VerifyProcessing {
        subject cpu : ApplicationProcessor;
        subject gpu : GraphicsProcessor;
        subject ram : SystemMemory;
    }

    verification verifySens : VerifySensors {
        subject sensorHub : SensorHub;
    }

    verification verifyAud : VerifyAudio {
        subject codec : AudioCodec;
    }

    // ============================================================
    // Top-Level Instance
    // ============================================================

    part myPhone : Smartphone {
        assert powerReq { subject = myPhone; }
        assert connReq { subject = myPhone.modem; }
        assert dispReq {
            subject display = myPhone.display;
            subject touch = myPhone.touch;
        }
        assert procReq { subject = myPhone; }
        assert sensorReq { subject = myPhone.sensorHub; }
        assert audioReq { subject = myPhone.codec; }
    }
}
