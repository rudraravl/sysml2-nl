package MobileDeviceModel {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    value def Voltage :> Real { unit 'V'; }
    value def Current :> Real { unit 'A'; }
    value def Power :> Real { unit 'W'; }
    value def Energy :> Real { unit 'J'; }
    value def ChargeLevel :> Real { unit '%'; }
    value def Frequency :> Real { unit 'GHz'; }
    value def DataRate :> Real { unit 'Mb/s'; }
    value def SignalStrength :> Real { unit 'dBm'; }
    value def Resolution :> Integer { unit 'px'; }
    value def PixelDensity :> Real { unit 'ppi'; }
    value def StorageCapacity :> Real { unit 'GB'; }
    value def Temperature :> Real { unit 'degC'; }
    value def Luminance :> Real { unit 'cd/m^2'; }
    value def Acceleration :> Real { unit 'm/s^2'; }
    value def AngularVelocity :> Real { unit 'rad/s'; }
    value def Distance :> Real { unit 'm'; }
    value def Duration :> Real { unit 's'; }

    // ===== Item Types =====
    item def ElectricPower {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    item def TouchEvent {
        attribute x : Real;
        attribute y : Real;
        attribute pressure : Real;
    }

    item def DisplayFrame {
        attribute width : Resolution;
        attribute height : Resolution;
        attribute pixelData : String;
    }

    item def AudioSignal {
        attribute amplitude : Real;
        attribute frequency : Real;
    }

    item def ImageData {
        attribute width : Resolution;
        attribute height : Resolution;
        attribute format : String;
    }

    item def VideoData {
        attribute duration : Duration;
        attribute resolution : String;
        attribute frameRate : Real;
    }

    item def NetworkPacket {
        attribute payload : String;
        attribute sourceAddr : String;
        attribute destAddr : String;
    }

    item def SensorData {
        attribute timestamp : Duration;
    }

    item def AccelerometerData :> SensorData {
        attribute accelX : Acceleration;
        attribute accelY : Acceleration;
        attribute accelZ : Acceleration;
    }

    item def GyroscopeData :> SensorData {
        attribute gyroX : AngularVelocity;
        attribute gyroY : AngularVelocity;
        attribute gyroZ : AngularVelocity;
    }

    item def ProximityData :> SensorData {
        attribute distance : Distance;
    }

    item def AmbientLightData :> SensorData {
        attribute luminance : Luminance;
    }

    item def FileData {
        attribute name : String;
        attribute size : StorageCapacity;
        attribute content : String;
    }

    // ===== Port Definitions =====
    port def PowerPort {
        attribute voltage : Voltage;
        in power : ElectricPower;
    }

    port def PowerOutPort :> PowerPort {
        out power : ElectricPower;
    }

    port def PowerInPort :> PowerPort {
        in power : ElectricPower;
    }

    port def DisplayPort {
        out frame : DisplayFrame;
    }

    port def TouchPort {
        in touch : TouchEvent;
    }

    port def AudioOutPort {
        out audio : AudioSignal;
    }

    port def AudioInPort {
        in audio : AudioSignal;
    }

    port def DataPort {
        in rx : NetworkPacket;
        out tx : NetworkPacket;
    }

    port def CameraPort {
        out image : ImageData;
        out video : VideoData;
    }

    port def StoragePort {
        in writeData : FileData;
        out readData : FileData;
    }

    port def SensorPort {
        out data : SensorData;
    }

    port def ControlPort {
        in command : String;
        out status : String;
    }

    // ===== Parts =====
    part def Battery {
        attribute capacity : Energy = 50000;
        attribute currentCharge : ChargeLevel = 100;
        attribute nominalVoltage : Voltage = 3.7;
        attribute maxCurrent : Current = 3.0;
        attribute criticalThreshold : ChargeLevel = 15;
        
        port powerOut : PowerOutPort;
        
        attribute isCharging : Boolean = false;
        
        action def discharge {
            in duration : Duration;
        }
        
        action def charge {
            in duration : Duration;
        }
        
        state batteryBehavior {
            entry; then normal;
            
            state normal;
            state low {
                entry { currentCharge < criticalThreshold; }
            }
            state critical {
                entry { currentCharge < 5; }
            }
            state charging;
            
            transition normal to low
                when currentCharge <= criticalThreshold;
            transition low to critical
                when currentCharge <= 5;
            transition low to normal
                when currentCharge > criticalThreshold;
            transition critical to low
                when currentCharge > 5;
            transition normal to charging
                when isCharging;
            transition charging to normal
                when !isCharging;
        }
    }

    part def Processor {
        attribute numCores : Integer = 8;
        attribute clockSpeed : Frequency = 2.8;
        attribute powerConsumption : Power = 5.0;
        attribute temperature : Temperature = 35;
        
        port powerIn : PowerInPort;
        port displayOut : DisplayPort;
        port touchIn : TouchPort;
        port audioOut : AudioOutPort;
        port audioIn : AudioInPort;
        port dataOut : DataPort;
        port cameraIn : CameraPort;
        port storageCtrl : StoragePort;
        port sensorIn : SensorPort;
        port controlOut : ControlPort;
        
        action def executeApplication {
            in appName : String;
            in inputData : String;
            out outputData : String;
        }
        
        action def manageHardware {
            in componentId : String;
            in command : String;
        }
        
        action def processTouch {
            in event : TouchEvent;
            out response : DisplayFrame;
        }
        
        action def processAudio {
            in input : AudioSignal;
            out output : AudioSignal;
        }
        
        action def handleNetworkData {
            in packet : NetworkPacket;
            out response : NetworkPacket;
        }
        
        action def processSensorData {
            in data : SensorData;
            out action : String;
        }
    }

    part def Display {
        attribute width : Resolution = 1080;
        attribute height : Resolution = 2400;
        attribute pixelDensity : PixelDensity = 400;
        attribute maxBrightness : Luminance = 800;
        attribute currentBrightness : Luminance = 400;
        attribute isOn : Boolean = false;
        
        port powerIn : PowerInPort;
        port displayIn : DisplayPort;
        port touchOut : TouchPort;
        
        action def renderFrame {
            in frame : DisplayFrame;
        }
        
        action def detectTouch {
            out event : TouchEvent;
        }
        
        action def adjustBrightness {
            in level : Luminance;
        }
    }

    part def Speaker {
        attribute maxVolume : Real = 1.0;
        attribute currentVolume : Real = 0.5;
        attribute impedance : Real = 8.0;
        
        port powerIn : PowerInPort;
        port audioIn : AudioOutPort;
        
        action def playSound {
            in signal : AudioSignal;
        }
        
        action def setVolume {
            in level : Real;
        }
    }

    part def Microphone {
        attribute sensitivity : Real = -40;
        attribute isMuted : Boolean = false;
        
        port powerIn : PowerInPort;
        port audioOut : AudioInPort;
        
        action def captureAudio {
            out signal : AudioSignal;
        }
        
        action def toggleMute;
    }

    part def WirelessRadio {
        attribute supportedBands : String = "5G/4G/WiFi/Bluetooth";
        attribute signalStrength : SignalStrength = -70;
        attribute dataRate : DataRate = 100;
        attribute isActive : Boolean = false;
        
        port powerIn : PowerInPort;
        port dataPort : DataPort;
        
        action def connect {
            in networkId : String;
        }
        
        action def disconnect;
        
        action def transmit {
            in packet : NetworkPacket;
        }
        
        action def receive {
            out packet : NetworkPacket;
        }
        
        action def measureSignal {
            out strength : SignalStrength;
        }
    }

    part def Camera {
        attribute resolution : Resolution = 1080;
        attribute aperture : Real = 1.8;
        attribute hasFlash : Boolean = true;
        attribute isRecording : Boolean = false;
        
        port powerIn : PowerInPort;
        port imageOut : CameraPort;
        
        action def capturePhoto {
            out image : ImageData;
        }
        
        action def recordVideo {
            in duration : Duration;
            out video : VideoData;
        }
        
        action def toggleFlash;
    }

    part def Storage {
        attribute capacity : StorageCapacity = 256;
        attribute usedSpace : StorageCapacity = 64;
        attribute type : String = "NVMe SSD";
        
        port powerIn : PowerInPort;
        port storagePort : StoragePort;
        
        action def read {
            in fileName : String;
            out data : FileData;
        }
        
        action def write {
            in data : FileData;
        }
        
        action def delete {
            in fileName : String;
        }
        
        attribute availableSpace : StorageCapacity = capacity - usedSpace;
    }

    part def Accelerometer {
        attribute range : Acceleration = 20;
        attribute sensitivity : Real = 0.001;
        
        port powerIn : PowerInPort;
        port sensorOut : SensorPort;
        
        action def measure {
            out data : AccelerometerData;
        }
    }

    part def Gyroscope {
        attribute range : AngularVelocity = 2000;
        attribute sensitivity : Real = 0.01;
        
        port powerIn : PowerInPort;
        port sensorOut : SensorPort;
        
        action def measure {
            out data : GyroscopeData;
        }
    }

    part def ProximitySensor {
        attribute maxRange : Distance = 0.05;
        attribute threshold : Distance = 0.01;
        
        port powerIn : PowerInPort;
        port sensorOut : SensorPort;
        
        action def detect {
            out data : ProximityData;
        }
    }

    part def LightSensor {
        attribute maxLuminance : Luminance = 1000;
        attribute sensitivity : Real = 1.0;
        
        port powerIn : PowerInPort;
        port sensorOut : SensorPort;
        
        action def measure {
            out data : AmbientLightData;
        }
    }

    // ===== Main Mobile Device =====
    part def MobileDevice {
        attribute deviceType : String = "smartphone";
        attribute manufacturer : String = "Generic";
        attribute model : String = "X-1000";
        attribute osVersion : String = "MobileOS 14.0";
        
        part battery : Battery;
        part processor : Processor;
        part display : Display;
        part speaker : Speaker;
        part microphone : Microphone;
        part radio : WirelessRadio;
        part camera : Camera;
        part storage : Storage;
        part accelerometer : Accelerometer;
        part gyroscope : Gyroscope;
        part proximitySensor : ProximitySensor;
        part lightSensor : LightSensor;
        
        // Power distribution connections
        connection battery.powerOut to processor.powerIn;
        connection battery.powerOut to display.powerIn;
        connection battery.powerOut to speaker.powerIn;
        connection battery.powerOut to microphone.powerIn;
        connection battery.powerOut to radio.powerIn;
        connection battery.powerOut to camera.powerIn;
        connection battery.powerOut to storage.powerIn;
        connection battery.powerOut to accelerometer.powerIn;
        connection battery.powerOut to gyroscope.powerIn;
        connection battery.powerOut to proximitySensor.powerIn;
        connection battery.powerOut to lightSensor.powerIn;
        
        // Display and touch connections
        connection processor.displayOut to display.displayIn;
        connection display.touchOut to processor.touchIn;
        
        // Audio connections
        connection processor.audioOut to speaker.audioIn;
        connection microphone.audioOut to processor.audioIn;
        
        // Network connections
        connection processor.dataOut to radio.dataPort;
        
        // Camera connections
        connection camera.imageOut to processor.cameraIn;
        
        // Storage connections
        connection processor.storageCtrl to storage.storagePort;
        
        // Sensor connections
        connection accelerometer.sensorOut to processor.sensorIn;
        connection gyroscope.sensorOut to processor.sensorIn;
        connection proximitySensor.sensorOut to processor.sensorIn;
        connection lightSensor.sensorOut to processor.sensorIn;
        
        // Device state machine
        state deviceOperation {
            entry; then off;
            
            state off {
                entry { /* device powered off */ }
            }
            
            state booting {
                entry { /* loading operating system */ }
                do { processor.executeApplication("bootloader", "init", "kernel"); }
            }
            
            state idle {
                entry { /* low activity, screen dimmed */ }
            }
            
            state standby {
                entry { /* power-saving mode, screen off */ }
            }
            
            state active {
                entry { /* user interacting with device */ }
                do { processor.processTouch; }
            }
            
            state lowPowerMode {
                entry { /* critical battery conservation */ }
                do { display.adjustBrightness(50); }
            }
            
            transition off to booting
                when battery.currentCharge > 0
                accept PowerOn;
            
            transition booting to idle
                when booting.complete;
            
            transition idle to active
                accept UserInteraction;
            
            transition active to idle
                when !userInteracting;
            
            transition idle to standby
                when idleDuration > 30;
            
            transition standby to idle
                accept WakeEvent;
            
            transition idle to active
                accept WakeEvent;
            
            transition active to standby
                when idleDuration > 60;
            
            transition active to lowPowerMode
                when battery.currentCharge <= battery.criticalThreshold;
            
            transition idle to lowPowerMode
                when battery.currentCharge <= battery.criticalThreshold;
            
            transition standby to lowPowerMode
                when battery.currentCharge <= battery.criticalThreshold;
            
            transition lowPowerMode to idle
                when battery.currentCharge > battery.criticalThreshold;
            
            transition active to off
                accept PowerOff;
            
            transition idle to off
                accept PowerOff;
            
            transition standby to off
                accept PowerOff;
        }
        
        // Main operational action
        action def operateDevice {
            // Monitor battery continuously
            action monitorBattery {
                loop {
                    action checkLevel {
                        out level : ChargeLevel = battery.currentCharge;
                    }
                    if (battery.currentCharge <= battery.criticalThreshold) {
                        action enterLowPower;
                    }
                }
            }
            
            // Process user interactions
            action handleUserInput {
                action receiveTouch {
                    in event : TouchEvent;
                }
                action updateDisplay {
                    out frame : DisplayFrame;
                }
            }
            
            // Manage connectivity
            action manageConnectivity {
                action checkSignal {
                    out strength : SignalStrength = radio.signalStrength;
                }
                action transferData {
                    in packet : NetworkPacket;
                }
            }
            
            // Gather sensor data
            action gatherSensorData {
                action readAccelerometer;
                action readGyroscope;
                action readProximity;
                action readLight;
            }
        }
    }

    // ===== Requirements =====
    requirement def PowerRequirement {
        subject device : MobileDevice;
        requirement {
            /* The device shall be powered by a rechargeable battery with a minimum capacity of 40000 J. */
            device.battery.capacity >= 40000;
        }
        requirement {
            /* The device shall supply power to all internal components including processor, display, and radios. */
        }
        requirement {
            /* The device shall enter low-power mode when battery charge falls below 15%. */
        }
    }

    requirement def ProcessingRequirement {
        subject device : MobileDevice;
        requirement {
            /* The device shall include a multi-core processor with at least 4 cores. */
            device.processor.numCores >= 4;
        }
        requirement {
            /* The processor shall execute applications and manage all hardware components. */
        }
    }

    requirement def DisplayRequirement {
        subject device : MobileDevice;
        requirement {
            /* The device shall include a high-resolution display with minimum resolution 1080x1920. */
            device.display.width >= 1080;
            device.display.height >= 1920;
        }
        requirement {
            /* The display shall support multi-touch input. */
        }
        requirement {
            /* The display brightness shall be automatically adjustable based on ambient light. */
        }
    }

    requirement def AudioRequirement {
        subject device : MobileDevice;
        requirement {
            /* The device shall include a built-in speaker for audio output. */
        }
        requirement {
            /* The device shall include a microphone for audio capture. */
        }
    }

    requirement def ConnectivityRequirement {
        subject device : MobileDevice;
        requirement {
            /* The device shall include a wireless radio for network connectivity. */
        }
        requirement {
            /* The radio performance shall be characterized by signal strength and data rate. */
        }
        requirement {
            /* The device shall support internet access, data transfer, and communication. */
        }
    }

    requirement def CameraRequirement {
        subject device : MobileDevice;
        requirement {
            /* The device shall include a high-resolution camera for capturing photos and videos. */
        }
        requirement {
            /* Captured media shall be stored locally on internal storage. */
        }
    }

    requirement def StorageRequirement {
        subject device : MobileDevice;
        requirement {
            /* The device shall include internal storage with minimum capacity of 64 GB. */
            device.storage.capacity >= 64;
        }
        requirement {
            /* Storage shall hold the operating system, applications, and user data. */
        }
    }

    requirement def SensorRequirement {
        subject device : MobileDevice;
        requirement {
            /* The device shall include an accelerometer for motion tracking. */
        }
        requirement {
            /* The device shall include a gyroscope for orientation tracking. */
        }
        requirement {
            /* The device shall include a proximity detector. */
        }
        requirement {
            /* The device shall include a light sensor for automatic brightness adjustment. */
        }
        requirement {
            /* Sensors shall enable context-aware features such as screen rotation. */
        }
    }

    requirement def OperationalStateRequirement {
        subject device : MobileDevice;
        requirement {
            /* The device shall support off, booting, idle, standby, and active operational states. */
        }
        requirement {
            /* The device shall monitor battery level continuously. */
        }
        requirement {
            /* The device shall enter low-power mode when charge is critically low. */
        }
    }

    requirement def MobileDeviceRequirement {
        subject device : MobileDevice;
        satisfy powerReq : PowerRequirement;
        satisfy processingReq : ProcessingRequirement;
        satisfy displayReq : DisplayRequirement;
        satisfy audioReq : AudioRequirement;
        satisfy connectivityReq : ConnectivityRequirement;
        satisfy cameraReq : CameraRequirement;
        satisfy storageReq : StorageRequirement;
        satisfy sensorReq : SensorRequirement;
        satisfy operationalReq : OperationalStateRequirement;
    }

}
