package 'UMTS System Model' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def Frequency {
        attribute value : Real;
        attribute unit : String;
    }
    
    attribute def SignalStrength {
        attribute value : Real;
        attribute unit : String;
    }
    
    attribute def DataRate {
        attribute downlink : Real;
        attribute uplink : Real;
        attribute unit : String;
    }
    
    attribute def PowerLevel {
        attribute value : Real;
        attribute unit : String;
    }
    
    attribute def IMSI :> String;
    attribute def CellID :> String;
    
    item def VoiceData {
        attribute codec : String;
        attribute bitrate : Real;
    }
    
    item def PacketData {
        attribute payload : Real;
        attribute qosClass : String;
    }
    
    item def SignalingMessage {
        attribute messageType : String;
        attribute priority : Integer;
    }
    
    item def RadioFrame {
        attribute frameNumber : Integer;
        attribute power : PowerLevel;
    }
    
    port def AirInterface {
        in item rxSignal : RadioFrame;
        out item txSignal : RadioFrame;
        inout item control : SignalingMessage;
    }
    
    port def IubInterface {
        in item uplinkData : PacketData;
        out item downlinkData : PacketData;
        inout item signaling : SignalingMessage;
    }
    
    port def IuInterface {
        in item userPlaneUp : PacketData;
        out item userPlaneDown : PacketData;
        inout item controlPlane : SignalingMessage;
    }
    
    part def UserEquipment {
        attribute imsi : IMSI;
        attribute transmitPower : PowerLevel;
        port airPort : AirInterface;
        
        perform action ueOperation;
    }
    
    part def NodeB {
        attribute cellId : CellID;
        attribute frequency : Frequency;
        attribute maxPower : PowerLevel;
        port airInterface : AirInterface[*];
        port iubInterface : IubInterface;
        
        perform action nodeBOperation;
    }
    
    part def RadioNetworkController {
        attribute rncId : String;
        attribute controlledCells : Integer;
        port iubPort : IubInterface[*];
        port iucsPort : IuInterface;
        port iupsPort : IuInterface;
        
        perform action rncOperation;
    }
    
    part def CircuitSwitchedDomain {
        attribute mscId : String;
        port iucsInterface : IuInterface;
        
        perform action processVoice;
    }
    
    part def PacketSwitchedDomain {
        attribute sgsnId : String;
        port iupsInterface : IuInterface;
        
        perform action processData;
    }
    
    action def EstablishConnection {
        in userIdentity : IMSI;
        in requestedService : String;
        out connectionEstablished : Boolean;
        
        first start;
        then action authenticate {
            in identity = userIdentity;
            out authenticated : Boolean;
        }
        then decide;
            if authenticate.authenticated then allocateResources;
            if !authenticate.authenticated then rejectConnection;
        
        action allocateResources {
            out resourcesAllocated : Boolean;
        }
        then assign connectionEstablished := allocateResources.resourcesAllocated;
        then done;
        
        action rejectConnection {
            out rejection : Boolean;
        }
        then assign connectionEstablished := false;
        then done;
    }
    
    action def TransmitUserData {
        in userData : PacketData;
        in channel : Integer;
        out transmissionSuccess : Boolean;
        
        first start;
        then action encodeData {
            in data = userData;
            out encodedData : PacketData;
        }
        then action modulateSignal {
            in data = encodeData.encodedData;
            out radioFrame : RadioFrame;
        }
        then action transmitFrame {
            in frame = modulateSignal.radioFrame;
            out success : Boolean;
        }
        then assign transmissionSuccess := transmitFrame.success;
        then done;
    }
    
    action def ManageHandover {
        in sourceCell : CellID;
        in targetCell : CellID;
        in ueIdentity : IMSI;
        out handoverComplete : Boolean;
        
        first start;
        then action measureSignal {
            out signalQuality : Real;
        }
        then decide;
            if measureSignal.signalQuality < 0.3 then initiateHandover;
            if measureSignal.signalQuality >= 0.3 then maintainConnection;
        
        action initiateHandover {
            first action prepareTarget {
                in target = targetCell;
                out targetReady : Boolean;
            }
            then action executeHandover {
                in ready = prepareTarget.targetReady;
                out executed : Boolean;
            }
            then assign handoverComplete := executeHandover.executed;
        }
        then done;
        
        action maintainConnection {
            out maintained : Boolean;
        }
        then assign handoverComplete := false;
        then done;
    }
    
    action def ControlPower {
        in currentSignal : SignalStrength;
        in targetSignal : SignalStrength;
        out adjustedPower : PowerLevel;
        
        first start;
        then action calculateDelta {
            in current = currentSignal.value;
            in target = targetSignal.value;
            out delta : Real;
        }
        then action adjustPowerLevel {
            in powerDelta = calculateDelta.delta;
            out newPower : PowerLevel;
        }
        then assign adjustedPower := adjustPowerLevel.newPower;
        then done;
    }
    
    state def UEConnectionState {
        entry action logStateEntry;
        exit action logStateExit;
        
        state idle {
            entry action enterIdle;
        }
        state cellSelection;
        state registering;
        state connected;
        state activeTransfer;
        state handoverInProgress;
        state releasing;
        
        transition idle_to_cellSelection
            first idle
            accept attachRequest
            then cellSelection;
        
        transition cellSelection_to_registering
            first cellSelection
            if cellSelected
            then registering;
        
        transition registering_to_connected
            first registering
            if registrationComplete
            then connected;
        
        transition connected_to_activeTransfer
            first connected
            accept dataTransferRequest
            then activeTransfer;
        
        transition activeTransfer_to_handoverInProgress
            first activeTransfer
            accept handoverTrigger
            then handoverInProgress;
        
        transition handoverInProgress_to_activeTransfer
            first handoverInProgress
            if handoverSuccess
            then activeTransfer;
        
        transition activeTransfer_to_connected
            first activeTransfer
            accept transferComplete
            then connected;
        
        transition connected_to_releasing
            first connected
            accept detachRequest
            then releasing;
        
        transition releasing_to_idle
            first releasing
            then idle;
    }
    
    requirement def UMTSCoverageRequirement {
        doc /* The UMTS system shall provide cellular coverage with specified cell radius and capacity. */
        
        require constraint cellRadiusConstraint {
            doc /* Cell radius shall be between 0.5 km and 20 km depending on environment. */
        }
        
        require constraint capacityConstraint {
            doc /* Each cell shall support minimum 100 simultaneous voice calls. */
        }
    }
    
    requirement def UMTSDataRateRequirement {
        doc /* The UMTS system shall provide specified data rates for different mobility scenarios. */
        
        require constraint downlinkRateConstraint {
            doc /* Downlink data rate shall be up to 2 Mbps for stationary users. */
        }
        
        require constraint uplinkRateConstraint {
            doc /* Uplink data rate shall be up to 384 kbps. */
        }
    }
    
    requirement def QoSRequirement {
        doc /* The UMTS system shall support differentiated Quality of Service classes. */
        
        require constraint conversationalQoS {
            doc /* Conversational class shall have end-to-end delay less than 100 ms. */
        }
        
        require constraint streamingQoS {
            doc /* Streaming class shall support variable bit rates with controlled delay. */
        }
        
        require constraint interactiveQoS {
            doc /* Interactive class shall prioritize request-response patterns. */
        }
        
        require constraint backgroundQoS {
            doc /* Background class shall utilize available capacity efficiently. */
        }
    }
    
    part def UMTSSystem;
    part def UTRAN;
    part def CoreNetwork;
    
    action def ProvideWirelessCommunication;
    
    part umtsSystem : UMTSSystem {
        doc /* 
            Universal Mobile Telecommunications System (UMTS) providing third-generation 
            wireless communications with integrated voice, data, and multimedia services 
            using Wideband Code Division Multiple Access (WCDMA) technology.
        */
        
        attribute systemIdentifier : String;
        attribute operatingBand : Frequency;
        attribute networkCapacity : Integer;
        
        part userEquipments : UserEquipment[1..*] {
            attribute imsi;
            attribute transmitPower;
        }
        
        part radioAccessNetwork : UTRAN {
            doc /* 
                UMTS Terrestrial Radio Access Network managing radio resources, 
                mobility, and connections between user equipment and core network.
            */
            
            part basestations : NodeB[1..*] {
                attribute cellId;
                attribute frequency;
                attribute maxPower;
            }
            
            part controller : RadioNetworkController {
                attribute rncId;
                attribute controlledCells;
                
                perform action manageRadioResources : ManageHandover;
                perform action powerControl : ControlPower;
            }
            
            connection nodeBToRNC : IubInterface connect 
                basestations.iubInterface to controller.iubPort;
        }
        
        part coreNetwork : CoreNetwork {
            doc /* 
                Core Network providing switching, routing, and service delivery 
                for both circuit-switched and packet-switched domains.
            */
            
            part csDomain : CircuitSwitchedDomain {
                attribute mscId;
            }
            
            part psDomain : PacketSwitchedDomain {
                attribute sgsnId;
            }
            
            connection csConnection : IuInterface connect 
                radioAccessNetwork.controller.iucsPort to csDomain.iucsInterface;
            
            connection psConnection : IuInterface connect 
                radioAccessNetwork.controller.iupsPort to psDomain.iupsInterface;
        }
        
        connection airConnection : AirInterface connect 
            userEquipments.airPort to radioAccessNetwork.basestations.airInterface;
        
        perform action provideWirelessCommunication : ProvideWirelessCommunication {
            doc /* 
                Primary function: Enable mobile users to establish and maintain 
                wireless voice and data communication sessions through a cellular 
                network infrastructure, supporting seamless mobility with handover 
                capabilities and differentiated quality of service.
            */
            
            in serviceRequest : SignalingMessage;
            out serviceDelivered : Boolean;
            
            first start;
            then action establishUserConnection : EstablishConnection {
                in userIdentity = umtsSystem.userEquipments[1].imsi;
                in requestedService = "voice_and_data";
                out connectionEstablished;
            }
            then decide;
                if establishUserConnection.connectionEstablished then provideService;
                if !establishUserConnection.connectionEstablished then terminateRequest;
            
            action provideService {
                first action allocateRadioChannel {
                    out channelAllocated : Boolean;
                }
                then action maintainSession {
                    loop {
                        action monitorConnection {
                            out connectionQuality : Real;
                        }
                        then decide;
                            if monitorConnection.connectionQuality < 0.4 then performHandover;
                            if monitorConnection.connectionQuality >= 0.4 then continueSession;
                        
                        action performHandover : ManageHandover {
                            in sourceCell = umtsSystem.radioAccessNetwork.basestations[1].cellId;
                            in targetCell = umtsSystem.radioAccessNetwork.basestations[2].cellId;
                            in ueIdentity = umtsSystem.userEquipments[1].imsi;
                            out handoverComplete;
                        }
                        then merge continueSession;
                        
                        merge continueSession;
                        then action transferData : TransmitUserData {
                            in userData : PacketData;
                            in channel = 1;
                            out transmissionSuccess;
                        }
                        then action adjustPower : ControlPower {
                            in currentSignal : SignalStrength;
                            in targetSignal : SignalStrength;
                            out adjustedPower;
                        }
                        accept sessionEnd;
                    }
                }
                then action releaseResources {
                    out resourcesReleased : Boolean;
                }
            }
            then assign serviceDelivered := true;
            then done;
            
            action terminateRequest {
                out terminated : Boolean;
            }
            then assign serviceDelivered := false;
            then done;
        }
        
        satisfy UMTSCoverageRequirement;
        satisfy UMTSDataRateRequirement;
        satisfy QoSRequirement;
    }
}
