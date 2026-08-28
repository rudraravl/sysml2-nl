package 'Direct Ophthalmoscope System' {

    private import ScalarValues::*;

    item def ElectricalPower;
    item def RawLight;
    item def CondensedLight;
    item def DirectedLight;
    item def RetinalReflection;
    item def CapturedImage;
    item def MagnifiedImage;
    item def DiagnosticReport;

    part def PowerSupply {
        attribute voltage : Real = 3.7;
        attribute current : Real = 0.5;
        port powerOut : ElectricalPower;
    }

    part def IlluminationSource {
        attribute luminousFlux : Real = 50;
        attribute intensity : Real = 150;
        port powerIn : ElectricalPower;
        port lightOut : RawLight;
    }

    part def CondensingLens {
        attribute focalLength : Real = 25;
        port lightIn : RawLight;
        port lightOut : CondensedLight;
    }

    part def ReflectingMirror {
        port lightIn : CondensedLight;
        port lightOut : DirectedLight;
    }

    part def PatientEye {
        port lightIn : DirectedLight;
        port reflectionOut : RetinalReflection;
    }

    part def ObjectiveLens {
        attribute focalLength : Real = 25;
        attribute workingDistance : Real = 30;
        port reflectionIn : RetinalReflection;
        port imageOut : CapturedImage;
    }

    part def ViewingOptics {
        attribute magnification : Real = 15;
        port imageIn : CapturedImage;
        port magnifiedOut : MagnifiedImage;
    }

    part def Clinician {
        port observationIn : MagnifiedImage;
        port reportOut : DiagnosticReport;
    }

    action def PreparePatient;
    action def ActivateLight;
    action def AlignInstrument;
    action def AdjustFocus;

    action def ObserveRetina {
        out item observation : MagnifiedImage;
    }

    action def DocumentFindings {
        in item observation : MagnifiedImage;
        out item report : DiagnosticReport;
    }

    action def PerformExamination {
        out item report : DiagnosticReport;

        action prepare : PreparePatient;
        action activate : ActivateLight;
        action align : AlignInstrument;
        action adjust : AdjustFocus;
        action observe : ObserveRetina {
            out item observation;
        }
        action document : DocumentFindings {
            in item observation;
            out item report = PerformExamination::report;
        }

        flow from observe.observation to document.observation;

        first prepare then activate;
        then align;
        then adjust;
        then observe;
        then document;
    }

    requirement def MagnificationRequirement {
        attribute magnification : Real;
        require magnification >= 15;
    }

    requirement def WorkingDistanceRequirement {
        attribute workingDistance : Real;
        require workingDistance >= 10 and workingDistance <= 50;
    }

    requirement def IlluminationIntensityRequirement {
        attribute intensity : Real;
        require intensity <= 1000;
    }

    part def Ophthalmoscope {
        attribute powerButtonPressed : Boolean = false;
        attribute powerButtonReleased : Boolean = false;
        attribute examinationTrigger : Boolean = false;
        attribute examinationComplete : Boolean = false;

        part powerSupply : PowerSupply;
        part illuminationSource : IlluminationSource;
        part condensingLens : CondensingLens;
        part reflectingMirror : ReflectingMirror;
        part objectiveLens : ObjectiveLens;
        part viewingOptics : ViewingOptics;
        part patientEye : PatientEye;
        part clinician : Clinician;

        connect powerSupply.powerOut to illuminationSource.powerIn;
        connect illuminationSource.lightOut to condensingLens.lightIn;
        connect condensingLens.lightOut to reflectingMirror.lightIn;
        connect reflectingMirror.lightOut to patientEye.lightIn;
        connect patientEye.reflectionOut to objectiveLens.reflectionIn;
        connect objectiveLens.imageOut to viewingOptics.imageIn;
        connect viewingOptics.magnifiedOut to clinician.observationIn;

        perform action examination : PerformExamination;

        state machine deviceStates {
            state off;
            state standby;
            state examining;
            transition from off to standby when powerButtonPressed;
            transition from standby to examining when examinationTrigger;
            transition from examining to standby when examinationComplete;
            transition from standby to off when powerButtonReleased;
        }

        requirement magnificationReq : MagnificationRequirement;
        requirement workingDistanceReq : WorkingDistanceRequirement;
        requirement illuminationReq : IlluminationIntensityRequirement;

        satisfy magnificationReq by viewingOptics;
        satisfy workingDistanceReq by objectiveLens;
        satisfy illuminationReq by illuminationSource;
    }

    part ophthalmoscope : Ophthalmoscope;
}
