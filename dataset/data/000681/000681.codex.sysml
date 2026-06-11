package MedicalGasSupplySystem {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Pressure :> ISQ::pressure {
    unit = SI::pascal;
  }

  attribute def FlowRate {
    unit = "L/min";
  }

  attribute def Volume {
    unit = SI::litre;
  }

  attribute def OxygenFraction {
    unit = "%";
  }

  attribute def TimeDuration :> ISQ::time {
    unit = SI::second;
  }

  attribute def Temperature :> ISQ::thermodynamicTemperature {
    unit = SI::kelvin;
  }

  attribute def AlarmPriority {
    enum values low, medium, high;
  }

  item def MedicalGas {
    attribute pressure : Pressure;
    attribute flowRate : FlowRate;
    attribute temperature : Temperature;
    attribute purity : OxygenFraction;
  }

  item def Oxygen :> MedicalGas {
    attribute purity : OxygenFraction = 99.5 [%];
  }

  item def MedicalAir :> MedicalGas {
    attribute oxygenContent : OxygenFraction = 21.0 [%];
  }

  item def AlarmSignal {
    attribute priority : AlarmPriority;
    attribute message : String;
    attribute active : Boolean;
  }

  item def ControlCommand {
    attribute commandName : String;
    attribute enabled : Boolean;
  }

  port def GasOutletPort {
    out item suppliedGas : MedicalGas;
  }

  port def GasInletPort {
    in item receivedGas : MedicalGas;
  }

  port def AlarmPort {
    out item alarm : AlarmSignal;
  }

  port def CommandPort {
    in item command : ControlCommand;
  }

  port def SensorDataPort {
    out attribute measuredPressure : Pressure;
    out attribute measuredFlowRate : FlowRate;
  }

  action def SupplyMedicalGas {
    in item requestedGas : MedicalGas;
    in attribute requestedFlowRate : FlowRate;
    in attribute requestedPressure : Pressure;
    out item deliveredGas : MedicalGas;

    action regulatePressure;
    action regulateFlow;
    action monitorPurity;
    action deliverGas;

    first regulatePressure then regulateFlow;
    then monitorPurity;
    then deliverGas;

    objective {
      deliveredGas.pressure >= 380000 [Pa] and
      deliveredGas.pressure <= 420000 [Pa] and
      deliveredGas.flowRate >= requestedFlowRate;
    }
  }

  action def IsolateFault {
    in attribute faultDetected : Boolean;
    out attribute isolated : Boolean;

    action closeSupplyValve;
    action switchToReserve;
    action raiseAlarm;

    first closeSupplyValve then switchToReserve;
    then raiseAlarm;
  }

  state def SupplyOperatingState {
    state startup;
    state primarySupply;
    state reserveSupply;
    state lowPressureAlarm;
    state shutdown;
    state faultIsolated;

    initial then startup;

    transition startup_to_primary
      first startup
      accept ControlCommand
      if command.commandName == "ENABLE_SUPPLY" and command.enabled
      then primarySupply;

    transition primary_to_reserve
      first primarySupply
      if sourcePressure < 900000 [Pa]
      then reserveSupply;

    transition primary_low_pressure_alarm
      first primarySupply
      if outletPressure < 350000 [Pa]
      then lowPressureAlarm;

    transition reserve_low_pressure_alarm
      first reserveSupply
      if outletPressure < 350000 [Pa]
      then lowPressureAlarm;

    transition alarm_to_fault_isolated
      first lowPressureAlarm
      if outletPressure < 300000 [Pa]
      then faultIsolated;

    transition any_to_shutdown
      first primarySupply
      accept ControlCommand
      if command.commandName == "DISABLE_SUPPLY"
      then shutdown;

    transition reserve_to_shutdown
      first reserveSupply
      accept ControlCommand
      if command.commandName == "DISABLE_SUPPLY"
      then shutdown;
  }

  part def GasCylinderBank {
    attribute cylinderCount : Integer = 12;
    attribute storagePressure : Pressure = 13700000 [Pa];
    attribute remainingVolume : Volume = 48000 [L];

    port outlet : GasOutletPort;
    port sensor : SensorDataPort;

    action releaseGas : SupplyMedicalGas;
  }

  part def BulkOxygenTank {
    attribute liquidVolume : Volume = 3000 [L];
    attribute vaporizerOutletPressure : Pressure = 1000000 [Pa];

    port outlet : GasOutletPort;
    port sensor : SensorDataPort;
  }

  part def CompressorAirPlant {
    attribute compressorOutletPressure : Pressure = 850000 [Pa];
    attribute dryerDewPoint : Temperature = 233 [K];

    port outlet : GasOutletPort;
    port sensor : SensorDataPort;
  }

  part def PressureRegulator {
    attribute setPressure : Pressure = 400000 [Pa];
    attribute tolerance : Pressure = 20000 [Pa];

    port inlet : GasInletPort;
    port outlet : GasOutletPort;
    port command : CommandPort;

    action regulate {
      in item highPressureGas : MedicalGas;
      out item regulatedGas : MedicalGas;
    }
  }

  part def FlowControlValve {
    attribute commandedOpening : Real;
    attribute maximumFlowRate : FlowRate = 1200 [L/min];

    port inlet : GasInletPort;
    port outlet : GasOutletPort;
    port command : CommandPort;
  }

  part def NonReturnValve {
    attribute crackingPressure : Pressure = 5000 [Pa];

    port inlet : GasInletPort;
    port outlet : GasOutletPort;
  }

  part def Manifold {
    attribute nominalHeaderPressure : Pressure = 400000 [Pa];

    port primaryInlet : GasInletPort;
    port reserveInlet : GasInletPort;
    port airInlet : GasInletPort;
    port outlet : GasOutletPort;
  }

  part def PressureSensor {
    attribute measuredPressure : Pressure;
    attribute accuracy : Pressure = 5000 [Pa];

    port sampleInlet : GasInletPort;
    port data : SensorDataPort;
  }

  part def FlowSensor {
    attribute measuredFlowRate : FlowRate;
    attribute accuracy : FlowRate = 2 [L/min];

    port sampleInlet : GasInletPort;
    port data : SensorDataPort;
  }

  part def AlarmPanel {
    attribute activeAlarmCount : Integer;
    attribute highestPriority : AlarmPriority;

    port alarmOut : AlarmPort;
    port commandIn : CommandPort;
  }

  part def DistributionPipeline {
    attribute internalVolume : Volume = 850 [L];
    attribute ratedPressure : Pressure = 1000000 [Pa];

    port inlet : GasInletPort;
    port wardOutlet : GasOutletPort;
    port operatingRoomOutlet : GasOutletPort;
    port intensiveCareOutlet : GasOutletPort;
  }

  part def TerminalOutlet {
    attribute outletPressure : Pressure = 400000 [Pa];
    attribute maximumPatientFlowRate : FlowRate = 60 [L/min];

    port inlet : GasInletPort;
    port patientConnection : GasOutletPort;
  }

  part def MedicalGasSupply {
    attribute primaryFunction : String =
      "Provide a continuous, regulated, monitored supply of medical oxygen and medical air from stored or generated sources to clinical terminal outlets at safe pressure, flow, and purity levels.";

    attribute nominalOutletPressure : Pressure = 400000 [Pa];
    attribute minimumOutletPressure : Pressure = 350000 [Pa];
    attribute maximumOutletPressure : Pressure = 450000 [Pa];
    attribute requiredContinuityTime : TimeDuration = 1800 [s];

    part bulkOxygenTank : BulkOxygenTank;
    part oxygenCylinderReserve : GasCylinderBank;
    part medicalAirPlant : CompressorAirPlant;

    part oxygenPrimaryRegulator : PressureRegulator;
    part oxygenReserveRegulator : PressureRegulator;
    part airRegulator : PressureRegulator;

    part oxygenPrimaryCheckValve : NonReturnValve;
    part oxygenReserveCheckValve : NonReturnValve;
    part airCheckValve : NonReturnValve;

    part oxygenFlowValve : FlowControlValve;
    part airFlowValve : FlowControlValve;

    part supplyManifold : Manifold;

    part headerPressureSensor : PressureSensor;
    part headerFlowSensor : FlowSensor;

    part alarmPanel : AlarmPanel;
    part hospitalPipeline : DistributionPipeline;

    part wardOutlet : TerminalOutlet;
    part operatingRoomOutlet : TerminalOutlet;
    part intensiveCareOutlet : TerminalOutlet;

    port controlCommand : CommandPort;
    port systemAlarm : AlarmPort;
    port wardGasSupply : GasOutletPort;
    port operatingRoomGasSupply : GasOutletPort;
    port intensiveCareGasSupply : GasOutletPort;

    connection bulk_to_primary_regulator
      connect bulkOxygenTank.outlet to oxygenPrimaryRegulator.inlet;

    connection reserve_to_reserve_regulator
      connect oxygenCylinderReserve.outlet to oxygenReserveRegulator.inlet;

    connection air_to_air_regulator
      connect medicalAirPlant.outlet to airRegulator.inlet;

    connection primary_regulator_to_check
      connect oxygenPrimaryRegulator.outlet to oxygenPrimaryCheckValve.inlet;

    connection reserve_regulator_to_check
      connect oxygenReserveRegulator.outlet to oxygenReserveCheckValve.inlet;

    connection air_regulator_to_check
      connect airRegulator.outlet to airCheckValve.inlet;

    connection primary_check_to_manifold
      connect oxygenPrimaryCheckValve.outlet to supplyManifold.primaryInlet;

    connection reserve_check_to_manifold
      connect oxygenReserveCheckValve.outlet to supplyManifold.reserveInlet;

    connection air_check_to_manifold
      connect airCheckValve.outlet to supplyManifold.airInlet;

    connection manifold_to_oxygen_flow
      connect supplyManifold.outlet to oxygenFlowValve.inlet;

    connection oxygen_flow_to_pipeline
      connect oxygenFlowValve.outlet to hospitalPipeline.inlet;

    connection pipeline_to_ward
      connect hospitalPipeline.wardOutlet to wardOutlet.inlet;

    connection pipeline_to_operating_room
      connect hospitalPipeline.operatingRoomOutlet to operatingRoomOutlet.inlet;

    connection pipeline_to_intensive_care
      connect hospitalPipeline.intensiveCareOutlet to intensiveCareOutlet.inlet;

    connection ward_terminal_to_system_port
      connect wardOutlet.patientConnection to wardGasSupply;

    connection operating_room_terminal_to_system_port
      connect operatingRoomOutlet.patientConnection to operatingRoomGasSupply;

    connection intensive_care_terminal_to_system_port
      connect intensiveCareOutlet.patientConnection to intensiveCareGasSupply;

    connection alarm_to_system
      connect alarmPanel.alarmOut to systemAlarm;

    action supplyGas : SupplyMedicalGas {
      in item requestedGas;
      in attribute requestedFlowRate;
      in attribute requestedPressure;
      out item deliveredGas;
    }

    action isolateFault : IsolateFault;

    state operatingState : SupplyOperatingState;

    constraint pressureSafety {
      hospitalPipeline.inlet.receivedGas.pressure >= minimumOutletPressure and
      hospitalPipeline.inlet.receivedGas.pressure <= maximumOutletPressure;
    }

    constraint oxygenPuritySafety {
      wardGasSupply.suppliedGas.purity >= 99.0 [%];
    }

    constraint continuitySafety {
      oxygenCylinderReserve.remainingVolume >= 12000 [L];
    }
  }

  requirement def ContinuousSupplyRequirement {
    subject system : MedicalGasSupply;

    require constraint {
      system.wardGasSupply.suppliedGas.pressure >= system.minimumOutletPressure and
      system.operatingRoomGasSupply.suppliedGas.pressure >= system.minimumOutletPressure and
      system.intensiveCareGasSupply.suppliedGas.pressure >= system.minimumOutletPressure;
    }

    doc /* The medical gas supply shall maintain regulated gas availability at all clinical terminal outlets during normal source operation. */
  }

  requirement def ReserveSupplyRequirement {
    subject system : MedicalGasSupply;

    require constraint {
      system.oxygenCylinderReserve.remainingVolume >= 12000 [L];
    }

    doc /* The medical gas supply shall include a reserve source capable of maintaining oxygen delivery after primary source pressure falls below the usable threshold. */
  }

  requirement def OutletPressureRequirement {
    subject system : MedicalGasSupply;

    require constraint {
      system.wardGasSupply.suppliedGas.pressure >= 350000 [Pa] and
      system.wardGasSupply.suppliedGas.pressure <= 450000 [Pa] and
      system.operatingRoomGasSupply.suppliedGas.pressure >= 350000 [Pa] and
      system.operatingRoomGasSupply.suppliedGas.pressure <= 450000 [Pa] and
      system.intensiveCareGasSupply.suppliedGas.pressure >= 350000 [Pa] and
      system.intensiveCareGasSupply.suppliedGas.pressure <= 450000 [Pa];
    }

    doc /* The medical gas supply shall regulate outlet pressure within the defined clinical delivery band. */
  }

  requirement def AlarmRequirement {
    subject system : MedicalGasSupply;

    require constraint {
      system.alarmPanel.activeAlarmCount > 0 implies system.systemAlarm.alarm.active == true;
    }

    doc /* The system shall issue an alarm when monitored pressure, flow, reserve capacity, or source status is outside allowed operating limits. */
  }

  requirement def NonReturnIsolationRequirement {
    subject system : MedicalGasSupply;

    require constraint {
      system.oxygenPrimaryCheckValve.crackingPressure > 0 [Pa] and
      system.oxygenReserveCheckValve.crackingPressure > 0 [Pa] and
      system.airCheckValve.crackingPressure > 0 [Pa];
    }

    doc /* The system shall prevent backflow between primary, reserve, and air supply branches. */
  }

  part medicalGasSupplySystem : MedicalGasSupply;

  requirement continuousSupply : ContinuousSupplyRequirement {
    subject system = medicalGasSupplySystem;
  }

  requirement reserveSupply : ReserveSupplyRequirement {
    subject system = medicalGasSupplySystem;
  }

  requirement outletPressure : OutletPressureRequirement {
    subject system = medicalGasSupplySystem;
  }

  requirement alarmBehavior : AlarmRequirement {
    subject system = medicalGasSupplySystem;
  }

  requirement sourceIsolation : NonReturnIsolationRequirement {
    subject system = medicalGasSupplySystem;
  }

}