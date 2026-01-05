package HomePNANetworkSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    doc /* 
     * Home Phoneline Networking Alliance (HomePNA) System Model
     * 
     * This model describes a HomePNA networking system that enables high-speed
     * data communication over existing telephone wiring infrastructure within
     * a home or small office environment.
     * 
     * Primary Function: The system transmits Ethernet data packets as modulated
     * signals over standard telephone lines, allowing multiple network devices
     * to communicate simultaneously without interfering with voice telephone
     * service. The system uses frequency division multiplexing to separate
     * data signals (operating at higher frequencies) from voice signals.
     */
    
    attribute def MACAddress :> String;
    attribute def IPAddress :> String;
    attribute def DataRate :> ISQ::FrequencyValue;
    attribute def SignalPower :> ISQ::PowerValue;
    attribute def LineImpedance :> Real;
    attribute def CarrierFrequency :> ISQ::FrequencyValue;
    
    item def NetworkFrame {
        attribute sourceMAC : MACAddress;
        attribute destinationMAC : MACAddress;
        attribute frameType : String;
        attribute payload : String;
        attribute frameSize : ISQ::LengthValue;
        attribute timestamp : ISQ::TimeValue;
    }
    
    port def EthernetPort {
        attribute macAddress : MACAddress;
        in item rxFrames : NetworkFrame[*];
        out item txFrames : NetworkFrame[*];
    }
    
    port def PhoneLinePort {
        attribute impedance : LineImpedance;
        attribute signalLevel : SignalPower;
        in item rxSignal : NetworkFrame[*];
        out item txSignal : NetworkFrame[*];
    }
    
    part def HomePNATransceiver {
        attribute transceiverID : String;
        attribute operatingFrequency : CarrierFrequency;
        attribute maxDataRate : DataRate;
        attribute currentDataRate : DataRate;
        
        port ethernetInterface : EthernetPort;
        port phoneLineInterface : PhoneLinePort;
        
        part physicalLayer {
            attribute carrierFreq : CarrierFrequency;
            attribute modulationScheme : String;
        }
        
        part macLayer {
            attribute csmaEnabled : Boolean;
            attribute collisionBackoff : ISQ::TimeValue;
        }
        
        part modulator {
            in item digitalFrame : NetworkFrame[*];
            out item modulatedSignal : NetworkFrame[*];
        }
        
        part demodulator {
            in item modulatedSignal : NetworkFrame[*];
            out item digitalFrame : NetworkFrame[*];
        }
        
        part carrierSense {
            in attribute lineSignal : SignalPower;
            out attribute channelBusy : Boolean;
        }
    }
    
    part def TelephoneWiring {
        attribute wiringID : String;
        attribute totalLength : ISQ::LengthValue;
        attribute characteristicImpedance : LineImpedance;
        attribute attenuationFactor : Real;
        
        port endpoint1 : PhoneLinePort;
        port endpoint2 : PhoneLinePort;
        port endpoint3 : PhoneLinePort;
    }
    
    part def NetworkEndpoint {
        attribute deviceName : String;
        attribute ipAddress : IPAddress;
        attribute macAddress : MACAddress;
        
        port networkPort : EthernetPort;
    }
    
    action def ModulateFrame {
        in digitalFrame : NetworkFrame;
        in carrierFreq : CarrierFrequency;
        in modulationScheme : String;
        out modulatedSignal : NetworkFrame;
    }
    
    action def DemodulateSignal {
        in modulatedSignal : NetworkFrame;
        in carrierFreq : CarrierFrequency;
        out digitalFrame : NetworkFrame;
    }
    
    action def SenseCarrier {
        in lineSignal : SignalPower;
        in threshold : SignalPower;
        out channelBusy : Boolean;
    }
    
    action def TransmitFrame {
        in sourceFrame : NetworkFrame;
        in sourcePort : EthernetPort;
        in destinationMAC : MACAddress;
        out transmitted : Boolean;
        
        first start;
        then merge checkLoop;
        then action checkChannel : SenseCarrier;
        then decide;
            if checkChannel.channelBusy then backoff;
            if !checkChannel.channelBusy then modulate;
        action backoff {
            accept after 5[SI::ms];
        }
        then checkLoop;
        action modulate : ModulateFrame {
            in digitalFrame = sourceFrame;
            out modulatedSignal;
        }
        then assign transmitted := true;
        then done;
    }
    
    state def TransceiverStateMachine {
        entry; then idle;
        
        state idle {
            accept when "frame ready";
            then carrierSense;
        }
        
        state carrierSense {
            do action sense : SenseCarrier;
            if sense.channelBusy then backoff;
            if !sense.channelBusy then transmit;
        }
        
        state backoff {
            accept after 10[SI::ms];
            then carrierSense;
        }
        
        state transmit {
            do action mod : ModulateFrame;
            then idle;
        }
        
        state receive {
            do action demod : DemodulateSignal;
            then processFrame;
        }
        
        state processFrame {
            accept after 1[SI::ms];
            then idle;
        }
    }
    
    part def HomePNANetwork {
        doc /* 
         * Complete HomePNA network system consisting of transceivers,
         * telephone wiring infrastructure, and connected network devices.
         */
        
        part transceiver1 : HomePNATransceiver {
            attribute transceiverID = "HPNA_TX_001";
            attribute operatingFrequency = 12[SI::MHz];
            attribute maxDataRate = 320[SI::MHz];
            attribute currentDataRate = 200[SI::MHz];
        }
        
        part transceiver2 : HomePNATransceiver {
            attribute transceiverID = "HPNA_TX_002";
            attribute operatingFrequency = 12[SI::MHz];
            attribute maxDataRate = 320[SI::MHz];
            attribute currentDataRate = 200[SI::MHz];
        }
        
        part transceiver3 : HomePNATransceiver {
            attribute transceiverID = "HPNA_TX_003";
            attribute operatingFrequency = 12[SI::MHz];
            attribute maxDataRate = 320[SI::MHz];
            attribute currentDataRate = 200[SI::MHz];
        }
        
        part wiring1 : TelephoneWiring {
            attribute wiringID = "WIRE_SEGMENT_A";
            attribute totalLength = 25[SI::m];
            attribute characteristicImpedance = 100.0;
            attribute attenuationFactor = 0.15;
        }
        
        part wiring2 : TelephoneWiring {
            attribute wiringID = "WIRE_SEGMENT_B";
            attribute totalLength = 15[SI::m];
            attribute characteristicImpedance = 100.0;
            attribute attenuationFactor = 0.10;
        }
        
        part device1 : NetworkEndpoint {
            attribute deviceName = "Desktop_Computer";
            attribute ipAddress = "192.168.1.100";
            attribute macAddress = "00:1A:2B:3C:4D:5E";
        }
        
        part device2 : NetworkEndpoint {
            attribute deviceName = "Smart_TV";
            attribute ipAddress = "192.168.1.101";
            attribute macAddress = "00:1A:2B:3C:4D:5F";
        }
        
        part device3 : NetworkEndpoint {
            attribute deviceName = "Network_Storage";
            attribute ipAddress = "192.168.1.102";
            attribute macAddress = "00:1A:2B:3C:4D:60";
        }
        
        connect device1.networkPort to transceiver1.ethernetInterface;
        connect device2.networkPort to transceiver2.ethernetInterface;
        connect device3.networkPort to transceiver3.ethernetInterface;
        
        connect transceiver1.phoneLineInterface to wiring1.endpoint1;
        connect transceiver2.phoneLineInterface to wiring1.endpoint2;
        connect wiring1.endpoint3 to wiring2.endpoint1;
        connect transceiver3.phoneLineInterface to wiring2.endpoint2;
        
        perform action networkCommunication {
            doc /* Primary network communication behavior */
            
            first start;
            then action initiateTransfer {
                out dataFrame : NetworkFrame;
            }
            then action tx1Modulate : ModulateFrame {
                in digitalFrame = initiateTransfer.dataFrame;
                in carrierFreq = transceiver1.operatingFrequency;
                in modulationScheme = "QAM256";
                out modulatedSignal;
            }
            flow tx1Modulate.modulatedSignal to propagateSignal.inputSignal;
            then action propagateSignal {
                in inputSignal : NetworkFrame;
                out attenuatedSignal : NetworkFrame;
            }
            flow propagateSignal.attenuatedSignal to tx3Demodulate.modulatedSignal;
            then action tx3Demodulate : DemodulateSignal {
                in modulatedSignal : NetworkFrame;
                in carrierFreq = transceiver3.operatingFrequency;
                out digitalFrame;
            }
            then action deliverFrame {
                in receivedFrame = tx3Demodulate.digitalFrame;
                out deliverySuccess : Boolean;
            }
            then done;
        }
        
        requirement networkRequirements {
            doc /* HomePNA network system requirements */
            
            requirement <'REQ-HPNA-001'> minimumDataRate {
                doc /* System shall support minimum data rate of 100 Mbps */
                subject network : HomePNANetwork;
                require constraint {
                    network.transceiver1.maxDataRate >= 100[SI::MHz] and
                    network.transceiver2.maxDataRate >= 100[SI::MHz] and
                    network.transceiver3.maxDataRate >= 100[SI::MHz]
                }
            }
            
            requirement <'REQ-HPNA-002'> voiceCoexistence {
                doc /* System shall operate without interfering with voice telephone service */
                assume constraint {
                    transceiver1.operatingFrequency >= 2[SI::MHz] and
                    transceiver2.operatingFrequency >= 2[SI::MHz] and
                    transceiver3.operatingFrequency >= 2[SI::MHz]
                }
            }
            
            requirement <'REQ-HPNA-003'> collisionDetection {
                doc /* System shall implement CSMA/CD for media access control */
                require constraint {
                    transceiver1.macLayer.csmaEnabled and
                    transceiver2.macLayer.csmaEnabled and
                    transceiver3.macLayer.csmaEnabled
                }
            }
            
            requirement <'REQ-HPNA-004'> impedanceMatching {
                doc /* Wiring impedance shall match transceiver specifications */
                require constraint {
                    wiring1.characteristicImpedance == 100.0 and
                    wiring2.characteristicImpedance == 100.0
                }
            }
            
            requirement <'REQ-HPNA-005'> networkTopology {
                doc /* System shall support daisy-chain topology with at least 3 nodes */
                require constraint {
                    transceiver1.transceiverID != null and
                    transceiver2.transceiverID != null and
                    transceiver3.transceiverID != null
                }
            }
        }
    }
    
    part homePNADeployment : HomePNANetwork {
        doc /* Instantiated HomePNA network system for residential deployment */
        
        satisfy networkRequirements.minimumDataRate;
        satisfy networkRequirements.voiceCoexistence;
        satisfy networkRequirements.collisionDetection;
        satisfy networkRequirements.impedanceMatching;
        satisfy networkRequirements.networkTopology;
    }
}
