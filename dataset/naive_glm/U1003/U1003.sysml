package SpotRobotModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    // ===== Value Types =====
    value type Torque :> Real;
    value type Voltage :> Real;
    value type Current :> Real;
    value type Power :> Real;
    value type Energy :> Real;
    value type AngularVelocity :> Real;
    value type LinearVelocity :> Real;
    value type Distance :> Real;
    value type Angle :> Real;
    value type MassValue :> Real;
    value type Frequency :> Real;
    value type Temperature :> Real;
    value type BatteryPercent :> Real;
    value type DataRate :> Real;

    // ===== Item Definitions =====
    item def SensorData;

    item def LidarPointCloud :> SensorData {
        attribute pointCount : Integer;
        attribute resolution : Distance;
    }

    item def DepthImage :> SensorData {
        attribute width : Integer;
        attribute height : Integer;
    }

    item def StereoImage :> SensorData {
        attribute leftImageWidth : Integer;
        attribute leftImageHeight : Integer;
        attribute rightImageWidth : Integer;
        attribute rightImageHeight : Integer;
    }

    item def ImuData :> SensorData {
        attribute orientation : Angle;
        attribute angularVelocity : AngularVelocity;
        attribute linearAcceleration : Real;
    }

    item def ControlCommand;

    item def ActuatorCommand :> ControlCommand {
        attribute targetTorque : Torque;
        attribute targetPosition : Angle;
        attribute targetVelocity : AngularVelocity;
    }

    item def GaitCommand :> ControlCommand {
        attribute gaitPattern : String;
        attribute stepFrequency : Frequency;
    }

    item def NavigationCommand :> ControlCommand {
        attribute waypoints : Distance[0..*];
        attribute targetVelocity : LinearVelocity;
    }

    item def OperatorCommand :> ControlCommand {
        attribute commandType : String;
    }

    item def PowerStatus {
        attribute batteryLevel : BatteryPercent;
        attribute voltage : Voltage;
        attribute current : Current;
    }

    item def EnvironmentMap {
        attribute pointCloud : LidarPointCloud;
        attribute obstacleDistances : Distance[0..*];
        attribute freeSpaceRegions : Distance[0..*];
    }

    // ===== Port Definitions =====
    port def PowerPort {
        out attribute voltage : Voltage;
        out attribute current : Current;
        in attribute powerDemand : Power;
    }

    port def SensorDataPort {
        out item sensorData : SensorData;
    }

    port def ControlPort {
        out item command : ControlCommand;
    }

    port def ActuatorPort {
        in item command : ActuatorCommand;
        out attribute actualTorque : Torque;
        out attribute actualPosition : Angle;
    }

    port def LidarDataPort {
        out item pointCloud : LidarPointCloud;
    }

    port def CameraDataPort {
        out item stereoImage : StereoImage;
        out item depthImage : DepthImage;
    }

    port def ImuDataPort {
        out item imuData : ImuData;
    }

    port def OperatorCommandPort {
        in item command : OperatorCommand;
    }

    // ===== Actuator Definition =====
    part def Actuator {
        attribute maxTorque : Torque = 23.0;
        attribute maxAngularVelocity : AngularVelocity = 12.0;
        attribute powerConsumption : Power;
        attribute currentTorque : Torque;
        attribute currentPosition : Angle;
        attribute currentVelocity : AngularVelocity;
        attribute jointName : String;

        port actuatorIn : ActuatorPort;

        state actuatorStates {
            state Idle;
            state Active;
            state Faulted;

            transition Idle to Active when actuatorIn.command.targetTorque > 0;
            transition Active to Idle when actuatorIn.command.targetTorque == 0;
            transition Active to Faulted when currentTorque > maxTorque;
            transition Faulted to Idle when actuatorIn.command.targetTorque == 0;
        }
    }

    // ===== Leg Definition =====
    part def Leg {
        attribute legId : String;

        part hipActuator : Actuator {
            :>> maxTorque = 30.0;
            :>> jointName = "hip";
        }

        part shoulderActuator : Actuator {
            :>> maxTorque = 30.0;
            :>> jointName = "shoulder";
        }

        part kneeActuator : Actuator {
            :>> maxTorque = 23.0;
            :>> jointName = "knee";
        }

        port legControlIn : ControlPort;

        connection hipControl connect legControlIn to hipActuator.actuatorIn;
        connection shoulderControl connect legControlIn to shoulderActuator.actuatorIn;
        connection kneeControl connect legControlIn to kneeActuator.actuatorIn;
    }

    // ===== Battery Pack Definition =====
    part def BatteryPack {
        attribute nominalVoltage : Voltage = 58.4;
        attribute capacity : Energy = 540.0;
        attribute maxDischargeCurrent : Current = 30.0;
        attribute chargeLevel : BatteryPercent = 100.0;
        attribute internalTemperature : Temperature;
        attribute isRecharging : Boolean = false;

        port powerOut : PowerPort;

        state batteryStates {
            state Discharging;
            state Charging;
            state LowPower;
            state Critical;

            transition Discharging to LowPower when chargeLevel < 20.0;
            transition LowPower to Critical when chargeLevel < 5.0;
            transition Discharging to Charging when isRecharging;
            transition Charging to Discharging when !isRecharging;
            transition LowPower to Charging when isRecharging;
            transition Critical to Charging when isRecharging;
            transition Charging to LowPower when !isRecharging & chargeLevel < 20.0;
            transition Charging to Discharging when !isRecharging & chargeLevel >= 20.0;
        }
    }

    // ===== Body Definition =====
    part def Body {
        attribute mass : MassValue = 16.0;
        attribute payloadCapacity : MassValue = 14.0;
        attribute maxSpeed : LinearVelocity = 1.6;
        attribute operatingTemperatureMin : Temperature;
        attribute operatingTemperatureMax : Temperature;

        port bodyPowerIn : PowerPort;
    }

    // ===== Sensor Definitions =====
    part def LidarScanner {
        attribute scanRange : Distance = 100.0;
        attribute scanRate : Frequency = 10.0;
        attribute angularResolution : Angle = 0.0175;
        attribute powerConsumption : Power = 8.0;
        attribute positionLabel : String;

        port lidarOut : LidarDataPort;
        port powerIn : PowerPort;
    }

    part def StereoCamera {
        attribute resolutionWidth : Integer = 3840;
        attribute resolutionHeight : Integer = 2160;
        attribute frameRate : Frequency = 30.0;
        attribute fieldOfView : Angle = 1.047;
        attribute powerConsumption : Power = 5.0;

        port cameraOut : CameraDataPort;
        port powerIn : PowerPort;
    }

    part def DepthCamera {
        attribute range : Distance = 4.0;
        attribute frameRate : Frequency = 30.0;
        attribute resolutionWidth : Integer = 1280;
        attribute resolutionHeight : Integer = 720;
        attribute powerConsumption : Power = 4.0;

        port depthOut : SensorDataPort;
        port powerIn : PowerPort;
    }

    part def IMU {
        attribute sampleRate : Frequency = 200.0;
        attribute gyroRange : AngularVelocity = 8.73;
        attribute accelRange : Real = 19.6;
        attribute powerConsumption : Power = 0.5;

        port imuOut : ImuDataPort;
        port powerIn : PowerPort;
    }

    // ===== Perception System Definition =====
    part def PerceptionSystem {
        part frontLidar : LidarScanner {
            :>> positionLabel = "front";
        }
        part rearLidar : LidarScanner {
            :>> positionLabel = "rear";
        }
        part stereoCamera : StereoCamera;
        part depthCamera : DepthCamera;
        part imu : IMU;

        port perceptionPowerIn : PowerPort;
        port perceptionDataOut : SensorDataPort;

        connection frontLidarPower connect perceptionPowerIn to frontLidar.powerIn;
        connection rearLidarPower connect perceptionPowerIn to rearLidar.powerIn;
        connection stereoPower connect perceptionPowerIn to stereoCamera.powerIn;
        connection depthPower connect perceptionPowerIn to depthCamera.powerIn;
        connection imuPower connect perceptionPowerIn to imu.powerIn;
    }

    // ===== Compute Module Definition =====
    part def ComputeModule {
        attribute processingFrequency : Frequency = 1000.0;
        attribute cpuCores : Integer = 8;
        attribute memoryGB : Real = 16.0;
        attribute powerConsumption : Power = 50.0;

        port sensorDataIn : SensorDataPort;
        port controlOut : ControlPort;
        port powerIn : PowerPort;
        port operatorIn : OperatorCommandPort;

        attribute currentMap : EnvironmentMap;
        attribute currentGait : String;
        attribute plannedPath : Distance[0..*];
        attribute obstacleDetected : Boolean = false;

        action perceiveEnvironment {
            in item sensorInput : SensorData;
            out item environmentMap : EnvironmentMap;
        }

        action planTrajectory {
            in item map : EnvironmentMap;
            in item waypoints : Distance[0..*];
            out item path : Distance[0..*];
        }

        action generateGait {
            in item terrainData : EnvironmentMap;
            out item gaitCommand : GaitCommand;
        }

        action balanceControl {
            in item imuData : ImuData;
            out item correctionCommand : ControlCommand;
        }

        action executeControl {
            in item gait : GaitCommand;
            in item balance : ControlCommand;
            out item actuatorCommands : ActuatorCommand[0..*];
        }

        flow perceiveEnvironment.environmentMap to planTrajectory.map;
        flow planTrajectory.path to generateGait.terrainData;

        succession perceiveEnvironment then planTrajectory;
        succession planTrajectory then generateGait;
        succession generateGait then executeControl;
    }

    // ===== Spot Robot Definition =====
    part def SpotRobot {
        attribute robotId : String;
        attribute manufacturer : String = "Boston Dynamics";
        attribute model : String = "Spot";
        attribute firmwareVersion : String;

        part body : Body;
        part battery : BatteryPack;
        part legFrontLeft : Leg { :>> legId = "FrontLeft"; }
        part legFrontRight : Leg { :>> legId = "FrontRight"; }
        part legRearLeft : Leg { :>> legId = "RearLeft"; }
        part legRearRight : Leg { :>> legId = "RearRight"; }
        part perception : PerceptionSystem;
        part compute : ComputeModule;

        port operatorCommandPort : OperatorCommandPort;

        // Power distribution
        connection batteryToBody connect battery.powerOut to body.bodyPowerIn;
        connection batteryToPerception connect battery.powerOut to perception.perceptionPowerIn;
        connection batteryToCompute connect battery.powerOut to compute.powerIn;

        // Data flow: sensors to compute
        connection perceptionToCompute connect perception.perceptionDataOut to compute.sensorDataIn;

        // Control flow: compute to legs
        connection computeToFrontLeft connect compute.controlOut to legFrontLeft.legControlIn;
        connection computeToFrontRight connect compute.controlOut to legFrontRight.legControlIn;
        connection computeToRearLeft connect compute.controlOut to legRearLeft.legControlIn;
        connection computeToRearRight connect compute.controlOut to legRearRight.legControlIn;

        // Operator commands
        connection operatorToCompute connect operatorCommandPort to compute.operatorIn;

        // Robot operational state machine
        state robotOperation {
            state PoweredOff;

            state Initializing {
                action calibrateSensors;
                action checkSystems;
            }

            state Standby;

            state Operational {
                action autonomousNavigate;
                action detectAvoidObstacles;
            }

            state ManualControl {
                action operatorControlled;
            }

            state Emergency {
                action safeStop;
            }

            transition PoweredOff to Initializing when battery.chargeLevel > 0;
            transition Initializing to Standby when perception.imu.sampleRate > 0;
            transition Standby to Operational when operatorCommandPort.command.commandType == "StartMission";
            transition Operational to ManualControl when operatorCommandPort.command.commandType == "ManualOverride";
            transition ManualControl to Operational when operatorCommandPort.command.commandType == "ResumeAutonomous";
            transition Operational to Emergency when battery.chargeLevel < 5.0;
            transition ManualControl to Emergency when battery.chargeLevel < 5.0;
            transition Operational to Standby when operatorCommandPort.command.commandType == "MissionComplete";
            transition ManualControl to Standby when operatorCommandPort.command.commandType == "Stop";
            transition Emergency to Standby when operatorCommandPort.command.commandType == "Reset";
            transition Standby to PoweredOff when operatorCommandPort.command.commandType == "PowerOff";
        }
    }

    // ===== Requirements =====
    requirement def MobilityRequirement {
        doc "The robot shall achieve a maximum speed of at least 1.6 m/s for autonomous navigation across varied terrain.";
        subject robot : SpotRobot;
        require robot.body.maxSpeed >= 1.6;
    }

    requirement def TerrainTraversalRequirement {
        doc "Each leg shall provide sufficient torque at the hip, shoulder, and knee joints for walking, climbing stairs, and maintaining balance.";
        subject robot : SpotRobot;
        require robot.legFrontLeft.hipActuator.maxTorque >= 30.0;
        require robot.legFrontLeft.shoulderActuator.maxTorque >= 30.0;
        require robot.legFrontLeft.kneeActuator.maxTorque >= 23.0;
        require robot.legFrontRight.hipActuator.maxTorque >= 30.0;
        require robot.legFrontRight.shoulderActuator.maxTorque >= 30.0;
        require robot.legFrontRight.kneeActuator.maxTorque >= 23.0;
        require robot.legRearLeft.hipActuator.maxTorque >= 30.0;
        require robot.legRearLeft.shoulderActuator.maxTorque >= 30.0;
        require robot.legRearLeft.kneeActuator.maxTorque >= 23.0;
        require robot.legRearRight.hipActuator.maxTorque >= 30.0;
        require robot.legRearRight.shoulderActuator.maxTorque >= 30.0;
        require robot.legRearRight.kneeActuator.maxTorque >= 23.0;
    }

    requirement def PerceptionRequirement {
        doc "The perception system shall provide adequate sensing for 3D mapping, visual perception, object recognition, and balance control.";
        subject robot : SpotRobot;
        require robot.perception.frontLidar.scanRange >= 100.0;
        require robot.perception.frontLidar.scanRate >= 10.0;
        require robot.perception.rearLidar.scanRange >= 100.0;
        require robot.perception.rearLidar.scanRate >= 10.0;
        require robot.perception.stereoCamera.frameRate >= 30.0;
        require robot.perception.depthCamera.frameRate >= 30.0;
        require robot.perception.imu.sampleRate >= 200.0;
    }

    requirement def AutonomyRequirement {
        doc "The compute module shall provide sufficient processing power for real-time environment perception, trajectory planning, gait generation, and balance control.";
        subject robot : SpotRobot;
        require robot.compute.processingFrequency >= 1000.0;
        require robot.compute.cpuCores >= 8;
    }

    requirement def EnduranceRequirement {
        doc "The battery pack shall provide sufficient energy for extended mission duration without recharge.";
        subject robot : SpotRobot;
        require robot.battery.nominalVoltage >= 48.0;
        require robot.battery.capacity >= 400.0;
    }

    requirement def SafetyRequirement {
        doc "The robot shall enter an emergency state and perform a safe stop upon detecting a critical error, and shall support manual operator control override.";
        subject robot : SpotRobot;
        require robot.body.payloadCapacity >= 14.0;
    }

    // Requirement instances
    requirement spotMobility : MobilityRequirement {
        subject robot = spotInstance;
    }

    requirement spotTerrainTraversal : TerrainTraversalRequirement {
        subject robot = spotInstance;
    }

    requirement spotPerception : PerceptionRequirement {
        subject robot = spotInstance;
    }

    requirement spotAutonomy : AutonomyRequirement {
        subject robot = spotInstance;
    }

    requirement spotEndurance : EnduranceRequirement {
        subject robot = spotInstance;
    }

    requirement spotSafety : SafetyRequirement {
        subject robot = spotInstance;
    }

    // Top-level instance
    part spotInstance : SpotRobot {
        :>> robotId = "SPOT-001";
    }

    // Satisfaction
    satisfy spotMobility by spotInstance;
    satisfy spotTerrainTraversal by spotInstance;
    satisfy spotPerception by spotInstance;
    satisfy spotAutonomy by spotInstance;
    satisfy spotEndurance by spotInstance;
    satisfy spotSafety by spotInstance;
}
