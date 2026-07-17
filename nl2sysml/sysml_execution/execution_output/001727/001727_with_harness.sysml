package 'Samsung Galaxy Smartphone System' {
    private import ScalarValues::*;
    private import ISQ::*;
    
    attribute def ScreenResolution {
        attribute width : Integer;
        attribute height : Integer;
    }
    
    attribute def BatteryLevel {
        attribute percentage : Real;
        attribute voltage : ISQ::VoltageValue;
    }
    
    item def TouchInput {
        attribute xCoordinate : Integer;
        attribute yCoordinate : Integer;
        attribute pressure : Real;
    }
    
    item def DisplayFrame {
        attribute resolution : ScreenResolution;
        attribute brightness : Real;
        attribute refreshRate : Real;
    }
    
    item def AudioOutput {
        attribute volume : Real;
        attribute frequency : ISQ::FrequencyValue;
        attribute channels : Integer;
    }
    
    item def NetworkData {
        attribute dataRate : ISQ::InformationFlowRateValue;
        attribute signalStrength : Real;
        attribute protocol : String;
    }
    
    item def CameraImage {
        attribute resolution : ScreenResolution;
        attribute colorDepth : Integer;
        attribute timestamp : Real;
    }
    
    item def PowerCommand {
        attribute targetVoltage : ISQ::VoltageValue;
        attribute currentLimit : ISQ::ElectricCurrentValue;
    }
    
    port def TouchInputPort {
        in item touchEvent : TouchInput;
    }
    
    port def DisplayPort {
        out item frameData : DisplayFrame;
    }
    
    port def AudioPort {
        out item audioSignal : AudioOutput;
    }
    
    port def NetworkPort {
        in item dataIn : NetworkData;
        out item dataOut : NetworkData;
    }
    
    port def CameraPort {
        out item imageData : CameraImage;
    }
    
    port def PowerPort {
        in item powerCmd : PowerCommand;
        out attribute powerStatus : BatteryLevel;
    }
    
    part def TouchScreen {
        attribute screenSize : ISQ::LengthValue;
        attribute maxResolution : ScreenResolution;
        port touchPort : TouchInputPort;
        port displayPort : DisplayPort;
        
        action def RenderFrame {
            in frameInput : DisplayFrame;
            out displayActive : Boolean;
        }
        
        action def DetectTouch {
            out touchData : TouchInput;
        }
    }
    
    part def ApplicationProcessor {
        attribute clockSpeed : ISQ::FrequencyValue;
        attribute coreCount : Integer;
        
        action def ProcessUserInput {
            in touchData : TouchInput;
            out uiCommand : String;
        }
        
        action def RenderGraphics {
            in graphicsData : String;
            out displayFrame : DisplayFrame;
        }
        
        action def ManageApplications {
            in appRequest : String;
            out appResponse : String;
        }
    }
    
    part def CameraModule {
        attribute megapixels : Real;
        attribute aperture : Real;
        port cameraPort : CameraPort;
        
        action def CaptureImage {
            in exposureTime : ISQ::TimeValue;
            in isoSensitivity : Real;
            out imageData : CameraImage;
        }
        
        action def ProcessImage {
            in rawImage : CameraImage;
            out processedImage : CameraImage;
        }
    }
    
    part def ModemChipset {
        attribute supportedBands : Integer;
        attribute maxDataRate : ISQ::InformationFlowRateValue;
        port networkPort : NetworkPort;
        
        action def TransmitData {
            in dataPacket : NetworkData;
            out transmissionStatus : Boolean;
        }
        
        action def ReceiveData {
            out dataPacket : NetworkData;
        }
        
        action def ManageConnection {
            in signalQuality : Real;
            out connectionStatus : String;
        }
    }
    
    part def AudioSubsystem {
        attribute speakerCount : Integer;
        attribute maxVolume : Real;
        port audioPort : AudioPort;
        
        action def PlayAudio {
            in audioData : AudioOutput;
            in volumeLevel : Real;
            out audioPlaying : Boolean;
        }
        
        action def ProcessAudio {
            in rawAudio : String;
            out processedAudio : AudioOutput;
        }
    }
    
    part def BatterySystem {
        attribute capacity : ISQ::EnergyValue;
        attribute currentCharge : BatteryLevel;
        attribute chargingRate : ISQ::PowerValue;
        port powerPort : PowerPort;
        
        action def SupplyPower {
            in powerDemand : ISQ::PowerValue;
            out powerDelivered : ISQ::PowerValue;
        }
        
        action def ChargeBattery {
            in chargingPower : ISQ::PowerValue;
            out chargeLevel : Real;
        }
        
        action def MonitorBattery {
            out batteryStatus : BatteryLevel;
        }
    }
    
    part def MemoryStorage {
        attribute ramCapacity : ISQ::InformationCapacityValue;
        attribute storageCapacity : ISQ::InformationCapacityValue;
        
        action def ReadData {
            in address : Integer;
            out data : String;
        }
        
        action def WriteData {
            in address : Integer;
            in data : String;
            out writeSuccess : Boolean;
        }
    }
    
    part def GalaxySmartphone {
        attribute powerConsumption : Real;
        attribute modelNumber : String;
        attribute serialNumber : String;
        
        part screen : TouchScreen {
            attribute :>> screenSize = 6.8;
            attribute :>> maxResolution = ScreenResolution {
                width = 3088;
                height = 1440;
            }
        }
        
        part processor : ApplicationProcessor {
            attribute :>> clockSpeed = 3.36;
            attribute :>> coreCount = 8;
        }
        
        part camera : CameraModule {
            attribute :>> megapixels = 200.0;
            attribute :>> aperture = 1.7;
        }
        
        part modem : ModemChipset {
            attribute :>> supportedBands = 28;
            attribute :>> maxDataRate = 10.0;
        }
        
        part audio : AudioSubsystem {
            attribute :>> speakerCount = 2;
            attribute :>> maxVolume = 100.0;
        }
        
        part battery : BatterySystem {
            attribute :>> capacity = 5000.0;
            attribute :>> chargingRate = 45.0;
        }
        
        part memory : MemoryStorage {
            attribute :>> ramCapacity = 12.0;
            attribute :>> storageCapacity = 512.0;
        }
        
        perform action operateSmartphone {
            first start;
            then merge awaitInput;
            
            action awaitInput {
                out inputType : String;
            }
            
            then decide;
                if awaitInput.inputType == "touch" then handleTouch;
                if awaitInput.inputType == "camera" then handleCamera;
                if awaitInput.inputType == "network" then handleNetwork;
                if awaitInput.inputType == "audio" then handleAudio;
            
            action handleTouch {
                perform action detectTouch : screen.DetectTouch;
                then perform action processInput : processor.ProcessUserInput;
                then perform action renderUI : processor.RenderGraphics;
                then perform action displayFrame : screen.RenderFrame;
            }
            then awaitInput;
            
            action handleCamera {
                perform action captureImage : camera.CaptureImage;
                then perform action processImage : camera.ProcessImage;
                then perform action storeImage : memory.WriteData;
            }
            then awaitInput;
            
            action handleNetwork {
                perform action receiveData : modem.ReceiveData;
                then perform action processData : processor.ManageApplications;
                then perform action transmitResponse : modem.TransmitData;
            }
            then awaitInput;
            
            action handleAudio {
                perform action processAudio : audio.ProcessAudio;
                then perform action playAudio : audio.PlayAudio;
            }
            then awaitInput;
        }
        
        exhibit state phoneStates : SmartphoneOperatingStates;
    }
    
    state def SmartphoneOperatingStates {
        entry; then powerOff;
        
        state powerOff;
        
        accept at powerOff
        then booting;
        
        state booting;
        then idle;
        
        state idle;
        
        accept at idle
        then active;
        
        state active {
            state userInteraction parallel state backgroundProcessing;
            
            state userInteraction {
                entry; then processingInput;
                
                state processingInput;
                
                accept at processingInput
                then runningApp;
                
                state runningApp {
                    accept at runningApp
                    then capturingPhoto;
                    
                    state capturingPhoto;
                    then runningApp;
                }
            }
            
            state backgroundProcessing {
                entry; then monitoring;
                
                state monitoring;
                then updating;
                
                state updating;
                then monitoring;
            }
        }
        
        accept at active
        then idle;
        
        accept at idle
        then powerOff;
    }
    
    requirement def <'REQ-001'> DisplayPerformanceRequirement {
        doc /* The smartphone shall provide a high-resolution display with minimum 1440p resolution. */
        
        subject phone : GalaxySmartphone;
        
        require constraint {
            phone.screen.maxResolution.width >= 1440 and
            phone.screen.maxResolution.height >= 3088
        }
    }
    
    requirement def <'REQ-002'> ProcessingPowerRequirement {
        doc /* The smartphone shall provide sufficient processing power with multi-core processor. */
        
        subject phone : GalaxySmartphone;
        
        require constraint {
            phone.processor.clockSpeed >= 3.0 and
            phone.processor.coreCount >= 8
        }
    }
    
    requirement def <'REQ-003'> BatteryLifeRequirement {
        doc /* The smartphone shall provide all-day battery life with minimum 5000mAh capacity. */
        
        subject phone : GalaxySmartphone;
        
        require constraint {
            phone.battery.capacity >= 5000.0 and
            phone.battery.chargingRate >= 45.0
        }
    }
    
    requirement def <'REQ-004'> ConnectivityRequirement {
        doc /* The smartphone shall support 5G connectivity with multi-band support. */
        
        subject phone : GalaxySmartphone;
        
        require constraint {
            phone.modem.supportedBands >= 28 and
            phone.modem.maxDataRate >= 10.0
        }
    }
    
    requirement def <'REQ-005'> CameraQualityRequirement {
        doc /* The smartphone shall provide professional-grade photography. */
        
        subject phone : GalaxySmartphone;
        
        require constraint {
            phone.camera.megapixels >= 200.0 and
            phone.camera.aperture <= 1.8
        }
    }
    
    requirement <'SYS-001'> galaxySmartphoneSystemRequirement {
        doc /* The Samsung Galaxy Smartphone system shall provide a premium mobile computing and communication experience. */
        
        subject galaxySystem : GalaxySmartphone;
        
        assume constraint {
            galaxySystem.battery.currentCharge.percentage >= 0.0 and
            galaxySystem.battery.currentCharge.percentage <= 100.0
        }
        
        require displayPerf : DisplayPerformanceRequirement;
        require processingPower : ProcessingPowerRequirement;
        require batteryLife : BatteryLifeRequirement;
        require connectivity : ConnectivityRequirement;
        require cameraQuality : CameraQualityRequirement;
    }
    
    part galaxyS24Ultra : GalaxySmartphone {
        attribute :>> modelNumber = "SM-S928U";
        attribute :>> serialNumber = "GALAXY2024001";
        attribute :>> powerConsumption = 2.0;
        
        part :>> battery {
            attribute :>> currentCharge = BatteryLevel {
                percentage = 100.0;
                voltage = 4.4;
            }
        }
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import 'Samsung Galaxy Smartphone System'::*;

    part testSubject : GalaxySmartphone {
        exhibit state phoneStates : SmartphoneOperatingStates;
    }

    action orchestrator {
        item testFrameInput : DisplayFrame {
            attribute resolution : ScreenResolution {
                attribute width = 0;
                attribute height = 0;
            }
            attribute brightness = 0.0;
            attribute refreshRate = 0.0;
        }
        action actionProbe : RenderFrame {
            in frameInput = testFrameInput;
        }
        first actionProbe;
    }
}
