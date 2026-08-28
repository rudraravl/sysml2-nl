package UMTS {

    import ScalarValues::*;

    attribute def DistanceKm :> Real { unit 'km'; }
    attribute def SignalStrengthDbm :> Real { unit 'dBm'; }
    attribute def DataRateMbps :> Real { unit 'Mbps'; }
    attribute def PowerMw :> Real { unit 'mW'; }
    attribute def Count :> Integer;

    item def IMSI;
    item def RadioSignal {
        attribute strength : SignalStrengthDbm;
    }
    item def ControlMessage;
    item def VoicePacket;
    item def DataPacket;

    enum def QoSClass {
        conversational;
        streaming;
        interactive;
        background;
    }

    enum def SessionType {
        voice;
        data;
    }

    part def UserEquipment {
        attribute imsi : IMSI;
        attribute txPower : PowerMw;
        attribute maxDownlinkRate : DataRateMbps = 2.0;
        attribute maxUplinkRate : DataRateMbps = 1.0;
        attribute currentQoS : QoSClass;

        port airOut : out RadioSignal;
        port airIn : in RadioSignal;
        port ctrlIn : in ControlMessage;
        port ctrlOut : out ControlMessage;

        state machine def UEStateMachine {
            state Off;
            state CellSearch;
            state Registering;
            state Standby;
            state ActiveSession {
                entry { perform InitializeActiveSession; }
                do { perform ContinuousTransmission; }
            }

            transition off_to_search first Off -> second CellSearch;
            transition search_to_reg first CellSearch -> second Registering;
            transition reg_to_standby first Registering -> second Standby;
            transition standby_to_active first Standby -> second ActiveSession;
            transition active_to_standby first ActiveSession -> second Standby;
            transition standby_to_off first Standby -> second Off;
        }

        action def InitializeActiveSession;
        action def ContinuousTransmission;
    }

    part def NodeB {
        attribute cellRadius : DistanceKm;
        attribute capacity : Count;
        attribute activeUsers : Count;

        port airIn : in RadioSignal;
        port airOut : out RadioSignal;
        port ctrlOut : out ControlMessage;
        port ctrlIn : in ControlMessage;
        port rncOutVoice : out VoicePacket;
        port rncOutData : out DataPacket;
        port rncInData : in DataPacket;

        action def HandleHandover;
    }

    part def RadioNetworkController {
        attribute managedNodeBs : Count;

        port nodeBInVoice : in VoicePacket;
        port nodeBInData : in DataPacket;
        port ctrlOut : out ControlMessage;
        port coreOutVoice : out VoicePacket;
        port coreOutData : out DataPacket;

        action def ExecutePowerControl {
            in ue : UserEquipment;
            in currentSignal : SignalStrengthDbm;
            out targetPower : PowerMw;
        }

        action def ExecuteHandover {
            in ue : UserEquipment;
            in source : NodeB;
            in target : NodeB;
        }

        state machine def RNCStateMachine {
            state Monitoring;
            state PowerControlActive {
                do { perform ExecutePowerControl; }
            }
            state HandoverActive {
                do { perform ExecuteHandover; }
            }

            transition monitor_to_power first Monitoring -> second PowerControlActive;
            transition power_to_monitor first PowerControlActive -> second Monitoring;
            transition monitor_to_handover first Monitoring -> second HandoverActive;
            transition handover_to_monitor first HandoverActive -> second Monitoring;
        }
    }

    part def UTRAN {
        part nodeBs : NodeB[*];
        part rnc : RadioNetworkController;

        connection rncToNodeBs {
            end rncOut : rnc.ctrlOut;
            end nodeBIn : nodeBs.ctrlIn;
        }
        connection nodeBToRnc {
            end nodeBOut : nodeBs.rncOutVoice;
            end rncIn : rnc.nodeBInVoice;
        }
    }

    part def CircuitSwitchedDomain {
        port rncVoiceIn : in VoicePacket;
        port rncVoiceOut : out VoicePacket;
        port pstnOut : out VoicePacket;
        port pstnIn : in VoicePacket;
    }

    part def PacketSwitchedDomain {
        port rncDataIn : in DataPacket;
        port rncDataOut : out DataPacket;
        port internetOut : out DataPacket;
        port internetIn : in DataPacket;
    }

    part def CoreNetwork {
        part csDomain : CircuitSwitchedDomain;
        part psDomain : PacketSwitchedDomain;

        port rncVoiceIn : in VoicePacket;
        port rncVoiceOut : out VoicePacket;
        port rncDataIn : in DataPacket;
        port rncDataOut : out DataPacket;

        connection rncToCs {
            end coreSide : rncVoiceIn;
            end csSide : csDomain.rncVoiceIn;
        }
        connection rncToPs {
            end coreSide : rncDataIn;
            end psSide : psDomain.rncDataIn;
        }
    }

    part def UMTSSystem {
        part ues : UserEquipment[*];
        part utran : UTRAN;
        part core : CoreNetwork;

        connection ueToNodeB {
            end ueSide : ues.airOut;
            end nodeBSide : utran.nodeBs.airIn;
        }
        connection nodeBToRnc {
            end nodeBSide : utran.nodeBs.rncOutVoice;
            end rncSide : utran.rnc.nodeBInVoice;
        }
        connection rncToCoreVoice {
            end rncSide : utran.rnc.coreOutVoice;
            end coreSide : core.rncVoiceIn;
        }
        connection rncToCoreData {
            end rncSide : utran.rnc.coreOutData;
            end coreSide : core.rncDataIn;
        }
    }

    requirement def CellCoverageReq {
        doc { Each NodeB shall provide a minimum cell coverage radius. }
        attribute minRadius : DistanceKm = 15.0;
        subject nodeB : NodeB;
        constraint { nodeB.cellRadius >= minRadius }
    }

    requirement def CellCapacityReq {
        doc { Each NodeB shall support a minimum number of simultaneous users. }
        attribute minCapacity : Count = 100;
        subject nodeB : NodeB;
        constraint { nodeB.capacity >= minCapacity }
    }

    requirement def DataRateReq {
        doc { The UE shall support specified minimum data rates for uplink and downlink. }
        attribute minDownlink : DataRateMbps = 2.0;
        attribute minUplink : DataRateMbps = 1.0;
        subject ue : UserEquipment;
        constraint { ue.maxDownlinkRate >= minDownlink and ue.maxUplinkRate >= minUplink }
    }

    requirement def QoSReq {
        doc { The system shall prioritize real-time traffic over background traffic. }
        attribute priorityClass : QoSClass = conversational;
        subject ue : UserEquipment;
        constraint { ue.currentQoS == priorityClass }
    }

    requirement def UMTSOverallReq {
        doc { The UMTS system shall provide voice and data services over a wide area. }
        subject system : UMTSSystem;
    }

    requirement overallReq : UMTSOverallReq;
    requirement coverageReq : CellCoverageReq;
    requirement capacityReq : CellCapacityReq;
    requirement dataRateReq : DataRateReq;
    requirement qosReq : QoSReq;

}
