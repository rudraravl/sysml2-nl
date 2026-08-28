package RoboticWorkCell {
    private import ISQ::*;
    private import ScalarValues::*;
    
    package Definitions {
        public import ItemDefinitions::*;
        public import AttributeDefinitions::*;
        public import PortDefinitions::*;
        public import ActionDefinitions::*;
        public import PartDefinitions::*;
        public import RequirementDefinitions::*;
        
        package ItemDefinitions {
            private import ISQ::*;
            
            item def Workpiece {
                attribute mass :> ISQ::mass;
            }
        }
        
        package AttributeDefinitions {
            private import ScalarValues::*;
            
            attribute def HazardSignal;
            attribute def EmergencyStopSignal;
            attribute def LightCurtainSignal;
            attribute def CollisionSignal;
            attribute def PickFailedSignal;
            attribute def PickReached;
            attribute def GraspComplete;
            attribute def PlaceReached;
            attribute def PlaceComplete;
            attribute def QualityFailSignal;
            attribute def QualityPassSignal;
            enum def Mode {
                AUTOMATIC;
                MANUAL;
                MAINTENANCE;
            }
            attribute def ModeCommand {
                attribute mode : Mode;
            }
            attribute def StartCycleSignal;
            attribute def ResetSignal;
        }
        
        package PortDefinitions {
            private import ItemDefinitions::*;
            private import AttributeDefinitions::*;
            private import ScalarValues::*;
            
            port def PowerPort {
                in voltage : Real;
                in current : Real;
            }
            port def ControlPort {
                in command : ModeCommand;
                out status : String;
            }
            port def SensorPort {
                out position : Real;
                out force : Real;
            }
            port def WorkpiecePort {
                in item workpiece : Workpiece;
                out item workpiece : Workpiece;
            }
            port def SafetyPort {
                out hazard : HazardSignal;
            }
        }
        
        package ActionDefinitions {
            action def MoveToPickup;
            action def GraspWorkpiece;
            action def MoveToDropoff;
            action def PlaceWorkpiece;
            action def InspectQuality;
            action def HandlePickFailure;
            action def HandleQualityFailure;
            action def HaltMotion;
        }
        
        package PartDefinitions {
            private import ItemDefinitions::*;
            private import AttributeDefinitions::*;
            private import PortDefinitions::*;
            private import ActionDefinitions::*;
            private import ISQ::*;
            private import ScalarValues::*;
            
            part def Motor;
            part def Joint {
                part motor : Motor;
            }
            part def Gripper;
            part def PositionSensor;
            part def ForceSensor;
            part def TeachPendant {
                port controlPort : ControlPort;
            }
            
            part def RobotArm {
                attribute reach :> ISQ::length = 2 [m];
                attribute maxPayload :> ISQ::mass = 25 [kg];
                part joints : Joint [6];
                part gripper : Gripper;
                part positionSensor : PositionSensor;
                part forceSensor : ForceSensor;
                
                port workpiecePort : WorkpiecePort;
                port sensorPort : SensorPort;
                port controlPort : ControlPort;
                port powerPort : PowerPort;
                
                exhibit state operationStates {
                    entry; then idle;
                    state idle;
                    state movingToPickup { do action MoveToPickup; }
                    state grasping { do action GraspWorkpiece; }
                    state movingToDropoff { do action MoveToDropoff; }
                    state placing { do action PlaceWorkpiece; }
                    state inspecting { do action InspectQuality; }
                    state handlingPickFailure { do action HandlePickFailure; }
                    state handlingQualityFailure { do action HandleQualityFailure; }

                    transition first idle accept s : StartCycleSignal then movingToPickup;
                    transition first movingToPickup accept r : PickReached then grasping;
                    transition first grasping accept c : GraspComplete then movingToDropoff;
                    transition first grasping accept f : PickFailedSignal then handlingPickFailure;
                    transition first movingToDropoff accept r : PlaceReached then placing;
                    transition first placing accept c : PlaceComplete then inspecting;
                    transition first inspecting accept f : QualityFailSignal then handlingQualityFailure;
                    transition first inspecting accept p : QualityPassSignal then idle;
                    transition first handlingPickFailure accept r : ResetSignal then idle;
                    transition first handlingQualityFailure accept r : ResetSignal then idle;
                }
            }
            
            part def Conveyor {
                port workpiecePort : WorkpiecePort;
                port powerPort : PowerPort;
                port controlPort : ControlPort;
            }
            
            part def SafetyFence;
            part def EmergencyStop;
            part def LightCurtain;
            part def CollisionDetector;
            
            part def SafetySystem {
                attribute responseTime :> ISQ::time = 0.05 [s];
                part emergencyStop : EmergencyStop;
                part lightCurtain : LightCurtain;
                part collisionDetector : CollisionDetector;
                
                port safetyPort : SafetyPort;
                
                exhibit state safetyStates {
                    entry; then safe;
                    state safe;
                    state emergency { do action HaltMotion; }
                    
                    transition first safe accept e : EmergencyStopSignal do send new HazardSignal() to safetyPort then emergency;
                    transition first safe accept l : LightCurtainSignal do send new HazardSignal() to safetyPort then emergency;
                    transition first safe accept c : CollisionSignal do send new HazardSignal() to safetyPort then emergency;
                    transition first emergency accept r : ResetSignal then safe;
                }
            }
            
            part def RobotController {
                port controlPort : ControlPort;
                port sensorPort : SensorPort;
                port powerPort : PowerPort;
                port safetyPort : SafetyPort;
                exhibit state controllerStates {
                    entry; then idle;
                    state idle;
                    state planning;
                    state executing;
                }
            }
            
            part def PLC {
                port controlPort : ControlPort;
                port powerPort : PowerPort;
                port safetyPort : SafetyPort;
            }
            
            part def PowerSupply {
                attribute outputVoltage :> ISQ::electricPotential = 480 [V];
                port powerPort : PowerPort;
            }
            
            part def WorkCell {
                part robotArm : RobotArm;
                part inputConveyor : Conveyor;
                part outputConveyor : Conveyor;
                part safetyFence : SafetyFence;
                part safetySystem : SafetySystem;
                part robotController : RobotController;
                part plc : PLC;
                part powerSupply : PowerSupply;
                part teachPendant : TeachPendant;
                
                connect powerSupply.powerPort to robotArm.powerPort;
                connect powerSupply.powerPort to robotController.powerPort;
                connect powerSupply.powerPort to plc.powerPort;
                connect powerSupply.powerPort to inputConveyor.powerPort;
                connect powerSupply.powerPort to outputConveyor.powerPort;
                
                connect plc.controlPort to robotController.controlPort;
                connect robotController.controlPort to robotArm.controlPort;
                connect plc.controlPort to inputConveyor.controlPort;
                connect plc.controlPort to outputConveyor.controlPort;
                connect teachPendant.controlPort to robotController.controlPort;
                
                connect robotArm.sensorPort to robotController.sensorPort;
                connect safetySystem.safetyPort to plc.safetyPort;
                connect safetySystem.safetyPort to robotController.safetyPort;
                
                connect inputConveyor.workpiecePort to robotArm.workpiecePort;
                connect robotArm.workpiecePort to outputConveyor.workpiecePort;
                
                exhibit state cellStates {
                    entry; then automatic;
                    state automatic;
                    state manual;
                    state maintenance;
                    state emergency {
                        do action HaltMotion;
                    }
                    
                    transition first automatic accept h : HazardSignal via safetySystem.safetyPort then emergency;
                    transition first manual accept h : HazardSignal via safetySystem.safetyPort then emergency;
                    transition first maintenance accept h : HazardSignal via safetySystem.safetyPort then emergency;
                    transition first automatic accept c : ModeCommand if c.mode == Mode::MANUAL then manual;
                    transition first manual accept c : ModeCommand if c.mode == Mode::AUTOMATIC then automatic;
                    transition first automatic accept c : ModeCommand if c.mode == Mode::MAINTENANCE then maintenance;
                    transition first maintenance accept c : ModeCommand if c.mode == Mode::AUTOMATIC then automatic;
                    transition first emergency accept r : ResetSignal then automatic;
                }
            }
        }
        
        package RequirementDefinitions {
            private import PartDefinitions::*;
            private import ISQ::*;
            
            requirement def ReachRequirement {
                attribute requiredReach :> ISQ::length = 2 [m];
                subject robotArm : RobotArm;
                constraint { robotArm.reach >= requiredReach }
            }
            requirement def PayloadRequirement {
                attribute requiredPayload :> ISQ::mass = 25 [kg];
                subject robotArm : RobotArm;
                constraint { robotArm.maxPayload >= requiredPayload }
            }
            requirement def SafetyResponseRequirement {
                attribute maxResponseTime :> ISQ::time = 0.1 [s];
                subject safetySystem : SafetySystem;
                constraint { safetySystem.responseTime <= maxResponseTime }
            }
        }
    }
    
    package Usages {
        private import Definitions::*;
        
        part workCell : WorkCell;
        
        requirement reachReq : ReachRequirement;
        requirement payloadReq : PayloadRequirement;
        requirement safetyReq : SafetyResponseRequirement;
        
        satisfy reachReq by workCell.robotArm;
        satisfy payloadReq by workCell.robotArm;
        satisfy safetyReq by workCell.safetySystem;
    }
}
