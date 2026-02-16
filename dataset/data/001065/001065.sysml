package 'Gas Detector System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    doc /* 
        This model specifies a gas detector system designed to continuously monitor 
        ambient air for hazardous gas concentrations and activate alarms when safety 
        thresholds are exceeded. The system integrates sensing, processing, alarming, 
        and communication capabilities to ensure personnel safety in industrial environments.
    */
    
    attribute def GasConcentration :> Real {
        doc /* Gas concentration measured in parts per million (ppm) */
    }
    
    attribute def ThresholdLevel {
        attribute value : GasConcentration;
        attribute severity : AlarmSeverity;
    }
    
    enum def AlarmSeverity {
        none;
        warning;
        danger;
        critical;
    }
    
    enum def SystemState {
        initializing;
        monitoring;
        alarming;
        fault;
    }
    
    attribute def SensorReading {
        attribute concentration : GasConcentration;
        attribute timestamp : ISQ::DurationValue;
        attribute valid : Boolean;
    }
    
    port def SensorDataPort {
        out reading : SensorReading;
    }
    
    port def AlarmSignalPort {
        out audioActive : Boolean;
        out visualActive : Boolean;
        out severity : AlarmSeverity;
    }
    
    port def PowerPort {
        in voltage : ISQ::EnergyValue;
    }
    
    port def DiagnosticPort {
        out status : SystemState;
        out message : String;
    }
    
    part def ChemicalSensor {
        attribute sensorType : String;
        attribute detectionRange : GasConcentration[2];
        attribute responseTime : ISQ::DurationValue;
        
        port dataOutput : SensorDataPort;
        
        action def MeasureGas {
            out measurement : SensorReading;
        }
        
        perform action continuousSensing : MeasureGas;
    }
    
    part def SignalProcessor {
        attribute filteringEnabled : Boolean;
        attribute calibrationFactor : Real;
        
        port sensorInput : ~SensorDataPort;
        
        action def ProcessSignal {
            in rawReading : SensorReading;
            out processedConcentration : GasConcentration;
            out isValid : Boolean;
        }
        
        action def ValidateReading {
            in reading : SensorReading;
            out valid : Boolean;
            
            then decide;
                if reading.concentration >= 0.0 then action checkUpper {
                    decide;
                        if reading.concentration <= 1000.0 then assign valid := true;
                        else assign valid := false;
                }
                else assign valid := false;
        }
    }
    
    part def AlarmUnit {
        attribute thresholds : ThresholdLevel[3] := (
            ThresholdLevel(value = 50.0, severity = AlarmSeverity::warning),
            ThresholdLevel(value = 100.0, severity = AlarmSeverity::danger),
            ThresholdLevel(value = 200.0, severity = AlarmSeverity::critical)
        );
        
        port alarmOutput : AlarmSignalPort;
        
        action def DetermineAlarmLevel {
            in concentration : GasConcentration;
            out level : AlarmSeverity;
            
            then decide;
                if concentration >= 200.0 then assign level := AlarmSeverity::critical;
                if concentration >= 100.0 then action checkDanger {
                    decide;
                        if concentration < 200.0 then assign level := AlarmSeverity::danger;
                }
                if concentration >= 50.0 then action checkWarning {
                    decide;
                        if concentration < 100.0 then assign level := AlarmSeverity::warning;
                }
                else assign level := AlarmSeverity::none;
        }
        
        action def ActivateAlarm {
            in severity : AlarmSeverity;
            out audio : Boolean;
            out visual : Boolean;
            
            then decide;
                if severity == AlarmSeverity::none then action setOff {
                    assign audio := false;
                    then assign visual := false;
                }
                if severity == AlarmSeverity::warning then action setWarning {
                    assign audio := false;
                    then assign visual := true;
                }
                if severity == AlarmSeverity::danger then action setDanger {
                    assign audio := true;
                    then assign visual := true;
                }
                if severity == AlarmSeverity::critical then action setCritical {
                    assign audio := true;
                    then assign visual := true;
                }
        }
    }
    
    part def DataLogger {
        attribute logCapacity : Integer;
        attribute recordInterval : ISQ::DurationValue;
        
        action def RecordData {
            in reading : SensorReading;
            in alarmState : AlarmSeverity;
        }
    }
    
    part def PowerSupply {
        attribute inputVoltage : ISQ::EnergyValue;
        attribute outputVoltage : ISQ::EnergyValue;
        
        port powerOut : PowerPort;
        
        action def RegulatePower {
            in inputV : ISQ::EnergyValue;
            out outputV : ISQ::EnergyValue;
        }
    }
    
    state def GasDetectorStateMachine {
        entry; then initialization;
        
        state initialization {
            entry action performSelfTest;
        }
        then operational;
        
        state operational {
            state monitoring {
                entry action startMonitoring;
                do action continuousMonitor;
            }
            
            accept when gasConcentration >= 50.0
            then alarming;
            
            state alarming {
                entry action activateAlarms;
                do action maintainAlarm;
            }
            
            accept when gasConcentration < 45.0
            then monitoring;
        }
        
        accept FaultDetected
        then faultState;
        
        state faultState {
            entry action reportFault;
        }
        
        accept FaultCleared
        then initialization;
    }
    
    action def MonitorAndAlarm {
        in samplingInterval : ISQ::DurationValue;
        out currentConcentration : GasConcentration;
        out alarmStatus : AlarmSeverity;
        
        first start;
        then merge monitoringLoop;
        
        then action measureCycle {
            action sense {
                out reading : SensorReading;
            }
            
            then action process {
                action validate {
                    in reading = sense.reading;
                    out isValid : Boolean;
                }
                
                action filter {
                    in reading = sense.reading;
                    out concentration : GasConcentration;
                }
            }
            
            then decide;
                if process.validate.isValid then evaluateAlarm;
                else logFault;
            
            action evaluateAlarm {
                action determineLevel {
                    in concentration = process.filter.concentration;
                    out severity : AlarmSeverity;
                }
                
                then action activate {
                    in severity = determineLevel.severity;
                    out audioOn : Boolean;
                    out visualOn : Boolean;
                }
            }
            then logData;
            
            action logFault;
            then logData;
            
            action logData {
                in reading = sense.reading;
                in alarmLevel = evaluateAlarm.determineLevel.severity;
            }
        }
        then monitoringLoop;
    }
    
    part def GasDetectorSystem;
    
    part gasDetectorSystem : GasDetectorSystem {
        doc /* 
            Complete gas detector system that monitors ambient air for hazardous gases,
            processes sensor data, evaluates alarm conditions, and activates warnings
            to protect personnel and facilities from gas-related hazards.
        */
        
        part sensor : ChemicalSensor {
            attribute :>> sensorType = "Electrochemical";
            attribute :>> detectionRange = (0.0, 500.0);
            attribute :>> responseTime = 30.0 [SI::s];
        }
        
        part processor : SignalProcessor {
            attribute :>> filteringEnabled = true;
            attribute :>> calibrationFactor = 1.0;
        }
        
        part alarm : AlarmUnit;
        
        part logger : DataLogger {
            attribute :>> logCapacity = 10000;
            attribute :>> recordInterval = 60.0 [SI::s];
        }
        
        part power : PowerSupply {
            attribute :>> inputVoltage = 24.0 [SI::J];
            attribute :>> outputVoltage = 5.0 [SI::J];
        }
        
        connect sensor.dataOutput to processor.sensorInput;
        
        perform action detectAndAlarm : MonitorAndAlarm {
            in samplingInterval : ISQ::DurationValue = 1.0 [SI::s];
            out currentConcentration : GasConcentration;
            out alarmStatus : AlarmSeverity;
        }
        
        exhibit state systemBehavior : GasDetectorStateMachine;
    }
    
    requirement def SafetyRequirement {
        doc /* Base requirement for gas detector safety specifications */
        subject system : GasDetectorSystem;
    }
    
    requirement <'REQ-001'> detectionAccuracy : SafetyRequirement {
        doc /* 
            The gas detector shall measure gas concentration with accuracy 
            within ±5% of reading or ±5 ppm, whichever is greater.
        */
    }
    
    requirement <'REQ-002'> responseTime : SafetyRequirement {
        doc /* 
            The gas detector shall respond to gas concentration changes 
            within 30 seconds (T90 response time).
        */
        require constraint {
            gasDetectorSystem.sensor.responseTime <= 30.0 [SI::s]
        }
    }
    
    requirement <'REQ-003'> alarmActivation : SafetyRequirement {
        doc /* 
            The gas detector shall activate alarms when concentration 
            exceeds 50 ppm (warning threshold).
        */
    }
    
    requirement <'REQ-004'> continuousOperation : SafetyRequirement {
        doc /* 
            The gas detector shall operate continuously without 
            interruption for minimum 24 months.
        */
    }
    
    requirement <'REQ-005'> dataLogging : SafetyRequirement {
        doc /* 
            The gas detector shall log readings and alarm events 
            at intervals not exceeding 60 seconds.
        */
        require constraint {
            gasDetectorSystem.logger.recordInterval <= 60.0 [SI::s]
        }
    }
    
    requirement primaryFunction {
        doc /* 
            The gas detector system shall continuously monitor ambient air for 
            hazardous gas concentrations and activate audible and visual alarms 
            when safety thresholds are exceeded, ensuring timely warning to 
            personnel and enabling emergency response procedures.
        */
        
        assume constraint operatingConditions {
            doc /* 
                Temperature: -20°C to +50°C
                Humidity: 0-95% RH non-condensing
                Pressure: 80-120 kPa
            */
        }
        
        require detectionAccuracy;
        require responseTime;
        require alarmActivation;
        require continuousOperation;
        require dataLogging;
    }
}
