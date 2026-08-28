package HomePNA {
    import ScalarValues::*;
    import ISQ::*;

    // Value Types
    value def Frequency :> Real { unit 'Hz'; }
    value def DataRate :> Real { unit 'Mbps'; }

    // Item Types
    item def EthernetFrame;
    item def AnalogSignal {
        ref freq : Frequency;
    }
    item def VoiceSignal {
        ref freq : Frequency;
    }

    // Ports
    port def EthernetPort {
        out ethFrameOut : EthernetFrame;
        in ethFrameIn : EthernetFrame;
    }
    port def PhoneJackPort {
        out analogOut : AnalogSignal;
        in analogIn : AnalogSignal;
    }

    // Requirements
    requirement def HomePNARequirements {
        subject transceiver : HomePNATransceiver;
        requirement convertEthernetToAnalog {
            subject transceiver;
        }
        requirement operateAboveVoiceFrequency {
            subject transceiver;
        }
        requirement preventCollisions {
            subject transceiver;
        }
    }

    // Parts
    part def NetworkDevice {
        port ethPort : EthernetPort;
    }
    part def Computer :> NetworkDevice;
    part def SmartTV :> NetworkDevice;
    part def NetworkStorage :> NetworkDevice;

    // Behaviors
    state def TransceiverBehavior {
        entry; 
        state Idle;
        state Sensing;
        state Transmitting;
        state Receiving;
        
        transition init
            first then Idle;

        transition idle_to_sensing
            from Idle
            if ethPort.ethFrameOut->notEmpty()
            then Sensing;
            
        transition sensing_to_transmitting
            from Sensing
            if phonePort.analogIn->isEmpty() 
            then Transmitting;
            
        transition sensing_to_idle
            from Sensing
            if phonePort.analogIn->notEmpty() 
            then Idle;
            
        transition transmitting_to_idle
            from Transmitting
            then Idle;
            
        transition idle_to_receiving
            from Idle
            if phonePort.analogIn->notEmpty()
            then Receiving;
            
        transition receiving_to_idle
            from Receiving
            then Idle;
    }

    part def HomePNATransceiver {
        port ethPort : EthernetPort;
        port phonePort : PhoneJackPort;
        
        attribute operatingFrequency : Frequency = 10000000 [Hz]; 
        attribute dataRate : DataRate = 100 [Mbps];
        
        exhibit transceiverState : TransceiverBehavior;
        
        action modulate {
            in frame : EthernetFrame;
            out signal : AnalogSignal;
        }
        action demodulate {
            in signal : AnalogSignal;
            out frame : EthernetFrame;
        }
    }

    part def TelephoneWiring {
        port jack1 : PhoneJackPort;
        port jack2 : PhoneJackPort;
        port jack3 : PhoneJackPort;
    }

    part def HomePNASystem {
        part computer : Computer;
        part tv : SmartTV;
        part storage : NetworkStorage;
        
        part transceiver1 : HomePNATransceiver;
        part transceiver2 : HomePNATransceiver;
        part transceiver3 : HomePNATransceiver;
        
        part wiring : TelephoneWiring;
        
        connect computer.ethPort to transceiver1.ethPort;
        connect tv.ethPort to transceiver2.ethPort;
        connect storage.ethPort to transceiver3.ethPort;
        
        connect transceiver1.phonePort to wiring.jack1;
        connect transceiver2.phonePort to wiring.jack2;
        connect transceiver3.phonePort to wiring.jack3;
    }
}
