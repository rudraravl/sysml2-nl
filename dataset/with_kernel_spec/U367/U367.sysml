package MedicalMonitoringSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::TimeInstantValue;

    item def ECGSignal {
        attribute samplingRate : FrequencyValue;
        attribute amplitude : ElectricPotentialValue;
    }

    value type def HeartRate :> Real;

    value type def RelativeAtrialIndex :> Real;

    item def AtrialRateReport {
        attribute atrialRate : HeartRate;
    }

    item def VentricularRateReport {
        attribute ventricularRate : HeartRate;
    }

    item def RAIReport {
        attribute rai : RelativeAtrialIndex;
        attribute status : RhythmStatus;
    }

    enum def RhythmStatus {
        normal,
        elevated,
        critical;
    }

    attribute def AlertSignal {
        attribute severity : RhythmStatus;
        attribute timestamp : TimeInstantValue;
    }

    action def AcquireECG {
        out ecg : ECGSignal;
    }

    action def AnalyzeAtrialRate {
        in ecg : ECGSignal;
        out atrialReport : AtrialRateReport;
    }

    action def AnalyzeVentricularRate {
        in ecg : ECGSignal;
        out ventricularReport : VentricularRateReport;
    }

    action def ComputeRAI {
        in atrialReport : AtrialRateReport;
        in ventricularReport : VentricularRateReport;
        out raiReport : RAIReport;
    }

    action def EvaluateAlert {
        in raiReport : RAIReport;
        out alert : AlertSignal[0..1];
    }

    part def ECGSensor {
        attribute samplingRate : FrequencyValue = 250.0 / s;
        port ecgOutPort {
            out ecg : ECGSignal;
        }
        perform action acquireECG : AcquireECG {
            out ecg = ecgOutPort.ecg;
        }
    }

    part def AtrialAnalyzer {
        attribute normalAtrialRate : HeartRate = 60.0;
        attribute maxAtrialRate : HeartRate = 100.0;
        port ecgInPort {
            in ecg : ECGSignal;
        }
        port atrialOutPort {
            out atrialReport : AtrialRateReport;
        }
        perform action analyzeAtrialRate : AnalyzeAtrialRate {
            in ecg = ecgInPort.ecg;
            out atrialReport = atrialOutPort.atrialReport;
        }
    }

    part def VentricularAnalyzer {
        attribute normalVentricularRate : HeartRate = 60.0;
        attribute maxVentricularRate : HeartRate = 100.0;
        port ecgInPort {
            in ecg : ECGSignal;
        }
        port ventricularOutPort {
            out ventricularReport : VentricularRateReport;
        }
        perform action analyzeVentricularRate : AnalyzeVentricularRate {
            in ecg = ecgInPort.ecg;
            out ventricularReport = ventricularOutPort.ventricularReport;
        }
    }

    part def RAIProcessor {
        attribute elevatedThreshold : RelativeAtrialIndex = 1.2;
        attribute criticalThreshold : RelativeAtrialIndex = 1.5;
        port atrialInPort {
            in atrialReport : AtrialRateReport;
        }
        port ventricularInPort {
            in ventricularReport : VentricularRateReport;
        }
        port raiOutPort {
            out raiReport : RAIReport;
        }
        perform action computeRAI : ComputeRAI {
            in atrialReport = atrialInPort.atrialReport;
            in ventricularReport = ventricularInPort.ventricularReport;
            out raiReport = raiOutPort.raiReport;
        }
    }

    part def AlertController {
        port raiInPort {
            in raiReport : RAIReport;
        }
        port alertOutPort {
            out alert : AlertSignal;
        }
        perform action evaluateAlert : EvaluateAlert {
            in raiReport = raiInPort.raiReport;
            out alert = alertOutPort.alert;
        }
    }

    state def MonitoringStates {
        entry; then idle;
        state idle;
        transition first idle then acquiring;
        state acquiring {
            do action acquireECGAction : AcquireECG;
        }
        transition first acquiring then analyzing;
        state analyzing {
            do action analyzeAtrialAction : AnalyzeAtrialRate;
            do action analyzeVentricularAction : AnalyzeVentricularRate;
        }
        transition first analyzing then computing;
        state computing {
            do action computeRAIAction : ComputeRAI;
        }
        transition first computing then evaluating;
        state evaluating {
            do action evaluateAlertAction : EvaluateAlert;
        }
        transition first evaluating then idle;
    }

    part def MedicalMonitor {
        attribute elevatedThreshold : RelativeAtrialIndex = 1.2;
        attribute criticalThreshold : RelativeAtrialIndex = 1.5;

        port patientPort {
            in patientECG : ECGSignal;
        }
        port clinicianAlertPort {
            out alert : AlertSignal;
        }

        part ecgSensor : ECGSensor {
            port ecgOutPort {
                out ecg : ECGSignal;
            }
        }

        part atrialAnalyzer : AtrialAnalyzer {
            port ecgInPort {
                in ecg : ECGSignal;
            }
            port atrialOutPort {
                out atrialReport : AtrialRateReport;
            }
        }

        part ventricularAnalyzer : VentricularAnalyzer {
            port ecgInPort {
                in ecg : ECGSignal;
            }
            port ventricularOutPort {
                out ventricularReport : VentricularRateReport;
            }
        }

        part raiProcessor : RAIProcessor {
            port atrialInPort {
                in atrialReport : AtrialRateReport;
            }
            port ventricularInPort {
                in ventricularReport : VentricularRateReport;
            }
            port raiOutPort {
                out raiReport : RAIReport;
            }
        }

        part alertController : AlertController {
            port raiInPort {
                in raiReport : RAIReport;
            }
            port alertOutPort {
                out alert : AlertSignal;
            }
        }

        flow ecgFlow1 of ECGSignal
            from ecgSensor.ecgOutPort.ecg to atrialAnalyzer.ecgInPort.ecg;

        flow ecgFlow2 of ECGSignal
            from ecgSensor.ecgOutPort.ecg to ventricularAnalyzer.ecgInPort.ecg;

        flow atrialRateFlow of AtrialRateReport
            from atrialAnalyzer.atrialOutPort.atrialReport to raiProcessor.atrialInPort.atrialReport;

        flow ventricularRateFlow of VentricularRateReport
            from ventricularAnalyzer.ventricularOutPort.ventricularReport to raiProcessor.ventricularInPort.ventricularReport;

        flow raiReportFlow of RAIReport
            from raiProcessor.raiOutPort.raiReport to alertController.raiInPort.raiReport;

        flow alertFlow of AlertSignal
            from alertController.alertOutPort.alert to clinicianAlertPort.alert;

        bind patientPort.patientECG = ecgSensor.ecgOutPort.ecg;

        assert constraint raiDefinition {
            raiProcessor.computeRAI.raiReport.rai ==
            raiProcessor.computeRAI.atrialReport.atrialRate /
            raiProcessor.computeRAI.ventricularReport.ventricularRate
        }

        assert constraint normalClassification {
            raiProcessor.computeRAI.raiReport.status == RhythmStatus::normal
            implies raiProcessor.computeRAI.raiReport.rai <= raiProcessor.elevatedThreshold
        }

        assert constraint elevatedClassification {
            raiProcessor.computeRAI.raiReport.status == RhythmStatus::elevated
            implies raiProcessor.computeRAI.raiReport.rai > raiProcessor.elevatedThreshold
                and raiProcessor.computeRAI.raiReport.rai <= raiProcessor.criticalThreshold
        }

        assert constraint criticalClassification {
            raiProcessor.computeRAI.raiReport.status == RhythmStatus::critical
            implies raiProcessor.computeRAI.raiReport.rai > raiProcessor.criticalThreshold
        }

        assert constraint alertOnCritical {
            alertController.evaluateAlert.alert.severity == RhythmStatus::critical
            implies raiProcessor.computeRAI.raiReport.status == RhythmStatus::critical
        }

        exhibit state monitoring : MonitoringStates;
    }

    requirement def ContinuousMonitoringRequirement {
        doc /* The system shall continuously monitor the patient's cardiac rhythm. */
        subject monitor : MedicalMonitor;
    }

    requirement def ECGAcquisitionRequirement {
        doc /* The ECG sensor shall acquire raw electrical signals from the patient's heart. */
        subject sensor : ECGSensor;
    }

    requirement def AtrialAnalysisRequirement {
        doc /* The atrial analyzer shall detect and measure the atrial rate from the ECG signal. */
        subject analyzer : AtrialAnalyzer;
    }

    requirement def VentricularAnalysisRequirement {
        doc /* The ventricular analyzer shall detect and measure the ventricular rate from the ECG signal. */
        subject analyzer : VentricularAnalyzer;
    }

    requirement def RAIComputationRequirement {
        doc /* The RAI processor shall compute the Relative Atrial Index as atrial rate divided by ventricular rate. */
        subject processor : RAIProcessor;
    }

    requirement def RhythmClassificationRequirement {
        doc /* The processor shall classify rhythm status as normal, elevated, or critical based on RAI thresholds. */
        subject processor : RAIProcessor;
    }

    requirement def AlertGenerationRequirement {
        doc /* The alert controller shall generate an alert signal when rhythm status is classified as critical. */
        subject controller : AlertController;
    }

    requirement continuousMonitoring : ContinuousMonitoringRequirement {
        subject monitor : MedicalMonitor;
    }

    requirement ecgAcquisition : ECGAcquisitionRequirement {
        subject sensor : ECGSensor;
    }

    requirement atrialAnalysis : AtrialAnalysisRequirement {
        subject analyzer : AtrialAnalyzer;
    }

    requirement ventricularAnalysis : VentricularAnalysisRequirement {
        subject analyzer : VentricularAnalyzer;
    }

    requirement raiComputation : RAIComputationRequirement {
        subject processor : RAIProcessor;
    }

    requirement rhythmClassification : RhythmClassificationRequirement {
        subject processor : RAIProcessor;
    }

    requirement alertGeneration : AlertGenerationRequirement {
        subject controller : AlertController;
    }

    satisfy continuousMonitoring by MedicalMonitor;
    satisfy ecgAcquisition by ECGSensor;
    satisfy atrialAnalysis by AtrialAnalyzer;
    satisfy ventricularAnalysis by VentricularAnalyzer;
    satisfy raiComputation by RAIProcessor;
    satisfy rhythmClassification by RAIProcessor;
    satisfy alertGeneration by AlertController;
}
