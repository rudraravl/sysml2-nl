package PatientLiftSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    /* Units and Value Types */

    attribute def Kilogram :> Real {
        unit = "kg";
    }

    attribute def Newton :> Real {
        unit = "N";
    }

    attribute def Meter :> Real {
        unit = "m";
    }

    attribute def Millimeter :> Real {
        unit = "mm";
    }

    attribute def Second :> Real {
        unit = "s";
    }

    attribute def Volt :> Real {
        unit = "V";
    }

    attribute def AmpereHour :> Real {
        unit = "Ah";
    }

    attribute def Degree :> Real {
        unit = "deg";
    }

    attribute def Percent :> Real {
        unit = "%";
    }

    attribute def LiftSpeed :> Real {
        unit = "mm/s";
    }

    attribute def ForceLimit :> Real {
        unit = "N";
    }

    enum def LiftMode {
        enum manual;
        enum powered;
        enum emergencyLowering;
    }

    enum def LiftState {
        enum off;
        enum ready;
        enum lifting;
        enum lowering;
        enum holding;
        enum faulted;
        enum emergencyStop;
        enum charging;
    }

    enum def PatientPosture {
        enum seated;
        enum supine;
        enum standingAssisted;
    }

    enum def CommandKind {
        enum raise;
        enum lower;
        enum stop;
        enum reset;
        enum emergencyStop;
    }

    /* Items */

    item def Patient {
        attribute mass : Kilogram;
        attribute posture : PatientPosture;
        attribute supported : Boolean;
    }

    item def Sling {
        attribute ratedLoad : Kilogram;
        attribute attachmentPoints : Integer;
        attribute properlyAttached : Boolean;
    }

    item def LiftCommand {
        attribute command : CommandKind;
        attribute requestedByCaregiver : Boolean;
    }

    item def BatteryEnergy {
        attribute voltage : Volt;
        attribute capacityRemaining : Percent;
    }

    item def LiftStatus {
        attribute state : LiftState;
        attribute boomHeight : Millimeter;
        attribute batteryRemaining : Percent;
        attribute loadMeasured : Kilogram;
        attribute faultPresent : Boolean;
    }

    item def AlarmSignal {
        attribute active : Boolean;
        attribute messageCode : String;
    }

    item def MechanicalLoad {
        attribute mass : Kilogram;
        attribute force : Newton;
    }

    item def ElectricalPower {
        attribute voltage : Volt;
        attribute current : Real;
    }

    /* Ports */

    port def PatientSupportPort {
        inout item patient : Patient;
        inout item sling : Sling;
        out item load : MechanicalLoad;
    }

    port def CaregiverControlPort {
        in item command : LiftCommand;
        out item status : LiftStatus;
        out item alarm : AlarmSignal;
    }

    port def PowerPort {
        in item powerIn : ElectricalPower;
        out item battery : BatteryEnergy;
    }

    port def ActuatorControlPort {
        in item command : LiftCommand;
        in item load : MechanicalLoad;
        out item status : LiftStatus;
    }

    port def SensorPort {
        out item measuredLoad : MechanicalLoad;
        out item status : LiftStatus;
    }

    port def BrakePort {
        in item command : LiftCommand;
        in item load : MechanicalLoad;
        out item status : LiftStatus;
    }

    /* Interfaces */

    interface def SupportInterface {
        end patientSide : PatientSupportPort;
        end boomSide : PatientSupportPort;
    }

    interface def ControlInterface {
        end controllerSide : CaregiverControlPort;
        end userSide : CaregiverControlPort;
    }

    interface def PowerInterface {
        end batterySide : PowerPort;
        end loadSide : PowerPort;
    }

    interface def ActuatorInterface {
        end controllerSide : ActuatorControlPort;
        end actuatorSide : ActuatorControlPort;
    }

    interface def SensorInterface {
        end sensorSide : SensorPort;
        end controllerSide : SensorPort;
    }

    interface def BrakeInterface {
        end controllerSide : BrakePort;
        end brakeSide : BrakePort;
    }

    /* Parts */

    part def BaseFrame {
        attribute width : Millimeter = 680;
        attribute length : Millimeter = 1210;
        attribute mass : Kilogram = 34;
        attribute casterDiameter : Millimeter = 100;
        attribute stableWithRatedLoad : Boolean;
    }

    part def Mast {
        attribute height : Millimeter = 1320;
        attribute allowableBendingForce : ForceLimit = 3200;
    }

    part def Boom {
        attribute minimumHeight : Millimeter = 620;
        attribute maximumHeight : Millimeter = 1820;
        attribute currentHeight : Millimeter;
        attribute reach : Millimeter = 760;
        port supportPort : PatientSupportPort;
    }

    part def SpreaderBar {
        attribute width : Millimeter = 450;
        attribute slingHookCount : Integer = 4;
        attribute latchClosed : Boolean;
        port supportPort : PatientSupportPort;
    }

    part def PatientSlingAssembly {
        attribute slingRatedLoad : Kilogram = 205;
        attribute attachmentVerified : Boolean;
        port supportPort : PatientSupportPort;
    }

    part def LinearActuator {
        attribute stroke : Millimeter = 400;
        attribute ratedPushForce : Newton = 8000;
        attribute liftSpeedLoaded : LiftSpeed = 28;
        attribute selfLocking : Boolean = true;
        port controlPort : ActuatorControlPort;
        port powerPort : PowerPort;
    }

    part def BatteryPack {
        attribute nominalVoltage : Volt = 24;
        attribute capacity : AmpereHour = 5;
        attribute stateOfCharge : Percent;
        attribute lowBatteryThreshold : Percent = 20;
        port powerPort : PowerPort;
    }

    part def Charger {
        attribute inputVoltage : Volt = 120;
        attribute outputVoltage : Volt = 24;
        attribute chargeCurrent : Real = 1.5;
        port powerPort : PowerPort;
    }

    part def HandControl {
        attribute pendantCableLength : Millimeter = 900;
        attribute raiseButtonPressed : Boolean;
        attribute lowerButtonPressed : Boolean;
        attribute stopButtonPressed : Boolean;
        port controlPort : CaregiverControlPort;
    }

    part def EmergencyStopSwitch {
        attribute latched : Boolean;
        port controlPort : CaregiverControlPort;
    }

    part def LoadSensor {
        attribute measurementRange : Kilogram = 250;
        attribute accuracy : Kilogram = 2;
        port sensorPort : SensorPort;
    }

    part def HeightSensor {
        attribute minimumReadableHeight : Millimeter = 500;
        attribute maximumReadableHeight : Millimeter = 1900;
        port sensorPort : SensorPort;
    }

    part def WheelBrakeSystem {
        attribute brakesEngaged : Boolean;
        attribute holdingForce : Newton = 1200;
        port brakePort : BrakePort;
    }

    part def ControlUnit {
        attribute currentState : LiftState;
        attribute selectedMode : LiftMode;
        attribute maximumPatientMass : Kilogram = 200;
        attribute overloadLimit : Kilogram = 210;
        attribute minimumBatteryForLift : Percent = 20;
        port caregiverPort : CaregiverControlPort;
        port actuatorPort : ActuatorControlPort;
        port loadSensorPort : SensorPort;
        port heightSensorPort : SensorPort;
        port brakePort : BrakePort;
        port powerPort : PowerPort;
    }

    part def AlarmIndicator {
        attribute audibleLevel : Real = 70;
        attribute visualIndicatorActive : Boolean;
        port controlPort : CaregiverControlPort;
    }

    part def PatientLift {
        attribute primaryFunction : String = "Safely raise, lower, support, and transfer a patient between nearby surfaces using a powered lifting boom and sling under caregiver control.";
        attribute ratedPatientMass : Kilogram = 200;
        attribute serviceMass : Kilogram = 48;
        attribute minimumBoomHeight : Millimeter = 620;
        attribute maximumBoomHeight : Millimeter = 1820;
        attribute nominalLiftSpeed : LiftSpeed = 28;

        part base : BaseFrame;
        part mast : Mast;
        part boom : Boom;
        part spreaderBar : SpreaderBar;
        part slingAssembly : PatientSlingAssembly;
        part actuator : LinearActuator;
        part battery : BatteryPack;
        part charger : Charger;
        part handControl : HandControl;
        part emergencyStop : EmergencyStopSwitch;
        part loadSensor : LoadSensor;
        part heightSensor : HeightSensor;
        part brakes : WheelBrakeSystem;
        part controller : ControlUnit;
        part alarm : AlarmIndicator;

        port patientInterface : PatientSupportPort;
        port caregiverInterface : CaregiverControlPort;
        port chargingInterface : PowerPort;

        connect patientInterface to slingAssembly.supportPort;
        connect slingAssembly.supportPort to spreaderBar.supportPort;
        connect spreaderBar.supportPort to boom.supportPort;

        connect caregiverInterface to handControl.controlPort;
        connect handControl.controlPort to controller.caregiverPort;
        connect emergencyStop.controlPort to controller.caregiverPort;
        connect alarm.controlPort to controller.caregiverPort;

        connect controller.actuatorPort to actuator.controlPort;
        connect controller.loadSensorPort to loadSensor.sensorPort;
        connect controller.heightSensorPort to heightSensor.sensorPort;
        connect controller.brakePort to brakes.brakePort;

        connect battery.powerPort to controller.powerPort;
        connect battery.powerPort to actuator.powerPort;
        connect chargingInterface to charger.powerPort;
        connect charger.powerPort to battery.powerPort;
    }

    /* Behavior */

    action def VerifySlingAttachment {
        in item patient : Patient;
        in item sling : Sling;
        out attribute verified : Boolean;

        first start;
        then checkSling;
        action checkSling {
            verified = sling.properlyAttached and sling.attachmentPoints >= 4 and patient.supported;
        }
        then done;
    }

    action def MeasurePatientLoad {
        in item patient : Patient;
        out item load : MechanicalLoad;

        first start;
        then computeLoad;
        action computeLoad {
            load.mass = patient.mass;
            load.force = patient.mass * 9.81;
        }
        then done;
    }

    action def RaisePatient {
        in item command : LiftCommand;
        in item load : MechanicalLoad;
        in attribute currentHeight : Millimeter;
        out attribute newHeight : Millimeter;
        out item status : LiftStatus;

        first start;
        then raise;
        action raise {
            newHeight = currentHeight + 28;
            status.state = LiftState::lifting;
            status.boomHeight = newHeight;
            status.loadMeasured = load.mass;
            status.faultPresent = false;
        }
        then hold;
        action hold {
            status.state = LiftState::holding;
        }
        then done;
    }

    action def LowerPatient {
        in item command : LiftCommand;
        in item load : MechanicalLoad;
        in attribute currentHeight : Millimeter;
        out attribute newHeight : Millimeter;
        out item status : LiftStatus;

        first start;
        then lower;
        action lower {
            newHeight = currentHeight - 28;
            status.state = LiftState::lowering;
            status.boomHeight = newHeight;
            status.loadMeasured = load.mass;
            status.faultPresent = false;
        }
        then hold;
        action hold {
            status.state = LiftState::holding;
        }
        then done;
    }

    action def StopMotion {
        out item status : LiftStatus;

        first start;
        then stopActuator;
        action stopActuator {
            status.state = LiftState::holding;
            status.faultPresent = false;
        }
        then done;
    }

    action def EngageEmergencyStop {
        out item status : LiftStatus;
        out item alarm : AlarmSignal;

        first start;
        then interruptPower;
        action interruptPower {
            status.state = LiftState::emergencyStop;
            status.faultPresent = true;
            alarm.active = true;
            alarm.messageCode = "EMERGENCY_STOP_ACTIVE";
        }
        then done;
    }

    action def DetectUnsafeCondition {
        in item load : MechanicalLoad;
        in item battery : BatteryEnergy;
        in attribute slingVerified : Boolean;
        out attribute unsafe : Boolean;
        out item alarm : AlarmSignal;

        first start;
        then evaluate;
        action evaluate {
            unsafe = load.mass > 210 or battery.capacityRemaining < 20 or not slingVerified;
            alarm.active = unsafe;
            alarm.messageCode = if unsafe then "UNSAFE_LIFT_CONDITION" else "NO_ALARM";
        }
        then done;
    }

    state def PatientLiftOperatingStateMachine {
        attribute state : LiftState;
        attribute loadMeasured : Kilogram;
        attribute batteryRemaining : Percent;
        attribute boomHeight : Millimeter;
        attribute slingVerified : Boolean;
        attribute emergencyStopLatched : Boolean;

        entry action initialize {
            state = LiftState::off;
        }

        state off;
        state ready;
        state lifting;
        state lowering;
        state holding;
        state faulted;
        state emergencyStop;
        state charging;

        transition off_to_ready
            first off
            accept LiftCommand
            if command == CommandKind::reset
            then ready;

        transition ready_to_lifting
            first ready
            accept LiftCommand
            if command == CommandKind::raise and slingVerified and loadMeasured <= 200 and batteryRemaining >= 20
            then lifting;

        transition ready_to_lowering
            first ready
            accept LiftCommand
            if command == CommandKind::lower and slingVerified and loadMeasured <= 200 and batteryRemaining >= 20
            then lowering;

        transition lifting_to_holding
            first lifting
            accept LiftCommand
            if command == CommandKind::stop or boomHeight >= 1820
            then holding;

        transition lowering_to_holding
            first lowering
            accept LiftCommand
            if command == CommandKind::stop or boomHeight <= 620
            then holding;

        transition holding_to_lifting
            first holding
            accept LiftCommand
            if command == CommandKind::raise and batteryRemaining >= 20
            then lifting;

        transition holding_to_lowering
            first holding
            accept LiftCommand
            if command == CommandKind::lower
            then lowering;

        transition any_to_faulted
            first ready
            accept AlarmSignal
            if active
            then faulted;

        transition faulted_to_ready
            first faulted
            accept LiftCommand
            if command == CommandKind::reset and not emergencyStopLatched
            then ready;

        transition any_to_emergencyStop
            first ready
            accept LiftCommand
            if command == CommandKind::emergencyStop
            then emergencyStop;

        transition emergencyStop_to_ready
            first emergencyStop
            accept LiftCommand
            if command == CommandKind::reset and not emergencyStopLatched
            then ready;

        transition off_to_charging
            first off
            accept ElectricalPower
            if voltage >= 24
            then charging;

        transition charging_to_ready
            first charging
            accept BatteryEnergy
            if capacityRemaining >= 95
            then ready;
    }

    /* Requirements */

    requirement def PrimaryFunctionRequirement {
        doc /* The patient lift shall safely raise, lower, support, and transfer a patient between nearby surfaces using a caregiver-controlled powered lifting mechanism. */
        attribute requiredRatedPatientMass : Kilogram = 200;
    }

    requirement def RatedLoadRequirement {
        doc /* The lift shall support and move a patient mass up to 200 kg without structural failure or loss of control. */
        attribute maximumPatientMass : Kilogram = 200;
    }

    requirement def OverloadProtectionRequirement {
        doc /* The lift shall inhibit powered lifting and issue an alarm when measured suspended load exceeds 210 kg. */
        attribute overloadLimit : Kilogram = 210;
    }

    requirement def LiftRangeRequirement {
        doc /* The boom shall provide a vertical lifting range from no higher than 620 mm at the low position to at least 1820 mm at the high position. */
        attribute lowPositionMaximum : Millimeter = 620;
        attribute highPositionMinimum : Millimeter = 1820;
    }

    requirement def ControlledMotionRequirement {
        doc /* The lift shall raise and lower the patient smoothly at a loaded nominal speed not exceeding 35 mm/s. */
        attribute maximumLoadedSpeed : LiftSpeed = 35;
    }

    requirement def BatteryRequirement {
        doc /* The lift shall prevent new powered lift motion when battery capacity is below 20 percent while still allowing controlled lowering. */
        attribute minimumBatteryForRaising : Percent = 20;
    }

    requirement def EmergencyStopRequirement {
        doc /* The lift shall stop actuator motion and enter an emergency stop state within one second after emergency stop activation. */
        attribute maximumStopTime : Second = 1;
    }

    requirement def SlingAttachmentRequirement {
        doc /* The lift shall require verified sling attachment at four attachment points before raising a patient. */
        attribute minimumAttachmentPoints : Integer = 4;
    }

    requirement def BrakeRequirement {
        doc /* The wheel brake system shall provide at least 1200 N holding force when the patient is suspended and transfer is not in progress. */
        attribute minimumHoldingForce : Newton = 1200;
    }

    requirement def StatusFeedbackRequirement {
        doc /* The lift shall provide caregiver-visible status for operating state, boom height, battery level, load, and active fault condition. */
    }

    /* Requirement Satisfaction */

    satisfy PrimaryFunctionRequirement by PatientLift;
    satisfy RatedLoadRequirement by PatientLift;
    satisfy RatedLoadRequirement by Boom;
    satisfy RatedLoadRequirement by SpreaderBar;
    satisfy RatedLoadRequirement by PatientSlingAssembly;
    satisfy OverloadProtectionRequirement by ControlUnit;
    satisfy OverloadProtectionRequirement by LoadSensor;
    satisfy LiftRangeRequirement by Boom;
    satisfy ControlledMotionRequirement by LinearActuator;
    satisfy BatteryRequirement by BatteryPack;
    satisfy BatteryRequirement by ControlUnit;
    satisfy EmergencyStopRequirement by EmergencyStopSwitch;
    satisfy EmergencyStopRequirement by ControlUnit;
    satisfy SlingAttachmentRequirement by PatientSlingAssembly;
    satisfy SlingAttachmentRequirement by ControlUnit;
    satisfy BrakeRequirement by WheelBrakeSystem;
    satisfy StatusFeedbackRequirement by HandControl;
    satisfy StatusFeedbackRequirement by AlarmIndicator;
    satisfy StatusFeedbackRequirement by ControlUnit;

    /* System Instance */

    part patientLiftSystem : PatientLift {
        attribute ratedPatientMass = 200;
        attribute serviceMass = 48;
        attribute nominalLiftSpeed = 28;

        part base {
            attribute stableWithRatedLoad = true;
        }

        part boom {
            attribute currentHeight = 620;
        }

        part slingAssembly {
            attribute attachmentVerified = false;
        }

        part battery {
            attribute stateOfCharge = 100;
        }

        part controller {
            attribute currentState = LiftState::ready;
            attribute selectedMode = LiftMode::powered;
            attribute maximumPatientMass = 200;
            attribute overloadLimit = 210;
            attribute minimumBatteryForLift = 20;
        }

        part brakes {
            attribute brakesEngaged = true;
        }

        part emergencyStop {
            attribute latched = false;
        }
    }

}