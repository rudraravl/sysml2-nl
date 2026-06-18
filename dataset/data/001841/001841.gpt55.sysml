package PumpingSystemModel {

  import ScalarValues::*;
  import SI::*;

  attribute def VolumeFlowRate :> ISQ::volumeFlowRate {
    doc /* Volumetric fluid flow rate. */
    :>> unit = SI::cubicMetrePerSecond;
  }

  attribute def Pressure :> ISQ::pressure {
    doc /* Fluid pressure. */
    :>> unit = SI::pascal;
  }

  attribute def PressureRise :> Pressure {
    doc /* Increase in pressure across a pump. */
    :>> unit = SI::pascal;
  }

  attribute def Temperature :> ISQ::thermodynamicTemperature {
    doc /* Fluid or equipment temperature. */
    :>> unit = SI::kelvin;
  }

  attribute def RotationalSpeed :> ISQ::angularVelocity {
    doc /* Shaft rotational speed. */
    :>> unit = SI::revolutionPerMinute;
  }

  attribute def Power :> ISQ::power {
    doc /* Mechanical or electrical power. */
    :>> unit = SI::watt;
  }

  attribute def Efficiency :> ScalarValues::Real {
    doc /* Dimensionless efficiency value from 0.0 to 1.0. */
  }

  attribute def TimeDuration :> ISQ::time {
    doc /* Duration of an operation or delay. */
    :>> unit = SI::second;
  }

  attribute def FluidLevel :> ISQ::length {
    doc /* Height of fluid above a reference point. */
    :>> unit = SI::metre;
  }

  attribute def ElectricVoltage :> ISQ::electricPotential {
    doc /* Electrical potential difference. */
    :>> unit = SI::volt;
  }

  attribute def ElectricCurrent :> ISQ::electricCurrent {
    doc /* Electrical current. */
    :>> unit = SI::ampere;
  }

  enum def FluidKind {
    enum potableWater;
    enum rawWater;
    enum coolingWater;
    enum processWater;
  }

  enum def PumpCommandKind {
    enum start;
    enum stop;
    enum reset;
    enum emergencyStop;
  }

  enum def PumpHealthKind {
    enum healthy;
    enum degraded;
    enum faulted;
    enum maintenanceRequired;
  }

  item def LiquidFluid {
    doc /* Liquid medium transported by the pumping system. */
    attribute kind : FluidKind;
    attribute density : ISQ::density;
    attribute temperature : Temperature;
    attribute vaporPressure : Pressure;
  }

  item def ElectricalEnergy {
    doc /* Electrical energy supplied to the pumping system motor drive. */
    attribute voltage : ElectricVoltage;
    attribute current : ElectricCurrent;
    attribute frequency : ISQ::frequency;
  }

  item def ControlCommand {
    doc /* Operator or supervisory command to the pumping controller. */
    attribute command : PumpCommandKind;
    attribute requestedFlowRate : VolumeFlowRate;
    attribute requestedDischargePressure : Pressure;
  }

  item def StatusMessage {
    doc /* Operating status reported by the pumping system. */
    attribute running : Boolean;
    attribute available : Boolean;
    attribute faultActive : Boolean;
    attribute health : PumpHealthKind;
    attribute measuredFlowRate : VolumeFlowRate;
    attribute measuredDischargePressure : Pressure;
  }

  port def FluidPort {
    doc /* Bidirectional physical interface for liquid flow. */
    inout item fluid : LiquidFluid;
    attribute pressure : Pressure;
    attribute flowRate : VolumeFlowRate;
    attribute temperature : Temperature;
  }

  port def ElectricalPowerPort {
    doc /* Electrical power interface. */
    in item powerInput : ElectricalEnergy;
    attribute voltage : ElectricVoltage;
    attribute current : ElectricCurrent;
    attribute consumedPower : Power;
  }

  port def CommandPort {
    doc /* Input interface for commands. */
    in item command : ControlCommand;
  }

  port def StatusPort {
    doc /* Output interface for status and measurements. */
    out item status : StatusMessage;
  }

  port def SignalPort {
    doc /* Generic internal signal interface. */
    inout item signal : StatusMessage;
  }

  connection def FluidConnection {
    end upstream : FluidPort;
    end downstream : FluidPort;
  }

  connection def PowerConnection {
    end source : ElectricalPowerPort;
    end load : ElectricalPowerPort;
  }

  connection def CommandConnection {
    end source : CommandPort;
    end receiver : CommandPort;
  }

  connection def StatusConnection {
    end source : StatusPort;
    end receiver : StatusPort;
  }

  part def SuctionReservoir {
    doc /* Source vessel providing liquid to the pumping system. */
    port outlet : FluidPort;
    attribute storedLevel : FluidLevel;
    attribute minimumOperatingLevel : FluidLevel = 0.75 [SI::metre];
    attribute fluidTemperature : Temperature;
  }

  part def SuctionStrainer {
    doc /* Removes large debris before liquid reaches the pump. */
    port inlet : FluidPort;
    port outlet : FluidPort;
    attribute cleanPressureDrop : Pressure = 10000 [SI::pascal];
    attribute cloggedPressureDropLimit : Pressure = 70000 [SI::pascal];
    attribute debrisLoading : ScalarValues::Real;
  }

  part def IsolationValve {
    doc /* On/off valve used to isolate equipment for operation or maintenance. */
    port inlet : FluidPort;
    port outlet : FluidPort;
    attribute commandedOpen : Boolean;
    attribute actualOpen : Boolean;
    attribute pressureDropWhenOpen : Pressure = 5000 [SI::pascal];
  }

  part def CheckValve {
    doc /* Prevents reverse flow from the discharge line back into the pump. */
    port inlet : FluidPort;
    port outlet : FluidPort;
    attribute crackingPressure : Pressure = 8000 [SI::pascal];
    attribute reverseLeakageFlow : VolumeFlowRate;
  }

  part def CentrifugalPump {
    doc /* Rotodynamic pump that converts shaft power into liquid pressure and flow. */
    port suction : FluidPort;
    port discharge : FluidPort;

    attribute nominalFlowRate : VolumeFlowRate = 0.050 [SI::cubicMetrePerSecond];
    attribute minimumContinuousFlowRate : VolumeFlowRate = 0.015 [SI::cubicMetrePerSecond];
    attribute maximumFlowRate : VolumeFlowRate = 0.080 [SI::cubicMetrePerSecond];
    attribute nominalPressureRise : PressureRise = 350000 [SI::pascal];
    attribute shutoffPressureRise : PressureRise = 520000 [SI::pascal];
    attribute hydraulicEfficiency : Efficiency = 0.78;
    attribute shaftSpeed : RotationalSpeed = 1800 [SI::revolutionPerMinute];
    attribute netPositiveSuctionHeadRequired : ISQ::length = 3.0 [SI::metre];
    attribute casingTemperature : Temperature;

    constraint pressureIncrease {
      discharge.pressure >= suction.pressure + nominalPressureRise;
    }

    constraint operatingEnvelope {
      discharge.flowRate >= minimumContinuousFlowRate and
      discharge.flowRate <= maximumFlowRate;
    }
  }

  part def ElectricMotor {
    doc /* Electrical machine that drives the pump shaft. */
    port electricalInput : ElectricalPowerPort;
    attribute ratedPower : Power = 30000 [SI::watt];
    attribute ratedVoltage : ElectricVoltage = 480 [SI::volt];
    attribute ratedCurrent : ElectricCurrent = 42 [SI::ampere];
    attribute motorEfficiency : Efficiency = 0.92;
    attribute shaftSpeed : RotationalSpeed = 1800 [SI::revolutionPerMinute];
    attribute windingTemperature : Temperature;
  }

  part def VariableFrequencyDrive {
    doc /* Power converter that controls motor speed and soft-starts the pump. */
    port powerIn : ElectricalPowerPort;
    port powerOut : ElectricalPowerPort;
    port commandIn : CommandPort;
    port statusOut : StatusPort;

    attribute outputFrequency : ISQ::frequency;
    attribute outputVoltage : ElectricVoltage;
    attribute maximumOutputCurrent : ElectricCurrent = 60 [SI::ampere];
    attribute enabled : Boolean;
  }

  part def FlowTransmitter {
    doc /* Measures volumetric flow rate in the discharge line. */
    port processPort : FluidPort;
    port statusOut : StatusPort;
    attribute measuredFlowRate : VolumeFlowRate;
    attribute accuracy : ScalarValues::Real = 0.01;
  }

  part def PressureTransmitter {
    doc /* Measures line pressure. */
    port processPort : FluidPort;
    port statusOut : StatusPort;
    attribute measuredPressure : Pressure;
    attribute accuracy : ScalarValues::Real = 0.005;
  }

  part def LevelTransmitter {
    doc /* Measures suction reservoir level to protect the pump from dry running. */
    port statusOut : StatusPort;
    attribute measuredLevel : FluidLevel;
    attribute lowLowLevelSetpoint : FluidLevel = 0.50 [SI::metre];
  }

  part def PumpController {
    doc /* Supervisory controller that starts, stops, protects, and reports the pumping function. */
    port commandIn : CommandPort;
    port driveCommandOut : CommandPort;
    port statusIn : StatusPort;
    port statusOut : StatusPort;

    attribute requestedFlowRate : VolumeFlowRate = 0.050 [SI::cubicMetrePerSecond];
    attribute requestedDischargePressure : Pressure = 450000 [SI::pascal];
    attribute lowSuctionLevelTrip : FluidLevel = 0.50 [SI::metre];
    attribute highDischargePressureTrip : Pressure = 650000 [SI::pascal];
    attribute minimumStartDelay : TimeDuration = 5 [SI::second];
    attribute health : PumpHealthKind = PumpHealthKind::healthy;
  }

  part def DischargeHeader {
    doc /* Downstream header receiving pressurized liquid from the pumping system. */
    port inlet : FluidPort;
    attribute requiredMinimumPressure : Pressure = 400000 [SI::pascal];
    attribute demandedFlowRate : VolumeFlowRate = 0.050 [SI::cubicMetrePerSecond];
  }

  action def DrawLiquidFromSource {
    doc /* Draw liquid from the suction reservoir through the inlet piping. */
    in item sourceLiquid : LiquidFluid;
    out item suctionLiquid : LiquidFluid;
    attribute suctionPressure : Pressure;
    attribute suctionFlowRate : VolumeFlowRate;
  }

  action def RemoveDebris {
    doc /* Pass liquid through the suction strainer to protect the pump impeller. */
    in item unfilteredLiquid : LiquidFluid;
    out item filteredLiquid : LiquidFluid;
    attribute allowablePressureDrop : Pressure = 70000 [SI::pascal];
  }

  action def IncreaseLiquidPressure {
    doc /* Convert electrical energy into hydraulic energy by rotating the pump impeller. */
    in item lowPressureLiquid : LiquidFluid;
    in item electricalEnergy : ElectricalEnergy;
    out item highPressureLiquid : LiquidFluid;
    attribute achievedPressureRise : PressureRise;
    attribute achievedFlowRate : VolumeFlowRate;
  }

  action def PreventReverseFlow {
    doc /* Block reverse flow when the pump is stopped or discharge pressure exceeds pump pressure. */
    in item pressurizedLiquid : LiquidFluid;
    out item oneWayLiquid : LiquidFluid;
  }

  action def DeliverPressurizedLiquid {
    doc /* Deliver pressurized liquid to the discharge header at the required flow and pressure. */
    in item pumpedLiquid : LiquidFluid;
    out item deliveredLiquid : LiquidFluid;
    attribute deliveryPressure : Pressure;
    attribute deliveryFlowRate : VolumeFlowRate;
  }

  action def MonitorAndProtectPump {
    doc /* Monitor flow, pressure, level, and drive status to protect equipment and maintain service. */
    in item command : ControlCommand;
    in item status : StatusMessage;
    out item driveCommand : ControlCommand;
    out item systemStatus : StatusMessage;
  }

  action def PumpingPrimaryFunction {
    doc /* Primary high-level function: receive liquid at low pressure from a source, add hydraulic energy using a motor-driven pump, and deliver the liquid at controlled flow and higher pressure to a downstream header. */

    in item sourceLiquid : LiquidFluid;
    in item supplyPower : ElectricalEnergy;
    in item operatorCommand : ControlCommand;
    out item deliveredLiquid : LiquidFluid;
    out item operatingStatus : StatusMessage;

    action draw : DrawLiquidFromSource {
      in item sourceLiquid = sourceLiquid;
    }

    action strain : RemoveDebris {
      in item unfilteredLiquid = draw.suctionLiquid;
    }

    action pressurize : IncreaseLiquidPressure {
      in item lowPressureLiquid = strain.filteredLiquid;
      in item electricalEnergy = supplyPower;
    }

    action check : PreventReverseFlow {
      in item pressurizedLiquid = pressurize.highPressureLiquid;
    }

    action deliver : DeliverPressurizedLiquid {
      in item pumpedLiquid = check.oneWayLiquid;
    }

    action supervise : MonitorAndProtectPump {
      in item command = operatorCommand;
    }

    bind deliveredLiquid = deliver.deliveredLiquid;
    bind operatingStatus = supervise.systemStatus;
  }

  state def PumpingOperatingStates {
    doc /* Operating state behavior for a protected motor-driven pumping system. */

    entry action initialize {
      doc /* Initialize controller outputs and verify measurements. */
    }

    state Off {
      doc /* Pump is stopped, valves may be closed, and the system awaits a start command. */
    }

    state Standby {
      doc /* Pump is available, primed, and ready to start. */
    }

    state Priming {
      doc /* Suction path is opened and the pump casing is filled with liquid before rotation. */
      entry action openSuctionValve;
      do action verifySuctionLevel;
    }

    state Starting {
      doc /* Drive accelerates the motor and pump to commanded speed. */
      entry action enableDrive;
      do action rampMotorSpeed;
    }

    state Running {
      doc /* Pump delivers pressurized liquid to the discharge header. */

      state FlowControl {
        doc /* Controller modulates motor speed to maintain requested flow. */
        do action regulateFlow;
      }

      state PressureControl {
        doc /* Controller modulates motor speed to maintain requested discharge pressure. */
        do action regulateDischargePressure;
      }
    }

    state Stopping {
      doc /* Pump is decelerated and isolated in a controlled manner. */
      entry action commandDriveStop;
      do action closeDischargeValveAfterDeceleration;
    }

    state Faulted {
      doc /* Pumping operation is inhibited because a protective trip or equipment fault is active. */
      entry action tripDrive;
      do action reportFault;
    }

    transition initialTransition first Off;

    transition makeAvailable
      first Off
      accept ControlCommand
      if command == PumpCommandKind::reset
      then Standby;

    transition beginPriming
      first Standby
      accept ControlCommand
      if command == PumpCommandKind::start
      then Priming;

    transition suctionReady
      first Priming
      if verifySuctionLevel
      then Starting;

    transition atSpeed
      first Starting
      if rampMotorSpeed
      then Running;

    transition normalStop
      first Running
      accept ControlCommand
      if command == PumpCommandKind::stop
      then Stopping;

    transition stopped
      first Stopping
      then Standby;

    transition lowLevelTrip
      first Priming
      if verifySuctionLevel == false
      then Faulted;

    transition highPressureTrip
      first Running
      if regulateDischargePressure == false
      then Faulted;

    transition emergencyStopTrip
      first Off, Standby, Priming, Starting, Running, Stopping
      accept ControlCommand
      if command == PumpCommandKind::emergencyStop
      then Faulted;

    transition resetFault
      first Faulted
      accept ControlCommand
      if command == PumpCommandKind::reset
      then Standby;
  }

  part def PumpingSystem {
    doc /* A motor-driven pumping system whose primary function is to move liquid from a low-pressure source to a downstream header by increasing the liquid pressure and controlling flow. */

    port suctionInlet : FluidPort;
    port dischargeOutlet : FluidPort;
    port electricalSupply : ElectricalPowerPort;
    port commandInput : CommandPort;
    port statusOutput : StatusPort;

    attribute designFlowRate : VolumeFlowRate = 0.050 [SI::cubicMetrePerSecond];
    attribute turndownFlowRate : VolumeFlowRate = 0.020 [SI::cubicMetrePerSecond];
    attribute maximumDischargeFlowRate : VolumeFlowRate = 0.080 [SI::cubicMetrePerSecond];
    attribute designDischargePressure : Pressure = 450000 [SI::pascal];
    attribute maximumAllowableDischargePressure : Pressure = 650000 [SI::pascal];
    attribute minimumSuctionPressure : Pressure = 100000 [SI::pascal];
    attribute designPressureRise : PressureRise = 350000 [SI::pascal];
    attribute nominalElectricalPower : Power = 30000 [SI::watt];
    attribute overallEfficiency : Efficiency = 0.70;
    attribute primaryFunctionDescription : String = "Receive liquid from a low-pressure source, add hydraulic energy with a motor-driven centrifugal pump, and deliver controlled pressurized flow to a downstream header.";

    part suctionReservoir : SuctionReservoir;
    part inletValve : IsolationValve;
    part suctionStrainer : SuctionStrainer;
    part pump : CentrifugalPump;
    part motor : ElectricMotor;
    part drive : VariableFrequencyDrive;
    part checkValve : CheckValve;
    part outletValve : IsolationValve;
    part flowTransmitter : FlowTransmitter;
    part suctionPressureTransmitter : PressureTransmitter;
    part dischargePressureTransmitter : PressureTransmitter;
    part levelTransmitter : LevelTransmitter;
    part controller : PumpController;
    part dischargeHeader : DischargeHeader;

    connection sourceToSystem : FluidConnection connect suctionReservoir.outlet to suctionInlet;
    connection inletToValve : FluidConnection connect suctionInlet to inletValve.inlet;
    connection valveToStrainer : FluidConnection connect inletValve.outlet to suctionStrainer.inlet;
    connection strainerToPump : FluidConnection connect suctionStrainer.outlet to pump.suction;
    connection pumpToCheckValve : FluidConnection connect pump.discharge to checkValve.inlet;
    connection checkValveToOutletValve : FluidConnection connect checkValve.outlet to outletValve.inlet;
    connection outletValveToDischarge : FluidConnection connect outletValve.outlet to dischargeOutlet;
    connection dischargeToHeader : FluidConnection connect dischargeOutlet to dischargeHeader.inlet;

    connection supplyToDrive : PowerConnection connect electricalSupply to drive.powerIn;
    connection driveToMotor : PowerConnection connect drive.powerOut to motor.electricalInput;

    connection operatorToController : CommandConnection connect commandInput to controller.commandIn;
    connection controllerToDrive : CommandConnection connect controller.driveCommandOut to drive.commandIn;
    connection driveStatusToController : StatusConnection connect drive.statusOut to controller.statusIn;
    connection controllerToSystemStatus : StatusConnection connect controller.statusOut to statusOutput;

    connection flowMeasurement : FluidConnection connect dischargeOutlet to flowTransmitter.processPort;
    connection suctionPressureMeasurement : FluidConnection connect pump.suction to suctionPressureTransmitter.processPort;
    connection dischargePressureMeasurement : FluidConnection connect pump.discharge to dischargePressureTransmitter.processPort;

    perform action primaryFunction : PumpingPrimaryFunction;

    exhibit state operatingBehavior : PumpingOperatingStates;

    constraint designPressureCapability {
      pump.nominalPressureRise >= designPressureRise;
    }

    constraint requiredDischargeService {
      dischargeOutlet.pressure >= designDischargePressure and
      dischargeOutlet.flowRate >= designFlowRate;
    }

    constraint suctionProtection {
      suctionInlet.pressure >= minimumSuctionPressure;
    }

    constraint maximumPressureProtection {
      dischargeOutlet.pressure <= maximumAllowableDischargePressure;
    }

    constraint flowOperatingRange {
      dischargeOutlet.flowRate >= turndownFlowRate and
      dischargeOutlet.flowRate <= maximumDischargeFlowRate;
    }

    constraint powerSizing {
      motor.ratedPower >= nominalElectricalPower;
    }
  }

  requirement def PrimaryPumpingFunctionRequirement {
    doc /* The pumping system shall transport liquid from a low-pressure suction source to a downstream discharge header by increasing the liquid pressure and controlling the delivered flow. */
    subject pumpingSystem : PumpingSystem;

    require constraint {
      pumpingSystem.dischargeOutlet.pressure >= pumpingSystem.designDischargePressure and
      pumpingSystem.dischargeOutlet.flowRate >= pumpingSystem.designFlowRate;
    }
  }

  requirement def FlowCapacityRequirement {
    doc /* The pumping system shall provide the design volumetric flow rate at the discharge outlet during normal running operation. */
    subject pumpingSystem : PumpingSystem;

    require constraint {
      pumpingSystem.dischargeOutlet.flowRate >= 0.050 [SI::cubicMetrePerSecond];
    }
  }

  requirement def PressureBoostRequirement {
    doc /* The pump shall provide sufficient pressure rise to deliver liquid to the discharge header at the required pressure. */
    subject pumpingSystem : PumpingSystem;

    require constraint {
      pumpingSystem.pump.nominalPressureRise >= 350000 [SI::pascal];
    }
  }

  requirement def ReverseFlowPreventionRequirement {
    doc /* The pumping system shall prevent reverse flow from the discharge header toward the suction source when the pump is stopped or discharge pressure exceeds pump discharge pressure. */
    subject pumpingSystem : PumpingSystem;

    require constraint {
      pumpingSystem.checkValve.reverseLeakageFlow <= 0.0001 [SI::cubicMetrePerSecond];
    }
  }

  requirement def DryRunProtectionRequirement {
    doc /* The controller shall inhibit pump starting and shall trip a running pump when suction reservoir level is below the low-low level setpoint. */
    subject pumpingSystem : PumpingSystem;

    require constraint {
      pumpingSystem.levelTransmitter.measuredLevel >= pumpingSystem.levelTransmitter.lowLowLevelSetpoint;
    }
  }

  requirement def OverPressureProtectionRequirement {
    doc /* The controller shall stop the pump before discharge pressure exceeds the maximum allowable discharge pressure. */
    subject pumpingSystem : PumpingSystem;

    require constraint {
      pumpingSystem.dischargeOutlet.pressure <= pumpingSystem.maximumAllowableDischargePressure;
    }
  }

  requirement def ElectricalPowerRequirement {
    doc /* The pumping system shall operate from a 480 V electrical supply and use a variable frequency drive to control motor speed. */
    subject pumpingSystem : PumpingSystem;

    require constraint {
      pumpingSystem.drive.powerIn.voltage == 480 [SI::volt] and
      pumpingSystem.motor.ratedVoltage == 480 [SI::volt];
    }
  }

  requirement def StatusReportingRequirement {
    doc /* The pumping system shall report running state, availability, fault state, measured flow rate, and measured discharge pressure to the external status interface. */
    subject pumpingSystem : PumpingSystem;

    require constraint {
      pumpingSystem.statusOutput.status.available == true or
      pumpingSystem.statusOutput.status.faultActive == true;
    }
  }

  requirement def MaintainMinimumContinuousFlowRequirement {
    doc /* The pumping system shall avoid sustained operation below the pump minimum continuous flow rate while running. */
    subject pumpingSystem : PumpingSystem;

    require constraint {
      pumpingSystem.dischargeOutlet.flowRate >= pumpingSystem.pump.minimumContinuousFlowRate;
    }
  }

  requirement def HighLevelSystemRequirement {
    doc /* The system shall be a pumping system whose primary high-level function is controlled transfer of liquid by pressure boosting. */
    subject pumpingSystem : PumpingSystem;

    require constraint {
      pumpingSystem.primaryFunctionDescription == "Receive liquid from a low-pressure source, add hydraulic energy with a motor-driven centrifugal pump, and deliver controlled pressurized flow to a downstream header.";
    }
  }

  part pumpingSystemDesign : PumpingSystem {
    attribute designFlowRate = 0.050 [SI::cubicMetrePerSecond];
    attribute designDischargePressure = 450000 [SI::pascal];
    attribute designPressureRise = 350000 [SI::pascal];
    attribute nominalElectricalPower = 30000 [SI::watt];

    part suctionReservoir {
      attribute storedLevel = 2.50 [SI::metre];
      attribute minimumOperatingLevel = 0.75 [SI::metre];
      attribute fluidTemperature = 293.15 [SI::kelvin];
    }

    part inletValve {
      attribute commandedOpen = true;
      attribute actualOpen = true;
    }

    part outletValve {
      attribute commandedOpen = true;
      attribute actualOpen = true;
    }

    part pump {
      attribute nominalFlowRate = 0.050 [SI::cubicMetrePerSecond];
      attribute minimumContinuousFlowRate = 0.015 [SI::cubicMetrePerSecond];
      attribute maximumFlowRate = 0.080 [SI::cubicMetrePerSecond];
      attribute nominalPressureRise = 350000 [SI::pascal];
      attribute hydraulicEfficiency = 0.78;
      attribute shaftSpeed = 1800 [SI::revolutionPerMinute];
    }

    part motor {
      attribute ratedPower = 30000 [SI::watt];
      attribute ratedVoltage = 480 [SI::volt];
      attribute ratedCurrent = 42 [SI::ampere];
      attribute motorEfficiency = 0.92;
    }

    part controller {
      attribute requestedFlowRate = 0.050 [SI::cubicMetrePerSecond];
      attribute requestedDischargePressure = 450000 [SI::pascal];
      attribute highDischargePressureTrip = 650000 [SI::pascal];
      attribute health = PumpHealthKind::healthy;
    }

    satisfy PrimaryPumpingFunctionRequirement by pumpingSystemDesign;
    satisfy FlowCapacityRequirement by pumpingSystemDesign;
    satisfy PressureBoostRequirement by pumpingSystemDesign;
    satisfy ReverseFlowPreventionRequirement by pumpingSystemDesign;
    satisfy DryRunProtectionRequirement by pumpingSystemDesign;
    satisfy OverPressureProtectionRequirement by pumpingSystemDesign;
    satisfy ElectricalPowerRequirement by pumpingSystemDesign;
    satisfy StatusReportingRequirement by pumpingSystemDesign;
    satisfy MaintainMinimumContinuousFlowRequirement by pumpingSystemDesign;
    satisfy HighLevelSystemRequirement by pumpingSystemDesign;
  }

}
