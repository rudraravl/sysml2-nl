package ConsumerIRSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def IRProtocol {
        attribute protocolName : String;
        attribute addressBits : Integer;
        attribute commandBits : Integer;
    }

    attribute def CommandCode {
        attribute deviceAddress : Integer;
        attribute functionCode : Integer;
        attribute protocol : IRProtocol;
    }

    attribute def SignalStrengthValue :> Real;
    attribute def ModulationFrequencyValue :> FrequencyValue;

    item def InfraredSignal {
        attribute wavelength : LengthValue = 940 [nm];
        attribute carrierFrequency : ModulationFrequencyValue = 38000 [Hz];
        attribute modulatedData : CommandCode;
        attribute signalStrength : SignalStrengthValue;
        attribute duration : TimeValue;
    }

    part def IREmitter {
        attribute emissionPower : PowerValue = 0.015 [W];
        attribute beamAngle : Real = 30.0;
        port irOut;
        
        action def EmitSignal {
            in commandData : CommandCode;
            out emittedSignal : InfraredSignal;
        }
        
        perform action emit : EmitSignal[*];
    }

    part def IRPhotodetector {
        attribute sensitivity : SignalStrengthValue = 0.05;
        attribute detectionRange : LengthValue = 12 [m];
        attribute fieldOfView : Real = 45.0;
        port irIn;
        
        action def DetectSignal {
            in receivedSignal : InfraredSignal;
            out detectedData : CommandCode;
        }
        
        perform action detect : DetectSignal[*];
    }

    part def RemoteControlUnit {
        attribute batteryVoltage : ElectricPotentialValue = 3.0 [V];
        attribute numberOfButtons : Integer = 25;
        attribute deviceType : String = "Universal Remote";
        
        part emitter : IREmitter {
            attribute :>> emissionPower = 0.015 [W];
        }
        
        part microcontroller {
            attribute clockFrequency : FrequencyValue = 8000000 [Hz];
        }
        
        action def GenerateCommand {
            in buttonPressed : Integer;
            out generatedCommand : CommandCode;
        }
        
        action def TransmitCommand {
            first start;
            then action generate : GenerateCommand {
                in buttonPressed : Integer;
                out generatedCommand : CommandCode;
            }
            then action transmit : IREmitter::EmitSignal {
                in commandData = generate.generatedCommand;
                out emittedSignal : InfraredSignal;
            }
            then done;
        }
        
        perform action sendCommand : TransmitCommand[*];
    }

    part def ReceiverModule {
        attribute minimumSignalStrength : SignalStrengthValue = 0.05;
        attribute operationalRange : LengthValue = 12 [m];
        
        part photodetector : IRPhotodetector {
            attribute :>> sensitivity = 0.05;
            attribute :>> detectionRange = 12 [m];
        }
        
        part demodulator {
            attribute filterFrequency : FrequencyValue = 38000 [Hz];
        }
        
        action def ReceiveAndDecode {
            first start;
            then action receive : IRPhotodetector::DetectSignal {
                in receivedSignal : InfraredSignal;
                out detectedData : CommandCode;
            }
            then action validate {
                in commandData : CommandCode = receive.detectedData;
                out validCommand : Boolean;
            }
            then decide;
                if validate.validCommand then processCommand;
                if !validate.validCommand then done;
            action processCommand {
                in commandToProcess : CommandCode = receive.detectedData;
            }
            then done;
        }
        
        perform action receiveCommand : ReceiveAndDecode[*];
    }

    part def ControlledAppliance {
        attribute applianceID : String;
        attribute powerConsumption : PowerValue;
        
        part receiver : ReceiverModule {
            attribute :>> operationalRange = 12 [m];
        }
        
        state def ApplianceStateMachine {
            entry action initializeDevice;
            
            state PowerOff {
                entry action shutdownSystems;
            }
            
            state Standby {
                entry action enterLowPowerMode;
                do action monitorIRInput;
            }
            
            state Active {
                entry action activateSystems;
                do action performFunction;
                exit action savePowerState;
            }
            
            transition powerOffToStandby
                first PowerOff
                accept at InfraredSignal
                then Standby;
            
            transition standbyToActive
                first Standby
                accept at InfraredSignal
                then Active;
            
            transition activeToStandby
                first Active
                accept at InfraredSignal
                then Standby;
            
            transition standbyToPowerOff
                first Standby
                accept at InfraredSignal
                then PowerOff;
        }
        
        exhibit state applianceBehavior : ApplianceStateMachine;
    }

    part def TelevisionSet :> ControlledAppliance {
        attribute :>> applianceID = "TV-MAIN-001";
        attribute :>> powerConsumption = 120 [W];
        attribute screenSize : LengthValue = 55 [in];
        attribute currentChannel : Integer = 1;
        attribute volumeLevel : Integer = 50;
        attribute maxVolume : Integer = 100;
        
        action def ChangeChannel {
            in channelNumber : Integer;
            
            first start;
            then action validateChannel {
                in requestedChannel : Integer = channelNumber;
                out isValid : Boolean;
            }
            then decide;
                if validateChannel.isValid then setChannel;
                if !validateChannel.isValid then done;
            action setChannel {
                in newChannel : Integer = channelNumber;
            }
            then done;
        }
        
        action def AdjustVolume {
            in volumeChange : Integer;
            
            first start;
            then action calculateNewVolume {
                in delta : Integer = volumeChange;
                out newLevel : Integer;
            }
            then action applyVolume {
                in level : Integer = calculateNewVolume.newLevel;
            }
            then done;
        }
        
        perform action channelControl : ChangeChannel[*];
        perform action volumeControl : AdjustVolume[*];
    }

    connection def IRCommunicationChannel {
        end transmitterPort;
        end receiverPort;
        
        attribute linkQuality : SignalStrengthValue;
        attribute effectiveRange : LengthValue;
        attribute latency : TimeValue;
    }

    part consumerIRControlSystem {
        doc /*
         * Consumer Infrared Control System
         * 
         * Primary Function: Enable wireless, line-of-sight control of consumer
         * electronic devices through modulated infrared light transmission.
         * 
         * The system allows users to remotely operate appliances by encoding
         * control commands into infrared signals transmitted from a handheld
         * remote control unit and received by the target device.
         */
        
        part remote : RemoteControlUnit {
            attribute :>> batteryVoltage = 3.0 [V];
            attribute :>> numberOfButtons = 25;
        }
        
        part television : TelevisionSet {
            attribute :>> screenSize = 55 [in];
            attribute :>> currentChannel = 1;
            attribute :>> volumeLevel = 50;
        }
        
        connection irLink : IRCommunicationChannel connect
            remote.emitter.irOut to television.receiver.photodetector.irIn {
            attribute :>> linkQuality = 0.92;
            attribute :>> effectiveRange = 10 [m];
            attribute :>> latency = 0.05 [s];
        }
        
        action def ControlDeviceOperation {
            doc /* End-to-end control operation from button press to device response */
            
            first start;
            then action userInput {
                out selectedButton : Integer;
            }
            then action remoteTransmit : RemoteControlUnit::TransmitCommand {
                in buttonPressed = userInput.selectedButton;
            }
            then action propagateSignal {
                in transmittedSignal : InfraredSignal;
                out receivedSignal : InfraredSignal;
            }
            then action deviceReceive : ReceiverModule::ReceiveAndDecode {
                in receivedSignal = propagateSignal.receivedSignal;
            }
            then action executeDeviceAction {
                in processedCommand : CommandCode;
            }
            then done;
        }
        
        perform action systemOperation : ControlDeviceOperation[*];
    }

    requirement <'REQ-CIR-001'> primaryControlFunction {
        doc /*
         * The Consumer IR system shall provide wireless remote control
         * capability for consumer electronic devices using modulated
         * infrared light transmission at standard carrier frequencies.
         */
        subject system :>> consumerIRControlSystem;
        
        require constraint {
            system.remote.emitter.emissionPower > 0 [W]
        }
    }

    requirement <'REQ-CIR-002'> operatingDistance {
        doc /*
         * The system shall maintain reliable communication over a minimum
         * line-of-sight distance of 10 meters under normal ambient conditions.
         */
        subject link :>> consumerIRControlSystem.irLink;
        
        require constraint {
            link.effectiveRange >= 10 [m]
        }
    }

    requirement <'REQ-CIR-003'> responseLatency {
        doc /*
         * The end-to-end latency from command transmission to device
         * response shall not exceed 100 milliseconds.
         */
        subject system :>> consumerIRControlSystem;
        
        require constraint {
            system.irLink.latency <= 0.1 [s]
        }
    }

    requirement <'REQ-CIR-004'> signalReliability {
        doc /*
         * The IR communication link shall maintain a minimum signal
         * quality factor of 0.85 for reliable command decoding.
         */
        subject link :>> consumerIRControlSystem.irLink;
        
        require constraint {
            link.linkQuality >= 0.85
        }
    }

    requirement <'REQ-CIR-005'> receiverSensitivity {
        doc /*
         * The receiver module shall detect infrared signals with a
         * minimum signal strength threshold appropriate for the
         * specified operating range.
         */
        subject receiver :>> consumerIRControlSystem.television.receiver;
        
        require constraint {
            receiver.photodetector.sensitivity <= 0.1
        }
    }

    satisfy primaryControlFunction by consumerIRControlSystem;
    satisfy operatingDistance by consumerIRControlSystem.irLink;
    satisfy responseLatency by consumerIRControlSystem;
    satisfy signalReliability by consumerIRControlSystem.irLink;
    satisfy receiverSensitivity by consumerIRControlSystem.television.receiver;
}
