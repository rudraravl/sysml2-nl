package GastricDecompressionSystem {
    import ScalarValues::*;

    unit mmHg;
    unit mL;
    unit mL_per_hr;

    attribute def PressureValue :> Real {
        unit mmHg;
    }
    attribute def VolumeValue :> Real {
        unit mL;
    }
    attribute def FlowRateValue :> Real {
        unit mL_per_hr;
    }

    item def GastricFluid;
    item def Air;
    item def Saline;

    port def SuctionPort {
        out item fluid: GastricFluid;
        in item vacuum: Air;
    }
    
    port def VentPort {
        in item ambientAir: Air;
        out item stomachAir: Air;
    }
    
    port def IrrigationPort {
        out item saline: Saline;
    }

    part def ReplogleTube {
        port suctionLumen: SuctionPort;
        port ventLumen: VentPort;
        port irrigationAccess: IrrigationPort;
        
        attribute tipOpenings: Integer = 5;
        
        part def Lumen {
            attribute diameter: Real;
        }
        
        part suctionChannel: Lumen {
            attribute diameter = 4.0;
        }
        part ventChannel: Lumen {
            attribute diameter = 2.0;
        }
    }

    part def SuctionApparatus {
        port suctionConnection: SuctionPort;
        
        attribute currentPressure: PressureValue;
        attribute minSafePressure: PressureValue = 40.0;
        attribute maxSafePressure: PressureValue = 80.0;
        
        part pressureRegulator {
            attribute regulatedPressure: PressureValue;
        }
        
        part collectionContainer {
            attribute capacity: VolumeValue = 1000.0;
            attribute currentVolume: VolumeValue = 0.0;
        }
        
        action generateVacuum {
            out pressure: PressureValue;
        }
    }

    part def IrrigationSystem {
        port irrigationConnection: IrrigationPort;
        
        attribute salineVolume: VolumeValue = 10.0;
        attribute flushRate: FlowRateValue = 30.0;
        
        action flushTube {
            in volume: VolumeValue;
            out saline: Saline;
        }
    }

    part def GastricDecompressionSystem {
        part replogleTube: ReplogleTube;
        part suctionApparatus: SuctionApparatus;
        part irrigationSystem: IrrigationSystem;
        
        connection suctionLine connect suctionApparatus.suctionConnection to replogleTube.suctionLumen;
        connection irrigationLine connect irrigationSystem.irrigationConnection to replogleTube.irrigationAccess;
        
        attribute ventBlocked: Boolean = false;
        
        state def VentMonitoring {
            state Patent;
            state Blocked;
            state Irrigating;
            
            transition patent_to_blocked
                first Patent
                if ventBlocked == true
                then Blocked;
                
            transition blocked_to_irrigating
                first Blocked
                then Irrigating;
                
            transition irrigating_to_patent
                first Irrigating
                if ventBlocked == false
                then Patent;
        }
        
        action def MonitorVentPatency {
            out isBlocked: Boolean;
        }
        
        action def InitiateIrrigationCycle {
            in blocked: Boolean;
            out irrigationTriggered: Boolean;
        }
        
        exhibit behavior {
            action monitorVent: MonitorVentPatency;
            action irrigate: InitiateIrrigationCycle;
            
            flow monitorVent.isBlocked to irrigate.blocked;
        }
    }

    requirement def SafeSuctionPressureRequirement {
        subject suctionApp: SuctionApparatus;
        requirement {
            doc /* The suction apparatus must maintain pressure between 40 and 80 mmHg */
            constraint { 40.0 <= suctionApp.currentPressure <= 80.0 }
        }
    }
    
    requirement def ContinuousDecompressionRequirement {
        subject system: GastricDecompressionSystem;
        requirement {
            doc /* The system must continuously remove fluids and air */
            constraint { system.suctionApparatus.currentPressure > 0.0 }
        }
    }
    
    requirement def VentPatencyRequirement {
        subject system: GastricDecompressionSystem;
        requirement {
            doc /* The system must monitor vent patency and initiate irrigation if blocked */
            constraint { system.ventBlocked == true implies system.irrigationSystem.salineVolume > 0.0 }
        }
    }
}
