package HumanoidAssistantRobot {
    private import ScalarValues::*;
    private import ISQ::*;

    // Signal Definitions
    attribute def SigUserCommandReceived;
    attribute def SigLowBattery;
    attribute def SigRechargeComplete;
    attribute def SigErrorDetected;
    attribute def SigErrorResolved;

    // Data Type Definitions
    attribute def UserCommand;
    attribute def PerceptionData;
    attribute def NavigationPlan;
    attribute def ManipulationPlan;
    attribute def MotorCommand;
    attribute def BatteryStatus;

    // Action Definitions
    action def ProcessSensorData {
        in attribute rawSensorData : Real;
        out attribute environmentMap : PerceptionData;
    }
    action def GeneratePlans {
        in attribute environmentMap : PerceptionData;
        in attribute userCommand : UserCommand;
        out attribute navigationPlan : NavigationPlan;
        out attribute manipulationPlan : ManipulationPlan;
    }
    action def TranslatePlansToCommands {
        in attribute navigationPlan : NavigationPlan;
        in attribute manipulationPlan : ManipulationPlan;
        out attribute motorCommand : MotorCommand;
        out attribute balanceCommand : MotorCommand;
    }

    // Actuator and Joint Definitions
    part def Motor {
        port controlPort { in attribute command : MotorCommand; }
        port powerPort { in attribute power : Real; }
        perform action actuate;
    }

    part def Joint {
        attribute jointAngle : ISQ::PlaneAngleValue;
        part motor : Motor;
    }

    part def ArmJoint :> Joint;
    part def LegJoint :> Joint;

    part def Shoulder :> ArmJoint;
    part def Elbow :> ArmJoint;
    part def Wrist :> ArmJoint;

    part def Hip :> LegJoint;
    part def Knee :> LegJoint;
    part def Ankle :> LegJoint;

    part def Gripper {
        attribute maxGraspForce : ISQ::ForceValue;
        port graspPort { out attribute appliedForce : ISQ::ForceValue; }
        part motor : Motor;
        perform action grasp;
    }

    part def Arm {
        part shoulder : Shoulder;
        part elbow : Elbow;
        part wrist : Wrist;
        part gripper : Gripper;
    }

    part def Leg {
        part hip : Hip;
        part knee : Knee;
        part ankle : Ankle;
    }

    part def Neck {
        attribute neckAngle : ISQ::PlaneAngleValue;
        part motor : Motor;
    }

    // Sensor Definitions
    part def Sensor {
        port dataPort { out attribute sensorData : Real; }
        port powerPort { in attribute power : Real; }
        perform action sense;
    }

    part def VisionSensor :> Sensor;
    part def RangeSensor :> Sensor {
        attribute distance : ISQ::LengthValue;
    }
    part def AudioSensor :> Sensor;

    part def Head {
        part neck : Neck;
        part camera : VisionSensor;
        part rangeSensor : RangeSensor;
        part microphone : AudioSensor;
    }

    part def Torso;

    // Power System Definitions
    part def Battery {
        attribute capacity : ISQ::ElectricChargeValue;
        attribute currentCharge : ISQ::ElectricChargeValue;
        port powerPort { out attribute power : Real; }
        port statusPort { out attribute status : BatteryStatus; }
        perform action discharge;
    }

    part def PowerManagementSystem {
        port powerInPort { in attribute power : Real; }
        port powerOutPort { out attribute power : Real; }
        port batteryStatusPort { in attribute status : BatteryStatus; }
        perform action distributePower;
    }

    // Brain Module Definitions
    part def PerceptionModule {
        port sensorDataPort { in attribute rawSensorData : Real; }
        port environmentPort { out attribute environmentMap : PerceptionData; }
        port powerPort { in attribute power : Real; }
        perform action processSensorData : ProcessSensorData;
    }

    part def PlanningModule {
        port environmentPort { in attribute environmentMap : PerceptionData; }
        port commandPort { in attribute userCommand : UserCommand; }
        port planPort { out attribute navigationPlan : NavigationPlan; out attribute manipulationPlan : ManipulationPlan; }
        port powerPort { in attribute power : Real; }
        perform action generatePlans : GeneratePlans;
    }

    part def ControlModule {
        port planPort { in attribute navigationPlan : NavigationPlan; in attribute manipulationPlan : ManipulationPlan; }
        port motorCommandPort { out attribute motorCommand : MotorCommand; }
        port balancePort { out attribute balanceCommand : MotorCommand; }
        port powerPort { in attribute power : Real; }
        perform action translatePlansToCommands : TranslatePlansToCommands;
    }

    // Requirements
    requirement OperateInHumanEnvironments {
        doc /* The robot shall autonomously perform physical tasks in human environments. */
    }
    requirement MaintainBalance {
        doc /* The robot shall dynamically maintain balance while walking or performing actions. */
    }

    // Robot Definition
    part def HumanoidRobot {
        attribute mode : String;

        part head : Head;
        part torso : Torso;
        part leftArm : Arm;
        part rightArm : Arm;
        part leftLeg : Leg;
        part rightLeg : Leg;

        part battery : Battery;
        part powerManagementSystem : PowerManagementSystem;

        part perceptionModule : PerceptionModule;
        part planningModule : PlanningModule;
        part controlModule : ControlModule;

        // Power Connections
        connect battery.powerPort to powerManagementSystem.powerInPort;
        connect battery.statusPort to powerManagementSystem.batteryStatusPort;
        connect powerManagementSystem.powerOutPort to head.camera.powerPort;
        connect powerManagementSystem.powerOutPort to head.rangeSensor.powerPort;
        connect powerManagementSystem.powerOutPort to head.microphone.powerPort;
        connect powerManagementSystem.powerOutPort to head.neck.motor.powerPort;
        connect powerManagementSystem.powerOutPort to perceptionModule.powerPort;
        connect powerManagementSystem.powerOutPort to planningModule.powerPort;
        connect powerManagementSystem.powerOutPort to controlModule.powerPort;
        connect powerManagementSystem.powerOutPort to leftArm.shoulder.motor.powerPort;
        connect powerManagementSystem.powerOutPort to leftArm.elbow.motor.powerPort;
        connect powerManagementSystem.powerOutPort to leftArm.wrist.motor.powerPort;
        connect powerManagementSystem.powerOutPort to leftArm.gripper.motor.powerPort;
        connect powerManagementSystem.powerOutPort to rightArm.shoulder.motor.powerPort;
        connect powerManagementSystem.powerOutPort to rightArm.elbow.motor.powerPort;
        connect powerManagementSystem.powerOutPort to rightArm.wrist.motor.powerPort;
        connect powerManagementSystem.powerOutPort to rightArm.gripper.motor.powerPort;
        connect powerManagementSystem.powerOutPort to leftLeg.hip.motor.powerPort;
        connect powerManagementSystem.powerOutPort to leftLeg.knee.motor.powerPort;
        connect powerManagementSystem.powerOutPort to leftLeg.ankle.motor.powerPort;
        connect powerManagementSystem.powerOutPort to rightLeg.hip.motor.powerPort;
        connect powerManagementSystem.powerOutPort to rightLeg.knee.motor.powerPort;
        connect powerManagementSystem.powerOutPort to rightLeg.ankle.motor.powerPort;

        // Data Connections
        connect head.camera.dataPort to perceptionModule.sensorDataPort;
        connect head.rangeSensor.dataPort to perceptionModule.sensorDataPort;
        connect head.microphone.dataPort to perceptionModule.sensorDataPort;

        connect perceptionModule.environmentPort to planningModule.environmentPort;

        // Control Connections
        connect controlModule.motorCommandPort to head.neck.motor.controlPort;
        connect controlModule.motorCommandPort to leftArm.shoulder.motor.controlPort;
        connect controlModule.motorCommandPort to leftArm.elbow.motor.controlPort;
        connect controlModule.motorCommandPort to leftArm.wrist.motor.controlPort;
        connect controlModule.motorCommandPort to leftArm.gripper.motor.controlPort;
        connect controlModule.motorCommandPort to rightArm.shoulder.motor.controlPort;
        connect controlModule.motorCommandPort to rightArm.elbow.motor.controlPort;
        connect controlModule.motorCommandPort to rightArm.wrist.motor.controlPort;
        connect controlModule.motorCommandPort to rightArm.gripper.motor.controlPort;
        connect controlModule.balancePort to leftLeg.hip.motor.controlPort;
        connect controlModule.balancePort to leftLeg.knee.motor.controlPort;
        connect controlModule.balancePort to leftLeg.ankle.motor.controlPort;
        connect controlModule.balancePort to rightLeg.hip.motor.controlPort;
        connect controlModule.balancePort to rightLeg.knee.motor.controlPort;
        connect controlModule.balancePort to rightLeg.ankle.motor.controlPort;

        // Operational Behavior
        perform action operateCycle {
            loop action cycle {
                action perceive : ProcessSensorData;
                then action plan : GeneratePlans;
                then action execute : TranslatePlansToCommands;
            }
        }

        // State Machine
        state robotStates {
            entry; then standby;
            state standby;
                accept SigUserCommandReceived then active;
                accept SigLowBattery then lowPower;
            state active;
                accept SigLowBattery then lowPower;
                accept SigErrorDetected then recovery;
            state lowPower;
                accept SigRechargeComplete then standby;
                accept SigErrorDetected then recovery;
            state recovery;
                accept SigErrorResolved then standby;
        }

        satisfy OperateInHumanEnvironments;
        satisfy MaintainBalance;
    }
}
