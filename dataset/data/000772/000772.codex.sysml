package SpicaSplintSystemModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def LengthValue :> Real {
    unit = "mm";
  }

  attribute def AngleValue :> Real {
    unit = "deg";
  }

  attribute def ForceValue :> Real {
    unit = "N";
  }

  attribute def PressureValue :> Real {
    unit = "kPa";
  }

  attribute def TemperatureValue :> Real {
    unit = "degC";
  }

  attribute def TimeValue :> Real {
    unit = "min";
  }

  item def LimbSegment {
    attribute circumference : LengthValue;
    attribute skinTemperature : TemperatureValue;
    attribute localPressure : PressureValue;
  }

  item def ThumbSegment :> LimbSegment {
    attribute abductionAngle : AngleValue;
    attribute extensionAngle : AngleValue;
  }

  item def WristSegment :> LimbSegment {
    attribute flexionAngle : AngleValue;
    attribute radialDeviationAngle : AngleValue;
  }

  item def ForearmSegment :> LimbSegment {
    attribute rotationAngle : AngleValue;
  }

  item def StabilizingLoad {
    attribute magnitude : ForceValue;
    attribute direction : String;
  }

  item def FitStatus {
    attribute isAligned : Boolean;
    attribute isSecure : Boolean;
    attribute hasExcessivePressure : Boolean;
    attribute skinAccessible : Boolean;
  }

  item def CareInstruction {
    attribute text : String;
    attribute inspectionInterval : TimeValue;
  }

  port def LimbInterfacePort {
    inout limbSegment : LimbSegment;
    out supportLoad : StabilizingLoad;
    out pressureAtInterface : PressureValue;
  }

  port def FastenerPort {
    in adjustmentForce : ForceValue;
    out compressionPressure : PressureValue;
    out secured : Boolean;
  }

  port def VentilationPort {
    out heatDissipationRate : Real;
    out moistureEvacuationRate : Real;
  }

  port def ClinicianAssessmentPort {
    in desiredThumbAbduction : AngleValue;
    in desiredWristExtension : AngleValue;
    out fitStatus : FitStatus;
    out instruction : CareInstruction;
  }

  part def PaddingLayer {
    attribute thickness : LengthValue = 4.0;
    attribute maximumRecommendedPressure : PressureValue = 4.0;
    attribute moistureAbsorptionIndex : Real = 0.65;

    port skinContact : LimbInterfacePort;
    port ventilation : VentilationPort;
  }

  part def RigidShell {
    attribute shellThickness : LengthValue = 2.5;
    attribute thumbAbductionSetpoint : AngleValue = 40.0;
    attribute wristExtensionSetpoint : AngleValue = 20.0;
    attribute maximumDeflectionUnderLoad : LengthValue = 3.0;

    port forearmSupport : LimbInterfacePort;
    port wristSupport : LimbInterfacePort;
    port thumbSupport : LimbInterfacePort;
  }

  part def ThumbSpicaExtension {
    attribute supportedThumbLength : LengthValue = 75.0;
    attribute thumbAbductionAngle : AngleValue = 40.0;
    attribute thumbExtensionAngle : AngleValue = 10.0;

    port thumbInterface : LimbInterfacePort;
  }

  part def WristCuff {
    attribute supportedWristLength : LengthValue = 60.0;
    attribute wristExtensionAngle : AngleValue = 20.0;

    port wristInterface : LimbInterfacePort;
  }

  part def ForearmCuff {
    attribute supportedForearmLength : LengthValue = 130.0;

    port forearmInterface : LimbInterfacePort;
  }

  part def StrapAssembly {
    attribute strapWidth : LengthValue = 25.0;
    attribute minimumRetentionForce : ForceValue = 18.0;
    attribute maximumClosureForce : ForceValue = 45.0;

    port thumbStrap : FastenerPort;
    port wristStrap : FastenerPort;
    port forearmStrap : FastenerPort;
  }

  part def EdgeTrim {
    attribute edgeRadius : LengthValue = 3.0;
    attribute abrasionRiskIndex : Real = 0.05;
  }

  action def AlignSplint {
    in desiredThumbAbduction : AngleValue;
    in desiredWristExtension : AngleValue;
    in thumb : ThumbSegment;
    in wrist : WristSegment;
    out alignedThumb : ThumbSegment;
    out alignedWrist : WristSegment;

    first start;
    then positionThumb;
    then positionWrist;
    then verifyAlignment;
    then done;

    action positionThumb {
      alignedThumb.abductionAngle := desiredThumbAbduction;
      alignedThumb.extensionAngle := 10.0;
    }

    action positionWrist {
      alignedWrist.flexionAngle := desiredWristExtension;
      alignedWrist.radialDeviationAngle := 0.0;
    }

    action verifyAlignment {
    }
  }

  action def SecureSplint {
    in closureForce : ForceValue;
    in maximumPressure : PressureValue;
    out secured : Boolean;
    out excessivePressure : Boolean;

    first start;
    then applyThumbStrap;
    then applyWristStrap;
    then applyForearmStrap;
    then evaluatePressure;
    then done;

    action applyThumbStrap {
    }

    action applyWristStrap {
    }

    action applyForearmStrap {
    }

    action evaluatePressure {
      excessivePressure := maximumPressure > 4.0;
      secured := closureForce >= 18.0 and not excessivePressure;
    }
  }

  action def InspectSkinAndFit {
    in interfacePressure : PressureValue;
    in skinTemperature : TemperatureValue;
    out fitStatus : FitStatus;

    first start;
    then inspectPressure;
    then inspectTemperature;
    then determineStatus;
    then done;

    action inspectPressure {
    }

    action inspectTemperature {
    }

    action determineStatus {
      fitStatus.hasExcessivePressure := interfacePressure > 4.0;
      fitStatus.isSecure := not fitStatus.hasExcessivePressure;
      fitStatus.skinAccessible := true;
      fitStatus.isAligned := true;
    }
  }

  state def SplintUseStateMachine {
    entry action initializeFit;

    state Unapplied;
    state Positioned;
    state Secured;
    state Supporting;
    state LoosenedForInspection;
    state Removed;

    transition first Unapplied;
    transition apply from Unapplied to Positioned;
    transition fasten from Positioned to Secured;
    transition beginSupport from Secured to Supporting;
    transition loosenForInspection from Supporting to LoosenedForInspection;
    transition refasten from LoosenedForInspection to Supporting;
    transition remove from Supporting to Removed;
    transition removeAfterInspection from LoosenedForInspection to Removed;
  }

  part def SpicaSplint {
    attribute totalLength : LengthValue = 205.0;
    attribute mass : Real = 0.18;
    attribute immobilizedThumbAbduction : AngleValue = 40.0;
    attribute immobilizedWristExtension : AngleValue = 20.0;
    attribute allowableInterfacePressure : PressureValue = 4.0;
    attribute primaryFunction : String = "Immobilize and support the thumb and wrist in a therapeutic position while distributing stabilizing loads across the hand, wrist, and forearm.";

    part shell : RigidShell;
    part thumbExtension : ThumbSpicaExtension;
    part wristCuff : WristCuff;
    part forearmCuff : ForearmCuff;
    part padding : PaddingLayer;
    part straps : StrapAssembly;
    part trim : EdgeTrim;

    port thumbInterface : LimbInterfacePort;
    port wristInterface : LimbInterfacePort;
    port forearmInterface : LimbInterfacePort;
    port clinicianInterface : ClinicianAssessmentPort;
    port ventilation : VentilationPort;

    perform action align : AlignSplint;
    perform action secure : SecureSplint;
    perform action inspect : InspectSkinAndFit;

    exhibit state useStates : SplintUseStateMachine;

    connect thumbInterface to thumbExtension.thumbInterface;
    connect wristInterface to wristCuff.wristInterface;
    connect forearmInterface to forearmCuff.forearmInterface;

    connect thumbExtension.thumbInterface to shell.thumbSupport;
    connect wristCuff.wristInterface to shell.wristSupport;
    connect forearmCuff.forearmInterface to shell.forearmSupport;

    connect padding.skinContact to thumbInterface;
    connect padding.ventilation to ventilation;
  }

  part def PatientUpperLimb {
    part thumb : ThumbSegment {
      attribute circumference = 62.0;
      attribute skinTemperature = 33.0;
      attribute localPressure = 0.0;
      attribute abductionAngle = 15.0;
      attribute extensionAngle = 0.0;
    }

    part wrist : WristSegment {
      attribute circumference = 165.0;
      attribute skinTemperature = 33.0;
      attribute localPressure = 0.0;
      attribute flexionAngle = 0.0;
      attribute radialDeviationAngle = 0.0;
    }

    part forearm : ForearmSegment {
      attribute circumference = 235.0;
      attribute skinTemperature = 33.0;
      attribute localPressure = 0.0;
      attribute rotationAngle = 0.0;
    }

    port thumbPort : LimbInterfacePort;
    port wristPort : LimbInterfacePort;
    port forearmPort : LimbInterfacePort;
  }

  part def SpicaSplintCareSystem {
    part splint : SpicaSplint;
    part limb : PatientUpperLimb;

    connect splint.thumbInterface to limb.thumbPort;
    connect splint.wristInterface to limb.wristPort;
    connect splint.forearmInterface to limb.forearmPort;

    requirement primaryFunctionRequirement {
      subject splint;
      doc /* The Spica splint shall maintain the thumb and wrist in prescribed therapeutic alignment while limiting motion that could aggravate injury or delay healing. */
    }

    requirement thumbImmobilizationRequirement {
      subject splint;
      attribute requiredAbduction : AngleValue = 40.0;
      attribute tolerance : AngleValue = 5.0;
      doc /* The thumb support shall hold the thumb in functional abduction within the specified tolerance. */
    }

    requirement wristSupportRequirement {
      subject splint;
      attribute requiredExtension : AngleValue = 20.0;
      attribute tolerance : AngleValue = 5.0;
      doc /* The wrist cuff shall maintain wrist extension within the prescribed therapeutic range. */
    }

    requirement pressureDistributionRequirement {
      subject splint;
      attribute maximumPressure : PressureValue = 4.0;
      doc /* The padding and fastening system shall distribute retention loads so that sustained skin interface pressure does not exceed the maximum recommended value. */
    }

    requirement inspectionRequirement {
      subject splint;
      attribute inspectionInterval : TimeValue = 120.0;
      doc /* The splint shall permit periodic inspection of skin condition and fit without destroying or permanently deforming the device. */
    }

    requirement ventilationRequirement {
      subject splint;
      doc /* The splint shall include ventilation paths or breathable interfaces to reduce moisture buildup during wear. */
    }

    satisfy primaryFunctionRequirement by splint;
    satisfy thumbImmobilizationRequirement by splint.thumbExtension;
    satisfy wristSupportRequirement by splint.wristCuff;
    satisfy pressureDistributionRequirement by splint.padding;
    satisfy pressureDistributionRequirement by splint.straps;
    satisfy inspectionRequirement by splint.straps;
    satisfy ventilationRequirement by splint.padding;
  }

}