package ValkyrieRobotSystem {
    import ScalarValues::*;

    value type ForceN :> Real;
    value type AngleRad :> Real;
    value type DistanceM :> Real;
    value type VoltageV :> Real;
    value type CurrentA :> Real;

    item def ElectricalPower {
        attribute voltage : VoltageV;
        attribute current : CurrentA;
    }

    item def SensorData;
    item def VideoData :> SensorData;
    item def LidarPointCloud :> SensorData;
    item def ImuTelemetry :> SensorData;

    item def JointCommand {
        attribute targetAngle : AngleRad;
        attribute targetTorque : ForceN;
    }

    item def JointFeedback {
        attribute currentAngle : AngleRad;
        attribute measuredTorque : ForceN;
    }

    port def PowerOut {
        out power : ElectricalPower;
    }

    port def PowerIn {
        in power : ElectricalPower;
    }

    port def DataOut {
        out data : SensorData;
    }

    port def DataIn {
        in data : SensorData;
    }

    port def ControlOut {
        out command : JointCommand;
        in feedback : JointFeedback;
    }

    port def ControlIn {
        in command : JointCommand;
        out feedback : JointFeedback;
    }

    part def MotorizedJoint {
        port powerIn : PowerIn;
        port controlPort : ControlIn;
        attribute maxTorque : ForceN;
        attribute maxAngle : AngleRad;
    }

    part def Gripper {
        port powerIn : PowerIn;
        port controlPort : ControlIn;
        attribute maxGripForce : ForceN;
        
        action def Open;
        action def Close;
        action def Hold;
    }

    part def Camera {
        port powerIn : PowerIn;
        port dataOut : DataOut;
        attribute resolution : String;
    }

    part def Lidar {
        port powerIn : PowerIn;
        port dataOut : DataOut;
        attribute maxRange : DistanceM;
    }

    part def Imu {
        port powerIn : PowerIn;
        port dataOut : DataOut;
        attribute updateRateHz : Real;
    }

    part def Arm {
        port powerIn : PowerIn;
        port controlPort : ControlIn;
        
        part shoulder : MotorizedJoint;
        part elbow : MotorizedJoint;
        part wrist : MotorizedJoint;
        part gripper : Gripper;
        
        connect powerIn to shoulder.powerIn;
        connect powerIn to elbow.powerIn;
        connect powerIn to wrist.powerIn;
        connect powerIn to gripper.powerIn;
        
        connect controlPort to shoulder.controlPort;
        connect controlPort to elbow.controlPort;
        connect controlPort to wrist.controlPort;
        connect controlPort to gripper.controlPort;
    }

    part def Leg {
        port powerIn : PowerIn;
        port controlPort : ControlIn;
        
        part hip : MotorizedJoint;
        part knee : MotorizedJoint;
        part ankle : MotorizedJoint;
        
        connect powerIn to hip.powerIn;
        connect powerIn to knee.powerIn;
        connect powerIn to ankle.powerIn;
        
        connect controlPort to hip.controlPort;
        connect controlPort to knee.controlPort;
        connect controlPort to ankle.controlPort;
    }

    part def Head {
        port powerIn : PowerIn;
        port sensorOut : DataOut;
        
        part cam1 : Camera;
        part cam2 : Camera;
        part lidar : Lidar;
        
        connect powerIn to cam1.powerIn;
        connect powerIn to cam2.powerIn;
        connect powerIn to lidar.powerIn;
        
        connect cam1.dataOut to sensorOut;
        connect cam2.dataOut to sensorOut;
        connect lidar.dataOut to sensorOut;
    }

    part def Battery {
        port powerOut : PowerOut;
        attribute capacity : Real;
        attribute nominalVoltage : VoltageV;
        attribute maxDischargeCurrent : CurrentA;
    }

    action def ProcessSensors {
        in sensorData : SensorData;
    }

    action def PlanMotion;

    action def ExecuteMotion {
        out command : JointCommand;
    }

    part def CentralComputer {
        port powerIn : PowerIn;
        port sensorIn : DataIn;
        port leftArmCtrl : ControlOut;
        port rightArmCtrl : ControlOut;
        port leftLegCtrl : ControlOut;
        port rightLegCtrl : ControlOut;
        
        action processSensors : ProcessSensors;
        action planMotion : PlanMotion;
        action executeMotion : ExecuteMotion;
        
        state machine {
            state Standby;
            state ActiveMission {
                do / processSensors;
                do / planMotion;
                do / executeMotion;
            }
            state Emergency;
            
            transition init from null to Standby;
            transition standby_to_active from Standby to ActiveMission;
            transition active_to_emergency from ActiveMission to Emergency;
            transition emergency_to_standby from Emergency to Standby;
            transition active_to_standby from ActiveMission to Standby;
        }
    }

    part def Torso {
        port headPower : PowerOut;
        port leftArmPower : PowerOut;
        port rightArmPower : PowerOut;
        port leftLegPower : PowerOut;
        port rightLegPower : PowerOut;
        
        port headSensor : DataIn;
        port leftArmCtrl : ControlOut;
        port rightArmCtrl : ControlOut;
        port leftLegCtrl : ControlOut;
        port rightLegCtrl : ControlOut;
        
        part battery : Battery;
        part computer : CentralComputer;
        part imu : Imu;
        
        connect battery.powerOut to computer.powerIn;
        connect battery.powerOut to imu.powerIn;
        connect battery.powerOut to headPower;
        connect battery.powerOut to leftArmPower;
        connect battery.powerOut to rightArmPower;
        connect battery.powerOut to leftLegPower;
        connect battery.powerOut to rightLegPower;
        
        connect imu.dataOut to computer.sensorIn;
        connect headSensor to computer.sensorIn;
        
        connect computer.leftArmCtrl to leftArmCtrl;
        connect computer.rightArmCtrl to rightArmCtrl;
        connect computer.leftLegCtrl to leftLegCtrl;
        connect computer.rightLegCtrl to rightLegCtrl;
    }

    part def ValkyrieR5 {
        part head : Head;
        part torso : Torso;
        part leftArm : Arm;
        part rightArm : Arm;
        part leftLeg : Leg;
        part rightLeg : Leg;
        
        connect torso.headPower to head.powerIn;
        connect head.sensorOut to torso.headSensor;
        
        connect torso.leftArmPower to leftArm.powerIn;
        connect torso.leftArmCtrl to leftArm.controlPort;
        
        connect torso.rightArmPower to rightArm.powerIn;
        connect torso.rightArmCtrl to rightArm.controlPort;
        
        connect torso.leftLegPower to leftLeg.powerIn;
        connect torso.leftLegCtrl to leftLeg.controlPort;
        
        connect torso.rightLegPower to rightLeg.powerIn;
        connect torso.rightLegCtrl to rightLeg.controlPort;
    }

    requirement def HumanoidStructureRequirement {
        doc /* The robot has a complete humanoid structure with a head, torso, two arms, and two legs. */
    }

    requirement def LimbJointRequirement {
        doc /* Limbs are comprised of multiple motorized joints: hip, knee, ankle for legs; shoulder, elbow, wrist for arms. */
    }

    requirement def BipedalWalkingRequirement {
        doc /* Legs are designed for stable, bipedal walking, capable of taking high steps over obstacles and covering ground with a significant stride. */
    }

    requirement def ManipulatorRequirement {
        doc /* Arms are highly capable manipulators ending in a gripper that can open, close, and hold objects with considerable force. */
    }

    requirement def CentralComputerRequirement {
        doc /* A powerful central computer in the torso processes information, makes decisions, and coordinates actions. */
    }

    requirement def PowerSystemRequirement {
        doc /* A high-capacity, rechargeable battery pack in the torso distributes electricity to all components. */
    }

    requirement def SensorSuiteRequirement {
        doc /* Head contains a high-resolution vision system and LiDAR. Torso contains an IMU for balance. */
    }

    requirement def OperationalStateRequirement {
        doc /* Robot operates through standby, active mission execution, and emergency mode states. */
    }

    requirement def AutonomousBehaviorRequirement {
        doc /* Active state performs a continuous loop of perceiving environment, planning, and executing actions like walking or manipulating. */
    }

    requirement r1 : HumanoidStructureRequirement {
        subject robot : ValkyrieR5;
    }

    requirement r2 : LimbJointRequirement {
        subject leftArm : Arm;
        subject rightArm : Arm;
        subject leftLeg : Leg;
        subject rightLeg : Leg;
    }

    requirement r3 : BipedalWalkingRequirement {
        subject leftLeg : Leg;
        subject rightLeg : Leg;
    }

    requirement r4 : ManipulatorRequirement {
        subject leftArm : Arm;
        subject rightArm : Arm;
    }

    requirement r5 : CentralComputerRequirement {
        subject computer : CentralComputer;
    }

    requirement r6 : PowerSystemRequirement {
        subject battery : Battery;
    }

    requirement r7 : SensorSuiteRequirement {
        subject head : Head;
        subject torso : Torso;
    }

    requirement r8 : OperationalStateRequirement {
        subject computer : CentralComputer;
    }

    requirement r9 : AutonomousBehaviorRequirement {
        subject computer : CentralComputer;
    }
}
