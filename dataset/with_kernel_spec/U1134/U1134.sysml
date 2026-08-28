package MobileManipulatorRobot {
    attribute def MassValue :> ScalarValues::Real;
    attribute def DistanceValue :> ScalarValues::Real;
    attribute def ForceValue :> ScalarValues::Real;
    attribute def VoltageValue :> ScalarValues::Real;
    attribute def EnergyValue :> ScalarValues::Real;
    attribute def AngleValue :> ScalarValues::Real;
    attribute def LinearVelocityValue :> ScalarValues::Real;
    attribute def AngularVelocityValue :> ScalarValues::Real;

    item def PhysicalObject;
    item def TargetObject :> PhysicalObject;

    attribute def Pose {
        attribute x : DistanceValue;
        attribute y : DistanceValue;
        attribute theta : AngleValue;
    }

    attribute def DriveCommand {
        attribute linearVelocity : LinearVelocityValue;
        attribute angularVelocity : AngularVelocityValue;
    }

    attribute def ArmCommand {
        attribute shoulderAngle : AngleValue;
        attribute elbowAngle : AngleValue;
        attribute wristAngle : AngleValue;
    }

    attribute def GripperCommand {
        attribute openingWidth : DistanceValue;
        attribute gripForce : ForceValue;
    }

    attribute def SensorData {
        attribute robotPose : Pose;
        attribute detectedObjects : TargetObject[*];
        attribute obstacleDetected : ScalarValues::Boolean;
    }

    attribute def MissionParameters {
        attribute pickupLocation : Pose;
        attribute deliveryLocation : Pose;
        attribute targetObject : TargetObject;
    }

    part def Battery {
        attribute capacity : EnergyValue = 500;
        attribute stateOfCharge : ScalarValues::Real = 1.0;
        port powerOut {
            out voltage : VoltageValue;
        }
        perform action supplyPower {
            first start;
            then done;
        }
    }

    part def PoweredComponent {
        port powerIn {
            in voltage : VoltageValue;
        }
    }

    part def MobileBase :> PoweredComponent {
        attribute currentPose : Pose;
        port driveCmdIn {
            in cmd : DriveCommand;
        }
        port poseOut {
            out pose : Pose;
        }
        port detectionOut {
            out detectedObjects : TargetObject[*];
            out obstacleDetected : ScalarValues::Boolean;
        }
        perform action navigate {
            in cmd : DriveCommand;
            first start;
            then done;
        }
    }

    part def Joint {
        attribute currentAngle : AngleValue;
        attribute targetAngle : AngleValue;
        port powerIn {
            in voltage : VoltageValue;
        }
    }

    part def ManipulatorArm :> PoweredComponent {
        part shoulder : Joint;
        part elbow : Joint;
        part wrist : Joint;
        attribute maxReach : DistanceValue = 1.2;
        attribute payloadCapacity : MassValue = 5;
        port armCmdIn {
            in cmd : ArmCommand;
        }
        port armPoseOut {
            out endEffectorPose : Pose;
        }
        perform action moveArm {
            in cmd : ArmCommand;
            first start;
            then done;
        }
    }

    part def Gripper :> PoweredComponent {
        attribute maxOpeningWidth : DistanceValue = 0.15;
        attribute maxGripForce : ForceValue = 50;
        attribute currentWidth : DistanceValue;
        attribute isHolding : ScalarValues::Boolean = false;
        port gripperCmdIn {
            in cmd : GripperCommand;
        }
        port gripStatusOut {
            out isHolding : ScalarValues::Boolean;
            out currentWidth : DistanceValue;
        }
        perform action actuateGripper {
            in cmd : GripperCommand;
            first start;
            then done;
        }
    }

    part def PerceptionModule :> PoweredComponent {
        port poseIn {
            in pose : Pose;
        }
        port detectionIn {
            in detectedObjects : TargetObject[*];
            in obstacleDetected : ScalarValues::Boolean;
        }
        port sensorDataOut {
            out data : SensorData;
        }
        perform action perceive {
            first start;
            then done;
        }
    }

    part def ControlComputer :> PoweredComponent {
        port perceptionIn {
            in data : SensorData;
        }
        port gripperStatusIn {
            in isHolding : ScalarValues::Boolean;
            in currentWidth : DistanceValue;
        }
        port driveCmdOut {
            out cmd : DriveCommand;
        }
        port armCmdOut {
            out cmd : ArmCommand;
        }
        port gripperCmdOut {
            out cmd : GripperCommand;
        }
        perform action control {
            first start;
            then done;
        }
    }

    state machine def PickAndPlaceStateMachine {
        state Idle;
        state NavigatingToPickup;
        state LocatingObject;
        state ApproachingObject;
        state Grasping;
        state NavigatingToDelivery;
        state Placing;
        transition from Idle to NavigatingToPickup;
        transition from NavigatingToPickup to LocatingObject;
        transition from LocatingObject to ApproachingObject;
        transition from ApproachingObject to Grasping;
        transition from Grasping to NavigatingToDelivery;
        transition from NavigatingToDelivery to Placing;
        transition from Placing to Idle;
    }

    action def PickAndPlaceMission {
        in params : MissionParameters;
        first start;
        then action determineLocation {
            out currentPose : Pose;
        }
        then action navigateToPickup {
            in target : Pose;
        }
        then action detectTarget {
            out foundObjects : TargetObject[*];
        }
        then action moveArmToTarget {
            in target : TargetObject;
        }
        then action graspObject {
            out secured : ScalarValues::Boolean;
        }
        then action navigateToDelivery {
            in target : Pose;
        }
        then action placeObject {
            out released : ScalarValues::Boolean;
        }
        then done;
    }

    requirement def PayloadCapacityRequirement {
        subject arm : ManipulatorArm;
        attribute maxPayload : MassValue = 5;
        require arm.payloadCapacity >= maxPayload;
    }

    requirement def ReachRequirement {
        subject arm : ManipulatorArm;
        attribute minReach : DistanceValue = 1.2;
        require arm.maxReach >= minReach;
    }

    requirement def GripperForceRequirement {
        subject gripper : Gripper;
        attribute maxForce : ForceValue = 50;
        require gripper.maxGripForce <= maxForce;
    }

    requirement def GripperWidthRequirement {
        subject gripper : Gripper;
        attribute minWidth : DistanceValue = 0.15;
        require gripper.maxOpeningWidth >= minWidth;
    }

    requirement def PickAndPlaceCapability {
        doc /* The robot shall autonomously pick up an object from a pickup location and place it at a delivery location without human intervention. */;
    }

    requirement def BatteryPowerRequirement {
        doc /* The battery shall supply power to all robot components including the base, arm, gripper, perception module, and control computer. */;
    }

    part def MobileManipulatorRobot {
        part battery : Battery;
        part base : MobileBase;
        part arm : ManipulatorArm {
            satisfy PayloadCapacityRequirement;
            satisfy ReachRequirement;
        }
        part gripper : Gripper {
            satisfy GripperForceRequirement;
            satisfy GripperWidthRequirement;
        }
        part perception : PerceptionModule;
        part computer : ControlComputer;

        connect battery.powerOut to base.powerIn;
        connect battery.powerOut to arm.powerIn;
        connect battery.powerOut to gripper.powerIn;
        connect battery.powerOut to perception.powerIn;
        connect battery.powerOut to computer.powerIn;

        connect base.poseOut to perception.poseIn;
        connect base.detectionOut to perception.detectionIn;
        connect perception.sensorDataOut to computer.perceptionIn;

        connect computer.driveCmdOut to base.driveCmdIn;
        connect computer.armCmdOut to arm.armCmdIn;
        connect computer.gripperCmdOut to gripper.gripperCmdIn;

        connect gripper.gripStatusOut to computer.gripperStatusIn;

        exhibit pickAndPlaceSM : PickAndPlaceStateMachine;
        satisfy PickAndPlaceCapability;
        satisfy BatteryPowerRequirement;

        perform action pickAndPlace : PickAndPlaceMission;
    }
}
