package MobileManipulatorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def Position3D {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
    }
    
    attribute def Orientation {
        attribute roll : Real;
        attribute pitch : Real;
        attribute yaw : Real;
    }
    
    attribute def Pose {
        attribute position : Position3D;
        attribute orientation : Orientation;
    }
    
    attribute def JointConfiguration {
        attribute shoulder : Real;
        attribute elbow : Real;
        attribute wrist : Real;
        attribute gripper : LengthValue;
    }
    
    item def Payload {
        attribute mass : MassValue;
        attribute dimensions : Position3D;
        attribute graspable : Boolean;
    }
    
    port def SensorDataPort {
        out currentPose : Pose;
        out detectedObjects : Payload[*];
        out batteryLevel : Real;
    }
    
    port def MotionCommandPort {
        in targetPose : Pose;
        in targetVelocity : SpeedValue;
    }
    
    port def ArmCommandPort {
        in targetJoints : JointConfiguration;
        in graspForce : ForceValue;
    }
    
    port def PowerPort {
        attribute voltage : Real;
        attribute current : Real;
    }
    
    part def Battery {
        attribute capacity : EnergyValue;
        attribute currentCharge : EnergyValue;
        attribute outputVoltage : Real;
        port powerOut : PowerPort;
    }
    
    part def MobileBase {
        attribute currentPose : Pose;
        attribute maxSpeed : SpeedValue;
        attribute wheelDiameter : LengthValue;
        port motionCmd : MotionCommandPort;
        port powerIn : PowerPort;
        port sensors : SensorDataPort;
    }
    
    part def ManipulatorArm {
        attribute jointConfig : JointConfiguration;
        attribute maxReach : LengthValue;
        attribute maxPayload : MassValue;
        port armCmd : ArmCommandPort;
        port powerIn : PowerPort;
    }
    
    part def Gripper {
        attribute openingWidth : LengthValue;
        attribute graspForce : ForceValue;
        attribute isGrasping : Boolean;
        port powerIn : PowerPort;
    }
    
    part def PerceptionModule {
        attribute detectionRange : LengthValue;
        attribute fieldOfView : Real;
        port sensorOut : SensorDataPort;
        port powerIn : PowerPort;
    }
    
    part def ControlComputer {
        attribute processingPower : Real;
        port sensorIn : SensorDataPort;
        port baseCmd : MotionCommandPort;
        port armCmd : ArmCommandPort;
        port powerIn : PowerPort;
    }
    
    action def LocalizeRobot {
        in sensorData : Pose;
        out estimatedPose : Pose;
    }
    
    action def DetectTargetObject {
        in scanArea : Position3D;
        out detectedPayload : Payload;
        out objectPose : Pose;
    }
    
    action def PlanNavigationPath {
        in startPose : Pose;
        in goalPose : Pose;
        out waypoints : Pose[*];
    }
    
    action def ExecuteNavigation {
        in pathWaypoints : Pose[*];
        in maxVelocity : SpeedValue;
        out finalPose : Pose;
        out navigationSuccess : Boolean;
    }
    
    action def PlanArmMotion {
        in currentJoints : JointConfiguration;
        in targetPosition : Position3D;
        out trajectoryJoints : JointConfiguration[*];
    }
    
    action def ExecuteArmMotion {
        in jointTrajectory : JointConfiguration[*];
        out finalJoints : JointConfiguration;
        out motionSuccess : Boolean;
    }
    
    action def GraspObject {
        in targetForce : ForceValue;
        in targetWidth : LengthValue;
        out graspSuccess : Boolean;
    }
    
    action def ReleaseObject {
        in releaseWidth : LengthValue;
        out releaseSuccess : Boolean;
    }
    
    action def PickAndPlaceMission {
        in pickupLocation : Position3D;
        in deliveryLocation : Position3D;
        out missionSuccess : Boolean;
        
        attribute robotPose : Pose;
        attribute targetObject : Payload;
        attribute objectLocation : Pose;
        attribute armJoints : JointConfiguration;
        
        first start;
        
        then action localize : LocalizeRobot {
            out estimatedPose;
        }
        then assign robotPose := localize.estimatedPose;
        
        then action detectObject : DetectTargetObject {
            in scanArea = pickupLocation;
            out detectedPayload;
            out objectPose;
        }
        then assign targetObject := detectObject.detectedPayload;
        then assign objectLocation := detectObject.objectPose;
        
        then action planPathToPickup : PlanNavigationPath {
            in startPose = robotPose;
            in goalPose = objectLocation;
            out waypoints;
        }
        
        then action navigateToPickup : ExecuteNavigation {
            in pathWaypoints = planPathToPickup.waypoints;
            in maxVelocity = 0.5 [m/s];
            out finalPose;
            out navigationSuccess;
        }
        
        then decide;
            if navigateToPickup.navigationSuccess then planReach;
            if not navigateToPickup.navigationSuccess then failMission;
        
        action planReach : PlanArmMotion {
            in targetPosition = pickupLocation;
            out trajectoryJoints;
        }
        
        then action reachObject : ExecuteArmMotion {
            in jointTrajectory = planReach.trajectoryJoints;
            out finalJoints;
            out motionSuccess;
        }
        then assign armJoints := reachObject.finalJoints;
        
        then decide;
            if reachObject.motionSuccess then graspPayload;
            if not reachObject.motionSuccess then failMission;
        
        action graspPayload : GraspObject {
            in targetForce = 50.0 [N];
            in targetWidth = 0.05 [m];
            out graspSuccess;
        }
        
        then decide;
            if graspPayload.graspSuccess then planPathToDelivery;
            if not graspPayload.graspSuccess then failMission;
        
        action planPathToDelivery : PlanNavigationPath {
            in startPose = navigateToPickup.finalPose;
            in goalPose {
                attribute position = deliveryLocation;
            }
            out waypoints;
        }
        
        then action navigateToDelivery : ExecuteNavigation {
            in pathWaypoints = planPathToDelivery.waypoints;
            in maxVelocity = 0.4 [m/s];
            out finalPose;
            out navigationSuccess;
        }
        
        then decide;
            if navigateToDelivery.navigationSuccess then planPlace;
            if not navigateToDelivery.navigationSuccess then failMission;
        
        action planPlace : PlanArmMotion {
            in targetPosition = deliveryLocation;
            out trajectoryJoints;
        }
        
        then action placeObject : ExecuteArmMotion {
            in jointTrajectory = planPlace.trajectoryJoints;
            out finalJoints;
            out motionSuccess;
        }
        
        then decide;
            if placeObject.motionSuccess then releasePayload;
            if not placeObject.motionSuccess then failMission;
        
        action releasePayload : ReleaseObject {
            in releaseWidth = 0.15 [m];
            out releaseSuccess;
        }
        
        then decide;
            if releasePayload.releaseSuccess then succeedMission;
            if not releasePayload.releaseSuccess then failMission;
        
        action succeedMission;
        then assign missionSuccess := true;
        then done;
        
        action failMission;
        then assign missionSuccess := false;
        then done;
    }
    
    part def MobileManipulator {
        doc /* A mobile manipulator integrates a mobile base with a robotic arm 
               to perform autonomous pick-and-place operations in dynamic environments. */
        
        part base : MobileBase {
            attribute :>> maxSpeed = 1.0 [m/s];
            attribute :>> wheelDiameter = 0.2 [m];
        }
        
        part arm : ManipulatorArm {
            attribute :>> maxReach = 0.8 [m];
            attribute :>> maxPayload = 5.0 [kg];
        }
        
        part gripper : Gripper {
            attribute :>> openingWidth = 0.12 [m];
            attribute :>> graspForce = 100.0 [N];
        }
        
        part perception : PerceptionModule {
            attribute :>> detectionRange = 5.0 [m];
            attribute :>> fieldOfView = 120.0;
        }
        
        part controller : ControlComputer {
            attribute :>> processingPower = 2.5;
        }
        
        part battery : Battery {
            attribute :>> capacity = 500.0 [W*h];
            attribute :>> currentCharge = 450.0 [W*h];
            attribute :>> outputVoltage = 24.0;
        }
        
        connection powerBase connect battery.powerOut to base.powerIn;
        connection powerArm connect battery.powerOut to arm.powerIn;
        connection powerGripper connect battery.powerOut to gripper.powerIn;
        connection powerPerception connect battery.powerOut to perception.powerIn;
        connection powerController connect battery.powerOut to controller.powerIn;
        
        connection sensorFeedback connect perception.sensorOut to controller.sensorIn;
        connection baseControl connect controller.baseCmd to base.motionCmd;
        connection armControl connect controller.armCmd to arm.armCmd;
    }
    
    part mobileManipulatorSystem : MobileManipulator {
        perform action mission[*] ordered : PickAndPlaceMission {
            in pickupLocation {
                attribute x = 2.0 [m];
                attribute y = 1.5 [m];
                attribute z = 0.3 [m];
            }
            in deliveryLocation {
                attribute x = 5.0 [m];
                attribute y = 3.0 [m];
                attribute z = 0.5 [m];
            }
            out missionSuccess;
        }
    }
    
    requirement def AutonomousOperationRequirement {
        doc /* The mobile manipulator shall autonomously navigate to target locations 
               and manipulate objects without human intervention. */
        subject system : MobileManipulator;
    }
    
    requirement def MobilityRequirement {
        doc /* The mobile base shall navigate at speeds up to 1.0 m/s while carrying 
               the manipulator and payload. */
        subject mobileBase : MobileBase;
        require constraint {
            mobileBase.maxSpeed >= 0.8 [m/s]
        }
    }
    
    requirement def ManipulationRequirement {
        doc /* The manipulator arm shall reach objects within 0.8 m radius and handle 
               payloads up to 5 kg. */
        subject manipulator : ManipulatorArm;
        require constraint {
            manipulator.maxReach >= 0.6 [m] and
            manipulator.maxPayload >= 3.0 [kg]
        }
    }
    
    requirement def GraspingRequirement {
        doc /* The gripper shall securely grasp objects with forces between 20 N and 100 N 
               and accommodate object widths from 0.02 m to 0.12 m. */
        subject endEffector : Gripper;
        require constraint {
            endEffector.graspForce >= 20.0 [N] and
            endEffector.graspForce <= 100.0 [N] and
            endEffector.openingWidth >= 0.02 [m] and
            endEffector.openingWidth <= 0.12 [m]
        }
    }
    
    requirement def PerceptionRequirement {
        doc /* The perception system shall detect objects within 5 m range with 
               a field of view of at least 90 degrees. */
        subject sensor : PerceptionModule;
        require constraint {
            sensor.detectionRange >= 3.0 [m] and
            sensor.fieldOfView >= 90.0
        }
    }
    
    requirement def BatteryRequirement {
        doc /* The battery shall provide sufficient energy for at least 2 hours 
               of continuous operation. */
        subject powerSource : Battery;
        require constraint {
            powerSource.capacity >= 400.0 [W*h]
        }
    }
    
    requirement primaryMissionRequirement {
        doc /* The mobile manipulator shall autonomously pick up objects from designated 
               pickup locations and deliver them to specified delivery locations within 
               its operational workspace. */
        
        subject system : MobileManipulator;
        
        assume autonomousOp : AutonomousOperationRequirement {
            subject system = mobileManipulatorSystem;
        }
        
        require mobilityReq : MobilityRequirement {
            subject mobileBase = mobileManipulatorSystem.base;
        }
        
        require manipulationReq : ManipulationRequirement {
            subject manipulator = mobileManipulatorSystem.arm;
        }
        
        require graspingReq : GraspingRequirement {
            subject endEffector = mobileManipulatorSystem.gripper;
        }
        
        require perceptionReq : PerceptionRequirement {
            subject sensor = mobileManipulatorSystem.perception;
        }
        
        require batteryReq : BatteryRequirement {
            subject powerSource = mobileManipulatorSystem.battery;
        }
    }
}
