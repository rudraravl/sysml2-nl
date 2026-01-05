package PhilipsRespironicsRespiratorySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def cmH2O :> PressureValue;
    attribute def BreathsPerMinute :> Real;
    attribute def InspExpirationRatio :> Real;
    attribute def OxygenPercentage :> Real;

    enum def TherapyModeKind {
        cpap;
        biPAP;
        autoTitrating;
        volumeControlled;
        pressureSupport;
    }

    enum def AlarmLevel {
        none;
        advisory;
        caution;
        warning;
        critical;
    }

    item def RespiratoryGas {
        attribute pressure : cmH2O;
        attribute flowRate : VolumeFlowRateValue;
        attribute oxygenConcentration : OxygenPercentage;
        attribute temperature : ThermodynamicTemperatureValue;
        attribute humidity : Real;
    }

    port def GasFlowPort {
        inout gas : RespiratoryGas;
    }

    port def SensorPort {
        out measuredPressure : cmH2O;
        out measuredFlow : VolumeFlowRateValue;
    }

    port def ControlSignalPort {
        in targetPressure : cmH2O;
        in targetFlow : VolumeFlowRateValue;
        out actualPressure : cmH2O;
        out actualFlow : VolumeFlowRateValue;
    }

    part def AirIntakeFilter {
        port inlet : GasFlowPort;
        port outlet : GasFlowPort;
        attribute filterEfficiency : Real;
        attribute replacementInterval : DurationValue;
    }

    part def TurbineBlower {
        port gasIn : GasFlowPort;
        port gasOut : GasFlowPort;
        port controlSignal : ControlSignalPort;
        attribute maxPressure : cmH2O;
        attribute maxFlowRate : VolumeFlowRateValue;
        attribute motorSpeed : Real;
        attribute powerConsumption : PowerValue;

        action generatePressure {
            in targetPressure : cmH2O;
            in targetFlow : VolumeFlowRateValue;
            out deliveredPressure : cmH2O;
            out deliveredFlow : VolumeFlowRateValue;
        }
    }

    part def HeatedHumidifier {
        port gasIn : GasFlowPort;
        port gasOut : GasFlowPort;
        attribute targetHumidity : Real;
        attribute heaterTemperature : ThermodynamicTemperatureValue;
        attribute waterLevel : Real;

        action humidifyGas {
            in dryGas : RespiratoryGas;
            in targetHumidity : Real;
            out humidifiedGas : RespiratoryGas;
        }

        state humidifierStates {
            entry; then idle;

            state idle;
            state heating;
            state maintaining;
            state lowWater;

            transition idle_to_heating
                first idle
                if waterLevel > 10.0
                then heating;

            transition heating_to_maintaining
                first heating
                if heaterTemperature >= 35.0
                then maintaining;

            transition maintaining_to_lowWater
                first maintaining
                if waterLevel < 10.0
                then lowWater;

            transition lowWater_to_idle
                first lowWater
                if waterLevel > 50.0
                then idle;

            transition maintaining_to_idle
                first maintaining
                if waterLevel <= 0.0
                then idle;
        }
    }

    part def PressureSensor {
        port sense : SensorPort;
        attribute measuredPressure : cmH2O;
        attribute accuracy : Real;
        attribute responseTime : DurationValue;

        action measurePressure {
            in gasFlow : RespiratoryGas;
            out pressureReading : cmH2O;
        }
    }

    part def FlowSensor {
        port sense : SensorPort;
        attribute measuredFlow : VolumeFlowRateValue;
        attribute accuracy : Real;
        attribute range : VolumeFlowRateValue;

        action measureFlow {
            in gasFlow : RespiratoryGas;
            out flowReading : VolumeFlowRateValue;
        }
    }

    part def OxygenSensor {
        attribute measuredO2 : OxygenPercentage;
        attribute calibrationDate : String;

        action measureOxygen {
            in gasFlow : RespiratoryGas;
            out oxygenReading : OxygenPercentage;
        }
    }

    part def ExhalationValve {
        port gasIn : GasFlowPort;
        port gasOut : GasFlowPort;
        attribute valvePosition : Real;
        attribute exhalationPressure : cmH2O;

        state valveStates {
            entry; then closed;

            state closed;
            state opening;
            state open;
            state closing;

            transition closed_to_opening
                first closed
                if valvePosition < 0.5
                then opening;

            transition opening_to_open
                first opening
                if valvePosition >= 0.9
                then open;

            transition open_to_closing
                first open
                if valvePosition > 0.5
                then closing;

            transition closing_to_closed
                first closing
                if valvePosition <= 0.1
                then closed;
        }
    }

    part def PatientCircuit {
        port deviceConnection : GasFlowPort;
        port maskConnection : GasFlowPort;
        attribute tubeLength : LengthValue;
        attribute tubeDiameter : LengthValue;
        attribute leakRate : VolumeFlowRateValue;
    }

    part def PatientMask {
        port circuitConnection : GasFlowPort;
        attribute maskType : String;
        attribute cushionSize : String;
        attribute fitQuality : Real;
    }

    part def TherapyController {
        attribute currentMode : TherapyModeKind;
        attribute targetIPAP : cmH2O;
        attribute targetEPAP : cmH2O;
        attribute respiratoryRate : BreathsPerMinute;
        attribute ieRatio : InspExpirationRatio;
        attribute rampTime : DurationValue;
        attribute rampEnabled : Boolean;

        action controlTherapy {
            in mode : TherapyModeKind;
            in measuredPressure : cmH2O;
            in measuredFlow : VolumeFlowRateValue;
            in patientEffort : Boolean;
            out blowerCommand : cmH2O;
            out valveCommand : Real;
        }

        action detectBreath {
            in flowSignal : VolumeFlowRateValue;
            in pressureSignal : cmH2O;
            out breathDetected : Boolean;
            out breathType : String;
        }

        state therapyStates {
            entry; then standby;

            state standby;
            state rampingUp;
            state activeTherapy;
            state paused;
            state alarm;

            transition standby_to_ramping
                first standby
                if rampEnabled
                then rampingUp;

            transition standby_to_active
                first standby
                if not rampEnabled
                then activeTherapy;

            transition ramping_to_active
                first rampingUp
                if targetIPAP > 0.0
                then activeTherapy;

            transition active_to_paused
                first activeTherapy
                if targetIPAP == 0.0
                then paused;

            transition paused_to_active
                first paused
                if targetIPAP > 0.0
                then activeTherapy;

            transition active_to_alarm
                first activeTherapy
                if targetIPAP > 30.0
                then alarm;

            transition alarm_to_standby
                first alarm
                if targetIPAP < 30.0
                then standby;

            transition active_to_standby
                first activeTherapy
                if targetIPAP < 0.0
                then standby;
        }
    }

    part def AlarmManager {
        attribute activeAlarms : AlarmLevel[0..*];
        attribute highPressureLimit : cmH2O;
        attribute lowPressureLimit : cmH2O;
        attribute apneaTimeout : DurationValue;

        action checkAlarms {
            in measuredPressure : cmH2O;
            in measuredFlow : VolumeFlowRateValue;
            in lastBreathTime : DurationValue;
            out alarmStatus : AlarmLevel;
            out alarmMessage : String;
        }

        action evaluatePressureAlarm {
            in pressure : cmH2O;
            out alarmTriggered : Boolean;
        }

        action evaluateApneaAlarm {
            in timeSinceLastBreath : DurationValue;
            out apneaDetected : Boolean;
        }
    }

    part def UserInterface {
        attribute displayBrightness : Real;
        attribute selectedMode : TherapyModeKind;
        attribute displayedPressure : cmH2O;
        attribute displayedLeakRate : VolumeFlowRateValue;

        action displayTherapyData {
            in pressure : cmH2O;
            in flow : VolumeFlowRateValue;
            in tidalVolume : VolumeValue;
            in respiratoryRate : BreathsPerMinute;
        }

        action acceptUserSettings {
            out mode : TherapyModeKind;
            out ipapSetting : cmH2O;
            out epapSetting : cmH2O;
            out rampTimeSetting : DurationValue;
        }
    }

    part def DataLogger {
        attribute sessionStartTime : String;
        attribute totalTherapyHours : DurationValue;
        attribute complianceData : Real[0..*];

        action recordSession {
            in pressureData : cmH2O[*];
            in flowData : VolumeFlowRateValue[*];
            in leakData : VolumeFlowRateValue[*];
            in eventData : String[*];
        }

        action generateComplianceReport {
            in sessionData : Real[*];
            out compliancePercentage : Real;
            out averageUsageHours : DurationValue;
        }
    }

    part def PowerManagement {
        attribute acPowerAvailable : Boolean;
        attribute batteryCharge : Real;
        attribute batteryCapacity : Real;
        attribute powerConsumption : PowerValue;

        state powerStates {
            entry; then acPowered;

            state acPowered;
            state batteryPowered;
            state charging;
            state lowBattery;

            transition ac_to_battery
                first acPowered
                if not acPowerAvailable
                then batteryPowered;

            transition battery_to_ac
                first batteryPowered
                if acPowerAvailable
                then acPowered;

            transition battery_to_lowBattery
                first batteryPowered
                if batteryCharge < 20.0
                then lowBattery;

            transition ac_to_charging
                first acPowered
                if batteryCharge < 100.0
                then charging;

            transition charging_to_ac
                first charging
                if batteryCharge >= 100.0
                then acPowered;
        }
    }

    part def RespironicsDevice {
        doc /* Philips Respironics respiratory therapy device providing 
             * positive airway pressure therapy for patients with sleep apnea
             * and other respiratory disorders through continuous monitoring
             * and adaptive pressure delivery. */

        attribute deviceModel : String;
        attribute serialNumber : String;
        attribute firmwareVersion : String;
        attribute operatingHours : DurationValue;

        part airFilter : AirIntakeFilter {
            attribute :>> filterEfficiency = 0.99;
            attribute :>> replacementInterval = 180.0;
        }

        part blower : TurbineBlower {
            attribute :>> maxPressure = 25.0;
            attribute :>> maxFlowRate = 150.0;
            attribute :>> motorSpeed = 0.0;
        }

        part humidifier : HeatedHumidifier {
            attribute :>> targetHumidity = 85.0;
            attribute :>> heaterTemperature = 37.0;
            attribute :>> waterLevel = 100.0;
        }

        part pressureSensor : PressureSensor {
            attribute :>> accuracy = 0.5;
        }

        part flowSensor : FlowSensor {
            attribute :>> accuracy = 2.0;
        }

        part oxygenSensor : OxygenSensor {
            attribute :>> measuredO2 = 21.0;
        }

        part exhalationValve : ExhalationValve {
            attribute :>> valvePosition = 0.0;
            attribute :>> exhalationPressure = 4.0;
        }

        part controller : TherapyController {
            attribute :>> currentMode = TherapyModeKind::biPAP;
            attribute :>> targetIPAP = 12.0;
            attribute :>> targetEPAP = 4.0;
            attribute :>> respiratoryRate = 15.0;
            attribute :>> ieRatio = 1.5;
            attribute :>> rampTime = 20.0;
            attribute :>> rampEnabled = true;
        }

        part alarmMgr : AlarmManager {
            attribute :>> highPressureLimit = 20.0;
            attribute :>> lowPressureLimit = 2.0;
            attribute :>> apneaTimeout = 20.0;
        }

        part userInterface : UserInterface {
            attribute :>> displayBrightness = 75.0;
            attribute :>> selectedMode = TherapyModeKind::biPAP;
        }

        part dataLogger : DataLogger {
            attribute :>> totalTherapyHours = 0.0;
        }

        part powerMgmt : PowerManagement {
            attribute :>> acPowerAvailable = true;
            attribute :>> batteryCharge = 100.0;
            attribute :>> batteryCapacity = 180.0;
        }

        part patientCircuit : PatientCircuit {
            attribute :>> tubeLength = 1.8;
            attribute :>> tubeDiameter = 0.022;
            attribute :>> leakRate = 5.0;
        }

        part patientMask : PatientMask {
            attribute :>> maskType = "Nasal";
            attribute :>> cushionSize = "Medium";
            attribute :>> fitQuality = 0.95;
        }

        port airIntake : GasFlowPort;
        port patientDelivery : GasFlowPort;

        connection filterToBlower connect airFilter.outlet to blower.gasIn;
        connection blowerToHumidifier connect blower.gasOut to humidifier.gasIn;
        connection humidifierToCircuit connect humidifier.gasOut to patientCircuit.deviceConnection;
        connection circuitToMask connect patientCircuit.maskConnection to patientMask.circuitConnection;

        perform action deliverTherapy {
            first start;
            then merge breathingCycle;

            then action monitorPatient {
                out currentPressure : cmH2O;
                out currentFlow : VolumeFlowRateValue;
                out patientEffort : Boolean;
            }

            then action controllerDecision : controller.controlTherapy {
                in mode = controller.currentMode;
                in measuredPressure = pressureSensor.measuredPressure;
                in measuredFlow = flowSensor.measuredFlow;
                in patientEffort = monitorPatient.patientEffort;
                out blowerCommand : cmH2O;
                out valveCommand : Real;
            }

            then decide;
                if controller.currentMode == TherapyModeKind::biPAP then biPAPCycle;
                if controller.currentMode == TherapyModeKind::cpap then cpapCycle;
                if controller.currentMode == TherapyModeKind::autoTitrating then autoTitratingCycle;

            action biPAPCycle {
                first action detectInhalation;
                then action deliverIPAP {
                    in targetPressure = controller.targetIPAP;
                }
                then action detectExhalation;
                then action deliverEPAP {
                    in targetPressure = controller.targetEPAP;
                }
            }

            action cpapCycle {
                first action maintainConstantPressure {
                    in targetPressure = controller.targetIPAP;
                }
            }

            action autoTitratingCycle {
                first action analyzeBreathing;
                then action adjustPressure {
                    in flowLimitation : Boolean;
                    in snoringDetected : Boolean;
                    out newPressure : cmH2O;
                }
            }

            then action checkSafety : alarmMgr.checkAlarms {
                in measuredPressure = pressureSensor.measuredPressure;
                in measuredFlow = flowSensor.measuredFlow;
                in lastBreathTime = 0.0;
                out alarmStatus : AlarmLevel;
                out alarmMessage : String;
            }

            then decide;
                if checkSafety.alarmStatus == AlarmLevel::critical then handleCriticalAlarm;
                if checkSafety.alarmStatus == AlarmLevel::none then breathingCycle;

            action handleCriticalAlarm {
                in alarmType : AlarmLevel;
            }
            then breathingCycle;

            then action logData : dataLogger.recordSession;

            then breathingCycle;
        }
    }

    requirement <'REQ-RESP-001'> primaryTherapyFunction {
        doc /* The Philips Respironics device shall provide continuous positive
             * airway pressure therapy to patients with obstructive sleep apnea
             * by delivering pressurized, humidified air through a patient interface
             * to maintain airway patency during sleep. */
        subject device : RespironicsDevice;
    }

    requirement <'REQ-RESP-002'> pressureDeliveryRange {
        doc /* The device shall deliver therapeutic pressure in the range of
             * 4 to 25 cmH2O with accuracy of ±0.5 cmH2O. */
        subject device : RespironicsDevice;
        assert constraint {
            device.blower.maxPressure >= 25.0 and
            device.pressureSensor.accuracy <= 0.5
        }
    }

    requirement <'REQ-RESP-003'> therapyModeSupport {
        doc /* The device shall support multiple therapy modes including CPAP,
             * BiPAP, Auto-Titrating CPAP, Volume-Controlled, and Pressure Support
             * to accommodate different patient needs and prescriptions. */
        subject controller :>> RespironicsDevice::controller;
    }

    requirement <'REQ-RESP-004'> humidificationCapability {
        doc /* The device shall provide heated humidification with adjustable
             * humidity levels to prevent airway drying and improve patient comfort. */
        subject humidifier :>> RespironicsDevice::humidifier;
        assert constraint {
            humidifier.targetHumidity >= 50.0 and
            humidifier.targetHumidity <= 100.0
        }
    }

    requirement <'REQ-RESP-005'> alarmSystem {
        doc /* The device shall provide comprehensive alarm monitoring for
             * high/low pressure, apnea detection, power failure, circuit disconnect,
             * and system malfunction with prioritized alerts. */
        subject alarmMgr :>> RespironicsDevice::alarmMgr;
    }

    requirement <'REQ-RESP-006'> batteryBackup {
        doc /* The device shall include battery backup capable of maintaining
             * therapy for at least 3 hours during AC power interruption. */
        subject powerMgmt :>> RespironicsDevice::powerMgmt;
        assert constraint {
            powerMgmt.batteryCapacity >= 180.0
        }
    }

    requirement <'REQ-RESP-007'> dataLogging {
        doc /* The device shall record therapy session data including pressure,
             * flow, leak rate, events, and usage hours for compliance monitoring
             * and clinical review. */
        subject dataLogger :>> RespironicsDevice::dataLogger;
    }

    part respironicsSystem : RespironicsDevice {
        attribute :>> deviceModel = "DreamStation 2";
        attribute :>> serialNumber = "DS2-2024-12345";
        attribute :>> firmwareVersion = "2.5.1";
        attribute :>> operatingHours = 0.0;
    }

    satisfy primaryTherapyFunction by respironicsSystem;
    satisfy pressureDeliveryRange by respironicsSystem;
    satisfy therapyModeSupport by respironicsSystem.controller;
    satisfy humidificationCapability by respironicsSystem.humidifier;
    satisfy alarmSystem by respironicsSystem.alarmMgr;
    satisfy batteryBackup by respironicsSystem.powerMgmt;
    satisfy dataLogging by respironicsSystem.dataLogger;
}
