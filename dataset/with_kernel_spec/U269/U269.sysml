package DigitalRadiographySystem {
    private import ScalarValues::*;

    value def Voltage :> Real;
    value def Current :> Real;
    value def Temperature :> Real;
    value def Dose :> Real;
    value def Length :> Real;
    value def Angle :> Real;
    value def Mass :> Real;
    value def Duration :> Real;
    value def FlowRate :> Real;

    item def XRayBeam;
    item def Coolant;
    item def RawImageData;
    item def ProcessedImage;
    item def DoseReport;
    item def ControlCommand;
    item def ExposureParameters {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute duration : Duration;
    }

    attribute def StartExamSignal;
    attribute def ProtocolSetSignal;
    attribute def ExposeCommandSignal;
    attribute def ExposureCompleteSignal;
    attribute def DataCapturedSignal;
    attribute def ProcessingCompleteSignal;
    attribute def ImageAcceptedSignal;
    attribute def ImageRejectedSignal;
    attribute def ArchiveCompleteSignal;
    attribute def EmergencyStopSignal;
    attribute def EmergencyResetSignal;

    action def GenerateXRay {
        in power : Voltage;
        out beam : XRayBeam;
    }
    action def SupplyPower {
        in params : ExposureParameters;
        out power : Voltage;
    }
    action def CirculateCoolant {
        out coolant : Coolant;
    }
    action def ShapeBeam {
        in beamIn : XRayBeam;
        out beamOut : XRayBeam;
    }
    action def PositionPatient {
        in height : Length;
        in angle : Angle;
    }
    action def CaptureData {
        in beam : XRayBeam;
        out data : RawImageData;
    }
    action def ProcessImage {
        in rawData : RawImageData;
        out image : ProcessedImage;
    }
    action def CalculateDose {
        in params : ExposureParameters;
        out report : DoseReport;
    }
    action def SelectProtocol {
        out params : ExposureParameters;
    }
    action def ReviewImage {
        in image : ProcessedImage;
    }
    action def ArchiveStudy {
        in image : ProcessedImage;
        in report : DoseReport;
    }

    part def XRayTube {
        port powerIn { in item power : Voltage; }
        port coolantIn { in item coolant : Coolant; }
        port beamOut { out item beam : XRayBeam; }
        attribute maxTemp : Temperature;
        perform action generateXRay : GenerateXRay;
    }
    part def HighVoltageGenerator {
        port powerOut { out item power : Voltage; }
        port controlIn { in item command : ControlCommand; }
        perform action supplyPower : SupplyPower;
    }
    part def CoolingSystem {
        port coolantOut { out item coolant : Coolant; }
        port controlIn { in item command : ControlCommand; }
        attribute flowRate : FlowRate;
        perform action circulateCoolant : CirculateCoolant;
    }
    part def BeamCollimator {
        port beamIn { in item beam : XRayBeam; }
        port beamOut { out item beam : XRayBeam; }
        port controlIn { in item command : ControlCommand; }
        attribute bladeX : Length;
        attribute bladeY : Length;
        perform action shapeBeam : ShapeBeam;
    }
    part def PatientPositioningTable {
        port controlIn { in item command : ControlCommand; }
        attribute height : Length;
        attribute angle : Angle;
        attribute maxLoad : Mass;
        perform action positionPatient : PositionPatient;
    }
    part def DigitalDetector {
        port beamIn { in item beam : XRayBeam; }
        port dataOut { out item data : RawImageData; }
        port controlIn { in item command : ControlCommand; }
        perform action captureData : CaptureData;
    }
    part def ImageProcessingUnit {
        port dataIn { in item data : RawImageData; }
        port imageOut { out item image : ProcessedImage; }
        port controlIn { in item command : ControlCommand; }
        perform action processImage : ProcessImage;
    }
    part def DoseManagementSystem {
        port reportOut { out item report : DoseReport; }
        port controlIn { in item command : ControlCommand; }
        attribute cumulativeDose : Dose;
        perform action calculateDose : CalculateDose;
    }
    part def OperatorWorkstation {
        port controlOut { out item command : ControlCommand; }
        port imageIn { in item image : ProcessedImage; }
        port reportIn { in item report : DoseReport; }
        perform action selectProtocol : SelectProtocol;
        perform action reviewImage : ReviewImage;
        perform action archiveStudy : ArchiveStudy;
    }

    state def SystemStates {
        entry; then standby;
        state standby;
        accept StartExamSignal then preparation;
        state preparation {
            do action selectProtocol : SelectProtocol;
            do action positionPatient : PositionPatient;
            do action calculateDose : CalculateDose;
        }
        accept ProtocolSetSignal then ready;
        state ready;
        accept ExposeCommandSignal then exposing;
        accept EmergencyStopSignal then emergency;
        state exposing {
            do action supplyPower : SupplyPower;
            do action circulateCoolant : CirculateCoolant;
            do action generateXRay : GenerateXRay;
            do action shapeBeam : ShapeBeam;
        }
        accept ExposureCompleteSignal then acquiring;
        accept EmergencyStopSignal then emergency;
        state acquiring {
            do action captureData : CaptureData;
        }
        accept DataCapturedSignal then processing;
        state processing {
            do action processImage : ProcessImage;
        }
        accept ProcessingCompleteSignal then review;
        state review {
            do action reviewImage : ReviewImage;
        }
        accept ImageAcceptedSignal then archiving;
        accept ImageRejectedSignal then preparation;
        state archiving {
            do action archiveStudy : ArchiveStudy;
        }
        accept ArchiveCompleteSignal then standby;
        state emergency;
        accept EmergencyResetSignal then standby;
    }

    requirement def ALARARequirement {
        doc "The dose management system shall calculate estimated dose before exposure and monitor cumulative dose to ensure adherence to ALARA principles.";
    }
    requirement def CoolingRequirement {
        doc "The cooling system shall maintain X-ray tube temperature below 1800 degrees C during continuous operation at maximum power.";
    }
    requirement def ImageQualityRequirement {
        doc "The image processing unit shall produce DICOM-compliant diagnostic images with spatial resolution of at least 3 lp/mm.";
    }
    requirement def EmergencyStopRequirement {
        doc "The system shall terminate X-ray production within 10 ms of an emergency stop command.";
    }
    requirement def StateSequenceRequirement {
        doc "The system shall follow the operational state sequence from standby through archive.";
    }

    part def DigitalRadiographySystem {
        part xrayTube : XRayTube;
        part generator : HighVoltageGenerator;
        part coolingSystem : CoolingSystem;
        part collimator : BeamCollimator;
        part patientTable : PatientPositioningTable;
        part detector : DigitalDetector;
        part imageProcessor : ImageProcessingUnit;
        part doseManager : DoseManagementSystem;
        part operatorWorkstation : OperatorWorkstation;

        connect generator.powerOut to xrayTube.powerIn;
        connect coolingSystem.coolantOut to xrayTube.coolantIn;
        connect xrayTube.beamOut to collimator.beamIn;
        connect collimator.beamOut to detector.beamIn;
        connect detector.dataOut to imageProcessor.dataIn;
        connect imageProcessor.imageOut to operatorWorkstation.imageIn;
        connect doseManager.reportOut to operatorWorkstation.reportIn;
        connect operatorWorkstation.controlOut to generator.controlIn;
        connect operatorWorkstation.controlOut to coolingSystem.controlIn;
        connect operatorWorkstation.controlOut to collimator.controlIn;
        connect operatorWorkstation.controlOut to patientTable.controlIn;
        connect operatorWorkstation.controlOut to detector.controlIn;
        connect operatorWorkstation.controlOut to imageProcessor.controlIn;
        connect operatorWorkstation.controlOut to doseManager.controlIn;

        exhibit state systemStates : SystemStates;
    }

    part radiographySystem : DigitalRadiographySystem;

    satisfy ALARARequirement by radiographySystem.doseManager;
    satisfy CoolingRequirement by radiographySystem.coolingSystem;
    satisfy ImageQualityRequirement by radiographySystem.imageProcessor;
    satisfy EmergencyStopRequirement by radiographySystem.xrayTube;
    satisfy StateSequenceRequirement by radiographySystem.systemStates;
}
