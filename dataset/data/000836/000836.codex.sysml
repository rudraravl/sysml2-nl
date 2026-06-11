package YankauerSuctionTipSystemModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Pressure;
  attribute def FlowRate;
  attribute def Volume;
  attribute def Length;
  attribute def Diameter;
  attribute def Force;
  attribute def Time;
  attribute def Boolean;

  item def AirFluidMixture {
    attribute liquidVolumeFraction : Real;
    attribute entrainedAirFraction : Real;
    attribute particulateContent : Real;
    attribute contaminationLevel : Real;
  }

  item def SuctionVacuum {
    attribute negativePressure : Pressure;
    attribute stability : Real;
  }

  item def OperatorCommand {
    attribute suctionRequested : Boolean;
    attribute ventOccluded : Boolean;
  }

  item def PatientContactLoad {
    attribute contactForce : Force;
    attribute contactDuration : Time;
  }

  port def FluidInletPort {
    in item aspiratedMaterial : AirFluidMixture;
  }

  port def FluidOutletPort {
    out item aspiratedMaterial : AirFluidMixture;
  }

  port def VacuumPort {
    in item vacuumSupply : SuctionVacuum;
  }

  port def VentPort {
    in item operatorControl : OperatorCommand;
  }

  port def ContactPort {
    in item patientContact : PatientContactLoad;
  }

  value def SuctionPerformance {
    attribute minimumVacuumPressure : Pressure;
    attribute maximumVacuumPressure : Pressure;
    attribute nominalFlowRate : FlowRate;
    attribute occlusionRecoveryTime : Time;
  }

  part def YankauerSuctionTipSystem {
    attribute primaryFunction : String = "Remove blood, saliva, irrigation fluid, and debris from an oral or surgical field by transmitting regulated vacuum through a rigid suction tip while allowing clinician control of suction intensity.";
    attribute systemPerformance : SuctionPerformance;

    port patientInterface : FluidInletPort;
    port wallVacuumInterface : VacuumPort;
    port collectionCanisterInterface : FluidOutletPort;
    port clinicianVentInterface : VentPort;
    port tissueContactInterface : ContactPort;

    part yankauerTip : RigidYankauerTip;
    part suctionTubing : FlexibleSuctionTubing;
    part collectionCanister : CollectionCanister;
    part regulatedVacuumSource : RegulatedVacuumSource;
    part clinician : ClinicalOperator;
    part patientField : SurgicalField;

    connection vacuumPath1 connect regulatedVacuumSource.vacuumOutput to suctionTubing.vacuumInput;
    connection vacuumPath2 connect suctionTubing.tipConnection to yankauerTip.proximalVacuumPort;
    connection fluidPath1 connect patientField.fluidSource to yankauerTip.distalIntakePort;
    connection fluidPath2 connect yankauerTip.proximalOutletPort to suctionTubing.fluidInput;
    connection fluidPath3 connect suctionTubing.canisterConnection to collectionCanister.inletPort;
    connection controlPath connect clinician.commandOutput to yankauerTip.thumbVentPort;
    connection contactPath connect patientField.contactSurface to yankauerTip.patientContactPort;

    perform action AspirateField {
      in item sourceFluid : AirFluidMixture;
      in item appliedVacuum : SuctionVacuum;
      in item command : OperatorCommand;
      out item removedFluid : AirFluidMixture;

      action establishVacuum;
      action modulateWithVent;
      action drawFluidThroughTip;
      action transportFluidToCanister;
      action separateCollectedMatter;

      flow sourceFluid from patientField.fluidSource to yankauerTip.distalIntakePort;
      flow appliedVacuum from regulatedVacuumSource.vacuumOutput to yankauerTip.proximalVacuumPort;
      flow command from clinician.commandOutput to yankauerTip.thumbVentPort;
      flow removedFluid from yankauerTip.proximalOutletPort to collectionCanister.inletPort;
    }

    state def SuctionUseStateMachine {
      state Ready;
      state TipPositioned;
      state SuctionActive;
      state VentRelieved;
      state Occluded;
      state CollectionFull;
      state Shutdown;

      transition initial then Ready;
      transition Ready_to_TipPositioned first Ready then TipPositioned
        accept OperatorCommand
        if clinician.positionedTip == true;

      transition TipPositioned_to_SuctionActive first TipPositioned then SuctionActive
        accept OperatorCommand
        if clinician.command.suctionRequested == true and clinician.command.ventOccluded == true;

      transition SuctionActive_to_VentRelieved first SuctionActive then VentRelieved
        accept OperatorCommand
        if clinician.command.ventOccluded == false;

      transition VentRelieved_to_SuctionActive first VentRelieved then SuctionActive
        accept OperatorCommand
        if clinician.command.ventOccluded == true;

      transition SuctionActive_to_Occluded first SuctionActive then Occluded
        if yankauerTip.currentFlowRate < 0.05 [L/s];

      transition Occluded_to_SuctionActive first Occluded then SuctionActive
        if yankauerTip.occlusionCleared == true;

      transition SuctionActive_to_CollectionFull first SuctionActive then CollectionFull
        if collectionCanister.remainingCapacity <= 0.05 [L];

      transition CollectionFull_to_Shutdown first CollectionFull then Shutdown;
      transition SuctionActive_to_Shutdown first SuctionActive then Shutdown
        accept OperatorCommand
        if clinician.command.suctionRequested == false;
    }
  }

  part def RigidYankauerTip {
    attribute material : String = "medical-grade rigid polymer";
    attribute overallLength : Length = 250 [mm];
    attribute distalOuterDiameter : Diameter = 6 [mm];
    attribute lumenInnerDiameter : Diameter = 4 [mm];
    attribute tipOpeningArea : Area = 12.6 [mm^2];
    attribute sideEyeCount : Integer = 2;
    attribute isSterileAtUse : Boolean = true;
    attribute currentFlowRate : FlowRate;
    attribute occlusionCleared : Boolean;

    port distalIntakePort : FluidInletPort;
    port proximalVacuumPort : VacuumPort;
    port proximalOutletPort : FluidOutletPort;
    port thumbVentPort : VentPort;
    port patientContactPort : ContactPort;

    part distalBulbousTip : DistalGuardedTip;
    part internalLumen : SmoothInternalLumen;
    part thumbVent : VacuumReliefVent;
    part proximalConnector : TubingConnector;

    connection intakeToLumen connect distalBulbousTip.intakePort to internalLumen.inletPort;
    connection lumenToConnector connect internalLumen.outletPort to proximalConnector.tipSidePort;
    connection ventToLumen connect thumbVent.ventControlPort to internalLumen.ventInterface;
  }

  part def DistalGuardedTip {
    attribute roundedTipRadius : Length = 3 [mm];
    attribute primaryApertureDiameter : Diameter = 3.5 [mm];
    attribute sideApertureDiameter : Diameter = 2 [mm];
    attribute atraumaticEdgeFinish : Boolean = true;

    port intakePort : FluidInletPort;
    port tissueContactPort : ContactPort;
  }

  part def SmoothInternalLumen {
    attribute innerDiameter : Diameter = 4 [mm];
    attribute surfaceRoughness : Length = 0.8 [um];
    attribute clogResistanceIndex : Real = 0.82;

    port inletPort : FluidInletPort;
    port outletPort : FluidOutletPort;
    port ventInterface : VentPort;
  }

  part def VacuumReliefVent {
    attribute ventDiameter : Diameter = 2.5 [mm];
    attribute normallyOpenToAtmosphere : Boolean = true;
    attribute maximumOperatorClosureForce : Force = 3 [N];

    port ventControlPort : VentPort;
  }

  part def TubingConnector {
    attribute barbOuterDiameter : Diameter = 6.4 [mm];
    attribute leakTightUnderVacuum : Boolean = true;

    port tipSidePort : FluidInletPort;
    port tubingSidePort : FluidOutletPort;
  }

  part def FlexibleSuctionTubing {
    attribute length : Length = 1800 [mm];
    attribute innerDiameter : Diameter = 6 [mm];
    attribute kinkResistanceRadius : Length = 35 [mm];
    attribute maximumAllowableVacuum : Pressure = -80 [kPa];

    port vacuumInput : VacuumPort;
    port tipConnection : VacuumPort;
    port fluidInput : FluidInletPort;
    port canisterConnection : FluidOutletPort;
  }

  part def CollectionCanister {
    attribute nominalCapacity : Volume = 2 [L];
    attribute remainingCapacity : Volume = 2 [L];
    attribute overflowProtectionPresent : Boolean = true;
    attribute biohazardContainmentIntegrity : Boolean = true;

    port inletPort : FluidInletPort;
    port vacuumOutletPort : VacuumPort;
  }

  part def RegulatedVacuumSource {
    attribute setPressure : Pressure = -40 [kPa];
    attribute pressureRangeLow : Pressure = -20 [kPa];
    attribute pressureRangeHigh : Pressure = -80 [kPa];
    attribute nominalFreeAirFlow : FlowRate = 30 [L/min];

    port vacuumOutput : VacuumPort;

    action regulateVacuum {
      in attribute requestedPressure : Pressure;
      out item deliveredVacuum : SuctionVacuum;
    }
  }

  part def ClinicalOperator {
    attribute positionedTip : Boolean;
    attribute command : OperatorCommand;

    port commandOutput : VentPort;

    action positionTip {
      out attribute positionedTip : Boolean;
    }

    action occludeVent {
      out item command : OperatorCommand;
    }

    action releaseVent {
      out item command : OperatorCommand;
    }
  }

  part def SurgicalField {
    attribute estimatedFluidLoad : Volume = 0.25 [L];
    attribute targetVisibilityRequired : Boolean = true;

    port fluidSource : FluidInletPort;
    port contactSurface : ContactPort;
  }

  requirement def PrimaryFunctionRequirement {
    subject system : YankauerSuctionTipSystem;

    require constraint {
      system.primaryFunction == "Remove blood, saliva, irrigation fluid, and debris from an oral or surgical field by transmitting regulated vacuum through a rigid suction tip while allowing clinician control of suction intensity."
    }
  }

  requirement def SuctionPerformanceRequirement {
    subject system : YankauerSuctionTipSystem;

    require constraint {
      system.regulatedVacuumSource.setPressure <= -20 [kPa] and
      system.regulatedVacuumSource.setPressure >= -80 [kPa] and
      system.yankauerTip.currentFlowRate >= 5 [L/min]
    }
  }

  requirement def AtraumaticContactRequirement {
    subject tip : RigidYankauerTip;

    require constraint {
      tip.distalBulbousTip.atraumaticEdgeFinish == true and
      tip.distalBulbousTip.roundedTipRadius >= 2 [mm]
    }
  }

  requirement def ClinicianControlRequirement {
    subject tip : RigidYankauerTip;

    require constraint {
      tip.thumbVent.normallyOpenToAtmosphere == true and
      tip.thumbVent.maximumOperatorClosureForce <= 3 [N]
    }
  }

  requirement def ContainmentRequirement {
    subject canister : CollectionCanister;

    require constraint {
      canister.overflowProtectionPresent == true and
      canister.biohazardContainmentIntegrity == true
    }
  }

  requirement def TubingCompatibilityRequirement {
    subject system : YankauerSuctionTipSystem;

    require constraint {
      system.yankauerTip.proximalConnector.barbOuterDiameter >= 6 [mm] and
      system.yankauerTip.proximalConnector.barbOuterDiameter <= 7 [mm] and
      system.suctionTubing.innerDiameter >= 5 [mm]
    }
  }

  satisfy PrimaryFunctionRequirement by YankauerSuctionTipSystem;
  satisfy SuctionPerformanceRequirement by YankauerSuctionTipSystem;
  satisfy AtraumaticContactRequirement by RigidYankauerTip;
  satisfy ClinicianControlRequirement by RigidYankauerTip;
  satisfy ContainmentRequirement by CollectionCanister;
  satisfy TubingCompatibilityRequirement by YankauerSuctionTipSystem;
}