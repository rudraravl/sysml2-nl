package IP500AllianceSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def IPAddress {
        attribute octet1 : Integer;
        attribute octet2 : Integer;
        attribute octet3 : Integer;
        attribute octet4 : Integer;
    }
    
    attribute def MACAddress {
        attribute bytes : Integer[6];
    }
    
    attribute def DataRate :> ISQ::dataRate;
    attribute def Bandwidth :> ISQ::frequency;
    attribute def Latency :> ISQ::time;
    
    item def VoIPPacket {
        attribute sourceIP : IPAddress;
        attribute destinationIP : IPAddress;
        attribute sequenceNumber : Integer;
        attribute timestamp : ISQ::DurationValue;
        attribute payloadSize : ISQ::InformationCapacityValue;
        attribute codec : String;
    }
    
    item def ControlMessage {
        attribute messageType : String;
        attribute priority : Integer;
        attribute payload : String;
    }
    
    port def EthernetPort {
        attribute macAddress : MACAddress;
        attribute speed : DataRate;
        in item rxData : VoIPPacket[*];
        out item txData : VoIPPacket[*];
    }
    
    port def VoicePort {
        attribute lineNumber : Integer;
        attribute impedance : ISQ::ElectricResistanceValue;
        in item analogIn : Real[*];
        out item analogOut : Real[*];
    }
    
    port def ControlPort {
        in item commands : ControlMessage[*];
        out item status : ControlMessage[*];
    }
    
    part def VoiceCodec {
        attribute codecType : String;
        attribute sampleRate : ISQ::FrequencyValue;
        attribute bitRate : DataRate;
        
        action def EncodeVoice {
            in analogSamples : Real[*];
            out digitalPackets : VoIPPacket[*];
        }
        
        action def DecodeVoice {
            in digitalPackets : VoIPPacket[*];
            out analogSamples : Real[*];
        }
    }
    
    part def TelephoneHandset {
        port voiceInterface : VoicePort;
        
        attribute offHook : Boolean;
        attribute dialedDigits : String;
        
        state def HandsetStateMachine {
            entry; then onHook;
            
            state onHook;
            accept liftHandset : Boolean
                then offHook;
            
            state offHook;
            accept startDial : Boolean
                then dialing;
            
            state dialing;
            accept callConnected : Boolean
                then inCall;
            
            state ringing;
            accept answerCall : Boolean
                then inCall;
            
            state inCall;
            accept hangUp : Boolean
                then onHook;
        }
    }
    
    part def IP500Phone {
        port ethPort : EthernetPort;
        port voicePort : VoicePort;
        port ctrlPort : ControlPort;
        
        part codec : VoiceCodec {
            attribute codecType = "G.711";
            attribute sampleRate = 8000.0[SI::Hz];
            attribute bitRate;
        }
        
        part handset : TelephoneHandset;
        
        attribute deviceIP : IPAddress;
        attribute registrationStatus : Boolean;
        attribute incomingCallDetected : Boolean;
        
        perform action operatePhone {
            first start;
            then action registerDevice {
                out registered : Boolean;
            }
            then decide;
                if registerDevice.registered then handleCalls;
                if !registerDevice.registered then retryRegistration;
            
            action handleCalls {
                loop {
                    action waitForEvent;
                    then decide;
                        if handset.offHook then processOutgoingCall;
                        if incomingCallDetected then processIncomingCall;
                    
                    action processOutgoingCall {
                        action encodeAudio : codec.EncodeVoice {
                            in analogSamples;
                            out digitalPackets;
                        }
                        flow encodeAudio.digitalPackets to ethPort.txData;
                    }
                    
                    action processIncomingCall {
                        action decodeAudio : codec.DecodeVoice {
                            in digitalPackets;
                            out analogSamples;
                        }
                        flow ethPort.rxData to decodeAudio.digitalPackets;
                        flow decodeAudio.analogSamples to voicePort.analogOut;
                    }
                }
            }
            
            action retryRegistration;
            then registerDevice;
        }
    }
    
    part def CallManager {
        port networkPort : EthernetPort;
        port controlPort : ControlPort;
        
        attribute maxConcurrentCalls : Integer;
        attribute activeCallCount : Integer;
        attribute callRoutingTable : String[*];
        
        perform action manageCallRouting {
            first start;
            then merge routingLoop;
            then action processCallRequest {
                in callerIP : IPAddress;
                in calleeExtension : String;
                out routingDecision : String;
            }
            then decide;
                if processCallRequest.routingDecision == "route" then establishCall;
                if processCallRequest.routingDecision == "busy" then sendBusySignal;
                if processCallRequest.routingDecision == "reject" then rejectCall;
            
            action establishCall {
                action allocateResources {
                    out resourcesAllocated : Boolean;
                }
                then action signalCallee {
                    in calleeIP : IPAddress;
                    out ringing : Boolean;
                }
                then action connectMedia {
                    in callerIP : IPAddress;
                    in calleeIP : IPAddress;
                    out mediaConnected : Boolean;
                }
            }
            then routingLoop;
            
            action sendBusySignal;
            then routingLoop;
            
            action rejectCall;
            then routingLoop;
        }
    }
    
    part def VoicemailServer {
        port networkPort : EthernetPort;
        
        attribute storageCapacity : ISQ::InformationCapacityValue;
        attribute mailboxCount : Integer;
        
        perform action handleVoicemail {
            first start;
            then loop {
                action detectNoAnswer {
                    in ringTimeout : ISQ::DurationValue;
                    out noAnswer : Boolean;
                }
                then decide;
                    if detectNoAnswer.noAnswer then recordMessage;
                
                action recordMessage {
                    in voiceStream : VoIPPacket[*];
                    out recordedFile : String;
                }
                then action storeMessage {
                    in messageFile = recordMessage.recordedFile;
                    in mailboxID : Integer;
                    out stored : Boolean;
                }
                then action notifyRecipient {
                    in mailbox = storeMessage.mailboxID;
                    out notificationSent : Boolean;
                }
            }
        }
    }
    
    part def NetworkSwitch {
        port ethernetPorts : EthernetPort[24];
        
        attribute switchingCapacity : DataRate;
        attribute vlanSupport : Boolean;
        attribute macTable : String[*];
        
        perform action switchTraffic {
            in incomingPacket : VoIPPacket;
            out outgoingPort : Integer;
            
            first start;
            then action lookupMAC {
                in destIP = incomingPacket.destinationIP;
                out portNumber : Integer;
            }
            then action forwardPacket {
                in packet = incomingPacket;
                in port = lookupMAC.portNumber;
            }
            then assign outgoingPort := lookupMAC.portNumber;
            then done;
        }
    }
    
    part def PowerSupply {
        attribute inputVoltage : ISQ::VoltageValue;
        attribute outputVoltage : ISQ::VoltageValue;
        attribute maxCurrent : ISQ::ElectricCurrentValue;
        attribute efficiency : Real;
        
        perform action providePower {
            in loadCurrent : ISQ::ElectricCurrentValue;
            out outputPower : ISQ::PowerValue;
        }
    }
    
    part def IP500AllianceSystem {
        doc /*
            The IP500 Alliance System is an integrated business communications platform
            that provides unified voice communications for small to medium enterprises.
            Its primary function is to enable reliable IP-based telephony services by
            managing call routing, voice encoding/decoding, and network connectivity
            between IP phones, while providing advanced features such as voicemail,
            call forwarding, and conference calling over standard Ethernet infrastructure.
        */
        
        part phones : IP500Phone[16] {
            attribute deviceIP;
        }
        
        part callManager : CallManager {
            attribute maxConcurrentCalls = 32;
            attribute activeCallCount = 0;
        }
        
        part voicemailServer : VoicemailServer {
            attribute storageCapacity = 10000000000.0[SI::byte];
            attribute mailboxCount = 50;
        }
        
        part networkSwitch : NetworkSwitch {
            attribute switchingCapacity;
            attribute vlanSupport = true;
        }
        
        part powerSupply : PowerSupply {
            attribute inputVoltage = 120.0[SI::V];
            attribute outputVoltage = 48.0[SI::V];
            attribute maxCurrent = 10.0[SI::A];
            attribute efficiency = 0.85;
        }
        
        connection phonesToSwitch : EthernetConnection
            connect phones.ethPort to networkSwitch.ethernetPorts;
        
        connection managerToSwitch : EthernetConnection
            connect callManager.networkPort to networkSwitch.ethernetPorts;
        
        connection voicemailToSwitch : EthernetConnection
            connect voicemailServer.networkPort to networkSwitch.ethernetPorts;
        
        perform action provideUnifiedCommunications {
            doc /*
                Primary system behavior: Process incoming and outgoing calls,
                route voice traffic between endpoints, provide voicemail services,
                and maintain system availability through continuous monitoring.
            */
            
            first start;
            then merge operationalLoop;
            then action {
                action routeCalls : callManager.manageCallRouting;
                action handleVoicemail : voicemailServer.handleVoicemail;
                action switchPackets : networkSwitch.switchTraffic;
                action operatePhones : phones.operatePhone;
            }
            then operationalLoop;
        }
    }
    
    connection def EthernetConnection {
        end source : EthernetPort;
        end target : EthernetPort;
    }
    
    requirement def SystemRequirements {
        doc /* Top-level requirements for IP500 Alliance System */
        
        requirement <'REQ-001'> callCapacity {
            doc /* System shall support minimum 32 concurrent calls */
            subject system : IP500AllianceSystem;
            require constraint {
                system.callManager.maxConcurrentCalls >= 32
            }
        }
        
        requirement <'REQ-002'> voiceQuality {
            doc /* System shall maintain voice quality with latency < 150ms */
            subject system : IP500AllianceSystem;
        }
        
        requirement <'REQ-003'> codecSupport {
            doc /* System shall support G.711 and G.729 codecs */
            subject phone : IP500Phone;
            require constraint {
                phone.codec.codecType == "G.711" or phone.codec.codecType == "G.729"
            }
        }
        
        requirement <'REQ-004'> voicemailCapacity {
            doc /* System shall provide voicemail storage for at least 50 mailboxes */
            subject vm : VoicemailServer;
            require constraint {
                vm.mailboxCount >= 50
            }
        }
        
        requirement <'REQ-005'> networkReliability {
            doc /* System shall provide 99.9% uptime */
            subject system : IP500AllianceSystem;
        }
    }
    
    requirement systemMission : SystemRequirements {
        doc /*
            The IP500 Alliance System shall provide enterprise-grade unified
            communications by enabling reliable IP telephony services with
            call routing, voicemail, and advanced calling features for up to
            32 concurrent users with carrier-grade voice quality and reliability.
        */
        
        assume constraint networkInfrastructure {
            doc /* Assumes Ethernet network with adequate bandwidth and QoS */
        }
        
        assume constraint powerAvailability {
            doc /* Assumes reliable AC power with UPS backup */
        }
        
        require callCapacity;
        require voiceQuality;
        require codecSupport;
        require voicemailCapacity;
        require networkReliability;
    }
}
