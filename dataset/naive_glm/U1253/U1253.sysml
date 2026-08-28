package PickAndPlaceSystem {
    import ScalarValues::*;
    import QuantityCalculations::*;

    package Units {
        attribute def MeterUnit :> Unit { }
        attribute def NewtonUnit :> Unit { }
        attribute def DegreeUnit :> Unit { }
        attribute def SecondUnit :> Unit { }
        attribute def MeterPerSecondUnit :> Unit { }
        attribute def PercentUnit :> Unit { }
    }

    package ValueTypes {
        value type Length :> Real {
            unit Units::MeterUnit;
        }
        value type Force :> Real {
            unit Units::NewtonUnit;
        }
        value type Angle :> Real {
            unit Units::DegreeUnit;
        }
        value type Duration :> Real {
            unit Units::SecondUnit;
        }
        value type Velocity :> Real {
            unit Units::MeterPerSecondUnit;
        }
        value type Confidence :> Real {
            unit Units::PercentUnit;
        }
    }

    package Items {
        item def Image {
            attribute width : Integer = 1920;
            attribute height : Integer = 1080;
            attribute timestamp : Duration;
        }

        item def ObjectClass :> String;

        item def DetectedObject {
            attribute objectClass : ObjectClass;
            attribute posX : Length;
            attribute posY : Length;
            attribute posZ : Length;
            attribute roll : Angle;
            attribute pitch : Angle;
            attribute yaw : Angle;
            attribute sizeX : Length;
            attribute sizeY : Length;
            attribute sizeZ : Length;
            attribute confidence : Confidence;
        }

        item def SceneAnalysis {
            attribute detectedObjects : DetectedObject[0..*];
            attribute processingTime : Duration;
        }

        item def Waypoint {
            attribute joint1 : Angle;
            attribute joint2 : Angle;
            attribute joint3 : Angle;
            attribute joint4 : Angle;
            attribute joint5 : Angle;
            attribute joint6 : Angle;
            attribute timestamp : Duration;
        }

        item def Trajectory {
            attribute waypoints : Waypoint[0..*];
            attribute isCollisionFree : Boolean;
            attribute estimatedDuration : Duration;
        }

        item def GraspParameters {
            attribute gripForce : Force;
            attribute jawOpening : Length;
        }
    }

    package Requirements {
        requirement def VisionIdentification {
            doc "The system shall visually identify target objects in the workspace and determine their class, 3D position, orientation, and detection confidence.";
            subject visionProcessor;
            attribute minConfidence : Confidence = 0.85;
            require { visionProcessor.lastConfidence >= minConfidence; }
        }

        requirement def PathPlanning {
            doc "The motion planner shall select the best object to pick and calculate a collision-free trajectory from the arm's current position to the target.";
            subject motionPlanner;
            require { motionPlanner.lastTrajectory.isCollisionFree == true; }
        }

        requirement def GraspExecution {
            doc "The gripper shall grasp the target object using grasp parameters determined from the object's identified shape and size.";
            subject gripper;
            attribute minGripForce : Force = 10.0;
            require { gripper.appliedForce >= minGripForce; }
        }

        requirement def PlacementCompletion {
            doc "The system shall transport the grasped object to a predefined placement zone and release it.";
            subject system;
            require { system.placementZoneReached == true; }
        }

        requirement def CycleReturn {
            doc "After successfully placing an object, the system shall return to a standby state ready for the next cycle.";
            subject system;
            require { system.currentState == "standby"; }
        }

        requirement def ErrorHandling {
            doc "The system shall enter an error-handling state upon any failure during the pick-and-place cycle and shall return to standby after the error is resolved.";
            subject system;
            require { system.errorHandled == true; }
        }
    }

    package Components {
        part def Camera {
            port imageOut : ~Items::Image;
            attribute resolution : String = "1920x1080";
            attribute frameRate : Real = 30.0;
            attribute trigger : Boolean = false;
            attribute imageCaptured : Boolean = false;
            action def CaptureImage {
                out image : Items::Image;
            }
            perform action capture : CaptureImage {
                when trigger == true then imageCaptured := true;
            }
        }

        part def VisionProcessor {
            port imageIn : Items::Image;
            port analysisOut : ~Items::SceneAnalysis;
            attribute algorithm : String = "DeepLearningCNN";
            attribute lastConfidence : Confidence = 0.0;
            attribute imageReceived : Boolean = false;
            attribute objectDetected : Boolean = false;
            action def ProcessImage {
                in image : Items::Image;
                out analysis : Items::SceneAnalysis;
            }
            perform action process : ProcessImage {
                when imageReceived == true then {
                    objectDetected := true;
                    lastConfidence := 0.92;
                }
            }
        }

        part def MotionPlanner {
            port analysisIn : Items::SceneAnalysis;
            port trajectoryOut : ~Items::Trajectory;
            attribute lastTrajectory : Items::Trajectory;
            attribute analysisReceived : Boolean = false;
            attribute trajectoryReady : Boolean = false;
            action def PlanMotion {
                in analysis : Items::SceneAnalysis;
                out trajectory : Items::Trajectory;
            }
            perform action plan : PlanMotion {
                when analysisReceived == true then {
                    trajectoryReady := true;
                }
            }
        }

        part def RoboticArm {
            port trajectoryIn : Items::Trajectory;
            port gripperCommandOut : ~Items::GraspParameters;
            attribute jointCount : Integer = 6;
            attribute joint1 : Angle;
            attribute joint2 : Angle;
            attribute joint3 : Angle;
            attribute joint4 : Angle;
            attribute joint5 : Angle;
            attribute joint6 : Angle;
            attribute maxReach : Length = 1.2;
            attribute maxVelocity : Velocity = 2.0;
            attribute reachedTarget : Boolean = false;
            attribute trajectoryReceived : Boolean = false;
            action def ExecuteTrajectory {
                in trajectory : Items::Trajectory;
            }
            perform action execute : ExecuteTrajectory {
                when trajectoryReceived == true then reachedTarget := true;
            }
        }

        part def Gripper {
            port graspIn : Items::GraspParameters;
            attribute appliedForce : Force;
            attribute jawOpening : Length;
            attribute isClosed : Boolean = false;
            attribute objectGrasped : Boolean = false;
            attribute objectReleased : Boolean = false;
            action def Grasp {
                in params : Items::GraspParameters;
            }
            action def Release { }
            perform action graspAction : Grasp {
                when graspIn.received == true then {
                    appliedForce := graspIn.gripForce;
                    jawOpening := graspIn.jawOpening;
                    isClosed := true;
                    objectGrasped := true;
                }
            }
            perform action releaseAction : Release {
                when objectGrasped == true then {
                    isClosed := false;
                    objectReleased := true;
                }
            }
        }
    }

    part def PickAndPlaceRobot {
        part camera : Components::Camera;
        part visionProcessor : Components::VisionProcessor;
        part motionPlanner : Components::MotionPlanner;
        part arm : Components::RoboticArm;
        part gripper : Components::Gripper;

        attribute currentState : String = "standby";
        attribute cycleCount : Integer = 0;
        attribute error : Boolean = false;
        attribute errorResolved : Boolean = false;
        attribute errorHandled : Boolean = false;
        attribute placementZoneReached : Boolean = false;

        connection camera.imageOut to visionProcessor.imageIn;
        connection visionProcessor.analysisOut to motionPlanner.analysisIn;
        connection motionPlanner.trajectoryOut to arm.trajectoryIn;
        connection arm.gripperCommandOut to gripper.graspIn;

        state machine def OperationStates {
            state standby {
                entry then camera.trigger := true;
            }
            state imaging {
                entry then camera.trigger := true;
            }
            state processing;
            state moving;
            state grasping;
            state placing;
            state errorHandling {
                entry then errorHandled := false;
                do then errorResolved := true;
            }

            transition standby to imaging
                when camera.trigger == true;
            transition imaging to processing
                when camera.imageCaptured == true;
            transition processing to moving
                when visionProcessor.objectDetected == true;
            transition moving to grasping
                when arm.reachedTarget == true;
            transition grasping to placing
                when gripper.objectGrasped == true;
            transition placing to standby
                when gripper.objectReleased == true {
                    then cycleCount := cycleCount + 1;
                    then placementZoneReached := true;
                    then gripper.objectReleased := false;
                    then gripper.objectGrasped := false;
                    then arm.reachedTarget := false;
                    then visionProcessor.objectDetected := false;
                    then camera.imageCaptured := false;
                }
            transition standby to errorHandling
                when error == true;
            transition imaging to errorHandling
                when error == true;
            transition processing to errorHandling
                when error == true;
            transition moving to errorHandling
                when error == true;
            transition grasping to errorHandling
                when error == true;
            transition placing to errorHandling
                when error == true;
            transition errorHandling to standby
                when errorResolved == true {
                    then errorHandled := true;
                    then error := false;
                    then errorResolved := false;
                }
        }

        perform state machine operation : OperationStates;

        satisfy req1 : Requirements::VisionIdentification by visionProcessor;
        satisfy req2 : Requirements::PathPlanning by motionPlanner;
        satisfy req3 : Requirements::GraspExecution by gripper;
        satisfy req4 : Requirements::PlacementCompletion by self;
        satisfy req5 : Requirements::CycleReturn by self;
        satisfy req6 : Requirements::ErrorHandling by self;
    }
}
