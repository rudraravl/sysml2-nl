package CancerTherapyNanosystem {
    import ScalarValues::*;

    package ValueTypes {
        value type pH :> Real;
        value type Volume :> Real {
            unit µm3;
        }
        value type Concentration :> Real {
            unit mol_per_L;
        }
        value type Mass :> Real {
            unit µg;
        }
    }

    package Items {
        item def ChemotherapyDrug;
        item def Blood;
        item def ProteinMarker;
        item def CancerCell;
        item def HealthyTissue;
    }

    package Interfaces {
        port def DrugFlowPort {
            out item drug : Items::ChemotherapyDrug;
        }
        port def EnvironmentPort {
            in item blood : Items::Blood;
            in item marker : Items::ProteinMarker;
            in attribute localpH : ValueTypes::pH;
        }
    }

    package Requirements {
        requirement def TargetedDeliveryReq {
            doc /* Deliver drug directly to cancer cells while avoiding healthy tissue. */
        }
        requirement def PayloadProtectionReq {
            doc /* Protect drug during circulation. */
        }
        requirement def AutonomousOperationReq {
            doc /* Operate autonomously through Circulation, Targeting, Binding, Release, and Depletion phases. */
        }
        requirement def AcidicTriggerReq {
            attribute threshold : ValueTypes::pH = 6.5;
            doc /* Open and release drug when local pH is below threshold. */
        }
    }

    package Components {
        part def PolymerCore {
            attribute capacity : ValueTypes::Mass = 10 [µg];
            item storedDrug : Items::ChemotherapyDrug;
            port drugOut : Interfaces::DrugFlowPort;
            
            action def ReleasePayload {
                out item drug : Items::ChemotherapyDrug;
            }
        }
        
        part def LipidBilayerShell {
            attribute integrity : Boolean = true;
        }
        
        part def TargetingAntibody {
            port envIn : Interfaces::EnvironmentPort;
            attribute detected : Boolean = false;
            
            action def ScanEnvironment {
                in marker : Items::ProteinMarker;
                out detected : Boolean;
            }
        }
        
        part def pHResponsiveGate {
            port envIn : Interfaces::EnvironmentPort;
            port drugIn : Interfaces::DrugFlowPort;
            port drugOut : Interfaces::DrugFlowPort;
            attribute isOpen : Boolean = false;
            attribute threshold : ValueTypes::pH = 6.5;
            
            action def CheckpH {
                in pH : ValueTypes::pH;
                out open : Boolean;
            }
        }
    }

    part def SmartNanocarrier {
        attribute cancerDetected : Boolean = false;
        attribute boundToCell : Boolean = false;
        attribute payloadReleased : Boolean = false;
        
        part core : Components::PolymerCore {
            item storedDrug : Items::ChemotherapyDrug;
        }
        part shell : Components::LipidBilayerShell;
        part antibodies[4] : Components::TargetingAntibody;
        part gate : Components::pHResponsiveGate;
        
        port envPort : Interfaces::EnvironmentPort;
        port drugReleasePort : Interfaces::DrugFlowPort;
        
        connection envToAntibodies connect envPort to antibodies.envIn;
        connection envToGate connect envPort to gate.envIn;
        connection coreToGate connect core.drugOut to gate.drugIn;
        connection gateToRelease connect gate.drugOut to drugReleasePort;
        
        requirement targetReq : Requirements::TargetedDeliveryReq;
        requirement autoReq : Requirements::AutonomousOperationReq;
        requirement acidReq : Requirements::AcidicTriggerReq;
        
        state def Lifecycle {
            entry; then Circulation;
            
            state Circulation {
                do action scan {
                    // Continuously scan for cancer markers
                }
            }
            transition circ_to_target
                first Circulation
                then Targeting
                if cancerDetected;
                
            state Targeting {
                do action move {
                    // Move towards detected cancer cell
                }
            }
            transition target_to_bind
                first Targeting
                then Binding
                if boundToCell;
                
            state Binding {
                do action latch {
                    // Securely latch onto cancer cell surface
                }
            }
            transition bind_to_release
                first Binding
                then Release
                if gate.isOpen;
                
            state Release {
                do action releaseDrug {
                    // Release stored chemotherapy drug
                }
            }
            transition release_to_deplete
                first Release
                then Depletion
                if payloadReleased;
                
            state Depletion {
                // Mission complete
            }
        }
    }

    part def NanocarrierSwarm {
        part carriers[10000] : SmartNanocarrier;
        port injectionPort : Interfaces::DrugFlowPort;
    }

    part def Patient {
        part blood : Items::Blood;
        part tumor : Items::CancerCell;
        part healthyTissue : Items::HealthyTissue;
        
        part swarm : NanocarrierSwarm;
        
        connection injectDrug connect swarm.injectionPort to blood;
    }
}
