package BurnRecoveryBedSystem {
    import ScalarValues::*;
    import ISQ::*;
    
    value def TemperatureValue :> Real {
        unit degC;
    }
    value def HumidityValue :> Real {
        unit percent;
    }
    value def PressureValue :> Real {
        unit kPa;
    }
    value def AngleValue :> Real {
        unit deg;
    }
    value def DurationValue :> Real {
        unit s;
    }
    value def PowerValue :> Real {
        unit W;
    }
    
    item def SensorData {
        attribute temperature : TemperatureValue;
        attribute humidity : HumidityValue;
        attribute pressure : PressureValue;
        attribute patientAngle : AngleValue;
        attribute timestamp : DurationValue;
    }
    
    item def ControlCommand {
        attribute targetSubsystem : String;
        attribute commandType : String;
        attribute value : Real;
    }
    
    item def AlarmSignal {
        attribute severity : String;
        attribute message : String;
        attribute audible : Boolean;
        attribute visual : Boolean;
    }
    
    item def PowerFlow {
        attribute power : PowerValue;
        attribute source : String;
    }
    
    enum def OperationalMode {
        standby;
        normal;
        adjustment;
        alarm;
        emergency;
    }
    
    enum def AlarmLevel {
        none;
        warning;
        critical;
    }
    
    port def SensorDataOutPort {
        out data : SensorData;
    }
    
    port def SensorDataInPort {
        in data : SensorData;
    }
    
    port def CommandOutPort {
        out command : ControlCommand;
    }
    
    port def CommandInPort {
        in command : ControlCommand;
    }
    
    port def AlarmOutPort {
        out alarm : AlarmSignal;
    }
    
    port def AlarmInPort {
        in alarm : AlarmSignal;
    }
    
    port def PowerOutPort {
        out power : PowerFlow;
    }
    
    port def PowerInPort {
        in power : PowerFlow;
    }
    
    requirement def TherapeuticEnvironmentRequirement {
        subject bed : BurnRecoveryBed;
        objective {
            doc /* The system shall maintain a controlled therapeutic environment for burn recovery. */
        }
        require constraint { bed.active == true }
    }
    
    requirement def TemperatureControlRequirement {
        subject tempSystem : TemperatureControlSystem;
        attribute setpoint : TemperatureValue = 32.0;
        attribute tolerance : TemperatureValue = 0.5;
        objective {
            doc /* The bed surface temperature shall be maintained within tolerance of setpoint. */
        }
        require constraint {
            tempSystem.measuredTemperature >= setpoint - tolerance and
            tempSystem.measuredTemperature <= setpoint + tolerance
        }
    }
    
    requirement def PressureReliefRequirement {
        subject pressureSystem : PressureReliefSystem;
        attribute maxPressure : PressureValue = 4.0;
        attribute maxDuration : DurationValue = 7200;
        objective {
            doc /* Pressure on any body area shall not exceed maxPressure for longer than maxDuration. */
        }
        require constraint {
            pressureSystem.peakPressure <= maxPressure
        }
    }
    
    requirement def HumidityControlRequirement {
        subject humiditySystem : HumidityControlSystem;
        attribute setpoint : HumidityValue = 50.0;
        attribute tolerance : HumidityValue = 5.0;
        objective {
            doc /* Humidity shall be maintained within tolerance of setpoint. */
        }
        require constraint {
            humiditySystem.measuredHumidity >= setpoint - tolerance and
            humiditySystem.measuredHumidity <= setpoint + tolerance
        }
    }
    
    requirement def PositioningRequirement {
        subject positioningSystem : PositioningSystem;
        attribute maxRotationRate : AngleValue = 2.0;
        attribute repositionInterval : DurationValue = 3600;
        objective {
            doc /* The system shall reposition the patient at programmed intervals with gentle motion. */
        }
        require constraint {
            positioningSystem.rotationRate <= maxRotationRate
        }
    }
    
    requirement def SafetyRequirement {
        subject bed : BurnRecoveryBed;
        objective {
            doc /* The system shall maintain life-support functions during any failure mode. */
        }
        require constraint { bed.lifeSupportActive == true }
    }
    
    requirement def AlarmRequirement {
        subject monitoring : MonitoringSystem;
        objective {
            doc /* Critical deviations shall trigger audible and visual alarms. */
        }
        require constraint {
            monitoring.alarmLevel == AlarmLevel::critical implies monitoring.alarmActivated == true
        }
    }
    
    requirement def PowerBackupRequirement {
        subject power : PowerSubsystem;
        objective {
            doc /* The system shall provide battery backup for power reliability. */
        }
        require constraint { power.backupAvailable == true }
    }
    
    part def TemperatureControlSystem {
        attribute measuredTemperature : TemperatureValue = 32.0;
        attribute setpoint : TemperatureValue = 32.0;
        attribute tolerance : TemperatureValue = 0.5;
        attribute heatingActive : Boolean = false;
        attribute coolingActive : Boolean = false;
        
        port commandIn : CommandInPort;
        port sensorOut : SensorDataOutPort;
        port powerIn : PowerInPort;
        
        action def regulateTemperature {
            in current : TemperatureValue;
            in target : TemperatureValue;
            in tol : TemperatureValue;
            
            start;
            action evaluateDeviation {
                in c = current;
                in t = target;
                in tl = tol;
            }
            then action decideAction {
                in c = current;
                in t = target;
            }
            then action applyHeatingOrCooling;
            then done;
        }
        
        state def TemperatureControlBehavior {
            entry; then Monitoring;
            
            state Monitoring {
                entry action {
                    if measuredTemperature < setpoint - tolerance {
                        heatingActive = true;
                        coolingActive = false;
                    } else if measuredTemperature > setpoint + tolerance {
                        heatingActive = false;
                        coolingActive = true;
                    } else {
                        heatingActive = false;
                        coolingActive = false;
                    }
                }
            }
            
            transition Monitoring -> Monitoring {
                when measuredTemperature != setpoint;
            }
        }
        
        exhibit TemperatureControlBehavior;
        
        satisfaction TemperatureControlRequirement {
            subject = self;
        }
    }
    
    part def PressureReliefSystem {
        attribute peakPressure : PressureValue = 2.0;
        attribute redistributionActive : Boolean = false;
        attribute zoneCount : Integer = 8;
        attribute pressureThreshold : PressureValue = 4.0;
        attribute criticalThreshold : PressureValue = 6.0;
        
        port commandIn : CommandInPort;
        port sensorOut : SensorDataOutPort;
        port powerIn : PowerInPort;
        
        action def redistributePressure {
            in zones : PressureValue;
            out adjusted : PressureValue;
            
            start;
            action analyzeZones {
                in p = zones;
            }
            then action adjustAirCells;
            then action verifyReduction {
                out a = adjusted;
            }
            then done;
        }
        
        state def PressureReliefBehavior {
            entry; then Monitoring;
            
            state Monitoring;
            state Redistributing;
            state Critical;
            
            transition Monitoring -> Redistributing {
                when peakPressure > pressureThreshold;
                action { redistributionActive = true; }
            }
            
            transition Redistributing -> Monitoring {
                when peakPressure <= pressureThreshold;
                action { redistributionActive = false; }
            }
            
            transition Monitoring -> Critical {
                when peakPressure > criticalThreshold;
            }
            
            transition Redistributing -> Critical {
                when peakPressure > criticalThreshold;
            }
            
            transition Critical -> Redistributing {
                when peakPressure <= criticalThreshold and peakPressure > pressureThreshold;
            }
        }
        
        exhibit PressureReliefBehavior;
        
        satisfaction PressureReliefRequirement {
            subject = self;
        }
    }
    
    part def PositioningSystem {
        attribute currentAngle : AngleValue = 0.0;
        attribute targetAngle : AngleValue = 0.0;
        attribute rotationRate : AngleValue = 0.0;
        attribute maxRotationRate : AngleValue = 2.0;
        attribute repositionInterval : DurationValue = 3600;
        attribute timeSinceReposition : DurationValue = 0.0;
        attribute isRepositioning : Boolean = false;
        
        port commandIn : CommandInPort;
        port sensorOut : SensorDataOutPort;
        port powerIn : PowerInPort;
        
        action def repositionPatient {
            in target : AngleValue;
            in rate : AngleValue;
            
            start;
            action initiateRotation {
                action setTarget;
                then action engageActuator;
            }
            then action rotateGently {
                // Slow controlled rotation toward target
            }
            then action stabilize {
                // Hold position after reaching target
            }
            then done;
        }
        
        state def PositioningBehavior {
            entry; then Idle;
            
            state Idle;
            state Repositioning;
            state Stabilizing;
            
            transition Idle -> Repositioning {
                when timeSinceReposition >= repositionInterval;
                action {
                    isRepositioning = true;
                    rotationRate = maxRotationRate;
                    targetAngle = currentAngle + 30.0;
                }
            }
            
            transition Repositioning -> Stabilizing {
                when currentAngle == targetAngle;
                action {
                    rotationRate = 0.0;
                    isRepositioning = false;
                    timeSinceReposition = 0.0;
                }
            }
            
            transition Stabilizing -> Idle {
                when isRepositioning == false;
            }
        }
        
        exhibit PositioningBehavior;
        
        satisfaction PositioningRequirement {
            subject = self;
        }
    }
    
    part def HumidityControlSystem {
        attribute measuredHumidity : HumidityValue = 50.0;
        attribute setpoint : HumidityValue = 50.0;
        attribute tolerance : HumidityValue = 5.0;
        attribute humidifyingActive : Boolean = false;
        attribute dehumidifyingActive : Boolean = false;
        
        port commandIn : CommandInPort;
        port sensorOut : SensorDataOutPort;
        port powerIn : PowerInPort;
        
        state def HumidityControlBehavior {
            entry; then Monitoring;
            
            state Monitoring {
                entry action {
                    if measuredHumidity < setpoint - tolerance {
                        humidifyingActive = true;
                        dehumidifyingActive = false;
                    } else if measuredHumidity > setpoint + tolerance {
                        humidifyingActive = false;
                        dehumidifyingActive = true;
                    } else {
                        humidifyingActive = false;
                        dehumidifyingActive = false;
                    }
                }
            }
            
            transition Monitoring -> Monitoring {
                when measuredHumidity != setpoint;
            }
        }
        
        exhibit HumidityControlBehavior;
        
        satisfaction HumidityControlRequirement {
            subject = self;
        }
    }
    
    part def MonitoringSystem {
        attribute latestData : SensorData;
        attribute alarmLevel : AlarmLevel = AlarmLevel::none;
        attribute alarmActivated : Boolean = false;
        attribute dataCollectionInterval : DurationValue = 1.0;
        attribute tempCriticalHigh : TemperatureValue = 40.0;
        attribute tempCriticalLow : TemperatureValue = 28.0;
        attribute pressureCritical : PressureValue = 6.0;
        attribute humidityCriticalLow : HumidityValue = 35.0;
        attribute humidityCriticalHigh : HumidityValue = 65.0;
        
        port sensorIn : SensorDataInPort;
        port dataOut : SensorDataOutPort;
        port alarmOut : AlarmOutPort;
        port powerIn : PowerInPort;
        
        action def collectReadings {
            in interval : DurationValue;
            out readings : SensorData;
            
            start;
            action pollSensors;
            then action aggregateData;
            then action evaluateThresholds {
                out r = readings;
            }
            then done;
        }
        
        state def MonitoringBehavior {
            entry; then Collecting;
            
            state Collecting;
            state Evaluating;
            state AlarmState;
            
            transition Collecting -> Evaluating {
                when latestData.timestamp > 0;
            }
            
            transition Evaluating -> Collecting {
                when alarmLevel == AlarmLevel::none;
            }
            
            transition Evaluating -> AlarmState {
                when alarmLevel == AlarmLevel::critical;
                action { alarmActivated = true; }
            }
            
            transition AlarmState -> Evaluating {
                when alarmLevel == AlarmLevel::none;
                action { alarmActivated = false; }
            }
        }
        
        exhibit MonitoringBehavior;
        
        satisfaction AlarmRequirement {
            subject = self;
        }
    }
    
    part def ControlUnit {
        attribute operationalMode : OperationalMode = OperationalMode::standby;
        attribute temperatureSetpoint : TemperatureValue = 32.0;
        attribute humiditySetpoint : HumidityValue = 50.0;
        attribute maxPressureThreshold : PressureValue = 4.0;
        attribute repositionInterval : DurationValue = 3600;
        attribute lifeSupportActive : Boolean = true;
        attribute alarmLevel : AlarmLevel = AlarmLevel::none;
        attribute latestData : SensorData;
        attribute tempSafeHigh : TemperatureValue = 40.0;
        attribute tempSafeLow : TemperatureValue = 28.0;
        attribute tempEmergencyHigh : TemperatureValue = 45.0;
        
        port sensorDataIn : SensorDataInPort;
        port tempCommandOut : CommandOutPort;
        port pressureCommandOut : CommandOutPort;
        port positioningCommandOut : CommandOutPort;
        port humidityCommandOut : CommandOutPort;
        port alarmOut : AlarmOutPort;
        port powerIn : PowerInPort;
        
        action def analyzeData {
            in data : SensorData;
            
            start;
            action compareTemperature {
                in d = data;
            }
            then action comparePressure {
                in d = data;
            }
            then action compareHumidity {
                in d = data;
            }
            then action evaluatePosition {
                in d = data;
            }
            then action generateCommands;
            then done;
        }
        
        state def ControlUnitBehavior {
            entry; then Standby;
            
            state Standby {
                entry action { operationalMode = OperationalMode::standby; }
            }
            state NormalOperation {
                entry action { operationalMode = OperationalMode::normal; }
            }
            state Adjustment {
                entry action { operationalMode = OperationalMode::adjustment; }
            }
            state AlarmMode {
                entry action {
                    operationalMode = OperationalMode::alarm;
                    alarmLevel = AlarmLevel::critical;
                }
            }
            state EmergencyMode {
                entry action {
                    operationalMode = OperationalMode::emergency;
                    lifeSupportActive = true;
                }
            }
            
            transition Standby -> NormalOperation {
                when operationalMode == OperationalMode::normal;
            }
            
            transition NormalOperation -> Adjustment {
                when latestData.pressure > maxPressureThreshold;
            }
            
            transition Adjustment -> NormalOperation {
                when latestData.pressure <= maxPressureThreshold;
            }
            
            transition NormalOperation -> AlarmMode {
                when latestData.temperature > tempSafeHigh or latestData.temperature < tempSafeLow;
            }
            
            transition Adjustment -> AlarmMode {
                when latestData.temperature > tempSafeHigh or latestData.temperature < tempSafeLow;
            }
            
            transition AlarmMode -> EmergencyMode {
                when latestData.temperature > tempEmergencyHigh;
            }
            
            transition EmergencyMode -> NormalOperation {
                when latestData.temperature >= 30.0 and latestData.temperature <= 34.0;
            }
        }
        
        exhibit ControlUnitBehavior;
    }
    
    part def PowerSubsystem {
        attribute mainPowerActive : Boolean = true;
        attribute backupAvailable : Boolean = true;
        attribute batteryCapacity : DurationValue = 14400;
        attribute currentPower : PowerValue = 500.0;
        
        port powerIn : PowerInPort;
        port powerOut : PowerOutPort;
        
        state def PowerBehavior {
            entry; then MainPower;
            
            state MainPower {
                entry action { mainPowerActive = true; }
            }
            state BatteryBackup {
                entry action {
                    mainPowerActive = false;
                    backupAvailable = true;
                }
            }
            state PowerFailure {
                entry action {
                    mainPowerActive = false;
                    backupAvailable = false;
                }
            }
            
            transition MainPower -> BatteryBackup {
                when mainPowerActive == false;
            }
            
            transition BatteryBackup -> MainPower {
                when mainPowerActive == true;
            }
            
            transition BatteryBackup -> PowerFailure {
                when batteryCapacity <= 0;
            }
        }
        
        exhibit PowerBehavior;
        
        satisfaction PowerBackupRequirement {
            subject = self;
        }
    }
    
    part def AlarmIndicator {
        attribute audibleActive : Boolean = false;
        attribute visualActive : Boolean = false;
        attribute alarmLevel : AlarmLevel = AlarmLevel::none;
        
        port alarmIn : AlarmInPort;
        port powerIn : PowerInPort;
        
        state def AlarmIndicatorBehavior {
            entry; then Silent;
            
            state Silent {
                entry action {
                    audibleActive = false;
                    visualActive = false;
                }
            }
            state Warning {
                entry action {
                    audibleActive = false;
                    visualActive = true;
                }
            }
            state Critical {
                entry action {
                    audibleActive = true;
                    visualActive = true;
                }
            }
            
            transition Silent -> Warning {
                when alarmLevel == AlarmLevel::warning;
            }
            transition Warning -> Critical {
                when alarmLevel == AlarmLevel::critical;
            }
            transition Critical -> Warning {
                when alarmLevel == AlarmLevel::warning;
            }
            transition Warning -> Silent {
                when alarmLevel == AlarmLevel::none;
            }
        }
        
        exhibit AlarmIndicatorBehavior;
    }
    
    part def Patient {
        attribute bodyTemperature : TemperatureValue = 37.0;
        attribute bodyAngle : AngleValue = 0.0;
    }
    
    part def BurnRecoveryBed {
        attribute active : Boolean = true;
        attribute lifeSupportActive : Boolean = true;
        attribute systemTime : DurationValue = 0.0;
        
        port externalAlarm : AlarmOutPort;
        port mainPower : PowerInPort;
        
        part controlUnit : ControlUnit;
        part temperatureControl : TemperatureControlSystem;
        part pressureRelief : PressureReliefSystem;
        part positioning : PositioningSystem;
        part humidityControl : HumidityControlSystem;
        part monitoring : MonitoringSystem;
        part powerSubsystem : PowerSubsystem;
        part alarmIndicator : AlarmIndicator;
        part patient : Patient;
        
        connection powerSubsystem.powerOut to controlUnit.powerIn;
        connection powerSubsystem.powerOut to temperatureControl.powerIn;
        connection powerSubsystem.powerOut to pressureRelief.powerIn;
        connection powerSubsystem.powerOut to positioning.powerIn;
        connection powerSubsystem.powerOut to humidityControl.powerIn;
        connection powerSubsystem.powerOut to monitoring.powerIn;
        connection powerSubsystem.powerOut to alarmIndicator.powerIn;
        
        connection mainPower to powerSubsystem.powerIn;
        
        connection temperatureControl.sensorOut to monitoring.sensorIn;
        connection pressureRelief.sensorOut to monitoring.sensorIn;
        connection positioning.sensorOut to monitoring.sensorIn;
        connection humidityControl.sensorOut to monitoring.sensorIn;
        
        connection monitoring.dataOut to controlUnit.sensorDataIn;
        
        connection controlUnit.tempCommandOut to temperatureControl.commandIn;
        connection controlUnit.pressureCommandOut to pressureRelief.commandIn;
        connection controlUnit.positioningCommandOut to positioning.commandIn;
        connection controlUnit.humidityCommandOut to humidityControl.commandIn;
        
        connection controlUnit.alarmOut to alarmIndicator.alarmIn;
        connection controlUnit.alarmOut to externalAlarm;
        
        satisfaction TherapeuticEnvironmentRequirement {
            subject = self;
        }
        satisfaction SafetyRequirement {
            subject = self;
        }
    }
}
