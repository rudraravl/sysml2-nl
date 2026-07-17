package PotentialEnergyStorageSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    
    package Definitions {
        attribute def ControlCommand;
        attribute def PositionCommand;
        attribute def ReleaseSignal;
        
        item def MechanicalForce {
            attribute force : ISQ::ForceValue;
            attribute displacement : ISQ::LengthValue;
        }
        
        item def KineticOutput {
            attribute velocity : ISQ::SpeedValue;
            attribute energy : ISQ::EnergyValue;
        }
        
        port def MechanicalInputPort {
            in force : ISQ::ForceValue;
            in displacement : ISQ::LengthValue;
        }
        
        port def EnergyOutputPort {
            out power : ISQ::PowerValue;
            out velocity : ISQ::SpeedValue;
        }
        
        port def ControlPort {
            in command : ControlCommand;
            out status : Real;
        }
        
        part def LiftingMechanism {
            attribute currentHeight : ISQ::LengthValue;
            attribute maxHeight : ISQ::LengthValue;
            port mechanicalInput : MechanicalInputPort;
            port controlInterface : ControlPort;
        }
        
        part def MassBlock {
            attribute mass : ISQ::MassValue;
            attribute position : ISQ::LengthValue;
            attribute potentialEnergy : ISQ::EnergyValue;
        }
        
        part def ReleaseController {
            attribute releaseThreshold : ISQ::EnergyValue;
            port controlOutput : ControlPort;
        }
        
        part def PowerConverter {
            attribute efficiency : Real;
            port mechanicalInput : MechanicalInputPort;
            port electricalOutput : EnergyOutputPort;
        }
        
        action def LiftMass {
            in appliedForce : ISQ::ForceValue;
            in liftDistance : ISQ::LengthValue;
            in massValue : ISQ::MassValue;
            in gravity : ISQ::AccelerationValue;
            out gainedPotentialEnergy : ISQ::EnergyValue;
            out finalHeight : ISQ::LengthValue;
        }
        
        action def CalculatePotentialEnergy {
            in mass : ISQ::MassValue;
            in height : ISQ::LengthValue;
            in gravitationalAcceleration : ISQ::AccelerationValue;
            out potentialEnergy : ISQ::EnergyValue;
        }
        
        action def ReleaseMass {
            in storedEnergy : ISQ::EnergyValue;
            in currentHeight : ISQ::LengthValue;
            in mass : ISQ::MassValue;
            in gravity : ISQ::AccelerationValue;
            out kineticEnergy : ISQ::EnergyValue;
            out velocity : ISQ::SpeedValue;
            out outputPower : ISQ::PowerValue;
        }
        
        action def MonitorEnergyLevel {
            in currentEnergy : ISQ::EnergyValue;
            in targetEnergy : ISQ::EnergyValue;
            out isCharged : Boolean;
            out chargePercentage : Real;
        }
        
        action def ConvertToElectricity {
            in mechanicalPower : ISQ::PowerValue;
            in efficiency : Real;
            out electricalPower : ISQ::PowerValue;
        }
    }
    
    package Requirements {
        requirement def PrimaryEnergyStorageFunction {
            doc /* The system shall store mechanical energy as gravitational potential energy 
                 * by elevating mass against gravity and release it on demand to generate power. */
        }
        
        requirement <'REQ-PE-001'> energyStorageCapacity {
            doc /* The system shall store at least 500 kJ of potential energy at maximum elevation. */
            subject system : Architecture::gravitationalEnergySystem;
        }
        
        requirement <'REQ-PE-002'> elevationHeight {
            doc /* The mass shall be elevated to a minimum height of 50 meters to achieve required energy storage. */
            subject liftMech : Architecture::GravitationalEnergySystem::liftingMechanism;
        }
        
        requirement <'REQ-PE-003'> powerDelivery {
            doc /* The system shall deliver electrical power output during energy release phase. */
            subject converter : Architecture::GravitationalEnergySystem::powerConverter;
        }
        
        requirement <'REQ-PE-004'> controlledRelease {
            doc /* The system shall release stored energy only upon receiving authorized release command. */
            subject controller : Architecture::GravitationalEnergySystem::releaseController;
        }
    }
    
    package Architecture {
        part def GravitationalEnergySystem {
            attribute totalStoredEnergy : ISQ::EnergyValue;
            attribute gravitationalConstant : ISQ::AccelerationValue;
            attribute systemEfficiency : Real;
            
            part liftingMechanism : Definitions::LiftingMechanism;
            part massBlock : Definitions::MassBlock;
            part releaseController : Definitions::ReleaseController;
            part powerConverter : Definitions::PowerConverter;
            
            port gridConnection : Definitions::EnergyOutputPort;
            port operatorControl : Definitions::ControlPort;
        }
        
        part gravitationalEnergySystem : GravitationalEnergySystem {
            attribute totalStoredEnergy = 490500.0;
            attribute gravitationalConstant = 9.81;
            attribute systemEfficiency = 0.85;
            
            part liftingMechanism : Definitions::LiftingMechanism {
                attribute currentHeight = 0.0;
                attribute maxHeight = 50.0;
            }
            
            part massBlock : Definitions::MassBlock {
                attribute mass = 1000.0;
                attribute position = 0.0;
                attribute potentialEnergy = 0.0;
            }
            
            part releaseController : Definitions::ReleaseController {
                attribute releaseThreshold = 450000.0;
            }
            
            part powerConverter : Definitions::PowerConverter {
                attribute efficiency = 0.85;
            }
        }
    }
    
    package Behaviors {
        state def SystemOperationStates {
            entry; then idle;
            
            state idle;
            accept chargeCommand;
            then charging;
            
            state charging;
            accept targetHeightReached;
            then charged;
            
            state charged;
            accept releaseCommand;
            then discharging;
            
            state discharging;
            accept energyDepleted;
            then idle;
        }
        
        action def OperateEnergySystem {
            in chargeCmd : Definitions::ControlCommand;
            in releaseCmd : Definitions::ReleaseSignal;
            out deliveredPower : ISQ::PowerValue;
            
            first start;
            then merge continueOperation;
            
            then action monitorStatus : Definitions::MonitorEnergyLevel {
                in currentEnergy : ISQ::EnergyValue;
                in targetEnergy : ISQ::EnergyValue;
                out isCharged : Boolean;
                out chargePercentage : Real;
            }
            
            then decide;
                if monitorStatus.isCharged == false then performCharging;
                if monitorStatus.isCharged == true then holdCharge;
            
            action performCharging {
                action liftMass : Definitions::LiftMass {
                    in appliedForce : ISQ::ForceValue;
                    in liftDistance : ISQ::LengthValue;
                    in massValue : ISQ::MassValue;
                    in gravity : ISQ::AccelerationValue;
                    out gainedPotentialEnergy : ISQ::EnergyValue;
                    out finalHeight : ISQ::LengthValue;
                }
                
                flow liftMass.gainedPotentialEnergy to calculateEnergy.potentialEnergy;
                
                then action calculateEnergy : Definitions::CalculatePotentialEnergy {
                    in mass : ISQ::MassValue;
                    in height : ISQ::LengthValue;
                    in gravitationalAcceleration : ISQ::AccelerationValue;
                    out potentialEnergy : ISQ::EnergyValue;
                }
            }
            then continueOperation;
            
            action holdCharge {
                accept release : Definitions::ReleaseSignal;
                
                then action releaseMass : Definitions::ReleaseMass {
                    in storedEnergy : ISQ::EnergyValue;
                    in currentHeight : ISQ::LengthValue;
                    in mass : ISQ::MassValue;
                    in gravity : ISQ::AccelerationValue;
                    out kineticEnergy : ISQ::EnergyValue;
                    out velocity : ISQ::SpeedValue;
                    out outputPower : ISQ::PowerValue;
                }
                
                flow releaseMass.outputPower to convertPower.mechanicalPower;
                
                then action convertPower : Definitions::ConvertToElectricity {
                    in mechanicalPower : ISQ::PowerValue;
                    in efficiency : Real;
                    out electricalPower : ISQ::PowerValue;
                }
                
                flow convertPower.electricalPower to deliveredPower;
            }
            
            then done;
        }
    }
    
    package SystemIntegration {
        part energyStorageSystem : Architecture::GravitationalEnergySystem {
            exhibit state operationStateMachine : Behaviors::SystemOperationStates;
            
            perform action systemOperation : Behaviors::OperateEnergySystem {
                in chargeCmd : Definitions::ControlCommand;
                in releaseCmd : Definitions::ReleaseSignal;
                out deliveredPower : ISQ::PowerValue;
            }
        }
        
        satisfy Requirements::PrimaryEnergyStorageFunction by energyStorageSystem;
        satisfy Requirements::energyStorageCapacity by energyStorageSystem;
        satisfy Requirements::elevationHeight by energyStorageSystem.liftingMechanism;
        satisfy Requirements::powerDelivery by energyStorageSystem.powerConverter;
        satisfy Requirements::controlledRelease by energyStorageSystem.releaseController;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import PotentialEnergyStorageSystem::*;

    part testSubject : LiftingMechanism {
        exhibit state sm : SystemOperationStates;
    }

    action orchestrator {
        attribute testAppliedForce : ISQ::ForceValue;
        attribute testLiftDistance : ISQ::LengthValue;
        attribute testMassValue : ISQ::MassValue;
        attribute testGravity : ISQ::AccelerationValue;
        action liftMassProbe : Definitions {
            in appliedForce = testAppliedForce;
            in liftDistance = testLiftDistance;
            in massValue = testMassValue;
            in gravity = testGravity;
        }
        first liftMassProbe;
    }
}
