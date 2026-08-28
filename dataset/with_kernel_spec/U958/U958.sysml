package RoboticManufacturingCell {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def PartPose {
        attribute x : ISQ::LengthValue;
        attribute y : ISQ::LengthValue;
        attribute z : ISQ::LengthValue;
        attribute roll : ISQ::PlaneAngleValue;
        attribute pitch : ISQ::PlaneAngleValue;
        attribute yaw : ISQ::PlaneAngleValue;
    }

    item def RobotMoveCommand {
        attribute targetPose : PartPose;
        attribute velocity : ISQ::SpeedValue;
        attribute acceleration : ISQ::AccelerationValue;
    }

    enum def GripperMode {
        enum open;
        enum close;
        enum hold;
    }

    item def GripperCommand {
        attribute mode : GripperMode;
        attribute force : ISQ::ForceValue;
    }

    item def ConveyorCommand {
        attribute speed : ISQ::SpeedValue;
        attribute enabled : ScalarValues::Boolean;
    }

    item def PartDetected {
        attribute pose : PartPose;
        attribute confidence : ScalarValues::Real;
    }

    item def RobotStatus {
        attribute currentPose : PartPose;
        attribute moving : ScalarValues::Boolean;
        attribute faulted : ScalarValues::Boolean;
    }

    item def GripperStatus {
        attribute isGripping : ScalarValues::Boolean;
        attribute force : ISQ::ForceValue;
    }

    item def ConveyorStatus {
        attribute running : ScalarValues::Boolean;
        attribute speed : ISQ::SpeedValue;
        attribute partPresent : ScalarValues::Boolean;
    }

    attribute def StartProductionSignal;
    attribute def StopProductionSignal;
    attribute def EmergencyStopSignal;
    attribute def ResetEmergencySignal;
    attribute def SwitchToManualSignal;
    attribute def SwitchToMaintenanceSignal;
    attribute def SwitchToAutomaticSignal;
    attribute def PartReadySignal;
    attribute def PickCompleteSignal;
    attribute def PlaceCompleteSignal;
    attribute def LightCurtainBreachSignal;
    attribute def ResetLightCurtainSignal;

    port def RobotControlPort {
        out cmd : RobotMoveCommand;
        in status : RobotStatus;
    }

    port def GripperControlPort {
        out cmd : GripperCommand;
        in status : GripperStatus;
    }

    port def VisionOutputPort {
        out detected : PartDetected;
    }

    port def ConveyorControlPort {
        out cmd : ConveyorCommand;
        in status : ConveyorStatus;
    }

    port def SafetyStatusPort {
        out eStopActive : ScalarValues::Boolean;
        out lightCurtainBreached : ScalarValues::Boolean;
    }

    port def PowerOutputPort {
        out voltage : ISQ::ElectricPotentialValue;
        out current : ISQ::ElectricCurrentValue;
    }

    port def PowerInputPort {
        in voltage : ISQ::ElectricPotentialValue;
        in current : ISQ::ElectricCurrentValue;
    }

    action def MoveTo {
        in targetPose : PartPose;
        out achievedPose : PartPose;
    }

    action def GripPart {
        in force : ISQ::ForceValue;
        out gripped : ScalarValues::Boolean;
    }

    action def ReleasePart {
        out released : ScalarValues::Boolean;
    }

    action def HaltMotion;

    action def CaptureAndProcess {
        out detected : PartDetected;
    }

    action def PlanPath {
        in targetPose : PartPose;
        out moveCmd : RobotMoveCommand;
    }

    action def RunProduction;

    action def StartConveyor;
    action def StopConveyor;
    action def TransportPart;

    action def MonitorSafety {
        out eStopActive : ScalarValues::Boolean;
        out lightCurtainBreached : ScalarValues::Boolean;
    }

    action def HaltAllMotion;
    action def SupplyPower;

    action def PickAndPlace {
        in componentPose : PartPose;
        in placePose : PartPose;
        action capture : CaptureAndProcess;
        action planPick : PlanPath;
        action movePick : MoveTo;
        action grip : GripPart;
        action planPlace : PlanPath;
        action movePlace : MoveTo;
        action release : ReleasePart;
        first capture;
        then planPick;
        then movePick;
        then grip;
        then planPlace;
        then movePlace;
        then release;
        then done;
    }

    part def ABBIRB6700 {
        attribute maxPayload : ISQ::MassValue = 200 [SI::kg];
        attribute reach : ISQ::LengthValue = 2.6 [SI::m];
        attribute currentPose : PartPose;
        port controlPort : RobotControlPort;
        port powerInput : PowerInputPort;
        perform action moveTo : MoveTo;
        perform action haltMotion : HaltMotion;
    }

    part def GripperEndEffector {
        attribute maxGrippingForce : ISQ::ForceValue = 500 [SI::N];
        port controlPort : GripperControlPort;
        port powerInput : PowerInputPort;
        perform action grip : GripPart;
        perform action release : ReleasePart;
    }

    part def ConveyorSystem {
        attribute maxSpeed : ISQ::SpeedValue = 1.0 [m/s];
        port controlPort : ConveyorControlPort;
        port powerInput : PowerInputPort;
        perform action startBelt : StartConveyor;
        perform action stopBelt : StopConveyor;
        perform action transportPart : TransportPart;
    }

    part def VisionSystem {
        attribute accuracy : ISQ::LengthValue = 0.5 [SI::mm];
        port outputPort : VisionOutputPort;
        port powerInput : PowerInputPort;
        perform action captureAndProcess : CaptureAndProcess;
    }

    part def RobotController {
        port robotPort : RobotControlPort;
        port gripperPort : GripperControlPort;
        port visionPort : VisionOutputPort;
        port conveyorPort : ConveyorControlPort;
        port safetyPort : SafetyStatusPort;
        port powerInput : PowerInputPort;
        perform action runProduction : RunProduction;
        perform action planPath : PlanPath;
        perform action monitorSafety : MonitorSafety;
        exhibit state controllerStates {
            entry; then automatic;
            state automatic {
                do runProduction;
            }
            accept SwitchToManualSignal then manual;
            accept SwitchToMaintenanceSignal then maintenance;
            accept EmergencyStopSignal then emergency_stop;
            state manual;
            accept SwitchToAutomaticSignal then automatic;
            accept SwitchToMaintenanceSignal then maintenance;
            accept EmergencyStopSignal then emergency_stop;
            state maintenance;
            accept SwitchToAutomaticSignal then automatic;
            accept EmergencyStopSignal then emergency_stop;
            state emergency_stop;
            accept ResetEmergencySignal then automatic;
        }
    }

    part def SafetySystem {
        attribute eStopActive : ScalarValues::Boolean = false;
        attribute lightCurtainBreached : ScalarValues::Boolean = false;
        port statusPort : SafetyStatusPort;
        port powerInput : PowerInputPort;
        perform action monitor : MonitorSafety;
        perform action haltAll : HaltAllMotion;
        exhibit state safetyStates {
            entry; then normal;
            state normal;
            accept EmergencyStopSignal then eStopActiveState;
            accept LightCurtainBreachSignal then lightCurtainBreachedState;
            state eStopActiveState {
                entry haltAll;
            }
            accept ResetEmergencySignal then normal;
            state lightCurtainBreachedState {
                entry haltAll;
            }
            accept ResetLightCurtainSignal then normal;
        }
    }

    part def PowerDistributionUnit {
        attribute mainVoltage : ISQ::ElectricPotentialValue = 480 [SI::V];
        attribute maxCurrent : ISQ::ElectricCurrentValue = 100 [SI::A];
        port outputRobot : PowerOutputPort;
        port outputGripper : PowerOutputPort;
        port outputConveyor : PowerOutputPort;
        port outputVision : PowerOutputPort;
        port outputController : PowerOutputPort;
        port outputSafety : PowerOutputPort;
        perform action supplyPower : SupplyPower;
    }

    part def RoboticCell {
        part robot : ABBIRB6700;
        part gripper : GripperEndEffector;
        part conveyor : ConveyorSystem;
        part vision : VisionSystem;
        part controller : RobotController;
        part safety : SafetySystem;
        part power : PowerDistributionUnit;

        connect controller.robotPort to robot.controlPort;
        connect controller.gripperPort to gripper.controlPort;
        connect controller.visionPort to vision.outputPort;
        connect controller.conveyorPort to conveyor.controlPort;
        connect safety.statusPort to controller.safetyPort;

        connect power.outputRobot to robot.powerInput;
        connect power.outputGripper to gripper.powerInput;
        connect power.outputConveyor to conveyor.powerInput;
        connect power.outputVision to vision.powerInput;
        connect power.outputController to controller.powerInput;
        connect power.outputSafety to safety.powerInput;

        exhibit state cellOperationalModes {
            entry; then automatic;
            state automatic;
            accept SwitchToManualSignal then manual;
            accept SwitchToMaintenanceSignal then maintenance;
            accept EmergencyStopSignal then emergency_stop;
            state manual;
            accept SwitchToAutomaticSignal then automatic;
            accept SwitchToMaintenanceSignal then maintenance;
            accept EmergencyStopSignal then emergency_stop;
            state maintenance;
            accept SwitchToAutomaticSignal then automatic;
            accept EmergencyStopSignal then emergency_stop;
            state emergency_stop;
            accept ResetEmergencySignal then automatic;
        }
    }

    requirement def SafetyRequirement {
        attribute emergencyStopResponse : ISQ::DurationValue;
        constraint { emergencyStopResponse <= 0.1 [SI::s] }
    }

    requirement def PlacementAccuracyRequirement {
        attribute placementAccuracy : ISQ::LengthValue;
        constraint { placementAccuracy <= 0.5 [SI::mm] }
    }

    requirement def PayloadCapacityRequirement {
        attribute payloadCapacity : ISQ::MassValue;
        constraint { payloadCapacity >= 200 [SI::kg] }
    }

    requirement def CycleTimeRequirement {
        attribute cycleTime : ISQ::DurationValue;
        constraint { cycleTime <= 5 [SI::s] }
    }

    requirement def ReachRequirement {
        attribute reach : ISQ::LengthValue;
        constraint { reach > 2.6 [SI::m] }
    }

    part cellInstance : RoboticCell {
        requirement req_Safety : SafetyRequirement;
        requirement req_Accuracy : PlacementAccuracyRequirement;
        requirement req_Payload : PayloadCapacityRequirement;
        requirement req_CycleTime : CycleTimeRequirement;
        requirement req_Reach : ReachRequirement;
    }
}
