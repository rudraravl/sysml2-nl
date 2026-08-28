package RoboticsSimulator {
    import ScalarValues::*;

    // ===== Value Types with Units =====
    value type Length :> Real { unit "m"; }
    value type Mass :> Real { unit "kg"; }
    value type Time :> Real { unit "s"; }
    value type Force :> Real { unit "N"; }
    value type Torque :> Real { unit "N·m"; }
    value type Angle :> Real { unit "rad"; }
    value type AngularVelocity :> Real { unit "rad/s"; }
    value type Velocity :> Real { unit "m/s"; }
    value type Acceleration :> Real { unit "m/s^2"; }
    value type Inertia :> Real { unit "kg·m^2"; }
    value type Frequency :> Real { unit "Hz"; }
    value type Coefficient :> Real { unit "dimensionless"; }
    value type Probability :> Real { unit "dimensionless"; min 0; max 1; }

    // ===== Item Definitions =====
    item def Pose {
        attribute x : Length;
        attribute y : Length;
        attribute z : Length;
        attribute roll : Angle;
        attribute pitch : Angle;
        attribute yaw : Angle;
    }

    item def JointState {
        attribute jointId : Integer;
        attribute position : Angle;
        attribute velocity : AngularVelocity;
        attribute appliedTorque : Torque;
    }

    item def RobotState {
        attribute pose : Pose;
        attribute joints : JointState[0..*];
        attribute timestamp : Time;
    }

    item def ControlCommand {
        attribute jointId : Integer;
        attribute torque : Torque;
    }

    item def ControlCommandSet {
        attribute commands : ControlCommand[0..*];
        attribute timestamp : Time;
    }

    item def Goal {
        attribute targetPose : Pose;
        attribute priority : Integer;
    }

    item def Obstacle {
        attribute id : String;
        attribute pose : Pose;
        attribute boundingRadius : Length;
    }

    item def EnvironmentConfig {
        attribute gravity : Acceleration;
        attribute friction : Coefficient;
        attribute obstacles : Obstacle[0..*];
    }

    item def LidarBeam {
        attribute range : Length;
        attribute bearing : Angle;
        attribute intensity : Real;
    }

    item def LidarScan {
        attribute beams : LidarBeam[0..*];
        attribute timestamp : Time;
        attribute maxRange : Length;
        attribute noiseStdDev : Length;
    }

    item def ContactForce {
        attribute contactPoint : Pose;
        attribute normalForce : Force;
        attribute frictionForce : Force;
    }

    item def PhysicsStep {
        attribute dt : Time;
        attribute appliedForces : Force[0..*];
        attribute appliedTorques : Torque[0..*];
    }

    item def RenderFrame {
        attribute robotPose : Pose;
        attribute jointPositions : Angle[0..*];
        attribute obstacles : Obstacle[0..*];
        attribute timestamp : Time;
    }

    item def LogEntry {
        attribute timestamp : Time;
        attribute robotState : RobotState;
        attribute sensorData : LidarScan;
        attribute commands : ControlCommandSet;
    }

    // ===== Port Definitions =====
    port def RobotStateOut { out robotState : RobotState; }
    port def RobotStateIn { in robotState : RobotState; }
    port def ControlCommandOut { out commands : ControlCommandSet; }
    port def ControlCommandIn { in commands : ControlCommandSet; }
    port def GoalIn { in goal : Goal; }
    port def EnvironmentConfigOut { out config : EnvironmentConfig; }
    port def EnvironmentConfigIn { in config : EnvironmentConfig; }
    port def SensorDataOut { out scan : LidarScan; }
    port def SensorDataIn { in scan : LidarScan; }
    port def RenderOut { out frame : RenderFrame; }
    port def RenderIn { in frame : RenderFrame; }
    port def ContactForceOut { out contacts : ContactForce[0..*]; }

    // ===== Part Definitions =====

    part def PhysicsEngine {
        attribute gravity : Acceleration := 9.81 [m/s^2];
        attribute timeStep : Time := 0.001 [s];
        attribute maxIterations : Integer := 100;

        port stateIn : RobotStateIn;
        port commandsIn : ControlCommandIn;
        port envIn : EnvironmentConfigIn;
        port stateOut : RobotStateOut;
        port contactsOut : ContactForceOut;

        action def computeDynamics {
            in currentState : RobotState;
            in commands : ControlCommandSet;
            in env : EnvironmentConfig;
            out newState : RobotState;
            out contacts : ContactForce[0..*];
        }

        action def detectCollisions {
            in pose : Pose;
            in obstacles : Obstacle[0..*];
            out contacts : ContactForce[0..*];
        }

        action def integrateMotion {
            in state : RobotState;
            in forces : Force[0..*];
            in torques : Torque[0..*];
            in dt : Time;
            out newState : RobotState;
        }
    }

    part def RobotModel {
        attribute mass : Mass := 15.0 [kg];
        attribute inertia : Inertia := 0.5 [kg·m^2];
        attribute jointCount : Integer := 6;
        attribute maxJointTorque : Torque := 40.0 [N·m];
        attribute linkLength : Length := 0.5 [m];

        port stateIn : RobotStateIn;
        port stateOut : RobotStateOut;
        port commandsIn : ControlCommandIn;

        attribute currentPose : Pose;
        attribute jointStates : JointState[0..*];

        action def forwardKinematics {
            in jointPositions : Angle[0..*];
            out endEffectorPose : Pose;
        }

        action def checkJointLimits {
            in command : ControlCommand;
            out valid : Boolean;
        }

        action def updateState {
            in newState : RobotState;
            out updatedState : RobotState;
        }
    }

    part def ControlSystem {
        attribute controlStrategy : String := "PID";
        attribute kp : Real := 1.5;
        attribute ki : Real := 0.01;
        attribute kd : Real := 0.2;
        attribute trajectoryHorizon : Time := 5.0 [s];

        port goalIn : GoalIn;
        port stateIn : RobotStateIn;
        port sensorIn : SensorDataIn;
        port commandsOut : ControlCommandOut;

        action def planTrajectory {
            in current : Pose;
            in target : Pose;
            out waypoints : Pose[0..*];
        }

        action def computeControl {
            in current : RobotState;
            in goal : Goal;
            in sensorData : LidarScan;
            out commands : ControlCommandSet;
        }

        action def pidController {
            in error : Angle;
            in integral : Angle;
            in derivative : Angle;
            out torque : Torque;
        }
    }

    part def EnvironmentModel {
        attribute gravity : Acceleration := 9.81 [m/s^2];
        attribute friction : Coefficient := 0.4;
        attribute obstacleCount : Integer := 10;
        attribute worldSize : Length := 10.0 [m];

        port configOut : EnvironmentConfigOut;

        action def generateObstacles {
            in count : Integer;
            in worldSize : Length;
            out obstacles : Obstacle[0..*];
        }

        action def updateEnvironment {
            in dt : Time;
            out config : EnvironmentConfig;
        }
    }

    part def SensorSimulator {
        attribute maxRange : Length := 30.0 [m];
        attribute angularResolution : Angle := 0.01745 [rad];
        attribute noiseStdDev : Length := 0.02 [m];
        attribute dropProbability : Probability := 0.01;
        attribute scanFrequency : Frequency := 10.0 [Hz];

        port stateIn : RobotStateIn;
        port envIn : EnvironmentConfigIn;
        port dataOut : SensorDataOut;

        action def simulateLidar {
            in pose : Pose;
            in obstacles : Obstacle[0..*];
            out scan : LidarScan;
        }

        action def addNoise {
            in rawRange : Length;
            out noisyRange : Length;
        }

        action def raycast {
            in origin : Pose;
            in bearing : Angle;
            in obstacles : Obstacle[0..*];
            out range : Length;
        }
    }

    part def VisualizationEngine {
        attribute renderFrequency : Frequency := 60.0 [Hz];
        attribute resolution : String := "1920x1080";
        attribute enableShadows : Boolean := true;

        port stateIn : RobotStateIn;
        port envIn : EnvironmentConfigIn;
        port renderOut : RenderOut;

        action def renderFrame {
            in robotState : RobotState;
            in env : EnvironmentConfig;
            out frame : RenderFrame;
        }

        action def drawRobot {
            in pose : Pose;
            in joints : JointState[0..*];
        }

        action def drawObstacles {
            in obstacles : Obstacle[0..*];
        }
    }

    part def DataRecorder {
        attribute filePath : String := "simulation_log.json";
        attribute bufferSize : Integer := 1000;
        attribute flushInterval : Time := 1.0 [s];
        attribute recording : Boolean := false;

        port stateIn : RobotStateIn;
        port sensorIn : SensorDataIn;
        port commandsIn : ControlCommandIn;

        action def recordEntry {
            in robotState : RobotState;
            in sensorData : LidarScan;
            in commands : ControlCommandSet;
            out entry : LogEntry;
        }

        action def flushBuffer {
            out success : Boolean;
        }

        action def startRecording {
            out success : Boolean;
        }

        action def stopRecording {
            out success : Boolean;
        }
    }

    // ===== Simulator System =====
    part def SimulatorSystem {
        attribute simulationTime : Time := 0.0 [s];
        attribute timeStep : Time := 0.001 [s];
        attribute maxSimulationTime : Time := 100.0 [s];

        part physicsEngine : PhysicsEngine;
        part robotModel : RobotModel;
        part controlSystem : ControlSystem;
        part environmentModel : EnvironmentModel;
        part sensorSimulator : SensorSimulator;
        part visualizationEngine : VisualizationEngine;
        part dataRecorder : DataRecorder;

        // Connections
        connection controlToRobot connect controlSystem.commandsOut to robotModel.commandsIn;
        connection controlToPhysics connect controlSystem.commandsOut to physicsEngine.commandsIn;
        connection robotStateToControl connect robotModel.stateOut to controlSystem.stateIn;
        connection robotStateToPhysics connect robotModel.stateOut to physicsEngine.stateIn;
        connection robotStateToSensor connect robotModel.stateOut to sensorSimulator.stateIn;
        connection robotStateToViz connect robotModel.stateOut to visualizationEngine.stateIn;
        connection robotStateToRecorder connect robotModel.stateOut to dataRecorder.stateIn;
        connection envToPhysics connect environmentModel.configOut to physicsEngine.envIn;
        connection envToSensor connect environmentModel.configOut to sensorSimulator.envIn;
        connection envToViz connect environmentModel.configOut to visualizationEngine.envIn;
        connection sensorToControl connect sensorSimulator.dataOut to controlSystem.sensorIn;
        connection sensorToRecorder connect sensorSimulator.dataOut to dataRecorder.sensorIn;
        connection commandsToRecorder connect controlSystem.commandsOut to dataRecorder.commandsIn;
        connection physicsToRobot connect physicsEngine.stateOut to robotModel.stateIn;

        // State Machine
        state def SimulatorStates {
            entry;
            then Ready;

            state Ready {
                doc /* Simulator is configured and waiting to start. */
            }

            transition ready_to_running
                from Ready
                to Running
                when startRequested;

            state Running {
                doc /* Simulator is actively executing simulation steps. */
                entry;
                then StepLoop;

                state StepLoop {
                    doc /* Single discrete time step execution. */
                }

                transition step_continue
                    from StepLoop
                    to StepLoop
                    when stepComplete;
            }

            transition running_to_paused
                from Running
                to Paused
                when pauseRequested;

            state Paused {
                doc /* Simulation is temporarily halted, state preserved. */
            }

            transition paused_to_running
                from Paused
                to Running
                when resumeRequested;

            transition running_to_stopped
                from Running
                to Stopped
                when stopRequested;

            transition paused_to_stopped
                from Paused
                to Stopped
                when stopRequested;

            state Stopped {
                doc /* Simulation has terminated, data flushed. */
                entry;
                then Final;
            }

            state Final {
                doc /* Simulator has completed and released resources. */
            }
        }

        attribute stateMachine : SimulatorStates;

        // Simulation step action
        action def simulationStep {
            in dt : Time;

            action computeControl : ControlSystem::computeControl;
            action updatePhysics : PhysicsEngine::computeDynamics;
            action updateKinematics : RobotModel::forwardKinematics;
            action senseEnvironment : SensorSimulator::simulateLidar;
            action render : VisualizationEngine::renderFrame;
            action record : DataRecorder::recordEntry;

            flow from computeControl.commands to updatePhysics.commands;
            flow from updatePhysics.newState to updateKinematics.jointPositions;
            flow from updateKinematics.endEffectorPose to senseEnvironment.pose;
            flow from senseEnvironment.scan to record.sensorData;
            flow from computeControl.commands to record.commands;
            flow from updatePhysics.newState to record.robotState;
        }
    }

    // ===== Requirements =====
    requirement def PhysicsFidelityRequirement {
        subject physicsEngine : PhysicsEngine;
        doc /* The physics engine shall compute motion with realistic physical laws including gravity, forces, torques, and collisions. */
        require gravityAccuracy : Real <= 0.01;
        require collisionDetectionLatency : Time <= 0.0005 [s];
        require contactForceComputation : Boolean = true;
    }

    requirement def RobotModelAccuracyRequirement {
        subject robotModel : RobotModel;
        doc /* The robot model shall accurately represent physical characteristics including mass, inertia, joints, and torque limits. */
        require massAccuracy : Mass <= 0.1 [kg];
        require jointLimitEnforcement : Boolean = true;
        require kinematicsComputation : Boolean = true;
    }

    requirement def ControlSystemRequirement {
        subject controlSystem : ControlSystem;
        doc /* The control system shall compute joint torques to achieve desired goals using configurable control strategies. */
        require controlLoopLatency : Time <= 0.001 [s];
        require trajectoryPlanningHorizon : Time >= 1.0 [s];
        require multipleStrategies : Boolean = true;
    }

    requirement def EnvironmentModelRequirement {
        subject environmentModel : EnvironmentModel;
        doc /* The environment model shall define virtual world properties and procedurally generate obstacles. */
        require gravityConfigurable : Boolean = true;
        require frictionRange : Coefficient >= 0.0;
        require frictionUpperBound : Coefficient <= 1.0;
        require obstacleGeneration : Boolean = true;
    }

    requirement def SensorSimulatorRequirement {
        subject sensorSimulator : SensorSimulator;
        doc /* The sensor simulator shall mimic real-world sensor output with noise and range limitations. */
        require lidarMaxRange : Length >= 10.0 [m];
        require noiseModeling : Boolean = true;
        require scanFrequency : Frequency >= 10.0 [Hz];
        require rangeLimitation : Boolean = true;
    }

    requirement def VisualizationRequirement {
        subject visualizationEngine : VisualizationEngine;
        doc /* The visualization engine shall provide a 3D graphical representation of the simulation in real-time. */
        require renderFrequency : Frequency >= 30.0 [Hz];
        require realTimeRendering : Boolean = true;
        require jointStateRendering : Boolean = true;
        require environmentRendering : Boolean = true;
    }

    requirement def DataRecorderRequirement {
        subject dataRecorder : DataRecorder;
        doc /* The data recorder shall log all critical simulation information to a file for later analysis. */
        require logRobotPose : Boolean = true;
        require logJointStates : Boolean = true;
        require logSensorData : Boolean = true;
        require logTimestampResolution : Time <= 0.001 [s];
        require fileOutput : Boolean = true;
    }

    requirement def SimulatorSystemRequirement {
        subject simulator : SimulatorSystem;
        doc /* The simulator system shall provide a safe, repeatable, high-fidelity virtual world for testing robotic systems. */
        require discreteTimeStepping : Boolean = true;
        require configurableTimeStep : Boolean = true;
        require stateMachineSupport : Boolean = true;
        require readyState : Boolean = true;
        require runningState : Boolean = true;
        require pausedState : Boolean = true;
        require stoppedState : Boolean = true;
    }

    requirement def SafetyAndRepeatabilityRequirement {
        subject simulator : SimulatorSystem;
        doc /* The simulator shall provide a safe testing environment without physical risk and support repeatable runs. */
        require noPhysicalHardware : Boolean = true;
        require repeatableRuns : Boolean = true;
        require deterministicMode : Boolean = true;
    }

    // ===== Requirement Satisfaction =====
    satisfaction physicsFidelitySatisfaction : PhysicsFidelityRequirement satisfy physicsEngine;
    satisfaction robotModelSatisfaction : RobotModelAccuracyRequirement satisfy robotModel;
    satisfaction controlSystemSatisfaction : ControlSystemRequirement satisfy controlSystem;
    satisfaction environmentModelSatisfaction : EnvironmentModelRequirement satisfy environmentModel;
    satisfaction sensorSimulatorSatisfaction : SensorSimulatorRequirement satisfy sensorSimulator;
    satisfaction visualizationSatisfaction : VisualizationRequirement satisfy visualizationEngine;
    satisfaction dataRecorderSatisfaction : DataRecorderRequirement satisfy dataRecorder;
    satisfaction simulatorSystemSatisfaction : SimulatorSystemRequirement satisfy simulator;
    satisfaction safetySatisfaction : SafetyAndRepeatabilityRequirement satisfy simulator;
}
