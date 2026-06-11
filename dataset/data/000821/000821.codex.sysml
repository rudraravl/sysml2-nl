package VeressNeedleSystemModel {

  import ScalarValues::*;
  import SI::*;

  item def Gas;
  item def CarbonDioxide specializes Gas;
  item def Tissue;
  item def AbdominalWall specializes Tissue;
  item def PeritonealCavity;
  item def SterileBarrier;
  item def PressureSignal;
  item def FlowSignal;
  item def PositionSignal;

  attribute def Pressure :> ISQ::pressure {
    unit = "kPa";
  }

  attribute def FlowRate :> ISQ::volumeFlowRate {
    unit = "L/min";
  }

  attribute def Length :> ISQ::length {
    unit = "mm";
  }

  attribute def Diameter :> ISQ::length {
    unit = "mm";
  }

  attribute def Force :> ISQ::force {
    unit = "N";
  }

  attribute def Volume :> ISQ::volume {
    unit = "L";
  }

  attribute def TimeDuration :> ISQ::duration {
    unit = "s";
  }

  enum def NeedleState {
    member Unarmed;
    member TissuePenetration;
    member PeritonealEntry;
    member InsufflationReady;
    member Insufflating;
    member Complete;
    member Fault;
  }

  port def GasInletPort {
    in item gasIn : CarbonDioxide;
    out item pressureFeedback : PressureSignal;
    out item flowFeedback : FlowSignal;
  }

  port def GasOutletPort {
    out item gasOut : CarbonDioxide;
  }

  port def TissueInterfacePort {
    in item contactedTissue : AbdominalWall;
    out item positionFeedback : PositionSignal;
  }

  port def UserGripPort {
    in attribute insertionForce : Force;
    in attribute insertionAngle : Real;
    out attribute tactileFeedback : Force;
  }

  part def SharpOuterCannula {
    attribute outerDiameter : Diameter = 2.1 [mm];
    attribute innerDiameter : Diameter = 1.7 [mm];
    attribute usableLength : Length = 120 [mm];
    attribute bevelAngle : Real = 15.0;
    attribute tipPenetrationForce : Force = 3.5 [N];

    port tissuePort : TissueInterfacePort;
    port outletPort : GasOutletPort;
  }

  part def SpringLoadedBluntStylet {
    attribute styletDiameter : Diameter = 1.4 [mm];
    attribute protrusionBeyondTip : Length = 3.0 [mm];
    attribute springPreload : Force = 1.2 [N];
    attribute fullRetractionTravel : Length = 5.0 [mm];
    attribute responseTime : TimeDuration = 0.08 [s];

    state styletState {
      entry; then Exposed;

      state Exposed;
      state Retracted;
      state ReExtended;

      transition expose_to_retract
        first Exposed
        accept TissueResistance
        if tissueContactForce > springPreload
        then Retracted;

      transition retract_to_extend
        first Retracted
        accept CavityEntry
        if tissueContactForce < springPreload
        then ReExtended;

      transition extended_stable
        first ReExtended
        then Exposed;
    }
  }

  part def StopcockValve {
    attribute openFraction : Real = 0.0;
    attribute leakRateClosed : FlowRate = 0.005 [L/min];
    attribute ratedFlowOpen : FlowRate = 8.0 [L/min];
    attribute ratedPressure : Pressure = 20.0 [kPa];

    port inlet : GasInletPort;
    port outlet : GasOutletPort;

    action openValve {
      in attribute commandOpen : Boolean;
      out attribute valveOpen : Boolean;
      if commandOpen {
        openFraction := 1.0;
        valveOpen := true;
      } else {
        openFraction := 0.0;
        valveOpen := false;
      }
    }
  }

  part def NeedleHub {
    attribute gripDiameter : Diameter = 12.0 [mm];
    attribute luerLockDiameter : Diameter = 4.0 [mm];
    attribute deadSpaceVolume : Volume = 0.004 [L];

    port userPort : UserGripPort;
    port gasPort : GasInletPort;
  }

  part def InsufflationSource {
    attribute supplyGas : CarbonDioxide;
    attribute setPressure : Pressure = 12.0 [kPa];
    attribute maxPressure : Pressure = 15.0 [kPa];
    attribute nominalFlow : FlowRate = 2.0 [L/min];
    attribute maxFlow : FlowRate = 8.0 [L/min];

    port outlet : GasInletPort;

    action regulateFlow {
      in attribute measuredPressure : Pressure;
      out attribute deliveredFlow : FlowRate;

      if measuredPressure < setPressure {
        deliveredFlow := nominalFlow;
      } else {
        deliveredFlow := 0.0 [L/min];
      }
    }
  }

  part def PressureAndFlowMonitor {
    attribute measuredPressure : Pressure = 0.0 [kPa];
    attribute measuredFlow : FlowRate = 0.0 [L/min];
    attribute occlusionThresholdPressure : Pressure = 15.0 [kPa];
    attribute minimumConfirmationFlow : FlowRate = 0.2 [L/min];

    in item pressureInput : PressureSignal;
    in item flowInput : FlowSignal;

    action evaluateAccess {
      in attribute pressure : Pressure;
      in attribute flow : FlowRate;
      out attribute accessConfirmed : Boolean;
      out attribute unsafeCondition : Boolean;

      accessConfirmed := pressure < occlusionThresholdPressure and flow >= minimumConfirmationFlow;
      unsafeCondition := pressure >= occlusionThresholdPressure;
    }
  }

  part def VeressNeedleAssembly {
    attribute overallLength : Length = 145 [mm];
    attribute nominalOuterDiameter : Diameter = 2.1 [mm];
    attribute sterile : Boolean = true;
    attribute singleUse : Boolean = true;
    attribute targetInsufflationPressure : Pressure = 12.0 [kPa];

    part cannula : SharpOuterCannula;
    part stylet : SpringLoadedBluntStylet;
    part valve : StopcockValve;
    part hub : NeedleHub;
    part monitor : PressureAndFlowMonitor;

    port operatorInterface : UserGripPort;
    port gasInput : GasInletPort;
    port distalOutput : GasOutletPort;
    port tissueInterface : TissueInterfacePort;

    connect operatorInterface to hub.userPort;
    connect gasInput to hub.gasPort;
    connect hub.gasPort to valve.inlet;
    connect valve.outlet to cannula.outletPort;
    connect cannula.outletPort to distalOutput;
    connect cannula.tissuePort to tissueInterface;

    state operatingState {
      entry; then Unarmed;

      state Unarmed;
      state TissuePenetration;
      state PeritonealEntry;
      state InsufflationReady;
      state Insufflating;
      state Complete;
      state Fault;

      transition beginInsertion
        first Unarmed
        accept InsertionStarted
        then TissuePenetration;

      transition enterPeritonealSpace
        first TissuePenetration
        accept LossOfResistance
        then PeritonealEntry;

      transition confirmPlacement
        first PeritonealEntry
        accept LowOpeningPressureConfirmed
        then InsufflationReady;

      transition beginInsufflation
        first InsufflationReady
        accept ValveOpened
        then Insufflating;

      transition targetReached
        first Insufflating
        accept TargetPressureReached
        then Complete;

      transition unsafePressure
        first Insufflating
        accept ExcessPressureDetected
        then Fault;

      transition obstructionDetected
        first InsufflationReady
        accept NoFlowDetected
        then Fault;
    }

    action insertNeedle {
      in item abdominalWall : AbdominalWall;
      in attribute userForce : Force;
      out attribute cavityEntered : Boolean;

      cavityEntered := userForce >= cannula.tipPenetrationForce;
    }

    action establishPneumoperitoneum {
      in item carbonDioxide : CarbonDioxide;
      in attribute pressure : Pressure;
      in attribute flow : FlowRate;
      out item insufflatedCavity : PeritonealCavity;
      out attribute completed : Boolean;

      completed := pressure >= targetInsufflationPressure and flow >= 0.0 [L/min];
    }
  }

  part def PatientInterface {
    part abdominalWall : AbdominalWall;
    part cavity : PeritonealCavity;

    attribute initialCavityPressure : Pressure = 0.0 [kPa];
    attribute targetCavityPressure : Pressure = 12.0 [kPa];
    attribute safeMaximumPressure : Pressure = 15.0 [kPa];
    attribute requiredGasVolume : Volume = 3.0 [L];

    port accessSite : TissueInterfacePort;
    port gasEntry : GasOutletPort;
  }

  part def VeressAccessSystem {
    doc /* Primary function: provide controlled initial access through the abdominal wall and deliver carbon dioxide into the peritoneal cavity to create pneumoperitoneum for minimally invasive abdominal procedures. */

    part needle : VeressNeedleAssembly;
    part insufflator : InsufflationSource;
    part patientInterface : PatientInterface;
    part sterileBarrier : SterileBarrier;

    attribute systemReady : Boolean;
    attribute maximumAllowedPressure : Pressure = 15.0 [kPa];
    attribute nominalWorkingPressure : Pressure = 12.0 [kPa];
    attribute nominalInsertionForce : Force = 4.0 [N];

    connect insufflator.outlet to needle.gasInput;
    connect needle.distalOutput to patientInterface.gasEntry;
    connect needle.tissueInterface to patientInterface.accessSite;

    action performAccessAndInsufflation {
      in item abdominalWall : AbdominalWall;
      in item gas : CarbonDioxide;
      out item cavity : PeritonealCavity;
      out attribute success : Boolean;

      first needle.insertNeedle(abdominalWall, nominalInsertionForce);
      then needle.establishPneumoperitoneum(gas, nominalWorkingPressure, insufflator.nominalFlow);
      success := true;
    }
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The system shall create controlled initial peritoneal access and enable carbon dioxide insufflation to establish pneumoperitoneum. */
    subject system : VeressAccessSystem;

    require constraint {
      system.nominalWorkingPressure <= system.maximumAllowedPressure
    }
  }

  requirement def BluntStyletSafetyRequirement {
    doc /* The blunt stylet shall protrude beyond the sharp cannula tip after entry into a low-resistance cavity to reduce unintended tissue injury. */
    subject needle : VeressNeedleAssembly;

    require constraint {
      needle.stylet.protrusionBeyondTip >= 2.0 [mm] and
      needle.stylet.responseTime <= 0.10 [s]
    }
  }

  requirement def FlowControlRequirement {
    doc /* The valve and insufflation source shall permit gas delivery only within the defined safe pressure range. */
    subject system : VeressAccessSystem;

    require constraint {
      system.insufflator.setPressure == system.nominalWorkingPressure and
      system.insufflator.maxPressure <= system.maximumAllowedPressure
    }
  }

  requirement def SterilityRequirement {
    doc /* Patient-contacting components shall be sterile and intended for single use. */
    subject needle : VeressNeedleAssembly;

    require constraint {
      needle.sterile == true and needle.singleUse == true
    }
  }

  requirement def PlacementConfirmationRequirement {
    doc /* The system shall provide pressure and flow feedback suitable for confirming likely intraperitoneal placement before insufflation continues. */
    subject needle : VeressNeedleAssembly;

    require constraint {
      needle.monitor.occlusionThresholdPressure <= 15.0 [kPa] and
      needle.monitor.minimumConfirmationFlow >= 0.2 [L/min]
    }
  }

  requirement def DimensionalCompatibilityRequirement {
    doc /* The needle shall have dimensions compatible with common minimally invasive initial access technique. */
    subject needle : VeressNeedleAssembly;

    require constraint {
      needle.nominalOuterDiameter <= 2.2 [mm] and
      needle.overallLength >= 120 [mm]
    }
  }

  satisfy PrimaryFunctionRequirement by VeressAccessSystem;
  satisfy BluntStyletSafetyRequirement by VeressNeedleAssembly;
  satisfy FlowControlRequirement by VeressAccessSystem;
  satisfy SterilityRequirement by VeressNeedleAssembly;
  satisfy PlacementConfirmationRequirement by VeressNeedleAssembly;
  satisfy DimensionalCompatibilityRequirement by VeressNeedleAssembly;

}