package RelativeAtrialIndexSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    private import NumericalFunctions::*;
    
    attribute def HeartRateValue :> Real;
    attribute def AtrialRateValue :> Real;
    attribute def VentricularRateValue :> Real;
    attribute def IndexRatioValue :> Real;
    attribute def ThresholdValue :> Real;
    attribute def SignalAmplitudeValue :> Real;
    
    enum def RhythmStatus {
        normal;
        elevated;
        critical;
    }
    
    item def ECGSignalData {
        attribute timestamp : TimeValue;
        attribute amplitude : SignalAmplitudeValue;
        attribute frequency : FrequencyValue;
    }
    
    item def AtrialMeasurement {
        attribute rate : AtrialRateValue;
        attribute timestamp : TimeValue;
        attribute signalQuality : Real;
    }
    
    item def VentricularMeasurement {
        attribute rate : VentricularRateValue;
        attribute timestamp : TimeValue;
        attribute signalQuality : Real;
    }
    
    item def RAIReport {
        attribute indexValue : IndexRatioValue;
        attribute status : RhythmStatus;
        attribute atrialRate : AtrialRateValue;
        attribute ventricularRate : VentricularRateValue;
        attribute timestamp : TimeValue;
    }
    
    port def ECGSensorPort {
        out item ecgSignal : ECGSignalData;
    }
    
    port def AtrialDataPort {
        out item atrialData : AtrialMeasurement;
    }
    
    port def VentricularDataPort {
        out item ventricularData : VentricularMeasurement;
    }
    
    port def RAIOutputPort {
        out item raiReport : RAIReport;
    }
    
    port def AlertPort {
        out item alertSignal : Boolean;
    }
    
    action def AcquireECGSignal {
        out ecgData : ECGSignalData;
    }
    
    action def DetectAtrialActivity {
        in ecgData : ECGSignalData;
        out atrialMeasurement : AtrialMeasurement;
    }
    
    action def DetectVentricularActivity {
        in ecgData : ECGSignalData;
        out ventricularMeasurement : VentricularMeasurement;
    }
    
    action def ComputeRAI {
        in atrialRate : AtrialRateValue;
        in ventricularRate : VentricularRateValue;
        out indexValue : IndexRatioValue;
        
        assert constraint validInputRates {
            atrialRate > 0.0 and ventricularRate > 0.0
        }
        
        assert constraint raiCalculation {
            indexValue == atrialRate / ventricularRate
        }
    }
    
    action def ClassifyRhythm {
        in indexValue : IndexRatioValue;
        in normalThreshold : ThresholdValue;
        in criticalThreshold : ThresholdValue;
        out status : RhythmStatus;
        
        first start;
        then decide;
            if indexValue < normalThreshold then setNormal;
            if indexValue >= normalThreshold and indexValue < criticalThreshold then setElevated;
            if indexValue >= criticalThreshold then setCritical;
        
        action setNormal {
            bind status = RhythmStatus::normal;
        }
        then done;
        
        action setElevated {
            bind status = RhythmStatus::elevated;
        }
        then done;
        
        action setCritical {
            bind status = RhythmStatus::critical;
        }
        then done;
    }
    
    action def GenerateReport {
        in indexValue : IndexRatioValue;
        in status : RhythmStatus;
        in atrialRate : AtrialRateValue;
        in ventricularRate : VentricularRateValue;
        in timestamp : TimeValue;
        out report : RAIReport;
    }
    
    part def ECGSensor {
        attribute samplingRate : FrequencyValue = 500 [Hz];
        port sensorOutput : ECGSensorPort;
        
        perform action acquireSignal : AcquireECGSignal;
    }
    
    part def AtrialAnalyzer {
        port ecgInput : ECGSensorPort;
        port atrialOutput : AtrialDataPort;
        
        perform action analyzeAtrial : DetectAtrialActivity;
    }
    
    part def VentricularAnalyzer {
        port ecgInput : ECGSensorPort;
        port ventricularOutput : VentricularDataPort;
        
        perform action analyzeVentricular : DetectVentricularActivity;
    }
    
    part def RAIProcessor {
        attribute normalThreshold : ThresholdValue = 1.2;
        attribute criticalThreshold : ThresholdValue = 1.5;
        attribute currentRAI : IndexRatioValue;
        
        port atrialInput : AtrialDataPort;
        port ventricularInput : VentricularDataPort;
        port raiOutput : RAIOutputPort;
        
        perform action processRAI {
            first start;
            then action computeIndex : ComputeRAI {
                in atrialRate : AtrialRateValue;
                in ventricularRate : VentricularRateValue;
                out indexValue : IndexRatioValue;
            }
            then action classify : ClassifyRhythm {
                in indexValue = computeIndex.indexValue;
                in normalThreshold = normalThreshold;
                in criticalThreshold = criticalThreshold;
                out status : RhythmStatus;
            }
            then action generateOutput : GenerateReport {
                in indexValue = computeIndex.indexValue;
                in status = classify.status;
                in atrialRate : AtrialRateValue;
                in ventricularRate : VentricularRateValue;
                out report : RAIReport;
            }
            then done;
        }
    }
    
    part def AlertController {
        port raiInput : RAIOutputPort;
        port alertOutput : AlertPort;
        
        perform action evaluateAlert {
            in report : RAIReport;
            out alertSignal : Boolean;
            
            first start;
            then decide;
                if report.status == RhythmStatus::critical then triggerAlert;
                if report.status != RhythmStatus::critical then noAlert;
            
            action triggerAlert {
                bind alertSignal = true;
            }
            then done;
            
            action noAlert {
                bind alertSignal = false;
            }
            then done;
        }
    }
    
    state def MonitoringState {
        entry action initializeSystem;
        do action continuousMonitoring;
        
        state idle;
        state acquiring;
        state analyzing;
        state computing;
        state reporting;
        state alerting;
        
        transition idle_to_acquiring
            first idle
            then acquiring;
        
        transition acquiring_to_analyzing
            first acquiring
            then analyzing;
        
        transition analyzing_to_computing
            first analyzing
            then computing;
        
        transition computing_to_reporting
            first computing
            then reporting;
        
        transition reporting_to_alerting
            first reporting
            then alerting;
        
        transition alerting_to_idle
            first alerting
            then idle;
    }
    
    part def RelativeAtrialIndexMonitor {
        doc /* A cardiac monitoring system that continuously measures and analyzes
             * the relationship between atrial and ventricular electrical activity
             * to assess cardiac rhythm status and detect potential arrhythmias. */
        
        attribute systemRAI : IndexRatioValue;
        attribute currentStatus : RhythmStatus;
        
        part ecgSensor : ECGSensor;
        part atrialAnalyzer : AtrialAnalyzer;
        part ventricularAnalyzer : VentricularAnalyzer;
        part raiProcessor : RAIProcessor;
        part alertController : AlertController;
        
        connection ecgToAtrial connect ecgSensor.sensorOutput to atrialAnalyzer.ecgInput;
        connection ecgToVentricular connect ecgSensor.sensorOutput to ventricularAnalyzer.ecgInput;
        connection atrialToProcessor connect atrialAnalyzer.atrialOutput to raiProcessor.atrialInput;
        connection ventricularToProcessor connect ventricularAnalyzer.ventricularOutput to raiProcessor.ventricularInput;
        connection processorToAlert connect raiProcessor.raiOutput to alertController.raiInput;
        
        perform action monitorCardiacActivity {
            first start;
            then merge continuousLoop;
            
            then action acquireData : AcquireECGSignal {
                out ecgData : ECGSignalData;
            }
            
            then action analyzeSignals {
                action detectAtrial : DetectAtrialActivity {
                    in ecgData = acquireData.ecgData;
                    out atrialMeasurement : AtrialMeasurement;
                }
                action detectVentricular : DetectVentricularActivity {
                    in ecgData = acquireData.ecgData;
                    out ventricularMeasurement : VentricularMeasurement;
                }
            }
            
            then action processData : ComputeRAI {
                in atrialRate = analyzeSignals.detectAtrial.atrialMeasurement.rate;
                in ventricularRate = analyzeSignals.detectVentricular.ventricularMeasurement.rate;
                out indexValue : IndexRatioValue;
            }
            
            then action classifyData : ClassifyRhythm {
                in indexValue = processData.indexValue;
                in normalThreshold = raiProcessor.normalThreshold;
                in criticalThreshold = raiProcessor.criticalThreshold;
                out status : RhythmStatus;
            }
            
            then action evaluateCondition {
                in report : RAIReport;
                out alertSignal : Boolean;
            }
            
            then continuousLoop;
        }
        
        exhibit state operationalState : MonitoringState;
    }
    
    requirement <'REQ-RAI-1000'> primaryMonitoringFunction {
        doc /* The Relative Atrial Index System shall continuously monitor cardiac
             * electrical activity by measuring the ratio of atrial to ventricular
             * rates to assess rhythm status and provide early detection of atrial
             * arrhythmias for clinical decision support. */
        subject monitor : RelativeAtrialIndexMonitor;
    }
    
    requirement <'REQ-RAI-1001'> raiComputationAccuracy {
        doc /* The system shall accurately compute the Relative Atrial Index as
             * the ratio of atrial rate to ventricular rate with sufficient
             * precision for clinical interpretation. */
        subject processor :> RelativeAtrialIndexMonitor::raiProcessor;
        
        assert constraint positiveRAI {
            processor.currentRAI >= 0.0
        }
    }
    
    requirement <'REQ-RAI-1002'> rhythmClassificationCriteria {
        doc /* The system shall classify cardiac rhythm status as normal when
             * RAI < 1.2, elevated when 1.2 <= RAI < 1.5, and critical when
             * RAI >= 1.5 based on established clinical thresholds. */
        subject processor :> RelativeAtrialIndexMonitor::raiProcessor;
        
        assert constraint normalThresholdSpec {
            processor.normalThreshold == 1.2
        }
        
        assert constraint criticalThresholdSpec {
            processor.criticalThreshold == 1.5
        }
    }
    
    requirement <'REQ-RAI-1003'> continuousOperation {
        doc /* The system shall operate continuously in real-time, processing
             * incoming ECG signals and generating diagnostic reports without
             * interruption during normal operation. */
        subject monitor :> RelativeAtrialIndexMonitor;
    }
    
    requirement <'REQ-RAI-1004'> alertGeneration {
        doc /* The system shall generate an alert when the computed RAI indicates
             * a critical rhythm status to notify clinical staff of potential
             * arrhythmic conditions requiring intervention. */
        subject alertController :> RelativeAtrialIndexMonitor::alertController;
    }
    
    part raiMonitoringSystem : RelativeAtrialIndexMonitor {
        attribute :>> systemRAI : IndexRatioValue;
        attribute :>> currentStatus : RhythmStatus;
    }
    
    satisfy primaryMonitoringFunction by raiMonitoringSystem;
    satisfy raiComputationAccuracy by raiMonitoringSystem.raiProcessor;
    satisfy rhythmClassificationCriteria by raiMonitoringSystem.raiProcessor;
    satisfy continuousOperation by raiMonitoringSystem;
    satisfy alertGeneration by raiMonitoringSystem.alertController;
}
