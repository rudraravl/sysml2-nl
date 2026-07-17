package SafetyCriticalSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def ConcentrationValue :> Real;
    
    attribute def PressureValue :> ISQ::pressure;
    
    attribute def TemperatureValue :> ISQ::thermodynamicTemperature;
    
    enum def SafetyState {
        normal;
        warning;
        critical;
        emergency;
    }
    
    enum def AlarmLevel {
        none;
        low;
        medium;
        high;
    }
    
    item def Hazard {
        attribute severity : Real;
        attribute probability : Real;
        attribute riskLevel : Real;
    }
    
    port def SensorPort {
        out reading : Real;
        out status : Boolean;
    }
    
    port def ControlPort {
        in command : String;
        out response : String;
    }
    
    port def AlarmPort {
        out alarmSignal : AlarmLevel;
        out message : String;
    }
    
    part def Sensor {
        attribute sensorId : String;
        attribute isOperational : Boolean;
        port sensorOutput : SensorPort;
    }
    
    part def PressureSensor :> Sensor {
        attribute currentPressure : PressureValue;
        attribute pressureThreshold : PressureValue;
    }
    
    part def TemperatureSensor :> Sensor {
        attribute currentTemperature : TemperatureValue;
        attribute temperatureThreshold : TemperatureValue;
    }
    
    part def GasSensor :> Sensor {
        attribute currentConcentration : ConcentrationValue;
        attribute concentrationThreshold : ConcentrationValue;
    }
    
    part def SafetyController {
        attribute currentState : SafetyState;
        attribute responseTime : DurationValue;
        
        port controlInput : ControlPort;
        port alarmOutput : AlarmPort;
        
        part processor {
            attribute processingCapacity : Real;
        }
        
        part memory {
            attribute capacity : Real;
        }
    }
    
    part def AlarmSystem {
        attribute alarmActive : Boolean;
        attribute alarmType : AlarmLevel;
        
        port alarmInput : AlarmPort;
        
        part visualAlarm {
            attribute brightness : Real;
            attribute color : String;
        }
        
        part audioAlarm {
            attribute volume : Real;
            attribute frequency : Real;
        }
    }
    
    part def EmergencyShutdown {
        attribute shutdownInitiated : Boolean;
        attribute shutdownTime : DurationValue;
        
        part powerCutoff {
            attribute isActive : Boolean;
        }
        
        part ventilationSystem {
            attribute isActive : Boolean;
        }
    }
    
    action def MonitorSensors {
        in sensorData : Real[*];
        out safetyStatus : SafetyState;
        out hazards : Hazard[*];
    }
    
    action def EvaluateRisk {
        in hazards : Hazard[*];
        in currentState : SafetyState;
        out riskAssessment : Real;
        out recommendedAction : String;
    }
    
    action def TriggerAlarm {
        in alarmLevel : AlarmLevel;
        in message : String;
    }
    
    action def InitiateShutdown {
        in reason : String;
        out shutdownConfirmed : Boolean;
    }
    
    action def SafetyMonitoringCycle {
        first start;
        then merge continuousMonitoring;
        
        then action monitor : MonitorSensors {
            in sensorData : Real[*];
            out safetyStatus : SafetyState;
            out detectedHazards : Hazard[*];
        }
        
        then action evaluate : EvaluateRisk {
            in hazards = monitor.detectedHazards;
            in currentState = monitor.safetyStatus;
            out riskLevel : Real;
            out action : String;
        }
        
        then decide;
            if evaluate.riskLevel < 0.3 then maintainNormal;
            if evaluate.riskLevel >= 0.3 and evaluate.riskLevel < 0.6 then issueWarning;
            if evaluate.riskLevel >= 0.6 and evaluate.riskLevel < 0.9 then raiseCritical;
            if evaluate.riskLevel >= 0.9 then emergencyResponse;
        
        action maintainNormal {
            then continuousMonitoring;
        }
        
        action issueWarning : TriggerAlarm {
            in alarmLevel = AlarmLevel::low;
            in message = "Warning condition detected";
        }
        then continuousMonitoring;
        
        action raiseCritical : TriggerAlarm {
            in alarmLevel = AlarmLevel::high;
            in message = "Critical condition detected";
        }
        then continuousMonitoring;
        
        action emergencyResponse : InitiateShutdown {
            in reason = "Emergency threshold exceeded";
            out confirmed : Boolean;
        }
        then done;
    }
    
    state def SafetyStateMachine {
        entry; then normalOperation;
        
        state normalOperation;
        
        state warningState;
        
        state criticalState;
        
        state emergencyState;
        
        transition normalToWarning
            first normalOperation
            if riskLevel >= 0.3
            then warningState;
        
        transition warningToNormal
            first warningState
            if riskLevel < 0.3
            then normalOperation;
        
        transition warningToCritical
            first warningState
            if riskLevel >= 0.6
            then criticalState;
        
        transition criticalToWarning
            first criticalState
            if riskLevel < 0.6
            then warningState;
        
        transition criticalToEmergency
            first criticalState
            if riskLevel >= 0.9
            then emergencyState;
    }
    
    part def IndustrialSafetySystem {
        attribute systemId : String;
        attribute operationalStatus : Boolean;
        attribute overallRiskLevel : Real;
        
        part sensors {
            part pressureSensor1 : PressureSensor {
                attribute :>> sensorId = "PS-001";
                attribute :>> isOperational = true;
            }
            
            part tempSensor1 : TemperatureSensor {
                attribute :>> sensorId = "TS-001";
                attribute :>> isOperational = true;
            }
            
            part gasSensor1 : GasSensor {
                attribute :>> sensorId = "GS-001";
                attribute :>> isOperational = true;
            }
        }
        
        part controller : SafetyController {
            attribute :>> currentState = SafetyState::normal;
        }
        
        part alarmSystem : AlarmSystem {
            attribute :>> alarmActive = false;
            attribute :>> alarmType = AlarmLevel::none;
        }
        
        part emergencyShutdown : EmergencyShutdown {
            attribute :>> shutdownInitiated = false;
        }
        
        connection sensorToController connect 
            sensors.pressureSensor1.sensorOutput to controller.controlInput;
        
        connection controllerToAlarm connect
            controller.alarmOutput to alarmSystem.alarmInput;
    }
    
    requirement <'REQ-SAFE-001'> primarySafetyFunction {
        doc /* The safety system shall continuously monitor environmental 
             * and operational conditions to detect hazardous situations 
             * and automatically initiate appropriate protective responses 
             * to prevent harm to personnel, equipment, and the environment.
             */
        subject safetySystem : IndustrialSafetySystem;
    }
    
    requirement <'REQ-SAFE-002'> continuousMonitoring {
        doc /* The system shall continuously monitor all connected sensors 
             * with a maximum response time of 100 milliseconds.
             */
        subject safetySystem : IndustrialSafetySystem;
        
        assert constraint {
            safetySystem.controller.responseTime <= 0.1 [s]
        }
    }
    
    requirement <'REQ-SAFE-003'> automaticResponse {
        doc /* Upon detecting a hazardous condition, the system shall 
             * automatically activate appropriate alarms and protective 
             * measures within 500 milliseconds.
             */
        subject controller : IndustrialSafetySystem::controller;
        
        assert constraint {
            controller.responseTime <= 0.5 [s]
        }
    }
    
    requirement <'REQ-SAFE-004'> emergencyProtection {
        doc /* When critical safety thresholds are exceeded, the system 
             * shall initiate emergency shutdown procedures to prevent 
             * catastrophic failure.
             */
        subject emergencyShutdown : IndustrialSafetySystem::emergencyShutdown;
    }
    
    part industrialSafetySystem : IndustrialSafetySystem {
        attribute :>> systemId = "ISS-MAIN-001";
        attribute :>> operationalStatus = true;
        attribute :>> overallRiskLevel = 0.2;
    }
    
    satisfy primarySafetyFunction by industrialSafetySystem;
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    private import SafetyCriticalSystem::*;

    part testSubject : Sensor {
        exhibit state sm : SafetyStateMachine;
    }

    action orchestrator {
        action issueWarningProbe : TriggerAlarm {
            in alarmLevel = AlarmLevel::none;
            in message = "";
        }
        first issueWarningProbe;
    }
}
