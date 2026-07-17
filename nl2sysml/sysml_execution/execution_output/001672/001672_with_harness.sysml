package MobileDeviceSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def BatteryPercentage :> Real;
    attribute def SignalStrengthValue :> Real;
    attribute def DataRateValue :> Real;
    
    item def UserInput {
        attribute inputType : String;
        attribute timestamp : TimeValue;
    }
    
    item def DisplayContent {
        attribute contentType : String;
        attribute resolution : String;
    }
    
    item def NetworkPacket {
        attribute size : Real;
        attribute priority : Integer;
    }
    
    item def AudioSignal {
        attribute volume : Real;
        attribute frequency : FrequencyValue;
    }
    
    item def SensorReading {
        attribute sensorType : String;
        attribute value : Real;
    }
    
    port def PowerPort {
        out item power : PowerValue;
    }
    
    port def DataPort {
        in item dataIn : NetworkPacket;
        out item dataOut : NetworkPacket;
    }
    
    port def UserInterfacePort {
        in item input : UserInput;
        out item output : DisplayContent;
    }
    
    port def AudioPort {
        in item audioIn : AudioSignal;
        out item audioOut : AudioSignal;
    }
    
    part def Battery {
        attribute capacity : EnergyValue;
        attribute chargeLevel : BatteryPercentage;
        attribute voltage : VoltageValue;
        port powerSupply : PowerPort;
        
        action def SupplyPower {
            in demand : PowerValue;
            out supplied : PowerValue;
        }
        
        action def MonitorCharge {
            out currentLevel : BatteryPercentage;
        }
    }
    
    part def Processor {
        attribute clockSpeed : FrequencyValue;
        attribute coreCount : Integer;
        attribute temperature : TemperatureValue;
        port powerIn : PowerPort;
        port networkInterface : DataPort;
        
        action def ExecuteApplication {
            in appData : NetworkPacket;
            out result : NetworkPacket;
        }
        
        action def ProcessInput {
            in userCommand : UserInput;
            out response : DisplayContent;
        }
    }
    
    part def Display {
        attribute screenSize : LengthValue;
        attribute resolution : String;
        attribute brightness : Real;
        port powerIn : PowerPort;
        port displayInterface : UserInterfacePort;
        
        action def RenderContent {
            in content : DisplayContent;
        }
        
        action def AdjustBrightness {
            in level : Real;
        }
    }
    
    part def WirelessRadio {
        attribute signalStrength : SignalStrengthValue;
        attribute frequency : FrequencyValue;
        attribute dataRate : DataRateValue;
        port powerIn : PowerPort;
        port antennaPort : DataPort;
        
        action def EstablishConnection {
            in networkId : String;
            out connected : Boolean;
        }
        
        action def TransmitData {
            in packet : NetworkPacket;
            out success : Boolean;
        }
        
        action def ReceiveData {
            out packet : NetworkPacket;
        }
    }
    
    part def TouchScreen {
        attribute multitouch : Boolean;
        attribute sensitivity : Real;
        port powerIn : PowerPort;
        port inputInterface : UserInterfacePort;
        
        action def DetectTouch {
            out touchInput : UserInput;
        }
    }
    
    part def Speaker {
        attribute maxVolume : Real;
        attribute impedance : Real;
        port powerIn : PowerPort;
        port audioInterface : AudioPort;
        
        action def PlayAudio {
            in signal : AudioSignal;
        }
    }
    
    part def Microphone {
        attribute sensitivity : Real;
        port powerIn : PowerPort;
        port audioInterface : AudioPort;
        
        action def CaptureAudio {
            out signal : AudioSignal;
        }
    }
    
    part def Camera {
        attribute megapixels : Real;
        attribute aperture : Real;
        port powerIn : PowerPort;
        port dataInterface : DataPort;
        
        action def CaptureImage {
            out imageData : NetworkPacket;
        }
    }
    
    part def SensorModule {
        part accelerometer;
        part gyroscope;
        part proximityDetector;
        part lightSensor;
        port powerIn : PowerPort;
        port sensorInterface : DataPort;
        
        action def ReadSensors {
            out readings : SensorReading;
        }
    }
    
    part def Storage {
        attribute capacity : Real;
        attribute usedSpace : Real;
        port powerIn : PowerPort;
        port dataInterface : DataPort;
        
        action def WriteData {
            in data : NetworkPacket;
            out success : Boolean;
        }
        
        action def ReadData {
            in address : Integer;
            out data : NetworkPacket;
        }
    }
    
    action def InitializeSystem {
        out systemReady : Boolean;
    }
    
    action def HandleUserInteraction {
        in userInput : UserInput;
        out displayUpdate : DisplayContent;
    }
    
    action def ManageNetworkCommunication {
        in outgoingData : NetworkPacket;
        out incomingData : NetworkPacket;
        out transmitSuccess : Boolean;
    }
    
    action def MonitorPowerConsumption {
        out batteryStatus : BatteryPercentage;
        out powerMode : String;
    }
    
    action def ProcessMultimedia {
        in mediaType : String;
        out processedData : NetworkPacket;
    }
    
    action def MobileDeviceMainOperation {
        first start;
        then action init : InitializeSystem {
            out systemReady;
        }
        then merge mainLoop;
        
        action monitorPower : MonitorPowerConsumption {
            out batteryStatus;
            out powerMode;
        }
        
        then decide;
            if monitorPower.batteryStatus < 5.0 then enterLowPowerMode;
            if monitorPower.batteryStatus >= 5.0 then normalOperation;
        
        action enterLowPowerMode;
        then mainLoop;
        
        action normalOperation {
            first merge opStart;
            then decide;
                if hasUserInput then handleUser;
                if hasNetworkData then handleNetwork;
                if captureMedia then handleMedia;
            
            action handleUser : HandleUserInteraction {
                in userInput;
                out displayUpdate;
            }
            then opStart;
            
            action handleNetwork : ManageNetworkCommunication {
                in outgoingData;
                out incomingData;
                out transmitSuccess;
            }
            then opStart;
            
            action handleMedia : ProcessMultimedia {
                in mediaType;
                out processedData;
            }
            then opStart;
        }
        then mainLoop;
    }
    
    state def MobileDeviceState {
        entry; then off;
        
        state off;
        transition off_to_booting
            first off
            accept powerButton : UserInput
            then booting;
        
        state booting {
            entry; then loadingOS;
            state loadingOS;
            state initializingHardware;
            
            transition loading_to_initializing
                first loadingOS
                then initializingHardware;
        }
        
        transition booting_to_idle
            first booting
            if bootComplete
            then idle;
        
        state idle;
        transition idle_to_active
            first idle
            accept userInteraction : UserInput
            then active;
        
        state active {
            entry; then processing;
            
            state processing {
                entry; then ready;
                state ready;
                state executing;
                
                transition ready_to_executing
                    first ready
                    if taskAvailable
                    then executing;
                
                transition executing_to_ready
                    first executing
                    if taskComplete
                    then ready;
            }
            
            state communicating;
            state displayingContent;
            
            transition processing_to_communicating
                first processing
                if networkRequest
                then communicating;
            
            transition communicating_to_displaying
                first communicating
                if dataReceived
                then displayingContent;
            
            transition displaying_to_processing
                first displayingContent
                then processing;
        }
        
        transition active_to_standby
            first active
            if inactivityTimeout
            then standby;
        
        state standby;
        transition standby_to_active
            first standby
            accept wakeEvent : UserInput
            then active;
        
        transition standby_to_idle
            first standby
            if batteryLow
            then idle;
        
        transition any_to_off
            first idle
            accept shutdownCommand : UserInput
            then off;
    }
    
    part def MobileDevice;
    
    part mobileDevice : MobileDevice {
        attribute deviceId : String;
        attribute osVersion : String;
        attribute manufacturer : String;
        
        part battery : Battery {
            :>> capacity = 15.0[Wh];
            :>> chargeLevel = 100.0;
            :>> voltage = 3.8[V];
        }
        
        part cpu : Processor {
            :>> clockSpeed = 2.5[GHz];
            :>> coreCount = 8;
            :>> temperature = 318.15[K];
        }
        
        part screen : Display {
            :>> screenSize = 6.5[cm];
            :>> resolution = "2400x1080";
            :>> brightness = 500.0;
        }
        
        part radio : WirelessRadio {
            :>> signalStrength = -70.0;
            :>> frequency = 2.4[GHz];
            :>> dataRate = 100.0;
        }
        
        part touchInput : TouchScreen {
            :>> multitouch = true;
            :>> sensitivity = 0.95;
        }
        
        part speaker : Speaker {
            :>> maxVolume = 85.0;
            :>> impedance = 8.0;
        }
        
        part microphone : Microphone {
            :>> sensitivity = 0.9;
        }
        
        part camera : Camera {
            :>> megapixels = 48.0;
            :>> aperture = 1.8;
        }
        
        part sensors : SensorModule;
        
        part storage : Storage {
            :>> capacity = 128.0;
            :>> usedSpace = 64.0;
        }
        
        connection powerToCPU connect battery.powerSupply to cpu.powerIn;
        connection powerToDisplay connect battery.powerSupply to screen.powerIn;
        connection powerToRadio connect battery.powerSupply to radio.powerIn;
        connection powerToTouch connect battery.powerSupply to touchInput.powerIn;
        connection powerToSpeaker connect battery.powerSupply to speaker.powerIn;
        connection powerToMic connect battery.powerSupply to microphone.powerIn;
        connection powerToCamera connect battery.powerSupply to camera.powerIn;
        connection powerToSensors connect battery.powerSupply to sensors.powerIn;
        connection powerToStorage connect battery.powerSupply to storage.powerIn;
        
        connection cpuToRadio connect cpu.networkInterface to radio.antennaPort;
        connection touchToDisplay connect touchInput.inputInterface to screen.displayInterface;
        connection cpuToStorage connect cpu.networkInterface to storage.dataInterface;
        connection cameraToStorage connect camera.dataInterface to storage.dataInterface;
        connection sensorsToProcessor connect sensors.sensorInterface to cpu.networkInterface;
        
        perform action mainOperation : MobileDeviceMainOperation;
        exhibit state deviceState : MobileDeviceState;
    }
    
    requirement def <'REQ-001'> PrimaryFunctionRequirement {
        doc /* The mobile device shall provide wireless communication capabilities 
                enabling voice calls, data transmission, and internet connectivity. */
        
        subject device : MobileDevice;
        
        require constraint {
            device.radio.signalStrength >= -100.0
        }
    }
    
    requirement def <'REQ-002'> UserInteractionRequirement {
        doc /* The mobile device shall provide intuitive user interaction through 
                touchscreen input and visual display output. */
        
        subject device : MobileDevice;
        
        require constraint {
            device.touchInput.sensitivity >= 0.85 and
            device.screen.brightness >= 300.0
        }
    }
    
    requirement def <'REQ-003'> PowerManagementRequirement {
        doc /* The mobile device shall operate for minimum 8 hours under normal usage 
                on a single battery charge. */
        
        subject device : MobileDevice;
        
        require constraint {
            device.battery.chargeLevel >= 10.0
        }
    }
    
    requirement def <'REQ-004'> MultimediaRequirement {
        doc /* The mobile device shall capture, store, and playback multimedia content 
                including photos, videos, and audio. */
        
        subject device : MobileDevice;
        
        require constraint {
            device.camera.megapixels >= 12.0 and
            device.storage.capacity >= 64.0
        }
    }
    
    requirement def <'REQ-005'> ProcessingRequirement {
        doc /* The mobile device shall provide sufficient processing power to run 
                multiple applications concurrently with responsive performance. */
        
        subject device : MobileDevice;
        
        require constraint {
            device.cpu.coreCount >= 4 and
            device.cpu.clockSpeed >= 1.5[GHz]
        }
    }
    
    requirement <'REQ-SYSTEM'> mobileDeviceSystemRequirement {
        doc /* The mobile device system shall integrate communication, computation, 
                user interaction, and multimedia capabilities into a portable form factor, 
                enabling users to communicate, access information, capture media, and run 
                applications while managing power consumption efficiently. */
        
        subject mobileDevice;
        
        assume constraint devicePowered {
            mobileDevice.battery.chargeLevel > 0.0
        }
        
        require primaryFunction : PrimaryFunctionRequirement;
        require userInteraction : UserInteractionRequirement;
        require powerManagement : PowerManagementRequirement;
        require multimedia : MultimediaRequirement;
        require processing : ProcessingRequirement;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import MobileDeviceSystem::*;

    part mobileDevice : Battery {
        exhibit state sm : MobileDeviceState;
    }
}
