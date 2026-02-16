package 'HD Hyundai Robotics System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def Position {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
    }
    
    attribute def Orientation {
        attribute roll : ISQ::PlaneAngleValue;
        attribute pitch : ISQ::PlaneAngleValue;
        attribute yaw : ISQ::PlaneAngleValue;
    }
    
    attribute def Pose {
        attribute position : Position;
        attribute orientation : Orientation;
    }
    
    attribute def JointConfiguration {
        attribute joint1 : ISQ::PlaneAngleValue;
        attribute joint2 : ISQ::PlaneAngleValue;
        attribute joint3 : ISQ::PlaneAngleValue;
        attribute joint4 : ISQ::PlaneAngleValue;
        attribute joint5 : ISQ::PlaneAngleValue;
        attribute joint6 : ISQ::PlaneAngleValue;
    }
    
    attribute def GripperCommand {
        attribute openDistance : LengthValue;
        attribute force : ForceValue;
    }
    
    item def Workpiece {
        attribute mass : MassValue;
        attribute currentPose : Pose;
    }
    
    item def MotionTrajectory {
        attribute waypoints : Pose[*] ordered;
        attribute velocity : SpeedValue;
        attribute acceleration : ISQ::AccelerationValue;
    }
    
    port def ControlPort {
        in targetPose : Pose;
        in targetJoints : JointConfiguration;
        out currentPose : Pose;
        out currentJoints : JointConfiguration;
    }
    
    port def PowerPort {
        in voltage : ISQ::ElectricPotentialValue;
        in current : ISQ::ElectricCurrentValue;
        out powerDraw : ISQ::PowerValue;
    }
    
    port def SafetyPort {
        in emergencyStop : Boolean;
        in collisionDetected : Boolean;
        out systemSafe : Boolean;
    }
    
    port def GripperControlPort {
        in gripperCmd : GripperCommand;
        out gripperState : Boolean;
        out graspForce : ForceValue;
    }
    
    port def VisionPort {
        out detectedPose : Pose;
        out objectDetected : Boolean;
        out objectType : String;
    }
    
    part def RobotController {
        port controlInterface : ControlPort;
        port safetyInterface : SafetyPort;
        attribute operatingMode : String;
        attribute programLoaded : Boolean;
    }
    
    part def ManipulatorArm {
        port controlInput : ControlPort;
        port powerInput : PowerPort;
        attribute reach : LengthValue;
        attribute maxPayload : MassValue;
        attribute repeatability : LengthValue;
        attribute jointConfig : JointConfiguration;
    }
    
    part def EndEffector {
        port gripperControl : GripperControlPort;
        attribute maxGripForce : ForceValue;
        attribute maxOpening : LengthValue;
        attribute currentOpening : LengthValue;
    }
    
    part def VisionSensor {
        port visionOutput : VisionPort;
        port powerInput : PowerPort;
        attribute resolution : Integer[2];
        attribute frameRate : ISQ::FrequencyValue;
    }
    
    part def SafetyController {
        port safetyMonitor : SafetyPort;
        attribute safetyZoneRadius : LengthValue;
        attribute maxSpeed : SpeedValue;
    }
    
    part def PowerDistribution {
        port mainPower : PowerPort;
        port armPower : PowerPort;
        port sensorPower : PowerPort;
        attribute inputVoltage : ISQ::ElectricPotentialValue;
        attribute maxCurrent : ISQ::ElectricCurrentValue;
    }
    
    action def DetectWorkpiece {
        in scanArea : Position;
        out workpiecePose : Pose;
        out detected : Boolean;
        out workpieceType : String;
    }
    
    action def PlanMotion {
        in startPose : Pose;
        in targetPose : Pose;
        in maxVelocity : SpeedValue;
        out trajectory : MotionTrajectory;
        out planSuccess : Boolean;
    }
    
    action def ExecuteMotion {
        in trajectory : MotionTrajectory;
        out finalPose : Pose;
        out motionComplete : Boolean;
    }
    
    action def ActivateGripper {
        in command : GripperCommand;
        out graspAchieved : Boolean;
        out actualForce : ForceValue;
    }
    
    action def ReleaseGripper {
        out releaseComplete : Boolean;
    }
    
    action def VerifySafety {
        in currentVelocity : SpeedValue;
        in currentPosition : Position;
        out safeToOperate : Boolean;
    }
    
    action def PerformMaterialHandling {
        in pickPose : Pose;
        in placePose : Pose;
        in workpieceType : String;
        out operationComplete : Boolean;
        
        first start;
        then merge safetyCheck;
        
        action checkSafety : VerifySafety {
            in currentVelocity;
            in currentPosition;
            out safeToOperate;
        }
        
        then decide;
            if checkSafety.safeToOperate then detectWorkpiece;
            if not checkSafety.safeToOperate then abort;
        
        action detectWorkpiece : DetectWorkpiece {
            in scanArea;
            out workpiecePose;
            out detected;
            out workpieceType;
        }
        
        then decide;
            if detectWorkpiece.detected then planPickMotion;
            if not detectWorkpiece.detected then safetyCheck;
        
        action planPickMotion : PlanMotion {
            in startPose;
            in targetPose = detectWorkpiece.workpiecePose;
            in maxVelocity;
            out trajectory;
            out planSuccess;
        }
        
        then action moveToPickPosition : ExecuteMotion {
            in trajectory = planPickMotion.trajectory;
            out finalPose;
            out motionComplete;
        }
        
        then action graspWorkpiece : ActivateGripper {
            in command;
            out graspAchieved;
            out actualForce;
        }
        
        then decide;
            if graspWorkpiece.graspAchieved then planPlaceMotion;
            if not graspWorkpiece.graspAchieved then retryGrasp;
        
        action planPlaceMotion : PlanMotion {
            in startPose = moveToPickPosition.finalPose;
            in targetPose = placePose;
            in maxVelocity;
            out trajectory;
            out planSuccess;
        }
        
        then action moveToPlacePosition : ExecuteMotion {
            in trajectory = planPlaceMotion.trajectory;
            out finalPose;
            out motionComplete;
        }
        
        then action releaseWorkpiece : ReleaseGripper {
            out releaseComplete;
        }
        
        then action returnToHome : ExecuteMotion {
            in trajectory;
            out finalPose;
            out motionComplete;
        }
        
        then assign operationComplete := true;
        then done;
        
        action retryGrasp : ExecuteMotion {
            in trajectory;
            out finalPose;
            out motionComplete;
        }
        then safetyCheck;
        
        action abort;
        then done;
    }
    
    state def RobotOperationStates {
        entry; then idle;
        
        state idle;
        transition idle_to_init
            first idle
            accept at initializing
            then initializing;
        
        state initializing;
        transition init_to_ready
            first initializing
            accept at ready
            then ready;
        
        state ready;
        transition ready_to_operating
            first ready
            accept at operating
            then operating;
        
        state operating;
        transition operating_to_ready
            first operating
            accept at ready
            then ready;
        
        transition operating_to_paused
            first operating
            accept at paused
            then paused;
        
        state paused;
        transition paused_to_operating
            first paused
            accept at operating
            then operating;
        
        transition operating_to_error
            first operating
            accept at error
            then error;
        
        state error;
        transition error_to_idle
            first error
            accept at idle
            then idle;
        
        transition operating_to_estop
            first operating
            accept at emergencyStop
            then emergencyStop;
        
        state emergencyStop;
        transition estop_to_idle
            first emergencyStop
            accept at idle
            then idle;
    }
    
    part def IndustrialRobotCell {
        doc /* HD Hyundai industrial robot cell for automated material handling and assembly. */
    }
    
    part robotCell : IndustrialRobotCell {
        part controller : RobotController {
            port controlInterface;
            port safetyInterface;
            attribute operatingMode = "Automatic";
            attribute programLoaded = true;
        }
        
        part manipulator : ManipulatorArm {
            port controlInput;
            port powerInput;
            attribute reach = 1700.0 [mm];
            attribute maxPayload = 25.0 [kg];
            attribute repeatability = 0.03 [mm];
        }
        
        part gripper : EndEffector {
            port gripperControl;
            attribute maxGripForce = 600.0 [N];
            attribute maxOpening = 180.0 [mm];
            attribute currentOpening = 0.0 [mm];
        }
        
        part visionSystem : VisionSensor {
            port visionOutput;
            port powerInput;
            attribute resolution = (2048, 1536);
            attribute frameRate = 30.0 [Hz];
        }
        
        part safetySystem : SafetyController {
            port safetyMonitor;
            attribute safetyZoneRadius = 1500.0 [mm];
            attribute maxSpeed = 2.0 [m/s];
        }
        
        part powerSystem : PowerDistribution {
            port mainPower;
            port armPower;
            port sensorPower;
            attribute inputVoltage = 400.0 [V];
            attribute maxCurrent = 32.0 [A];
        }
        
        connection controlConnection : ControlPort 
            connect controller.controlInterface to manipulator.controlInput;
        
        connection safetyConnection : SafetyPort 
            connect controller.safetyInterface to safetySystem.safetyMonitor;
        
        connection gripperConnection : GripperControlPort 
            connect controller to gripper.gripperControl;
        
        connection armPowerConnection : PowerPort 
            connect powerSystem.armPower to manipulator.powerInput;
        
        connection sensorPowerConnection : PowerPort 
            connect powerSystem.sensorPower to visionSystem.powerInput;
        
        exhibit state operationStateMachine : RobotOperationStates;
        
        perform action materialHandlingCycle[*] ordered 
            references handlingOperation;
    }
    
    action handlingOperation : PerformMaterialHandling {
        in pickPose : Pose {
            attribute position : Position {
                attribute x = 600.0 [mm];
                attribute y = 400.0 [mm];
                attribute z = 150.0 [mm];
            }
            attribute orientation : Orientation {
                attribute roll = 0.0 [deg];
                attribute pitch = 90.0 [deg];
                attribute yaw = 0.0 [deg];
            }
        }
        in placePose : Pose {
            attribute position : Position {
                attribute x = 900.0 [mm];
                attribute y = -300.0 [mm];
                attribute z = 200.0 [mm];
            }
            attribute orientation : Orientation {
                attribute roll = 0.0 [deg];
                attribute pitch = 90.0 [deg];
                attribute yaw = 45.0 [deg];
            }
        }
        in workpieceType = "Assembly_Component";
        out operationComplete : Boolean;
    }
    
    requirement def PerformanceRequirement {
        doc /* Performance requirements for the robotic system. */
        subject system : IndustrialRobotCell;
    }
    
    requirement def SafetyRequirement {
        doc /* Safety requirements for the robotic system. */
        subject system : IndustrialRobotCell;
    }
    
    requirement def ReliabilityRequirement {
        doc /* Reliability requirements for the robotic system. */
        subject system : IndustrialRobotCell;
    }
    
    requirement <'REQ-001'> cycleTimeRequirement : PerformanceRequirement {
        doc /* The robot shall complete a material handling cycle in less than 12 seconds. */
        subject system = robotCell;
    }
    
    requirement <'REQ-002'> payloadCapacityRequirement : PerformanceRequirement {
        doc /* The manipulator shall handle workpieces up to 25 kg. */
        subject system = robotCell;
        require constraint {
            robotCell.manipulator.maxPayload >= 25.0 [kg]
        }
    }
    
    requirement <'REQ-003'> positioningAccuracyRequirement : PerformanceRequirement {
        doc /* The manipulator shall achieve positioning repeatability of ±0.03 mm. */
        subject system = robotCell;
        require constraint {
            robotCell.manipulator.repeatability <= 0.03 [mm]
        }
    }
    
    requirement <'REQ-004'> reachRequirement : PerformanceRequirement {
        doc /* The manipulator shall have a minimum reach of 1700 mm. */
        subject system = robotCell;
        require constraint {
            robotCell.manipulator.reach >= 1700.0 [mm]
        }
    }
    
    requirement <'REQ-005'> safetyZoneRequirement : SafetyRequirement {
        doc /* The safety system shall monitor a safety zone of at least 1500 mm radius. */
        subject system = robotCell;
        require constraint {
            robotCell.safetySystem.safetyZoneRadius >= 1500.0 [mm]
        }
    }
    
    requirement <'REQ-006'> emergencyStopRequirement : SafetyRequirement {
        doc /* The system shall halt all motion within 50 ms of emergency stop activation. */
        subject system = robotCell;
    }
    
    requirement <'REQ-007'> collisionDetectionRequirement : SafetyRequirement {
        doc /* The system shall detect collisions and stop motion immediately. */
        subject system = robotCell;
        require constraint {
            robotCell.safetySystem.safetyMonitor.collisionDetected implies
            not robotCell.safetySystem.safetyMonitor.systemSafe
        }
    }
    
    requirement <'REQ-008'> visionAccuracyRequirement : PerformanceRequirement {
        doc /* The vision system shall detect workpiece position with accuracy of ±0.5 mm. */
        subject system = robotCell;
    }
    
    requirement <'REQ-009'> gripperForceRequirement : PerformanceRequirement {
        doc /* The gripper shall provide adjustable grip force up to 600 N. */
        subject system = robotCell;
        require constraint {
            robotCell.gripper.maxGripForce >= 600.0 [N]
        }
    }
    
    requirement <'REQ-010'> uptimeRequirement : ReliabilityRequirement {
        doc /* The system shall maintain 98% uptime during production shifts. */
        subject system = robotCell;
    }
    
    requirement systemMissionRequirement {
        doc /* The HD Hyundai industrial robot system shall autonomously perform high-precision material handling and assembly operations in manufacturing environments. */
        
        assume constraint workpieceAvailability {
            doc /* Workpieces are available at designated pick locations. */
        }
        
        assume constraint powerStability {
            doc /* Power supply provides stable voltage within specifications. */
            robotCell.powerSystem.inputVoltage >= 380.0 [V] and
            robotCell.powerSystem.inputVoltage <= 420.0 [V]
        }
        
        assume constraint environmentalConditions {
            doc /* Operating environment is within specified temperature and humidity ranges. */
        }
        
        require cycleTimeRequirement;
        require payloadCapacityRequirement;
        require positioningAccuracyRequirement;
        require reachRequirement;
        require safetyZoneRequirement;
        require emergencyStopRequirement;
        require collisionDetectionRequirement;
        require visionAccuracyRequirement;
        require gripperForceRequirement;
        require uptimeRequirement;
    }
}
