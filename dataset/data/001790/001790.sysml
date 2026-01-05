package GravitationalEnergyStorageSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    package ValueDefinitions {
        attribute def PotentialEnergy :> EnergyValue;
        attribute def KineticEnergy :> EnergyValue;
        attribute def ElevationHeight :> LengthValue;
        attribute def MassWeight :> MassValue;
        attribute def GravityConstant :> AccelerationValue;
        attribute def EfficiencyRatio :> Real;
        
        enum def OperationMode {
            enum charging;
            enum discharging;
            enum standby;
        }
        
        item def ControlCommand {
            attribute mode : OperationMode;
            attribute targetPower : PowerValue;
        }
        
        item def EnergyFlow {
            attribute power : PowerValue;
            attribute direction : Real;
        }
    }

    package PortDefinitions {
        port def ElectricalPort {
            inout electricalFlow : ValueDefinitions::EnergyFlow;
        }
        
        port def MechanicalPort {
            inout mechanicalForce : ForceValue;
        }
        
        port def ControlPort {
            in command : ValueDefinitions::ControlCommand;
            out status : ValueDefinitions::OperationMode;
        }
    }

    package ComponentDefinitions {
        part def MassBlock {
            attribute mass : ValueDefinitions::MassWeight;
            attribute currentHeight : ValueDefinitions::ElevationHeight;
            attribute maxHeight : ValueDefinitions::ElevationHeight;
            attribute minHeight : ValueDefinitions::ElevationHeight;
            attribute storedEnergy : ValueDefinitions::PotentialEnergy;
        }
        
        part def HoistingMechanism {
            port mechanical : PortDefinitions::MechanicalPort;
            port electrical : PortDefinitions::ElectricalPort;
            attribute liftingCapacity : ForceValue;
            attribute motorEfficiency : ValueDefinitions::EfficiencyRatio;
            attribute ratedPower : PowerValue;
        }
        
        part def Generator {
            port mechanical : PortDefinitions::MechanicalPort;
            port electrical : PortDefinitions::ElectricalPort;
            attribute generationEfficiency : ValueDefinitions::EfficiencyRatio;
            attribute ratedOutput : PowerValue;
        }
        
        part def PowerConverter {
            port gridSide : PortDefinitions::ElectricalPort;
            port machineSide : PortDefinitions::ElectricalPort;
            attribute conversionEfficiency : ValueDefinitions::EfficiencyRatio;
        }
        
        part def SystemController {
            port control : PortDefinitions::ControlPort;
            attribute currentMode : ValueDefinitions::OperationMode;
            attribute targetHeight : ValueDefinitions::ElevationHeight;
        }
    }

    package BehaviorDefinitions {
        action def CalculatePotentialEnergy {
            in mass : ValueDefinitions::MassWeight;
            in height : ValueDefinitions::ElevationHeight;
            in gravity : ValueDefinitions::GravityConstant;
            out energy : ValueDefinitions::PotentialEnergy;
        }
        
        action def LiftMass {
            in targetHeight : ValueDefinitions::ElevationHeight;
            in currentHeight : ValueDefinitions::ElevationHeight;
            in liftForce : ForceValue;
            out heightChange : ValueDefinitions::ElevationHeight;
        }
        
        action def LowerMass {
            in currentHeight : ValueDefinitions::ElevationHeight;
            in targetHeight : ValueDefinitions::ElevationHeight;
            out releasedEnergy : ValueDefinitions::KineticEnergy;
        }
        
        action def ConvertMechanicalToElectrical {
            in mechanicalEnergy : ValueDefinitions::KineticEnergy;
            in efficiency : ValueDefinitions::EfficiencyRatio;
            out electricalPower : PowerValue;
        }
        
        action def StoreEnergy {
            in inputPower : PowerValue;
            out heightIncrease : ValueDefinitions::ElevationHeight;
        }
        
        action def ReleaseEnergy {
            in demandPower : PowerValue;
            out outputPower : PowerValue;
        }
        
        action def ManageEnergyStorage {
            in command : ValueDefinitions::ControlCommand;
            in heightCurrent : ValueDefinitions::ElevationHeight;
            in heightMax : ValueDefinitions::ElevationHeight;
            in heightMin : ValueDefinitions::ElevationHeight;
            out deliveredPower : PowerValue;
            
            first start;
            then merge controlLoop;
            
            then action evaluateCommand {
                in cmd : ValueDefinitions::ControlCommand = command;
                out mode : ValueDefinitions::OperationMode;
            }
            
            then decide;
                if evaluateCommand.mode == ValueDefinitions::OperationMode::charging 
                    and heightCurrent < heightMax then chargeAction;
                if evaluateCommand.mode == ValueDefinitions::OperationMode::discharging 
                    and heightCurrent > heightMin then dischargeAction;
                if evaluateCommand.mode == ValueDefinitions::OperationMode::standby then standbyAction;
            
            action chargeAction {
                action store : StoreEnergy {
                    in inputPower : PowerValue = command.targetPower;
                    out heightIncrease : ValueDefinitions::ElevationHeight;
                }
                then action updateHeight {
                    doc /* Increment mass height based on energy input. */
                }
            }
            then controlLoop;
            
            action dischargeAction {
                action release : ReleaseEnergy {
                    in demandPower : PowerValue = command.targetPower;
                    out outputPower : PowerValue;
                }
                flow release.outputPower to convert.mechanicalEnergy;
                
                then action convert : ConvertMechanicalToElectrical {
                    in mechanicalEnergy : ValueDefinitions::KineticEnergy;
                    in efficiency : ValueDefinitions::EfficiencyRatio = 0.88;
                    out electricalPower : PowerValue;
                }
                then action deliverPower {
                    deliveredPower = convert.electricalPower;
                }
            }
            then controlLoop;
            
            action standbyAction {
                doc /* System maintains current state without active energy transfer. */
            }
            then controlLoop;
        }
        
        state def SystemOperationStates {
            in heightCurrent : ValueDefinitions::ElevationHeight;
            in heightMax : ValueDefinitions::ElevationHeight;
            in heightMin : ValueDefinitions::ElevationHeight;
            
            entry; then idle;
            
            state idle {
                doc /* System is inactive, mass at rest position. */
            }
            
            transition idle_to_charging
                first idle
                accept cmd : ValueDefinitions::ControlCommand
                if cmd.mode == ValueDefinitions::OperationMode::charging
                then charging;
            
            state charging {
                doc /* Consuming electrical power to lift mass and store potential energy. */
                entry action initiateLifting : LiftMass;
            }
            
            transition charging_to_storing
                first charging
                if heightCurrent >= heightMax * 0.95
                then storing;
            
            transition charging_to_idle
                first charging
                accept cmd : ValueDefinitions::ControlCommand
                if cmd.mode == ValueDefinitions::OperationMode::standby
                then idle;
            
            state storing {
                doc /* Mass elevated to maximum height, energy fully stored. */
            }
            
            transition storing_to_discharging
                first storing
                accept cmd : ValueDefinitions::ControlCommand
                if cmd.mode == ValueDefinitions::OperationMode::discharging
                then discharging;
            
            state discharging {
                doc /* Lowering mass to generate electrical power from potential energy. */
                entry action initiateLowering : LowerMass;
                do action generatePower : ConvertMechanicalToElectrical;
            }
            
            transition discharging_to_idle
                first discharging
                if heightCurrent <= heightMin * 1.05
                then idle;
            
            transition discharging_to_storing
                first discharging
                accept cmd : ValueDefinitions::ControlCommand
                if cmd.mode == ValueDefinitions::OperationMode::charging
                then storing;
        }
    }

    package SystemArchitecture {
        part gravitationalStorageSystem {
            doc /* 
             * A gravitational energy storage system that stores electrical energy by 
             * lifting a massive weight to an elevated position, converting electrical 
             * energy into gravitational potential energy. When energy is needed, the 
             * mass is lowered in a controlled manner, driving a generator to convert 
             * the potential energy back into electrical power for delivery to the grid.
             */
            
            port gridConnection : PortDefinitions::ElectricalPort;
            port systemControl : PortDefinitions::ControlPort;
            
            attribute gravityAcceleration : ValueDefinitions::GravityConstant = 9.81;
            attribute systemMass : ValueDefinitions::MassWeight = 500000.0;
            attribute operationalHeight : ValueDefinitions::ElevationHeight = 120.0;
            attribute totalCapacity : ValueDefinitions::PotentialEnergy;
            
            part massBlock : ComponentDefinitions::MassBlock {
                attribute mass : ValueDefinitions::MassWeight = systemMass;
                attribute currentHeight : ValueDefinitions::ElevationHeight = 60.0;
                attribute maxHeight : ValueDefinitions::ElevationHeight = operationalHeight;
                attribute minHeight : ValueDefinitions::ElevationHeight = 5.0;
                attribute storedEnergy : ValueDefinitions::PotentialEnergy = 
                    mass * gravityAcceleration * currentHeight;
            }
            
            part hoistingSystem : ComponentDefinitions::HoistingMechanism {
                port mechanical : PortDefinitions::MechanicalPort;
                port electrical : PortDefinitions::ElectricalPort;
                attribute liftingCapacity : ForceValue = 6000000.0;
                attribute motorEfficiency : ValueDefinitions::EfficiencyRatio = 0.92;
                attribute ratedPower : PowerValue = 5000000.0;
            }
            
            part generatorUnit : ComponentDefinitions::Generator {
                port mechanical : PortDefinitions::MechanicalPort;
                port electrical : PortDefinitions::ElectricalPort;
                attribute generationEfficiency : ValueDefinitions::EfficiencyRatio = 0.88;
                attribute ratedOutput : PowerValue = 4500000.0;
            }
            
            part powerElectronics : ComponentDefinitions::PowerConverter {
                port gridSide : PortDefinitions::ElectricalPort;
                port machineSide : PortDefinitions::ElectricalPort;
                attribute conversionEfficiency : ValueDefinitions::EfficiencyRatio = 0.96;
            }
            
            part controller : ComponentDefinitions::SystemController {
                port control : PortDefinitions::ControlPort;
                attribute currentMode : ValueDefinitions::OperationMode = 
                    ValueDefinitions::OperationMode::standby;
                attribute targetHeight : ValueDefinitions::ElevationHeight = 100.0;
            }
            
            connect gridConnection to powerElectronics.gridSide;
            connect powerElectronics.machineSide to hoistingSystem.electrical;
            connect powerElectronics.machineSide to generatorUnit.electrical;
            connect systemControl to controller.control;
            
            perform action energyManagement : BehaviorDefinitions::ManageEnergyStorage {
                in command : ValueDefinitions::ControlCommand;
                in heightCurrent : ValueDefinitions::ElevationHeight = massBlock.currentHeight;
                in heightMax : ValueDefinitions::ElevationHeight = massBlock.maxHeight;
                in heightMin : ValueDefinitions::ElevationHeight = massBlock.minHeight;
                out deliveredPower : PowerValue;
            }
            
            exhibit state operationalBehavior : BehaviorDefinitions::SystemOperationStates {
                in heightCurrent : ValueDefinitions::ElevationHeight = massBlock.currentHeight;
                in heightMax : ValueDefinitions::ElevationHeight = massBlock.maxHeight;
                in heightMin : ValueDefinitions::ElevationHeight = massBlock.minHeight;
            }
        }
    }

    package SystemRequirements {
        requirement <'GES-REQ-001'> energyStorageCapability {
            doc /* 
             * The system shall store energy by converting electrical power into 
             * gravitational potential energy through mass elevation.
             */
            subject system : SystemArchitecture::gravitationalStorageSystem;
            assert constraint {
                system.massBlock.storedEnergy >= 0.0
            }
        }
        
        requirement <'GES-REQ-002'> minimumStorageCapacity {
            doc /* 
             * The system shall provide minimum energy storage capacity of 150 MWh 
             * based on mass elevation to maximum height.
             */
            subject system : SystemArchitecture::gravitationalStorageSystem;
            assert constraint {
                system.massBlock.mass * system.gravityAcceleration * 
                system.massBlock.maxHeight >= 540000000000.0
            }
        }
        
        requirement <'GES-REQ-003'> powerDeliveryRate {
            doc /* 
             * The system shall deliver continuous electrical power output of at least 
             * 4 MW during discharge operation.
             */
            subject system : SystemArchitecture::gravitationalStorageSystem;
            assert constraint {
                system.generatorUnit.ratedOutput >= 4000000.0
            }
        }
        
        requirement <'GES-REQ-004'> roundTripEfficiency {
            doc /* 
             * The system shall achieve minimum round-trip energy efficiency of 75% 
             * accounting for all conversion losses.
             */
            subject system : SystemArchitecture::gravitationalStorageSystem;
            assert constraint {
                system.hoistingSystem.motorEfficiency * 
                system.generatorUnit.generationEfficiency * 
                system.powerElectronics.conversionEfficiency >= 0.75
            }
        }
        
        requirement <'GES-REQ-005'> safeOperatingLimits {
            doc /* 
             * The system shall maintain mass position within defined safe height 
             * boundaries during all operations.
             */
            subject system : SystemArchitecture::gravitationalStorageSystem;
            assert constraint {
                system.massBlock.currentHeight >= system.massBlock.minHeight and 
                system.massBlock.currentHeight <= system.massBlock.maxHeight
            }
        }
        
        satisfy energyStorageCapability by SystemArchitecture::gravitationalStorageSystem;
        satisfy minimumStorageCapacity by SystemArchitecture::gravitationalStorageSystem;
        satisfy powerDeliveryRate by SystemArchitecture::gravitationalStorageSystem;
        satisfy roundTripEfficiency by SystemArchitecture::gravitationalStorageSystem;
        satisfy safeOperatingLimits by SystemArchitecture::gravitationalStorageSystem;
    }
}
