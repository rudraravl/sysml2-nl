package HugMachineSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Pressure {
        :> scalarValues::Real;
        unit = "kPa";
    }

    attribute def Force {
        :> scalarValues::Real;
        unit = "N";
    }

    attribute def TimeDuration {
        :> scalarValues::Real;
        unit = "s";
    }

    attribute def Angle {
        :> scalarValues::Real;
        unit = "deg";
    }

    attribute def Voltage {
        :> scalarValues::Real;
        unit = "V";
    }

    attribute def Current {
        :> scalarValues::Real;
        unit = "A";
    }

    attribute def Temperature {
        :> scalarValues::Real;
        unit = "degC";
    }

    attribute def Percent {
        :> scalarValues::Real;
        unit = "%";
    }

    attribute def UserMass {
        :> scalarValues::Real;
        unit = "kg";
    }

    item def UserPresenceSignal {
        attribute occupied : Boolean;
        attribute seatedStable : Boolean;
        attribute userMass : UserMass;
    }

    item def PressureCommand {
        attribute targetPressure : Pressure;
        attribute rampTime : TimeDuration;
        attribute holdTime : TimeDuration;
    }

    item def PressureFeedback {
        attribute leftPanelPressure : Pressure;
        attribute rightPanelPressure : Pressure;
        attribute averagePressure : Pressure;
        attribute pressureBalanced : Boolean;
    }

    item def SafetyEvent {
        attribute emergencyStop : Boolean;
        attribute overPressure : Boolean;
        attribute obstructionDetected : Boolean;
        attribute doorOpen : Boolean;
        attribute actuatorFault : Boolean;
    }

    item def UserComfortInput {
        attribute increaseRequested : Boolean;
        attribute decreaseRequested : Boolean;
        attribute releaseRequested : Boolean;
        attribute selectedIntensity : Percent;
    }

    item def SessionReport {
        attribute sessionCompleted : Boolean;
        attribute maximumPressure : Pressure;
        attribute totalCompressionTime : TimeDuration;
        attribute safetyReleaseOccurred : Boolean;
    }

    port def PowerPort {
        in item supplyVoltage : Voltage;
        in item supplyCurrent : Current;
    }

    port def CommandPort {
        in item command : PressureCommand;
        in item comfortInput : UserComfortInput;
        out item sessionReport : SessionReport;
    }

    port def PressureSensorPort {
        out item feedback : PressureFeedback;
    }

    port def PresenceSensorPort {
        out item presence : UserPresenceSignal;
    }

    port def SafetyPort {
        out item safetyEvent : SafetyEvent;
    }

    port def ActuatorDrivePort {
        out item commandedForce : Force;
        in item actualForce : Force;
    }

    port def PanelMechanicalPort {
        inout item appliedPressure : Pressure;
        inout item contactForce : Force;
    }

    part def HugMachine {
        attribute primaryFunction : String = "Provide user-controlled deep-pressure compression around the torso to support calming, relaxation, and sensory regulation while maintaining safe pressure limits.";
        attribute maxAllowedPressure : Pressure = 18.0;
        attribute nominalTherapeuticPressure : Pressure = 9.0;
        attribute minimumTherapeuticPressure : Pressure = 3.0;
        attribute maximumSessionDuration : TimeDuration = 900.0;
        attribute emergencyReleaseTime : TimeDuration = 2.0;

        port power : PowerPort;
        port userCommands : CommandPort;
        port safetyStatus : SafetyPort;

        part frame : SupportFrame;
        part seat : AdjustableSeat;
        part leftCompressionPanel : CompressionPanel {
            attribute sideName : String = "left";
        }
        part rightCompressionPanel : CompressionPanel {
            attribute sideName : String = "right";
        }
        part controlUnit : ControlUnit;
        part actuatorSet : PneumaticActuationSystem;
        part sensorSet : SensorSuite;
        part userInterface : UserInterface;
        part releaseSystem : EmergencyReleaseSystem;

        connect power to controlUnit.power;
        connect controlUnit.actuatorCommand to actuatorSet.driveCommand;
        connect actuatorSet.leftPanelOutput to leftCompressionPanel.mechanicalInterface;
        connect actuatorSet.rightPanelOutput to rightCompressionPanel.mechanicalInterface;
        connect leftCompressionPanel.sensorInterface to sensorSet.leftPressureInput;
        connect rightCompressionPanel.sensorInterface to sensorSet.rightPressureInput;
        connect sensorSet.pressureFeedback to controlUnit.pressureFeedback;
        connect sensorSet.presenceFeedback to controlUnit.presenceFeedback;
        connect sensorSet.safetyFeedback to controlUnit.safetyFeedback;
        connect userInterface.operatorCommand to controlUnit.operatorCommand;
        connect controlUnit.sessionOutput to userCommands;
        connect controlUnit.releaseCommand to releaseSystem.releaseInput;
        connect releaseSystem.leftReleaseOutput to actuatorSet.leftReleaseInput;
        connect releaseSystem.rightReleaseOutput to actuatorSet.rightReleaseInput;
        connect sensorSet.safetyFeedback to safetyStatus;

        perform action provideDeepPressureHug;
        exhibit state machine HugMachineOperatingStates;
    }

    part def SupportFrame {
        attribute frameWidth : LengthValue = 0.95 [m];
        attribute frameDepth : LengthValue = 1.20 [m];
        attribute frameHeight : LengthValue = 1.25 [m];
        attribute staticLoadCapacity : UserMass = 160.0;
        attribute lateralStiffness : Force = 2500.0;
    }

    part def AdjustableSeat {
        attribute seatHeight : LengthValue = 0.46 [m];
        attribute backAngle : Angle = 105.0;
        attribute occupantMassLimit : UserMass = 140.0;
        port presenceOutput : PresenceSensorPort;
    }

    part def CompressionPanel {
        attribute sideName : String;
        attribute panelArea : AreaValue = 0.32 [m^2];
        attribute paddingThickness : LengthValue = 0.08 [m];
        attribute minimumGap : LengthValue = 0.34 [m];
        attribute maximumGap : LengthValue = 0.74 [m];
        attribute currentContactPressure : Pressure;
        attribute currentContactForce : Force;

        port mechanicalInterface : PanelMechanicalPort;
        port sensorInterface : PressureSensorPort;
    }

    part def PneumaticActuationSystem {
        attribute supplyPressure : Pressure = 55.0;
        attribute maximumPanelForce : Force = 600.0;
        attribute normalRampRate : Pressure = 1.0;
        attribute quietModeEnabled : Boolean = true;

        port driveCommand : ActuatorDrivePort;
        port leftPanelOutput : PanelMechanicalPort;
        port rightPanelOutput : PanelMechanicalPort;
        port leftReleaseInput : SafetyPort;
        port rightReleaseInput : SafetyPort;

        part compressor : AirCompressor;
        part leftBladder : InflatableBladder;
        part rightBladder : InflatableBladder;
        part proportionalValve : PressureRegulationValve;
        part exhaustValve : PressureReliefValve;
    }

    part def AirCompressor {
        attribute operatingVoltage : Voltage = 24.0;
        attribute peakCurrent : Current = 8.0;
        attribute maximumOutletPressure : Pressure = 70.0;
        attribute maximumSurfaceTemperature : Temperature = 45.0;
    }

    part def InflatableBladder {
        attribute nominalVolume : VolumeValue = 0.012 [m^3];
        attribute burstPressure : Pressure = 90.0;
        attribute leakageLimit : Pressure = 0.2;
    }

    part def PressureRegulationValve {
        attribute responseTime : TimeDuration = 0.25;
        attribute minimumControllablePressure : Pressure = 0.5;
        attribute maximumControllablePressure : Pressure = 55.0;
    }

    part def PressureReliefValve {
        attribute reliefSetPressure : Pressure = 20.0;
        attribute fullExhaustTime : TimeDuration = 1.5;
    }

    part def SensorSuite {
        port leftPressureInput : PressureSensorPort;
        port rightPressureInput : PressureSensorPort;
        port pressureFeedback : PressureSensorPort;
        port presenceFeedback : PresenceSensorPort;
        port safetyFeedback : SafetyPort;

        part leftPressureSensor : PressureSensor;
        part rightPressureSensor : PressureSensor;
        part seatPresenceSensor : PresenceSensor;
        part panelObstructionSensor : ObstructionSensor;
        part doorSwitch : DoorInterlockSensor;
    }

    part def PressureSensor {
        attribute measurementRange : Pressure = 25.0;
        attribute accuracy : Pressure = 0.25;
        attribute samplePeriod : TimeDuration = 0.02;
    }

    part def PresenceSensor {
        attribute minimumDetectedMass : UserMass = 20.0;
        attribute stableDetectionTime : TimeDuration = 1.0;
    }

    part def ObstructionSensor {
        attribute obstructionForceThreshold : Force = 45.0;
        attribute detectionTime : TimeDuration = 0.10;
    }

    part def DoorInterlockSensor {
        attribute closedStateRequired : Boolean = true;
        attribute debounceTime : TimeDuration = 0.05;
    }

    part def UserInterface {
        attribute minimumIntensity : Percent = 10.0;
        attribute maximumIntensity : Percent = 100.0;
        attribute defaultIntensity : Percent = 45.0;

        port operatorCommand : CommandPort;

        part startButton : MomentaryControl;
        part releaseButton : MomentaryControl;
        part intensityDial : IntensityControl;
        part statusDisplay : StatusDisplay;
    }

    part def MomentaryControl {
        attribute pressed : Boolean;
        attribute debounceTime : TimeDuration = 0.03;
    }

    part def IntensityControl {
        attribute selectedIntensity : Percent;
        attribute adjustmentStep : Percent = 5.0;
    }

    part def StatusDisplay {
        attribute displayedPressure : Pressure;
        attribute displayedTimeRemaining : TimeDuration;
        attribute alarmVisible : Boolean;
    }

    part def ControlUnit {
        attribute controllerVoltage : Voltage = 24.0;
        attribute controlLoopPeriod : TimeDuration = 0.02;
        attribute pressureTolerance : Pressure = 0.5;
        attribute maximumPressureDifference : Pressure = 2.0;

        port power : PowerPort;
        port operatorCommand : CommandPort;
        port pressureFeedback : PressureSensorPort;
        port presenceFeedback : PresenceSensorPort;
        port safetyFeedback : SafetyPort;
        port actuatorCommand : ActuatorDrivePort;
        port releaseCommand : SafetyPort;
        port sessionOutput : CommandPort;

        perform action regulatePressure;
        perform action monitorSafety;
    }

    part def EmergencyReleaseSystem {
        attribute manualReleaseForce : Force = 25.0;
        attribute automaticReleaseDelay : TimeDuration = 0.1;
        attribute targetDepressurizationTime : TimeDuration = 2.0;

        port releaseInput : SafetyPort;
        port leftReleaseOutput : SafetyPort;
        port rightReleaseOutput : SafetyPort;
    }

    action def provideDeepPressureHug {
        in item requestedComfort : UserComfortInput;
        in item userPresence : UserPresenceSignal;
        out item report : SessionReport;

        first start;
        then verifyOccupancy;
        then closePanelsUntilContact;
        then rampToTargetPressure;
        then holdPressure;
        then releasePressure;
        then completeSession;

        action start;
        action verifyOccupancy;
        action closePanelsUntilContact;
        action rampToTargetPressure;
        action holdPressure;
        action releasePressure;
        action completeSession;
    }

    action def regulatePressure {
        in item command : PressureCommand;
        in item feedback : PressureFeedback;
        out item driveForce : Force;

        first compareTargetToFeedback;
        then balanceLeftAndRightPanels;
        then limitPressureCommand;
        then updateActuatorDrive;

        action compareTargetToFeedback;
        action balanceLeftAndRightPanels;
        action limitPressureCommand;
        action updateActuatorDrive;
    }

    action def monitorSafety {
        in item feedback : PressureFeedback;
        in item safety : SafetyEvent;
        out item release : SafetyEvent;

        first readSafetyInputs;
        then evaluatePressureLimit;
        then evaluateUserReleaseRequest;
        then commandReleaseIfUnsafe;

        action readSafetyInputs;
        action evaluatePressureLimit;
        action evaluateUserReleaseRequest;
        action commandReleaseIfUnsafe;
    }

    state def HugMachineOperatingStates {
        entry action initializeControls;

        state Off;
        state Standby;
        state OccupancyConfirmed;
        state Compressing;
        state HoldingPressure;
        state Releasing;
        state FaultRelease;
        state SessionComplete;

        transition powerApplied first Off then Standby;
        transition userSeated first Standby then OccupancyConfirmed;
        transition startRequested first OccupancyConfirmed then Compressing;
        transition targetPressureReached first Compressing then HoldingPressure;
        transition holdTimeExpired first HoldingPressure then Releasing;
        transition pressureReleased first Releasing then SessionComplete;
        transition resetRequested first SessionComplete then Standby;

        transition emergencyStopFromStandby first Standby then FaultRelease;
        transition emergencyStopFromCompressing first Compressing then FaultRelease;
        transition emergencyStopFromHolding first HoldingPressure then FaultRelease;
        transition overPressureFromCompressing first Compressing then FaultRelease;
        transition overPressureFromHolding first HoldingPressure then FaultRelease;
        transition obstructionDetected first Compressing then FaultRelease;
        transition faultCleared first FaultRelease then Standby;

        action initializeControls;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The hug machine shall provide controlled, adjustable, deep-pressure compression around the seated user's torso as its primary high-level function. */
        subject hugMachine : HugMachine;
        require constraint {
            hugMachine.nominalTherapeuticPressure >= hugMachine.minimumTherapeuticPressure and
            hugMachine.nominalTherapeuticPressure <= hugMachine.maxAllowedPressure
        }
    }

    requirement def UserControlledPressureRequirement {
        doc /* The user shall be able to increase, decrease, hold, or release compression during a session without assistance. */
        subject interface : UserInterface;
        require constraint {
            interface.minimumIntensity >= 0.0 and
            interface.maximumIntensity <= 100.0 and
            interface.defaultIntensity >= interface.minimumIntensity and
            interface.defaultIntensity <= interface.maximumIntensity
        }
    }

    requirement def PressureSafetyRequirement {
        doc /* The hug machine shall automatically release compression when measured average torso pressure exceeds the allowed pressure limit. */
        subject hugMachine : HugMachine;
        require constraint {
            hugMachine.maxAllowedPressure <= 18.0
        }
    }

    requirement def EmergencyReleaseRequirement {
        doc /* The hug machine shall reduce compression to a non-contact condition within two seconds after emergency stop activation, over-pressure detection, obstruction detection, or user release request. */
        subject hugMachine : HugMachine;
        require constraint {
            hugMachine.emergencyReleaseTime <= 2.0
        }
    }

    requirement def BalancedCompressionRequirement {
        doc /* The left and right compression panels shall remain balanced so that the pressure difference between sides does not exceed two kilopascals during normal operation. */
        subject controller : ControlUnit;
        require constraint {
            controller.maximumPressureDifference <= 2.0
        }
    }

    requirement def SessionLimitRequirement {
        doc /* A single compression session shall not exceed fifteen minutes without explicit restart by the user. */
        subject hugMachine : HugMachine;
        require constraint {
            hugMachine.maximumSessionDuration <= 900.0
        }
    }

    requirement def OccupancyInterlockRequirement {
        doc /* Compression shall be inhibited unless the seat presence sensor reports a stable seated user. */
        subject sensorSuite : SensorSuite;
    }

    requirement def MechanicalLoadRequirement {
        doc /* The support frame and seat shall support the specified user mass while maintaining panel alignment during compression. */
        subject frame : SupportFrame;
        require constraint {
            frame.staticLoadCapacity >= 160.0
        }
    }

    satisfy PrimaryFunctionRequirement by HugMachine;
    satisfy UserControlledPressureRequirement by UserInterface;
    satisfy PressureSafetyRequirement by HugMachine;
    satisfy EmergencyReleaseRequirement by EmergencyReleaseSystem;
    satisfy BalancedCompressionRequirement by ControlUnit;
    satisfy SessionLimitRequirement by HugMachine;
    satisfy OccupancyInterlockRequirement by SensorSuite;
    satisfy MechanicalLoadRequirement by SupportFrame;

    part hugMachineSystem : HugMachine;

}