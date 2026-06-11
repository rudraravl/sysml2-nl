package StandingWheelchairSystem {
    private import ScalarValues::*;
    private import SI::*;

    attribute def Mass_kg :> Real {
        doc /* mass measured in kilograms */
    }

    attribute def Length_mm :> Real {
        doc /* length measured in millimeters */
    }

    attribute def Angle_deg :> Real {
        doc /* angle measured in degrees */
    }

    attribute def Speed_km_per_h :> Real {
        doc /* speed measured in kilometers per hour */
    }

    attribute def Energy_Wh :> Real {
        doc /* stored electrical energy measured in watt-hours */
    }

    attribute def Power_W :> Real {
        doc /* electrical or mechanical power measured in watts */
    }

    attribute def Force_N :> Real {
        doc /* force measured in newtons */
    }

    attribute def Voltage_V :> Real {
        doc /* voltage measured in volts */
    }

    attribute def Current_A :> Real {
        doc /* current measured in amperes */
    }

    enum def PostureMode {
        enum seated;
        enum standing;
        enum transitioningUp;
        enum transitioningDown;
        enum faultLocked;
    }

    enum def DriveMode {
        enum indoor;
        enum outdoor;
        enum lowSpeedStanding;
        enum attendantAssist;
    }

    enum def BrakeState {
        enum released;
        enum engaged;
        enum emergencyEngaged;
    }

    item def UserCommand {
        attribute requestedPosture : PostureMode;
        attribute requestedDriveMode : DriveMode;
        attribute requestedSpeed : Speed_km_per_h;
    }

    item def UserWeightLoad {
        attribute load : Force_N;
        attribute estimatedUserMass : Mass_kg;
    }

    item def ElectricalPower {
        attribute voltage : Voltage_V;
        attribute current : Current_A;
        attribute power : Power_W;
    }

    item def MechanicalLiftPower {
        attribute liftForce : Force_N;
        attribute liftSpeed : Speed_km_per_h;
        attribute mechanicalPower : Power_W;
    }

    item def DriveTorqueCommand {
        attribute leftWheelPower : Power_W;
        attribute rightWheelPower : Power_W;
        attribute speedLimit : Speed_km_per_h;
    }

    item def PostureTelemetry {
        attribute currentMode : PostureMode;
        attribute seatTiltAngle : Angle_deg;
        attribute backrestAngle : Angle_deg;
        attribute legSupportAngle : Angle_deg;
        attribute centerOfMassOffset : Length_mm;
    }

    item def SafetyStatus {
        attribute brakes : BrakeState;
        attribute antiTipDeployed : Boolean;
        attribute obstacleDetected : Boolean;
        attribute userHarnessLatched : Boolean;
        attribute overloadDetected : Boolean;
        attribute safeToStand : Boolean;
    }

    port def UserControlPort {
        out item command : UserCommand;
        in item postureFeedback : PostureTelemetry;
        in item safetyFeedback : SafetyStatus;
    }

    port def PowerOutPort {
        out item power : ElectricalPower;
    }

    port def PowerInPort {
        in item power : ElectricalPower;
    }

    port def LiftMechanicalPort {
        in item liftPower : MechanicalLiftPower;
        out item posture : PostureTelemetry;
    }

    port def DriveControlPort {
        in item torqueCommand : DriveTorqueCommand;
        out item safetyFeedback : SafetyStatus;
    }

    port def LoadSupportPort {
        in item supportedUserLoad : UserWeightLoad;
        out item posture : PostureTelemetry;
    }

    port def SafetyCoordinationPort {
        in item posture : PostureTelemetry;
        out item safetyStatus : SafetyStatus;
    }

    part def BatteryPack {
        attribute nominalVoltage : Voltage_V = 24.0;
        attribute capacity : Energy_Wh = 720.0;
        attribute maximumContinuousPower : Power_W = 850.0;
        attribute minimumOperatingVoltage : Voltage_V = 20.0;

        port powerOut : PowerOutPort;
    }

    part def PowerDistributionUnit {
        attribute maximumOutputCurrent : Current_A = 45.0;
        attribute controllerSupplyVoltage : Voltage_V = 24.0;

        port batteryInput : PowerInPort;
        port liftPowerOut : PowerOutPort;
        port drivePowerOut : PowerOutPort;
        port controlPowerOut : PowerOutPort;
    }

    part def UserInterface {
        attribute displayBrightnessPercent : Real = 80.0;
        attribute joystickDeadbandPercent : Real = 5.0;

        port control : UserControlPort;
    }

    part def StandingLiftAssembly {
        attribute maximumLiftForce : Force_N = 1400.0;
        attribute seatTravel : Length_mm = 420.0;
        attribute standingSeatTiltAngle : Angle_deg = 18.0;
        attribute standingBackrestAngle : Angle_deg = 82.0;
        attribute transitionTimeSeconds : Real = 18.0;

        port electricalInput : PowerInPort;
        port mechanicalInterface : LiftMechanicalPort;
        port userSupport : LoadSupportPort;
    }

    part def SeatingAndSupportFrame {
        attribute frameMass : Mass_kg = 38.0;
        attribute maximumUserMass : Mass_kg = 120.0;
        attribute seatWidth : Length_mm = 460.0;
        attribute seatDepth : Length_mm = 430.0;
        attribute harnessRequiredForStanding : Boolean = true;

        port loadSupport : LoadSupportPort;
        port postureOutput : SafetyCoordinationPort;
    }

    part def DriveBase {
        attribute maximumSeatedSpeed : Speed_km_per_h = 6.0;
        attribute maximumStandingSpeed : Speed_km_per_h = 2.0;
        attribute turningRadius : Length_mm = 760.0;
        attribute slopeCapabilityDegrees : Angle_deg = 6.0;

        port electricalInput : PowerInPort;
        port driveControl : DriveControlPort;
    }

    part def BrakeSystem {
        attribute parkingBrakeHoldingForce : Force_N = 1800.0;
        attribute emergencyStopDelaySeconds : Real = 0.3;
        attribute currentBrakeState : BrakeState = BrakeState::engaged;

        port driveInterface : DriveControlPort;
        port safetyInterface : SafetyCoordinationPort;
    }

    part def AntiTipStabilizer {
        attribute rearCasterExtension : Length_mm = 180.0;
        attribute sideStabilizerExtension : Length_mm = 120.0;
        attribute deploymentTimeSeconds : Real = 1.2;
        attribute deployed : Boolean = false;

        port safetyInterface : SafetyCoordinationPort;
    }

    part def SensorSuite {
        attribute seatAngleResolution : Angle_deg = 0.5;
        attribute loadSensorResolution : Force_N = 10.0;
        attribute obstacleDetectionRange : Length_mm = 900.0;
        attribute centerOfMassLimit : Length_mm = 35.0;

        port safetyOutput : SafetyCoordinationPort;
    }

    part def SafetyController {
        attribute maximumAllowedUserMass : Mass_kg = 120.0;
        attribute maximumStandingCenterOfMassOffset : Length_mm = 35.0;
        attribute minimumBatteryEnergyForStand : Energy_Wh = 80.0;

        port userControl : UserControlPort;
        port liftSafety : SafetyCoordinationPort;
        port driveSafety : DriveControlPort;
        port brakeSafety : SafetyCoordinationPort;
        port stabilizerSafety : SafetyCoordinationPort;
        port sensorInput : SafetyCoordinationPort;
    }

    action def ProvideStandingMobility {
        in item command : UserCommand;
        in item userLoad : UserWeightLoad;
        in item safety : SafetyStatus;
        out item posture : PostureTelemetry;
        out item driveCommand : DriveTorqueCommand;

        action validateStandingRequest {
            in item requestedCommand : UserCommand;
            in item measuredLoad : UserWeightLoad;
            in item currentSafety : SafetyStatus;
            out item approved : Boolean;
        }

        action engageBrakesAndStabilizers {
            in item approved : Boolean;
            out item stabilized : SafetyStatus;
        }

        action raiseUserToStandingPosture {
            in item stabilizedStatus : SafetyStatus;
            out item standingPosture : PostureTelemetry;
        }

        action limitStandingDriveSpeed {
            in item standingPosture : PostureTelemetry;
            out item limitedDriveCommand : DriveTorqueCommand;
        }

        first start;
        then validateStandingRequest;
        then engageBrakesAndStabilizers;
        then raiseUserToStandingPosture;
        then limitStandingDriveSpeed;
        then done;
    }

    state def WheelchairOperatingStateMachine {
        entry action initializeControllers;

        state off;
        state seatedIdle;
        state seatedDriving;
        state preparingToStand;
        state standingTransitionUp;
        state standingIdle;
        state standingDriving;
        state standingTransitionDown;
        state faultLocked;

        transition initial then off;

        transition off_to_seatedIdle
            first off
            accept UserCommand
            if command.requestedPosture == PostureMode::seated
            then seatedIdle;

        transition seatedIdle_to_seatedDriving
            first seatedIdle
            accept UserCommand
            if command.requestedSpeed > 0.0
            then seatedDriving;

        transition seatedDriving_to_seatedIdle
            first seatedDriving
            accept UserCommand
            if command.requestedSpeed == 0.0
            then seatedIdle;

        transition seatedIdle_to_preparingToStand
            first seatedIdle
            accept UserCommand
            if command.requestedPosture == PostureMode::standing
            then preparingToStand;

        transition preparingToStand_to_transitionUp
            first preparingToStand
            accept SafetyStatus
            if safety.safeToStand == true and safety.userHarnessLatched == true
            then standingTransitionUp;

        transition standingTransitionUp_to_standingIdle
            first standingTransitionUp
            accept PostureTelemetry
            if posture.currentMode == PostureMode::standing
            then standingIdle;

        transition standingIdle_to_standingDriving
            first standingIdle
            accept UserCommand
            if command.requestedSpeed > 0.0
            then standingDriving;

        transition standingDriving_to_standingIdle
            first standingDriving
            accept UserCommand
            if command.requestedSpeed == 0.0
            then standingIdle;

        transition standingIdle_to_transitionDown
            first standingIdle
            accept UserCommand
            if command.requestedPosture == PostureMode::seated
            then standingTransitionDown;

        transition standingTransitionDown_to_seatedIdle
            first standingTransitionDown
            accept PostureTelemetry
            if posture.currentMode == PostureMode::seated
            then seatedIdle;

        transition any_to_faultLocked
            first seatedIdle
            accept SafetyStatus
            if safety.overloadDetected == true or safety.obstacleDetected == true
            then faultLocked;
    }

    part def StandingWheelchair {
        doc /* A powered mobility system whose primary function is to transport a seated user and safely raise, support, and move the user in a standing posture for improved reach, pressure relief, and participation in daily activities. */

        attribute totalMassWithoutUser : Mass_kg = 135.0;
        attribute maximumUserMass : Mass_kg = 120.0;
        attribute nominalSystemVoltage : Voltage_V = 24.0;
        attribute seatedMaximumSpeed : Speed_km_per_h = 6.0;
        attribute standingMaximumSpeed : Speed_km_per_h = 2.0;
        attribute maximumStandingAngle : Angle_deg = 82.0;
        attribute minimumTurningRadius : Length_mm = 760.0;

        part battery : BatteryPack;
        part powerDistribution : PowerDistributionUnit;
        part userInterface : UserInterface;
        part liftAssembly : StandingLiftAssembly;
        part seatingFrame : SeatingAndSupportFrame;
        part driveBase : DriveBase;
        part brakes : BrakeSystem;
        part antiTip : AntiTipStabilizer;
        part sensors : SensorSuite;
        part safetyController : SafetyController;

        port userCommandPort : UserControlPort;

        connection battery_to_powerDistribution
            connect battery.powerOut to powerDistribution.batteryInput;

        connection powerDistribution_to_lift
            connect powerDistribution.liftPowerOut to liftAssembly.electricalInput;

        connection powerDistribution_to_drive
            connect powerDistribution.drivePowerOut to driveBase.electricalInput;

        connection powerDistribution_to_controls
            connect powerDistribution.controlPowerOut to safetyController.userControl;

        connection userInterface_to_systemControl
            connect userInterface.control to userCommandPort;

        connection userInterface_to_safetyController
            connect userInterface.control to safetyController.userControl;

        connection lift_to_seating
            connect liftAssembly.userSupport to seatingFrame.loadSupport;

        connection seating_to_safety
            connect seatingFrame.postureOutput to safetyController.liftSafety;

        connection sensors_to_safety
            connect sensors.safetyOutput to safetyController.sensorInput;

        connection safety_to_drive
            connect safetyController.driveSafety to driveBase.driveControl;

        connection safety_to_brakes
            connect safetyController.brakeSafety to brakes.safetyInterface;

        connection safety_to_stabilizer
            connect safetyController.stabilizerSafety to antiTip.safetyInterface;

        perform action primaryFunction : ProvideStandingMobility;
        exhibit state operatingStates : WheelchairOperatingStateMachine;
    }

    requirement def SupportStandingPostureRequirement {
        doc /* The wheelchair shall raise and support the user from seated posture to standing posture while maintaining stable load support. */

        subject wheelchair : StandingWheelchair;

        require constraint {
            wheelchair.maximumUserMass >= 120.0 and
            wheelchair.maximumStandingAngle >= 80.0
        }
    }

    requirement def StandingDriveSpeedRequirement {
        doc /* The wheelchair shall restrict powered driving speed while the user is standing. */

        subject wheelchair : StandingWheelchair;

        require constraint {
            wheelchair.standingMaximumSpeed <= 2.0
        }
    }

    requirement def SeatedMobilityRequirement {
        doc /* The wheelchair shall provide powered seated mobility for indoor use. */

        subject wheelchair : StandingWheelchair;

        require constraint {
            wheelchair.seatedMaximumSpeed >= 6.0 and
            wheelchair.minimumTurningRadius <= 800.0
        }
    }

    requirement def StabilityRequirement {
        doc /* The wheelchair shall deploy stabilizing features and engage brakes before initiating a standing transition. */

        subject wheelchair : StandingWheelchair;

        require constraint {
            wheelchair.antiTip.rearCasterExtension >= 150.0 and
            wheelchair.brakes.parkingBrakeHoldingForce >= 1500.0
        }
    }

    requirement def BatteryEnergyRequirement {
        doc /* The wheelchair shall store enough energy to support powered driving and multiple standing transitions. */

        subject wheelchair : StandingWheelchair;

        require constraint {
            wheelchair.battery.capacity >= 700.0 and
            wheelchair.battery.nominalVoltage == 24.0
        }
    }

    requirement def UserSafetyInterlockRequirement {
        doc /* The wheelchair shall prevent standing transition when the user harness is not latched, overload is detected, or center of mass is outside the safe limit. */

        subject wheelchair : StandingWheelchair;

        require constraint {
            wheelchair.safetyController.maximumAllowedUserMass <= wheelchair.maximumUserMass and
            wheelchair.safetyController.maximumStandingCenterOfMassOffset <= 35.0
        }
    }

    satisfy SupportStandingPostureRequirement by StandingWheelchair::liftAssembly;
    satisfy StandingDriveSpeedRequirement by StandingWheelchair::safetyController;
    satisfy SeatedMobilityRequirement by StandingWheelchair::driveBase;
    satisfy StabilityRequirement by StandingWheelchair::antiTip;
    satisfy StabilityRequirement by StandingWheelchair::brakes;
    satisfy BatteryEnergyRequirement by StandingWheelchair::battery;
    satisfy UserSafetyInterlockRequirement by StandingWheelchair::safetyController;
}