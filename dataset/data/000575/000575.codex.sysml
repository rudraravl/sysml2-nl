package CranialDrillSystemModel {

    import ScalarValues::*;
    import ISQ::*;

    attribute def RotationalSpeed :> scalarValues::Real {
        unit = "rpm";
    }

    attribute def Torque :> scalarValues::Real {
        unit = "N*m";
    }

    attribute def Force :> scalarValues::Real {
        unit = "N";
    }

    attribute def Length :> scalarValues::Real {
        unit = "mm";
    }

    attribute def Temperature :> scalarValues::Real {
        unit = "degC";
    }

    attribute def ElectricPotential :> scalarValues::Real {
        unit = "V";
    }

    attribute def ElectricCurrent :> scalarValues::Real {
        unit = "A";
    }

    attribute def Power :> scalarValues::Real {
        unit = "W";
    }

    attribute def TimeDuration :> scalarValues::Real {
        unit = "s";
    }

    item def ElectricalEnergy {
        attribute voltage : ElectricPotential;
        attribute current : ElectricCurrent;
        attribute availablePower : Power;
    }

    item def MechanicalRotation {
        attribute speed : RotationalSpeed;
        attribute torque : Torque;
        attribute axialForce : Force;
    }

    item def IrrigationFluid {
        attribute flowRate {
            unit = "mL/min";
            :>> scalarValues::Real;
        }
        attribute temperature : Temperature;
    }

    item def ControlSignal {
        attribute commandLevel {
            unit = "percent";
            :>> scalarValues::Real;
        }
        attribute enable : Boolean;
    }

    item def SensorReading {
        attribute measuredSpeed : RotationalSpeed;
        attribute measuredTorque : Torque;
        attribute measuredTemperature : Temperature;
        attribute measuredDepth : Length;
    }

    port def ElectricalPowerPort {
        out item electricalEnergy : ElectricalEnergy;
    }

    port def MotorPowerPort {
        in item electricalEnergy : ElectricalEnergy;
        in item controlSignal : ControlSignal;
        out item rotation : MechanicalRotation;
    }

    port def RotationPort {
        in item rotationIn : MechanicalRotation;
        out item rotationOut : MechanicalRotation;
    }

    port def DrillBitPort {
        in item driveRotation : MechanicalRotation;
        out item cuttingRotation : MechanicalRotation;
    }

    port def IrrigationPort {
        out item irrigationFluid : IrrigationFluid;
    }

    port def SensorPort {
        out item sensorReading : SensorReading;
    }

    port def UserControlPort {
        out item controlSignal : ControlSignal;
    }

    port def BoneInterfacePort {
        in item cuttingRotation : MechanicalRotation;
        in item irrigationFluid : IrrigationFluid;
    }

    action def ConvertElectricalPowerToRotation {
        in item suppliedEnergy : ElectricalEnergy;
        in item motorCommand : ControlSignal;
        out item motorRotation : MechanicalRotation;

        attribute commandedSpeed : RotationalSpeed;
        attribute generatedTorque : Torque;
    }

    action def ReduceSpeedAndIncreaseTorque {
        in item motorRotation : MechanicalRotation;
        out item spindleRotation : MechanicalRotation;

        attribute gearRatio : Real = 8.0;
    }

    action def CutCranialBone {
        in item cuttingRotation : MechanicalRotation;
        in item coolingFluid : IrrigationFluid;

        attribute targetHoleDiameter : Length = 6.0;
        attribute maximumPenetrationDepth : Length = 4.5;
        attribute expectedCutDuration : TimeDuration = 20.0;
    }

    action def MonitorDrilling {
        in item sensorReading : SensorReading;
        out item safetyInterlock : ControlSignal;
    }

    state def DrillOperationalState {
        entry action InitializeController;

        state Off;
        state Standby;
        state Armed;
        state Drilling;
        state Cooling;
        state Fault;
        state Shutdown;

        transition first Off;

        transition Off_to_Standby
            first Off
            then Standby;

        transition Standby_to_Armed
            first Standby
            accept operatorEnable
            then Armed;

        transition Armed_to_Drilling
            first Armed
            accept triggerPressed
            then Drilling;

        transition Drilling_to_Cooling
            first Drilling
            accept triggerReleased
            then Cooling;

        transition Cooling_to_Standby
            first Cooling
            accept coolingComplete
            then Standby;

        transition Drilling_to_Fault
            first Drilling
            accept excessiveTorqueDetected
            then Fault;

        transition Drilling_to_Fault_Temperature
            first Drilling
            accept excessiveTemperatureDetected
            then Fault;

        transition Fault_to_Shutdown
            first Fault
            accept faultLatched
            then Shutdown;

        transition Shutdown_to_Off
            first Shutdown
            accept powerRemoved
            then Off;
    }

    part def BatteryPack {
        attribute nominalVoltage : ElectricPotential = 18.0;
        attribute maximumCurrent : ElectricCurrent = 12.0;
        attribute capacity {
            unit = "A*h";
            :>> scalarValues::Real = 4.0;
        }

        port powerOut : ElectricalPowerPort;
    }

    part def UserInterface {
        attribute triggerPosition {
            unit = "percent";
            :>> scalarValues::Real;
        }
        attribute modeSelected : String;
        attribute enabled : Boolean;

        port controlOut : UserControlPort;
    }

    part def MotorController {
        attribute maximumOutputPower : Power = 120.0;
        attribute speedSetpoint : RotationalSpeed;
        attribute currentLimit : ElectricCurrent = 10.0;

        port powerIn : MotorPowerPort;
        port commandIn : UserControlPort;
        port sensorIn : SensorPort;
        port motorDriveOut : MotorPowerPort;

        perform action MonitorDrilling;
    }

    part def BrushlessMotor {
        attribute noLoadSpeed : RotationalSpeed = 48000.0;
        attribute ratedTorque : Torque = 0.025;
        attribute windingTemperatureLimit : Temperature = 65.0;

        port motorPowerIn : MotorPowerPort;
        port shaftOut : RotationPort;

        perform action ConvertElectricalPowerToRotation;
    }

    part def ReductionGearbox {
        attribute reductionRatio : Real = 8.0;
        attribute efficiency {
            unit = "percent";
            :>> scalarValues::Real = 88.0;
        }

        port motorShaftIn : RotationPort;
        port spindleOut : RotationPort;

        perform action ReduceSpeedAndIncreaseTorque;
    }

    part def SpindleAssembly {
        attribute maximumRunout : Length = 0.05;
        attribute bearingTemperatureLimit : Temperature = 55.0;

        port driveIn : RotationPort;
        port bitDriveOut : DrillBitPort;
    }

    part def CranialDrillBit {
        attribute diameter : Length = 6.0;
        attribute cuttingLength : Length = 12.0;
        attribute tipGeometry : String = "fluted cranial perforator";
        attribute maximumAllowedDepth : Length = 4.5;

        port drivenEnd : DrillBitPort;
        port boneInterface : BoneInterfacePort;

        perform action CutCranialBone;
    }

    part def DepthLimiter {
        attribute setDepth : Length = 4.5;
        attribute depthTolerance : Length = 0.2;
        attribute contactForceLimit : Force = 15.0;
    }

    part def IrrigationSubsystem {
        attribute nominalFlowRate {
            unit = "mL/min";
            :>> scalarValues::Real = 45.0;
        }
        attribute reservoirVolume {
            unit = "mL";
            :>> scalarValues::Real = 250.0;
        }

        port fluidOut : IrrigationPort;
    }

    part def SensorSuite {
        attribute torqueTripThreshold : Torque = 0.18;
        attribute temperatureTripThreshold : Temperature = 48.0;
        attribute speedAccuracy {
            unit = "percent";
            :>> scalarValues::Real = 2.0;
        }

        port sensorOut : SensorPort;
    }

    part def SterileHousing {
        attribute ingressProtection : String = "sealed surgical handpiece";
        attribute mass {
            unit = "g";
            :>> scalarValues::Real = 950.0;
        }
        attribute gripDiameter : Length = 34.0;
    }

    part def CranialDrillSystem {
        attribute primaryFunction : String =
            "Create a controlled circular opening through cranial bone by delivering regulated rotary cutting motion to a sterile drill bit while limiting depth, heat, torque, and operator-applied risk.";

        attribute maximumBitSpeed : RotationalSpeed = 6000.0;
        attribute nominalBitSpeed : RotationalSpeed = 4200.0;
        attribute maximumOutputTorque : Torque = 0.20;
        attribute maximumBoneTemperature : Temperature = 48.0;
        attribute maximumPenetrationDepth : Length = 4.5;
        attribute maximumAxialForce : Force = 20.0;

        part battery : BatteryPack;
        part userInterface : UserInterface;
        part controller : MotorController;
        part motor : BrushlessMotor;
        part gearbox : ReductionGearbox;
        part spindle : SpindleAssembly;
        part drillBit : CranialDrillBit;
        part depthLimiter : DepthLimiter;
        part irrigation : IrrigationSubsystem;
        part sensors : SensorSuite;
        part housing : SterileHousing;

        port externalBoneInterface : BoneInterfacePort;

        connection battery_to_controller
            connect battery.powerOut to controller.powerIn;

        connection user_to_controller
            connect userInterface.controlOut to controller.commandIn;

        connection controller_to_motor
            connect controller.motorDriveOut to motor.motorPowerIn;

        connection motor_to_gearbox
            connect motor.shaftOut to gearbox.motorShaftIn;

        connection gearbox_to_spindle
            connect gearbox.spindleOut to spindle.driveIn;

        connection spindle_to_bit
            connect spindle.bitDriveOut to drillBit.drivenEnd;

        connection irrigation_to_bone
            connect irrigation.fluidOut to drillBit.boneInterface;

        connection bit_to_external_bone
            connect drillBit.boneInterface to externalBoneInterface;

        connection sensors_to_controller
            connect sensors.sensorOut to controller.sensorIn;

        exhibit state operationalState : DrillOperationalState;
    }

    requirement def PrimaryFunctionRequirement {
        subject drill : CranialDrillSystem;

        doc
            /* The cranial drill shall provide controlled rotary cutting of cranial bone for creation of a surgical access opening. */

        require constraint {
            drill.nominalBitSpeed <= drill.maximumBitSpeed
        }
    }

    requirement def DepthSafetyRequirement {
        subject drill : CranialDrillSystem;

        doc
            /* The cranial drill shall mechanically limit penetration depth to protect underlying tissue. */

        require constraint {
            drill.depthLimiter.setDepth <= drill.maximumPenetrationDepth
        }
    }

    requirement def ThermalSafetyRequirement {
        subject drill : CranialDrillSystem;

        doc
            /* The cranial drill shall limit heat at the drilling interface by regulating speed and providing irrigation. */

        require constraint {
            drill.sensors.temperatureTripThreshold <= drill.maximumBoneTemperature
        }
    }

    requirement def TorqueSafetyRequirement {
        subject drill : CranialDrillSystem;

        doc
            /* The cranial drill shall stop powered rotation when measured torque exceeds the safe cranial cutting threshold. */

        require constraint {
            drill.sensors.torqueTripThreshold <= drill.maximumOutputTorque
        }
    }

    requirement def SterilityRequirement {
        subject drill : CranialDrillSystem;

        doc
            /* Patient-contacting components of the cranial drill shall support sterile surgical use. */

        require constraint {
            drill.housing.ingressProtection == "sealed surgical handpiece"
        }
    }

    requirement def OperatorControlRequirement {
        subject drill : CranialDrillSystem;

        doc
            /* The cranial drill shall produce cutting rotation only when enabled and commanded by the operator trigger. */
    }

    satisfy PrimaryFunctionRequirement by CranialDrillSystem;
    satisfy DepthSafetyRequirement by CranialDrillSystem.depthLimiter;
    satisfy ThermalSafetyRequirement by CranialDrillSystem.irrigation;
    satisfy TorqueSafetyRequirement by CranialDrillSystem.controller;
    satisfy SterilityRequirement by CranialDrillSystem.housing;
    satisfy OperatorControlRequirement by CranialDrillSystem.userInterface;

}