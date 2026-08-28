package MotionPlanningSystem {
    import ScalarValues::*;

    // ===== Value Types =====
    value type Length :> Real { unit 'm'; }
    value type Distance :> Length;
    value type Velocity :> Real { unit 'm/s'; }
    value type Acceleration :> Real { unit 'm/s^2'; }
    value type Deceleration :> Acceleration;
    value type Angle :> Real { unit 'rad'; }
    value type AngularVelocity :> Real { unit 'rad/s'; }
    value type Duration :> Real { unit 's'; }
    value type Mass :> Real { unit 'kg'; }
    value type Curvature :> Real { unit '1/m'; }
    value type Confidence :> Real { unit 'percent'; }

    // ===== Item Definitions =====
    item def Obstacle {
        attribute id : String;
        attribute positionX : Length;
        attribute positionY : Length;
        attribute size : Length;
        attribute velocityX : Velocity;
        attribute velocityY : Velocity;
        attribute isMoving : Boolean;
        attribute isStationary : Boolean;
        attribute confidenceLevel : Confidence;
    }

    item def OperationalBoundary {
        attribute minX : Length;
        attribute maxX : Length;
        attribute minY : Length;
        attribute maxY : Length;
    }

    item def EnvironmentMap {
        item obstacles : Obstacle[0..*];
        attribute boundary : OperationalBoundary;
        attribute timestamp : Duration;
        attribute isUpdated : Boolean;
        attribute obstacleCount : Integer;
    }

    item def VehicleState {
        attribute positionX : Length;
        attribute positionY : Length;
        attribute roll : Angle;
        attribute pitch : Angle;
        attribute yaw : Angle;
        attribute speed : Velocity;
        attribute heading : Angle;
        attribute angularVelocity : AngularVelocity;
        attribute timestamp : Duration;
        attribute confidenceLevel : Confidence;
    }

    item def PathPoint {
        attribute x : Length;
        attribute y : Length;
        attribute curvature : Curvature;
        attribute distanceFromStart : Length;
    }

    item def GlobalPath {
        item points : PathPoint[0..*];
        attribute totalLength : Length;
        attribute goalX : Length;
        attribute goalY : Length;
        attribute isComplete : Boolean;
        attribute estimatedTime : Duration;
    }

    item def TrajectoryPoint {
        attribute x : Length;
        attribute y : Length;
        attribute yaw : Angle;
        attribute speed : Velocity;
        attribute acceleration : Acceleration;
        attribute curvature : Curvature;
        attribute timeFromStart : Duration;
    }

    item def Trajectory {
        item points : TrajectoryPoint[0..*];
        attribute duration : Duration;
        attribute isValid : Boolean;
        attribute minClearance : Length;
        attribute maxSpeedInPath : Velocity;
        attribute maxAccelInPath : Acceleration;
        attribute minTurningRadiusInPath : Length;
    }

    item def ControlCommand {
        attribute linearVelocity : Velocity;
        attribute steeringAngle : Angle;
        attribute acceleration : Acceleration;
        attribute timestamp : Duration;
    }

    item def Goal {
        attribute x : Length;
        attribute y : Length;
        attribute tolerance : Length;
        attribute isReached : Boolean;
    }

    // ===== Action Definitions =====
    action def ScanEnvironment {
        in sensorData : Real[0..*];
        out map : EnvironmentMap;
    }

    action def EstimateState {
        in sensorData : Real[0..*];
        out state : VehicleState;
    }

    action def PlanGlobalRoute {
        in map : EnvironmentMap;
        in state : VehicleState;
        in goal : Goal;
        out path : GlobalPath;
    }

    action def GenerateLocalTrajectory {
        in globalPath : GlobalPath;
        in map : EnvironmentMap;
        in state : VehicleState;
        in horizon : Duration;
        out trajectory : Trajectory;
    }

    action def SmoothTrajectory {
        in trajectory : Trajectory;
        out smoothedTrajectory : Trajectory;
    }

    action def ValidateTrajectory {
        in trajectory : Trajectory;
        in map : EnvironmentMap;
        in state : VehicleState;
        in maxSpeed : Velocity;
        in maxAccel : Acceleration;
        in minRadius : Length;
        in minMargin : Length;
        out isValid : Boolean;
        out minClearance : Length;
    }

    action def ComputeControlCommands {
        in trajectory : Trajectory;
        in state : VehicleState;
        out command : ControlCommand;
    }

    action def ExecuteActuatorCommand {
        in command : ControlCommand;
    }

    action def EmergencyBrake {
        out command : ControlCommand;
    }

    // ===== Port Definitions =====
    port def MapPort {
        out map : EnvironmentMap;
    }

    port def StatePort {
        out state : VehicleState;
    }

    port def PathPort {
        out path : GlobalPath;
    }

    port def TrajectoryPort {
        out trajectory : Trajectory;
    }

    port def CommandPort {
        out command : ControlCommand;
    }

    port def SensorDataPort {
        out sensorData : Real[0..*];
    }

    // ===== Constraint Definitions =====
    constraint def SpeedLimitConstraint {
        in speed : Velocity;
        attribute maxSpeed : Velocity = 2.0;
        constraint { speed <= maxSpeed; }
    }

    constraint def AccelerationLimitConstraint {
        in accel : Acceleration;
        attribute maxAccel : Acceleration = 1.5;
        constraint { accel <= maxAccel; }
    }

    constraint def TurningRadiusConstraint {
        in radius : Length;
        attribute minRadius : Length = 0.5;
        constraint { radius >= minRadius; }
    }

    constraint def SafetyMarginConstraint {
        in clearance : Length;
        attribute minMargin : Length = 0.3;
        constraint { clearance >= minMargin; }
    }

    constraint def TrajectoryFeasibilityConstraint {
        in trajectory : Trajectory;
        in maxSpeed : Velocity;
        in maxAccel : Acceleration;
        in minRadius : Length;
        in minMargin : Length;
        constraint {
            trajectory.isValid == true
            && trajectory.minClearance >= minMargin
            && trajectory.maxSpeedInPath <= maxSpeed
            && trajectory.maxAccelInPath <= maxAccel
            && trajectory.minTurningRadiusInPath >= minRadius
        }
    }

    constraint def LoopTimeConstraint {
        in loopDuration : Duration;
        attribute maxLoopTime : Duration = 0.1;
        constraint { loopDuration <= maxLoopTime; }
    }

    // ===== Requirement Definitions =====
    requirement def NavigationRequirement {
        doc /*
            The system shall navigate the vehicle from its current location
            to a designated goal safely and efficiently.
        */
    }

    requirement def ObstacleAvoidanceRequirement {
        doc /*
            The system shall maintain a minimum safety margin of 0.3 meters
            around all obstacles, both stationary and moving.
        */
        attribute requiredMargin : Length = 0.3;
    }

    requirement def SpeedConstraintRequirement {
        doc /*
            The system shall not exceed a maximum speed of 2.0 m/s.
        */
        attribute maxSpeed : Velocity = 2.0;
    }

    requirement def AccelerationConstraintRequirement {
        doc /*
            The system shall not exceed a maximum acceleration of 1.5 m/s^2.
        */
        attribute maxAccel : Acceleration = 1.5;
    }

    requirement def TurningRadiusRequirement {
        doc /*
            The system shall respect a minimum turning radius of 0.5 meters.
        */
        attribute minRadius : Length = 0.5;
    }

    requirement def DynamicEnvironmentRequirement {
        doc /*
            The system shall react to both stationary and moving obstacles
            in real time, updating its path and trajectory continuously.
        */
    }

    requirement def TrajectoryValidationRequirement {
        doc /*
            The local planner shall validate every trajectory for safety
            and physical feasibility before issuing it to the controller.
        */
    }

    requirement def RealTimeResponseRequirement {
        doc /*
            The system shall complete the perception-localization-planning-control
            loop within 100 milliseconds to ensure real-time responsiveness.
        */
        attribute maxLoopTime : Duration = 0.1;
    }

    requirement def SmoothMotionRequirement {
        doc /*
            The system shall generate smooth trajectories that minimize
            jerk and produce comfortable motion for the vehicle occupants.
        */
    }

    // ===== Part Definitions =====

    part def Sensor {
        port dataOut : SensorDataPort;

        attribute scanRate : Duration = 0.05;
        attribute isOnline : Boolean = true;
        attribute range : Length = 30.0;
        attribute fieldOfView : Angle = 3.14159;
        attribute angularResolution : Angle = 0.01745;
        attribute sensorType : String;

        state sensorBehavior {
            entry; then PoweringUp;

            state PoweringUp {
                entry { /* Initialize sensor hardware and calibrate */ }
            }
            transition from PoweringUp to Active
                when isOnline == true;

            state Active {
                do { /* Continuously scan environment and emit raw sensor data */ }
            }
            transition from Active to Error
                when isOnline == false;

            state Error {
                entry { /* Report sensor failure and attempt recovery */ }
            }
            transition from Error to PoweringUp
                when isOnline == true;
        }
    }

    part def PerceptionSubsystem {
        port sensorIn : ~SensorDataPort;
        port mapOut : MapPort;

        attribute processingRate : Duration = 0.1;
        attribute detectionRange : Length = 30.0;
        attribute currentMap : EnvironmentMap;
        attribute obstacleCount : Integer;
        attribute hasNewSensorData : Boolean = false;
        attribute mapReady : Boolean = false;

        state perceptionBehavior {
            entry; then Idle;

            state Idle;
            transition from Idle to Scanning
                when hasNewSensorData == true;

            state Scanning {
                entry { /* Receive and parse raw sensor data from all sensors */ }
                do { /* Aggregate multi-sensor readings into unified scan */ }
            }
            transition from Scanning to DetectingObstacles;

            state DetectingObstacles {
                entry { /* Identify obstacles using clustering and classification */ }
                do { /* Extract position, size, and velocity for each detected obstacle */ }
            }
            transition from DetectingObstacles to ClassifyingObstacles;

            state ClassifyingObstacles {
                entry { /* Classify each obstacle as stationary or moving */ }
                do { /* Estimate velocity vectors for moving obstacles */ }
            }
            transition from ClassifyingObstacles to BuildingMap;

            state BuildingMap {
                entry { /* Construct environment map with obstacle data and operational boundaries */ }
                do { /* Update obstacle list, boundary, and timestamp */ }
            }
            transition from BuildingMap to PublishingMap;

            state PublishingMap {
                entry { /* Publish updated environment map through mapOut port */ }
                do { /* Set mapReady flag to true */ }
            }
            transition from PublishingMap to Idle;
        }

        constraint detectionRangeLimit { detectionRange <= 30.0; }
    }

    part def LocalizationSubsystem {
        port sensorIn : ~SensorDataPort;
        port stateOut : StatePort;

        attribute updateRate : Duration = 0.05;
        attribute currentState : VehicleState;
        attribute positionUncertainty : Length = 0.05;
        attribute headingUncertainty : Angle = 0.0175;
        attribute hasNewSensorData : Boolean = false;
        attribute stateReady : Boolean = false;

        state localizationBehavior {
            entry; then Initializing;

            state Initializing {
                entry { /* Initialize position estimate from first sensor readings */ }
                do { /* Set initial position, orientation, and speed */ }
            }
            transition from Initializing to Estimating;

            state Estimating {
                entry { /* Fuse sensor data to estimate position, orientation, and speed */ }
                do { /* Apply filtering (e.g., Kalman filter) for state estimation */ }
            }
            transition from Estimating to UpdatingState;

            state UpdatingState {
                entry { /* Update roll, pitch, yaw, heading, and angular velocity */ }
                do { /* Compute confidence level of estimate */ }
            }
            transition from UpdatingState to PublishingState;

            state PublishingState {
                entry { /* Publish current vehicle state through stateOut port */ }
                do { /* Set stateReady flag to true */ }
            }
            transition from PublishingState to Estimating;
        }

        constraint positionAccuracy { positionUncertainty <= 0.05; }
    }

    part def GlobalPlannerSubsystem {
        port mapIn : ~MapPort;
        port stateIn : ~StatePort;
        port pathOut : PathPort;

        attribute replanningRate : Duration = 1.0;
        attribute currentPath : GlobalPath;
        attribute goal : Goal;
        attribute isPathValid : Boolean = false;
        attribute hasNewMap : Boolean = false;
        attribute hasNewState : Boolean = false;
        attribute pathReady : Boolean = false;

        state globalPlannerBehavior {
            entry; then WaitingForInputs;

            state WaitingForInputs;
            transition from WaitingForInputs to Planning
                when hasNewMap == true && hasNewState == true;

            state Planning {
                entry { /* Calculate optimal global route using full environment map and vehicle state */ }
                do { /* Apply graph search or sampling-based planning algorithm */ }
            }
            transition from Planning to OptimizingPath;

            state OptimizingPath {
                entry { /* Optimize path for smoothness, efficiency, and distance */ }
                do { /* Reduce unnecessary waypoints and smooth curvature */ }
            }
            transition from OptimizingPath to CheckingPath;

            state CheckingPath {
                entry { /* Verify path stays within operational boundaries */ }
                do { /* Check path does not intersect known static obstacles */ }
            }
            transition from CheckingPath to PublishingPath
                when isPathValid == true;
            transition from CheckingPath to Planning
                when isPathValid == false;

            state PublishingPath {
                entry { /* Publish global path through pathOut port */ }
                do { /* Set pathReady flag to true */ }
            }
            transition from PublishingPath to WaitingForInputs;
        }
    }

    part def LocalPlannerSubsystem {
        port pathIn : ~PathPort;
        port mapIn : ~MapPort;
        port stateIn : ~StatePort;
        port trajectoryOut : TrajectoryPort;

        attribute planningHorizon : Duration = 3.0;
        attribute currentTrajectory : Trajectory;
        attribute maxSpeed : Velocity = 2.0;
        attribute maxAccel : Acceleration = 1.5;
        attribute minTurningRadius : Length = 0.5;
        attribute safetyMargin : Length = 0.3;
        attribute replanningRate : Duration = 0.1;
        attribute hasNewPath : Boolean = false;
        attribute hasNewMap : Boolean = false;
        attribute hasNewState : Boolean = false;
        attribute trajectoryReady : Boolean = false;

        state localPlannerBehavior {
            entry; then Idle;

            state Idle;
            transition from Idle to GeneratingTrajectory
                when hasNewPath == true && hasNewMap == true && hasNewState == true;

            state GeneratingTrajectory {
                entry { /* Generate short-term trajectory from global path considering near environment */ }
                do { /* Anticipate vehicle states a few seconds into the future */ }
            }
            transition from GeneratingTrajectory to SmoothingTrajectory;

            state SmoothingTrajectory {
                entry { /* Apply spline or polynomial smoothing for kinematic feasibility */ }
                do { /* Ensure curvature and curvature derivative are continuous */ }
            }
            transition from SmoothingTrajectory to ValidatingTrajectory;

            state ValidatingTrajectory {
                entry { /* Check trajectory against speed, acceleration, turning radius, and safety margin */ }
                do { /* Compute minimum clearance to all obstacles along trajectory */ }
            }
            transition from ValidatingTrajectory to TrajectoryValid
                when currentTrajectory.isValid == true;
            transition from ValidatingTrajectory to GeneratingTrajectory
                when currentTrajectory.isValid == false;

            state TrajectoryValid {
                entry { /* Trajectory confirmed safe and physically achievable */ }
            }
            transition from TrajectoryValid to PublishingTrajectory;

            state PublishingTrajectory {
                entry { /* Publish validated trajectory through trajectoryOut port */ }
                do { /* Set trajectoryReady flag to true */ }
            }
            transition from PublishingTrajectory to Idle;
        }

        constraint speedConstraint : SpeedLimitConstraint { in speed = maxSpeed; }
        constraint accelConstraint : AccelerationLimitConstraint { in accel = maxAccel; }
        constraint turningRadiusConstraint : TurningRadiusConstraint { in radius = minTurningRadius; }
        constraint safetyMarginConstraint : SafetyMarginConstraint { in clearance = safetyMargin; }
    }

    part def ControllerSubsystem {
        port trajectoryIn : ~TrajectoryPort;
        port stateIn : ~StatePort;
        port commandOut : CommandPort;

        attribute controlRate : Duration = 0.02;
        attribute currentCommand : ControlCommand;
        attribute maxSpeed : Velocity = 2.0;
        attribute maxAccel : Acceleration = 1.5;
        attribute maxSteeringAngle : Angle = 0.785;
        attribute hasNewTrajectory : Boolean = false;
        attribute hasNewState : Boolean = false;
        attribute commandReady : Boolean = false;

        state controllerBehavior {
            entry; then Idle;

            state Idle;
            transition from Idle to ComputingCommands
                when hasNewTrajectory == true && hasNewState == true;

            state ComputingCommands {
                entry { /* Compute precise velocity and steering commands from trajectory */ }
                do { /* Apply control law such as pure pursuit or model predictive control */ }
            }
            transition from ComputingCommands to CheckingLimits;

            state CheckingLimits {
                entry { /* Ensure commands are within physical limits of the vehicle */ }
                do { /* Clamp speed, acceleration, and steering angle to maximum values */ }
            }
            transition from CheckingLimits to SendingCommands;

            state SendingCommands {
                entry { /* Send control commands to actuators through commandOut port */ }
                do { /* Set commandReady flag to true */ }
            }
            transition from SendingCommands to Idle;
        }

        constraint commandSpeedLimit : SpeedLimitConstraint { in speed = currentCommand.linearVelocity; }
        constraint commandAccelLimit : AccelerationLimitConstraint { in accel = currentCommand.acceleration; }
    }

    part def VehicleActuator {
        port commandIn : ~CommandPort;

        attribute currentSpeed : Velocity;
        attribute currentSteering : Angle;
        attribute currentAcceleration : Acceleration;
        attribute responseTime : Duration = 0.05;
        attribute hasNewCommand : Boolean = false;
        attribute isOperational : Boolean = true;

        state actuatorBehavior {
            entry; then Standby;

            state Standby {
                entry { /* Actuators in standby mode awaiting commands */ }
            }
            transition from Standby to Receiving
                when hasNewCommand == true;

            state Receiving {
                entry { /* Receive control commands from controller */ }
                do { /* Parse command fields: velocity, steering, acceleration */ }
            }
            transition from Receiving to Executing;

            state Executing {
                entry { /* Apply velocity and steering commands to motors and steering actuators */ }
                do { /* Continuously execute commands and update current actuator states */ }
            }
            transition from Executing to Receiving;
        }
    }

    // ===== Top-Level System =====
    part def MotionPlanningSystem {
        // Requirements
        requirement navReq : NavigationRequirement;
        requirement obstacleReq : ObstacleAvoidanceRequirement;
        requirement speedReq : SpeedConstraintRequirement;
        requirement accelReq : AccelerationConstraintRequirement;
        requirement turningReq : TurningRadiusRequirement;
        requirement dynamicReq : DynamicEnvironmentRequirement;
        requirement validationReq : TrajectoryValidationRequirement;
        requirement realtimeReq : RealTimeResponseRequirement;
        requirement smoothMotionReq : SmoothMotionRequirement;

        // System-level attributes
        attribute systemMaxSpeed : Velocity = 2.0;
        attribute systemMaxAccel : Acceleration = 1.5;
        attribute systemMinTurningRadius : Length = 0.5;
        attribute systemSafetyMargin : Length = 0.3;
        attribute systemGoal : Goal;
        attribute loopTime : Duration = 0.1;
        attribute emergencyStopTriggered : Boolean = false;
        attribute isSystemInitialized : Boolean = false;
        attribute allSensorsOnline : Boolean = false;

        // Subsystem parts
        part sensors : Sensor[2..*] {
            attribute totalRange : Length = 30.0;
        }

        part perception : PerceptionSubsystem;
        part localization : LocalizationSubsystem;
        part globalPlanner : GlobalPlannerSubsystem;
        part localPlanner : LocalPlannerSubsystem;
        part controller : ControllerSubsystem;
        part actuator : VehicleActuator;

        // Connections
        connection sensorToPerception connect sensors.dataOut to perception.sensorIn;
        connection sensorToLocalization connect sensors.dataOut to localization.sensorIn;
        connection perceptionToGlobalPlanner connect perception.mapOut to globalPlanner.mapIn;
        connection perceptionToLocalPlanner connect perception.mapOut to localPlanner.mapIn;
        connection localizationToGlobalPlanner connect localization.stateOut to globalPlanner.stateIn;
        connection localizationToLocalPlanner connect localization.stateOut to localPlanner.stateIn;
        connection localizationToController connect localization.stateOut to controller.stateIn;
        connection globalPlannerToLocalPlanner connect globalPlanner.pathOut to localPlanner.pathIn;
        connection localPlannerToController connect localPlanner.trajectoryOut to controller.trajectoryIn;
        connection controllerToActuator connect controller.commandOut to actuator.commandIn;

        // System-level state machine
        state systemBehavior {
            entry; then Booting;

            state Booting {
                entry { /* Initialize all subsystems and perform self-diagnostics */ }
                do { /* Verify sensor connectivity and calibration status */ }
            }
            transition from Booting to Operational
                when allSensorsOnline == true;

            state Operational {
                entry { /* Enter normal autonomous navigation mode */ }
                do { /* Continuously execute perception-localization-planning-control loop */ }
            }
            transition from Operational to EmergencyStop
                when emergencyStopTriggered == true;

            state EmergencyStop {
                entry { /* Halt vehicle immediately and issue maximum brake command */ }
                do { /* Maintain stopped state and monitor for clearance */ }
            }
            transition from EmergencyStop to Booting
                when emergencyStopTriggered == false;
        }

        // System-level constraints
        constraint systemSpeedLimit : SpeedLimitConstraint { in speed = systemMaxSpeed; }
        constraint systemAccelLimit : AccelerationLimitConstraint { in accel = systemMaxAccel; }
        constraint systemTurningRadius : TurningRadiusConstraint { in radius = systemMinTurningRadius; }
        constraint systemSafetyMargin : SafetyMarginConstraint { in clearance = systemSafetyMargin; }
        constraint systemLoopTime : LoopTimeConstraint { in loopDuration = loopTime; }

        // Satisfy relationships
        satisfy navReq by self;
        satisfy obstacleReq by localPlanner;
        satisfy speedReq by controller;
        satisfy accelReq by controller;
        satisfy turningReq by localPlanner;
        satisfy dynamicReq by perception;
        satisfy validationReq by localPlanner;
        satisfy realtimeReq by self;
        satisfy smoothMotionReq by localPlanner;
    }

    // ===== System Instance =====
    part motionPlanningSystem : MotionPlanningSystem {
        attribute systemGoal : Goal = Goal { x = 100.0; y = 50.0; tolerance = 0.5; isReached = false; };
    }
}
