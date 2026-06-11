package StethoscopeSystemModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Frequency {
    :> scalar;
    unit = "Hz";
  }

  attribute def SoundPressureLevel {
    :> scalar;
    unit = "dB";
  }

  attribute def AcousticImpedance {
    :> scalar;
    unit = "Pa*s/m^3";
  }

  attribute def Length {
    :> scalar;
    unit = "mm";
  }

  attribute def Mass {
    :> scalar;
    unit = "g";
  }

  attribute def Force {
    :> scalar;
    unit = "N";
  }

  attribute def Duration {
    :> scalar;
    unit = "s";
  }

  item def BodySound {
    attribute centerFrequency : Frequency;
    attribute soundLevel : SoundPressureLevel;
    attribute sourceRegion : String;
  }

  item def MechanicalVibration {
    attribute frequency : Frequency;
    attribute amplitudeLevel : SoundPressureLevel;
  }

  item def AirPressureWave {
    attribute frequency : Frequency;
    attribute level : SoundPressureLevel;
  }

  item def DiagnosticCue {
    attribute cueName : String;
    attribute confidence : Real;
    attribute anatomicalRegion : String;
  }

  port def AcousticContactPort {
    in item incomingSound : BodySound;
    out item reflectedVibration : MechanicalVibration;
  }

  port def AcousticTubePort {
    inout item pressureWave : AirPressureWave;
  }

  port def EarInterfacePort {
    out item perceivedSound : AirPressureWave;
  }

  port def UserForcePort {
    in attribute appliedForce : Force;
  }

  part def Stethoscope {
    attribute totalMass : Mass = 180 [g];
    attribute usableFrequencyMin : Frequency = 20 [Hz];
    attribute usableFrequencyMax : Frequency = 1000 [Hz];

    port patientInterface : AcousticContactPort;
    port leftEarOutput : EarInterfacePort;
    port rightEarOutput : EarInterfacePort;
    port clinicianInput : UserForcePort;

    part chestpiece : Chestpiece;
    part flexibleTubing : BinauralTubing;
    part headset : Headset;

    connect patientInterface to chestpiece.contactSurface;
    connect clinicianInput to chestpiece.holdDownForce;
    connect chestpiece.stemOutput to flexibleTubing.inputStem;
    connect flexibleTubing.leftBranch to headset.leftAcousticInput;
    connect flexibleTubing.rightBranch to headset.rightAcousticInput;
    connect headset.leftEartipOutput to leftEarOutput;
    connect headset.rightEartipOutput to rightEarOutput;

    perform action auscultate : Auscultation;
    exhibit state usageState : StethoscopeUsageState;
  }

  part def Chestpiece {
    attribute diameter : Length = 45 [mm];
    attribute acousticSealForceMin : Force = 2 [N];

    port contactSurface : AcousticContactPort;
    port stemOutput : AcousticTubePort;
    port holdDownForce : UserForcePort;

    part diaphragm : Diaphragm;
    part bell : Bell;
    part selectorValve : ModeSelectorValve;

    connect contactSurface to diaphragm.patientSide;
    connect diaphragm.airSide to selectorValve.diaphragmInput;
    connect bell.openCup to selectorValve.bellInput;
    connect selectorValve.selectedOutput to stemOutput;
  }

  part def Diaphragm {
    attribute membraneDiameter : Length = 43 [mm];
    attribute membraneMass : Mass = 2 [g];
    attribute lowFrequencyAttenuation : SoundPressureLevel = 12 [dB];

    port patientSide : AcousticContactPort;
    port airSide : AcousticTubePort;

    action convertContactSound {
      in item bodySound : BodySound;
      out item airWave : AirPressureWave;

      first start;
      then transformVibration;

      action transformVibration {
        in item bodySound;
        out item airWave;
      }
    }
  }

  part def Bell {
    attribute cupDiameter : Length = 30 [mm];
    attribute preferredFrequencyMax : Frequency = 150 [Hz];

    port openCup : AcousticTubePort;
  }

  part def ModeSelectorValve {
    attribute selectedMode : String = "diaphragm";

    port diaphragmInput : AcousticTubePort;
    port bellInput : AcousticTubePort;
    port selectedOutput : AcousticTubePort;

    state def ValveState {
      state diaphragmMode;
      state bellMode;

      transition first diaphragmMode;
      transition diaphragmMode then bellMode accept ToggleMode;
      transition bellMode then diaphragmMode accept ToggleMode;
    }
  }

  part def BinauralTubing {
    attribute tubeLength : Length = 560 [mm];
    attribute internalDiameter : Length = 4 [mm];
    attribute acousticLossAt500Hz : SoundPressureLevel = 3 [dB];

    port inputStem : AcousticTubePort;
    port leftBranch : AcousticTubePort;
    port rightBranch : AcousticTubePort;

    part mainTube : AcousticTube;
    part yJunction : AcousticYJunction;
    part leftTube : AcousticTube;
    part rightTube : AcousticTube;

    connect inputStem to mainTube.inlet;
    connect mainTube.outlet to yJunction.singleSide;
    connect yJunction.leftSide to leftTube.inlet;
    connect yJunction.rightSide to rightTube.inlet;
    connect leftTube.outlet to leftBranch;
    connect rightTube.outlet to rightBranch;
  }

  part def AcousticTube {
    attribute length : Length;
    attribute impedance : AcousticImpedance;

    port inlet : AcousticTubePort;
    port outlet : AcousticTubePort;
  }

  part def AcousticYJunction {
    port singleSide : AcousticTubePort;
    port leftSide : AcousticTubePort;
    port rightSide : AcousticTubePort;
  }

  part def Headset {
    attribute springClampForce : Force = 3 [N];

    port leftAcousticInput : AcousticTubePort;
    port rightAcousticInput : AcousticTubePort;
    port leftEartipOutput : EarInterfacePort;
    port rightEartipOutput : EarInterfacePort;

    part leftMetalTube : EarTube;
    part rightMetalTube : EarTube;
    part leftEartip : Eartip;
    part rightEartip : Eartip;

    connect leftAcousticInput to leftMetalTube.inlet;
    connect rightAcousticInput to rightMetalTube.inlet;
    connect leftMetalTube.outlet to leftEartip.inlet;
    connect rightMetalTube.outlet to rightEartip.inlet;
    connect leftEartip.outlet to leftEartipOutput;
    connect rightEartip.outlet to rightEartipOutput;
  }

  part def EarTube {
    attribute bendAngle : Real = 15;
    attribute length : Length = 180 [mm];

    port inlet : AcousticTubePort;
    port outlet : AcousticTubePort;
  }

  part def Eartip {
    attribute sealCompliance : Real = 0.85;
    attribute externalNoiseReduction : SoundPressureLevel = 18 [dB];

    port inlet : AcousticTubePort;
    port outlet : EarInterfacePort;
  }

  action def Auscultation {
    in item bodySound : BodySound;
    in attribute contactForce : Force;
    out item clinicianPerceivedSound : AirPressureWave;
    out item diagnosticCue : DiagnosticCue;

    first positionChestpiece;
    then establishAcousticSeal;
    then collectBodySound;
    then transmitSound;
    then perceiveSound;
    then identifyCue;
    then done;

    action positionChestpiece;
    action establishAcousticSeal;
    action collectBodySound;
    action transmitSound;
    action perceiveSound;
    action identifyCue;
  }

  state def StethoscopeUsageState {
    state stored;
    state positioned;
    state sealed;
    state listening;
    state repositioning;
    state cleaning;

    transition first stored;
    transition stored then positioned accept PlaceChestpiece;
    transition positioned then sealed accept ApplyContactForce;
    transition sealed then listening accept BeginAuscultation;
    transition listening then repositioning accept MoveToNewSite;
    transition repositioning then positioned accept PlaceChestpiece;
    transition listening then cleaning accept EndExam;
    transition cleaning then stored accept StoreDevice;
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The stethoscope shall collect low-level acoustic body sounds from a patient surface, transmit them through a passive acoustic path, and deliver amplified perception cues to both ears of a clinician for high-level assessment of heart, lung, and vascular function. */

    subject stethoscope : Stethoscope;

    require constraint {
      stethoscope.usableFrequencyMin <= 20 [Hz] and
      stethoscope.usableFrequencyMax >= 1000 [Hz]
    }
  }

  requirement def AcousticTransmissionRequirement {
    doc /* The acoustic path shall transmit clinically relevant body sounds from the chestpiece to both eartips with limited loss across the auscultation band. */

    subject tubing : BinauralTubing;

    require constraint {
      tubing.acousticLossAt500Hz <= 6 [dB]
    }
  }

  requirement def EarSealRequirement {
    doc /* Each eartip shall reduce ambient sound intrusion so body sounds remain distinguishable during routine clinical use. */

    subject headset : Headset;

    require constraint {
      headset.leftEartip.externalNoiseReduction >= 15 [dB] and
      headset.rightEartip.externalNoiseReduction >= 15 [dB]
    }
  }

  requirement def ContactSealRequirement {
    doc /* The chestpiece shall form an effective acoustic seal against the patient when the clinician applies normal examination force. */

    subject chestpiece : Chestpiece;

    require constraint {
      chestpiece.acousticSealForceMin <= 3 [N]
    }
  }

  part clinicalStethoscope : Stethoscope;

  satisfy PrimaryFunctionRequirement by clinicalStethoscope;
  satisfy AcousticTransmissionRequirement by clinicalStethoscope.flexibleTubing;
  satisfy EarSealRequirement by clinicalStethoscope.headset;
  satisfy ContactSealRequirement by clinicalStethoscope.chestpiece;
}