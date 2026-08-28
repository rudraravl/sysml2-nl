package BurnRecoveryBedSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import ScalarFunctions::*;

    package Definitions {
        value type BedSurfaceTemp :> TemperatureValue;
        value type PatientInterfacePressure :> PressureValue;
        value type CabinHumidity :> Real;
        value type BedTiltAngle :> Real;
        value type BedAngularSpeed :> Real;
        value type TimeDuration :> Real;

        item def TemperatureReading {
            attribute value : BedSurfaceTemp;
        }
        item def PressureReading {
            attribute value : PatientInterfacePressure;
            attribute zoneId : Integer;
        }
        item def HumidityReading {
            attribute value : CabinHumidity;
        }
        item def PositionReading {
            attribute angle : BedTiltAngle;
        }

        attribute def TemperatureCommand {
            attribute target : BedSurfaceTemp;
        }
        attribute def PressureCommand {
            attribute zoneId : Integer;
        }
        attribute def PositionCommand {
            attribute targetAngle : BedTiltAngle;
            attribute speed : BedAngularSpeed;
        }
        attribute def HumidityCommand {
            attribute target : CabinHumidity;
        }
        attribute def AlarmCommand {
            attribute severity : String;
            attribute source : String;
        }

        attribute def StartSignal;
        attribute def ShutdownSignal;
        attribute def InitComplete;
        attribute def RepositionTrigger;
        attribute def RepositionComplete;
        attribute def CriticalDeviation;
        attribute def AlarmClear;
        attribute def PowerLoss;
        attribute def PowerRestore;
        attribute def AdjustComplete;

        action def PerformSelfTest;
        action def SenseTemperature {
            out temp : BedSurfaceTemp;
        }
        action def SensePressure {
            out pressure : PatientInterfacePressure;
        }
        action def SenseHumidity {
            out humidity : CabinHumidity;
        }
        action def SensePosition {
            out angle : BedTiltAngle;
        }
        action def MaintainTherapy;
        action def RepositionPatient;
        action def ActivateAudibleAlarm;
        action def ActivateVisualAlarm;
        action def EngageBackup;
        action def RestoreMainPower;
        action def SafeShutdown;
        action def VerifyPosition;

        part def ControlUnit {
            exhibit state 'controller states' : 'Controller States';
        }
        part def TemperatureControlSystem;
        part def PressureReliefSystem;
        part def PositioningSystem;
        part def HumidityControlSystem;
        part def MonitoringSystem;
        part def AlarmSystem;
        part def BatteryBackup;
        part def BurnRecoveryBed {
            exhibit state 'bed states' : 'Bed States';
        }

        state def 'Bed States';
        state def 'Controller States';

        requirement def TemperaturePrecisionReq {
            doc /* The bed surface temperature shall be maintained within 0.5 K of the prescribed setpoint. */
            attribute setpoint : BedSurfaceTemp;
            attribute measured : BedSurfaceTemp;
            require constraint { abs(measured - setpoint) <= 0.5 }
        }
        requirement def HumidityRangeReq {
            doc /* The cabin humidity shall be maintained between 40 and 60 percent. */
            attribute measured : CabinHumidity;
            require constraint { measured >= 40 and measured <= 60 }
        }
        requirement def PressureReliefReq {
            doc /* No body zone shall sustain pressure above the threshold for longer than the maximum allowed duration. */
            attribute peakPressure : PatientInterfacePressure;
            attribute maxPressure : PatientInterfacePressure;
            attribute sustainedDuration : TimeDuration;
            attribute maxDuration : TimeDuration;
            require constraint { peakPressure <= maxPressure or sustainedDuration <= maxDuration }
        }
        requirement def RepositioningIntervalReq {
            doc /* The bed shall automatically reposition the patient at intervals not exceeding two hours. */
            attribute interval : TimeDuration;
            attribute maxInterval : TimeDuration;
            require constraint { interval <= maxInterval }
        }
        requirement def GentleMotionReq {
            doc /* Repositioning motion shall be gentle with maximum angular speed of 5 degrees per second. */
            attribute rotationSpeed : BedAngularSpeed;
            attribute maxRotationSpeed : BedAngularSpeed;
            require constraint { rotationSpeed <= maxRotationSpeed }
        }
        requirement def AlarmResponseReq {
            doc /* Audible and visual alarms shall activate within 2 seconds of a critical deviation. */
            attribute latency : TimeDuration;
            attribute maxLatency : TimeDuration;
            require constraint { latency <= maxLatency }
        }
        requirement def BatteryBackupReq {
            doc /* The battery backup shall sustain life-support functions for at least 30 minutes. */
            attribute backupDuration : TimeDuration;
            attribute minBackupDuration : TimeDuration;
            require constraint { backupDuration >= minBackupDuration }
        }
        requirement def ContinuousMonitoringReq {
            doc /* The monitoring system shall continuously collect readings for temperature, pressure, humidity, and position. */
            attribute monitoringActive : Boolean;
            require constraint { monitoringActive == true }
        }
        requirement def SafetyInterlockReq {
            doc /* The bed shall not start unless safety interlocks are engaged. */
            attribute interlockEngaged : Boolean;
            require constraint { interlockEngaged == true }
        }
    }

    package Usages {
        private import Definitions::*;

        part burnRecoveryBed : BurnRecoveryBed {
            attribute 'safety interlock engaged' : Boolean := true;
            attribute temperatureSetpoint : BedSurfaceTemp := 305.15;
            attribute humiditySetpoint : CabinHumidity := 50;
            attribute 'max pressure threshold' : PatientInterfacePressure := 4000;
            attribute 'max pressure duration' : TimeDuration := 1200;
            attribute 'reposition interval' : TimeDuration := 7200;
            attribute 'max rotation speed' : BedAngularSpeed := 5;

            part controlUnit : ControlUnit {
                port tempReadingsPort {
                    in tempReadings : TemperatureReading;
                }
                port pressureReadingsPort {
                    in pressureReadings : PressureReading;
                }
                port humidityReadingsPort {
                    in humidityReadings : HumidityReading;
                }
                port positionReadingsPort {
                    in positionReadings : PositionReading;
                }
                port tempCmdPort {
                    out tempCmd : TemperatureCommand;
                }
                port pressureCmdPort {
                    out pressureCmd : PressureCommand;
                }
                port positionCmdPort {
                    out positionCmd : PositionCommand;
                }
                port humidityCmdPort {
                    out humidityCmd : HumidityCommand;
                }
                port alarmCmdPort {
                    out alarmCmd : AlarmCommand;
                }
            }

            part monitoringSystem : MonitoringSystem {
                port tempSensorPort {
                    out tempReadings : TemperatureReading;
                }
                port pressureSensorPort {
                    out pressureReadings : PressureReading;
                }
                port humiditySensorPort {
                    out humidityReadings : HumidityReading;
                }
                port positionSensorPort {
                    out positionReadings : PositionReading;
                }
            }

            part temperatureControl : TemperatureControlSystem {
                port cmdPort {
                    in cmd : TemperatureCommand;
                }
            }
            part pressureRelief : PressureReliefSystem {
                port cmdPort {
                    in cmd : PressureCommand;
                }
            }
            part positioning : PositioningSystem {
                port cmdPort {
                    in cmd : PositionCommand;
                }
            }
            part humidityControl : HumidityControlSystem {
                port cmdPort {
                    in cmd : HumidityCommand;
                }
            }
            part alarmSystem : AlarmSystem {
                port cmdPort {
                    in cmd : AlarmCommand;
                }
            }
            part batteryBackup : BatteryBackup;

            flow tempReadingsFlow of TemperatureReading
                from monitoringSystem.tempSensorPort.tempReadings
                to controlUnit.tempReadingsPort.tempReadings;
            flow pressureReadingsFlow of PressureReading
                from monitoringSystem.pressureSensorPort.pressureReadings
                to controlUnit.pressureReadingsPort.pressureReadings;
            flow humidityReadingsFlow of HumidityReading
                from monitoringSystem.humiditySensorPort.humidityReadings
                to controlUnit.humidityReadingsPort.humidityReadings;
            flow positionReadingsFlow of PositionReading
                from monitoringSystem.positionSensorPort.positionReadings
                to controlUnit.positionReadingsPort.positionReadings;
            flow tempCmdFlow of TemperatureCommand
                from controlUnit.tempCmdPort.tempCmd
                to temperatureControl.cmdPort.cmd;
            flow pressureCmdFlow of PressureCommand
                from controlUnit.pressureCmdPort.pressureCmd
                to pressureRelief.cmdPort.cmd;
            flow positionCmdFlow of PositionCommand
                from controlUnit.positionCmdPort.positionCmd
                to positioning.cmdPort.cmd;
            flow humidityCmdFlow of HumidityCommand
                from controlUnit.humidityCmdPort.humidityCmd
                to humidityControl.cmdPort.cmd;
            flow alarmCmdFlow of AlarmCommand
                from controlUnit.alarmCmdPort.alarmCmd
                to alarmSystem.cmdPort.cmd;
        }

        action 'perform self test' : PerformSelfTest;
        action 'sense temperature' : SenseTemperature;
        action 'sense pressure' : SensePressure;
        action 'sense humidity' : SenseHumidity;
        action 'sense position' : SensePosition;
        action 'maintain therapy' : MaintainTherapy;
        action 'reposition patient' : RepositionPatient;
        action 'activate audible alarm' : ActivateAudibleAlarm;
        action 'activate visual alarm' : ActivateVisualAlarm;
        action 'engage backup' : EngageBackup;
        action 'restore main power' : RestoreMainPower;
        action 'safe shutdown' : SafeShutdown;
        action 'verify position' : VerifyPosition;

        state 'bed states' : 'Bed States' parallel {
            state 'operational states' {
                entry; then off;
                state off;
                accept StartSignal
                    if burnRecoveryBed.'safety interlock engaged'
                    then initializing;
                state initializing {
                    entry 'perform self test';
                    exit 'verify position';
                }
                accept InitComplete
                    then active;
                state active {
                    do 'maintain therapy';
                }
                accept RepositionTrigger
                    then repositioning;
                accept CriticalDeviation
                    then 'critical alarm';
                accept ShutdownSignal
                    do 'safe shutdown'
                    then off;
                state repositioning {
                    do 'reposition patient';
                    exit 'verify position';
                }
                accept RepositionComplete
                    then active;
                state 'critical alarm' {
                    entry 'activate audible alarm';
                    entry 'activate visual alarm';
                    do 'maintain therapy';
                }
                accept AlarmClear
                    then active;
            }
            state 'power states' {
                entry; then 'main power';
                state 'main power';
                accept PowerLoss
                    do 'engage backup'
                    then 'backup power';
                state 'backup power' {
                    do 'maintain therapy';
                }
                accept PowerRestore
                    do 'restore main power'
                    then 'main power';
            }
        }

        state 'controller states' : 'Controller States' {
            entry; then idle;
            state idle;
            accept StartSignal
                then monitoring;
            state monitoring {
                do 'sense temperature';
                do 'sense pressure';
                do 'sense humidity';
                do 'sense position';
            }
            accept when 'sense temperature'.temp > burnRecoveryBed.temperatureSetpoint + 2
                do send new CriticalDeviation() to burnRecoveryBed
                then emergency;
            accept when 'sense temperature'.temp > burnRecoveryBed.temperatureSetpoint + 0.5
                do send new TemperatureCommand(target = burnRecoveryBed.temperatureSetpoint) to burnRecoveryBed.temperatureControl
                then adjusting;
            accept when 'sense temperature'.temp < burnRecoveryBed.temperatureSetpoint - 0.5
                do send new TemperatureCommand(target = burnRecoveryBed.temperatureSetpoint) to burnRecoveryBed.temperatureControl
                then adjusting;
            accept when 'sense humidity'.humidity > burnRecoveryBed.humiditySetpoint + 5
                do send new HumidityCommand(target = burnRecoveryBed.humiditySetpoint) to burnRecoveryBed.humidityControl
                then adjusting;
            accept when 'sense humidity'.humidity < burnRecoveryBed.humiditySetpoint - 5
                do send new HumidityCommand(target = burnRecoveryBed.humiditySetpoint) to burnRecoveryBed.humidityControl
                then adjusting;
            accept when 'sense pressure'.pressure > burnRecoveryBed.'max pressure threshold'
                do send new RepositionTrigger() to burnRecoveryBed
                then repositioning;
            accept ShutdownSignal
                then idle;
            state adjusting;
            accept AdjustComplete
                then monitoring;
            state repositioning;
            accept RepositionComplete
                then monitoring;
            state emergency {
                do 'activate audible alarm';
                do 'activate visual alarm';
                do 'maintain therapy';
            }
            accept AlarmClear
                then monitoring;
        }

        requirement temperaturePrecisionReq : TemperaturePrecisionReq {
            attribute setpoint : BedSurfaceTemp := 305.15;
            attribute measured : BedSurfaceTemp := 305.15;
        }
        requirement humidityRangeReq : HumidityRangeReq {
            attribute measured : CabinHumidity := 50;
        }
        requirement pressureReliefReq : PressureReliefReq {
            attribute peakPressure : PatientInterfacePressure := 3000;
            attribute maxPressure : PatientInterfacePressure := 4000;
            attribute sustainedDuration : TimeDuration := 600;
            attribute maxDuration : TimeDuration := 1200;
        }
        requirement repositioningIntervalReq : RepositioningIntervalReq {
            attribute interval : TimeDuration := 7200;
            attribute maxInterval : TimeDuration := 7200;
        }
        requirement gentleMotionReq : GentleMotionReq {
            attribute rotationSpeed : BedAngularSpeed := 3;
            attribute maxRotationSpeed : BedAngularSpeed := 5;
        }
        requirement alarmResponseReq : AlarmResponseReq {
            attribute latency : TimeDuration := 1;
            attribute maxLatency : TimeDuration := 2;
        }
        requirement batteryBackupReq : BatteryBackupReq {
            attribute backupDuration : TimeDuration := 1800;
            attribute minBackupDuration : TimeDuration := 1800;
        }
        requirement continuousMonitoringReq : ContinuousMonitoringReq {
            attribute monitoringActive : Boolean := true;
        }
        requirement safetyInterlockReq : SafetyInterlockReq {
            attribute interlockEngaged : Boolean := true;
        }
    }
}
