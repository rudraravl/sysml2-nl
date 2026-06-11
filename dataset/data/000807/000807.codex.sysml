package TubexPrimaryFunctionModel {

  import ScalarValues::*;

  attribute def Pressure :> Real {
    doc /* Fluid pressure in kilopascals. */
  }

  attribute def VolumeFlowRate :> Real {
    doc /* Volumetric flow rate in liters per minute. */
  }

  attribute def Temperature :> Real {
    doc /* Fluid temperature in degrees Celsius. */
  }

  attribute def Volume :> Real {
    doc /* Fluid volume in liters. */
  }

  attribute def Percent :> Real {
    doc /* Percentage from 0 to 100. */
  }

  item def ProcessFluid {
    attribute temperature : Temperature;
    attribute pressure : Pressure;
    attribute contaminationLevel : Percent;
  }

  item def ControlCommand {
    attribute requestedFlowRate : VolumeFlowRate;
    attribute requestedVolume : Volume;
  }

  item def HealthReport {
    attribute filterLoading : Percent;
    attribute leakRisk : Percent;
    attribute deliveredVolume : Volume;
  }

  port def FluidInputPort {
    in item fluidIn : ProcessFluid;
  }

  port def FluidOutputPort {
    out item fluidOut : ProcessFluid;
  }

  port def CommandPort {
    in item command : ControlCommand;
  }

  port def StatusPort {
    out item status : HealthReport;
  }

  part def Tubex {
    doc /* Tubex is a sealed tubular processing module whose primary function is to receive process fluid, convey it through a protected tube path, condition it, monitor its state, and deliver it at a controlled flow rate. */

    port inlet : FluidInputPort;
    port outlet : FluidOutputPort;
    port commandIn : CommandPort;
    port statusOut : StatusPort;

    attribute internalVolume : Volume = 2.5;
    attribute maximumPressure : Pressure = 450.0;
    attribute nominalFlowRate : VolumeFlowRate = 18.0;
    attribute operatingTemperature : Temperature = 25.0;

    part tubeBody {
      attribute ratedPressure : Pressure = 500.0;
      attribute containedVolume : Volume = 2.5;
    }

    part inletValve {
      attribute commandedOpen : Boolean;
      attribute openingPercent : Percent;
    }

    part outletValve {
      attribute commandedOpen : Boolean;
      attribute openingPercent : Percent;
    }

    part filterStage {
      attribute removalEfficiency : Percent = 98.5;
      attribute loading : Percent;
    }

    part flowController {
      attribute setpoint : VolumeFlowRate;
      attribute measuredFlow : VolumeFlowRate;
    }

    part pressureSensor {
      attribute measuredPressure : Pressure;
    }

    part temperatureSensor {
      attribute measuredTemperature : Temperature;
    }

    part leakMonitor {
      attribute leakRisk : Percent;
    }

    connection inletToValve connect inlet to inletValve;
    connection valveToTube connect inletValve to tubeBody;
    connection tubeToFilter connect tubeBody to filterStage;
    connection filterToController connect filterStage to flowController;
    connection controllerToOutletValve connect flowController to outletValve;
    connection outletValveToOutlet connect outletValve to outlet;
  }

  action def ExecuteTubexTransfer {
    in item incomingFluid : ProcessFluid;
    in item transferCommand : ControlCommand;
    out item deliveredFluid : ProcessFluid;
    out item transferStatus : HealthReport;

    first startTransfer;
    then admitFluid;
    then conditionFluid;
    then regulateFlow;
    then dischargeFluid;
    then reportHealth;

    action startTransfer;
    action admitFluid;
    action conditionFluid;
    action regulateFlow;
    action dischargeFluid;
    action reportHealth;
  }

  state def TubexOperatingState {
    entry action initialize;

    state Idle;
    state Priming;
    state Transferring;
    state Monitoring;
    state Flushing;
    state Faulted;
    state Shutdown;

    transition idleToPriming first Idle then Priming
      accept ControlCommand;

    transition primingToTransfer first Priming then Transferring;

    transition transferToMonitoring first Transferring then Monitoring;

    transition monitoringToFlushing first Monitoring then Flushing;

    transition flushingToIdle first Flushing then Idle;

    transition anyToFault first Idle then Faulted;
    transition transferFault first Transferring then Faulted;

    transition faultToShutdown first Faulted then Shutdown;

    action initialize;
  }

  part def TubexBasedTransferSystem {
    doc /* High-level primary function: controlled transfer of process fluid from a source vessel to a destination vessel using a Tubex module that contains, filters, monitors, and regulates the fluid path. */

    port sourceFluidIn : FluidInputPort;
    port destinationFluidOut : FluidOutputPort;
    port operatorCommandIn : CommandPort;
    port systemStatusOut : StatusPort;

    part sourceReservoir {
      attribute availableVolume : Volume = 100.0;
      port outlet : FluidOutputPort;
    }

    part destinationReservoir {
      attribute receivedVolume : Volume;
      port inlet : FluidInputPort;
    }

    part tubex : Tubex;

    part controller {
      port commandOut : CommandPort;
      port statusIn : StatusPort;
    }

    connection sourceToTubex connect sourceReservoir.outlet to tubex.inlet;
    connection tubexToDestination connect tubex.outlet to destinationReservoir.inlet;
    connection operatorToTubex connect operatorCommandIn to tubex.commandIn;
    connection tubexStatusToSystem connect tubex.statusOut to systemStatusOut;
  }

  requirement def ControlledFluidTransferRequirement {
    doc /* The system shall transfer process fluid through the Tubex from the source reservoir to the destination reservoir at the commanded flow rate. */

    require constraint {
      tubex.nominalFlowRate <= tubex.maximumPressure;
    }
  }

  requirement def ContainmentRequirement {
    doc /* The Tubex shall maintain sealed containment during normal operation. */

    require constraint {
      tubex.leakMonitor.leakRisk <= 1.0;
    }
  }

  requirement def FiltrationRequirement {
    doc /* The Tubex shall reduce contamination while transferring fluid. */

    require constraint {
      tubex.filterStage.removalEfficiency >= 95.0;
    }
  }

  requirement def PressureProtectionRequirement {
    doc /* The Tubex shall prevent operation above its rated pressure. */

    require constraint {
      tubex.pressureSensor.measuredPressure <= tubex.maximumPressure;
    }
  }

  requirement def HealthReportingRequirement {
    doc /* The system shall report delivered volume, filter loading, and leak risk during operation. */

    require constraint {
      tubex.filterStage.loading <= 100.0;
    }
  }

}