package UMTS_Model {
    private import ScalarValues::*;

    attribute def IMSI :> String;
    attribute def CellRadius :> Real; // metres
    attribute def TransmitPower :> Real; // milliwatts
    attribute def DataRate :> Real; // bits per second
    attribute def UserCount :> Integer;
    attribute def QoSLevel :> Integer;

    item def PowerOnSignal;
    item def CellFoundSignal;
    item def RegistrationCompleteSignal;
    item def SessionRequestSignal;
    item def SessionEndSignal;
    item def PowerOffSignal;
    item def HandoverTriggerSignal;
    item def HandoverCompleteSignal;

    item def ControlData;
    item def VoiceData;
    item def PacketData;

    port def UuAirInterface {
        in item ctrlIn : ControlData;
        out item ctrlOut : ControlData;
        in item voiceIn : VoiceData;
        out item voiceOut : VoiceData;
        in item packetIn : PacketData;
        out item packetOut : PacketData;
    }

    port def IubInterface {
        in item ctrlIn : ControlData;
        out item ctrlOut : ControlData;
        in item dataIn : PacketData;
        out item dataOut : PacketData;
    }

    port def IuCSInterface {
        in item voiceIn : VoiceData;
        out item voiceOut : VoiceData;
        in item ctrlIn : ControlData;
        out item ctrlOut : ControlData;
    }

    port def IuPSInterface {
        in item packetIn : PacketData;
        out item packetOut : PacketData;
        in item ctrlIn : ControlData;
        out item ctrlOut : ControlData;
    }

    action def PowerControl {
        in attribute measuredPower : TransmitPower;
        out item powerCommand : ControlData;
    }

    action def Handover {
        in item sourceCellInfo : ControlData;
        in item targetCellInfo : ControlData;
        out item handoverCommand : ControlData;
    }

    state def UEStateMachine {
        entry; then poweredOff;
        state poweredOff;
        state cellSearch;
        state registration;
        state standby;
        state activeSession;

        transition powerOn
            first poweredOff
            accept PowerOnSignal
            then cellSearch;
        transition cellFound
            first cellSearch
            accept CellFoundSignal
            then registration;
        transition registrationDone
            first registration
            accept RegistrationCompleteSignal
            then standby;
        transition sessionStart
            first standby
            accept SessionRequestSignal
            then activeSession;
        transition sessionEnd
            first activeSession
            accept SessionEndSignal
            then standby;
        transition powerOffFromStandby
            first standby
            accept PowerOffSignal
            then poweredOff;
        transition powerOffFromActive
            first activeSession
            accept PowerOffSignal
            then poweredOff;
    }

    state def RNCControlLoop {
        entry; then monitoring;
        state monitoring {
            do action powerControl : PowerControl;
        }
        state handoverExecution {
            do action handover : Handover;
        }

        transition initiateHandover
            first monitoring
            accept HandoverTriggerSignal
            then handoverExecution;
        transition handoverDone
            first handoverExecution
            accept HandoverCompleteSignal
            then monitoring;
    }

    part def UserEquipment {
        attribute imsi : IMSI;
        attribute txPower : TransmitPower;
        port radioPort : UuAirInterface;
        exhibit UEStateMachine;
    }

    part def NodeB {
        attribute cellRadius : CellRadius;
        attribute maxSimultaneousUsers : UserCount;
        attribute transmitPower : TransmitPower;
        port airInterface : ~UuAirInterface;
        port iubPort : ~IubInterface;
    }

    part def RadioNetworkController {
        port nodeBPort : IubInterface;
        port iuCSPort : IuCSInterface;
        port iuPSPort : IuPSInterface;
        exhibit RNCControlLoop;
    }

    part def CircuitSwitchedDomain {
        port iuCSPort : ~IuCSInterface;
        attribute activeCalls : UserCount;
    }

    part def PacketSwitchedDomain {
        port iuPSPort : ~IuPSInterface;
        attribute activeSessions : UserCount;
    }

    part def CoreNetwork {
        part csDomain : CircuitSwitchedDomain;
        part psDomain : PacketSwitchedDomain;
    }

    part def UTRAN {
        part nodeBs : NodeB[1..*];
        part rnc : RadioNetworkController;
        connect rnc.nodeBPort to nodeBs.iubPort;
    }

    part def UMTSNetwork {
        part userEquipments : UserEquipment[1..*];
        part utran : UTRAN;
        part coreNetwork : CoreNetwork;
        connect userEquipments.radioPort to utran.nodeBs.airInterface;
        connect utran.rnc.iuCSPort to coreNetwork.csDomain.iuCSPort;
        connect utran.rnc.iuPSPort to coreNetwork.psDomain.iuPSPort;
    }

    part umtsSystem : UMTSNetwork;

    requirement def CoverageRadiusRequirement {
        doc /* Each NodeB cell shall provide a coverage radius of at least 5000 metres. */
        attribute minRadius : CellRadius = 5000.0;
    }

    requirement def SimultaneousUsersRequirement {
        doc /* Each NodeB cell shall support at least 100 simultaneous users. */
        attribute minUsers : UserCount = 100;
    }

    requirement def DownlinkDataRateRequirement {
        doc /* The downlink data rate shall be at least 384000 bits per second. */
        attribute minDownlinkRate : DataRate = 384000.0;
    }

    requirement def UplinkDataRateRequirement {
        doc /* The uplink data rate shall be at least 128000 bits per second. */
        attribute minUplinkRate : DataRate = 128000.0;
    }

    requirement def QoSLevelsRequirement {
        doc /* The system shall support at least 4 QoS levels for traffic prioritization. */
        attribute minQoSLevels : QoSLevel = 4;
    }

    requirement UMTSRequirements {
        subject system : UMTSNetwork;

        requirement coverage : CoverageRadiusRequirement;
        requirement capacity : SimultaneousUsersRequirement;
        requirement downlinkRate : DownlinkDataRateRequirement;
        requirement uplinkRate : UplinkDataRateRequirement;
        requirement qos : QoSLevelsRequirement;
    }

    requirement coverageReq : CoverageRadiusRequirement;
    requirement capacityReq : SimultaneousUsersRequirement;
    requirement qosReq : QoSLevelsRequirement;

    satisfy coverageReq by umtsSystem.utran.nodeBs.cellRadius;
    satisfy capacityReq by umtsSystem.utran.nodeBs.maxSimultaneousUsers;
    satisfy qosReq by umtsSystem.coreNetwork;
}
