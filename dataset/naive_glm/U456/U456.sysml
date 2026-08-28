package Worth4DotTest {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====

    value type Distance :> Real {
        unit 'm';
    }

    value type DotCount :> Integer {
        constraint { self >= 0 and self <= 5 }
    }

    value type Luminance :> Real {
        unit 'cd/m^2';
    }

    value type Wavelength :> Real {
        unit 'nm';
    }

    enumeration DotColor {
        red;
        green;
        white;
    }

    enumeration ClinicalDiagnosis {
        normalBinocularVision;
        leftEyeSuppression;
        rightEyeSuppression;
        diplopia;
        inconclusive;
    }

    enumeration EyeSide {
        right;
        left;
    }

    enumeration LensColor {
        redLens;
        greenLens;
    }

    item def Dot {
        attribute color : DotColor;
        attribute positionX : Real;
        attribute positionY : Real;
    }

    item def DotPattern {
        attribute dots : Dot[4];
    }

    item def PerceivedImage {
        attribute reportedDotCount : DotCount;
        attribute perceivedColors : DotColor[*];
    }

    item def PatientResponse {
        attribute dotCount : DotCount;
        attribute timestamp : DateTime;
    }

    // ===== Requirements =====

    requirement def IlluminationRequirement {
        subject source : IlluminationUnit;
        objective {
            source.projectedPattern.dots.size == 4
            and source.projectedPattern.dots->select(color == DotColor::red)->size == 1
            and source.projectedPattern.dots->select(color == DotColor::green)->size == 2
            and source.projectedPattern.dots->select(color == DotColor::white)->size == 1
        }
    }

    requirement def ConsistentLightingRequirement {
        subject source : IlluminationUnit;
        attribute minLuminance : Luminance = 100 [cd/m^2];
        attribute maxLuminance : Luminance = 500 [cd/m^2];
        constraint { source.luminance >= minLuminance and source.luminance <= maxLuminance }
    }

    requirement def FilterGlassesRequirement {
        subject glasses : FilterGlasses;
        objective {
            glasses.rightLensColor == LensColor::redLens
            and glasses.leftLensColor == LensColor::greenLens
        }
    }

    requirement def TestDistanceRequirement {
        subject test : Worth4DotTestSystem;
        attribute nominalDistance : Distance = 6 [m];
        constraint { abs(test.patientDistance - nominalDistance) <= 0.5 [m] }
    }

    requirement def DiagnosticAccuracyRequirement {
        subject processor : DiagnosticProcessor;
        objective {
            processor.diagnosis in ClinicalDiagnosis
            and processor.diagnosis != ClinicalDiagnosis::inconclusive
            when processor.response.dotCount in {2, 3, 4, 5}
        }
    }

    requirement def NormalVisionRule {
        subject processor : DiagnosticProcessor;
        constraint {
            processor.response.dotCount == 4 implies processor.diagnosis == ClinicalDiagnosis::normalBinocularVision
        }
    }

    requirement def LeftSuppressionRule {
        subject processor : DiagnosticProcessor;
        constraint {
            processor.response.dotCount == 2 implies processor.diagnosis == ClinicalDiagnosis::leftEyeSuppression
        }
    }

    requirement def RightSuppressionRule {
        subject processor : DiagnosticProcessor;
        constraint {
            processor.response.dotCount == 3 implies processor.diagnosis == ClinicalDiagnosis::rightEyeSuppression
        }
    }

    requirement def DiplopiaRule {
        subject processor : DiagnosticProcessor;
        constraint {
            processor.response.dotCount == 5 implies processor.diagnosis == ClinicalDiagnosis::diplopia
        }
    }

    // ===== Ports =====

    port def LightOutput {
        out pattern : DotPattern;
        out luminanceValue : Luminance;
    }

    port def VisualInput {
        in pattern : DotPattern;
        in luminanceValue : Luminance;
    }

    port def LensInput {
        in incomingPattern : DotPattern;
    }

    port def LensOutput {
        out filteredPattern : DotPattern;
    }

    port def ResponseInput {
        in response : PatientResponse;
    }

    port def ResponseOutput {
        out response : PatientResponse;
    }

    port def DiagnosisOutput {
        out diagnosis : ClinicalDiagnosis;
    }

    port def DiagnosisInput {
        in diagnosis : ClinicalDiagnosis;
    }

    // ===== Parts =====

    part def IlluminationUnit {
        port lightOut : LightOutput;
        attribute luminance : Luminance = 250 [cd/m^2];
        attribute projectedPattern : DotPattern;

        attribute redDot : Dot = Dot{color = DotColor::red; positionX = 0.0; positionY = 0.05;};
        attribute greenDot1 : Dot = Dot{color = DotColor::green; positionX = -0.05; positionY = -0.05;};
        attribute greenDot2 : Dot = Dot{color = DotColor::green; positionX = 0.05; positionY = -0.05;};
        attribute whiteDot : Dot = Dot{color = DotColor::white; positionX = 0.0; positionY = 0.0;};

        init projectedPattern {
            dots = (redDot, greenDot1, greenDot2, whiteDot);
        }

        exhibit state illuminationBehavior {
            entry;
            then operating;

            state operating {
                entry {
                    lightOut.pattern = projectedPattern;
                    lightOut.luminanceValue = luminance;
                }
            }
        }

        satisfy IlluminationRequirement {
            subject = self;
        }

        satisfy ConsistentLightingRequirement {
            subject = self;
        }
    }

    part def FilterGlasses {
        port lensIn : LensInput;
        port rightEyeOut : LensOutput;
        port leftEyeOut : LensOutput;

        attribute rightLensColor : LensColor = LensColor::redLens;
        attribute leftLensColor : LensColor = LensColor::greenLens;

        action filterPattern {
            in incoming : DotPattern;
            out rightFiltered : DotPattern;
            out leftFiltered : DotPattern;

            perform {
                // Right eye (red lens): sees red and white dots
                rightFiltered.dots = incoming.dots->select(d |
                    d.color == DotColor::red or d.color == DotColor::white);

                // Left eye (green lens): sees green and white dots
                leftFiltered.dots = incoming.dots->select(d |
                    d.color == DotColor::green or d.color == DotColor::white);
            }
        }

        exhibit state glassesBehavior {
            entry;
            then filtering;

            state filtering {
                do {
                    filterPattern(
                        in incoming = lensIn.incomingPattern,
                        out rightFiltered = rightEyeOut.filteredPattern,
                        out leftFiltered = leftEyeOut.filteredPattern
                    );
                }
            }
        }

        satisfy FilterGlassesRequirement {
            subject = self;
        }
    }

    part def PatientInterface {
        port visualIn : VisualInput;
        port responseOut : ResponseOutput;

        attribute perceivedDotCount : DotCount;
        attribute currentResponse : PatientResponse;

        action perceiveAndReport {
            in pattern : DotPattern;
            out response : PatientResponse;

            perform {
                // Patient perceives and reports total dot count
                // Normal fusion: 4 dots
                // Left suppression: 2 dots (red only)
                // Right suppression: 3 dots (green only)
                // Diplopia: 5 dots (2 red + 3 green)
                response.dotCount = perceivedDotCount;
                response.timestamp = now;
            }
        }

        exhibit state patientBehavior {
            entry;
            then observing;

            state observing {
                do {
                    perceiveAndReport(
                        in pattern = visualIn.pattern,
                        out response = responseOut.response
                    );
                }
            }
        }
    }

    part def DiagnosticProcessor {
        port responseIn : ResponseInput;
        port diagnosisOut : DiagnosisOutput;

        attribute response : PatientResponse;
        attribute diagnosis : ClinicalDiagnosis = ClinicalDiagnosis::inconclusive;

        action determineDiagnosis {
            in inputResponse : PatientResponse;
            out outputDiagnosis : ClinicalDiagnosis;

            perform {
                if inputResponse.dotCount == 4 {
                    outputDiagnosis = ClinicalDiagnosis::normalBinocularVision;
                } else if inputResponse.dotCount == 2 {
                    outputDiagnosis = ClinicalDiagnosis::leftEyeSuppression;
                } else if inputResponse.dotCount == 3 {
                    outputDiagnosis = ClinicalDiagnosis::rightEyeSuppression;
                } else if inputResponse.dotCount == 5 {
                    outputDiagnosis = ClinicalDiagnosis::diplopia;
                } else {
                    outputDiagnosis = ClinicalDiagnosis::inconclusive;
                }
            }
        }

        exhibit state processorBehavior {
            entry;
            then idle;

            state idle {
                do {
                    response = responseIn.response;
                }
                transition idle
                    when response.dotCount in {2, 3, 4, 5}
                    to analyzing;
            }

            state analyzing {
                entry {
                    determineDiagnosis(
                        in inputResponse = response,
                        out outputDiagnosis = diagnosis
                    );
                    diagnosisOut.diagnosis = diagnosis;
                }
                then idle;
            }
        }

        satisfy DiagnosticAccuracyRequirement {
            subject = self;
        }

        satisfy NormalVisionRule {
            subject = self;
        }

        satisfy LeftSuppressionRule {
            subject = self;
        }

        satisfy RightSuppressionRule {
            subject = self;
        }

        satisfy DiplopiaRule {
            subject = self;
        }
    }

    part def Clinician {
        port diagnosisIn : DiagnosisInput;
        attribute receivedDiagnosis : ClinicalDiagnosis;

        exhibit state clinicianBehavior {
            entry;
            then reviewing;

            state reviewing {
                do {
                    receivedDiagnosis = diagnosisIn.diagnosis;
                }
            }
        }
    }

    // ===== Top-level System =====

    part def Worth4DotTestSystem {
        attribute patientDistance : Distance = 6 [m];

        part illumination : IlluminationUnit;
        part glasses : FilterGlasses;
        part patientInterface : PatientInterface;
        part processor : DiagnosticProcessor;
        part clinician : Clinician;

        // Connections
        connection illuminationToGlasses connect
            illumination.lightOut.pattern to glasses.lensIn.incomingPattern;

        connection glassesToPatientRight connect
            glasses.rightEyeOut.filteredPattern to patientInterface.visualIn.pattern;

        connection glassesToPatientLeft connect
            glasses.leftEyeOut.filteredPattern to patientInterface.visualIn.pattern;

        connection patientToProcessor connect
            patientInterface.responseOut.response to processor.responseIn.response;

        connection processorToClinician connect
            processor.diagnosisOut.diagnosis to clinician.diagnosisIn.diagnosis;

        satisfy TestDistanceRequirement {
            subject = self;
        }

        exhibit state testProcedure {
            entry;
            then setup;

            state setup {
                entry {
                    // Patient wears filter glasses at specified distance
                }
                then illuminating;
            }

            state illuminating {
                do {
                    // Illumination unit projects four-dot pattern
                }
                then patientObserving;
            }

            state patientObserving {
                do {
                    // Patient perceives pattern through filter glasses
                    // and reports total dot count
                }
                then diagnosing;
            }

            state diagnosing {
                do {
                    // Diagnostic processor determines clinical diagnosis
                }
                then complete;
            }

            state complete {
                entry {
                    // Clinician reviews diagnosis
                }
            }
        }
    }

    // ===== Test Cases =====

    test def VerifyNormalVisionDiagnosis {
        subject processor : DiagnosticProcessor;
        objective {
            processor.response.dotCount == 4
            and processor.diagnosis == ClinicalDiagnosis::normalBinocularVision
        }
    }

    test def VerifyLeftEyeSuppressionDiagnosis {
        subject processor : DiagnosticProcessor;
        objective {
            processor.response.dotCount == 2
            and processor.diagnosis == ClinicalDiagnosis::leftEyeSuppression
        }
    }

    test def VerifyRightEyeSuppressionDiagnosis {
        subject processor : DiagnosticProcessor;
        objective {
            processor.response.dotCount == 3
            and processor.diagnosis == ClinicalDiagnosis::rightEyeSuppression
        }
    }

    test def VerifyDiplopiaDiagnosis {
        subject processor : DiagnosticProcessor;
        objective {
            processor.response.dotCount == 5
            and processor.diagnosis == ClinicalDiagnosis::diplopia
        }
    }

    test def VerifyIlluminationPattern {
        subject illumination : IlluminationUnit;
        objective {
            illumination.projectedPattern.dots.size == 4
        }
    }

    test def VerifyFilterGlassesConfiguration {
        subject glasses : FilterGlasses;
        objective {
            glasses.rightLensColor == LensColor::redLens
            and glasses.leftLensColor == LensColor::greenLens
        }
    }

}
