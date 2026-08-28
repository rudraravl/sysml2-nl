package KERS {
    import ScalarValues::*;
    import SI::*;
    
    // ===== Value Types =====
    
    value def PowerUnit :> Real { unit 'kW'; }
    value def EnergyUnit :> Real { unit 'kWh'; }
    value def VelocityUnit :> Real { unit 'm/s'; }
    value def TorqueUnit :> Real { unit 'N*m'; }
    value def AngularVelocityUnit :> Real { unit 'rad/s'; }
    value def VoltageUnit :> Real { unit 'V'; }
    value def CurrentUnit :> Real { unit 'A'; }
    value def TemperatureUnit :> Real { unit 'degC'; }
    value def Percent :> Real { unit '%'; }
    
    value def MaxPower :> PowerUnit;
    value def StateOfCharge :> Percent;
    
    // ===== Items =====
    
    item def MechanicalPower;
    item def ElectricalPower;
    item def BrakeCommand;
    item def AcceleratorCommand;
    item def VehicleSpeed;
    item def ControlSignal;
    
    // ===== Enumerations =====
    
    enum def OperationMode {
        CHARGING;
        DISCHARGING;
        IDLE;
    }
    
    enum def MotorGeneratorMode {
        GENERATOR;
        MOTOR;
        OFF;
    }
    
    // ===== Port Definitions =====
    
    port def MechanicalPort {
        out torque : TorqueUnit;
        in angularVelocity : AngularVelocityUnit;
    }
    
    port def ElectricalPort {
        out voltage : VoltageUnit;
        out current : CurrentUnit;
    }
    
    port def ControlPort {
        in mode : OperationMode;
        in powerCommand : PowerUnit;
    }
    
    port def SensorPort {
        out vehicleSpeed : VelocityUnit;
    }
    
    port def CommandPort {
        out brakeDemand : Percent;
        out accelDemand : Percent;
    }
    
    // ===== Interfaces =====
    
    interface def MechanicalConnection {
        end supplier : MechanicalPort;
        end consumer : MechanicalPort;
    }
    
    interface def ElectricalConnection {
        end supplier : ElectricalPort;
        end consumer : ElectricalPort;
    }
    
    interface def ControlInterface {
        end controller : ControlPort;
        end device : ControlPort;
    }
    
    // ===== Requirements =====
    
    requirement def EnergyRecoveryRequirement {
        doc /* The system shall recover kinetic energy during braking and store it as electrical energy. */
        subject kers : KERS::System;
        requirement recoverDuringBraking {
            doc /* When brake demand > 0 and vehicle speed > 0, the system shall enter Charging mode. */
        }
        requirement maxRecoveryPower {
            doc /* The system shall handle charging power up to 50 kW. */
            constraint { maxChargingPower <= 50 [kW] }
        }
    }
    
    requirement def EnergyDeploymentRequirement {
        doc /* The system shall deploy stored energy to assist acceleration. */
        subject kers : KERS::System;
        requirement deployDuringAcceleration {
            doc /* When accelerator demand > threshold and SoC > minSoC, the system shall enter Discharging mode. */
        }
        requirement maxDischargePower {
            doc /* The system shall handle discharging power up to 50 kW. */
            constraint { maxDischargingPower <= 50 [kW] }
        }
    }
    
    requirement def IdleRequirement {
        doc /* The system shall be Idle when not charging or discharging. */
        subject kers : KERS::System;
        requirement idleWhenCruising {
            doc /* When no brake or accelerator demand and vehicle is cruising, the system shall be Idle. */
        }
        requirement idleWhenStopped {
            doc /* When vehicle speed is zero, the system shall be Idle. */
        }
    }
    
    requirement def StorageRequirement {
        doc /* The energy storage unit shall handle rapid charge and discharge cycles. */
        subject esu : KERS::EnergyStorageUnit;
        requirement capacityConstraint {
            doc /* The storage unit shall have sufficient capacity for KERS operation. */
            constraint { capacity >= 1.0 [kWh] }
        }
        requirement socLimits {
            doc /* The SoC shall be maintained between 20% and 95%. */
            constraint { minSoC >= 20 [%] and maxSoC <= 95 [%] }
        }
    }
    
    // ===== Components =====
    
    part def VelocitySensor {
        port sensorOut : SensorPort;
        attribute measuredSpeed : VelocityUnit;
        
        action def measureSpeed {
            out speed : VelocityUnit;
        }
        
        perform measureSpeed;
    }
    
    part def DriverInterface {
        port commandOut : CommandPort;
        attribute brakeDemand : Percent;
        attribute accelDemand : Percent;
        
        action def readCommands {
            out brake : Percent;
            out accel : Percent;
        }
        
        perform readCommands;
    }
    
    part def Drivetrain {
        port mechanicalInterface : MechanicalPort;
        attribute rotationalSpeed : AngularVelocityUnit;
        attribute outputTorque : TorqueUnit;
        
        action def transmitPower {
            in torque : TorqueUnit;
            in speed : AngularVelocityUnit;
        }
        
        perform transmitPower;
    }
    
    part def MotorGenerator {
        port mechPort : MechanicalPort;
        port elecPort : ElectricalPort;
        port controlIn : ControlPort;
        
        attribute currentMode : MotorGeneratorMode;
        attribute maxPower : PowerUnit = 50 [kW];
        attribute efficiency : Percent = 90 [%];
        
        action def generateMode {
            in mechanicalInput : MechanicalPower;
            out electricalOutput : ElectricalPower;
        }
        
        action def motorMode {
            in electricalInput : ElectricalPower;
            out mechanicalOutput : MechanicalPower;
        }
        
        action def offMode {
        }
        
        perform generateMode when currentMode == MotorGeneratorMode::GENERATOR;
        perform motorMode when currentMode == MotorGeneratorMode::MOTOR;
        perform offMode when currentMode == MotorGeneratorMode::OFF;
    }
    
    part def PowerElectronics {
        port elecPortA : ElectricalPort;
        port elecPortB : ElectricalPort;
        port controlIn : ControlPort;
        
        attribute conversionEfficiency : Percent = 95 [%];
        attribute maxPower : PowerUnit = 50 [kW];
        attribute outputVoltage : VoltageUnit = 400 [V];
        
        action def regulateCharging {
            in inputPower : ElectricalPower;
            out regulatedPower : ElectricalPower;
        }
        
        action def regulateDischarging {
            in storedPower : ElectricalPower;
            out regulatedPower : ElectricalPower;
        }
        
        perform regulateCharging;
        perform regulateDischarging;
    }
    
    part def EnergyStorageUnit {
        port elecPort : ElectricalPort;
        port controlIn : ControlPort;
        
        attribute capacity : EnergyUnit = 1.5 [kWh];
        attribute currentSoC : StateOfCharge = 50 [%];
        attribute minSoC : Percent = 20 [%];
        attribute maxSoC : Percent = 95 [%];
        attribute maxChargeRate : PowerUnit = 50 [kW];
        attribute maxDischargeRate : PowerUnit = 50 [kW];
        attribute packVoltage : VoltageUnit = 400 [V];
        
        action def charge {
            in power : ElectricalPower;
            out newSoC : StateOfCharge;
        }
        
        action def discharge {
            in power : ElectricalPower;
            out newSoC : StateOfCharge;
        }
        
        action def monitorSoC {
            out soc : StateOfCharge;
        }
        
        perform charge;
        perform discharge;
        perform monitorSoC;
    }
    
    part def SystemController {
        port sensorIn : SensorPort;
        port commandIn : CommandPort;
        port mgControl : ControlPort;
        port peControl : ControlPort;
        port esuControl : ControlPort;
        
        attribute currentMode : OperationMode = OperationMode::IDLE;
        attribute brakeThreshold : Percent = 5 [%];
        attribute accelThreshold : Percent = 10 [%];
        attribute minOperatingSoC : Percent = 20 [%];
        attribute maxOperatingSoC : Percent = 95 [%];
        attribute targetBoostPower : PowerUnit = 30 [kW];
        
        state def ControllerStateMachine {
            entry; then Idle;
            
            state Idle {
                entry { currentMode = OperationMode::IDLE; }
                do { send ControlSignal; }
                transition to Charging
                    when sensorIn.vehicleSpeed > 0 [m/s] and commandIn.brakeDemand > brakeThreshold
                    and esuControl.powerCommand < maxOperatingSoC;
                transition to Discharging
                    when commandIn.accelDemand > accelThreshold
                    and esuControl.powerCommand > minOperatingSoC;
            }
            
            state Charging {
                entry { currentMode = OperationMode::CHARGING; }
                do { 
                    mgControl.mode = OperationMode::CHARGING;
                    mgControl.powerCommand = 50 [kW];
                }
                transition to Idle
                    when commandIn.brakeDemand <= brakeThreshold
                    or sensorIn.vehicleSpeed <= 0 [m/s]
                    or esuControl.powerCommand >= maxOperatingSoC;
                transition to Discharging
                    when commandIn.accelDemand > accelThreshold
                    and esuControl.powerCommand > minOperatingSoC;
            }
            
            state Discharging {
                entry { currentMode = OperationMode::DISCHARGING; }
                do {
                    mgControl.mode = OperationMode::DISCHARGING;
                    mgControl.powerCommand = targetBoostPower;
                }
                transition to Idle
                    when commandIn.accelDemand <= accelThreshold
                    or esuControl.powerCommand <= minOperatingSoC;
                transition to Charging
                    when commandIn.brakeDemand > brakeThreshold
                    and sensorIn.vehicleSpeed > 0 [m/s];
            }
        }
        
        exhibit ControllerStateMachine;
        
        action def evaluateMode {
            in brakeDemand : Percent;
            in accelDemand : Percent;
            in speed : VelocityUnit;
            in soc : StateOfCharge;
            out mode : OperationMode;
        }
        
        perform evaluateMode;
    }
    
    // ===== Top-Level System =====
    
    part def System {
        doc /* Kinetic Energy Recovery System (KERS) for a vehicle. */
        
        satisfy EnergyRecoveryRequirement;
        satisfy EnergyDeploymentRequirement;
        satisfy IdleRequirement;
        
        attribute maxChargingPower : PowerUnit = 50 [kW];
        attribute maxDischargingPower : PowerUnit = 50 [kW];
        attribute systemEfficiency : Percent = 85 [%];
        
        part velocitySensor : VelocitySensor {
            port sensorOut : SensorPort;
        }
        
        part driverInterface : DriverInterface {
            port commandOut : CommandPort;
        }
        
        part drivetrain : Drivetrain {
            port mechanicalInterface : MechanicalPort;
        }
        
        part motorGenerator : MotorGenerator {
            port mechPort : MechanicalPort;
            port elecPort : ElectricalPort;
            port controlIn : ControlPort;
        }
        
        part powerElectronics : PowerElectronics {
            port elecPortA : ElectricalPort;
            port elecPortB : ElectricalPort;
            port controlIn : ControlPort;
        }
        
        part energyStorageUnit : EnergyStorageUnit {
            port elecPort : ElectricalPort;
            port controlIn : ControlPort;
            
            satisfy StorageRequirement;
        }
        
        part systemController : SystemController {
            port sensorIn : SensorPort;
            port commandIn : CommandPort;
            port mgControl : ControlPort;
            port peControl : ControlPort;
            port esuControl : ControlPort;
        }
        
        // Connections
        interface : MechanicalConnection connect drivetrain.mechanicalInterface to motorGenerator.mechPort;
        
        interface : ElectricalConnection connect motorGenerator.elecPort to powerElectronics.elecPortA;
        
        interface : ElectricalConnection connect powerElectronics.elecPortB to energyStorageUnit.elecPort;
        
        interface : ControlInterface connect systemController.mgControl to motorGenerator.controlIn;
        
        interface : ControlInterface connect systemController.peControl to powerElectronics.controlIn;
        
        interface : ControlInterface connect systemController.esuControl to energyStorageUnit.controlIn;
        
        flow from velocitySensor.sensorOut.vehicleSpeed to systemController.sensorIn.vehicleSpeed;
        flow from driverInterface.commandOut.brakeDemand to systemController.commandIn.brakeDemand;
        flow from driverInterface.commandOut.accelDemand to systemController.commandIn.accelDemand;
    }
}
