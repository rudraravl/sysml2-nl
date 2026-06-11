package PenileImplantSystemModel {

  import ScalarValues::*;
  import ISQ::*;

  attribute def Pressure {
    :> ISQ::pressure;
    unit = SI::pascal;
  }

  attribute def Volume {
    :> ISQ::volume;
    unit = SI::cubicMetre;
  }

  attribute def Force {
    :> ISQ::force;
    unit = SI::newton;
  }

  attribute def Time {
    :> ISQ::time;
    unit = SI::second;
  }

  attribute def Temperature {
    :> ISQ::thermodynamicTemperature;
    unit = SI::kelvin;
  }

  attribute def Length {
    :> ISQ::length;
    unit = SI::metre;
  }

  item def SterileSaline {
    attribute volume : Volume;
    attribute pressure : Pressure;
    attribute temperature : Temperature;
  }

  item def ManualCompression {
    attribute appliedForce : Force;
    attribute duration : Time;
  }

  item def ImplantStatus {
    attribute reservoirPressure : Pressure;
    attribute cylinderPressure : Pressure;
    attribute fluidTransferred : Volume;
    attribute isInflated : Boolean;
    attribute isLocked : Boolean;
  }

  port def FluidPort {
    inout fluid : SterileSaline;
  }

  port def ManualControlPort {
    in command : ManualCompression;
  }

  port def StatusPort {
    out status : ImplantStatus;
  }

  part def PenileImplantSystem {
    attribute maximumCylinderPressure : Pressure = 1200000 [SI::pascal];
    attribute nominalCylinderPressure : Pressure = 850000 [SI::pascal];
    attribute reservoirCapacity : Volume = 0.00008 [SI::cubicMetre];
    attribute expectedServiceLife : Time = 315360000 [SI::second];

    port userControl : ManualControlPort;
    port systemStatus : StatusPort;

    part reservoir : FluidReservoir {
      attribute capacity = 0.00008 [SI::cubicMetre];
      attribute storedVolume = 0.000075 [SI::cubicMetre];
    }

    part pump : ManualPump {
      attribute transferVolumePerCycle = 0.0000015 [SI::cubicMetre];
      attribute minimumActuationForce = 8 [SI::newton];
    }

    part valveAssembly : ValveAssembly {
      attribute crackingPressure = 25000 [SI::pascal];
    }

    part leftCylinder : InflatableCylinder {
      attribute expandedLength = 0.17 [SI::metre];
      attribute restingLength = 0.11 [SI::metre];
      attribute maximumPressure = 1200000 [SI::pascal];
    }

    part rightCylinder : InflatableCylinder {
      attribute expandedLength = 0.17 [SI::metre];
      attribute restingLength = 0.11 [SI::metre];
      attribute maximumPressure = 1200000 [SI::pascal];
    }

    part tubingSet : BiocompatibleTubing {
      attribute internalVolume = 0.000004 [SI::cubicMetre];
      attribute ratedPressure = 1500000 [SI::pascal];
    }

    connect reservoir.outlet to tubingSet.reservoirSide;
    connect tubingSet.pumpSide to pump.inlet;
    connect pump.outlet to valveAssembly.pumpSide;
    connect valveAssembly.leftCylinderSide to leftCylinder.fluidPort;
    connect valveAssembly.rightCylinderSide to rightCylinder.fluidPort;
    connect userControl to pump.manualInput;
    connect valveAssembly.statusOut to systemStatus;

    exhibit state implantOperatingState : ImplantOperatingStateMachine;

    perform action provideRigidity : ProvideControlledRigidity {
      in system = this;
      out status = systemStatus.status;
    }
  }

  part def FluidReservoir {
    attribute capacity : Volume;
    attribute storedVolume : Volume;
    attribute internalPressure : Pressure = 90000 [SI::pascal];

    port outlet : FluidPort;
  }

  part def ManualPump {
    attribute transferVolumePerCycle : Volume;
    attribute minimumActuationForce : Force;

    port inlet : FluidPort;
    port outlet : FluidPort;
    port manualInput : ManualControlPort;

    perform action transferFluid : TransferFluidAction;
  }

  part def ValveAssembly {
    attribute crackingPressure : Pressure;
    attribute locked : Boolean = true;

    port pumpSide : FluidPort;
    port leftCylinderSide : FluidPort;
    port rightCylinderSide : FluidPort;
    port statusOut : StatusPort;

    perform action routeFluidToCylinders : RouteInflationFluidAction;
    perform action routeFluidToReservoir : RouteDeflationFluidAction;
  }

  part def InflatableCylinder {
    attribute restingLength : Length;
    attribute expandedLength : Length;
    attribute currentPressure : Pressure = 90000 [SI::pascal];
    attribute maximumPressure : Pressure;
    attribute containedVolume : Volume = 0.00001 [SI::cubicMetre];

    port fluidPort : FluidPort;
  }

  part def BiocompatibleTubing {
    attribute internalVolume : Volume;
    attribute ratedPressure : Pressure;

    port reservoirSide : FluidPort;
    port pumpSide : FluidPort;
  }

  action def TransferFluidAction {
    in command : ManualCompression;
    in reservoirFluid : SterileSaline;
    out pressurizedFluid : SterileSaline;

    constraint forceAdequate {
      command.appliedForce >= 8 [SI::newton]
    }

    constraint transferLimited {
      pressurizedFluid.volume <= 0.0000015 [SI::cubicMetre]
    }
  }

  action def RouteInflationFluidAction {
    in pressurizedFluid : SterileSaline;
    out leftCylinderFluid : SterileSaline;
    out rightCylinderFluid : SterileSaline;

    constraint balancedDistribution {
      leftCylinderFluid.volume == rightCylinderFluid.volume
    }

    constraint inflationPressureLimit {
      leftCylinderFluid.pressure <= 1200000 [SI::pascal] and
      rightCylinderFluid.pressure <= 1200000 [SI::pascal]
    }
  }

  action def RouteDeflationFluidAction {
    in leftCylinderFluid : SterileSaline;
    in rightCylinderFluid : SterileSaline;
    out reservoirFluid : SterileSaline;

    constraint returnedVolume {
      reservoirFluid.volume == leftCylinderFluid.volume + rightCylinderFluid.volume
    }
  }

  action def ProvideControlledRigidity {
    in system : PenileImplantSystem;
    out status : ImplantStatus;

    first start;
    then acceptManualInput;
    then moveFluid;
    then stabilize;
    then reportStatus;

    action start;
    action acceptManualInput {
      in compression : ManualCompression;
    }

    action moveFluid {
      perform system.pump.transferFluid;
      perform system.valveAssembly.routeFluidToCylinders;
    }

    action stabilize {
      constraint cylinderPressureNominal {
        system.leftCylinder.currentPressure <= system.maximumCylinderPressure and
        system.rightCylinder.currentPressure <= system.maximumCylinderPressure
      }
    }

    action reportStatus {
      out status : ImplantStatus;
    }
  }

  state def ImplantOperatingStateMachine {
    attribute cylinderPressure : Pressure;
    attribute reservoirPressure : Pressure;
    attribute inflated : Boolean;

    entry action initialize {
      inflated = false;
    }

    state Deflated {
      entry action setRestingMode {
        inflated = false;
      }
    }

    state Filling {
      entry action openInflationPath;
      do action pumpFluid;
    }

    state Inflated {
      entry action lockValve {
        inflated = true;
      }
      do action maintainRigidity;
    }

    state Deflating {
      entry action openReturnPath;
      do action returnFluidToReservoir;
    }

    state Fault {
      entry action isolateFluidPath;
    }

    transition first Deflated;

    transition inflate from Deflated to Filling
      accept ManualCompression
      if cylinderPressure < 850000 [SI::pascal];

    transition inflationComplete from Filling to Inflated
      if cylinderPressure >= 850000 [SI::pascal] and cylinderPressure <= 1200000 [SI::pascal];

    transition deflate from Inflated to Deflating
      accept ManualCompression;

    transition deflationComplete from Deflating to Deflated
      if cylinderPressure <= 120000 [SI::pascal];

    transition overPressure from Filling to Fault
      if cylinderPressure > 1200000 [SI::pascal];

    transition pressureLoss from Inflated to Fault
      if cylinderPressure < 500000 [SI::pascal];
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The penile implant system shall provide controllable penile rigidity by transferring sterile fluid from an implanted reservoir into paired inflatable cylinders through a manually actuated pump and valve assembly. */
  }

  requirement def BiocompatibilityRequirement {
    doc /* Implanted components shall be made from biocompatible materials suitable for long-term internal medical use. */
  }

  requirement def PressureLimitRequirement {
    attribute maxAllowedPressure : Pressure = 1200000 [SI::pascal];
    doc /* The implant shall prevent cylinder pressure from exceeding the maximum allowed pressure during inflation and retention. */
  }

  requirement def FluidContainmentRequirement {
    doc /* The system shall maintain a closed sterile fluid circuit across reservoir, pump, tubing, valve assembly, and cylinders. */
  }

  requirement def ManualOperationRequirement {
    attribute minimumActuationForce : Force = 8 [SI::newton];
    doc /* The system shall be manually operable without external electrical power. */
  }

  requirement def DeflationRequirement {
    attribute targetRestingPressure : Pressure = 120000 [SI::pascal];
    doc /* The system shall allow controlled return of fluid from the cylinders to the reservoir to restore the resting state. */
  }

  requirement def SymmetryRequirement {
    doc /* The system shall distribute inflation fluid to the paired cylinders in a balanced manner to support symmetric mechanical expansion. */
  }

  satisfy PrimaryFunctionRequirement by PenileImplantSystem::provideRigidity;
  satisfy BiocompatibilityRequirement by PenileImplantSystem;
  satisfy PressureLimitRequirement by PenileImplantSystem::valveAssembly;
  satisfy FluidContainmentRequirement by PenileImplantSystem::reservoir;
  satisfy FluidContainmentRequirement by PenileImplantSystem::pump;
  satisfy FluidContainmentRequirement by PenileImplantSystem::tubingSet;
  satisfy FluidContainmentRequirement by PenileImplantSystem::leftCylinder;
  satisfy FluidContainmentRequirement by PenileImplantSystem::rightCylinder;
  satisfy ManualOperationRequirement by PenileImplantSystem::pump;
  satisfy DeflationRequirement by PenileImplantSystem::valveAssembly;
  satisfy SymmetryRequirement by PenileImplantSystem::valveAssembly;

}