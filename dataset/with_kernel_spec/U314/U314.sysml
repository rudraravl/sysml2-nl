package 'MAST System' {
    private import ScalarValues::*;

    attribute def Pressure :> Real;
    attribute def BloodPressure :> Real;
    attribute def HeartRateValue :> Real;
    attribute def Perfusion :> Real;

    item def VitalSigns {
        attribute systolicBP : BloodPressure;
        attribute diastolicBP : BloodPressure;
        attribute heartRate : HeartRateValue;
        attribute perfusionIndex : Perfusion;
    }

    item def PressureReading {
        attribute pressure : Pressure;
    }

    item def InflationCommand {
        attribute targetPressure : Pressure;
    }

    item def DeflationCommand {
        attribute targetPressure : Pressure;
    }

    item def EmergencyDeflationCommand;

    item def ShockAssessment {
        attribute inShock : Boolean;
        attribute severity : Real;
    }

    action def AssessPatient {
        in vitals : VitalSigns;
        out assessment : ShockAssessment;
    }

    action def InflateLegs {
        in targetPressure : Pressure;
        out leftCommand : InflationCommand;
        out rightCommand : InflationCommand;
    }

    action def ReEvaluatePatient {
        in vitals : VitalSigns;
        out bpImproved : Boolean;
    }

    action def InflateAbdomen {
        in targetPressure : Pressure;
        out command : InflationCommand;
    }

    action def MaintainPressure {
        in leftReading : PressureReading;
        in rightReading : PressureReading;
        in abdomenReading : PressureReading;
        out leftCommand : InflationCommand;
        out rightCommand : InflationCommand;
        out abdomenCommand : InflationCommand;
    }

    action def WeanPressure {
        out leftCommand : DeflationCommand;
        out rightCommand : DeflationCommand;
        out abdomenCommand : DeflationCommand;
    }

    action def EmergencyDeflate {
        out command : EmergencyDeflationCommand;
    }

    action def MASTTherapy {
        first start;
        then action assess : AssessPatient {
            out assessment : ShockAssessment;
        }
        then decide;
            if assess.assessment.inShock then deployLegs;
            if not assess.assessment.inShock then endTreatment;
        action deployLegs : InflateLegs {
            in targetPressure = 60;
        }
        then action reEval : ReEvaluatePatient {
            out bpImproved : Boolean;
        }
        then decide;
            if reEval.bpImproved then maintain;
            if not reEval.bpImproved then deployAbdomen;
        action deployAbdomen : InflateAbdomen {
            in targetPressure = 40;
        }
        then maintain;
        action maintain : MaintainPressure;
        then action wean : WeanPressure;
        then done;
        action endTreatment;
        then done;
    }

    part def PressureSensor {
        port readingOut {
            out reading : PressureReading;
        }
    }

    part def InflatableCompartment {
        port inflationIn {
            in inflationCmd : InflationCommand;
        }
        port deflationIn {
            in deflationCmd : DeflationCommand;
        }
        port emergencyIn {
            in emergencyCmd : EmergencyDeflationCommand;
        }
        port pressureOut {
            out reading : PressureReading;
        }
        part sensor : PressureSensor;
        flow sensorFlow of PressureReading
            from sensor.readingOut.reading to pressureOut.reading;
    }

    part def MASTTrousers {
        part leftLeg : InflatableCompartment;
        part rightLeg : InflatableCompartment;
        part abdomen : InflatableCompartment;
    }

    part def PatientMonitoringUnit {
        port vitalsOut {
            out vitals : VitalSigns;
        }
    }

    part def TherapyController {
        port vitalsIn {
            in vitals : VitalSigns;
        }
        port leftPressureIn {
            in reading : PressureReading;
        }
        port rightPressureIn {
            in reading : PressureReading;
        }
        port abdomenPressureIn {
            in reading : PressureReading;
        }
        port leftInflateOut {
            out cmd : InflationCommand;
        }
        port rightInflateOut {
            out cmd : InflationCommand;
        }
        port abdomenInflateOut {
            out cmd : InflationCommand;
        }
        port leftDeflateOut {
            out cmd : DeflationCommand;
        }
        port rightDeflateOut {
            out cmd : DeflationCommand;
        }
        port abdomenDeflateOut {
            out cmd : DeflationCommand;
        }
        port emergencyOut {
            out cmd : EmergencyDeflationCommand;
        }
        perform action therapy : MASTTherapy;
    }

    part def PneumaticControlUnit {
        port leftInflateIn {
            in cmd : InflationCommand;
        }
        port rightInflateIn {
            in cmd : InflationCommand;
        }
        port abdomenInflateIn {
            in cmd : InflationCommand;
        }
        port leftDeflateIn {
            in cmd : DeflationCommand;
        }
        port rightDeflateIn {
            in cmd : DeflationCommand;
        }
        port abdomenDeflateIn {
            in cmd : DeflationCommand;
        }
        port emergencyIn {
            in cmd : EmergencyDeflationCommand;
        }
        port leftPneumaticOut {
            out inflationCmd : InflationCommand;
            out deflationCmd : DeflationCommand;
            out emergencyCmd : EmergencyDeflationCommand;
        }
        port rightPneumaticOut {
            out inflationCmd : InflationCommand;
            out deflationCmd : DeflationCommand;
            out emergencyCmd : EmergencyDeflationCommand;
        }
        port abdomenPneumaticOut {
            out inflationCmd : InflationCommand;
            out deflationCmd : DeflationCommand;
            out emergencyCmd : EmergencyDeflationCommand;
        }
    }

    part def MASTDevice {
        part therapyController : TherapyController;
        part patientMonitor : PatientMonitoringUnit;
        part pneumaticUnit : PneumaticControlUnit;
        part trousers : MASTTrousers;

        flow vitalsFlow of VitalSigns
            from patientMonitor.vitalsOut.vitals to therapyController.vitalsIn.vitals;

        flow leftPressureFlow of PressureReading
            from trousers.leftLeg.pressureOut.reading to therapyController.leftPressureIn.reading;
        flow rightPressureFlow of PressureReading
            from trousers.rightLeg.pressureOut.reading to therapyController.rightPressureIn.reading;
        flow abdomenPressureFlow of PressureReading
            from trousers.abdomen.pressureOut.reading to therapyController.abdomenPressureIn.reading;

        flow leftInflateFlow of InflationCommand
            from therapyController.leftInflateOut.cmd to pneumaticUnit.leftInflateIn.cmd;
        flow rightInflateFlow of InflationCommand
            from therapyController.rightInflateOut.cmd to pneumaticUnit.rightInflateIn.cmd;
        flow abdomenInflateFlow of InflationCommand
            from therapyController.abdomenInflateOut.cmd to pneumaticUnit.abdomenInflateIn.cmd;

        flow leftDeflateFlow of DeflationCommand
            from therapyController.leftDeflateOut.cmd to pneumaticUnit.leftDeflateIn.cmd;
        flow rightDeflateFlow of DeflationCommand
            from therapyController.rightDeflateOut.cmd to pneumaticUnit.rightDeflateIn.cmd;
        flow abdomenDeflateFlow of DeflationCommand
            from therapyController.abdomenDeflateOut.cmd to pneumaticUnit.abdomenDeflateIn.cmd;

        flow emergencyFlow of EmergencyDeflationCommand
            from therapyController.emergencyOut.cmd to pneumaticUnit.emergencyIn.cmd;

        flow pcuLeftInflateFlow of InflationCommand
            from pneumaticUnit.leftPneumaticOut.inflationCmd to trousers.leftLeg.inflationIn.inflationCmd;
        flow pcuLeftDeflateFlow of DeflationCommand
            from pneumaticUnit.leftPneumaticOut.deflationCmd to trousers.leftLeg.deflationIn.deflationCmd;
        flow pcuLeftEmergencyFlow of EmergencyDeflationCommand
            from pneumaticUnit.leftPneumaticOut.emergencyCmd to trousers.leftLeg.emergencyIn.emergencyCmd;

        flow pcuRightInflateFlow of InflationCommand
            from pneumaticUnit.rightPneumaticOut.inflationCmd to trousers.rightLeg.inflationIn.inflationCmd;
        flow pcuRightDeflateFlow of DeflationCommand
            from pneumaticUnit.rightPneumaticOut.deflationCmd to trousers.rightLeg.deflationIn.deflationCmd;
        flow pcuRightEmergencyFlow of EmergencyDeflationCommand
            from pneumaticUnit.rightPneumaticOut.emergencyCmd to trousers.rightLeg.emergencyIn.emergencyCmd;

        flow pcuAbdomenInflateFlow of InflationCommand
            from pneumaticUnit.abdomenPneumaticOut.inflationCmd to trousers.abdomen.inflationIn.inflationCmd;
        flow pcuAbdomenDeflateFlow of DeflationCommand
            from pneumaticUnit.abdomenPneumaticOut.deflationCmd to trousers.abdomen.deflationIn.deflationCmd;
        flow pcuAbdomenEmergencyFlow of EmergencyDeflationCommand
            from pneumaticUnit.abdomenPneumaticOut.emergencyCmd to trousers.abdomen.emergencyIn.emergencyCmd;
    }

    requirement def MASTSafetyRequirement {
        doc /* The MAST system shall enforce maximum pressure limits in all compartments and provide an emergency rapid deflation capability to prevent patient injury and allow immediate medical intervention. */
    }

    requirement def MASTAutoDetectionRequirement {
        doc /* The system shall automatically detect hemorrhagic shock and its severity from patient blood pressure, heart rate, and perfusion status. */
    }

    requirement def MASTSequentialInflationRequirement {
        doc /* The system shall inflate leg compartments first, re-evaluate the patient, then inflate the abdominal compartment only if blood pressure has not sufficiently improved. */
    }

    requirement def MASTPressureMaintenanceRequirement {
        doc /* The system shall maintain target compartment pressures using real-time feedback from dedicated pressure sensors in each compartment. */
    }

    requirement def MASTWeaningRequirement {
        doc /* The system shall gradually release pressure during the weaning phase to prevent a sudden drop in the patient's blood pressure. */
    }

    requirement mastSafety : MASTSafetyRequirement;
    requirement mastAutoDetection : MASTAutoDetectionRequirement;
    requirement mastSequentialInflation : MASTSequentialInflationRequirement;
    requirement mastPressureMaintenance : MASTPressureMaintenanceRequirement;
    requirement mastWeaning : MASTWeaningRequirement;

    part mastDevice : MASTDevice;
}
