package StandingWheelchairSystem {
    private import ISQ::*;
    private import ScalarValues::*;

    attribute def StandCommand;
    attribute def SitCommand;
    attribute def EmergencyStopCommand;
    attribute def DriveEnableSignal;
    attribute def DriveDisableSignal;
    attribute def DeployStabilizerSignal;
    attribute def RetractStabilizerSignal;
    attribute def StabilizerDeployedSignal;
    attribute def StabilizerRetractedSignal;
    attribute def LiftUpSignal;
    attribute def LiftDownSignal;
    attribute def LiftCompleteSignal;
    attribute def LiftDownCompleteSignal;

    port def PowerPort {
        out attribute voltage :> electricPotential;
        out attribute current :> electricCurrent;
    }

    port def UICmdPort {
        in attribute command :> String;
    }

    port def TiltOutPort {
        out attribute isLevel : Boolean;
        out attribute tiltAngle :> planeAngle;
    }

    port def TiltInPort {
        in attribute isLevel : Boolean;
        in attribute tiltAngle :> planeAngle;
    }

    port def PressureOutPort {
        out attribute isOccupied : Boolean;
        out attribute forceValue :> force;
    }

    port def PressureInPort {
        in attribute isOccupied : Boolean;
        in attribute forceValue :> force;
    }

    port def DriveCmdPort {
        in attribute enable : Boolean;
    }

    port def LiftCmdPort {
        in attribute command :> String;
    }

    port def StabilizerCmdPort {
        in attribute command :> String;
    }

    port def FeedbackPort {
        out attribute status :> String;
    }

    connection def PowerFlow {
        end : PowerPort;
        end : PowerPort;
    }

    connection def CmdFlow {
        end : UICmdPort;
        end : UICmdPort;
    }

    connection def TiltFlow {
        end : TiltOutPort;
        end : TiltInPort;
    }

    connection def PressureFlow {
        end : PressureOutPort;
        end : PressureInPort;
    }

    connection def DriveFlow {
        end : DriveCmdPort;
        end : DriveCmdPort;
    }

    connection def LiftFlow {
        end : LiftCmdPort;
        end : LiftCmdPort;
    }

    connection def StabilizerFlow {
        end : StabilizerCmdPort;
        end : StabilizerCmdPort;
    }

    connection def FeedbackFlow {
        end : FeedbackPort;
        end : FeedbackPort;
    }

    connection def TiltInternalFlow {
        end : TiltOutPort;
        end : TiltOutPort;
    }

    connection def PressureInternalFlow {
        end : PressureOutPort;
        end : PressureOutPort;
    }

    state def ControlStates;

    part def Frame {
        attribute frameMass :> mass;
        attribute structuralIntegrity : Real;
    }

    part def DriveMotor {
        attribute maxTorque :> torque;
        attribute nominalSpeed :> rotationalSpeed;
        attribute enabled : Boolean = true;
        port powerPort : PowerPort;
        port cmdPort : DriveCmdPort;
        perform action enable;
        perform action disable;
    }

    part def Wheel {
        attribute wheelDiameter :> length;
        part motor : DriveMotor;
    }

    part def DriveSystem {
        port powerPort : PowerPort;
        port cmdPort : DriveCmdPort;
        part leftWheel : Wheel;
        part rightWheel : Wheel;

        connection : PowerFlow connect powerPort to leftWheel.motor.powerPort;
        connection : PowerFlow connect powerPort to rightWheel.motor.powerPort;
        connection : DriveFlow connect cmdPort to leftWheel.motor.cmdPort;
        connection : DriveFlow connect cmdPort to rightWheel.motor.cmdPort;
    }

    part def LiftActuator {
        attribute maxForce :> force;
        attribute stroke :> length;
        port powerPort : PowerPort;
        port cmdPort : LiftCmdPort;
        perform action liftUp;
        perform action liftDown;
        perform action stopLift;
        perform action reportComplete;
    }

    part def SeatFrame {
        attribute seatMass :> mass;
        attribute seatWidth :> length;
    }

    part def LiftMechanism {
        port powerPort : PowerPort;
        port cmdPort : LiftCmdPort;
        port feedbackPort : FeedbackPort;
        part actuator : LiftActuator;
        part seatFrame : SeatFrame;

        connection : PowerFlow connect powerPort to actuator.powerPort;
        connection : LiftFlow connect cmdPort to actuator.cmdPort;
    }

    part def StabilizerLeg {
        attribute deployed : Boolean = false;
        attribute maxLoad :> force;
        port cmdPort : StabilizerCmdPort;
        port powerPort : PowerPort;
        perform action deploy;
        perform action retract;
        perform action reportStatus;
    }

    part def StabilizerSystem {
        port cmdPort : StabilizerCmdPort;
        port powerPort : PowerPort;
        port feedbackPort : FeedbackPort;
        part frontLeg : StabilizerLeg;
        part rearLeg : StabilizerLeg;

        connection : StabilizerFlow connect cmdPort to frontLeg.cmdPort;
        connection : StabilizerFlow connect cmdPort to rearLeg.cmdPort;
        connection : PowerFlow connect powerPort to frontLeg.powerPort;
        connection : PowerFlow connect powerPort to rearLeg.powerPort;
    }

    part def Battery {
        attribute batteryCapacity :> electricCharge;
        attribute nominalVoltage :> electricPotential = 24 [V];
        attribute stateOfCharge : Real;
        port powerPort : PowerPort;
        perform action providePower;
    }

    part def ControlUnit {
        attribute maxTiltThreshold :> planeAngle = 5 [deg];
        attribute minOccupancyForce :> force = 50 [N];

        port powerPort : PowerPort;
        port uiCmdPort : UICmdPort;
        port tiltInPort : TiltInPort;
        port pressureInPort : PressureInPort;
        port driveCmdPort : DriveCmdPort;
        port liftCmdPort : LiftCmdPort;
        port stabilizerCmdPort : StabilizerCmdPort;
        port liftFeedbackPort : FeedbackPort;
        port stabilizerFeedbackPort : FeedbackPort;

        exhibit state controlStates : ControlStates {
            entry; then seated;

            state seated;
            state standing;

            state standUpSequence {
                entry; then checkSafetyStand;

                state checkSafetyStand;
                transition checkSafetyStand_deploy
                    first checkSafetyStand
                    if tiltInPort.isLevel and pressureInPort.isOccupied
                    do send new DeployStabilizerSignal() to stabilizerCmdPort
                    do send new DriveDisableSignal() to driveCmdPort
                    then deployForStand;

                state deployForStand;
                transition deployForStand_lift
                    first deployForStand
                    accept StabilizerDeployedSignal
                    do send new LiftUpSignal() to liftCmdPort
                    then liftForStand;

                state liftForStand;
                transition liftForStand_retract
                    first liftForStand
                    accept LiftCompleteSignal
                    do send new RetractStabilizerSignal() to stabilizerCmdPort
                    then retractForStand;

                state retractForStand;
                transition retractForStand_to_standing
                    first retractForStand
                    accept StabilizerRetractedSignal
                    do send new DriveEnableSignal() to driveCmdPort
                    then standing;
            }

            state sitDownSequence {
                entry; then checkSafetySit;

                state checkSafetySit;
                transition checkSafetySit_deploy
                    first checkSafetySit
                    if tiltInPort.isLevel and pressureInPort.isOccupied
                    do send new DeployStabilizerSignal() to stabilizerCmdPort
                    do send new DriveDisableSignal() to driveCmdPort
                    then deployForSit;

                state deployForSit;
                transition deployForSit_lower
                    first deployForSit
                    accept StabilizerDeployedSignal
                    do send new LiftDownSignal() to liftCmdPort
                    then lowerForSit;

                state lowerForSit;
                transition lowerForSit_retract
                    first lowerForSit
                    accept LiftDownCompleteSignal
                    do send new RetractStabilizerSignal() to stabilizerCmdPort
                    then retractForSit;

                state retractForSit;
                transition retractForSit_to_seated
                    first retractForSit
                    accept StabilizerRetractedSignal
                    do send new DriveEnableSignal() to driveCmdPort
                    then seated;
            }

            transition seated_to_standUp
                first seated
                accept StandCommand via uiCmdPort
                then standUpSequence;

            transition standing_to_sitDown
                first standing
                accept SitCommand via uiCmdPort
                then sitDownSequence;

            transition emergency_from_seated
                first seated
                accept EmergencyStopCommand via uiCmdPort
                do send new DriveDisableSignal() to driveCmdPort
                do send new RetractStabilizerSignal() to stabilizerCmdPort
                then seated;

            transition emergency_from_standing
                first standing
                accept EmergencyStopCommand via uiCmdPort
                do send new DriveDisableSignal() to driveCmdPort
                do send new RetractStabilizerSignal() to stabilizerCmdPort
                then seated;

            transition emergency_from_standUp
                first standUpSequence
                accept EmergencyStopCommand via uiCmdPort
                do send new DriveDisableSignal() to driveCmdPort
                do send new RetractStabilizerSignal() to stabilizerCmdPort
                then seated;

            transition emergency_from_sitDown
                first sitDownSequence
                accept EmergencyStopCommand via uiCmdPort
                do send new DriveDisableSignal() to driveCmdPort
                do send new RetractStabilizerSignal() to stabilizerCmdPort
                then seated;
        }
    }

    part def UserInterface {
        attribute standButton : Boolean;
        attribute sitButton : Boolean;
        attribute emergencyStopButton : Boolean;
        port cmdPort : UICmdPort;
        perform action emitStand;
        perform action emitSit;
        perform action emitEmergencyStop;
    }

    part def TiltSensor {
        attribute currentTilt :> planeAngle;
        attribute maxTiltThreshold :> planeAngle = 5 [deg];
        port outPort : TiltOutPort;
        perform action senseTilt;
    }

    part def PressureSensor {
        attribute detected : Boolean = false;
        attribute minForceThreshold :> force = 50 [N];
        port outPort : PressureOutPort;
        perform action sensePressure;
    }

    part def SensorSuite {
        part tiltSensor : TiltSensor;
        part pressureSensor : PressureSensor;
        port tiltPort : TiltOutPort;
        port pressurePort : PressureOutPort;

        connection : TiltInternalFlow connect tiltSensor.outPort to tiltPort;
        connection : PressureInternalFlow connect pressureSensor.outPort to pressurePort;
    }

    part def Wheelchair {
        attribute wheelchairMass :> mass;
        attribute maxSpeed :> speed;
        attribute maxLiftHeight :> length = 300 [mm];

        part frame : Frame;
        part driveSystem : DriveSystem;
        part liftMechanism : LiftMechanism;
        part stabilizerSystem : StabilizerSystem;
        part battery : Battery;
        part controlUnit : ControlUnit;
        part userInterface : UserInterface;
        part sensorSuite : SensorSuite;

        connection : PowerFlow connect battery.powerPort to driveSystem.powerPort;
        connection : PowerFlow connect battery.powerPort to liftMechanism.powerPort;
        connection : PowerFlow connect battery.powerPort to stabilizerSystem.powerPort;
        connection : PowerFlow connect battery.powerPort to controlUnit.powerPort;

        connection : CmdFlow connect userInterface.cmdPort to controlUnit.uiCmdPort;
        connection : TiltFlow connect sensorSuite.tiltPort to controlUnit.tiltInPort;
        connection : PressureFlow connect sensorSuite.pressurePort to controlUnit.pressureInPort;

        connection : DriveFlow connect controlUnit.driveCmdPort to driveSystem.cmdPort;
        connection : LiftFlow connect controlUnit.liftCmdPort to liftMechanism.cmdPort;
        connection : StabilizerFlow connect controlUnit.stabilizerCmdPort to stabilizerSystem.cmdPort;

        connection : FeedbackFlow connect liftMechanism.feedbackPort to controlUnit.liftFeedbackPort;
        connection : FeedbackFlow connect stabilizerSystem.feedbackPort to controlUnit.stabilizerFeedbackPort;
    }

    requirement def SafeTransitionRequirement {
        doc /* The wheelchair shall only initiate a posture transition when the tilt sensor indicates the wheelchair is on level ground and the seat pressure sensor confirms the user is properly positioned. */
        subject wheelchair : Wheelchair;
    }

    requirement def DriveLockoutRequirement {
        doc /* The drive motors shall be disabled during the transitioning state to prevent unintended movement. */
        subject wheelchair : Wheelchair;
    }

    requirement def StabilizerFirstRequirement {
        doc /* Front and rear stabilizer legs shall deploy to the ground before any lifting or lowering begins and shall remain deployed until the lift or descent is complete. */
        subject wheelchair : Wheelchair;
    }

    requirement def EmergencyStopRequirement {
        doc /* An emergency stop command shall disable the drive motors, retract the stabilizers, and return the system to the seated mode. */
        subject wheelchair : Wheelchair;
    }

    requirement def AutomatedSequenceRequirement {
        doc /* The stand or sit button shall initiate a fully automated sequence: check safety, deploy stabilizers, disable drive, perform lift or descent, retract stabilizers, then re-enable drive in the target mode. */
        subject wheelchair : Wheelchair;
    }

    requirement def UprightStabilityRequirement {
        doc /* In the standing mode, the system shall maintain upright stability through the stabilizer legs until the user commands a return to seated mode. */
        subject wheelchair : Wheelchair;
    }

    requirement def BatteryPowerRequirement {
        doc /* The rechargeable battery shall provide power to the drive motors, lift actuator, stabilizers, and control unit. */
        subject wheelchair : Wheelchair;
    }

    requirement def DualMotorMobilityRequirement {
        doc /* Mobility shall be provided by two independent drive motors, one for each main wheel. */
        subject wheelchair : Wheelchair;
    }
}
