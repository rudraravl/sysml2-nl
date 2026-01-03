package HomePlugNetworkSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def MACAddress :> String;
    
    attribute def EncryptionKey {
        attribute keyBits : Integer;
        attribute keyValue : String;
    }
    
    attribute def DataRateValue :> Real;
    
    value def FrequencyBandValue {
        attribute lowerBound : FrequencyValue;
        attribute upperBound : FrequencyValue;
    }
    
    item def EthernetPacket {
        attribute sourceMAC : MACAddress;
        attribute destinationMAC : MACAddress;
        attribute payload : String;
        attribute packetSize : LengthValue;
    }
    
    item def PowerlineSignal {
        attribute carrierFrequency : FrequencyValue;
        attribute modulatedPayload : String;
        attribute signalPower : PowerValue;
        attribute encrypted : Boolean;
    }
    
    port def EthernetInterfacePort {
        in item rxPacket : EthernetPacket;
        out item txPacket : EthernetPacket;
    }
    
    port def PowerlineInterfacePort {
        in item rxSignal : PowerlineSignal;
        out item txSignal : PowerlineSignal;
        in attribute acVoltage : VoltageValue;
        in attribute acFrequency : FrequencyValue;
    }
    
    part def PHYLayer {
        attribute operatingBand : FrequencyBandValue;
        
        perform action modulateSignal {
            in dataIn : EthernetPacket;
            out signalOut : PowerlineSignal;
        }
        
        perform action demodulateSignal {
            in signalIn : PowerlineSignal;
            out dataOut : EthernetPacket;
        }
    }
    
    part def MACLayer {
        attribute deviceMAC : MACAddress;
        
        perform action processIncomingPacket {
            in packet : EthernetPacket;
            out forwardedPacket : EthernetPacket;
        }
        
        perform action processOutgoingPacket {
            in packet : EthernetPacket;
            out transmittedPacket : EthernetPacket;
        }
    }
    
    part def SecurityModule {
        attribute networkKey : EncryptionKey;
        
        perform action encryptData {
            in plainPacket : EthernetPacket;
            in key : EncryptionKey;
            out encryptedPacket : EthernetPacket;
        }
        
        perform action decryptData {
            in encryptedPacket : EthernetPacket;
            in key : EncryptionKey;
            out plainPacket : EthernetPacket;
        }
    }
    
    part def PowerManagement {
        in attribute acInput : VoltageValue;
        out attribute dcOutput : VoltageValue;
        
        perform action regulatePower {
            in acPower : PowerValue;
            out dcPower : PowerValue;
        }
    }
    
    part def HomePlugAdapter {
        attribute adapterMAC : MACAddress;
        attribute maxThroughput : DataRateValue;
        attribute securityKey : EncryptionKey;
        
        port ethPort : EthernetInterfacePort;
        port plcPort : PowerlineInterfacePort;
        
        part phyModule : PHYLayer {
            attribute operatingBand : FrequencyBandValue {
                attribute lowerBound : FrequencyValue = 2.0 [MHz];
                attribute upperBound : FrequencyValue = 30.0 [MHz];
            }
        }
        
        part macModule : MACLayer;
        part securityModule : SecurityModule;
        part powerModule : PowerManagement;
        
        perform action operateAdapter;
    }
    
    part def ElectricalWiring {
        attribute wiringType : String;
        attribute totalLength : LengthValue;
        attribute impedance : Real;
        
        port plcConnection1 : PowerlineInterfacePort;
        port plcConnection2 : PowerlineInterfacePort;
        port plcConnection3 : PowerlineInterfacePort;
        
        perform action propagateSignal {
            in inputSignal : PowerlineSignal;
            out outputSignal : PowerlineSignal;
        }
    }
    
    part def NetworkDevice {
        attribute deviceName : String;
        port ethInterface : EthernetInterfacePort;
    }
    
    connection def PowerlineLink {
        end adapterEnd : PowerlineInterfacePort;
        end wiringEnd : PowerlineInterfacePort;
        
        flow adapterEnd.txSignal to wiringEnd.rxSignal;
        flow wiringEnd.txSignal to adapterEnd.rxSignal;
    }
    
    connection def EthernetLink {
        end deviceEnd : EthernetInterfacePort;
        end adapterEnd : EthernetInterfacePort;
        
        flow deviceEnd.txPacket to adapterEnd.rxPacket;
        flow adapterEnd.txPacket to deviceEnd.rxPacket;
    }
    
    state def AdapterOperationStates {
        entry; then initializing;
        
        state initializing {
            entry;
            do action initializeHardware;
        }
        
        state idle;
        
        state receiving {
            entry;
            do action receiveAndDecode;
        }
        
        state transmitting {
            entry;
            do action encodeAndTransmit;
        }
        
        state processing {
            entry;
            do action processData;
        }
        
        state forwarding {
            entry;
            do action forwardToEthernet;
        }
        
        transition initializing to idle;
        transition idle to receiving;
        transition idle to transmitting;
        transition receiving to processing;
        transition processing to forwarding;
        transition processing to idle;
        transition forwarding to idle;
        transition transmitting to idle;
    }
    
    action def TransmitDataOverPowerline {
        in attribute sourcePacket : EthernetPacket;
        in attribute networkKey : EncryptionKey;
        in attribute operatingFrequency : FrequencyValue;
        out attribute deliveredPacket : EthernetPacket;
        
        first start;
        
        then action receiveFromEthernet {
            in packet = sourcePacket;
            out receivedPacket : EthernetPacket;
        }
        
        then action performMACProcessing {
            in inPacket = receiveFromEthernet.receivedPacket;
            out processedPacket : EthernetPacket;
        }
        
        then action encryptPacket {
            in plainData = performMACProcessing.processedPacket;
            in key = networkKey;
            out encryptedData : EthernetPacket;
        }
        
        then action modulateToCarrier {
            in dataPacket = encryptPacket.encryptedData;
            in frequency = operatingFrequency;
            out plcSignal : PowerlineSignal;
        }
        
        then action transmitOnPowerline {
            in signal = modulateToCarrier.plcSignal;
            out transmittedSignal : PowerlineSignal;
        }
        
        then action propagateThroughWiring {
            in inputSignal = transmitOnPowerline.transmittedSignal;
            out outputSignal : PowerlineSignal;
        }
        
        then action receiveFromPowerline {
            in receivedSignal = propagateThroughWiring.outputSignal;
            out capturedSignal : PowerlineSignal;
        }
        
        then action demodulateSignal {
            in plcSignal = receiveFromPowerline.capturedSignal;
            out demodulatedData : EthernetPacket;
        }
        
        then action decryptPacket {
            in encryptedData = demodulateSignal.demodulatedData;
            in key = networkKey;
            out plainData : EthernetPacket;
        }
        
        then action performMACValidation {
            in inPacket = decryptPacket.plainData;
            out validatedPacket : EthernetPacket;
        }
        
        then action deliverToEthernet {
            in packet = performMACValidation.validatedPacket;
            out finalPacket : EthernetPacket;
        }
        
        then assign deliveredPacket = deliverToEthernet.finalPacket;
        then done;
    }
    
    requirement def <'REQ-HP-001'> MinimumDataRateRequirement {
        doc /* The HomePlug system shall support a minimum physical layer data rate 
             of 14 Mbps for transmission over powerline medium. */
        
        subject adapter : HomePlugAdapter;
        
        require constraint {
            adapter.maxThroughput >= 14.0
        }
    }
    
    requirement def <'REQ-HP-002'> EncryptionSecurityRequirement {
        doc /* All data transmitted over the powerline shall be encrypted using 
             DES encryption with a minimum key length of 56 bits to ensure 
             network security and prevent unauthorized access. */
        
        subject security : SecurityModule;
        
        require constraint {
            security.networkKey.keyBits >= 56
        }
    }
    
    requirement def <'REQ-HP-003'> FrequencyBandRequirement {
        doc /* The HomePlug adapter shall operate within the frequency band of 
             4.3 MHz to 20.9 MHz to comply with electromagnetic compatibility 
             standards and avoid interference with other services. */
        
        subject phy : PHYLayer;
        
        require constraint {
            phy.operatingBand.lowerBound >= 4.3 [MHz] and
            phy.operatingBand.upperBound <= 20.9 [MHz]
        }
    }
    
    requirement def <'REQ-HP-004'> PowerlineCompatibilityRequirement {
        doc /* The HomePlug adapter shall operate on standard AC powerline 
             infrastructure with voltages ranging from 100V to 240V AC 
             at 50/60 Hz without requiring modifications to existing wiring. */
        
        subject adapter : HomePlugAdapter;
    }
    
    requirement def <'REQ-HP-005'> InteroperabilityRequirement {
        doc /* HomePlug adapters shall interoperate with other HomePlug-compliant 
             devices when configured with the same network encryption key, 
             regardless of manufacturer. */
        
        subject network : HomePlugNetwork;
    }
    
    requirement <'SYS-REQ-HP'> homePlugSystemRequirements {
        doc /* The HomePlug system shall enable high-speed local area networking 
             over existing electrical powerline infrastructure for residential 
             and small office environments. */
        
        require dataRate : MinimumDataRateRequirement;
        require security : EncryptionSecurityRequirement;
        require frequency : FrequencyBandRequirement;
        require powerline : PowerlineCompatibilityRequirement;
        require interop : InteroperabilityRequirement;
    }
    
    part def HomePlugNetwork {
        attribute networkIdentifier : String;
        attribute sharedNetworkKey : EncryptionKey;
        
        part masterAdapter : HomePlugAdapter {
            attribute adapterMAC : MACAddress = "00:B0:52:00:00:01";
            attribute maxThroughput : DataRateValue = 14.0;
            attribute securityKey : EncryptionKey {
                attribute keyBits : Integer = 56;
                attribute keyValue : String = "NetworkKey123";
            }
        }
        
        part slaveAdapter1 : HomePlugAdapter {
            attribute adapterMAC : MACAddress = "00:B0:52:00:00:02";
            attribute maxThroughput : DataRateValue = 14.0;
            attribute securityKey : EncryptionKey {
                attribute keyBits : Integer = 56;
                attribute keyValue : String = "NetworkKey123";
            }
        }
        
        part slaveAdapter2 : HomePlugAdapter {
            attribute adapterMAC : MACAddress = "00:B0:52:00:00:03";
            attribute maxThroughput : DataRateValue = 14.0;
            attribute securityKey : EncryptionKey {
                attribute keyBits : Integer = 56;
                attribute keyValue : String = "NetworkKey123";
            }
        }
        
        part houseWiring : ElectricalWiring {
            attribute wiringType : String = "Copper 14 AWG";
            attribute totalLength : LengthValue = 75.0 [m];
            attribute impedance : Real = 50.0;
        }
        
        part router : NetworkDevice {
            attribute deviceName : String = "Internet Gateway";
        }
        
        part computer : NetworkDevice {
            attribute deviceName : String = "Desktop PC";
        }
        
        part smartTV : NetworkDevice {
            attribute deviceName : String = "Smart Television";
        }
        
        connection plLink1 : PowerlineLink
            connect masterAdapter.plcPort to houseWiring.plcConnection1;
        
        connection plLink2 : PowerlineLink
            connect slaveAdapter1.plcPort to houseWiring.plcConnection2;
        
        connection plLink3 : PowerlineLink
            connect slaveAdapter2.plcPort to houseWiring.plcConnection3;
        
        connection ethLink1 : EthernetLink
            connect router.ethInterface to masterAdapter.ethPort;
        
        connection ethLink2 : EthernetLink
            connect computer.ethInterface to slaveAdapter1.ethPort;
        
        connection ethLink3 : EthernetLink
            connect smartTV.ethInterface to slaveAdapter2.ethPort;
        
        perform action networkOperation : TransmitDataOverPowerline {
            in attribute networkKey = sharedNetworkKey;
            in attribute operatingFrequency : FrequencyValue = 10.0 [MHz];
        }
    }
    
    action homePlugPrimaryFunction : TransmitDataOverPowerline {
        doc /* Primary Function: The HomePlug system enables high-speed local area 
             network connectivity by transmitting Ethernet data packets over existing 
             electrical powerline wiring. It uses frequency division multiplexing, 
             modulation techniques, and encryption to create a secure network without 
             requiring additional cabling infrastructure. The system bridges Ethernet 
             devices through powerline adapters that convert digital data to powerline 
             signals and vice versa, allowing seamless communication between networked 
             devices throughout a building using the electrical power distribution system. */
    }
    
    part homePlugDeployment : HomePlugNetwork {
        attribute networkIdentifier : String = "HomeNetwork_Main";
        attribute sharedNetworkKey : EncryptionKey {
            attribute keyBits : Integer = 56;
            attribute keyValue : String = "SecureKey456";
        }
    }
}
