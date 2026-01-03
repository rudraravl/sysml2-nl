package AnthropomorphicRobotSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def JointAngle :> ISQ::PlaneAngleValue {
        doc /* Angular position of a robotic joint */
    }
    
    attribute def JointTorque :> ISQ::TorqueValue {
        doc /* Torque applied at a robotic joint */
    }
    
    attribute def GripForce :> ISQ::ForceValue {
        doc /* Force applied by end effector gripper */
    }
    
    attribute def VisionData {
        doc /* Visual sensor data package */
        attribute resolution : Integer;
        attribute frameRate : Real;
        attribute timestamp : ISQ::TimeValue;
    }
    
    attribute def Position3D {
        doc /* Three-dimensional position in workspace */
        attribute x : ISQ::LengthValue;
        attribute y : ISQ::LengthValue;
        attribute z : ISQ::LengthValue;
    }
    
    attribute def Orientation {
        doc /* Spatial orientation using Euler angles */
        attribute roll : ISQ::PlaneAngleValue;
        attribute pitch : ISQ::PlaneAngleValue;
        attribute yaw : ISQ::PlaneAngleValue;
    }
    
    attribute def TaskCommand {
        doc /* High-level task instruction */
        attribute taskType : String;
        attribute priority : Integer;
    }
    
    attribute def SystemStatus {
        doc /* Overall system operational status */
        attribute state : String;
        attribute errorCode : Integer;
    }
    
    port def VisionPort {
        out visionData : VisionData;
        out detectedObjects : Position3D[*];
    }
    
    port def JointControlPort {
        in commandAngle : JointAngle;
        in commandTorque : JointTorque;
        out feedbackAngle : JointAngle;
        out feedbackTorque : JointTorque;
    }
    
    port def GripperPort {
        in gripCommand : GripForce;
        out gripFeedback : GripForce;
        out contactDetected : Boolean;
    }
    
    port def CommandPort {
        in taskCommand : TaskCommand;
        out systemStatus : SystemStatus;
    }
    
    port def PowerPort {
        in voltage : ISQ::VoltageValue;
        in current : ISQ::CurrentValue;
    }
    
    part def VisionSystem {
        doc /* Stereo vision system for environmental perception and object detection */
        
        port visionOutput : VisionPort;
        port powerInput : PowerPort;
        
        attribute cameraResolution : Integer := 1920;
        attribute stereoBaseline : ISQ::LengthValue;
        attribute processingRate : Real;
        
        perform action acquireAndProcessVision {
            out processedVision : VisionData;
            out objectPositions : Position3D[*];
            
            action captureImages {
                out leftImage : VisionData;
                out rightImage : VisionData;
            }
            then action computeDepth {
                in leftImg : VisionData;
                in rightImg : VisionData;
                out depthMap : VisionData;
            }
            then action detectObjects {
                in depthData : VisionData;
                out objects : Position3D[*];
            }
            then send processedVision := computeDepth.depthMap;
            then send objectPositions := detectObjects.objects;
        }
    }
    
    part def ShoulderJoint {
        doc /* Anthropomorphic shoulder joint with three degrees of freedom */
        
        port jointControl : JointControlPort;
        port powerInput : PowerPort;
        
        attribute flexionAngle : JointAngle;
        attribute abductionAngle : JointAngle;
        attribute rotationAngle : JointAngle;
        attribute maxTorque : JointTorque;
        
        perform action actuateJoint {
            in targetAngles : JointAngle[3];
            out achievedAngles : JointAngle[3];
            
            action computeTrajectory {
                in target : JointAngle[3];
                out trajectory : JointAngle[3];
            }
            then action applyTorque {
                in path : JointAngle[3];
                out result : JointAngle[3];
            }
            then send achievedAngles := applyTorque.result;
        }
    }
    
    part def ElbowJoint {
        doc /* Anthropomorphic elbow joint with single degree of freedom */
        
        port jointControl : JointControlPort;
        port powerInput : PowerPort;
        
        attribute flexionAngle : JointAngle;
        attribute maxFlexion : ISQ::PlaneAngleValue := 150.0 [SI::deg];
        attribute minFlexion : ISQ::PlaneAngleValue := 0.0 [SI::deg];
        
        perform action flexElbow {
            in targetAngle : JointAngle;
            out currentAngle : JointAngle;
            
            action validateRange {
                in desired : JointAngle;
                out valid : Boolean;
            }
            then decide;
                if validateRange.valid then executeMotion;
                else holdPosition;
            action executeMotion {
                in angle : JointAngle;
                out final : JointAngle;
            }
            then send currentAngle := executeMotion.final;
            action holdPosition {
                out final : JointAngle;
            }
        }
    }
    
    part def WristJoint {
        doc /* Anthropomorphic wrist joint with two degrees of freedom */
        
        port jointControl : JointControlPort;
        port powerInput : PowerPort;
        
        attribute pitchAngle : JointAngle;
        attribute yawAngle : JointAngle;
        
        perform action orientateWrist {
            in targetPitch : JointAngle;
            in targetYaw : JointAngle;
            out finalPitch : JointAngle;
            out finalYaw : JointAngle;
        }
    }
    
    part def AnthropomorphicGripper {
        doc /* Five-finger anthropomorphic gripper with independent finger control */
        
        port gripperControl : GripperPort;
        port powerInput : PowerPort;
        
        attribute fingerCount : Integer := 5;
        attribute fingerAngles : JointAngle[5];
        attribute maxGripForce : GripForce;
        attribute graspedObjectMass : ISQ::MassValue;
        
        perform action executeGrasp {
            in targetForce : GripForce;
            in objectSize : ISQ::LengthValue;
            out appliedForce : GripForce;
            out graspSuccess : Boolean;
            
            action positionFingers {
                in size : ISQ::LengthValue;
                out fingerPositions : JointAngle[5];
            }
            then action closeFingers {
                in positions : JointAngle[5];
                in force : GripForce;
                out finalForce : GripForce;
            }
            then action verifyGrasp {
                in force : GripForce;
                out success : Boolean;
            }
            then send appliedForce := closeFingers.finalForce;
            then send graspSuccess := verifyGrasp.success;
        }
    }
    
    part def ArmManipulator {
        doc /* Complete anthropomorphic arm assembly with shoulder, elbow, and wrist */
        
        port armControl : JointControlPort;
        port powerInput : PowerPort;
        
        part shoulder : ShoulderJoint;
        part elbow : ElbowJoint;
        part wrist : WristJoint;
        
        attribute totalMass : ISQ::MassValue;
        attribute reachRadius : ISQ::LengthValue;
        
        connection shoulderPower connect powerInput to shoulder.powerInput;
        connection elbowPower connect powerInput to elbow.powerInput;
        connection wristPower connect powerInput to wrist.powerInput;
        
        perform action moveToPosition {
            in targetPosition : Position3D;
            in targetOrientation : Orientation;
            out finalPosition : Position3D;
            out success : Boolean;
            
            action computeInverseKinematics {
                in position : Position3D;
                in orientation : Orientation;
                out shoulderAngles : JointAngle[3];
                out elbowAngle : JointAngle;
                out wristAngles : JointAngle[2];
            }
            then action actuateShoulder : shoulder.actuateJoint {
                in targetAngles = computeInverseKinematics.shoulderAngles;
                out achievedAngles;
            }
            then action actuateElbow : elbow.flexElbow {
                in targetAngle = computeInverseKinematics.elbowAngle;
                out currentAngle;
            }
            then action actuateWrist : wrist.orientateWrist {
                in targetPitch = computeInverseKinematics.wristAngles[0];
                in targetYaw = computeInverseKinematics.wristAngles[1];
                out finalPitch;
                out finalYaw;
            }
            then action verifyPosition {
                in achieved : Position3D;
                out valid : Boolean;
            }
            then send success := verifyPosition.valid;
        }
    }
    
    part def MotionPlanner {
        doc /* Central motion planning and coordination controller */
        
        port controlInterface : CommandPort;
        port powerInput : PowerPort;
        
        attribute planningHorizon : ISQ::TimeValue;
        attribute currentPlan : String;
        
        perform action planManipulation {
            in task : TaskCommand;
            in objectLocation : Position3D;
            in obstacles : Position3D[*];
            out armTrajectory : Position3D[*];
            out gripperCommands : GripForce[*];
            out executionStatus : SystemStatus;
            
            action analyzeTask {
                in taskSpec : TaskCommand;
                out taskType : String;
                out requiredActions : String[*];
            }
            then action generatePath {
                in start : Position3D;
                in goal : Position3D;
                in obstacleList : Position3D[*];
                out waypoints : Position3D[*];
            }
            then action optimizeTrajectory {
                in path : Position3D[*];
                out smoothPath : Position3D[*];
            }
            then action computeGripSequence {
                in trajectory : Position3D[*];
                out gripSequence : GripForce[*];
            }
            then send armTrajectory := optimizeTrajectory.smoothPath;
            then send gripperCommands := computeGripSequence.gripSequence;
        }
    }
    
    part def PowerManagementUnit {
        doc /* Power distribution and management for all subsystems */
        
        port mainPower : PowerPort;
        port visionPower : PowerPort;
        port leftArmPower : PowerPort;
        port rightArmPower : PowerPort;
        port controllerPower : PowerPort;
        
        attribute totalCapacity : ISQ::EnergyValue;
        attribute currentDraw : ISQ::CurrentValue;
        attribute batteryLevel : Real;
        
        perform action distributePower {
            in demand : ISQ::PowerValue[*];
            out allocation : ISQ::PowerValue[*];
            
            action assessLoad {
                in requests : ISQ::PowerValue[*];
                out totalLoad : ISQ::PowerValue;
            }
            then decide;
                if assessLoad.totalLoad <= totalCapacity then allocateFull;
                else allocatePriority;
            action allocateFull {
                in requests : ISQ::PowerValue[*];
                out distribution : ISQ::PowerValue[*];
            }
            then send allocation := allocateFull.distribution;
            action allocatePriority {
                in requests : ISQ::PowerValue[*];
                out distribution : ISQ::PowerValue[*];
            }
        }
    }
    
    part anthropomorphicRobot {
        doc /* 
            Anthropomorphic robot system designed to replicate human upper body morphology and function.
            Primary function: Execute complex manipulation tasks in human-centric environments through
            biologically-inspired kinematics, including object recognition, precise reaching, adaptive
            grasping, and coordinated bimanual manipulation using dual arm systems with human-like
            range of motion and dexterity.
        */
        
        port systemCommand : CommandPort;
        port externalPower : PowerPort;
        
        part visionSys : VisionSystem {
            port visionOutput;
            port powerInput;
        }
        
        part leftArm : ArmManipulator {
            port armControl;
            port powerInput;
            attribute totalMass = 8.5 [SI::kg];
            attribute reachRadius = 0.85 [SI::m];
        }
        
        part rightArm : ArmManipulator {
            port armControl;
            port powerInput;
            attribute totalMass = 8.5 [SI::kg];
            attribute reachRadius = 0.85 [SI::m];
        }
        
        part leftGripper : AnthropomorphicGripper {
            port gripperControl;
            port powerInput;
            attribute maxGripForce = 150.0 [SI::N];
        }
        
        part rightGripper : AnthropomorphicGripper {
            port gripperControl;
            port powerInput;
            attribute maxGripForce = 150.0 [SI::N];
        }
        
        part planner : MotionPlanner {
            port controlInterface;
            port powerInput;
        }
        
        part powerMgmt : PowerManagementUnit {
            port mainPower;
            port visionPower;
            port leftArmPower;
            port rightArmPower;
            port controllerPower;
            attribute totalCapacity = 5000.0 [SI::'W*h'];
        }
        
        connection externalToPower connect externalPower to powerMgmt.mainPower;
        connection powerToVision connect powerMgmt.visionPower to visionSys.powerInput;
        connection powerToLeftArm connect powerMgmt.leftArmPower to leftArm.powerInput;
        connection powerToRightArm connect powerMgmt.rightArmPower to rightArm.powerInput;
        connection powerToController connect powerMgmt.controllerPower to planner.powerInput;
        connection powerToLeftGripper connect powerMgmt.leftArmPower to leftGripper.powerInput;
        connection powerToRightGripper connect powerMgmt.rightArmPower to rightGripper.powerInput;
        
        perform action executeManipulationMission {
            in missionCommand : TaskCommand;
            out missionStatus : SystemStatus;
            
            first start;
            then merge continuousOperation;
            then action perceiveEnvironment : visionSys.acquireAndProcessVision {
                out processedVision;
                out objectPositions;
            }
            then action planMotion : planner.planManipulation {
                in task = missionCommand;
                in objectLocation = perceiveEnvironment.objectPositions[0];
                in obstacles;
                out armTrajectory;
                out gripperCommands;
                out executionStatus;
            }
            then decide;
                if planMotion.executionStatus.errorCode == 0 then executeLeft;
                else abortMission;
            action executeLeft : leftArm.moveToPosition {
                in targetPosition = planMotion.armTrajectory[0];
                in targetOrientation;
                out finalPosition;
                out success;
            }
            then action graspLeft : leftGripper.executeGrasp {
                in targetForce = planMotion.gripperCommands[0];
                in objectSize;
                out appliedForce;
                out graspSuccess;
            }
            then decide;
                if graspLeft.graspSuccess then completeTask;
                else retryGrasp;
            action retryGrasp;
            then continuousOperation;
            action completeTask;
            then send missionStatus := planMotion.executionStatus;
            action abortMission;
        }
        
        exhibit state operationalBehavior {
            entry; then idle;
            
            state idle {
                doc /* Robot awaiting task command */
            }
            
            transition idleToPerceiving
                first idle
                accept cmd : TaskCommand
                then perceiving;
            
            state perceiving {
                doc /* Acquiring and processing visual information */
                entry do visionSys.acquireAndProcessVision;
            }
            
            transition perceivingToPlanning
                first perceiving
                then planning;
            
            state planning {
                doc /* Computing motion plan and grasp strategy */
                entry do planner.planManipulation;
            }
            
            transition planningToExecuting
                first planning
                then executing;
            
            state executing {
                doc /* Executing coordinated manipulation */
                
                entry; then reaching;
                
                state reaching {
                    entry do leftArm.moveToPosition;
                }
                
                transition reachToGrasp
                    first reaching
                    then grasping;
                
                state grasping {
                    entry do leftGripper.executeGrasp;
                }
                
                transition graspToManipulating
                    first grasping
                    then manipulating;
                
                state manipulating;
            }
            
            transition executingToIdle
                first executing
                then idle;
            
            transition executingToError
                first executing
                if powerMgmt.batteryLevel < 10.0
                then error;
            
            state error {
                doc /* Error state requiring intervention */
            }
        }
    }
    
    requirement def AnthropomorphicCapability {
        doc /* Robot shall exhibit human-like manipulation capabilities */
        
        subject robot : anthropomorphicRobot;
        
        require constraint jointRangeCompliance {
            doc /* Joint ranges shall match human physiological limits */
            robot.leftArm.shoulder.flexionAngle >= -180.0 [SI::deg] and
            robot.leftArm.shoulder.flexionAngle <= 180.0 [SI::deg] and
            robot.leftArm.elbow.flexionAngle >= 0.0 [SI::deg] and
            robot.leftArm.elbow.flexionAngle <= 150.0 [SI::deg]
        }
        
        require constraint dexterityRequirement {
            doc /* Gripper shall provide five-finger dexterity */
            robot.leftGripper.fingerCount >= 5 and
            robot.rightGripper.fingerCount >= 5
        }
        
        require constraint reachRequirement {
            doc /* Arm reach shall approximate human arm span */
            robot.leftArm.reachRadius >= 0.8 [SI::m] and
            robot.rightArm.reachRadius >= 0.8 [SI::m]
        }
    }
    
    requirement def SafetyRequirement {
        doc /* Robot shall operate safely in human environments */
        
        subject robot : anthropomorphicRobot;
        
        require constraint forceLimitation {
            doc /* Grip force shall not exceed safe human interaction threshold */
            robot.leftGripper.maxGripForce <= 150.0 [SI::N] and
            robot.rightGripper.maxGripForce <= 150.0 [SI::N]
        }
        
        require constraint visionMonitoring {
            doc /* Vision system shall maintain continuous environmental awareness */
            robot.visionSys.processingRate >= 30.0
        }
        
        require constraint powerManagement {
            doc /* System shall manage power to prevent sudden shutdown */
            robot.powerMgmt.batteryLevel >= 5.0
        }
    }
    
    requirement def PerformanceRequirement {
        doc /* Robot shall meet manipulation performance criteria */
        
        subject robot : anthropomorphicRobot;
        
        require constraint positionAccuracy {
            doc /* End effector positioning accuracy requirement */
        }
        
        require constraint responseTime {
            doc /* System shall respond to commands within specified time */
        }
    }
    
    requirement primaryMissionRequirement : AnthropomorphicCapability {
        doc /* Top-level mission requirement for anthropomorphic manipulation */
        
        assume constraint operationalEnvironment {
            doc /* Robot operates in structured indoor human workspace */
        }
        
        require safetyReq : SafetyRequirement;
        require performanceReq : PerformanceRequirement;
    }
}
