package DermatologySystem {
    private import ScalarValues::*;

    attribute def Wavelength :> Real;
    attribute def TemperatureValue :> Real;
    attribute def LaserEnergy :> Real;
    attribute def DurationValue :> Real;
    attribute def PressureValue :> Real;
    attribute def CoolingFlow :> Real;
    attribute def LengthValue :> Real;

    enum def RiskLevel {
        benign;
        suspicious;
        malignant;
    }

    enum def TreatmentType {
        laser;
        cryotherapy;
    }

    enum def SystemMode {
        idle;
        imaging;
        analyzing;
        treating;
        emergency;
    }

    item def SkinImage {
        attribute width : Integer;
        attribute height : Integer;
        attribute modality : String;
        attribute captureWavelength : Wavelength;
        attribute polarized : Boolean;
    }

    item def DiagnosticReport {
        attribute asymmetry : Real;
        attribute borderIrregularity : Real;
        attribute colorVariation : Real;
        attribute diameter : LengthValue;
        attribute riskClassification : RiskLevel;
        attribute confidence : Real;
        attribute notes : String;
    }

    item def TreatmentProtocol {
        attribute treatmentType : TreatmentType;
        attribute laserWavelength : Wavelength;
        attribute laserEnergy : LaserEnergy;
        attribute freezeDuration : DurationValue;
        attribute targetTemperature : TemperatureValue;
    }

    item def SystemStatus {
        attribute mode : SystemMode;
        attribute safetyInterlockEngaged : Boolean;
        attribute errorCode : Integer;
        attribute statusMessage : String;
    }

    item def InterruptSignal {
        attribute source : String;
        attribute reason : String;
    }

    port def ImageOutPort { out image : SkinImage; }
    port def ImageInPort { in image : SkinImage; }
    port def ReportOutPort { out report : DiagnosticReport; }
    port def ReportInPort { in report : DiagnosticReport; }
    port def CommandOutPort { out protocol : TreatmentProtocol; }
    port def CommandInPort { in protocol : TreatmentProtocol; }
    port def StatusOutPort { out status : SystemStatus; }
    port def StatusInPort { in status : SystemStatus; }
    port def EmergencyOutPort { out interrupt : InterruptSignal; }
    port def EmergencyInPort { in interrupt : InterruptSignal; }

    part def OpticalSystem {
        attribute magnification : Real;
        attribute polarized : Boolean = true;
        attribute illuminationWavelengths : Wavelength[1..*];
    }

    part def ImageSensor {
        attribute exposureTimeMs : Real;
        attribute resolutionWidth : Integer;
        attribute resolutionHeight : Integer;
    }

    action def CaptureImage {
        out capturedImage : SkinImage;
    }

    part def DermatoscopeModule {
        part opticalSystem : OpticalSystem;
        part sensor : ImageSensor;
        port imageOut : ImageOutPort;
        action captureImage : CaptureImage;
    }

    part def ImagePreprocessor {
        attribute algorithm : String;
    }

    part def AIEngine {
        attribute modelVersion : String;
        attribute patternRecognitionEnabled : Boolean = true;
    }

    part def RiskClassifier {
        attribute classificationModel : String;
    }

    action def AnalyzeImage {
        in inputImage : SkinImage;
        out analysisReport : DiagnosticReport;
    }

    part def DiagnosticAnalysisUnit {
        part preprocessor : ImagePreprocessor;
        part aiEngine : AIEngine;
        part classifier : RiskClassifier;
        port imageIn : ImageInPort;
        port reportOut : ReportOutPort;
        action analyzeImage : AnalyzeImage;
    }

    part def BeamDeliverySystem {
        attribute focusDepth : LengthValue;
        attribute wavelength : Wavelength;
        attribute energy : LaserEnergy;
    }

    part def SkinCoolingSystem {
        attribute coolingLevel : Real;
        attribute coolantFlow : CoolingFlow;
    }

    part def SafetyInterlock {
        attribute engaged : Boolean = false;
    }

    action def PerformLaserTherapy {
        in protocol : TreatmentProtocol;
        out status : SystemStatus;
    }

    part def LaserTherapyUnit {
        part beamDelivery : BeamDeliverySystem;
        part cooling : SkinCoolingSystem;
        part interlock : SafetyInterlock;
        attribute emergencyInterlockActive : Boolean;
        port commandIn : CommandInPort;
        port statusOut : StatusOutPort;
        port emergencyOut : EmergencyOutPort;
        action performTherapy : PerformLaserTherapy;
    }

    part def RefrigerantSystem {
        attribute refrigerantType : String;
        attribute pressure : PressureValue;
    }

    part def ApplicatorProbe {
        attribute probeDiameter : LengthValue;
        attribute contactArea : Real;
    }

    part def TemperatureSensor {
        attribute reading : TemperatureValue;
    }

    action def PerformCryotherapy {
        in protocol : TreatmentProtocol;
        out status : SystemStatus;
    }

    part def CryotherapyUnit {
        part refrigerant : RefrigerantSystem;
        part probe : ApplicatorProbe;
        part sensor : TemperatureSensor;
        port commandIn : CommandInPort;
        port statusOut : StatusOutPort;
        action performTherapy : PerformCryotherapy;
    }

    part def UserInterfacePanel {
        attribute displayMode : String;
        attribute operatingMode : SystemMode;
    }

    action def ManageTreatment {
        in report : DiagnosticReport;
        out laserProtocol : TreatmentProtocol;
        out cryoProtocol : TreatmentProtocol;
        in laserStatus : SystemStatus;
        in cryoStatus : SystemStatus;
    }

    state machine def WorkflowStateMachine {
        state idle;
        state imaging;
        state analyzing;
        state selectingTreatment;
        state laserActive;
        state cryoActive;
        state monitoring;
        state emergencyStop;

        transition from idle to imaging;
        transition from imaging to analyzing;
        transition from analyzing to selectingTreatment;
        transition from selectingTreatment to laserActive;
        transition from selectingTreatment to cryoActive;
        transition from laserActive to monitoring;
        transition from cryoActive to monitoring;
        transition from monitoring to idle;
        transition from laserActive to emergencyStop;
        transition from emergencyStop to idle;
    }

    part def ControlAndMonitoringSystem {
        part ui : UserInterfacePanel;
        port reportIn : ReportInPort;
        port laserCommandOut : CommandOutPort;
        port cryoCommandOut : CommandOutPort;
        port laserStatusIn : StatusInPort;
        port cryoStatusIn : StatusInPort;
        port laserEmergencyIn : EmergencyInPort;
        attribute currentMode : SystemMode;
        action manageTreatment : ManageTreatment;
        state machine workflow : WorkflowStateMachine;
    }

    part def IntegratedDermatologySystem {
        part dermatoscope : DermatoscopeModule;
        part diagnosticUnit : DiagnosticAnalysisUnit;
        part controlSystem : ControlAndMonitoringSystem;
        part laserUnit : LaserTherapyUnit;
        part cryoUnit : CryotherapyUnit;

        connect dermatoscope.imageOut to diagnosticUnit.imageIn;
        connect diagnosticUnit.reportOut to controlSystem.reportIn;
        connect controlSystem.laserCommandOut to laserUnit.commandIn;
        connect laserUnit.statusOut to controlSystem.laserStatusIn;
        connect controlSystem.cryoCommandOut to cryoUnit.commandIn;
        connect cryoUnit.statusOut to controlSystem.cryoStatusIn;
        connect laserUnit.emergencyOut to controlSystem.laserEmergencyIn;
    }

    action def ClinicalWorkflow {
        in startSignal : Boolean;
        out finalReport : DiagnosticReport;
        out treatmentOutcome : SystemStatus;

        action capture : CaptureImage;
        action analyze : AnalyzeImage;
        action select : ManageTreatment;
        action laserAction : PerformLaserTherapy;
        action cryoAction : PerformCryotherapy;

        flow from capture.capturedImage to analyze.inputImage;
        flow from analyze.analysisReport to select.report;
        flow from select.laserProtocol to laserAction.protocol;
        flow from select.cryoProtocol to cryoAction.protocol;
        flow from laserAction.status to treatmentOutcome;
        flow from cryoAction.status to treatmentOutcome;

        first start;
        then capture;
        then analyze;
        then select;
        then decide;
            if select.laserProtocol.treatmentType == TreatmentType::laser then laserAction;
            else cryoAction;
    }

    requirement def Req_ImageCapture {
        doc /* The system shall capture high-resolution dermoscopic images using polarized light and multiple illumination wavelengths. */
        subject dermatoscope : DermatoscopeModule;
        constraint { dermatoscope.opticalSystem.polarized == true; }
        constraint { dermatoscope.sensor.resolutionWidth >= 1024; }
        constraint { dermatoscope.sensor.resolutionHeight >= 768; }
    }

    requirement def Req_AIDiagnosis {
        doc /* The system shall automatically analyze lesion characteristics and generate a diagnostic assessment with risk classification. */
        subject diagnosticUnit : DiagnosticAnalysisUnit;
        constraint { diagnosticUnit.aiEngine.patternRecognitionEnabled == true; }
    }

    requirement def Req_LaserTreatment {
        doc /* The laser therapy unit shall deliver precise, controlled doses of laser energy with safety features including skin cooling and emergency interlock. */
        subject laserUnit : LaserTherapyUnit;
        constraint { laserUnit.cooling.coolantFlow > 0.0; }
        constraint { laserUnit.interlock.engaged == false; }
    }

    requirement def Req_CryoTreatment {
        doc /* The cryotherapy unit shall apply extreme cold via a refrigerant system and applicator probe with temperature monitoring. */
        subject cryoUnit : CryotherapyUnit;
        constraint { cryoUnit.sensor.reading <= -40.0; }
        constraint { cryoUnit.refrigerant.pressure > 0.0; }
    }

    requirement def Req_CentralControl {
        doc /* A central control and monitoring system shall manage operating modes, review diagnostics, configure protocols, and monitor safety in real-time. */
        subject controlSystem : ControlAndMonitoringSystem;
    }

    requirement def Req_IntegratedWorkflow {
        doc /* The system shall support a complete examination-to-treatment workflow within a single integrated platform. */
        subject system : IntegratedDermatologySystem;
    }

    satisfy Req_ImageCapture by DermatoscopeModule;
    satisfy Req_AIDiagnosis by DiagnosticAnalysisUnit;
    satisfy Req_LaserTreatment by LaserTherapyUnit;
    satisfy Req_CryoTreatment by CryotherapyUnit;
    satisfy Req_CentralControl by ControlAndMonitoringSystem;
    satisfy Req_IntegratedWorkflow by IntegratedDermatologySystem;
}
