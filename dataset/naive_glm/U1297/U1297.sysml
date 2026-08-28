package Lagotek {
    import ScalarValues::*;

    value type Frequency :> Real;
    value type Gain :> Real;
    value type Power :> Real;
    value type DataRate :> Real;

    item def RFSignal {
        attribute frequency : Frequency;
        attribute power : Power;
    }
    
    item def IFSignal :> RFSignal;
    
    item def DigitalSample {
        attribute value : Integer;
    }
    
    item def DecodedData {
        attribute payload : String;
    }

    port def RFPort {
        out item rfSignal : RFSignal;
    }
    
    port def IFPort {
        out item ifSignal : IFSignal;
    }
    
    port def DataPort {
        out item data : DecodedData;
    }
    
    port def ControlPort {
        in attribute command : String;
        out attribute status : String;
    }

    part def AntennaArray {
        port rfOut : RFPort;
        attribute minFreq : Frequency = 100e6;
        attribute maxFreq : Frequency = 6e9;
    }
    
    part def FrontEndReceiver {
        port rfIn : RFPort;
        port ifOut : IFPort;
        port ctrl : ControlPort;
        attribute gain : Gain = 20;
    }
    
    part def DigitalSignalProcessor {
        port ifIn : IFPort;
        port dataOut : DataPort;
        port ctrl : ControlPort;
    }
    
    part def ControlProcessor {
        port ctrlDSP : ControlPort;
        port ctrlFE : ControlPort;
        attribute targetFreq : Frequency = 2.4e9;
        
        event activated;
        event signalDetected;
        event stableLock;
        event lockLost;
        
        state def ControlBehavior {
            entry;
            state idle;
            state searching;
            state locked;
            state processing;
            
            transition idle to searching when activated;
            transition searching to locked when signalDetected;
            transition locked to processing when stableLock;
            transition processing to searching when lockLost;
        }
    }
    
    part def DataOutputInterface {
        port dataIn : DataPort;
        port ethOut : DataPort;
        attribute bufferSize : Integer = 1024;
    }

    requirement def SpectrumMonitoring {
        subject sdrSystem : LagotekSystem;
        requirement freqRange : Frequency = 100e6 .. 6e9;
        requirement continuousOperation : Boolean = true;
    }

    part def LagotekSystem {
        part antenna : AntennaArray;
        part frontEnd : FrontEndReceiver;
        part dsp : DigitalSignalProcessor;
        part controller : ControlProcessor;
        part dataOutput : DataOutputInterface;
        
        connection rfLink connect antenna.rfOut to frontEnd.rfIn;
        connection ifLink connect frontEnd.ifOut to dsp.ifIn;
        connection dataLink connect dsp.dataOut to dataOutput.dataIn;
        
        connection ctrlFE connect controller.ctrlFE to frontEnd.ctrl;
        connection ctrlDSP connect controller.ctrlDSP to dsp.ctrl;
    }
}
