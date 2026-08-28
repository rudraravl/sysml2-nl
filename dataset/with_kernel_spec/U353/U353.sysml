package RespiratoryTherapyDevice {
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        item def Air;
        item def Power;

        attribute def Pressure :> Real;
        attribute def Flow :> Real;
        attribute def Temperature :> Real;
        attribute def Volume :> Real;
        attribute def TimeValue :> Real;

        port def AirPort {
            out air: Air;
            out pressure: Pressure;
            out flowRate: Flow;
        }
        port def PowerPort {
            out power: Power;
        }
        port def DataPort {
            out data: String;
        }

        part def Filter {
            port airOut: AirPort;
            attribute filterLife: TimeValue;
        }
        part def Blower {
            port airIn: AirPort;
            port airOut: AirPort;
            port controlIn: DataPort;
            port powerIn: PowerPort;
            attribute targetPressure: Pressure;
            perform action pressurizeAir: PressurizeAir;
        }
        part def Humidifier {
            port airIn: AirPort;
            port airOut: AirPort;
            port controlIn: DataPort;
            port powerIn: PowerPort;
            attribute waterLevel: Volume;
            attribute targetTemp: Temperature;
            attribute actualTemp: Temperature;
        }
        part def PatientCircuit {
            port airIn: AirPort;
            port airOut: AirPort;
            part mask: Mask;
        }
        part def Mask {
            port airIn: AirPort;
        }
        part def PressureSensor {
            port airIn: AirPort;
            port dataOut: DataPort;
            attribute pressure: Pressure;
            perform action sensePressure: SensePressure;
        }
        part def FlowSensor {
            port airIn: AirPort;
            port dataOut: DataPort;
            attribute flowRate: Flow;
            perform action senseFlow: SenseFlow;
        }
        part def TherapyController {
            port sensorIn: DataPort;
            port blowerControl: DataPort;
            port humidifierControl: DataPort;
            port alarmOut: DataPort;
            port uiOut: DataPort;
            port loggerOut: DataPort;
            port powerIn: PowerPort;
            attribute setPressure: Pressure;
            attribute rampDuration: TimeValue;
            perform action detectBreath: DetectBreath;
            perform action adjustBlower: AdjustBlower;
        }
        part def AlarmManager {
            port sensorIn: DataPort;
            port alarmOut: DataPort;
            port powerIn: PowerPort;
            attribute detectionTime: TimeValue;
            attribute alarmTime: TimeValue;
            perform action checkAlarms: CheckAlarms;
        }
        part def UserInterface {
            port displayIn: DataPort;
            port alarmIn: DataPort;
            port controlOut: DataPort;
            port powerIn: PowerPort;
            perform action displayData: DisplayData;
        }
        part def DataLogger {
            port dataIn: DataPort;
            port powerIn: PowerPort;
            attribute storageDays: Integer;
            perform action logSession: LogSession;
        }
        part def PowerManagement {
            port acIn: PowerPort;
            port batteryIn: PowerPort;
            port powerOut: PowerPort;
            attribute batteryDuration: TimeValue;
        }
        part def BackupBattery {
            port powerOut: PowerPort;
        }
        part def WallOutlet {
            port powerOut: PowerPort;
        }
        part def Patient {
            port airIn: AirPort;
        }
        part def RespiratoryTherapyDevice {
            part airFilter: Filter;
            part blower: Blower;
            part humidifier: Humidifier;
            part patientCircuit: PatientCircuit;
            part pressureSensor: PressureSensor;
            part flowSensor: FlowSensor;
            part therapyController: TherapyController;
            part alarmManager: AlarmManager;
            part userInterface: UserInterface;
            part dataLogger: DataLogger;
            part powerManagement: PowerManagement;
            part backupBattery: BackupBattery;
        }

        state def HumidifierStates;
        state def TherapyStates;
        state def AlarmStates;
        state def PowerStates;

        action def PressurizeAir;
        action def SensePressure { out pressure: Pressure; }
        action def SenseFlow { out flowRate: Flow; }
        action def DetectBreath { in pressure: Pressure; in flowRate: Flow; out breathPhase: String; }
        action def AdjustBlower { in targetPressure: Pressure; }
        action def CheckAlarms { in pressure: Pressure; in flowRate: Flow; out alarmType: String; }
        action def DisplayData;
        action def LogSession { in data: String; }
        action def RampPressure { in startPressure: Pressure; in endPressure: Pressure; in duration: TimeValue; }

        attribute def StartTherapy;
        attribute def StopTherapy;
        attribute def RefillWater;
        attribute def PowerLoss;
        attribute def PowerRestored;
        attribute def AcknowledgeAlarm;
        attribute def HighPressureAlarm;
        attribute def LowPressureAlarm;
        attribute def DisconnectAlarm;
        attribute def ApneaAlarm;

        requirement def PressureAccuracyReq {
            doc /* The delivered pressure shall be within ±0.5 cmH2O of the set pressure. */
            attribute setPressure: Pressure;
            attribute actualPressure: Pressure;
            require constraint { actualPressure >= setPressure - 0.5 and actualPressure <= setPressure + 0.5 }
        }
        requirement def HumidifierPerformanceReq {
            doc /* The humidifier shall maintain outlet air temperature between 25°C and 30°C. */
            attribute outletTemp: Temperature;
            require constraint { outletTemp >= 25.0 and outletTemp <= 30.0 }
        }
        requirement def AlarmResponseTimeReq {
            doc /* The alarm shall be triggered within 2 seconds of detecting a hazardous condition. */
            attribute detectionTime: TimeValue;
            attribute alarmTime: TimeValue;
            require constraint { alarmTime - detectionTime <= 2.0 }
        }
        requirement def BackupBatteryDurationReq {
            doc /* The backup battery shall provide at least 3 hours of therapy during a power outage. */
            attribute batteryDuration: TimeValue;
            require constraint { batteryDuration >= 3.0 }
        }
        requirement def DataLoggingReq {
            doc /* The device shall log therapy data for at least 365 days. */
            attribute storageDays: Integer;
            require constraint { storageDays >= 365 }
        }
        requirement def RampFeatureReq {
            doc /* The ramp feature shall gradually increase pressure over a user-settable duration up to 45 minutes. */
            attribute rampDuration: TimeValue;
            require constraint { rampDuration <= 0.75 }
        }
    }

    import Definitions::*;

    package Usages {
        private import Definitions::*;

        part wallOutlet: WallOutlet;
        part patient: Patient;

        part device: RespiratoryTherapyDevice {
            action rampPressure: RampPressure;
            action detectBreath: DetectBreath;
            action adjustBlower: AdjustBlower;
            action checkAlarms: CheckAlarms { out alarmType; }
            action logSessionData: LogSession;
            action displayData: DisplayData;

            connect airFilter.airOut to blower.airIn;
            connect blower.airOut to humidifier.airIn;
            connect humidifier.airOut to patientCircuit.airIn;
            connect patientCircuit.airOut to patient.airIn;

            connect humidifier.airOut to pressureSensor.airIn;
            connect humidifier.airOut to flowSensor.airIn;

            connect pressureSensor.dataOut to therapyController.sensorIn;
            connect flowSensor.dataOut to therapyController.sensorIn;
            connect therapyController.blowerControl to blower.controlIn;
            connect therapyController.humidifierControl to humidifier.controlIn;
            connect therapyController.alarmOut to alarmManager.sensorIn;
            connect alarmManager.alarmOut to userInterface.alarmIn;
            connect therapyController.uiOut to userInterface.displayIn;
            connect userInterface.controlOut to therapyController.sensorIn;
            connect therapyController.loggerOut to dataLogger.dataIn;

            connect wallOutlet.powerOut to powerManagement.acIn;
            connect backupBattery.powerOut to powerManagement.batteryIn;
            connect powerManagement.powerOut to blower.powerIn;
            connect powerManagement.powerOut to humidifier.powerIn;
            connect powerManagement.powerOut to therapyController.powerIn;
            connect powerManagement.powerOut to alarmManager.powerIn;
            connect powerManagement.powerOut to userInterface.powerIn;
            connect powerManagement.powerOut to dataLogger.powerIn;

            state humidifierStates: HumidifierStates {
                entry; then off;
                state off;
                accept StartTherapy then heating;
                state heating;
                accept when humidifier.actualTemp >= humidifier.targetTemp then maintaining;
                state maintaining;
                accept when humidifier.waterLevel < 50.0 then lowWater;
                state lowWater {
                    do send new RefillWater() to userInterface;
                }
                accept RefillWater then maintaining;
                accept StopTherapy then off;
            }

            state therapyStates: TherapyStates {
                entry; then idle;
                state idle;
                accept StartTherapy then ramping;
                state ramping {
                    do rampPressure;
                }
                accept when therapyController.rampDuration <= 0.0 then active;
                state active {
                    entry detectBreath;
                    do adjustBlower;
                }
                accept StopTherapy then idle;
            }

            state alarmStates: AlarmStates {
                entry; then normal;
                state normal {
                    do checkAlarms;
                }
                accept when checkAlarms.alarmType == "highPressure" then highPressureAlarm;
                accept when checkAlarms.alarmType == "lowPressure" then lowPressureAlarm;
                accept when checkAlarms.alarmType == "disconnect" then disconnectAlarm;
                accept when checkAlarms.alarmType == "apnea" then apneaAlarm;
                state highPressureAlarm {
                    do send new HighPressureAlarm() to userInterface;
                }
                state lowPressureAlarm {
                    do send new LowPressureAlarm() to userInterface;
                }
                state disconnectAlarm {
                    do send new DisconnectAlarm() to userInterface;
                }
                state apneaAlarm {
                    do send new ApneaAlarm() to userInterface;
                }
                accept AcknowledgeAlarm then normal;
            }

            state powerStates: PowerStates {
                entry; then acPower;
                state acPower;
                accept PowerLoss then batteryPower;
                state batteryPower;
                accept PowerRestored then acPower;
            }
        }

        requirement pressureAccuracy: PressureAccuracyReq {
            :>> setPressure = device.therapyController.setPressure;
            :>> actualPressure = device.pressureSensor.pressure;
        }
        requirement humidifierPerformance: HumidifierPerformanceReq {
            :>> outletTemp = device.humidifier.actualTemp;
        }
        requirement alarmResponseTime: AlarmResponseTimeReq {
            :>> detectionTime = device.alarmManager.detectionTime;
            :>> alarmTime = device.alarmManager.alarmTime;
        }
        requirement backupBatteryDuration: BackupBatteryDurationReq {
            :>> batteryDuration = device.powerManagement.batteryDuration;
        }
        requirement dataLogging: DataLoggingReq {
            :>> storageDays = device.dataLogger.storageDays;
        }
        requirement rampFeature: RampFeatureReq {
            :>> rampDuration = device.therapyController.rampDuration;
        }
    }
}
