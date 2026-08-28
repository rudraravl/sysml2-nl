package ProtectiveMechanicalVentilator {
    private import ScalarValues::*;
    
    value type PressureValue :> Real;
    value type VolumeValue :> Real;
    value type FlowRateValue :> Real;
    value type RespiratoryRateValue :> Integer;
    value type OxygenConcentrationValue :> Real;
    value type BodyWeightValue :> Real;
    
    item def BreathableGas {
        attribute oxygenConcentration : OxygenConcentrationValue;
        attribute flowRate : FlowRateValue;
    }
    
    item def VentilatorSettings {
        attribute respiratoryRate : RespiratoryRateValue;
        attribute oxygenConcentration : OxygenConcentrationValue;
        attribute peep : PressureValue;
        attribute tidalVolumeTarget : VolumeValue;
    }
    
    item def PatientParameters {
        attribute predictedBodyWeight : BodyWeightValue;
    }
    
    item def SensorReading {
        attribute airwayPressure : PressureValue;
        attribute tidalVolume : VolumeValue;
        attribute flowRate : FlowRateValue;
    }
    
    item def ControlCommand {
        attribute targetFlow : FlowRateValue;
        attribute targetPressure : PressureValue;
        attribute targetVolume : VolumeValue;
        attribute peep : PressureValue;
    }
    
    item def AlarmSignal {
        attribute alarmType : String;
        attribute severity : String;
    }
    
    enum def BreathingPhase { inspiration; expiration; }
    enum def AlarmType { highPressure; highVolume; lowPressure; systemFault; }
    
    part def ClinicalUser {
        port settingsPort { out settings : VentilatorSettings; }
        port patientDataPort { out patientParams : PatientParameters; }
        port alarmReceivePort { in alarm : AlarmSignal; }
    }
    
    part def Patient {
        port airwayPort { in gas : BreathableGas; }
        attribute predictedBodyWeight : BodyWeightValue;
    }
    
    part def PneumaticDeliverySystem {
        port gasInputPort { in gas : BreathableGas; }
        port patientPort { out gas : BreathableGas; }
        port commandPort { in command : ControlCommand; }
        attribute currentPhase : BreathingPhase;
        
        perform action deliverGas {
            in gas : BreathableGas;
            in command : ControlCommand;
            out deliveredGas : BreathableGas;
            first start;
            then action regulateInhalation;
            then action maintainPEEP;
            then done;
        }
    }
    
    part def SensorArray {
        port sensingPort { in gas : BreathableGas; }
        port dataPort { out reading : SensorReading; }
        
        part pressureSensor {
            attribute measuredPressure : PressureValue;
            perform action measurePressure { out pressure : PressureValue; }
        }
        part flowSensor {
            attribute measuredFlow : FlowRateValue;
            perform action measureFlow { out flow : FlowRateValue; }
        }
        part volumeSensor {
            attribute measuredVolume : VolumeValue;
            perform action measureVolume { out volume : VolumeValue; }
        }
        
        perform action aggregateReadings {
            in pressure : PressureValue;
            in flow : FlowRateValue;
            in volume : VolumeValue;
            out reading : SensorReading;
            first start;
            then action collectPressure;
            then action collectFlow;
            then action collectVolume;
            then action assembleReading;
            then done;
        }
    }
    
    part def AlarmSystem {
        port alarmInputPort { in trigger : AlarmType; }
        port alarmOutputPort { out alarm : AlarmSignal; }
        
        perform action raiseAlarm {
            in trigger : AlarmType;
            out alarm : AlarmSignal;
            first start;
            then action determineSeverity;
            then action generateSignal;
            then done;
        }
    }
    
    part def VentilatorController {
        port settingsPort { in settings : VentilatorSettings; }
        port patientDataPort { in patientParams : PatientParameters; }
        port sensorPort { in reading : SensorReading; }
        port commandPort { out command : ControlCommand; }
        port alarmPort { out trigger : AlarmType; }
        
        attribute maxPressureLimit : PressureValue = 30;
        attribute maxTidalVolumePerKg : VolumeValue = 6;
        attribute currentPhase : BreathingPhase;
        attribute settingsReceived : Boolean;
        attribute inspirationComplete : Boolean;
        attribute expirationComplete : Boolean;
        attribute alarmTriggered : Boolean;
        attribute alarmReset : Boolean;
        
        perform action computeSafetyLimits {
            in predictedBodyWeight : BodyWeightValue;
            out pressureLimit : PressureValue;
            out volumeLimit : VolumeValue;
            first start;
            then action calculateVolumeLimit;
            then done;
        }
        
        perform action evaluateSafety {
            in reading : SensorReading;
            in pressureLimit : PressureValue;
            in volumeLimit : VolumeValue;
            out trigger : AlarmType;
            first start;
            then action checkPressure;
            then action checkVolume;
            then action decideAlarm;
            then done;
        }
        
        state machine breathingCycle {
            state idle {
                transition to inspiring when settingsReceived;
            }
            state inspiring {
                transition to expiring when inspirationComplete;
                transition to alarming when alarmTriggered;
            }
            state expiring {
                transition to inspiring when expirationComplete;
                transition to alarming when alarmTriggered;
            }
            state alarming {
                transition to idle when alarmReset;
            }
        }
    }
    
    part def ProtectiveVentilator {
        port userSettingsPort { in settings : VentilatorSettings; }
        port userPatientDataPort { in patientParams : PatientParameters; }
        port userAlarmPort { out alarm : AlarmSignal; }
        port patientAirwayPort { out gas : BreathableGas; }
        
        part controller : VentilatorController;
        part pneumaticSystem : PneumaticDeliverySystem;
        part sensorArray : SensorArray;
        part alarmSystem : AlarmSystem;
        
        connect userSettingsPort to controller.settingsPort;
        connect userPatientDataPort to controller.patientDataPort;
        connect controller.commandPort to pneumaticSystem.commandPort;
        connect pneumaticSystem.patientPort to patientAirwayPort;
        connect pneumaticSystem.patientPort to sensorArray.sensingPort;
        connect sensorArray.dataPort to controller.sensorPort;
        connect controller.alarmPort to alarmSystem.alarmInputPort;
        connect alarmSystem.alarmOutputPort to userAlarmPort;
    }
    
    requirement def ProtectiveVentilationRequirement {
        subject ventilator : ProtectiveVentilator;
        doc "The ventilator shall provide life-sustaining breathing support while preventing VALI.";
    }
    
    requirement def PressureSafetyRequirement :> ProtectiveVentilationRequirement {
        subject ventilator : ProtectiveVentilator;
        doc "The ventilator shall ensure airway pressure does not exceed the maximum pressure limit.";
        constraint { ventilator.sensorArray.pressureSensor.measuredPressure <= ventilator.controller.maxPressureLimit }
    }
    
    requirement def VolumeSafetyRequirement :> ProtectiveVentilationRequirement {
        subject ventilator : ProtectiveVentilator;
        doc "The ventilator shall ensure delivered tidal volume does not exceed the patient-specific volume limit.";
        constraint { ventilator.sensorArray.volumeSensor.measuredVolume <= ventilator.controller.maxTidalVolumePerKg * 70 }
    }
    
    requirement def AlarmResponseRequirement :> ProtectiveVentilationRequirement {
        subject ventilator : ProtectiveVentilator;
        doc "The ventilator shall trigger an alarm when pressure or volume limits are exceeded.";
        constraint { ventilator.controller.alarmTriggered }
    }
    
    requirement def ClosedLoopControlRequirement :> ProtectiveVentilationRequirement {
        subject ventilator : ProtectiveVentilator;
        doc "The controller shall continuously analyze sensor feedback and adjust gas delivery in a closed loop.";
        constraint { ventilator.sensorArray.dataPort.reading != null implies ventilator.controller.commandPort.command != null }
    }
    
    part ventilatorInstance : ProtectiveVentilator;
    
    part clinician : ClinicalUser;
    
    part patientInstance : Patient {
        attribute :>> predictedBodyWeight = 70;
    }
    
    connect clinician.settingsPort to ventilatorInstance.userSettingsPort;
    connect clinician.patientDataPort to ventilatorInstance.userPatientDataPort;
    connect ventilatorInstance.userAlarmPort to clinician.alarmReceivePort;
    connect ventilatorInstance.patientAirwayPort to patientInstance.airwayPort;
}
