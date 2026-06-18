package VacuumFluidPumpingSubsystem {

  import ScalarValues::*;
  import SI::*;
  import ISQ::*;

  attribute def Pressure_kPa :> Real {
    doc /* Unit: kilopascal absolute, kPa. */
  }

  attribute def VolumeFlowRate_L_per_min :> Real {
    doc /* Unit: liter per minute, L/min. */
  }

  attribute def Temperature_degC :> Real {
    doc /* Unit: degree Celsius, degC. */
  }

  attribute def Density_kg_per_m3 :> Real {
    doc /* Unit: kilogram per cubic meter, kg/m^3. */
  }

  attribute def DynamicViscosity_mPa_s :> Real {
    doc /* Unit: millipascal-second, mPa*s. */
  }

  attribute def Voltage_V :> Real {
    doc /* Unit: volt, V. */
  }

  attribute def Current_A :> Real {
    doc /* Unit: ampere, A. */
  }

  attribute def Power_W :> Real {
    doc /* Unit: watt, W. */
  }

  attribute def RotationalSpeed_rpm :> Real {
    doc /* Unit: revolution per minute, rpm. */
  }

  attribute def Time_s :> Real {
    doc /* Unit: second, s. */
  }

  attribute def ParticleSize_um :> Real {
    doc /* Unit: micrometer, um. */
  }

  attribute def Efficiency_percent :> Real {
    doc /* Unit: percent, %. */
  }

  item def WorkingFluid {
    attribute description : String = "non-corrosive process liquid or vapor-laden fluid";
    attribute density : Density_kg_per_m3 = 998.0;
    attribute dynamicViscosity : DynamicViscosity_mPa_s = 1.0;
    attribute temperature : Temperature_degC = 20.0;
    attribute vaporPressure : Pressure_kPa = 2.34;
    attribute containsEntrainedGas : Boolean = true;
  }

  item def ElectricalPower {
    attribute voltage : Voltage_V;
    attribute current : Current_A;
    attribute power : Power_W;
  }

  item def ControlCommand {
    attribute enablePump : Boolean;
    attribute openInletValve : Boolean;
    attribute resetFault : Boolean;
    attribute requestedSpeed : RotationalSpeed_rpm;
    attribute targetSuctionPressure : Pressure_kPa;
  }

  item def PumpStatus {
    attribute running : Boolean;
    attribute faulted : Boolean;
    attribute measuredSpeed : RotationalSpeed_rpm;
    attribute suctionPressure : Pressure_kPa;
    attribute dischargePressure : Pressure_kPa;
    attribute flowRate : VolumeFlowRate_L_per_min;
  }

  item def SensorSample {
    attribute pressure : Pressure_kPa;
    attribute flowRate : VolumeFlowRate_L_per_min;
    attribute temperature : Temperature_degC;
    attribute valid : Boolean;
  }

  port def FluidPort {
    inout item fluid : WorkingFluid;
    attribute pressure : Pressure_kPa;
    attribute temperature : Temperature_degC;
    attribute flowRate : VolumeFlowRate_L_per_min;
  }

  port def ElectricalPowerPort {
    in item suppliedPower : ElectricalPower;
    attribute nominalVoltage : Voltage_V = 24.0;
    attribute maximumCurrent : Current_A = 15.0;
  }

  port def CommandInputPort {
    in item command : ControlCommand;
  }

  port def CommandOutputPort {
    out item command : ControlCommand;
  }

  port def StatusInputPort {
    in item status : PumpStatus;
  }

  port def StatusOutputPort {
    out item status : PumpStatus;
  }

  port def SensorInputPort {
    in item sample : SensorSample;
  }

  port def SensorOutputPort {
    out item sample : SensorSample;
  }

  constraint def FlowCapacityConstraint {
    in actualFlow : VolumeFlowRate_L_per_min;
    in requiredFlow : VolumeFlowRate_L_per_min;
    constraint { actualFlow >= requiredFlow }
  }

  constraint def VacuumPressureConstraint {
    in actualSuctionPressure : Pressure_kPa;
    in maximumAllowedSuctionPressure : Pressure_kPa;
    constraint { actualSuctionPressure <= maximumAllowedSuctionPressure }
  }

  constraint def DischargePressureConstraint {
    in actualDischargePressure : Pressure_kPa;
    in maximumDischargePressure : Pressure_kPa;
    constraint { actualDischargePressure <= maximumDischargePressure }
  }

  constraint def ElectricalPowerConstraint {
    in consumedPower : Power_W;
    in maximumPower : Power_W;
    constraint { consumedPower <= maximumPower }
  }

  constraint def FilterParticleConstraint {
    in capturedParticleSize : ParticleSize_um;
    in requiredParticleSize : ParticleSize_um;
    constraint { capturedParticleSize <= requiredParticleSize }
  }

  action def OpenValve {
    inout valveOpen : Boolean;
    out completed : Boolean;
    action setOpen;
    then action confirmOpen;
  }

  action def CloseValve {
    inout valveOpen : Boolean;
    out completed : Boolean;
    action setClosed;
    then action confirmClosed;
  }

  action def StartVacuumPump {
    in command : ControlCommand;
    in availablePower : ElectricalPower;
    out status : PumpStatus;
    action energizeMotor;
    then action accelerateRotor;
    then action verifySuctionDeveloping;
  }

  action def StopVacuumPump {
    in command : ControlCommand;
    out status : PumpStatus;
    action removeMotorDrive;
    then action decelerateRotor;
    then action confirmStopped;
  }

  action def MoveFluidByVacuum {
    in item inletFluid : WorkingFluid;
    out item outletFluid : WorkingFluid;
    in suctionPressure : Pressure_kPa;
    in dischargePressure : Pressure_kPa;
    out deliveredFlow : VolumeFlowRate_L_per_min;
    action createLowPressureAtInlet;
    then action drawFluidThroughInlet;
    then action compressEntrainedGasAndFluidVapor;
    then action dischargeFluidToOutlet;
  }

  action def MaintainVacuumTransfer {
    in targetSuctionPressure : Pressure_kPa;
    in minimumFlow : VolumeFlowRate_L_per_min;
    in maximumDischargePressure : Pressure_kPa;
    out achievedFlow : VolumeFlowRate_L_per_min;
    action openSuctionPath : OpenValve;
    then action startPump : StartVacuumPump;
    then action regulateSpeed;
    then action transferFluid : MoveFluidByVacuum;
    then action monitorPressureAndFlow;
  }

  action def FaultShutdown {
    out safe : Boolean;
    action commandPumpStop : StopVacuumPump;
    then action closeInletIsolation : CloseValve;
    then action ventControlledVolume;
    then action reportFault;
  }

  state def VacuumPumpOperatingStates {
    attribute suctionPressure : Pressure_kPa;
    attribute dischargePressure : Pressure_kPa;
    attribute motorSpeed : RotationalSpeed_rpm;
    attribute faultPresent : Boolean;

    entry action initializeStatus;

    state off;
    state starting;
    state evacuating;
    state pumping;
    state stopping;
    state faulted;

    transition initial_to_off
      first start
      then off;

    transition off_to_starting
      first off
      accept ControlCommand
      if command.enablePump
      then starting;

    transition starting_to_evacuating
      first starting
      if motorSpeed >= 1200.0
      then evacuating;

    transition evacuating_to_pumping
      first evacuating
      if suctionPressure <= 25.0
      then pumping;

    transition pumping_to_stopping
      first pumping
      accept ControlCommand
      if not command.enablePump
      then stopping;

    transition stopping_to_off
      first stopping
      if motorSpeed <= 10.0
      then off;

    transition any_to_faulted
      first off
      then faulted
      if faultPresent;

    transition starting_to_faulted
      first starting
      then faulted
      if faultPresent;

    transition evacuating_to_faulted
      first evacuating
      then faulted
      if faultPresent;

    transition pumping_to_faulted
      first pumping
      then faulted
      if faultPresent;

    transition faulted_to_off
      first faulted
      accept ControlCommand
      if command.resetFault
      then off;
  }

  state def PumpingSubsystemStates {
    attribute inletValveOpen : Boolean;
    attribute pumpRunning : Boolean;
    attribute suctionPressure : Pressure_kPa;
    attribute outletFlow : VolumeFlowRate_L_per_min;
    attribute faultPresent : Boolean;

    state unpowered;
    state standby;
    state priming;
    state transferring;
    state controlledStop;
    state safeFault;

    transition initial_to_unpowered
      first start
      then unpowered;

    transition unpowered_to_standby
      first unpowered
      accept ElectricalPower
      if suppliedPower.voltage >= 21.0
      then standby;

    transition standby_to_priming
      first standby
      accept ControlCommand
      if command.enablePump
      then priming;

    transition priming_to_transferring
      first priming
      if suctionPressure <= 35.0 and inletValveOpen
      then transferring;

    transition transferring_to_controlledStop
      first transferring
      accept ControlCommand
      if not command.enablePump
      then controlledStop;

    transition controlledStop_to_standby
      first controlledStop
      if not pumpRunning
      then standby;

    transition standby_to_safeFault
      first standby
      if faultPresent
      then safeFault;

    transition priming_to_safeFault
      first priming
      if faultPresent
      then safeFault;

    transition transferring_to_safeFault
      first transferring
      if faultPresent
      then safeFault;

    transition safeFault_to_standby
      first safeFault
      accept ControlCommand
      if command.resetFault
      then standby;
  }

  part def IsolationValve {
    port upstream : FluidPort;
    port downstream : FluidPort;
    port commandIn : CommandInputPort;

    attribute open : Boolean = false;
    attribute nominalDiameter_mm : Real = 12.0;
    attribute pressureDropAtRatedFlow : Pressure_kPa = 1.0;

    perform action openValve : OpenValve;
    perform action closeValve : CloseValve;
  }

  part def InletFilter {
    port upstream : FluidPort;
    port downstream : FluidPort;

    attribute retainedParticleSize : ParticleSize_um = 25.0;
    attribute cleanPressureDrop : Pressure_kPa = 0.8;
    attribute clogged : Boolean = false;

    constraint filterRetention : FilterParticleConstraint {
      capturedParticleSize = retainedParticleSize;
      requiredParticleSize = 25.0;
    }
  }

  part def PressureSensor {
    port sensedFluid : FluidPort;
    port sampleOut : SensorOutputPort;

    attribute rangeMinimum : Pressure_kPa = 0.0;
    attribute rangeMaximum : Pressure_kPa = 150.0;
    attribute accuracy : Pressure_kPa = 0.5;
    attribute samplePeriod : Time_s = 0.05;
  }

  part def FlowSensor {
    port sensedFluid : FluidPort;
    port sampleOut : SensorOutputPort;

    attribute rangeMinimum : VolumeFlowRate_L_per_min = 0.0;
    attribute rangeMaximum : VolumeFlowRate_L_per_min = 40.0;
    attribute accuracy : VolumeFlowRate_L_per_min = 0.4;
    attribute samplePeriod : Time_s = 0.10;
  }

  part def CheckValve {
    port inlet : FluidPort;
    port outlet : FluidPort;

    attribute crackingPressure : Pressure_kPa = 2.0;
    attribute reverseLeakageFlow : VolumeFlowRate_L_per_min = 0.02;
    attribute preventsBackflow : Boolean = true;
  }

  part def CondensateTrap {
    port inlet : FluidPort;
    port outlet : FluidPort;
    port drain : FluidPort;

    attribute collectedVolume_L : Real = 0.0;
    attribute maximumCollectedVolume_L : Real = 0.75;
    attribute separationEfficiency : Efficiency_percent = 95.0;
  }

  part def ElectricMotor {
    port powerIn : ElectricalPowerPort;

    attribute ratedVoltage : Voltage_V = 24.0;
    attribute ratedCurrent : Current_A = 10.0;
    attribute ratedPower : Power_W = 240.0;
    attribute commandedSpeed : RotationalSpeed_rpm = 0.0;
    attribute actualSpeed : RotationalSpeed_rpm = 0.0;
    attribute efficiency : Efficiency_percent = 82.0;
  }

  part def VacuumPumpHead {
    port suction : FluidPort;
    port discharge : FluidPort;

    attribute sweptVolume_mL_per_rev : Real = 4.5;
    attribute ultimatePressure : Pressure_kPa = 5.0;
    attribute maximumDischargePressure : Pressure_kPa = 125.0;
    attribute internalLeakageFlow : VolumeFlowRate_L_per_min = 0.15;
  }

  part def VacuumPump {
    port suction : FluidPort;
    port discharge : FluidPort;
    port powerIn : ElectricalPowerPort;
    port commandIn : CommandInputPort;
    port statusOut : StatusOutputPort;

    part motor : ElectricMotor;
    part head : VacuumPumpHead;
    part outletCheckValve : CheckValve;

    attribute maximumFreeAirFlow : VolumeFlowRate_L_per_min = 30.0;
    attribute minimumControlledFlow : VolumeFlowRate_L_per_min = 5.0;
    attribute ratedSuctionPressure : Pressure_kPa = 20.0;
    attribute ultimateSuctionPressure : Pressure_kPa = 5.0;
    attribute maximumElectricalPower : Power_W = 260.0;
    attribute currentElectricalPower : Power_W = 0.0;
    attribute currentSuctionPressure : Pressure_kPa = 101.3;
    attribute currentDischargePressure : Pressure_kPa = 101.3;
    attribute currentFlow : VolumeFlowRate_L_per_min = 0.0;

    connect powerIn to motor.powerIn;
    connect suction to head.suction;
    connect head.discharge to outletCheckValve.inlet;
    connect outletCheckValve.outlet to discharge;

    exhibit state pumpStates : VacuumPumpOperatingStates;

    perform action start : StartVacuumPump;
    perform action stop : StopVacuumPump;
    perform action moveFluid : MoveFluidByVacuum;

    constraint vacuumLimit : VacuumPressureConstraint {
      actualSuctionPressure = currentSuctionPressure;
      maximumAllowedSuctionPressure = ratedSuctionPressure;
    }

    constraint dischargeLimit : DischargePressureConstraint {
      actualDischargePressure = currentDischargePressure;
      maximumDischargePressure = head.maximumDischargePressure;
    }

    constraint powerLimit : ElectricalPowerConstraint {
      consumedPower = currentElectricalPower;
      maximumPower = maximumElectricalPower;
    }
  }

  part def PumpController {
    port pressureSampleIn : SensorInputPort;
    port flowSampleIn : SensorInputPort;
    port pumpStatusIn : StatusInputPort;
    port pumpCommandOut : CommandOutputPort;
    port valveCommandOut : CommandOutputPort;

    attribute targetSuctionPressure : Pressure_kPa = 25.0;
    attribute minimumRequiredFlow : VolumeFlowRate_L_per_min = 12.0;
    attribute maximumAllowedDischargePressure : Pressure_kPa = 115.0;
    attribute startDelay : Time_s = 0.5;
    attribute stopDelay : Time_s = 0.2;
    attribute faultPresent : Boolean = false;

    action def RegulateVacuumPump {
      in pressureSample : SensorSample;
      in flowSample : SensorSample;
      out pumpCommand : ControlCommand;
      action comparePressureToTarget;
      then action computeSpeedRequest;
      then action commandPumpSpeed;
      then action detectLowFlowOrOverPressure;
    }

    perform action regulate : RegulateVacuumPump;
  }

  requirement def MoveFluidUsingVacuumPumpRequirement {
    subject subsystem : PumpingSubsystem;
    attribute requiredFlow : VolumeFlowRate_L_per_min = 12.0;
    attribute maximumSuctionPressure : Pressure_kPa = 35.0;

    doc /* The pumping subsystem shall move working fluid from the inlet to the outlet by operating a vacuum pump that creates a lower pressure at the suction side than at the fluid source. */

    require constraint flowRequirement : FlowCapacityConstraint {
      actualFlow = subsystem.outlet.flowRate;
      requiredFlow = requiredFlow;
    }

    require constraint suctionRequirement : VacuumPressureConstraint {
      actualSuctionPressure = subsystem.vacuumPump.currentSuctionPressure;
      maximumAllowedSuctionPressure = maximumSuctionPressure;
    }
  }

  requirement def SafeDischargeRequirement {
    subject subsystem : PumpingSubsystem;
    attribute maximumDischargePressure : Pressure_kPa = 115.0;

    doc /* The subsystem shall limit outlet pressure to protect downstream equipment. */

    require constraint dischargeRequirement : DischargePressureConstraint {
      actualDischargePressure = subsystem.vacuumPump.currentDischargePressure;
      maximumDischargePressure = maximumDischargePressure;
    }
  }

  requirement def ElectricalPowerRequirement {
    subject subsystem : PumpingSubsystem;
    attribute maximumInputPower : Power_W = 260.0;

    doc /* The subsystem shall operate within the specified electrical input power limit while transferring fluid. */

    require constraint electricalRequirement : ElectricalPowerConstraint {
      consumedPower = subsystem.vacuumPump.currentElectricalPower;
      maximumPower = maximumInputPower;
    }
  }

  requirement def BackflowPreventionRequirement {
    subject subsystem : PumpingSubsystem;

    doc /* The subsystem shall prevent reverse flow from the outlet toward the inlet when the vacuum pump is stopped. */

    require constraint { subsystem.outletCheckValve.preventsBackflow == true }
  }

  part def PumpingSubsystem {
    port inlet : FluidPort;
    port outlet : FluidPort;
    port drain : FluidPort;
    port powerIn : ElectricalPowerPort;
    port commandIn : CommandInputPort;
    port statusOut : StatusOutputPort;

    part inletIsolationValve : IsolationValve;
    part inletFilter : InletFilter;
    part suctionPressureSensor : PressureSensor;
    part vacuumPump : VacuumPump;
    part condensateTrap : CondensateTrap;
    part outletCheckValve : CheckValve;
    part outletFlowSensor : FlowSensor;
    part controller : PumpController;

    attribute designFlow : VolumeFlowRate_L_per_min = 18.0;
    attribute minimumRequiredFlow : VolumeFlowRate_L_per_min = 12.0;
    attribute targetSuctionPressure : Pressure_kPa = 25.0;
    attribute maximumOutletPressure : Pressure_kPa = 115.0;
    attribute operatingTemperatureMinimum : Temperature_degC = 5.0;
    attribute operatingTemperatureMaximum : Temperature_degC = 45.0;
    attribute nominalSupplyVoltage : Voltage_V = 24.0;
    attribute subsystemEnabled : Boolean = false;
    attribute faultPresent : Boolean = false;

    connect inlet to inletIsolationValve.upstream;
    connect inletIsolationValve.downstream to inletFilter.upstream;
    connect inletFilter.downstream to suctionPressureSensor.sensedFluid;
    connect suctionPressureSensor.sensedFluid to vacuumPump.suction;
    connect vacuumPump.discharge to condensateTrap.inlet;
    connect condensateTrap.outlet to outletCheckValve.inlet;
    connect outletCheckValve.outlet to outletFlowSensor.sensedFluid;
    connect outletFlowSensor.sensedFluid to outlet;
    connect condensateTrap.drain to drain;

    connect powerIn to vacuumPump.powerIn;
    connect commandIn to controller.pumpStatusIn;
    connect suctionPressureSensor.sampleOut to controller.pressureSampleIn;
    connect outletFlowSensor.sampleOut to controller.flowSampleIn;
    connect vacuumPump.statusOut to controller.pumpStatusIn;
    connect controller.pumpCommandOut to vacuumPump.commandIn;
    connect controller.valveCommandOut to inletIsolationValve.commandIn;
    connect vacuumPump.statusOut to statusOut;

    exhibit state subsystemStates : PumpingSubsystemStates;

    perform action transferOperation : MaintainVacuumTransfer {
      targetSuctionPressure = targetSuctionPressure;
      minimumFlow = minimumRequiredFlow;
      maximumDischargePressure = maximumOutletPressure;
    }

    perform action emergencyShutdown : FaultShutdown;

    requirement moveFluidReq : MoveFluidUsingVacuumPumpRequirement {
      subject subsystem = this;
      requiredFlow = minimumRequiredFlow;
      maximumSuctionPressure = 35.0;
    }

    requirement safeDischargeReq : SafeDischargeRequirement {
      subject subsystem = this;
      maximumDischargePressure = maximumOutletPressure;
    }

    requirement electricalPowerReq : ElectricalPowerRequirement {
      subject subsystem = this;
      maximumInputPower = vacuumPump.maximumElectricalPower;
    }

    requirement backflowReq : BackflowPreventionRequirement {
      subject subsystem = this;
    }

    satisfy moveFluidReq by vacuumPump;
    satisfy moveFluidReq by inletIsolationValve;
    satisfy moveFluidReq by controller;
    satisfy safeDischargeReq by vacuumPump;
    satisfy safeDischargeReq by outletCheckValve;
    satisfy electricalPowerReq by vacuumPump.motor;
    satisfy backflowReq by outletCheckValve;

    constraint deliveredFlowCapability : FlowCapacityConstraint {
      actualFlow = outlet.flowRate;
      requiredFlow = minimumRequiredFlow;
    }

    constraint suctionCapability : VacuumPressureConstraint {
      actualSuctionPressure = vacuumPump.currentSuctionPressure;
      maximumAllowedSuctionPressure = 35.0;
    }

    constraint outletPressureCapability : DischargePressureConstraint {
      actualDischargePressure = vacuumPump.currentDischargePressure;
      maximumDischargePressure = maximumOutletPressure;
    }
  }

  part vacuumPumpingSubsystem : PumpingSubsystem {
    attribute :>> designFlow = 18.0;
    attribute :>> minimumRequiredFlow = 12.0;
    attribute :>> targetSuctionPressure = 25.0;
    attribute :>> maximumOutletPressure = 115.0;
    attribute :>> nominalSupplyVoltage = 24.0;
  }
}
