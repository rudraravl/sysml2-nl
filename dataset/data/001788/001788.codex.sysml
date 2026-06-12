package GasolineAdditiveSystemModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  value def VolumeConcentration {
    unit = "%vol";
    quantity = "volume fraction";
  }

  value def MassConcentration {
    unit = "mg/L";
    quantity = "mass concentration";
  }

  value def OctaneNumber {
    unit = "RON";
    quantity = "research octane number";
  }

  value def TemperatureC {
    unit = "degC";
    quantity = "temperature";
  }

  value def PressureKPa {
    unit = "kPa";
    quantity = "pressure";
  }

  value def FlowRate {
    unit = "L/min";
    quantity = "volumetric flow rate";
  }

  value def EnergyDensity {
    unit = "MJ/L";
    quantity = "energy density";
  }

  value def DepositMass {
    unit = "mg";
    quantity = "deposit mass";
  }

  item def BaseGasoline {
    attribute volume : Real;
    attribute octaneRating : OctaneNumber;
    attribute sulfurContent : MassConcentration;
    attribute energyDensity : EnergyDensity;
  }

  item def AdditiveConcentrate {
    attribute detergentConcentration : MassConcentration;
    attribute corrosionInhibitorConcentration : MassConcentration;
    attribute stabilizerConcentration : MassConcentration;
    attribute carrierSolventFraction : VolumeConcentration;
  }

  item def TreatedGasoline {
    attribute additiveDose : VolumeConcentration;
    attribute octaneRating : OctaneNumber;
    attribute detergentLevel : MassConcentration;
    attribute oxidationStabilityHours : Real;
    attribute expectedDepositReduction : VolumeConcentration;
  }

  item def CombustionMixture {
    attribute airFuelRatio : Real;
    attribute fuelTemperature : TemperatureC;
    attribute manifoldPressure : PressureKPa;
  }

  item def ExhaustGas {
    attribute carbonMonoxide : MassConcentration;
    attribute unburnedHydrocarbons : MassConcentration;
    attribute nitrogenOxides : MassConcentration;
  }

  port def FuelInletPort {
    in item fuel : BaseGasoline;
  }

  port def AdditiveInletPort {
    in item additive : AdditiveConcentrate;
  }

  port def TreatedFuelOutletPort {
    out item treatedFuel : TreatedGasoline;
  }

  port def EngineFuelPort {
    in item treatedFuel : TreatedGasoline;
  }

  port def CombustionPort {
    out item mixture : CombustionMixture;
  }

  port def ExhaustPort {
    out item exhaust : ExhaustGas;
  }

  port def ControlSignalPort {
    in attribute commandedDose : VolumeConcentration;
    out attribute actualDose : VolumeConcentration;
  }

  action def MeterAdditive {
    in item fuel : BaseGasoline;
    in item additive : AdditiveConcentrate;
    in attribute targetDose : VolumeConcentration;
    out item meteredFuel : TreatedGasoline;

    constraint doseRange {
      targetDose >= 0.03 and targetDose <= 0.15
    }
  }

  action def MixFuel {
    in item fuel : BaseGasoline;
    in item additive : AdditiveConcentrate;
    out item treatedFuel : TreatedGasoline;

    constraint detergentDelivered {
      treatedFuel.detergentLevel >= 60
    }
  }

  action def StabilizeGasoline {
    in item treatedFuel : TreatedGasoline;
    out item stabilizedFuel : TreatedGasoline;

    constraint stabilityTarget {
      stabilizedFuel.oxidationStabilityHours >= 360
    }
  }

  action def SupportCombustion {
    in item treatedFuel : TreatedGasoline;
    out item mixture : CombustionMixture;
    out item exhaust : ExhaustGas;

    constraint combustionQuality {
      mixture.airFuelRatio >= 12.0 and mixture.airFuelRatio <= 15.5
    }
  }

  state def AdditiveSystemState {
    state Off;
    state Priming;
    state Dosing;
    state Mixing;
    state DeliveringTreatedFuel;
    state Fault;

    entry action initialize {
      then Off;
    }

    transition Off_to_Priming
      first Off
      then Priming;

    transition Priming_to_Dosing
      first Priming
      then Dosing;

    transition Dosing_to_Mixing
      first Dosing
      then Mixing;

    transition Mixing_to_Delivering
      first Mixing
      then DeliveringTreatedFuel;

    transition Any_to_Fault
      first Off
      then Fault;

    transition Fault_to_Off
      first Fault
      then Off;
  }

  part def AdditiveReservoir {
    attribute capacity : Real = 1.0;
    attribute usableVolume : Real;
    attribute additiveTemperature : TemperatureC;
    port additiveOut : AdditiveInletPort;
  }

  part def FuelTank {
    attribute fuelVolume : Real;
    attribute tankPressure : PressureKPa;
    attribute fuelTemperature : TemperatureC;
    port fuelOut : FuelInletPort;
  }

  part def DosingController {
    attribute targetDose : VolumeConcentration = 0.08;
    attribute minimumDose : VolumeConcentration = 0.03;
    attribute maximumDose : VolumeConcentration = 0.15;
    attribute measuredFuelFlow : FlowRate;
    port control : ControlSignalPort;

    perform action meter : MeterAdditive;
  }

  part def MeteringPump {
    attribute pumpFlowRate : FlowRate;
    attribute doseAccuracy : VolumeConcentration;
    port additiveIn : AdditiveInletPort;
    port control : ControlSignalPort;
    port additiveOut : AdditiveInletPort;
  }

  part def StaticMixer {
    attribute mixingEfficiency : VolumeConcentration;
    attribute pressureDrop : PressureKPa;
    port fuelIn : FuelInletPort;
    port additiveIn : AdditiveInletPort;
    port treatedFuelOut : TreatedFuelOutletPort;

    perform action mix : MixFuel;
  }

  part def FuelLine {
    attribute internalVolume : Real;
    attribute maxPressure : PressureKPa;
    port inlet : TreatedFuelOutletPort;
    port outlet : EngineFuelPort;
  }

  part def GasolineEngine {
    attribute displacement : Real;
    attribute compressionRatio : Real;
    attribute depositMassBeforeTreatment : DepositMass;
    attribute depositMassAfterTreatment : DepositMass;
    port fuelIn : EngineFuelPort;
    port combustionOut : CombustionPort;
    port exhaustOut : ExhaustPort;

    perform action combustion : SupportCombustion;
  }

  part def GasolineAdditiveSystem {
    attribute primaryFunction : String = "Meter, blend, and deliver a controlled gasoline additive dose to improve fuel cleanliness, storage stability, corrosion protection, and combustion quality.";
    attribute nominalDose : VolumeConcentration = 0.08;
    attribute operatingTemperatureMin : TemperatureC = -30;
    attribute operatingTemperatureMax : TemperatureC = 50;
    attribute maximumFuelFlow : FlowRate = 80;

    part tank : FuelTank;
    part reservoir : AdditiveReservoir;
    part controller : DosingController;
    part pump : MeteringPump;
    part mixer : StaticMixer;
    part line : FuelLine;
    part engine : GasolineEngine;

    port rawFuelIn : FuelInletPort;
    port additiveFill : AdditiveInletPort;
    port treatedFuelOut : TreatedFuelOutletPort;
    port exhaustOut : ExhaustPort;

    state systemState : AdditiveSystemState;

    connect tank.fuelOut to mixer.fuelIn;
    connect reservoir.additiveOut to pump.additiveIn;
    connect controller.control to pump.control;
    connect pump.additiveOut to mixer.additiveIn;
    connect mixer.treatedFuelOut to line.inlet;
    connect line.outlet to engine.fuelIn;
    connect engine.exhaustOut to exhaustOut;

    perform action doseAdditive : MeterAdditive;
    perform action blendAdditive : MixFuel;
    perform action stabilizeFuel : StabilizeGasoline;
    perform action burnFuel : SupportCombustion;
  }

  requirement def PrimaryFunctionRequirement {
    subject system : GasolineAdditiveSystem;

    doc /* The gasoline additive system shall add a controlled formulation to base gasoline so that the delivered fuel helps keep intake and injector surfaces clean, resists oxidation during storage, reduces corrosion risk, and supports stable combustion. */

    require constraint {
      system.nominalDose >= 0.03 and system.nominalDose <= 0.15
    }
  }

  requirement def DoseAccuracyRequirement {
    subject pump : MeteringPump;

    doc /* The metering pump shall maintain additive dose accuracy within plus or minus 0.01 percent by volume during normal fuel flow. */

    require constraint {
      pump.doseAccuracy <= 0.01
    }
  }

  requirement def MixingRequirement {
    subject mixer : StaticMixer;

    doc /* The static mixer shall distribute additive uniformly into gasoline before delivery to the engine fuel inlet. */

    require constraint {
      mixer.mixingEfficiency >= 95
    }
  }

  requirement def StabilityRequirement {
    subject fuel : TreatedGasoline;

    doc /* Treated gasoline shall maintain oxidation stability for extended storage. */

    require constraint {
      fuel.oxidationStabilityHours >= 360
    }
  }

  requirement def CleanlinessRequirement {
    subject fuel : TreatedGasoline;

    doc /* Treated gasoline shall reduce intake and injector deposit formation relative to untreated gasoline. */

    require constraint {
      fuel.expectedDepositReduction >= 30
    }
  }

  requirement def OperatingEnvironmentRequirement {
    subject system : GasolineAdditiveSystem;

    doc /* The system shall operate across typical automotive ambient fuel handling temperatures. */

    require constraint {
      system.operatingTemperatureMin <= -30 and system.operatingTemperatureMax >= 50
    }
  }

  requirement def CombustionCompatibilityRequirement {
    subject fuel : TreatedGasoline;

    doc /* The additive shall not reduce gasoline octane quality below the base gasoline requirement. */

    require constraint {
      fuel.octaneRating >= 87
    }
  }

  part systemInstance : GasolineAdditiveSystem {
    attribute nominalDose = 0.08;
    attribute maximumFuelFlow = 80;

    part tank {
      attribute fuelVolume = 45.0;
      attribute tankPressure = 101.3;
      attribute fuelTemperature = 20;
    }

    part reservoir {
      attribute capacity = 1.0;
      attribute usableVolume = 0.9;
      attribute additiveTemperature = 20;
    }

    part controller {
      attribute targetDose = 0.08;
      attribute minimumDose = 0.03;
      attribute maximumDose = 0.15;
      attribute measuredFuelFlow = 35;
    }

    part pump {
      attribute pumpFlowRate = 0.028;
      attribute doseAccuracy = 0.008;
    }

    part mixer {
      attribute mixingEfficiency = 97;
      attribute pressureDrop = 4;
    }

    part line {
      attribute internalVolume = 0.25;
      attribute maxPressure = 500;
    }

    part engine {
      attribute displacement = 2.0;
      attribute compressionRatio = 10.5;
      attribute depositMassBeforeTreatment = 120;
      attribute depositMassAfterTreatment = 78;
    }
  }

  satisfy PrimaryFunctionRequirement by systemInstance;
  satisfy OperatingEnvironmentRequirement by systemInstance;
  satisfy DoseAccuracyRequirement by systemInstance.pump;
  satisfy MixingRequirement by systemInstance.mixer;
}