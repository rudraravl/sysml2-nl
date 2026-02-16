package HexapodSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import SequenceFunctions::*;
    
    attribute def GaitType;
    attribute def TerrainCondition;
    attribute def MovementCommand;
    attribute def StopCommand;
    
    item def PowerSupply {
        attribute voltage : ISQ::VoltageValue;
        attribute currentCapacity : ISQ::ElectricCurrentValue;
        attribute remainingCharge : Real;
    }
    
    item def SensorReading {
        attribute proximityDistance : ISQ::LengthValue;
        attribute groundContact : Boolean;
        attribute orientation : ISQ::AngleValue;
    }
    
    item def JointCommand {
        attribute targetAngle : ISQ::AngleValue;
        attribute targetTorque : ISQ::TorqueValue;
        attribute velocity : ISQ::AngularVelocityValue;
    }
    
    port def PowerPort {
        out item power : PowerSupply;
    }
    
    port def SensorDataPort {
        out item sensorData : SensorReading;
    }
    
    port def ActuatorControlPort {
        in item controlSignal : JointCommand;
    }
    
    part def Joint {
        attribute currentAngle : ISQ::AngleValue;
        attribute maxTorque : ISQ::TorqueValue;
        attribute minAngle : ISQ::AngleValue;
        attribute maxAngle : ISQ::AngleValue;
        
        port actuatorPort : ActuatorControlPort;
        
        action def SetJointPosition {
            in targetAngle : ISQ::AngleValue;
            in targetTorque : ISQ::TorqueValue;
        }
    }
    
    part def LegSegment {
        attribute segmentLength : ISQ::LengthValue;
        attribute segmentMass : ISQ::MassValue;
        
        part coxaJoint : Joint;
        part femurJoint : Joint;
        part tibiaJoint : Joint;
        
        port legControlCoxa : ActuatorControlPort;
        port legControlFemur : ActuatorControlPort;
        port legControlTibia : ActuatorControlPort;
        
        action def MoveLegToPosition {
            in coxaAngle : ISQ::AngleValue;
            in femurAngle : ISQ::AngleValue;
            in tibiaAngle : ISQ::AngleValue;
        }
    }
    
    part def GroundSensor {
        attribute detectionRange : ISQ::LengthValue;
        attribute sensitivity : Real;
        
        port sensorOut : SensorDataPort;
        
        action def DetectGround {
            out contactDetected : Boolean;
            out distance : ISQ::LengthValue;
        }
    }
    
    part def ControlProcessor {
        attribute computationFrequency : ISQ::FrequencyValue;
        attribute memoryCapacity : Real;
        
        port powerInput : ~PowerPort;
        port sensorInput1 : ~SensorDataPort;
        port sensorInput2 : ~SensorDataPort;
        port sensorInput3 : ~SensorDataPort;
        port sensorInput4 : ~SensorDataPort;
        port sensorInput5 : ~SensorDataPort;
        port sensorInput6 : ~SensorDataPort;
        port actuatorOutput1 : ActuatorControlPort;
        port actuatorOutput2 : ActuatorControlPort;
        port actuatorOutput3 : ActuatorControlPort;
        port actuatorOutput4 : ActuatorControlPort;
        port actuatorOutput5 : ActuatorControlPort;
        port actuatorOutput6 : ActuatorControlPort;
        port actuatorOutput7 : ActuatorControlPort;
        port actuatorOutput8 : ActuatorControlPort;
        port actuatorOutput9 : ActuatorControlPort;
        port actuatorOutput10 : ActuatorControlPort;
        port actuatorOutput11 : ActuatorControlPort;
        port actuatorOutput12 : ActuatorControlPort;
        port actuatorOutput13 : ActuatorControlPort;
        port actuatorOutput14 : ActuatorControlPort;
        port actuatorOutput15 : ActuatorControlPort;
        port actuatorOutput16 : ActuatorControlPort;
        port actuatorOutput17 : ActuatorControlPort;
        port actuatorOutput18 : ActuatorControlPort;
        
        action def ProcessSensorData {
            in sensorReadings : SensorReading[6];
            out terrainAnalysis : TerrainCondition;
        }
        
        action def ComputeGaitPattern {
            in terrainCondition : TerrainCondition;
            in movementCmd : MovementCommand;
            out selectedGait : GaitType;
        }
    }
    
    part def BatteryPack {
        attribute totalCapacity : ISQ::EnergyValue;
        attribute currentCharge : ISQ::EnergyValue;
        attribute outputVoltage : ISQ::VoltageValue;
        
        port powerOutput : PowerPort;
        
        action def SupplyPower {
            out powerLevel : ISQ::PowerValue;
        }
    }
    
    action def ScanTerrain {
        in currentTerrain : TerrainCondition;
        out obstacleDetected : Boolean;
        out surfaceReadings : SensorReading[6];
    }
    
    action def SelectGait {
        in obstaclePresent : Boolean;
        in commandedDirection : MovementCommand;
        out gaitPattern : GaitType;
    }
    
    action def GenerateJointTrajectories {
        in gaitPattern : GaitType;
        in legNumber : Integer;
        out jointCommands : JointCommand[3];
    }
    
    action def ExecuteLegMotion {
        in jointCommands : JointCommand[3];
        out legPosition : ISQ::LengthValue;
    }
    
    action def CoordinatedLocomotion {
        in movementCommand : MovementCommand;
        in terrainCondition : TerrainCondition;
        out allJointCommands : JointCommand[18];
        
        first start;
        then merge locomotionCycle;
        
        then action scanEnvironment : ScanTerrain {
            in currentTerrain = CoordinatedLocomotion::terrainCondition;
            out obstacleDetected;
            out surfaceReadings;
        }
        
        then action selectGaitPattern : SelectGait {
            in obstaclePresent = scanEnvironment.obstacleDetected;
            in commandedDirection = CoordinatedLocomotion::movementCommand;
            out gaitPattern;
        }
        
        then action coordinateAllLegs {
            private attribute legIndex : Integer := 1;
            private attribute accumulatedCommands : JointCommand[18] := ();
            
            for legIdx in 1..6 {
                action generateTrajectory : GenerateJointTrajectories {
                    in gaitPattern = selectGaitPattern.gaitPattern;
                    in legNumber = legIdx;
                    out jointCommands;
                }
                then assign accumulatedCommands := accumulatedCommands->including(generateTrajectory.jointCommands->at(1));
                then assign accumulatedCommands := accumulatedCommands->including(generateTrajectory.jointCommands->at(2));
                then assign accumulatedCommands := accumulatedCommands->including(generateTrajectory.jointCommands->at(3));
            }
            then assign allJointCommands := accumulatedCommands;
        }
        
        then locomotionCycle;
    }
    
    state def HexapodOperationalMode {
        entry; then standby;
        
        state standby {
            entry assign operatingMode := "Standby";
        }
        
        transition standby_to_active
            first standby
            accept activationCmd : MovementCommand
            then activeLocomotion;
        
        state activeLocomotion {
            entry assign operatingMode := "Active";
            do action locomote : CoordinatedLocomotion;
        }
        
        transition active_to_obstacle
            first activeLocomotion
            if obstacleEncountered
            then obstacleResponse;
        
        state obstacleResponse {
            entry assign operatingMode := "ObstacleAvoidance";
            do action navigateObstacle;
        }
        
        transition obstacle_to_active
            first obstacleResponse
            if pathCleared
            then activeLocomotion;
        
        transition active_to_standby
            first activeLocomotion
            accept haltCmd : StopCommand
            then standby;
        
        private attribute operatingMode : String;
        private attribute obstacleEncountered : Boolean;
        private attribute pathCleared : Boolean;
        
        action navigateObstacle;
    }
    
    part def Hexapod {
        attribute totalMass : ISQ::MassValue;
        attribute maximumSpeed : ISQ::SpeedValue;
        attribute bodyWidth : ISQ::LengthValue;
        attribute bodyLength : ISQ::LengthValue;
        attribute currentMode : String;
    }
    
    part hexapodRobot : Hexapod {
        attribute totalMass = 12.5[SI::kg];
        attribute maximumSpeed = 0.6[SI::m/SI::s];
        attribute bodyWidth = 0.35[SI::m];
        attribute bodyLength = 0.45[SI::m];
        
        part frontLeftLeg : LegSegment {
            attribute segmentLength = 0.15[SI::m];
            attribute segmentMass = 0.4[SI::kg];
        }
        
        part frontRightLeg : LegSegment {
            attribute segmentLength = 0.15[SI::m];
            attribute segmentMass = 0.4[SI::kg];
        }
        
        part middleLeftLeg : LegSegment {
            attribute segmentLength = 0.15[SI::m];
            attribute segmentMass = 0.4[SI::kg];
        }
        
        part middleRightLeg : LegSegment {
            attribute segmentLength = 0.15[SI::m];
            attribute segmentMass = 0.4[SI::kg];
        }
        
        part rearLeftLeg : LegSegment {
            attribute segmentLength = 0.15[SI::m];
            attribute segmentMass = 0.4[SI::kg];
        }
        
        part rearRightLeg : LegSegment {
            attribute segmentLength = 0.15[SI::m];
            attribute segmentMass = 0.4[SI::kg];
        }
        
        part frontLeftSensor : GroundSensor {
            attribute detectionRange = 0.25[SI::m];
            attribute sensitivity = 0.95;
        }
        
        part frontRightSensor : GroundSensor {
            attribute detectionRange = 0.25[SI::m];
            attribute sensitivity = 0.95;
        }
        
        part middleLeftSensor : GroundSensor {
            attribute detectionRange = 0.25[SI::m];
            attribute sensitivity = 0.95;
        }
        
        part middleRightSensor : GroundSensor {
            attribute detectionRange = 0.25[SI::m];
            attribute sensitivity = 0.95;
        }
        
        part rearLeftSensor : GroundSensor {
            attribute detectionRange = 0.25[SI::m];
            attribute sensitivity = 0.95;
        }
        
        part rearRightSensor : GroundSensor {
            attribute detectionRange = 0.25[SI::m];
            attribute sensitivity = 0.95;
        }
        
        part mainController : ControlProcessor {
            attribute computationFrequency = 100.0[SI::Hz];
            attribute memoryCapacity = 512.0;
        }
        
        part batterySystem : BatteryPack {
            attribute totalCapacity = 180.0[SI::kJ];
            attribute currentCharge = 150.0[SI::kJ];
            attribute outputVoltage = 12.0[SI::V];
        }
        
        connection powerDistribution connect 
            batterySystem.powerOutput to mainController.powerInput;
        
        connection sensorLink1 connect 
            frontLeftSensor.sensorOut to mainController.sensorInput1;
        connection sensorLink2 connect 
            frontRightSensor.sensorOut to mainController.sensorInput2;
        connection sensorLink3 connect 
            middleLeftSensor.sensorOut to mainController.sensorInput3;
        connection sensorLink4 connect 
            middleRightSensor.sensorOut to mainController.sensorInput4;
        connection sensorLink5 connect 
            rearLeftSensor.sensorOut to mainController.sensorInput5;
        connection sensorLink6 connect 
            rearRightSensor.sensorOut to mainController.sensorInput6;
        
        connection actuatorLink1 connect 
            mainController.actuatorOutput1 to frontLeftLeg.legControlCoxa;
        connection actuatorLink2 connect 
            mainController.actuatorOutput2 to frontLeftLeg.legControlFemur;
        connection actuatorLink3 connect 
            mainController.actuatorOutput3 to frontLeftLeg.legControlTibia;
        connection actuatorLink4 connect 
            mainController.actuatorOutput4 to frontRightLeg.legControlCoxa;
        connection actuatorLink5 connect 
            mainController.actuatorOutput5 to frontRightLeg.legControlFemur;
        connection actuatorLink6 connect 
            mainController.actuatorOutput6 to frontRightLeg.legControlTibia;
        connection actuatorLink7 connect 
            mainController.actuatorOutput7 to middleLeftLeg.legControlCoxa;
        connection actuatorLink8 connect 
            mainController.actuatorOutput8 to middleLeftLeg.legControlFemur;
        connection actuatorLink9 connect 
            mainController.actuatorOutput9 to middleLeftLeg.legControlTibia;
        connection actuatorLink10 connect 
            mainController.actuatorOutput10 to middleRightLeg.legControlCoxa;
        connection actuatorLink11 connect 
            mainController.actuatorOutput11 to middleRightLeg.legControlFemur;
        connection actuatorLink12 connect 
            mainController.actuatorOutput12 to middleRightLeg.legControlTibia;
        connection actuatorLink13 connect 
            mainController.actuatorOutput13 to rearLeftLeg.legControlCoxa;
        connection actuatorLink14 connect 
            mainController.actuatorOutput14 to rearLeftLeg.legControlFemur;
        connection actuatorLink15 connect 
            mainController.actuatorOutput15 to rearLeftLeg.legControlTibia;
        connection actuatorLink16 connect 
            mainController.actuatorOutput16 to rearRightLeg.legControlCoxa;
        connection actuatorLink17 connect 
            mainController.actuatorOutput17 to rearRightLeg.legControlFemur;
        connection actuatorLink18 connect 
            mainController.actuatorOutput18 to rearRightLeg.legControlTibia;
        
        perform action locomotionBehavior : CoordinatedLocomotion;
        
        exhibit state operationalStateMachine : HexapodOperationalMode;
    }
    
    requirement def MobilityRequirement;
    requirement def StabilityRequirement;
    requirement def AdaptabilityRequirement;
    requirement def PowerEfficiencyRequirement;
    
    requirement <'REQ-HEX-001'> mobilityCapability : MobilityRequirement {
        doc /* The hexapod system shall traverse complex terrain using coordinated 
                six-legged locomotion with adaptive gait patterns to achieve stable 
                forward movement at commanded speeds. */
        
        subject hexapodSystem : Hexapod;
        
        require constraint { hexapodSystem.totalMass <= 15.0[SI::kg] }
        require constraint { hexapodSystem.maximumSpeed >= 0.5[SI::m/SI::s] }
    }
    
    requirement <'REQ-HEX-002'> staticStabilityMaintenance : StabilityRequirement {
        doc /* The hexapod system shall maintain static stability during all phases 
                of locomotion by ensuring a minimum of three legs remain in ground 
                contact at all times. */
        
        subject hexapodSystem : Hexapod;
    }
    
    requirement <'REQ-HEX-003'> terrainAdaptation : AdaptabilityRequirement {
        doc /* The hexapod system shall detect terrain variations and obstacles 
                using proximity sensors and autonomously adapt gait patterns to 
                navigate uneven surfaces and avoid collisions. */
        
        subject hexapodSystem : Hexapod;
        
        assume constraint { 
            hexapodRobot.frontLeftSensor.detectionRange >= 0.2[SI::m] and
            hexapodRobot.frontRightSensor.detectionRange >= 0.2[SI::m]
        }
    }
    
    requirement <'REQ-HEX-004'> energyEfficiency : PowerEfficiencyRequirement {
        doc /* The hexapod system shall operate for a minimum of 60 minutes on 
                a single battery charge under normal locomotion conditions. */
        
        subject hexapodSystem : Hexapod;
        
        require constraint { 
            hexapodRobot.batterySystem.totalCapacity >= 150.0[SI::kJ]
        }
    }
    
    requirement hexapodPrimaryMission {
        doc /* The hexapod system shall provide autonomous mobile locomotion 
                capabilities for terrain exploration, navigation, and payload 
                transport across varied environmental conditions. */
        
        require mobilityCapability;
        require staticStabilityMaintenance;
        require terrainAdaptation;
        require energyEfficiency;
    }
}
