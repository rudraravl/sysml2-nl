package Worth4DotTestSystem {
    private import ScalarValues::*;
    private import SI::*;

    enum def ColorEnum {
        red;
        green;
        white;
    }

    enum def DiagnosisEnum {
        normal;
        leftSuppression;
        rightSuppression;
        diplopia;
        unknown;
    }

    enum def VisionStatus {
        fused;
        leftSuppressed;
        rightSuppressed;
        unfused;
    }

    part def Dot {
        attribute color : ColorEnum;
    }

    attribute def DotCount :> Integer;

    port def DotPort {
        out dots : Dot[0..*];
    }

    port def CountPort {
        out count : DotCount;
    }

    port def DiagnosisPort {
        out diagnosis : DiagnosisEnum;
    }

    part def IlluminationUnit {
        part dot1 : Dot { attribute :>> color = ColorEnum::red; }
        part dot2 : Dot { attribute :>> color = ColorEnum::green; }
        part dot3 : Dot { attribute :>> color = ColorEnum::green; }
        part dot4 : Dot { attribute :>> color = ColorEnum::white; }

        port dotProjectionPort : DotPort {
            out :>> dots = (dot1, dot2, dot3, dot4);
        }

        action projectPattern {
            out pattern : Dot[4] = (dot1, dot2, dot3, dot4);
        }
    }

    part def Lens {
        attribute filterColor : ColorEnum;
    }

    part def FilterGlasses {
        port dotPort : DotPort;
        port rightEyePort : DotPort;
        port leftEyePort : DotPort;

        part rightLens : Lens {
            attribute :>> filterColor = ColorEnum::red;
        }
        part leftLens : Lens {
            attribute :>> filterColor = ColorEnum::green;
        }

        action filterDots {
            in dots : Dot[0..*] = dotPort.dots;
            out rightDots : Dot[0..*] = dots.select(d => d.color == ColorEnum::red or d.color == ColorEnum::white);
            out leftDots : Dot[0..*] = dots.select(d => d.color == ColorEnum::green or d.color == ColorEnum::white);
        }

        bind rightEyePort.dots = filterDots.rightDots;
        bind leftEyePort.dots = filterDots.leftDots;
    }

    calc def PerceiveCount {
        in rightDotCount : DotCount;
        in leftDotCount : DotCount;
        in status : VisionStatus;
        return count : DotCount =
            status == VisionStatus::fused ? 4 :
            status == VisionStatus::leftSuppressed ? 2 :
            status == VisionStatus::rightSuppressed ? 3 :
            status == VisionStatus::unfused ? 5 : 0;
    }

    part def Patient {
        port rightEyePort : DotPort;
        port leftEyePort : DotPort;
        port reportPort : CountPort;

        attribute visionStatus : VisionStatus;

        calc perception : PerceiveCount {
            in rightDotCount = rightEyePort.dots.size();
            in leftDotCount = leftEyePort.dots.size();
            in status = visionStatus;
        }

        bind reportPort.count = perception.count;
    }

    part def PatientInterface {
        port reportPort : CountPort;
        port transmittedPort : CountPort;

        action transmit {
            in count : DotCount = reportPort.count;
            out transmittedCount : DotCount = count;
        }

        bind transmittedPort.count = transmit.transmittedCount;
    }

    calc def MapCountToDiagnosis {
        in dotCount : DotCount;
        return diagnosis : DiagnosisEnum =
            dotCount == 4 ? DiagnosisEnum::normal :
            dotCount == 2 ? DiagnosisEnum::leftSuppression :
            dotCount == 3 ? DiagnosisEnum::rightSuppression :
            dotCount == 5 ? DiagnosisEnum::diplopia : DiagnosisEnum::unknown;
    }

    part def DiagnosticProcessor {
        port transmittedPort : CountPort;
        port diagnosisPort : DiagnosisPort;

        calc mapping : MapCountToDiagnosis {
            in dotCount = transmittedPort.count;
        }

        bind diagnosisPort.diagnosis = mapping.diagnosis;
    }

    event def startTest;
    event def responseReceived;

    state machine def TestProcedure {
        state idle;
        transition on startTest to projecting;
        state projecting;
        transition to awaitingResponse;
        state awaitingResponse;
        transition on responseReceived to diagnosing;
        state diagnosing;
        transition to complete;
        state complete;
    }

    requirement def BinocularVisionRequirement {
        doc /* The system shall accurately diagnose binocular vision status based on the patient's perceived dot count. */
        subject testSystem : Worth4DotTestSystem;
        attribute reportedCount : DotCount;
        attribute expectedDiagnosis : DiagnosisEnum;

        require constraint {
            (reportedCount == 4 and expectedDiagnosis == DiagnosisEnum::normal) or
            (reportedCount == 2 and expectedDiagnosis == DiagnosisEnum::leftSuppression) or
            (reportedCount == 3 and expectedDiagnosis == DiagnosisEnum::rightSuppression) or
            (reportedCount == 5 and expectedDiagnosis == DiagnosisEnum::diplopia)
        }
    }

    part def Worth4DotTestSystem {
        part illuminationUnit : IlluminationUnit;
        part filterGlasses : FilterGlasses;
        part patient : Patient;
        part patientInterface : PatientInterface;
        part diagnosticProcessor : DiagnosticProcessor;

        connect illuminationUnit.dotProjectionPort to filterGlasses.dotPort;
        connect filterGlasses.rightEyePort to patient.rightEyePort;
        connect filterGlasses.leftEyePort to patient.leftEyePort;
        connect patient.reportPort to patientInterface.reportPort;
        connect patientInterface.transmittedPort to diagnosticProcessor.transmittedPort;

        perform TestProcedure;

        requirement binocularVisionRequirement : BinocularVisionRequirement {
            subject :>> testSystem = self;
            attribute :>> reportedCount = diagnosticProcessor.transmittedPort.count;
            attribute :>> expectedDiagnosis = diagnosticProcessor.diagnosisPort.diagnosis;
        }
    }

    analysis def Worth4DotTestAnalysis {
        subject testSystem : Worth4DotTestSystem;
        requirement binocularVisionReq : BinocularVisionRequirement;

        attribute testCounts : DotCount[4] = (4, 2, 3, 5);
        attribute expectedDiagnoses : DiagnosisEnum[4] = (
            DiagnosisEnum::normal,
            DiagnosisEnum::leftSuppression,
            DiagnosisEnum::rightSuppression,
            DiagnosisEnum::diplopia
        );

        objective {
            doc /* Verify that the diagnostic processor correctly maps each reported dot count to the expected clinical diagnosis. */
        }
    }
}
