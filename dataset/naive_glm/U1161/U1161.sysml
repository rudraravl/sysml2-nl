package AutonomousMobileRobot {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;
    import ISQTime::*;
    import ISQMass::*;
    import ISQAngle::*;
    
    // ===== Value Types with Units =====
    
    value type Length_mm :> Real {
        :>> unit = mm;
    }
    
    value type Distance_m :> Real {
        :>> unit = m;
    }
    
    value type Velocity_m_s :> Real {
        :>> unit = m/s;
    }
    
    value type AngularVelocity_rad_s :> Real {
        :>> unit = rad/s;
    }
    
    value type Angle_deg :> Real {
        :>> unit = '°';
    }
    
    value type Mass_kg :> Real {
        :>> unit = kg;
    }
    
    value type Frequency_Hz :> Real {
        :>> unit = Hz;
    }
    
    value type Power_W :> Real {
        :>> unit = W;
    }
    
    value type Time_ms :> Real {
        :>> unit = ms;
    }
    
    value type Confidence :> Real {
        :>> unit = 1;
        doc /* Range 0.0 to 1.0 */;
    }
    
    value type JointTorque_Nm :> Real {
        :>> unit = N*m;
    }
    
    value type Pose {
        attribute x : Distance_m;
        attribute y : Distance_m;
        attribute z : Distance_m;
        attribute roll : Angle_deg;
        attribute pitch : Angle_deg;
        attribute yaw : Angle_deg;
    }
    
    value type PointCloud {
        attribute pointCount : PositiveNatural;
        attribute resolution_mm : Length_mm;
    }
    
    value type RGBDImage {
        attribute width_px : PositiveNatural;
        attribute height_px : PositiveNatural;
        attribute depthRange_m : Distance_m;
    }
    
    value type ObjectClassification {
        attribute label : String;
        attribute confidence : Confidence;
        attribute centroid : Pose;
        attribute boundingBoxVolume_m3 : Real;
    }
    
    value type WorldModel {
        attribute robotPose : Pose;
        attribute detectedObjects : ObjectClassification[0..*];
        attribute mapResolution_mm : Length_mm;
        attribute lastUpdateTimestamp : Time_ms;
    }
    
    value type MotionCommand {
        attribute linearVelocity : Velocity_m_s;
        attribute angularVelocity : AngularVelocity_rad_s;
        attribute targetPose : Pose;
    }
    
    value type ManipulatorCommand {
        attribute jointPositions : Angle_deg[6];
        attribute jointVelocities : AngularVelocity_rad_s[6];
        attribute gripperState : GripperState;
    }
    
    enum GripperState { open | closed | holding }
    
    enum GoalType { navigate | pick | place | inspect }
    
    value type HighLevelGoal {
        attribute goalType : GoalType;
        attribute targetPose : Pose;
        attribute targetObjectLabel : String;
        attribute priority : Integer;
    }
    
    // ===== Item Definitions =====
    
    item def SensorData;
    item def CameraFrame :> SensorData {
        attribute rgbImage : RGBDImage;
        attribute depthImage : RGBDImage;
        attribute timestamp : Time_ms;
    }
    
    item def LidarScan :> SensorData {
        attribute cloud : PointCloud;
        attribute timestamp : Time_ms;
    }
    
    item def FusedPerception {
        attribute worldModel : WorldModel;
        attribute timestamp : Time_ms;
    }
    
    item def Plan {
        attribute motionPlan : MotionCommand[0..*];
        attribute manipulatorPlan : ManipulatorCommand[0..*];
        attribute estimatedDuration_ms : Time_ms;
    }
    
    item def ExecutionStatus {
        attribute motionComplete : Boolean;
        attribute manipulationComplete : Boolean;
        attribute collisionDetected : Boolean;
        attribute poseError_m : Distance_m;
    }
    
    item def SafetyAlert {
        attribute alertType : String;
        attribute severity : Integer;
        attribute timestamp : Time_ms;
    }
    
    // ===== Port Definitions =====
    
    port def SensorOutPort {
        out item : SensorData;
    }
    
    port def PerceptionOutPort {
        out item : FusedPerception;
    }
    
    port def GoalInPort {
        in item : HighLevelGoal;
    }
    
    port def PlanOutPort {
        out item : Plan;
    }
    
    port def PlanInPort {
        in item : Plan;
    }
    
    port def MotionCmdPort {
        out item : MotionCommand;
    }
    
    port def ManipulatorCmdPort {
        out item : ManipulatorCommand;
    }
    
    port def StatusOutPort {
        out item : ExecutionStatus;
    }
    
    port def SafetyPort {
        out item : SafetyAlert;
        in item : ExecutionStatus;
    }
    
    port def PowerPort {
        attribute voltage : Real;
        attribute current : Real;
    }
    
    // ===== Requirements =====
    
    requirement def PerceptionAccuracyRequirement {
        doc /* The perception subsystem shall detect and classify objects with high accuracy. */
        attribute minDetectionConfidence : Confidence = 0.85;
        attribute maxLocalizationError_mm : Length_mm = 50.0;
        subject perceptionSubsystem : PerceptionSubsystem;
        require {
            perceptionSubsystem.detectedObject.confidence >= minDetectionConfidence;
            perceptionSubsystem.localizationError_mm <= maxLocalizationError_mm;
        }
    }
    
    requirement def CollisionAvoidanceRequirement {
        doc /* The robot shall avoid collisions with any obstacle in its environment. */
        attribute minSafeDistance_m : Distance_m = 0.20;
        attribute responseTime_ms : Time_ms = 100.0;
        subject robot : AutonomousMobileRobotSystem;
        require {
            robot.minObstacleClearance_m >= minSafeDistance_m;
            robot.collisionResponseTime_ms <= responseTime_ms;
        }
    }
    
    requirement def RealTimePerformanceRequirement {
        doc /* The sense-plan-act cycle shall complete within real-time constraints. */
        attribute maxCycleLatency_ms : Time_ms = 50.0;
        attribute minControlLoopFreq_Hz : Frequency_Hz = 20.0;
        subject controlSystem : CentralController;
        require {
            controlSystem.cycleLatency_ms <= maxCycleLatency_ms;
            controlSystem.controlLoopFreq_Hz >= minControlLoopFreq_Hz;
        }
    }
    
    requirement def ManipulationPrecisionRequirement {
        doc /* The robotic arm shall perform manipulation tasks with high precision. */
        attribute maxGraspError_mm : Length_mm = 5.0;
        attribute jointCount : PositiveNatural = 6;
        subject arm : RoboticArm;
        require {
            arm.graspPositionError_mm <= maxGraspError_mm;
            arm.jointCount == jointCount;
        }
    }
    
    requirement def NavigationAccuracyRequirement {
        doc /* The mobile base shall navigate to target locations accurately. */
        attribute maxPositionError_m : Distance_m = 0.10;
        attribute maxOrientationError_deg : Angle_deg = 5.0;
        subject base : MobileBase;
        require {
            base.positionError_m <= maxPositionError_m;
            base.orientationError_deg <= maxOrientationError_deg;
        }
    }
    
    requirement def SystemRequirements {
        requirement perceptionAcc : PerceptionAccuracyRequirement;
        requirement collisionAvoid : CollisionAvoidanceRequirement;
        requirement realTime : RealTimePerformanceRequirement;
        requirement manipulationPrec : ManipulationPrecisionRequirement;
        requirement navigationAcc : NavigationAccuracyRequirement;
    }
    
    // ===== Action / Activity Definitions =====
    
    action def SensePlanActCycle {
        in goal : HighLevelGoal;
        in sensorStream : SensorData[0..*];
        out executionResult : ExecutionStatus;
        
        action sense {
            in sensorData : SensorData[0..*] = sensorStream;
            out fused : FusedPerception;
        }
        action plan {
            in currentGoal : HighLevelGoal = goal;
            in perception : FusedPerception = sense.fused;
            out motionPlan : Plan;
        }
        action act {
            in p : Plan = plan.motionPlan;
            out status : ExecutionStatus;
        }
        action monitor {
            in status : ExecutionStatus = act.status;
            out updatedModel : FusedPerception;
        }
        
        satisfy realTime by cycleLatency_ms;
        attribute cycleLatency_ms : Time_ms;
        
        flow from sense.fused to plan.perception;
        flow from plan.motionPlan to act.p;
        flow from act.status to monitor.status;
        
        bind executionResult = act.status;
    }
    
    action def FuseSensorData {
        in cameraFrame : CameraFrame;
        in lidarScan : LidarScan;
        out fusedPerception : FusedPerception;
        
        action extractFeatures {
            in image : CameraFrame = cameraFrame;
            out detectedObjects : ObjectClassification[0..*];
        }
        action buildMap {
            in cloud : PointCloud = lidarScan.cloud;
            out occupancyMap : PointCloud;
        }
        action updateWorldModel {
            in objects : ObjectClassification[0..*] = extractFeatures.detectedObjects;
            in map : PointCloud = buildMap.occupancyMap;
            out model : WorldModel;
        }
        flow from updateWorldModel.model to fusedPerception.worldModel;
    }
    
    action def GenerateMotionPlan {
        in goal : HighLevelGoal;
        in worldModel : WorldModel;
        out plan : Plan;
        
        action pathPlan {
            in target : Pose;
            in obstacles : ObjectClassification[0..*];
            out motionCommands : MotionCommand[0..*];
        }
        action manipulatorPlan {
            in targetObject : ObjectClassification;
            out armCommands : ManipulatorCommand[0..*];
        }
        action checkSafety {
            in motion : MotionCommand[0..*] = pathPlan.motionCommands;
            in arm : ManipulatorCommand[0..*] = manipulatorPlan.armCommands;
            out safe : Boolean;
        }
    }
    
    // ===== State Machine Definitions =====
    
    state def ControlStateMachine {
        entry; then Idle;
        
        state Idle {
            entry; 
            accept GoalInPort.item : HighLevelGoal
                then Sensing;
        }
        
        state Sensing {
            entry action fuseSensors;
            do fuseSensorData;
            accept FusedPerception
                then Planning;
        }
        
        state Planning {
            entry action generatePlan;
            do generateMotionPlan;
            accept Plan
                then Executing;
            accept SafetyAlert
                then EmergencyStop;
        }
        
        state Executing {
            entry action dispatchCommands;
            do executeMotion;
            accept ExecutionStatus {
                :>> motionComplete == true && manipulationComplete == true;
            } then Monitoring;
            accept SafetyAlert
                then EmergencyStop;
        }
        
        state Monitoring {
            entry action updateWorldModel;
            do monitorExecution;
            accept ExecutionStatus {
                :>> collisionDetected == false;
            } then Idle;
            accept ExecutionStatus {
                :>> collisionDetected == true;
            } then EmergencyStop;
        }
        
        state EmergencyStop {
            entry action haltAllMotion;
            do emergencyBrake;
            accept ResetCommand
                then Idle;
        }
    }
    
    // ===== Part Definitions =====
    
    part def RGBDCamera {
        port sensorOut : SensorOutPort;
        attribute resolution : String = "1920x1080";
        attribute depthRange_m : Distance_m = 10.0;
        attribute frameRate_Hz : Frequency_Hz = 30.0;
        attribute powerConsumption_W : Power_W = 5.0;
        
        perform action captureFrame {
            out frame : CameraFrame;
        }
    }
    
    part def LidarSensor {
        port sensorOut : SensorOutPort;
        attribute range_m : Distance_m = 100.0;
        attribute angularResolution_deg : Angle_deg = 0.2;
        attribute scanRate_Hz : Frequency_Hz = 20.0;
        attribute powerConsumption_W : Power_W = 10.0;
        
        perform action scanEnvironment {
            out scan : LidarScan;
        }
    }
    
    part def MobileBase {
        port motionCmdIn : MotionCmdPort;
        port statusOut : StatusOutPort;
        port powerIn : PowerPort;
        
        attribute maxLinearVelocity : Velocity_m_s = 2.0;
        attribute maxAngularVelocity : AngularVelocity_rad_s = 1.5;
        attribute payload_kg : Mass_kg = 50.0;
        attribute wheelbase_m : Distance_m = 0.6;
        attribute positionError_m : Distance_m;
        attribute orientationError_deg : Angle_deg;
        attribute minObstacleClearance_m : Distance_m;
        
        perform action executeMotion {
            in cmd : MotionCommand;
            out status : ExecutionStatus;
        }
        
        satisfy navigationAcc;
    }
    
    part def Joint {
        attribute jointId : Integer;
        attribute minAngle_deg : Angle_deg;
        attribute maxAngle_deg : Angle_deg;
        attribute maxTorque_Nm : JointTorque_Nm;
        attribute currentAngle_deg : Angle_deg;
        attribute currentVelocity_rad_s : AngularVelocity_rad_s;
        
        perform action moveJoint {
            in targetAngle : Angle_deg;
            in targetVelocity : AngularVelocity_rad_s;
        }
    }
    
    part def Gripper {
        attribute maxGripForce_N : Real = 50.0;
        attribute state : GripperState = open;
        
        perform action actuateGripper {
            in targetState : GripperState;
        }
    }
    
    part def RoboticArm {
        port manipulatorCmdIn : ManipulatorCmdPort;
        port statusOut : StatusOutPort;
        port powerIn : PowerPort;
        
        part joints : Joint[6] {
            :>> jointId = #(1..6);
            :>> minAngle_deg = -180.0;
            :>> maxAngle_deg = 180.0;
            :>> maxTorque_Nm = 40.0;
        }
        part endEffector : Gripper;
        
        attribute jointCount : PositiveNatural = 6;
        attribute reach_m : Distance_m = 1.2;
        attribute graspPositionError_mm : Length_mm;
        attribute payload_kg : Mass_kg = 5.0;
        
        perform action executeManipulation {
            in cmd : ManipulatorCommand;
            out status : ExecutionStatus;
        }
        
        satisfy manipulationPrec;
    }
    
    part def PerceptionSubsystem {
        port cameraIn : SensorOutPort;
        port lidarIn : SensorOutPort;
        port perceptionOut : PerceptionOutPort;
        
        part camera : RGBDCamera;
        part lidar : LidarSensor;
        
        attribute detectedObject : ObjectClassification;
        attribute localizationError_mm : Length_mm;
        attribute fusionRate_Hz : Frequency_Hz = 15.0;
        
        perform action fuseSensorData : FuseSensorData;
        
        satisfy perceptionAcc;
    }
    
    part def PlanningSubsystem {
        port perceptionIn : PerceptionOutPort;
        port goalIn : GoalInPort;
        port planOut : PlanOutPort;
        
        attribute planningHorizon_s : Real = 5.0;
        attribute replanningThreshold_m : Distance_m = 0.5;
        
        perform action generateMotionPlan : GenerateMotionPlan;
    }
    
    part def CentralController {
        port goalIn : GoalInPort;
        port perceptionIn : PerceptionOutPort;
        port planIn : PlanInPort;
        port motionCmdOut : MotionCmdPort;
        port manipulatorCmdOut : ManipulatorCmdPort;
        port statusIn : StatusOutPort;
        port safetyOut : SafetyPort;
        
        attribute cycleLatency_ms : Time_ms;
        attribute controlLoopFreq_Hz : Frequency_Hz = 20.0;
        attribute collisionResponseTime_ms : Time_ms;
        
        exhibit state behavior : ControlStateMachine;
        
        perform action sensePlanActCycle : SensePlanActCycle;
        
        satisfy realTime;
        satisfy collisionAvoid;
    }
    
    part def SafetyMonitor {
        port statusIn : StatusOutPort;
        port safetyOut : SafetyPort;
        
        attribute minSafeDistance_m : Distance_m = 0.20;
        attribute emergencyStopEngaged : Boolean = false;
        
        perform action checkCollision {
            in status : ExecutionStatus;
            out alert : SafetyAlert;
        }
    }
    
    part def PowerSystem {
        port powerOut : PowerPort[3];
        attribute batteryCapacity_Wh : Real = 500.0;
        attribute currentCharge_pct : Real = 100.0;
        attribute outputVoltage_V : Real = 24.0;
    }
    
    // ===== Top-Level System =====
    
    part def AutonomousMobileRobotSystem {
        port goalIn : GoalInPort;
        port safetyOut : SafetyPort;
        
        attribute minObstacleClearance_m : Distance_m;
        attribute collisionResponseTime_ms : Time_ms;
        attribute totalMass_kg : Mass_kg = 75.0;
        attribute operatingTempRange_C : String = "-10 to 50";
        
        part perception : PerceptionSubsystem {
            :>> cameraIn;
            :>> lidarIn;
            :>> perceptionOut;
        }
        
        part planning : PlanningSubsystem {
            :>> perceptionIn;
            :>> goalIn;
            :>> planOut;
        }
        
        part controller : CentralController {
            :>> goalIn;
            :>> perceptionIn;
            :>> planIn;
            :>> motionCmdOut;
            :>> manipulatorCmdOut;
            :>> statusIn;
            :>> safetyOut;
        }
        
        part safety : SafetyMonitor {
            :>> statusIn;
            :>> safetyOut;
        }
        
        part mobileBase : MobileBase {
            :>> motionCmdIn;
            :>> statusOut;
            :>> powerIn;
        }
        
        part arm : RoboticArm {
            :>> manipulatorCmdIn;
            :>> statusOut;
            :>> powerIn;
        }
        
        part power : PowerSystem {
            :>> powerOut;
        }
        
        // ===== Connections =====
        
        connection cameraDataFlow connect perception.camera.sensorOut to perception.cameraIn;
        connection lidarDataFlow connect perception.lidar.sensorOut to perception.lidarIn;
        
        connection perceptionToPlanning connect perception.perceptionOut to planning.perceptionIn;
        connection perceptionToController connect perception.perceptionOut to controller.perceptionIn;
        
        connection goalToPlanning connect goalIn to planning.goalIn;
        connection goalToController connect goalIn to controller.goalIn;
        
        connection planToController connect planning.planOut to controller.planIn;
        
        connection motionCmdFlow connect controller.motionCmdOut to mobileBase.motionCmdIn;
        connection manipulatorCmdFlow connect controller.manipulatorCmdOut to arm.manipulatorCmdIn;
        
        connection baseStatusFlow connect mobileBase.statusOut to controller.statusIn;
        connection armStatusFlow connect arm.statusOut to controller.statusIn;
        
        connection baseStatusToSafety connect mobileBase.statusOut to safety.statusIn;
        connection armStatusToSafety connect arm.statusOut to safety.statusIn;
        
        connection safetyAlertFlow connect safety.safetyOut to controller.safetyOut;
        connection safetyAlertExternal connect safety.safetyOut to safetyOut;
        
        connection powerToBase connect power.powerOut[1] to mobileBase.powerIn;
        connection powerToArm connect power.powerOut[2] to arm.powerIn;
        connection powerToPerception connect power.powerOut[3] to perception.camera.sensorOut;
        
        // ===== Requirements Satisfaction =====
        
        satisfy SystemRequirements;
        
        // ===== Allocation =====
        
        allocate sensePlanActCycle from controller;
        allocate FuseSensorData from perception;
        allocate GenerateMotionPlan from planning;
        allocate ControlStateMachine from controller;
        allocate executeMotion from mobileBase;
        allocate executeManipulation from arm;
    }
    
    // ===== Verification =====
    
    verification def VerifyCollisionAvoidance {
        subject robot : AutonomousMobileRobotSystem;
        objective {
            doc /* Verify the robot maintains safe distance from obstacles. */
        }
        return success : Boolean;
    }
    
    verification def VerifyPerceptionAccuracy {
        subject perception : PerceptionSubsystem;
        objective {
            doc /* Verify object detection confidence and localization accuracy. */
        }
        return success : Boolean;
    }
    
    verification def VerifyRealTimePerformance {
        subject controller : CentralController;
        objective {
            doc /* Verify sense-plan-act cycle meets latency requirements. */
        }
        return success : Boolean;
    }
    
    verification def VerifyManipulationPrecision {
        subject arm : RoboticArm;
        objective {
            doc /* Verify grasp position accuracy. */
        }
        return success : Boolean;
    }
    
    verification def VerifyNavigationAccuracy {
        subject base : MobileBase;
        objective {
            doc /* Verify navigation to target pose accuracy. */
        }
        return success : Boolean;
    }
}
