package PellistorBasedCombustibleGasDetectionSystem {

  import ScalarValues::*;
  import SI::*;

  attribute def Voltage :> Real {
    unit = "V";
  }

  attribute def Current :> Real {
    unit = "mA";
  }

  attribute def Resistance :> Real {
    unit = "ohm";
  }

  attribute def Power :> Real {
    unit = "mW";
  }

  attribute def Temperature :> Real {
    unit = "degC";
  }

  attribute def TimeDuration :> Real {
    unit = "s";
  }

  attribute def GasConcentrationLEL :> Real {
    unit = "%LEL";
  }

  attribute def GasConcentrationPPM :> Real {
    unit = "ppm";
  }

  attribute def FlowRate :> Real {
    unit = "mL/min";
  }

  attribute def Frequency :> Real {
    unit = "Hz";
  }

  attribute def DigitalCount :> Integer;

  attribute def BooleanStatus :> Boolean;

  item def AmbientGasSample {
    attribute combustibleGasConcentration : GasConcentrationLEL;
    attribute methaneEquivalentConcentration : GasConcentrationPPM;
    attribute oxygenFraction : Real {
      unit = "%";
    }
    attribute humidity : Real {
      unit = "%RH";
    }
    attribute ambientTemperature : Temperature;
    attribute pressure : Real {
      unit = "kPa";
    }
  }

  item def FilteredGasSample :> AmbientGasSample {
    attribute dustRemoved : BooleanStatus;
    attribute liquidDropletRemoved : BooleanStatus;
  }

  item def ElectricalPower {
    attribute voltage : Voltage;
    attribute current : Current;
    attribute availablePower : Power;
  }

  item def HeatedBeadThermalState {
    attribute beadTemperature : Temperature;
    attribute heaterPower : Power;
    attribute beadResistance : Resistance;
  }

  item def BridgeAnalogSignal {
    attribute differentialVoltage : Voltage;
    attribute commonModeVoltage : Voltage;
    attribute bridgeExcitationVoltage : Voltage;
    attribute bridgeCurrent : Current;
  }

  item def AmplifiedAnalogSignal {
    attribute outputVoltage : Voltage;
    attribute gain : Real;
    attribute bandwidth : Frequency;
  }

  item def DigitalGasMeasurement {
    attribute concentration : GasConcentrationLEL;
    attribute rawAdcCount : DigitalCount;
    attribute temperatureCompensated : BooleanStatus;
    attribute valid : BooleanStatus;
    attribute timestamp : TimeDuration;
  }

  item def AlarmCommand {
    attribute alarmActive : BooleanStatus;
    attribute alarmLevel : Integer;
    attribute latched : BooleanStatus;
    attribute concentrationAtAlarm : GasConcentrationLEL;
  }

  item def DiagnosticReport {
    attribute sensorOpenCircuit : BooleanStatus;
    attribute sensorShortCircuit : BooleanStatus;
    attribute bridgeImbalanceFault : BooleanStatus;
    attribute insufficientOxygenFault : BooleanStatus;
    attribute heaterControlFault : BooleanStatus;
    attribute calibrationDue : BooleanStatus;
    attribute measurementValid : BooleanStatus;
  }

  port def GasIntakePort {
    in item sample : AmbientGasSample;
  }

  port def GasDiffusionPort {
    in item sampleIn : AmbientGasSample;
    out item sampleOut : FilteredGasSample;
  }

  port def PowerInputPort {
    in item power : ElectricalPower;
  }

  port def RegulatedPowerPort {
    out item power : ElectricalPower;
  }

  port def HeaterPowerPort {
    in item powerIn : ElectricalPower;
  }

  port def BeadThermalPort {
    out item thermalState : HeatedBeadThermalState;
  }

  port def BridgeSignalPort {
    out item signal : BridgeAnalogSignal;
  }

  port def AnalogSignalPort {
    in item analogIn : BridgeAnalogSignal;
    out item analogOut : AmplifiedAnalogSignal;
  }

  port def AdcInputPort {
    in item analogSignal : AmplifiedAnalogSignal;
    out item digitalCount : DigitalCount;
  }

  port def MeasurementPort {
    out item measurement : DigitalGasMeasurement;
  }

  port def AlarmOutputPort {
    out item alarm : AlarmCommand;
  }

  port def DiagnosticPort {
    out item diagnostic : DiagnosticReport;
  }

  port def UserCalibrationPort {
    in item zeroGasSample : AmbientGasSample;
    in item spanGasSample : AmbientGasSample;
  }

  action def CatalyticOxidation {
    in item gas : FilteredGasSample;
    in item activeBeadState : HeatedBeadThermalState;
    out item heatedState : HeatedBeadThermalState;

    attribute minimumOperatingTemperature : Temperature = 450.0;
    attribute nominalOperatingTemperature : Temperature = 500.0;
    attribute reactionHeatGainPerLEL : Power = 0.85;
  }

  action def ReferenceCompensation {
    in item activeState : HeatedBeadThermalState;
    in item referenceState : HeatedBeadThermalState;
    out item differentialBridgeSignal : BridgeAnalogSignal;

    attribute ambientCancellationEnabled : BooleanStatus = true;
  }

  action def ConvertBridgeSignalToGasConcentration {
    in item bridgeSignal : BridgeAnalogSignal;
    out item gasMeasurement : DigitalGasMeasurement;

    attribute zeroOffsetVoltage : Voltage = 0.000;
    attribute sensitivity : Real {
      unit = "mV/%LEL";
    } = 1.25;
    attribute measurementRange : GasConcentrationLEL = 100.0;
  }

  action def ExecuteAlarmDecision {
    in item measurement : DigitalGasMeasurement;
    out item command : AlarmCommand;

    attribute lowAlarmThreshold : GasConcentrationLEL = 20.0;
    attribute highAlarmThreshold : GasConcentrationLEL = 50.0;
    attribute alarmHysteresis : GasConcentrationLEL = 2.0;
  }

  action def PerformSelfDiagnostics {
    in item activeState : HeatedBeadThermalState;
    in item referenceState : HeatedBeadThermalState;
    in item bridgeSignal : BridgeAnalogSignal;
    out item diagnostic : DiagnosticReport;

    attribute openCircuitResistanceThreshold : Resistance = 20.0;
    attribute shortCircuitResistanceThreshold : Resistance = 0.5;
    attribute maximumBridgeOffsetAtZeroGas : Voltage = 0.020;
  }

  action def CalibratePellistor {
    in item zeroGas : AmbientGasSample;
    in item spanGas : AmbientGasSample;
    out item updatedMeasurementModel : DigitalGasMeasurement;

    attribute spanGasConcentration : GasConcentrationLEL = 50.0;
    attribute zeroStabilityTime : TimeDuration = 30.0;
    attribute spanStabilityTime : TimeDuration = 60.0;
  }

  state def PellistorDetectorOperationalState {
    entry action initializeElectronics;
    state Off;
    state WarmUp;
    state ZeroStabilization;
    state Measuring;
    state AlarmLow;
    state AlarmHigh;
    state Fault;
    state Calibration;

    transition initial then Off;

    transition powerApplied
      first Off
      then WarmUp;

    transition warmUpComplete
      first WarmUp
      then ZeroStabilization;

    transition zeroStable
      first ZeroStabilization
      then Measuring;

    transition lowAlarmDetected
      first Measuring
      then AlarmLow;

    transition highAlarmDetected
      first Measuring
      then AlarmHigh;

    transition lowAlarmCleared
      first AlarmLow
      then Measuring;

    transition highAlarmReduced
      first AlarmHigh
      then AlarmLow;

    transition highAlarmCleared
      first AlarmHigh
      then Measuring;

    transition calibrationRequested
      first Measuring
      then Calibration;

    transition calibrationComplete
      first Calibration
      then Measuring;

    transition diagnosticFaultDetected
      first WarmUp
      then Fault;

    transition diagnosticFaultDetectedFromMeasuring
      first Measuring
      then Fault;

    transition resetAfterFault
      first Fault
      then WarmUp;
  }

  part def FlameArrestor {
    port environmentPort : GasIntakePort;
    port protectedPort : GasDiffusionPort;

    attribute meshMaterial : String = "316 stainless steel";
    attribute maximumPoreSize : Real {
      unit = "mm";
    } = 0.25;
    attribute flameTransmissionPrevented : BooleanStatus = true;
    attribute nominalDiffusionFlow : FlowRate = 120.0;
  }

  part def GasDiffusionChamber {
    port inlet : GasDiffusionPort;
    port beadExposure : GasDiffusionPort;

    attribute chamberVolume : Real {
      unit = "cm^3";
    } = 1.8;
    attribute responseTimeT50 : TimeDuration = 6.0;
    attribute responseTimeT90 : TimeDuration = 15.0;
  }

  part def ActiveCatalyticBead {
    port heaterPower : HeaterPowerPort;
    port gasExposure : GasDiffusionPort;
    port thermalOutput : BeadThermalPort;

    attribute catalystMaterial : String = "platinum-palladium";
    attribute beadSubstrate : String = "alumina";
    attribute nominalResistanceAt20C : Resistance = 2.5;
    attribute operatingResistance : Resistance = 3.8;
    attribute nominalOperatingTemperature : Temperature = 500.0;
    attribute maximumSafeTemperature : Temperature = 650.0;
    attribute nominalHeaterPower : Power = 420.0;

    perform action oxidation : CatalyticOxidation;
  }

  part def ReferenceBead {
    port heaterPower : HeaterPowerPort;
    port gasExposure : GasDiffusionPort;
    port thermalOutput : BeadThermalPort;

    attribute coatingMaterial : String = "inert glass";
    attribute beadSubstrate : String = "alumina";
    attribute nominalResistanceAt20C : Resistance = 2.5;
    attribute operatingResistance : Resistance = 3.8;
    attribute nominalOperatingTemperature : Temperature = 500.0;
    attribute catalyticActivitySuppressed : BooleanStatus = true;
    attribute nominalHeaterPower : Power = 420.0;
  }

  part def WheatstoneBridge {
    port activeBeadThermalInput : BeadThermalPort;
    port referenceBeadThermalInput : BeadThermalPort;
    port excitationPower : HeaterPowerPort;
    port bridgeOutput : BridgeSignalPort;

    attribute excitationVoltage : Voltage = 2.50;
    attribute nominalBridgeCurrent : Current = 180.0;
    attribute fixedArmResistanceA : Resistance = 3.8;
    attribute fixedArmResistanceB : Resistance = 3.8;
    attribute zeroGasOffsetVoltage : Voltage = 0.000;
    attribute fullScaleDifferentialVoltage : Voltage = 0.125;

    perform action compensation : ReferenceCompensation;
  }

  part def ConstantPowerHeaterController {
    port supplyInput : PowerInputPort;
    port beadPowerOutput : RegulatedPowerPort;
    port bridgeExcitationOutput : RegulatedPowerPort;
    port diagnosticOutput : DiagnosticPort;

    attribute inputVoltageMinimum : Voltage = 18.0;
    attribute inputVoltageNominal : Voltage = 24.0;
    attribute inputVoltageMaximum : Voltage = 30.0;
    attribute regulatedBridgeVoltage : Voltage = 2.50;
    attribute maximumHeaterCurrent : Current = 250.0;
    attribute heaterPowerStability : Real {
      unit = "%";
    } = 1.0;
  }

  part def InstrumentationAmplifier {
    port bridgeInput : AnalogSignalPort;
    port amplifiedOutput : AnalogSignalPort;

    attribute gain : Real = 40.0;
    attribute inputOffsetVoltage : Voltage = 0.001;
    attribute outputRangeMinimum : Voltage = 0.10;
    attribute outputRangeMaximum : Voltage = 4.90;
    attribute lowPassCutoff : Frequency = 5.0;
  }

  part def AnalogToDigitalConverter {
    port analogInput : AdcInputPort;
    port digitalOutput : MeasurementPort;

    attribute resolution : Integer = 16;
    attribute referenceVoltage : Voltage = 5.0;
    attribute sampleRate : Frequency = 10.0;
    attribute leastSignificantBit : Voltage = 0.000076;
  }

  part def Microcontroller {
    port adcMeasurementInput : MeasurementPort;
    port calibrationInput : UserCalibrationPort;
    port measurementOutput : MeasurementPort;
    port alarmOutput : AlarmOutputPort;
    port diagnosticOutput : DiagnosticPort;

    attribute firmwareName : String = "Pellistor combustible gas detection control";
    attribute measurementUpdateRate : Frequency = 2.0;
    attribute warmUpTime : TimeDuration = 120.0;
    attribute zeroTrackingLimit : GasConcentrationLEL = 2.0;
    attribute measurementRangeMinimum : GasConcentrationLEL = 0.0;
    attribute measurementRangeMaximum : GasConcentrationLEL = 100.0;
    attribute lowAlarmThreshold : GasConcentrationLEL = 20.0;
    attribute highAlarmThreshold : GasConcentrationLEL = 50.0;
    attribute overRangeThreshold : GasConcentrationLEL = 105.0;

    perform action conversion : ConvertBridgeSignalToGasConcentration;
    perform action alarmDecision : ExecuteAlarmDecision;
    perform action diagnostics : PerformSelfDiagnostics;
    perform action calibration : CalibratePellistor;

    exhibit state operationalState : PellistorDetectorOperationalState;
  }

  part def LocalAlarmAnnunciator {
    port commandInput : AlarmOutputPort;

    attribute audibleSoundLevel : Real {
      unit = "dBA";
    } = 85.0;
    attribute redVisualAlarmEnabled : BooleanStatus = true;
    attribute amberFaultIndicatorEnabled : BooleanStatus = true;
    attribute alarmLatchEnabled : BooleanStatus = true;
  }

  part def MeasurementCommunicationInterface {
    port measurementInput : MeasurementPort;
    port diagnosticInput : DiagnosticPort;
    port alarmInput : AlarmOutputPort;
    port externalMeasurementOutput : MeasurementPort;
    port externalDiagnosticOutput : DiagnosticPort;
    port externalAlarmOutput : AlarmOutputPort;

    attribute interfaceType : String = "4-20 mA plus digital diagnostic channel";
    attribute analogCurrentAtZero : Current = 4.0;
    attribute analogCurrentAtFullScale : Current = 20.0;
    attribute faultCurrent : Current = 3.6;
    attribute overRangeCurrent : Current = 22.0;
  }

  part def PellistorSensorHead {
    port gasInput : GasIntakePort;
    port heaterPowerInput : PowerInputPort;
    port bridgeSignalOutput : BridgeSignalPort;
    port diagnosticOutput : DiagnosticPort;

    part flameArrestor : FlameArrestor;
    part chamber : GasDiffusionChamber;
    part activeBead : ActiveCatalyticBead;
    part referenceBead : ReferenceBead;
    part bridge : WheatstoneBridge;

    connect gasInput to flameArrestor.environmentPort;
    connect flameArrestor.protectedPort to chamber.inlet;
    connect chamber.beadExposure to activeBead.gasExposure;
    connect chamber.beadExposure to referenceBead.gasExposure;

    connect heaterPowerInput to activeBead.heaterPower;
    connect heaterPowerInput to referenceBead.heaterPower;
    connect heaterPowerInput to bridge.excitationPower;

    connect activeBead.thermalOutput to bridge.activeBeadThermalInput;
    connect referenceBead.thermalOutput to bridge.referenceBeadThermalInput;
    connect bridge.bridgeOutput to bridgeSignalOutput;

    attribute primarySensingPrinciple : String =
      "combustible gas oxidizes on the heated catalytic bead; the resulting temperature and resistance rise is measured against an inert reference bead";
  }

  part def PellistorGasDetectorSystem {
    port ambientGasInlet : GasIntakePort;
    port dcPowerInput : PowerInputPort;
    port gasMeasurementOutput : MeasurementPort;
    port alarmCommandOutput : AlarmOutputPort;
    port diagnosticReportOutput : DiagnosticPort;
    port calibrationPort : UserCalibrationPort;

    part heaterController : ConstantPowerHeaterController;
    part sensorHead : PellistorSensorHead;
    part amplifier : InstrumentationAmplifier;
    part adc : AnalogToDigitalConverter;
    part controller : Microcontroller;
    part annunciator : LocalAlarmAnnunciator;
    part communicationInterface : MeasurementCommunicationInterface;

    connect ambientGasInlet to sensorHead.gasInput;
    connect dcPowerInput to heaterController.supplyInput;
    connect heaterController.beadPowerOutput to sensorHead.heaterPowerInput;

    connect sensorHead.bridgeSignalOutput to amplifier.bridgeInput;
    connect amplifier.amplifiedOutput to adc.analogInput;
    connect adc.digitalOutput to controller.adcMeasurementInput;

    connect calibrationPort to controller.calibrationInput;
    connect controller.measurementOutput to gasMeasurementOutput;
    connect controller.alarmOutput to alarmCommandOutput;
    connect controller.diagnosticOutput to diagnosticReportOutput;

    connect controller.alarmOutput to annunciator.commandInput;

    connect controller.measurementOutput to communicationInterface.measurementInput;
    connect controller.diagnosticOutput to communicationInterface.diagnosticInput;
    connect controller.alarmOutput to communicationInterface.alarmInput;
    connect communicationInterface.externalMeasurementOutput to gasMeasurementOutput;
    connect communicationInterface.externalDiagnosticOutput to diagnosticReportOutput;
    connect communicationInterface.externalAlarmOutput to alarmCommandOutput;

    attribute primaryFunction : String =
      "Detect combustible gas in the surrounding atmosphere by maintaining a heated pellistor pair, comparing the catalytic bead response with an inert reference bead, converting bridge imbalance into gas concentration in percent lower explosive limit, and issuing measurement, alarm, and diagnostic outputs.";

    attribute supportedGasReference : String = "methane equivalent";
    attribute measurementRange : GasConcentrationLEL = 100.0;
    attribute nominalSupplyVoltage : Voltage = 24.0;
    attribute expectedServiceLife : Real {
      unit = "year";
    } = 5.0;
  }

  requirement def PrimaryFunctionRequirement {
    subject detector : PellistorGasDetectorSystem;

    doc
      /* The detector shall provide high-level combustible-gas detection using a pellistor catalytic bead and an inert reference bead. */

    require constraint {
      detector.measurementRange >= 100.0
    }
  }

  requirement def CatalyticDetectionRequirement {
    subject sensorHead : PellistorSensorHead;

    doc
      /* The sensor head shall expose both active and reference beads to the same filtered atmosphere while only the active bead provides catalytic oxidation response to combustible gas. */

    require constraint {
      sensorHead.activeBead.nominalOperatingTemperature >= 450.0 and
      sensorHead.referenceBead.catalyticActivitySuppressed == true
    }
  }

  requirement def BridgeMeasurementRequirement {
    subject bridge : WheatstoneBridge;

    doc
      /* The Wheatstone bridge shall convert differential resistance change between active and reference beads into a differential voltage suitable for amplification. */

    require constraint {
      bridge.excitationVoltage >= 2.0 and
      bridge.excitationVoltage <= 3.0 and
      bridge.fullScaleDifferentialVoltage >= 0.100
    }
  }

  requirement def MeasurementRangeRequirement {
    subject detector : PellistorGasDetectorSystem;

    doc
      /* The detector shall report methane-equivalent combustible gas concentration from 0 to 100 percent lower explosive limit. */

    require constraint {
      detector.measurementRange == 100.0
    }
  }

  requirement def WarmUpRequirement {
    subject controller : Microcontroller;

    doc
      /* The controller shall inhibit normal measurement until the pellistor beads have reached stable operating temperature after power application. */

    require constraint {
      controller.warmUpTime <= 180.0
    }
  }

  requirement def AlarmRequirement {
    subject controller : Microcontroller;

    doc
      /* The controller shall generate low and high alarm commands when compensated gas concentration exceeds configured thresholds. */

    require constraint {
      controller.lowAlarmThreshold == 20.0 and
      controller.highAlarmThreshold == 50.0 and
      controller.highAlarmThreshold > controller.lowAlarmThreshold
    }
  }

  requirement def DiagnosticRequirement {
    subject controller : Microcontroller;

    doc
      /* The detector shall report faults for open sensor, shorted sensor, heater-control failure, excessive bridge imbalance, invalid measurement, and calibration due conditions. */

    require constraint {
      controller.measurementUpdateRate >= 1.0
    }
  }

  requirement def FlameSafetyRequirement {
    subject arrestor : FlameArrestor;

    doc
      /* The flame arrestor shall allow ambient gas diffusion to the pellistor while preventing flame propagation from the heated beads to the external atmosphere. */

    require constraint {
      arrestor.flameTransmissionPrevented == true and
      arrestor.maximumPoreSize <= 0.25
    }
  }

  requirement def OutputInterfaceRequirement {
    subject communicationInterface : MeasurementCommunicationInterface;

    doc
      /* The detector shall provide external measurement, alarm, and diagnostic outputs for integration with a gas safety controller. */

    require constraint {
      communicationInterface.analogCurrentAtZero == 4.0 and
      communicationInterface.analogCurrentAtFullScale == 20.0 and
      communicationInterface.faultCurrent < communicationInterface.analogCurrentAtZero
    }
  }

  satisfy PrimaryFunctionRequirement by PellistorGasDetectorSystem;
  satisfy CatalyticDetectionRequirement by PellistorSensorHead;
  satisfy BridgeMeasurementRequirement by WheatstoneBridge;
  satisfy MeasurementRangeRequirement by PellistorGasDetectorSystem;
  satisfy WarmUpRequirement by Microcontroller;
  satisfy AlarmRequirement by Microcontroller;
  satisfy DiagnosticRequirement by Microcontroller;
  satisfy FlameSafetyRequirement by FlameArrestor;
  satisfy OutputInterfaceRequirement by MeasurementCommunicationInterface;

}
