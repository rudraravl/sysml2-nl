package 'Rainbow RB-5 Robot' {
    private import ScalarValues::*;
    private import ISQ::*;
    
    package Definitions {
        attribute def JointAngle :> PlaneAngleValue;
        attribute def JointTorque :> TorqueValue;
        attribute def GripperForce :> ForceValue;
        attribute def CartesianPosition :> LengthValue;
        
        attribute def PowerOnSignal;
        attribute def TrajectoryCommand;
        attribute def PickPlaceCommand;
        attribute def TrajectoryComplete;
        attribute def PartSecured;
        attribute def AtAssemblyPoint;
        attribute def ReleaseComplete;
        attribute def ResetSignal;
        
        item def Trajectory {
            attribute waypoints : CartesianPosition[0..*];
        }
        item def Part;
        item def SensorData;
        item def ImageData;
        
        port def CommandPort {
            in cmd : TrajectoryCommand;
            out status : SensorData;
        }
        port def ActuatorDrivePort {
            out driveSignal : Real;
        }
        port def GripperControlPort {
            out gripCmd : Real;
        }
        port def VisionPort {
            out image : ImageData;
        }
        port def ForceTorquePort {
            out ftData : SensorData;
        }
        
        part def RigidLink {
            attribute length : LengthValue;
            attribute mass : MassValue;
        }
        
        part def JointActuator {
            port driveIn : ActuatorDrivePort;
            attribute currentAngle : JointAngle;
            attribute currentTorque : JointTorque;
            action drive;
        }
        
        part def Gripper {
            port controlIn : GripperControlPort;
            attribute appliedForce : GripperForce;
            action grasp;
            action release;
        }
        
        action def Initialize;
        action def Calibrate;
        action def ExecuteTrajectory {
            in traj : Trajectory;
        }
        
        part def CentralController {
            port cmdIn : CommandPort;
            port actuatorOut1 : ActuatorDrivePort;
            port actuatorOut2 : ActuatorDrivePort;
            port actuatorOut3 : ActuatorDrivePort;
            port actuatorOut4 : ActuatorDrivePort;
            port actuatorOut5 : ActuatorDrivePort;
            port actuatorOut6 : ActuatorDrivePort;
            port gripperOut : GripperControlPort;
            port visionIn : VisionPort;
            port ftIn : ForceTorquePort;
            
            perform action initialize : Initialize;
            perform action calibrate : Calibrate;
            perform action executeTrajectory : ExecuteTrajectory;
        }
        
        part def VisionSensor {
            port visionOut : VisionPort;
            action captureImage {
                out img : ImageData;
            }
        }
        
        part def ForceTorqueSensor {
            port ftOut : ForceTorquePort;
            attribute measuredForce : GripperForce;
            attribute measuredTorque : JointTorque;
        }
        
        part def RobotArm {
            part links : RigidLink[6];
            part joints : JointActuator[6];
            part gripper : Gripper;
            part controller : CentralController;
            part vision : VisionSensor;
            part forceTorque : ForceTorqueSensor;
            
            attribute collisionThreshold : GripperForce = 50.0 [N];
            
            exhibit state robotStates parallel {
                state operationalStates {
                    entry; then poweredOff;
                    state poweredOff;
                    accept PowerOnSignal then initializing;
                    state initializing {
                        entry controller.initialize;
                    }
                    then calibrating;
                    state calibrating {
                        entry controller.calibrate;
                    }
                    then ready;
                    state ready;
                    accept TrajectoryCommand then executingTrajectory;
                    accept PickPlaceCommand then picking;
                    state executingTrajectory {
                        do controller.executeTrajectory;
                    }
                    accept TrajectoryComplete then ready;
                    state picking {
                        do gripper.grasp;
                    }
                    accept PartSecured then movingToAssembly;
                    state movingToAssembly {
                        do controller.executeTrajectory;
                    }
                    accept AtAssemblyPoint then releasing;
                    state releasing {
                        do gripper.release;
                    }
                    accept ReleaseComplete then ready;
                }
                state safetyStates {
                    entry; then monitoring;
                    state monitoring;
                    accept when forceTorque.measuredForce > collisionThreshold
                        then emergencyStop;
                    state emergencyStop;
                    accept ResetSignal then monitoring;
                }
            }
        }
        
        requirement def SafetyRequirement {
            subject robot : RobotArm;
            doc /* The robot must enter emergency stop if collision force exceeds the threshold. */
        }
        
        requirement def AccuracyRequirement {
            subject robot : RobotArm;
            doc /* The robot must position its end-effector with high accuracy and repeatability. */
            attribute positioningAccuracy : LengthValue = 0.1 [mm];
        }
    }
    
    package Usages {
        private import Definitions::*;
        
        part rb5 : RobotArm {
            part link1 : RigidLink :> links;
            part link2 : RigidLink :> links;
            part link3 : RigidLink :> links;
            part link4 : RigidLink :> links;
            part link5 : RigidLink :> links;
            part link6 : RigidLink :> links;
            
            part joint1 : JointActuator :> joints;
            part joint2 : JointActuator :> joints;
            part joint3 : JointActuator :> joints;
            part joint4 : JointActuator :> joints;
            part joint5 : JointActuator :> joints;
            part joint6 : JointActuator :> joints;
            
            connect controller.actuatorOut1 to joint1.driveIn;
            connect controller.actuatorOut2 to joint2.driveIn;
            connect controller.actuatorOut3 to joint3.driveIn;
            connect controller.actuatorOut4 to joint4.driveIn;
            connect controller.actuatorOut5 to joint5.driveIn;
            connect controller.actuatorOut6 to joint6.driveIn;
            
            connect controller.gripperOut to gripper.controlIn;
            connect vision.visionOut to controller.visionIn;
            connect forceTorque.ftOut to controller.ftIn;
        }
        
        requirement safetyReq : SafetyRequirement {
            subject = rb5;
        }
        
        requirement accuracyReq : AccuracyRequirement {
            subject = rb5;
        }
    }
}
