package MagnetohydrodynamicDriveModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def ElectricCurrent :> ISQ::electricCurrent {
    unit = SI::ampere;
  }

  attribute def ElectricVoltage :> ISQ::electricPotential {
    unit = SI::volt;
  }

  attribute def MagneticFluxDensity :> ISQ::magneticFluxDensity {
    unit = SI::tesla;
  }

  attribute def Force :> ISQ::force {
    unit = SI::newton;
  }

  attribute def Velocity :> ISQ::speed {
    unit = SI::metrePerSecond;
  }

  attribute def MassFlowRate {
    unit = SI::kilogram / SI::second;
  }

  attribute def Efficiency {
    :>> range = "0..1";
  }

  attribute def Temperature :> ISQ::thermodynamicTemperature {
    unit = SI::kelvin;
  }

  attribute def Pressure :> ISQ::pressure {
    unit = SI::pascal;
  }

  attribute def Salinity {
    unit = SI::gram / SI::kilogram;
  }

  attribute def Conductivity {
    unit = SI::siemens / SI::metre;
  }

  item def Seawater {
    attribute temperature : Temperature;
    attribute pressure : Pressure;
    attribute salinity : Salinity;
    attribute electricalConductivity : Conductivity;
    attribute velocity : Velocity;
  }

  item def ElectricalPower {
    attribute voltage : ElectricVoltage;
    attribute current : ElectricCurrent;
    attribute power : ISQ::power;
  }

  item def CoolingWater {
    attribute temperature : Temperature;
    attribute massFlowRate : MassFlowRate;
  }

  item def CommandSignal {
    attribute demandedThrust : Force;
    attribute demandedCurrent : ElectricCurrent;
    attribute enableDrive : Boolean;
    attribute emergencyStop : Boolean;
  }

  item def StatusSignal {
    attribute measuredThrust : Force;
    attribute measuredCurrent : ElectricCurrent;
    attribute measuredMagneticField : MagneticFluxDensity;
    attribute inletConductivity : Conductivity;
    attribute driveReady : Boolean;
    attribute faultActive : Boolean;
  }

  port def FluidInletPort {
    in item fluid : Seawater;
  }

  port def FluidOutletPort {
    out item fluid : Seawater;
  }

  port def ElectricalInputPort {
    in item power : ElectricalPower;
  }

  port def CoolingPort {
    in item coolantIn : CoolingWater;
    out item coolantOut : CoolingWater;
  }

  port def ControlInputPort {
    in item command : CommandSignal;
  }

  port def StatusOutputPort {
    out item status : StatusSignal;
  }

  port def MechanicalInterfacePort {
    out attribute axialThrust : Force;
  }

  action def ConditionSeawater {
    in item inletFlow : Seawater;
    out item conditionedFlow : Seawater;
    attribute targetConductivity : Conductivity = 4.0 [SI::siemens / SI::metre];
  }

  action def GenerateMagneticField {
    in item electricalInput : ElectricalPower;
    out attribute magneticField : MagneticFluxDensity;
    attribute nominalField : MagneticFluxDensity = 5.0 [SI::tesla];
  }

  action def InjectCrossChannelCurrent {
    in item electricalInput : ElectricalPower;
    in item conditionedFlow : Seawater;
    out attribute channelCurrent : ElectricCurrent;
    attribute nominalCurrent : ElectricCurrent = 12000 [SI::ampere];
  }

  action def AccelerateConductiveFluid {
    in item conditionedFlow : Seawater;
    in attribute magneticField : MagneticFluxDensity;
    in attribute channelCurrent : ElectricCurrent;
    out item acceleratedFlow : Seawater;
    out attribute generatedThrust : Force;
  }

  action def RejectHeat {
    in item heatSourceFlow : Seawater;
    in item coolantIn : CoolingWater;
    out item cooledFlow : Seawater;
    out item coolantOut : CoolingWater;
  }

  action def MHDPropulsionCycle {
    in item inletFlow : Seawater;
    in item electricalInput : ElectricalPower;
    in item coolantIn : CoolingWater;
    out item outletJet : Seawater;
    out item coolantOut : CoolingWater;
    out attribute thrust : Force;

    action condition : ConditionSeawater {
      in inletFlow = MHDPropulsionCycle::inletFlow;
    }

    action fieldGeneration : GenerateMagneticField {
      in electricalInput = MHDPropulsionCycle::electricalInput;
    }

    action currentInjection : InjectCrossChannelCurrent {
      in electricalInput = MHDPropulsionCycle::electricalInput;
      in conditionedFlow = condition.conditionedFlow;
    }

    action acceleration : AccelerateConductiveFluid {
      in conditionedFlow = condition.conditionedFlow;
      in magneticField = fieldGeneration.magneticField;
      in channelCurrent = currentInjection.channelCurrent;
    }

    action cooling : RejectHeat {
      in heatSourceFlow = acceleration.acceleratedFlow;
      in coolantIn = MHDPropulsionCycle::coolantIn;
    }

    bind outletJet = cooling.cooledFlow;
    bind coolantOut = cooling.coolantOut;
    bind thrust = acceleration.generatedThrust;
  }

  part def PowerConversionUnit {
    port electricalInput : ElectricalInputPort;
    port conditionedPowerOut : ElectricalInputPort;

    attribute inputVoltage : ElectricVoltage = 5000 [SI::volt];
    attribute outputVoltage : ElectricVoltage = 1500 [SI::volt];
    attribute maxCurrent : ElectricCurrent = 15000 [SI::ampere];
    attribute conversionEfficiency : Efficiency = 0.94;
  }

  part def SuperconductingMagnetAssembly {
    port electricalInput : ElectricalInputPort;
    port cooling : CoolingPort;

    attribute magneticFluxDensity : MagneticFluxDensity = 5.0 [SI::tesla];
    attribute boreDiameter : ISQ::length = 1.8 [SI::metre];
    attribute coilTemperature : Temperature = 20 [SI::kelvin];
    attribute fieldUniformity : Efficiency = 0.96;
  }

  part def ElectrodeArray {
    port electricalInput : ElectricalInputPort;

    attribute electrodeVoltage : ElectricVoltage = 1200 [SI::volt];
    attribute channelCurrent : ElectricCurrent = 12000 [SI::ampere];
    attribute electrodeSpacing : ISQ::length = 1.4 [SI::metre];
    attribute corrosionAllowance : ISQ::length = 0.004 [SI::metre];
  }

  part def PropulsionDuct {
    port inlet : FluidInletPort;
    port outlet : FluidOutletPort;
    port thrustInterface : MechanicalInterfacePort;

    attribute ductLength : ISQ::length = 6.5 [SI::metre];
    attribute hydraulicDiameter : ISQ::length = 1.2 [SI::metre];
    attribute inletVelocity : Velocity = 4.0 [SI::metrePerSecond];
    attribute outletVelocity : Velocity = 9.5 [SI::metrePerSecond];
    attribute massFlowRate : MassFlowRate = 8500 [SI::kilogram / SI::second];
    attribute generatedThrust : Force = 46000 [SI::newton];
  }

  part def CoolingSubsystem {
    port magnetCooling : CoolingPort;
    port electrodeCooling : CoolingPort;

    attribute coolantSupplyTemperature : Temperature = 18 [SI::kelvin];
    attribute coolantReturnTemperature : Temperature = 30 [SI::kelvin];
    attribute heatRejectionRate : ISQ::power = 850000 [SI::watt];
  }

  part def ControlUnit {
    port commandInput : ControlInputPort;
    port statusOutput : StatusOutputPort;

    attribute currentSetpoint : ElectricCurrent;
    attribute thrustSetpoint : Force;
    attribute faultLatched : Boolean = false;
  }

  state def DriveOperatingStateMachine {
    state off;
    state standby;
    state precharge;
    state magnetRamp;
    state ready;
    state thrusting;
    state coolingHold;
    state fault;

    initial then off;

    transition off_to_standby
      first off
      accept CommandSignal
      if enableDrive and not emergencyStop
      then standby;

    transition standby_to_precharge
      first standby
      accept CommandSignal
      if demandedThrust > 0 [SI::newton]
      then precharge;

    transition precharge_to_magnetRamp
      first precharge
      if true
      then magnetRamp;

    transition magnetRamp_to_ready
      first magnetRamp
      if true
      then ready;

    transition ready_to_thrusting
      first ready
      accept CommandSignal
      if demandedCurrent > 0 [SI::ampere] and demandedThrust > 0 [SI::newton]
      then thrusting;

    transition thrusting_to_coolingHold
      first thrusting
      accept CommandSignal
      if demandedThrust == 0 [SI::newton]
      then coolingHold;

    transition coolingHold_to_ready
      first coolingHold
      if true
      then ready;

    transition any_to_fault_from_stop
      first off
      accept CommandSignal
      if emergencyStop
      then fault;

    transition ready_to_fault
      first ready
      accept StatusSignal
      if faultActive
      then fault;

    transition thrusting_to_fault
      first thrusting
      accept StatusSignal
      if faultActive
      then fault;
  }

  part def MagnetohydrodynamicDrive {
    port seawaterIn : FluidInletPort;
    port seawaterJetOut : FluidOutletPort;
    port shipPowerIn : ElectricalInputPort;
    port cryogenicCooling : CoolingPort;
    port command : ControlInputPort;
    port status : StatusOutputPort;
    port thrustMount : MechanicalInterfacePort;

    part powerConverter : PowerConversionUnit;
    part magnets : SuperconductingMagnetAssembly;
    part electrodes : ElectrodeArray;
    part duct : PropulsionDuct;
    part cooling : CoolingSubsystem;
    part controller : ControlUnit;

    attribute nominalThrust : Force = 46000 [SI::newton];
    attribute minimumConductivity : Conductivity = 3.2 [SI::siemens / SI::metre];
    attribute nominalMagneticField : MagneticFluxDensity = 5.0 [SI::tesla];
    attribute nominalChannelCurrent : ElectricCurrent = 12000 [SI::ampere];
    attribute propulsiveEfficiency : Efficiency = 0.58;
    attribute acousticSignatureReduction : Efficiency = 0.80;

    perform action propulsionCycle : MHDPropulsionCycle {
      in inletFlow = seawaterIn.fluid;
      in electricalInput = shipPowerIn.power;
      in coolantIn = cryogenicCooling.coolantIn;
      out outletJet = seawaterJetOut.fluid;
      out coolantOut = cryogenicCooling.coolantOut;
      out thrust = thrustMount.axialThrust;
    }

    exhibit state behavior : DriveOperatingStateMachine;

    connect shipPowerIn to powerConverter.electricalInput;
    connect powerConverter.conditionedPowerOut to magnets.electricalInput;
    connect powerConverter.conditionedPowerOut to electrodes.electricalInput;
    connect cryogenicCooling to cooling.magnetCooling;
    connect cooling.magnetCooling to magnets.cooling;
    connect cooling.electrodeCooling to electrodes.electricalInput;
    connect seawaterIn to duct.inlet;
    connect duct.outlet to seawaterJetOut;
    connect duct.thrustInterface to thrustMount;
    connect command to controller.commandInput;
    connect controller.statusOutput to status;
  }

  requirement def PrimaryFunctionRequirement {
    subject drive : MagnetohydrodynamicDrive;

    doc /* The magnetohydrodynamic drive shall convert shipboard electrical power into axial thrust by passing electric current through conductive seawater inside a strong transverse magnetic field, producing a Lorentz body force that accelerates seawater through a propulsion duct without rotating propulsor blades. */

    require constraint {
      drive.nominalThrust >= 40000 [SI::newton]
    }
  }

  requirement def ConductiveFluidRequirement {
    subject drive : MagnetohydrodynamicDrive;

    doc /* The drive shall operate only when inlet seawater conductivity is sufficient to sustain controlled cross-channel current injection. */

    require constraint {
      drive.minimumConductivity >= 3.2 [SI::siemens / SI::metre]
    }
  }

  requirement def MagneticFieldRequirement {
    subject drive : MagnetohydrodynamicDrive;

    doc /* The superconducting magnet assembly shall provide a stable transverse magnetic field across the active propulsion channel. */

    require constraint {
      drive.nominalMagneticField >= 4.5 [SI::tesla]
    }
  }

  requirement def CurrentControlRequirement {
    subject drive : MagnetohydrodynamicDrive;

    doc /* The electrode array and power conversion unit shall regulate propulsion-channel current to command thrust while preventing uncontrolled current excursions. */

    require constraint {
      drive.nominalChannelCurrent <= 15000 [SI::ampere]
    }
  }

  requirement def QuietPropulsionRequirement {
    subject drive : MagnetohydrodynamicDrive;

    doc /* The drive shall provide thrust without external rotating machinery and shall reduce tonal acoustic emissions relative to a comparable mechanical propeller. */

    require constraint {
      drive.acousticSignatureReduction >= 0.75
    }
  }

  requirement def ThermalManagementRequirement {
    subject drive : MagnetohydrodynamicDrive;

    doc /* The cooling subsystem shall remove thermal loads from superconducting magnets, electrodes, and power electronics during continuous thrust operation. */

    require constraint {
      drive.cooling.heatRejectionRate >= 800000 [SI::watt]
    }
  }

  satisfy PrimaryFunctionRequirement by MagnetohydrodynamicDrive;
  satisfy ConductiveFluidRequirement by MagnetohydrodynamicDrive;
  satisfy MagneticFieldRequirement by MagnetohydrodynamicDrive;
  satisfy CurrentControlRequirement by MagnetohydrodynamicDrive;
  satisfy QuietPropulsionRequirement by MagnetohydrodynamicDrive;
  satisfy ThermalManagementRequirement by MagnetohydrodynamicDrive;

  part mhdDriveSystem : MagnetohydrodynamicDrive {
    attribute nominalThrust = 46000 [SI::newton];
    attribute nominalMagneticField = 5.0 [SI::tesla];
    attribute nominalChannelCurrent = 12000 [SI::ampere];
    attribute propulsiveEfficiency = 0.58;
  }
}