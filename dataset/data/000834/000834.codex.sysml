package WorthFourDotTestSystem {

  enum def Eye { right; left; both; unknown; }

  enum def DotColor { red; green; white; yellow; }

  enum def PerceptClass {
    fusion;
    rightEyeSuppression;
    leftEyeSuppression;
    diplopia;
    inconclusive;
  }

  value type Distance {
    unit m;
  }

  value type Illuminance {
    unit lx;
  }

  value type Luminance {
    unit cd_per_m2;
  }

  value type Wavelength {
    unit nm;
  }

  value type Angle {
    unit deg;
  }

  value type Duration {
    unit s;
  }

  value type Count {
    unit one;
  }

  value type Confidence {
    unit percent;
  }

  item def DotStimulus {
    attribute dotId : String;
    attribute color : DotColor;
    attribute apparentAngularDiameter : Angle;
    attribute luminance : Luminance;
  }

  item def FilteredLight {
    attribute sourceColor : DotColor;
    attribute transmittedColor : DotColor;
    attribute peakWavelength : Wavelength;
    attribute luminanceAtEye : Luminance;
  }

  item def PatientReport {
    attribute reportedDotCount : Count;
    attribute reportedRedCount : Count;
    attribute reportedGreenCount : Count;
    attribute reportedWhiteOrYellowCount : Count;
    attribute perceivedSeparation : Angle;
    attribute reportLatency : Duration;
  }

  item def TestResult {
    attribute classification : PerceptClass;
    attribute confidence : Confidence;
    attribute explanation : String;
  }

  port def OpticalDisplayPort {
    out item stimulus : DotStimulus;
  }

  port def FilterInputPort {
    in item incidentLight : DotStimulus;
  }

  port def FilterOutputPort {
    out item filteredLight : FilteredLight;
  }

  port def VisualPerceptionPort {
    in item retinalInput : FilteredLight;
  }

  port def ResponsePort {
    out item report : PatientReport;
  }

  port def ClinicianCommandPort {
    in attribute startRequested : Boolean;
    in attribute stopRequested : Boolean;
    in attribute testDistance : Distance;
    in attribute roomIlluminanceLimit : Illuminance;
  }

  port def ResultPort {
    out item result : TestResult;
  }

  part def FourDotTarget {
    attribute targetDistance : Distance = 6.0 [m];
    attribute backgroundLuminance : Luminance = 2.0 [cd_per_m2];

    part redDot : DotStimulus {
      attribute dotId = "upper red dot";
      attribute color = DotColor::red;
      attribute apparentAngularDiameter = 0.50 [deg];
      attribute luminance = 25.0 [cd_per_m2];
    }

    part leftGreenDot : DotStimulus {
      attribute dotId = "left green dot";
      attribute color = DotColor::green;
      attribute apparentAngularDiameter = 0.50 [deg];
      attribute luminance = 25.0 [cd_per_m2];
    }

    part rightGreenDot : DotStimulus {
      attribute dotId = "right green dot";
      attribute color = DotColor::green;
      attribute apparentAngularDiameter = 0.50 [deg];
      attribute luminance = 25.0 [cd_per_m2];
    }

    part lowerWhiteDot : DotStimulus {
      attribute dotId = "lower white dot";
      attribute color = DotColor::white;
      attribute apparentAngularDiameter = 0.50 [deg];
      attribute luminance = 30.0 [cd_per_m2];
    }

    port opticalOut : OpticalDisplayPort;
  }

  part def RedGreenGlasses {
    attribute redLensEye : Eye = Eye::right;
    attribute greenLensEye : Eye = Eye::left;

    part redLens {
      attribute peakTransmission : Wavelength = 630.0 [nm];
      port input : FilterInputPort;
      port output : FilterOutputPort;
    }

    part greenLens {
      attribute peakTransmission : Wavelength = 535.0 [nm];
      port input : FilterInputPort;
      port output : FilterOutputPort;
    }
  }

  part def Patient {
    attribute ageYears : Count;
    attribute wearingCorrection : Boolean;

    port rightEyeInput : VisualPerceptionPort;
    port leftEyeInput : VisualPerceptionPort;
    port responseOut : ResponsePort;
  }

  part def TestController {
    attribute commandedDistance : Distance = 6.0 [m];
    attribute maximumRoomIlluminance : Illuminance = 20.0 [lx];
    attribute stimulusPresentationTime : Duration = 10.0 [s];

    port clinicianCommand : ClinicianCommandPort;
    port resultOut : ResultPort;
  }

  part def PerceptClassifier {
    port responseIn : ResponsePort;
    port resultOut : ResultPort;

    action classifyReport {
      in item report : PatientReport;
      out item result : TestResult;

      if report.reportedDotCount == 4 [one] then {
        result.classification = PerceptClass::fusion;
        result.confidence = 95 [percent];
        result.explanation = "Four-dot perception indicates simultaneous binocular perception with fusion.";
      } else if report.reportedDotCount == 2 [one] and report.reportedRedCount == 2 [one] then {
        result.classification = PerceptClass::leftEyeSuppression;
        result.confidence = 90 [percent];
        result.explanation = "Only red-filter-visible dots reported, indicating suppression of the eye behind the green lens.";
      } else if report.reportedDotCount == 3 [one] and report.reportedGreenCount == 3 [one] then {
        result.classification = PerceptClass::rightEyeSuppression;
        result.confidence = 90 [percent];
        result.explanation = "Only green-filter-visible dots reported, indicating suppression of the eye behind the red lens.";
      } else if report.reportedDotCount == 5 [one] then {
        result.classification = PerceptClass::diplopia;
        result.confidence = 92 [percent];
        result.explanation = "Five-dot perception indicates simultaneous perception without sensory fusion.";
      } else {
        result.classification = PerceptClass::inconclusive;
        result.confidence = 50 [percent];
        result.explanation = "Report does not match standard Worth four-dot response patterns.";
      }
    }
  }

  part def WorthFourDotTestSystem {
    attribute primaryFunction : String =
      "Present a calibrated red-green-white four-dot stimulus through dissociating color filters, collect the patient's perceived dot count and colors, and classify binocular visual function as fusion, suppression, diplopia, or inconclusive.";

    part target : FourDotTarget;
    part glasses : RedGreenGlasses;
    part patient : Patient;
    part controller : TestController;
    part classifier : PerceptClassifier;

    connect target.opticalOut to glasses.redLens.input;
    connect target.opticalOut to glasses.greenLens.input;
    connect glasses.redLens.output to patient.rightEyeInput;
    connect glasses.greenLens.output to patient.leftEyeInput;
    connect patient.responseOut to classifier.responseIn;
    connect classifier.resultOut to controller.resultOut;

    state def TestSession {
      state idle;
      state setup;
      state presentingStimulus;
      state collectingResponse;
      state classifying;
      state completed;
      state aborted;

      entry action initialize {
        controller.commandedDistance = 6.0 [m];
        controller.maximumRoomIlluminance = 20.0 [lx];
      }

      transition idle_to_setup
        first idle
        then setup
        accept controller.clinicianCommand.startRequested;

      transition setup_to_presenting
        first setup
        then presentingStimulus
        if controller.clinicianCommand.testDistance == controller.commandedDistance;

      transition presenting_to_collecting
        first presentingStimulus
        then collectingResponse
        after controller.stimulusPresentationTime;

      transition collecting_to_classifying
        first collectingResponse
        then classifying
        accept patient.responseOut.report;

      transition classifying_to_completed
        first classifying
        then completed;

      transition abort_from_setup
        first setup
        then aborted
        accept controller.clinicianCommand.stopRequested;

      transition abort_from_presenting
        first presentingStimulus
        then aborted
        accept controller.clinicianCommand.stopRequested;
    }
  }

  requirement def PrimaryFunctionRequirement {
    subject system : WorthFourDotTestSystem;

    require constraint {
      system.primaryFunction != "";
    }

    doc
      /* The system shall perform a Worth four-dot binocular vision test by presenting one red, two green, and one white target element through red-green glasses and producing a high-level classification of the patient's binocular sensory response. */
  }

  requirement def StimulusCompositionRequirement {
    subject target : FourDotTarget;

    require constraint {
      target.redDot.color == DotColor::red and
      target.leftGreenDot.color == DotColor::green and
      target.rightGreenDot.color == DotColor::green and
      target.lowerWhiteDot.color == DotColor::white;
    }

    doc
      /* The displayed target shall contain exactly four clinically recognizable dots: one red, two green, and one white. */
  }

  requirement def FilterAssignmentRequirement {
    subject glasses : RedGreenGlasses;

    require constraint {
      glasses.redLensEye == Eye::right and
      glasses.greenLensEye == Eye::left;
    }

    doc
      /* The standard test configuration shall place the red filter before the right eye and the green filter before the left eye. */
  }

  requirement def FusionClassificationRequirement {
    subject classifier : PerceptClassifier;

    doc
      /* A patient report of four dots shall be classified as fusion when the reported colors are compatible with combined binocular perception of the Worth four-dot target. */
  }

  requirement def SuppressionClassificationRequirement {
    subject classifier : PerceptClassifier;

    doc
      /* A report of only two red dots shall indicate suppression of the eye behind the green lens, and a report of only three green dots shall indicate suppression of the eye behind the red lens. */
  }

  requirement def DiplopiaClassificationRequirement {
    subject classifier : PerceptClassifier;

    doc
      /* A report of five dots shall be classified as diplopia because the white dot is perceived separately by both eyes while fusion is absent. */
  }

}