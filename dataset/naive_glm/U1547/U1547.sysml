package DSN_Ground_Station {
    import ScalarValues::*;
    import ISQ::*;

    value type Power > Real { unit "kW"; }
    value type SignalStrength > Real { unit "dBm"; }
    value type Angle > Real { unit "deg"; }

    item def CommandSequence;
    item def RFSignal;
    item def DataPacket;

    port def CommandOutPort { out item commands : CommandSequence; }
    port def CommandInPort { in item commands : CommandSequence; }
    port def DataOutPort { out item data : DataPacket; }
    port def DataInPort { in item data : DataPacket; }
    port def RFOutPort { out item signal : RFSignal; }
    port def RFInPort { in item signal : RFSignal; }
    port def SpacePort {
        in item downlink : RFSignal;
        out item uplink : RFSignal;
    }

    requirement def PointingAccuracyRequirement {
        subject antenna : Antenna;
        requirement {
            antenna.pointingAccuracy <= 0.01 [Angle];
        }
    }

    requirement def TransmitterPowerRequirement {
        subject transmitter : TransmitterSubsystem;
        requirement {
            transmitter.outputPower >= 20 [Power];
        }
    }

    requirement def ReceiverSensitivityRequirement {
        subject receiver : ReceiverSubsystem;
        requirement {
            receiver.minDetectableSignal <= -160 [SignalStrength];
        }
    }

    requirement PointingAccuracyReq : PointingAccuracyRequirement;
    requirement TransmitterPowerReq : TransmitterPowerRequirement;
    requirement ReceiverSensitivityReq : ReceiverSensitivityRequirement;

    part def Antenna {
        attribute diameter : Real = 70 [m];
        attribute pointingAccuracy : Angle;
        attribute isTracking : Boolean;
        port spaceInterface : SpacePort;
        port txInterface : RFInPort;
        port rxInterface : RFOutPort;
        
        exhibit state AntennaStateMachine {
            state Idle;
            state Tracking;
            transition idle_to_tracking
                first Idle
                if isTracking
                then Tracking;
            transition tracking_to_idle
                first Tracking
                if !isTracking
                then Idle;
        }
    }

    part def TransmitterSubsystem {
        attribute outputPower : Power;
        attribute isCommanding : Boolean;
        port commandIn : CommandInPort;
        port rfOut : RFOutPort;
        
        exhibit state TransmitterStateMachine {
            state Standby;
            state Transmitting;
            transition standby_to_transmitting
                first Standby
                if isCommanding
                then Transmitting;
            transition transmitting_to_standby
                first Transmitting
                if !isCommanding
                then Standby;
        }
    }

    part def ReceiverSubsystem {
        attribute minDetectableSignal : SignalStrength;
        attribute isReceiving : Boolean;
        port rfIn : RFInPort;
        port dataOut : DataOutPort;
        
        exhibit state ReceiverStateMachine {
            state Listening;
            state Receiving;
            transition listening_to_receiving
                first Listening
                if isReceiving
                then Receiving;
            transition receiving_to_listening
                first Receiving
                if !isReceiving
                then Listening;
        }
    }

    part def SignalProcessingUnit {
        attribute isProcessing : Boolean;
        port dataIn : DataInPort;
        port dataOut : DataOutPort;
        
        exhibit state ProcessingStateMachine {
            state Waiting;
            state Decoding;
            transition waiting_to_decoding
                first Waiting
                if isProcessing
                then Decoding;
            transition decoding_to_waiting
                first Decoding
                if !isProcessing
                then Waiting;
        }
    }

    part def MissionControlInterface {
        port commandOut : CommandOutPort;
        port dataIn : DataInPort;
    }

    part def GroundStation {
        part missionControl : MissionControlInterface;
        part transmitter : TransmitterSubsystem {
            satisfy TransmitterPowerReq;
        }
        part receiver : ReceiverSubsystem {
            satisfy ReceiverSensitivityReq;
        }
        part processor : SignalProcessingUnit;
        part antenna : Antenna {
            satisfy PointingAccuracyReq;
        }

        connection commandLink connect missionControl.commandOut to transmitter.commandIn;
        connection uplinkRF connect transmitter.rfOut to antenna.txInterface;
        connection downlinkRF connect antenna.rxInterface to receiver.rfIn;
        connection receiverToProcessor connect receiver.dataOut to processor.dataIn;
        connection processorToMissionControl connect processor.dataOut to missionControl.dataIn;
    }
}
