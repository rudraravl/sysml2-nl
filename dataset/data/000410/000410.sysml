package MineCamSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ImageResolution {
        attribute width : Integer;
        attribute height : Integer;
        attribute pixelCount : Integer;
    }
    
    attribute def VideoFormat {
        attribute resolution : ImageResolution;
        attribute frameRate : Real;
        attribute compressionType : String;
    }
    
    attribute def EnvironmentalConditions {
        attribute temperature : TemperatureValue;
        attribute humidity : Real;
        attribute dustDensity : Real;
        attribute vibrationLevel : Real;
    }
    
    item def ImageFrame {
        attribute timestamp : Real;
        attribute resolution : ImageResolution;
        attribute brightness : Real;
        attribute contrast : Real;
    }
    
    item def VideoData {
        attribute format : VideoFormat;
        attribute duration : DurationValue;
        attribute dataSize : Real;
    }
    
    item def CommandSignal {
        attribute commandType : String;
        attribute parameters : String;
    }
    
    item def StatusData {
        attribute systemState : String;
        attribute batteryLevel : Real;
        attribute storageRemaining : Real;
        attribute errorFlags : Integer;
    }
    
    port def PowerPort {
        attribute voltage : ISQ::ElectricPotentialDifferenceValue;
        attribute current : ElectricCurrentValue;
    }
    
    port def DataPort {
        out imageOutput : ImageFrame;
        out videoOutput : VideoData;
    }
    
    port def ControlPort {
        in commandInput : CommandSignal;
        out statusOutput : StatusData;
    }
    
    part def ImageSensor {
        attribute sensorResolution : ImageResolution;
        attribute sensitivity : Real;
        attribute dynamicRange : Real;
        
        port power : PowerPort;
        port dataOut : DataPort;
        
        action captureImage {
            in exposureTime : DurationValue;
            out rawImage : ImageFrame;
        }
    }
    
    part def OpticalSystem {
        attribute focalLength : LengthValue;
        attribute aperture : Real;
        attribute fieldOfView : Real;
        
        action focusLens {
            in targetDistance : LengthValue;
            out focusAchieved : Boolean;
        }
    }
    
    part def ImageProcessingUnit {
        attribute processingSpeed : Real;
        attribute memorySize : Real;
        
        port power : PowerPort;
        port dataIn : DataPort;
        port dataOut : DataPort;
        
        action enhanceImage {
            in rawImage : ImageFrame;
            out enhancedImage : ImageFrame;
        }
        
        action compressVideo {
            in rawFrames : ImageFrame[*];
            out compressedVideo : VideoData;
        }
    }
    
    part def StorageUnit {
        attribute capacity : Real;
        attribute writeSpeed : Real;
        attribute readSpeed : Real;
        
        port dataIn : DataPort;
        
        action storeData {
            in data : ImageFrame;
            out storageStatus : StatusData;
        }
    }
    
    part def IlluminationModule {
        attribute lightIntensity : LuminousIntensityValue;
        attribute lightColor : String;
        attribute beamAngle : Real;
        
        port power : PowerPort;
        
        action illuminate {
            in intensity : LuminousIntensityValue;
            out actualIntensity : LuminousIntensityValue;
        }
    }
    
    part def ProtectiveEnclosure {
        attribute dustRating : String;
        attribute waterResistance : String;
        attribute shockResistance : PressureValue;
        attribute temperatureRange : TemperatureValue;
        
        action protectInternals {
            in environment : EnvironmentalConditions;
            out protectionLevel : Real;
        }
    }
    
    part def CommunicationInterface {
        attribute protocol : String;
        attribute bandwidth : Real;
        attribute transmissionRange : LengthValue;
        
        port power : PowerPort;
        port dataIn : DataPort;
        
        action transmitData {
            in imageData : ImageFrame;
            out transmissionStatus : StatusData;
        }
    }
    
    part def PowerSupply {
        attribute batteryCapacity : Real;
        attribute outputVoltage : ISQ::ElectricPotentialDifferenceValue;
        attribute outputCurrent : ElectricCurrentValue;
        
        port powerOut : PowerPort;
        
        action supplyPower {
            out powerLevel : Real;
        }
    }
    
    part def MineCam {
        doc /*
            MineCam is a ruggedized imaging system designed for underground mining operations.
            Its primary function is to capture high-quality visual documentation of mine tunnels,
            shafts, and working areas in harsh environmental conditions including low light,
            dust, vibration, and extreme temperatures. The system provides real-time visual
            monitoring and recorded documentation for safety inspection, geological assessment,
            and operational oversight.
        */
        
        attribute operatingVoltage : ISQ::ElectricPotentialDifferenceValue;
        attribute totalPowerConsumption : PowerValue;
        attribute systemWeight : MassValue;
        attribute overallDimensions : LengthValue[3];
        
        port mainPowerInput : PowerPort;
        port controlInterface : ControlPort;
        port dataOutputInterface : DataPort;
        
        part sensor : ImageSensor {
            :>> sensorResolution = ImageResolution {
                width = 1920;
                height = 1080;
                pixelCount = 2073600;
            }
            :>> sensitivity = 0.01;
        }
        
        part optics : OpticalSystem {
            :>> focalLength = 8.0;
            :>> aperture = 2.8;
            :>> fieldOfView = 90.0;
        }
        
        part processor : ImageProcessingUnit {
            :>> processingSpeed = 60.0;
            :>> memorySize = 4096.0;
        }
        
        part storage : StorageUnit {
            :>> capacity = 256000.0;
            :>> writeSpeed = 100.0;
        }
        
        part lighting : IlluminationModule {
            :>> lightColor = "white";
            :>> beamAngle = 60.0;
        }
        
        part enclosure : ProtectiveEnclosure {
            :>> dustRating = "IP68";
            :>> waterResistance = "IP68";
        }
        
        part communications : CommunicationInterface {
            :>> protocol = "Ethernet";
            :>> bandwidth = 1000.0;
        }
        
        part powerSystem : PowerSupply {
            :>> batteryCapacity = 5000.0;
            :>> outputVoltage = 12.0;
        }
        
        connection powerDistribution {
            connect powerSystem.powerOut to sensor.power;
            connect powerSystem.powerOut to processor.power;
            connect powerSystem.powerOut to lighting.power;
            connect powerSystem.powerOut to communications.power;
        }
        
        connection dataPathway {
            connect sensor.dataOut to processor.dataIn;
            connect processor.dataOut to storage.dataIn;
            connect processor.dataOut to communications.dataIn;
            connect communications.dataIn to dataOutputInterface;
        }
        
        action documentMineEnvironment {
            doc /*
                Primary operational behavior: Capture and transmit visual documentation
                of underground mining environments for safety monitoring, geological analysis,
                and operational management.
            */
            
            first start;
            
            then action initializeSystem {
                first action powerUpComponents;
                then action runDiagnostics {
                    out systemStatus : StatusData;
                }
                then action configureParameters {
                    in settings : CommandSignal;
                }
            }
            
            then merge operationalReady;
            
            then action awaitCommand {
                accept receivedCommand : CommandSignal via controlInterface;
            }
            
            then decide;
                if awaitCommand.receivedCommand.commandType == "captureImage" then captureStillImage;
                if awaitCommand.receivedCommand.commandType == "recordVideo" then recordVideoSequence;
                if awaitCommand.receivedCommand.commandType == "shutdown" then shutdownSystem;
            
            action captureStillImage {
                first action activateLighting {
                    in intensity : LuminousIntensityValue;
                    out actualIntensity : LuminousIntensityValue;
                }
                
                then action adjustFocus {
                    in targetDistance : LengthValue;
                    out focusAchieved : Boolean;
                }
                
                then action acquireRawImage {
                    in exposureTime : DurationValue;
                    out rawImage : ImageFrame;
                }
                
                then action processImage {
                    in rawImage = acquireRawImage.rawImage;
                    out enhancedImage : ImageFrame;
                }
                
                then action saveToStorage {
                    in data = processImage.enhancedImage;
                    out storageStatus : StatusData;
                }
                
                then action transmitToSurface {
                    in imageData = processImage.enhancedImage;
                    out transmissionStatus : StatusData;
                }
                
                then action sendStatus {
                    send transmitToSurface.transmissionStatus via controlInterface;
                }
            }
            then operationalReady;
            
            action recordVideoSequence {
                first action startVideoRecording;
                
                then loop {
                    action captureVideoFrame {
                        out rawImage : ImageFrame;
                    }
                    then action processVideoFrame {
                        in rawImage = captureVideoFrame.rawImage;
                        out enhancedImage : ImageFrame;
                    }
                    then action bufferFrame;
                    
                    accept stopRecording : CommandSignal;
                }
                
                then action compressVideoData {
                    in rawFrames : ImageFrame[*];
                    out compressedVideo : VideoData;
                }
                
                then action saveVideoData;
                then action transmitVideoData;
            }
            then operationalReady;
            
            action shutdownSystem {
                first action saveSystemState;
                then action powerDownComponents;
            }
            then done;
        }
        
        state operationalStates {
            entry; then offline;
            
            state offline {
                accept powerOn : CommandSignal;
                then booting;
            }
            
            state booting {
                do action initializeSystem;
                if initializeSystem.runDiagnostics.systemStatus.errorFlags == 0
                    then standby;
                if initializeSystem.runDiagnostics.systemStatus.errorFlags != 0
                    then error;
            }
            
            state standby {
                accept activationCommand : CommandSignal;
                if activationCommand.commandType == "captureImage" then imaging;
                if activationCommand.commandType == "recordVideo" then recording;
            }
            
            state imaging {
                do action captureStillImage;
                then standby;
            }
            
            state recording {
                do action recordVideoSequence;
                then standby;
            }
            
            state error {
                do action diagnosticMode;
                accept resetCommand : CommandSignal;
                then booting;
            }
        }
    }
    
    requirement def <'REQ-MC-001'> PrimaryFunctionRequirement {
        doc /*
            The MineCam system shall capture high-resolution visual documentation
            of underground mining environments to support safety monitoring,
            geological assessment, and operational oversight.
        */
        
        subject mineCamInstance : MineCam;
        
        require constraint imageResolutionRequirement {
            mineCamInstance.sensor.sensorResolution.width >= 1920 and
            mineCamInstance.sensor.sensorResolution.height >= 1080
        }
    }
    
    requirement def <'REQ-MC-002'> EnvironmentalDurabilityRequirement {
        doc /*
            The MineCam system shall operate reliably in harsh underground
            mining conditions including dust, moisture, vibration, and
            temperature extremes from -20°C to +60°C.
        */
        
        subject enclosureSystem : ProtectiveEnclosure;
        
        require constraint dustProtectionLevel {
            enclosureSystem.dustRating == "IP68"
        }
        
        require constraint waterProtectionLevel {
            enclosureSystem.waterResistance == "IP68"
        }
    }
    
    requirement def <'REQ-MC-003'> LowLightCapabilityRequirement {
        doc /*
            The MineCam system shall provide adequate illumination and
            image capture capability in low-light underground conditions
            with ambient light levels below 1 lux.
        */
        
        subject lightingSystem : IlluminationModule;
        subject imagingSensor : ImageSensor;
        
        require constraint minimumIlluminationLevel {
            lightingSystem.lightIntensity >= 500.0
        }
        
        require constraint sensorSensitivity {
            imagingSensor.sensitivity <= 0.1
        }
    }
    
    requirement def <'REQ-MC-004'> DataTransmissionRequirement {
        doc /*
            The MineCam system shall transmit captured image and video data
            to surface monitoring stations with sufficient bandwidth to support
            real-time viewing and analysis.
        */
        
        subject commSystem : CommunicationInterface;
        
        require constraint minimumBandwidth {
            commSystem.bandwidth >= 100.0
        }
    }
    
    part mineCamSystem : MineCam {
        :>> operatingVoltage = 12.0;
        :>> totalPowerConsumption = 18.0;
        :>> systemWeight = 3.2;
        :>> overallDimensions = (0.15, 0.12, 0.20);
    }
}
