package PoweredStandingWheelchair {
    import ScalarValues::*;

    // ===== Value Types with Units =====
    value type LengthValue :> Real { unit 'mm'; }
    value type MassValue :> Real { unit 'kg'; }
    value type AngleValue :> Real { unit 'deg'; }
    value type VoltageValue :> Real { unit 'V'; }
    value type CurrentValue :> Real {> Real { unit 'A'; }
    value type PressureValue :> Real { unit 'kPa'; }
    value type DurationValue :> Real { unit 's'; }
    value type TorqueValue :> Real { unit 'Nm'; }
    value type ForceValue :> Real { unit 'N'; }
    value type FrequencyValue :> Real { unit 'Hz'; }
    value type SpeedValue :> Real { unit 'm/s'; }
    value type PowerValue :> Real { unit 'W'; }
    value type PercentValue :> Real;

    // ===== Enumerations =====
    enum WheelchairMode { seated; standing; transitioning; }
    enum PostureCommand { standUp; sitDown; emergencyStop; idle; }
    enum LiftPosition { lowered; lifting; raised; lowering; }
    enum StabilizerStatus { retracted; deploying; deployed; retracting; }
    enum DriveEnableState { enabled; disabled; }
    enum TransitionPhase { checkingSafety; deployingStabilizers; disablingDrive; executingLift; completingTransition; complete; }

    // ===== Item Definitions =====
    item def ElectricalPower {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }

    item def UserPostureCommand {
        attribute command : PostureCommand;
    }

    item def JoystickInput {
        attribute forwardSpeed : Real;
        attribute turnRate : Real;
    }

    item def SensorData {
        attribute timestamp : DurationValue;
    }

    item def TiltData :> SensorData {
        attribute pitchAngle : AngleValue;
        attribute rollAngle : AngleValue;
        attribute isLevel : Boolean;
    }

    item def PressureData :> SensorData {
        attribute pressureValue : PressureValue;
        attribute userPresent : Boolean;
    }

    item def WheelchairStatus {
        attribute mode : WheelchairMode;
        attribute liftPosition : LiftPosition;
        attribute stabilizerStatus : StabilizerStatus;
        attribute driveState : DriveEnableState;
        attribute batteryLevel : PercentValue;
    }

    // ===== Port Definitions =====
    port def PowerOutputPort {
        out item power : ElectricalPower;
    }

    port def PowerInputPort {
        in item power : ElectricalPower;
    }

    port def UserCommandOutputPort {
        out item postureCommand : UserPostureCommand;
        out item joystick : JoystickInput;
        out attribute emergencyStopSignal : Boolean;
    }

    port def UserCommandInputPort {
        in item postureCommand : UserPostureCommand;
        in item joystick : JoystickInput;
        in attribute emergencyStopSignal : Boolean;
    }

    port def SensorOutputPort {
        out item data : SensorData;
    }

    port def SensorInputPort {
        in item data : SensorData;
    }

    port def DriveControlOutputPort {
        out attribute enable : Boolean;
        out attribute leftTorque : TorqueValue;
        out attribute rightTorque : TorqueValue;
    }

    port def DriveControlInputPort {
        in attribute enable : Boolean;
        in attribute leftTorque : TorqueValue;
        in attribute rightTorque : TorqueValue;
    }

    port def StabilizerControlOutputPort {
        out attribute deploy : Boolean;
    }

    port def StabilizerControlInputPort {
        in attribute deploy : Boolean;
    }

    port def LiftControlOutputPort {
        out attribute liftCommand : LiftPosition;
        out attribute liftSpeed : SpeedValue;
    }

    port def LiftControlInputPort {
        in attribute liftCommand : LiftPosition;
        in attribute liftSpeed : SpeedValue;
    }

    port def StatusOutputPort {
        out item status : WheelchairStatus;
    }

    port def StatusInputPort {
        in item status : WheelchairStatus;
    }

    // ===== Part Definitions =====
    part def MainFrame {
        attribute maxLoadCapacity : MassValue = 150;
        attribute frameWeight : MassValue = 45;
    }

    part def DriveWheel {
        attribute wheelDiameter : LengthValue = 350;
    }

    part def DriveMotor {
        attribute maxTorque : TorqueValue = 12;
        attribute maxSpeed : SpeedValue = 6;
        attribute currentTorque : TorqueValue;
        attribute currentSpeed : SpeedValue;

        port powerIn : PowerInputPort;
        port controlIn : DriveControlInputPort;

        action applyTorque;
        action stopMotor;

        state MotorStateMachine {
            transition initial -> motorDisabled;
            state motorDisabled {
                entry action { currentTorque = 0; currentSpeed = 0; }
            }
            state motorEnabled {
                do applyTorque;
            }
            transition motorDisabled -> motorEnabled when controlIn.enable == true;
            transition motorEnabled -> motorDisabled when controlIn.enable == false;
        }
    }

    part def BatteryPack {
        attribute nominalVoltage : VoltageValue = 24;
        attribute capacity : CurrentValue = 50;
        attribute chargeLevel : PercentValue = 100;
        attribute minChargeLevel : PercentValue = 15;

        port powerOut : PowerOutputPort;

        action discharge;
        action recharge;
        action monitorChargeLevel;
    }

    part def LiftActuator {
        attribute maxLiftHeight : LengthValue = 600;
        attribute liftForce : ForceValue = 1500;
        attribute nominalLiftSpeed : SpeedValue = 0.05;
        attribute currentHeight : LengthValue = 0;

        port controlIn : LiftControlInputPort;

        action raise;
        action lower;
        action holdPosition;

        state LiftStateMachine {
            transition initial -> liftLowered;
            state liftLowered {
                entry action { currentHeight = 0; }
                do holdPosition;
            }
            state liftRaising {
                do raise;
            }
            state liftRaised {
                entry action { currentHeight = maxLiftHeight; }
                do holdPosition;
            }
            state liftLowering {
                do lower;
            }
            transition liftLowered -> liftRaising when controlIn.liftCommand == LiftPosition::lifting;
            transition liftRaising -> liftRaised when currentHeight >= maxLiftHeight;
            transition liftRaised -> liftLowering when controlIn.liftCommand == LiftPosition::lowering;
            transition liftLowering -> liftLowered when currentHeight <= 0;
        }
    }

    part def StabilizerLeg {
        attribute extensionLength : LengthValue = 200;
        attribute isDeployed : Boolean = false;
        attribute location : String;

        port controlIn : StabilizerControlInputPort;

        action extend;
        action retract;

        state StabilizerStateMachine {
            transition initial -> legRetracted;
            state legRetracted {
                entry action { isDeployed = false; }
            }
            state legDeploying {
                do extend;
            }
            state legDeployed {
                entry action { isDeployed = true; }
            }
            state legRetracting {
                do retract;
            }
            transition legRetracted -> legDeploying when controlIn.deploy == true;
            transition legDeploying -> legDeployed when isDeployed == true;
            transition legDeployed -> legRetracting when controlIn.deploy == false;
            transition legRetracting -> legRetracted when isDeployed == false;
        }
    }

    part def TiltSensor {
        attribute maxSafeTiltAngle : AngleValue = 5;
        attribute pitch : AngleValue = 0;
        attribute roll : AngleValue = 0;
        attribute isLevel : Boolean = true;

        port dataOut : SensorOutputPort;

        action readTilt {
            action measurePitch;
            then action measureRoll;
            then action evaluateLevel;
        }
    }

    part def SeatPressureSensor {
        attribute minAcceptablePressure : PressureValue = 2;
        attribute maxAcceptablePressure : PressureValue = 150;
        attribute currentPressure : PressureValue = 0;
        attribute userPresent : Boolean = false;

        port dataOut : SensorOutputPort;

        action readPressure {
            action measurePressure;
            then action evaluateUserPresence;
        }
    }

    part def UserInterfacePanel {
        attribute buttonCount : Integer = 4;

        port commandOut : UserCommandOutputPort;
        port statusIn : StatusInputPort;

        action pressStandButton;
        action pressSitButton;
        action pressEmergencyStop;
        action readJoystick;
        action updateStatusDisplay;
    }

    part def DriveSystemAssembly {
        part leftDriveMotor : DriveMotor;
        part rightDriveMotor : DriveMotor;
        part leftWheel : DriveWheel;
        part rightWheel : DriveWheel;
    }

    part def CentralControlUnit {
        attribute processingFrequency : FrequencyValue = 100;
        attribute currentMode : WheelchairMode = WheelchairMode::seated;
        attribute standButtonPressed : Boolean = false;
        attribute sitButtonPressed : Boolean = false;
        attribute emergencyStopPressed : Boolean = false;
        attribute tiltSafetyOK : Boolean = false;
        attribute pressureSafetyOK : Boolean = false;
        attribute allSafetyChecksPassed : Boolean = false;
        attribute stabilizersDeployed : Boolean = false;
        attribute driveDisabled : Boolean = false;
        attribute liftOrDescentComplete : Boolean = false;
        attribute transitionComplete : Boolean = false;
        attribute isStandingUp : Boolean = false;
        attribute cleanupComplete : Boolean = false;

        port powerIn : PowerInputPort;
        port userCommandIn : UserCommandInputPort;
        port tiltSensorIn : SensorInputPort;
        port pressureSensorIn : SensorInputPort;
        port driveControlOut : DriveControlOutputPort;
        port frontStabilizerOut : StabilizerControlOutputPort;
        port rearStabilizerOut : StabilizerControlOutputPort;
        port liftControlOut : LiftControlOutputPort;
        port statusOut : StatusOutputPort;

        action checkTiltSafety;
        action checkPressureSafety;
        action verifyAllSafetyConditions;
        action deployStabilizers;
        action retractStabilizers;
        action disableDriveSystem;
        action enableDriveSystem;
        action executeLift;
        action executeDescent;
        action performFullTransition;

        action performStandingSequence {
            action verifySafety {
                action checkTilt;
                action checkPressure;
            }
            then action deployLegs;
            then action disableDrive;
            then action lift;
            then action markComplete;
        }

        action performSittingSequence {
            action verifySafety2 {
                action checkTilt2;
                action checkPressure2;
            }
            then action deployLegs2;
            then action disableDrive2;
            then action descend;
            then action reenableDrive;
            then action retractLegs;
            then action markComplete2;
        }

        action processUserInput;
        action updateStatus;

        state ControlUnitStateMachine {
            transition initial -> seatedMode;

            state seatedMode {
                entry action { currentMode = WheelchairMode::seated; }
                do processUserInput;
            }

            state transitioningMode {
                entry action {
                    currentMode = WheelchairMode::transitioning;
                    transitionComplete = false;
                    liftOrDescentComplete = false;
                    cleanupComplete = false;
                    stabilizersDeployed = false;
                    driveDisabled = false;
                }

                transition initial -> checkingSafety;

                state checkingSafety {
                    do action {
                        checkTiltSafety;
                        checkPressureSafety;
                    }
                }

                state deployingStabilizersState {
                    do deployStabilizers;
                }

                state disablingDriveState {
                    do disableDriveSystem;
                }

                state executingLiftState {
                    do action {
                        if isStandingUp {
                            executeLift;
                        } else {
                            executeDescent;
                        }
                    }
                }

                state completingTransitionState {
                    do action {
                        if isStandingUp == false {
                            enableDriveSystem;
                            retractStabilizers;
                        }
                    }
                    entry action { transitionComplete = true; }
                }

                transition checkingSafety -> deployingStabilizersState when allSafetyChecksPassed == true;
                transition deployingStabilizersState -> disablingDriveState when stabilizersDeployed == true;
                transition disablingDriveState -> executingLiftState when driveDisabled == true;
                transition executingLiftState -> completingTransitionState when liftOrDescentComplete == true;
            }

            state standingMode {
                entry action { currentMode = WheelchairMode::standing; }
                do processUserInput;
            }

            state emergencyStoppedState {
                entry action {
                    currentMode = WheelchairMode::seated;
                    disableDriveSystem;
                }
            }

            transition seatedMode -> transitioningMode when standButtonPressed == true && allSafetyChecksPassed == true;
            transition standingMode -> transitioningMode when sitButtonPressed == true;
            transition transitioningMode -> standingMode when transitionComplete == true && isStandingUp == true;
            transition transitioningMode -> seatedMode when transitionComplete == true && isStandingUp == false;
            transition seatedMode -> emergencyStoppedState when emergencyStopPressed == true;
            transition standingMode -> emergencyStoppedState when emergencyStopPressed == true;
            transition transitioningMode -> emergencyStoppedState when emergencyStopPressed == true;
        }
    }

    // ===== Main System =====
    part def PoweredStandingWheelchair {
        attribute systemWeight : MassValue = 120;
        attribute maxUserWeight : MassValue = 150;
        attribute maxSpeed : SpeedValue = 6;

        part mainFrame : MainFrame;
        part seatFrame : MainFrame;
        part liftActuator : LiftActuator;
        part driveSystem : DriveSystemAssembly;
        part battery : BatteryPack;
        part controlUnit : CentralControlUnit;
        part userInterface : UserInterfacePanel;
        part tiltSensor : TiltSensor;
        part seatPressureSensor : SeatPressureSensor;
        part frontStabilizer : StabilizerLeg {
            attribute redefinition location = 'front';
        }
        part rearStabilizer : StabilizerLeg {
            attribute redefinition location = 'rear';
        }

        connection battery.powerOut to controlUnit.powerIn;
        connection battery.powerOut to driveSystem.leftDriveMotor.powerIn;
        connection battery.powerOut to driveSystem.rightDriveMotor.powerIn;
        connection userInterface.commandOut to controlUnit.userCommandIn;
        connection controlUnit.statusOut to userInterface.statusIn;
        connection tiltSensor.dataOut to controlUnit.tiltSensorIn;
        connection seatPressureSensor.dataOut to controlUnit.pressureSensorIn;
        connection controlUnit.driveControlOut to driveSystem.leftDriveMotor.controlIn;
        connection controlUnit.driveControlOut to driveSystem.rightDriveMotor.controlIn;
        connection controlUnit.frontStabilizerOut to frontStabilizer.controlIn;
        connection controlUnit.rearStabilizerOut to rearStabilizer.controlIn;
        connection controlUnit.liftControlOut to liftActuator.controlIn;
    }

    // ===== Requirements =====
    requirement def PostureTransitionCapability {
        doc 'The system shall allow the user to safely transition between a seated driving position and an upright standing position while also functioning as a standard electric wheelchair.';
        subject s : PoweredStandingWheelchair;
    }

    requirement def StabilizerDeploymentRequirement {
        doc 'The system shall deploy front and rear stabilizer legs to the ground before any lifting or lowering begins.';
        subject s : PoweredStandingWheelchair;
    }

    requirement def DriveDisableDuringTransitionRequirement {
        doc 'The drive motors shall be disabled during the transitioning mode to prevent movement while the lift mechanism is in operation.';
        subject s : PoweredStandingWheelchair;
    }

    requirement def SafetySensorMonitoringRequirement {
        doc 'The central control unit shall continuously monitor the tilt sensor and seat pressure sensor for safety conditions.';
        subject s : CentralControlUnit;
    }

    requirement def LevelGroundCheckRequirement {
        doc 'The system shall verify the wheelchair is on stable level ground with tilt less than 5 degrees before allowing any posture transition.';
        subject s : TiltSensor;
    }

    requirement def UserPositionCheckRequirement {
        doc 'The system shall verify the user is properly positioned via the seat pressure sensor before allowing any posture transition attempt.';
        subject s : SeatPressureSensor;
    }

    requirement def EmergencyStopRequirement {
        doc 'The system shall provide an emergency stop button that immediately halts all motion disables all actuators and returns the wheelchair to a safe state.';
        subject s : UserInterfacePanel;
    }

    requirement def IndependentDriveMotorsRequirement {
        doc 'The system shall use two independent drive motors one for each main wheel powered by a central rechargeable battery for mobility.';
        subject s : DriveSystemAssembly;
    }

    requirement def BatteryPoweredRequirement {
        doc 'The system shall be powered by a central rechargeable battery providing electrical power to all subsystems including drive motors lift actuator and control unit.';
        subject s : BatteryPack;
    }

    requirement def AutomatedTransitionRequirement {
        doc 'The entire standing or sitting sequence shall be an automated process initiated by a single button press following a strict protocol of checking safety conditions deploying stabilizers disabling drive performing the lift or descent and then re-engaging the drive system upon return to seated mode.';
        subject s : CentralControlUnit;
    }

    requirement def ModeBasedOperationRequirement {
        doc 'The wheelchair shall operate in three distinct modes: a seated mode for normal driving a standing mode and a temporary transitioning mode where movement is locked for safety.';
        subject s : CentralControlUnit;
    }

    requirement def CentralControlOrchestration {
        doc 'A central control unit shall act as the brain of the system orchestrating all operations by processing commands from the user interface and monitoring all safety sensors.';
        subject s : CentralControlUnit;
    }

    // ===== Verifications =====
    verification def VerifyPostureTransition {
        subject s : PoweredStandingWheelchair;
        objective { doc 'Verify that the wheelchair can safely transition between seated and standing positions.'; }
    }

    verification def VerifyStabilizerDeployment {
        subject s : PoweredStandingWheelchair;
        objective { doc 'Verify that both front and rear stabilizer legs deploy to the ground before lifting or lowering begins.'; }
    }

    verification def VerifyDriveDisable {
        subject s : DriveSystemAssembly;
        objective { doc 'Verify that drive motors are disabled during the transitioning mode.'; }
    }

    verification def VerifySafetyMonitoring {
        subject s : CentralControlUnit;
        objective { doc 'Verify that the control unit continuously monitors tilt and pressure sensors.'; }
    }

    verification def VerifyLevelGround {
        subject s : TiltSensor;
        objective { doc 'Verify that the tilt sensor prevents posture transitions when ground tilt exceeds 5 degrees.'; }
    }

    verification def VerifyUserPosition {
        subject s : SeatPressureSensor;
        objective { doc 'Verify that the pressure sensor confirms user presence before allowing posture transition.'; }
    }

    verification def VerifyEmergencyStop {
        subject s : UserInterfacePanel;
        objective { doc 'Verify that the emergency stop button halts all motion and disables all actuators immediately.'; }
    }

    verification def VerifyIndependentDriveMotors {
        subject s : DriveSystemAssembly;
        objective { doc 'Verify that two independent drive motors are present one for each main wheel.'; }
    }

    verification def VerifyBatteryPower {
        subject s : BatteryPack;
        objective { doc 'Verify that the rechargeable battery powers all subsystems.'; }
    }

    verification def VerifyAutomatedTransition {
        subject s : CentralControlUnit;
        objective { doc 'Verify that a single button press initiates the full automated transition sequence following the strict safety protocol.'; }
    }

    verification def VerifyModeBasedOperation {
        subject s : CentralControlUnit;
        objective { doc 'Verify that the wheelchair operates in seated standing and transitioning modes with movement locked during transition.'; }
    }
}
