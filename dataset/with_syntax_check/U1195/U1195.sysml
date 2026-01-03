package 'Robotics Simulator System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import SequenceFunctions::*;

    attribute def Position3D {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
    }

    attribute def Orientation3D {
        attribute roll : Real;
        attribute pitch : Real;
        attribute yaw : Real;
    }

    attribute def Velocity3D {
        attribute vx : SpeedValue;
        attribute vy : SpeedValue;
        attribute vz : SpeedValue;
    }

    attribute def AngularVelocity3D {
        attribute wx : Real;
        attribute wy : Real;
        attribute wz : Real;
    }

    attribute def JointState {
        attribute position : Real;
        attribute velocity : Real;
        attribute torque : TorqueValue;
    }

    attribute def RobotPose {
        attribute position : Position3D;
        attribute orientation : Orientation3D;
        attribute linearVelocity : Velocity3D;
        attribute angularVelocity : AngularVelocity3D;
    }

    attribute def SensorData {
        attribute timestamp : TimeValue;
        attribute range : LengthValue;
        attribute bearing : Real;
    }

    attribute def ControlCommand {
        attribute jointTorques : TorqueValue[*];
        attribute targetPose : RobotPose;
    }

    attribute def CollisionData {
        attribute detected : Boolean;
        attribute contactPoint : Position3D;
        attribute contactForce : ForceValue;
    }

    item def RobotConfiguration {
        attribute robotID : String;
        attribute mass : MassValue;
        attribute inertia : Real;
        attribute numberOfJoints : Integer;
        attribute maxJointTorque : TorqueValue;
    }

    item def EnvironmentConfiguration {
        attribute gravity : AccelerationValue;
        attribute airDensity : Real;
        attribute groundFriction : Real;
        attribute numberOfObstacles : Integer;
    }

    item def SimulationParameters {
        attribute timeStep : TimeValue;
        attribute totalDuration : TimeValue;
        attribute solverTolerance : Real;
        attribute enableCollisions : Boolean;
    }

    port def PhysicsDataPort {
        out currentPose : RobotPose;
        out jointStates : JointState[*];
        in appliedTorques : TorqueValue[*];
        in externalForces : ForceValue[*];
    }

    port def SensorDataPort {
        out sensorReadings : SensorData[*];
        in robotPose : RobotPose;
    }

    port def ControlPort {
        in commands : ControlCommand;
        out feedback : RobotPose;
    }

    port def VisualizationDataPort {
        in robotPose : RobotPose;
        in jointStates : JointState[*];
        in environmentState : Position3D[*];
    }

    port def CollisionPort {
        out collisionEvents : CollisionData[*];
        in objectPositions : Position3D[*];
    }

    part def PhysicsEngine {
        attribute currentSimTime : TimeValue;
        attribute integrationMethod : String;

        port physicsData : PhysicsDataPort[*];
        port collisionInterface : CollisionPort;

        action def IntegrateRobotDynamics {
            in deltaTime : TimeValue;
            in appliedTorques : TorqueValue[*];
            in externalForces : ForceValue[*];
            in currentPose : RobotPose;
            in currentJointStates : JointState[*];
            in robotMass : MassValue;
            in gravity : AccelerationValue;
            out nextPose : RobotPose;
            out nextJointStates : JointState[*];
        }

        action def DetectCollisions {
            in robotPosition : Position3D;
            in obstaclePositions : Position3D[*];
            in robotRadius : LengthValue;
            out collisions : CollisionData[*];
        }

        action def ComputeContactForces {
            in collisionData : CollisionData[*];
            in stiffness : Real;
            in damping : Real;
            out contactForces : ForceValue[*];
        }
    }

    part def RobotModel {
        attribute config : RobotConfiguration;
        attribute currentPose : RobotPose;
        attribute jointStates : JointState[*];

        port physicsInterface : PhysicsDataPort;
        port sensorInterface : SensorDataPort[*];
        port controlInterface : ControlPort;

        action def UpdateKinematics {
            in jointPositions : Real[*];
            in linkLengths : LengthValue[*];
            out endEffectorPose : RobotPose;
        }

        action def ComputeJacobianMatrix {
            in jointPositions : Real[*];
            out jacobian : Real[*];
        }

        action def ApplyJointLimits {
            in desiredTorques : TorqueValue[*];
            in maxTorque : TorqueValue;
            out limitedTorques : TorqueValue[*];
        }
    }

    part def SensorSimulator {
        attribute sensorNoise : Real;
        attribute sensorRange : LengthValue;

        port sensorOutput : SensorDataPort;

        action def SimulateLidarScan {
            in robotPose : RobotPose;
            in obstaclePositions : Position3D[*];
            in maxRange : LengthValue;
            in angularResolution : Real;
            out scanData : SensorData[*];
        }

        action def AddSensorNoise {
            in trueMeasurement : LengthValue;
            in noiseLevel : Real;
            out noisyMeasurement : LengthValue;
        }
    }

    part def ControlSystem {
        attribute controlGains : Real[*];
        attribute controlMode : String;

        port controlOutput : ControlPort;

        action def ComputePDControl {
            in targetPose : RobotPose;
            in currentPose : RobotPose;
            in kp : Real;
            in kd : Real;
            out controlTorques : TorqueValue[*];
        }

        action def TrajectoryPlanning {
            in startPose : RobotPose;
            in goalPose : RobotPose;
            in planningHorizon : TimeValue;
            out trajectory : RobotPose[*];
        }
    }

    part def VisualizationEngine {
        attribute renderFrequency : Real;
        attribute displayResolution : Integer[2];

        port visualInput : VisualizationDataPort;

        action def RenderScene {
            in robotPose : RobotPose;
            in jointStates : JointState[*];
            in cameraPosition : Position3D;
            in lightingParameters : Real[*];
        }

        action def UpdateDisplay {
            in frameRate : Real;
            in vsyncEnabled : Boolean;
        }
    }

    part def EnvironmentModel {
        attribute envConfig : EnvironmentConfiguration;
        attribute obstaclePositions : Position3D[*];

        action def GenerateObstacles {
            in numberOfObstacles : Integer;
            in workspaceSize : LengthValue;
            out positions : Position3D[*];
        }

        action def ComputeEnvironmentalForces {
            in robotVelocity : Velocity3D;
            in airDensity : Real;
            in dragCoefficient : Real;
            out dragForce : ForceValue;
        }
    }

    part def DataRecorder {
        attribute recordingActive : Boolean;
        attribute dataFilePath : String;

        action def RecordSimulationState {
            in timestamp : TimeValue;
            in robotPose : RobotPose;
            in jointStates : JointState[*];
            in sensorData : SensorData[*];
        }

        action def ExportToFile {
            in format : String;
            in compressionEnabled : Boolean;
        }
    }

    action def InitializeSimulation {
        in simParams : SimulationParameters;
        in robotConfig : RobotConfiguration;
        in envConfig : EnvironmentConfiguration;
        out initialPose : RobotPose;
        out initialJointStates : JointState[*];
        out obstaclePositions : Position3D[*];
    }

    action def SimulationStep {
        in deltaTime : TimeValue;
        in controlCommands : ControlCommand;
        inout robotPose : RobotPose;
        inout jointStates : JointState[*];
        in obstaclePositions : Position3D[*];
        out sensorReadings : SensorData[*];
        out collisions : CollisionData[*];

        action computeControl : ControlSystem::ComputePDControl {
            in targetPose = controlCommands.targetPose;
            in currentPose = robotPose;
            in kp = 100.0;
            in kd = 20.0;
            out controlTorques;
        }

        flow computeControl.controlTorques to applyLimits.desiredTorques;

        action applyLimits : RobotModel::ApplyJointLimits {
            in desiredTorques;
            in maxTorque = 50.0[N*m];
            out limitedTorques;
        }

        flow applyLimits.limitedTorques to integrateDynamics.appliedTorques;

        action integrateDynamics : PhysicsEngine::IntegrateRobotDynamics {
            in deltaTime = deltaTime;
            in appliedTorques;
            in externalForces;
            in currentPose = robotPose;
            in currentJointStates = jointStates;
            in robotMass = 50.0[kg];
            in gravity = 9.81[m/(s^2)];
            out nextPose;
            out nextJointStates;
        }

        then assign robotPose := integrateDynamics.nextPose;
        then assign jointStates := integrateDynamics.nextJointStates;

        action simulateSensors : SensorSimulator::SimulateLidarScan {
            in robotPose = robotPose;
            in obstaclePositions = obstaclePositions;
            in maxRange = 10.0[m];
            in angularResolution = 0.1;
            out scanData;
        }

        flow simulateSensors.scanData to sensorReadings;

        action detectCollisions : PhysicsEngine::DetectCollisions {
            in robotPosition = robotPose.position;
            in obstaclePositions = obstaclePositions;
            in robotRadius = 0.5[m];
            out collisions;
        }
    }

    action def RunSimulation {
        in attribute simParams : SimulationParameters;
        in attribute robotConfig : RobotConfiguration;
        in attribute envConfig : EnvironmentConfiguration;
        in attribute controlProfile : ControlCommand[*];
        out attribute poseHistory : RobotPose[*] := ();
        out attribute sensorHistory : SensorData[*] := ();

        private attribute currentPose : RobotPose;
        private attribute currentJointStates : JointState[*];
        private attribute currentTime : TimeValue := 0.0[s];
        private attribute obstacles : Position3D[*];

        first action initSim : InitializeSimulation {
            in simParams = simParams;
            in robotConfig = robotConfig;
            in envConfig = envConfig;
            out initialPose;
            out initialJointStates;
            out obstaclePositions;
        }

        then assign currentPose := initSim.initialPose;
        then assign currentJointStates := initSim.initialJointStates;
        then assign obstacles := initSim.obstaclePositions;

        then merge simulationLoop;

        action simulationLoop {
            for command in controlProfile {
                perform action step : SimulationStep {
                    in deltaTime = simParams.timeStep;
                    in controlCommands = command;
                    inout robotPose = currentPose;
                    inout jointStates = currentJointStates;
                    in obstaclePositions = obstacles;
                    out sensorReadings;
                    out collisions;
                }

                then assign currentPose := step.robotPose;
                then assign currentJointStates := step.jointStates;
                then assign currentTime := currentTime + simParams.timeStep;
                then assign poseHistory := poseHistory->including(currentPose);
            }
        }

        then done;
    }

    part def RoboticsSimulatorSystem {
        doc /* 
        The Robotics Simulator System provides a comprehensive virtual environment 
        for simulating robotic systems with high-fidelity physics, sensor modeling, 
        and control integration. The system enables testing and validation of robot 
        behaviors, control algorithms, and motion planning strategies in a safe, 
        repeatable virtual environment before deployment to physical hardware.
        */

        attribute simParams : SimulationParameters {
            attribute :>> timeStep = 0.01[s];
            attribute :>> totalDuration = 60.0[s];
            attribute :>> solverTolerance = 1.0e-6;
            attribute :>> enableCollisions = true;
        }

        attribute robotConfig : RobotConfiguration {
            attribute :>> robotID = "Robot_001";
            attribute :>> mass = 50.0[kg];
            attribute :>> inertia = 2.5;
            attribute :>> numberOfJoints = 6;
            attribute :>> maxJointTorque = 50.0[N*m];
        }

        attribute envConfig : EnvironmentConfiguration {
            attribute :>> gravity = 9.81[m/(s^2)];
            attribute :>> airDensity = 1.225;
            attribute :>> groundFriction = 0.6;
            attribute :>> numberOfObstacles = 5;
        }

        part physicsEngine : PhysicsEngine {
            attribute :>> currentSimTime = 0.0[s];
            attribute :>> integrationMethod = "RK4";
        }

        part robotModel : RobotModel {
            attribute :>> config = robotConfig;
        }

        part sensorSim : SensorSimulator {
            attribute :>> sensorNoise = 0.02;
            attribute :>> sensorRange = 10.0[m];
        }

        part controller : ControlSystem {
            attribute :>> controlGains = (100.0, 20.0, 5.0);
            attribute :>> controlMode = "PD";
        }

        part visualizer : VisualizationEngine {
            attribute :>> renderFrequency = 30.0;
            attribute :>> displayResolution = (1920, 1080);
        }

        part environment : EnvironmentModel {
            attribute :>> envConfig = envConfig;
        }

        part recorder : DataRecorder {
            attribute :>> recordingActive = true;
            attribute :>> dataFilePath = "/data/simulation_log.csv";
        }

        connect robotModel.physicsInterface to physicsEngine.physicsData;
        connect robotModel.sensorInterface to sensorSim.sensorOutput;
        connect robotModel.controlInterface to controller.controlOutput;
        connect visualizer.visualInput to robotModel.physicsInterface;
        connect physicsEngine.collisionInterface to environment;

        perform action mainSimulation : RunSimulation {
            in simParams = simParams;
            in robotConfig = robotConfig;
            in envConfig = envConfig;
            in controlProfile;
            out poseHistory;
            out sensorHistory;
        }
    }

    requirement def SimulationFidelityRequirement {
        doc /* 
        The simulator shall provide physically accurate simulation of robot dynamics 
        with numerical stability and bounded error accumulation over extended runs.
        */

        require constraint positionAccuracy {
            doc /* Position error shall remain below 1mm per simulation step. */
        }

        require constraint velocityAccuracy {
            doc /* Velocity error shall remain below 0.01 m/s per simulation step. */
        }

        require constraint energyConservation {
            doc /* Total system energy drift shall be less than 0.1% over 60 seconds. */
        }
    }

    requirement def RealTimePerformanceRequirement {
        doc /* 
        The simulator shall execute efficiently to support interactive operation 
        and batch processing scenarios.
        */

        require constraint executionSpeed {
            doc /* Simulation shall run at minimum 1x real-time on standard hardware. */
        }

        require constraint visualizationRate {
            doc /* Visualization shall maintain minimum 30 Hz refresh rate. */
        }
    }

    requirement def RobotModelFlexibilityRequirement {
        doc /* 
        The simulator shall support diverse robot configurations and kinematics.
        */

        require constraint degreesOfFreedom {
            doc /* Shall support robots with 1 to 20 degrees of freedom. */
        }

        require constraint kinematicTypes {
            doc /* Shall support serial, parallel, and hybrid kinematic chains. */
        }

        require constraint massRange {
            doc /* Shall support robot masses from 0.1 kg to 1000 kg. */
        }
    }

    requirement def SensorSimulationRequirement {
        doc /* 
        The simulator shall provide realistic sensor models with configurable 
        noise and environmental effects.
        */

        require constraint sensorTypes {
            doc /* Shall support lidar, camera, IMU, and force/torque sensors. */
        }

        require constraint noiseModeling {
            doc /* Shall model Gaussian and non-Gaussian sensor noise. */
        }
    }

    requirement <'SIM-001'> primarySimulatorRequirement {
        doc /* 
        The Robotics Simulator System shall simulate robot motion, dynamics, sensing, 
        and control in a virtual environment with high fidelity, enabling validation 
        of robotic systems prior to physical deployment.
        */

        subject simulatorSystem : RoboticsSimulatorSystem;

        require fidelity : SimulationFidelityRequirement;
        require performance : RealTimePerformanceRequirement;
        require flexibility : RobotModelFlexibilityRequirement;
        require sensors : SensorSimulationRequirement;

        assume constraint validParameters {
            doc /* All simulation parameters shall be physically valid and numerically stable. */
        }

        assume constraint validRobotModel {
            doc /* Robot model shall have positive mass, valid inertia, and feasible joint limits. */
        }
    }

    state def SimulatorOperationalState {
        entry action initializeSystem;

        initial state Uninitialized;

        transition uninitialized_to_ready
            first Uninitialized
            accept InitializationComplete
            then Ready;

        state Ready {
            entry action loadConfiguration;
        }

        transition ready_to_running
            first Ready
            accept StartSimulation
            then Running;

        state Running {
            entry action beginSimulationLoop;

            state Active {
                state PhysicsUpdate;
                state SensorUpdate;
                state ControlUpdate;
                state VisualizationUpdate;

                transition physics_to_sensor
                    first PhysicsUpdate
                    then SensorUpdate;

                transition sensor_to_control
                    first SensorUpdate
                    then ControlUpdate;

                transition control_to_visualization
                    first ControlUpdate
                    then VisualizationUpdate;

                transition visualization_to_physics
                    first VisualizationUpdate
                    then PhysicsUpdate;
            }

            state Recording {
                entry action startDataRecording;
                exit action stopDataRecording;
            }
        }

        transition running_to_paused
            first Running
            accept PauseSimulation
            then Paused;

        state Paused {
            entry action freezeSimulationState;
        }

        transition paused_to_running
            first Paused
            accept ResumeSimulation
            then Running;

        transition running_to_stopped
            first Running
            accept StopSimulation
            then Stopped;

        transition paused_to_stopped
            first Paused
            accept StopSimulation
            then Stopped;

        state Stopped {
            entry action finalizeSimulation;
            exit action cleanupResources;
        }

        transition stopped_to_ready
            first Stopped
            accept ResetSimulation
            then Ready;

        exit action shutdownSystem;
    }

    attribute def InitializationComplete;
    attribute def StartSimulation;
    attribute def PauseSimulation;
    attribute def ResumeSimulation;
    attribute def StopSimulation;
    attribute def ResetSimulation;

    part roboticsSimulator : RoboticsSimulatorSystem;
}
