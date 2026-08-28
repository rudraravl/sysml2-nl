package ATHLETE_Rover_System {
    public import ISQ::*;
    public import ScalarValues::*;

    package Definitions {
        public import PartDefinitions::*;
        public import PortDefinitions::*;
        public import ItemDefinitions::*;
        public import ActionDefinitions::*;
        public import RequirementDefinitions::*;

        package ItemDefinitions {
            item def TerrainData {
                attribute surfaceRoughness : Real;
                attribute slopeAngle : ISQ::AngleValue;
                attribute obstacleHeight : LengthValue;
                attribute firmness : Real;
            }
            item def NavigationCommand {
                attribute targetDestination : LengthValue;
                attribute recommendedMode : String;
            }
            item def JointCommand {
                attribute jointTorques : TorqueValue[6];
                attribute jointAngles : ISQ::AngleValue[6];
            }
            item def WheelCommand {
                attribute driveTorque : TorqueValue;
                attribute steerAngle : ISQ::AngleValue;
            }
            item def PowerSignal;
        }

        package PortDefinitions {
            port def TerrainDataPort {
                out terrainData : TerrainData;
            }
            port def NavCommandPort {
                out navCommand : NavigationCommand;
            }
            port def JointCommandPort {
                out jointCommand : JointCommand;
            }
            port def WheelCommandPort {
                out wheelCommand : WheelCommand;
            }
            port def PowerPort {
                out power : PowerSignal;
            }
        }

        package PartDefinitions {
            part def ATHLETE {
                attribute mass : MassValue;
                attribute maxPayloadMass : MassValue = 500.0[kg];
                attribute maxSpeed : SpeedValue;
                attribute powerConsumption : PowerValue;
                attribute position : LengthValue;
                attribute velocity : SpeedValue;
                
                part powerSource : PowerSource;
                part terrainSensors : TerrainSensor;
                part navSystem : NavigationSystem;
                part mobilityController : MobilityController;
                part limbs : Limb[6];
                part payload : Payload[0..1];
                
                connect powerSource.powerOut to navSystem.powerIn;
                connect powerSource.powerOut to mobilityController.powerIn;
                connect powerSource.powerOut to limbs.powerIn;
                connect powerSource.powerOut to payload.powerIn;
                
                connect terrainSensors.dataOut to navSystem.dataIn;
                connect navSystem.cmdOut to mobilityController.navIn;
                connect mobilityController.cmdOut to limbs.cmdIn;
                
                perform action navigate;
                perform action controlMobility;
                perform action moveRover;
                perform action configureForRolling;
                perform action maintainWheelDrive;
                perform action configureForWalking;
                perform action coordinateLimbGait;
                perform action configureForClimbing;
                perform action executeClimbingSequence;
                perform action lockJoints;
                perform action stabilizePlatform;
                
                exhibit state mobilityModes {
                    entry action initial;
                    state rolling {
                        entry configureForRolling;
                        do maintainWheelDrive;
                    }
                    state walking {
                        entry configureForWalking;
                        do coordinateLimbGait;
                    }
                    state climbing {
                        entry configureForClimbing;
                        do executeClimbingSequence;
                    }
                    state anchored {
                        entry lockJoints;
                        do stabilizePlatform;
                    }
                    
                    transition initial then rolling;
                    
                    transition rolling_to_walking
                        first rolling
                        accept navCmd : NavigationCommand
                        if navCmd.recommendedMode == "Walking"
                        then walking;
                        
                    transition walking_to_rolling
                        first walking
                        accept navCmd : NavigationCommand
                        if navCmd.recommendedMode == "Rolling"
                        then rolling;
                        
                    transition rolling_to_climbing
                        first rolling
                        accept navCmd : NavigationCommand
                        if navCmd.recommendedMode == "Climbing"
                        then climbing;
                        
                    transition climbing_to_rolling
                        first climbing
                        accept navCmd : NavigationCommand
                        if navCmd.recommendedMode == "Rolling"
                        then rolling;
                        
                    transition rolling_to_anchored
                        first rolling
                        accept navCmd : NavigationCommand
                        if navCmd.recommendedMode == "Anchored"
                        then anchored;
                        
                    transition walking_to_anchored
                        first walking
                        accept navCmd : NavigationCommand
                        if navCmd.recommendedMode == "Anchored"
                        then anchored;
                        
                    transition climbing_to_anchored
                        first climbing
                        accept navCmd : NavigationCommand
                        if navCmd.recommendedMode == "Anchored"
                        then anchored;
                        
                    transition anchored_to_rolling
                        first anchored
                        accept navCmd : NavigationCommand
                        if navCmd.recommendedMode == "Rolling"
                        then rolling;
                        
                    transition walking_to_climbing
                        first walking
                        accept navCmd : NavigationCommand
                        if navCmd.recommendedMode == "Climbing"
                        then climbing;
                        
                    transition climbing_to_walking
                        first climbing
                        accept navCmd : NavigationCommand
                        if navCmd.recommendedMode == "Walking"
                        then walking;
                }
            }
            
            part def Limb {
                attribute length : LengthValue;
                attribute maxTorque : TorqueValue;
                port cmdIn : JointCommandPort;
                port powerIn : PowerPort;
                part shoulder : Joint;
                part elbow : Joint;
                part wrist : Joint;
                part wheel : Wheel;
                
                connect cmdIn to shoulder.cmdIn;
                connect cmdIn to elbow.cmdIn;
                connect cmdIn to wrist.cmdIn;
                connect cmdIn to wheel.cmdIn;
                connect powerIn to shoulder.powerIn;
                connect powerIn to elbow.powerIn;
                connect powerIn to wrist.powerIn;
                connect powerIn to wheel.powerIn;
            }
            
            part def Joint {
                attribute currentAngle : ISQ::AngleValue;
                attribute targetAngle : ISQ::AngleValue;
                attribute appliedTorque : TorqueValue;
                attribute maxAngle : ISQ::AngleValue;
                attribute minAngle : ISQ::AngleValue;
                port cmdIn : JointCommandPort;
                port powerIn : PowerPort;
            }
            
            part def Wheel {
                attribute radius : LengthValue;
                attribute steeringAngle : ISQ::AngleValue;
                attribute angularVelocity : AngularVelocityValue;
                attribute maxSpeed : SpeedValue;
                attribute maxTorque : TorqueValue;
                port cmdIn : WheelCommandPort;
                port powerIn : PowerPort;
            }
            
            part def TerrainSensor {
                attribute scanRange : LengthValue;
                attribute resolution : LengthValue;
                port dataOut : TerrainDataPort;
                port powerIn : PowerPort;
                perform action scanTerrain;
            }
            
            part def NavigationSystem {
                attribute mapResolution : LengthValue;
                port dataIn : TerrainDataPort;
                port cmdOut : NavCommandPort;
                port powerIn : PowerPort;
                perform action planPath;
            }
            
            part def MobilityController {
                port navIn : NavCommandPort;
                port cmdOut : JointCommandPort;
                port powerIn : PowerPort;
                perform action generateCommands;
            }
            
            part def PowerSource {
                attribute capacity : EnergyValue;
                attribute maxPower : PowerValue;
                attribute currentOutput : PowerValue;
                port powerOut : PowerPort;
            }
            
            part def Payload {
                attribute mass : MassValue;
                attribute secured : Boolean;
                port powerIn : PowerPort;
            }
        }

        package ActionDefinitions {
            action def Navigate {
                in terrainData : TerrainData;
                out navCmd : NavigationCommand;
            }
            action def ControlMobility {
                in navCmd : NavigationCommand;
                out jointCmd : JointCommand;
            }
            action def MoveRover {
                in jointCmd : JointCommand;
            }
            action def ScanTerrain {
                out terrainData : TerrainData;
            }
            action def PlanPath {
                in terrainData : TerrainData;
                out navCmd : NavigationCommand;
            }
            action def GenerateCommands {
                in navCmd : NavigationCommand;
                out jointCmd : JointCommand;
            }
            action def ConfigureForRolling;
            action def MaintainWheelDrive;
            action def ConfigureForWalking;
            action def CoordinateLimbGait;
            action def ConfigureForClimbing;
            action def ExecuteClimbingSequence;
            action def LockJoints;
            action def StabilizePlatform;
        }

        package RequirementDefinitions {
            requirement def MobilityRequirement {
                subject rover : ATHLETE;
                requirement supportMobilityModes {
                    doc /* The rover shall support rolling, walking, climbing, and anchored mobility modes. */
                }
                requirement adaptToTerrain {
                    doc /* The rover shall adapt its mobility mode based on terrain data including surface roughness, slopes, and obstacle heights. */
                }
            }
            requirement def PayloadRequirement {
                subject payload : Payload;
                requirement securePayload {
                    doc /* The rover shall secure the payload during all mobility modes. */
                }
                requirement carryPayload {
                    doc /* The rover shall carry an optional payload with a mass up to 500 kg. */
                }
            }
            requirement def NavigationRequirement {
                subject navSystem : NavigationSystem;
                requirement autonomousNavigation {
                    doc /* The rover shall autonomously plan a path and select the optimal mobility mode based on terrain data and target destination. */
                }
            }
            requirement def PowerRequirement {
                subject powerSource : PowerSource;
                requirement providePower {
                    doc /* The rover shall be powered by a central power source capable of delivering sufficient power for all mobility modes and payload operations. */
                }
            }
            requirement def LimbRequirement {
                subject limb : Limb;
                requirement articulateLimbs {
                    doc /* Each limb shall have independently controllable shoulder, elbow, and wrist joints with a powered steerable wheel. */
                }
            }
            requirement def TerrainSensingRequirement {
                subject sensor : TerrainSensor;
                requirement senseTerrain {
                    doc /* The rover shall be equipped with terrain sensors to continuously scan the environment measuring surface roughness, slopes, and obstacle heights. */
                }
            }
        }
    }
}
