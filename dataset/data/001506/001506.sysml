package MotionPlanningSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def Pose {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
        attribute roll : Real;
        attribute pitch : Real;
        attribute yaw : Real;
    }
    
    attribute def Twist {
        attribute linearX : SpeedValue;
        attribute linearY : SpeedValue;
        attribute linearZ : SpeedValue;
        attribute angularX : AngularVelocityValue;
        attribute angularY : AngularVelocityValue;
        attribute angularZ : AngularVelocityValue;
    }
    
    item def Obstacle {
        attribute position : Pose;
        attribute dimensions : LengthValue[3];
        attribute velocity : Twist;
        attribute classification : String;
    }
    
    item def EnvironmentModel {
        attribute obstacles : Obstacle[*];
        attribute boundaries : LengthValue[6];
        attribute resolution : LengthValue;
        attribute timestamp : TimeValue;
    }
    
    item def Waypoint {
        attribute pose : Pose;
        attribute velocity : SpeedValue;
        attribute timestamp : TimeValue;
    }
    
    item def Trajectory {
        attribute waypoints : Waypoint[*] ordered;
        attribute totalLength : LengthValue;
        attribute estimatedDuration : TimeValue;
        attribute safetyScore : Real;
    }
    
    item def PlanningConstraints {
        attribute maxVelocity : SpeedValue;
        attribute maxAcceleration : AccelerationValue;
        attribute minTurningRadius : LengthValue;
        attribute obstacleMargin : LengthValue;
    }
    
    port def EnvironmentSensorPort {
        in item environmentData : EnvironmentModel;
    }
    
    port def StateEstimationPort {
        in item currentPose : Pose;
        in item currentTwist : Twist;
    }
    
    port def GoalPort {
        in item targetPose : Pose;
    }
    
    port def TrajectoryOutputPort {
        out item plannedTrajectory : Trajectory;
    }
    
    port def ControlCommandPort {
        out item velocityCommand : Twist;
    }
    
    action def ScanEnvironment {
        out environmentModel : EnvironmentModel;
    }
    
    action def EstimateState {
        out currentPose : Pose;
        out currentVelocity : Twist;
    }
    
    action def GenerateGlobalPath {
        in startPose : Pose;
        in goalPose : Pose;
        in environment : EnvironmentModel;
        in constraints : PlanningConstraints;
        out globalPath : Trajectory;
        out pathFound : Boolean;
    }
    
    action def OptimizeLocalTrajectory {
        in globalPath : Trajectory;
        in currentPose : Pose;
        in currentVelocity : Twist;
        in localEnvironment : EnvironmentModel;
        in constraints : PlanningConstraints;
        out localTrajectory : Trajectory;
    }
    
    action def ValidateTrajectory {
        in trajectory : Trajectory;
        in environment : EnvironmentModel;
        in constraints : PlanningConstraints;
        out isValid : Boolean;
        out collisionFree : Boolean;
        out constraintsSatisfied : Boolean;
    }
    
    action def ComputeVelocityCommand {
        in trajectory : Trajectory;
        in currentPose : Pose;
        in currentVelocity : Twist;
        out velocityCommand : Twist;
    }
    
    part def PerceptionSubsystem {
        attribute sensorUpdateRate : FrequencyValue;
        
        port sensorData : EnvironmentSensorPort;
        
        action perceive : ScanEnvironment {
            out environmentModel;
        }
    }
    
    part def LocalizationSubsystem {
        attribute localizationAccuracy : LengthValue;
        
        port stateOutput : StateEstimationPort;
        
        action localize : EstimateState {
            out currentPose;
            out currentVelocity;
        }
    }
    
    part def GlobalPlannerSubsystem {
        attribute planningAlgorithm : String;
        attribute replanningDistance : LengthValue;
        
        port environmentInput : EnvironmentSensorPort;
        port goalInput : GoalPort;
        port stateInput : StateEstimationPort;
        
        action planGlobal : GenerateGlobalPath {
            in startPose;
            in goalPose;
            in environment;
            in constraints;
            out globalPath;
            out pathFound;
        }
    }
    
    part def LocalPlannerSubsystem {
        attribute planningHorizon : TimeValue;
        attribute updateFrequency : FrequencyValue;
        
        port environmentInput : EnvironmentSensorPort;
        port stateInput : StateEstimationPort;
        port trajectoryOutput : TrajectoryOutputPort;
        
        action planLocal : OptimizeLocalTrajectory {
            in globalPath;
            in currentPose;
            in currentVelocity;
            in localEnvironment;
            in constraints;
            out localTrajectory;
        }
        
        action validate : ValidateTrajectory {
            in trajectory;
            in environment;
            in constraints;
            out isValid;
            out collisionFree;
            out constraintsSatisfied;
        }
    }
    
    part def ControllerSubsystem {
        attribute controlFrequency : FrequencyValue;
        
        port trajectoryInput : TrajectoryOutputPort;
        port stateInput : StateEstimationPort;
        port commandOutput : ControlCommandPort;
        
        action control : ComputeVelocityCommand {
            in trajectory;
            in currentPose;
            in currentVelocity;
            out velocityCommand;
        }
    }
    
    part def MotionPlanningSystem {
        attribute systemConstraints : PlanningConstraints {
            attribute :>> maxVelocity = 2.0 [m/s];
            attribute :>> maxAcceleration = 1.0 [m/s^2];
            attribute :>> minTurningRadius = 0.5 [m];
            attribute :>> obstacleMargin = 0.3 [m];
        }
        
        attribute goalPosition : Pose;
        
        part perception : PerceptionSubsystem {
            attribute :>> sensorUpdateRate = 10.0 [Hz];
        }
        
        part localization : LocalizationSubsystem {
            attribute :>> localizationAccuracy = 0.05 [m];
        }
        
        part globalPlanner : GlobalPlannerSubsystem {
            attribute :>> planningAlgorithm = "A*";
            attribute :>> replanningDistance = 1.0 [m];
        }
        
        part localPlanner : LocalPlannerSubsystem {
            attribute :>> planningHorizon = 3.0 [s];
            attribute :>> updateFrequency = 20.0 [Hz];
        }
        
        part controller : ControllerSubsystem {
            attribute :>> controlFrequency = 50.0 [Hz];
        }
        
        connect perception.sensorData to globalPlanner.environmentInput;
        connect perception.sensorData to localPlanner.environmentInput;
        connect localization.stateOutput to globalPlanner.stateInput;
        connect localization.stateOutput to localPlanner.stateInput;
        connect localization.stateOutput to controller.stateInput;
        connect localPlanner.trajectoryOutput to controller.trajectoryInput;
        
        perform action autonomousNavigation {
            first start;
            then merge navigationLoop;
            
            then action sense : ScanEnvironment {
                out environmentModel;
            }
            
            then action estimateState : EstimateState {
                out currentPose;
                out currentVelocity;
            }
            
            then action planGlobalPath : GenerateGlobalPath {
                in startPose = estimateState.currentPose;
                in goalPose = goalPosition;
                in environment = sense.environmentModel;
                in constraints = systemConstraints;
                out globalPath;
                out pathFound;
            }
            
            then decide;
                if planGlobalPath.pathFound then optimizeLocal;
                if not planGlobalPath.pathFound then replan;
            
            action optimizeLocal : OptimizeLocalTrajectory {
                in globalPath = planGlobalPath.globalPath;
                in currentPose = estimateState.currentPose;
                in currentVelocity = estimateState.currentVelocity;
                in localEnvironment = sense.environmentModel;
                in constraints = systemConstraints;
                out localTrajectory;
            }
            
            then action validateLocal : ValidateTrajectory {
                in trajectory = optimizeLocal.localTrajectory;
                in environment = sense.environmentModel;
                in constraints = systemConstraints;
                out isValid;
                out collisionFree;
                out constraintsSatisfied;
            }
            
            then decide;
                if validateLocal.isValid then executeTrajectory;
                if not validateLocal.isValid then replan;
            
            action executeTrajectory : ComputeVelocityCommand {
                in trajectory = optimizeLocal.localTrajectory;
                in currentPose = estimateState.currentPose;
                in currentVelocity = estimateState.currentVelocity;
                out velocityCommand;
            }
            
            then decide;
                if estimateState.currentPose != goalPosition then navigationLoop;
                if estimateState.currentPose == goalPosition then goalReached;
            
            action replan;
            then navigationLoop;
            
            action goalReached;
            then done;
        }
    }
    
    requirement def SafetyRequirement {
        doc /* The motion planning system shall maintain a minimum safety margin from all detected obstacles. */
        
        subject system : MotionPlanningSystem;
        
        require constraint {
            system.systemConstraints.obstacleMargin >= 0.2 [m]
        }
    }
    
    requirement def PerformanceRequirement {
        doc /* The motion planning system shall generate a valid trajectory within specified time limits. */
        
        subject system : MotionPlanningSystem;
        
        attribute maxGlobalPlanningTime : TimeValue = 1.0 [s];
        attribute maxLocalPlanningTime : TimeValue = 0.05 [s];
        
        require constraint {
            system.localPlanner.planningHorizon <= maxGlobalPlanningTime
        }
    }
    
    requirement def KinematicConstraintRequirement {
        doc /* The motion planning system shall respect vehicle kinematic constraints. */
        
        subject system : MotionPlanningSystem;
        
        require constraint {
            system.systemConstraints.maxVelocity > 0.0 [m/s] and
            system.systemConstraints.maxAcceleration > 0.0 [m/s^2] and
            system.systemConstraints.minTurningRadius > 0.0 [m]
        }
    }
    
    requirement def CompletenessRequirement {
        doc /* The motion planning system shall find a path to the goal if one exists within the environment. */
        
        subject system : MotionPlanningSystem;
    }
    
    requirement <'MP-SYS-001'> motionPlanningSystemRequirement {
        doc /* The motion planning system shall autonomously navigate a vehicle from its current position to a 
                specified goal position while avoiding obstacles, respecting kinematic constraints, and ensuring 
                safe operation through continuous environment monitoring and trajectory optimization. */
        
        subject system : MotionPlanningSystem;
        
        assume constraint validEnvironment {
            doc /* The environment is observable and sensor data is available at sufficient rate. */
            system.perception.sensorUpdateRate >= 5.0 [Hz]
        }
        
        assume constraint validGoal {
            doc /* The goal position is reachable and within the environment boundaries. */
        }
        
        require constraint safetyReq {
            system.systemConstraints.obstacleMargin >= 0.2 [m]
        }
        
        require constraint performanceReq {
            system.localPlanner.planningHorizon <= 1.0 [s]
        }
        
        require constraint kinematicReq {
            system.systemConstraints.maxVelocity > 0.0 [m/s] and
            system.systemConstraints.maxAcceleration > 0.0 [m/s^2] and
            system.systemConstraints.minTurningRadius > 0.0 [m]
        }
        
        require constraint completenessReq {
            doc /* A valid path must be found if one exists. */
        }
    }
}
