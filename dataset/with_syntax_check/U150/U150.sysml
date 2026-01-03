package AtelectotraumaPreventionSystem {
    private import ISQ::*;
    private import ScalarValues::*;
    
    attribute def PressureValue :> ISQ::PressureValue;
    attribute def VolumeValue :> ISQ::VolumeValue;
    attribute def FlowRateValue :> ISQ::VolumeFlowRateValue;
    attribute def TimeValue :> ISQ::TimeValue;
    attribute def FrequencyValue :> ISQ::FrequencyValue;
    
    item def PressureReading {
        attribute airwayPressure : PressureValue;
        attribute alveolarPressure : PressureValue;
        attribute timestamp : TimeValue;
    }
    
    item def VolumeReading {
        attribute tidalVolume : VolumeValue;
        attribute functionalResidualCapacity : VolumeValue;
        attribute timestamp : TimeValue;
    }
    
    item def VentilatorCommand {
        attribute targetPEEP : PressureValue;
        attribute targetPIP : PressureValue;
        attribute targetRate : FrequencyValue;
        attribute targetTidalVolume : VolumeValue;
    }
    
    item def AlarmSignal {
        attribute alarmType : String;
        attribute severity : String;
        attribute timestamp : TimeValue;
    }
    
    part def PressureSensor {
        out port pressureOutput : PressureReading;
    }
    
    part def VolumeSensor {
        out port volumeOutput : VolumeReading;
    }
    
    part def VentilatorActuator {
        in port commandInput : VentilatorCommand;
        out port gasDelivery : FlowRateValue;
    }
    
    part def AlarmSystem {
        in port alarmInput : AlarmSignal;
        out port alarmOutput : AlarmSignal;
    }
    
    part def ControlProcessor {
        in port pressureInput : PressureReading;
        in port volumeInput : VolumeReading;
        out port ventilatorOutput : VentilatorCommand;
        out port alarmOutput : AlarmSignal;
        
        attribute targetPEEP : PressureValue;
        attribute maxPIP : PressureValue;
        attribute minTidalVolume : VolumeValue;
        attribute maxTidalVolume : VolumeValue;
    }
    
    part def PatientLung {
        in port gasInput : FlowRateValue;
        out port pressureMonitor : PressureReading;
        out port volumeMonitor : VolumeReading;
        
        attribute compliance : Real;
        attribute resistance : Real;
    }
    
    part def AtelectotraumaPreventionVentilator {
        doc /*
         * A mechanical ventilation system designed to prevent atelectotrauma,
         * which is lung injury caused by repetitive opening and closing of
         * collapsed alveoli. The system maintains optimal positive end-expiratory
         * pressure (PEEP) to keep alveoli open throughout the respiratory cycle,
         * preventing cyclical collapse and re-expansion that damages lung tissue.
         */
        
        part pressureSensor : PressureSensor;
        part volumeSensor : VolumeSensor;
        part controller : ControlProcessor {
            :>> targetPEEP = 8.0;
            :>> maxPIP = 30.0;
            :>> minTidalVolume = 300.0;
            :>> maxTidalVolume = 500.0;
        }
        part ventilatorActuator : VentilatorActuator;
        part alarmSystem : AlarmSystem;
        part lung : PatientLung;
        
        interface pressureSensorConnection connect pressureSensor.pressureOutput to controller.pressureInput;
        interface volumeSensorConnection connect volumeSensor.volumeOutput to controller.volumeInput;
        interface ventilatorCommandConnection connect controller.ventilatorOutput to ventilatorActuator.commandInput;
        interface alarmConnection connect controller.alarmOutput to alarmSystem.alarmInput;
        interface gasDeliveryConnection connect ventilatorActuator.gasDelivery to lung.gasInput;
        interface lungPressureConnection connect lung.pressureMonitor to pressureSensor.pressureOutput;
        interface lungVolumeConnection connect lung.volumeMonitor to volumeSensor.volumeOutput;
        
        perform action maintainAlveolarRecruitment;
    }
    
    action def MonitorLungMechanics {
        in pressureData : PressureReading;
        in volumeData : VolumeReading;
        out alveolarStatus : String;
        out recruitmentNeeded : Boolean;
    }
    
    action def CalculateOptimalPEEP {
        in currentPressure : PressureValue;
        in currentVolume : VolumeValue;
        in alveolarStatus : String;
        out optimalPEEP : PressureValue;
    }
    
    action def AdjustVentilatorSettings {
        in optimalPEEP : PressureValue;
        in currentSettings : VentilatorCommand;
        out newSettings : VentilatorCommand;
    }
    
    action def DetectAtelectotrauma {
        in pressureData : PressureReading;
        in volumeData : VolumeReading;
        out atelectotraumaRisk : Real;
        out alarmRequired : Boolean;
    }
    
    action def TriggerAlarm {
        in alarmType : String;
        in severity : String;
        out alarm : AlarmSignal;
    }
    
    action def maintainAlveolarRecruitment {
        doc /*
         * Primary function: Continuously monitor lung mechanics and adjust
         * ventilator settings to maintain adequate PEEP, preventing alveolar
         * collapse. The system operates in a closed-loop feedback cycle,
         * measuring airway pressure and lung volume, calculating optimal
         * ventilation parameters, and adjusting gas delivery to keep alveoli
         * recruited throughout the breathing cycle.
         */
        
        first start;
        then merge continuousMonitoring;
        
        action monitor : MonitorLungMechanics {
            in pressureData : PressureReading;
            in volumeData : VolumeReading;
            out alveolarStatus : String;
            out recruitmentNeeded : Boolean;
        }
        
        then action detectRisk : DetectAtelectotrauma {
            in pressureData = monitor.pressureData;
            in volumeData = monitor.volumeData;
            out atelectotraumaRisk : Real;
            out alarmRequired : Boolean;
        }
        
        then decide;
            if detectRisk.alarmRequired then triggerAlarm;
            if detectRisk.atelectotraumaRisk > 0.7 then adjustSettings;
            if detectRisk.atelectotraumaRisk <= 0.7 then continuousMonitoring;
        
        action triggerAlarm : TriggerAlarm {
            in alarmType = "Atelectotrauma Risk";
            in severity = "High";
            out alarm : AlarmSignal;
        }
        then adjustSettings;
        
        action adjustSettings {
            action calculatePEEP : CalculateOptimalPEEP {
                in currentPressure : PressureValue;
                in currentVolume : VolumeValue;
                in alveolarStatus = monitor.alveolarStatus;
                out optimalPEEP : PressureValue;
            }
            
            then action adjust : AdjustVentilatorSettings {
                in optimalPEEP = calculatePEEP.optimalPEEP;
                in currentSettings : VentilatorCommand;
                out newSettings : VentilatorCommand;
            }
        }
        then continuousMonitoring;
    }
    
    attribute def PressureReachedSignal;
    attribute def VolumeExpiredSignal;
    attribute def BreathCycleCompleteSignal;
    attribute def AtelectotraumaDetectedSignal;
    attribute def ConditionResolvedSignal;
    
    state def VentilationState {
        entry; then idle;
        
        state idle {
            doc /* Ventilator is ready but not actively ventilating */
        }
        
        state inspiration {
            doc /* Delivering positive pressure breath */
        }
        
        state expiration {
            doc /* Allowing passive exhalation with PEEP maintained */
        }
        
        state peepMaintenance {
            doc /* Actively maintaining PEEP to prevent alveolar collapse */
        }
        
        state alarm {
            doc /* Critical condition detected requiring intervention */
        }
        
        transition idle_to_inspiration
            first idle
            accept VentilatorCommand
            then inspiration;
        
        transition inspiration_to_expiration
            first inspiration
            accept PressureReachedSignal
            then expiration;
        
        transition expiration_to_peep
            first expiration
            accept VolumeExpiredSignal
            then peepMaintenance;
        
        transition peep_to_inspiration
            first peepMaintenance
            accept BreathCycleCompleteSignal
            then inspiration;
        
        transition any_to_alarm
            first inspiration
            accept AtelectotraumaDetectedSignal
            then alarm;
        
        transition alarm_to_peep
            first alarm
            accept ConditionResolvedSignal
            then peepMaintenance;
    }
    
    requirement def FunctionalRequirement;
    requirement def SafetyRequirement;
    requirement def PerformanceRequirement;
    
    requirement <'FR-001'> preventAlveolarCollapse : FunctionalRequirement {
        doc /*
         * The system shall maintain positive end-expiratory pressure (PEEP)
         * between 5 and 15 cmH2O to prevent alveolar collapse during the
         * expiratory phase of mechanical ventilation.
         */
        subject ventilator : AtelectotraumaPreventionVentilator;
    }
    
    requirement <'FR-002'> continuousMonitoring : FunctionalRequirement {
        doc /*
         * The system shall continuously monitor airway pressure and lung
         * volume at a minimum frequency of 100 Hz to detect early signs
         * of alveolar derecruitment.
         */
        subject ventilator : AtelectotraumaPreventionVentilator;
    }
    
    requirement <'SR-001'> pressureLimit : SafetyRequirement {
        doc /*
         * The system shall limit peak inspiratory pressure to a maximum
         * of 35 cmH2O to prevent barotrauma while maintaining adequate
         * alveolar recruitment.
         */
        subject ventilator : AtelectotraumaPreventionVentilator;
    }
    
    requirement <'SR-002'> alarmResponse : SafetyRequirement {
        doc /*
         * The system shall trigger an audible and visual alarm within
         * 500 milliseconds when atelectotrauma risk exceeds threshold
         * or when PEEP falls below minimum safe level.
         */
        subject ventilator : AtelectotraumaPreventionVentilator;
    }
    
    requirement <'PR-001'> responseTime : PerformanceRequirement {
        doc /*
         * The system shall adjust ventilator settings within 2 seconds
         * of detecting suboptimal alveolar recruitment to minimize
         * duration of harmful ventilation patterns.
         */
        subject ventilator : AtelectotraumaPreventionVentilator;
    }
    
    requirement <'SYS-001'> atelectotraumaPrevention {
        doc /*
         * The atelectotrauma prevention system shall protect lung tissue
         * from injury caused by repetitive alveolar collapse and re-expansion
         * by maintaining optimal PEEP and monitoring lung mechanics.
         */
        
        require preventAlveolarCollapse;
        require continuousMonitoring;
        require pressureLimit;
        require alarmResponse;
        require responseTime;
    }
}
