package LaundryFoldingMachineModel {

  attribute def Mass {
    :>> unit = "kg";
  }

  attribute def Length {
    :>> unit = "m";
  }

  attribute def Area {
    :>> unit = "m^2";
  }

  attribute def Time {
    :>> unit = "s";
  }

  attribute def Temperature {
    :>> unit = "degC";
  }

  attribute def Force {
    :>> unit = "N";
  }

  attribute def Power {
    :>> unit = "W";
  }

  attribute def Voltage {
    :>> unit = "V";
  }

  attribute def Current {
    :>> unit = "A";
  }

  attribute def Speed {
    :>> unit = "m/s";
  }

  attribute def Probability {
    :>> unit = "1";
  }

  enum def GarmentKind {
    enum shirt;
    enum pants;
    enum towel;
    enum sheet;
    enum underwear;
    enum sock;
    enum unknown;
  }

  enum def FabricKind {
    enum cotton;
    enum denim;
    enum polyester;
    enum wool;
    enum silk;
    enum mixed;
    enum unknown;
  }

  enum def FoldPattern {
    enum biFold;
    enum triFold;
    enum sleeveFold;
    enum trouserFold;
    enum towelStackFold;
    enum flatReject;
  }

  enum def MachineMode {
    enum off;
    enum standby;
    enum loading;
    enum identifying;
    enum spreading;
    enum folding;
    enum stacking;
    enum unloading;
    enum paused;
    enum faulted;
  }

  enum def FaultKind {
    enum none;
    enum jam;
    enum overTemperature;
    enum sensorBlocked;
    enum doorOpen;
    enum motorOverCurrent;
    enum garmentUnfoldable;
    enum emergencyStop;
  }

  item def Garment {
    attribute garmentKind : GarmentKind;
    attribute fabricKind : FabricKind;
    attribute mass : Mass;
    attribute maximumDimension : Length;
    attribute surfaceArea : Area;
    attribute moistureFraction : Probability;
    attribute wrinkleScore : Probability;
  }

  item def FoldedGarment :> Garment {
    attribute appliedPattern : FoldPattern;
    attribute foldedWidth : Length;
    attribute foldedLength : Length;
    attribute foldedHeight : Length;
    attribute foldQuality : Probability;
  }

  item def RejectGarment :> Garment {
    attribute rejectionCause : FaultKind;
  }

  item def ElectricalEnergy {
    attribute voltage : Voltage;
    attribute current : Current;
    attribute power : Power;
  }

  item def ControlCommand {
    attribute requestedMode : MachineMode;
    attribute startCycle : Boolean;
    attribute pauseCycle : Boolean;
    attribute resetFault : Boolean;
  }

  item def StatusMessage {
    attribute currentMode : MachineMode;
    attribute currentFault : FaultKind;
    attribute garmentsProcessed : Integer;
    attribute cycleTimeRemaining : Time;
  }

  item def GarmentImage {
    attribute imageWidthPixels : Integer;
    attribute imageHeightPixels : Integer;
    attribute confidence : Probability;
  }

  item def FoldPlan {
    attribute garmentKind : GarmentKind;
    attribute fabricKind : FabricKind;
    attribute selectedPattern : FoldPattern;
    attribute targetWidth : Length;
    attribute targetLength : Length;
    attribute expectedCycleTime : Time;
  }

  port def GarmentInputPort {
    in item incomingGarment : Garment;
  }

  port def FoldedGarmentOutputPort {
    out item foldedGarment : FoldedGarment;
  }

  port def RejectOutputPort {
    out item rejectedGarment : RejectGarment;
  }

  port def ElectricalPowerPort {
    in item suppliedEnergy : ElectricalEnergy;
  }

  port def CommandPort {
    in item command : ControlCommand;
  }

  port def StatusPort {
    out item status : StatusMessage;
  }

  port def ImagePort {
    out item capturedImage : GarmentImage;
  }

  port def FoldPlanPort {
    out item foldPlan : FoldPlan;
  }

  port def ActuationPort {
    in item foldPlan : FoldPlan;
    in item garment : Garment;
    out item foldedGarment : FoldedGarment;
    out item rejectedGarment : RejectGarment;
  }

  port def SafetyInterlockPort {
    out attribute safeToOperate : Boolean;
    out attribute detectedFault : FaultKind;
  }

  part def VisionSubsystem {
    port garmentObservation : ImagePort;

    attribute cameraCount : Integer = 4;
    attribute minimumIdentificationConfidence : Probability = 0.92;
    attribute illuminationPower : Power = 45 [W];
    attribute maximumScanTime : Time = 3 [s];

    action scanGarment {
      in item garment : Garment;
      out item image : GarmentImage;

      first startScan;
      then illuminateGarment;
      then captureTopImage;
      then captureSideImage;
      then mergeImageFeatures;
      then publishImage;

      action startScan;
      action illuminateGarment;
      action captureTopImage;
      action captureSideImage;
      action mergeImageFeatures;
      action publishImage;
    }
  }

  part def GarmentClassifier {
    port planOutput : FoldPlanPort;

    attribute supportedGarmentKinds : Integer = 6;
    attribute minimumPlanConfidence : Probability = 0.90;
    attribute nominalPlanningTime : Time = 1.5 [s];

    action classifyAndPlan {
      in item garment : Garment;
      in item image : GarmentImage;
      out item plan : FoldPlan;

      first determineGarmentKind;
      then estimateFabricCompliance;
      then selectFoldPattern;
      then computeTargetFoldEnvelope;
      then publishPlan;

      action determineGarmentKind;
      action estimateFabricCompliance;
      action selectFoldPattern;
      action computeTargetFoldEnvelope;
      action publishPlan;
    }
  }

  part def FeedConveyor {
    port garmentInput : GarmentInputPort;

    attribute beltSpeed : Speed = 0.18 [m/s];
    attribute usableWidth : Length = 0.85 [m];
    attribute maximumGarmentMass : Mass = 3.0 [kg];

    action feedGarment {
      in item garment : Garment;
      out item positionedGarment : Garment;

      first acceptGarment;
      then centerOnBelt;
      then moveToPresentationZone;
      then stopAtDatum;

      action acceptGarment;
      action centerOnBelt;
      action moveToPresentationZone;
      action stopAtDatum;
    }
  }

  part def SpreadingSubsystem {
    attribute gripperCount : Integer = 4;
    attribute maximumPullForce : Force = 18 [N];
    attribute spreadingTimeLimit : Time = 8 [s];

    action spreadGarment {
      in item garment : Garment;
      out item spreadGarment : Garment;

      first locateCorners;
      then graspEdges;
      then tensionFabric;
      then flattenOnTable;
      then releaseToFoldTable;

      action locateCorners;
      action graspEdges;
      action tensionFabric;
      action flattenOnTable;
      action releaseToFoldTable;
    }
  }

  part def FoldingSubsystem {
    port actuation : ActuationPort;

    attribute foldingPanelCount : Integer = 5;
    attribute maximumPanelForce : Force = 35 [N];
    attribute foldTableWidth : Length = 0.90 [m];
    attribute foldTableLength : Length = 1.20 [m];
    attribute nominalFoldTime : Time = 12 [s];

    action executeFold {
      in item garment : Garment;
      in item plan : FoldPlan;
      out item foldedGarment : FoldedGarment;
      out item rejectedGarment : RejectGarment;

      first validateFoldPlan;
      then alignGarmentToFoldAxes;
      then applyPrimaryFold;
      then applySecondaryFold;
      then compressFoldedGarment;
      then inspectFoldQuality;
      then routeFoldedOrRejected;

      action validateFoldPlan;
      action alignGarmentToFoldAxes;
      action applyPrimaryFold;
      action applySecondaryFold;
      action compressFoldedGarment;
      action inspectFoldQuality;
      action routeFoldedOrRejected;
    }
  }

  part def StackingSubsystem {
    port foldedOutput : FoldedGarmentOutputPort;

    attribute stackCapacity : Integer = 20;
    attribute maximumStackHeight : Length = 0.45 [m];
    attribute alignmentTolerance : Length = 0.015 [m];

    action stackFoldedGarment {
      in item foldedGarment : FoldedGarment;
      out item stackedGarment : FoldedGarment;

      first receiveFoldedGarment;
      then alignWithStack;
      then lowerOntoStack;
      then updateStackCount;

      action receiveFoldedGarment;
      action alignWithStack;
      action lowerOntoStack;
      action updateStackCount;
    }
  }

  part def RejectBin {
    port rejectOutput : RejectOutputPort;

    attribute rejectCapacity : Integer = 10;

    action storeRejectedGarment {
      in item rejectedGarment : RejectGarment;

      first receiveRejectedGarment;
      then logRejectCause;

      action receiveRejectedGarment;
      action logRejectCause;
    }
  }

  part def SafetySubsystem {
    port interlock : SafetyInterlockPort;

    attribute emergencyStopPressed : Boolean = false;
    attribute accessDoorClosed : Boolean = true;
    attribute maximumSafeTemperature : Temperature = 55 [degC];
    attribute maximumSafeCurrent : Current = 12 [A];

    action evaluateSafety {
      in attribute measuredTemperature : Temperature;
      in attribute measuredCurrent : Current;
      out attribute safeToOperate : Boolean;
      out attribute fault : FaultKind;

      first checkEmergencyStop;
      then checkAccessDoor;
      then checkTemperature;
      then checkMotorCurrent;
      then publishSafetyState;

      action checkEmergencyStop;
      action checkAccessDoor;
      action checkTemperature;
      action checkMotorCurrent;
      action publishSafetyState;
    }
  }

  part def OperatorInterface {
    port commandInput : CommandPort;
    port statusOutput : StatusPort;

    attribute displaySize : Length = 0.178 [m];
    attribute audibleAlarmPower : Power = 2 [W];

    action handleOperatorInteraction {
      in item operatorCommand : ControlCommand;
      out item status : StatusMessage;

      first readControls;
      then validateCommand;
      then updateDisplay;
      then soundAlarmIfFaulted;

      action readControls;
      action validateCommand;
      action updateDisplay;
      action soundAlarmIfFaulted;
    }
  }

  part def PowerSubsystem {
    port mainsInput : ElectricalPowerPort;

    attribute nominalVoltage : Voltage = 120 [V];
    attribute maximumPowerDraw : Power = 950 [W];
    attribute standbyPowerDraw : Power = 18 [W];

    action distributePower {
      in item suppliedEnergy : ElectricalEnergy;
      out item regulatedEnergy : ElectricalEnergy;

      first filterMainsInput;
      then convertToControlVoltage;
      then supplyMotors;
      then monitorCurrent;

      action filterMainsInput;
      action convertToControlVoltage;
      action supplyMotors;
      action monitorCurrent;
    }
  }

  part def LaundryFoldingMachine {
    port garmentIn : GarmentInputPort;
    port foldedOut : FoldedGarmentOutputPort;
    port rejectedOut : RejectOutputPort;
    port powerIn : ElectricalPowerPort;
    port commandIn : CommandPort;
    port statusOut : StatusPort;

    part powerSubsystem : PowerSubsystem;
    part operatorInterface : OperatorInterface;
    part feedConveyor : FeedConveyor;
    part visionSubsystem : VisionSubsystem;
    part garmentClassifier : GarmentClassifier;
    part spreadingSubsystem : SpreadingSubsystem;
    part foldingSubsystem : FoldingSubsystem;
    part stackingSubsystem : StackingSubsystem;
    part rejectBin : RejectBin;
    part safetySubsystem : SafetySubsystem;

    attribute currentMode : MachineMode = MachineMode::off;
    attribute currentFault : FaultKind = FaultKind::none;
    attribute processedGarmentCount : Integer = 0;
    attribute nominalGarmentsPerHour : Integer = 60;
    attribute maximumGarmentMass : Mass = 3.0 [kg];
    attribute maximumGarmentDimension : Length = 1.20 [m];
    attribute averageCycleTime : Time = 60 [s];
    attribute acceptableFoldQuality : Probability = 0.90;

    connect powerIn to powerSubsystem.mainsInput;
    connect commandIn to operatorInterface.commandInput;
    connect operatorInterface.statusOutput to statusOut;
    connect garmentIn to feedConveyor.garmentInput;
    connect stackingSubsystem.foldedOutput to foldedOut;
    connect rejectBin.rejectOutput to rejectedOut;

    action foldLaundry {
      in item looseGarment : Garment;
      out item foldedGarment : FoldedGarment;
      out item rejectedGarment : RejectGarment;

      first acceptLooseGarment;
      then evaluateOperationalSafety;
      then feedAndPositionGarment;
      then scanGarmentShape;
      then classifyGarmentAndGeneratePlan;
      then spreadAndFlattenGarment;
      then foldAccordingToPlan;
      then stackOrRejectResult;
      then publishCycleStatus;

      action acceptLooseGarment;
      action evaluateOperationalSafety;
      action feedAndPositionGarment;
      action scanGarmentShape;
      action classifyGarmentAndGeneratePlan;
      action spreadAndFlattenGarment;
      action foldAccordingToPlan;
      action stackOrRejectResult;
      action publishCycleStatus;
    }

    state def OperatingStateMachine {
      entry action initializeMachine;

      state Off;
      state Standby;
      state Loading;
      state Identifying;
      state Spreading;
      state Folding;
      state Stacking;
      state Unloading;
      state Paused;
      state Faulted;

      transition powerApplied
        first Off
        accept ControlCommand
        if command.startCycle == false
        then Standby;

      transition startRequested
        first Standby
        accept ControlCommand
        if command.startCycle == true
        then Loading;

      transition garmentAccepted
        first Loading
        then Identifying;

      transition identificationComplete
        first Identifying
        if currentFault == FaultKind::none
        then Spreading;

      transition cannotIdentify
        first Identifying
        if currentFault == FaultKind::garmentUnfoldable
        then Faulted;

      transition spreadComplete
        first Spreading
        then Folding;

      transition foldComplete
        first Folding
        if currentFault == FaultKind::none
        then Stacking;

      transition foldRejected
        first Folding
        if currentFault == FaultKind::garmentUnfoldable
        then Unloading;

      transition stackComplete
        first Stacking
        then Unloading;

      transition unloadComplete
        first Unloading
        then Standby;

      transition pauseRequested
        first Loading
        accept ControlCommand
        if command.pauseCycle == true
        then Paused;

      transition pauseDuringFold
        first Folding
        accept ControlCommand
        if command.pauseCycle == true
        then Paused;

      transition resumeRequested
        first Paused
        accept ControlCommand
        if command.startCycle == true
        then Loading;

      transition safetyFault
        first Standby
        if currentFault != FaultKind::none
        then Faulted;

      transition operationalFault
        first Folding
        if currentFault == FaultKind::jam or currentFault == FaultKind::motorOverCurrent
        then Faulted;

      transition resetFault
        first Faulted
        accept ControlCommand
        if command.resetFault == true
        then Standby;

      transition powerRemoved
        first Standby
        then Off;
    }
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The laundry-folding machine shall receive loose, clean garments and transform each processable garment into a compact folded garment stack with minimal operator intervention. */
    subject machine : LaundryFoldingMachine;

    require constraint {
      machine.nominalGarmentsPerHour >= 45
    }
  }

  requirement def GarmentCompatibilityRequirement {
    doc /* The machine shall process common household shirts, pants, towels, sheets, underwear, and socks within the defined mass and dimension limits. */
    subject machine : LaundryFoldingMachine;

    require constraint {
      machine.maximumGarmentMass >= 3.0 [kg] and machine.maximumGarmentDimension >= 1.20 [m]
    }
  }

  requirement def FoldQualityRequirement {
    doc /* The machine shall produce folded garments with a fold quality score of at least 0.90 for supported garment and fabric combinations. */
    subject machine : LaundryFoldingMachine;

    require constraint {
      machine.acceptableFoldQuality >= 0.90
    }
  }

  requirement def CycleTimeRequirement {
    doc /* The machine shall complete the nominal feed, identify, spread, fold, and stack cycle within sixty seconds for one supported garment. */
    subject machine : LaundryFoldingMachine;

    require constraint {
      machine.averageCycleTime <= 60 [s]
    }
  }

  requirement def SafetyRequirement {
    doc /* The machine shall stop motion and enter a faulted state when an emergency stop, open access door, jam, over-temperature, or motor over-current condition is detected. */
    subject machine : LaundryFoldingMachine;

    require constraint {
      machine.currentFault == FaultKind::none or machine.currentMode == MachineMode::faulted
    }
  }

  requirement def PowerRequirement {
    doc /* The machine shall operate from household electrical service and shall not exceed the specified maximum power draw during normal folding operation. */
    subject subsystem : PowerSubsystem;

    require constraint {
      subsystem.nominalVoltage == 120 [V] and subsystem.maximumPowerDraw <= 950 [W]
    }
  }

  requirement def RejectHandlingRequirement {
    doc /* The machine shall route garments that cannot be identified, spread, or folded to a reject bin without contaminating the folded output stack. */
    subject machine : LaundryFoldingMachine;

    require constraint {
      machine.currentFault != FaultKind::garmentUnfoldable or machine.currentMode == MachineMode::unloading or machine.currentMode == MachineMode::faulted
    }
  }

  requirement def OperatorVisibilityRequirement {
    doc /* The machine shall provide operating mode, fault state, processed garment count, and remaining cycle time to the operator interface. */
    subject interface : OperatorInterface;
  }

  part laundryFoldingMachineSystem : LaundryFoldingMachine {
    :>> nominalGarmentsPerHour = 60;
    :>> maximumGarmentMass = 3.0 [kg];
    :>> maximumGarmentDimension = 1.20 [m];
    :>> averageCycleTime = 60 [s];
    :>> acceptableFoldQuality = 0.90;
  }

  satisfy PrimaryFunctionRequirement by laundryFoldingMachineSystem;
  satisfy GarmentCompatibilityRequirement by laundryFoldingMachineSystem;
  satisfy FoldQualityRequirement by laundryFoldingMachineSystem;
  satisfy CycleTimeRequirement by laundryFoldingMachineSystem;
  satisfy SafetyRequirement by laundryFoldingMachineSystem;
  satisfy PowerRequirement by laundryFoldingMachineSystem.powerSubsystem;
  satisfy RejectHandlingRequirement by laundryFoldingMachineSystem;
  satisfy OperatorVisibilityRequirement by laundryFoldingMachineSystem.operatorInterface;
}