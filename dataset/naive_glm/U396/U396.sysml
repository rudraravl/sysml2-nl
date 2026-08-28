package TherapeuticStandingFrame {
    import ScalarValues::*;
    import ISQ::*;

    // =================================================================
    // Value Types
    // =================================================================

    value type MassKg :> MassValue {
        doc "Mass measured in kilograms.";
        unit 'kg';
    }

    value type AngleDeg :> PlaneAngleValue {
        doc "Tilt angle measured in degrees.";
        unit 'deg';
    }

    value type AngularVelocityDegPerSec :> AngularVelocityValue {
        doc "Angular velocity in degrees per second.";
        unit 'deg/s';
    }

    value type VoltageV :> ElectricPotentialValue {
        doc "Electric potential in volts.";
        unit V;
    }

    value type ChargeAh :> ElectricChargeValue {
        doc "Electric charge in ampere-hours.";
        unit Ah;
    }

    value type CurrentA :> ElectricCurrentValue {
        doc "Electric current in amperes.";
        unit A;
    }

    value type ForceN :> ForceValue {
        doc "Force in newtons.";
        unit N;
    }

    value type LengthM :> LengthValue {
        doc "Length in meters.";
        unit m;
    }

    // =================================================================
    // Enumerations
    // =================================================================

    enum def TiltCommandKind {
        doc "Kind of command sent to the tilt mechanism.";
        literals UP, DOWN, STOP, EMERGENCY_STOP;
    }

    enum def StrapLocationKind {
        doc "Anatomical location of a restraint strap.";
        literals PELVIS, CHEST, FEET_LEFT, FEET_RIGHT;
    }

    enum def TiltStateKind {
        doc "Operational state of the tilt mechanism.";
        literals SEATED, TILTING_UP, STANDING_LOCKED, TILTING_DOWN, FAULT;
    }

    // =================================================================
    // Item Definitions
    // =================================================================

    item def ElectricPower {
        doc "Electric power flow characterized by voltage and current.";
        attribute voltage : VoltageV;
        attribute current : CurrentA;
    }

    item def TiltCommand {
        doc "Command to control the tilt mechanism.";
        attribute kind : TiltCommandKind;
        attribute targetAngle : AngleDeg;
    }

    item def FrameStatus {
        doc "Operational status of the standing frame.";
        attribute currentAngle : AngleDeg;
        attribute locked : Boolean;
        attribute moving : Boolean;
        attribute emergencyStopActive : Boolean;
    }

    item def RestraintContact {
        doc "Contact force between a restraint strap and the patient.";
        attribute location : StrapLocationKind;
        attribute force : ForceN;
    }

    item def MotionTransfer {
        doc "Motion transferred from the actuator to the support platform.";
        attribute angle : AngleDeg;
        attribute angularVelocity : AngularVelocityDegPerSec;
    }

    // =================================================================
    // Port Definitions
    // =================================================================

    port def CommandPort {
        doc "Port for receiving tilt commands and reporting frame status.";
        in item command : TiltCommand;
        out item status : FrameStatus;
    }

    port def PowerPort {
        doc "Bidirectional port for electric power flow.";
        in out item power : ElectricPower;
    }

    port def MotionPort {
        doc "Port for receiving motion transfer from the tilt mechanism.";
        in item motion : MotionTransfer;
    }

    port def RestraintPort {
        doc "Bidirectional port for restraint contact interaction.";
        in out item contact : RestraintContact;
    }

    // =================================================================
    // Part Definitions – Structural Components
    // =================================================================

    part def StructuralBase {
        doc "Wide, stable base providing the foundation for the standing frame.";
        attribute length : LengthM = 1.0 [m];
        attribute width : LengthM = 0.8 [m];
        attribute maxLoad : MassKg = 150 [kg];
    }

    part def VerticalSupport {
        doc "Vertical structural support connecting the base to the upper frame.";
        attribute height : LengthM = 1.6 [m];
        attribute maxLoad : MassKg = 150 [kg];
    }

    part def StructuralFrame {
        doc "Robust structural frame composed of a wide stable base and two vertical supports, engineered to safely handle patients weighing up to 150 kg.";
        part base : StructuralBase;
        part verticalSupports[2] : VerticalSupport;
        attribute maxPatientMass : MassKg = 150 [kg];
    }

    // =================================================================
    // Part Definitions – Tilt Mechanism
    // =================================================================

    part def Actuator {
        doc "Electrically powered linear actuator that smoothly and slowly lifts the patient support platform.";
        port electricIn : PowerPort;
        port motionOut : ~MotionPort;
        attribute maxSpeed : AngularVelocityDegPerSec = 2.0 [deg/s];
        attribute minAngle : AngleDeg = 0 [deg];
        attribute maxAngle : AngleDeg = 85 [deg];

        action extend {
            doc "Smoothly extend the actuator to lift the platform toward standing.";
            in targetAngle : AngleDeg;
        }

        action retract {
            doc "Smoothly retract the actuator to lower the platform to seated.";
        }

        action stop {
            doc "Immediately halt actuator motion.";
        }
    }

    part def MechanicalLock {
        doc "Mechanical locking system that secures the frame at the desired tilt angle.";
        attribute locked : Boolean = false;
        attribute lockAngle : AngleDeg = 0 [deg];

        action engage {
            doc "Engage the mechanical lock at the specified angle.";
            in angle : AngleDeg;
            locked = true;
            lockAngle = angle;
        }

        action disengage {
            doc "Disengage the mechanical lock.";
            locked = false;
        }
    }

    part def TiltMechanism {
        doc "Electrically powered tilt mechanism that lifts the entire patient support platform from a horizontal seated position (0 deg) to a near-vertical standing position (up to 85 deg). Tilt speed is controlled and a mechanical lock secures the frame at the desired angle.";

        port commandIn : CommandPort;
        port powerIn : PowerPort;
        port motionOut : ~MotionPort;

        part actuator : Actuator;
        part lock : MechanicalLock;

        attribute currentAngle : AngleDeg = 0 [deg];
        attribute tiltSpeed : AngularVelocityDegPerSec = 1.5 [deg/s];
        attribute targetAngle : AngleDeg = 0 [deg];
        attribute tiltState : TiltStateKind = TiltStateKind::SEATED;

        state tiltStateMachine {
            doc "State machine controlling tilt mechanism operation.";

            state seated {
                doc "Frame in seated (horizontal) position.";
                entry { currentAngle = 0 [deg]; tiltState = TiltStateKind::SEATED; }
            }

            state tiltingUp {
                doc "Platform tilting upward toward the standing position.";
                entry { tiltState = TiltStateKind::TILTING_UP; }
                do { currentAngle = currentAngle + tiltSpeed; }
            }

            state standingLocked {
                doc "Platform at standing angle with mechanical lock engaged.";
                entry {
                    tiltState = TiltStateKind::STANDING_LOCKED;
                    lock.engage(currentAngle);
                }
            }

            state tiltingDown {
                doc "Platform tilting downward back to the seated position.";
                entry { tiltState = TiltStateKind::TILTING_DOWN; lock.disengage(); }
                do { currentAngle = currentAngle - tiltSpeed; }
            }

            state fault {
                doc "Fault state — all motion halted.";
                entry { tiltState = TiltStateKind::FAULT; }
            }

            transition from seated to tiltingUp
                when commandIn.command.kind == TiltCommandKind::UP;
            transition from tiltingUp to standingLocked
                when currentAngle >= targetAngle;
            transition from standingLocked to tiltingDown
                when commandIn.command.kind == TiltCommandKind::DOWN;
            transition from tiltingDown to seated
                when currentAngle <= 0 [deg];
            transition from seated to fault
                when commandIn.command.kind == TiltCommandKind::EMERGENCY_STOP;
            transition from tiltingUp to fault
                when commandIn.command.kind == TiltCommandKind::EMERGENCY_STOP;
            transition from standingLocked to fault
                when commandIn.command.kind == TiltCommandKind::EMERGENCY_STOP;
            transition from tiltingDown to fault
                when commandIn.command.kind == TiltCommandKind::EMERGENCY_STOP;
        }

        flow from powerIn.power to actuator.electricIn.power;
        connection from actuator.motionOut to motionOut;

        action setTarget {
            doc "Set the target tilt angle.";
            in angle : AngleDeg;
            targetAngle = angle;
        }

        action tiltUp {
            doc "Begin tilting up to the standing position.";
            setTarget(85 [deg]);
        }

        action tiltDown {
            doc "Begin tilting down to the seated position.";
            setTarget(0 [deg]);
        }

        action lockInStanding {
            doc "Engage the mechanical lock at the current standing angle.";
            lock.engage(currentAngle);
        }
    }

    // =================================================================
    // Part Definitions – Support Platform
    // =================================================================

    part def Footplate {
        doc "Footplate for the patient's feet.";
        attribute width : LengthM = 0.4 [m];
        attribute depth : LengthM = 0.3 [m];
        attribute maxLoad : MassKg = 150 [kg];
    }

    part def KneeSupport {
        doc "Padded support for the patient's knees.";
        attribute padded : Boolean = true;
        attribute width : LengthM = 0.35 [m];
    }

    part def ChestPad {
        doc "Padded chest pad for upper body stability.";
        attribute padded : Boolean = true;
        attribute width : LengthM = 0.45 [m];
        attribute height : LengthM = 0.3 [m];
    }

    part def SupportPlatform {
        doc "Main support platform that includes a footplate for the feet, padded supports for the knees, and a chest pad for upper body stability.";
        part footplate : Footplate;
        part kneeSupports[2] : KneeSupport;
        part chestPad : ChestPad;
        port motionIn : MotionPort;
        port restraintInterface : RestraintPort;
        attribute maxPatientMass : MassKg = 150 [kg];
    }

    // =================================================================
    // Part Definitions – Restraint System
    // =================================================================

    part def RestraintStrap {
        doc "Adjustable restraint strap that secures the patient at a specific anatomical location.";
        attribute location : StrapLocationKind;
        attribute secured : Boolean = false;
        attribute maxRestraintForce : ForceN = 500 [N];
        port restraintOut : RestraintPort;

        action secure {
            doc "Secure the strap.";
            secured = true;
        }

        action release {
            doc "Release the strap.";
            secured = false;
        }
    }

    part def RestraintSystem {
        doc "Comprehensive restraint system featuring adjustable straps for the pelvis, chest, and feet. Straps are secured before any movement begins to hold the patient safely in place.";

        part pelvisStrap : RestraintStrap { :>> location = StrapLocationKind::PELVIS; }
        part chestStrap : RestraintStrap { :>> location = StrapLocationKind::CHEST; }
        part footStrapLeft : RestraintStrap { :>> location = StrapLocationKind::FEET_LEFT; }
        part footStrapRight : RestraintStrap { :>> location = StrapLocationKind::FEET_RIGHT; }

        attribute allSecured : Boolean = false;
        port restraintAggregate : RestraintPort;

        action secureAll {
            doc "Secure all restraint straps.";
            pelvisStrap.secure();
            chestStrap.secure();
            footStrapLeft.secure();
            footStrapRight.secure();
            allSecured = true;
        }

        action releaseAll {
            doc "Release all restraint straps.";
            pelvisStrap.release();
            chestStrap.release();
            footStrapLeft.release();
            footStrapRight.release();
            allSecured = false;
        }

        flow from pelvisStrap.restraintOut.contact to restraintAggregate.contact;
        flow from chestStrap.restraintOut.contact to restraintAggregate.contact;
        flow from footStrapLeft.restraintOut.contact to restraintAggregate.contact;
        flow from footStrapRight.restraintOut.contact to restraintAggregate.contact;
    }

    // =================================================================
    // Part Definitions – Control System
    // =================================================================

    part def UserInterface {
        doc "Simple user interface for a caregiver to operate the device.";
        attribute tiltUpPressed : Boolean = false;
        attribute tiltDownPressed : Boolean = false;
        attribute emergencyStopPressed : Boolean = false;
        port commandOut : ~CommandPort;

        action pressTiltUp {
            doc "Press the tilt-up button.";
            tiltUpPressed = true;
        }

        action pressTiltDown {
            doc "Press the tilt-down button.";
            tiltDownPressed = true;
        }

        action pressEmergencyStop {
            doc "Press the emergency stop button.";
            emergencyStopPressed = true;
        }
    }

    part def SafetyController {
        doc "Integrated safety controller with an emergency stop function that can halt all motion immediately.";
        port commandIn : CommandPort;
        port commandOut : ~CommandPort;
        attribute emergencyStopActive : Boolean = false;
        attribute faultDetected : Boolean = false;

        action haltAllMotion {
            doc "Halt all motion immediately.";
            emergencyStopActive = true;
        }

        action reset {
            doc "Reset the safety controller after an emergency stop.";
            emergencyStopActive = false;
            faultDetected = false;
        }

        state safetyState {
            state monitoring;
            state emergencyHalted;

            transition from monitoring to emergencyHalted
                when commandIn.command.kind == TiltCommandKind::EMERGENCY_STOP;
            transition from emergencyHalted to monitoring
                when faultDetected == false;
        }
    }

    part def Battery {
        doc "Rechargeable battery allowing for mobility and use away from a direct power outlet.";
        attribute voltage : VoltageV = 24 [V];
        attribute capacity : ChargeAh = 10 [Ah];
        attribute chargeLevel : Real = 1.0;
        attribute chargeCycles : Integer = 0;
        port chargingPort : PowerPort;
        port dischargePort : PowerPort;

        state batteryState {
            state idle;
            state charging;
            state discharging;
            state depleted;

            transition from idle to charging
                when chargingPort.power.voltage > 0 [V];
            transition from charging to idle
                when chargeLevel >= 1.0;
            transition from idle to discharging
                when chargeLevel > 0.0;
            transition from discharging to depleted
                when chargeLevel <= 0.0;
            transition from depleted to charging
                when chargingPort.power.voltage > 0 [V];
        }

        action charge {
            doc "Charge the battery.";
            in power : ElectricPower;
            chargeLevel = chargeLevel + 0.01;
        }

        action discharge {
            doc "Discharge the battery to supply power.";
            out power : ElectricPower;
            chargeLevel = chargeLevel - 0.01;
        }
    }

    part def ControlSystem {
        doc "Central control system that manages the entire operation. Includes a user interface for the caregiver, an integrated safety controller with emergency stop, and a rechargeable battery.";

        port powerIn : PowerPort;
        port powerOut : PowerPort;
        port motionControlPort : ~CommandPort;

        part userInterface : UserInterface;
        part safetyController : SafetyController;
        part battery : Battery;

        flow from powerIn.power to battery.chargingPort.power;
        flow from battery.dischargePort.power to powerOut.power;

        connection from userInterface.commandOut to safetyController.commandIn;
        connection from safetyController.commandOut to motionControlPort;
    }

    // =================================================================
    // Part Definition – Top-Level System
    // =================================================================

    part def TherapeuticStandingFrame {
        doc "Therapeutic standing frame system — medical equipment designed to safely assist patients with limited mobility in moving from a seated to a standing position, providing weight-bearing support for therapeutic benefits such as improving circulation, bone density, and muscle tone.";

        part frame : StructuralFrame;
        part tiltMechanism : TiltMechanism;
        part supportPlatform : SupportPlatform;
        part restraintSystem : RestraintSystem;
        part controlSystem : ControlSystem;

        port powerInput : PowerPort;

        attribute maxPatientMass : MassKg = 150 [kg];
        attribute maxTiltAngle : AngleDeg = 85 [deg];
        attribute minTiltAngle : AngleDeg = 0 [deg];

        connection from powerInput to controlSystem.powerIn;
        connection from controlSystem.powerOut to tiltMechanism.powerIn;
        connection from controlSystem.motionControlPort to tiltMechanism.commandIn;
        connection from tiltMechanism.motionOut to supportPlatform.motionIn;
        connection from restraintSystem.restraintAggregate to supportPlatform.restraintInterface;

        state operationalState {
            doc "Overall operational state machine for a typical therapy session.";

            state idle;
            state patientPositioning;
            state securingRestraints;
            state tiltingUp;
            state therapyStanding;
            state tiltingDown;
            state releasingRestraints;
            state emergencyHalted;

            transition from idle to patientPositioning;
            transition from patientPositioning to securingRestraints;
            transition from securingRestraints to tiltingUp
                when restraintSystem.allSecured == true;
            transition from tiltingUp to therapyStanding
                when tiltMechanism.tiltState == TiltStateKind::STANDING_LOCKED;
            transition from therapyStanding to tiltingDown;
            transition from tiltingDown to releasingRestraints
                when tiltMechanism.tiltState == TiltStateKind::SEATED;
            transition from releasingRestraints to idle;
            transition from idle to emergencyHalted
                when controlSystem.safetyController.emergencyStopActive == true;
            transition from patientPositioning to emergencyHalted
                when controlSystem.safetyController.emergencyStopActive == true;
            transition from securingRestraints to emergencyHalted
                when controlSystem.safetyController.emergencyStopActive == true;
            transition from tiltingUp to emergencyHalted
                when controlSystem.safetyController.emergencyStopActive == true;
            transition from therapyStanding to emergencyHalted
                when controlSystem.safetyController.emergencyStopActive == true;
            transition from tiltingDown to emergencyHalted
                when controlSystem.safetyController.emergencyStopActive == true;
            transition from releasingRestraints to emergencyHalted
                when controlSystem.safetyController.emergencyStopActive == true;
        }
    }

    // =================================================================
    // Action Definition – Therapeutic Session
    // =================================================================

    action def TherapeuticSession {
        doc "Typical sequence of operations for a therapeutic standing frame session.";
        in frame : TherapeuticStandingFrame;

        action positionPatient {
            doc "Position the patient on the support platform while the frame is in the seated position.";
        }

        action secureRestraints {
            doc "Secure all restraint straps (pelvis, chest, feet) before any movement begins.";
            frame.restraintSystem.secureAll();
        }

        action beginTiltUp {
            doc "Caregiver uses the controls to begin the slow upward tilt.";
            frame.controlSystem.userInterface.pressTiltUp();
        }

        action lockInStanding {
            doc "Frame locks in place at the target standing angle for the duration of the therapy.";
            frame.tiltMechanism.lockInStanding();
        }

        action performTherapy {
            doc "Weight-bearing therapy session — improves circulation, bone density, and muscle tone.";
        }

        action returnToSeated {
            doc "Frame smoothly returned to the seated position.";
            frame.controlSystem.userInterface.pressTiltDown();
        }

        action releaseRestraints {
            doc "Patient can be safely released.";
            frame.restraintSystem.releaseAll();
        }

        succession from positionPatient to secureRestraints;
        succession from secureRestraints to beginTiltUp;
        succession from beginTiltUp to lockInStanding;
        succession from lockInStanding to performTherapy;
        succession from performTherapy to returnToSeated;
        succession from returnToSeated to releaseRestraints;
    }

    // =================================================================
    // Requirements
    // =================================================================

    requirement WeightCapacity {
        doc "The system shall safely handle patients weighing up to 150 kg.";
        subject frame : TherapeuticStandingFrame;
        constraint { frame.maxPatientMass >= 150 [kg] }
        constraint { frame.frame.base.maxLoad >= 150 [kg] }
    }

    requirement TiltAngleRange {
        doc "The tilt mechanism shall lift the patient support platform from a horizontal (0 deg) to a near-vertical standing position (up to 85 deg).";
        subject frame : TherapeuticStandingFrame;
        constraint { frame.tiltMechanism.actuator.minAngle == 0 [deg] }
        constraint { frame.tiltMechanism.actuator.maxAngle >= 85 [deg] }
        constraint { frame.maxTiltAngle == 85 [deg] }
    }

    requirement ControlledTiltSpeed {
        doc "The tilt speed shall be controlled and slow for patient safety and comfort.";
        subject frame : TherapeuticStandingFrame;
        constraint { frame.tiltMechanism.tiltSpeed <= 2.0 [deg/s] }
    }

    requirement MechanicalLocking {
        doc "A mechanical locking system shall secure the frame at the desired angle.";
        subject frame : TherapeuticStandingFrame;
        constraint { frame.tiltMechanism.tiltState == TiltStateKind::STANDING_LOCKED
                    implies frame.tiltMechanism.lock.locked == true }
    }

    requirement EmergencyStopFunction {
        doc "An integrated safety controller with emergency stop function shall halt all motion immediately.";
        subject frame : TherapeuticStandingFrame;
        constraint { frame.controlSystem.userInterface.emergencyStopPressed == true
                    implies frame.controlSystem.safetyController.emergencyStopActive == true }
    }

    requirement RestraintSecurement {
        doc "The patient shall be secured with adjustable straps for the pelvis, chest, and feet before any movement begins.";
        subject frame : TherapeuticStandingFrame;
        constraint { frame.tiltMechanism.tiltState != TiltStateKind::SEATED
                    implies frame.restraintSystem.allSecured == true }
    }

    requirement BatteryOperation {
        doc "The system shall be powered by a rechargeable battery, allowing for mobility and use away from a direct power outlet.";
        subject frame : TherapeuticStandingFrame;
        constraint { frame.controlSystem.battery.voltage >= 24 [V] }
        constraint { frame.controlSystem.battery.capacity >= 5 [Ah] }
    }

    requirement SupportComponents {
        doc "The patient shall be supported by a main support platform with a footplate, padded knee supports, and a chest pad for upper body stability.";
        subject frame : TherapeuticStandingFrame;
        constraint { frame.supportPlatform.footplate.maxLoad >= 150 [kg] }
        constraint { frame.supportPlatform.kneeSupports.padded == true }
        constraint { frame.supportPlatform.chestPad.padded == true }
    }

    requirement UseSequence {
        doc "A typical use shall follow a clear sequence: position and secure patient while frame is seated; slowly tilt upward; lock at target standing angle for therapy; smoothly return to seated; release patient.";
        subject frame : TherapeuticStandingFrame;
    }
}
