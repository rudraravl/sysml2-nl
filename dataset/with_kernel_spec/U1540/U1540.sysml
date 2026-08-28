package ValkyrieR5 {
    private import ISQ::**;
    private import ScalarValues::**;
    
    attribute def TorqueValue :> ISQ::TorqueValue;
    attribute def AngleValue :> ISQ::AngleValue;
    attribute def ForceValue :> ISQ::ForceValue;
    attribute def ElectricChargeValue :> ISQ::ElectricChargeValue;
    
    attribute def SigActivate;
    attribute def SigEmergency;
    attribute def SigReset;
    
    part def MotorizedJoint {
        attribute maxTorque : TorqueValue;
        attribute currentAngle : AngleValue;
        in port powerIn;
        in port commandIn;
        out port feedbackOut;
    }
    
    part def Gripper {
        attribute maxGripForce : ForceValue;
        attribute isOpen : Boolean;
        in port powerIn;
        in port commandIn;
        perform action open {
            first start;
            then action unlockFingers;
            then action retractFingers;
            then done;
        }
        perform action close {
            first start;
            then action extendFingers;
            then action lockFingers;
            then done;
        }
    }
    
    part def Limb {
        in port powerBus;
        in port commandBus;
    }
    
    part def Leg :> Limb {
        part hipJoint : MotorizedJoint;
        part kneeJoint : MotorizedJoint;
        part ankleJoint : MotorizedJoint;
        connect powerBus to hipJoint.powerIn;
        connect powerBus to kneeJoint.powerIn;
        connect powerBus to ankleJoint.powerIn;
        connect commandBus to hipJoint.commandIn;
        connect commandBus to kneeJoint.commandIn;
        connect commandBus to ankleJoint.commandIn;
    }
    
    part def Arm :> Limb {
        part shoulderJoint : MotorizedJoint;
        part elbowJoint : MotorizedJoint;
        part wristJoint : MotorizedJoint;
        part gripper : Gripper;
        connect powerBus to shoulderJoint.powerIn;
        connect powerBus to elbowJoint.powerIn;
        connect powerBus to wristJoint.powerIn;
        connect powerBus to gripper.powerIn;
        connect commandBus to shoulderJoint.commandIn;
        connect commandBus to elbowJoint.commandIn;
        connect commandBus to wristJoint.commandIn;
        connect commandBus to gripper.commandIn;
    }
    
    part def Sensor {
        in port powerIn;
        out port dataOut;
    }
    
    part def Camera :> Sensor {
        attribute resolution : String;
    }
    
    part def LiDAR :> Sensor;
    
    part def IMU :> Sensor {
        attribute orientation : Real;
    }
    
    part def CentralComputer {
        in port powerIn;
        in port sensorDataIn;
        out port motorCommandsOut;
    }
    
    part def BatteryPack {
        attribute capacity : ElectricChargeValue;
        out port powerOut;
    }
    
    part def ValkyrieRobot {
        part head {
            part visionSystem {
                part cameras[2] : Camera;
                in port powerIn;
                out port dataOut;
                connect powerIn to cameras.powerIn;
                connect cameras.dataOut to dataOut;
            }
            part lidar : LiDAR;
        }
        part torso {
            part centralComputer : CentralComputer;
            part batteryPack : BatteryPack;
            part imu : IMU;
        }
        part leftArm : Arm;
        part rightArm : Arm;
        part leftLeg : Leg;
        part rightLeg : Leg;
        
        connect torso.batteryPack.powerOut to torso.centralComputer.powerIn;
        connect torso.batteryPack.powerOut to leftArm.powerBus;
        connect torso.batteryPack.powerOut to rightArm.powerBus;
        connect torso.batteryPack.powerOut to leftLeg.powerBus;
        connect torso.batteryPack.powerOut to rightLeg.powerBus;
        connect torso.batteryPack.powerOut to head.visionSystem.powerIn;
        connect torso.batteryPack.powerOut to head.lidar.powerIn;
        connect torso.batteryPack.powerOut to torso.imu.powerIn;
        
        connect head.visionSystem.dataOut to torso.centralComputer.sensorDataIn;
        connect head.lidar.dataOut to torso.centralComputer.sensorDataIn;
        connect torso.imu.dataOut to torso.centralComputer.sensorDataIn;
        
        connect torso.centralComputer.motorCommandsOut to leftArm.commandBus;
        connect torso.centralComputer.motorCommandsOut to rightArm.commandBus;
        connect torso.centralComputer.motorCommandsOut to leftLeg.commandBus;
        connect torso.centralComputer.motorCommandsOut to rightLeg.commandBus;
        
        perform action perceiveEnvironment {
            first start;
            then action readSensors;
            then action fuseData;
            then done;
        }
        perform action planAction {
            first start;
            then action analyzeEnvironment;
            then action generateTrajectory;
            then done;
        }
        perform action executeAction {
            first start;
            then action sendMotorCommands;
            then done;
        }
        
        state robotStates {
            entry; then standby;
            state standby;
            accept SigActivate then active;
            state active {
                entry; then perceiving;
                state perceiving {
                    do action perceiveEnvironment;
                }
                transition t1 first perceiving then planning;
                state planning {
                    do action planAction;
                }
                transition t2 first planning then executing;
                state executing {
                    do action executeAction;
                }
                transition t3 first executing then perceiving;
            }
            accept SigEmergency then emergency;
            state emergency;
            accept SigReset then standby;
        }
    }

    requirement def BipedalMovementRequirement {
        doc /* The robot shall walk bipedally with stable gait control on uneven terrain. */
    }
    requirement def DexterousManipulationRequirement {
        doc /* The arms shall provide full range of motion and the grippers shall hold objects with considerable force. */
    }
    requirement def EnvironmentalPerceptionRequirement {
        doc /* The sensor suite shall map the 3D environment for obstacle avoidance and object recognition. */
    }

    requirement bipedalMovement : BipedalMovementRequirement {
        subject robot : ValkyrieRobot;
    }
    requirement dexterousManipulation : DexterousManipulationRequirement {
        subject robot : ValkyrieRobot;
    }
    requirement environmentalPerception : EnvironmentalPerceptionRequirement {
        subject robot : ValkyrieRobot;
    }
}
