package HydraulicAccumulatorSystem {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  value def Pressure {
    :> scalarValues::Real;
    unit = "Pa";
  }

  value def Volume {
    :> scalarValues::Real;
    unit = "m^3";
  }

  value def FlowRate {
    :> scalarValues::Real;
    unit = "m^3/s";
  }

  value def Temperature {
    :> scalarValues::Real;
    unit = "K";
  }

  value def Force {
    :> scalarValues::Real;
    unit = "N";
  }

  value def Time {
    :> scalarValues::Real;
    unit = "s";
  }

  item def HydraulicFluid {
    attribute pressure : Pressure;
    attribute temperature : Temperature;
    attribute volumetricFlow : FlowRate;
    attribute bulkModulus : Pressure = 1.5e9;
  }

  item def NitrogenGas {
    attribute pressure : Pressure;
    attribute temperature : Temperature;
    attribute volume : Volume;
    attribute polytropicIndex : scalarValues::Real = 1.4;
  }

  item def MechanicalForce {
    attribute magnitude : Force;
  }

  port def HydraulicPort {
    inout fluid : HydraulicFluid;
  }

  port def GasServicePort {
    inout gas : NitrogenGas;
  }

  port def MechanicalMountPort {
    inout load : MechanicalForce;
  }

  port def SignalPort {
    out pressureSignal : Pressure;
  }

  part def PressureVessel {
    attribute ratedPressure : Pressure = 21000000;
    attribute internalVolume : Volume = 0.020;
    attribute proofPressure : Pressure = 31500000;
    attribute operatingTemperatureMin : Temperature = 253.15;
    attribute operatingTemperatureMax : Temperature = 353.15;

    port hydraulicCavity : HydraulicPort;
    port gasCavity : GasServicePort;
    port mountingInterface : MechanicalMountPort;
  }

  part def BladderSeparator {
    attribute effectiveArea : scalarValues::Real = 0.012;
    attribute maximumStrokeVolume : Volume = 0.018;
    attribute minimumGasVolume : Volume = 0.002;
    attribute fatigueCycleLimit : scalarValues::Integer = 1000000;

    port hydraulicSide : HydraulicPort;
    port gasSide : GasServicePort;
  }

  part def HydraulicValveBlock {
    attribute crackingPressure : Pressure = 200000;
    attribute maximumFlowRate : FlowRate = 0.003;
    attribute isolationLeakageRate : FlowRate = 1.0e-8;

    port systemLine : HydraulicPort;
    port accumulatorLine : HydraulicPort;
  }

  part def GasChargeValve {
    attribute prechargePressureSetpoint : Pressure = 9000000;
    attribute maximumServicePressure : Pressure = 16000000;

    port gasService : GasServicePort;
    port vesselGasSide : GasServicePort;
  }

  part def PressureSensor {
    attribute measurementRangeMin : Pressure = 0;
    attribute measurementRangeMax : Pressure = 25000000;
    attribute accuracyBand : Pressure = 50000;
    attribute samplePeriod : Time = 0.010;

    port sensedHydraulicLine : HydraulicPort;
    port signalOut : SignalPort;
  }

  action def StoreHydraulicEnergy {
    in hydraulicFluidIn : HydraulicFluid;
    inout gasCharge : NitrogenGas;
    out storedFluid : HydraulicFluid;

    attribute initialGasPressure : Pressure;
    attribute finalGasPressure : Pressure;
    attribute displacedFluidVolume : Volume;
    attribute storedEnergy : scalarValues::Real;

    first start;
    then compressGas;
    then acceptFluid;
    then computeStoredEnergy;
    then done;

    action compressGas {
      inout gasCharge : NitrogenGas;
    }

    action acceptFluid {
      in hydraulicFluidIn : HydraulicFluid;
      out storedFluid : HydraulicFluid;
    }

    action computeStoredEnergy {
      in initialGasPressure : Pressure;
      in finalGasPressure : Pressure;
      in displacedFluidVolume : Volume;
      out storedEnergy : scalarValues::Real;
    }
  }

  action def ReleaseHydraulicEnergy {
    inout gasCharge : NitrogenGas;
    out hydraulicFluidOut : HydraulicFluid;

    attribute deliveryPressure : Pressure;
    attribute releasedVolume : Volume;
    attribute deliveredFlowRate : FlowRate;

    first start;
    then expandGas;
    then dischargeFluid;
    then stabilizePressure;
    then done;

    action expandGas {
      inout gasCharge : NitrogenGas;
    }

    action dischargeFluid {
      out hydraulicFluidOut : HydraulicFluid;
    }

    action stabilizePressure {
      in deliveryPressure : Pressure;
    }
  }

  action def IsolateAccumulator {
    inout hydraulicPath : HydraulicFluid;

    first start;
    then closeValve;
    then verifyLeakageLimit;
    then done;

    action closeValve;
    action verifyLeakageLimit {
      in hydraulicPath : HydraulicFluid;
    }
  }

  state def AccumulatorOperationalState {
    entry action initializePressureMonitoring;

    state Uncharged;
    state Precharged;
    state Charging;
    state Charged;
    state Discharging;
    state Isolated;
    state OverpressureProtected;

    transition first Uncharged;

    transition Uncharged_to_Precharged
      first Uncharged
      then Precharged
      accept ChargeGas
      if gasPressure >= 9000000 and gasPressure <= 10000000;

    transition Precharged_to_Charging
      first Precharged
      then Charging
      accept HydraulicPressureApplied
      if hydraulicPressure > gasPressure;

    transition Charging_to_Charged
      first Charging
      then Charged
      accept ChargeComplete
      if hydraulicPressure >= 16000000;

    transition Charged_to_Discharging
      first Charged
      then Discharging
      accept SystemPressureDrop
      if hydraulicPressure < gasPressure;

    transition Discharging_to_Precharged
      first Discharging
      then Precharged
      accept FluidVolumeDepleted
      if hydraulicVolume <= 0.002;

    transition Charged_to_Isolated
      first Charged
      then Isolated
      accept IsolationCommand;

    transition Charging_to_OverpressureProtected
      first Charging
      then OverpressureProtected
      accept OverpressureDetected
      if hydraulicPressure > 21000000;

    transition OverpressureProtected_to_Isolated
      first OverpressureProtected
      then Isolated
      accept ReliefComplete
      if hydraulicPressure <= 19000000;
  }

  part def HydraulicAccumulator {
    attribute nominalFluidVolume : Volume = 0.010;
    attribute usableFluidVolume : Volume = 0.008;
    attribute gasPrechargePressure : Pressure = 9000000;
    attribute minimumOperatingPressure : Pressure = 10000000;
    attribute maximumOperatingPressure : Pressure = 18000000;
    attribute maximumAllowablePressure : Pressure = 21000000;
    attribute nominalDischargeFlow : FlowRate = 0.0015;
    attribute storedEnergyCapacity : scalarValues::Real = 6500;

    port hydraulicSystemPort : HydraulicPort;
    port gasServicePort : GasServicePort;
    port mountPort : MechanicalMountPort;
    port pressureSignalPort : SignalPort;

    part vessel : PressureVessel;
    part separator : BladderSeparator;
    part valveBlock : HydraulicValveBlock;
    part gasValve : GasChargeValve;
    part sensor : PressureSensor;

    connection hydraulicEntry {
      end hydraulicSystemPort;
      end valveBlock.systemLine;
    }

    connection valveToVessel {
      end valveBlock.accumulatorLine;
      end vessel.hydraulicCavity;
    }

    connection vesselToSeparatorHydraulic {
      end vessel.hydraulicCavity;
      end separator.hydraulicSide;
    }

    connection vesselToSeparatorGas {
      end vessel.gasCavity;
      end separator.gasSide;
    }

    connection serviceGasPath {
      end gasServicePort;
      end gasValve.gasService;
    }

    connection gasValveToVessel {
      end gasValve.vesselGasSide;
      end vessel.gasCavity;
    }

    connection sensorTap {
      end sensor.sensedHydraulicLine;
      end valveBlock.accumulatorLine;
    }

    connection sensorSignal {
      end sensor.signalOut;
      end pressureSignalPort;
    }

    connection structuralMount {
      end mountPort;
      end vessel.mountingInterface;
    }

    perform action storeEnergy : StoreHydraulicEnergy;
    perform action releaseEnergy : ReleaseHydraulicEnergy;
    perform action isolate : IsolateAccumulator;

    exhibit state operationalState : AccumulatorOperationalState;
  }

  part def HydraulicPowerUnit {
    attribute supplyPressure : Pressure = 16000000;
    attribute returnPressure : Pressure = 200000;
    attribute pumpFlowRate : FlowRate = 0.002;

    port pressureLine : HydraulicPort;
    port returnLine : HydraulicPort;
  }

  part def HydraulicActuatorLoad {
    attribute requiredPeakFlowRate : FlowRate = 0.003;
    attribute minimumAcceptablePressure : Pressure = 10000000;

    port supplyPort : HydraulicPort;
  }

  part def AccumulatorBasedHydraulicSystem {
    attribute primaryFunction : String =
      "Store pressurized hydraulic energy by compressing a gas charge, then release hydraulic fluid to maintain pressure, supply transient flow demand, and absorb pressure pulsations.";

    part accumulator : HydraulicAccumulator;
    part powerUnit : HydraulicPowerUnit;
    part actuatorLoad : HydraulicActuatorLoad;

    connection supplyToAccumulator {
      end powerUnit.pressureLine;
      end accumulator.hydraulicSystemPort;
    }

    connection supplyToLoad {
      end powerUnit.pressureLine;
      end actuatorLoad.supplyPort;
    }
  }

  requirement def StoreEnergyRequirement {
    doc
      "The accumulator shall store hydraulic energy by accepting fluid when system pressure exceeds gas precharge pressure.";

    subject accumulator : HydraulicAccumulator;

    require constraint {
      accumulator.minimumOperatingPressure > accumulator.gasPrechargePressure
    }
  }

  requirement def DeliverTransientFlowRequirement {
    doc
      "The accumulator shall deliver supplemental flow to the hydraulic load when load demand exceeds pump flow capability.";

    subject system : AccumulatorBasedHydraulicSystem;

    require constraint {
      system.accumulator.nominalDischargeFlow >=
      system.actuatorLoad.requiredPeakFlowRate - system.powerUnit.pumpFlowRate
    }
  }

  requirement def MaintainPressureRequirement {
    doc
      "The accumulator shall maintain delivered hydraulic pressure at or above the load minimum during discharge.";

    subject accumulator : HydraulicAccumulator;
    subject load : HydraulicActuatorLoad;

    require constraint {
      accumulator.minimumOperatingPressure >= load.minimumAcceptablePressure
    }
  }

  requirement def PressureContainmentRequirement {
    doc
      "The accumulator pressure vessel shall withstand maximum operating pressure without exceeding rated pressure.";

    subject accumulator : HydraulicAccumulator;

    require constraint {
      accumulator.maximumOperatingPressure <= accumulator.vessel.ratedPressure
    }
  }

  requirement def GasPrechargeRequirement {
    doc
      "The gas precharge pressure shall be lower than minimum operating pressure and high enough to preserve usable stored energy.";

    subject accumulator : HydraulicAccumulator;

    require constraint {
      accumulator.gasPrechargePressure >= 0.85 * accumulator.minimumOperatingPressure and
      accumulator.gasPrechargePressure < accumulator.minimumOperatingPressure
    }
  }

  requirement def OverpressureProtectionRequirement {
    doc
      "The accumulator shall enter an overpressure protected condition when hydraulic pressure exceeds the maximum allowable pressure.";

    subject accumulator : HydraulicAccumulator;

    require constraint {
      accumulator.maximumAllowablePressure <= accumulator.vessel.proofPressure
    }
  }

  requirement def IsolationRequirement {
    doc
      "The accumulator valve block shall support isolation from the hydraulic system with leakage below the specified limit.";

    subject accumulator : HydraulicAccumulator;

    require constraint {
      accumulator.valveBlock.isolationLeakageRate <= 1.0e-8
    }
  }

  satisfy StoreEnergyRequirement by HydraulicAccumulator::storeEnergy;
  satisfy DeliverTransientFlowRequirement by AccumulatorBasedHydraulicSystem::accumulator;
  satisfy MaintainPressureRequirement by AccumulatorBasedHydraulicSystem::accumulator;
  satisfy PressureContainmentRequirement by HydraulicAccumulator::vessel;
  satisfy GasPrechargeRequirement by HydraulicAccumulator::gasValve;
  satisfy OverpressureProtectionRequirement by HydraulicAccumulator::operationalState;
  satisfy IsolationRequirement by HydraulicAccumulator::valveBlock;

  part hydraulicAccumulatorSystem : AccumulatorBasedHydraulicSystem;

}