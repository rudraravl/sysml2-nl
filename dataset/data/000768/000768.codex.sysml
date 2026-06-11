package SoundBasedSystem {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def SoundPressureLevel :> real {
    unit = "dB";
  }

  attribute def Frequency :> real {
    unit = "Hz";
  }

  attribute def TimeDuration :> real {
    unit = "s";
  }

  attribute def ElectricPotential :> real {
    unit = "V";
  }

  attribute def Power :> real {
    unit = "W";
  }

  attribute def Ratio :> real {
    unit = "1";
  }

  item def AcousticWave {
    attribute soundPressureLevel : SoundPressureLevel;
    attribute dominantFrequency : Frequency;
    attribute bandwidth : Frequency;
    attribute duration : TimeDuration;
  }

  item def ElectricalAudioSignal {
    attribute voltageAmplitude : ElectricPotential;
    attribute sampleRate : Frequency;
    attribute signalToNoiseRatio : SoundPressureLevel;
  }

  item def DigitalAudioFrame {
    attribute sampleRate : Frequency;
    attribute bitDepth : Integer;
    attribute frameDuration : TimeDuration;
    attribute normalizedAmplitude : Ratio;
  }

  item def SoundClassification {
    attribute label : String;
    attribute confidence : Ratio;
    attribute detectedFrequency : Frequency;
    attribute detectedLevel : SoundPressureLevel;
  }

  port def AcousticInputPort {
    in item incidentSound : AcousticWave;
  }

  port def AcousticOutputPort {
    out item emittedSound : AcousticWave;
  }

  port def AnalogAudioPort {
    inout item audioSignal : ElectricalAudioSignal;
  }

  port def DigitalAudioPort {
    inout item audioFrame : DigitalAudioFrame;
  }

  port def ClassificationPort {
    out item classification : SoundClassification;
  }

  part def Microphone {
    port soundIn : AcousticInputPort;
    port analogOut : AnalogAudioPort;

    attribute sensitivity : real {
      unit = "mV/Pa";
      default = 40.0;
    }

    attribute selfNoise : SoundPressureLevel = 22.0;
    attribute minFrequency : Frequency = 20.0;
    attribute maxFrequency : Frequency = 20000.0;

    action transduceSound {
      in item acousticInput : AcousticWave;
      out item analogSignal : ElectricalAudioSignal;

      first start;
      then convertPressureToVoltage;
      then applyFrequencyResponse;
      then outputSignal;
    }
  }

  part def AudioPreAmplifier {
    port analogIn : AnalogAudioPort;
    port analogOut : AnalogAudioPort;

    attribute gain : Ratio = 12.0;
    attribute maxOutputVoltage : ElectricPotential = 3.3;
    attribute noiseFloor : SoundPressureLevel = 18.0;

    action amplify {
      in item lowLevelSignal : ElectricalAudioSignal;
      out item conditionedSignal : ElectricalAudioSignal;

      first receiveSignal;
      then increaseAmplitude;
      then limitClipping;
      then deliverConditionedSignal;
    }
  }

  part def AnalogToDigitalConverter {
    port analogIn : AnalogAudioPort;
    port digitalOut : DigitalAudioPort;

    attribute sampleRate : Frequency = 48000.0;
    attribute resolutionBits : Integer = 24;
    attribute conversionLatency : TimeDuration = 0.001;

    action sampleAndQuantize {
      in item analogSignal : ElectricalAudioSignal;
      out item digitalFrame : DigitalAudioFrame;

      first sampleVoltage;
      then quantizeSamples;
      then packageFrame;
    }
  }

  part def SoundProcessor {
    port digitalIn : DigitalAudioPort;
    port classificationOut : ClassificationPort;
    port digitalOut : DigitalAudioPort;

    attribute analysisWindow : TimeDuration = 0.050;
    attribute minimumConfidence : Ratio = 0.85;
    attribute minimumDetectableLevel : SoundPressureLevel = 35.0;

    action analyzeSound {
      in item frame : DigitalAudioFrame;
      out item classification : SoundClassification;

      first receiveFrame;
      then computeSpectrum;
      then extractFeatures;
      then classifyPattern;
      then publishClassification;
    }

    state processorState {
      entry; then Idle;

      state Idle;
      state Listening;
      state Analyzing;
      state EventDetected;
      state Fault;

      transition Idle_to_Listening
        first Idle
        accept startListening
        then Listening;

      transition Listening_to_Analyzing
        first Listening
        accept audioFrameAvailable
        then Analyzing;

      transition Analyzing_to_EventDetected
        first Analyzing
        if classification.confidence >= minimumConfidence
        then EventDetected;

      transition Analyzing_to_Listening
        first Analyzing
        if classification.confidence < minimumConfidence
        then Listening;

      transition EventDetected_to_Listening
        first EventDetected
        accept eventReported
        then Listening;

      transition Any_to_Fault
        first Idle
        accept processingError
        then Fault;
    }
  }

  part def SpeakerDriver {
    port digitalIn : DigitalAudioPort;
    port analogOut : AnalogAudioPort;

    attribute outputPower : Power = 5.0;
    attribute distortionAtRatedPower : Ratio = 0.01;

    action synthesizeAlertSignal {
      in item classification : SoundClassification;
      out item alertSignal : ElectricalAudioSignal;

      first selectAlertTone;
      then shapeEnvelope;
      then driveAnalogOutput;
    }
  }

  part def Speaker {
    port analogIn : AnalogAudioPort;
    port soundOut : AcousticOutputPort;

    attribute ratedPower : Power = 5.0;
    attribute nominalImpedance : real {
      unit = "ohm";
      default = 8.0;
    }

    attribute minFrequency : Frequency = 80.0;
    attribute maxFrequency : Frequency = 18000.0;
    attribute maxSoundPressureLevel : SoundPressureLevel = 92.0;

    action emitSound {
      in item driveSignal : ElectricalAudioSignal;
      out item acousticOutput : AcousticWave;

      first receiveDriveSignal;
      then moveDiaphragm;
      then radiateAcousticWave;
    }
  }

  part def AcousticSoundSystem {
    doc /* Primary high-level function: capture sound from the environment, convert it into usable audio data, analyze it for meaningful acoustic events, and emit an audible response when required. */

    port environmentSoundIn : AcousticInputPort;
    port audibleSoundOut : AcousticOutputPort;
    port eventReportOut : ClassificationPort;

    part microphone : Microphone;
    part preAmplifier : AudioPreAmplifier;
    part converter : AnalogToDigitalConverter;
    part processor : SoundProcessor;
    part driver : SpeakerDriver;
    part speaker : Speaker;

    connect environmentSoundIn to microphone.soundIn;
    connect microphone.analogOut to preAmplifier.analogIn;
    connect preAmplifier.analogOut to converter.analogIn;
    connect converter.digitalOut to processor.digitalIn;
    connect processor.classificationOut to eventReportOut;
    connect processor.digitalOut to driver.digitalIn;
    connect driver.analogOut to speaker.analogIn;
    connect speaker.soundOut to audibleSoundOut;

    action performPrimaryFunction {
      in item incomingSound : AcousticWave;
      out item reportedEvent : SoundClassification;
      out item responseSound : AcousticWave;

      first captureEnvironmentalSound;
      then convertAcousticEnergyToElectricalSignal;
      then digitizeAudioSignal;
      then analyzeDigitalSoundPattern;
      then decideResponse;
      then emitAudibleResponse;
    }
  }

  requirement def CaptureAudibleSound {
    subject system : AcousticSoundSystem;

    require constraint {
      system.microphone.minFrequency <= 20.0 and
      system.microphone.maxFrequency >= 20000.0
    }

    doc /* The system shall capture audible acoustic waves across the nominal human hearing range. */
  }

  requirement def DigitizeWithLowLatency {
    subject system : AcousticSoundSystem;

    require constraint {
      system.converter.sampleRate >= 48000.0 and
      system.converter.resolutionBits >= 24 and
      system.converter.conversionLatency <= 0.005
    }

    doc /* The system shall digitize captured sound with sufficient fidelity and latency for real-time analysis. */
  }

  requirement def DetectSoundEvent {
    subject system : AcousticSoundSystem;

    require constraint {
      system.processor.minimumConfidence >= 0.85 and
      system.processor.minimumDetectableLevel <= 35.0
    }

    doc /* The system shall classify meaningful acoustic events with high confidence at moderate sound levels. */
  }

  requirement def EmitAudibleResponse {
    subject system : AcousticSoundSystem;

    require constraint {
      system.speaker.maxSoundPressureLevel >= 90.0 and
      system.driver.outputPower >= 5.0
    }

    doc /* The system shall emit an audible response that can be heard in a typical indoor environment. */
  }

  requirement def PrimaryFunctionRequirement {
    subject system : AcousticSoundSystem;

    require constraint {
      system.microphone.sensitivity > 0.0 and
      system.processor.analysisWindow <= 0.100 and
      system.speaker.ratedPower >= 3.0
    }

    doc /* The system shall transform environmental sound into analyzed information and, when appropriate, an audible output. */
  }

}