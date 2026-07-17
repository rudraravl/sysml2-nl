package KineticEnergyRecoverySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    
    package Definitions {
        attribute def Energy :> Real;
        attribute def Power :> Real;
        attribute def Torque :> Real;
        attribute def AngularVelocity :> Real;
        attribute def Velocity :> Real;
        attribute def Mass :> Real;
        
        item def MechanicalPower {
            attribute torque : Torque;
            attribute angularVelocity : AngularVelocity;
        }
        
        item def ElectricalPower {
            attribute voltage : Real;
            attribute current : Real;
        }
        
        attribute def BrakeCommand {
            attribute intensity : Real;
        }
        
        attribute def SystemMode {
            attribute mode : ModeEnum;
        }
        
        enum def ModeEnum {
            enum charging;
            enum discharging;
            enum idle;
        }
        
        port def MechanicalPort {
            attribute torque : Torque;
            attribute angularVelocity : AngularVelocity;
        }
        
        port def ElectricalPort {
            attribute voltage : Real;
            attribute current : Real;
        }
        
        action def MeasureVelocity {
            in vehicleMass : Mass;
            out velocity : Velocity;
        }
        
        action def CalculateKineticEnergy {
            in mass : Mass;
            in velocity : Velocity;
            out kineticEnergy : Energy;
        }
        
        action def ConvertMechanicalToElectrical {
            in mechanicalPower : MechanicalPower;
            out electricalPower : ElectricalPower;
            out convertedEnergy : Energy;
        }
        
        action def StoreEnergy {
            in electricalPower : ElectricalPower;
            out storedEnergy : Energy;
        }
        
        action def ReleaseEnergy {
            in requestedPower : Power;
            out electricalPower : ElectricalPower;
            out releasedEnergy : Energy;
        }
        
        action def ConvertElectricalToMechanical {
            in electricalPower : ElectricalPower;
            out mechanicalPower : MechanicalPower;
        }
        
        action def RecoverKineticEnergy {
            in vehicleMass : Mass;
            in brakeCmd : BrakeCommand;
            out recoveredEnergy : Energy;
        }
    }
    
    package Components {
        private import Definitions::*;
        
        part def VelocitySensor {
            out port velocityOut;
            perform action measureVelocity : MeasureVelocity;
        }
        
        part def MotorGenerator {
            port mechPort : MechanicalPort;
            port elecPort : ElectricalPort;
            attribute efficiency : Real = 0.92;
            
            action def OperateAsGenerator {
                in mechPower : MechanicalPower;
                out elecPower : ElectricalPower;
            }
            
            action def OperateAsMotor {
                in elecPower : ElectricalPower;
                out mechPower : MechanicalPower;
            }
        }
        
        part def EnergyStorageUnit {
            port elecIn : ElectricalPort;
            port elecOut : ElectricalPort;
            attribute capacity : Energy = 500000.0;
            attribute currentCharge : Energy = 0.0;
            attribute maxChargeRate : Power = 50000.0;
            attribute maxDischargeRate : Power = 50000.0;
        }
        
        part def PowerElectronics {
            port gridSide : ElectricalPort;
            port storageSide : ElectricalPort;
            attribute conversionEfficiency : Real = 0.95;
        }
        
        part def SystemController {
            in port brakeInput;
            in port velocityInput;
            in port modeInput;
            out port controlOutput;
            attribute currentMode : ModeEnum = ModeEnum::idle;
        }
        
        part def Drivetrain {
            port mechOutput : MechanicalPort;
            attribute vehicleMass : Mass = 1500.0;
        }
        
        part def KERS {
            attribute totalRecoveredEnergy : Energy = 0.0;
            attribute vehicleMass : Mass = 1500.0;
            
            port drivetrainConnection : MechanicalPort;
            port powerOutput : ElectricalPort;
            
            part velocitySensor : VelocitySensor;
            part motorGen : MotorGenerator;
            part storage : EnergyStorageUnit;
            part electronics : PowerElectronics;
            part controller : SystemController;
            
            connection mechConnection connect drivetrainConnection to motorGen.mechPort;
            connection elecConnection1 connect motorGen.elecPort to electronics.gridSide;
            connection elecConnection2 connect electronics.storageSide to storage.elecIn;
            connection outputConnection connect storage.elecOut to powerOutput;
        }
    }
    
    package Behaviors {
        private import Definitions::*;
        private import Components::*;
        
        action recoverKineticEnergy : RecoverKineticEnergy {
            in vehicleMass : Mass;
            in brakeCmd : BrakeCommand;
            out recoveredEnergy : Energy;
            
            first start;
            then merge recoveryLoop;
            
            then action measureVel : MeasureVelocity {
                in vehicleMass : Mass = recoverKineticEnergy::vehicleMass;
                out velocity : Velocity;
            }
            
            then action calcKE : CalculateKineticEnergy {
                in mass : Mass = recoverKineticEnergy::vehicleMass;
                in velocity : Velocity = measureVel.velocity;
                out kineticEnergy : Energy;
            }
            
            then decide;
                if brakeCmd.intensity > 0.0 and measureVel.velocity > 0.0 then performRecovery;
                if brakeCmd.intensity <= 0.0 or measureVel.velocity <= 0.0 then endRecovery;
            
            action performRecovery {
                action convertMech : ConvertMechanicalToElectrical {
                    in mechanicalPower : MechanicalPower;
                    out electricalPower : ElectricalPower;
                    out convertedEnergy : Energy;
                }
                
                then action storeEnergy : StoreEnergy {
                    in electricalPower : ElectricalPower = convertMech.electricalPower;
                    out storedEnergy : Energy;
                }
                
                flow storeEnergy.storedEnergy to recoverKineticEnergy.recoveredEnergy;
            }
            then recoveryLoop;
            
            action endRecovery;
            then done;
        }
        
        state def KERSOperationalStates {
            entry; then idle;
            
            state idle {
                doc /* System is inactive, no energy recovery or delivery occurring. */
            }
            
            transition idle_to_charging
                first idle
                accept brakeCmd : BrakeCommand
                if brakeCmd.intensity > 0.0
                then charging;
            
            state charging {
                doc /* Converting vehicle kinetic energy to electrical energy and storing it. */
            }
            
            transition charging_to_idle
                first charging
                accept brakeCmd : BrakeCommand
                if brakeCmd.intensity <= 0.0
                then idle;
            
            transition charging_to_discharging
                first charging
                accept modeCmd : SystemMode
                if modeCmd.mode == ModeEnum::discharging
                then discharging;
            
            state discharging {
                doc /* Releasing stored electrical energy to assist vehicle propulsion. */
            }
            
            transition discharging_to_idle
                first discharging
                accept modeCmd : SystemMode
                if modeCmd.mode == ModeEnum::idle
                then idle;
            
            transition discharging_to_charging
                first discharging
                accept brakeCmd : BrakeCommand
                if brakeCmd.intensity > 0.0
                then charging;
        }
    }
    
    package Architecture {
        private import Components::*;
        private import Behaviors::*;
        
        part vehicle {
            attribute mass : Mass = 1500.0;
            
            part drivetrain : Drivetrain {
                attribute vehicleMass = vehicle.mass;
            }
            
            part kers : KERS {
                attribute vehicleMass = vehicle.mass;
                
                connect kers.drivetrainConnection to drivetrain.mechOutput;
                
                perform action recoveryAction : recoverKineticEnergy;
                exhibit state operationalBehavior : KERSOperationalStates;
            }
        }
    }
    
    package Requirements {
        private import Architecture::*;
        private import Components::KERS;
        
        requirement <'REQ-KERS-001'> primaryFunction {
            doc /* The Kinetic Energy Recovery System shall capture kinetic energy 
                 * from the vehicle during braking events, convert it to electrical 
                 * energy, store it, and make it available for later use to assist 
                 * vehicle propulsion, thereby improving overall energy efficiency.
                 */
            subject system : KERS;
        }
        
        requirement <'REQ-KERS-002'> energyRecoveryEfficiency {
            doc /* The system shall recover at least 60% of available kinetic energy 
                 * during braking events above 5 m/s.
                 */
            subject kers :>> vehicle.kers;
            assert constraint {
                kers.motorGen.efficiency >= 0.92 and 
                kers.electronics.conversionEfficiency >= 0.95
            }
        }
        
        requirement <'REQ-KERS-003'> storageCapacity {
            doc /* The energy storage unit shall have a minimum capacity of 500 kJ.
                 */
            subject storage :>> vehicle.kers.storage;
            assert constraint {
                storage.capacity >= 500000.0
            }
        }
        
        requirement <'REQ-KERS-004'> chargingRate {
            doc /* The system shall support a maximum charging rate of at least 50 kW.
                 */
            subject storage :>> vehicle.kers.storage;
            assert constraint {
                storage.maxChargeRate >= 50000.0
            }
        }
        
        requirement <'REQ-KERS-005'> dischargingRate {
            doc /* The system shall support a maximum discharging rate of at least 50 kW.
                 */
            subject storage :>> vehicle.kers.storage;
            assert constraint {
                storage.maxDischargeRate >= 50000.0
            }
        }
        
        requirement <'REQ-KERS-006'> operationalModes {
            doc /* The system shall operate in three distinct modes: charging during 
                 * braking, discharging during acceleration assist, and idle when inactive.
                 */
            subject controller :>> vehicle.kers.controller;
        }
        
        satisfy primaryFunction by vehicle.kers;
        satisfy energyRecoveryEfficiency by vehicle.kers;
        satisfy storageCapacity by vehicle.kers.storage;
        satisfy chargingRate by vehicle.kers.storage;
        satisfy dischargingRate by vehicle.kers.storage;
        satisfy operationalModes by vehicle.kers.controller;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import KineticEnergyRecoverySystem::*;

    part kers : VelocitySensor {
        exhibit state sm : KERSOperationalStates;
    }

    action orchestrator {
        attribute testVehicleMass : Mass = 0.0;
        attribute testBrakeCmd : BrakeCommand {
            attribute intensity = 0.0;
        }
        action recoverKineticEnergyProbe : RecoverKineticEnergy {
            in vehicleMass = testVehicleMass;
            in brakeCmd = testBrakeCmd;
        }
        first recoverKineticEnergyProbe;
    }
}
