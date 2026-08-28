package RoboticsSimulatorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import Quantities::*;
    private import SequenceFunctions::*;

    attribute def TorqueValue :> ScalarQuantityValue;
    attribute def InertiaValue :> ScalarQuantityValue;
    attribute def PoseValue :> ScalarQuantityValue;
    attribute def JointAngleValue :> ScalarQuantityValue;
    attribute def AngularVelocityValue :> ScalarQuantityValue;
    attribute def AngleValue :> ScalarQuantityValue;

    item def SensorData;
    item def LidarScan :> SensorData {
        attribute ranges : LengthValue[*];
        attribute bearings : AngleValue[*];
    }
    item def JointCommand {
        attribute torques : TorqueValue[*];
    }
    item def RobotState {
        attribute pose : PoseValue;
        attribute jointAngles : JointAngleValue[*];
        attribute jointVelocities : AngularVelocityValue[*];
    }
    item def Goal {
        attribute targetPose : PoseValue;
    }
    item def Obstacle {
        attribute position : LengthValue[3];
        attribute radius : LengthValue;
    }
    item def ContactForce {
        attribute force : ForceValue;
        attribute location : LengthValue[3];
    }
    item def LogEntry {
        attribute time : TimeValue;
        attribute robotState : RobotState;
        attribute sensorData : SensorData;
    }
    item def StartSignal;
    item def PauseSignal;
    item def ResumeSignal;
    item def StopSignal;

    port def EnvironmentPort {
        out obstacles : Obstacle[*];
        out gravity : AccelerationValue;
        out friction : Real;
    }
    port def ControlCommandPort {
        out command : JointCommand;
    }
    port def RobotStatePort {
        out robotState : RobotState;
    }
    port def SensorDataPort {
        out data : SensorData;
    }

    part def RobotModel {
        attribute mass : MassValue;
        attribute inertia : InertiaValue;
        attribute jointCount : Natural;
        attribute maxJointTorque : TorqueValue;
        port commandIn : ~ControlCommandPort;
        action updateKinematics {
            in command : JointCommand;
            in dt : TimeValue;
            in currentRobotState : RobotState;
            out newState : RobotState;
        }
    }

    part def PhysicsEngine {
        attribute gravity : AccelerationValue;
        attribute friction : Real;
        port envIn : ~EnvironmentPort;
        port commandIn : ~ControlCommandPort;
        port stateOut : RobotStatePort;
        action computeDynamics {
            in dt : TimeValue;
            in robotState : RobotState;
            in command : JointCommand;
            in obstacles : Obstacle[*];
            out updatedState : RobotState;
            out contacts : ContactForce[*];
        }
        action detectCollisions {
            in robotState : RobotState;
            in obstacles : Obstacle[*];
            out contacts : ContactForce[*];
        }
    }

    part def ControlSystem {
        attribute controlStrategy : String;
        port stateIn : ~RobotStatePort;
        port commandOut : ControlCommandPort;
        action planTrajectory {
            in goal : Goal;
            in robotState : RobotState;
            out trajectory : PoseValue[*];
        }
        action computeControl {
            in goal : Goal;
            in robotState : RobotState;
            out command : JointCommand;
        }
    }

    part def EnvironmentModel {
        attribute gravity : AccelerationValue;
        attribute friction : Real;
        attribute obstacles : Obstacle[*];
        port envOut : EnvironmentPort;
        action generateObstacles {
            in count : Natural;
            out obstacles : Obstacle[*];
        }
    }

    part def SensorSimulator {
        attribute noiseLevel : Real;
        attribute maxRange : LengthValue;
        port robotStateIn : ~RobotStatePort;
        port envIn : ~EnvironmentPort;
        port sensorDataOut : SensorDataPort;
        action simulateLidar {
            in robotState : RobotState;
            in obstacles : Obstacle[*];
            out scan : LidarScan;
        }
        action addNoise {
            in scan : LidarScan;
            in noise : Real;
            out noisyScan : LidarScan;
        }
    }

    part def VisualizationEngine {
        attribute renderRate : Real;
        port stateIn : ~RobotStatePort;
        port envIn : ~EnvironmentPort;
        action render {
            in robotState : RobotState;
            in obstacles : Obstacle[*];
        }
    }

    part def DataRecorder {
        attribute logFile : String;
        attribute entries : LogEntry[*];
        action recordEntry {
            in entry : LogEntry;
        }
        action saveLog {
            in filename : String;
        }
    }

    state machine def SimulatorStates {
        state ready;
        transition t_ready_to_running first ready then running {
            accept StartSignal;
        }
        state running {
            transition t_running_to_paused first running then paused {
                accept PauseSignal;
            }
            transition t_running_to_stopped first running then stopped {
                accept StopSignal;
            }
        }
        state paused {
            transition t_paused_to_running first paused then running {
                accept ResumeSignal;
            }
            transition t_paused_to_stopped first paused then stopped {
                accept StopSignal;
            }
        }
        state stopped;
    }

    requirement def SimulationFidelityRequirement {
        doc /* The simulator must provide high-fidelity physics-based simulation. */
        subject simulator : RoboticsSimulator;
        require constraint {
            simulator.physics.gravity == 9.81 ['m/s^2']
        }
    }

    requirement def RealTimeVisualizationRequirement {
        doc /* The visualization engine must render at least 30 frames per second. */
        subject vizEngine : VisualizationEngine;
        require constraint {
            vizEngine.renderRate >= 30.0
        }
    }

    requirement def SensorNoiseRequirement {
        doc /* The sensor simulator must support configurable noise levels. */
        subject sensorSim : SensorSimulator;
        require constraint {
            sensorSim.noiseLevel >= 0.0 & sensorSim.noiseLevel <= 1.0
        }
    }

    requirement def DataLoggingRequirement {
        doc /* All simulation states and sensor data must be logged for post-analysis. */
        subject recorder : DataRecorder;
        require constraint {
            recorder.entries->size() > 0
        }
    }

    part def RoboticsSimulator {
        attribute timeStep : TimeValue = 0.001 ['s'];

        part environment : EnvironmentModel {
            attribute gravity = 9.81 ['m/s^2'];
            attribute friction = 0.3;
        }
        part robot : RobotModel {
            attribute mass = 25 ['kg'];
            attribute inertia = 0.5 ['kg*m^2'];
            attribute jointCount = 6;
            attribute maxJointTorque = 50 ['N*m'];
        }
        part physics : PhysicsEngine {
            attribute gravity = environment.gravity;
            attribute friction = environment.friction;
        }
        part control : ControlSystem {
            attribute controlStrategy = "PID";
        }
        part sensors : SensorSimulator {
            attribute noiseLevel = 0.05;
            attribute maxRange = 10.0 ['m'];
        }
        part visualization : VisualizationEngine {
            attribute renderRate = 30.0;
        }
        part recorder : DataRecorder {
            attribute logFile = "simulation_log.csv";
        }

        exhibit state behavior : SimulatorStates;

        connect environment.envOut to physics.envIn;
        connect environment.envOut to sensors.envIn;
        connect environment.envOut to visualization.envIn;
        connect control.commandOut to physics.commandIn;
        connect control.commandOut to robot.commandIn;
        connect physics.stateOut to control.stateIn;
        connect physics.stateOut to sensors.robotStateIn;
        connect physics.stateOut to visualization.stateIn;

        action runSimulation {
            in goal : Goal;
            in duration : TimeValue;
            attribute elapsed : TimeValue = 0 ['s'];
            attribute currentRobotState : RobotState;
            attribute command : JointCommand;
            attribute updatedState : RobotState;
            attribute scan : LidarScan;
            attribute logEntry : LogEntry;

            while elapsed < duration {
                perform ctrl : control.computeControl {
                    in goal = goal;
                    in robotState = currentRobotState;
                }
                then assign command := ctrl.command;

                then perform phys : physics.computeDynamics {
                    in dt = timeStep;
                    in robotState = currentRobotState;
                    in command = command;
                    in obstacles = environment.obstacles;
                }
                then assign updatedState := phys.updatedState;

                then perform sens : sensors.simulateLidar {
                    in robotState = updatedState;
                    in obstacles = environment.obstacles;
                }
                then assign scan := sens.scan;

                then assign currentRobotState := updatedState;

                then assign logEntry.time := elapsed;
                then assign logEntry.robotState := currentRobotState;
                then assign logEntry.sensorData := scan;

                then perform rec : recorder.recordEntry {
                    in entry = logEntry;
                }

                then perform viz : visualization.render {
                    in robotState = currentRobotState;
                    in obstacles = environment.obstacles;
                }

                then assign elapsed := elapsed + timeStep;
            }
        }
    }

    part sim : RoboticsSimulator;

    requirement simFidelityReq : SimulationFidelityRequirement {
        subject = sim;
    }
    requirement vizReq : RealTimeVisualizationRequirement {
        subject = sim.visualization;
    }
    requirement noiseReq : SensorNoiseRequirement {
        subject = sim.sensors;
    }
    requirement loggingReq : DataLoggingRequirement {
        subject = sim.recorder;
    }
}
