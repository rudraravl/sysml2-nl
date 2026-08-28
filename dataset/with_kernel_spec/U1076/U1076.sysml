package HomePNA_System {
    private import ScalarValues::*;
    
    item def EthernetFrame;
    item def PhoneSignal {
        attribute frequency: Real;
        attribute modulatedFrame: EthernetFrame;
    }
    
    port def EthernetPort {
        in item rxFrame: EthernetFrame;
        out item txFrame: EthernetFrame;
    }
    
    port def PhoneLinePort {
        in item rxSignal: PhoneSignal;
        out item txSignal: PhoneSignal;
    }
    
    part def NetworkDevice {
        port ethPort: ~EthernetPort;
    }
    
    part def Computer :> NetworkDevice;
    part def SmartTV :> NetworkDevice;
    part def NetworkStorage :> NetworkDevice;
    
    part def HomePNATransceiver {
        attribute operatingFrequency: Real = 7.0;
        attribute lineIsBusy: Boolean = false;
        attribute backoffDuration: Real = 50.0;
        
        port ethPort: EthernetPort;
        port phonePort: PhoneLinePort;
        
        action checkLine;
        action waitBackoff;
        action modulate;
        action demodulate;
        action transmitFrame;
        action receiveFrame;
        
        exhibit state transceiverBehavior {
            entry; then Idle;
            state Idle;
            transition startTx
                first Idle
                accept frame : EthernetFrame via ethPort
                then CarrierSense;
            transition receiveSignal
                first Idle
                accept signal : PhoneSignal via phonePort
                then Receiving;
            state CarrierSense {
                do checkLine;
            }
            transition lineBusy
                first CarrierSense
                if lineIsBusy
                do waitBackoff
                then WaitBackoff;
            transition lineClear
                first CarrierSense
                if !lineIsBusy
                do transmitFrame
                then Transmitting;
            state WaitBackoff;
            transition retry
                first WaitBackoff
                then CarrierSense;
            state Transmitting;
            transition transmissionDone
                first Transmitting
                then Idle;
            state Receiving {
                do receiveFrame;
            }
            transition receiveDone
                first Receiving
                then Idle;
        }
    }
    
    part def TelephoneWallJack {
        port linePort: ~PhoneLinePort;
    }
    
    part def TelephoneWiring {
        port jackPort1: PhoneLinePort;
        port jackPort2: PhoneLinePort;
        port jackPort3: PhoneLinePort;
    }
    
    requirement def TransmitEthernetOverPhoneLine {
        doc /* The system shall transmit Ethernet data over existing telephone wiring. */
    }
    
    requirement def CoexistWithVoice {
        doc /* The system shall operate at frequencies above voice band to avoid interference. */
        attribute minFrequency: Real = 4.0;
    }
    
    requirement def CollisionAvoidance {
        doc /* Transceivers shall use listen-before-talk to prevent collisions. */
    }
    
    part homePNA {
        part computer: Computer;
        part tv: SmartTV;
        part storage: NetworkStorage;
        
        part transceiver1: HomePNATransceiver;
        part transceiver2: HomePNATransceiver;
        part transceiver3: HomePNATransceiver;
        
        part jack1: TelephoneWallJack;
        part jack2: TelephoneWallJack;
        part jack3: TelephoneWallJack;
        
        part wiring: TelephoneWiring;
        
        connect computer.ethPort to transceiver1.ethPort;
        connect tv.ethPort to transceiver2.ethPort;
        connect storage.ethPort to transceiver3.ethPort;
        
        connect transceiver1.phonePort to jack1.linePort;
        connect transceiver2.phonePort to jack2.linePort;
        connect transceiver3.phonePort to jack3.linePort;
        
        connect jack1.linePort to wiring.jackPort1;
        connect jack2.linePort to wiring.jackPort2;
        connect jack3.linePort to wiring.jackPort3;
    }
    
    satisfy TransmitEthernetOverPhoneLine by homePNA;
    satisfy CoexistWithVoice by homePNA;
    satisfy CollisionAvoidance by homePNA;
}
