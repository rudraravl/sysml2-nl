package OmmayaReservoir {
    import ScalarValues::*;

    value type Volume :> Real { unit "mL"; }
    value type Pressure :> Real { unit "mmHg"; }
    value type PunctureCount :> Integer { unit "1"; }
    value type FlowRate :> Real { unit "mL/min"; }
    value type Length :> Real { unit "mm"; }

    item def Fluid;
    item def CSF :> Fluid;
    item def Medication :> Fluid;

    port def FluidPort {
        out item fluidOut : Fluid;
        in item fluidIn : Fluid;
    }

    part def SelfSealingSeptum {
        attribute maxPunctures : PunctureCount = 200;
        attribute currentPunctures : PunctureCount = 0;
        attribute isSealed : Boolean = true;
        attribute needleInserted : Boolean = false;
        
        port def PuncturePort {
            in item needleAccess;
        }
        port puncturePort : PuncturePort;
    }

    part def ReservoirDome {
        attribute capacity : Volume = 2.0 [mL];
        attribute currentVolume : Volume = 0.0 [mL];
        attribute fluidInFlow : Boolean = false;
        attribute fluidOutFlow : Boolean = false;
        
        port fluidPort : FluidPort;
        
        part septum : SelfSealingSeptum;
    }

    part def VentricularCatheter {
        attribute length : Length = 100.0 [mm];
        attribute innerDiameter : Length = 1.0 [mm];
        attribute isPatent : Boolean = true;
        
        port proximalPort : FluidPort;
        port distalPort : FluidPort;
    }

    part def OmmayaReservoirSystem {
        part dome : ReservoirDome;
        part catheter : VentricularCatheter;
        
        connection dome.fluidPort to catheter.proximalPort;
        
        exhibit state machine OmmayaReservoirStateMachine {
            state sealed;
            state accessed;
            state delivering;
            state sampling;
            
            transition sealed -> accessed when dome.septum.needleInserted;
            transition accessed -> delivering when dome.fluidInFlow;
            transition delivering -> accessed when !dome.fluidInFlow;
            transition accessed -> sampling when dome.fluidOutFlow;
            transition sampling -> accessed when !dome.fluidOutFlow;
            transition accessed -> sealed when !dome.septum.needleInserted;
        }
    }

    requirement def BiocompatibilityRequirement {
        subject system : OmmayaReservoirSystem;
        requirement {
            doc "The system must be made of biocompatible materials suitable for long-term implantation."
        }
    }

    requirement def PunctureResistanceRequirement {
        subject septum : SelfSealingSeptum;
        requirement {
            doc "The septum must withstand at least 200 punctures without compromising integrity."
            constraint { septum.maxPunctures >= 200 }
        }
    }

    requirement def PatencyRequirement {
        subject catheter : VentricularCatheter;
        requirement {
            doc "The catheter must remain unblocked (patent) to allow for fluid flow."
            constraint { catheter.isPatent == true }
        }
    }
}
