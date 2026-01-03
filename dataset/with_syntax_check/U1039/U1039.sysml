package DoosanRoboticsCollaborativeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def JointPosition {
        attribute joint1 : PlaneAngleValue;
        attribute joint2 : PlaneAngleValue;
        attribute joint3 : PlaneAngleValue;
        attribute joint4 : PlaneAngleValue;
        attribute joint5 : PlaneAngleValue;
        attribute joint6 : PlaneAngleValue;
    }
    
    attribute def CartesianPose {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
        attribute roll : PlaneAngleValue;
        attribute pitch : PlaneAngleValue;
        attribute yaw : PlaneAngleValue;
    }
    
    attribute def RobotState {
        attribute jointPositions : JointPosition;
        attribute jointVelocities : AngularVelocityValue[6];
        attribute jointTorques : TorqueValue[6];
        attribute endEffectorPose : CartesianPose;
        attribute temperature : ThermodynamicTemperatureValue;
    }
    
    attribute def SafetyZoneBoundary {
        attribute minX : LengthValue;
        attribute maxX : LengthValue;
        attribute minY : LengthValue;
        attribute maxY : LengthValue;
        attribute minZ : LengthValue;
        attribute maxZ : LengthValue;
    }
    
    attribute def MotionCommand;
    attribute def GripCommand;
    attribute def SafetyStop;
    attribute def CollisionDetected;
    attribute def TaskCompleted;
    
    item def Workpiece {
        attribute mass : MassValue;
        attribute dimensions : LengthValue[3];
        attribute location : CartesianPose;
        attribute graspable : Boolean;
    }
    
    port def PowerPort {
        in attribute voltage : ElectricPotentialValue;
        in attribute current : ElectricCurrentValue;
    }
    
    port def ControlPort {
        in attribute commandSignal : Real;
        out attribute feedbackSignal : Real;
    }
    
    port def DataPort {
        in attribute inputData : Real;
        out attribute outputData : Real;
    }
    
    port def MechanicalPort {
        out attribute force : ForceValue;
        out attribute torque : TorqueValue;
    }
    
    part def MainController {
        port controlOut : ControlPort;
        port dataIO : DataPort;
        port powerIn : PowerPort;
        
        attribute currentState : RobotState;
        attribute targetPose : CartesianPose;
        attribute safetyZone : SafetyZoneBoundary;
        attribute operationMode : String;
        
        perform action computeTrajectory {
            in startPose : CartesianPose;
            in goalPose : CartesianPose;
            in maxVelocity : SpeedValue;
            out waypoints : CartesianPose[*];
        }
        
        perform action validateSafety {
            in robotState : RobotState;
            in safetyBounds : SafetyZoneBoundary;
            out isSafe : Boolean;
        }
    }
    
    part def SixAxisArm {
        port controlIn : ControlPort;
        port powerIn : PowerPort;
        port flangeOut : MechanicalPort;
        
        attribute maxPayload : MassValue;
        attribute maxReach : LengthValue;
        attribute repeatability : LengthValue;
        attribute currentLoad : MassValue;
        
        part baseJoint : RevoluteJoint {
            attribute :>> maxTorque = 60.0[SI::N*SI::m];
            attribute :>> maxSpeed = 3.14159[SI::rad/SI::s];
        }
        
        part shoulderJoint : RevoluteJoint {
            attribute :>> maxTorque = 60.0[SI::N*SI::m];
            attribute :>> maxSpeed = 3.14159[SI::rad/SI::s];
        }
        
        part elbowJoint : RevoluteJoint {
            attribute :>> maxTorque = 40.0[SI::N*SI::m];
            attribute :>> maxSpeed = 3.92699[SI::rad/SI::s];
        }
        
        part wrist1Joint : RevoluteJoint {
            attribute :>> maxTorque = 30.0[SI::N*SI::m];
            attribute :>> maxSpeed = 3.92699[SI::rad/SI::s];
        }
        
        part wrist2Joint : RevoluteJoint {
            attribute :>> maxTorque = 30.0[SI::N*SI::m];
            attribute :>> maxSpeed = 3.92699[SI::rad/SI::s];
        }
        
        part wrist3Joint : RevoluteJoint {
            attribute :>> maxTorque = 30.0[SI::N*SI::m];
            attribute :>> maxSpeed = 3.92699[SI::rad/SI::s];
        }
    }
    
    part def RevoluteJoint {
        attribute currentAngle : PlaneAngleValue;
        attribute currentVelocity : AngularVelocityValue;
        attribute currentTorque : TorqueValue;
        attribute maxTorque : TorqueValue;
        attribute maxSpeed : AngularVelocityValue;
        
        part actuator : ServoMotor;
        part encoder : PositionEncoder;
        part torqueSensor : TorqueSensor;
    }
    
    part def ServoMotor {
        attribute ratedPower : PowerValue;
        attribute peakTorque : TorqueValue;
        attribute continuousTorque : TorqueValue;
        attribute maxRotationalSpeed : AngularVelocityValue;
    }
    
    part def PositionEncoder {
        attribute resolution : PlaneAngleValue;
        attribute accuracy : PlaneAngleValue;
        out attribute measuredAngle : PlaneAngleValue;
    }
    
    part def TorqueSensor {
        attribute range : TorqueValue;
        attribute sensitivity : Real;
        out attribute measuredTorque : TorqueValue;
    }
    
    part def AdaptiveGripper {
        port mechanicalIn : MechanicalPort;
        port controlIn : ControlPort;
        port powerIn : PowerPort;
        
        attribute maxGripForce : ForceValue;
        attribute maxOpeningWidth : LengthValue;
        attribute currentGripForce : ForceValue;
        attribute currentWidth : LengthValue;
        
        perform action grasp {
            in targetForce : ForceValue;
            in targetWidth : LengthValue;
            out graspSuccess : Boolean;
        }
        
        perform action release {
            out releaseComplete : Boolean;
        }
        
        part fingerActuator1 : LinearActuator;
        part fingerActuator2 : LinearActuator;
        part forceSensor : ForceSensor;
    }
    
    part def LinearActuator {
        attribute maxForce : ForceValue;
        attribute maxStroke : LengthValue;
        attribute currentPosition : LengthValue;
    }
    
    part def ForceSensor {
        attribute maxForce : ForceValue;
        attribute resolution : ForceValue;
        out attribute measuredForce : ForceValue;
    }
    
    part def VisionSystem {
        port dataOut : DataPort;
        port powerIn : PowerPort;
        
        attribute resolution : Real[2];
        attribute frameRate : FrequencyValue;
        attribute fieldOfView : PlaneAngleValue;
        
        perform action detectObjects {
            out detectedWorkpieces : Workpiece[*];
        }
        
        perform action locateWorkpiece {
            in targetWorkpiece : Workpiece;
            out workpiecePose : CartesianPose;
            out confidence : Real;
        }
        
        perform action verifyPlacement {
            in expectedPose : CartesianPose;
            in tolerance : LengthValue;
            out verified : Boolean;
        }
        
        part camera : DepthCamera;
        part processor : ImageProcessor;
    }
    
    part def DepthCamera {
        attribute resolution : Real[2];
        attribute depthRange : LengthValue[2];
        attribute frameRate : FrequencyValue;
    }
    
    part def ImageProcessor {
        attribute processingRate : FrequencyValue;
        attribute algorithmType : String;
    }
    
    part def SafetyController {
        port controlIn : ControlPort;
        port emergencyOut : ControlPort;
        port powerIn : PowerPort;
        
        attribute emergencyStopActive : Boolean;
        attribute collisionThreshold : ForceValue;
        attribute speedLimit : SpeedValue;
        attribute forceLimit : ForceValue;
        
        perform action monitorCollision {
            in jointTorques : TorqueValue[6];
            in torqueThreshold : TorqueValue;
            out collisionDetected : Boolean;
        }
        
        perform action enforceSpeedLimit {
            in currentSpeed : SpeedValue;
            in maxSpeed : SpeedValue;
            out speedViolation : Boolean;
        }
        
        perform action triggerEmergencyStop {
            out stopSignal : SafetyStop;
        }
        
        part emergencyStopButton : EmergencyButton;
        part proximityScanner : LaserScanner;
    }
    
    part def EmergencyButton {
        attribute pressed : Boolean;
        out attribute stopSignal : Boolean;
    }
    
    part def LaserScanner {
        attribute scanRange : LengthValue;
        attribute scanAngle : PlaneAngleValue;
        attribute detectionThreshold : LengthValue;
        out attribute obstacleDetected : Boolean;
    }
    
    part def PowerSupply {
        port powerOut : PowerPort;
        
        attribute inputVoltage : ElectricPotentialValue;
        attribute outputVoltage : ElectricPotentialValue;
        attribute maxCurrent : ElectricCurrentValue;
        attribute efficiency : Real;
    }
    
    action def PickAndPlaceOperation {
        in pickLocation : CartesianPose;
        in placeLocation : CartesianPose;
        in gripForce : ForceValue;
        in approachSpeed : SpeedValue;
        out operationSuccess : Boolean;
    }
    
    action def QualityInspection {
        in workpiece : Workpiece;
        in inspectionCriteria : Real;
        out passedInspection : Boolean;
    }
    
    action def AssemblyTask {
        in component1 : Workpiece;
        in component2 : Workpiece;
        in assemblyForce : ForceValue;
        out assemblyComplete : Boolean;
    }
    
    part def DoosanCollaborativeRobot {
        part controller : MainController;
        part arm : SixAxisArm;
        part gripper : AdaptiveGripper;
        part vision : VisionSystem;
        part safety : SafetyController;
        part power : PowerSupply;
    }
    
    part collaborativeRobotSystem : DoosanCollaborativeRobot {
        doc /* 
            Doosan collaborative robot system designed for safe, flexible automation
            in manufacturing environments. The system performs precision pick-and-place,
            assembly, and quality inspection tasks through integrated vision guidance,
            force control, and comprehensive safety monitoring.
        */
        
        part controller : MainController {
            attribute :>> safetyZone {
                attribute :>> minX = -1.5[SI::m];
                attribute :>> maxX = 1.5[SI::m];
                attribute :>> minY = -1.5[SI::m];
                attribute :>> maxY = 1.5[SI::m];
                attribute :>> minZ = 0.0[SI::m];
                attribute :>> maxZ = 2.0[SI::m];
            }
            attribute :>> operationMode = "collaborative";
        }
        
        part arm : SixAxisArm {
            attribute :>> maxPayload = 15.0[SI::kg];
            attribute :>> maxReach = 1.7[SI::m];
            attribute :>> repeatability = 0.00005[SI::m];
        }
        
        part gripper : AdaptiveGripper {
            attribute :>> maxGripForce = 150.0[SI::N];
            attribute :>> maxOpeningWidth = 0.2[SI::m];
        }
        
        part vision : VisionSystem {
            attribute :>> resolution = (1920.0, 1080.0);
            attribute :>> frameRate = 60.0[SI::Hz];
            attribute :>> fieldOfView = 1.309[SI::rad];
        }
        
        part safety : SafetyController {
            attribute :>> emergencyStopActive = false;
            attribute :>> collisionThreshold = 100.0[SI::N];
            attribute :>> speedLimit = 1.0[SI::m/SI::s];
            attribute :>> forceLimit = 150.0[SI::N];
        }
        
        part power : PowerSupply {
            attribute :>> inputVoltage = 220.0[SI::V];
            attribute :>> outputVoltage = 48.0[SI::V];
            attribute :>> maxCurrent = 20.0[SI::A];
            attribute :>> efficiency = 0.92;
        }
        
        connection powerToController : PowerPort connect 
            power.powerOut to controller.powerIn;
        
        connection powerToArm : PowerPort connect 
            power.powerOut to arm.powerIn;
        
        connection powerToGripper : PowerPort connect 
            power.powerOut to gripper.powerIn;
        
        connection powerToVision : PowerPort connect 
            power.powerOut to vision.powerIn;
        
        connection powerToSafety : PowerPort connect 
            power.powerOut to safety.powerIn;
        
        connection controlToArm : ControlPort connect 
            controller.controlOut to arm.controlIn;
        
        connection controlToGripper : ControlPort connect 
            controller.controlOut to gripper.controlIn;
        
        connection visionToController : DataPort connect 
            vision.dataOut to controller.dataIO;
        
        connection safetyToController : ControlPort connect 
            safety.emergencyOut to controller.controlOut;
        
        connection armToGripper : MechanicalPort connect 
            arm.flangeOut to gripper.mechanicalIn;
        
        perform action automatedManufacturing {
            doc /* 
                Primary function: Execute collaborative manufacturing operations including
                precision material handling, component assembly, and quality verification
                through vision-guided manipulation with integrated safety monitoring and
                adaptive force control for safe human-robot collaboration.
            */
            
            first start;
            then merge operationLoop;
            
            then action systemInitialization {
                action calibrateRobot {
                    action zeroJoints {
                        out jointsZeroed : Boolean;
                    }
                    then action verifyCalibration {
                        out calibrationValid : Boolean;
                    }
                    out robotCalibrated : Boolean;
                }
                
                then action initializeVision {
                    action loadVisionModel {
                        out modelLoaded : Boolean;
                    }
                    then action calibrateCamera {
                        out cameraCalibrated : Boolean;
                    }
                    out visionReady : Boolean;
                }
                
                then action enableSafetySystems {
                    action testEmergencyStop {
                        out estopFunctional : Boolean;
                    }
                    then action activateCollisionDetection {
                        out collisionMonitorActive : Boolean;
                    }
                    out safetyEnabled : Boolean;
                }
                
                then action moveToHome {
                    in homePosition : JointPosition;
                    out atHome : Boolean;
                }
            }
            
            then operationLoop;
            
            then action productionCycle {
                action scanWorkspace : vision.detectObjects {
                    out detectedWorkpieces;
                }
                
                flow scanWorkspace.detectedWorkpieces to selectWorkpiece.availableWorkpieces;
                
                action selectWorkpiece {
                    in availableWorkpieces : Workpiece[*];
                    out selectedWorkpiece : Workpiece;
                    out targetPose : CartesianPose;
                }
                
                flow selectWorkpiece.targetPose to planApproach.goalPose;
                
                action planApproach : controller.computeTrajectory {
                    in startPose : CartesianPose;
                    in goalPose : CartesianPose;
                    in maxVelocity = 0.5[SI::m/SI::s];
                    out waypoints;
                }
                
                flow planApproach.waypoints to executeApproach.trajectory;
                
                action executeApproach {
                    in trajectory : CartesianPose[*];
                    
                    for waypoint in trajectory {
                        action moveToWaypoint {
                            in targetPose = waypoint;
                            
                            action checkSafety : safety.monitorCollision {
                                in jointTorques = (
                                    arm.baseJoint.currentTorque,
                                    arm.shoulderJoint.currentTorque,
                                    arm.elbowJoint.currentTorque,
                                    arm.wrist1Joint.currentTorque,
                                    arm.wrist2Joint.currentTorque,
                                    arm.wrist3Joint.currentTorque
                                );
                                in torqueThreshold = safety.collisionThreshold;
                                out collisionDetected;
                            }
                            
                            then decide;
                                if checkSafety.collisionDetected then handleCollision;
                                if not checkSafety.collisionDetected then continueMotion;
                            
                            action continueMotion {
                                action updateArmPosition;
                            }
                            
                            action handleCollision : safety.triggerEmergencyStop {
                                out stopSignal;
                            }
                        }
                    }
                    
                    out approachComplete : Boolean;
                }
                
                flow executeApproach.approachComplete to graspWorkpiece.ready;
                
                action graspWorkpiece : gripper.grasp {
                    in ready : Boolean;
                    in targetForce = 80.0[SI::N];
                    in targetWidth = 0.05[SI::m];
                    out graspSuccess;
                }
                
                then decide;
                    if graspWorkpiece.graspSuccess then transportWorkpiece;
                    if not graspWorkpiece.graspSuccess then retryGrasp;
                
                action retryGrasp {
                    action adjustGripperPosition;
                    then action attemptGraspAgain : gripper.grasp {
                        in targetForce = 100.0[SI::N];
                        in targetWidth = 0.06[SI::m];
                        out graspSuccess;
                    }
                }
                
                then transportWorkpiece;
                
                action transportWorkpiece {
                    in holding : Boolean;
                    
                    action planTransport : controller.computeTrajectory {
                        in startPose;
                        in goalPose;
                        in maxVelocity = 0.3[SI::m/SI::s];
                        out waypoints;
                    }
                    
                    flow planTransport.waypoints to executeTransport.path;
                    
                    action executeTransport {
                        in path : CartesianPose[*];
                        
                        action monitorLoad {
                            in currentLoad = arm.currentLoad;
                            in maxLoad = arm.maxPayload;
                            out loadSafe : Boolean;
                        }
                        
                        action traversePath {
                            in trajectory = path;
                        }
                    }
                    
                    out transportComplete : Boolean;
                }
                
                flow transportWorkpiece.transportComplete to inspectWorkpiece.ready;
                
                action inspectWorkpiece : QualityInspection {
                    in ready : Boolean;
                    in workpiece;
                    in inspectionCriteria = 0.95;
                    out passedInspection;
                }
                
                then decide;
                    if inspectWorkpiece.passedInspection then placeWorkpiece;
                    if not inspectWorkpiece.passedInspection then rejectWorkpiece;
                
                action rejectWorkpiece {
                    action moveToRejectBin {
                        in rejectLocation : CartesianPose;
                    }
                    then action releaseRejected : gripper.release {
                        out releaseComplete;
                    }
                }
                
                then operationLoop;
                
                action placeWorkpiece {
                    action alignForPlacement {
                        in targetPose : CartesianPose;
                        in alignmentTolerance = 0.0001[SI::m];
                        out aligned : Boolean;
                    }
                    
                    then action lowerToPlace {
                        in placeSpeed = 0.05[SI::m/SI::s];
                        in contactForce = 20.0[SI::N];
                    }
                    
                    then action releaseGripper : gripper.release {
                        out releaseComplete;
                    }
                    
                    out placementComplete : Boolean;
                }
                
                flow placeWorkpiece.placementComplete to verifyPlacement.trigger;
                
                action verifyPlacement : vision.verifyPlacement {
                    in trigger : Boolean;
                    in expectedPose;
                    in tolerance = 0.0005[SI::m];
                    out verified;
                }
                
                then decide;
                    if verifyPlacement.verified then returnToHome;
                    if not verifyPlacement.verified then correctPlacement;
                
                action correctPlacement {
                    action detectMisalignment {
                        out offset : CartesianPose;
                    }
                    then action adjustPlacement {
                        in correction = detectMisalignment.offset;
                    }
                }
                
                then returnToHome;
                
                action returnToHome {
                    action planReturnPath : controller.computeTrajectory {
                        in startPose;
                        in goalPose;
                        in maxVelocity = 0.8[SI::m/SI::s];
                        out waypoints;
                    }
                    
                    action executeReturn {
                        in path = planReturnPath.waypoints;
                    }
                    
                    out homeReached : Boolean;
                }
                
                then operationLoop;
            }
            
            accept taskComplete : TaskCompleted;
            then done;
        }
    }
    
    requirement def SafetyRequirement {
        doc /* 
            The collaborative robot system shall detect potential collisions through
            torque monitoring and halt motion within 100 milliseconds to ensure
            operator safety during human-robot collaboration.
        */
        
        require constraint collisionDetectionResponse {
            attribute responseTime : DurationValue;
            responseTime <= 0.1[SI::s]
        }
        
        require constraint maxCollaborativeSpeed {
            attribute endEffectorSpeed : SpeedValue;
            endEffectorSpeed <= 1.0[SI::m/SI::s]
        }
        
        require constraint maxContactForce {
            attribute contactForce : ForceValue;
            contactForce <= 150.0[SI::N]
        }
    }
    
    requirement def PerformanceRequirement {
        doc /* 
            The robot system shall achieve positioning repeatability within 0.05mm
            and complete standard pick-and-place cycles in under 4 seconds while
            maintaining payload capacity of 15kg across full workspace.
        */
        
        require constraint positioningRepeatability {
            attribute repeatability : LengthValue;
            repeatability <= 0.00005[SI::m]
        }
        
        require constraint cycleTimeTarget {
            attribute cycleTime : DurationValue;
            cycleTime <= 4.0[SI::s]
        }
        
        require constraint payloadCapacity {
            attribute payload : MassValue;
            payload >= 15.0[SI::kg]
        }
    }
    
    requirement def VisionRequirement {
        doc /* 
            The vision system shall detect and localize workpieces with position
            accuracy within 0.2mm and orientation accuracy within 0.5 degrees
            at a minimum frame rate of 30Hz.
        */
        
        require constraint positionAccuracy {
            attribute accuracy : LengthValue;
            accuracy <= 0.0002[SI::m]
        }
        
        require constraint orientationAccuracy {
            attribute accuracy : PlaneAngleValue;
            accuracy <= 0.00873[SI::rad]
        }
        
        require constraint visionFrameRate {
            attribute frameRate : FrequencyValue;
            frameRate >= 30.0[SI::Hz]
        }
    }
    
    requirement systemRequirements {
        subject robotSystem : DoosanCollaborativeRobot;
        
        require safetyRequirement : SafetyRequirement;
        require performanceRequirement : PerformanceRequirement;
        require visionRequirement : VisionRequirement;
        
        assume constraint operatingEnvironment {
            doc /* 
                Robot operates in controlled manufacturing environment with
                regulated temperature, humidity, and minimal vibration.
            */
            attribute ambientTemperature : ThermodynamicTemperatureValue;
            attribute relativeHumidity : Real;
            attribute vibrationLevel : Real;
            
            ambientTemperature >= 278.15[SI::K] and ambientTemperature <= 318.15[SI::K] and
            relativeHumidity >= 20.0 and relativeHumidity <= 80.0 and
            vibrationLevel <= 0.5
        }
        
        assume constraint powerSupply {
            doc /* Stable electrical power supply within specified voltage range. */
            attribute voltage : ElectricPotentialValue;
            attribute frequency : FrequencyValue;
            
            voltage >= 200.0[SI::V] and voltage <= 240.0[SI::V] and
            frequency >= 47.0[SI::Hz] and frequency <= 63.0[SI::Hz]
        }
    }
}
