package 'ObstetricsGynecologyInstrumentSystem' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
    attribute def PressureValue :> ISQ::PressureValue;
    attribute def FrequencyValue :> ISQ::FrequencyValue;
    attribute def FlowRateValue :> ISQ::VolumeFlowRateValue;

    item def FetalHeartRateData {
        attribute heartRate : FrequencyValue;
        attribute timestamp : ISQ::TimeValue;
        attribute signalQuality : Real;
    }

    item def UterineContractionData {
        attribute intensity : PressureValue;
        attribute frequency : FrequencyValue;
        attribute duration : ISQ::TimeValue;
    }

    item def UltrasoundImage {
        attribute resolution : ISQ::LengthValue;
        attribute depth : ISQ::LengthValue;
        attribute frameRate : FrequencyValue;
        attribute timestamp : ISQ::TimeValue;
    }

    item def BiometricMeasurements {
        attribute fetalCrownRumpLength : ISQ::LengthValue;
        attribute biparietal_diameter : ISQ::LengthValue;
        attribute femurLength : ISQ::LengthValue;
        attribute amnioticFluidIndex : Real;
    }

    item def VitalSignsData {
        attribute maternalHeartRate : FrequencyValue;
        attribute bloodPressure : PressureValue;
        attribute oxygenSaturation : Real;
        attribute temperature : TemperatureValue;
    }

    item def DiagnosticReport {
        attribute findings : String;
        attribute measurements : BiometricMeasurements;
        attribute recommendations : String;
        attribute riskAssessment : String;
    }

    port def SensorDataPort {
        out item sensorReading : FetalHeartRateData;
    }

    port def DisplayPort {
        in item displayData : DiagnosticReport;
    }

    port def PowerSupplyPort {
        in attribute voltage : ISQ::ElectricPotentialValue;
        in attribute current : ISQ::ElectricCurrentValue;
    }

    port def TransducerPort {
        out item imageData : UltrasoundImage;
        in attribute controlSignal : ISQ::ElectricPotentialValue;
    }

    port def MonitoringPort {
        out item contractionData : UterineContractionData;
        out item fetalData : FetalHeartRateData;
    }

    part def CardiotocographMonitor {
        attribute operatingMode : String;
        
        port fetalSensor : SensorDataPort;
        port contractionSensor : MonitoringPort;
        port displayOutput : DisplayPort;
        port powerInput : PowerSupplyPort;

        part fetalHeartRateTransducer {
            attribute sensitivity : Real;
            perform action detectHeartbeat;
        }

        part tocodynamometer {
            attribute calibrationFactor : Real;
            perform action measureContractions;
        }

        part signalProcessor {
            perform action processSignals;
        }

        part dataRecorder {
            perform action recordData;
        }
    }

    part def UltrasoundSystem {
        attribute imagingMode : String;
        attribute operatingFrequency : FrequencyValue;

        port transducerInterface : TransducerPort;
        port displayInterface : DisplayPort;
        port powerInterface : PowerSupplyPort;

        part ultrasonicTransducer {
            attribute elementCount : Integer;
            attribute beamWidth : Real;
            perform action emitUltrasound;
            perform action receiveEchoes;
        }

        part beamFormer {
            perform action focusBeam;
        }

        part imageProcessor {
            perform action reconstructImage;
        }

        part measurementModule {
            perform action calculateBiometrics;
        }
    }

    part def InfusionPump {
        attribute maxFlowRate : FlowRateValue;
        attribute currentFlowRate : FlowRateValue;

        port controlInput : PowerSupplyPort;
        port statusOutput : DisplayPort;

        part pumpMechanism {
            perform action deliverFluid;
        }

        part flowRateController {
            perform action regulateFlow;
        }

        part safetyMonitor {
            perform action checkOcclusion;
            perform action detectAirBubbles;
        }
    }

    part def VacuumAspirator {
        attribute vacuumPressure : PressureValue;
        attribute collectionCapacity : ISQ::VolumeValue;

        port powerInterface : PowerSupplyPort;
        port controlInterface : DisplayPort;

        part vacuumPump {
            perform action generateVacuum;
        }

        part pressureRegulator {
            perform action maintainPressure;
        }

        part collectionCanister {
            perform action collectFluid;
        }
    }

    part def Colposcope {
        attribute magnificationRange : Real;
        attribute illuminationType : String;

        port powerInterface : PowerSupplyPort;
        port imageOutput : DisplayPort;

        part opticalSystem {
            attribute magnification : Real;
            perform action magnifyTissue;
        }

        part illuminationSystem {
            attribute lightIntensity : ISQ::LuminousIntensityValue;
            perform action illuminateTarget;
        }

        part imagingCamera {
            perform action captureImage;
        }
    }

    action def AcquireFetalData {
        out fhrData : FetalHeartRateData;
    }

    action def AcquireContractionData {
        out contractionData : UterineContractionData;
    }

    action def AnalyzeFetalPatterns {
        in heartRateData : FetalHeartRateData;
        in contractionInfo : UterineContractionData;
        out analysis : DiagnosticReport;
    }

    action def MonitorFetalWellbeing {
        in patientIdentifier : String;
        out monitoringReport : DiagnosticReport;

        first start;
        then action attachSensors {
            out sensorsAttached : Boolean;
        }
        then merge continuousMonitoring;
        then action acquireFetalHeartRate : AcquireFetalData {
            out fhrData : FetalHeartRateData;
        }
        then action acquireContractionData : AcquireContractionData {
            out contractionData : UterineContractionData;
        }
        then action analyzePatterns : AnalyzeFetalPatterns {
            in heartRateData = acquireFetalHeartRate.fhrData;
            in contractionInfo = acquireContractionData.contractionData;
            out analysis : DiagnosticReport;
        }
        then decide;
            if analyzePatterns.analysis.riskAssessment == "normal" then continueMonitoring;
            else if analyzePatterns.analysis.riskAssessment == "concerning" then alertClinician;
            else emergencyAlert;

        action continueMonitoring {
            then continuousMonitoring;
        }

        action alertClinician {
            out notification : String;
            then continuousMonitoring;
        }

        action emergencyAlert {
            out urgentNotification : String;
        }
        then done;
    }

    action def CaptureUltrasoundImage {
        out image : UltrasoundImage;
    }

    action def MeasureFetalStructures {
        in imageData : UltrasoundImage;
        out measurements : BiometricMeasurements;
    }

    action def AssessFetalAnatomy {
        in biometrics : BiometricMeasurements;
        out anatomyNormal : Boolean;
    }

    action def CompileDiagnosticReport {
        in allMeasurements : BiometricMeasurements;
        in findings : Boolean;
        out finalReport : DiagnosticReport;
    }

    action def PerformObstetricUltrasound {
        in examinationType : String;
        in gestationalAge : ISQ::TimeValue;
        out images : UltrasoundImage[*];
        out diagnosticReport : DiagnosticReport;

        first start;
        then action preparePatient {
            out patientReady : Boolean;
        }
        then action applyCouplingGel;
        then action positionTransducer {
            out transducerPositioned : Boolean;
        }
        then merge scanningSequence;
        then action acquireImage : CaptureUltrasoundImage {
            out image : UltrasoundImage;
        }
        then action performMeasurements : MeasureFetalStructures {
            in imageData = acquireImage.image;
            out measurements : BiometricMeasurements;
        }
        then action assessAnatomy : AssessFetalAnatomy {
            in biometrics = performMeasurements.measurements;
            out anatomyNormal : Boolean;
        }
        then decide;
            if assessAnatomy.anatomyNormal and examinationType == "detailed" then additionalViews;
            else if assessAnatomy.anatomyNormal and examinationType == "standard" then generateReport;
            else targetedExamination;

        action additionalViews {
            then scanningSequence;
        }

        action targetedExamination {
            out detailedFindings : String;
            then generateReport;
        }

        action generateReport : CompileDiagnosticReport {
            in allMeasurements = performMeasurements.measurements;
            in findings = assessAnatomy.anatomyNormal;
            out finalReport : DiagnosticReport;
        }
        then done;
    }

    action def VisualizeCervicalTissue {
        out cervicalImage : UltrasoundImage;
    }

    action def ObserveTissueChanges {
        out abnormalitiesDetected : Boolean;
    }

    action def DocumentFindings {
        out findings : DiagnosticReport;
    }

    action def PerformColposcopy {
        in indication : String;
        out examinationFindings : DiagnosticReport;

        first start;
        then action positionPatient;
        then action insertSpeculum;
        then action positionColposcope {
            out colposcopeReady : Boolean;
        }
        then action adjustMagnification {
            in targetMagnification : Real;
        }
        then action visualizeCervix : VisualizeCervicalTissue {
            out cervicalImage : UltrasoundImage;
        }
        then action applyAceticAcid;
        then action observeAcetowhitening : ObserveTissueChanges {
            out abnormalitiesDetected : Boolean;
        }
        then decide;
            if observeAcetowhitening.abnormalitiesDetected then performBiopsy;
            else concludeExamination;

        action performBiopsy {
            out biopsySample : String;
            out biopsyLocation : String;
        }
        then concludeExamination;

        action concludeExamination : DocumentFindings {
            out findings : DiagnosticReport;
        }
        then done;
    }

    action def ConfigureFlowRate {
        in targetRate : FlowRateValue;
        out rateSet : Boolean;
    }

    action def MonitorInfusionFlow {
        out currentRate : FlowRateValue;
        out alarmStatus : String;
    }

    action def ManageInfusionTherapy {
        in medicationOrder : String;
        in prescribedRate : FlowRateValue;
        out infusionStatus : String;

        first start;
        then action verifyMedication {
            out medicationVerified : Boolean;
        }
        then action primeTubing;
        then action setFlowRate : ConfigureFlowRate {
            in targetRate = prescribedRate;
            out rateSet : Boolean;
        }
        then action startInfusion;
        then merge monitoringLoop;
        then action monitorFlow : MonitorInfusionFlow {
            out currentRate : FlowRateValue;
            out alarmStatus : String;
        }
        then decide;
            if monitorFlow.alarmStatus == "none" then continueInfusion;
            else if monitorFlow.alarmStatus == "occlusion" then handleOcclusion;
            else if monitorFlow.alarmStatus == "air" then handleAirDetection;
            else stopInfusion;

        action continueInfusion {
            then monitoringLoop;
        }

        action handleOcclusion {
            out occlusionCleared : Boolean;
            then monitoringLoop;
        }

        action handleAirDetection {
            out airRemoved : Boolean;
            then monitoringLoop;
        }

        action stopInfusion;
        then done;
    }

    part obgynInstrumentationSystem {
        part fetalMonitor : CardiotocographMonitor {
            attribute operatingMode = "continuous";
            perform action fetalMonitoring : MonitorFetalWellbeing;
        }

        part diagnosticUltrasound : UltrasoundSystem {
            attribute imagingMode = "B-mode";
            attribute operatingFrequency = 3.5 [MHz];
            perform action ultrasoundExam : PerformObstetricUltrasound;
        }

        part medicationInfusion : InfusionPump {
            attribute maxFlowRate = 999.0 [mL/h];
            attribute currentFlowRate = 0.0 [mL/h];
            perform action infusionControl : ManageInfusionTherapy;
        }

        part suctionDevice : VacuumAspirator {
            attribute vacuumPressure = 0.8 [bar];
            attribute collectionCapacity = 2.0 [L];
        }

        part colposcopeUnit : Colposcope {
            attribute magnificationRange = 15.0;
            attribute illuminationType = "LED";
            perform action cervicalExam : PerformColposcopy;
        }

        part centralMonitoringStation {
            perform action aggregateData;
            perform action displayVitalSigns;
        }

        connection fetalMonitorToStation connect 
            fetalMonitor.displayOutput to centralMonitoringStation;

        connection ultrasoundToStation connect 
            diagnosticUltrasound.displayInterface to centralMonitoringStation;

        connection infusionToStation connect 
            medicationInfusion.statusOutput to centralMonitoringStation;

        connection colposcopeToStation connect 
            colposcopeUnit.imageOutput to centralMonitoringStation;
    }

    requirement def FetalMonitoringAccuracyRequirement {
        subject monitor : CardiotocographMonitor;
        doc /* The fetal heart rate monitor shall detect and display fetal heart rate 
             with an accuracy of ±2 bpm in the range of 50-240 bpm. */
        require constraint {
            monitor.fetalHeartRateTransducer.sensitivity >= 0.95
        }
    }

    requirement def UltrasoundImagingRequirement {
        subject ultrasound : UltrasoundSystem;
        doc /* The ultrasound system shall provide image resolution sufficient 
             for accurate biometric measurements with error less than 5%. */
        require constraint {
            ultrasound.transducerInterface.imageData.resolution <= 1.0 [mm]
        }
    }

    requirement def InfusionSafetyRequirement {
        subject pump : InfusionPump;
        doc /* The infusion pump shall detect occlusions and air bubbles 
             and trigger alarms within 15 seconds of occurrence. */
        require constraint {
            pump.safetyMonitor != null
        }
    }

    requirement systemRequirements {
        doc /* The obstetrics and gynecology instrumentation system shall provide 
             comprehensive monitoring, diagnostic, and therapeutic capabilities 
             for maternal-fetal care throughout pregnancy, labor, and delivery. */

        requirement fetalMonitoringReq : FetalMonitoringAccuracyRequirement {
            subject ctgMonitor = obgynInstrumentationSystem.fetalMonitor;
        }

        requirement imagingCapabilityReq : UltrasoundImagingRequirement {
            subject ultrasoundSystem = obgynInstrumentationSystem.diagnosticUltrasound;
        }

        requirement infusionSafetyReq : InfusionSafetyRequirement {
            subject infusionPump = obgynInstrumentationSystem.medicationInfusion;
        }

        requirement colposcopyCapabilityReq {
            doc /* The colposcope shall provide magnification between 5x and 20x 
                 with adequate illumination for cervical tissue examination. */
            subject colposcope = obgynInstrumentationSystem.colposcopeUnit;
            require constraint {
                colposcope.magnificationRange >= 5.0 and 
                colposcope.magnificationRange <= 20.0
            }
        }

        requirement dataIntegrationReq {
            doc /* All instruments shall interface with the central monitoring station 
                 for integrated patient data display and documentation. */
            subject system = obgynInstrumentationSystem;
        }
    }
}
