package RadarGunHighLevelSpecification {

  enum def RadarGunMode {
    enum off;
    enum selfTest;
    enum standby;
    enum aiming;
    enum measuring;
    enum reporting;
    enum fault;
  }

  enum def OperatorCommandKind {
    enum powerOn;
    enum powerOff;
    enum pullTrigger;
    enum releaseTrigger;
    enum selectStationaryMode;
    enum selectMovingMode;
    enum clearDisplay;
  }

  enum def MeasurementQuality {
    enum invalid;
    enum weakEcho;
    enum saturated;
    enum stable;
    enum locked;
  }

  enum def DisplayColor {
    enum off;
    enum green;
    enum amber;
    enum red;
  }

  attribute def Frequency {
    attribute hertz : Real;
    attribute unit : String = "Hz";
  }

  attribute def Speed {
    attribute metersPerSecond : Real;
    attribute unit : String = "m/s";
  }

  attribute def Distance {
    attribute meters : Real;
    attribute unit : String = "m";
  }

  attribute def TimeDuration {
    attribute seconds : Real;
    attribute unit : String = "s";
  }

  attribute def Voltage {
    attribute volts : Real;
    attribute unit : String = "V";
  }

  attribute def Current {
    attribute amperes : Real;
    attribute unit : String = "A";
  }

  attribute def Power {
    attribute watts : Real;
    attribute unit : String = "W";
  }

  attribute def Angle {
    attribute degrees : Real;
    attribute unit : String = "deg";
  }

  attribute def Temperature {
    attribute degreesCelsius : Real;
    attribute unit : String = "degC";
  }

  attribute def Ratio {
    attribute percent : Real;
    attribute unit : String = "%";
  }

  item def ElectricalPower {
    attribute voltage : Voltage;
    attribute current : Current;
    attribute power : Power;
  }

  item def OperatorCommand {
    attribute kind : OperatorCommandKind;
    attribute timeSincePowerOn : TimeDuration;
  }

  item def MicrowaveSignal {
    attribute carrierFrequency : Frequency;
    attribute dopplerShift : Frequency;
    attribute radiatedPower : Power;
    attribute beamAzimuth : Angle;
    attribute beamElevation : Angle;
    attribute signalToNoiseRatio : Ratio;
  }

  item def BasebandDopplerSignal {
    attribute dopplerFrequency : Frequency;
    attribute amplitude : Voltage;
    attribute sampleWindow : TimeDuration;
    attribute signalToNoiseRatio : Ratio;
  }

  item def SpeedMeasurement {
    attribute radialSpeed : Speed;
    attribute quality : MeasurementQuality;
    attribute measurementLatency : TimeDuration;
    attribute rangeToTarget : Distance;
    attribute displayedSpeed : Speed;
  }

  item def DisplayMessage {
    attribute measuredSpeed : Speed;
    attribute quality : MeasurementQuality;
    attribute color : DisplayColor;
    attribute visibleDuration : TimeDuration;
  }

  item def DiagnosticStatus {
    attribute passed : Boolean;
    attribute batteryCharge : Ratio;
    attribute internalTemperature : Temperature;
    attribute receiverHealthy : Boolean;
    attribute processorHealthy : Boolean;
    attribute displayHealthy : Boolean;
  }

  item def MovingTarget {
    attribute trueRadialSpeed : Speed;
    attribute distanceFromRadar : Distance;
    attribute radarCrossSection : Ratio;
    attribute approachAngle : Angle;
  }

  port def ElectricalPowerInputPort {
    in item power : ElectricalPower;
  }

  port def ElectricalPowerOutputPort {
    out item power : ElectricalPower;
  }

  port def CommandInputPort {
    in item command : OperatorCommand;
  }

  port def CommandOutputPort {
    out item command : OperatorCommand;
  }

  port def RadarAperturePort {
    out item transmittedSignal : MicrowaveSignal;
    in item reflectedSignal : MicrowaveSignal;
  }

  port def RadioFrequencyInputPort {
    in item signal : MicrowaveSignal;
  }

  port def RadioFrequencyOutputPort {
    out item signal : MicrowaveSignal;
  }

  port def BasebandOutputPort {
    out item signal : BasebandDopplerSignal;
  }

  port def BasebandInputPort {
    in item signal : BasebandDopplerSignal;
  }

  port def SpeedMeasurementOutputPort {
    out item measurement : SpeedMeasurement;
  }

  port def SpeedMeasurementInputPort {
    in item measurement : SpeedMeasurement;
  }

  port def DisplayMessageOutputPort {
    out item message : DisplayMessage;
  }

  port def DiagnosticOutputPort {
    out item status : DiagnosticStatus;
  }

  port def DiagnosticInputPort {
    in item status : DiagnosticStatus;
  }

  constraint def DopplerRadialSpeedEquation {
    in carrierFrequency : Frequency;
    in dopplerShift : Frequency;
    in speedOfLight : Speed;
    in computedRadialSpeed : Speed;

    require constraint {
      computedRadialSpeed.metersPerSecond ==
        (dopplerShift.hertz * speedOfLight.metersPerSecond) /
        (2.0 * carrierFrequency.hertz)
    }
  }

  constraint def ValidMeasurementEnvelope {
    in measuredSpeed : Speed;
    in targetRange : Distance;
    in minimumSpeed : Speed;
    in maximumSpeed : Speed;
    in maximumRange : Distance;

    require constraint {
      measuredSpeed.metersPerSecond >= minimumSpeed.metersPerSecond and
      measuredSpeed.metersPerSecond <= maximumSpeed.metersPerSecond and
      targetRange.meters <= maximumRange.meters
    }
  }

  part def BatteryPack {
    attribute nominalVoltage : Voltage {
      :>> volts = 7.4;
    }

    attribute capacity : Power {
      :>> watts = 22.2;
    }

    attribute stateOfCharge : Ratio {
      :>> percent = 100.0;
    }

    port dcOut : ElectricalPowerOutputPort;
  }

  part def PowerRegulator {
    attribute regulatedVoltage : Voltage {
      :>> volts = 5.0;
    }

    attribute maximumOutputPower : Power {
      :>> watts = 15.0;
    }

    port rawPowerIn : ElectricalPowerInputPort;
    port regulatedPowerOut : ElectricalPowerOutputPort;
    port diagnosticOut : DiagnosticOutputPort;
  }

  part def PowerSubsystem {
    part battery : BatteryPack;
    part regulator : PowerRegulator;

    port dcOut : ElectricalPowerOutputPort;
    port diagnosticOut : DiagnosticOutputPort;

    connect battery.dcOut to regulator.rawPowerIn;
    connect regulator.regulatedPowerOut to dcOut;
    connect regulator.diagnosticOut to diagnosticOut;
  }

  part def FrequencyReference {
    attribute nominalFrequency : Frequency {
      :>> hertz = 24150000000.0;
    }

    attribute frequencyStability : Ratio {
      :>> percent = 0.002;
    }

    port powerIn : ElectricalPowerInputPort;
    port referenceOut : RadioFrequencyOutputPort;
    port commandIn : CommandInputPort;
  }

  part def MicrowavePowerAmplifier {
    attribute transmitPower : Power {
      :>> watts = 0.010;
    }

    port powerIn : ElectricalPowerInputPort;
    port referenceIn : RadioFrequencyInputPort;
    port amplifiedOut : RadioFrequencyOutputPort;
    port commandIn : CommandInputPort;
  }

  part def DirectionalAntenna {
    attribute nominalGain : Ratio {
      :>> percent = 85.0;
    }

    attribute beamWidth : Angle {
      :>> degrees = 12.0;
    }

    port transmitIn : RadioFrequencyInputPort;
    port echoOut : RadioFrequencyOutputPort;
    port aperture : RadarAperturePort;
  }

  part def LowNoiseReceiver {
    attribute receiverNoiseFigure : Ratio {
      :>> percent = 8.0;
    }

    port powerIn : ElectricalPowerInputPort;
    port echoIn : RadioFrequencyInputPort;
    port conditionedEchoOut : RadioFrequencyOutputPort;
    port commandIn : CommandInputPort;
  }

  part def DopplerMixer {
    port powerIn : ElectricalPowerInputPort;
    port referenceIn : RadioFrequencyInputPort;
    port echoIn : RadioFrequencyInputPort;
    port basebandOut : BasebandOutputPort;
  }

  part def MicrowaveTransceiver {
    attribute carrierFrequency : Frequency {
      :>> hertz = 24150000000.0;
    }

    attribute nominalTransmittedPower : Power {
      :>> watts = 0.010;
    }

    part referenceOscillator : FrequencyReference;
    part transmitterAmplifier : MicrowavePowerAmplifier;
    part antenna : DirectionalAntenna;
    part receiver : LowNoiseReceiver;
    part mixer : DopplerMixer;

    port powerIn : ElectricalPowerInputPort;
    port controlIn : CommandInputPort;
    port radarAperture : RadarAperturePort;
    port basebandOut : BasebandOutputPort;

    connect powerIn to referenceOscillator.powerIn;
    connect powerIn to transmitterAmplifier.powerIn;
    connect powerIn to receiver.powerIn;
    connect powerIn to mixer.powerIn;

    connect controlIn to referenceOscillator.commandIn;
    connect controlIn to transmitterAmplifier.commandIn;
    connect controlIn to receiver.commandIn;

    connect referenceOscillator.referenceOut to transmitterAmplifier.referenceIn;
    connect referenceOscillator.referenceOut to mixer.referenceIn;
    connect transmitterAmplifier.amplifiedOut to antenna.transmitIn;
    connect antenna.echoOut to receiver.echoIn;
    connect receiver.conditionedEchoOut to mixer.echoIn;
    connect antenna.aperture to radarAperture;
    connect mixer.basebandOut to basebandOut;
  }

  part def AnalogToDigitalConverter {
    attribute sampleRate : Frequency {
      :>> hertz = 48000.0;
    }

    attribute resolutionBits : Integer = 16;

    port powerIn : ElectricalPowerInputPort;
    port analogIn : BasebandInputPort;
    port digitalOut : BasebandOutputPort;
  }

  part def DopplerEstimator {
    attribute minimumDopplerFrequency : Frequency {
      :>> hertz = 30.0;
    }

    attribute maximumDopplerFrequency : Frequency {
      :>> hertz = 15000.0;
    }

    port sampledSignalIn : BasebandInputPort;
    port estimatedSignalOut : BasebandOutputPort;
  }

  part def SpeedCalculator {
    attribute speedOfLight : Speed {
      :>> metersPerSecond = 299792458.0;
    }

    attribute carrierFrequency : Frequency {
      :>> hertz = 24150000000.0;
    }

    port dopplerIn : BasebandInputPort;
    port speedOut : SpeedMeasurementOutputPort;

    constraint speedComputation : DopplerRadialSpeedEquation;
  }

  part def MeasurementValidator {
    attribute minimumReportableSpeed : Speed {
      :>> metersPerSecond = 1.0;
    }

    attribute maximumReportableSpeed : Speed {
      :>> metersPerSecond = 89.4;
    }

    attribute maximumOperatingRange : Distance {
      :>> meters = 300.0;
    }

    port rawSpeedIn : SpeedMeasurementInputPort;
    port validSpeedOut : SpeedMeasurementOutputPort;

    constraint envelope : ValidMeasurementEnvelope;
  }

  part def SignalProcessor {
    part adc : AnalogToDigitalConverter;
    part dopplerEstimator : DopplerEstimator;
    part speedCalculator : SpeedCalculator;
    part validator : MeasurementValidator;

    port powerIn : ElectricalPowerInputPort;
    port commandIn : CommandInputPort;
    port transceiverCommandOut : CommandOutputPort;
    port basebandIn : BasebandInputPort;
    port speedOut : SpeedMeasurementOutputPort;
    port diagnosticOut : DiagnosticOutputPort;

    connect powerIn to adc.powerIn;
    connect commandIn to transceiverCommandOut;
    connect basebandIn to adc.analogIn;
    connect adc.digitalOut to dopplerEstimator.sampledSignalIn;
    connect dopplerEstimator.estimatedSignalOut to speedCalculator.dopplerIn;
    connect speedCalculator.speedOut to validator.rawSpeedIn;
    connect validator.validSpeedOut to speedOut;
  }

  part def TriggerSwitch {
    port commandOut : CommandOutputPort;
  }

  part def ModeSelector {
    port commandOut : CommandOutputPort;
  }

  part def NumericDisplay {
    attribute refreshPeriod : TimeDuration {
      :>> seconds = 0.05;
    }

    attribute maximumDisplaySpeed : Speed {
      :>> metersPerSecond = 89.4;
    }

    port powerIn : ElectricalPowerInputPort;
    port speedIn : SpeedMeasurementInputPort;
    port messageOut : DisplayMessageOutputPort;
  }

  part def AudibleIndicator {
    attribute toneDuration : TimeDuration {
      :>> seconds = 0.25;
    }

    port powerIn : ElectricalPowerInputPort;
    port speedIn : SpeedMeasurementInputPort;
  }

  part def UserInterface {
    part trigger : TriggerSwitch;
    part modeSelector : ModeSelector;
    part display : NumericDisplay;
    part beeper : AudibleIndicator;

    port powerIn : ElectricalPowerInputPort;
    port operatorCommandOut : CommandOutputPort;
    port measuredSpeedIn : SpeedMeasurementInputPort;
    port displayedMessageOut : DisplayMessageOutputPort;

    connect trigger.commandOut to operatorCommandOut;
    connect modeSelector.commandOut to operatorCommandOut;
    connect powerIn to display.powerIn;
    connect powerIn to beeper.powerIn;
    connect measuredSpeedIn to display.speedIn;
    connect measuredSpeedIn to beeper.speedIn;
    connect display.messageOut to displayedMessageOut;
  }

  part def HandheldHousing {
    attribute mass : Real = 0.82;
    attribute massUnit : String = "kg";

    attribute length : Distance {
      :>> meters = 0.265;
    }

    attribute width : Distance {
      :>> meters = 0.095;
    }

    attribute height : Distance {
      :>> meters = 0.180;
    }

    attribute ingressProtectionRating : String = "IP54";
  }

  action def InitializeElectronics {
    out item status : DiagnosticStatus;
  }

  action def PerformSelfTest {
    in item power : ElectricalPower;
    out item status : DiagnosticStatus;
  }

  action def ArmTransmitter {
    in item command : OperatorCommand;
    out item enabledCommand : OperatorCommand;
  }

  action def EmitMicrowaveBeam {
    in item command : OperatorCommand;
    out item transmittedSignal : MicrowaveSignal;
  }

  action def ReceiveReflectedEcho {
    in item reflectedSignal : MicrowaveSignal;
    out item conditionedEcho : MicrowaveSignal;
  }

  action def EstimateDopplerShift {
    in item conditionedEcho : MicrowaveSignal;
    out item dopplerSignal : BasebandDopplerSignal;
  }

  action def CalculateRadialSpeed {
    in item dopplerSignal : BasebandDopplerSignal;
    out item rawMeasurement : SpeedMeasurement;

    attribute carrierFrequency : Frequency {
      :>> hertz = 24150000000.0;
    }

    attribute speedOfLight : Speed {
      :>> metersPerSecond = 299792458.0;
    }

    constraint speedEquation : DopplerRadialSpeedEquation;
  }

  action def ValidateMeasurement {
    in item rawMeasurement : SpeedMeasurement;
    out item validMeasurement : SpeedMeasurement;
  }

  action def PresentSpeedToOperator {
    in item validMeasurement : SpeedMeasurement;
    out item displayMessage : DisplayMessage;
  }

  action def MeasureTargetSpeed {
    in item operatorCommand : OperatorCommand;
    in item reflectedSignal : MicrowaveSignal;
    out item displayMessage : DisplayMessage;
    out item measuredSpeed : SpeedMeasurement;

    action arm : ArmTransmitter;
    action transmit : EmitMicrowaveBeam;
    action receive : ReceiveReflectedEcho;
    action estimate : EstimateDopplerShift;
    action calculate : CalculateRadialSpeed;
    action validate : ValidateMeasurement;
    action present : PresentSpeedToOperator;

    succession arm then transmit;
    succession transmit then receive;
    succession receive then estimate;
    succession estimate then calculate;
    succession calculate then validate;
    succession validate then present;
  }

  state def RadarGunOperatingStates {
    state off;
    state selfTesting;
    state standby;
    state aiming;
    state measuring;
    state reporting;
    state fault;

    transition initialToOff then off;
    transition powerOn first off then selfTesting;
    transition selfTestPassed first selfTesting then standby;
    transition selfTestFailed first selfTesting then fault;
    transition triggerPulled first standby then aiming;
    transition targetIlluminated first aiming then measuring;
    transition speedLocked first measuring then reporting;
    transition triggerReleasedFromAiming first aiming then standby;
    transition triggerReleasedFromMeasuring first measuring then standby;
    transition reportComplete first reporting then standby;
    transition faultCleared first fault then selfTesting;
    transition powerOffFromStandby first standby then off;
    transition powerOffFromFault first fault then off;
  }

  part def RadarGun {
    attribute primaryFunction : String =
      "Measure and display the radial speed of a moving target by transmitting microwave energy, receiving a Doppler-shifted reflection, computing speed from the frequency shift, and presenting the result to the operator.";

    attribute mode : RadarGunMode = RadarGunMode::off;

    attribute carrierFrequency : Frequency {
      :>> hertz = 24150000000.0;
    }

    attribute speedOfLightReference : Speed {
      :>> metersPerSecond = 299792458.0;
    }

    attribute minimumMeasuredSpeed : Speed {
      :>> metersPerSecond = 1.0;
    }

    attribute maximumMeasuredSpeed : Speed {
      :>> metersPerSecond = 89.4;
    }

    attribute maximumTargetRange : Distance {
      :>> meters = 300.0;
    }

    attribute maximumMeasurementLatency : TimeDuration {
      :>> seconds = 0.5;
    }

    attribute nominalSpeedAccuracy : Speed {
      :>> metersPerSecond = 0.45;
    }

    attribute canEmitMicrowaveBeam : Boolean = true;
    attribute canReceiveReflectedEcho : Boolean = true;
    attribute canCalculateDopplerSpeed : Boolean = true;
    attribute canDisplaySpeed : Boolean = true;

    part powerSubsystem : PowerSubsystem;
    part transceiver : MicrowaveTransceiver;
    part signalProcessor : SignalProcessor;
    part userInterface : UserInterface;
    part housing : HandheldHousing;

    port operatorCommandIn : CommandInputPort;
    port radarAperture : RadarAperturePort;
    port displayOut : DisplayMessageOutputPort;
    port diagnosticOut : DiagnosticOutputPort;

    connect powerSubsystem.dcOut to transceiver.powerIn;
    connect powerSubsystem.dcOut to signalProcessor.powerIn;
    connect powerSubsystem.dcOut to userInterface.powerIn;

    connect operatorCommandIn to signalProcessor.commandIn;
    connect userInterface.operatorCommandOut to signalProcessor.commandIn;
    connect signalProcessor.transceiverCommandOut to transceiver.controlIn;

    connect transceiver.radarAperture to radarAperture;
    connect transceiver.basebandOut to signalProcessor.basebandIn;
    connect signalProcessor.speedOut to userInterface.measuredSpeedIn;
    connect userInterface.displayedMessageOut to displayOut;

    connect powerSubsystem.diagnosticOut to diagnosticOut;
    connect signalProcessor.diagnosticOut to diagnosticOut;

    perform action primaryMeasurementBehavior : MeasureTargetSpeed;
    exhibit state operatingState : RadarGunOperatingStates;
  }

  part def RadarMeasurementScenario {
    part radarGun : RadarGun;

    part targetVehicle : MovingTarget {
      attribute trueRadialSpeed : Speed {
        :>> metersPerSecond = 31.3;
      }

      attribute distanceFromRadar : Distance {
        :>> meters = 145.0;
      }

      attribute radarCrossSection : Ratio {
        :>> percent = 60.0;
      }

      attribute approachAngle : Angle {
        :>> degrees = 0.0;
      }
    }

    connect radarGun.radarAperture to radarGun.transceiver.radarAperture;
  }

  requirement def PrimaryFunctionRequirement {
    doc
      /*
       The radar gun shall determine the radial speed of a moving target at a high level by emitting a microwave beam, receiving the Doppler-shifted reflected signal, calculating the speed from the frequency shift, and displaying the measured speed to the operator.
      */

    subject gun : RadarGun;

    require constraint {
      gun.canEmitMicrowaveBeam == true and
      gun.canReceiveReflectedEcho == true and
      gun.canCalculateDopplerSpeed == true and
      gun.canDisplaySpeed == true
    }
  }

  requirement def MeasurementRangeRequirement {
    doc
      /*
       The radar gun shall measure target radial speeds from 1.0 m/s through 89.4 m/s when the target is within 300 m and has adequate reflected signal strength.
      */

    subject gun : RadarGun;

    require constraint {
      gun.minimumMeasuredSpeed.metersPerSecond <= 1.0 and
      gun.maximumMeasuredSpeed.metersPerSecond >= 89.4 and
      gun.maximumTargetRange.meters >= 300.0
    }
  }

  requirement def MeasurementLatencyRequirement {
    doc
      /*
       The radar gun shall present a valid speed measurement within 0.5 s after the operator pulls the trigger and the target reflection is stable.
      */

    subject gun : RadarGun;

    require constraint {
      gun.maximumMeasurementLatency.seconds <= 0.5
    }
  }

  requirement def MeasurementAccuracyRequirement {
    doc
      /*
       The radar gun shall have nominal speed error no greater than 0.45 m/s under stable target, adequate signal-to-noise ratio, and calibrated carrier-frequency conditions.
      */

    subject gun : RadarGun;

    require constraint {
      gun.nominalSpeedAccuracy.metersPerSecond <= 0.45
    }
  }

  requirement def OperatorDisplayRequirement {
    doc
      /*
       The radar gun shall display the calculated target speed and measurement quality to the operator after a stable speed lock.
      */

    subject gun : RadarGun;

    require constraint {
      gun.canDisplaySpeed == true
    }
  }

  requirement def LowPowerMicrowaveEmissionRequirement {
    doc
      /*
       The radar gun shall use low-power microwave emission suitable for handheld speed measurement.
      */

    subject gun : RadarGun;

    require constraint {
      gun.transceiver.nominalTransmittedPower.watts <= 0.010
    }
  }

  part radarGunSystem : RadarGun;

  requirement primaryFunction : PrimaryFunctionRequirement {
    subject gun = radarGunSystem;
  }

  requirement measurementRange : MeasurementRangeRequirement {
    subject gun = radarGunSystem;
  }

  requirement measurementLatency : MeasurementLatencyRequirement {
    subject gun = radarGunSystem;
  }

  requirement measurementAccuracy : MeasurementAccuracyRequirement {
    subject gun = radarGunSystem;
  }

  requirement operatorDisplay : OperatorDisplayRequirement {
    subject gun = radarGunSystem;
  }

  requirement lowPowerEmission : LowPowerMicrowaveEmissionRequirement {
    subject gun = radarGunSystem;
  }

  satisfy primaryFunction by radarGunSystem;
  satisfy measurementRange by radarGunSystem;
  satisfy measurementLatency by radarGunSystem;
  satisfy measurementAccuracy by radarGunSystem;
  satisfy operatorDisplay by radarGunSystem;
  satisfy lowPowerEmission by radarGunSystem;
}
