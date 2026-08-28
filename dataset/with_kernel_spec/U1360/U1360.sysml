package SamsungGalaxyS24Ultra {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import ISQElectromagnetism::*;

    item def PowerOn;
    item def PowerOff;
    item def UserInteraction;
    item def IdleTimeout;
    item def BootComplete;
    item def ShutterCommand;

    item def ElectricPower;
    item def DisplayFrame;
    item def TouchEvent {
        attribute x : Real;
        attribute y : Real;
        attribute pressure : Real;
    }
    item def DataPacket;
    item def ImageData;
    item def SoundWave;

    port def PowerOutPort { out power : ElectricPower; }
    port def PowerInPort { in power : ElectricPower; }
    port def DisplayOutPort { out displayFrame : DisplayFrame; }
    port def DisplayInPort { in displayFrame : DisplayFrame; }
    port def TouchOutPort { out touch : TouchEvent; }
    port def TouchInPort { in touch : TouchEvent; }
    port def DataOutPort { out data : DataPacket; }
    port def DataInPort { in data : DataPacket; }
    port def ImageOutPort { out image : ImageData; }
    port def ImageInPort { in image : ImageData; }
    port def AudioOutPort { out sound : SoundWave; }
    port def AudioInPort { in sound : SoundWave; }
    port def MemoryBusPort { inout data : DataPacket; }

    action def ProcessTouch {
        in touch : TouchEvent;
        out displayFrame : DisplayFrame;
    }
    action def ProcessImage {
        in image : ImageData;
        out storedImage : DataPacket;
    }

    part def ApplicationProcessor {
        attribute coreCount : Integer = 8;
        port powerIn : PowerInPort;
        port displayOut : DisplayOutPort;
        port touchIn : TouchInPort;
        port dataIn : DataInPort;
        port cameraIn : ImageInPort;
        port audioOut : AudioOutPort;
        port memoryBus : MemoryBusPort;
    }

    part def Touchscreen {
        attribute resolution : String = "3120x1440";
        port displayIn : DisplayInPort;
        port touchOut : TouchOutPort;
    }

    part def ModemChipset {
        attribute bands : String = "5G, 4G, 3G";
        port dataOut : DataOutPort;
    }

    part def CameraModule {
        attribute sensorResolution : Integer = 200;
        port imageOut : ImageOutPort;
    }

    part def AudioSubsystem {
        attribute speakerConfig : String = "Stereo";
        port audioIn : AudioInPort;
    }

    part def BatterySystem {
        attribute capacity : Real = 5000;
        attribute fastCharging : Boolean = true;
        port powerOut : PowerOutPort;
    }

    part def MemoryAndStorage {
        attribute ram : Integer = 12;
        attribute storage : Integer = 512;
        port bus : MemoryBusPort;
    }

    part def Smartphone {
        part processor : ApplicationProcessor;
        part display : Touchscreen;
        part modem : ModemChipset;
        part camera : CameraModule;
        part audio : AudioSubsystem;
        part battery : BatterySystem;
        part memory : MemoryAndStorage;

        connection powerConnection connect battery.powerOut to processor.powerIn;
        connection displayConnection connect processor.displayOut to display.displayIn;
        connection touchConnection connect display.touchOut to processor.touchIn;
        connection modemConnection connect modem.dataOut to processor.dataIn;
        connection cameraConnection connect camera.imageOut to processor.cameraIn;
        connection audioConnection connect processor.audioOut to audio.audioIn;
        connection memoryConnection connect processor.memoryBus to memory.bus;

        state PhoneStates {
            entry; then PoweredOff;
            state PoweredOff;
            transition power_on
                first PoweredOff
                accept PowerOn
                then Booting;
            state Booting;
            transition boot_complete
                first Booting
                accept BootComplete
                then Idle;
            state Idle;
            transition wake_up
                first Idle
                accept UserInteraction
                then Active;
            state Active {
                do action HandleUserInput {
                    action receiveTouch accept touch : TouchEvent via processor.touchIn;
                    action processTouch : ProcessTouch { in touch = receiveTouch.touch; out displayFrame; }
                    action sendFrame send processTouch.displayFrame via processor.displayOut;
                }
                do action RunBackgroundTasks {
                    doc /* Check for updates and sync data */
                }
            }
            transition sleep
                first Active
                accept IdleTimeout
                then Idle;
            transition power_off
                first Idle
                accept PowerOff
                then PoweredOff;
        }

        action CapturePhoto {
            out storedImage : DataPacket;
            first start;
            then action receiveShutter accept shutter : ShutterCommand;
            then action receiveImage accept image : ImageData via processor.cameraIn;
            then action processImage : ProcessImage {
                in image = receiveImage.image;
                out storedImage;
            }
            then action storeImage send processImage.storedImage via processor.memoryBus;
        }
    }

    requirement def PremiumSmartphoneRequirements {
        subject phone : Smartphone;
        requirement ProcessorRequirement {
            doc /* The phone must have an 8-core application processor. */
            constraint { phone.processor.coreCount == 8 }
        }
        requirement CameraRequirement {
            doc /* The camera module must have a 200-megapixel sensor. */
            constraint { phone.camera.sensorResolution == 200 }
        }
        requirement BatteryRequirement {
            doc /* The battery must have a capacity of at least 5000 mAh. */
            constraint { phone.battery.capacity >= 5000 }
        }
        requirement DisplayRequirement {
            doc /* The touchscreen shall have a resolution of at least 3120x1440. */
            constraint { phone.display.resolution == "3120x1440" }
        }
        requirement StorageRequirement {
            doc /* The device shall have at least 12 GB RAM and 512 GB storage. */
            constraint { phone.memory.ram >= 12 }
            constraint { phone.memory.storage >= 512 }
        }
    }
}
