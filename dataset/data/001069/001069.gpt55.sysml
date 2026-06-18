package GeigerMullerTubeBasedRadiationMonitor {

  import ScalarValues::*;

  enum def RadiationKind {
    alpha;
    beta;
    gamma;
    xRay;
    neutron;
    cosmicRay;
  }

  enum def AlarmLevel {
    normal;
    elevated;
    high;
    overload;
  }

  attribute def Voltage_V {
    attribute value: Real;
    attribute unit: String = "V";
  }

  attribute def Current_mA {
    attribute value: Real;
    attribute unit: String = "mA";
  }

  attribute def Resistance_MOhm {
    attribute value: Real;
    attribute unit: String = "MOhm";
  }

  attribute def Capacitance_nF {
    attribute value: Real;
    attribute unit: String = "nF";
  }

  attribute def Energy_keV {
    attribute value: Real;
    attribute unit: String = "keV";
  }

  attribute def Duration_us {
    attribute value: Real;
    attribute unit: String = "us";
  }

  attribute def Duration_ms {
    attribute value: Real;
    attribute unit: String = "ms";
  }

  attribute def Duration_s {
    attribute value: Real;
    attribute unit: String = "s";
  }

  attribute def Count {
    attribute value: Integer;
    attribute unit: String = "count";
  }

  attribute def CountRate_cps {
    attribute value: Real;
    attribute unit: String = "count/s";
  }

  attribute def CountRate_cpm {
    attribute value: Real;
    attribute unit: String = "count/min";
  }

  attribute def DoseRate_uSvPerHour {
    attribute value: Real;
    attribute unit: String = "uSv/h";
  }

  attribute def Dose_uSv {
    attribute value: Real;
    attribute unit: String = "uSv";
  }

  attribute def Charge_pC {
    attribute value: Real;
    attribute unit: String = "pC";
  }

  attribute def Temperature_C {
    attribute value: Real;
    attribute unit: String = "degC";
  }

  attribute def Pressure_kPa {
    attribute value: Real;
    attribute unit: String = "kPa";
  }

  attribute def FluenceRate_perCm2s {
    attribute value: Real;
    attribute unit: "1/(cm^2*s)";
  }

  item def IonizingRadiation {
    attribute kind: RadiationKind;
    attribute particleEnergy: Energy_keV;
    attribute fluenceRate: FluenceRate_perCm2s;
  }

  item def GasIonPair {
    attribute creationEnergy: Energy_keV;
    attribute electronCount: Count;
    attribute positiveIonCount: Count;
  }

  item def AvalanchePulse {
    attribute peakVoltage: Voltage_V;
    attribute pulseWidth: Duration_us;
    attribute charge: Charge_pC;
  }

  item def ShapedLogicPulse {
    attribute logicHighVoltage: Voltage_V;
    attribute width: Duration_us;
  }

  item def ElectricalPower {
    attribute voltage: Voltage_V;
    attribute current: Current_mA;
  }

  item def CountSample {
    attribute sampleInterval: Duration_s;
    attribute grossCounts: Count;
    attribute countRate: CountRate_cps;
  }

  item def DoseEstimate {
    attribute doseRate: DoseRate_uSvPerHour;
    attribute accumulatedDose: Dose_uSv;
    attribute integrationTime: Duration_s;
  }

  item def UserIndication {
    attribute displayedCountRate: CountRate_cpm;
    attribute displayedDoseRate: DoseRate_uSvPerHour;
    attribute alarm: AlarmLevel;
  }

  port def RadiationInputPort {
    in item incidentRadiation: IonizingRadiation;
  }

  port def LowVoltagePowerPort {
    in item lowVoltagePower: ElectricalPower;
    out item lowVoltagePowerStatus: ElectricalPower;
  }

  port def HighVoltagePowerPort {
    in item highVoltagePower: ElectricalPower;
  }

  port def HighVoltageOutputPort {
    out item highVoltagePower: ElectricalPower;
  }

  port def RawPulseOutputPort {
    out item rawPulse: AvalanchePulse;
  }

  port def RawPulseInputPort {
    in item rawPulse: AvalanchePulse;
  }

  port def LogicPulseOutputPort {
    out item logicPulse: ShapedLogicPulse;
  }

  port def LogicPulseInputPort {
    in item logicPulse: ShapedLogicPulse;
  }

  port def CountSamplePort {
    out item sample: CountSample;
  }

  port def DoseEstimatePort {
    out item dose: DoseEstimate;
  }

  port def UserIndicationPort {
    out item indication: UserIndication;
  }

  event def IncidentIonizingParticle;
  event def IonPairCreated;
  event def TownsendAvalancheStarted;
  event def GeigerDischargeQuenched;
  event def DeadTimeExpired;
  event def PulseAccepted;
  event def AlarmThresholdCrossed;
  event def BatteryLowDetected;

  action def ConvertRadiationToAvalanchePulse {
    in item radiation: IonizingRadiation;
    in operatingVoltage: Voltage_V;
    out item ionPair: GasIonPair;
    out item pulse: AvalanchePulse;
  }

  action def QuenchDischarge {
    in item pulse: AvalanchePulse;
    in quenchResistance: Resistance_MOhm;
    out recoveryTime: Duration_us;
  }

  action def ShapeAndDiscriminatePulse {
    in item rawPulse: AvalanchePulse;
    in threshold: Voltage_V;
    out item logicPulse: ShapedLogicPulse;
  }

  action def CountAcceptedPulse {
    in item logicPulse: ShapedLogicPulse;
    in previousCount: Count;
    out newCount: Count;
  }

  action def EstimateDoseRate {
    in countRate: CountRate_cps;
    in conversionFactor: DoseRate_uSvPerHour;
    out item dose: DoseEstimate;
  }

  action def ProduceUserIndication {
    in item sample: CountSample;
    in item dose: DoseEstimate;
    in alarmThreshold: DoseRate_uSvPerHour;
    out item indication: UserIndication;
  }

  state def GeigerMullerTubeEventCycle {
    entry; then Quiescent;

    state Quiescent {
      doc "Tube gas is non-conductive while high voltage bias establishes the electric field.";
    }

    state PrimaryIonization {
      doc "An incident ionizing particle or photon creates one or more ion pairs in the fill gas.";
    }

    state TownsendAvalanche {
      doc "Electrons accelerate toward the anode and create secondary ionization.";
    }

    state GeigerDischarge {
      doc "A saturated pulse is produced; pulse amplitude is substantially independent of incident particle energy.";
    }

    state DeadTime {
      doc "Positive ion sheath suppresses sensitivity immediately after discharge.";
    }

    state Recovery {
      doc "Field strength returns to the Geiger plateau and the tube becomes sensitive again.";
    }

    transition detectParticle
      first Quiescent
      accept IncidentIonizingParticle
      then PrimaryIonization;

    transition beginAvalanche
      first PrimaryIonization
      accept IonPairCreated
      then TownsendAvalanche;

    transition saturatedDischarge
      first TownsendAvalanche
      accept TownsendAvalancheStarted
      then GeigerDischarge;

    transition quench
      first GeigerDischarge
      accept GeigerDischargeQuenched
      then DeadTime;

    transition recover
      first DeadTime
      accept DeadTimeExpired
      then Recovery;

    transition readyAgain
      first Recovery
      then Quiescent;
  }

  state def MonitorOperatingMode {
    entry; then PowerOff;

    state PowerOff;
    state SelfTest;
    state HighVoltageRamp;
    state MeasuringBackground;
    state MeasuringRadiation;
    state Alarm;
    state FaultBatteryLow;

    transition powerApplied
      first PowerOff
      then SelfTest;

    transition selfTestPassed
      first SelfTest
      then HighVoltageRamp;

    transition highVoltageStable
      first HighVoltageRamp
      then MeasuringBackground;

    transition pulseDetected
      first MeasuringBackground
      accept PulseAccepted
      then MeasuringRadiation;

    transition backgroundStable
      first MeasuringRadiation
      then MeasuringBackground;

    transition alarmRaised
      first MeasuringRadiation
      accept AlarmThresholdCrossed
      then Alarm;

    transition alarmCleared
      first Alarm
      then MeasuringRadiation;

    transition batteryFault
      first MeasuringBackground
      accept BatteryLowDetected
      then FaultBatteryLow;
  }

  part def MicaWindow {
    attribute arealDensity: Real;
    attribute arealDensityUnit: String = "mg/cm^2";
    attribute effectiveDiameter: Real;
    attribute effectiveDiameterUnit: String = "mm";
  }

  part def InertFillGas {
    attribute gasMixture: String = "neon with halogen quench additive";
    attribute pressure: Pressure_kPa;
  }

  part def AnodeWire {
    attribute material: String = "tungsten";
    attribute diameter: Real;
    attribute diameterUnit: String = "um";
  }

  part def CathodeCylinder {
    attribute material: String = "stainless steel";
    attribute activeLength: Real;
    attribute activeLengthUnit: String = "mm";
  }

  part def GeigerMullerTube {
    doc "Primary transducer that converts ionizing radiation events into saturated electrical pulses.";

    port radiationIn: RadiationInputPort;
    port highVoltageIn: HighVoltagePowerPort;
    port pulseOut: RawPulseOutputPort;

    attribute nominalOperatingVoltage: Voltage_V;
    attribute plateauStartVoltage: Voltage_V;
    attribute plateauEndVoltage: Voltage_V;
    attribute deadTime: Duration_us;
    attribute recoveryTime: Duration_us;
    attribute backgroundRate: CountRate_cps;
    attribute maximumRecommendedRate: CountRate_cps;

    part window: MicaWindow {
      :>> arealDensity = 1.8;
      :>> effectiveDiameter = 9.0;
    }

    part fillGas: InertFillGas {
      :>> pressure.value = 13.3;
      :>> pressure.unit = "kPa";
    }

    part anode: AnodeWire {
      :>> diameter = 50.0;
    }

    part cathode: CathodeCylinder {
      :>> activeLength = 38.0;
    }

    perform action ionizationToPulse: ConvertRadiationToAvalanchePulse;
    perform action quenching: QuenchDischarge;
    exhibit state eventCycle: GeigerMullerTubeEventCycle;
  }

  part def QuenchResistor {
    port highVoltageIn: HighVoltagePowerPort;
    port biasedTubeOut: HighVoltageOutputPort;

    attribute resistance: Resistance_MOhm;
    attribute powerRating: Real;
    attribute powerRatingUnit: String = "W";
  }

  part def CouplingCapacitor {
    port rawPulseIn: RawPulseInputPort;
    port acPulseOut: RawPulseOutputPort;

    attribute capacitance: Capacitance_nF;
    attribute voltageRating: Voltage_V;
  }

  part def HighVoltageSupply {
    port lowVoltageIn: LowVoltagePowerPort;
    port highVoltageOut: HighVoltageOutputPort;

    attribute inputVoltage: Voltage_V;
    attribute regulatedOutputVoltage: Voltage_V;
    attribute outputCurrentLimit: Current_mA;
    attribute ripplePeakToPeak: Voltage_V;
    attribute startupTime: Duration_ms;
  }

  part def PulseShaper {
    port rawPulseIn: RawPulseInputPort;
    port logicPulseOut: LogicPulseOutputPort;

    attribute discriminatorThreshold: Voltage_V;
    attribute outputHighVoltage: Voltage_V;
    attribute minimumAcceptedWidth: Duration_us;
    attribute pulseStretchWidth: Duration_us;

    perform action shaping: ShapeAndDiscriminatePulse;
  }

  part def CounterController {
    port logicPulseIn: LogicPulseInputPort;
    port sampleOut: CountSamplePort;
    port doseOut: DoseEstimatePort;
    port indicationOut: UserIndicationPort;
    port powerIn: LowVoltagePowerPort;

    attribute sampleInterval: Duration_s;
    attribute totalCount: Count;
    attribute countRate: CountRate_cps;
    attribute tubeConversionFactor: DoseRate_uSvPerHour;
    attribute alarmThreshold: DoseRate_uSvPerHour;

    perform action countPulse: CountAcceptedPulse;
    perform action estimateDose: EstimateDoseRate;
    perform action prepareIndication: ProduceUserIndication;
    exhibit state operatingMode: MonitorOperatingMode;
  }

  part def Display {
    port indicationIn: UserIndicationPort;

    attribute refreshInterval: Duration_ms;
    attribute displayedUnits: String = "CPM and uSv/h";
  }

  part def AudibleAlarm {
    port indicationIn: UserIndicationPort;

    attribute normalClickDuration: Duration_ms;
    attribute alarmToneFrequency: Real;
    attribute alarmToneFrequencyUnit: String = "Hz";
  }

  part def BatteryPack {
    port lowVoltageOut: LowVoltagePowerPort;

    attribute nominalVoltage: Voltage_V;
    attribute capacity: Real;
    attribute capacityUnit: String = "mAh";
    attribute lowVoltageLimit: Voltage_V;
  }

  part def ShieldedEnclosure {
    port radiationAperture: RadiationInputPort;
    attribute material: String = "impact resistant polymer";
    attribute wallThickness: Real;
    attribute wallThicknessUnit: String = "mm";
  }

  part def GeigerMullerRadiationMonitor {
    doc "System whose primary high-level function is to detect ionizing radiation entering a Geiger-Muller tube, convert each detected event into an electrical pulse, count pulses over time, and report count rate and estimated dose rate to a user.";

    port radiationInput: RadiationInputPort;
    port userOutput: UserIndicationPort;

    attribute operatingTemperatureMin: Temperature_C;
    attribute operatingTemperatureMax: Temperature_C;
    attribute measurementRangeMin: DoseRate_uSvPerHour;
    attribute measurementRangeMax: DoseRate_uSvPerHour;
    attribute normalAlarmThreshold: DoseRate_uSvPerHour;

    part enclosure: ShieldedEnclosure {
      :>> wallThickness = 2.5;
    }

    part battery: BatteryPack {
      :>> nominalVoltage.value = 3.7;
      :>> nominalVoltage.unit = "V";
      :>> capacity = 2200.0;
      :>> lowVoltageLimit.value = 3.2;
      :>> lowVoltageLimit.unit = "V";
    }

    part highVoltageSupply: HighVoltageSupply {
      :>> inputVoltage.value = 3.7;
      :>> inputVoltage.unit = "V";
      :>> regulatedOutputVoltage.value = 400.0;
      :>> regulatedOutputVoltage.unit = "V";
      :>> outputCurrentLimit.value = 0.1;
      :>> outputCurrentLimit.unit = "mA";
      :>> ripplePeakToPeak.value = 2.0;
      :>> ripplePeakToPeak.unit = "V";
      :>> startupTime.value = 1500.0;
      :>> startupTime.unit = "ms";
    }

    part quenchResistor: QuenchResistor {
      :>> resistance.value = 5.6;
      :>> resistance.unit = "MOhm";
      :>> powerRating = 0.25;
    }

    part tube: GeigerMullerTube {
      :>> nominalOperatingVoltage.value = 400.0;
      :>> nominalOperatingVoltage.unit = "V";
      :>> plateauStartVoltage.value = 360.0;
      :>> plateauStartVoltage.unit = "V";
      :>> plateauEndVoltage.value = 460.0;
      :>> plateauEndVoltage.unit = "V";
      :>> deadTime.value = 190.0;
      :>> deadTime.unit = "us";
      :>> recoveryTime.value = 250.0;
      :>> recoveryTime.unit = "us";
      :>> backgroundRate.value = 0.33;
      :>> backgroundRate.unit = "count/s";
      :>> maximumRecommendedRate.value = 1000.0;
      :>> maximumRecommendedRate.unit = "count/s";
    }

    part couplingCapacitor: CouplingCapacitor {
      :>> capacitance.value = 4.7;
      :>> capacitance.unit = "nF";
      :>> voltageRating.value = 1000.0;
      :>> voltageRating.unit = "V";
    }

    part pulseShaper: PulseShaper {
      :>> discriminatorThreshold.value = 0.08;
      :>> discriminatorThreshold.unit = "V";
      :>> outputHighVoltage.value = 3.3;
      :>> outputHighVoltage.unit = "V";
      :>> minimumAcceptedWidth.value = 0.5;
      :>> minimumAcceptedWidth.unit = "us";
      :>> pulseStretchWidth.value = 100.0;
      :>> pulseStretchWidth.unit = "us";
    }

    part controller: CounterController {
      :>> sampleInterval.value = 1.0;
      :>> sampleInterval.unit = "s";
      :>> totalCount.value = 0;
      :>> totalCount.unit = "count";
      :>> countRate.value = 0.0;
      :>> countRate.unit = "count/s";
      :>> tubeConversionFactor.value = 0.0057;
      :>> tubeConversionFactor.unit = "uSv/h";
      :>> alarmThreshold.value = 0.5;
      :>> alarmThreshold.unit = "uSv/h";
    }

    part display: Display {
      :>> refreshInterval.value = 500.0;
      :>> refreshInterval.unit = "ms";
    }

    part audibleAlarm: AudibleAlarm {
      :>> normalClickDuration.value = 20.0;
      :>> normalClickDuration.unit = "ms";
      :>> alarmToneFrequency = 2400.0;
    }

    connect radiationInput to enclosure.radiationAperture;
    connect enclosure.radiationAperture to tube.radiationIn;
    connect battery.lowVoltageOut to highVoltageSupply.lowVoltageIn;
    connect battery.lowVoltageOut to controller.powerIn;
    connect highVoltageSupply.highVoltageOut to quenchResistor.highVoltageIn;
    connect quenchResistor.biasedTubeOut to tube.highVoltageIn;
    connect tube.pulseOut to couplingCapacitor.rawPulseIn;
    connect couplingCapacitor.acPulseOut to pulseShaper.rawPulseIn;
    connect pulseShaper.logicPulseOut to controller.logicPulseIn;
    connect controller.indicationOut to display.indicationIn;
    connect controller.indicationOut to audibleAlarm.indicationIn;
    connect controller.indicationOut to userOutput;
  }

  requirement def PrimaryFunctionRequirement {
    doc "The system shall perform the high-level function of detecting ionizing radiation using a Geiger-Muller tube and reporting a radiation level to the user.";
    subject monitor: GeigerMullerRadiationMonitor;

    require constraint {
      monitor.tube.nominalOperatingVoltage.value >= monitor.tube.plateauStartVoltage.value and
      monitor.tube.nominalOperatingVoltage.value <= monitor.tube.plateauEndVoltage.value
    }
  }

  requirement def PulseGenerationRequirement {
    doc "Each detectable ionizing event in the sensitive volume of the tube shall produce one raw avalanche pulse suitable for shaping and counting.";
    subject tube: GeigerMullerTube;

    require constraint {
      tube.deadTime.value > 0.0 and
      tube.recoveryTime.value >= tube.deadTime.value
    }
  }

  requirement def HighVoltageBiasRequirement {
    doc "The high voltage supply and quench path shall bias the tube in its Geiger plateau while limiting discharge current.";
    subject monitor: GeigerMullerRadiationMonitor;

    require constraint {
      monitor.highVoltageSupply.regulatedOutputVoltage.value == monitor.tube.nominalOperatingVoltage.value and
      monitor.quenchResistor.resistance.value >= 1.0
    }
  }

  requirement def CountRateMeasurementRequirement {
    doc "The controller shall count accepted logic pulses over a defined sampling interval and produce a count-rate sample.";
    subject controller: CounterController;

    require constraint {
      controller.sampleInterval.value >= 1.0 and
      controller.countRate.value >= 0.0
    }
  }

  requirement def DoseEstimateRequirement {
    doc "The controller shall estimate dose rate from measured count rate using the configured tube conversion factor.";
    subject controller: CounterController;

    require constraint {
      controller.tubeConversionFactor.value > 0.0
    }
  }

  requirement def UserAlarmRequirement {
    doc "The monitor shall provide an elevated or high alarm indication when the estimated dose rate exceeds the configured threshold.";
    subject monitor: GeigerMullerRadiationMonitor;

    require constraint {
      monitor.controller.alarmThreshold.value == monitor.normalAlarmThreshold.value
    }
  }

  requirement def MeasurementRangeRequirement {
    doc "The monitor shall cover a practical survey range from background radiation to elevated radiation fields without intentionally operating beyond the tube recommended count rate.";
    subject monitor: GeigerMullerRadiationMonitor;

    require constraint {
      monitor.measurementRangeMin.value >= 0.0 and
      monitor.measurementRangeMax.value > monitor.measurementRangeMin.value and
      monitor.tube.maximumRecommendedRate.value >= 1000.0
    }
  }

  part monitor: GeigerMullerRadiationMonitor {
    :>> operatingTemperatureMin.value = -10.0;
    :>> operatingTemperatureMin.unit = "degC";
    :>> operatingTemperatureMax.value = 50.0;
    :>> operatingTemperatureMax.unit = "degC";
    :>> measurementRangeMin.value = 0.05;
    :>> measurementRangeMin.unit = "uSv/h";
    :>> measurementRangeMax.value = 100.0;
    :>> measurementRangeMax.unit = "uSv/h";
    :>> normalAlarmThreshold.value = 0.5;
    :>> normalAlarmThreshold.unit = "uSv/h";
  }

  satisfy PrimaryFunctionRequirement by monitor;
  satisfy PulseGenerationRequirement by monitor.tube;
  satisfy HighVoltageBiasRequirement by monitor;
  satisfy CountRateMeasurementRequirement by monitor.controller;
  satisfy DoseEstimateRequirement by monitor.controller;
  satisfy UserAlarmRequirement by monitor;
  satisfy MeasurementRangeRequirement by monitor;
}
