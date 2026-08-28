package AutonomousMobileRobotModel {
    public import Definitions::*;
    public import ISQ::*;
    public import ScalarValues::*;

    package Definitions {
        public import PartDefinitions::*;
        public import PortDefinitions::*;
        public import ItemDefinitions::*;
        public import SignalDefinitions::*;
        public import ActionDefinitions::*;
        public import RequirementDefinitions::*;
        public import AttributeDefinitions::*;

        package AttributeDefinitions {
            attribute def TaskType;
        }

        package ItemDefinitions {
            item def Destination {
                attribute x :> ISQ::length;
                attribute y :> ISQ::length;
            }
            item def Path;
            item def Obstacle {
                attribute distance :> ISQ::length;
                attribute bearing :> ISQ::planeAngle;
            }
            item def TaskCommand {
                attribute taskType : TaskType;
                attribute targetForce :> ISQ::force;
            }
            item def SensorData {
                attribute position : Destination;
                attribute frontDistance :> ISQ::length;
                attribute rearDistance :> ISQ::length;
            }
            item def DriveCommand {
                attribute leftWheelSpeed :> ISQ::angularVelocity;
                attribute rightWheelSpeed :> ISQ::angularVelocity;
            }
            item def ArmCommand {
                attribute targetForce :> ISQ::force;
                attribute extend : Boolean;
            }
            item def StatusReport {
                attribute code : Integer;
                attribute description : String;
            }
        }

        package SignalDefinitions {
            attribute def MissionCommand {
                attribute destination : Destination;
                attribute task : TaskCommand;
            }
            attribute def PathCalculatedSignal;
            attribute def ObstacleDetectedSignal {
                attribute distance :> ISQ::length;
            }
            attribute def DestinationReachedSignal;
            attribute def TaskCompleteSignal;
            attribute def ResetCommand;
        }

        package PortDefinitions {
            port def CommandPort;
            port def DriveCmdPort;
            port def SensorDataPort;
            port def ArmCmdPort;
            port def WheelMotionPort;
            port def PowerPort;
        }

        package ActionDefinitions {
            action def PlanPath {
                in currentPosition : Destination;
                in destination : Destination;
                in sensorData : SensorData;
                out path : Path;
            }
            action def ReplanPath {
                in currentPath : Path;
                in sensorData : SensorData;
                out newPath : Path;
            }
            action def MoveAlongPath {
                in path : Path;
                out driveCommand : DriveCommand;
            }
            action def ExecuteTask {
                in taskCommand : TaskCommand;
                out armCommand : ArmCommand;
            }
            action def GraspObject {
                in targetForce :> ISQ::force;
                out appliedForce :> ISQ::force;
            }
            action def ReleaseObject;
            action def NavigateToDestination;
            action def MoveForward;
            action def MoveBackward;
            action def Turn;
        }

        package RequirementDefinitions {
            requirement def ObstacleClearanceRequirement {
                doc /* The robot must always maintain a distance of at least 0.5 meters from any detected obstacle. */
                subject robot : MobileRobot;
                attribute minSafeDistance :> ISQ::length = 0.5[m];
                constraint {
                    robot.sensorArray.frontProximitySensor.detectedDistance >= minSafeDistance
                }
                constraint {
                    robot.sensorArray.rearProximitySensor.detectedDistance >= minSafeDistance
                }
            }

            requirement def RobotMassRequirement {
                doc /* The robot shall weigh 30 kg. */
                subject robot : MobileRobot;
                attribute targetMass :> ISQ::mass = 30[kg];
                constraint { robot.mass == targetMass }
            }

            requirement def BatteryPoweredRequirement {
                doc /* The robot shall be powered by an onboard battery with sufficient capacity. */
                subject robot : MobileRobot;
                attribute minCapacity :> ISQ::energy = 1800000[J];
                constraint { robot.battery.energyCapacity >= minCapacity }
            }

            requirement def GripperForceRequirement {
                doc /* The gripper shall be capable of applying significant force to hold objects. */
                subject gripper : Gripper;
                attribute minGripForce :> ISQ::force = 10[N];
                constraint { gripper.maxGripForce >= minGripForce }
            }

            requirement def NavigationRequirement {
                doc /* The robot shall navigate to a specified destination and execute a physical task. */
                subject robot : MobileRobot;
            }
        }

        package PartDefinitions {
            part def MobileRobot {
                attribute mass :> ISQ::mass = 30[kg];
                attribute positionX :> ISQ::length;
                attribute positionY :> ISQ::length;
                attribute velocity :> ISQ::speed;
                attribute headingAngle :> ISQ::planeAngle;

                port commandPort : CommandPort;

                part controlComputer : ControlComputer;
                part differentialDrive : DifferentialDrive;
                part sensorArray : SensorArray;
                part manipulatorArm : ManipulatorArm;
                part battery : Battery;

                connect controlComputer.driveCmdOutPort to differentialDrive.driveCmdInPort;
                connect sensorArray.sensorDataOutPort to controlComputer.sensorDataInPort;
                connect controlComputer.armCmdOutPort to manipulatorArm.armCmdInPort;
                connect battery.powerOutPort to controlComputer.powerInPort;
                connect battery.powerOutPort to differentialDrive.powerInPort;
                connect battery.powerOutPort to sensorArray.powerInPort;
                connect battery.powerOutPort to manipulatorArm.powerInPort;

                perform action navigateToDestination : NavigateToDestination;
                perform action executeTask : ExecuteTask;
                perform action planPath : PlanPath;
                perform action moveAlongPath : MoveAlongPath;

                exhibit state robotStates {
                    entry; then idle;
                    state idle;
                    state navigating {
                        do planPath;
                    }
                    state moving {
                        do moveAlongPath;
                    }
                    state executing {
                        do executeTask;
                    }
                    state completed;

                    transition idle_To_navigating
                        first idle
                        accept missionCmd : MissionCommand via commandPort
                        then navigating;

                    transition navigating_To_moving
                        first navigating
                        accept PathCalculatedSignal
                        then moving;

                    transition moving_To_navigating
                        first moving
                        accept obsDetected : ObstacleDetectedSignal
                            if obsDetected.distance < 0.5[m]
                        then navigating;

                    transition moving_To_executing
                        first moving
                        accept DestinationReachedSignal
                        then executing;

                    transition executing_To_completed
                        first executing
                        accept TaskCompleteSignal
                        then completed;

                    transition completed_To_idle
                        first completed
                        accept ResetCommand
                        then idle;
                }

                satisfy ObstacleClearanceRequirement;
                satisfy RobotMassRequirement;
                satisfy BatteryPoweredRequirement;
                satisfy NavigationRequirement;
            }

            part def ControlComputer {
                attribute processingPower :> ISQ::power = 15[W];
                attribute plannedPath : Path;

                port missionCmdInPort : CommandPort;
                port driveCmdOutPort : DriveCmdPort;
                port sensorDataInPort : SensorDataPort;
                port armCmdOutPort : ArmCmdPort;
                port powerInPort : PowerPort;
                port statusOutPort : CommandPort;

                perform action planPath : PlanPath;
                perform action replanPath : ReplanPath;
            }

            part def DifferentialDrive {
                attribute maxSpeed :> ISQ::speed = 2[m/s];
                attribute trackWidth :> ISQ::length = 0.4[m];

                port driveCmdInPort : DriveCmdPort;
                port powerInPort : PowerPort;

                part leftWheel : MotorizedWheel;
                part rightWheel : MotorizedWheel;

                connect driveCmdInPort to leftWheel.motionPort;
                connect driveCmdInPort to rightWheel.motionPort;

                perform action moveForward : MoveForward;
                perform action moveBackward : MoveBackward;
                perform action turn : Turn;
            }

            part def MotorizedWheel {
                attribute wheelDiameter :> ISQ::length = 0.15[m];
                attribute maxTorque :> ISQ::torque;
                attribute angularVelocity :> ISQ::angularVelocity;
                port motionPort : WheelMotionPort;
                port powerInPort : PowerPort;
            }

            part def SensorArray {
                attribute measurementRange :> ISQ::length = 2.0[m];

                port sensorDataOutPort : SensorDataPort;
                port powerInPort : PowerPort;

                part positionSensor : PositionSensor;
                part frontProximitySensor : ProximitySensor;
                part rearProximitySensor : ProximitySensor;

                connect positionSensor.dataOutPort to sensorDataOutPort;
                connect frontProximitySensor.dataOutPort to sensorDataOutPort;
                connect rearProximitySensor.dataOutPort to sensorDataOutPort;
            }

            part def PositionSensor {
                attribute position : Destination;
                attribute accuracy :> ISQ::length = 0.05[m];
                port dataOutPort : SensorDataPort;
            }

            part def ProximitySensor {
                attribute detectionRange :> ISQ::length = 2.0[m];
                attribute detectedDistance :> ISQ::length;
                attribute isObstacleDetected : Boolean;
                port dataOutPort : SensorDataPort;
            }

            part def ManipulatorArm {
                attribute armReach :> ISQ::length = 0.5[m];
                attribute maxForce :> ISQ::force = 100[N];

                port armCmdInPort : ArmCmdPort;
                port powerInPort : PowerPort;

                part gripper : Gripper;

                connect armCmdInPort to gripper.controlPort;

                perform action graspObject : GraspObject;
                perform action releaseObject : ReleaseObject;
            }

            part def Gripper {
                attribute maxGripForce :> ISQ::force = 100[N];
                attribute appliedForce :> ISQ::force;
                port controlPort : ArmCmdPort;

                satisfy GripperForceRequirement;
            }

            part def Battery {
                attribute energyCapacity :> ISQ::energy = 1800000[J];
                attribute currentCharge :> ISQ::energy;
                attribute nominalVoltage :> ISQ::electricPotential = 12[V];
                port powerOutPort : PowerPort;
            }
        }
    }
}
