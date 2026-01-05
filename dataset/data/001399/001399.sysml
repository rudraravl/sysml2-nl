package 'DECT Wireless Communication System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def FrequencyValue :> ISQ::FrequencyValue;
    attribute def PowerValue :> ISQ::PowerValue;
    attribute def DataRateValue :> Real;
    attribute def SignalQualityValue :> Real;
    
    item def VoicePacket {
        attribute sequenceNumber : Integer;
        attribute timestamp : ISQ::TimeValue;
        attribute payload : String;
    }
    
    item def ControlMessage {
        attribute messageType : ControlMessageType;
        attribute handsetID : String;
    }
    
    enum def ControlMessageType {
        registration;
        callSetup;
        callAnswer;
        callTerminate;
        keepAlive;
    }
    
    port def RFInterfacePort {
        in item rxPacket : VoicePacket;
        out item txPacket : VoicePacket;
        in item rxControl : ControlMessage;
        out item txControl : ControlMessage;
    }
    
    port def AudioInterfacePort {
        in item microphoneInput : VoicePacket;
        out item speakerOutput : VoicePacket;
    }
    
    port def TelephoneLinePort {
        in item incomingCall : VoicePacket;
        out item outgoingCall : VoicePacket;
    }
    
    part def Handset {
        attribute deviceID : String;
        attribute batteryLevel : Real;
        attribute signalStrength : SignalQualityValue;
        
        port rfInterface : RFInterfacePort;
        port audioInterface : AudioInterfacePort;
        
        part rfTransceiver {
            attribute operatingFrequency : FrequencyValue;
            attribute transmitPower : PowerValue;
        }
        
        part audioCodec {
            attribute samplingRate : DataRateValue;
            attribute compressionRatio : Real;
        }
        
        part userInterface {
            part keypad;
            part display;
            part ringer;
        }
        
        part powerManagement {
            attribute batteryCapacity : ISQ::EnergyValue;
            attribute currentDraw : ISQ::ElectricCurrentValue;
        }
    }
    
    part def BaseStation {
        attribute stationID : String;
        attribute maxHandsets : Integer;
        
        port rfInterface : RFInterfacePort;
        port telephoneLine : TelephoneLinePort;
        
        part rfTransceiver {
            attribute operatingFrequency : FrequencyValue;
            attribute transmitPower : PowerValue;
            attribute channelCount : Integer;
        }
        
        part callController {
            attribute activeConnections : Integer;
        }
        
        part lineInterface {
            attribute lineVoltage : ISQ::ElectricPotentialValue;
        }
    }
    
    state def HandsetOperationalState {
        entry; then idle;
        
        state idle {
            doc /* Handset is powered on but not engaged in communication. */
        }
        
        state registering {
            doc /* Handset is establishing identity with base station. */
        }
        
        state standby {
            doc /* Handset is registered and monitoring for incoming calls. */
        }
        
        state ringing {
            doc /* Handset is alerting user to incoming call. */
        }
        
        state activeCall {
            doc /* Handset is engaged in voice communication. */
        }
        
        state lowBattery {
            doc /* Handset battery is below operational threshold. */
        }
        
        transition idle_to_registering
            first idle
            accept ControlMessage
            then registering;
        
        transition registering_to_standby
            first registering
            accept ControlMessage
            then standby;
        
        transition standby_to_ringing
            first standby
            accept ControlMessage
            then ringing;
        
        transition ringing_to_activeCall
            first ringing
            accept ControlMessage
            then activeCall;
        
        transition activeCall_to_standby
            first activeCall
            accept ControlMessage
            then standby;
        
        transition any_to_lowBattery
            first idle
            accept ControlMessage
            then lowBattery;
    }
    
    action def RegisterHandset {
        in handsetIdentifier : String;
        in baseIdentifier : String;
        out registrationSuccess : Boolean;
        
        first start;
        then action sendRegistrationRequest {
            out request : ControlMessage {
                attribute messageType = ControlMessageType::registration;
                attribute handsetID = handsetIdentifier;
            }
        }
        then action waitForAcknowledgment {
            in response : ControlMessage;
            out acknowledged : Boolean;
        }
        then action validateCredentials {
            in ack : Boolean = waitForAcknowledgment.acknowledged;
            out validated : Boolean;
        }
        then assign registrationSuccess := validateCredentials.validated;
        then done;
    }
    
    action def EstablishVoiceCall {
        in initiatingParty : String;
        in receivingParty : String;
        out callEstablished : Boolean;
        
        first start;
        then action allocateRFChannel {
            out assignedFrequency : FrequencyValue;
            out timeSlot : Integer;
        }
        then action sendCallSetup {
            in frequency : FrequencyValue = allocateRFChannel.assignedFrequency;
            out setupMessage : ControlMessage {
                attribute messageType = ControlMessageType::callSetup;
            }
        }
        then action waitForAnswer {
            in setup : ControlMessage = sendCallSetup.setupMessage;
            out answered : Boolean;
        }
        then decide;
            if waitForAnswer.answered then confirmConnection;
            if !waitForAnswer.answered then releaseChannel;
        
        action confirmConnection {
            out confirmed : Boolean := true;
        }
        then assign callEstablished := confirmConnection.confirmed;
        
        action releaseChannel {
            out released : Boolean := false;
        }
        then assign callEstablished := releaseChannel.released;
        
        then done;
    }
    
    action def TransmitVoiceData {
        in audioInput : VoicePacket[*];
        in channelFrequency : FrequencyValue;
        out transmittedPackets : VoicePacket[*] := ( );
        
        private attribute packetSequence : Integer := 0;
        
        for voiceData in audioInput {
            action encodeAudio {
                in rawAudio : VoicePacket = voiceData;
                out encodedPacket : VoicePacket;
            }
            then action modulateSignal {
                in packet : VoicePacket = encodeAudio.encodedPacket;
                in frequency : FrequencyValue = channelFrequency;
                out rfPacket : VoicePacket;
            }
            then action transmitPacket {
                in txPacket : VoicePacket = modulateSignal.rfPacket;
                out sentPacket : VoicePacket;
            }
            then assign transmittedPackets := transmittedPackets->including(transmitPacket.sentPacket);
            then assign packetSequence := packetSequence + 1;
        }
    }
    
    action def ReceiveVoiceData {
        in receivedPackets : VoicePacket[*];
        out audioOutput : VoicePacket[*] := ( );
        
        for rfPacket in receivedPackets {
            action demodulateSignal {
                in rxPacket : VoicePacket = rfPacket;
                out demodulatedPacket : VoicePacket;
            }
            then action decodeAudio {
                in encodedPacket : VoicePacket = demodulateSignal.demodulatedPacket;
                out decodedAudio : VoicePacket;
            }
            then action bufferAudio {
                in audio : VoicePacket = decodeAudio.decodedAudio;
                out bufferedAudio : VoicePacket;
            }
            then assign audioOutput := audioOutput->including(bufferAudio.bufferedAudio);
        }
    }
    
    action def ManageDECTCommunication {
        doc /* Primary operational behavior coordinating wireless voice communication. */
        
        first start;
        then merge monitorSystem;
        
        then action checkForActivity {
            out activityDetected : Boolean;
            out activityType : ControlMessageType;
        }
        
        then decide;
            if checkForActivity.activityType == ControlMessageType::registration then handleRegistration;
            if checkForActivity.activityType == ControlMessageType::callSetup then handleCallSetup;
            if checkForActivity.activityDetected then maintainCall;
            if !checkForActivity.activityDetected then monitorSystem;
        
        action handleRegistration : RegisterHandset {
            in handsetIdentifier;
            in baseIdentifier;
            out registrationSuccess;
        }
        then monitorSystem;
        
        action handleCallSetup : EstablishVoiceCall {
            in initiatingParty;
            in receivingParty;
            out callEstablished;
        }
        then decide;
            if handleCallSetup.callEstablished then maintainCall;
            if !handleCallSetup.callEstablished then monitorSystem;
        
        action maintainCall {
            action transmit : TransmitVoiceData {
                in audioInput;
                in channelFrequency;
                out transmittedPackets;
            }
            
            flow from transmit.transmittedPackets to receive.receivedPackets;
            
            action receive : ReceiveVoiceData {
                in receivedPackets;
                out audioOutput;
            }
            
            action monitorQuality {
                out signalQuality : SignalQualityValue;
                out maintainConnection : Boolean;
            }
        }
        
        then decide;
            if maintainCall.monitorQuality.maintainConnection then maintainCall;
            if !maintainCall.monitorQuality.maintainConnection then terminateCall;
        
        action terminateCall {
            action releaseResources;
            then action notifyParties;
        }
        then monitorSystem;
        
        then done;
    }
    
    part dectCommunicationSystem {
        doc /* Complete DECT system providing wireless voice communication. */
        
        part baseStation : BaseStation {
            attribute stationID = "BASE-001";
            attribute maxHandsets = 6;
            
            part rfTransceiver {
                attribute operatingFrequency = 1900.0 [SI::MHz];
                attribute transmitPower = 250.0 [SI::mW];
                attribute channelCount = 10;
            }
            
            perform action manageBaseOperations : ManageDECTCommunication;
        }
        
        part handset1 : Handset {
            attribute deviceID = "HS-001";
            attribute batteryLevel = 85.0;
            
            part rfTransceiver {
                attribute operatingFrequency = 1900.0 [SI::MHz];
                attribute transmitPower = 250.0 [SI::mW];
            }
            
            part audioCodec {
                attribute samplingRate = 32.0;
                attribute compressionRatio = 4.0;
            }
            
            exhibit state operationalBehavior : HandsetOperationalState;
            perform action manageHandsetOperations : ManageDECTCommunication;
        }
        
        part handset2 : Handset {
            attribute deviceID = "HS-002";
            attribute batteryLevel = 92.0;
            
            part rfTransceiver {
                attribute operatingFrequency = 1900.0 [SI::MHz];
                attribute transmitPower = 250.0 [SI::mW];
            }
            
            exhibit state operationalBehavior : HandsetOperationalState;
        }
        
        connect baseStation.rfInterface to handset1.rfInterface;
        connect baseStation.rfInterface to handset2.rfInterface;
    }
    
    requirement def WirelessCoverageRequirement {
        doc /* System shall provide adequate wireless coverage range. */
        
        attribute indoorRange : ISQ::LengthValue;
        attribute outdoorRange : ISQ::LengthValue;
        
        require constraint {
            doc /* Indoor range shall be at least 50 meters. */
            indoorRange >= 50.0 [SI::m]
        }
        
        require constraint {
            doc /* Outdoor range shall be at least 300 meters. */
            outdoorRange >= 300.0 [SI::m]
        }
    }
    
    requirement def VoiceQualityRequirement {
        doc /* System shall maintain acceptable voice quality. */
        
        attribute codecBitRate : DataRateValue;
        attribute latency : ISQ::TimeValue;
        
        require constraint {
            doc /* Codec bit rate shall be at least 32 kbps. */
            codecBitRate >= 32.0
        }
        
        require constraint {
            doc /* End-to-end latency shall not exceed 50 milliseconds. */
            latency <= 50.0 [SI::ms]
        }
    }
    
    requirement def HandsetBatteryRequirement {
        doc /* Handset shall provide sufficient battery life. */
        
        attribute talkTime : ISQ::TimeValue;
        attribute standbyTime : ISQ::TimeValue;
        
        require constraint {
            doc /* Talk time shall be at least 10 hours. */
            talkTime >= 10.0 [SI::h]
        }
        
        require constraint {
            doc /* Standby time shall be at least 100 hours. */
            standbyTime >= 100.0 [SI::h]
        }
    }
    
    requirement def MultiHandsetCapability {
        doc /* Base station shall support multiple simultaneous handsets. */
        
        attribute maxSimultaneousHandsets : Integer;
        attribute maxSimultaneousCalls : Integer;
        
        require constraint {
            doc /* Base station shall support at least 6 registered handsets. */
            maxSimultaneousHandsets >= 6
        }
        
        require constraint {
            doc /* Base station shall support at least 4 simultaneous calls. */
            maxSimultaneousCalls >= 4
        }
    }
    
    requirement <'DECT-SYS-001'> dectSystemRequirement {
        doc /* The DECT system shall provide secure, high-quality wireless voice 
               communication between base station and multiple handsets, enabling 
               cordless telephone service within residential and small office environments. */
        
        subject dectCommunicationSystem;
        
        require coverageRequirement : WirelessCoverageRequirement {
            attribute indoorRange = 50.0 [SI::m];
            attribute outdoorRange = 300.0 [SI::m];
        }
        
        require voiceQualityRequirement : VoiceQualityRequirement {
            attribute codecBitRate = 32.0;
            attribute latency = 40.0 [SI::ms];
        }
        
        require batteryRequirement : HandsetBatteryRequirement {
            attribute talkTime = 10.0 [SI::h];
            attribute standbyTime = 100.0 [SI::h];
        }
        
        require multiHandsetRequirement : MultiHandsetCapability {
            attribute maxSimultaneousHandsets = 6;
            attribute maxSimultaneousCalls = 4;
        }
        
        assume constraint {
            doc /* Base station is connected to standard telephone line or VoIP network. */
        }
        
        assume constraint {
            doc /* Operating frequency band is allocated and compliant with regional regulations. */
        }
    }
}
