package BELTRI {
    attribute def Frequency :> ScalarValues::Real;
    attribute def SignalStrength :> ScalarValues::Real;
    attribute def Velocity :> ScalarValues::Real;
    attribute def Position :> ScalarValues::Real;
    
    item def RFSignal {
        attribute frequency : Frequency;
        attribute strength : SignalStrength;
    }
    
    item def TargetData {
        attribute position : Position;
        attribute velocity : Velocity;
        attribute signalStrength : SignalStrength;
        attribute classification : ScalarValues::String;
    }
    
    item def Command {
        attribute mode : ScalarValues::String;
    }
    
    attribute def StartScanCommand;
    attribute def StopScanCommand;
    attribute def TargetDetected;
    attribute def TargetLost;
    
    port def RFInPort {
        in signal : RFSignal;
    }
    port def RFOutPort {
        out signal : RFSignal;
    }
    port def DataInPort {
        in data : TargetData;
    }
    port def DataOutPort {
        out data : TargetData;
    }
    port def CmdInPort {
        in command : Command;
    }
    port def CmdOutPort {
        out command : Command;
    }
    port def PowerPort {
        out power : ScalarValues::Real;
    }
    
    action def ExtractTargetData {
        in signal : RFSignal;
        out data : TargetData;
    }
    
    state def OperationalMode {
        entry; then idle;
        state idle;
        accept StartScanCommand then scanning;
        state scanning;
        accept TargetDetected then tracking;
        accept StopScanCommand then idle;
        state tracking;
        accept TargetLost then scanning;
        accept StopScanCommand then idle;
    }
    
    part def Antenna {
        port rfOut : RFOutPort;
    }
    
    part def Receiver {
        port rfIn : RFInPort;
        port dataOut : DataOutPort;
        port cmdIn : CmdInPort;
        port pwrIn : ~PowerPort;
    }
    
    part def SignalProcessor {
        port dataIn : DataInPort;
        port dataOut : DataOutPort;
        port cmdIn : CmdInPort;
        port pwrIn : ~PowerPort;
    }
    
    part def Transmitter {
        port dataIn : DataInPort;
        port dataOut : DataOutPort;
        port cmdIn : CmdInPort;
        port pwrIn : ~PowerPort;
    }
    
    part def PowerSupply {
        port pwrOut : PowerPort;
    }
    
    part def ControlProcessor {
        port cmdIn : CmdInPort;
        port ctrlOut : CmdOutPort;
        port pwrIn : ~PowerPort;
    }
    
    part def BELTRISystem {
        port extCmdIn : CmdInPort;
        port extDataOut : DataOutPort;
        
        part antennas : Antenna[4];
        part receiver : Receiver;
        part signalProcessor : SignalProcessor;
        part transmitter : Transmitter;
        part powerSupply : PowerSupply;
        part controlProcessor : ControlProcessor;
        
        connect antennas.rfOut to receiver.rfIn;
        connect receiver.dataOut to signalProcessor.dataIn;
        connect signalProcessor.dataOut to transmitter.dataIn;
        connect transmitter.dataOut to extDataOut;
        
        connect extCmdIn to controlProcessor.cmdIn;
        connect controlProcessor.ctrlOut to receiver.cmdIn;
        connect controlProcessor.ctrlOut to signalProcessor.cmdIn;
        connect controlProcessor.ctrlOut to transmitter.cmdIn;
        
        connect powerSupply.pwrOut to receiver.pwrIn;
        connect powerSupply.pwrOut to signalProcessor.pwrIn;
        connect powerSupply.pwrOut to transmitter.pwrIn;
        connect powerSupply.pwrOut to controlProcessor.pwrIn;
        
        state mode : OperationalMode;
    }
    
    requirement def DetectTargets {
        doc /* The system shall passively detect targets by analyzing electromagnetic signals. */
    }
    requirement def TrackTargets {
        doc /* The system shall track detected targets and compute position, velocity, signal strength, and classification. */
    }
    requirement def CommunicateIntel {
        doc /* The system shall transmit intelligence data to remote operators. */
    }
    requirement def OperationalModes {
        doc /* The system shall support idle, scanning, and tracking modes with transitions based on commands and detection events. */
    }
    
    requirement detectTargets : DetectTargets;
    requirement trackTargets : TrackTargets;
    requirement communicateIntel : CommunicateIntel;
    requirement operationalModes : OperationalModes;
    
    part beltri : BELTRISystem;
    
    satisfy detectTargets by beltri;
    satisfy trackTargets by beltri;
    satisfy communicateIntel by beltri;
    satisfy operationalModes by beltri;
}
