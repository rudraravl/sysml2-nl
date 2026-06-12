package ThinFilmThicknessMonitorModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Nanometer :> LengthUnit {
    :>> conversionFactor = 1.0e-9;
    :>> symbol = "nm";
  }

  attribute def Angstrom :> LengthUnit {
    :>> conversionFactor = 1.0e-10;
    :>> symbol = "A";
  }

  attribute def Percent :> DimensionlessUnit {
    :>> conversionFactor = 0.01;
    :>> symbol = "%";
  }

  value type FilmThickness :> Length {
    unit = Nanometer;
  }

  value type DepositionRate :> Speed {
    unit = Nanometer / s;
  }

  value type OpticalWavelength :> Length {
    unit = Nanometer;
  }

  value type OpticalIntensity :> Real {
    unit = W / m^2;
  }

  value type TemperatureCelsius :> Real {
    unit = degC;
  }

  value type PressurePascal :> Pressure {
    unit = Pa;
  }

  value type Confidence :> Real {
    unit = Percent;
  }

  value type SamplePeriod :> Time {
    unit = s;
  }

  value type VoltageLevel :> ElectricPotential {
    unit = V;
  }

  item def OpticalBeam {
    attribute wavelength : OpticalWavelength;
    attribute intensity : OpticalIntensity;
    attribute incidenceAngle : Real;
  }

  item def ReflectedSignal {
    attribute measuredIntensity : OpticalIntensity;
    attribute wavelength : OpticalWavelength;
    attribute phaseShift : Real;
    attribute timestamp : Time;
  }

  item def ThicknessEstimate {
    attribute thickness : FilmThickness;
    attribute rate : DepositionRate;
    attribute confidence : Confidence;
    attribute timestamp : Time;
  }

  item def ProcessEnvironment {
    attribute chamberPressure : PressurePascal;
    attribute substrateTemperature : TemperatureCelsius;
    attribute depositionActive : Boolean;
  }

  item def ThicknessSetpoint {
    attribute targetThickness : FilmThickness;
    attribute maxAllowedRate : DepositionRate;
    attribute minConfidence : Confidence;
  }

  item def ControlCommand {
    attribute shutterOpen : Boolean;
    attribute depositionPowerPercent : Real;
    attribute stopDeposition : Boolean;
  }

  item def AlarmEvent {
    attribute alarmCode : String;
    attribute severity : Integer;
    attribute message : String;
    attribute timestamp : Time;
  }

  port def OpticalTransmitPort {
    out item beam : OpticalBeam;
  }

  port def OpticalReceivePort {
    in item signal : ReflectedSignal;
  }

  port def EnvironmentPort {
    in item environment : ProcessEnvironment;
  }

  port def SetpointPort {
    in item setpoint : ThicknessSetpoint;
  }

  port def EstimatePort {
    out item estimate : ThicknessEstimate;
  }

  port def CommandPort {
    out item command : ControlCommand;
  }

  port def AlarmPort {
    out item alarm : AlarmEvent;
  }

  port def PowerPort {
    in attribute supplyVoltage : VoltageLevel;
  }

  action def EmitMeasurementBeam {
    in targetWavelength : OpticalWavelength;
    in sourceIntensity : OpticalIntensity;
    out beam : OpticalBeam;
  }

  action def AcquireReflectedSignal {
    in reflectedSignal : ReflectedSignal;
    out sampledIntensity : OpticalIntensity;
    out sampledPhase : Real;
  }

  action def CalculateThickness {
    in sampledIntensity : OpticalIntensity;
    in sampledPhase : Real;
    in wavelength : OpticalWavelength;
    in previousThickness : FilmThickness;
    in samplePeriod : SamplePeriod;
    out estimate : ThicknessEstimate;
  }

  action def CompareToSetpoint {
    in estimate : ThicknessEstimate;
    in setpoint : ThicknessSetpoint;
    out command : ControlCommand;
    out complete : Boolean;
  }

  action def RaiseMeasurementAlarm {
    in estimate : ThicknessEstimate;
    in environment : ProcessEnvironment;
    out alarm : AlarmEvent;
  }

  state def MonitorOperatingState {
    entry action initialize {
      then initializeOptics;
      then initializeEstimator;
    }

    state Off;
    state SelfTest;
    state Standby;
    state Monitoring;
    state ControllingDeposition;
    state TargetReached;
    state Fault;

    transition powerApplied first Off then SelfTest;

    transition selfTestPassed
      first SelfTest
      then Standby;

    transition selfTestFailed
      first SelfTest
      then Fault;

    transition recipeLoaded
      first Standby
      then Monitoring;

    transition depositionDetected
      first Monitoring
      then ControllingDeposition;

    transition targetThicknessReached
      first ControllingDeposition
      then TargetReached;

    transition resetForNextRun
      first TargetReached
      then Standby;

    transition invalidSignal
      first Monitoring
      then Fault;

    transition unsafeEnvironment
      first ControllingDeposition
      then Fault;

    transition operatorReset
      first Fault
      then SelfTest;
  }

  part def BroadbandLightSource {
    attribute nominalWavelength : OpticalWavelength = 550 [Nanometer];
    attribute emittedIntensity : OpticalIntensity;
    attribute warmupTime : Time = 5 [s];

    port opticalOut : OpticalTransmitPort;
    port powerIn : PowerPort;

    action emit : EmitMeasurementBeam {
      in targetWavelength = nominalWavelength;
      in sourceIntensity = emittedIntensity;
      out beam = opticalOut.beam;
    }
  }

  part def OpticalProbe {
    attribute incidenceAngle : Real = 0.0;
    attribute collectionEfficiency : Real = 0.82;

    port sourceIn : OpticalReceivePort;
    port beamOut : OpticalTransmitPort;
    port reflectionIn : OpticalReceivePort;

    connection sourceToProbe connect sourceIn.signal to reflectionIn.signal;
  }

  part def SpectrometerDetector {
    attribute spectralResolution : OpticalWavelength = 0.2 [Nanometer];
    attribute integrationTime : Time = 0.05 [s];
    attribute darkCurrentCompensationEnabled : Boolean = true;

    port reflectedIn : OpticalReceivePort;
    port signalOut : OpticalReceivePort;
    port powerIn : PowerPort;

    action acquire : AcquireReflectedSignal {
      in reflectedSignal = reflectedIn.signal;
      out sampledIntensity;
      out sampledPhase;
    }
  }

  part def ThicknessEstimator {
    attribute refractiveIndex : Real = 1.46;
    attribute extinctionCoefficient : Real = 0.0;
    attribute samplePeriod : SamplePeriod = 0.1 [s];
    attribute lastThickness : FilmThickness = 0 [Nanometer];

    port signalIn : OpticalReceivePort;
    port estimateOut : EstimatePort;

    action estimateThickness : CalculateThickness {
      in sampledIntensity = signalIn.signal.measuredIntensity;
      in sampledPhase = signalIn.signal.phaseShift;
      in wavelength = signalIn.signal.wavelength;
      in previousThickness = lastThickness;
      in samplePeriod = samplePeriod;
      out estimate = estimateOut.estimate;
    }
  }

  part def DepositionController {
    attribute shutterLatency : Time = 0.2 [s];
    attribute controlEnabled : Boolean = true;

    port estimateIn : EstimatePort;
    port setpointIn : SetpointPort;
    port commandOut : CommandPort;

    action closeLoopControl : CompareToSetpoint {
      in estimate = estimateIn.estimate;
      in setpoint = setpointIn.setpoint;
      out command = commandOut.command;
      out complete;
    }
  }

  part def ChamberInterface {
    attribute maxSafePressure : PressurePascal = 5.0 [Pa];
    attribute maxSafeTemperature : TemperatureCelsius = 350 [degC];

    port environmentOut : EnvironmentPort;
    port commandIn : CommandPort;
    port alarmIn : AlarmPort;
  }

  part def UserInterface {
    port setpointOut : SetpointPort;
    port estimateIn : EstimatePort;
    port alarmIn : AlarmPort;
  }

  part def AlarmManager {
    attribute lowConfidenceLimit : Confidence = 80 [Percent];
    attribute maximumRateLimit : DepositionRate = 5 [Nanometer / s];

    port estimateIn : EstimatePort;
    port environmentIn : EnvironmentPort;
    port alarmOut : AlarmPort;

    action evaluateAlarm : RaiseMeasurementAlarm {
      in estimate = estimateIn.estimate;
      in environment = environmentIn.environment;
      out alarm = alarmOut.alarm;
    }
  }

  part def ThinFilmThicknessMonitor {
    attribute primaryFunction : String =
      "Continuously estimate thin-film thickness during deposition by measuring optical interference from the growing film and provide endpoint/control outputs when the target thickness is reached.";

    attribute measurementRangeMinimum : FilmThickness = 0 [Nanometer];
    attribute measurementRangeMaximum : FilmThickness = 5000 [Nanometer];
    attribute thicknessAccuracy : FilmThickness = 0.5 [Nanometer];
    attribute updatePeriod : SamplePeriod = 0.1 [s];
    attribute operatingState : MonitorOperatingState;

    port powerIn : PowerPort;
    port environmentIn : EnvironmentPort;
    port setpointIn : SetpointPort;
    port estimateOut : EstimatePort;
    port commandOut : CommandPort;
    port alarmOut : AlarmPort;

    part lightSource : BroadbandLightSource;
    part opticalProbe : OpticalProbe;
    part detector : SpectrometerDetector;
    part estimator : ThicknessEstimator;
    part controller : DepositionController;
    part chamberInterface : ChamberInterface;
    part userInterface : UserInterface;
    part alarmManager : AlarmManager;

    connection powerToSource connect powerIn to lightSource.powerIn;
    connection powerToDetector connect powerIn to detector.powerIn;

    connection setpointToController connect setpointIn to controller.setpointIn;
    connection setpointFromUi connect userInterface.setpointOut to controller.setpointIn;

    connection environmentToAlarm connect environmentIn to alarmManager.environmentIn;
    connection environmentToChamber connect environmentIn to chamberInterface.environmentOut;

    connection sourceToProbe connect lightSource.opticalOut to opticalProbe.beamOut;
    connection reflectedToDetector connect opticalProbe.reflectionIn to detector.reflectedIn;
    connection detectorToEstimator connect detector.signalOut to estimator.signalIn;

    connection estimatorToController connect estimator.estimateOut to controller.estimateIn;
    connection estimatorToAlarm connect estimator.estimateOut to alarmManager.estimateIn;
    connection estimatorToUi connect estimator.estimateOut to userInterface.estimateIn;
    connection estimatorToExternal connect estimator.estimateOut to estimateOut;

    connection controllerToChamber connect controller.commandOut to chamberInterface.commandIn;
    connection controllerToExternal connect controller.commandOut to commandOut;

    connection alarmToUi connect alarmManager.alarmOut to userInterface.alarmIn;
    connection alarmToChamber connect alarmManager.alarmOut to chamberInterface.alarmIn;
    connection alarmToExternal connect alarmManager.alarmOut to alarmOut;

    perform action monitorFilm {
      first startOptics : EmitMeasurementBeam {
        in targetWavelength = lightSource.nominalWavelength;
        in sourceIntensity = lightSource.emittedIntensity;
      }

      then acquireSignal : AcquireReflectedSignal {
        in reflectedSignal = detector.reflectedIn.signal;
      }

      then computeEstimate : CalculateThickness {
        in sampledIntensity = detector.reflectedIn.signal.measuredIntensity;
        in sampledPhase = detector.reflectedIn.signal.phaseShift;
        in wavelength = detector.reflectedIn.signal.wavelength;
        in previousThickness = estimator.lastThickness;
        in samplePeriod = estimator.samplePeriod;
        out estimate = estimateOut.estimate;
      }

      then decideControl : CompareToSetpoint {
        in estimate = estimateOut.estimate;
        in setpoint = setpointIn.setpoint;
        out command = commandOut.command;
      }
    }
  }

  requirement def PrimaryFunctionRequirement {
    subject monitor : ThinFilmThicknessMonitor;

    require constraint {
      monitor.measurementRangeMinimum <= monitor.estimateOut.estimate.thickness and
      monitor.estimateOut.estimate.thickness <= monitor.measurementRangeMaximum
    }

    doc /* The monitor shall provide continuous, non-contact measurement of thin-film thickness during deposition and produce a current thickness estimate, growth-rate estimate, confidence value, and endpoint/control command. */
  }

  requirement def AccuracyRequirement {
    subject monitor : ThinFilmThicknessMonitor;

    require constraint {
      monitor.thicknessAccuracy <= 1.0 [Nanometer]
    }

    doc /* The monitor shall estimate film thickness with no worse than 1 nm error under calibrated optical conditions. */
  }

  requirement def UpdateRateRequirement {
    subject monitor : ThinFilmThicknessMonitor;

    require constraint {
      monitor.updatePeriod <= 0.25 [s]
    }

    doc /* The monitor shall update the displayed and exported thickness estimate at least four times per second. */
  }

  requirement def EndpointControlRequirement {
    subject monitor : ThinFilmThicknessMonitor;

    require constraint {
      monitor.commandOut.command.stopDeposition ==
      (monitor.estimateOut.estimate.thickness >= monitor.setpointIn.setpoint.targetThickness)
    }

    doc /* The monitor shall command deposition stop when the estimated thickness reaches or exceeds the target thickness. */
  }

  requirement def ConfidenceAlarmRequirement {
    subject monitor : ThinFilmThicknessMonitor;

    require constraint {
      monitor.alarmOut.alarm.severity >= 1 implies
      monitor.estimateOut.estimate.confidence < monitor.setpointIn.setpoint.minConfidence
    }

    doc /* The monitor shall issue an alarm when measurement confidence falls below the recipe minimum confidence. */
  }

  part thinFilmThicknessMonitor : ThinFilmThicknessMonitor {
    attribute measurementRangeMinimum = 0 [Nanometer];
    attribute measurementRangeMaximum = 5000 [Nanometer];
    attribute thicknessAccuracy = 0.5 [Nanometer];
    attribute updatePeriod = 0.1 [s];
  }

  satisfy PrimaryFunctionRequirement by thinFilmThicknessMonitor;
  satisfy AccuracyRequirement by thinFilmThicknessMonitor;
  satisfy UpdateRateRequirement by thinFilmThicknessMonitor;
  satisfy EndpointControlRequirement by thinFilmThicknessMonitor;
  satisfy ConfidenceAlarmRequirement by thinFilmThicknessMonitor;
}