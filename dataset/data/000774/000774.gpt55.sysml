package StadiometerSystemModel {

  import ScalarValues::*;

  enum def MeasurementStatusKind {
    enum idle;
    enum ready;
    enum subjectPositioning;
    enum measuring;
    enum valid;
    enum invalidPosture;
    enum outOfRange;
    enum fault;
  }

  enum def PowerModeKind {
    enum off;
    enum standby;
    enum active;
    enum charging;
    enum lowBattery;
  }

  enum def ContactStateKind {
    enum notInContact;
    enum softContact;
    enum excessiveForce;
  }

  enum def PostureStateKind {
    enum unknown;
    enum acceptable;
    enum leaning;
    enum kneesBent;
    enum headNotAligned;
    enum feetNotOnBase;
  }

  attribute def Length_mm :> Real {
    attribute unitSymbol : String = "mm";
    attribute quantityKind : String = "length";
  }

  attribute def Length_m :> Real {
    attribute unitSymbol : String = "m";
    attribute quantityKind : String = "length";
  }

  attribute def Mass_kg :> Real {
    attribute unitSymbol : String = "kg";
    attribute quantityKind : String = "mass";
  }

  attribute def Force_N :> Real {
    attribute unitSymbol : String = "N";
    attribute quantityKind : String = "force";
  }

  attribute def Voltage_V :> Real {
    attribute unitSymbol : String = "V";
    attribute quantityKind : String = "electric potential";
  }

  attribute def Current_mA :> Real {
    attribute unitSymbol : String = "mA";
    attribute quantityKind : String = "electric current";
  }

  attribute def Power_W :> Real {
    attribute unitSymbol : String = "W";
    attribute quantityKind : String = "power";
  }

  attribute def Time_s :> Real {
    attribute unitSymbol : String = "s";
    attribute quantityKind : String = "time";
  }

  attribute def Temperature_C :> Real {
    attribute unitSymbol : String = "degC";
    attribute quantityKind : String = "temperature";
  }

  attribute def Angle_deg :> Real {
    attribute unitSymbol : String = "deg";
    attribute quantityKind : String = "plane angle";
  }

  item def ElectricalPower {
    attribute voltage : Voltage_V;
    attribute current : Current_mA;
    attribute power : Power_W;
  }

  item def HumanSubject {
    attribute subjectIdentifier : String;
    attribute actualStandingHeight : Length_mm;
    attribute mass : Mass_kg;
    attribute heelPositionOnBase : Length_mm;
    attribute posture : PostureStateKind;
  }

  item def ReferencePlane {
    attribute planeName : String;
    attribute elevation : Length_mm;
    attribute levelError : Angle_deg;
  }

  item def HeadpieceContact {
    attribute contactState : ContactStateKind;
    attribute contactForce : Force_N;
    attribute contactLocationHeight : Length_mm;
  }

  item def LinearPositionSignal {
    attribute rawPosition : Length_mm;
    attribute filteredPosition : Length_mm;
    attribute sampleTime : Time_s;
    attribute signalValid : Boolean;
  }

  item def PostureSignal {
    attribute posture : PostureStateKind;
    attribute confidence : Real;
    attribute sampleTime : Time_s;
  }

  item def HeightMeasurement {
    attribute measuredHeight : Length_mm;
    attribute resolution : Length_mm;
    attribute uncertainty : Length_mm;
    attribute status : MeasurementStatusKind;
    attribute subjectIdentifier : String;
    attribute measurementTime : Time_s;
  }

  item def DisplayMessage {
    attribute primaryText : String;
    attribute secondaryText : String;
    attribute numericHeight : Length_mm;
    attribute status : MeasurementStatusKind;
  }

  item def UserCommand {
    attribute commandName : String;
    attribute requestedZero : Boolean;
    attribute requestedMeasure : Boolean;
    attribute requestedUnitsMillimetres : Boolean;
  }

  item def DiagnosticStatus {
    attribute status : MeasurementStatusKind;
    attribute errorCode : String;
    attribute batteryVoltage : Voltage_V;
    attribute sensorHealthy : Boolean;
    attribute calibrationDue : Boolean;
  }

  item def CalibrationData {
    attribute zeroOffset : Length_mm;
    attribute scaleFactor : Real;
    attribute lastCalibrationTime : Time_s;
    attribute referenceRodLength : Length_mm;
  }

  port def PowerInputPort {
    in item suppliedPower : ElectricalPower;
  }

  port def PowerOutputPort {
    out item suppliedPower : ElectricalPower;
  }

  port def SubjectInteractionPort {
    in item subject : HumanSubject;
    out item displayedInstruction : DisplayMessage;
  }

  port def HeightMeasurementOutputPort {
    out item measurement : HeightMeasurement;
  }

  port def UserInterfacePort {
    in item command : UserCommand;
    out item message : DisplayMessage;
    out item diagnostic : DiagnosticStatus;
  }

  port def MechanicalReferencePort {
    inout item referencePlane : ReferencePlane;
  }

  port def HeadpieceContactPort {
    out item contact : HeadpieceContact;
  }

  port def HeadpieceMotionPort {
    in item driveCommand : UserCommand;
    out item positionSignal : LinearPositionSignal;
  }

  port def PositionSensorPort {
    in item sensedContact : HeadpieceContact;
    out item positionSignal : LinearPositionSignal;
  }

  port def PostureSensorPort {
    in item subject : HumanSubject;
    out item postureSignal : PostureSignal;
  }

  port def ControllerSensorInputPort {
    in item positionSignal : LinearPositionSignal;
    in item postureSignal : PostureSignal;
    in item contact : HeadpieceContact;
  }

  port def ControllerOutputPort {
    out item measurement : HeightMeasurement;
    out item displayMessage : DisplayMessage;
    out item diagnostic : DiagnosticStatus;
  }

  port def DataServicePort {
    out item measurement : HeightMeasurement;
    out item diagnostic : DiagnosticStatus;
  }

  constraint def MeasurementRangeConstraint {
    in measuredHeight : Length_mm;
    in minimumHeight : Length_mm;
    in maximumHeight : Length_mm;
    require constraint { measuredHeight >= minimumHeight and measuredHeight <= maximumHeight }
  }

  constraint def MeasurementResolutionConstraint {
    in resolution : Length_mm;
    in maximumResolution : Length_mm;
    require constraint { resolution <= maximumResolution }
  }

  constraint def ContactForceConstraint {
    in contactForce : Force_N;
    in minimumForce : Force_N;
    in maximumForce : Force_N;
    require constraint { contactForce >= minimumForce and contactForce <= maximumForce }
  }

  constraint def BaseLevelConstraint {
    in levelError : Angle_deg;
    in maximumLevelError : Angle_deg;
    require constraint { levelError <= maximumLevelError }
  }

  constraint def BatteryVoltageConstraint {
    in batteryVoltage : Voltage_V;
    in minimumOperatingVoltage : Voltage_V;
    require constraint { batteryVoltage >= minimumOperatingVoltage }
  }

  action def InitializeStadiometer {
    out item diagnostic : DiagnosticStatus;

    action energizeController;
    action verifyBatteryVoltage;
    action verifyPositionSensor;
    action loadCalibrationData;
    action setReadyIndication;

    succession first energizeController then verifyBatteryVoltage;
    succession verifyBatteryVoltage then verifyPositionSensor;
    succession verifyPositionSensor then loadCalibrationData;
    succession loadCalibrationData then setReadyIndication;
  }

  action def ZeroReference {
    in item referencePlane : ReferencePlane;
    in item calibrationData : CalibrationData;
    out item updatedCalibrationData : CalibrationData;

    action readBaseReference;
    action computeZeroOffset;
    action storeZeroOffset;

    succession first readBaseReference then computeZeroOffset;
    succession computeZeroOffset then storeZeroOffset;
  }

  action def AcquireStandingHeight {
    in item subject : HumanSubject;
    in item calibrationData : CalibrationData;
    in item positionSignal : LinearPositionSignal;
    in item postureSignal : PostureSignal;
    in item contact : HeadpieceContact;
    out item measurement : HeightMeasurement;

    attribute minimumValidHeight : Length_mm = 300.0;
    attribute maximumValidHeight : Length_mm = 2200.0;
    attribute requiredResolution : Length_mm = 1.0;
    attribute maximumUncertainty : Length_mm = 2.0;
    attribute minimumContactForce : Force_N = 0.5;
    attribute maximumContactForce : Force_N = 5.0;

    action promptSubjectToStandOnBase;
    action verifyFeetAndPosture;
    action bringHeadpieceToCrown;
    action detectSoftContact;
    action sampleLinearPosition;
    action applyCalibration;
    action validateMeasurementRange;
    action publishHeightMeasurement;

    succession first promptSubjectToStandOnBase then verifyFeetAndPosture;
    succession verifyFeetAndPosture then bringHeadpieceToCrown;
    succession bringHeadpieceToCrown then detectSoftContact;
    succession detectSoftContact then sampleLinearPosition;
    succession sampleLinearPosition then applyCalibration;
    succession applyCalibration then validateMeasurementRange;
    succession validateMeasurementRange then publishHeightMeasurement;
  }

  action def ReportMeasurement {
    in item measurement : HeightMeasurement;
    out item message : DisplayMessage;
    out item diagnostic : DiagnosticStatus;

    action formatHeightForDisplay;
    action showHeightAndStatus;
    action emitDataRecord;

    succession first formatHeightForDisplay then showHeightAndStatus;
    succession showHeightAndStatus then emitDataRecord;
  }

  state def StadiometerOperationalStates {
    state Off;
    state Standby;
    state SelfTest;
    state Ready;
    state PositioningSubject;
    state Measuring;
    state Reporting;
    state Fault;
    state LowBattery;

    transition powerApplied first Off then SelfTest;
    transition selfTestPassed first SelfTest then Ready;
    transition selfTestFailed first SelfTest then Fault;
    transition noSubjectTimeout first Ready then Standby;
    transition wakeCommanded first Standby then Ready;
    transition subjectDetected first Ready then PositioningSubject;
    transition postureAcceptable first PositioningSubject then Measuring;
    transition postureInvalid first PositioningSubject then Ready;
    transition measurementValid first Measuring then Reporting;
    transition measurementInvalid first Measuring then Ready;
    transition reportComplete first Reporting then Ready;
    transition batteryLowFromReady first Ready then LowBattery;
    transition batteryLowFromMeasuring first Measuring then LowBattery;
    transition recoverBattery first LowBattery then Ready;
    transition criticalFaultFromAny first Ready then Fault;
    transition resetFault first Fault then SelfTest;
    transition powerRemoved first Ready then Off;
  }

  part def BasePlate {
    attribute width : Length_mm = 350.0;
    attribute depth : Length_mm = 450.0;
    attribute thickness : Length_mm = 25.0;
    attribute maximumSupportedMass : Mass_kg = 200.0;
    attribute levelError : Angle_deg = 0.1;

    port subjectPort : SubjectInteractionPort;
    port referencePort : MechanicalReferencePort;
    port columnMount : MechanicalReferencePort;
  }

  part def VerticalColumn {
    attribute height : Length_mm = 2400.0;
    attribute straightnessError : Length_mm = 0.5;
    attribute scaleGraduation : Length_mm = 1.0;

    port baseMount : MechanicalReferencePort;
    port railPort : HeadpieceMotionPort;
    port scaleReference : MechanicalReferencePort;
  }

  part def SlidingHeadpiece {
    attribute plateWidth : Length_mm = 180.0;
    attribute plateDepth : Length_mm = 90.0;
    attribute minimumContactForce : Force_N = 0.5;
    attribute maximumContactForce : Force_N = 5.0;

    port railFollower : HeadpieceMotionPort;
    port crownContact : HeadpieceContactPort;
    port positionOutput : HeadpieceMotionPort;
  }

  part def LinearPositionSensor {
    attribute measurementRangeMinimum : Length_mm = 0.0;
    attribute measurementRangeMaximum : Length_mm = 2400.0;
    attribute resolution : Length_mm = 0.5;
    attribute repeatability : Length_mm = 1.0;
    attribute samplePeriod : Time_s = 0.05;

    port sensedPosition : PositionSensorPort;
    port sensorOutput : ControllerSensorInputPort;
    port powerIn : PowerInputPort;
  }

  part def PostureSensor {
    attribute acceptableLeanAngle : Angle_deg = 3.0;
    attribute confidenceThreshold : Real = 0.90;
    attribute samplePeriod : Time_s = 0.10;

    port subjectObservation : PostureSensorPort;
    port sensorOutput : ControllerSensorInputPort;
    port powerIn : PowerInputPort;
  }

  part def ContactForceSensor {
    attribute forceRangeMinimum : Force_N = 0.0;
    attribute forceRangeMaximum : Force_N = 20.0;
    attribute resolution : Force_N = 0.1;

    port contactInput : HeadpieceContactPort;
    port sensorOutput : ControllerSensorInputPort;
    port powerIn : PowerInputPort;
  }

  part def MeasurementController {
    attribute processorClockRateMHz : Real = 48.0;
    attribute measurementRangeMinimum : Length_mm = 300.0;
    attribute measurementRangeMaximum : Length_mm = 2200.0;
    attribute heightResolution : Length_mm = 1.0;
    attribute maximumPermittedUncertainty : Length_mm = 2.0;
    attribute operatingTemperatureMinimum : Temperature_C = 5.0;
    attribute operatingTemperatureMaximum : Temperature_C = 40.0;

    port powerIn : PowerInputPort;
    port sensorInputs : ControllerSensorInputPort;
    port userInterface : UserInterfacePort;
    port measurementOutput : HeightMeasurementOutputPort;
    port dataOutput : DataServicePort;

    perform action initialize : InitializeStadiometer;
    perform action zeroReference : ZeroReference;
    perform action acquireHeight : AcquireStandingHeight;
    perform action reportHeight : ReportMeasurement;
  }

  part def DisplayModule {
    attribute diagonalSize : Length_mm = 55.0;
    attribute characterHeight : Length_mm = 8.0;
    attribute updatePeriod : Time_s = 0.2;

    port userInterface : UserInterfacePort;
    port powerIn : PowerInputPort;
  }

  part def KeypadModule {
    attribute keyCount : Integer = 3;

    port userInterface : UserInterfacePort;
    port powerIn : PowerInputPort;
  }

  part def AudibleIndicator {
    attribute soundPressureLevel : Real = 65.0;
    attribute beepDuration : Time_s = 0.2;

    port userInterface : UserInterfacePort;
    port powerIn : PowerInputPort;
  }

  part def PowerSubsystem {
    attribute batteryNominalVoltage : Voltage_V = 7.4;
    attribute minimumOperatingVoltage : Voltage_V = 6.4;
    attribute maximumOutputPower : Power_W = 12.0;
    attribute standbyPower : Power_W = 0.2;
    attribute activePower : Power_W = 4.0;

    port externalPowerIn : PowerInputPort;
    port regulatedPowerOut : PowerOutputPort;
    port statusOut : UserInterfacePort;
  }

  part def DataLogger {
    attribute storageCapacityRecords : Integer = 10000;
    attribute retainedDataYears : Real = 5.0;

    port dataIn : DataServicePort;
    port powerIn : PowerInputPort;
  }

  part def Stadiometer {
    doc /* Primary high-level function: determine and report the standing height of a human subject by referencing the subject's feet to a stable base plane, positioning a headpiece at the crown of the head with controlled contact force, sensing the headpiece position, validating posture and range, and presenting a calibrated height measurement. */

    attribute measurementRangeMinimum : Length_mm = 300.0;
    attribute measurementRangeMaximum : Length_mm = 2200.0;
    attribute displayedResolution : Length_mm = 1.0;
    attribute maximumMeasurementUncertainty : Length_mm = 2.0;
    attribute maximumSubjectMass : Mass_kg = 200.0;
    attribute maximumBaseLevelError : Angle_deg = 0.5;

    port subjectInterface : SubjectInteractionPort;
    port powerInput : PowerInputPort;
    port measurementOutput : HeightMeasurementOutputPort;
    port operatorInterface : UserInterfacePort;
    port serviceData : DataServicePort;

    part base : BasePlate;
    part column : VerticalColumn;
    part headpiece : SlidingHeadpiece;
    part positionSensor : LinearPositionSensor;
    part postureSensor : PostureSensor;
    part contactForceSensor : ContactForceSensor;
    part controller : MeasurementController;
    part display : DisplayModule;
    part keypad : KeypadModule;
    part audibleIndicator : AudibleIndicator;
    part powerSubsystem : PowerSubsystem;
    part logger : DataLogger;

    connect powerInput to powerSubsystem.externalPowerIn;
    connect powerSubsystem.regulatedPowerOut to controller.powerIn;
    connect powerSubsystem.regulatedPowerOut to positionSensor.powerIn;
    connect powerSubsystem.regulatedPowerOut to postureSensor.powerIn;
    connect powerSubsystem.regulatedPowerOut to contactForceSensor.powerIn;
    connect powerSubsystem.regulatedPowerOut to display.powerIn;
    connect powerSubsystem.regulatedPowerOut to keypad.powerIn;
    connect powerSubsystem.regulatedPowerOut to audibleIndicator.powerIn;
    connect powerSubsystem.regulatedPowerOut to logger.powerIn;

    connect subjectInterface to base.subjectPort;
    connect subjectInterface to postureSensor.subjectObservation;

    connect base.columnMount to column.baseMount;
    connect base.referencePort to column.scaleReference;
    connect column.railPort to headpiece.railFollower;
    connect headpiece.crownContact to contactForceSensor.contactInput;
    connect headpiece.positionOutput to positionSensor.sensedPosition;

    connect positionSensor.sensorOutput to controller.sensorInputs;
    connect postureSensor.sensorOutput to controller.sensorInputs;
    connect contactForceSensor.sensorOutput to controller.sensorInputs;

    connect keypad.userInterface to controller.userInterface;
    connect display.userInterface to controller.userInterface;
    connect audibleIndicator.userInterface to controller.userInterface;
    connect powerSubsystem.statusOut to controller.userInterface;

    connect controller.measurementOutput to measurementOutput;
    connect controller.dataOutput to logger.dataIn;
    connect controller.dataOutput to serviceData;
    connect operatorInterface to controller.userInterface;

    exhibit state operationalState : StadiometerOperationalStates;

    perform action initializeSystem : InitializeStadiometer;
    perform action measureStandingHeight : AcquireStandingHeight;
    perform action reportStandingHeight : ReportMeasurement;

    assert constraint rangeConstraint : MeasurementRangeConstraint {
      in measuredHeight = measurementRangeMinimum;
      in minimumHeight = 300.0;
      in maximumHeight = 2200.0;
    }

    assert constraint resolutionConstraint : MeasurementResolutionConstraint {
      in resolution = displayedResolution;
      in maximumResolution = 1.0;
    }

    assert constraint levelConstraint : BaseLevelConstraint {
      in levelError = maximumBaseLevelError;
      in maximumLevelError = 0.5;
    }
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The stadiometer shall provide the primary function of measuring a standing human subject's height from the base reference plane to the crown of the head and reporting the result to the operator. */
    subject stadiometer : Stadiometer;
    require constraint {
      stadiometer.measurementRangeMinimum <= 300.0 and
      stadiometer.measurementRangeMaximum >= 2200.0 and
      stadiometer.displayedResolution <= 1.0
    }
  }

  requirement def AccuracyRequirement {
    doc /* The stadiometer shall report standing height with measurement uncertainty not exceeding 2 mm under normal operating conditions. */
    subject stadiometer : Stadiometer;
    require constraint {
      stadiometer.maximumMeasurementUncertainty <= 2.0
    }
  }

  requirement def PostureValidationRequirement {
    doc /* The stadiometer shall validate that the subject is standing on the base plate with acceptable posture before accepting a height measurement. */
    subject postureSensor : PostureSensor;
    require constraint {
      postureSensor.confidenceThreshold >= 0.90 and
      postureSensor.acceptableLeanAngle <= 3.0
    }
  }

  requirement def ControlledContactRequirement {
    doc /* The headpiece shall contact the crown of the subject's head using soft contact force to reduce compression and improve repeatability. */
    subject headpiece : SlidingHeadpiece;
    require constraint {
      headpiece.minimumContactForce >= 0.5 and
      headpiece.maximumContactForce <= 5.0
    }
  }

  requirement def BaseSupportRequirement {
    doc /* The base plate shall support the subject and provide the physical zero-height reference plane for measurement. */
    subject base : BasePlate;
    require constraint {
      base.maximumSupportedMass >= 200.0 and
      base.levelError <= 0.5
    }
  }

  requirement def PowerRequirement {
    doc /* The stadiometer shall remain operational when the regulated power subsystem voltage is at or above the minimum operating voltage. */
    subject powerSubsystem : PowerSubsystem;
    require constraint {
      powerSubsystem.minimumOperatingVoltage >= 6.4 and
      powerSubsystem.maximumOutputPower >= 12.0
    }
  }

  requirement def MeasurementStorageRequirement {
    doc /* The stadiometer shall store at least 10000 height measurement records for later retrieval. */
    subject logger : DataLogger;
    require constraint {
      logger.storageCapacityRecords >= 10000
    }
  }

  part stadiometerSystem : Stadiometer {
    attribute measurementRangeMinimum = 300.0;
    attribute measurementRangeMaximum = 2200.0;
    attribute displayedResolution = 1.0;
    attribute maximumMeasurementUncertainty = 2.0;
    attribute maximumSubjectMass = 200.0;
    attribute maximumBaseLevelError = 0.5;
  }

  requirement primaryFunction : PrimaryFunctionRequirement {
    subject stadiometer = stadiometerSystem;
  }

  requirement accuracy : AccuracyRequirement {
    subject stadiometer = stadiometerSystem;
  }

  requirement postureValidation : PostureValidationRequirement {
    subject postureSensor = stadiometerSystem.postureSensor;
  }

  requirement controlledContact : ControlledContactRequirement {
    subject headpiece = stadiometerSystem.headpiece;
  }

  requirement baseSupport : BaseSupportRequirement {
    subject base = stadiometerSystem.base;
  }

  requirement powerAvailability : PowerRequirement {
    subject powerSubsystem = stadiometerSystem.powerSubsystem;
  }

  requirement measurementStorage : MeasurementStorageRequirement {
    subject logger = stadiometerSystem.logger;
  }

}
