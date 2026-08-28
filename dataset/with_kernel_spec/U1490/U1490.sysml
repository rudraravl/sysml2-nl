package 'Mechanical Safety Relief System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    package Definitions {
        port def FluidPort;
        
        part def ProtectedVessel {
            out port fluidPort : FluidPort;
            attribute internalPressure : PressureValue;
        }
        
        part def DischargeSystem {
            in port fluidPort : FluidPort;
        }
        
        part def PressureSensor {
            attribute pressure : PressureValue;
        }
        
        part def ValveDisc {
            attribute position : Real;
        }
        
        part def ValveBody;
        part def SpringMechanism;
        
        part def SafetyValve {
            in port inletPort : FluidPort;
            out port outletPort : FluidPort;
            
            attribute setPressure : PressureValue;
            attribute blowdownPressure : PressureValue;
            attribute ratedCapacity : VolumetricFlowRateValue;
            
            part body : ValveBody;
            part pressureSensor : PressureSensor;
            part valveDisc : ValveDisc;
            part springMechanism : SpringMechanism;
            
            exhibit state 'valve states' : 'Valve States';
        }
        
        state def 'Valve States';
        
        action def 'Vent Fluid' {
            out flowRate : VolumetricFlowRateValue;
        }
        
        action def 'Lift Disc';
        action def 'Seat Disc';
    }
    
    package Requirements {
        private import Definitions::*;
        
        requirement def 'Overpressure Protection Requirement' {
            subject safetyValve : SafetyValve;
            doc /* 
             * The safety valve shall vent excess pressure when the vessel pressure exceeds the set pressure, 
             * and shall reseat when the pressure drops below the blowdown pressure. 
             */
        }
        
        requirement def 'Automatic Reseating Requirement' {
            subject safetyValve : SafetyValve;
            doc /*
             * The safety valve shall automatically reseat to fully closed without manual intervention
             * once the pressure drops below the blowdown pressure.
             */
        }
    }
    
    package Usages {
        private import Definitions::*;
        private import Requirements::*;
        
        action 'lift disc' : 'Lift Disc';
        action 'seat disc' : 'Seat Disc';
        action 'vent fluid' : 'Vent Fluid';
        
        part safetyReliefSystem {
            part protectedVessel : ProtectedVessel;
            part safetyValve : SafetyValve {
                attribute setPressure = 10000000 [Pa];
                attribute blowdownPressure = 8000000 [Pa];
                attribute ratedCapacity = 0.1 [m^3/s];
                
                state 'valve states' : 'Valve States' {
                    entry; then fullyClosed;
                    
                    state fullyClosed;
                    accept when pressureSensor.pressure >= setPressure
                        do 'lift disc'
                        then opening;
                        
                    state opening;
                    accept after 0.5 [s]
                        then fullyOpen;
                        
                    state fullyOpen {
                        do 'vent fluid';
                    }
                    accept when pressureSensor.pressure <= blowdownPressure
                        do 'seat disc'
                        then closing;
                        
                    state closing;
                    accept after 0.5 [s]
                        then fullyClosed;
                }
            }
            part dischargeSystem : DischargeSystem;
            
            connect protectedVessel.fluidPort to safetyValve.inletPort;
            connect safetyValve.outletPort to dischargeSystem.fluidPort;
        }
        
        requirement 'overpressure protection' : 'Overpressure Protection Requirement' {
            subject safetyValve = safetyReliefSystem.safetyValve;
        }
        
        requirement 'automatic reseating' : 'Automatic Reseating Requirement' {
            subject safetyValve = safetyReliefSystem.safetyValve;
        }
    }
}
