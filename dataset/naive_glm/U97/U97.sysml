package AutonomousEdgeSensorNode {
    import ScalarValues::*;
    import ISQ::*;
    import Quantities::TimeUnit;

    value type BatteryLevel :> Real { unit "percent"; }
    value type Temperature :> Real { unit "degC"; }
    value type CPUUsage :> Real { unit "percent"; }
    value type MemoryUsage :> Real { unit "percent"; }
    value type TimeDelay :> Real { unit "s"; }

    item def DataPacket {
        attribute timestamp : Time;
        attribute payload : String;
    }

    item def HealthStatus {
        attribute cpu : CPUUsage;
        attribute memory : MemoryUsage;
        attribute temp : Temperature;
    }

    item def NetworkCommand;
    item def NetworkAck;

    port def NetworkPort {
        out item networkCommand : NetworkCommand;
        in item networkAck : NetworkAck;
    }

    port def DataPort {
        out item dataPacket : DataPacket;
    }

    requirement def ResilientOperationReq {
        doc /* The node must continue to operate when orphaned. */
    }
    requirement def LocalStorageReq {
        doc /* The internal data store must have a capacity of 5000 data packets. */
        attribute capacity : Integer = 5000;
    }
    requirement def ReconnectionReq {
        doc /* The node must use an exponential backoff algorithm starting at 30 seconds. */
        attribute initialDelay : TimeDelay = 30 [s];
    }
    requirement def PowerConservationReq {
        doc /* The node must switch to low-power mode when battery is low. */
    }
    requirement def DataSynchronizationReq {
        doc /* Upon reconnection, the node must synchronize all buffered data. */
    }

    part def ReconnectionController {
        attribute currentDelay : TimeDelay = 30 [s];
        attribute maxDelay : TimeDelay = 3600 [s];
        
        action attemptReconnection;
        action calculateBackoff;
    }

    part def PowerManager {
        attribute batteryLevel : BatteryLevel = 100 [percent];
        attribute lowPowerThreshold : BatteryLevel = 20 [percent];
        attribute isLowPower : Boolean = false;
        
        action monitorBattery;
    }

    part def DiagnosticMonitor {
        attribute healthStatus : HealthStatus;
        
        action monitorHealth;
    }

    part def DataStore {
        in port dataIn : DataPort;
        attribute capacity : Integer = 5000;
        attribute storedPackets : DataPacket[0..5000] := {};
        
        action storePacket(in packet : DataPacket);
        action retrievePackets(out packets : DataPacket[*]);
        action clearStore;
    }

    part def Sensor {
        port dataOut : DataPort;
        
        action collectData {
            out packet : DataPacket;
        }
    }

    part def NetworkInterface {
        port netPort : NetworkPort;
        attribute isConnected : Boolean = false;
        
        action connect;
        action disconnect;
    }

    part def AutonomousEdgeSensorNode {
        port externalNetwork : NetworkPort;
        
        part reconnectionController : ReconnectionController;
        part powerManager : PowerManager;
        part diagnosticMonitor : DiagnosticMonitor;
        part dataStore : DataStore {
            in port dataIn : DataPort;
        }
        part sensor : Sensor {
            port dataOut : DataPort;
        }
        part networkInterface : NetworkInterface {
            port netPort : NetworkPort;
        }
        
        connection networkConn connect networkInterface.netPort to externalNetwork;
        connection dataFlow connect sensor.dataOut to dataStore.dataIn;
        
        requirement resilientOp : ResilientOperationReq;
        requirement localStore : LocalStorageReq;
        requirement reconnection : ReconnectionReq;
        requirement powerCons : PowerConservationReq;
        requirement dataSync : DataSynchronizationReq;
        
        state NodeBehavior {
            entry action initialize;
            
            state Connected {
                entry action resumeNormalOperation;
                transition Connected to Orphaned when !networkInterface.isConnected;
            }
            
            state Orphaned {
                entry action enterAutonomousMode;
                do action collectAndStoreData;
                transition Orphaned to Synchronizing when networkInterface.isConnected;
            }
            
            state Synchronizing {
                entry action syncBufferedData;
                transition Synchronizing to Connected when dataStore.storedPackets->isEmpty();
            }
        }
    }
}
