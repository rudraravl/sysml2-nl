package MedicalExaminationStation {
    private import ISQ::TemperatureValue;
    private import ISQ::PressureValue;
    private import ISQ::ElectricPotentialValue;
    private import ISQ::DurationValue;
    private import ScalarValues::*;
    private import Time::TimeInstantValue;
    private import SI::min;
    private import SI::s;

    item def TemperatureReading {
        attribute temp : TemperatureValue;
        attribute timestamp : TimeInstantValue;
    }
    item def BloodPressureReading {
        attribute systolic : PressureValue;
        attribute diastolic : PressureValue;
        attribute timestamp : TimeInstantValue;
    }
    item def PulseOximeterReading {
        attribute spo2 : Real;
        attribute heartRate : Integer;
        attribute timestamp : TimeInstantValue;
    }
    item def StethoscopeReading {
        attribute heartSounds : String;
        attribute lungSounds : String;
        attribute respiratoryRate : Integer;
        attribute timestamp : TimeInstantValue;
    }
    item def VitalSignsRecord {
        attribute patientId : String;
        attribute temperature : TemperatureReading;
        attribute bloodPressure : BloodPressureReading;
        attribute pulseOximetry : PulseOximeterReading;
        attribute stethoscope : StethoscopeReading;
        attribute timestamp : TimeInstantValue;
    }
    item def DiagnosticAssessment {
        attribute severity : SeverityLevel;
        attribute abnormalities : String;
        attribute timestamp : TimeInstantValue;
    }
    enum def SeverityLevel {
        mild;
        moderate;
        critical;
    }
    item def PowerSupply {
        attribute voltage : ElectricPotentialValue;
    }

    attribute def StartExamination;
    attribute def MeasurementsComplete;
    attribute def AnalysisComplete;
    attribute def AlertAcknowledged;
    attribute def RecordingComplete;
    attribute def AlertSignal;

    action def AcquireMeasurements {
        out temp : TemperatureReading;
        out bp : BloodPressureReading;
        out pulse : PulseOximeterReading;
        out stethoscope : StethoscopeReading;
    }
    action def AnalyzeVitals {
        in record : VitalSignsRecord;
        out assessment : DiagnosticAssessment;
    }
    action def RecordData {
        in record : VitalSignsRecord;
    }

    part def DigitalThermometer {
        port tempOut {
            out temp : TemperatureReading;
        }
        port powerIn {
            in power : PowerSupply;
        }
    }
    part def Sphygmomanometer {
        port bpOut {
            out bp : BloodPressureReading;
        }
        port powerIn {
            in power : PowerSupply;
        }
    }
    part def PulseOximeter {
        port pulseOut {
            out pulse : PulseOximeterReading;
        }
        port powerIn {
            in power : PowerSupply;
        }
    }
    part def Stethoscope {
        port stethoscopeOut {
            out stethoscope : StethoscopeReading;
        }
    }
    part def CentralMonitoringUnit {
        port tempIn {
            in temp : TemperatureReading;
        }
        port bpIn {
            in bp : BloodPressureReading;
        }
        port pulseIn {
            in pulse : PulseOximeterReading;
        }
        port stethoscopeIn {
            in stethoscope : StethoscopeReading;
        }
        port recordOut {
            out record : VitalSignsRecord;
        }
        port powerIn {
            in power : PowerSupply;
        }
    }
    part def PowerDistributionUnit {
        port powerOut {
            out power : PowerSupply;
        }
    }
    part def DataRecorder {
        port recordIn {
            in record : VitalSignsRecord;
        }
        port powerIn {
            in power : PowerSupply;
        }
        port retrievalOut {
            out history : VitalSignsRecord;
        }
    }

    part def MedicalExaminationStation {
        attribute assessmentTime : DurationValue;
        attribute electricalSafetyCertified : Boolean;
        attribute dataPrivacyCompliant : Boolean;
    }

    part medicalStaff;

    part medicalExaminationStation : MedicalExaminationStation {
        attribute :>> assessmentTime = 4 [min];
        attribute :>> electricalSafetyCertified = true;
        attribute :>> dataPrivacyCompliant = true;

        part digitalThermometer : DigitalThermometer;
        part sphygmomanometer : Sphygmomanometer;
        part pulseOximeter : PulseOximeter;
        part stethoscope : Stethoscope;
        part centralMonitoringUnit : CentralMonitoringUnit;
        part powerDistributionUnit : PowerDistributionUnit;
        part dataRecorder : DataRecorder;

        flow tempFlow of TemperatureReading
            from digitalThermometer.tempOut.temp to centralMonitoringUnit.tempIn.temp;
        flow bpFlow of BloodPressureReading
            from sphygmomanometer.bpOut.bp to centralMonitoringUnit.bpIn.bp;
        flow pulseFlow of PulseOximeterReading
            from pulseOximeter.pulseOut.pulse to centralMonitoringUnit.pulseIn.pulse;
        flow stethoscopeFlow of StethoscopeReading
            from stethoscope.stethoscopeOut.stethoscope to centralMonitoringUnit.stethoscopeIn.stethoscope;
        flow recordFlow of VitalSignsRecord
            from centralMonitoringUnit.recordOut.record to dataRecorder.recordIn.record;

        flow powerFlow1 of PowerSupply
            from powerDistributionUnit.powerOut.power to digitalThermometer.powerIn.power;
        flow powerFlow2 of PowerSupply
            from powerDistributionUnit.powerOut.power to sphygmomanometer.powerIn.power;
        flow powerFlow3 of PowerSupply
            from powerDistributionUnit.powerOut.power to pulseOximeter.powerIn.power;
        flow powerFlow4 of PowerSupply
            from powerDistributionUnit.powerOut.power to centralMonitoringUnit.powerIn.power;
        flow powerFlow5 of PowerSupply
            from powerDistributionUnit.powerOut.power to dataRecorder.powerIn.power;

        action acquireMeasurements : AcquireMeasurements;
        action analyzeVitals : AnalyzeVitals;
        action recordDataAction : RecordData;

        exhibit state examinationStates {
            entry; then idle;
            state idle;
            accept StartExamination then measuring;
            state measuring {
                do acquireMeasurements;
            }
            accept MeasurementsComplete then analyzing;
            state analyzing {
                do analyzeVitals;
            }
            accept AnalysisComplete if analyzeVitals.assessment.severity == SeverityLevel::critical then alerting;
            accept AnalysisComplete if analyzeVitals.assessment.severity != SeverityLevel::critical then recording;
            state alerting {
                do send new AlertSignal() to medicalStaff;
            }
            accept AlertAcknowledged then idle;
            state recording {
                do recordDataAction;
            }
            accept RecordingComplete then idle;
        }
    }

    requirement def PerformanceRequirement {
        subject station : MedicalExaminationStation;
        constraint { station.assessmentTime <= 5 [min] }
    }
    requirement def SafetyRequirement {
        subject station : MedicalExaminationStation;
        constraint { station.electricalSafetyCertified == true }
        constraint { station.dataPrivacyCompliant == true }
    }

    requirement performanceReq : PerformanceRequirement {
        subject station = medicalExaminationStation;
    }
    requirement safetyReq : SafetyRequirement {
        subject station = medicalExaminationStation;
    }
}
