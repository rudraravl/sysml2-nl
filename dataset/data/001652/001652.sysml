package ExtronAVDistributionSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def ResolutionSpec {
        attribute horizontalPixels : Integer;
        attribute verticalPixels : Integer;
        attribute refreshRate : Real;
    }
    
    attribute def DataRateValue :> Real;
    
    enum def VideoFormat {
        HDMI_2_0;
        DisplayPort_1_4;
        HDBaseT;
        DVI_D;
    }
    
    enum def AudioFormat {
        stereo;
        surround_5_1;
        surround_7_1;
        embedded;
    }
    
    enum def SwitchingMode {
        manual;
        automatic;
        scheduled;
    }
    
    item def VideoSignal {
        attribute format : VideoFormat;
        attribute resolution : ResolutionSpec;
        attribute bandwidth : DataRateValue;
        attribute colorDepth : Integer;
    }
    
    item def AudioSignal {
        attribute format : AudioFormat;
        attribute sampleRate : FrequencyValue;
        attribute bitDepth : Integer;
        attribute channelCount : Integer;
    }
    
    item def ControlCommand {
        attribute commandType : String;
        attribute sourceId : Integer;
        attribute destinationId : Integer;
        attribute timestamp : TimeValue;
    }
    
    port def VideoInputPort {
        in item videoSignal : VideoSignal;
    }
    
    port def VideoOutputPort {
        out item videoSignal : VideoSignal;
    }
    
    port def AudioInputPort {
        in item audioSignal : AudioSignal;
    }
    
    port def AudioOutputPort {
        out item audioSignal : AudioSignal;
    }
    
    port def ControlInterfacePort {
        in item commandIn : ControlCommand;
        out item statusOut : ControlCommand;
    }
    
    port def NetworkPort {
        in item dataIn : ControlCommand;
        out item dataOut : ControlCommand;
    }
    
    part def MatrixSwitcher {
        attribute inputCount : Integer;
        attribute outputCount : Integer;
        attribute switchingSpeed : TimeValue;
        attribute currentMode : SwitchingMode;
        attribute activeRoutes : Integer[*];
        
        port videoInputs : VideoInputPort[8];
        port videoOutputs : VideoOutputPort[8];
        port audioInputs : AudioInputPort[8];
        port audioOutputs : AudioOutputPort[8];
        port controlInterface : ControlInterfacePort;
        
        action routeSignal {
            in command : ControlCommand;
            out success : Boolean;
            
            first start;
            then action receiveCommand {
                in cmd : ControlCommand = command;
                out sourcePort : Integer;
                out destPort : Integer;
            }
            then action validatePorts {
                in source : Integer = receiveCommand.sourcePort;
                in dest : Integer = receiveCommand.destPort;
                out isValid : Boolean;
            }
            then decide;
                if validatePorts.isValid then performSwitch;
                else reportError;
            
            action performSwitch {
                first action breakExisting;
                then action connectNew {
                    in source : Integer = receiveCommand.sourcePort;
                    in dest : Integer = receiveCommand.destPort;
                }
                then action verifyConnection {
                    out verified : Boolean;
                }
                then done;
            }
            
            action reportError {
                out errorCode : Integer;
            }
            then done;
        }
    }
    
    part def VideoScaler {
        attribute inputResolution : ResolutionSpec;
        attribute outputResolution : ResolutionSpec;
        attribute scalingAlgorithm : String;
        attribute processingLatency : TimeValue;
        
        port videoInput : VideoInputPort;
        port videoOutput : VideoOutputPort;
        port control : ControlInterfacePort;
        
        action scaleVideo {
            in inputSignal : VideoSignal;
            out outputSignal : VideoSignal;
            
            first start;
            then action detectInput {
                in signal : VideoSignal = inputSignal;
                out detectedRes : ResolutionSpec;
                out detectedFormat : VideoFormat;
            }
            then action analyzeScaling {
                in sourceRes : ResolutionSpec = detectInput.detectedRes;
                in targetRes : ResolutionSpec = outputResolution;
                out scaleFactor : Real;
            }
            then action applyScaling {
                in factor : Real = analyzeScaling.scaleFactor;
                in source : VideoSignal = inputSignal;
                out scaled : VideoSignal;
            }
            then action enhanceImage {
                in signal : VideoSignal = applyScaling.scaled;
                out enhanced : VideoSignal;
            }
            then action outputVideo {
                in signal : VideoSignal = enhanceImage.enhanced;
            }
            then done;
        }
    }
    
    part def AudioProcessor {
        attribute channelCount : Integer;
        attribute processingMode : String;
        attribute equalizerBands : Integer;
        attribute dynamicRange : Real;
        
        port audioInputs : AudioInputPort[8];
        port audioOutputs : AudioOutputPort[8];
        port control : ControlInterfacePort;
        
        action processAudio {
            in inputSignals : AudioSignal[*];
            out outputSignal : AudioSignal;
            
            first start;
            then action analyzeInputs {
                in signals : AudioSignal[*] = inputSignals;
                out levels : Real[*];
                out formats : AudioFormat[*];
            }
            then action mixChannels {
                in signals : AudioSignal[*] = inputSignals;
                in levels : Real[*] = analyzeInputs.levels;
                out mixed : AudioSignal;
            }
            then action applyEQ {
                in signal : AudioSignal = mixChannels.mixed;
                out equalized : AudioSignal;
            }
            then action applyDynamics {
                in signal : AudioSignal = applyEQ.equalized;
                out processed : AudioSignal;
            }
            then action distributeOutput {
                in signal : AudioSignal = applyDynamics.processed;
            }
            then done;
        }
    }
    
    part def ControlSystem {
        attribute firmwareVersion : String;
        attribute ipAddress : String;
        attribute macAddress : String;
        attribute uptime : TimeValue;
        
        port networkInterface : NetworkPort;
        port deviceControl : ControlInterfacePort[*];
        port userInterface : ControlInterfacePort;
        
        action executeCommand {
            in userCommand : ControlCommand;
            out result : ControlCommand;
            
            first start;
            then action authenticateUser {
                in cmd : ControlCommand = userCommand;
                out authorized : Boolean;
            }
            then decide;
                if authenticateUser.authorized then processCommand;
                else denyAccess;
            
            action processCommand {
                first action parseRequest {
                    in cmd : ControlCommand = userCommand;
                    out targetDevice : Integer;
                    out action : String;
                }
                then action sendToDevice {
                    in device : Integer = parseRequest.targetDevice;
                    in cmd : String = parseRequest.action;
                    out deviceResponse : ControlCommand;
                }
                then action logTransaction {
                    in response : ControlCommand = sendToDevice.deviceResponse;
                }
                then done;
            }
            
            action denyAccess {
                out errorResponse : ControlCommand;
            }
            then done;
        }
    }
    
    part def PowerDistribution {
        attribute inputVoltage : VoltageValue;
        attribute outputVoltage : VoltageValue;
        attribute maxCurrent : ElectricCurrentValue;
        attribute powerConsumption : PowerValue;
        attribute efficiency : Real;
        
        assert constraint efficiencyConstraint {
            efficiency >= 0.88 && efficiency <= 0.95
        }
        
        assert constraint voltageRegulation {
            outputVoltage >= 11.5 [V] && outputVoltage <= 12.5 [V]
        }
    }
    
    part def AVDistributionSystem {
        doc /* 
         * Professional audiovisual distribution system providing centralized
         * switching, scaling, and routing of multiple video and audio sources
         * to multiple displays and audio zones throughout a facility.
         */
        
        attribute systemModel : String;
        attribute rackSpace : Real;
        attribute totalPowerDraw : PowerValue;
        attribute maxVideoResolution : ResolutionSpec;
        attribute operatingTemperature : TemperatureValue;
        
        part mainSwitcher : MatrixSwitcher {
            attribute :>> inputCount = 8;
            attribute :>> outputCount = 8;
            attribute :>> switchingSpeed : TimeValue = 0.05 [s];
            attribute :>> currentMode = SwitchingMode::automatic;
        }
        
        part videoScaler1 : VideoScaler {
            attribute :>> inputResolution {
                attribute :>> horizontalPixels = 1920;
                attribute :>> verticalPixels = 1080;
                attribute :>> refreshRate = 60.0;
            }
            attribute :>> outputResolution {
                attribute :>> horizontalPixels = 3840;
                attribute :>> verticalPixels = 2160;
                attribute :>> refreshRate = 60.0;
            }
            attribute :>> scalingAlgorithm = "Advanced Edge Adaptive";
            attribute :>> processingLatency : TimeValue = 0.016 [s];
        }
        
        part videoScaler2 : VideoScaler {
            attribute :>> inputResolution {
                attribute :>> horizontalPixels = 1920;
                attribute :>> verticalPixels = 1080;
                attribute :>> refreshRate = 60.0;
            }
            attribute :>> outputResolution {
                attribute :>> horizontalPixels = 3840;
                attribute :>> verticalPixels = 2160;
                attribute :>> refreshRate = 60.0;
            }
            attribute :>> scalingAlgorithm = "Advanced Edge Adaptive";
            attribute :>> processingLatency : TimeValue = 0.016 [s];
        }
        
        part audioProcessor : AudioProcessor {
            attribute :>> channelCount = 8;
            attribute :>> processingMode = "Matrix Mixing";
            attribute :>> equalizerBands = 10;
            attribute :>> dynamicRange = 110.0;
        }
        
        part controller : ControlSystem {
            attribute :>> firmwareVersion = "3.2.1";
            attribute :>> ipAddress = "192.168.1.50";
            attribute :>> macAddress = "00:05:A6:3C:4D:1E";
            attribute :>> uptime : TimeValue = 0.0 [s];
        }
        
        part powerSupply : PowerDistribution {
            attribute :>> inputVoltage : VoltageValue = 120.0 [V];
            attribute :>> outputVoltage : VoltageValue = 12.0 [V];
            attribute :>> maxCurrent : ElectricCurrentValue = 8.0 [A];
            attribute :>> powerConsumption : PowerValue = 96.0 [W];
            attribute :>> efficiency = 0.92;
        }
        
        connection videoPath1 connect 
            mainSwitcher.videoOutputs[0] to videoScaler1.videoInput;
        
        connection videoPath2 connect 
            mainSwitcher.videoOutputs[1] to videoScaler2.videoInput;
        
        connection controlToSwitcher connect
            controller.deviceControl[0] to mainSwitcher.controlInterface;
        
        connection controlToScaler1 connect
            controller.deviceControl[1] to videoScaler1.control;
        
        connection controlToScaler2 connect
            controller.deviceControl[2] to videoScaler2.control;
        
        connection controlToAudio connect
            controller.deviceControl[3] to audioProcessor.control;
        
        action distributeAVContent {
            doc /* 
             * Primary system operation: receive AV signals from multiple sources,
             * route through matrix switcher, scale video to appropriate resolutions,
             * process and distribute audio, all under centralized control.
             */
            
            first start;
            then merge operationCycle;
            
            then action monitorInputs {
                out activeVideoInputs : Integer;
                out activeAudioInputs : Integer;
                out signalQuality : Real;
            }
            
            then decide;
                if monitorInputs.activeVideoInputs > 0 || monitorInputs.activeAudioInputs > 0 
                    then processContent;
                else standbyMode;
            
            action processContent {
                first parallel processVideoPath, processAudioPath, handleControl;
                
                action processVideoPath {
                    first action switchVideoSources {
                        references mainSwitcher.routeSignal;
                    }
                    then action scaleOutputs {
                        first parallel scaleOutput1, scaleOutput2;
                        
                        action scaleOutput1 {
                            references videoScaler1.scaleVideo;
                        }
                        
                        action scaleOutput2 {
                            references videoScaler2.scaleVideo;
                        }
                        
                        then join;
                    }
                    then done;
                }
                
                action processAudioPath {
                    first action routeAudio {
                        references mainSwitcher.routeSignal;
                    }
                    then action processAudioSignals {
                        references audioProcessor.processAudio;
                    }
                    then done;
                }
                
                action handleControl {
                    references controller.executeCommand;
                }
                
                then join;
            }
            then action distributeToOutputs;
            then operationCycle;
            
            action standbyMode {
                out powerSaveActive : Boolean;
            }
            then operationCycle;
        }
    }
    
    requirement def SystemRequirement;
    
    requirement <'REQ-AV-1000'> primaryDistributionFunction : SystemRequirement {
        doc /* 
         * The system shall provide centralized distribution of audiovisual content
         * from multiple sources to multiple destinations with seamless switching,
         * scaling, and processing capabilities for professional AV installations.
         */
        subject system : AVDistributionSystem;
    }
    
    requirement <'REQ-AV-1001'> videoResolutionSupport : SystemRequirement {
        doc /* 
         * The system shall support video signals up to 4K UHD resolution
         * (3840x2160) at 60Hz refresh rate with full color depth.
         */
        subject system : AVDistributionSystem;
        
        require constraint {
            system.videoScaler1.outputResolution.horizontalPixels >= 3840 &&
            system.videoScaler1.outputResolution.verticalPixels >= 2160 &&
            system.videoScaler1.outputResolution.refreshRate >= 60.0
        }
    }
    
    requirement <'REQ-AV-1002'> switchingPerformance : SystemRequirement {
        doc /* 
         * The matrix switcher shall complete video routing transitions
         * in less than 100 milliseconds to ensure seamless presentation switching.
         */
        subject switcher : MatrixSwitcher;
        
        require constraint {
            switcher.switchingSpeed <= 0.1 [s]
        }
    }
    
    requirement <'REQ-AV-1003'> inputOutputCapacity : SystemRequirement {
        doc /* 
         * The system shall support minimum 8 video inputs and 8 video outputs
         * with corresponding audio channels for comprehensive distribution.
         */
        subject system : AVDistributionSystem;
        
        require constraint {
            system.mainSwitcher.inputCount >= 8 &&
            system.mainSwitcher.outputCount >= 8 &&
            system.audioProcessor.channelCount >= 8
        }
    }
    
    requirement <'REQ-AV-1004'> scalingLatency : SystemRequirement {
        doc /* 
         * Video scalers shall introduce maximum 20 milliseconds of processing
         * latency to maintain lip-sync and interactive responsiveness.
         */
        subject scaler : VideoScaler;
        
        require constraint {
            scaler.processingLatency <= 0.020 [s]
        }
    }
    
    requirement <'REQ-AV-1005'> powerEfficiency : SystemRequirement {
        doc /* 
         * The power distribution system shall maintain minimum 88% efficiency
         * to reduce heat generation and energy costs in rack installations.
         */
        subject power : PowerDistribution;
        
        require constraint {
            power.efficiency >= 0.88
        }
    }
    
    requirement <'REQ-AV-1006'> networkControl : SystemRequirement {
        doc /* 
         * The control system shall provide IP-based network control interface
         * for integration with building automation and control systems.
         */
        subject ctrl : ControlSystem;
    }
    
    part extronSystem : AVDistributionSystem {
        attribute :>> systemModel = "DTP CrossPoint 84 4K";
        attribute :>> rackSpace = 3.0;
        attribute :>> totalPowerDraw : PowerValue = 85.0 [W];
        attribute :>> maxVideoResolution {
            attribute :>> horizontalPixels = 3840;
            attribute :>> verticalPixels = 2160;
            attribute :>> refreshRate = 60.0;
        }
        attribute :>> operatingTemperature : TemperatureValue = 298.15 [K];
        
        perform action mainOperation references distributeAVContent;
    }
    
    satisfy primaryDistributionFunction by extronSystem;
    satisfy videoResolutionSupport by extronSystem;
    satisfy switchingPerformance by extronSystem.mainSwitcher;
    satisfy inputOutputCapacity by extronSystem;
    satisfy scalingLatency by extronSystem.videoScaler1;
    satisfy scalingLatency by extronSystem.videoScaler2;
    satisfy powerEfficiency by extronSystem.powerSupply;
    satisfy networkControl by extronSystem.controller;
}
