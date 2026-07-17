package 'ATHLETE System Model' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def TerrainType;
    attribute def MobilityMode;
    attribute def LimbConfiguration;
    attribute def NavigationCommand;
    
    attribute def JointAngle :> ISQ::planeAngleValue {
        doc /* Angular position of limb joint */
    }
    
    attribute def WheelTorque :> ISQ::torqueValue {
        doc /* Torque applied to wheel actuator */
    }
    
    attribute def LimbForce :> ISQ::forceValue {
        doc /* Force exerted by limb */
    }
    
    attribute def PayloadMass :> ISQ::massValue {
        doc /* Mass of transported payload */
    }
    
    attribute def Velocity :> ISQ::speedValue {
        doc /* Rover velocity */
    }
    
    attribute def Position :> ISQ::lengthValue {
        doc /* Position coordinate */
    }
    
    item def Payload {
        attribute mass : PayloadMass;
        attribute volume : ISQ::volumeValue;
        attribute secured : ScalarValues::Boolean;
    }
    
    item def PowerSource {
        attribute capacity : ISQ::energyValue;
        attribute currentCharge : ISQ::energyValue;
        attribute outputPower : ISQ::powerValue;
    }
    
    item def TerrainData {
        attribute roughness : ScalarValues::Real;
        attribute slope : ISQ::planeAngleValue;
        attribute obstacleHeight : ISQ::lengthValue;
    }
    
    port def PowerPort {
        in item powerSupply : PowerSource;
        out attribute powerDemand : ISQ::powerValue;
    }
    
    port def SensorPort {
        out item terrainInfo : TerrainData;
        out attribute obstacleDistance : ISQ::lengthValue;
    }
    
    port def ControlPort {
        in attribute command : MobilityMode;
        out attribute status : LimbConfiguration;
    }
    
    part def Wheel {
        attribute diameter : ISQ::lengthValue;
        attribute steeringAngle : JointAngle;
        attribute rotationSpeed : ISQ::angularVelocityValue;
        
        port drivePort {
            in attribute torqueCommand : WheelTorque;
            out attribute wheelSpeed : ISQ::angularVelocityValue;
        }
    }
    
    part def LimbJoint {
        attribute currentAngle : JointAngle;
        attribute minAngle : JointAngle;
        attribute maxAngle : JointAngle;
        attribute maxTorque : ISQ::torqueValue;
        
        port actuatorPort {
            in attribute torqueCommand : ISQ::torqueValue;
            out attribute jointAngle : JointAngle;
            out attribute jointVelocity : ISQ::angularVelocityValue;
        }
    }
    
    part def Limb {
        attribute limbID : ScalarValues::Integer;
        
        part shoulderJoint : LimbJoint {
            :>> minAngle = -90.0;
            :>> maxAngle = 90.0;
        }
        
        part elbowJoint : LimbJoint {
            :>> minAngle = 0.0;
            :>> maxAngle = 180.0;
        }
        
        part wristJoint : LimbJoint {
            :>> minAngle = -45.0;
            :>> maxAngle = 45.0;
        }
        
        part wheel : Wheel {
            :>> diameter = 0.5;
        }
        
        port limbControl : ControlPort;
        port limbPower : PowerPort;
    }
    
    part def TerrainSensor {
        attribute sensorRange : ISQ::lengthValue;
        attribute updateRate : ISQ::frequencyValue;
        
        port sensorOutput : SensorPort;
    }
    
    part def NavigationSystem {
        attribute currentPosition : Position[3];
        attribute targetPosition : Position[3];
        attribute currentVelocity : Velocity;
        attribute pathPlan : Position[*] ordered;
        
        port navControl {
            in item terrainData : TerrainData;
            in attribute currentState : Position[3];
            out attribute mobilityCommand : MobilityMode;
            out attribute plannedPath : Position[*];
        }
    }
    
    part def MobilityController {
        attribute controlFrequency : ISQ::frequencyValue;
        
        port controlInterface {
            in attribute mobilityMode : MobilityMode;
            in item terrainFeedback : TerrainData;
            out attribute limbCommands : LimbConfiguration[6];
            out attribute wheelCommands : WheelTorque[6];
        }
    }
    
    state def ATHLETEMobilityStates {
        entry; then rolling;
        
        state rolling {
            doc /* All six wheels in contact with ground, standard rolling locomotion */
        }
        
        state walking {
            doc /* Coordinated limb stepping for rough terrain navigation */
        }
        
        state climbing {
            doc /* Limbs grasping and pulling over large obstacles */
        }
        
        state anchored {
            doc /* Limbs locked to provide stable work platform */
        }
        
        transition rolling_to_walking {
            first rolling;
            accept at when terrainRoughness > 0.3;
            then walking;
        }
        
        transition walking_to_climbing {
            first walking;
            accept at when obstacleDetected;
            then climbing;
        }
        
        transition climbing_to_walking {
            first climbing;
            accept at when obstacleCleared;
            then walking;
        }
        
        transition walking_to_rolling {
            first walking;
            accept at when terrainRoughness <= 0.3;
            then rolling;
        }
        
        transition any_to_anchored {
            accept at when anchorCommand;
            then anchored;
        }
        
        transition anchored_to_rolling {
            first anchored;
            accept at when releaseCommand;
            then rolling;
        }
    }
    
    action def SenseEnvironment {
        in currentPosition : Position[3];
        out terrainData : TerrainData;
        out obstacleMap : ISQ::lengthValue[*];
    }
    
    action def PlanPath {
        in terrainData : TerrainData;
        in currentPosition : Position[3];
        in targetPosition : Position[3];
        out pathPlan : Position[*];
        out mobilityMode : MobilityMode;
    }
    
    action def ConfigureLimbs {
        in mobilityMode : MobilityMode;
        in terrainFeedback : TerrainData;
        out limbConfigurations : LimbConfiguration[6];
    }
    
    action def ActuateLimbs {
        in limbConfigurations : LimbConfiguration[6];
        in wheelCommands : WheelTorque[6];
        out limbForces : LimbForce[6];
    }
    
    action def UpdatePosition {
        in limbForces : LimbForce[6];
        in currentPosition : Position[3];
        in currentVelocity : Velocity;
        in deltaTime : ISQ::timeValue;
        out newPosition : Position[3];
        out newVelocity : Velocity;
    }
    
    action def TransportPayload {
        in navigationCommand : NavigationCommand;
        in payloadMass : PayloadMass;
        in targetLocation : Position[3];
        out deliveryStatus : ScalarValues::Boolean;
        
        private attribute currentPos : Position[3];
        private attribute currentVel : Velocity := 0.0;
        private attribute timeStep : ISQ::timeValue := 0.1;
        
        first start;
        then merge continueTransport;
        
        then action sense : SenseEnvironment {
            in currentPosition = currentPos;
            out terrainData;
            out obstacleMap;
        }
        
        then action plan : PlanPath {
            in terrainData = sense.terrainData;
            in currentPosition = currentPos;
            in targetPosition = targetLocation;
            out pathPlan;
            out mobilityMode;
        }
        
        then action configure : ConfigureLimbs {
            in mobilityMode = plan.mobilityMode;
            in terrainFeedback = sense.terrainData;
            out limbConfigurations;
        }
        
        then action actuate : ActuateLimbs {
            in limbConfigurations = configure.limbConfigurations;
            in wheelCommands;
            out limbForces;
        }
        
        then action update : UpdatePosition {
            in limbForces = actuate.limbForces;
            in currentPosition = currentPos;
            in currentVelocity = currentVel;
            in deltaTime = timeStep;
            out newPosition;
            out newVelocity;
        }
        
        then assign currentPos := update.newPosition;
        then assign currentVel := update.newVelocity;
        
        then decide;
            if distanceToTarget(currentPos, targetLocation) > 1.0
                then continueTransport;
            if distanceToTarget(currentPos, targetLocation) <= 1.0
                then complete;
        
        action complete {
            assign deliveryStatus := true;
        }
        then done;
    }
    
    part def ATHLETERover {
        doc /* 
            All-Terrain Hex-Limbed Extra-Terrestrial Explorer (ATHLETE) is an advanced
            robotic mobility system designed for planetary exploration and cargo transport.
            
            Primary Function: Autonomously transport heavy payloads across challenging
            extraterrestrial terrain by dynamically adapting its mobility mode between
            rolling, walking, and climbing based on real-time terrain assessment and
            obstacle detection.
            
            The system employs six independently articulated limbs, each equipped with
            a steerable wheel, enabling seamless transitions between wheeled rolling on
            smooth surfaces, coordinated walking over rough terrain, and climbing over
            large obstacles. This adaptive multi-modal locomotion allows ATHLETE to
            navigate environments that would be impassable for conventional rovers.
        */
        
        attribute totalMass : ISQ::massValue;
        attribute maxPayloadCapacity : PayloadMass;
        attribute maxSpeed : Velocity;
        attribute maxClimbAngle : ISQ::planeAngleValue;
        attribute operatingTemperatureRange : ISQ::thermodynamicTemperatureValue[2];
        
        part limbs : Limb[6] {
            doc /* Six independently articulated limbs with wheels */
        }
        
        part sensors : TerrainSensor[*] {
            doc /* Multiple terrain and obstacle sensors */
        }
        
        part navigation : NavigationSystem {
            doc /* Autonomous navigation and path planning system */
        }
        
        part mobilityControl : MobilityController {
            doc /* Coordinates limb and wheel actuation */
            :>> controlFrequency = 10.0;
        }
        
        part powerSystem : PowerSource {
            doc /* Primary power source for all systems */
        }
        
        part payload : Payload[0..1] {
            doc /* Optional transported payload */
        }
        
        connection powerToLimb1 connect powerSystem to limbs[1].limbPower;
        connection powerToLimb2 connect powerSystem to limbs[2].limbPower;
        connection powerToLimb3 connect powerSystem to limbs[3].limbPower;
        connection powerToLimb4 connect powerSystem to limbs[4].limbPower;
        connection powerToLimb5 connect powerSystem to limbs[5].limbPower;
        connection powerToLimb6 connect powerSystem to limbs[6].limbPower;
        
        connection sensorToNav connect sensors.sensorOutput to navigation.navControl;
        connection navToControl connect navigation.navControl to mobilityControl.controlInterface;
        connection controlToLimb1 connect mobilityControl.controlInterface to limbs[1].limbControl;
        connection controlToLimb2 connect mobilityControl.controlInterface to limbs[2].limbControl;
        connection controlToLimb3 connect mobilityControl.controlInterface to limbs[3].limbControl;
        connection controlToLimb4 connect mobilityControl.controlInterface to limbs[4].limbControl;
        connection controlToLimb5 connect mobilityControl.controlInterface to limbs[5].limbControl;
        connection controlToLimb6 connect mobilityControl.controlInterface to limbs[6].limbControl;
        
        perform action transport : TransportPayload;
        
        exhibit state mobilityBehavior : ATHLETEMobilityStates;
    }
    
    requirement def <'REQ-001'> MobilityRequirement {
        doc /* ATHLETE shall traverse rough terrain using adaptive limb configurations */
        
        subject athlete : ATHLETERover;
        
        require constraint {
            athlete.limbs->size() == 6
        }
        
        require constraint {
            athlete.maxClimbAngle >= 30.0
        }
    }
    
    requirement def <'REQ-002'> PayloadTransportRequirement {
        doc /* ATHLETE shall transport payloads across extraterrestrial terrain */
        
        subject athlete : ATHLETERover;
        
        require constraint {
            athlete.maxPayloadCapacity >= 450.0
        }
        
        require constraint {
            athlete.totalMass <= 850.0
        }
    }
    
    requirement def <'REQ-003'> AutonomyRequirement {
        doc /* ATHLETE shall autonomously navigate and adapt to terrain conditions */
        
        subject athlete : ATHLETERover;
        
        require constraint {
            athlete.navigation.pathPlan->notEmpty()
        }
    }
    
    requirement def <'REQ-004'> PowerRequirement {
        doc /* ATHLETE shall provide sufficient power to all subsystems during operation */
        
        subject athlete : ATHLETERover;
        
        require constraint {
            athlete.powerSystem.currentCharge > 0.2 * athlete.powerSystem.capacity
        }
    }
    
    requirement <'SYS-001'> athleteSystemRequirement {
        doc /* Top-level requirement for ATHLETE system capabilities */
        
        subject rover : ATHLETERover;
        
        require <'REQ-001'> mobilityReq : MobilityRequirement;
        require <'REQ-002'> payloadReq : PayloadTransportRequirement;
        require <'REQ-003'> autonomyReq : AutonomyRequirement;
        require <'REQ-004'> powerReq : PowerRequirement;
    }
    
    part athleteSystem : ATHLETERover {
        :>> totalMass = 750.0;
        :>> maxPayloadCapacity = 450.0;
        :>> maxSpeed = 10.0;
        :>> maxClimbAngle = 35.0;
        :>> operatingTemperatureRange = (223.15, 323.15);
        
        :>> powerSystem {
            :>> capacity = 5000.0;
            :>> currentCharge = 4500.0;
            :>> outputPower = 500.0;
        }
        
        satisfy athleteSystemRequirement;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import 'ATHLETE System Model'::*;

    part testSubject : ATHLETERover {
        exhibit state mobilityBehavior : ATHLETEMobilityStates;
    }

    action orchestrator {
        action actionProbe : SenseEnvironment {
            // TODO(human): unsupported input type for currentPosition: Position[3] (type is not a primitive, enum, extracted payload def, or known value type)
        }
        first actionProbe;
    }
}
