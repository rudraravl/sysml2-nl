package ProportionalCounterModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def ElectricPotential {
    :>> unit = "V";
  }

  attribute def ElectricFieldStrength {
    :>> unit = "V/m";
  }

  attribute def Pressure {
    :>> unit = "Pa";
  }

  attribute def Temperature {
    :>> unit = "K";
  }

  attribute def TimeDuration {
    :>> unit = "s";
  }

  attribute def Charge {
    :>> unit = "C";
  }

  attribute def CountRate {
    :>> unit = "1/s";
  }

  attribute def Energy {
    :>> unit = "eV";
  }

  attribute def Gain {
    :>> unit = "1";
  }

  attribute def Length {
    :>> unit = "m";
  }

  enum def CounterMode {
    enum idle;
    enum biasing;
    enum detecting;
    enum saturated;
    enum faulted;
    enum shutdown;
  }

  item def IncidentRadiation {
    attribute particleEnergy : Energy;
    attribute arrivalTime : TimeDuration;
  }

  item def IonPairCloud {
    attribute pairCount : Integer;
    attribute meanIonizationEnergy : Energy = 30.0;
    attribute creationTime : TimeDuration;
  }

  item def ElectronAvalanche {
    attribute multiplicationGain : Gain;
    attribute collectedCharge : Charge;
    attribute pulseRiseTime : TimeDuration;
  }

  item def VoltagePulse {
    attribute amplitude : ElectricPotential;
    attribute width : TimeDuration;
    attribute chargeIntegral : Charge;
    attribute timestamp : TimeDuration;
  }

  item def DigitalCount {
    attribute countIndex : Integer;
    attribute timestamp : TimeDuration;
    attribute estimatedEnergy : Energy;
  }

  item def CounterStatus {
    attribute mode : CounterMode;
    attribute highVoltage : ElectricPotential;
    attribute countRate : CountRate;
    attribute gasPressure : Pressure;
    attribute temperature : Temperature;
    attribute faultPresent : Boolean;
  }

  port def RadiationInputPort {
    in item radiation : IncidentRadiation;
  }

  port def GasServicePort {
    in item fillPressureCommand : Pressure;
    out item measuredPressure : Pressure;
  }

  port def HighVoltagePort {
    out attribute biasVoltage : ElectricPotential;
  }

  port def IonizationPort {
    in item radiation : IncidentRadiation;
    out item ionCloud : IonPairCloud;
  }

  port def AvalanchePort {
    in item ionCloud : IonPairCloud;
    out item avalanche : ElectronAvalanche;
  }

  port def SignalPort {
    in item avalanche : ElectronAvalanche;
    out item pulse : VoltagePulse;
  }

  port def CountOutputPort {
    out item count : DigitalCount;
  }

  port def StatusPort {
    out item status : CounterStatus;
  }

  action def ConvertRadiationToIonPairs {
    in item radiation : IncidentRadiation;
    out item ionCloud : IonPairCloud;

    constraint ionizationYield {
      ionCloud.pairCount == radiation.particleEnergy / ionCloud.meanIonizationEnergy;
    }
  }

  action def MultiplyIonizationProportionally {
    in item ionCloud : IonPairCloud;
    in attribute electricField : ElectricFieldStrength;
    in attribute gasPressure : Pressure;
    out item avalanche : ElectronAvalanche;

    constraint proportionalRegionGain {
      avalanche.multiplicationGain >= 100.0 and avalanche.multiplicationGain <= 100000.0;
    }

    constraint chargeFormation {
      avalanche.collectedCharge == ionCloud.pairCount * avalanche.multiplicationGain * 1.602176634e-19;
    }
  }

  action def ShapeAndDiscriminatePulse {
    in item avalanche : ElectronAvalanche;
    in attribute threshold : ElectricPotential;
    out item pulse : VoltagePulse;
    out attribute accepted : Boolean;

    constraint pulseAmplitudeRelation {
      pulse.chargeIntegral == avalanche.collectedCharge;
    }

    constraint thresholdDecision {
      accepted == pulse.amplitude >= threshold;
    }
  }

  action def RegisterDigitalCount {
    in item pulse : VoltagePulse;
    out item count : DigitalCount;

    constraint energyEstimate {
      count.estimatedEnergy > 0.0;
    }
  }

  state def CounterOperatingState {
    attribute mode : CounterMode;

    state idle;
    state biasing;
    state detecting;
    state saturated;
    state faulted;
    state shutdown;

    transition initial then idle;

    transition idle_to_biasing
      first idle
      accept PowerOn
      then biasing;

    transition biasing_to_detecting
      first biasing
      accept BiasStable
      then detecting;

    transition detecting_to_saturated
      first detecting
      accept CountRateTooHigh
      then saturated;

    transition saturated_to_detecting
      first saturated
      accept RateRecovered
      then detecting;

    transition detecting_to_faulted
      first detecting
      accept GasPressureOutOfRange
      then faulted;

    transition biasing_to_faulted
      first biasing
      accept HighVoltageFault
      then faulted;

    transition faulted_to_shutdown
      first faulted
      accept FaultLatched
      then shutdown;

    transition detecting_to_shutdown
      first detecting
      accept PowerOff
      then shutdown;
  }

  part def GasFilledDetectionTube {
    attribute tubeLength : Length = 0.20;
    attribute cathodeRadius : Length = 0.010;
    attribute anodeWireRadius : Length = 0.000025;
    attribute gasPressure : Pressure = 101325.0;
    attribute gasTemperature : Temperature = 293.15;
    attribute fillGasName : String = "P10 argon methane";

    port radiationIn : RadiationInputPort;
    port gasService : GasServicePort;
    port ionization : IonizationPort;

    perform action ionize : ConvertRadiationToIonPairs;
  }

  part def AnodeCathodeFieldAssembly {
    attribute operatingVoltage : ElectricPotential = 1650.0;
    attribute maximumVoltage : ElectricPotential = 2200.0;
    attribute nominalFieldNearAnode : ElectricFieldStrength = 2500000.0;

    port highVoltageIn : HighVoltagePort;
    port avalanche : AvalanchePort;

    perform action multiply : MultiplyIonizationProportionally;
  }

  part def HighVoltageSupply {
    attribute commandedVoltage : ElectricPotential = 1650.0;
    attribute voltageTolerance : ElectricPotential = 10.0;
    attribute rampTime : TimeDuration = 5.0;
    attribute enabled : Boolean;

    port hvOut : HighVoltagePort;
    port statusOut : StatusPort;
  }

  part def ChargeSensitivePreamplifier {
    attribute feedbackCapacitance : Real = 1.0e-12;
    attribute pulseDecayTime : TimeDuration = 0.000050;
    attribute noiseEquivalentCharge : Charge = 3.2e-16;

    port signalIn : SignalPort;
    port pulseOut : SignalPort;
  }

  part def PulseShaperDiscriminator {
    attribute shapingTime : TimeDuration = 0.000001;
    attribute threshold : ElectricPotential = 0.015;
    attribute deadTime : TimeDuration = 0.000010;

    port pulseIn : SignalPort;
    port countOut : CountOutputPort;

    perform action shape : ShapeAndDiscriminatePulse;
  }

  part def DigitalCounterProcessor {
    attribute accumulatedCounts : Integer;
    attribute liveTime : TimeDuration;
    attribute measuredCountRate : CountRate;
    attribute saturationLimit : CountRate = 100000.0;

    port countIn : CountOutputPort;
    port statusOut : StatusPort;

    perform action register : RegisterDigitalCount;
  }

  part def ControlAndMonitoringUnit {
    attribute requestedMode : CounterMode;
    attribute activeMode : CounterMode;
    attribute pressureLowLimit : Pressure = 90000.0;
    attribute pressureHighLimit : Pressure = 120000.0;
    attribute temperatureLowLimit : Temperature = 273.15;
    attribute temperatureHighLimit : Temperature = 323.15;

    port hvCommand : HighVoltagePort;
    port statusIn : StatusPort;
    port statusOut : StatusPort;

    exhibit state behavior : CounterOperatingState;
  }

  part def ProportionalCounterSystem {
    doc /* Primary function: detect incident ionizing radiation by converting radiation energy into gas ionization, multiplying the ionization in the proportional region near the anode wire, and producing digital counts whose pulse amplitudes remain proportional to deposited particle energy. */

    attribute nominalBiasVoltage : ElectricPotential = 1650.0;
    attribute nominalGasPressure : Pressure = 101325.0;
    attribute nominalTemperature : Temperature = 293.15;
    attribute expectedGain : Gain = 10000.0;
    attribute minimumDetectableEnergy : Energy = 1000.0;
    attribute maximumLinearEnergy : Energy = 1000000.0;

    port radiationInput : RadiationInputPort;
    port countOutput : CountOutputPort;
    port statusOutput : StatusPort;
    port gasService : GasServicePort;

    part tube : GasFilledDetectionTube;
    part fieldAssembly : AnodeCathodeFieldAssembly;
    part hvSupply : HighVoltageSupply;
    part preamplifier : ChargeSensitivePreamplifier;
    part discriminator : PulseShaperDiscriminator;
    part processor : DigitalCounterProcessor;
    part controller : ControlAndMonitoringUnit;

    connect radiationPath connect radiationInput to tube.radiationIn;
    connect gasPath connect gasService to tube.gasService;
    connect ionPath connect tube.ionization to fieldAssembly.avalanche;
    connect hvPath connect hvSupply.hvOut to fieldAssembly.highVoltageIn;
    connect avalancheSignalPath connect fieldAssembly.avalanche to preamplifier.signalIn;
    connect shapedPulsePath connect preamplifier.pulseOut to discriminator.pulseIn;
    connect countPath connect discriminator.countOut to processor.countIn;
    connect externalCountPath connect processor.countIn to countOutput;
    connect processorStatusPath connect processor.statusOut to controller.statusIn;
    connect controllerStatusPath connect controller.statusOut to statusOutput;
    connect supplyStatusPath connect hvSupply.statusOut to controller.statusIn;

    constraint proportionalOperatingRange {
      hvSupply.commandedVoltage >= 1200.0 and
      hvSupply.commandedVoltage <= fieldAssembly.maximumVoltage and
      tube.gasPressure >= controller.pressureLowLimit and
      tube.gasPressure <= controller.pressureHighLimit;
    }

    constraint proportionalPulseCondition {
      expectedGain >= 100.0 and expectedGain <= 100000.0;
    }
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The system shall provide a high-level radiation counting function by accepting incident ionizing radiation and producing time-stamped digital counts while preserving proportionality between deposited energy and output pulse charge within the configured linear operating region. */

    subject counter : ProportionalCounterSystem;

    require constraint {
      counter.minimumDetectableEnergy <= 1000.0 and
      counter.maximumLinearEnergy >= 1000000.0 and
      counter.expectedGain >= 100.0 and
      counter.expectedGain <= 100000.0;
    }
  }

  requirement def StableGasRequirement {
    subject counter : ProportionalCounterSystem;

    require constraint {
      counter.tube.gasPressure >= 90000.0 and
      counter.tube.gasPressure <= 120000.0 and
      counter.tube.gasTemperature >= 273.15 and
      counter.tube.gasTemperature <= 323.15;
    }
  }

  requirement def BiasControlRequirement {
    subject counter : ProportionalCounterSystem;

    require constraint {
      counter.hvSupply.commandedVoltage >= 1200.0 and
      counter.hvSupply.commandedVoltage <= 2200.0 and
      counter.hvSupply.voltageTolerance <= 10.0;
    }
  }

  requirement def CountThroughputRequirement {
    subject counter : ProportionalCounterSystem;

    require constraint {
      counter.processor.saturationLimit >= 100000.0 and
      counter.discriminator.deadTime <= 0.000010;
    }
  }

  requirement def SafetyShutdownRequirement {
    subject counter : ProportionalCounterSystem;

    require constraint {
      counter.controller.pressureLowLimit == 90000.0 and
      counter.controller.pressureHighLimit == 120000.0;
    }
  }

  part proportionalCounter : ProportionalCounterSystem;

  satisfy PrimaryFunctionRequirement by proportionalCounter;
  satisfy StableGasRequirement by proportionalCounter;
  satisfy BiasControlRequirement by proportionalCounter;
  satisfy CountThroughputRequirement by proportionalCounter;
  satisfy SafetyShutdownRequirement by proportionalCounter;
}