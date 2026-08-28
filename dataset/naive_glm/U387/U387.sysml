package INVOS_Cerebral_Oximeter {
    package ValueTypes {
        value type Wavelength :> Real {
            unit nm;
        }
        value type OxygenSaturation :> Real {
            unit '%';
            constraint { 0 <= self and self <= 100 }
        }
        value type LightIntensity :> Real {
            unit 'cd/m^2';
        }
        value type Voltage :> Real {
            unit V;
        }
        value type Power :> Real {
            unit W;
        }
        value type Duration :> Real {
            unit s;
        }
        value type Frequency :> Real {
            unit Hz;
        }
        value type Temperature :> Real {
            unit 'degC';
        }
        
        item def NearInfraredLight {
            attribute wavelength : Wavelength;
            attribute intensity : LightIntensity;
        }
        
        item def PhotodetectorSignal {
            attribute measuredIntensity : LightIntensity;
            attribute wavelength : Wavelength;
            attribute timestamp : Duration;
        }
        
        item def OxygenSaturationReading {
            attribute rSO2 : OxygenSaturation;
            attribute side : String;
            attribute timestamp : Duration;
        }
        
        item def TrendData {
            attribute readings : OxygenSaturationReading[0..*];
            attribute durationWindow : Duration;
        }
        
        item def AlarmEvent {
            attribute severity : String;
            attribute side : String;
            attribute rSO2 : OxygenSaturation;
            attribute timestamp : Duration;
        }
        
        item def PowerStatus {
            attribute source : String;
            attribute batteryLevel : Real;
            attribute onBattery : Boolean;
        }
    }
    
    package Interfaces {
        port def OpticalOutputPort {
            out light : NearInfraredLight;
        }
        
        port def OpticalInputPort {
            in detectedLight : NearInfraredLight;
        }
        
        port def SignalOutputPort {
            out signal : PhotodetectorSignal;
        }
        
        port def SignalInputPort {
            in signal : PhotodetectorSignal;
        }
        
        port def DataOutputPort {
            out reading : OxygenSaturationReading;
            out trend : TrendData;
        }
        
        port def DataInputPort {
            in reading : OxygenSaturationReading;
            in trend : TrendData;
        }
        
        port def AlarmOutputPort {
            out alarm : AlarmEvent;
        }
        
        port def AlarmInputPort {
            in alarm : AlarmEvent;
        }
        
        port def PowerOutputPort {
            out voltage : Voltage;
            out status : PowerStatus;
        }
        
        port def PowerInputPort {
            in voltage : Voltage;
            in status : PowerStatus;
        }
        
        interface def OpticalInterface {
            end source : OpticalOutputPort;
            end detector : OpticalInputPort;
        }
        
        interface def SignalInterface {
            end source : SignalOutputPort;
            end destination : SignalInputPort;
        }
        
        interface def DataInterface {
            end source : DataOutputPort;
            end destination : DataInputPort;
        }
        
        interface def AlarmInterface {
            end source : AlarmOutputPort;
            end destination : AlarmInputPort;
        }
        
        interface def PowerInterface {
            end source : PowerOutputPort;
            end destination : PowerInputPort;
        }
    }
    
    package Components {
        part def LightEmitter {
            attribute nominalWavelength1 : Wavelength = 730 [nm];
            attribute nominalWavelength2 : Wavelength = 810 [nm];
            attribute driveVoltage : Voltage = 3.3 [V];
            port opticalOut : OpticalOutputPort;
            
            action emitLight {
                out light1 : NearInfraredLight { wavelength = 730 [nm]; }
                out light2 : NearInfraredLight { wavelength = 810 [nm]; }
            }
        }
        
        part def Photodetector {
            attribute sensitivity : Real = 0.85;
            attribute samplingRate : Frequency = 50 [Hz];
            port opticalIn : OpticalInputPort;
            port signalOut : SignalOutputPort;
            
            action detectLight {
                in incomingLight : NearInfraredLight;
                out signal : PhotodetectorSignal;
            }
        }
        
        part def SensorHead {
            attribute side : String;
            attribute adhesiveType : String = "medical-grade";
            attribute isAttached : Boolean = false;
            
            part emitter : LightEmitter;
            part detector : Photodetector;
            
            interface : OpticalInterface {
                connect emitter.opticalOut to detector.opticalIn;
            }
            
            port signalOut : SignalOutputPort;
            
            flow from detector.signalOut.signal to signalOut.signal;
        }
        
        part def SignalProcessingUnit {
            attribute calculationInterval : Duration = 1 [s];
            attribute lowThreshold : OxygenSaturation = 50 [%];
            attribute criticalThreshold : OxygenSaturation = 40 [%];
            
            port signalInLeft : SignalInputPort;
            port signalInRight : SignalInputPort;
            port dataOut : DataOutputPort;
            port alarmOut : AlarmOutputPort;
            port powerIn : PowerInputPort;
            
            action processSignals {
                in leftSignals : PhotodetectorSignal[0..*];
                in rightSignals : PhotodetectorSignal[0..*];
                out leftReading : OxygenSaturationReading;
                out rightReading : OxygenSaturationReading;
                
                action calculateAbsorptionDifference {
                    in signals730 : PhotodetectorSignal;
                    in signals810 : PhotodetectorSignal;
                    out absorptionDiff : Real;
                }
                
                action computeRSO2 {
                    in absorptionDiff : Real;
                    out rSO2 : OxygenSaturation;
                }
            }
            
            state processingState {
                entry; then calculating;
                state calculating;
                transition calculating to calculating;
            }
        }
        
        part def DisplayModule {
            attribute displayType : String = "LCD";
            attribute resolution : String = "800x480";
            attribute trendWindowHours : Duration = 4 [h];
            
            port dataIn : DataInputPort;
            port powerIn : PowerInputPort;
            
            action renderDisplay {
                in reading : OxygenSaturationReading;
                in trend : TrendData;
            }
        }
        
        part def AlarmModule {
            attribute audibleEnabled : Boolean = true;
            attribute visualEnabled : Boolean = true;
            attribute alarmVolume : Real = 85 [dB];
            
            port alarmIn : AlarmInputPort;
            port powerIn : PowerInputPort;
            
            action evaluateThresholds {
                in reading : OxygenSaturationReading;
                out alarm : AlarmEvent;
                
                if reading.rSO2 < 40 [%] {
                    alarm.severity = "critical";
                } else if reading.rSO2 < 50 [%] {
                    alarm.severity = "low";
                } else {
                    alarm.severity = "none";
                }
            }
            
            action triggerAudibleAlarm {
                in alarm : AlarmEvent;
            }
            
            action triggerVisualAlarm {
                in alarm : AlarmEvent;
            }
        }
        
        part def PowerSupplyUnit {
            attribute inputVoltage : Voltage = 120 [V];
            attribute outputVoltage : Voltage = 12 [V];
            attribute maxPower : Power = 50 [W];
            attribute batteryCapacity : Duration = 3600 [s];
            attribute batteryRemaining : Duration = 3600 [s];
            attribute onBattery : Boolean = false;
            
            part batteryBackup {
                attribute capacity : Duration = 3600 [s];
                attribute chargeLevel : Real = 1.0;
            }
            
            port powerOut : PowerOutputPort;
            
            action supplyPower {
                out voltage : Voltage;
                out status : PowerStatus;
            }
            
            action switchToBattery {
                attribute onBattery = true;
            }
            
            action monitorBatteryLevel {
                in battery : PowerSupplyUnit;
            }
        }
        
        part def DataStorageUnit {
            attribute storageCapacity : Real = 8 [GB];
            attribute recordingDuration : Duration = 24 [h];
            attribute samplingInterval : Duration = 1 [s];
            
            port dataIn : DataInputPort;
            port powerIn : PowerInputPort;
            
            action storeReading {
                in reading : OxygenSaturationReading;
            }
            
            action retrieveTrend {
                in startTime : Duration;
                in endTime : Duration;
                out trend : TrendData;
            }
        }
    }
    
    package System {
        part def INVOSCerebralOximeter {
            attribute deviceName : String = "Somanetics INVOS Cerebral Oximeter";
            attribute manufacturer : String = "Somanetics";
            attribute monitoringType : String = "Non-invasive NIRS";
            attribute bilateralMonitoring : Boolean = true;
            
            part leftSensor : Components::SensorHead {
                attribute side = "left";
            }
            part rightSensor : Components::SensorHead {
                attribute side = "right";
            }
            part signalProcessor : Components::SignalProcessingUnit;
            part display : Components::DisplayModule;
            part alarm : Components::AlarmModule;
            part powerSupply : Components::PowerSupplyUnit;
            part dataStorage : Components::DataStorageUnit;
            
            interface : Interfaces::SignalInterface {
                connect leftSensor.signalOut to signalProcessor.signalInLeft;
            }
            interface : Interfaces::SignalInterface {
                connect rightSensor.signalOut to signalProcessor.signalInRight;
            }
            interface : Interfaces::DataInterface {
                connect signalProcessor.dataOut to display.dataIn;
            }
            interface : Interfaces::DataInterface {
                connect signalProcessor.dataOut to dataStorage.dataIn;
            }
            interface : Interfaces::AlarmInterface {
                connect signalProcessor.alarmOut to alarm.alarmIn;
            }
            interface : Interfaces::PowerInterface {
                connect powerSupply.powerOut to signalProcessor.powerIn;
            }
            interface : Interfaces::PowerInterface {
                connect powerSupply.powerOut to display.powerIn;
            }
            interface : Interfaces::PowerInterface {
                connect powerSupply.powerOut to alarm.powerIn;
            }
            interface : Interfaces::PowerInterface {
                connect powerSupply.powerOut to dataStorage.powerIn;
            }
            
            state oximeterStateMachine {
                entry; then Initialization;
                
                state Initialization {
                    entry action performSelfTest {
                        action testSensors;
                        action testSignalProcessor;
                        action testDisplay;
                        action testAlarm;
                        action testPowerSupply;
                        action testDataStorage;
                    }
                    do action verifyComponents;
                    transition Initialization to Standby
                        when self.testComplete == true;
                }
                
                state Standby {
                    entry action enterStandby {
                        action dimDisplay;
                        action disableAlarms;
                    }
                    transition Standby to ActiveMonitoring
                        when self.monitoringStarted == true;
                }
                
                state ActiveMonitoring {
                    entry action startMonitoring {
                        action activateSensors;
                        action beginSignalProcessing;
                        action startDataRecording;
                    }
                    do action continuousMonitoring {
                        loop {
                            action acquireSignals;
                            action processSignals;
                            action updateDisplay;
                            action storeData;
                            action checkThresholds;
                        }
                    }
                    transition ActiveMonitoring to AlarmState
                        when self.criticalAlarmTriggered == true;
                    transition ActiveMonitoring to Standby
                        when self.monitoringStopped == true;
                }
                
                state AlarmState {
                    entry action triggerAlarms {
                        action activateAudibleAlarm;
                        action activateVisualAlarm;
                        action logAlarmEvent;
                    }
                    do action maintainAlarm;
                    transition AlarmState to ActiveMonitoring
                        when self.alarmAcknowledged == true
                        and self.rSO2 >= 50 [%];
                    transition AlarmState to Standby
                        when self.monitoringStopped == true;
                }
            }
        }
    }
    
    package Requirements {
        requirement def SystemRequirement {
            doc /* Base requirement for the INVOS Cerebral Oximeter system */
        }
        
        requirement NonInvasiveMonitoringRequirement :> SystemRequirement {
            doc /* The system shall provide non-invasive, continuous monitoring of cerebral oxygen saturation. */
            attribute monitoringMethod : String = "NIRS";
            constraint { monitoringMethod == "NIRS" }
        }
        
        requirement BilateralMonitoringRequirement :> SystemRequirement {
            doc /* The system shall monitor both left and right frontal cortex simultaneously. */
            attribute sensorCount : Integer = 2;
            constraint { sensorCount == 2 }
        }
        
        requirement DualWavelengthRequirement :> SystemRequirement {
            doc /* The emitter shall shine near-infrared light at 730nm and 810nm wavelengths. */
            attribute wavelength1 : Wavelength = 730 [nm];
            attribute wavelength2 : Wavelength = 810 [nm];
            constraint { wavelength1 == 730 [nm] and wavelength2 == 810 [nm] }
        }
        
        requirement OxygenSaturationRangeRequirement :> SystemRequirement {
            doc /* The system shall measure rSO2 values within the range of 0 to 100 percent. */
            attribute minRange : OxygenSaturation = 0 [%];
            attribute maxRange : OxygenSaturation = 100 [%];
            constraint { minRange >= 0 [%] and maxRange <= 100 [%] }
        }
        
        requirement AlarmThresholdRequirement :> SystemRequirement {
            doc /* The system shall trigger alarms when rSO2 drops below preset thresholds. */
            attribute lowThreshold : OxygenSaturation = 50 [%];
            attribute criticalThreshold : OxygenSaturation = 40 [%];
            constraint { lowThreshold > criticalThreshold }
        }
        
        requirement BatteryBackupRequirement :> SystemRequirement {
            doc /* The system shall operate on battery backup for at least one hour during power outage. */
            attribute minBatteryDuration : Duration = 3600 [s];
            constraint { minBatteryDuration >= 3600 [s] }
        }
        
        requirement DataStorageRequirement :> SystemRequirement {
            doc /* The system shall store patient monitoring data for later review and trend analysis. */
            attribute minStorageDuration : Duration = 24 [h];
            constraint { minStorageDuration >= 24 [h] }
        }
        
        requirement DisplayRequirement :> SystemRequirement {
            doc /* The system shall display current oxygen saturation values and historical trends. */
            attribute trendWindow : Duration = 4 [h];
            constraint { trendWindow >= 4 [h] }
        }
        
        requirement StateMachineRequirement :> SystemRequirement {
            doc /* The system shall operate through initialization, standby, active monitoring, and alarm states. */
            attribute requiredStates : String = "Initialization, Standby, ActiveMonitoring, AlarmState";
        }
        
        satisfaction NonInvasiveMonitoringRequirement by System::INVOSCerebralOximeter;
        satisfaction BilateralMonitoringRequirement by System::INVOSCerebralOximeter;
        satisfaction DualWavelengthRequirement by System::INVOSCerebralOximeter.leftSensor.emitter;
        satisfaction DualWavelengthRequirement by System::INVOSCerebralOximeter.rightSensor.emitter;
        satisfaction OxygenSaturationRangeRequirement by System::INVOSCerebralOximeter.signalProcessor;
        satisfaction AlarmThresholdRequirement by System::INVOSCerebralOximeter.alarm;
        satisfaction BatteryBackupRequirement by System::INVOSCerebralOximeter.powerSupply;
        satisfaction DataStorageRequirement by System::INVOSCerebralOximeter.dataStorage;
        satisfaction DisplayRequirement by System::INVOSCerebralOximeter.display;
        satisfaction StateMachineRequirement by System::INVOSCerebralOximeter.oximeterStateMachine;
    }
}
