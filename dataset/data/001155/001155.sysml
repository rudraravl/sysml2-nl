package NeutronDetectionSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def NeutronCountRate :> Real;
    attribute def NeutronEnergy :> EnergyValue;
    attribute def DetectorEfficiency :> Real;
    attribute def SignalAmplitude :> Real;
    attribute def ThresholdLevel :> Real;
    attribute def NeutronFluxValue :> Real;
    
    enum def DetectorState {
        idle;
        monitoring;
        alarming;
        calibrating;
    }
    
    enum def AlarmLevel {
        normal;
        caution;
        warning;
        critical;
    }
    
    item def Neutron {
        attribute energy : NeutronEnergy;
        attribute velocity : SpeedValue;
    }
    
    item def ElectricalPulse {
        attribute amplitude : SignalAmplitude;
        attribute timestamp : TimeInstantValue;
    }
    
    item def CountData {
        attribute countRate : NeutronCountRate;
        attribute totalCounts : Real;
        attribute timestamp : TimeInstantValue;
    }
    
    port def NeutronInputPort {
        in item neutronFlux : Neutron[*];
    }
    
    port def PulseOutputPort {
        out item pulse : ElectricalPulse;
    }
    
    port def DataOutputPort {
        out item data : CountData;
    }
    
    port def AlarmOutputPort {
        out attribute alarmStatus : AlarmLevel;
    }
    
    port def ControlInputPort {
        in attribute enable : Boolean;
        in attribute threshold : ThresholdLevel;
    }
    
    part def DetectorTube {
        doc /* Gas-filled proportional counter that converts neutron interactions into electrical pulses */
        
        attribute efficiency : DetectorEfficiency = 0.30;
        attribute activeVolume : VolumeValue = 150.0 [SI::cm^3];
        attribute gasPressure : PressureValue = 5.0e5 [SI::Pa];
        attribute operatingVoltage : Real = 1500.0;
        
        port neutronIn : NeutronInputPort;
        port pulseOut : PulseOutputPort;
        
        perform action detectNeutron {
            in neutron : Neutron;
            out pulse : ElectricalPulse;
            
            first start;
            then action moderateNeutron {
                doc /* Slow down fast neutrons to thermal energies */
            }
            then action interactWithGas {
                doc /* Neutron interacts with detector gas producing ionization */
            }
            then action generateCharge {
                doc /* Ionization produces charge carriers */
            }
            then action amplifyCharge {
                doc /* Gas multiplication amplifies the charge signal */
            }
            then action outputPulse {
                out pulseSignal = pulse;
            }
            then done;
        }
    }
    
    part def SignalProcessor {
        doc /* Processes detector pulses, discriminates noise, and counts valid events */
        
        attribute amplificationGain : Real = 50.0;
        attribute discriminatorThreshold : ThresholdLevel = 0.5;
        attribute noiseLevel : SignalAmplitude = 0.05;
        
        port pulseIn : PulseOutputPort;
        port dataOut : DataOutputPort;
        
        perform action processSignal {
            in rawPulse : ElectricalPulse;
            out validEvent : Boolean;
            
            first start;
            then action preamplify {
                doc /* Initial amplification of detector signal */
            }
            then action shapeSignal {
                doc /* Shape pulse for optimal signal-to-noise ratio */
            }
            then action discriminate {
                out aboveThreshold : Boolean;
            }
            then decide;
                if discriminate.aboveThreshold then acceptEvent;
                if not discriminate.aboveThreshold then rejectEvent;
            action acceptEvent {
                out validEvent = true;
            }
            then merge complete;
            action rejectEvent {
                out validEvent = false;
            }
            then complete;
            then done;
        }
    }
    
    part def CountRateMonitor {
        doc /* Calculates neutron count rate and maintains statistics */
        
        attribute integrationTime : TimeValue = 1.0 [SI::s];
        attribute currentCountRate : NeutronCountRate = 0.0;
        attribute totalCounts : Real = 0.0;
        attribute averageCountRate : NeutronCountRate = 0.0;
        
        port dataIn : DataOutputPort;
        port dataOut : DataOutputPort;
        
        perform action calculateCountRate {
            first start;
            then merge continuousMonitoring;
            then action collectCounts {
                out eventCount : Real;
            }
            then action computeRate {
                in eventCount : Real;
                in timeWindow : TimeValue;
                out countRate : NeutronCountRate;
            }
            then action updateStatistics {
                doc /* Update running average and total counts */
            }
            then action outputData {
                out data : CountData;
            }
            then continuousMonitoring;
        }
    }
    
    part def AlarmController {
        doc /* Monitors count rate and activates alarms when thresholds are exceeded */
        
        attribute cautionThreshold : NeutronCountRate = 1000.0;
        attribute warningThreshold : NeutronCountRate = 5000.0;
        attribute criticalThreshold : NeutronCountRate = 10000.0;
        attribute currentAlarmLevel : AlarmLevel = AlarmLevel::normal;
        
        port dataIn : DataOutputPort;
        port alarmOut : AlarmOutputPort;
        port controlIn : ControlInputPort;
        
        perform action monitorAndAlarm {
            in countRate : NeutronCountRate;
            out alarmLevel : AlarmLevel;
            
            first start;
            then merge checkLoop;
            then action readCountRate {
                out currentRate : NeutronCountRate;
            }
            then action evaluateLevel {
                in rate : NeutronCountRate;
                out level : AlarmLevel;
            }
            then decide;
                if evaluateLevel.level == AlarmLevel::critical then activateCritical;
                if evaluateLevel.level == AlarmLevel::warning then activateWarning;
                if evaluateLevel.level == AlarmLevel::caution then activateCaution;
                else activateNormal;
            action activateCritical {
                doc /* Activate critical alarm - immediate action required */
            }
            then merge checkLoop;
            action activateWarning {
                doc /* Activate warning alarm - elevated radiation levels */
            }
            then checkLoop;
            action activateCaution {
                doc /* Activate caution alarm - above normal levels */
            }
            then checkLoop;
            action activateNormal {
                doc /* Normal operation - no alarm */
            }
            then checkLoop;
        }
    }
    
    part def DisplayUnit {
        doc /* Displays count rate, total counts, and alarm status to operators */
        
        attribute displayUpdateRate : FrequencyValue = 2.0 [SI::Hz];
        
        port dataIn : DataOutputPort;
        port alarmIn : AlarmOutputPort;
    }
    
    part def PowerSupply {
        doc /* Provides regulated high voltage for detector and low voltage for electronics */
        
        attribute highVoltageOutput : Real = 1500.0;
        attribute lowVoltageOutput : Real = 12.0;
        attribute outputStability : Real = 0.01;
        attribute efficiency : Real = 0.88;
    }
    
    part neutronDetectionSystem {
        doc /* 
         * Neutron detection system for continuous monitoring of neutron radiation.
         * The system detects neutrons, measures count rates, and provides alarm
         * indication when radiation levels exceed safety thresholds.
         */
        
        attribute systemEfficiency : DetectorEfficiency = 0.30;
        attribute maxCountRate : NeutronCountRate = 100000.0;
        attribute systemState : DetectorState = DetectorState::idle;
        
        part detector : DetectorTube {
            attribute :>> efficiency = 0.30;
            attribute :>> activeVolume = 150.0 [SI::cm^3];
            attribute :>> gasPressure = 5.0e5 [SI::Pa];
            attribute :>> operatingVoltage = 1500.0;
        }
        
        part processor : SignalProcessor {
            attribute :>> amplificationGain = 50.0;
            attribute :>> discriminatorThreshold = 0.5;
            attribute :>> noiseLevel = 0.05;
        }
        
        part monitor : CountRateMonitor {
            attribute :>> integrationTime = 1.0 [SI::s];
            attribute :>> currentCountRate = 0.0;
            attribute :>> totalCounts = 0.0;
        }
        
        part alarmController : AlarmController {
            attribute :>> cautionThreshold = 1000.0;
            attribute :>> warningThreshold = 5000.0;
            attribute :>> criticalThreshold = 10000.0;
            attribute :>> currentAlarmLevel = AlarmLevel::normal;
        }
        
        part display : DisplayUnit {
            attribute :>> displayUpdateRate = 2.0 [SI::Hz];
        }
        
        part powerSupply : PowerSupply {
            attribute :>> highVoltageOutput = 1500.0;
            attribute :>> lowVoltageOutput = 12.0;
            attribute :>> outputStability = 0.01;
            attribute :>> efficiency = 0.88;
        }
        
        connection detectorToProcessor connect 
            detector.pulseOut to processor.pulseIn;
        
        connection processorToMonitor connect 
            processor.dataOut to monitor.dataIn;
        
        connection monitorToAlarm connect 
            monitor.dataOut to alarmController.dataIn;
        
        connection monitorToDisplay connect 
            monitor.dataOut to display.dataIn;
        
        connection alarmToDisplay connect 
            alarmController.alarmOut to display.alarmIn;
        
        perform action detectAndMonitorNeutrons {
            doc /* 
             * Primary system function: continuously detect neutrons, measure radiation levels,
             * and provide alarm indication when safety thresholds are exceeded.
             */
            
            first start;
            then merge operationalLoop;
            then action captureNeutrons {
                doc /* Detector tube captures incoming neutron flux */
            }
            then action convertToSignal {
                doc /* Convert neutron interactions to electrical pulses */
            }
            then action processSignals {
                doc /* Amplify, shape, and discriminate valid pulses */
            }
            then action countEvents {
                doc /* Count valid neutron detection events */
            }
            then action calculateRate {
                doc /* Calculate neutron count rate over integration window */
            }
            then action updateDisplay {
                doc /* Update operator display with current measurements */
            }
            then action evaluateAlarms {
                out alarmRequired : Boolean;
            }
            then decide;
                if evaluateAlarms.alarmRequired then activateAlarm;
                if not evaluateAlarms.alarmRequired then continueMonitoring;
            action activateAlarm {
                doc /* Alert operators to elevated neutron radiation levels */
            }
            then merge operationalLoop;
            action continueMonitoring {
                doc /* Continue normal monitoring operation */
            }
            then operationalLoop;
        }
    }
    
    state machine systemStateMachine {
        initial state Idle;
        
        state Idle {
            entry action powerOn;
        }
        
        state Monitoring {
            entry action startDetection;
            do action detectAndMonitorNeutrons;
        }
        
        state Alarming {
            entry action activateAlarms;
            do action continueMonitoring;
        }
        
        state Calibrating {
            entry action enterCalibrationMode;
        }
        
        transition Idle to Monitoring;
        transition Monitoring to Alarming;
        transition Alarming to Monitoring;
        transition Monitoring to Calibrating;
        transition Calibrating to Monitoring;
        transition Monitoring to Idle;
    }
    
    requirement <'REQ-NDS-001'> primaryFunction {
        doc /* 
         * The neutron detection system shall continuously detect neutrons,
         * measure neutron count rates, and provide alarm indication when
         * radiation levels exceed configurable safety thresholds.
         */
        subject system :> neutronDetectionSystem;
    }
    
    requirement <'REQ-NDS-002'> detectionEfficiency {
        doc /* 
         * The system shall detect thermal neutrons with a minimum
         * efficiency of 25%.
         */
        subject det :> neutronDetectionSystem.detector;
        
        require constraint {
            det.efficiency >= 0.25
        }
    }
    
    requirement <'REQ-NDS-003'> countRateCapability {
        doc /* 
         * The system shall measure neutron count rates up to
         * 100,000 counts per second without saturation.
         */
        subject sys :> neutronDetectionSystem;
        
        require constraint {
            sys.maxCountRate >= 100000.0
        }
    }
    
    requirement <'REQ-NDS-004'> alarmResponse {
        doc /* 
         * The system shall activate alarm indication within 2 seconds
         * when measured count rate exceeds configured threshold levels.
         */
        subject alarm :> neutronDetectionSystem.alarmController;
    }
    
    requirement <'REQ-NDS-005'> continuousOperation {
        doc /* 
         * The system shall operate continuously in real-time to provide
         * uninterrupted monitoring of neutron radiation levels.
         */
        subject sys :> neutronDetectionSystem;
    }
    
    requirement <'REQ-NDS-006'> powerStability {
        doc /* 
         * The high voltage power supply shall maintain output voltage
         * stability within ±1% to ensure consistent detector performance.
         */
        subject ps :> neutronDetectionSystem.powerSupply;
        
        require constraint {
            ps.outputStability <= 0.01
        }
    }
    
    satisfy primaryFunction by neutronDetectionSystem;
    satisfy detectionEfficiency by neutronDetectionSystem.detector;
    satisfy countRateCapability by neutronDetectionSystem;
    satisfy alarmResponse by neutronDetectionSystem.alarmController;
    satisfy continuousOperation by neutronDetectionSystem;
    satisfy powerStability by neutronDetectionSystem.powerSupply;
}
