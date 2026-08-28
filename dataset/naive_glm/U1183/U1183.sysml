package AutonomousRobot {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;
    import ISQForce::*;
    import ISQMass::*;
    import ISQEnergy::*;
    import ISQElectricity::*;

    // ---- Value types with units ----
    value def MassKg :> Mass;
    value def DistanceM :> Length;
    value def VelocityMps :> Speed;
    value def ForceN :> Force;
    value def EnergyWh :> Energy;
    value def VoltageV :> ElectricPotential;
    value def CurrentA :> ElectricCurrent;
    value def AngleDeg :> Angle;

    attribute def Pose {
        attribute x : DistanceM;
        attribute y : DistanceM;
        attribute heading : AngleDeg;
    }

    attribute def Destination {
        attribute targetPose : Pose;
        attribute taskType : String;
    }

    item def ObstacleDetected {
        attribute distance : DistanceM;
        attribute direction : AngleDeg;
    }

    item def Command {
        attribute destination : Destination;
    }

    item def PathPlan {
        attribute waypoints : Pose[0..*];
        attribute safe : Boolean;
    }

    item def TaskResult {
        attribute success : Boolean;
        attribute gripperForceApplied : ForceN;
    }

    // ---- Ports / interfaces ----
    port def PowerPort {
        attribute voltage : VoltageV;
        out attribute current : CurrentA;
    }

    port def SensorDataPort {
        out item obstacle : ObstacleDetected[0..*];
        out attribute pose : Pose;
    }

    port def MotorCmdPort {
        out attribute leftWheelSpeed : VelocityMps;
        out attribute rightWheelSpeed : VelocityMps;
    }

    port def ArmCmdPort {
        out attribute targetGripperForce : ForceN;
        out attribute extend : Boolean;
    }

    port def CommandPort {
        in item command : Command;
        out item result : TaskResult;
    }

    // ---- Component parts ----
    part def Battery {
        attribute capacity : EnergyWh = 240 [Wh];
        attribute voltage : VoltageV = 24 [V];
        attribute chargeLevel : Real = 1.0;
        port powerOut : PowerPort;
    }

    part def ControlComputer {
        port cmdIn : CommandPort;
        port sensorIn : SensorDataPort;
        port motorOut : MotorCmdPort;
        port armOut : ArmCmdPort;

        attribute minSafeDistance : DistanceM = 0.5 [m];

        action def computePath {
            in target : Pose;
            in currentPose : Pose;
            in obstacles : ObstacleDetected[0..*];
            out path : PathPlan;
        }

        action def checkSafety {
            in obstacles : ObstacleDetected[0..*];
            out safe : Boolean;
        }

        action def executeTask {
            in taskType : String;
            out result : TaskResult;
        }
    }

    part def MotorizedWheel {
        attribute wheelRadius : DistanceM = 0.1 [m];
        attribute maxSpeed : VelocityMps = 1.5 [m/s];
        port cmdIn : MotorCmdPort;
        attribute commandedSpeed : VelocityMps;
    }

    part def DifferentialDrive {
        part leftWheel : MotorizedWheel;
        part rightWheel : MotorizedWheel;
        port cmdIn : MotorCmdPort;

        action def moveForward {
            in speed : VelocityMps;
        }
        action def moveBackward {
            in speed : VelocityMps;
        }
        action def turn {
            in angularRate : Real;
        }
        action def stop;
    }

    part def PositionSensor {
        attribute pose : Pose;
        port dataOut : SensorDataPort;
    }

    part def ProximitySensor {
        attribute range : DistanceM = 2.0 [m];
        attribute fieldOfView : AngleDeg = 60 [deg];
        port dataOut : SensorDataPort;
    }

    part def SensorArray {
        part positionSensor : PositionSensor;
        part frontProximity : ProximitySensor;
        part rearProximity : ProximitySensor;
        port dataOut : SensorDataPort;
    }

    part def Gripper {
        attribute maxForce : ForceN = 50 [N];
        attribute currentForce : ForceN;
        port cmdIn : ArmCmdPort;
    }

    part def ManipulatorArm {
        attribute reach : DistanceM = 0.6 [m];
        part gripper : Gripper;
        port cmdIn : ArmCmdPort;

        action def grasp {
            in force : ForceN;
        }
        action def release;
        action def extendArm {
            in distance : DistanceM;
        }
    }

    // ---- The robot ----
    part def AutonomousMobileRobot {
        attribute totalMass : MassKg = 30 [kg];

        port cmdPort : CommandPort;

        part battery : Battery;
        part computer : ControlComputer;
        part drive : DifferentialDrive;
        part sensors : SensorArray;
        part arm : ManipulatorArm;

        // Power distribution
        connection powerBatteryToComputer connect battery.powerOut to computer.cmdIn;
        connection powerBatteryToDrive connect battery.powerOut to drive.cmdIn;

        // Sensor data to computer
        connection sensorData connect sensors.dataOut to computer.sensorIn;

        // Motor commands
        connection motorCommands connect computer.motorOut to drive.cmdIn;

        // Arm commands
        connection armCommands connect computer.armOut to arm.cmdIn;

        // External command interface
        flow commandFlow from cmdPort.command to computer.cmdIn.command;
        flow resultFlow from computer.cmdIn.result to cmdPort.result;

        // ---- State machine ----
        state def OperationalLifecycle {
            entry; then idle;

            state idle;
            state navigating;
            state moving;
            state replanning;
            state executing;
            state completed;

            transition t_idle_to_navigating
                from idle to navigating
                when cmdPort.command->notEmpty();

            transition t_navigating_to_moving
                from navigating to moving
                when computer.computePath.path.safe;

            transition t_moving_to_replanning
                from moving to replanning
                when sensors.dataOut.obstacle->select(d | d.distance < computer.minSafeDistance)->size() > 0;

            transition t_replanning_to_moving
                from replanning to moving
                when computer.computePath.path.safe;

            transition t_moving_to_executing
                from moving to executing
                when sensors.dataOut.pose == cmdPort.command.destination.targetPose;

            transition t_executing_to_completed
                from executing to completed
                when computer.executeTask.result.success;

            transition t_completed_to_idle
                from completed to idle
                when true;

            do action cycleMonitor {
                // Continuous safety monitoring
                if sensors.dataOut.obstacle->select(d | d.distance < computer.minSafeDistance)->size() > 0 {
                    drive.stop();
                }
            }
        }

        part behavior controller : OperationalLifecycle;

        // ---- Main mission action ----
        action def MissionExecution {
            in destination : Destination;
            out result : TaskResult;

            action receiveCommand {
                out cmd : Command;
            }
            action planPath {
                in target : Pose;
                in currentPose : Pose;
                in obstacles : ObstacleDetected[0..*];
                out path : PathPlan;
            }
            action traversePath {
                in path : PathPlan;
                in obstacles : ObstacleDetected[0..*];
            }
            action performTask {
                in taskType : String;
                out taskResult : TaskResult;
            }

            flow cmdFlow from receiveCommand.cmd to planPath.target;
            flow pathFlow from planPath.path to traversePath.path;
            flow taskFlow from traversePath to performTask;

            // Safety enforcement
            if planPath.obstacles->select(d | d.distance < 0.5 [m])->size() > 0 {
                planPath.path.safe = false;
            }
        }
    }

    // ---- Requirements ----
    requirement def SafetyDistanceRequirement {
        subject robot : AutonomousMobileRobot;
        objective {
            doc /* The robot must always maintain a distance of at least half a meter from any detected obstacle. */
            assert robot.sensors.dataOut.obstacle->forAll(d | d.distance >= 0.5 [m]);
        }
    }

    requirement def NavigationRequirement {
        subject robot : AutonomousMobileRobot;
        objective {
            doc /* The robot shall navigate to a received destination using a safe path. */
            assert robot.controller.idle->transition->navigating->transition->moving->transition->executing;
        }
    }

    requirement def ManipulatorForceRequirement {
        subject arm : ManipulatorArm;
        objective {
            doc /* The gripper shall be capable of applying significant force to hold objects. */
            assert arm.gripper.maxForce >= 30 [N];
        }
    }

    requirement def MassRequirement {
        subject robot : AutonomousMobileRobot;
        objective {
            doc /* The robot shall be a self-contained unit weighing 30 kg. */
            assert robot.totalMass == 30 [kg];
        }
    }

    requirement def PowerRequirement {
        subject robot : AutonomousMobileRobot;
        objective {
            doc /* The robot shall be powered by an onboard battery. */
            assert robot.battery.capacity > 0 [Wh];
        }
    }

    requirement def ObstacleReplanRequirement {
        subject robot : AutonomousMobileRobot;
        objective {
            doc /* If an obstacle is detected during movement, the robot shall stop and re-plan its route. */
            assert robot.controller.moving->transition->replanning->transition->moving;
        }
    }

    requirement def LifecycleRequirement {
        subject robot : AutonomousMobileRobot;
        objective {
            doc /* Operational cycle: idle -> navigating -> moving -> executing -> completed -> idle. */
            assert robot.controller.OperationalLifecycle.states->includesAll({'idle','navigating','moving','replanning','executing','completed'});
        }
    }

    // ---- Satisfaction ----
    satisfaction massSatisfies : MassRequirement satisfy AutonomousMobileRobot;
    satisfaction powerSatisfies : PowerRequirement satisfy AutonomousMobileRobot;
    satisfaction safetySatisfies : SafetyDistanceRequirement satisfy AutonomousMobileRobot;
    satisfaction navSatisfies : NavigationRequirement satisfy AutonomousMobileRobot;
    satisfaction forceSatisfies : ManipulatorForceRequirement satisfy ManipulatorArm;
    satisfaction replanSatisfies : ObstacleReplanRequirement satisfy AutonomousMobileRobot;
    satisfaction lifecycleSatisfies : LifecycleRequirement satisfy AutonomousMobileRobot;
}
