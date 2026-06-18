package PlungerBasedDrainClearingSystem {

  import ScalarValues::*;
  import NumericalFunctions::*;

  // -----------------------------
  // Value types and units
  // -----------------------------

  attribute def Length {
    :>> unit = "m";
  }

  attribute def Area {
    :>> unit = "m^2";
  }

  attribute def Volume {
    :>> unit = "m^3";
  }

  attribute def Mass {
    :>> unit = "kg";
  }

  attribute def Time {
    :>> unit = "s";
  }

  attribute def Velocity {
    :>> unit = "m/s";
  }

  attribute def Acceleration {
    :>> unit = "m/s^2";
  }

  attribute def Force {
    :>> unit = "N";
  }

  attribute def Pressure {
    :>> unit = "Pa";
  }

  attribute def FlowRate {
    :>> unit = "m^3/s";
  }

  attribute def Stiffness {
    :>> unit = "N/m";
  }

  attribute def Damping {
    :>> unit = "N*s/m";
  }

  attribute def Ratio {
    :>> unit = "1";
  }

  attribute def Frequency {
    :>> unit = "Hz";
  }

  attribute def Angle {
    :>> unit = "rad";
  }

  attribute def BooleanValue {
    :>> type = Boolean;
  }

  // -----------------------------
  // Item definitions
  // -----------------------------

  item def HandGripLoad {
    attribute axialForce : Force;
    attribute lateralForce : Force;
    attribute gripTorque : Force;
    attribute commandStroke : Length;
  }

  item def RodMotion {
    attribute axialDisplacement : Length;
    attribute axialVelocity : Velocity;
    attribute axialAcceleration : Acceleration;
  }

  item def CupDeformation {
    attribute rimCompression : Length;
    attribute cupInversionDepth : Length;
    attribute storedElasticForce : Force;
  }

  item def PressurePulse {
    attribute peakPositivePressure : Pressure;
    attribute peakNegativePressure : Pressure;
    attribute pulseDuration : Time;
    attribute pulseFrequency : Frequency;
  }

  item def DrainFluid {
    attribute liquidVolume : Volume;
    attribute airVolume : Volume;
    attribute suspendedDebrisMass : Mass;
    attribute flowRate : FlowRate;
  }

  item def ObstructionFragment {
    attribute mass : Mass;
    attribute characteristicDiameter : Length;
    attribute mobilityRatio : Ratio;
  }

  item def SealStatus {
    attribute isSealed : BooleanValue;
    attribute leakageRatio : Ratio;
    attribute contactPressure : Pressure;
  }

  item def UserInstruction {
    attribute targetStrokeAmplitude : Length;
    attribute targetCycleFrequency : Frequency;
    attribute requiredSealForce : Force;
  }

  item def RestoredDrainFlow {
    attribute achievedFlowRate : FlowRate;
    attribute remainingObstructionRatio : Ratio;
    attribute clearingSuccessful : BooleanValue;
  }

  // -----------------------------
  // Port definitions
  // -----------------------------

  port def ManualInputPort {
    in load : HandGripLoad;
    out instructionFeedback : UserInstruction;
  }

  port def MechanicalTranslationPort {
    in motionIn : RodMotion;
    out reactionForce : Force;
  }

  port def MechanicalOutputPort {
    out motionOut : RodMotion;
    in reactionForce : Force;
  }

  port def RodCupInterfacePort {
    in rodMotion : RodMotion;
    out cupReaction : Force;
  }

  port def CupFluidPort {
    out pulse : PressurePulse;
    in seal : SealStatus;
    in fluidBackPressure : Pressure;
  }

  port def DrainFluidPort {
    in pulse : PressurePulse;
    in displacedFluid : DrainFluid;
    out sealFeedback : SealStatus;
    out loosenedDebris : ObstructionFragment;
    out restoredFlow : RestoredDrainFlow;
  }

  port def DrainEnvironmentPort {
    in incomingWastewater : DrainFluid;
    out outgoingWastewater : DrainFluid;
    out ambientBackPressure : Pressure;
  }

  // -----------------------------
  // Component definitions
  // -----------------------------

  part def UserOperator {
    attribute availablePeakForce : Force = 180 [N];
    attribute nominalCycleFrequency : Frequency = 1.2 [Hz];
    attribute nominalStrokeAmplitude : Length = 0.18 [m];

    port hands : ManualInputPort;

    action performManualPumping : ApplyManualPumpingAction;
  }

  part def ErgonomicHandle {
    attribute handleLength : Length = 0.28 [m];
    attribute gripDiameter : Length = 0.032 [m];
    attribute maxAllowableGripForce : Force = 300 [N];
    attribute slipResistant : BooleanValue = true;

    port userSide : ManualInputPort;
    port rodSide : MechanicalOutputPort;
  }

  part def PlungerRod {
    attribute rodLength : Length = 0.55 [m];
    attribute rodDiameter : Length = 0.024 [m];
    attribute axialStiffness : Stiffness = 120000 [N/m];
    attribute dampingCoefficient : Damping = 12 [N*s/m];
    attribute allowableCompressiveForce : Force = 450 [N];

    port handleEnd : MechanicalTranslationPort;
    port cupEnd : MechanicalOutputPort;
  }

  part def FlexibleCup {
    attribute cupOuterDiameter : Length = 0.155 [m];
    attribute cupInnerDiameter : Length = 0.125 [m];
    attribute cupDepth : Length = 0.075 [m];
    attribute lipWidth : Length = 0.018 [m];
    attribute effectiveArea : Area = 0.014 [m^2];
    attribute cupCompliance : Ratio = 0.72;
    attribute rimSealCompressionNominal : Length = 0.006 [m];
    attribute maximumInversionDepth : Length = 0.055 [m];

    port rodMount : RodCupInterfacePort;
    port fluidSide : CupFluidPort;
    port rimContact : CupFluidPort;

    action convertMotionToPressure : GeneratePressurePulseAction;
  }

  part def SealLip {
    attribute lipOuterDiameter : Length = 0.158 [m];
    attribute lipContactWidth : Length = 0.015 [m];
    attribute minimumContactPressure : Pressure = 2500 [Pa];
    attribute maximumLeakageRatio : Ratio = 0.12;
    attribute compatibleSurfaceRoughness : Length = 0.002 [m];

    port cupSide : CupFluidPort;
    port drainSide : DrainFluidPort;

    action formTemporarySeal : EstablishSealAction;
  }

  part def DrainOpeningAdapter {
    attribute drainOpeningDiameter : Length = 0.100 [m];
    attribute waterTrapVolume : Volume = 0.0015 [m^3];
    attribute initialStandingWaterVolume : Volume = 0.0008 [m^3];
    attribute drainThroatLength : Length = 0.18 [m];
    attribute rimFlatnessTolerance : Length = 0.004 [m];

    port plungerSide : DrainFluidPort;
    port pipeSide : DrainEnvironmentPort;
  }

  part def DrainPipe {
    attribute pipeDiameter : Length = 0.050 [m];
    attribute pipeLengthToTrap : Length = 1.2 [m];
    attribute nominalClearFlowRate : FlowRate = 0.00045 [m^3/s];
    attribute blockedFlowRate : FlowRate = 0.00004 [m^3/s];
    attribute ambientPressure : Pressure = 101325 [Pa];

    port drainMouth : DrainEnvironmentPort;
    port downstream : DrainEnvironmentPort;
  }

  part def Obstruction {
    attribute initialObstructionMass : Mass = 0.080 [kg];
    attribute initialBlockageRatio : Ratio = 0.86;
    attribute adhesionForce : Force = 32 [N];
    attribute breakupPressureThreshold : Pressure = 4200 [Pa];
    attribute mobilityAfterBreakup : Ratio = 0.70;

    port exposedFace : DrainFluidPort;

    action breakUpAndMobilize : MobilizeObstructionAction;
  }

  part def PressurePulseController {
    attribute recommendedStrokeAmplitude : Length = 0.15 [m];
    attribute recommendedCycleFrequency : Frequency = 1.0 [Hz];
    attribute minimumCyclesForClearing : Integer = 6;
    attribute maximumRecommendedCycles : Integer = 20;
    attribute minimumEffectivePositivePressure : Pressure = 3800 [Pa];
    attribute minimumEffectiveNegativePressure : Pressure = -2500 [Pa];

    port operatorGuidance : ManualInputPort;
    port pulseMonitor : CupFluidPort;

    action guideUse : GuidePlungingAction;
  }

  // -----------------------------
  // High-level system definition
  // -----------------------------

  part def PlungerDrainClearingSystem {
    attribute primaryFunction : String =
      "Convert repeated manual axial motion into alternating positive pressure and suction pulses through a flexible sealing cup to dislodge a drain obstruction and restore wastewater flow.";
    attribute totalMass : Mass = 0.95 [kg];
    attribute overallLength : Length = 0.72 [m];
    attribute expectedClearingTime : Time = 45 [s];
    attribute designServiceLifeCycles : Integer = 25000;

    part operator : UserOperator;
    part handle : ErgonomicHandle;
    part rod : PlungerRod;
    part cup : FlexibleCup;
    part sealLip : SealLip;
    part drainOpening : DrainOpeningAdapter;
    part drainPipe : DrainPipe;
    part clog : Obstruction;
    part controller : PressurePulseController;

    port userInterface : ManualInputPort;
    port drainInterface : DrainFluidPort;
    port environmentInterface : DrainEnvironmentPort;

    connection userToHandle connect userInterface to handle.userSide;
    connection operatorToHandle connect operator.hands to handle.userSide;
    connection handleToRod connect handle.rodSide to rod.handleEnd;
    connection rodToCup connect rod.cupEnd to cup.rodMount;
    connection cupToSeal connect cup.rimContact to sealLip.cupSide;
    connection sealToDrainOpening connect sealLip.drainSide to drainOpening.plungerSide;
    connection systemDrainInterface connect drainInterface to drainOpening.plungerSide;
    connection drainOpeningToPipe connect drainOpening.pipeSide to drainPipe.drainMouth;
    connection clogToDrainOpening connect clog.exposedFace to drainOpening.plungerSide;
    connection pipeToEnvironment connect drainPipe.downstream to environmentInterface;
    connection controllerToOperator connect controller.operatorGuidance to operator.hands;
    connection controllerToCup connect controller.pulseMonitor to cup.fluidSide;

    action primaryUse : ClearDrainAction;

    state operationalState : PlungerOperationalState;
  }

  // -----------------------------
  // Action definitions
  // -----------------------------

  action def ApplyManualPumpingAction {
    in instruction : UserInstruction;
    out appliedLoad : HandGripLoad;

    attribute actualPeakForce : Force;
    attribute actualStrokeAmplitude : Length;
    attribute actualCycleFrequency : Frequency;

    first start;
    then alignHands;
    then pushDown;
    then pullUp;
    then repeatStroke;
    then done;

    action alignHands {
      out centeredLoad : HandGripLoad;
    }

    action pushDown {
      in centeredLoad : HandGripLoad;
      out compressionLoad : HandGripLoad;
    }

    action pullUp {
      in compressionLoad : HandGripLoad;
      out suctionLoad : HandGripLoad;
    }

    action repeatStroke {
      in suctionLoad : HandGripLoad;
      out appliedLoad : HandGripLoad;
    }
  }

  action def EstablishSealAction {
    in cupCompression : CupDeformation;
    in drainBackPressure : Pressure;
    out sealStatus : SealStatus;

    attribute requiredCompression : Length = 0.005 [m];
    attribute achievedContactPressure : Pressure;

    first start;
    then compressLip;
    then evaluateLeakage;
    then reportSeal;

    action compressLip {
      in cupCompression : CupDeformation;
      out contactPressure : Pressure;
    }

    action evaluateLeakage {
      in contactPressure : Pressure;
      out leakageRatio : Ratio;
    }

    action reportSeal {
      in leakageRatio : Ratio;
      out sealStatus : SealStatus;
    }
  }

  action def GeneratePressurePulseAction {
    in rodMotion : RodMotion;
    in sealStatus : SealStatus;
    in fluidBackPressure : Pressure;
    out pressurePulse : PressurePulse;
    out cupDeformation : CupDeformation;

    attribute effectiveCupArea : Area = 0.014 [m^2];
    attribute pressureGain : Ratio = 0.82;

    first start;
    then deformCup;
    then compressFluid;
    then generateSuction;
    then outputPulse;

    action deformCup {
      in rodMotion : RodMotion;
      out cupDeformation : CupDeformation;
    }

    action compressFluid {
      in cupDeformation : CupDeformation;
      out positivePulse : PressurePulse;
    }

    action generateSuction {
      in cupDeformation : CupDeformation;
      out negativePulse : PressurePulse;
    }

    action outputPulse {
      in positivePulse : PressurePulse;
      in negativePulse : PressurePulse;
      out pressurePulse : PressurePulse;
    }
  }

  action def MobilizeObstructionAction {
    in pressurePulse : PressurePulse;
    in initialFluid : DrainFluid;
    out fragment : ObstructionFragment;
    out restoredFlow : RestoredDrainFlow;

    attribute breakupAchieved : BooleanValue;
    attribute finalBlockageRatio : Ratio;

    first start;
    then applyPositivePulse;
    then applyNegativePulse;
    then fractureObstruction;
    then flushFragments;
    then reportFlow;

    action applyPositivePulse {
      in pressurePulse : PressurePulse;
      out compressedObstructionForce : Force;
    }

    action applyNegativePulse {
      in pressurePulse : PressurePulse;
      out reverseShearForce : Force;
    }

    action fractureObstruction {
      in compressedObstructionForce : Force;
      in reverseShearForce : Force;
      out fragment : ObstructionFragment;
    }

    action flushFragments {
      in fragment : ObstructionFragment;
      in initialFluid : DrainFluid;
      out clearedFluid : DrainFluid;
    }

    action reportFlow {
      in clearedFluid : DrainFluid;
      out restoredFlow : RestoredDrainFlow;
    }
  }

  action def GuidePlungingAction {
    in measuredSeal : SealStatus;
    in measuredPulse : PressurePulse;
    out instruction : UserInstruction;

    first start;
    then assessSeal;
    then assessPulseStrength;
    then issueGuidance;

    action assessSeal {
      in measuredSeal : SealStatus;
      out sealAdequate : BooleanValue;
    }

    action assessPulseStrength {
      in measuredPulse : PressurePulse;
      out pulseAdequate : BooleanValue;
    }

    action issueGuidance {
      in sealAdequate : BooleanValue;
      in pulseAdequate : BooleanValue;
      out instruction : UserInstruction;
    }
  }

  action def ClearDrainAction {
    in operatorLoad : HandGripLoad;
    in startingFluid : DrainFluid;
    out finalFlow : RestoredDrainFlow;

    part handle : ErgonomicHandle;
    part rod : PlungerRod;
    part cup : FlexibleCup;
    part sealLip : SealLip;
    part obstruction : Obstruction;

    attribute cycleCount : Integer;
    attribute clearingDetected : BooleanValue;

    first start;
    then positionCupOverDrain;
    then establishSeal;
    then performPressureCycles;
    then mobilizeClog;
    then verifyFlow;
    then finish;

    action positionCupOverDrain {
      in operatorLoad : HandGripLoad;
      out initialSealCompression : CupDeformation;
    }

    action establishSeal : EstablishSealAction {
      in cupCompression = initialSealCompression;
      out sealStatus;
    }

    action performPressureCycles : GeneratePressurePulseAction {
      in sealStatus = establishSeal.sealStatus;
      out pressurePulse;
    }

    action mobilizeClog : MobilizeObstructionAction {
      in pressurePulse = performPressureCycles.pressurePulse;
      in initialFluid = startingFluid;
      out restoredFlow;
    }

    action verifyFlow {
      in restoredFlow = mobilizeClog.restoredFlow;
      out finalFlow : RestoredDrainFlow;
    }
  }

  // -----------------------------
  // State machine definition
  // -----------------------------

  state def PlungerOperationalState {
    attribute currentCycleCount : Integer;
    attribute sealEstablished : BooleanValue;
    attribute obstructionCleared : BooleanValue;

    entry action initialize {
      out currentCycleCount : Integer;
    }

    state Stored {
      entry action relaxCup;
    }

    state Positioned {
      entry action alignCupWithDrain;
    }

    state Sealing {
      entry action compressSealLip;
    }

    state Pumping {
      entry action executeStrokeCycle;
      do action repeatPressurePulses;
    }

    state ClearingDetected {
      entry action senseImprovedFlow;
    }

    state Rinsing {
      entry action flushRemainingDebris;
    }

    state Complete {
      entry action reportClearingComplete;
    }

    state RepositionRequired {
      entry action requestBetterSeal;
    }

    transition initialTransition first Stored;

    transition placeOnDrain
      first Stored
      then Positioned;

    transition beginSeal
      first Positioned
      then Sealing;

    transition sealAdequate
      first Sealing
      then Pumping
      guard sealEstablished == true;

    transition sealLeakDetected
      first Sealing
      then RepositionRequired
      guard sealEstablished == false;

    transition reposition
      first RepositionRequired
      then Positioned;

    transition pressureCyclesEffective
      first Pumping
      then ClearingDetected
      guard obstructionCleared == true;

    transition continuePumping
      first Pumping
      then Pumping
      guard currentCycleCount < 20 and obstructionCleared == false;

    transition rinseDrain
      first ClearingDetected
      then Rinsing;

    transition finishUse
      first Rinsing
      then Complete;
  }

  // -----------------------------
  // Requirements
  // -----------------------------

  requirement def PrimaryFunctionRequirement {
    subject system : PlungerDrainClearingSystem;

    doc /* The system shall use a plunger to restore drain flow by converting user-applied axial motion into alternating pressure and suction pulses at the drain opening. */

    require constraint {
      system.cup.effectiveArea >= 0.010 [m^2]
    }
  }

  requirement def SealRequirement {
    subject lip : SealLip;

    doc /* The seal lip shall create a temporary seal against a typical drain rim with sufficiently low leakage during pumping. */

    require constraint {
      lip.maximumLeakageRatio <= 0.12
    }

    require constraint {
      lip.minimumContactPressure >= 2500 [Pa]
    }
  }

  requirement def ManualForceRequirement {
    subject system : PlungerDrainClearingSystem;

    doc /* The system shall be operable by a typical user without exceeding the maximum recommended manual peak force. */

    require constraint {
      system.operator.availablePeakForce >= 120 [N]
    }

    require constraint {
      system.handle.maxAllowableGripForce >= system.operator.availablePeakForce
    }
  }

  requirement def PressurePulseRequirement {
    subject controller : PressurePulseController;

    doc /* The system shall provide guidance for pressure pulses strong enough to disturb a common sink or tub drain obstruction. */

    require constraint {
      controller.minimumEffectivePositivePressure >= 3500 [Pa]
    }

    require constraint {
      controller.minimumEffectiveNegativePressure <= -2000 [Pa]
    }
  }

  requirement def CupStrokeRequirement {
    subject cup : FlexibleCup;

    doc /* The flexible cup shall tolerate the nominal plunging stroke without permanent inversion or loss of sealing function. */

    require constraint {
      cup.maximumInversionDepth >= 0.050 [m]
    }

    require constraint {
      cup.rimSealCompressionNominal >= 0.004 [m]
    }
  }

  requirement def DrainFlowRestorationRequirement {
    subject pipe : DrainPipe;

    doc /* After successful clearing, the drain shall recover at least seventy percent of nominal clear flow rate. */

    require constraint {
      pipe.blockedFlowRate < 0.25 * pipe.nominalClearFlowRate
    }
  }

  requirement def DurabilityRequirement {
    subject system : PlungerDrainClearingSystem;

    doc /* The plunger assembly shall withstand repeated household use. */

    require constraint {
      system.designServiceLifeCycles >= 20000
    }

    require constraint {
      system.rod.allowableCompressiveForce >= 2.0 * system.operator.availablePeakForce
    }
  }

  requirement def UsabilityRequirement {
    subject system : PlungerDrainClearingSystem;

    doc /* The complete plunger shall be light and long enough for ergonomic manual drain clearing. */

    require constraint {
      system.totalMass <= 1.5 [kg]
    }

    require constraint {
      system.overallLength >= 0.60 [m]
    }
  }

  requirement def ClearingTimeRequirement {
    subject system : PlungerDrainClearingSystem;

    doc /* The high-level clearing operation should complete within a practical household intervention time for typical blockages. */

    require constraint {
      system.expectedClearingTime <= 120 [s]
    }
  }

  // -----------------------------
  // Verification cases
  // -----------------------------

  verification def VerifySealPerformance {
    subject lip : SealLip;
    objective requirement SealRequirement;

    action measureContactPressure {
      out measuredContactPressure : Pressure;
    }

    action measureLeakage {
      out measuredLeakageRatio : Ratio;
    }
  }

  verification def VerifyPressurePulseGeneration {
    subject system : PlungerDrainClearingSystem;
    objective requirement PressurePulseRequirement;

    action applyNominalStroke {
      out measuredPulse : PressurePulse;
    }
  }

  verification def VerifyDrainFlowRestoration {
    subject system : PlungerDrainClearingSystem;
    objective requirement DrainFlowRestorationRequirement;

    action simulateBlockedDrainClearing {
      out restoredFlow : RestoredDrainFlow;
    }
  }

  // -----------------------------
  // Example configured system
  // -----------------------------

  part householdPlungerSystem : PlungerDrainClearingSystem {
    attribute totalMass = 0.95 [kg];
    attribute overallLength = 0.72 [m];
    attribute expectedClearingTime = 45 [s];

    part handle {
      attribute handleLength = 0.28 [m];
      attribute gripDiameter = 0.032 [m];
      attribute maxAllowableGripForce = 300 [N];
    }

    part rod {
      attribute rodLength = 0.55 [m];
      attribute rodDiameter = 0.024 [m];
      attribute allowableCompressiveForce = 450 [N];
    }

    part cup {
      attribute cupOuterDiameter = 0.155 [m];
      attribute cupDepth = 0.075 [m];
      attribute effectiveArea = 0.014 [m^2];
      attribute maximumInversionDepth = 0.055 [m];
    }

    part sealLip {
      attribute minimumContactPressure = 2500 [Pa];
      attribute maximumLeakageRatio = 0.12;
    }

    part drainPipe {
      attribute nominalClearFlowRate = 0.00045 [m^3/s];
      attribute blockedFlowRate = 0.00004 [m^3/s];
    }

    part clog {
      attribute initialObstructionMass = 0.080 [kg];
      attribute initialBlockageRatio = 0.86;
      attribute breakupPressureThreshold = 4200 [Pa];
    }
  }

}
