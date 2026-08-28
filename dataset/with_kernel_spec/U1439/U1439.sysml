package 'KERS Model' {

    private import ScalarValues::*;

    // ===== Units =====
    unit km_per_h;
    unit kW;
    unit kWh;
    unit N_m;
    unit rpm;
    unit V;
    unit A;

    // ===== Value Types =====
    value def SpeedValue :> Real { unit km_per_h; }
    value def PowerValue :> Real { unit kW; }
    value def EnergyValue :> Real { unit kWh; }
    value def TorqueValue :> Real { unit N_m; }
    value def RotationalSpeedValue :> Real { unit rpm; }
    value def VoltageValue :> Real { unit V; }
    value def CurrentValue :> Real { unit A; }
    value def StateOfChargeValue :> Real;

    // ===== Item Definitions =====
    item def BrakeCommand {
        attribute brakePressure : Real;
        attribute isBraking : Boolean;
    }
    item def SpeedReading {
        attribute speed : SpeedValue;
    }
    item def MechanicalPower {
        attribute torque : TorqueValue;
        attribute rotationalSpeed : RotationalSpeedValue;
    }
    item def ElectricalPower {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }
    item def ControlCommand {
        attribute targetMode : String;
    }
    item def StorageStatus {
        attribute stateOfCharge : StateOfChargeValue;
        attribute storedEnergy : EnergyValue;
    }

    // ===== Part Definitions =====
    part def Driver {
        port brakeCommandPort {
            out brakeCommand : BrakeCommand;
        }
    }

    part def VelocitySensor {
        port speedPort {
            out speedReading : SpeedReading;
        }
    }

    part def Drivetrain {
        port mechanicalPort {
            in mechanicalPowerIn : MechanicalPower;
            out mechanicalPowerOut : MechanicalPower;
        }
    }

    part def MotorGenerator {
        port mechanicalPort {
            in mechanicalPowerIn : MechanicalPower;
            out mechanicalPowerOut : MechanicalPower;
        }
        port electricalPort {
            in electricalPowerIn : ElectricalPower;
            out electricalPowerOut : ElectricalPower;
        }
    }

    part def PowerElectronics {
        port mgElectricalPort {
            in electricalPowerFromMG : ElectricalPower;
            out electricalPowerToMG : ElectricalPower;
        }
        port esuElectricalPort {
            in electricalPowerFromESU : ElectricalPower;
            out electricalPowerToESU : ElectricalPower;
        }
        port controlPort {
            in controlCommand : ControlCommand;
        }
    }

    part def EnergyStorageUnit {
        attribute maxChargeRate : PowerValue = 50;
        attribute maxDischargeRate : PowerValue = 50;
        attribute capacity : EnergyValue = 5;

        port electricalPort {
            in electricalPowerIn : ElectricalPower;
            out electricalPowerOut : ElectricalPower;
        }
        port statusPort {
            out storageStatus : StorageStatus;
        }
    }

    part def SystemController {
        port brakeCommandPort {
            in brakeCommand : BrakeCommand;
        }
        port speedPort {
            in speedReading : SpeedReading;
        }
        port storageStatusPort {
            in storageStatus : StorageStatus;
        }
        port controlPort {
            out controlCommand : ControlCommand;
        }
    }

    part def Vehicle {
        port brakeInputPort {
            in brakeCommand : BrakeCommand;
        }
    }

    // ===== State Machine Definition =====
    state def KERSStates {
        in isBraking : Boolean;
        in stateOfCharge : Real;
        in speed : Real;

        entry; then Idle;

        state Idle;
        state Charging;
        state Discharging;

        transition toCharging from Idle to Charging when isBraking == true;
        transition toDischarging from Idle to Discharging when stateOfCharge > 10 and speed > 30;
        transition toIdleFromCharging from Charging to Idle when isBraking == false;
        transition toIdleFromDischarging from Discharging to Idle when stateOfCharge < 10;
        transition toChargingFromDischarging from Discharging to Charging when isBraking == true;
    }

    // ===== Vehicle Assembly =====
    part vehicle : Vehicle {
        part systemController : SystemController;
        part velocitySensor : VelocitySensor;
        part drivetrain : Drivetrain;
        part motorGenerator : MotorGenerator;
        part powerElectronics : PowerElectronics;
        part energyStorageUnit : EnergyStorageUnit;

        flow brakeCommandFlow of BrakeCommand
            from brakeInputPort.brakeCommand to systemController.brakeCommandPort.brakeCommand;

        flow speedReadingFlow of SpeedReading
            from velocitySensor.speedPort.speedReading to systemController.speedPort.speedReading;

        flow storageStatusFlow of StorageStatus
            from energyStorageUnit.statusPort.storageStatus to systemController.storageStatusPort.storageStatus;

        flow controlCommandFlow of ControlCommand
            from systemController.controlPort.controlCommand to powerElectronics.controlPort.controlCommand;

        flow mechanicalPowerChargingFlow of MechanicalPower
            from drivetrain.mechanicalPort.mechanicalPowerOut to motorGenerator.mechanicalPort.mechanicalPowerIn;

        flow mechanicalPowerDischargingFlow of MechanicalPower
            from motorGenerator.mechanicalPort.mechanicalPowerOut to drivetrain.mechanicalPort.mechanicalPowerIn;

        flow electricalPowerChargingFlow of ElectricalPower
            from motorGenerator.electricalPort.electricalPowerOut to powerElectronics.mgElectricalPort.electricalPowerFromMG;

        flow electricalPowerDischargingFlow of ElectricalPower
            from powerElectronics.mgElectricalPort.electricalPowerToMG to motorGenerator.electricalPort.electricalPowerIn;

        flow storageChargingFlow of ElectricalPower
            from powerElectronics.esuElectricalPort.electricalPowerToESU to energyStorageUnit.electricalPort.electricalPowerIn;

        flow storageDischargingFlow of ElectricalPower
            from energyStorageUnit.electricalPort.electricalPowerOut to powerElectronics.esuElectricalPort.electricalPowerFromESU;

        exhibit kersStateBehavior : KERSStates {
            in isBraking = systemController.brakeCommandPort.brakeCommand.isBraking;
            in stateOfCharge = energyStorageUnit.statusPort.storageStatus.stateOfCharge;
            in speed = velocitySensor.speedPort.speedReading.speed;
        }
    }

    // ===== Driver and Interface =====
    part driver : Driver;

    interface driverToVehicleInterface connect driver.brakeCommandPort to vehicle.brakeInputPort {
        flow brakeCommandInterfaceFlow of BrakeCommand
            from driver.brakeCommandPort.brakeCommand to vehicle.brakeInputPort.brakeCommand;
    }

    // ===== Requirements =====
    requirement def EnergyRecoveryRequirement {
        doc = "The KERS shall capture kinetic energy normally lost as heat during braking, convert it to electrical energy, and store it for later use.";
        subject kersVehicle : Vehicle;
    }

    requirement def PowerHandlingRequirement {
        doc = "The energy storage unit shall handle rapid charging and discharging up to 50 kW.";
        subject storageUnit : EnergyStorageUnit;
        constraint { storageUnit.maxChargeRate <= 50 and storageUnit.maxDischargeRate <= 50 }
    }

    requirement def DualModeOperationRequirement {
        doc = "The motor-generator shall operate as a generator during braking and as a motor during acceleration boost.";
        subject mg : MotorGenerator;
    }

    requirement def StateOperationRequirement {
        doc = "The KERS shall operate in three distinct states: Charging, Discharging, and Idle.";
        subject kersVehicle : Vehicle;
    }

    requirement def ControllerDecisionRequirement {
        doc = "The system controller shall monitor driver braking commands and vehicle speed to determine the system operating mode.";
        subject controller : SystemController;
    }

    requirement def EnergyDeploymentRequirement {
        doc = "The stored energy shall be deployable to assist the vehicle drivetrain during acceleration by operating the motor-generator in motor mode.";
        subject kersVehicle : Vehicle;
    }

    // ===== Requirement Usages =====
    requirement energyRecoveryReq : EnergyRecoveryRequirement {
        subject kersVehicle :>> vehicle;
    }

    requirement powerHandlingReq : PowerHandlingRequirement {
        subject storageUnit :>> vehicle.energyStorageUnit;
    }

    requirement dualModeReq : DualModeOperationRequirement {
        subject mg :>> vehicle.motorGenerator;
    }

    requirement stateOperationReq : StateOperationRequirement {
        subject kersVehicle :>> vehicle;
    }

    requirement controllerDecisionReq : ControllerDecisionRequirement {
        subject controller :>> vehicle.systemController;
    }

    requirement energyDeploymentReq : EnergyDeploymentRequirement {
        subject kersVehicle :>> vehicle;
    }
}
