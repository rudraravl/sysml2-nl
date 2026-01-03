package SituatedRoboticsSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def EnvironmentCondition;
    attribute def ObstaclePresent;
    attribute def PathClear;
    attribute def GoalReached;
    attribute def EmergencyStop;
    
    item def SpatialPosition {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute heading : PlaneAngleValue;
    }
    
    item def VelocityVector {
        attribute linear : SpeedValue;
        attribute angular : AngularVelocityValue;
    }
    
    item def ProximityReading {
        attribute distance : LengthValue;
        attribute bearing : PlaneAngleValue;
        attribute timestamp : TimeValue;
    }
    
    item def MotorCommand {
        attribute leftWheelSpeed : SpeedValue;
        attribute rightWheelSpeed : SpeedValue;
        attribute duration : TimeValue;
    }
    
    item def EnvironmentModel {
        attribute nearestObstacleDistance : LengthValue;
        attribute obstacleDirection : PlaneAngleValue;
        attribute openPathDirection : PlaneAngleValue;
        attribute confidence : Real;
    }
    
    port def SensorDataPort {
        out proximityData : ProximityReading;
    }
    
    port def ActuationPort {
        in motorCmd : MotorCommand;
        out actualVelocity : VelocityVector;
    }
    
    port def PerceptionPort {
        in rawSensorData : ProximityReading[*];
        out environmentModel : EnvironmentModel;
    }
    
    port def BehaviorPort {
        in environmentModel : EnvironmentModel;
        in currentPosition : SpatialPosition;
        out actionCommand : MotorCommand;
    }
    
    part def UltrasonicSensor {
        port output : SensorDataPort;
        attribute range : LengthValue;
        attribute beamAngle : PlaneAngleValue;
        attribute updateRate : FrequencyValue;
        
        action measureDistance {
            out reading : ProximityReading;
        }
    }
    
    part def InfraredSensor {
        port output : SensorDataPort;
        attribute detectionRange : LengthValue;
        attribute responseTime : TimeValue;
        
        action detectProximity {
            out reading : ProximityReading;
        }
    }
    
    part def WheelMotor {
        port control : ActuationPort;
        attribute maxSpeed : SpeedValue;
        attribute maxTorque : TorqueValue;
        attribute wheelRadius : LengthValue;
        
        action driveWheel {
            in command : MotorCommand;
            out velocity : SpeedValue;
        }
    }
    
    part def PerceptionSubsystem {
        port perceptionInterface : PerceptionPort;
        
        action fuseProximityData {
            in sensorReadings : ProximityReading[*];
            out fusedModel : EnvironmentModel;
        }
        
        action identifyObstacles {
            in readings : ProximityReading[*];
            out obstacleDistance : LengthValue;
            out obstacleAngle : PlaneAngleValue;
        }
        
        action findOpenSpace {
            in environmentData : EnvironmentModel;
            out safeDirection : PlaneAngleValue;
        }
    }
    
    part def ReactiveBehaviorController {
        port behaviorInterface : BehaviorPort;
        
        attribute safetyThreshold : LengthValue;
        attribute cruiseSpeed : SpeedValue;
        attribute turnRate : AngularVelocityValue;
        
        action selectBehavior {
            in envModel : EnvironmentModel;
            in position : SpatialPosition;
            out selectedAction : MotorCommand;
        }
    }
    
    action def SenseEnvironment {
        in sensorArray : ProximityReading[*];
        out aggregatedData : ProximityReading[*];
    }
    
    action def BuildEnvironmentModel {
        in proximityData : ProximityReading[*];
        out worldModel : EnvironmentModel;
    }
    
    action def GenerateReactiveResponse {
        in worldModel : EnvironmentModel;
        in robotPose : SpatialPosition;
        out motorCommands : MotorCommand;
    }
    
    action def ExecuteMotorCommands {
        in commands : MotorCommand;
        out achievedVelocity : VelocityVector;
    }
    
    action def UpdateRobotState {
        in velocity : VelocityVector;
        in deltaTime : TimeValue;
        in previousPose : SpatialPosition;
        out newPose : SpatialPosition;
    }
    
    part def SituatedMobileRobot {
        attribute currentPose : SpatialPosition;
        attribute operationalStatus : String;
        
        part frontUltrasonic : UltrasonicSensor {
            attribute :>> range = 3.0 [m];
            attribute :>> beamAngle = 15.0 [deg];
            attribute :>> updateRate = 10.0 [Hz];
        }
        
        part leftInfrared : InfraredSensor {
            attribute :>> detectionRange = 0.8 [m];
            attribute :>> responseTime = 0.05 [s];
        }
        
        part rightInfrared : InfraredSensor {
            attribute :>> detectionRange = 0.8 [m];
            attribute :>> responseTime = 0.05 [s];
        }
        
        part rearUltrasonic : UltrasonicSensor {
            attribute :>> range = 2.0 [m];
            attribute :>> beamAngle = 20.0 [deg];
            attribute :>> updateRate = 5.0 [Hz];
        }
        
        part leftMotor : WheelMotor {
            attribute :>> maxSpeed = 1.5 [m/s];
            attribute :>> maxTorque = 8.0 [N*m];
            attribute :>> wheelRadius = 0.1 [m];
        }
        
        part rightMotor : WheelMotor {
            attribute :>> maxSpeed = 1.5 [m/s];
            attribute :>> maxTorque = 8.0 [N*m];
            attribute :>> wheelRadius = 0.1 [m];
        }
        
        part perception : PerceptionSubsystem;
        
        part behaviorController : ReactiveBehaviorController {
            attribute :>> safetyThreshold = 0.5 [m];
            attribute :>> cruiseSpeed = 0.8 [m/s];
            attribute :>> turnRate = 0.6 [rad/s];
        }
        
        connection frontUltrasonic.output to perception.perceptionInterface;
        connection leftInfrared.output to perception.perceptionInterface;
        connection rightInfrared.output to perception.perceptionInterface;
        connection rearUltrasonic.output to perception.perceptionInterface;
        
        connection perception.perceptionInterface to behaviorController.behaviorInterface;
        
        connection behaviorController.behaviorInterface to leftMotor.control;
        connection behaviorController.behaviorInterface to rightMotor.control;
        
        perform action autonomousOperation;
    }
    
    action autonomousOperation {
        first start;
        then merge perceptionActionLoop;
        
        action gatherSensorData : SenseEnvironment {
            in sensorArray : ProximityReading[*];
            out aggregatedData : ProximityReading[*];
        }
        
        flow gatherSensorData.aggregatedData to constructModel.proximityData;
        
        action constructModel : BuildEnvironmentModel {
            in proximityData : ProximityReading[*];
            out worldModel : EnvironmentModel;
        }
        
        flow constructModel.worldModel to generateAction.worldModel;
        
        action generateAction : GenerateReactiveResponse {
            in worldModel : EnvironmentModel;
            in robotPose : SpatialPosition;
            out motorCommands : MotorCommand;
        }
        
        flow generateAction.motorCommands to actuate.commands;
        
        action actuate : ExecuteMotorCommands {
            in commands : MotorCommand;
            out achievedVelocity : VelocityVector;
        }
        
        flow actuate.achievedVelocity to updateState.velocity;
        
        action updateState : UpdateRobotState {
            in velocity : VelocityVector;
            in deltaTime : TimeValue;
            in previousPose : SpatialPosition;
            out newPose : SpatialPosition;
        }
        
        then decide;
            if continueOperation then perceptionActionLoop;
            if shutdownRequested then terminateOperation;
        
        action terminateOperation;
        then done;
    }
    
    requirement <'REQ-SR-001'> situatedRoboticsCapability {
        doc /* The situated robotics system shall autonomously navigate through 
               unstructured environments by continuously coupling perception 
               directly to action without relying on internal world models or 
               deliberative planning. */
        
        subject robot : SituatedMobileRobot;
        
        require constraint tightPerceptionActionCoupling {
            doc /* Sensory information shall directly trigger motor responses 
                   with minimal computational delay. */
        }
        
        require constraint environmentEmbodiment {
            doc /* The robot's behavior shall emerge from continuous interaction 
                   with its physical environment. */
        }
    }
    
    requirement <'REQ-SR-002'> reactiveObstacleAvoidance {
        doc /* The system shall detect obstacles within sensor range and 
               immediately execute avoidance behaviors without pre-planning 
               trajectories. */
        
        attribute maxReactionTime : TimeValue = 0.2 [s];
        attribute minSafeDistance : LengthValue = 0.3 [m];
        
        require constraint immediateResponse {
            doc /* Obstacle detection shall trigger avoidance within 200ms. */
        }
    }
    
    requirement <'REQ-SR-003'> emergentNavigationBehavior {
        doc /* Complex navigation capabilities shall emerge from simple reactive 
               rules combining multiple sensor inputs without explicit path 
               planning or map building. */
        
        assume constraint distributedSensing {
            doc /* Multiple sensors provide overlapping coverage of the robot's 
                   surroundings. */
        }
        
        require constraint behaviorComposition {
            doc /* Simple reactive behaviors combine to produce robust navigation. */
        }
    }
    
    requirement <'REQ-SR-004'> realTimePerformance {
        doc /* The perception-action cycle shall execute continuously at a 
               minimum frequency to ensure responsive behavior. */
        
        attribute minCycleFrequency : FrequencyValue = 5.0 [Hz];
        
        require constraint continuousOperation {
            doc /* The system shall maintain uninterrupted perception-action loops 
                   during operation. */
        }
    }
}
