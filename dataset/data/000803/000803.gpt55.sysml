package TrocarSystemModel {

  import ScalarValues::*;

  attribute def Length_mm :> Real {
    doc "Length measured in millimeters.";
    attribute unitSymbol : String = "mm";
  }

  attribute def Diameter_mm :> Length_mm {
    doc "Diameter measured in millimeters.";
  }

  attribute def Force_N :> Real {
    doc "Force measured in newtons.";
    attribute unitSymbol : String = "N";
  }

  attribute def Pressure_kPa :> Real {
    doc "Pressure measured in kilopascals.";
    attribute unitSymbol : String = "kPa";
  }

  attribute def Flow_L_per_min :> Real {
    doc "Volumetric flow rate measured in liters per minute.";
    attribute unitSymbol : String = "L/min";
  }

  attribute def Angle_deg :> Real {
    doc "Angle measured in degrees.";
    attribute unitSymbol : String = "deg";
  }

  attribute def Time_s :> Real {
    doc "Time measured in seconds.";
    attribute unitSymbol : String = "s";
  }

  attribute def Roughness_um :> Real {
    doc "Surface roughness measured in micrometers.";
    attribute unitSymbol : String = "um";
  }

  attribute def Leakage_mL_per_min :> Real {
    doc "Gas leakage rate measured in milliliters per minute.";
    attribute unitSymbol : String = "mL/min";
  }

  attribute def Temperature_C :> Real {
    doc "Temperature measured in degrees Celsius.";
    attribute unitSymbol : String = "degC";
  }

  enum def SterilityState {
    enum sterile;
    enum nonSterile;
    enum compromised;
  }

  enum def ValvePosition {
    enum open;
    enum closed;
    enum vent;
  }

  enum def AccessStatus {
    enum notEstablished;
    enum penetrating;
    enum established;
    enum failed;
    enum sealed;
  }

  enum def SafetyShieldStatus {
    enum retracted;
    enum armed;
    enum deployed;
    enum locked;
  }

  enum def TissueLayer {
    enum skin;
    enum subcutaneousTissue;
    enum fascia;
    enum muscle;
    enum peritoneum;
    enum abdominalCavity;
  }

  item def CarbonDioxideGas {
    attribute pressure : Pressure_kPa;
    attribute flowRate : Flow_L_per_min;
    attribute temperature : Temperature_C;
    attribute sterileFiltered : Boolean;
  }

  item def SurgicalInstrument {
    attribute instrumentName : String;
    attribute shaftOuterDiameter : Diameter_mm;
    attribute shaftLength : Length_mm;
    attribute tipBlunt : Boolean;
    attribute electricallyInsulated : Boolean;
  }

  item def Laparoscope :> SurgicalInstrument {
    attribute fieldOfView : Angle_deg = 30.0;
    attribute imageTransmissionActive : Boolean;
    attribute lightTransmissionActive : Boolean;
  }

  item def ObturatorTipContact {
    attribute contactedLayer : TissueLayer;
    attribute axialForce : Force_N;
    attribute insertionDepth : Length_mm;
    attribute shieldStatus : SafetyShieldStatus;
  }

  item def AbdominalWallTissue {
    attribute totalThickness : Length_mm;
    attribute currentLayer : TissueLayer;
    attribute allowableEntryForce : Force_N;
    attribute entryIncisionLength : Length_mm;
  }

  item def ControlledAccessChannel {
    attribute innerDiameter : Diameter_mm;
    attribute lengthThroughBodyWall : Length_mm;
    attribute status : AccessStatus;
    attribute gasLeakageRate : Leakage_mL_per_min;
    attribute acceptsInstrumentDiameter : Diameter_mm;
    attribute pathSterility : SterilityState;
  }

  item def SterileBarrier {
    attribute state : SterilityState;
    attribute packageIntegrityVerified : Boolean;
    attribute expirationValid : Boolean;
  }

  port def GasSupplyPort {
    in item suppliedGas : CarbonDioxideGas;
    out item ventedGas : CarbonDioxideGas;
    attribute maximumPressure : Pressure_kPa;
    attribute nominalFlowCapability : Flow_L_per_min;
  }

  port def GasDeliveryPort {
    out item deliveredGas : CarbonDioxideGas;
    in item backflowGas : CarbonDioxideGas;
    attribute internalLeakage : Leakage_mL_per_min;
  }

  port def InstrumentEntryPort {
    in item insertedInstrument : SurgicalInstrument;
    out item withdrawnInstrument : SurgicalInstrument;
    attribute maximumAcceptedDiameter : Diameter_mm;
  }

  port def InstrumentExitPort {
    out item exitingInstrument : SurgicalInstrument;
    in item returningInstrument : SurgicalInstrument;
    attribute distalOpeningDiameter : Diameter_mm;
  }

  port def TissueInterfacePort {
    in item contactedTissue : AbdominalWallTissue;
    out item tipContact : ObturatorTipContact;
    attribute contactForceLimit : Force_N;
  }

  port def SealInterfacePort {
    in item instrumentThroughSeal : SurgicalInstrument;
    in item gasAtSeal : CarbonDioxideGas;
    out item leakedGas : CarbonDioxideGas;
    attribute sealLeakageRate : Leakage_mL_per_min;
  }

  port def AccessChannelPort {
    out item establishedChannel : ControlledAccessChannel;
    in item tissueWall : AbdominalWallTissue;
    attribute accessStatus : AccessStatus;
  }

  constraint def InstrumentCompatibilityConstraint {
    in instrumentDiameter : Diameter_mm;
    in cannulaInnerDiameter : Diameter_mm;
    in radialClearance : Diameter_mm;
    require constraint { cannulaInnerDiameter >= instrumentDiameter + radialClearance }
  }

  constraint def InsufflationPressureConstraint {
    in deliveredPressure : Pressure_kPa;
    in maximumSafePressure : Pressure_kPa;
    require constraint { deliveredPressure <= maximumSafePressure }
  }

  constraint def GasLeakageConstraint {
    in measuredLeakage : Leakage_mL_per_min;
    in allowableLeakage : Leakage_mL_per_min;
    require constraint { measuredLeakage <= allowableLeakage }
  }

  constraint def TipForceConstraint {
    in appliedForce : Force_N;
    in maximumAllowedForce : Force_N;
    require constraint { appliedForce <= maximumAllowedForce }
  }

  constraint def ShieldDeploymentConstraint {
    in penetrationComplete : Boolean;
    in shieldStatus : SafetyShieldStatus;
    require constraint { penetrationComplete implies shieldStatus == SafetyShieldStatus::deployed }
  }

  part def Cannula {
    doc "Rigid tubular component that remains across the abdominal wall to define and maintain the access path.";

    attribute innerDiameter : Diameter_mm = 5.5;
    attribute outerDiameter : Diameter_mm = 7.0;
    attribute workingLength : Length_mm = 100.0;
    attribute distalBevelAngle : Angle_deg = 15.0;
    attribute surfaceRoughness : Roughness_um = 0.8;
    attribute radiopaqueMarkerPresent : Boolean = true;
    attribute accessStatus : AccessStatus = AccessStatus::notEstablished;

    port proximalInstrumentPort : InstrumentEntryPort {
      :>> maximumAcceptedDiameter = 5.2;
    }

    port distalInstrumentPort : InstrumentExitPort {
      :>> distalOpeningDiameter = 5.5;
    }

    port sideGasPort : GasDeliveryPort {
      :>> maximumPressure = 20.0;
      :>> nominalFlowCapability = 10.0;
      :>> internalLeakage = 0.0;
    }

    port tissueContactPort : TissueInterfacePort {
      :>> contactForceLimit = 35.0;
    }

    port accessChannelPort : AccessChannelPort {
      :>> accessStatus = AccessStatus::notEstablished;
    }
  }

  part def Obturator {
    doc "Removable penetrating member used with the cannula to traverse the body wall during initial placement.";

    attribute shaftDiameter : Diameter_mm = 5.0;
    attribute usableLength : Length_mm = 120.0;
    attribute tipIncludedAngle : Angle_deg = 55.0;
    attribute maximumRecommendedInsertionForce : Force_N = 30.0;
    attribute safetyShieldStatus : SafetyShieldStatus = SafetyShieldStatus::armed;
    attribute lockedToCannula : Boolean = false;

    port proximalHandlePort : InstrumentEntryPort {
      :>> maximumAcceptedDiameter = 5.0;
    }

    port distalTipPort : TissueInterfacePort {
      :>> contactForceLimit = 30.0;
    }
  }

  part def SafetyShield {
    doc "Spring-biased shield intended to cover the obturator tip after entry into the abdominal cavity.";

    attribute deploymentTravel : Length_mm = 8.0;
    attribute deploymentTime : Time_s = 0.05;
    attribute shieldStatus : SafetyShieldStatus = SafetyShieldStatus::armed;
    attribute deploymentForce : Force_N = 2.5;
    attribute mechanicallyLatchedAfterDeployment : Boolean = true;

    port shieldTissuePort : TissueInterfacePort {
      :>> contactForceLimit = 8.0;
    }
  }

  part def SealHousing {
    doc "Proximal housing containing instrument seals and gas seals to reduce pneumoperitoneum leakage.";

    attribute housingOuterDiameter : Diameter_mm = 26.0;
    attribute valveOpenDiameter : Diameter_mm = 5.5;
    attribute sealNominalLeakage : Leakage_mL_per_min = 5.0;
    attribute supportsInstrumentExchange : Boolean = true;

    port proximalInstrumentPort : InstrumentEntryPort {
      :>> maximumAcceptedDiameter = 5.2;
    }

    port distalInstrumentPort : InstrumentExitPort {
      :>> distalOpeningDiameter = 5.5;
    }

    port sealPort : SealInterfacePort {
      :>> sealLeakageRate = 5.0;
    }
  }

  part def DuckbillSeal {
    doc "Normally closed elastomeric seal limiting gas escape when no instrument is inserted.";

    attribute normallyClosed : Boolean = true;
    attribute openingDiameter : Diameter_mm = 5.5;
    attribute noInstrumentLeakage : Leakage_mL_per_min = 3.0;
    attribute withInstrumentLeakage : Leakage_mL_per_min = 7.0;

    port sealInterface : SealInterfacePort {
      :>> sealLeakageRate = 7.0;
    }
  }

  part def InstrumentWiperSeal {
    doc "Annular seal that contacts an inserted instrument shaft.";

    attribute nominalInstrumentDiameter : Diameter_mm = 5.0;
    attribute elasticCompression : Diameter_mm = 0.3;
    attribute wipingLeakage : Leakage_mL_per_min = 5.0;

    port sealInterface : SealInterfacePort {
      :>> sealLeakageRate = 5.0;
    }
  }

  part def StopcockValve {
    doc "User-operated valve for insufflation, closure, and controlled venting.";

    attribute position : ValvePosition = ValvePosition::closed;
    attribute boreDiameter : Diameter_mm = 3.0;
    attribute maximumWorkingPressure : Pressure_kPa = 20.0;
    attribute nominalOpenFlow : Flow_L_per_min = 10.0;

    port gasInlet : GasSupplyPort {
      :>> maximumPressure = 20.0;
      :>> nominalFlowCapability = 10.0;
    }

    port gasOutlet : GasDeliveryPort {
      :>> maximumPressure = 20.0;
      :>> nominalFlowCapability = 10.0;
      :>> internalLeakage = 1.0;
    }
  }

  part def TrocarHandle {
    doc "Hand interface for controlled axial insertion and stabilizing torque.";

    attribute gripDiameter : Diameter_mm = 32.0;
    attribute gripLength : Length_mm = 65.0;
    attribute texturedSurface : Boolean = true;
    attribute maximumUserAppliedForce : Force_N = 30.0;

    port userForcePort : TissueInterfacePort {
      :>> contactForceLimit = 30.0;
    }
  }

  part def FixationGrip {
    doc "External stabilizing feature intended to reduce migration after placement.";

    attribute contactWidth : Length_mm = 12.0;
    attribute axialRetentionForce : Force_N = 10.0;
    attribute skinContactSurfaceRoughness : Roughness_um = 2.0;

    port tissueContactPort : TissueInterfacePort {
      :>> contactForceLimit = 10.0;
    }
  }

  part def TrocarAssembly {
    doc "Integrated trocar consisting of a cannula, removable obturator, proximal seals, insufflation valve, and handling features.";

    attribute assembledSterility : SterilityState = SterilityState::sterile;
    attribute accessEstablished : Boolean = false;
    attribute maximumInstrumentDiameter : Diameter_mm = 5.0;
    attribute nominalAccessDiameter : Diameter_mm = 5.5;
    attribute maximumSafeInsufflationPressure : Pressure_kPa = 15.0;
    attribute allowableGasLeakage : Leakage_mL_per_min = 20.0;
    attribute maximumInsertionForce : Force_N = 30.0;

    part cannula : Cannula;
    part obturator : Obturator;
    part safetyShield : SafetyShield;
    part sealHousing : SealHousing;
    part duckbillSeal : DuckbillSeal;
    part wiperSeal : InstrumentWiperSeal;
    part stopcock : StopcockValve;
    part handle : TrocarHandle;
    part fixationGrip : FixationGrip;

    port proximalInstrumentPort : InstrumentEntryPort {
      :>> maximumAcceptedDiameter = 5.2;
    }

    port distalAccessPort : InstrumentExitPort {
      :>> distalOpeningDiameter = 5.5;
    }

    port insufflationPort : GasSupplyPort {
      :>> maximumPressure = 20.0;
      :>> nominalFlowCapability = 10.0;
    }

    port tissuePort : TissueInterfacePort {
      :>> contactForceLimit = 30.0;
    }

    port accessPort : AccessChannelPort {
      :>> accessStatus = AccessStatus::notEstablished;
    }

    connect proximalInstrumentPort to sealHousing.proximalInstrumentPort;
    connect sealHousing.distalInstrumentPort to cannula.proximalInstrumentPort;
    connect cannula.distalInstrumentPort to distalAccessPort;
    connect insufflationPort to stopcock.gasInlet;
    connect stopcock.gasOutlet to cannula.sideGasPort;
    connect sealHousing.sealPort to duckbillSeal.sealInterface;
    connect sealHousing.sealPort to wiperSeal.sealInterface;
    connect obturator.distalTipPort to safetyShield.shieldTissuePort;
    connect obturator.distalTipPort to tissuePort;
    connect cannula.tissueContactPort to fixationGrip.tissueContactPort;
    connect cannula.accessChannelPort to accessPort;

    constraint instrumentFit : InstrumentCompatibilityConstraint {
      in instrumentDiameter = maximumInstrumentDiameter;
      in cannulaInnerDiameter = nominalAccessDiameter;
      in radialClearance = 0.3;
    }

    constraint pressureLimit : InsufflationPressureConstraint {
      in deliveredPressure = maximumSafeInsufflationPressure;
      in maximumSafePressure = 15.0;
    }

    constraint leakageLimit : GasLeakageConstraint {
      in measuredLeakage = allowableGasLeakage;
      in allowableLeakage = 20.0;
    }

    constraint insertionForceLimit : TipForceConstraint {
      in appliedForce = maximumInsertionForce;
      in maximumAllowedForce = 30.0;
    }

    exhibit state useState : TrocarUseStateMachine;
    perform action establishAccess : EstablishControlledPercutaneousAccess;
    perform action exchangeInstrument : ExchangeInstrumentThroughCannula;
    perform action maintainPneumoperitoneum : MaintainInsufflatedAccess;
  }

  part def Insufflator {
    doc "External gas source providing regulated carbon dioxide for pneumoperitoneum.";

    attribute setPressure : Pressure_kPa = 12.0;
    attribute maximumPressure : Pressure_kPa = 15.0;
    attribute maximumFlowRate : Flow_L_per_min = 10.0;
    attribute gasSterileFiltered : Boolean = true;

    port gasOutlet : GasSupplyPort {
      :>> maximumPressure = 15.0;
      :>> nominalFlowCapability = 10.0;
    }
  }

  part def PatientAbdominalWall {
    doc "Modeled surgical access site through which the trocar establishes a channel.";

    attribute wallThickness : Length_mm = 35.0;
    attribute incisionLength : Length_mm = 7.0;
    attribute safeEntryForceLimit : Force_N = 30.0;
    attribute accessChannelPresent : Boolean = false;

    port tissueInterface : TissueInterfacePort {
      :>> contactForceLimit = 30.0;
    }

    port channelInterface : AccessChannelPort {
      :>> accessStatus = AccessStatus::notEstablished;
    }
  }

  part def TrocarSystem {
    doc "A trocar-based access system whose primary high-level function is to create and maintain a controlled percutaneous pathway through the body wall for minimally invasive instruments while preserving insufflation gas containment.";

    attribute primaryFunction : String = "Create and maintain controlled minimally invasive access for instruments and insufflation.";
    attribute accessEstablished : Boolean = false;
    attribute pneumoperitoneumMaintained : Boolean = false;
    attribute maximumInstrumentDiameter : Diameter_mm = 5.0;
    attribute controlledPressure : Pressure_kPa = 12.0;
    attribute measuredLeakage : Leakage_mL_per_min = 8.0;
    attribute accessStatus : AccessStatus = AccessStatus::notEstablished;

    part trocar : TrocarAssembly;
    part insufflator : Insufflator;
    part patientWall : PatientAbdominalWall;
    part laparoscope : Laparoscope {
      :>> instrumentName = "5 mm thirty-degree laparoscope";
      :>> shaftOuterDiameter = 5.0;
      :>> shaftLength = 330.0;
      :>> tipBlunt = true;
      :>> electricallyInsulated = true;
      :>> imageTransmissionActive = true;
      :>> lightTransmissionActive = true;
    }

    part accessPath : ControlledAccessChannel {
      :>> innerDiameter = 5.5;
      :>> lengthThroughBodyWall = 35.0;
      :>> status = AccessStatus::established;
      :>> gasLeakageRate = 8.0;
      :>> acceptsInstrumentDiameter = 5.0;
      :>> pathSterility = SterilityState::sterile;
    }

    part sterileBarrier : SterileBarrier {
      :>> state = SterilityState::sterile;
      :>> packageIntegrityVerified = true;
      :>> expirationValid = true;
    }

    connect insufflator.gasOutlet to trocar.insufflationPort;
    connect trocar.tissuePort to patientWall.tissueInterface;
    connect trocar.accessPort to patientWall.channelInterface;
    connect trocar.distalAccessPort to patientWall.channelInterface;
    connect trocar.proximalInstrumentPort to laparoscope;

    constraint systemInstrumentCompatibility : InstrumentCompatibilityConstraint {
      in instrumentDiameter = maximumInstrumentDiameter;
      in cannulaInnerDiameter = accessPath.innerDiameter;
      in radialClearance = 0.3;
    }

    constraint systemPressureLimit : InsufflationPressureConstraint {
      in deliveredPressure = controlledPressure;
      in maximumSafePressure = 15.0;
    }

    constraint systemLeakageLimit : GasLeakageConstraint {
      in measuredLeakage = measuredLeakage;
      in allowableLeakage = 20.0;
    }

    exhibit state systemState : TrocarSystemLifecycle;
    perform action primaryFunctionBehavior : ProvideMinimallyInvasiveAccess;
  }

  action def VerifySterileReadiness {
    in item barrier : SterileBarrier;
    out ready : Boolean;

    action inspectPackage;
    action confirmSterilityState;
    action confirmExpiration;
    action reportReady;

    first inspectPackage;
    then confirmSterilityState;
    then confirmExpiration;
    then reportReady;
  }

  action def AssembleTrocar {
    in part cannula : Cannula;
    in part obturator : Obturator;
    in part sealHousing : SealHousing;
    out assembled : Boolean;

    action insertObturatorThroughSeal;
    action lockObturatorToCannula;
    action verifyTipShieldArmed;
    action verifyGasValveClosed;

    first insertObturatorThroughSeal;
    then lockObturatorToCannula;
    then verifyTipShieldArmed;
    then verifyGasValveClosed;
  }

  action def EstablishControlledPercutaneousAccess {
    doc "Creates a controlled channel across the abdominal wall using the obturator and cannula, then leaves the cannula in place.";

    in part trocar : TrocarAssembly;
    in item tissue : AbdominalWallTissue;
    in targetDepth : Length_mm;
    in maximumAllowedForce : Force_N;
    out item channel : ControlledAccessChannel;
    out success : Boolean;

    action alignAtIncision;
    action advanceObturatorAndCannula;
    action monitorInsertionForce;
    action detectPeritonealEntry;
    action deploySafetyShield;
    action stopAdvancement;
    action withdrawObturator;
    action leaveCannulaInPlace;
    action confirmAccessChannel;

    first alignAtIncision;
    then advanceObturatorAndCannula;
    then monitorInsertionForce;
    then detectPeritonealEntry;
    then deploySafetyShield;
    then stopAdvancement;
    then withdrawObturator;
    then leaveCannulaInPlace;
    then confirmAccessChannel;
  }

  action def MaintainInsufflatedAccess {
    doc "Maintains a sealed access path and allows regulated carbon dioxide flow through the trocar cannula.";

    in part trocar : TrocarAssembly;
    in item suppliedGas : CarbonDioxideGas;
    in targetPressure : Pressure_kPa;
    out pneumoperitoneumMaintained : Boolean;
    out measuredLeakage : Leakage_mL_per_min;

    action closeSealAroundInstrument;
    action openStopcockIfInsufflationRequired;
    action deliverRegulatedGas;
    action limitPressure;
    action measureLeakage;
    action resealWhenInstrumentRemoved;

    first closeSealAroundInstrument;
    then openStopcockIfInsufflationRequired;
    then deliverRegulatedGas;
    then limitPressure;
    then measureLeakage;
    then resealWhenInstrumentRemoved;
  }

  action def ExchangeInstrumentThroughCannula {
    doc "Allows a compatible instrument to pass through the seal housing and cannula without removing the access pathway.";

    in part trocar : TrocarAssembly;
    in item instrumentIn : SurgicalInstrument;
    out item instrumentOut : SurgicalInstrument;
    out exchangeComplete : Boolean;

    action verifyDiameterCompatibility;
    action openInstrumentSeal;
    action advanceInstrumentThroughCannula;
    action maintainGasSealDuringPassage;
    action withdrawOrPositionInstrument;
    action closeSealAfterExchange;

    first verifyDiameterCompatibility;
    then openInstrumentSeal;
    then advanceInstrumentThroughCannula;
    then maintainGasSealDuringPassage;
    then withdrawOrPositionInstrument;
    then closeSealAfterExchange;
  }

  action def ProvideMinimallyInvasiveAccess {
    doc "High-level primary function behavior for the trocar system.";

    in part system : TrocarSystem;
    out accessReady : Boolean;
    out gasContainmentReady : Boolean;

    action verifyReadiness : VerifySterileReadiness;
    action assembleDevice : AssembleTrocar;
    action establishAccess : EstablishControlledPercutaneousAccess;
    action maintainAccess : MaintainInsufflatedAccess;
    action supportInstrumentUse : ExchangeInstrumentThroughCannula;

    first verifyReadiness;
    then assembleDevice;
    then establishAccess;
    then maintainAccess;
    then supportInstrumentUse;
  }

  event def SterilePackageOpened;
  event def ObturatorLocked;
  event def IncisionPrepared;
  event def PenetrationStarted;
  event def PeritoneumEntered;
  event def ShieldDeployed;
  event def ObturatorRemoved;
  event def InsufflationConnected;
  event def InstrumentInserted;
  event def ProcedureCompleted;
  event def DeviceRemoved;
  event def SealFailureDetected;
  event def ExcessForceDetected;

  state def TrocarUseStateMachine {
    doc "Operational state machine for a trocar assembly during a minimally invasive access workflow.";

    state packaged {
      entry action recordSterilePackaged;
    }

    state prepared {
      entry action verifyPackageIntegrity;
    }

    state assembled {
      entry action confirmObturatorCannulaLock;
    }

    state positioning {
      entry action alignDistalTipWithIncision;
    }

    state penetrating {
      entry action advanceUnderControlledForce;
    }

    state shieldedEntry {
      entry action deployTipShield;
    }

    state cannulaPlaced {
      entry action stabilizeCannula;
    }

    state obturatorRemoved {
      entry action removeSharpObturatorFromCannula;
    }

    state sealedAccess {
      entry action closeDuckbillAndWiperSeals;
    }

    state insufflating {
      entry action openStopcockAndDeliverGas;
    }

    state instrumentAccess {
      entry action permitInstrumentPassage;
    }

    state completed {
      entry action removeCannulaAndCloseAccessSite;
    }

    state fault {
      entry action stopInsertionOrGasFlow;
    }

    transition initialToPackaged first packaged;
    transition openPackage first packaged accept SterilePackageOpened then prepared;
    transition lockAssembly first prepared accept ObturatorLocked then assembled;
    transition prepareIncision first assembled accept IncisionPrepared then positioning;
    transition startPenetration first positioning accept PenetrationStarted then penetrating;
    transition forceFault first penetrating accept ExcessForceDetected then fault;
    transition enterPeritoneum first penetrating accept PeritoneumEntered then shieldedEntry;
    transition shieldComplete first shieldedEntry accept ShieldDeployed then cannulaPlaced;
    transition removeObturator first cannulaPlaced accept ObturatorRemoved then obturatorRemoved;
    transition sealAccess first obturatorRemoved then sealedAccess;
    transition connectGas first sealedAccess accept InsufflationConnected then insufflating;
    transition insertInstrument first insufflating accept InstrumentInserted then instrumentAccess;
    transition finishProcedure first instrumentAccess accept ProcedureCompleted then completed;
    transition removeDevice first completed accept DeviceRemoved then packaged;
    transition sealFault first insufflating accept SealFailureDetected then fault;
  }

  state def TrocarSystemLifecycle {
    doc "System-level lifecycle states describing readiness, use, and completion.";

    state unavailable {
      entry action keepSystemOutOfUse;
    }

    state sterileReady {
      entry action confirmSterileBarrier;
    }

    state accessCreation {
      entry action createPercutaneousPath;
    }

    state accessMaintained {
      entry action holdCannulaAndSealGas;
    }

    state instrumentUse {
      entry action exchangeAndOperateInstruments;
    }

    state removal {
      entry action withdrawCannula;
    }

    state complete {
      entry action documentAccessCompleted;
    }

    state unsafe {
      entry action alertUserAndStopUse;
    }

    transition initialToReady first sterileReady;
    transition beginAccess first sterileReady then accessCreation;
    transition accessEstablished first accessCreation then accessMaintained;
    transition unsafeEntry first accessCreation accept ExcessForceDetected then unsafe;
    transition beginInstrumentUse first accessMaintained accept InstrumentInserted then instrumentUse;
    transition sealFailure first accessMaintained accept SealFailureDetected then unsafe;
    transition procedureDone first instrumentUse accept ProcedureCompleted then removal;
    transition deviceOut first removal accept DeviceRemoved then complete;
  }

  requirement def PrimaryFunctionRequirement {
    doc "The trocar system shall create and maintain a controlled percutaneous access pathway for minimally invasive surgical instruments while limiting gas leakage and avoiding uncontrolled penetration.";

    subject system : TrocarSystem;

    require constraint {
      system.accessPath.status == AccessStatus::established and
      system.accessPath.acceptsInstrumentDiameter >= system.maximumInstrumentDiameter and
      system.measuredLeakage <= 20.0 and
      system.controlledPressure <= 15.0
    }
  }

  requirement def InstrumentPassageRequirement {
    doc "The cannula and seals shall permit passage of a compatible 5 mm instrument through the established access channel.";

    subject trocar : TrocarAssembly;

    require constraint {
      trocar.nominalAccessDiameter >= trocar.maximumInstrumentDiameter + 0.3
    }
  }

  requirement def GasSealRequirement {
    doc "The seal housing, duckbill seal, wiper seal, and stopcock shall limit carbon dioxide leakage during instrument exchange and when no instrument is present.";

    subject trocar : TrocarAssembly;

    require constraint {
      trocar.allowableGasLeakage <= 20.0
    }
  }

  requirement def InsufflationSafetyRequirement {
    doc "The trocar assembly shall support regulated insufflation without exceeding the defined safe working pressure at the access device.";

    subject trocar : TrocarAssembly;

    require constraint {
      trocar.maximumSafeInsufflationPressure <= 15.0
    }
  }

  requirement def InsertionForceRequirement {
    doc "The obturator and handle design shall enable controlled insertion while limiting axial force applied at the tissue interface.";

    subject trocar : TrocarAssembly;

    require constraint {
      trocar.maximumInsertionForce <= 30.0
    }
  }

  requirement def SafetyShieldRequirement {
    doc "After entry through the body wall, the obturator tip shield shall deploy to cover the penetrating tip before continued manipulation.";

    subject trocar : TrocarAssembly;

    require constraint {
      trocar.safetyShield.mechanicallyLatchedAfterDeployment == true and
      trocar.safetyShield.deploymentTime <= 0.1
    }
  }

  requirement def SterilityRequirement {
    doc "The trocar system shall preserve sterile readiness before use through an intact sterile barrier.";

    subject system : TrocarSystem;

    require constraint {
      system.sterileBarrier.state == SterilityState::sterile and
      system.sterileBarrier.packageIntegrityVerified == true and
      system.sterileBarrier.expirationValid == true
    }
  }

  requirement def CannulaRetentionRequirement {
    doc "The cannula shall remain stable in the abdominal wall during instrument exchange and insufflation.";

    subject trocar : TrocarAssembly;

    require constraint {
      trocar.fixationGrip.axialRetentionForce >= 10.0
    }
  }

  requirement def TrocarSystemRequirementSet {
    doc "Integrated requirement set for the trocar-based access system.";

    subject system : TrocarSystem;

    requirement primaryFunction : PrimaryFunctionRequirement {
      subject system = system;
    }

    requirement sterileReadiness : SterilityRequirement {
      subject system = system;
    }

    requirement passage : InstrumentPassageRequirement {
      subject trocar = system.trocar;
    }

    requirement gasSeal : GasSealRequirement {
      subject trocar = system.trocar;
    }

    requirement pressureSafety : InsufflationSafetyRequirement {
      subject trocar = system.trocar;
    }

    requirement insertionSafety : InsertionForceRequirement {
      subject trocar = system.trocar;
    }

    requirement shieldSafety : SafetyShieldRequirement {
      subject trocar = system.trocar;
    }

    requirement cannulaRetention : CannulaRetentionRequirement {
      subject trocar = system.trocar;
    }
  }

  part trocarAccessSystem : TrocarSystem;

  requirement trocarAccessSystemRequirements : TrocarSystemRequirementSet {
    subject system = trocarAccessSystem;
  }
}
