package MobileManipulatorRobot {

    import ISQ::*;
    import ScalarValues::*;

    // ---- Value types with units ----
    value def Mass :> Real { unit 'kg'; }
    value def Length :> Real { unit 'm'; }
    value def Force :> Real { unit 'N'; }
    value def Angle :> Real { unit 'rad'; }
    value def Velocity :> Real { unit 'm/s'; }
    value def AngularVelocity :> Real {> Real { unit 'V'; }
    value def ElectricCurrent :> Real { unit 'A'; }
    value def Energy :> Real { unit 'J'; }
    value def Power :> Real { unit 'W'; }
    value def Time :> Real { unit 's'; }
    value def Percentage :> Real { unit '%'; }

    // ---- Item types ----
    item def PhysicalObject {
        attribute mass : Mass;
        attribute position : Length[3];
    }

    item def TargetObject :> PhysicalObject {
        attribute identifier : String;
    }

    item def Pose {
        attribute position : Length[3];
        attribute orientation : Angle[3];
    }

    item def DetectedObject {
        attribute pose : Pose;
        attribute mass : Mass;
        attribute confidence : Real;
    }

    item def NavigationGoal {
        attribute destination : Pose;
        attribute priority : Integer;
    }

    item def ArmCommand {
        attribute targetPose : Pose;
        attribute maxForce : Force;
    }

    item def GripperCommand {
        attribute openWidth : Length;
        attribute gripForce : Force;
        attribute action : GripperActionType;
    }

    enum def GripperActionType { open; close; hold; }

    item def PowerDemand {
        attribute voltage : Voltage;
        attribute current : ElectricCurrent;
    }

    // ---- Interfaces ----
    interface def PowerInterface {
        end supplier : PowerSupply;
        end consumer : PowerConsumer;
        flow power : Power;
    }

    interface def PerceptionInterface {
        end source : PerceptionProvider;
        end sink : PerceptionReceiver;
        flow detectedObjects : DetectedObject[*];
        flow robotPose : Pose;
    }

    interface def MotionCommandInterface {
        end commander : MotionCommander;
        end executor : MotionExecutor;
        flow navigationGoal : NavigationGoal;
    }

    interface def ManipulationCommandInterface {
        end commander : ManipulationCommander;
        end executor : ManipulationExecutor;
        flow armCommand : ArmCommand;
        flow gripperCommand : GripperCommand;
    }

    // ---- Port definitions ----
    port def PowerOutPort :> PowerSupply {
        out power : Power;
    }
    port def PowerInPort :> PowerConsumer {
        in power : Power;
    }
    port def PerceptionOutPort :> PerceptionProvider {
        out detectedObjects : DetectedObject[*];
        out robotPose : Pose;
    }
    port def PerceptionInPort :> PerceptionReceiver {
        in detectedObjects : DetectedObject[*];
        in robotPose : Pose;
    }
    port def NavCommandOutPort :> MotionCommander {
        out navigationGoal : NavigationGoal;
    }
    port def NavCommandInPort :> MotionExecutor {
        in navigationGoal : NavigationGoal;
    }
    port def ManipCommandOutPort :> ManipulationCommander {
        out armCommand : ArmCommand;
        out gripperCommand : GripperCommand;
    }
    port def ManipCommandInPort :> ManipulationExecutor {
        in armCommand : ArmCommand;
        in gripperCommand : GripperCommand;
    }

    // ---- Battery ----
    part def Battery {
        attribute capacity : Energy = 360000 * [J];
        attribute nominalVoltage : Voltage = 24 * [V];
        attribute chargeLevel : Percentage = 100 * [%];
        attribute maxOutputCurrent : ElectricCurrent = 30 * [A];

        port powerOut : PowerOutPort;

        attribute currentPower : Power;

        state def BatteryStates {
            entry; then Normal;
            state Normal {
                entry chargeLevel > 20 * [%];
            }
            state Low {
                entry chargeLevel <= 20 * [%] & chargeLevel > 5 * [%];
            }
            state Critical {
                entry chargeLevel <= 5 * [%];
            }
            transition from Normal to Low when chargeLevel <= 20 * [%];
            transition from Low to Critical when chargeLevel <= 5 * [%];
            transition from Critical to Low when chargeLevel > 5 * [%];
            transition from Low to Normal when chargeLevel > 20 * [%];
        }

        compute currentPower {
            currentPower = nominalVoltage * maxOutputCurrent * (chargeLevel / 100 * [%]);
        }

        flow powerOut.power = currentPower;
    }

    // ---- Mobile Base ----
    part def MobileBase {
        attribute maxSpeed : Velocity = 1.5 * [m/s];
        attribute wheelbase : Length = 0.5 * [m];
        attribute mass : Mass = 25 * [kg];
        attribute currentPose : Pose;

        port powerIn : PowerInPort;
        port navCommandIn : NavCommandInPort;
        port perceptionOut : PerceptionOutPort;

        part driveMotors {
            attribute count : Integer = 4;
            attribute powerConsumption : Power = 60 * [W];
        }

        part wheelEncoders {
            attribute resolution : Integer = 1024;
        }

        part proximitySensors {
            attribute range : Length = 2.0 * [m];
            attribute fieldOfView : Angle = 3.14 * [rad];
        }

        part localizationUnit {
            attribute updateRate : Real = 10 * [1/s];
        }

        state def BaseStates {
            entry; then Idle;
            state Idle;
            state Navigating;
            state Holding;
            transition from Idle to Navigating when navCommandIn.navigationGoal->notEmpty();
            transition from Navigating to Holding when currentPose == navCommandIn.navigationGoal.destination;
            transition from Holding to Idle when true;
        }

        compute currentPose {
            currentPose = localizationUnit.estimatedPose;
        }

        flow perceptionOut.robotPose = currentPose;
        flow perceptionOut.detectedObjects = proximitySensors.detections;
    }

    // ---- Manipulator Arm ----
    part def ManipulatorArm {
        attribute maxReach : Length = 0.8 * [m];
        attribute maxPayload : Mass = 5 * [kg];
        attribute jointCount : Integer = 6;

        port powerIn : PowerInPort;
        port manipCommandIn : ManipCommandInPort;

        part shoulderJoint {
            attribute range : Angle[2] = (-3.14 * [rad], 3.14 * [rad]);
            attribute maxTorque : Force = 40 * [N];
        }
        part elbowJoint {
            attribute range : Angle[2] = (0 * [rad], 2.09 * [rad]);
            attribute maxTorque : Force = 30 * [N];
        }
        part wristJoint {
            attribute range : Angle[2] = (-3.14 * [rad], 3.14 * [rad]);
            attribute maxTorque : Force = 15 * [N];
        }

        attribute endEffectorPose : Pose;

        compute endEffectorPose {
            endEffectorPose = forwardKinematics(shoulderJoint.angle, elbowJoint.angle, wristJoint.angle);
        }

        action def forwardKinematics(in shoulder : Angle, in elbow : Angle, in wrist : Angle) : Pose;
    }

    // ---- Gripper ----
    part def Gripper {
        attribute maxWidth : Length = 0.08 * [m];
        attribute maxForce : Force = 20 * [N];
        attribute currentWidth : Length;
        attribute appliedForce : Force;

        port powerIn : PowerInPort;
        port manipCommandIn : ManipCommandInPort;

        state def GripperStates {
            entry; then Released;
            state Released {
                entry currentWidth = maxWidth;
            }
            state Grasping;
            state Grasped {
                entry appliedForce >= 5 * [N];
            }
            transition from Released to Grasping when manipCommandIn.gripperCommand.action == GripperActionType::close;
            transition from Grasping to Grasped when appliedForce >= 5 * [N];
            transition from Grasped to Released when manipCommandIn.gripperCommand.action == GripperActionType::open;
        }
    }

    // ---- Perception Module ----
    part def PerceptionModule {
        attribute processingRate : Real = 30 * [1/s];

        port perceptionOut : PerceptionOutPort;

        part camera {
            attribute resolution : String = "1920x1080";
            attribute frameRate : Real = 30 * [1/s];
        }
        part lidar {
            attribute range : Length = 10 * [m];
            attribute angularResolution : Angle = 0.017 * [rad];
        }
        part imu {
            attribute updateRate : Real = 200 * [1/s];
        }

        action def detectObjects(in rawImage : Any, in lidarScan : Any) : DetectedObject[*];
        action def estimatePose(in imuData : Any, in encoderData : Any) : Pose;

        flow perceptionOut.detectedObjects = detectObjects(camera.frame, lidar.scan);
        flow perceptionOut.robotPose = estimatePose(imu.data, wheelEncoderData);
    }

    // ---- Control Computer ----
    part def ControlComputer {
        attribute clockSpeed : Real = 1.6e9 * [1/s];
        attribute memory : Real = 8e9 * [byte];

        port perceptionIn : PerceptionInPort;
        port navCommandOut : NavCommandOutPort;
        port manipCommandOut : ManipCommandOutPort;

        attribute currentGoal : NavigationGoal;
        attribute detectedTarget : DetectedObject;

        action def planPath(in start : Pose, in goal : Pose) : NavigationGoal;
        action def planGrasp(in objectPose : Pose) : ArmCommand;
        action def planGrip(in objectMass : Mass) : GripperCommand;

        state def ControllerStates {
            entry; then Initializing;
            state Initializing;
            state Localizing;
            state NavigatingToPickup;
            state SearchingForObject;
            state ApproachingObject;
            state GraspingObject;
            state NavigatingToDelivery;
            state PlacingObject;
            state ReleasingObject;
            state TaskComplete;

            transition from Initializing to Localizing when perceptionIn.robotPose->notEmpty();
            transition from Localizing to NavigatingToPickup when currentGoal.destination->notEmpty();
            transition from NavigatingToPickup to SearchingForObject when perceptionIn.robotPose == currentGoal.destination;
            transition from SearchingForObject to ApproachingObject when detectedTarget->notEmpty();
            transition from ApproachingObject to GraspingObject when detectedTarget.pose.position closeTo manipulatorArm.endEffectorPose.position;
            transition from GraspingObject to NavigatingToDelivery when gripper.state == GripperStates::Grasped;
            transition from NavigatingToDelivery to PlacingObject when perceptionIn.robotPose == deliveryGoal.destination;
            transition from PlacingObject to ReleasingObject when arm.endEffectorPose == placementPose;
            transition from ReleasingObject to TaskComplete when gripper.state == GripperStates::Released;
        }
    }

    // ---- Top-level Robot ----
    part def MobileManipulatorRobot {
        attribute serialNumber : String;
        attribute manufacturer : String = "AutoBot Inc.";
        attribute model : String = "MMR-5000";

        part battery : Battery;
        part mobileBase : MobileBase;
        part manipulatorArm : ManipulatorArm;
        part gripper : Gripper;
        part perceptionModule : PerceptionModule;
        part controlComputer : ControlComputer;

        // Power distribution
        connection powerToBase : PowerInterface connect battery.powerOut to mobileBase.powerIn;
        connection powerToArm : PowerInterface connect battery.powerOut to manipulatorArm.powerIn;
        connection powerToGripper : PowerInterface connect battery.powerOut to gripper.powerIn;

        // Perception data flow
        connection perceptionToController : PerceptionInterface connect perceptionModule.perceptionOut to controlComputer.perceptionIn;
        connection basePerceptionToController : PerceptionInterface connect mobileBase.perceptionOut to controlComputer.perceptionIn;

        // Command flows
        connection navCommands : MotionCommandInterface connect controlComputer.navCommandOut to mobileBase.navCommandIn;
        connection manipCommands : ManipulationCommandInterface connect controlComputer.manipCommandOut to manipulatorArm.manipCommandIn;
        connection gripperCommands : ManipulationCommandInterface connect controlComputer.manipCommandOut to gripper.manipCommandIn;

        // Mission behavior
        action def PickAndPlaceMission(in pickupLocation : Pose, in deliveryLocation : Pose, in target : TargetObject) {
            action localizeSelf;
            action navigateToPickup;
            action searchForObject;
            action approachObject;
            action graspObject;
            action navigateToDelivery;
            action placeObject;
            action releaseObject;

            flow localizeSelf.outPose -> navigateToPickup.startPose;
            flow navigateToPickup.arrived -> searchForObject.trigger;
            flow searchForObject.detectedTarget -> approachObject.target;
            flow approachObject.inPosition -> graspObject.trigger;
            flow graspObject.secured -> navigateToDelivery.trigger;
            flow navigateToDelivery.arrived -> placeObject.trigger;
            flow placeObject.positioned -> releaseObject.trigger;
            flow releaseObject.released -> done;
        }

        requirement def PickAndPlaceRequirement {
            subject robot : MobileManipulatorRobot;
            objective {
                doc /* The robot shall autonomously pick up a target object and transport it to a delivery location without human intervention. */
            }
            assume {
                doc /* The battery charge level is above 20%. */
            }
        }

        requirement def PayloadCapacityRequirement {
            subject arm : ManipulatorArm;
            attribute maxPayload : Mass = 5 * [kg];
            objective {
                doc /* The manipulator arm shall lift payloads up to 5 kg. */
            }
        }

        requirement def ReachRequirement {
            subject arm : ManipulatorArm;
            attribute minReach : Length = 0.8 * [m];
            objective {
                doc /* The manipulator arm shall have a reach of at least 0.8 m. */
            }
        }

        requirement def GripperRequirement {
            subject gripper : Gripper;
            attribute minMaxWidth : Length = 0.08 * [m];
            attribute minGripForce : Force = 5 * [N];
            objective {
                doc /* The gripper shall open to at least 80 mm and apply at least 5 N of force to securely grasp objects. */
            }
        }

        requirement def NavigationRequirement {
            subject base : MobileBase;
            attribute minSpeed : Velocity = 1.0 * [m/s];
            objective {
                doc /* The mobile base shall navigate autonomously at speeds up to 1.5 m/s while avoiding obstacles. */
            }
        }

        requirement def PowerRequirement {
            subject battery : Battery;
            attribute minRuntime : Time = 14400 * [s];
            objective {
                doc /* The battery shall power all subsystems for at least 4 hours of continuous operation. */
            }
        }

        requirement def PerceptionRequirement {
            subject perception : PerceptionModule;
            attribute minDetectionRange : Length = 2.0 * [m];
            objective {
                doc /* The perception module shall detect manipulable objects within at least 2 m of the robot. */
            }
        }

        satisfy PickAndPlaceRequirement by robot;
        satisfy PayloadCapacityRequirement by manipulatorArm;
        satisfy ReachRequirement by manipulatorArm;
        satisfy GripperRequirement by gripper;
        satisfy NavigationRequirement by mobileBase;
        satisfy PowerRequirement by battery;
        satisfy PerceptionRequirement by perceptionModule;
    }
}
