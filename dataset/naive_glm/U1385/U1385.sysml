package BicyclePumpSystem {
    import ISQ::*;
    import ScalarValues::*;
    
    attribute def Pressure :> Real { unit 'kPa'; }
    attribute def Volume :> Real { unit 'm3'; }
    attribute def Force :> Real { unit 'N'; }
    attribute def Length :> Real { unit 'm'; }
    
    item def Air;
    
    port def AirPort {
        out item air: Air;
        in attribute pressure: Pressure;
    }
    
    part def Handle {
        attribute appliedForce: Force;
    }
    
    part def Piston {
        attribute position: Length;
    }
    
    part def Cylinder {
        attribute internalVolume: Volume;
        attribute internalPressure: Pressure;
        attribute topPosition: Length;
        attribute bottomPosition: Length;
        port intakePort: AirPort;
        port outletPort: AirPort;
    }
    
    part def CheckValve {
        attribute isOpen: Boolean = false;
        port inlet: AirPort;
        port outlet: AirPort;
    }
    
    part def Hose {
        port inlet: AirPort;
        port outlet: AirPort;
    }
    
    requirement def PumpPerformanceRequirements {
        subject pump : ManualBicyclePump;
        
        requirement deliverPressure {
            doc /* The pump must be able to deliver air at a pressure of at least 400 kPa. */
            constraint { pump.outletPressure >= 400 }
        }
        
        requirement valveExclusivity {
            doc /* The intake and outlet valves must never be open at the same time. */
            constraint { pump.intakeValve.isOpen == false or pump.outletValve.isOpen == false }
        }
    }
    
    part def ManualBicyclePump {
        part handle: Handle;
        part piston: Piston;
        part cylinder: Cylinder;
        part intakeValve: CheckValve;
        part outletValve: CheckValve;
        part hose: Hose;
        
        attribute outletPressure: Pressure;
        
        port atmosphereIn: AirPort;
        port targetOut: AirPort;
        
        connection intakeConnection connect atmosphereIn to intakeValve.inlet;
        connection valveToCylinder connect intakeValve.outlet to cylinder.intakePort;
        connection cylinderToValve connect cylinder.outletPort to outletValve.inlet;
        connection valveToHose connect outletValve.outlet to hose.inlet;
        connection hoseToTarget connect hose.outlet to targetOut;
        
        state def PumpingCycle {
            entry; then Upstroke;
            
            state Upstroke {
                entry { 
                    intakeValve.isOpen = true; 
                    outletValve.isOpen = false; 
                }
                do {
                    piston.position = piston.position + 0.01;
                }
            }
            
            transition from Upstroke to Downstroke when piston.position >= cylinder.topPosition;
            
            state Downstroke {
                entry { 
                    intakeValve.isOpen = false; 
                    outletValve.isOpen = true; 
                }
                do {
                    piston.position = piston.position - 0.01;
                }
            }
            
            transition from Downstroke to Upstroke when piston.position <= cylinder.bottomPosition;
        }
        
        satisfy PumpPerformanceRequirements;
    }
    
    part def Atmosphere {
        port airSupply: AirPort;
    }
    
    part def InflatableTarget {
        port airInlet: AirPort;
    }
    
    part def BicyclePumpSystem {
        part atmosphere: Atmosphere;
        part pump: ManualBicyclePump;
        part target: InflatableTarget;
        
        connection atmosphereToPump connect atmosphere.airSupply to pump.atmosphereIn;
        connection pumpToTarget connect pump.targetOut to target.airInlet;
    }
}
