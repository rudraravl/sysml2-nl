package MichaabBasedSystemModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  // ===== Units and Value Types =====

  attribute def AngleDeg :> Real {
    unit = "deg";
  }

  attribute def LengthM :> Real {
    unit = "m";
  }

  attribute def AreaM2 :> Real {
    unit = "m^2";
  }

  attribute def VolumeM3 :> Real {
    unit = "m^3";
  }

  attribute def MassKg :> Real {
    unit = "kg";
  }

  attribute def PowerW :> Real {
    unit = "W";
  }

  attribute def LuminousFluxLm :> Real {
    unit = "lm";
  }

  attribute def IlluminanceLux :> Real {
    unit = "lx";
  }

  attribute def FrequencyHz :> Real {
    unit = "Hz";
  }

  attribute def SoundPressureDb :> Real {
    unit = "dB";
  }

  attribute def TemperatureC :> Real {
    unit = "degC";
  }

  attribute def TimeS :> Real {
    unit = "s";
  }

  attribute def Percent :> Real {
    unit = "%";
  }

  attribute def DirectionReference {
    attribute azimuth : AngleDeg;
    attribute elevation : AngleDeg;
    attribute uncertainty : AngleDeg;
  }

  attribute def AcousticProfile {
    attribute reverberationTime : TimeS;
    attribute speechClarityIndex : Percent;
    attribute amplificationGain : SoundPressureDb;
    attribute dominantFrequency : FrequencyHz;
  }

  attribute def LightingProfile {
    attribute luminousFlux : LuminousFluxLm;
    attribute focalIlluminance : IlluminanceLux;
    attribute colorTemperature : TemperatureC;
    attribute dimmingLevel : Percent;
  }

  attribute def StructuralLoad {
    attribute deadLoad : MassKg;
    attribute serviceLoad : MassKg;
    attribute safetyFactor : Real;
  }

  item def HumanVoice {
    attribute soundLevel : SoundPressureDb;
    attribute frequency : FrequencyHz;
    attribute articulationIndex : Percent;
  }

  item def ReflectedSound {
    attribute soundLevel : SoundPressureDb;
    attribute arrivalDelay : TimeS;
    attribute clarity : Percent;
  }

  item def AmbientLight {
    attribute illuminance : IlluminanceLux;
    attribute colorTemperature : TemperatureC;
  }

  item def FocusedLight {
    attribute illuminance : IlluminanceLux;
    attribute beamAngle : AngleDeg;
  }

  item def OrientationCue {
    attribute direction : DirectionReference;
    attribute confidence : Percent;
  }

  item def MaintenanceNotice {
    attribute severity : Percent;
    attribute messageCode : String;
  }

  item def ElectricalPower {
    attribute voltage : Real;
    attribute current : Real;
    attribute power : PowerW;
  }

  // ===== Interfaces and Ports =====

  port def AcousticInputPort {
    in item voice : HumanVoice;
  }

  port def AcousticOutputPort {
    out item reflectedSound : ReflectedSound;
  }

  port def LightInputPort {
    in item ambientLight : AmbientLight;
  }

  port def LightOutputPort {
    out item focusedLight : FocusedLight;
  }

  port def OrientationOutputPort {
    out item cue : OrientationCue;
  }

  port def PowerInputPort {
    in item electricalPower : ElectricalPower;
  }

  port def MaintenanceOutputPort {
    out item notice : MaintenanceNotice;
  }

  interface def VoiceReflectionInterface {
    end source : AcousticInputPort;
    end target : AcousticOutputPort;
  }

  interface def LightFocusingInterface {
    end source : LightInputPort;
    end target : LightOutputPort;
  }

  interface def OrientationIndicationInterface {
    end source : OrientationOutputPort;
    end target : OrientationOutputPort;
  }

  // ===== Part Definitions =====

  part def MichaabNiche {
    attribute height : LengthM = 3.2;
    attribute width : LengthM = 1.4;
    attribute depth : LengthM = 0.85;
    attribute innerSurfaceArea : AreaM2 = 7.6;
    attribute curvatureRadius : LengthM = 0.72;
    attribute wallThickness : LengthM = 0.22;
    attribute qiblaAlignment : DirectionReference;
    attribute surfaceAbsorption : Percent = 18.0;

    port acousticIn : AcousticInputPort;
    port acousticOut : AcousticOutputPort;
    port orientationOut : OrientationOutputPort;
    port lightIn : LightInputPort;
    port lightOut : LightOutputPort;
  }

  part def ConcaveReflector {
    attribute radius : LengthM = 0.76;
    attribute focalDistance : LengthM = 1.18;
    attribute acousticGain : SoundPressureDb = 5.5;
    attribute opticalReflectance : Percent = 64.0;

    port acousticIn : AcousticInputPort;
    port acousticOut : AcousticOutputPort;
    port lightIn : LightInputPort;
    port lightOut : LightOutputPort;
  }

  part def DirectionalAxisMarker {
    attribute engravedAzimuth : AngleDeg;
    attribute visualContrast : Percent = 82.0;
    attribute tactileReliefHeight : LengthM = 0.004;

    port orientationOut : OrientationOutputPort;
  }

  part def StructuralFrame {
    attribute frameMass : MassKg = 420.0;
    attribute loadCapacity : StructuralLoad;
    attribute anchorDepth : LengthM = 0.45;
    attribute expectedServiceLife : TimeS = 946080000.0;
  }

  part def IntegratedLighting {
    attribute profile : LightingProfile;
    attribute maximumPower : PowerW = 38.0;
    attribute minimumDimmingLevel : Percent = 12.0;
    attribute thermalLimit : TemperatureC = 65.0;

    port powerIn : PowerInputPort;
    port lightOut : LightOutputPort;
    port maintenanceOut : MaintenanceOutputPort;
  }

  part def AcousticTreatmentLayer {
    attribute profile : AcousticProfile;
    attribute porousLayerDepth : LengthM = 0.035;
    attribute diffuserSpacing : LengthM = 0.08;
    attribute targetSpeechClarity : Percent = 86.0;

    port acousticIn : AcousticInputPort;
    port acousticOut : AcousticOutputPort;
  }

  part def EnvironmentalSensorSet {
    attribute measuredTemperature : TemperatureC;
    attribute measuredIlluminance : IlluminanceLux;
    attribute measuredSoundLevel : SoundPressureDb;
    attribute diagnosticHealth : Percent;

    port maintenanceOut : MaintenanceOutputPort;
  }

  part def MichaabBasedGuidanceSystem {
    attribute installedHeight : LengthM = 3.4;
    attribute occupiedFloorArea : AreaM2 = 2.1;
    attribute totalMass : MassKg = 515.0;
    attribute nominalQiblaDirection : DirectionReference;
    attribute primaryFunctionStatement : String =
      "Provide a spatial, visual, and acoustic focal point that indicates the sacred direction and improves intelligibility of spoken guidance within an interior gathering space.";

    part niche : MichaabNiche;
    part reflector : ConcaveReflector;
    part axisMarker : DirectionalAxisMarker;
    part frame : StructuralFrame;
    part lighting : IntegratedLighting;
    part treatment : AcousticTreatmentLayer;
    part sensors : EnvironmentalSensorSet;

    port voiceInput : AcousticInputPort;
    port speechOutput : AcousticOutputPort;
    port ambientLightInput : LightInputPort;
    port focusedLightOutput : LightOutputPort;
    port powerInput : PowerInputPort;
    port orientationOutput : OrientationOutputPort;
    port maintenanceOutput : MaintenanceOutputPort;

    connect voiceInput to niche.acousticIn;
    connect niche.acousticOut to treatment.acousticIn;
    connect treatment.acousticOut to reflector.acousticIn;
    connect reflector.acousticOut to speechOutput;

    connect ambientLightInput to niche.lightIn;
    connect niche.lightOut to reflector.lightIn;
    connect reflector.lightOut to focusedLightOutput;
    connect powerInput to lighting.powerIn;
    connect lighting.lightOut to focusedLightOutput;

    connect axisMarker.orientationOut to niche.orientationOut;
    connect niche.orientationOut to orientationOutput;

    connect lighting.maintenanceOut to maintenanceOutput;
    connect sensors.maintenanceOut to maintenanceOutput;
  }

  // ===== Behavior Definitions =====

  action def ReceiveVoice {
    in item spokenInput : HumanVoice;
    out item capturedVoice : HumanVoice;
  }

  action def ShapeAcousticReflection {
    in item capturedVoice : HumanVoice;
    in profile : AcousticProfile;
    out item reflectedOutput : ReflectedSound;
  }

  action def FocusAmbientLight {
    in item incomingLight : AmbientLight;
    in reflectorEfficiency : Percent;
    out item guidedLight : FocusedLight;
  }

  action def EmitDirectionCue {
    in direction : DirectionReference;
    out item cue : OrientationCue;
  }

  action def MonitorEnvironment {
    in temperature : TemperatureC;
    in illuminance : IlluminanceLux;
    in soundLevel : SoundPressureDb;
    out item notice : MaintenanceNotice;
  }

  action def ProvideHighLevelGuidance {
    in item voice : HumanVoice;
    in item ambient : AmbientLight;
    in qibla : DirectionReference;
    out item speech : ReflectedSound;
    out item light : FocusedLight;
    out item cue : OrientationCue;

    first start;
    then receive : ReceiveVoice {
      in spokenInput = voice;
    }
    then reflect : ShapeAcousticReflection {
      in capturedVoice = receive.capturedVoice;
    }
    then illuminate : FocusAmbientLight {
      in incomingLight = ambient;
    }
    then orient : EmitDirectionCue {
      in direction = qibla;
    }
    then done;

    bind speech = reflect.reflectedOutput;
    bind light = illuminate.guidedLight;
    bind cue = orient.cue;
  }

  state def MichaabOperationalStates {
    entry action InitializeSystem;

    state Off;
    state Standby;
    state Guiding;
    state VoiceEnhancement;
    state MaintenanceRequired;
    state Fault;

    transition initial then Off;

    transition Off_to_Standby
      first Off
      accept item electricalPower : ElectricalPower
      then Standby;

    transition Standby_to_Guiding
      first Standby
      accept item cueRequest : OrientationCue
      then Guiding;

    transition Guiding_to_VoiceEnhancement
      first Guiding
      accept item voice : HumanVoice
      then VoiceEnhancement;

    transition VoiceEnhancement_to_Guiding
      first VoiceEnhancement
      after 6.0 [s]
      then Guiding;

    transition Any_to_MaintenanceRequired
      first Guiding
      accept item notice : MaintenanceNotice
      if notice.severity >= 55.0
      then MaintenanceRequired;

    transition MaintenanceRequired_to_Standby
      first MaintenanceRequired
      accept item notice : MaintenanceNotice
      if notice.severity < 20.0
      then Standby;

    transition Any_to_Fault
      first Standby
      accept item notice : MaintenanceNotice
      if notice.severity >= 90.0
      then Fault;
  }

  // ===== Requirements =====

  requirement def PrimaryFunctionRequirement {
    doc
      /* The system shall use a Michaab-derived concave niche form as the main spatial element to identify a directional focal axis and support spoken guidance at a high level. */

    subject system : MichaabBasedGuidanceSystem;

    require constraint {
      system.primaryFunctionStatement ==
      "Provide a spatial, visual, and acoustic focal point that indicates the sacred direction and improves intelligibility of spoken guidance within an interior gathering space."
    }
  }

  requirement def DirectionAlignmentRequirement {
    doc
      /* The system shall indicate the configured direction with an angular uncertainty no greater than 1.5 degrees. */

    subject system : MichaabBasedGuidanceSystem;

    require constraint {
      system.nominalQiblaDirection.uncertainty <= 1.5
    }
  }

  requirement def AcousticClarityRequirement {
    doc
      /* The acoustic treatment and concave reflector shall produce speech clarity suitable for unaided spoken guidance. */

    subject system : MichaabBasedGuidanceSystem;

    require constraint {
      system.treatment.profile.speechClarityIndex >= 80.0 and
      system.reflector.acousticGain >= 4.0
    }
  }

  requirement def LightingFocusRequirement {
    doc
      /* The lighting subsystem and reflective niche geometry shall provide visible focal illumination at the directional axis. */

    subject system : MichaabBasedGuidanceSystem;

    require constraint {
      system.lighting.profile.focalIlluminance >= 250.0 and
      system.reflector.opticalReflectance >= 55.0
    }
  }

  requirement def StructuralIntegrityRequirement {
    doc
      /* The frame and niche assembly shall sustain installed loads with a minimum structural safety factor. */

    subject system : MichaabBasedGuidanceSystem;

    require constraint {
      system.frame.loadCapacity.safetyFactor >= 2.5 and
      system.totalMass <= system.frame.loadCapacity.serviceLoad
    }
  }

  requirement def ThermalSafetyRequirement {
    doc
      /* Integrated lighting shall remain below the thermal limit during continuous operation. */

    subject system : MichaabBasedGuidanceSystem;

    require constraint {
      system.lighting.profile.dimmingLevel <= 100.0 and
      system.lighting.thermalLimit <= 65.0
    }
  }

  requirement def MaintainabilityRequirement {
    doc
      /* The system shall issue a maintenance notice when environmental or lighting health falls below the acceptable diagnostic threshold. */

    subject system : MichaabBasedGuidanceSystem;

    require constraint {
      system.sensors.diagnosticHealth >= 75.0
    }
  }

  // ===== System Instance =====

  part michaabGuidanceSystem : MichaabBasedGuidanceSystem {
    attribute nominalQiblaDirection : DirectionReference {
      azimuth = 58.2;
      elevation = 0.0;
      uncertainty = 1.0;
    }

    part niche {
      attribute qiblaAlignment : DirectionReference {
        azimuth = 58.2;
        elevation = 0.0;
        uncertainty = 1.0;
      }
    }

    part axisMarker {
      attribute engravedAzimuth = 58.2;
    }

    part frame {
      attribute loadCapacity : StructuralLoad {
        deadLoad = 515.0;
        serviceLoad = 875.0;
        safetyFactor = 2.8;
      }
    }

    part treatment {
      attribute profile : AcousticProfile {
        reverberationTime = 1.1;
        speechClarityIndex = 88.0;
        amplificationGain = 3.0;
        dominantFrequency = 1200.0;
      }
    }

    part lighting {
      attribute profile : LightingProfile {
        luminousFlux = 3200.0;
        focalIlluminance = 310.0;
        colorTemperature = 3000.0;
        dimmingLevel = 74.0;
      }
    }

    part sensors {
      attribute measuredTemperature = 31.0;
      attribute measuredIlluminance = 305.0;
      attribute measuredSoundLevel = 62.0;
      attribute diagnosticHealth = 91.0;
    }
  }

  satisfy PrimaryFunctionRequirement by michaabGuidanceSystem;
  satisfy DirectionAlignmentRequirement by michaabGuidanceSystem;
  satisfy AcousticClarityRequirement by michaabGuidanceSystem;
  satisfy LightingFocusRequirement by michaabGuidanceSystem;
  satisfy StructuralIntegrityRequirement by michaabGuidanceSystem;
  satisfy ThermalSafetyRequirement by michaabGuidanceSystem;
  satisfy MaintainabilityRequirement by michaabGuidanceSystem;
}