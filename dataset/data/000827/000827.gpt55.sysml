package WartenbergWheelSystem {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  value type Length {
    unit = "mm";
  }

  value type Diameter specializes Length;
  value type Radius specializes Length;

  value type Mass {
    unit = "g";
  }

  value type Force {
    unit = "N";
  }

  value type Torque {
    unit = "N*m";
  }

  value type Angle {
    unit = "deg";
  }

  value type AngularVelocity {
    unit = "rad/s";
  }

  value type LinearVelocity {
    unit = "mm/s";
  }

  value type TimeDuration {
    unit = "s";
  }

  value type SurfaceRoughness {
    unit = "um";
  }

  value type ContactPressure {
    unit = "kPa";
  }

  value type Count {
    unit = "1";
  }

  value type Temperature {
    unit = "degC";
  }

  value type TactileIntensity {
    unit = "mN";
  }

  enum def UseMode {
    enum baselineCheck;
    enum sensoryScreening;
    enum dermatomeMapping;
    enum cleaning;
    enum storage;
  }

  enum def SterilizationState {
    enum nonSterile;
    enum cleaned;
    enum disinfected;
    enum sterile;
  }

  enum def WheelMotionState {
    enum stopped;
    enum rolling;
    enum obstructed;
  }

  item def ClinicianHandLoad {
    attribute gripForce : Force;
    attribute appliedNormalForce : Force;
    attribute sweepVelocity : LinearVelocity;
  }

  item def SkinContactStimulus {
    attribute contactForce : Force;
    attribute estimatedContactPressure : ContactPressure;
    attribute stimulusIntensity : TactileIntensity;
    attribute wheelAngularVelocity : AngularVelocity;
    attribute contactPointCountPerRevolution : Count;
  }

  item def RotationTransfer {
    attribute torque : Torque;
    attribute angularVelocity : AngularVelocity;
    attribute rotationAngle : Angle;
  }

  item def CleaningFluid {
    attribute fluidTemperature : Temperature;
    attribute contactTime : TimeDuration;
  }

  item def ObservationRecord {
    attribute patientIdentifierEncoded : String;
    attribute testSite : String;
    attribute perceivedStimulus : Boolean;
    attribute perceivedSymmetry : Boolean;
    attribute notes : String;
  }

  port def HandInterfacePort {
    in handLoad : ClinicianHandLoad;
  }

  port def SkinInterfacePort {
    out stimulus : SkinContactStimulus;
  }

  port def RotationPort {
    in transferIn : RotationTransfer;
    out transferOut : RotationTransfer;
  }

  port def CleaningPort {
    in cleaningFluid : CleaningFluid;
    out cleaningResidue : CleaningFluid;
  }

  port def ObservationPort {
    out observation : ObservationRecord;
  }

  part def Handle {
    attribute length : Length = 135 [mm];
    attribute maximumDiameter : Diameter = 9 [mm];
    attribute minimumDiameter : Diameter = 6 [mm];
    attribute mass : Mass = 18 [g];
    attribute surfaceRoughnessRa : SurfaceRoughness = 0.8 [um];
    attribute material : String = "AISI 304 stainless steel";
    attribute roundedEndRadius : Radius = 3 [mm];

    port handGrip : HandInterfacePort;
    port distalRotationSupport : RotationPort;
    port cleaningAccess : CleaningPort;
  }

  part def Axle {
    attribute length : Length = 15 [mm];
    attribute diameter : Diameter = 1.6 [mm];
    attribute mass : Mass = 1.2 [g];
    attribute material : String = "hardened stainless steel";
    attribute maximumRunout : Length = 0.05 [mm];

    port handleSide : RotationPort;
    port wheelSide : RotationPort;
    port cleaningAccess : CleaningPort;
  }

  part def LowFrictionBearing {
    attribute innerDiameter : Diameter = 1.6 [mm];
    attribute outerDiameter : Diameter = 3.2 [mm];
    attribute width : Length = 2.0 [mm];
    attribute startingTorque : Torque = 0.0008 [N*m];
    attribute material : String = "medical grade stainless steel";
    attribute sealed : Boolean = true;

    port axleInterface : RotationPort;
    port hubInterface : RotationPort;
    port cleaningAccess : CleaningPort;
  }

  part def Hub {
    attribute outerDiameter : Diameter = 6 [mm];
    attribute boreDiameter : Diameter = 1.6 [mm];
    attribute width : Length = 3 [mm];
    attribute mass : Mass = 0.9 [g];
    attribute material : String = "stainless steel";

    port bearingInterface : RotationPort;
    port rimInterface : RotationPort;
    port cleaningAccess : CleaningPort;
  }

  part def TactilePoint {
    attribute length : Length = 3.2 [mm];
    attribute baseDiameter : Diameter = 0.45 [mm];
    attribute tipRadius : Radius = 0.12 [mm];
    attribute includedTipAngle : Angle = 28 [deg];
    attribute material : String = "rounded stainless steel";
    attribute polished : Boolean = true;

    port skinContact : SkinInterfacePort;
    port wheelRoot : RotationPort;
  }

  part def SpokedWheelRim {
    attribute outerDiameterAcrossTips : Diameter = 26 [mm];
    attribute rimDiameter : Diameter = 20 [mm];
    attribute thickness : Length = 1.2 [mm];
    attribute mass : Mass = 2.8 [g];
    attribute pointCount : Count = 20;
    attribute pointSpacingAngle : Angle = 18 [deg];
    attribute maximumEdgeBurrHeight : Length = 0.01 [mm];
    attribute material : String = "AISI 420 stainless steel";

    port hubInterface : RotationPort;
    port skinTrack : SkinInterfacePort;
    port cleaningAccess : CleaningPort;

    part tactilePoint[20] : TactilePoint;
  }

  part def WheelAssembly {
    attribute nominalOuterDiameter : Diameter = 26 [mm];
    attribute maximumAllowedDiameter : Diameter = 27 [mm];
    attribute mass : Mass = 5.0 [g];
    attribute rotationalState : WheelMotionState = WheelMotionState::stopped;
    attribute minimumFreeSpinTime : TimeDuration = 2 [s];

    port axleInput : RotationPort;
    port skinOutput : SkinInterfacePort;
    port cleaningAccess : CleaningPort;

    part bearing : LowFrictionBearing;
    part hub : Hub;
    part rim : SpokedWheelRim;

    connect axleInput to bearing.axleInterface;
    connect bearing.hubInterface to hub.bearingInterface;
    connect hub.rimInterface to rim.hubInterface;
    connect rim.skinTrack to skinOutput;
    connect cleaningAccess to bearing.cleaningAccess;
    connect cleaningAccess to hub.cleaningAccess;
    connect cleaningAccess to rim.cleaningAccess;
  }

  part def ProtectiveStorageCap {
    attribute innerLength : Length = 32 [mm];
    attribute innerDiameter : Diameter = 30 [mm];
    attribute wallThickness : Length = 1.5 [mm];
    attribute mass : Mass = 4 [g];
    attribute material : String = "autoclavable polymer";
    attribute coversWheelTips : Boolean = true;

    port cleaningAccess : CleaningPort;
  }

  part def WartenbergWheelInstrument {
    attribute primaryFunction : String =
      "Provide controlled rolling tactile point stimulation on the skin so a clinician can perform high-level sensory screening and neurological response assessment.";
    attribute useMode : UseMode = UseMode::sensoryScreening;
    attribute sterilizationState : SterilizationState = SterilizationState::disinfected;
    attribute totalMass : Mass = 28 [g];
    attribute overallLength : Length = 165 [mm];
    attribute recommendedAppliedNormalForce : Force = 0.8 [N];
    attribute maximumAppliedNormalForce : Force = 2.0 [N];
    attribute recommendedSweepVelocity : LinearVelocity = 40 [mm/s];
    attribute maximumSweepVelocity : LinearVelocity = 100 [mm/s];

    port clinicianInput : HandInterfacePort;
    port patientSkinInterface : SkinInterfacePort;
    port cleaningInterface : CleaningPort;
    port observationOutput : ObservationPort;

    part handle : Handle;
    part axle : Axle;
    part wheelAssembly : WheelAssembly;
    part storageCap : ProtectiveStorageCap;

    connect clinicianInput to handle.handGrip;
    connect handle.distalRotationSupport to axle.handleSide;
    connect axle.wheelSide to wheelAssembly.axleInput;
    connect wheelAssembly.skinOutput to patientSkinInterface;
    connect cleaningInterface to handle.cleaningAccess;
    connect cleaningInterface to axle.cleaningAccess;
    connect cleaningInterface to wheelAssembly.cleaningAccess;
    connect cleaningInterface to storageCap.cleaningAccess;
  }

  action def PrepareInstrument {
    in instrument : WartenbergWheelInstrument;
    in cleaningFluid : CleaningFluid;
    out readyForUse : Boolean;

    first start;
    then inspectWheel;
    then disinfectContactSurfaces;
    then verifyFreeRotation;
    then setReady;

    action start;
    action inspectWheel;
    action disinfectContactSurfaces;
    action verifyFreeRotation;
    action setReady;

    flow cleaningFluid to instrument.cleaningInterface.cleaningFluid;

    assert constraint {
      instrument.wheelAssembly.minimumFreeSpinTime >= 2 [s]
    }

    assert constraint {
      instrument.sterilizationState == SterilizationState::disinfected or
      instrument.sterilizationState == SterilizationState::sterile
    }
  }

  action def ApplyRollingStimulus {
    in instrument : WartenbergWheelInstrument;
    in handLoad : ClinicianHandLoad;
    out stimulus : SkinContactStimulus;

    first positionWheel;
    then applyLightNormalForce;
    then rollAlongSkin;
    then observePatientResponse;
    then liftWheel;

    action positionWheel;
    action applyLightNormalForce;
    action rollAlongSkin;
    action observePatientResponse;
    action liftWheel;

    flow handLoad to instrument.clinicianInput.handLoad;
    flow instrument.patientSkinInterface.stimulus to stimulus;

    assert constraint {
      handLoad.appliedNormalForce <= instrument.maximumAppliedNormalForce
    }

    assert constraint {
      handLoad.sweepVelocity <= instrument.maximumSweepVelocity
    }
  }

  action def RecordSensoryObservation {
    in stimulus : SkinContactStimulus;
    in testSite : String;
    in perceivedStimulus : Boolean;
    in perceivedSymmetry : Boolean;
    out record : ObservationRecord;

    first captureSite;
    then capturePerception;
    then createRecord;

    action captureSite;
    action capturePerception;
    action createRecord;
  }

  state def InstrumentOperationalState {
    attribute sterilizationState : SterilizationState;
    attribute motionState : WheelMotionState;

    entry action initialize {
      sterilizationState = SterilizationState::nonSterile;
      motionState = WheelMotionState::stopped;
    }

    state Stored;
    state Cleaning;
    state Ready;
    state InUse;
    state PostUseInspection;
    state OutOfService;

    transition initialToStored first start then Stored;

    transition storedToCleaning
      first Stored
      then Cleaning
      accept CleaningRequested;

    transition cleaningToReady
      first Cleaning
      then Ready
      accept CleaningCompleted
      if sterilizationState == SterilizationState::disinfected or sterilizationState == SterilizationState::sterile;

    transition readyToInUse
      first Ready
      then InUse
      accept UseStarted;

    transition inUseToInspection
      first InUse
      then PostUseInspection
      accept UseCompleted;

    transition inspectionToCleaning
      first PostUseInspection
      then Cleaning
      accept ReprocessingRequired;

    transition inspectionToOutOfService
      first PostUseInspection
      then OutOfService
      accept DamageDetected;

    transition readyToOutOfService
      first Ready
      then OutOfService
      accept WheelObstructed
      if motionState == WheelMotionState::obstructed;
  }

  requirement def PrimaryFunctionRequirement {
    subject instrument : WartenbergWheelInstrument;

    doc
      "The instrument shall provide its primary high-level function by rolling a spoked tactile wheel over skin to create controlled point-contact tactile stimulation for sensory screening.";

    require constraint {
      instrument.primaryFunction ==
      "Provide controlled rolling tactile point stimulation on the skin so a clinician can perform high-level sensory screening and neurological response assessment."
    }
  }

  requirement def ControlledForceRequirement {
    subject instrument : WartenbergWheelInstrument;

    doc
      "The instrument shall support controlled light contact and shall not require excessive force during intended clinical use.";

    require constraint {
      instrument.recommendedAppliedNormalForce <= 1.0 [N] and
      instrument.maximumAppliedNormalForce <= 2.0 [N]
    }
  }

  requirement def FreeRollingWheelRequirement {
    subject instrument : WartenbergWheelInstrument;

    doc
      "The wheel shall rotate freely on its axle so the tactile points roll rather than drag across the skin.";

    require constraint {
      instrument.wheelAssembly.minimumFreeSpinTime >= 2 [s] and
      instrument.wheelAssembly.bearing.startingTorque <= 0.001 [N*m]
    }
  }

  requirement def RoundedPointSafetyRequirement {
    subject instrument : WartenbergWheelInstrument;

    doc
      "Each tactile point shall be rounded and polished to provide tactile stimulation while minimizing risk of skin puncture during intended light-force use.";

    require constraint {
      instrument.wheelAssembly.rim.tactilePoint.tipRadius >= 0.10 [mm] and
      instrument.wheelAssembly.rim.tactilePoint.polished == true
    }
  }

  requirement def CleanabilityRequirement {
    subject instrument : WartenbergWheelInstrument;

    doc
      "The instrument shall expose metallic contact surfaces to cleaning and disinfection processes after each use.";

    require constraint {
      instrument.handle.material == "AISI 304 stainless steel" and
      instrument.wheelAssembly.rim.material == "AISI 420 stainless steel" and
      instrument.storageCap.coversWheelTips == true
    }
  }

  requirement def ErgonomicHandleRequirement {
    subject instrument : WartenbergWheelInstrument;

    doc
      "The handle shall allow stable clinician control during a light rolling sensory examination.";

    require constraint {
      instrument.handle.length >= 120 [mm] and
      instrument.handle.maximumDiameter <= 12 [mm] and
      instrument.handle.surfaceRoughnessRa <= 1.6 [um]
    }
  }

  requirement def TactilePointDistributionRequirement {
    subject instrument : WartenbergWheelInstrument;

    doc
      "The wheel shall provide multiple evenly spaced tactile points around its perimeter to produce a repeatable rolling stimulus.";

    require constraint {
      instrument.wheelAssembly.rim.pointCount == 20 and
      instrument.wheelAssembly.rim.pointSpacingAngle == 18 [deg]
    }
  }

  requirement def ObservationSupportRequirement {
    subject instrument : WartenbergWheelInstrument;

    doc
      "The system shall support recording the examined site and patient perception of the tactile stimulus.";

    require constraint {
      instrument.observationOutput != null
    }
  }

  satisfy PrimaryFunctionRequirement by WartenbergWheelInstrument;
  satisfy ControlledForceRequirement by WartenbergWheelInstrument;
  satisfy FreeRollingWheelRequirement by WheelAssembly;
  satisfy RoundedPointSafetyRequirement by TactilePoint;
  satisfy CleanabilityRequirement by WartenbergWheelInstrument;
  satisfy ErgonomicHandleRequirement by Handle;
  satisfy TactilePointDistributionRequirement by SpokedWheelRim;
  satisfy ObservationSupportRequirement by WartenbergWheelInstrument;

  part wartenbergWheelSystem : WartenbergWheelInstrument {
    attribute primaryFunction =
      "Provide controlled rolling tactile point stimulation on the skin so a clinician can perform high-level sensory screening and neurological response assessment.";
    attribute useMode = UseMode::sensoryScreening;
    attribute sterilizationState = SterilizationState::disinfected;
  }

}
