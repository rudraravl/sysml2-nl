package 'IEEE RAS Autonomous Bin Picking System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def SuccessRate :> Real;
    attribute def CycleTime :> TimeValue;
    attribute def PositionError :> LengthValue;
    attribute def GraspForce :> ForceValue;
    attribute def ProcessingFrequency :> FrequencyValue;

    attribute def Pose3D {
        doc /* Represents position and orientation in 3D space. */
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
        attribute roll : Real;
        attribute pitch : Real;
        attribute yaw : Real;
    }

    attribute def PointCloud {
        doc /* 3D point cloud data from depth sensors. */
        attribute pointCount : Integer;
        attribute timestamp : TimeValue;
    }

    item def WorkPiece {
        doc /* Object to be picked from bin. */
        attribute mass : MassValue;
        attribute dimensionX : LengthValue;
        attribute dimensionY : LengthValue;
        attribute dimensionZ : LengthValue;
        attribute pose : Pose3D;
        attribute graspable : Boolean;
    }

    item def GraspPlan {
        doc /* Computed grasp strategy for a work piece. */
        attribute approachPose : Pose3D;
        attribute graspPose : Pose3D;
        attribute graspForce : GraspForce;
        attribute confidence : Real;
    }

    port def VisionPort {
        out pointCloudData : PointCloud;
        out objectCount : Integer;
        out processingComplete : Boolean;
    }

    port def MotionPort {
        in targetPose : Pose3D;
        in targetVelocity : SpeedValue;
        out currentPose : Pose3D;
        out reachedTarget : Boolean;
    }

    port def GripperPort {
        in graspCommand : Boolean;
        in releaseCommand : Boolean;
        in targetForce : GraspForce;
        out graspSuccess : Boolean;
        out measuredForce : GraspForce;
    }

    port def PlannerPort {
        in sceneData : PointCloud;
        in objectCount : Integer;
        out graspPlan : GraspPlan;
        out planReady : Boolean;
    }

    part def DepthCamera {
        doc /* 3D vision sensor for scene perception. */
        attribute frameRate : ProcessingFrequency;
        attribute depthRange : LengthValue;
        attribute resolutionX : Integer;
        attribute resolutionY : Integer;
        port visionOut : VisionPort;

        action captureScene {
            out pointCloudData : PointCloud;
            out objectCount : Integer;
        }
    }

    part def RoboticManipulator {
        doc /* 6-DOF industrial robot arm. */
        attribute reach : LengthValue;
        attribute maxPayload : MassValue;
        attribute repeatability : PositionError;
        port motionControl : MotionPort;

        action executeMotion {
            in targetPose : Pose3D;
            in targetVelocity : SpeedValue;
            out currentPose : Pose3D;
            out reachedTarget : Boolean;
        }
    }

    part def AdaptiveGripper {
        doc /* Compliant gripper with force sensing. */
        attribute maxForce : GraspForce;
        attribute fingerSpan : LengthValue;
        port gripperControl : GripperPort;

        action executeGrasp {
            in targetForce : GraspForce;
            out graspSuccess : Boolean;
            out measuredForce : GraspForce;
        }

        action releaseObject {
            out releaseComplete : Boolean;
        }
    }

    part def MotionPlanner {
        doc /* Real-time trajectory and grasp planning. */
        attribute planningCycleTime : TimeValue;
        port plannerInterface : PlannerPort;

        action computeGraspPlan {
            in sceneData : PointCloud;
            in objectCount : Integer;
            out graspPlan : GraspPlan;
        }

        action planTrajectory {
            in startPose : Pose3D;
            in goalPose : Pose3D;
            out planReady : Boolean;
        }
    }

    part def SystemController {
        doc /* High-level coordination and state management. */
        attribute controlFrequency : ProcessingFrequency;
        attribute visionActive : Boolean;

        action coordinateBinPicking;
    }

    action def PerceiveScene {
        doc /* Acquire and process 3D scene data. */
        out scenePointCloud : PointCloud;
        out objectCount : Integer;
        out perceptionSuccess : Boolean;
    }

    action def PlanGrasp {
        doc /* Compute optimal grasp for target object. */
        in sceneData : PointCloud;
        in objectCount : Integer;
        out graspStrategy : GraspPlan;
        out planningSuccess : Boolean;
    }

    action def ExecutePickMotion {
        doc /* Move to object and execute grasp. */
        in graspPlan : GraspPlan;
        out pickSuccess : Boolean;
    }

    action def ExecutePlaceMotion {
        doc /* Transport and place object at target location. */
        in placementPose : Pose3D;
        out placeSuccess : Boolean;
    }

    requirement def SystemPerformanceRequirement {
        doc /* The autonomous bin picking system shall achieve high-speed, reliable picking from unstructured bins. */

        require constraint cycleTimeConstraint {
            doc /* Average pick-and-place cycle time shall be less than 4 seconds. */
        }

        require constraint successRateConstraint {
            doc /* Grasp success rate shall exceed 95% for known object types. */
        }

        require constraint positionAccuracyConstraint {
            doc /* Placement accuracy shall be within 1.0 mm of target position. */
        }
    }

    requirement def RobustnessRequirement {
        doc /* System shall handle variability in object pose, lighting, and occlusion. */

        require constraint occlusionHandling {
            doc /* System shall successfully grasp objects with up to 60% occlusion. */
        }

        require constraint lightingInvariance {
            doc /* System shall operate under varying ambient lighting conditions. */
        }
    }

    requirement def SafetyRequirement {
        doc /* System shall operate safely in industrial environments. */

        require constraint forceControl {
            doc /* Gripper force shall be limited to prevent object damage. */
        }

        require constraint collisionAvoidance {
            doc /* System shall detect and avoid collisions with bin walls and other objects. */
        }
    }

    part binPickingSystem {
        doc /* 
        This system represents an IEEE Robotics and Automation Award-winning autonomous 
        bin picking solution. Its primary function is to autonomously perceive, plan, and 
        execute high-speed picking of randomly oriented objects from unstructured bins.
        
        The system integrates advanced 3D vision, real-time motion planning, and adaptive 
        grasping to handle the challenges of cluttered environments, partial occlusions, 
        and varying object poses. It demonstrates breakthrough capabilities in robotic 
        perception and manipulation for industrial automation, achieving human-level 
        performance in tasks previously requiring manual labor.
        
        Key innovations include deep learning-based object segmentation, collision-free 
        trajectory generation in cluttered spaces, and force-controlled grasping that 
        adapts to object geometry and material properties.
        */

        part camera : DepthCamera {
            attribute :>> frameRate = 30.0 [Hz];
            attribute :>> depthRange = 2000.0 [mm];
            attribute :>> resolutionX = 1920;
            attribute :>> resolutionY = 1080;
        }

        part manipulator : RoboticManipulator {
            attribute :>> reach = 900.0 [mm];
            attribute :>> maxPayload = 10.0 [kg];
            attribute :>> repeatability = 0.05 [mm];
        }

        part gripper : AdaptiveGripper {
            attribute :>> maxForce = 150.0 [N];
            attribute :>> fingerSpan = 120.0 [mm];
        }

        part planner : MotionPlanner {
            attribute :>> planningCycleTime = 0.1 [s];
        }

        part controller : SystemController {
            attribute :>> controlFrequency = 100.0 [Hz];
            attribute :>> visionActive = false;
        }

        connection visionToPlanner connect 
            camera.visionOut to planner.plannerInterface;

        connection plannerToManipulator connect 
            planner.plannerInterface to manipulator.motionControl;

        connection controllerToGripper connect 
            controller to gripper.gripperControl;

        action autonomousBinPicking {
            doc /* Main operational behavior coordinating perception, planning, and execution. */

            first start;
            then merge operationLoop;

            action perceive : PerceiveScene {
                out scenePointCloud;
                out objectCount;
                out perceptionSuccess;
            }

            then decide;
                if perceive.perceptionSuccess and perceive.objectCount > 0 
                    then selectTarget;
                if not perceive.perceptionSuccess or perceive.objectCount == 0 
                    then operationLoop;

            action selectTarget {
                doc /* Select highest-priority pickable object. */
                in candidateCount = perceive.objectCount;
                out targetSelected : Boolean;
            }

            then action planGrasp : PlanGrasp {
                in sceneData = perceive.scenePointCloud;
                in objectCount = perceive.objectCount;
                out graspStrategy;
                out planningSuccess;
            }

            then decide;
                if planGrasp.planningSuccess then executePick;
                if not planGrasp.planningSuccess then operationLoop;

            action executePick : ExecutePickMotion {
                in graspPlan = planGrasp.graspStrategy;
                out pickSuccess;
            }

            then decide;
                if executePick.pickSuccess then executePlace;
                if not executePick.pickSuccess then operationLoop;

            action executePlace : ExecutePlaceMotion {
                in placementPose;
                out placeSuccess;
            }

            then action returnToHome {
                doc /* Return manipulator to home position. */
                action moveHome {
                    in targetPose;
                    out motionComplete : Boolean;
                }
            }

            then operationLoop;
            then done;
        }

        satisfy requirement performanceReq : SystemPerformanceRequirement;
        satisfy requirement robustnessReq : RobustnessRequirement;
        satisfy requirement safetyReq : SafetyRequirement;
    }

    state binPickingStateMachine {
        doc /* State machine governing system operational modes. */

        entry; then idle;

        state idle {
            doc /* System ready, awaiting start command. */
        }

        accept startCommand;
        transition first idle then scanning;

        state scanning {
            doc /* Acquiring and processing scene data. */
        }

        accept scanComplete;
        transition first scanning 
            if binPickingSystem.camera.visionOut.objectCount > 0
            then planning;

        transition first scanning 
            if binPickingSystem.camera.visionOut.objectCount == 0
            then idle;

        state planning {
            doc /* Computing grasp and motion plan. */
        }

        accept planComplete;
        transition first planning
            if binPickingSystem.planner.plannerInterface.graspPlan.confidence >= 0.8
            then approaching;

        transition first planning
            if binPickingSystem.planner.plannerInterface.graspPlan.confidence < 0.8
            then scanning;

        state approaching {
            doc /* Moving to pre-grasp position. */
        }

        accept reachedPreGrasp;
        transition first approaching then grasping;

        state grasping {
            doc /* Executing grasp on target object. */
        }

        accept graspComplete;
        transition first grasping
            if binPickingSystem.gripper.gripperControl.graspSuccess
            then lifting;

        transition first grasping
            if not binPickingSystem.gripper.gripperControl.graspSuccess
            then scanning;

        state lifting {
            doc /* Lifting object from bin. */
        }

        accept liftComplete;
        transition first lifting then transporting;

        state transporting {
            doc /* Moving object to placement location. */
        }

        accept transportComplete;
        transition first transporting then placing;

        state placing {
            doc /* Releasing object at target location. */
        }

        accept placeComplete;
        transition first placing then retracting;

        state retracting {
            doc /* Returning to home position. */
        }

        accept retractComplete;
        transition first retracting then scanning;

        state error {
            doc /* Error recovery state. */
        }

        accept systemFault;
        transition first scanning then error;
        transition first planning then error;
        transition first approaching then error;
        transition first grasping then error;
        transition first lifting then error;
        transition first transporting then error;
        transition first placing then error;
        transition first retracting then error;

        accept resetCommand;
        transition first error then idle;
    }
}
