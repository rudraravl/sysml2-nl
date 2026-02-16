package HomeEnergyMonitorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    package Definitions {
        attribute def VoltageValue :> ISQ::VoltageValue;
        attribute def CurrentValue :> ISQ::ElectricCurrentValue;
        attribute def PowerValue :> ISQ::PowerValue;
        attribute def EnergyValue :> ISQ::EnergyValue;
        
        item def ElectricalMeasurement {
            attribute voltage : VoltageValue;
            attribute current : CurrentValue;
            attribute power : PowerValue;
            attribute timestamp : String;
        }
        
        item def EnergyData {
            attribute totalEnergy : EnergyValue;
            attribute averagePower : PowerValue;
            attribute peakPower : PowerValue;
            attribute cost : Real;
        }
        
        item def ThresholdConfig {
            attribute maxPower : PowerValue;
            attribute maxDailyCost : Real;
        }
        
        item def AlertNotification {
            attribute alertType : String;
            attribute powerLevel : PowerValue;
            attribute alertMessage : String;
        }
        
        port def SensingPort {
            in item electricalSignal : ElectricalMeasurement;
        }
        
        port def DataOutputPort {
            out item measurementData : ElectricalMeasurement;
        }
        
        port def DisplayPort {
            in item displayData : EnergyData;
        }
        
        port def AlertOutputPort {
            out item alert : AlertNotification;
        }
        
        action def MeasureElectricalParameters {
            in rawVoltage : VoltageValue;
            in rawCurrent : CurrentValue;
            out measurement : ElectricalMeasurement;
        }
        
        action def ComputePower {
            in voltage : VoltageValue;
            in current : CurrentValue;
            out power : PowerValue;
        }
        
        action def AccumulateEnergy {
            in measurements : ElectricalMeasurement[1..*];
            out energyData : EnergyData;
        }
        
        action def EvaluateThresholds {
            in currentPower : PowerValue;
            in threshold : ThresholdConfig;
            out exceedsThreshold : Boolean;
        }
        
        action def IssueAlert {
            in powerLevel : PowerValue;
            out alert : AlertNotification;
        }
        
        action def UpdateUserDisplay {
            in energyData : EnergyData;
            in currentMeasurement : ElectricalMeasurement;
        }
        
        action def MonitorHomeEnergy {
            in voltageInput : VoltageValue;
            in currentInput : CurrentValue;
            in thresholdSettings : ThresholdConfig;
            out displayData : EnergyData;
            out alert : AlertNotification[0..1];
        }
    }
    
    package Components {
        import Definitions::*;
        
        part def VoltageSensor {
            port sensingPort : SensingPort;
            port dataOut : DataOutputPort;
            attribute accuracy : Real = 0.005;
            attribute range : VoltageValue;
            
            perform action measureVoltage : MeasureElectricalParameters;
        }
        
        part def CurrentSensor {
            port sensingPort : SensingPort;
            port dataOut : DataOutputPort;
            attribute accuracy : Real = 0.01;
            attribute range : CurrentValue;
            
            perform action measureCurrent : MeasureElectricalParameters;
        }
        
        part def ProcessingUnit {
            port dataIn : SensingPort;
            attribute samplingFrequency : Real = 1.0;
            attribute storageCapacity : Integer = 10000;
            
            perform action computePowerUsage : ComputePower;
            perform action aggregateData : AccumulateEnergy;
            perform action checkThresholds : EvaluateThresholds;
        }
        
        part def UserDisplay {
            port displayPort : DisplayPort;
            attribute screenSize : Real = 5.0;
            attribute refreshRate : Real = 1.0;
            
            perform action showEnergyData : UpdateUserDisplay;
        }
        
        part def NotificationModule {
            port alertPort : AlertOutputPort;
            attribute notificationMethod : String = "visual_audio";
            
            perform action sendAlert : IssueAlert;
        }
        
        part def EnergyMonitorDevice {
            attribute deviceID : String;
            attribute operatingVoltage : VoltageValue;
            attribute maxMeasurablePower : PowerValue;
            
            part voltageSensor : VoltageSensor {
                attribute range = 300.0;
            }
            
            part currentSensor : CurrentSensor {
                attribute range = 100.0;
            }
            
            part processor : ProcessingUnit {
                attribute samplingFrequency = 2.0;
            }
            
            part display : UserDisplay {
                attribute screenSize = 7.0;
            }
            
            part notifier : NotificationModule;
            
            connection voltageDataFlow connect voltageSensor.dataOut to processor.dataIn;
            connection currentDataFlow connect currentSensor.dataOut to processor.dataIn;
            
            perform action monitoringOperation : MonitorHomeEnergy;
        }
    }
    
    package Behaviors {
        import Definitions::*;
        
        action monitoringOperation : MonitorHomeEnergy {
            in voltageInput : VoltageValue;
            in currentInput : CurrentValue;
            in thresholdSettings : ThresholdConfig;
            out displayData : EnergyData;
            out alert : AlertNotification[0..1];
            
            first start;
            then merge continuousMonitoring;
            
            then action measureParameters : MeasureElectricalParameters {
                in rawVoltage = monitoringOperation::voltageInput;
                in rawCurrent = monitoringOperation::currentInput;
                out measurement : ElectricalMeasurement;
            }
            
            flow measureParameters.measurement.voltage to calculatePower.voltage;
            flow measureParameters.measurement.current to calculatePower.current;
            
            then action calculatePower : ComputePower {
                in voltage : VoltageValue;
                in current : CurrentValue;
                out power : PowerValue;
            }
            
            then action accumulateEnergy : AccumulateEnergy {
                in measurements : ElectricalMeasurement[1..*];
                out energyData = monitoringOperation::displayData;
            }
            
            then action updateDisplay : UpdateUserDisplay {
                in energyData : EnergyData;
                in currentMeasurement : ElectricalMeasurement;
            }
            
            then action evaluateThresholds : EvaluateThresholds {
                in currentPower : PowerValue;
                in threshold = monitoringOperation::thresholdSettings;
                out exceedsThreshold : Boolean;
            }
            
            then decide;
                if evaluateThresholds.exceedsThreshold then generateAlert;
                else continuousMonitoring;
            
            action generateAlert : IssueAlert {
                in powerLevel = calculatePower.power;
                out alert = monitoringOperation::alert;
            }
            
            then continuousMonitoring;
        }
    }
    
    package Requirements {
        import Components::*;
        
        requirement <'REQ-HEM-001'> continuousMonitoring {
            doc /* The home energy monitor shall continuously measure 
                 * and track real-time electrical energy consumption 
                 * from the household electrical supply.
                 */
            subject monitor : EnergyMonitorDevice;
        }
        
        requirement <'REQ-HEM-002'> measurementAccuracy {
            doc /* The system shall measure voltage and current with 
                 * accuracy sufficient to calculate power consumption 
                 * within 1% error margin.
                 */
            subject monitor : EnergyMonitorDevice;
            
            require constraint {
                monitor.voltageSensor.accuracy <= 0.01 and
                monitor.currentSensor.accuracy <= 0.01
            }
        }
        
        requirement <'REQ-HEM-003'> dataAggregation {
            doc /* The system shall accumulate energy consumption data 
                 * and calculate total energy usage, average power, 
                 * peak power, and estimated cost.
                 */
            subject monitor : EnergyMonitorDevice;
        }
        
        requirement <'REQ-HEM-004'> userFeedback {
            doc /* The system shall display current power consumption, 
                 * accumulated energy usage, and cost information to 
                 * the user in real-time.
                 */
            subject monitor : EnergyMonitorDevice;
        }
        
        requirement <'REQ-HEM-005'> thresholdAlerts {
            doc /* The system shall generate alerts when power consumption 
                 * exceeds user-configurable threshold levels.
                 */
            subject monitor : EnergyMonitorDevice;
        }
        
        requirement <'REQ-HEM-006'> samplingRate {
            doc /* The system shall sample electrical parameters at 
                 * a minimum rate of 1 Hz to ensure accurate energy 
                 * consumption tracking.
                 */
            subject monitor : EnergyMonitorDevice;
            
            require constraint {
                monitor.processor.samplingFrequency >= 1.0
            }
        }
    }
    
    package SystemArchitecture {
        import Components::*;
        import Definitions::*;
        import Requirements::*;
        
        part homeEnergyMonitor : EnergyMonitorDevice {
            attribute deviceID = "HEM-2024-001";
            attribute operatingVoltage = 120.0;
            attribute maxMeasurablePower = 10000.0;
            
            part voltageSensor : VoltageSensor {
                attribute accuracy = 0.005;
                attribute range = 300.0;
            }
            
            part currentSensor : CurrentSensor {
                attribute accuracy = 0.008;
                attribute range = 100.0;
            }
            
            part processor : ProcessingUnit {
                attribute samplingFrequency = 2.0;
                attribute storageCapacity = 20000;
            }
            
            part display : UserDisplay {
                attribute screenSize = 7.0;
                attribute refreshRate = 1.0;
            }
            
            part notifier : NotificationModule {
                attribute notificationMethod = "visual_audio";
            }
        }
        
        satisfy continuousMonitoring by homeEnergyMonitor;
        satisfy measurementAccuracy by homeEnergyMonitor;
        satisfy dataAggregation by homeEnergyMonitor;
        satisfy userFeedback by homeEnergyMonitor;
        satisfy thresholdAlerts by homeEnergyMonitor;
        satisfy samplingRate by homeEnergyMonitor;
    }
    
    package OperationalScenario {
        import SystemArchitecture::*;
        import Definitions::*;
        import Behaviors::*;
        
        action operateEnergyMonitor {
            ref part monitor :>> homeEnergyMonitor;
            
            first action configureThresholds {
                out thresholdConfig : ThresholdConfig {
                    attribute maxPower = 8000.0;
                    attribute maxDailyCost = 15.0;
                }
            }
            
            then action normalOperation {
                loop {
                    action monitorCycle : monitoringOperation {
                        in voltageInput : VoltageValue = 120.0;
                        in currentInput : CurrentValue = 25.0;
                        in thresholdSettings = configureThresholds.thresholdConfig;
                        out displayData : EnergyData;
                        out alert : AlertNotification[0..1];
                    }
                }
            }
        }
    }
}
