package PtosisCrutchSystemModel {

  import ScalarValues::*;
  import SI::*;

  attribute def Length_mm :> Real;
  attribute def Force_N :> Real;
  attribute def Mass_g :> Real;
  attribute def Angle_deg :> Real;
  attribute def Time_s :> Real;
  attribute def Pressure_kPa :> Real;

  item def UpperEyelid {
    attribute lidMass : Mass_g = 2.8;
    attribute ptosisSeverity : Length_mm;
    attribute desiredElevation : Length_mm;
    attribute cornealClearance : Length_mm;
  }

  item def UserAdjustmentCommand {
    attribute targetLiftHeight : Length_mm;
    attribute comfortPreference : Real;
  }

  item def SupportLoad {
    attribute upwardForce : Force_N;
    attribute contactPressure : Pressure_kPa;
    attribute contactWidth : Length_mm;
  }

  item def VisualField {
    attribute verticalOpening : Length_mm;
    attribute unobstructedFraction : Real;
  }

  port def EyelidContactPort {
    out supportLoad : SupportLoad;
    in eyelid : UpperEyelid;
  }

  port def FrameMountPort {
    in reactionForce : Force_N;
    out mountStability : Real;
  }

  port def UserControlPort {
    in command : UserAdjustmentCommand;
    out adjustmentPosition : Length_mm;
  }

  port def VisualClearancePort {
    out field : VisualField;
  }

  part def SpectacleFrame {
    attribute frameMass : Mass_g = 24.0;
    attribute bridgeWidth : Length_mm = 18.0;
    attribute lensHeight : Length_mm = 38.0;
    attribute templeLength : Length_mm = 140.0;

    port leftMount : FrameMountPort;
    port rightMount : FrameMountPort;
  }

  part def CrutchArm {
    attribute armLength : Length_mm = 32.0;
    attribute armDiameter : Length_mm = 1.2;
    attribute bendAngle : Angle_deg = 12.0;
    attribute elasticDeflection : Length_mm;
    attribute maxSafeForce : Force_N = 0.45;

    port frameInterface : FrameMountPort;
    port eyelidInterface : EyelidContactPort;
  }

  part def SoftContactSleeve {
    attribute sleeveLength : Length_mm = 16.0;
    attribute sleeveDiameter : Length_mm = 2.4;
    attribute shoreHardness : Real = 35.0;
    attribute maximumContactPressure : Pressure_kPa = 4.0;

    port eyelidSurface : EyelidContactPort;
  }

  part def MicroAdjuster {
    attribute adjustmentRange : Length_mm = 8.0;
    attribute adjustmentStep : Length_mm = 0.5;
    attribute currentExtension : Length_mm = 3.0;
    attribute lockingMargin : Real = 1.5;

    port userInput : UserControlPort;
    port frameOutput : FrameMountPort;
  }

  part def PtosisCrutchAssembly {
    attribute totalMass : Mass_g;
    attribute nominalLiftHeight : Length_mm = 5.0;
    attribute maximumLiftHeight : Length_mm = 8.0;
    attribute minimumCornealClearance : Length_mm = 1.5;

    part frame : SpectacleFrame;
    part leftArm : CrutchArm;
    part rightArm : CrutchArm;
    part leftSleeve : SoftContactSleeve;
    part rightSleeve : SoftContactSleeve;
    part leftAdjuster : MicroAdjuster;
    part rightAdjuster : MicroAdjuster;

    port leftEyelidSupport : EyelidContactPort;
    port rightEyelidSupport : EyelidContactPort;
    port userAdjustment : UserControlPort;
    port visualOutput : VisualClearancePort;

    connect leftAdjuster.frameOutput to frame.leftMount;
    connect rightAdjuster.frameOutput to frame.rightMount;
    connect leftArm.frameInterface to frame.leftMount;
    connect rightArm.frameInterface to frame.rightMount;
    connect leftArm.eyelidInterface to leftSleeve.eyelidSurface;
    connect rightArm.eyelidInterface to rightSleeve.eyelidSurface;
    connect leftSleeve.eyelidSurface to leftEyelidSupport;
    connect rightSleeve.eyelidSurface to rightEyelidSupport;
    connect userAdjustment to leftAdjuster.userInput;
    connect userAdjustment to rightAdjuster.userInput;
  }

  action def FitCrutchToPatient {
    in measuredPtosis : Length_mm;
    in eyelidSensitivity : Real;
    out prescribedLift : Length_mm;
    out selectedContactPressure : Pressure_kPa;

    action computeLift {
      in measuredPtosis : Length_mm;
      out prescribedLift : Length_mm;
    }

    action limitPressure {
      in eyelidSensitivity : Real;
      out selectedContactPressure : Pressure_kPa;
    }

    flow measuredPtosis to computeLift.measuredPtosis;
    flow computeLift.prescribedLift to prescribedLift;
    flow eyelidSensitivity to limitPressure.eyelidSensitivity;
    flow limitPressure.selectedContactPressure to selectedContactPressure;
  }

  action def SupportPtoticEyelid {
    in eyelid : UpperEyelid;
    in command : UserAdjustmentCommand;
    out supportedField : VisualField;
    out supportLoad : SupportLoad;

    action receiveAdjustmentCommand;
    action positionCrutchArm;
    action applyDistributedLift;
    action verifyVisualClearance;
    action verifyComfortLimit;

    flow command to receiveAdjustmentCommand;
    flow receiveAdjustmentCommand to positionCrutchArm;
    flow eyelid to applyDistributedLift;
    flow positionCrutchArm to applyDistributedLift;
    flow applyDistributedLift to supportLoad;
    flow applyDistributedLift to verifyVisualClearance;
    flow verifyVisualClearance to supportedField;
    flow supportLoad to verifyComfortLimit;
  }

  state def PtosisCrutchOperatingState {
    entry action initializeCrutchGeometry;

    state Stored;
    state Donning;
    state Adjusting;
    state SupportingEyelid;
    state TemporarilyRemoved;
    state CleaningInspection;

    transition initial then Stored;
    transition Stored_to_Donning first Stored then Donning;
    transition Donning_to_Adjusting first Donning then Adjusting;
    transition Adjusting_to_Supporting first Adjusting then SupportingEyelid;
    transition Supporting_to_Adjusting first SupportingEyelid then Adjusting;
    transition Supporting_to_Removed first SupportingEyelid then TemporarilyRemoved;
    transition Removed_to_Cleaning first TemporarilyRemoved then CleaningInspection;
    transition Cleaning_to_Stored first CleaningInspection then Stored;
  }

  requirement def PrimaryFunctionRequirement {
    subject crutch : PtosisCrutchAssembly;
    doc /* The ptosis crutch system shall provide a high-level primary function of mechanically elevating and supporting a drooping upper eyelid using a spectacle-mounted adjustable support while preserving visual field, comfort, and corneal clearance. */
    require constraint {
      crutch.nominalLiftHeight >= 3.0 and
      crutch.maximumLiftHeight <= 8.0 and
      crutch.minimumCornealClearance >= 1.5
    }
  }

  requirement def ComfortRequirement {
    subject sleeve : SoftContactSleeve;
    require constraint {
      sleeve.maximumContactPressure <= 4.0
    }
  }

  requirement def AdjustabilityRequirement {
    subject adjuster : MicroAdjuster;
    require constraint {
      adjuster.adjustmentRange >= 6.0 and
      adjuster.adjustmentStep <= 0.5
    }
  }

  requirement def SafetyForceRequirement {
    subject arm : CrutchArm;
    require constraint {
      arm.maxSafeForce <= 0.45
    }
  }

  part ptosisCrutchSystem : PtosisCrutchAssembly;

  satisfy PrimaryFunctionRequirement by ptosisCrutchSystem;
  satisfy ComfortRequirement by ptosisCrutchSystem.leftSleeve;
  satisfy ComfortRequirement by ptosisCrutchSystem.rightSleeve;
  satisfy AdjustabilityRequirement by ptosisCrutchSystem.leftAdjuster;
  satisfy AdjustabilityRequirement by ptosisCrutchSystem.rightAdjuster;
  satisfy SafetyForceRequirement by ptosisCrutchSystem.leftArm;
  satisfy SafetyForceRequirement by ptosisCrutchSystem.rightArm;
}