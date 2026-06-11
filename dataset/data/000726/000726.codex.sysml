package PapooseBoardModel {
  import ScalarValues::*;
  import SI::*;

  doc
  /*
   * High-level primary function:
   * The papoose board system provides controlled, temporary, clinician-supervised
   * immobilization of a pediatric patient to support short medical or dental procedures
   * while preserving airway access, circulation, padding, rapid release, observation,
   * cleaning, and documented consent.
   */

  attribute def Force_N :> Real {
    doc /* Tensile or contact force measured in newtons. */
  }

  attribute def Pressure_kPa :> Real {
    doc /* Distributed contact pressure measured in kilopascals. */
  }

  attribute def Time_s :> Real {
    doc /* Time duration measured in seconds. */
  }

  attribute def Length_mm :> Real {
    doc /* Linear dimension measured in millimeters. */
  }

  attribute def Mass_kg :> Real {
    doc /* Mass measured in kilograms. */
  }

  attribute def Temperature_C :> Real {
    doc /* Temperature measured in degrees Celsius. */
  }

  attribute def BooleanStatus :> Boolean;

  enum def PatientSizeClass {
    enum small;
    enum medium;
    enum large;
  }

  enum def RestraintStatus {
    enum notApplied;
    enum partiallyApplied;
    enum applied;
    enum released;
    enum emergencyReleased;
  }

  enum def FastenerState {
    enum open;
    enum aligned;
    enum latched;
    enum locked;
    enum failed;
  }

  enum def ProcedureContext {
    enum dentalExam;
    enum dentalTreatment;
    enum woundCare;
    enum imagingPreparation;
    enum briefMedicalProcedure;
  }

  item def PediatricPatient {
    attribute bodyMass : Mass_kg;
    attribute shoulderWidth : Length_mm;
    attribute torsoLength : Length_mm;
    attribute sizeClass : PatientSizeClass;
    attribute isConscious : BooleanStatus;
    attribute airwayAccessible : BooleanStatus;
    attribute circulationAdequate : BooleanStatus;
    attribute distressObserved : BooleanStatus;
  }

  item def Clinician {
    attribute trainedForUse : BooleanStatus;
    attribute canReachQuickRelease : BooleanStatus;
  }

  item def GuardianConsent {
    attribute obtained : BooleanStatus;
    attribute procedureContext : ProcedureContext;
    attribute validForSession : BooleanStatus;
  }

  item def MonitoringObservation {
    attribute airwayClear : BooleanStatus;
    attribute skinColorNormal : BooleanStatus;
    attribute circulationAdequate : BooleanStatus;
    attribute distressObserved : BooleanStatus;
    attribute elapsedImmobilizationTime : Time_s;
  }

  item def ReleaseCommand {
    attribute emergency : BooleanStatus;
    attribute requestedByClinician : BooleanStatus;
  }

  item def CleaningRecord {
    attribute disinfected : BooleanStatus;
    attribute dried : BooleanStatus;
    attribute readyForReuse : BooleanStatus;
  }

  port def PatientSupportPort {
    out supportedPatient : PediatricPatient;
    in patientLoad : Force_N;
  }

  port def HumanAccessPort {
    in clinician : Clinician;
    in consent : GuardianConsent;
    out observation : MonitoringObservation;
    in releaseCommand : ReleaseCommand;
  }

  port def RestraintInterfacePort {
    in patientSegmentLoad : Force_N;
    out appliedPressure : Pressure_kPa;
    out restraintStatus : RestraintStatus;
  }

  port def FastenerControlPort {
    in closeForce : Force_N;
    in releaseCommand : ReleaseCommand;
    out fastenerState : FastenerState;
  }

  port def CleaningPort {
    in cleaningRecord : CleaningRecord;
    out cleanReady : BooleanStatus;
  }

  part def BaseBoard {
    attribute length : Length_mm;
    attribute width : Length_mm;
    attribute thickness : Length_mm;
    attribute maximumPatientMass : Mass_kg;
    attribute radiolucent : BooleanStatus;

    port support : PatientSupportPort;
  }

  part def HeadSupport {
    attribute lateralClearance : Length_mm;
    attribute paddingThickness : Length_mm;
    attribute airwayOpeningClear : BooleanStatus;

    port headInterface : RestraintInterfacePort;
  }

  part def WrapPanel {
    attribute panelWidth : Length_mm;
    attribute panelLength : Length_mm;
    attribute paddingThickness : Length_mm;
    attribute maximumAllowedPressure : Pressure_kPa;
    attribute currentPressure : Pressure_kPa;

    port patientInterface : RestraintInterfacePort;
  }

  part def StrapAssembly {
    attribute strapWidth : Length_mm;
    attribute ratedTensileForce : Force_N;
    attribute appliedTension : Force_N;
    attribute quickAdjustable : BooleanStatus;

    port restraintSide : RestraintInterfacePort;
    port fastenerSide : FastenerControlPort;
  }

  part def QuickReleaseLatch {
    attribute releaseTime : Time_s;
    attribute state : FastenerState;
    attribute accessibleFromBothSides : BooleanStatus;
    attribute singleActionRelease : BooleanStatus;

    port latchControl : FastenerControlPort;
  }

  part def MonitoringPanel {
    attribute checkInterval : Time_s;
    attribute maximumContinuousUseTime : Time_s;
    attribute lastObservationTime : Time_s;

    port humanAccess : HumanAccessPort;
  }

  part def ReusableCover {
    attribute surfaceTemperature : Temperature_C;
    attribute disinfectantCompatible : BooleanStatus;
    attribute clean : BooleanStatus;

    port cleaning : CleaningPort;
  }

  action def InspectBoard {
    in board : BaseBoard;
    in straps : StrapAssembly[4];
    in latch : QuickReleaseLatch;
    out inspectionPassed : BooleanStatus;

    first start;
    then checkBoardIntegrity;
    then checkPadding;
    then checkStraps;
    then checkQuickRelease;
    then setInspectionPassed;
    then done;

    action checkBoardIntegrity;
    action checkPadding;
    action checkStraps;
    action checkQuickRelease;
    action setInspectionPassed;
  }

  action def ConfirmConsent {
    in consent : GuardianConsent;
    in clinician : Clinician;
    out consentAccepted : BooleanStatus;

    first start;
    then verifyGuardianConsent;
    then verifyProcedureContext;
    then verifyClinicianTraining;
    then done;

    action verifyGuardianConsent;
    action verifyProcedureContext;
    action verifyClinicianTraining;
  }

  action def PositionPatient {
    in patient : PediatricPatient;
    in board : BaseBoard;
    out positionedPatient : PediatricPatient;

    first start;
    then alignSpineWithBoard;
    then placeHeadForAirwayAccess;
    then placeArmsAndLegsWithinPanels;
    then done;

    action alignSpineWithBoard;
    action placeHeadForAirwayAccess;
    action placeArmsAndLegsWithinPanels;
  }

  action def ApplyRestraint {
    in patient : PediatricPatient;
    in torsoPanel : WrapPanel;
    in armPanels : WrapPanel[2];
    in legPanel : WrapPanel;
    in straps : StrapAssembly[4];
    in latch : QuickReleaseLatch;
    out status : RestraintStatus;

    first start;
    then closeTorsoPanel;
    then secureArmPanels;
    then secureLegPanel;
    then latchStraps;
    then verifyPressureAndCirculation;
    then done;

    action closeTorsoPanel;
    action secureArmPanels;
    action secureLegPanel;
    action latchStraps;
    action verifyPressureAndCirculation;
  }

  action def MonitorPatient {
    in patient : PediatricPatient;
    in monitor : MonitoringPanel;
    out observation : MonitoringObservation;
    out releaseRequired : BooleanStatus;

    first start;
    then observeAirway;
    then observeCirculation;
    then observeDistress;
    then checkElapsedTime;
    then decideReleaseNeed;
    then done;

    action observeAirway;
    action observeCirculation;
    action observeDistress;
    action checkElapsedTime;
    action decideReleaseNeed;
  }

  action def ReleasePatient {
    in command : ReleaseCommand;
    in latch : QuickReleaseLatch;
    in straps : StrapAssembly[4];
    out status : RestraintStatus;

    first start;
    then actuateQuickRelease;
    then openPanels;
    then confirmPatientFree;
    then done;

    action actuateQuickRelease;
    action openPanels;
    action confirmPatientFree;
  }

  action def CleanAndReset {
    in cover : ReusableCover;
    in cleaningRecord : CleaningRecord;
    out ready : BooleanStatus;

    first start;
    then disinfectSurface;
    then drySurface;
    then inspectAfterCleaning;
    then markReady;
    then done;

    action disinfectSurface;
    action drySurface;
    action inspectAfterCleaning;
    action markReady;
  }

  state def RestraintLifecycle {
    entry action initialize;

    state idle;
    state preUseInspection;
    state consentConfirmation;
    state patientPositioning;
    state restraintApplication;
    state immobilizedMonitoring;
    state controlledRelease;
    state emergencyRelease;
    state cleaning;
    state outOfService;

    transition first idle;
    transition idle then preUseInspection;
    transition preUseInspection then consentConfirmation;
    transition consentConfirmation then patientPositioning;
    transition patientPositioning then restraintApplication;
    transition restraintApplication then immobilizedMonitoring;
    transition immobilizedMonitoring then controlledRelease;
    transition immobilizedMonitoring then emergencyRelease;
    transition controlledRelease then cleaning;
    transition emergencyRelease then cleaning;
    transition cleaning then idle;
    transition preUseInspection then outOfService;
    transition cleaning then outOfService;

    action initialize;
  }

  part def PapooseBoardSystem {
    attribute primaryFunction : String =
      "Provide temporary supervised immobilization of a pediatric patient during a short clinical procedure while maintaining access, observation, comfort, and rapid release.";

    attribute maximumPatientMass : Mass_kg = 35.0;
    attribute maximumContinuousUseTime : Time_s = 900.0;
    attribute maximumContactPressure : Pressure_kPa = 6.0;
    attribute requiredReleaseTime : Time_s = 5.0;
    attribute readyForUse : BooleanStatus;
    attribute currentStatus : RestraintStatus;

    part board : BaseBoard {
      attribute length = 1100.0;
      attribute width = 430.0;
      attribute thickness = 18.0;
      attribute maximumPatientMass = 35.0;
      attribute radiolucent = true;
    }

    part headSupport : HeadSupport {
      attribute lateralClearance = 80.0;
      attribute paddingThickness = 20.0;
      attribute airwayOpeningClear = true;
    }

    part torsoPanel : WrapPanel {
      attribute panelWidth = 390.0;
      attribute panelLength = 420.0;
      attribute paddingThickness = 12.0;
      attribute maximumAllowedPressure = 6.0;
    }

    part leftArmPanel : WrapPanel {
      attribute panelWidth = 150.0;
      attribute panelLength = 500.0;
      attribute paddingThickness = 10.0;
      attribute maximumAllowedPressure = 5.0;
    }

    part rightArmPanel : WrapPanel {
      attribute panelWidth = 150.0;
      attribute panelLength = 500.0;
      attribute paddingThickness = 10.0;
      attribute maximumAllowedPressure = 5.0;
    }

    part legPanel : WrapPanel {
      attribute panelWidth = 360.0;
      attribute panelLength = 520.0;
      attribute paddingThickness = 12.0;
      attribute maximumAllowedPressure = 6.0;
    }

    part torsoStrap : StrapAssembly {
      attribute strapWidth = 50.0;
      attribute ratedTensileForce = 450.0;
      attribute quickAdjustable = true;
    }

    part armStrap : StrapAssembly {
      attribute strapWidth = 38.0;
      attribute ratedTensileForce = 300.0;
      attribute quickAdjustable = true;
    }

    part legStrap : StrapAssembly {
      attribute strapWidth = 50.0;
      attribute ratedTensileForce = 450.0;
      attribute quickAdjustable = true;
    }

    part secondarySafetyStrap : StrapAssembly {
      attribute strapWidth = 38.0;
      attribute ratedTensileForce = 300.0;
      attribute quickAdjustable = true;
    }

    part quickRelease : QuickReleaseLatch {
      attribute releaseTime = 3.0;
      attribute accessibleFromBothSides = true;
      attribute singleActionRelease = true;
    }

    part monitor : MonitoringPanel {
      attribute checkInterval = 30.0;
      attribute maximumContinuousUseTime = 900.0;
    }

    part cover : ReusableCover {
      attribute disinfectantCompatible = true;
      attribute clean = true;
    }

    port userPort : HumanAccessPort;
    port patientPort : PatientSupportPort;
    port cleaningPort : CleaningPort;

    connect board.support to patientPort;
    connect userPort to monitor.humanAccess;
    connect cover.cleaning to cleaningPort;

    connect headSupport.headInterface to board.support;
    connect torsoPanel.patientInterface to torsoStrap.restraintSide;
    connect leftArmPanel.patientInterface to armStrap.restraintSide;
    connect rightArmPanel.patientInterface to armStrap.restraintSide;
    connect legPanel.patientInterface to legStrap.restraintSide;

    connect torsoStrap.fastenerSide to quickRelease.latchControl;
    connect armStrap.fastenerSide to quickRelease.latchControl;
    connect legStrap.fastenerSide to quickRelease.latchControl;
    connect secondarySafetyStrap.fastenerSide to quickRelease.latchControl;

    perform lifecycle : RestraintLifecycle;
  }

  requirement def PrimaryFunctionRequirement {
    subject system : PapooseBoardSystem;

    doc /* The system shall provide temporary supervised immobilization during short clinical procedures. */

    require constraint {
      system.maximumContinuousUseTime <= 900.0
    }
  }

  requirement def AirwayAccessRequirement {
    subject system : PapooseBoardSystem;

    doc /* The system shall keep the patient's airway visible and reachable while restraint is applied. */

    require constraint {
      system.headSupport.airwayOpeningClear == true
    }
  }

  requirement def RapidReleaseRequirement {
    subject system : PapooseBoardSystem;

    doc /* The system shall permit complete patient release within five seconds by a trained clinician. */

    require constraint {
      system.quickRelease.releaseTime <= system.requiredReleaseTime
    }
  }

  requirement def PressureLimitRequirement {
    subject system : PapooseBoardSystem;

    doc /* The system shall distribute restraint loads so panel contact pressure remains within defined limits. */

    require constraint {
      system.torsoPanel.currentPressure <= system.torsoPanel.maximumAllowedPressure and
      system.leftArmPanel.currentPressure <= system.leftArmPanel.maximumAllowedPressure and
      system.rightArmPanel.currentPressure <= system.rightArmPanel.maximumAllowedPressure and
      system.legPanel.currentPressure <= system.legPanel.maximumAllowedPressure
    }
  }

  requirement def ConsentAndTrainingRequirement {
    subject consent : GuardianConsent;
    subject clinician : Clinician;

    doc /* The system shall be used only when guardian consent is valid and the clinician is trained. */

    require constraint {
      consent.obtained == true and
      consent.validForSession == true and
      clinician.trainedForUse == true
    }
  }

  requirement def MonitoringRequirement {
    subject observation : MonitoringObservation;

    doc /* The system shall support repeated observation of airway, circulation, distress, and elapsed time. */

    require constraint {
      observation.elapsedImmobilizationTime <= 900.0 and
      observation.airwayClear == true and
      observation.circulationAdequate == true
    }
  }

  requirement def CleaningRequirement {
    subject cover : ReusableCover;
    subject record : CleaningRecord;

    doc /* The reusable patient-contact surface shall be disinfected and dried before reuse. */

    require constraint {
      cover.disinfectantCompatible == true and
      record.disinfected == true and
      record.dried == true and
      record.readyForReuse == true
    }
  }

  requirement def LoadCapacityRequirement {
    subject system : PapooseBoardSystem;
    subject patient : PediatricPatient;

    doc /* The system shall support patients within the specified mass range. */

    require constraint {
      patient.bodyMass <= system.maximumPatientMass
    }
  }

  satisfy PrimaryFunctionRequirement by PapooseBoardSystem;
  satisfy AirwayAccessRequirement by PapooseBoardSystem::headSupport;
  satisfy RapidReleaseRequirement by PapooseBoardSystem::quickRelease;
  satisfy PressureLimitRequirement by PapooseBoardSystem::torsoPanel;
  satisfy PressureLimitRequirement by PapooseBoardSystem::leftArmPanel;
  satisfy PressureLimitRequirement by PapooseBoardSystem::rightArmPanel;
  satisfy PressureLimitRequirement by PapooseBoardSystem::legPanel;
  satisfy CleaningRequirement by PapooseBoardSystem::cover;
  satisfy LoadCapacityRequirement by PapooseBoardSystem::board;
}