package 'SoftRoboticWorkCell' {

    import ScalarValues::*;
    import ScalarFunctions::*;

    // ---- Value types with units ----
    value type PressureValue :> Real { 
        attribute unit : String = "Pa";
        attribute nominal : PressureValue = 100000.0;
    }
    value type ForceValue :> Real { 
        attribute unit : String = "N";
    }
    value type LengthValue :> Real { 
        attribute unit : String = "m";
    }
    value type MassValue :> Real { 
        attribute unit : String = "kg";
    }
    value type TimeValue :> Real { 
        attribute unit : String = "s";
    }
    value type FlowRateValue :> Real { 
        attribute unit : String = "L/min";
    }
    value type AngleValue :> Real { 
        attribute unit : String = "deg";
    }
    value type VoltageValue :> Real { 
        attribute unit : String = "V";
    }
    value type CurrentValue :> Real { 
        attribute unit : String = "A";
    }

    // ---- Items ----
    item def HydraulicFluid {
        attribute density : MassValue = 850.0;
        attribute viscosity : Real = 0.05;
        attribute bioCompatible : Boolean = true;
        attribute siliconFree : Boolean = true;
    }

    item def Workpiece {
        attribute identifier : String;
        attribute mass : MassValue;
        attribute length : LengthValue;
        attribute width : LengthValue;
        attribute height : LengthValue;
        attribute sourceX : LengthValue;
        attribute sourceY : LengthValue;
        attribute sourceZ : LengthValue;
        attribute destX : LengthValue;
        attribute destY : LengthValue;
        attribute destZ : LengthValue;
    }

    item def PressurizedFluid :> HydraulicFluid {
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }

    // ---- Ports ----
    port def FluidPort {
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
        in flow of PressurizedFluid;
        out flow of PressurizedFluid;
    }

    port def PowerPort {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }

    port def SensorDataPort {
        attribute positionX : LengthValue;
        attribute positionY : LengthValue;
        attribute positionZ : LengthValue;
        attribute measuredForce : ForceValue;
        attribute jointAngle : AngleValue;
    }

    port def ControlSignalPort {
        attribute targetPressure : PressureValue;
        attribute targetJointIndex : Integer;
        attribute targetFlow : FlowRateValue;
    }

    // ---- Requirements ----
    requirement def MaterialRequirement {
        doc /* The work cell shall use non-silicon-based materials, such as organic polymers and biocompatible components, for all structural and actuation elements. */
        attribute materialClass : String = "OrganicPolymer";
        attribute siliconBased : Boolean = false;
        attribute bioCompatible : Boolean = true;
    }

    requirement def MaxArmForceRequirement {
        doc /* The arm shall not exert force greater than the maximum safe arm force limit. */
        attribute maxArmForce : ForceValue = 50.0;
        attribute armForce : ForceValue;
        constraint { armForce <= maxArmForce }
    }

    requirement def MaxGripperForceRequirement {
        doc /* The gripper shall not exert force greater than the maximum safe gripper force limit. */
        attribute maxGripperForce : ForceValue = 20.0;
        attribute gripperForce : ForceValue;
        constraint { gripperForce <= maxGripperForce }
    }

    requirement def PickAndPlaceRequirement {
        doc /* The robot shall perform a complete pick-and-place operation consisting of sensing the workpiece, computing a path, moving to the object, grasping with controlled force, transporting the object to a destination, and releasing it. */
        attribute maxGraspTime : TimeValue = 2.0;
        attribute maxTransportTime : TimeValue = 5.0;
        attribute maxReleaseTime : TimeValue = 1.0;
        attribute maxTotalCycleTime : TimeValue = 10.0;
    }

    requirement def OrganicSensorRequirement {
        doc /* The robot shall be equipped with exactly four organic sensors for perception of its surroundings. */
        attribute sensorCount : Integer = 4;
        attribute sensorMaterial : String = "Organic";
    }

    requirement def FluidicActuationRequirement {
        doc /* The robot shall be actuated and controlled entirely by a fluidic system, without electric motors or a computer processor. */
        attribute hasElectricMotors : Boolean = false;
        attribute hasComputerProcessor : Boolean = false;
        attribute actuationType : String = "Fluidic";
    }

    requirement def PowerSupplyRequirement {
        doc /* The work cell shall include a dedicated power supply providing power to the fluidic pump. */
        attribute outputVoltage : VoltageValue = 24.0;
        attribute maxCurrent : CurrentValue = 10.0;
    }

    requirement def LifecycleRequirement {
        doc /* The system shall implement a lifecycle starting in a powered-off state, transitioning through initialization to a ready state, and entering an operating mode for task execution with error handling and reset capability. */
        attribute supportsReset : Boolean = true;
        attribute supportsErrorHandling : Boolean = true;
    }

    // ---- Actions ----
    action def PowerOnAction {
        out powerStatus : Boolean;
    }

    action def PowerOffAction {
        out powerStatus : Boolean;
    }

    action def InitializeAction {
        in duration : TimeValue;
        out initComplete : Boolean;
    }

    action def SenseWorkpieceAction {
        in sensors : OrganicSensor[4];
        out workpieceLocationX : LengthValue;
        out workpieceLocationY : LengthValue;
        out workpieceLocationZ : LengthValue;
        out detected : Boolean;
    }

    action def ComputePathAction {
        in startX : LengthValue;
        in startY : LengthValue;
        in startZ : LengthValue;
        in endX : LengthValue;
        in endY : LengthValue;
        in endZ : LengthValue;
        out pathValid : Boolean;
    }

    action def MoveToAction {
        in targetX : LengthValue;
        in targetY : LengthValue;
        in targetZ : LengthValue;
        out arrived : Boolean;
    }

    action def GraspAction {
        in targetForce : ForceValue;
        out grasped : Boolean;
        out appliedForce : ForceValue;
    }

    action def TransportAction {
        in targetX : LengthValue;
        in targetY : LengthValue;
        in targetZ : LengthValue;
        out delivered : Boolean;
    }

    action def ReleaseAction {
        out released : Boolean;
        out appliedForce : ForceValue;
    }

    action def PickAndPlaceAction {
        in workpiece : Workpiece;
        out success : Boolean;

        perform SenseWorkpieceAction {
            out workpieceLocationX = workpiece.sourceX;
            out workpieceLocationY = workpiece.sourceY;
            out workpieceLocationZ = workpiece.sourceZ;
            out detected = true;
        }
        then perform ComputePathAction {
            in startX = workpiece.sourceX;
            in startY = workpiece.sourceY;
            in startZ = workpiece.sourceZ;
            in endX = workpiece.destX;
            in endY = workpiece.destY;
            in endZ = workpiece.destZ;
        }
        then perform MoveToAction {
            in targetX = workpiece.sourceX;
            in targetY = workpiece.sourceY;
            in targetZ = workpiece.sourceZ;
        }
        then perform GraspAction {
            in targetForce = 5.0;
        }
        then perform TransportAction {
            in targetX = workpiece.destX;
            in targetY = workpiece.destY;
            in targetZ = workpiece.destZ;
        }
        then perform ReleaseAction {
            out appliedForce = 0.0;
        }
        then assign success = true;
    }

    // ---- Part definitions ----
    part def PowerSupply {
        attribute outputVoltage : VoltageValue = 24.0;
        attribute maxCurrent : CurrentValue = 10.0;
        attribute powerStatus : Boolean = false;
        attribute efficiency : Real = 0.92;

        port powerOut : PowerPort;

        action def powerOn() {
            assign powerStatus = true;
        }

        action def powerOff() {
            assign powerStatus = false;
        }

        satisfy PowerSupplyRequirement by powerOut;
    }

    part def FluidicPump {
        attribute ratedPressure : PressureValue = 200000.0;
        attribute ratedFlow : FlowRateValue = 12.0;
        attribute currentPressure : PressureValue;
        attribute currentFlow : FlowRateValue;
        attribute active : Boolean = false;
        attribute pumpMaterial : String = "BiocompatiblePolymer";

        port fluidOut : FluidPort;
        port powerIn : PowerPort;

        action def startPumping() {
            assign active = true;
            assign currentPressure = ratedPressure;
            assign currentFlow = ratedFlow;
        }

        action def stopPumping() {
            assign active = false;
            assign currentPressure = 0.0;
            assign currentFlow = 0.0;
        }

        action def regulatePressure(target : PressureValue) {
            assign currentPressure = target;
        }
    }

    part def OrganicSensor {
        attribute sensorId : Integer;
        attribute sensorType : String;
        attribute bioCompatible : Boolean = true;
        attribute material : String = "OrganicPolymer";
        attribute currentReading : Real = 0.0;
        attribute isActive : Boolean = false;
        attribute maxForceReading : ForceValue = 1000.0;

        port dataOut : SensorDataPort;

        action def activate() {
            assign isActive = true;
        }

        action def deactivate() {
            assign isActive = false;
        }

        action def readPosition() {
            assign currentReading = 0.0;
        }

        action def readForce() {
            assign currentReading = 0.0;
        }
    }

    part def FluidicController {
        attribute controllerMaterial : String = "OrganicPolymer";
        attribute bioCompatible : Boolean = true;
        attribute commandPressure : PressureValue;
        attribute targetFlow : FlowRateValue;
        attribute controllerState : String;
        attribute hasProcessor : Boolean = false;

        port fluidIn : FluidPort;
        port controlToJoint1 : ControlSignalPort;
        port controlToJoint2 : ControlSignalPort;
        port controlToJoint3 : ControlSignalPort;
        port controlToJoint4 : ControlSignalPort;
        port controlToGripper : ControlSignalPort;

        action def directFluidToJoint(jointIndex : Integer, pressure : PressureValue, flow : FlowRateValue) {
            assign commandPressure = pressure;
            assign targetFlow = flow;
        }

        action def computePath(targetX : LengthValue, targetY : LengthValue, targetZ : LengthValue) {
            // fluidic logic computation
        }

        action def routeControlSignal(jointIndex : Integer, pressure : PressureValue) {
            perform directFluidToJoint(jointIndex, pressure, 5.0);
        }

        satisfy FluidicActuationRequirement by controllerMaterial;
    }

    part def Joint {
        attribute jointId : Integer;
        attribute jointAngle : AngleValue = 0.0;
        attribute maxAngle : AngleValue = 90.0;
        attribute minAngle : AngleValue = -90.0;
        attribute appliedForce : ForceValue;
        attribute maxJointForce : ForceValue = 50.0;
        attribute material : String = "OrganicPolymer";
        attribute actuationType : String = "Fluidic";

        port fluidActuationIn : FluidPort;
        port jointSensorOut : SensorDataPort;

        action def move(targetAngle : AngleValue) {
            assign jointAngle = targetAngle;
        }

        action def applyForce(force : ForceValue) {
            assign appliedForce = force;
        }

        constraint { appliedForce <= maxJointForce }
        constraint { jointAngle <= maxAngle }
        constraint { jointAngle >= minAngle }
    }

    part def Arm {
        attribute armMaterial : String = "OrganicPolymer";
        attribute bioCompatible : Boolean = true;
        attribute totalArmLength : LengthValue = 0.8;
        attribute maxArmForce : ForceValue = 50.0;
        attribute currentArmForce : ForceValue;
        attribute hasElectricMotor : Boolean = false;

        part joints : Joint[4] {
            part joint1 : Joint { attribute jointId = 1; }
            part joint2 : Joint { attribute jointId = 2; }
            part joint3 : Joint { attribute jointId = 3; }
            part joint4 : Joint { attribute jointId = 4; }
        }

        port fluidIn : FluidPort;
        port armSensorOut : SensorDataPort;

        action def moveTo(x : LengthValue, y : LengthValue, z : LengthValue) {
            // fluidic-driven motion
        }

        action def applyArmForce(force : ForceValue) {
            assign currentArmForce = force;
        }

        constraint { currentArmForce <= maxArmForce }
        satisfy MaxArmForceRequirement by maxArmForce;
    }

    part def Gripper {
        attribute gripperMaterial : String = "BiocompatibleElastomer";
        attribute bioCompatible : Boolean = true;
        attribute maxGripperForce : ForceValue = 20.0;
        attribute currentGripperForce : ForceValue = 0.0;
        attribute gripState : String = "open";
        attribute hasElectricMotor : Boolean = false;

        port fluidIn : FluidPort;
        port gripperSensorOut : SensorDataPort;

        action def grasp(targetForce : ForceValue) {
            assign gripState = "closed";
            assign currentGripperForce = targetForce;
        }

        action def release() {
            assign gripState = "open";
            assign currentGripperForce = 0.0;
        }

        constraint { currentGripperForce <= maxGripperForce }
        satisfy MaxGripperForceRequirement by maxGripperForce;
    }

    part def SoftRobot {
        attribute robotName : String;
        attribute bioCompatible : Boolean = true;
        attribute materialClass : String = "Organic";
        attribute hasElectricMotors : Boolean = false;
        attribute hasComputerProcessor : Boolean = false;
        attribute actuationType : String = "Fluidic";

        part arm : Arm;
        part gripper : Gripper;
        part controller : FluidicController;
        part sensors : OrganicSensor[4] {
            part sensor1 : OrganicSensor { attribute sensorId = 1; attribute sensorType = "Position"; }
            part sensor2 : OrganicSensor { attribute sensorId = 2; attribute sensorType = "Position"; }
            part sensor3 : OrganicSensor { attribute sensorId = 3; attribute sensorType = "Force"; }
            part sensor4 : OrganicSensor { attribute sensorId = 4; attribute sensorType = "Force"; }
        }

        port fluidIn : FluidPort;
        port powerIn : PowerPort;

        // State machine lifecycle
        state machine LifecycleStateMachine {
            state PoweredOff {
                entry action { /* System powered down */ }
            }
            state Initializing {
                entry action { /* Initialize sensors and calibrate joints */ }
                perform InitializeAction {
                    in duration = 3.0;
                }
            }
            state Ready {
                entry action { /* Ready to receive task */ }
            }
            state Operating {
                entry action { /* Begin pick-and-place */ }
                perform PickAndPlaceAction;
            }
            state ErrorState {
                entry action { /* Handle task failure */ }
            }

            transition from PoweredOff to Initializing when powerOn;
            transition from Initializing to Ready when initComplete;
            transition from Ready to Operating when taskReceived;
            transition from Operating to Ready when taskComplete;
            transition from Operating to ErrorState when taskFailed;
            transition from ErrorState to Ready when resetRequested;
            transition from ErrorState to PoweredOff when powerOff;
            transition from Ready to PoweredOff when powerOff;
            transition from Operating to PoweredOff when powerOff;
        }

        action def performPickAndPlace(workpiece : Workpiece) {
            perform PickAndPlaceAction {
                in workpiece = workpiece;
            }
        }

        action def reset() {
            // Reset joints to neutral, clear errors
        }

        satisfy MaterialRequirement by materialClass;
        satisfy OrganicSensorRequirement by sensors;
        satisfy PickAndPlaceRequirement by performPickAndPlace;
        satisfy FluidicActuationRequirement by actuationType;
        satisfy LifecycleRequirement by LifecycleStateMachine;
    }

    // ---- Top-level Work Cell ----
    part def WorkCell {
        attribute cellName : String = "SoftRoboticWorkCellA";
        attribute safetyRating : String = "IntrinsicallySafe";
        attribute operationalMode : String;

        part robot : SoftRobot {
            attribute robotName = "SoftArm-I";
        }
        part pump : FluidicPump;
        part power : PowerSupply;

        // Connections
        connection pumpFluidOut to robotFluidIn from pump.fluidOut to robot.fluidIn;
        connection powerToPump from power.powerOut to pump.powerIn;

        // Internal robot connections
        connection pumpToController from robot.fluidIn to robot.controller.fluidIn;
        connection controllerToJoint1 from robot.controller.controlToJoint1 to robot.arm.joints.joint1.fluidActuationIn;
        connection controllerToJoint2 from robot.controller.controlToJoint2 to robot.arm.joints.joint2.fluidActuationIn;
        connection controllerToJoint3 from robot.controller.controlToJoint3 to robot.arm.joints.joint3.fluidActuationIn;
        connection controllerToJoint4 from robot.controller.controlToJoint4 to robot.arm.joints.joint4.fluidActuationIn;
        connection controllerToGripper from robot.controller.controlToGripper to robot.gripper.fluidIn;
        connection controllerToArmFluid from robot.arm.fluidIn to robot.arm.joints.joint1.fluidActuationIn;

        // Sensor connections
        connection sensor1ToController from robot.sensors.sensor1.dataOut to robot.controller.fluidIn;
        connection sensor2ToController from robot.sensors.sensor2.dataOut to robot.controller.fluidIn;
        connection sensor3ToController from robot.sensors.sensor3.dataOut to robot.gripper.gripperSensorOut;
        connection sensor4ToController from robot.sensors.sensor4.dataOut to robot.arm.armSensorOut;

        // Satisfy requirements
        satisfy MaterialRequirement by robot.materialClass;
        satisfy MaxArmForceRequirement by robot.arm.maxArmForce;
        satisfy MaxGripperForceRequirement by robot.gripper.maxGripperForce;
        satisfy PickAndPlaceRequirement by robot;
        satisfy PowerSupplyRequirement by power;
        satisfy OrganicSensorRequirement by robot.sensors;
        satisfy FluidicActuationRequirement by robot.actuationType;
        satisfy LifecycleRequirement by robot.LifecycleStateMachine;

        action def initializeCell() {
            perform PowerOnAction {
                out powerStatus = power.powerStatus;
            }
            then perform pump.startPumping();
            then perform robot.sensors.sensor1.activate();
            then perform robot.sensors.sensor2.activate();
            then perform robot.sensors.sensor3.activate();
            then perform robot.sensors.sensor4.activate();
        }

        action def shutdownCell() {
            perform pump.stopPumping();
            then perform PowerOffAction {
                out powerStatus = false;
            }
        }
    }

    // ---- Instances / Scenarios ----
    part 'SoftWorkCellInstance' :> WorkCell {
        attribute cellName = "Cell-Alpha";
        part robot {
            attribute robotName = "SoftArm-I-001";
        }
    }

    item 'demoWorkpiece' :> Workpiece {
        attribute identifier = "WP-001";
        attribute mass = 0.5;
        attribute length = 0.05;
        attribute width = 0.05;
        attribute height = 0.02;
        attribute sourceX = 0.1;
        attribute sourceY = 0.2;
        attribute sourceZ = 0.3;
        attribute destX = 0.4;
        attribute destY = 0.5;
        attribute destZ = 0.3;
    }
}
