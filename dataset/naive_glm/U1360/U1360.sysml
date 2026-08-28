package SmartphoneModel {
    import ScalarValues::*;

    value type Megapixel { :>> unit = "MP"; }
    value type MilliampereHour { :>> unit = "mAh"; }
    value type Gigabyte { :>> unit = "GB"; }
    value type Gigahertz { :>> unit = "GHz"; }
    value type Inch { :>> unit = "in"; }

    item def TouchEvent {
        attribute x : Real;
        attribute y : Real;
        attribute pressure : Real;
    }
    item def DisplayFrame;
    item def ImageData {
        attribute resolution : Megapixel;
    }
    item def AudioData;
    item def NetworkData;
    item def PowerFlow;

    port def DisplayOut { out frame : DisplayFrame; }
    port def DisplayIn { in frame : DisplayFrame; }
    port def TouchOut { out event : TouchEvent; }
    port def TouchIn { in event : TouchEvent; }
    port def CameraOut { out image : ImageData; }
    port def AudioOut { out audio : AudioData; }
    port def AudioIn { in audio : AudioData; }
    port def DataPort { in inData; out outData; }
    port def PowerPort { out power : PowerFlow; }

    part def PowerButton {
        attribute isPressed : Boolean = false;
    }

    part def ApplicationProcessor {
        attribute cores : Integer = 8;
        attribute clockSpeed : Gigahertz = 3.4 [Gigahertz];
        
        port displayOut : DisplayOut;
        port touchIn : TouchIn;
        port cameraIn : CameraOut;
        port memoryPort : DataPort;
        port modemPort : DataPort;
        port audioOut : AudioOut;
        port powerIn : PowerPort;
        
        action def processTouch {
            in event : TouchEvent;
            out frame : DisplayFrame;
        }
        action def processImage {
            in image : ImageData;
            out storedImage : ImageData;
        }
    }
    
    part def Touchscreen {
        attribute size : Inch = 6.8 [Inch];
        attribute isTouched : Boolean = false;
        port touchOut : TouchOut;
        port displayIn : DisplayIn;
    }
    
    part def ModemChipset {
        port networkPort : DataPort;
        port processorPort : DataPort;
        port powerIn : PowerPort;
    }
    
    part def CameraModule {
        attribute sensorResolution : Megapixel = 200 [Megapixel];
        port imageOut : CameraOut;
        port powerIn : PowerPort;
    }
    
    part def AudioSubsystem {
        port audioIn : AudioIn;
        port powerIn : PowerPort;
    }
    
    part def BatterySystem {
        attribute capacity : MilliampereHour = 5000 [MilliampereHour];
        port powerOut : PowerPort;
    }
    
    part def MemoryAndStorage {
        attribute ram : Gigabyte = 12 [Gigabyte];
        attribute rom : Gigabyte = 256 [Gigabyte];
        port processorPort : DataPort;
        port powerIn : PowerPort;
    }
    
    part def GalaxySmartphone {
        part powerButton : PowerButton;
        part processor : ApplicationProcessor;
        part screen : Touchscreen;
        part modem : ModemChipset;
        part camera : CameraModule;
        part audio : AudioSubsystem;
        part battery : BatterySystem;
        part memory : MemoryAndStorage;
        
        connect processor.displayOut to screen.displayIn;
        connect screen.touchOut to processor.touchIn;
        connect camera.imageOut to processor.cameraIn;
        connect processor.audioOut to audio.audioIn;
        connect processor.memoryPort to memory.processorPort;
        connect processor.modemPort to modem.processorPort;
        
        connect battery.powerOut to processor.powerIn;
        connect battery.powerOut to modem.powerIn;
        connect battery.powerOut to camera.powerIn;
        connect battery.powerOut to audio.powerIn;
        connect battery.powerOut to memory.powerIn;
        
        state def OperatingStates {
            state Off;
            state Booting;
            state Idle;
            state Active {
                parallel {
                    state UserInteraction;
                    state BackgroundProcess;
                }
            }
            transition off_to_booting
                from Off to Booting
                when powerButton.isPressed;
            transition booting_to_idle
                from Booting to Idle
                when processor.cores > 0;
            transition idle_to_active
                from Idle to Active
                when screen.isTouched;
            transition active_to_idle
                from Active to Idle
                when screen.isTouched == false;
        }
        
        action def handleTouchInteraction {
            in touch : TouchEvent;
            out frame : DisplayFrame;
            perform processor.processTouch {
                in event = touch;
                out frame = frame;
            }
        }
        
        action def capturePhoto {
            in image : ImageData;
            out stored : ImageData;
            perform processor.processImage {
                in image = image;
                out storedImage = stored;
            }
        }
    }
    
    requirement def SmartphoneRequirements {
        subject device : GalaxySmartphone;
        
        requirement ProcessorRequirement {
            subject device.processor;
            requirement:: 'The processor shall have 8 cores.' { device.processor.cores == 8 }
        }
        requirement CameraRequirement {
            subject device.camera;
            requirement:: 'The camera shall have a 200MP sensor.' { device.camera.sensorResolution == 200 [Megapixel] }
        }
        requirement BatteryRequirement {
            subject device.battery;
            requirement:: 'The battery shall support all-day use.' { device.battery.capacity >= 4000 [MilliampereHour] }
        }
        requirement MemoryRequirement {
            subject device.memory;
            requirement:: 'The device shall have at least 12GB RAM.' { device.memory.ram >= 12 [Gigabyte] }
        }
    }
}
