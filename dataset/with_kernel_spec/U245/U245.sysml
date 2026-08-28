package HospitalBedSystem {
    private import ScalarValues::*;
    
    value def AngleDeg :> Real;
    value def HeightCm :> Real;
    value def WeightKg :> Real;
    value def PressurePa :> Real;
    
    item def BedCommand {
        attribute headAngleCmd : AngleDeg;
        attribute footAngleCmd : AngleDeg;
        attribute heightCmd : HeightCm;
    }
    
    item def BedStatus {
        attribute currentHeadAngle : AngleDeg;
        attribute currentFootAngle : AngleDeg;
        attribute currentHeight : HeightCm;
        attribute patientWeight : WeightKg;
    }
    
    item def Alert {
        attribute severity : Integer;
        attribute alertText : String;
    }
    
    item def PressureMap {
        attribute values : PressurePa[16];
    }
    
    port def CaregiverPort {
        in command : BedCommand;
        out status : BedStatus;
        out alert : Alert;
    }
    
    port def MotorControlPort {
        out angleCmd : AngleDeg;
    }
    
    port def ActuatorControlPort {
        out heightCmd : HeightCm;
    }
    
    port def PressureSensorPort {
        out pressureData : PressureMap;
    }
    
    port def LoadCellPort {
        out weightData : WeightKg;
    }
    
    part def ElectricMotor {
        port controlPort : ~MotorControlPort;
        attribute currentAngle : AngleDeg;
    }
    
    part def LinearActuator {
        port controlPort : ~ActuatorControlPort;
        attribute currentHeight : HeightCm;
    }
    
    part def BedSection {
        part motor : ElectricMotor;
        port motorControl : ~MotorControlPort;
        bind motorControl = motor.controlPort;
    }
    
    part def PressureSensor {
        port dataPort : PressureSensorPort;
    }
    
    part def LoadCell {
        port dataPort : LoadCellPort;
    }
    
    action def ProcessSensorData {
        in pressureData : PressureMap;
        in weightData : WeightKg;
        out status : BedStatus;
    }
    
    action def CheckSafetyLimits {
        in weight : WeightKg;
        in angle : AngleDeg;
        in height : HeightCm;
        out alert : Alert;
    }
    
    action def ProcessCommand {
        in command : BedCommand;
        out headAngleCmd : AngleDeg;
        out footAngleCmd : AngleDeg;
        out heightCmd : HeightCm;
    }
    
    action def GenerateAlert {
        out alert : Alert;
    }
    
    state def ControlStateMachine {
        entry; then Monitoring;
        state Monitoring {
            do action processSensorData;
        }
        state Adjusting {
            do action processCommand;
        }
        state Alerting {
            do action generateAlert;
        }
        transition first Monitoring accept command : BedCommand then Adjusting;
        transition first Adjusting then Monitoring;
        transition first Alerting then Monitoring;
    }
    
    part def ControlUnit {
        port caregiverPort : CaregiverPort;
        port headMotorPort : MotorControlPort;
        port footMotorPort : MotorControlPort;
        port actuatorPort : ActuatorControlPort;
        port pressureSensorPort : ~PressureSensorPort;
        port loadCellPort : ~LoadCellPort;
        
        attribute maxWeight : WeightKg = 250;
        attribute maxAngle : AngleDeg = 80;
        attribute maxHeight : HeightCm = 100;
        
        state controllerStateMachine : ControlStateMachine;
    }
    
    part def CaregiverInterface {
        port interfacePort : ~CaregiverPort;
    }
    
    part def BedFrame {
        part headSection : BedSection;
        part footSection : BedSection;
        part linearActuator : LinearActuator;
        
        port headMotorControl : ~MotorControlPort;
        port footMotorControl : ~MotorControlPort;
        port actuatorControl : ~ActuatorControlPort;
        
        bind headMotorControl = headSection.motorControl;
        bind footMotorControl = footSection.motorControl;
        bind actuatorControl = linearActuator.controlPort;
    }
    
    part def HospitalBed {
        part controlUnit : ControlUnit;
        part bedFrame : BedFrame;
        part pressureSensors[16] : PressureSensor;
        part loadCells[4] : LoadCell;
        part caregiverInterface : CaregiverInterface;
        
        connect controlUnit.caregiverPort to caregiverInterface.interfacePort;
        connect controlUnit.headMotorPort to bedFrame.headMotorControl;
        connect controlUnit.footMotorPort to bedFrame.footMotorControl;
        connect controlUnit.actuatorPort to bedFrame.actuatorControl;
        connect pressureSensors.dataPort to controlUnit.pressureSensorPort;
        connect loadCells.dataPort to controlUnit.loadCellPort;
    }
    
    requirement def PressureUlcerRiskAlert {
        subject bed : HospitalBed;
        doc /* Alert caregivers to reposition patient when prolonged pressure is detected. */
    }
    
    requirement def PatientExitDetection {
        subject bed : HospitalBed;
        doc /* Detect patient exit via weight drop and pressure change, and alert staff. */
    }
    
    requirement def SafetyInterlocks {
        subject bed : HospitalBed;
        doc /* Ensure adjustments remain within safe mechanical limits and monitor weight capacity. */
    }
}
