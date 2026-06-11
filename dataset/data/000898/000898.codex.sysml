package HydristorSystemModel {

  import ScalarValues::*;
  import ISQ::*;

  value def Pressure {
    unit = "Pa";
  }

  value def FlowRate {
    unit = "m^3/s";
  }

  value def Temperature {
    unit = "K";
  }

  value def Viscosity {
    unit = "Pa*s";
  }

  value def Area {
    unit = "m^2";
  }

  value def Position {
    unit = "m";
  }

  value def Resistance {
    unit = "Pa*s/m^3";
  }

  value def Power {
    unit = "W";
  }

  item def HydraulicFluid {
    attribute pressure : Pressure;
    attribute temperature : Temperature;
    attribute dynamicViscosity : Viscosity;
    attribute volumetricFlow : FlowRate;
  }

  item def ControlSignal {
    attribute demandedRestriction : Real;
    attribute enable : Boolean;
  }

  port def HydraulicPort {
    inout fluid : HydraulicFluid;
  }

  port def ControlPort {
    in command : ControlSignal;
  }

  port def TelemetryPort {
    out upstreamPressure : Pressure;
    out downstreamPressure : Pressure;
    out flowRate : FlowRate;
    out valvePosition : Position;
    out hydraulicResistance : Resistance;
    out dissipatedPower : Power;
  }

  action def ComputeHydraulicResistance {
    in inletPressure : Pressure;
    in outletPressure : Pressure;
    in flow : FlowRate;
    out resistance : Resistance;

    requirement nonZeroFlow {
      subject flow;
      require constraint { flow > 0.000001 [m^3/s] }
    }
  }

  action def ModulateRestriction {
    in command : ControlSignal;
    in currentPosition : Position;
    out targetPosition : Position;
  }

  action def DissipateHydraulicEnergy {
    in pressureDrop : Pressure;
    in flow : FlowRate;
    out heatPower : Power;
  }

  state def HydristorOperatingState {
    state off;
    state initializing;
    state regulating;
    state bypass;
    state fault;

    entry; then off;

    transition off_to_initializing
      first off
      accept ControlSignal
      if command.enable
      then initializing;

    transition initializing_to_regulating
      first initializing
      if true
      then regulating;

    transition regulating_to_bypass
      first regulating
      accept ControlSignal
      if command.demandedRestriction <= 0.05
      then bypass;

    transition bypass_to_regulating
      first bypass
      accept ControlSignal
      if command.demandedRestriction > 0.05
      then regulating;

    transition regulating_to_fault
      first regulating
      if false
      then fault;

    transition bypass_to_fault
      first bypass
      if false
      then fault;

    transition fault_to_off
      first fault
      accept ControlSignal
      if not command.enable
      then off;
  }

  part def FluidReservoir {
    attribute supplyPressure : Pressure = 500000 [Pa];
    attribute returnPressure : Pressure = 100000 [Pa];
    attribute fluidTemperature : Temperature = 293.15 [K];

    port supply : HydraulicPort;
    port return : HydraulicPort;
  }

  part def HydraulicLoad {
    attribute nominalFlowDemand : FlowRate = 0.003 [m^3/s];
    attribute minimumOperatingPressure : Pressure = 250000 [Pa];

    port inlet : HydraulicPort;
    port outlet : HydraulicPort;
  }

  part def Hydristor {
    attribute minimumOrificeArea : Area = 0.000001 [m^2];
    attribute maximumOrificeArea : Area = 0.00008 [m^2];
    attribute spoolPosition : Position = 0.0 [m];
    attribute maximumSpoolTravel : Position = 0.012 [m];
    attribute upstreamPressure : Pressure;
    attribute downstreamPressure : Pressure;
    attribute pressureDrop : Pressure;
    attribute commandedRestriction : Real;
    attribute effectiveResistance : Resistance;
    attribute measuredFlow : FlowRate;
    attribute dissipatedPower : Power;

    port inlet : HydraulicPort;
    port outlet : HydraulicPort;
    port control : ControlPort;
    port telemetry : TelemetryPort;

    perform action regulateRestriction {
      action modulate : ModulateRestriction;
      action computeResistance : ComputeHydraulicResistance;
      action dissipate : DissipateHydraulicEnergy;

      bind control.command = modulate.command;
      bind spoolPosition = modulate.currentPosition;
      bind spoolPosition = modulate.targetPosition;

      bind upstreamPressure = computeResistance.inletPressure;
      bind downstreamPressure = computeResistance.outletPressure;
      bind measuredFlow = computeResistance.flow;
      bind effectiveResistance = computeResistance.resistance;

      bind pressureDrop = dissipate.pressureDrop;
      bind measuredFlow = dissipate.flow;
      bind dissipatedPower = dissipate.heatPower;
    }

    exhibit stateMachine : HydristorOperatingState;

    requirement primaryFunction {
      subject Hydristor;
      doc /* The hydristor shall provide a controllable hydraulic resistance between an upstream source and a downstream load, reducing or bypassing flow restriction according to a command signal while dissipating excess hydraulic energy as heat. */
    }

    requirement pressureDropRequirement {
      subject pressureDrop;
      require constraint { pressureDrop == upstreamPressure - downstreamPressure }
    }

    requirement resistanceRequirement {
      subject effectiveResistance;
      require constraint { effectiveResistance >= 0 [Pa*s/m^3] }
    }

    requirement travelLimitRequirement {
      subject spoolPosition;
      require constraint {
        spoolPosition >= 0 [m] and spoolPosition <= maximumSpoolTravel
      }
    }

    requirement flowContinuityRequirement {
      subject measuredFlow;
      require constraint {
        inlet.fluid.volumetricFlow == outlet.fluid.volumetricFlow
      }
    }
  }

  part def HydristorController {
    attribute enabled : Boolean = true;
    attribute targetRestriction : Real = 0.65;
    attribute maximumAllowedPressureDrop : Pressure = 350000 [Pa];

    port commandOut : ControlPort;
    port telemetryIn : TelemetryPort;

    perform action issueCommand {
      out command : ControlSignal;
    }

    requirement commandRangeRequirement {
      subject targetRestriction;
      require constraint { targetRestriction >= 0.0 and targetRestriction <= 1.0 }
    }
  }

  part def HeatSink {
    attribute thermalCapacity : Real;
    attribute fluidHeatRejection : Power;

    port hydraulicInterface : HydraulicPort;

    requirement thermalDissipationRequirement {
      subject fluidHeatRejection;
      require constraint { fluidHeatRejection >= 0 [W] }
    }
  }

  part def HydristorBasedHydraulicRegulationSystem {
    part reservoir : FluidReservoir;
    part hydristor : Hydristor;
    part load : HydraulicLoad;
    part controller : HydristorController;
    part heatSink : HeatSink;

    port supplyInterface : HydraulicPort;
    port returnInterface : HydraulicPort;
    port operatorCommand : ControlPort;
    port systemTelemetry : TelemetryPort;

    connection supplyToHydristor
      connect reservoir.supply to hydristor.inlet;

    connection hydristorToLoad
      connect hydristor.outlet to load.inlet;

    connection loadReturn
      connect load.outlet to reservoir.return;

    connection controllerToHydristor
      connect controller.commandOut to hydristor.control;

    connection hydristorTelemetry
      connect hydristor.telemetry to controller.telemetryIn;

    connection externalSupply
      connect supplyInterface to reservoir.supply;

    connection externalReturn
      connect returnInterface to reservoir.return;

    connection operatorToController
      connect operatorCommand to controller.commandOut;

    connection telemetryOut
      connect hydristor.telemetry to systemTelemetry;

    connection heatRejectionPath
      connect hydristor.outlet to heatSink.hydraulicInterface;

    requirement systemPrimaryFunction {
      subject HydristorBasedHydraulicRegulationSystem;
      doc /* The system shall use a hydristor to regulate hydraulic flow at a high level by converting an input command into a controlled restriction between a pressure source and a hydraulic load. */
    }

    requirement regulatedFlowRequirement {
      subject load.nominalFlowDemand;
      require constraint {
        load.nominalFlowDemand >= 0.001 [m^3/s] and
        load.nominalFlowDemand <= 0.006 [m^3/s]
      }
    }

    requirement sourcePressureRequirement {
      subject reservoir.supplyPressure;
      require constraint { reservoir.supplyPressure >= 400000 [Pa] }
    }

    requirement loadPressureRequirement {
      subject load.minimumOperatingPressure;
      require constraint {
        hydristor.downstreamPressure >= load.minimumOperatingPressure
      }
    }

    requirement safePressureDropRequirement {
      subject hydristor.pressureDrop;
      require constraint {
        hydristor.pressureDrop <= controller.maximumAllowedPressureDrop
      }
    }
  }

}