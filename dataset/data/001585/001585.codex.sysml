package SoftRoboticsSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def PressureValue :> ISQ::pressure {
        unit = SI::pascal;
    }

    attribute def FlowRateValue {
        value flow : Real;
        unit = "L/min";
    }

    attribute def ForceValue :> ISQ::force {
        unit = SI::newton;
    }

    attribute def LengthValue :> ISQ::length {
        unit = SI::meter;
    }

    attribute def TemperatureValue :> ISQ::thermodynamicTemperature {
        unit = SI::kelvin;
    }

    attribute def VoltageValue :> ISQ::electricPotential {
        unit = SI::volt;
    }

    attribute def TimeValue :> ISQ::time {
        unit = SI::second;
    }

    item def CompressedAir {
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
        attribute temperature : TemperatureValue;
    }

    item def ExhaustAir {
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }

    item def ElectricalPower {
        attribute voltage : VoltageValue;
        attribute current : Real;
    }

    item def GripCommand {
        attribute desiredGripForce : ForceValue;
        attribute desiredFingerCurvature : Real;
        attribute closeRequest : Boolean;
        attribute releaseRequest : Boolean;
    }

    item def GripStatus {
        attribute measuredGripForce : ForceValue;
        attribute measuredFingerCurvature : Real;
        attribute objectDetected : Boolean;
        attribute safeToMove : Boolean;
    }

    item def SoftObject {
        attribute mass : Real;
        attribute width : LengthValue;
        attribute fragilityLimit : ForceValue;
    }

    port def PneumaticInlet {
        in item air : CompressedAir;
    }

    port def PneumaticOutlet {
        out item air : ExhaustAir;
    }

    port def ElectricalPowerPort {
        in item power : ElectricalPower;
    }

    port def CommandPort {
        in item command : GripCommand;
    }

    port def StatusPort {
        out item status : GripStatus;
    }

    port def ObjectInteractionPort {
        inout item object : SoftObject;
        out item status : GripStatus;
    }

    part def SoftRoboticGripper {
        attribute maxGripForce : ForceValue = 35 [SI::newton];
        attribute nominalPressure : PressureValue = 85000 [SI::pascal];
        attribute maximumPressure : PressureValue = 140000 [SI::pascal];
        attribute openingWidth : LengthValue = 0.12 [SI::meter];

        port powerPort : ElectricalPowerPort;
        port commandPort : CommandPort;
        port statusPort : StatusPort;
        port objectPort : ObjectInteractionPort;

        part controller : EmbeddedController;
        part pneumaticSupply : PneumaticSupplyModule;
        part manifold : PneumaticManifold;
        part leftFinger : SoftPneumaticFinger;
        part rightFinger : SoftPneumaticFinger;
        part palm : CompliantPalm;
        part sensorArray : SensorArray;
        part safetyVent : PassiveSafetyVent;

        connect powerPort to controller.powerPort;
        connect commandPort to controller.commandPort;
        connect controller.valveCommandPort to manifold.controlPort;
        connect controller.statusInputPort to sensorArray.statusPort;
        connect controller.statusPort to statusPort;

        connect pneumaticSupply.outletPort to manifold.inletPort;
        connect manifold.leftOutletPort to leftFinger.inletPort;
        connect manifold.rightOutletPort to rightFinger.inletPort;
        connect leftFinger.exhaustPort to safetyVent.inletPort;
        connect rightFinger.exhaustPort to safetyVent.inletPort;
        connect safetyVent.outletPort to pneumaticSupply.returnPort;

        connect leftFinger.contactPort to objectPort;
        connect rightFinger.contactPort to objectPort;
        connect palm.objectPort to objectPort;
        connect sensorArray.leftSensorPort to leftFinger.sensorPort;
        connect sensorArray.rightSensorPort to rightFinger.sensorPort;
        connect sensorArray.objectPort to objectPort;

        perform action gripCycle : GripCycleAction;
        exhibit state gripperState : GripperStateMachine;
    }

    part def EmbeddedController {
        attribute controlPeriod : TimeValue = 0.01 [SI::second];
        attribute pressureSetpoint : PressureValue;
        attribute gripForceLimit : ForceValue = 30 [SI::newton];

        port powerPort : ElectricalPowerPort;
        port commandPort : CommandPort;
        port statusInputPort : StatusPort;
        port statusPort : StatusPort;
        port valveCommandPort : ValveControlPort;

        perform action computePressureSetpoint : ComputePressureSetpointAction;
    }

    port def ValveControlPort {
        out item command : ValveControlSignal;
    }

    item def ValveControlSignal {
        attribute leftValveDutyCycle : Real;
        attribute rightValveDutyCycle : Real;
        attribute ventOpen : Boolean;
    }

    part def PneumaticSupplyModule {
        attribute reservoirPressure : PressureValue = 160000 [SI::pascal];
        attribute regulatedPressure : PressureValue = 90000 [SI::pascal];
        attribute maximumFlowRate : FlowRateValue;

        port outletPort : PneumaticOutlet;
        port returnPort : PneumaticInlet;

        part compressor : MicroCompressor;
        part regulator : PressureRegulator;
        part reservoir : AirReservoir;

        connect compressor.outletPort to reservoir.inletPort;
        connect reservoir.outletPort to regulator.inletPort;
        connect regulator.outletPort to outletPort;
        connect returnPort to compressor.returnPort;
    }

    part def MicroCompressor {
        attribute supplyVoltage : VoltageValue = 24 [SI::volt];
        attribute maximumPressure : PressureValue = 180000 [SI::pascal];

        port outletPort : PneumaticOutlet;
        port returnPort : PneumaticInlet;
    }

    part def AirReservoir {
        attribute volume : Real = 0.0005;
        attribute designPressure : PressureValue = 200000 [SI::pascal];

        port inletPort : PneumaticInlet;
        port outletPort : PneumaticOutlet;
    }

    part def PressureRegulator {
        attribute setPressure : PressureValue = 90000 [SI::pascal];
        attribute reliefPressure : PressureValue = 145000 [SI::pascal];

        port inletPort : PneumaticInlet;
        port outletPort : PneumaticOutlet;
    }

    part def PneumaticManifold {
        attribute leftChamberPressure : PressureValue;
        attribute rightChamberPressure : PressureValue;

        port inletPort : PneumaticInlet;
        port leftOutletPort : PneumaticOutlet;
        port rightOutletPort : PneumaticOutlet;
        port controlPort : ValveControlPort;

        part leftProportionalValve : ProportionalValve;
        part rightProportionalValve : ProportionalValve;

        connect inletPort to leftProportionalValve.inletPort;
        connect inletPort to rightProportionalValve.inletPort;
        connect leftProportionalValve.outletPort to leftOutletPort;
        connect rightProportionalValve.outletPort to rightOutletPort;
    }

    part def ProportionalValve {
        attribute commandDutyCycle : Real;
        attribute responseTime : TimeValue = 0.025 [SI::second];
        attribute leakageRate : FlowRateValue;

        port inletPort : PneumaticInlet;
        port outletPort : PneumaticOutlet;
    }

    part def SoftPneumaticFinger {
        attribute chamberPressure : PressureValue;
        attribute curvature : Real;
        attribute contactForce : ForceValue;
        attribute freeLength : LengthValue = 0.095 [SI::meter];
        attribute wallThickness : LengthValue = 0.002 [SI::meter];

        port inletPort : PneumaticInlet;
        port exhaustPort : PneumaticOutlet;
        port contactPort : ObjectInteractionPort;
        port sensorPort : FingerSensorPort;

        part elastomerBody : ElastomericActuatorBody;
        part strainLimiter : FiberReinforcedLayer;
        part tactileSkin : TactileSensorSkin;

        connect inletPort to elastomerBody.airPort;
        connect elastomerBody.exhaustPort to exhaustPort;
        connect tactileSkin.sensorPort to sensorPort;
        connect tactileSkin.contactPort to contactPort;

        perform action inflateAndBend : InflateFingerAction;
    }

    port def FingerSensorPort {
        out item data : FingerSensorData;
    }

    item def FingerSensorData {
        attribute pressure : PressureValue;
        attribute curvature : Real;
        attribute contactForce : ForceValue;
        attribute contactDetected : Boolean;
    }

    part def ElastomericActuatorBody {
        attribute materialName : String = "platinum-cured silicone";
        attribute shoreHardness : Real = 20;
        attribute chamberCount : Integer = 12;

        port airPort : PneumaticInlet;
        port exhaustPort : PneumaticOutlet;
    }

    part def FiberReinforcedLayer {
        attribute fiberAngle : Real = 0.0;
        attribute axialStiffness : Real;
    }

    part def TactileSensorSkin {
        attribute taxelCount : Integer = 16;
        attribute forceResolution : ForceValue = 0.05 [SI::newton];

        port sensorPort : FingerSensorPort;
        port contactPort : ObjectInteractionPort;
    }

    part def CompliantPalm {
        attribute padStiffness : Real;
        attribute padThickness : LengthValue = 0.006 [SI::meter];

        port objectPort : ObjectInteractionPort;
    }

    part def SensorArray {
        port leftSensorPort : FingerSensorPort;
        port rightSensorPort : FingerSensorPort;
        port objectPort : ObjectInteractionPort;
        port statusPort : StatusPort;

        perform action estimateGripStatus : EstimateGripStatusAction;
    }

    part def PassiveSafetyVent {
        attribute crackingPressure : PressureValue = 145000 [SI::pascal];
        attribute ventingTime : TimeValue = 0.2 [SI::second];

        port inletPort : PneumaticInlet;
        port outletPort : PneumaticOutlet;
    }

    action def GripCycleAction {
        in item command : GripCommand;
        inout item targetObject : SoftObject;
        out item status : GripStatus;

        first start;
        then detectObject;
        then closeSoftFingers;
        then regulateGripForce;
        then holdObject;
        then releaseObject;
        then done;

        action start;
        action detectObject;
        action closeSoftFingers;
        action regulateGripForce;
        action holdObject;
        action releaseObject;
        action done;
    }

    action def ComputePressureSetpointAction {
        in item command : GripCommand;
        in item currentStatus : GripStatus;
        out item valveSignal : ValveControlSignal;

        constraint forceControl {
            currentStatus.measuredGripForce <= command.desiredGripForce;
        }

        constraint safetyLimit {
            command.desiredGripForce <= 30 [SI::newton];
        }
    }

    action def InflateFingerAction {
        in item suppliedAir : CompressedAir;
        out item exhaustedAir : ExhaustAir;
        out attribute resultingCurvature : Real;
        out attribute resultingContactForce : ForceValue;

        constraint bendResponse {
            resultingCurvature > 0.0;
        }

        constraint softContact {
            resultingContactForce <= 35 [SI::newton];
        }
    }

    action def EstimateGripStatusAction {
        in item leftFingerData : FingerSensorData;
        in item rightFingerData : FingerSensorData;
        out item status : GripStatus;

        constraint objectDetectionLogic {
            status.objectDetected == leftFingerData.contactDetected and rightFingerData.contactDetected;
        }
    }

    state def GripperStateMachine {
        state Idle;
        state ObjectSearch;
        state PreShape;
        state Closing;
        state ForceRegulation;
        state Holding;
        state Releasing;
        state FaultVenting;

        initial then Idle;

        transition Idle_to_ObjectSearch
            first Idle
            accept GripCommand
            if command.closeRequest
            then ObjectSearch;

        transition ObjectSearch_to_PreShape
            first ObjectSearch
            if status.objectDetected
            then PreShape;

        transition PreShape_to_Closing
            first PreShape
            then Closing;

        transition Closing_to_ForceRegulation
            first Closing
            if status.measuredGripForce >= command.desiredGripForce
            then ForceRegulation;

        transition ForceRegulation_to_Holding
            first ForceRegulation
            if status.safeToMove
            then Holding;

        transition Holding_to_Releasing
            first Holding
            accept GripCommand
            if command.releaseRequest
            then Releasing;

        transition Releasing_to_Idle
            first Releasing
            if status.measuredGripForce <= 0.5 [SI::newton]
            then Idle;

        transition Any_to_FaultVenting
            first Idle
            if status.measuredGripForce > 35 [SI::newton]
            then FaultVenting;

        transition FaultVenting_to_Idle
            first FaultVenting
            if status.measuredGripForce <= 0.5 [SI::newton]
            then Idle;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The soft robotic gripper shall conform around delicate objects using compliant pneumatic fingers and shall grasp, hold, and release those objects without exceeding a safe contact force. */

        subject gripper : SoftRoboticGripper;

        require constraint {
            gripper.maxGripForce <= 35 [SI::newton]
        }
    }

    requirement def SafePressureRequirement {
        doc /* The pneumatic actuation subsystem shall keep actuator chamber pressure below the material and safety limit during all operating states. */

        subject gripper : SoftRoboticGripper;

        require constraint {
            gripper.maximumPressure <= 140000 [SI::pascal]
        }
    }

    requirement def CompliantContactRequirement {
        doc /* The finger contact surface shall distribute gripping force through a compliant tactile skin to reduce localized stress on fragile objects. */

        subject finger : SoftPneumaticFinger;

        require constraint {
            finger.contactForce <= 35 [SI::newton]
        }
    }

    requirement def ReleaseRequirement {
        doc /* The gripper shall vent both pneumatic fingers and release the object when a release command is received. */

        subject gripper : SoftRoboticGripper;

        require constraint {
            gripper.safetyVent.ventingTime <= 0.2 [SI::second]
        }
    }

    requirement def HighLevelMissionRequirement {
        doc /* The system shall provide a soft robotic manipulation function that safely adapts its shape to an object's geometry, applies controlled pneumatic gripping force, transports the object while maintaining stable contact, and releases the object on command. */

        subject gripper : SoftRoboticGripper;
    }

    satisfy PrimaryFunctionRequirement by SoftRoboticGripper;
    satisfy SafePressureRequirement by PneumaticSupplyModule;
    satisfy CompliantContactRequirement by SoftPneumaticFinger;
    satisfy ReleaseRequirement by PassiveSafetyVent;
    satisfy HighLevelMissionRequirement by SoftRoboticGripper;

    part softRoboticsSystem : SoftRoboticGripper {
        attribute maxGripForce = 30 [SI::newton];
        attribute nominalPressure = 90000 [SI::pascal];
        attribute maximumPressure = 140000 [SI::pascal];
        attribute openingWidth = 0.12 [SI::meter];
    }

}