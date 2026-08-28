package DSN_GroundStation {
    private import ScalarValues::*;
    private import ISQ::*;
    
    package Definitions {
        alias AngleValue for ISQ::PlaneAngleValue;
        alias PowerValue for ISQ::PowerValue;
        alias LengthValue for ISQ::LengthValue;
        alias FrequencyValue for ISQ::FrequencyValue;
        
        attribute def SignalStrengthValue :> Real;
        
        item def CommandSequence;
        item def UplinkSignal {
            attribute carrierFreq : FrequencyValue;
            attribute power : PowerValue;
        }
        item def DownlinkSignal {
            attribute carrierFreq : FrequencyValue;
            attribute strength : SignalStrengthValue;
        }
        item def ScienceDataPacket;
        item def TrackingDataPacket;
        
        port def CmdIF {
            in cmd : CommandSequence;
        }
        port def RFTxIF {
            in tx : UplinkSignal;
        }
        port def RFRxIF {
            in rx : DownlinkSignal;
        }
        port def DataIF {
            in sciData : ScienceDataPacket;
            in trackData : TrackingDataPacket;
        }
        
        part def Antenna {
            attribute diameter : LengthValue = 70 [m];
            attribute pointingAccuracy : AngleValue = 0.01 [deg];
            port txIn : RFTxIF;
            port rxOut : ~RFRxIF;
        }
        
        part def TransmitterSubsystem {
            attribute outputPower : PowerValue = 20 [kW];
            port cmdIn : CmdIF;
            port txOut : ~RFTxIF;
        }
        
        part def ReceiverSubsystem {
            attribute sensitivity : SignalStrengthValue = -160.0;
            port rxIn : RFRxIF;
            port dataOut : ~DataIF;
        }
        
        part def SignalProcessingUnit {
            port dataIn : DataIF;
            port dataOut : ~DataIF;
        }
        
        part def MissionControlInterface {
            port cmdOut : ~CmdIF;
            port dataIn : DataIF;
        }
        
        part def DSNGroundStation {
            part antenna : Antenna;
            part transmitter : TransmitterSubsystem;
            part receiver : ReceiverSubsystem;
            part processor : SignalProcessingUnit;
            part missionControl : MissionControlInterface;
            
            connect missionControl.cmdOut to transmitter.cmdIn;
            connect transmitter.txOut to antenna.txIn;
            connect antenna.rxOut to receiver.rxIn;
            connect receiver.dataOut to processor.dataIn;
            connect processor.dataOut to missionControl.dataIn;
        }
        
        action def Modulate {
            in cmd : CommandSequence;
            out sig : UplinkSignal;
        }
        action def Amplify {
            in sig : UplinkSignal;
            in minPower : PowerValue;
            out amplifiedSig : UplinkSignal;
        }
        action def Capture {
            in sig : DownlinkSignal;
            out capturedSig : DownlinkSignal;
        }
        action def Decode {
            in sig : DownlinkSignal;
            out sciData : ScienceDataPacket;
            out trackData : TrackingDataPacket;
        }
        
        action def UplinkProcess {
            in cmd : CommandSequence;
            in minPwr : PowerValue;
            out sig : UplinkSignal;
            action modulate : Modulate {
                in cmd = UplinkProcess::cmd;
            }
            action amplify : Amplify {
                in sig = modulate::sig;
                in minPower = UplinkProcess::minPwr;
                out amplifiedSig = UplinkProcess::sig;
            }
            flow modulate.sig to amplify.sig;
            first start; then modulate; then amplify; then done;
        }
        
        action def DownlinkProcess {
            in sig : DownlinkSignal;
            out sci : ScienceDataPacket;
            out track : TrackingDataPacket;
            action capture : Capture {
                in sig = DownlinkProcess::sig;
            }
            action decode : Decode {
                in sig = capture::capturedSig;
                out sciData = DownlinkProcess::sci;
                out trackData = DownlinkProcess::track;
            }
            flow capture.capturedSig to decode.sig;
            first start; then capture; then decode; then done;
        }
        
        state def DSNOperationalState {
            entry; then Standby;
            state Standby;
            state UplinkActive;
            state DownlinkActive;
            
            transition first Standby 
                accept c : CommandSequence 
                do action u : UplinkProcess { in cmd = c; in minPwr = 20 [kW]; }
                then UplinkActive;
                
            transition first Standby 
                accept r : DownlinkSignal 
                do action d : DownlinkProcess { in sig = r; }
                then DownlinkActive;
                
            transition first UplinkActive 
                accept r : DownlinkSignal 
                do action d : DownlinkProcess { in sig = r; }
                then DownlinkActive;
                
            transition first DownlinkActive 
                accept c : CommandSequence 
                do action u : UplinkProcess { in cmd = c; in minPwr = 20 [kW]; }
                then UplinkActive;
                
            transition first UplinkActive then Standby;
            transition first DownlinkActive then Standby;
        }
    }
    
    package Requirements {
        private import Definitions::*;
        
        requirement PointingAccuracyRequirement {
            doc /* The antenna shall maintain pointing accuracy better than 0.01 degrees. */
            attribute maxError : AngleValue = 0.01 [deg];
        }
        requirement TransmitPowerRequirement {
            doc /* The transmitter shall generate at least 20 kW of RF power. */
            attribute minPower : PowerValue = 20 [kW];
        }
        requirement ReceiverSensitivityRequirement {
            doc /* The receiver shall detect signals as weak as -160 dBm. */
            attribute minSensitivity : SignalStrengthValue = -160.0;
        }
        requirement DSNStationRequirements {
            requirement pointingAcc : PointingAccuracyRequirement;
            requirement txPower : TransmitPowerRequirement;
            requirement rxSens : ReceiverSensitivityRequirement;
        }
    }
    
    package Usages {
        private import Definitions::*;
        private import Requirements::*;
        
        part dsnStation : DSNGroundStation {
            satisfy PointingAccuracyRequirement by antenna;
            satisfy TransmitPowerRequirement by transmitter;
            satisfy ReceiverSensitivityRequirement by receiver;
            state opState : DSNOperationalState;
        }
    }
}
