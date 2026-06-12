package MetalDetectorSystemModel {

  import ScalarValues::*;
  import SI::*;

  attribute def Frequency :> ScalarValues::Real;
  attribute def Voltage :> ScalarValues::Real;
  attribute def Current :> ScalarValues::Real;
  attribute def MagneticFluxDensity :> ScalarValues::Real;
  attribute def SignalAmplitude :> ScalarValues::Real;
  attribute def Conductivity :> ScalarValues::Real;
  attribute def Depth :> ScalarValues::Real;
  attribute def Confidence :> ScalarValues::Real;
  attribute def BatteryCharge :> ScalarValues::Real;

  item def ElectricalPower {
    attribute voltage : Voltage [V];
    attribute current : Current [A];
  }

  item def ExcitationWaveform {
    attribute frequency : Frequency [Hz];
    attribute amplitude : Voltage [V];
    attribute dutyCycle : Real;
  }

  item def MagneticField {
    attribute fluxDensity : MagneticFluxDensity [T];
    attribute frequency : Frequency [Hz];
  }

  item def CoilResponseSignal {
    attribute amplitude : SignalAmplitude [V];
    attribute phaseShift : Real;
    attribute noiseLevel : SignalAmplitude [V];
  }

  item def DetectionResult {
    attribute metalDetected : Boolean;
    attribute estimatedDepth : Depth [m];
    attribute confidence : Confidence;
    attribute targetClass : TargetClassification;
  }

  enum def TargetClassification {
    enum ferrous;
    enum nonFerrous;
    enum unknownMetal;
    enum noTarget;
  }

  port def PowerInputPort {
    in item power : ElectricalPower;
  }

  port def PowerOutputPort {
    out item power : ElectricalPower;
  }

  port def WaveformOutputPort {
    out item waveform : ExcitationWaveform;
  }

  port def MagneticTransmitPort {
    out item field : MagneticField;
  }

  port def MagneticReceivePort {
    in item field : MagneticField;
  }

  port def SignalOutputPort {
    out item signal : CoilResponseSignal;
  }

  port def SignalInputPort {
    in item signal : CoilResponseSignal;
  }

  port def ResultOutputPort {
    out item result : DetectionResult;
  }

  port def ResultInputPort {
    in item result : DetectionResult;
  }

  port def AlertOutputPort {
    out item result : DetectionResult;
  }

  part def BatteryPack {
    attribute nominalVoltage : Voltage [V] = 12.0;
    attribute remainingCharge : BatteryCharge = 1.0;
    attribute lowChargeThreshold : BatteryCharge = 0.15;

    port powerOut : PowerOutputPort;

    state def BatteryState {
      state charged;
      state low;
      state depleted;

      entry; then charged;

      transition charged_to_low
        first charged
        if remainingCharge <= lowChargeThreshold
        then low;

      transition low_to_depleted
        first low
        if remainingCharge <= 0.02
        then depleted;
    }

    exhibit state batteryState : BatteryState;
  }

  part def PowerRegulator {
    attribute regulatedVoltage : Voltage [V] = 5.0;
    attribute maxOutputCurrent : Current [A] = 1.5;

    port inputPower : PowerInputPort;
    port outputPower : PowerOutputPort;

    action regulatePower {
      in item rawPower : ElectricalPower;
      out item regulatedPower : ElectricalPower;

      first start;
      then provideStableVoltage;
      then done;

      action provideStableVoltage {
        regulatedPower.voltage = regulatedVoltage;
        regulatedPower.current = rawPower.current;
      }
    }
  }

  part def TransmitOscillator {
    attribute operatingFrequency : Frequency [Hz] = 7500.0;
    attribute driveAmplitude : Voltage [V] = 3.3;
    attribute dutyCycle : Real = 0.50;

    port powerIn : PowerInputPort;
    port waveformOut : WaveformOutputPort;

    action generateExcitation {
      out item waveform : ExcitationWaveform;

      first start;
      then setFrequency;
      then emitWaveform;
      then done;

      action setFrequency {
        waveform.frequency = operatingFrequency;
        waveform.amplitude = driveAmplitude;
        waveform.dutyCycle = dutyCycle;
      }
    }
  }

  part def SearchCoilAssembly {
    attribute coilDiameter : Length [m] = 0.28;
    attribute nominalFieldStrength : MagneticFluxDensity [T] = 0.00008;

    port excitationIn : WaveformOutputPort;
    port transmitFieldOut : MagneticTransmitPort;
    port receiveFieldIn : MagneticReceivePort;
    port responseOut : SignalOutputPort;

    action transmitMagneticField {
      in item waveform : ExcitationWaveform;
      out item emittedField : MagneticField;

      first start;
      then energizeCoil;
      then done;

      action energizeCoil {
        emittedField.frequency = waveform.frequency;
        emittedField.fluxDensity = nominalFieldStrength;
      }
    }

    action senseDisturbedField {
      in item disturbedField : MagneticField;
      out item responseSignal : CoilResponseSignal;

      first start;
      then induceVoltage;
      then done;

      action induceVoltage {
        responseSignal.amplitude = disturbedField.fluxDensity * 1000.0;
        responseSignal.phaseShift = 0.0;
        responseSignal.noiseLevel = 0.002;
      }
    }
  }

  part def SignalConditioner {
    attribute gain : Real = 45.0;
    attribute bandPassCenterFrequency : Frequency [Hz] = 7500.0;
    attribute noiseRejectionThreshold : SignalAmplitude [V] = 0.004;

    port signalIn : SignalInputPort;
    port signalOut : SignalOutputPort;

    action filterAndAmplify {
      in item rawSignal : CoilResponseSignal;
      out item conditionedSignal : CoilResponseSignal;

      first start;
      then rejectOutOfBandNoise;
      then amplify;
      then done;

      action rejectOutOfBandNoise {
        conditionedSignal.noiseLevel = rawSignal.noiseLevel * 0.25;
      }

      action amplify {
        conditionedSignal.amplitude = rawSignal.amplitude * gain;
        conditionedSignal.phaseShift = rawSignal.phaseShift;
      }
    }
  }

  part def DetectionProcessor {
    attribute detectionThreshold : SignalAmplitude [V] = 0.12;
    attribute ferrousPhaseLimit : Real = -0.25;
    attribute minimumConfidence : Confidence = 0.70;
    attribute maximumReliableDepth : Depth [m] = 0.35;

    port signalIn : SignalInputPort;
    port resultOut : ResultOutputPort;

    action evaluateMetalPresence {
      in item conditionedSignal : CoilResponseSignal;
      out item result : DetectionResult;

      first start;
      then estimateConfidence;
      then classifyTarget;
      then publishResult;
      then done;

      action estimateConfidence {
        result.confidence =
          if conditionedSignal.amplitude > detectionThreshold
          then 0.90
          else 0.20;
        result.metalDetected = result.confidence >= minimumConfidence;
      }

      action classifyTarget {
        result.targetClass =
          if result.metalDetected and conditionedSignal.phaseShift < ferrousPhaseLimit
          then TargetClassification::ferrous
          else if result.metalDetected
          then TargetClassification::nonFerrous
          else TargetClassification::noTarget;

        result.estimatedDepth =
          if result.metalDetected
          then maximumReliableDepth * detectionThreshold / conditionedSignal.amplitude
          else 0.0 [m];
      }
    }

    state def DetectionMode {
      state idle;
      state scanning;
      state targetDetected;
      state fault;

      entry; then idle;

      transition begin_scan
        first idle
        accept StartScan
        then scanning;

      transition detect_target
        first scanning
        if resultOut.result.metalDetected
        then targetDetected;

      transition target_lost
        first targetDetected
        if not resultOut.result.metalDetected
        then scanning;

      transition stop_scan
        first scanning
        accept StopScan
        then idle;

      transition processor_fault
        first scanning
        accept FaultDetected
        then fault;
    }

    exhibit state mode : DetectionMode;
  }

  part def UserInterface {
    attribute audioAlertFrequency : Frequency [Hz] = 1200.0;
    attribute displayRefreshRate : Frequency [Hz] = 10.0;

    port detectionResultIn : ResultInputPort;
    port alertOut : AlertOutputPort;

    action notifyOperator {
      in item result : DetectionResult;

      first start;
      then updateDisplay;
      then commandAudioAlert;
      then done;

      action updateDisplay {
        result.targetClass = result.targetClass;
      }

      action commandAudioAlert {
        if result.metalDetected then result.confidence = result.confidence;
      }
    }
  }

  part def SurveyEnvironment {
    attribute soilConductivity : Conductivity = 0.015;
    attribute nominalSearchHeight : Length [m] = 0.05;
    attribute targetDepth : Depth [m] = 0.12;
    attribute targetConductivity : Conductivity = 5.8e7;

    port incidentFieldIn : MagneticReceivePort;
    port disturbedFieldOut : MagneticTransmitPort;

    action disturbMagneticField {
      in item incidentField : MagneticField;
      out item disturbedField : MagneticField;

      first start;
      then induceEddyCurrents;
      then returnDisturbedField;
      then done;

      action induceEddyCurrents {
        disturbedField.frequency = incidentField.frequency;
        disturbedField.fluxDensity =
          incidentField.fluxDensity * (1.0 + targetConductivity / 1.0e9) / (1.0 + targetDepth);
      }
    }
  }

  part def HandheldMetalDetector {
    attribute mass : Mass [kg] = 1.4;
    attribute scanWidth : Length [m] = 0.28;
    attribute primaryFunction : String =
      "Detect metallic objects by transmitting an alternating magnetic field into the search area, sensing field disturbances caused by conductive targets, processing the response, and alerting the operator with target presence and classification.";

    part battery : BatteryPack;
    part regulator : PowerRegulator;
    part oscillator : TransmitOscillator;
    part coil : SearchCoilAssembly;
    part conditioner : SignalConditioner;
    part processor : DetectionProcessor;
    part interface : UserInterface;

    port operatorAlert : AlertOutputPort;

    connect battery.powerOut to regulator.inputPower;
    connect regulator.outputPower to oscillator.powerIn;
    connect oscillator.waveformOut to coil.excitationIn;
    connect coil.responseOut to conditioner.signalIn;
    connect conditioner.signalOut to processor.signalIn;
    connect processor.resultOut to interface.detectionResultIn;
    connect interface.alertOut to operatorAlert;

    action performMetalDetection {
      out item finalResult : DetectionResult;

      first start;
      then energizeSearchCoil;
      then acquireResponse;
      then processResponse;
      then alertOperator;
      then done;

      action energizeSearchCoil {
        objective {
          doc "Generate a controlled alternating magnetic field through the search coil.";
        }
      }

      action acquireResponse {
        objective {
          doc "Sense changes in the magnetic field caused by nearby conductive or ferromagnetic material.";
        }
      }

      action processResponse {
        objective {
          doc "Filter, amplify, compare against thresholds, estimate depth, and classify the target.";
        }
      }

      action alertOperator {
        objective {
          doc "Provide an operator-visible and audible indication when metal is detected.";
        }
      }
    }
  }

  part def MetalDetectionMission {
    part detector : HandheldMetalDetector;
    part environment : SurveyEnvironment;

    connect detector.coil.transmitFieldOut to environment.incidentFieldIn;
    connect environment.disturbedFieldOut to detector.coil.receiveFieldIn;
  }

  requirement def DetectMetalRequirement {
    subject detector : HandheldMetalDetector;

    require constraint {
      detector.processor.detectionThreshold <= 0.12 [V]
    }

    doc "The system shall detect metallic objects by sensing electromagnetic field disturbances produced by conductive or ferromagnetic targets within its reliable search depth.";
  }

  requirement def ProvideOperatorAlertRequirement {
    subject detector : HandheldMetalDetector;

    require constraint {
      detector.interface.audioAlertFrequency >= 800.0 [Hz] and
      detector.interface.audioAlertFrequency <= 3000.0 [Hz]
    }

    doc "The system shall provide an operator alert when a metallic target is detected with confidence greater than or equal to the minimum reporting threshold.";
  }

  requirement def EstimateTargetDepthRequirement {
    subject detector : HandheldMetalDetector;

    require constraint {
      detector.processor.maximumReliableDepth >= 0.30 [m]
    }

    doc "The system shall estimate target depth for detected objects within the configured reliable detection range.";
  }

  requirement def ClassifyTargetRequirement {
    subject detector : HandheldMetalDetector;

    require constraint {
      detector.processor.minimumConfidence >= 0.70
    }

    doc "The system shall classify detected targets as ferrous, non-ferrous, unknown metal, or no target based on processed signal amplitude and phase response.";
  }

  requirement def PortablePowerRequirement {
    subject detector : HandheldMetalDetector;

    require constraint {
      detector.battery.nominalVoltage >= 9.0 [V] and
      detector.mass <= 2.0 [kg]
    }

    doc "The system shall be portable and powered from an onboard battery suitable for handheld scanning operation.";
  }

  satisfy DetectMetalRequirement by HandheldMetalDetector;
  satisfy ProvideOperatorAlertRequirement by UserInterface;
  satisfy EstimateTargetDepthRequirement by DetectionProcessor;
  satisfy ClassifyTargetRequirement by DetectionProcessor;
  satisfy PortablePowerRequirement by BatteryPack;

}