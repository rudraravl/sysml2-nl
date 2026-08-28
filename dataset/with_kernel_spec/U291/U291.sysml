package PatientMonitoringPlatform {
    private import ScalarValues::*;

    value def HeartRateValue :> Real { unit "bpm"; }
    value def PressureValue :> Real { unit "mmHg"; }
    value def SaturationValue :> Real { unit "%"; }
    value def TimestampValue :> Real { unit "s"; }
    value def PatientIDValue :> String;

    item def ECGReading {
        attribute patientId : PatientIDValue;
        attribute timestamp : TimestampValue;
        attribute heartRate : HeartRateValue;
    }
    item def BPReading {
        attribute patientId : PatientIDValue;
        attribute timestamp : TimestampValue;
        attribute systolic : PressureValue;
        attribute diastolic : PressureValue;
    }
    item def SpO2Reading {
        attribute patientId : PatientIDValue;
        attribute timestamp : TimestampValue;
        attribute oxygenSat : SaturationValue;
    }
    item def VitalSignSample {
        attribute patientId : PatientIDValue;
        attribute timestamp : TimestampValue;
        attribute heartRate : HeartRateValue;
        attribute systolic : PressureValue;
        attribute diastolic : PressureValue;
        attribute oxygenSat : SaturationValue;
    }
    item def AlarmSignal {
        attribute patientId : PatientIDValue;
        attribute timestamp : TimestampValue;
        attribute vitalName : String;
        attribute measuredValue : Real;
        attribute severity : String;
    }
    item def AggregatedRecord {
        attribute sample : VitalSignSample;
        attribute alarm : AlarmSignal[0..1];
    }
    item def FHIRMessage {
        attribute resourceType : String;
        attribute payload : String;
    }
    item def DICOMObject {
        attribute modality : String;
        attribute payload : String;
    }

    port def ECGOutPort { out reading : ECGReading; }
    port def BPOutPort { out reading : BPReading; }
    port def SpO2OutPort { out reading : SpO2Reading; }
    port def ECGInPort { in reading : ECGReading; }
    port def BPInPort { in reading : BPReading; }
    port def SpO2InPort { in reading : SpO2Reading; }
    port def AggregatedOutPort { out record : AggregatedRecord; }
    port def AggregatedInPort { in record : AggregatedRecord; }
    port def RecordOutPort { out record : AggregatedRecord; }
    port def RecordInPort { in record : AggregatedRecord; }
    port def FHIROutPort { out message : FHIRMessage; }
    port def DICOMOutPort { out object : DICOMObject; }

    action def AnalyzeVitalSigns {
        in sample : VitalSignSample;
        out alarm : AlarmSignal[0..1];

        bind alarm =
            if sample.heartRate < 60 or sample.heartRate > 100 ?
                new AlarmSignal(sample.patientId, sample.timestamp, "heartRate", sample.heartRate, "critical")
            else (
                if sample.systolic < 90 or sample.systolic > 180 ?
                    new AlarmSignal(sample.patientId, sample.timestamp, "systolicBP", sample.systolic, "critical")
                else (
                    if sample.diastolic < 60 or sample.diastolic > 120 ?
                        new AlarmSignal(sample.patientId, sample.timestamp, "diastolicBP", sample.diastolic, "critical")
                    else (
                        if sample.oxygenSat < 95 ?
                            new AlarmSignal(sample.patientId, sample.timestamp, "oxygenSat", sample.oxygenSat, "critical")
                        else null
                    )
                )
            );
    }

    part def ECGMonitor {
        port dataOut : ECGOutPort;
        state Streaming {
            entry send new ECGReading("patient-001", 0.0, 72.0) via dataOut;
        }
    }
    part def BloodPressureMonitor {
        port dataOut : BPOutPort;
        state Streaming {
            entry send new BPReading("patient-001", 0.0, 120.0, 80.0) via dataOut;
        }
    }
    part def PulseOximeter {
        port dataOut : SpO2OutPort;
        state Streaming {
            entry send new SpO2Reading("patient-001", 0.0, 98.0) via dataOut;
        }
    }

    part def DataAggregator {
        port ecgIn : ECGInPort;
        port bpIn : BPInPort;
        port spo2In : SpO2InPort;
        port dataOut : AggregatedOutPort;

        attribute current : VitalSignSample;

        state Aggregating {
            state Waiting;
            transition Waiting -> Waiting {
                accept ecg : ECGReading via ecgIn do action {
                    bind current.patientId = ecg.patientId;
                    bind current.timestamp = ecg.timestamp;
                    bind current.heartRate = ecg.heartRate;
                }
            }
            transition Waiting -> Waiting {
                accept bp : BPReading via bpIn do action {
                    bind current.patientId = bp.patientId;
                    bind current.timestamp = bp.timestamp;
                    bind current.systolic = bp.systolic;
                    bind current.diastolic = bp.diastolic;
                }
            }
            transition Waiting -> Waiting {
                accept spo2 : SpO2Reading via spo2In do action {
                    bind current.patientId = spo2.patientId;
                    bind current.timestamp = spo2.timestamp;
                    bind current.oxygenSat = spo2.oxygenSat;
                    send new AggregatedRecord(current, null) via dataOut;
                }
            }
        }
    }

    part def ClinicalDataProcessor {
        port dataIn : AggregatedInPort;
        port displayOut : RecordOutPort;
        port repoOut : RecordOutPort;
        port gatewayOut : RecordOutPort;

        attribute safeHeartRateMin : HeartRateValue = 60;
        attribute safeHeartRateMax : HeartRateValue = 100;
        attribute safeSystolicMin : PressureValue = 90;
        attribute safeSystolicMax : PressureValue = 180;
        attribute safeDiastolicMin : PressureValue = 60;
        attribute safeDiastolicMax : PressureValue = 120;
        attribute safeSpO2Min : SaturationValue = 95;

        attribute latestAlarm : AlarmSignal[0..1];

        state Processing {
            state Monitoring;
            transition Monitoring -> Monitoring {
                accept rec : AggregatedRecord via dataIn do action {
                    first start;
                    then action AnalyzeVitalSigns {
                        in sample = rec.sample;
                        out alarm = latestAlarm;
                    }
                    then send new AggregatedRecord(rec.sample, latestAlarm) via displayOut;
                    then send new AggregatedRecord(rec.sample, latestAlarm) via repoOut;
                    then send new AggregatedRecord(rec.sample, latestAlarm) via gatewayOut;
                }
            }
        }
    }

    part def ClinicalDisplay {
        port dataIn : RecordInPort;
        state Displaying {
            state Active;
            transition Active -> Active {
                accept rec : AggregatedRecord via dataIn;
            }
        }
    }

    part def DataRepository {
        port dataIn : RecordInPort;
        attribute minRetentionYears : Integer = 7;
        state Archiving {
            state Storing;
            transition Storing -> Storing {
                accept rec : AggregatedRecord via dataIn;
            }
        }
    }

    part def InteroperabilityGateway {
        port dataIn : RecordInPort;
        port fhirOut : FHIROutPort;
        port dicomOut : DICOMOutPort;
        state Translating {
            state Ready;
            transition Ready -> Ready {
                accept rec : AggregatedRecord via dataIn do action {
                    send new FHIRMessage("Observation", "Patient vitals record") via fhirOut;
                    send new DICOMObject("ECG", "Patient waveform data") via dicomOut;
                }
            }
        }
    }

    part def PatientMonitoringSystem {
        part ecgMonitor : ECGMonitor;
        part bpMonitor : BloodPressureMonitor;
        part pulseOximeter : PulseOximeter;
        part dataAggregator : DataAggregator;
        part clinicalDataProcessor : ClinicalDataProcessor;
        part clinicalDisplay : ClinicalDisplay;
        part dataRepository : DataRepository;
        part interoperabilityGateway : InteroperabilityGateway;

        interface ecgToAggregator connect ecgMonitor.dataOut to dataAggregator.ecgIn;
        interface bpToAggregator connect bpMonitor.dataOut to dataAggregator.bpIn;
        interface spo2ToAggregator connect pulseOximeter.dataOut to dataAggregator.spo2In;
        interface aggregatorToProcessor connect dataAggregator.dataOut to clinicalDataProcessor.dataIn;
        interface processorToDisplay connect clinicalDataProcessor.displayOut to clinicalDisplay.dataIn;
        interface processorToRepository connect clinicalDataProcessor.repoOut to dataRepository.dataIn;
        interface processorToGateway connect clinicalDataProcessor.gatewayOut to interoperabilityGateway.dataIn;

        satisfy dataCollection by ecgMonitor, bpMonitor, pulseOximeter;
        satisfy dataAggregation by dataAggregator;
        satisfy alarmGeneration by clinicalDataProcessor;
        satisfy dataDistribution by clinicalDataProcessor;
        satisfy dataRetention by dataRepository;
        satisfy interoperability by interoperabilityGateway;
    }

    part hospitalPlatform : PatientMonitoringSystem;

    requirement def DataCollectionRequirement {
        doc /* The system shall collect vital signs from multiple bedside medical devices including ECG, blood pressure, and pulse oximeter. */
    }
    requirement def DataAggregationRequirement {
        doc /* The Data Aggregator shall combine data streams from multiple devices, correlating by patient and timestamp. */
    }
    requirement def AlarmGenerationRequirement {
        doc /* The Clinical Data Processor shall continuously analyze vital signs against predefined safe thresholds and generate an alarm signal within seconds when any measurement falls outside the safe range. */
        attribute maxAlarmLatencySeconds : Real = 5.0;
    }
    requirement def DataDistributionRequirement {
        doc /* The system shall distribute processed patient data and alarm statuses simultaneously to the Clinical Display, Data Repository, and Interoperability Gateway. */
    }
    requirement def DataRetentionRequirement {
        doc /* The Data Repository shall securely archive the complete patient record for a minimum of seven years for legal and medical auditing purposes. */
        attribute minRetentionYears : Integer = 7;
    }
    requirement def InteroperabilityRequirement {
        doc /* The Interoperability Gateway shall support HL7 FHIR and DICOM protocols to ensure seamless communication with external healthcare information systems including the hospital EHR. */
    }

    requirement dataCollection : DataCollectionRequirement;
    requirement dataAggregation : DataAggregationRequirement;
    requirement alarmGeneration : AlarmGenerationRequirement;
    requirement dataDistribution : DataDistributionRequirement;
    requirement dataRetention : DataRetentionRequirement;
    requirement interoperability : InteroperabilityRequirement;
}
