package GasLiftSystemModel {

  import ScalarValues::*;
  import SI::*;
  import ISQ::*;

  value def Pressure :> ISQ::pressure {
    unit = "Pa";
  }

  value def Temperature :> ISQ::thermodynamicTemperature {
    unit = "K";
  }

  value def MassFlowRate :> ISQ::massFlowRate {
    unit = "kg/s";
  }

  value def VolumeFlowRate :> ISQ::volumeFlowRate {
    unit = "m^3/s";
  }

  value def Length :> ISQ::length {
    unit = "m";
  }

  value def Fraction {
    unit = "1";
  }

  value def ValvePosition {
    unit = "%";
  }

  item def InjectionGas {
    attribute pressure : Pressure;
    attribute temperature : Temperature;
    attribute massFlow : MassFlowRate;
    attribute methaneFraction : Fraction;
  }

  item def ReservoirFluid {
    attribute pressure : Pressure;
    attribute temperature : Temperature;
    attribute liquidRate : VolumeFlowRate;
    attribute gasOilRatio : Fraction;
    attribute waterCut : Fraction;
  }

  item def ProducedMultiphaseFluid {
    attribute pressure : Pressure;
    attribute temperature : Temperature;
    attribute liquidRate : VolumeFlowRate;
    attribute gasRate : VolumeFlowRate;
    attribute waterCut : Fraction;
  }

  item def ControlSignal {
    attribute commandedValvePosition : ValvePosition;
    attribute targetInjectionRate : MassFlowRate;
  }

  item def SensorSignal {
    attribute measuredTubingPressure : Pressure;
    attribute measuredCasingPressure : Pressure;
    attribute measuredWellheadPressure : Pressure;
    attribute measuredInjectionFlow : MassFlowRate;
  }

  port def GasInletPort {
    in item gas : InjectionGas;
  }

  port def ReservoirInflowPort {
    in item fluid : ReservoirFluid;
  }

  port def ProductionOutletPort {
    out item fluid : ProducedMultiphaseFluid;
  }

  port def ControlInputPort {
    in item command : ControlSignal;
  }

  port def InstrumentOutputPort {
    out item telemetry : SensorSignal;
  }

  port def AnnulusGasPort {
    in item gas : InjectionGas;
  }

  port def TubingFluidPort {
    inout item fluid : ProducedMultiphaseFluid;
  }

  action def RegulateInjectionGas {
    in targetRate : MassFlowRate;
    in casingPressure : Pressure;
    out valvePosition : ValvePosition;

    first start;
    then computePosition;
    then issueCommand;
    then done;
  }

  action def InjectGasIntoTubing {
    in gas : InjectionGas;
    in fluid : ReservoirFluid;
    out liftedFluid : ProducedMultiphaseFluid;

    first receiveGasAndFluid;
    then reduceHydrostaticGradient;
    then aerateFluidColumn;
    then dischargeMultiphaseFlow;
  }

  action def MonitorWellPerformance {
    in tubingPressure : Pressure;
    in casingPressure : Pressure;
    in wellheadPressure : Pressure;
    in injectionFlow : MassFlowRate;
    out signal : SensorSignal;

    first sampleSensors;
    then validateMeasurements;
    then publishTelemetry;
  }

  state def GasLiftOperatingState {
    state shutIn;
    state startup;
    state unloading;
    state steadyLift;
    state optimization;
    state faulted;

    transition first shutIn;
    transition shutIn_to_startup
      first shutIn
      then startup
      accept ControlSignal;

    transition startup_to_unloading
      first startup
      then unloading;

    transition unloading_to_steadyLift
      first unloading
      then steadyLift;

    transition steadyLift_to_optimization
      first steadyLift
      then optimization;

    transition optimization_to_steadyLift
      first optimization
      then steadyLift;

    transition any_to_faulted
      first steadyLift
      then faulted;

    transition faulted_to_shutIn
      first faulted
      then shutIn;
  }

  part def CompressorPackage {
    attribute dischargePressure : Pressure;
    attribute dischargeTemperature : Temperature;
    attribute maximumGasFlow : MassFlowRate;

    port gasOut : GasInletPort;
  }

  part def SurfaceInjectionManifold {
    attribute headerPressure : Pressure;
    attribute distributedFlow : MassFlowRate;

    port gasIn : GasInletPort;
    port gasOut : GasInletPort;
    port controlIn : ControlInputPort;
  }

  part def InjectionControlValve {
    attribute position : ValvePosition;
    attribute flowCapacity : MassFlowRate;
    attribute upstreamPressure : Pressure;
    attribute downstreamPressure : Pressure;

    port gasIn : GasInletPort;
    port gasOut : GasInletPort;
    port controlIn : ControlInputPort;

    perform action regulate : RegulateInjectionGas;
  }

  part def ProductionCasing {
    attribute internalPressure : Pressure;
    attribute measuredDepth : Length;

    port annulusGasIn : AnnulusGasPort;
    port annulusGasOut : AnnulusGasPort;
  }

  part def ProductionTubing {
    attribute flowingPressure : Pressure;
    attribute flowingTemperature : Temperature;
    attribute verticalDepth : Length;

    port bottomInflow : ReservoirInflowPort;
    port liftGasEntry : AnnulusGasPort;
    port producedFluidOut : ProductionOutletPort;

    perform action lift : InjectGasIntoTubing;
  }

  part def GasLiftValve {
    attribute openingPressure : Pressure;
    attribute closingPressure : Pressure;
    attribute portSize : Length;
    attribute installedDepth : Length;
    attribute isOpen : Boolean;

    port annulusGasIn : AnnulusGasPort;
    port tubingFluidPort : TubingFluidPort;
  }

  part def DownholeCompletion {
    attribute reservoirPressure : Pressure;
    attribute productivityIndex : VolumeFlowRate;
    attribute perforationDepth : Length;

    port reservoirInflow : ReservoirInflowPort;
    port tubingOut : ReservoirInflowPort;
  }

  part def WellheadAssembly {
    attribute wellheadPressure : Pressure;
    attribute chokePosition : ValvePosition;

    port producedFluidIn : ProductionOutletPort;
    port producedFluidOut : ProductionOutletPort;
    port telemetryOut : InstrumentOutputPort;
  }

  part def Separator {
    attribute operatingPressure : Pressure;
    attribute liquidOutletRate : VolumeFlowRate;
    attribute gasOutletRate : VolumeFlowRate;

    port producedFluidIn : ProductionOutletPort;
  }

  part def SensorSuite {
    attribute tubingPressure : Pressure;
    attribute casingPressure : Pressure;
    attribute wellheadPressure : Pressure;
    attribute injectionFlow : MassFlowRate;

    port telemetryOut : InstrumentOutputPort;

    perform action monitor : MonitorWellPerformance;
  }

  part def GasLiftController {
    attribute targetProductionRate : VolumeFlowRate;
    attribute targetInjectionRate : MassFlowRate;
    attribute maximumAllowableCasingPressure : Pressure;
    attribute minimumWellheadPressure : Pressure;

    port telemetryIn : InstrumentOutputPort;
    port commandOut : ControlInputPort;
  }

  part def GasLiftedWellSystem {
    attribute primaryFunction : String = "Inject compressed gas into the well annulus and through downhole gas lift valves to reduce the hydrostatic pressure of the production fluid column, enabling reservoir fluids to flow to the surface at a controlled production rate.";

    port externalGasSupply : GasInletPort;
    port reservoirInterface : ReservoirInflowPort;
    port productionExport : ProductionOutletPort;
    port supervisoryCommand : ControlInputPort;
    port systemTelemetry : InstrumentOutputPort;

    part compressor : CompressorPackage {
      attribute dischargePressure = 12000000 [Pa];
      attribute maximumGasFlow = 2.5 [kg/s];
    }

    part manifold : SurfaceInjectionManifold {
      attribute headerPressure = 11500000 [Pa];
    }

    part injectionValve : InjectionControlValve {
      attribute position = 55 [%];
      attribute flowCapacity = 2.0 [kg/s];
    }

    part casing : ProductionCasing {
      attribute internalPressure = 9800000 [Pa];
      attribute measuredDepth = 2500 [m];
    }

    part tubing : ProductionTubing {
      attribute flowingPressure = 6200000 [Pa];
      attribute verticalDepth = 2400 [m];
    }

    part operatingValve : GasLiftValve {
      attribute openingPressure = 9000000 [Pa];
      attribute closingPressure = 7600000 [Pa];
      attribute portSize = 0.012 [m];
      attribute installedDepth = 1800 [m];
      attribute isOpen = true;
    }

    part completion : DownholeCompletion {
      attribute reservoirPressure = 14500000 [Pa];
      attribute perforationDepth = 2450 [m];
    }

    part wellhead : WellheadAssembly {
      attribute wellheadPressure = 3200000 [Pa];
      attribute chokePosition = 68 [%];
    }

    part separator : Separator {
      attribute operatingPressure = 1800000 [Pa];
    }

    part sensors : SensorSuite;
    part controller : GasLiftController {
      attribute targetProductionRate = 0.015 [m^3/s];
      attribute targetInjectionRate = 1.4 [kg/s];
      attribute maximumAllowableCasingPressure = 12500000 [Pa];
      attribute minimumWellheadPressure = 2500000 [Pa];
    }

    perform state machine operatingState : GasLiftOperatingState;

    connect externalGasSupply to compressor.gasOut;
    connect compressor.gasOut to manifold.gasIn;
    connect manifold.gasOut to injectionValve.gasIn;
    connect injectionValve.gasOut to casing.annulusGasIn;
    connect casing.annulusGasOut to operatingValve.annulusGasIn;
    connect operatingValve.tubingFluidPort to tubing.liftGasEntry;
    connect reservoirInterface to completion.reservoirInflow;
    connect completion.tubingOut to tubing.bottomInflow;
    connect tubing.producedFluidOut to wellhead.producedFluidIn;
    connect wellhead.producedFluidOut to separator.producedFluidIn;
    connect wellhead.producedFluidOut to productionExport;
    connect sensors.telemetryOut to controller.telemetryIn;
    connect sensors.telemetryOut to systemTelemetry;
    connect supervisoryCommand to controller.commandOut;
    connect controller.commandOut to manifold.controlIn;
    connect controller.commandOut to injectionValve.controlIn;
  }

  requirement def PrimaryFunctionRequirement {
    subject system : GasLiftedWellSystem;

    require constraint {
      system.primaryFunction ==
      "Inject compressed gas into the well annulus and through downhole gas lift valves to reduce the hydrostatic pressure of the production fluid column, enabling reservoir fluids to flow to the surface at a controlled production rate."
    }
  }

  requirement def InjectionPressureRequirement {
    subject system : GasLiftedWellSystem;

    require constraint {
      system.compressor.dischargePressure > system.casing.internalPressure
    }
  }

  requirement def CasingPressureLimitRequirement {
    subject system : GasLiftedWellSystem;

    require constraint {
      system.casing.internalPressure <= system.controller.maximumAllowableCasingPressure
    }
  }

  requirement def ControlledInjectionRequirement {
    subject system : GasLiftedWellSystem;

    require constraint {
      system.injectionValve.position >= 0 [%] and
      system.injectionValve.position <= 100 [%]
    }
  }

  requirement def LiftValveOpeningRequirement {
    subject system : GasLiftedWellSystem;

    require constraint {
      system.operatingValve.isOpen implies
      system.casing.internalPressure >= system.operatingValve.openingPressure
    }
  }

  requirement def SurfaceProductionRequirement {
    subject system : GasLiftedWellSystem;

    require constraint {
      system.wellhead.wellheadPressure >= system.controller.minimumWellheadPressure
    }
  }

  satisfy PrimaryFunctionRequirement by GasLiftedWellSystem;
  satisfy InjectionPressureRequirement by GasLiftedWellSystem;
  satisfy CasingPressureLimitRequirement by GasLiftedWellSystem;
  satisfy ControlledInjectionRequirement by GasLiftedWellSystem;
  satisfy LiftValveOpeningRequirement by GasLiftedWellSystem;
  satisfy SurfaceProductionRequirement by GasLiftedWellSystem;
}