package PressureGaugeSystemModel {

  import ScalarValues::*;

  attribute def Pressure_kPa :> Real {
    doc "Pressure expressed in kilopascals.";
  }

  attribute def Pressure_MPa :> Real {
    doc "Pressure expressed in megapascals.";
  }

  attribute def Temperature_degC :> Real {
    doc "Temperature expressed in degrees Celsius.";
  }

  attribute def Angle_deg :> Real {
    doc "Angular displacement expressed in degrees.";
  }

  attribute def Length_mm :> Real {
    doc "Linear displacement expressed in millimeters.";
  }

  attribute def Torque_Nmm :> Real {
    doc "Torque expressed in newton millimeters.";
  }

  attribute def Time_s :> Real {
    doc "Time expressed in seconds.";
  }

  attribute def Percent :> Real {
    doc "Percent of full scale.";
  }

  attribute def FlowRate_Lpm :> Real {
    doc "Flow rate expressed in liters per minute.";
  }

  attribute def Frequency_Hz :> Real {
    doc "Frequency expressed in hertz.";
  }

  enum def GaugeHealthKind {
    enum nominal;
    enum degraded;
    enum overrange;
    enum blocked;
    enum leaking;
    enum calibrationDue;
    enum failed;
  }

  enum def PointerVisibilityKind {
    enum visible;
    enum obscured;
  }

  enum def ProcessFluidKind {
    enum air;
    enum nitrogen;
    enum hydraulicOil;
    enum water;
    enum steam;
    enum naturalGas;
  }

  enum def MountingOrientationKind {
    enum verticalDial;
    enum horizontalDial;
    enum panelMounted;
    enum pipeMounted;
  }

  item def PressurizedFluid {
    attribute kind: ProcessFluidKind;
    attribute gaugePressure: Pressure_kPa;
    attribute absolutePressure: Pressure_kPa;
    attribute temperature: Temperature_degC;
    attribute pulsationFrequency: Frequency_Hz;
    attribute flowRateThroughTap: FlowRate_Lpm;
  }

  item def PressureImpulse {
    attribute pressure: Pressure_kPa;
    attribute temperature: Temperature_degC;
    attribute duration: Time_s;
  }

  item def LinearDeflection {
    attribute displacement: Length_mm;
    attribute proportionalPressure: Pressure_kPa;
  }

  item def RotaryMotion {
    attribute angle: Angle_deg;
    attribute torque: Torque_Nmm;
  }

  item def PressureIndication {
    attribute indicatedPressure: Pressure_kPa;
    attribute pointerAngle: Angle_deg;
    attribute percentOfSpan: Percent;
    attribute visibility: PointerVisibilityKind;
    attribute health: GaugeHealthKind;
  }

  item def DiagnosticReport {
    attribute health: GaugeHealthKind;
    attribute lastObservedPressure: Pressure_kPa;
    attribute pointerZeroOffset: Pressure_kPa;
    attribute elapsedTimeSinceCalibration: Time_s;
    attribute overrangeEvents: Integer;
  }

  item def CalibrationCommand {
    attribute targetPressure: Pressure_kPa;
    attribute holdTime: Time_s;
  }

  port def ProcessPressurePort {
    in item medium: PressurizedFluid;
    in item pressurePulse: PressureImpulse;
  }

  port def SensingPressurePort {
    in item medium: PressurizedFluid;
    in item pressurePulse: PressureImpulse;
  }

  port def DeflectionOutputPort {
    out item deflection: LinearDeflection;
  }

  port def DeflectionInputPort {
    in item deflection: LinearDeflection;
  }

  port def RotaryOutputPort {
    out item rotation: RotaryMotion;
  }

  port def RotaryInputPort {
    in item rotation: RotaryMotion;
  }

  port def IndicationOutputPort {
    out item indication: PressureIndication;
  }

  port def DiagnosticPort {
    out item report: DiagnosticReport;
    in item command: CalibrationCommand;
  }

  port def VentPort {
    out item ventedFluid: PressurizedFluid;
  }

  constraint def PressureRangeConstraint {
    in p: Pressure_kPa;
    in minimum: Pressure_kPa;
    in maximum: Pressure_kPa;
    require p >= minimum and p <= maximum;
  }

  constraint def AccuracyConstraint {
    in actualPressure: Pressure_kPa;
    in indicatedPressure: Pressure_kPa;
    in fullScaleSpan: Pressure_kPa;
    in accuracyClass: Percent;
    require indicatedPressure <= actualPressure + fullScaleSpan * accuracyClass / 100.0;
    require indicatedPressure >= actualPressure - fullScaleSpan * accuracyClass / 100.0;
  }

  constraint def OverrangeProtectionConstraint {
    in processPressure: Pressure_kPa;
    in fullScalePressure: Pressure_kPa;
    in proofPressure: Pressure_kPa;
    require proofPressure >= fullScalePressure * 1.30;
    require processPressure <= proofPressure;
  }

  constraint def ReadabilityConstraint {
    in pointerAngle: Angle_deg;
    in minimumReadableAngle: Angle_deg;
    in maximumReadableAngle: Angle_deg;
    require pointerAngle >= minimumReadableAngle;
    require pointerAngle <= maximumReadableAngle;
  }

  part def ProcessConnection {
    attribute nominalLinePressure: Pressure_kPa = 700.0;
    attribute maximumLinePressure: Pressure_kPa = 1000.0;
    attribute fluidKind: ProcessFluidKind = ProcessFluidKind::water;
    attribute tappingOrificeDiameter: Length_mm = 1.5;
    port tap: ProcessPressurePort;
  }

  part def Snubber {
    doc "Restricts rapid pressure pulsations to protect the sensing element and stabilize the displayed reading.";
    attribute restrictionDiameter: Length_mm = 0.35;
    attribute dampingTimeConstant: Time_s = 0.8;
    attribute maximumAllowedFlow: FlowRate_Lpm = 0.2;
    port processSide: ProcessPressurePort;
    port gaugeSide: SensingPressurePort;

    action dampPulsation {
      in item incoming: PressureImpulse;
      out item damped: PressureImpulse;
    }
  }

  part def BourdonTube {
    doc "Elastic pressure sensing element that converts pressure into mechanical tip deflection.";
    attribute materialAllowablePressure: Pressure_kPa = 1600.0;
    attribute minimumPressure: Pressure_kPa = 0.0;
    attribute fullScalePressure: Pressure_kPa = 1000.0;
    attribute proofPressure: Pressure_kPa = 1300.0;
    attribute burstPressure: Pressure_kPa = 4000.0;
    attribute nominalTipTravelAtFullScale: Length_mm = 4.2;
    attribute temperatureCoefficient: Percent = 0.04;
    port pressurePort: SensingPressurePort;
    port deflectionPort: DeflectionOutputPort;

    constraint operatingRange: PressureRangeConstraint {
      in p = pressurePort.medium.gaugePressure;
      in minimum = minimumPressure;
      in maximum = proofPressure;
    }

    action def convertPressureToDeflection {
      in item sensedFluid: PressurizedFluid;
      out item tubeDeflection: LinearDeflection;
    }
  }

  part def MechanicalLinkage {
    doc "Amplifies Bourdon tube tip deflection and converts it into rotary motion.";
    attribute sectorGearRatio: Real = 18.0;
    attribute linkLength: Length_mm = 24.0;
    attribute backlashAngle: Angle_deg = 0.4;
    attribute frictionTorque: Torque_Nmm = 1.2;
    port inputDeflection: DeflectionInputPort;
    port outputRotation: RotaryOutputPort;

    action amplifyAndConvert {
      in item deflection: LinearDeflection;
      out item rotation: RotaryMotion;
    }
  }

  part def Pointer {
    doc "Visual pointer that rotates over the dial scale.";
    attribute pointerLength: Length_mm = 42.0;
    attribute massBalanceOffset: Length_mm = 0.2;
    attribute zeroStopAngle: Angle_deg = -2.0;
    attribute fullScaleAngle: Angle_deg = 270.0;
    port rotationInput: RotaryInputPort;
    port indicationOutput: IndicationOutputPort;

    action positionPointer {
      in item rotation: RotaryMotion;
      out item indication: PressureIndication;
    }
  }

  part def DialFace {
    doc "Fixed scale that maps pointer angle to pressure value.";
    attribute minimumScalePressure: Pressure_kPa = 0.0;
    attribute maximumScalePressure: Pressure_kPa = 1000.0;
    attribute majorGraduation: Pressure_kPa = 100.0;
    attribute minorGraduation: Pressure_kPa = 20.0;
    attribute scaleArc: Angle_deg = 270.0;
    attribute minimumReadableAngle: Angle_deg = 0.0;
    attribute maximumReadableAngle: Angle_deg = 270.0;
  }

  part def CaseVent {
    doc "Provides safe case pressure relief if the sensing element leaks.";
    attribute ventOpeningPressure: Pressure_kPa = 20.0;
    attribute ventArea: Length_mm = 18.0;
    port vent: VentPort;
  }

  part def GaugeHousing {
    doc "Mechanical enclosure supporting the dial, sensing element, window, and process connection.";
    attribute windowDiameter: Length_mm = 63.0;
    attribute caseDiameter: Length_mm = 80.0;
    attribute ingressProtectionRating: String = "IP54";
    attribute mountingOrientation: MountingOrientationKind = MountingOrientationKind::verticalDial;
    part vent: CaseVent;
  }

  action def SenseProcessPressure {
    in item processFluid: PressurizedFluid;
    out item sensedFluid: PressurizedFluid;
  }

  action def ConvertPressureToDeflection {
    in item sensedFluid: PressurizedFluid;
    out item deflection: LinearDeflection;
  }

  action def ConvertDeflectionToRotation {
    in item deflection: LinearDeflection;
    out item rotation: RotaryMotion;
  }

  action def DisplayPressure {
    in item rotation: RotaryMotion;
    out item indication: PressureIndication;
  }

  action def GenerateDiagnostics {
    in item indication: PressureIndication;
    out item report: DiagnosticReport;
  }

  action def MeasureAndDisplayPressure {
    doc "Primary behavior: accept process pressure, convert it mechanically, and provide a local visual pressure indication.";
    in item processFluid: PressurizedFluid;
    out item localReading: PressureIndication;
    out item diagnosticReport: DiagnosticReport;

    action sense: SenseProcessPressure {
      in processFluid = processFluid;
    }

    action convert: ConvertPressureToDeflection {
      in sensedFluid = sense.sensedFluid;
    }

    action amplify: ConvertDeflectionToRotation {
      in deflection = convert.deflection;
    }

    action display: DisplayPressure {
      in rotation = amplify.rotation;
    }

    action diagnose: GenerateDiagnostics {
      in indication = display.indication;
    }

    flow sense.sensedFluid to convert.sensedFluid;
    flow convert.deflection to amplify.deflection;
    flow amplify.rotation to display.rotation;
    flow display.indication to diagnose.indication;
    flow display.indication to localReading;
    flow diagnose.report to diagnosticReport;
  }

  state def PressureGaugeStateMachine {
    attribute currentPressure: Pressure_kPa;
    attribute health: GaugeHealthKind;

    state uninstalled;
    state installed;
    state zeroed;
    state measuring;
    state overrangeProtected;
    state blockedInput;
    state leaking;
    state calibrationRequired;
    state failed;

    transition initial then uninstalled;

    transition install
      first uninstalled
      then installed;

    transition verifyZero
      first installed
      then zeroed;

    transition applyPressure
      first zeroed
      then measuring;

    transition pressureRemoved
      first measuring
      then zeroed;

    transition overrangeDetected
      first measuring
      then overrangeProtected;

    transition pressureReturnsWithinRange
      first overrangeProtected
      then measuring;

    transition noResponseToPressure
      first measuring
      then blockedInput;

    transition leakDetected
      first measuring
      then leaking;

    transition calibrationIntervalExpired
      first measuring
      then calibrationRequired;

    transition recalibrated
      first calibrationRequired
      then zeroed;

    transition unrecoverableFault
      first blockedInput
      then failed;

    transition ventedLeakFault
      first leaking
      then failed;
  }

  part def PressureGauge {
    doc "Local mechanical pressure gauge whose primary function is to sense process pressure and present a readable pressure value to an operator.";
    attribute minimumPressure: Pressure_kPa = 0.0;
    attribute fullScalePressure: Pressure_kPa = 1000.0;
    attribute proofPressure: Pressure_kPa = 1300.0;
    attribute accuracyClass: Percent = 1.6;
    attribute repeatability: Percent = 0.5;
    attribute responseTime: Time_s = 1.5;
    attribute calibrationInterval: Time_s = 31536000.0;
    attribute operatingTemperatureMinimum: Temperature_degC = -20.0;
    attribute operatingTemperatureMaximum: Temperature_degC = 60.0;
    attribute health: GaugeHealthKind = GaugeHealthKind::nominal;

    port processPort: ProcessPressurePort;
    port indicationPort: IndicationOutputPort;
    port maintenancePort: DiagnosticPort;

    part snubber: Snubber;
    part sensingElement: BourdonTube;
    part linkage: MechanicalLinkage;
    part pointer: Pointer;
    part dial: DialFace;
    part housing: GaugeHousing;

    perform action primaryFunction: MeasureAndDisplayPressure;

    exhibit state lifecycle: PressureGaugeStateMachine;

    connect processPort to snubber.processSide;
    connect snubber.gaugeSide to sensingElement.pressurePort;
    connect sensingElement.deflectionPort to linkage.inputDeflection;
    connect linkage.outputRotation to pointer.rotationInput;
    connect pointer.indicationOutput to indicationPort;

    constraint pressureWithinGaugeRange: PressureRangeConstraint {
      in p = processPort.medium.gaugePressure;
      in minimum = minimumPressure;
      in maximum = proofPressure;
    }

    constraint indicationAccuracy: AccuracyConstraint {
      in actualPressure = processPort.medium.gaugePressure;
      in indicatedPressure = indicationPort.indication.indicatedPressure;
      in fullScaleSpan = fullScalePressure - minimumPressure;
      in accuracyClass = accuracyClass;
    }

    constraint overrangeProtection: OverrangeProtectionConstraint {
      in processPressure = processPort.medium.gaugePressure;
      in fullScalePressure = fullScalePressure;
      in proofPressure = proofPressure;
    }

    constraint readableDialArc: ReadabilityConstraint {
      in pointerAngle = indicationPort.indication.pointerAngle;
      in minimumReadableAngle = dial.minimumReadableAngle;
      in maximumReadableAngle = dial.maximumReadableAngle;
    }
  }

  part def Operator {
    doc "Human user who observes the local gauge indication.";
    port observedIndication: IndicationOutputPort;
  }

  part def PressureGaugeAssembly {
    doc "System based on a pressure gauge for local monitoring of process pressure.";
    attribute designPressure: Pressure_kPa = 1000.0;
    attribute normalOperatingPressure: Pressure_kPa = 700.0;
    attribute maximumAllowablePressure: Pressure_kPa = 1300.0;

    part processConnection: ProcessConnection;
    part gauge: PressureGauge;
    part operator: Operator;

    connect processConnection.tap to gauge.processPort;
    connect gauge.indicationPort to operator.observedIndication;

    satisfy requirement primaryFunctionRequirement by gauge;
    satisfy requirement accuracyRequirement by gauge;
    satisfy requirement overrangeRequirement by gauge;
    satisfy requirement readabilityRequirement by gauge;
    satisfy requirement diagnosticRequirement by gauge;
  }

  requirement primaryFunctionRequirement {
    doc "The pressure gauge system shall sense the pressure of a connected process fluid and provide a local, continuously readable visual indication of that pressure at a high level without requiring external electrical power.";
    subject gauge: PressureGauge;

    require constraint {
      gauge.processPort.medium.gaugePressure >= gauge.minimumPressure and
      gauge.processPort.medium.gaugePressure <= gauge.fullScalePressure and
      gauge.indicationPort.indication.visibility == PointerVisibilityKind::visible
    }
  }

  requirement accuracyRequirement {
    doc "When pressure is within the calibrated range, the indicated pressure shall remain within the specified accuracy class relative to full scale.";
    subject gauge: PressureGauge;

    require constraint AccuracyConstraint {
      in actualPressure = gauge.processPort.medium.gaugePressure;
      in indicatedPressure = gauge.indicationPort.indication.indicatedPressure;
      in fullScaleSpan = gauge.fullScalePressure - gauge.minimumPressure;
      in accuracyClass = gauge.accuracyClass;
    }
  }

  requirement overrangeRequirement {
    doc "The pressure gauge shall tolerate proof pressure without burst and shall enter an overrange protected condition if process pressure exceeds full scale.";
    subject gauge: PressureGauge;

    require constraint OverrangeProtectionConstraint {
      in processPressure = gauge.processPort.medium.gaugePressure;
      in fullScalePressure = gauge.fullScalePressure;
      in proofPressure = gauge.proofPressure;
    }
  }

  requirement readabilityRequirement {
    doc "The gauge pointer and dial shall provide a readable indication across the calibrated arc.";
    subject gauge: PressureGauge;

    require constraint ReadabilityConstraint {
      in pointerAngle = gauge.indicationPort.indication.pointerAngle;
      in minimumReadableAngle = gauge.dial.minimumReadableAngle;
      in maximumReadableAngle = gauge.dial.maximumReadableAngle;
    }
  }

  requirement diagnosticRequirement {
    doc "The gauge shall provide diagnostic information identifying nominal, degraded, blocked, leaking, overrange, calibration due, or failed conditions.";
    subject gauge: PressureGauge;

    require constraint {
      gauge.maintenancePort.report.health == GaugeHealthKind::nominal or
      gauge.maintenancePort.report.health == GaugeHealthKind::degraded or
      gauge.maintenancePort.report.health == GaugeHealthKind::blocked or
      gauge.maintenancePort.report.health == GaugeHealthKind::leaking or
      gauge.maintenancePort.report.health == GaugeHealthKind::overrange or
      gauge.maintenancePort.report.health == GaugeHealthKind::calibrationDue or
      gauge.maintenancePort.report.health == GaugeHealthKind::failed
    }
  }

}
