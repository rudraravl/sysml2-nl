package MedicalExaminationStation {
    import ScalarValues::*;
    import MeasurementReferences::*;

    // ===== Units =====
    unit degC;
    unit mmHg;
    unit percent;
    unit bpm;
    unit breathsPerMin;
    unit volt;
    unit second;

    // ===== Value Types =====
    value def TemperatureValue :> Real { unit degC; }
    value def PressureValue :> Real { unit mmHg; }
    value def PercentageValue :> Real { unit percent; }
    value def HeartRateValue :> Real { unit bpm; }
    value def RespiratoryRateValue :> Real { unit breathsPerMin; }
    value def VoltageValue :> Real { unit volt; }
    value def DurationValue :> Real { unit second; }

    // ===== Enumerations =====
    enum def SeverityLevel { mild, moderate, severe, critical; }
    enum def SoundType { heartSound, lungSound; }

    // ===== Item Definitions =====
    item def VitalSignsRecord {
        attribute patientId : String;
        attribute timestamp : String;
        attribute temperature : TemperatureValue;
        attribute systolicBP : PressureValue;
        attribute diastolicBP : PressureValue;
        attribute oxygenSaturation : PercentageValue;
        attribute heartRate : HeartRateValue;
        attribute respiratoryRate : RespiratoryRateValue;
    }

    item def DiagnosticAssessment {
        attribute record : VitalSignsRecord;
        attribute abnormalFlags : String[0..*];
        attribute severity : SeverityLevel;
    }

    item def AcousticSound {
        attribute soundType : SoundType;
        attribute description : String;
    }

    // ===== Port Definitions =====
    port def DataPort {
        out record : VitalSignsRecord;
    }

    port def PowerPort {
        in voltage : VoltageValue;
    }

    port def AssessmentPort {
        out assessment : DiagnosticAssessment;
    }

    port def SoundPort {
        out sound : AcousticSound;
    }

    // ===== Requirement Definitions =====
    requirement def AccuracyRequirement {
        doc "The station shall provide accurate vital signs measurements within clinically acceptable tolerances.";
    }

    requirement def SpeedRequirement {
        doc "The station shall complete a full assessment in under 5 minutes.";
        attribute maxAssessmentTime : DurationValue = 300;
    }

    requirement def SafetyRequirement {
        doc "The station shall adhere to medical standards for electrical safety and patient data privacy.";
    }

    requirement def AlertRequirement {
        doc "The station shall immediately enter an alerting state when a critical issue is detected.";
    }

    // ===== Part Definitions =====
    part def DigitalThermometer {
        doc "An infrared device for taking body temperature readings.";
        port powerIn : PowerPort;
        port dataOut : DataPort;
        attribute measuredTemperature : TemperatureValue;

        action measureTemperature {
            out temp : TemperatureValue;
        }
    }

    part def Sphygmomanometer {
        doc "An automated, cuff-based monitor for measuring systolic and diastolic blood pressure.";
        port powerIn : PowerPort;
        port dataOut : DataPort;
        attribute systolic : PressureValue;
        attribute diastolic : PressureValue;

        action measureBloodPressure {
            out sys : PressureValue;
            out dia : PressureValue;
        }
    }

    part def PulseOximeter {
        doc "A sensor that measures oxygen saturation and heart rate.";
        port powerIn : PowerPort;
        port dataOut : DataPort;
        attribute oxygenSaturation : PercentageValue;
        attribute heartRate : HeartRateValue;

        action measureOxygenAndHeartRate {
            out spo2 : PercentageValue;
            out hr : HeartRateValue;
        }
    }

    part def Stethoscope {
        doc "A dual-head acoustic device for listening to heart and lung sounds.";
        port soundOut : SoundPort;
        attribute respiratoryRate : RespiratoryRateValue;

        action auscultate {
            out sound : AcousticSound;
            out rr : RespiratoryRateValue;
        }
    }

    part def CentralMonitoringUnit {
        doc "Collects data from each sensor, compiles a timestamped record, analyzes, and generates diagnostic assessments.";
        port powerIn : PowerPort;
        port thermometerData : DataPort;
        port sphygmomanometerData : DataPort;
        port oximeterData : DataPort;
        port stethoscopeSound : SoundPort;
        port assessmentOut : AssessmentPort;
        port recorderData : DataPort;

        attribute currentRecord : VitalSignsRecord;
        attribute assessment : DiagnosticAssessment;

        // Normal ranges
        attribute normalTempMin : TemperatureValue = 36.1;
        attribute normalTempMax : TemperatureValue = 37.2;
        attribute normalSysBPMin : PressureValue = 90;
        attribute normalSysBPMax : PressureValue = 120;
        attribute normalDiaBPMin : PressureValue = 60;
        attribute normalDiaBPMax : PressureValue = 80;
        attribute normalSpO2Min : PercentageValue = 95;
        attribute normalHRMin : HeartRateValue = 60;
        attribute normalHRMax : HeartRateValue = 100;
        attribute normalRRMin : RespiratoryRateValue = 12;
        attribute normalRRMax : RespiratoryRateValue = 20;

        action compileRecord {
            in temp : TemperatureValue;
            in sys : PressureValue;
            in dia : PressureValue;
            in spo2 : PercentageValue;
            in hr : HeartRateValue;
            in rr : RespiratoryRateValue;
            out record : VitalSignsRecord;
        }

        action analyzeData {
            in record : VitalSignsRecord;
            out assessment : DiagnosticAssessment;
        }
    }

    part def PowerDistributionUnit {
        doc "Ensures all electronic components receive stable and appropriate voltage.";
        port powerOutThermometer : PowerPort;
        port powerOutSphygmomanometer : PowerPort;
        port powerOutOximeter : PowerPort;
        port powerOutCMU : PowerPort;
        port powerOutRecorder : PowerPort;

        attribute outputVoltage : VoltageValue = 12;

        action distributePower {
            out voltage : VoltageValue;
        }
    }

    part def DataRecorder {
        doc "Stores patient vital signs records and allows later retrieval of historical data.";
        port powerIn : PowerPort;
        port dataIn : DataPort;

        attribute storedRecords : VitalSignsRecord[0..*];

        action storeRecord {
            in record : VitalSignsRecord;
        }

        action retrieveRecord {
            in patientId : String;
            out record : VitalSignsRecord;
        }
    }

    // ===== State Machine Definition =====
    state def StationStateMachine {
        state idle {
            doc "Station is on and ready for use.";
        }

        state measuring {
            doc "Instruments actively acquiring patient data.";
        }

        state analyzing {
            doc "Central unit processes data to look for abnormalities.";
        }

        state alerting {
            doc "Critical issue detected; alarms activated to notify medical staff.";
        }

        state recording {
            doc "Data sent to Data Recorder for storage in patient medical record.";
        }

        transition first to idle;
        transition idle to measuring when startExamination;
        transition measuring to analyzing when measurementsComplete;
        transition analyzing to alerting when criticalIssueDetected;
        transition analyzing to recording when noCriticalIssue;
        transition alerting to recording when alertAcknowledged;
        transition recording to idle when dataRecorded;
    }

    // ===== Main System =====
    part def MedicalExaminationStation {
        doc "An integrated Medical Examination Station for acquiring, analyzing, and recording patient vital signs.";
        requirement accuracy : AccuracyRequirement;
        requirement speed : SpeedRequirement;
        requirement safety : SafetyRequirement;
        requirement alert : AlertRequirement;

        part thermometer : DigitalThermometer;
        part sphygmomanometer : Sphygmomanometer;
        part pulseOximeter : PulseOximeter;
        part stethoscope : Stethoscope;
        part cmu : CentralMonitoringUnit;
        part pdu : PowerDistributionUnit;
        part recorder : DataRecorder;

        // Power connections
        connect pdu.powerOutThermometer to thermometer.powerIn;
        connect pdu.powerOutSphygmomanometer to sphygmomanometer.powerIn;
        connect pdu.powerOutOximeter to pulseOximeter.powerIn;
        connect pdu.powerOutCMU to cmu.powerIn;
        connect pdu.powerOutRecorder to recorder.powerIn;

        // Data connections
        connect thermometer.dataOut to cmu.thermometerData;
        connect sphygmomanometer.dataOut to cmu.sphygmomanometerData;
        connect pulseOximeter.dataOut to cmu.oximeterData;
        connect stethoscope.soundOut to cmu.stethoscopeSound;
        connect cmu.recorderData to recorder.dataIn;

        exhibit StationStateMachine;
    }
}
