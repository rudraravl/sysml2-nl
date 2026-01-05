package DryRunningProtectionSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def FlowRateValue {
        attribute magnitude : Real;
        attribute unit : String = "L/min";
    }

    attribute def PressureValue {
        attribute magnitude : Real;
        attribute unit : String = "bar";
    }

    attribute def TemperatureValue {
        attribute magnitude : Real;
        attribute unit : String = "degC";
    }

    attribute def TimeValue {
        attribute magnitude : Real;
        attribute unit : String = "s";
    }

    enum def SystemState {
        normal;
        warning;
        shutdown;
        fault;
    }

    enum def PumpState {
        running;
        stopped;
        protected;
    }

    item def Liquid {
        attribute flowRate : FlowRateValue;
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
    }

    port def LiquidPort {
        in item liquid : Liquid;
    }

    port def SensorPort {
        out flowReading : FlowRateValue;
        out pressureReading : PressureValue;
        out temperatureReading : TemperatureValue;
    }

    port def ControlPort {
        in shutdownCommand : Boolean;
        in warningCommand : Boolean;
        out statusFeedback : SystemState;
    }

    part def FlowSensor {
        out port sensorOutput : SensorPort {
            out :>> flowReading : FlowRateValue;
        }
        attribute measurementAccuracy : Real = 0.02;
        attribute responseTime : TimeValue {
            attribute :>> magnitude = 0.1;
        }
    }

    part def PressureSensor {
        out port sensorOutput : SensorPort {
            out :>> pressureReading : PressureValue;
        }
        attribute measurementAccuracy : Real = 0.01;
        attribute responseTime : TimeValue {
            attribute :>> magnitude = 0.05;
        }
    }

    part def TemperatureSensor {
        out port sensorOutput : SensorPort {
            out :>> temperatureReading : TemperatureValue;
        }
        attribute measurementAccuracy : Real = 0.5;
        attribute responseTime : TimeValue {
            attribute :>> magnitude = 0.5;
        }
    }

    part def ProtectionController {
        in port flowInput {
            in flowData : FlowRateValue;
        }
        in port pressureInput {
            in pressureData : PressureValue;
        }
        in port temperatureInput {
            in tempData : TemperatureValue;
        }
        out port controlOutput : ControlPort {
            out :>> shutdownCommand : Boolean;
            out :>> warningCommand : Boolean;
            out :>> statusFeedback : SystemState;
        }

        attribute currentState : SystemState = SystemState::normal;
        attribute minFlowThreshold : FlowRateValue {
            attribute :>> magnitude = 5.0;
        }
        attribute minPressureThreshold : PressureValue {
            attribute :>> magnitude = 1.0;
        }
        attribute maxTemperatureThreshold : TemperatureValue {
            attribute :>> magnitude = 80.0;
        }
        attribute shutdownDelayTime : TimeValue {
            attribute :>> magnitude = 3.0;
        }
        attribute warningDelayTime : TimeValue {
            attribute :>> magnitude = 1.0;
        }

        state protectionStateMachine {
            entry; then normalOperation;

            state normalOperation;
            then monitoringLoop;

            state monitoringLoop;
            then decide;
                if flowInput.flowData.magnitude < minFlowThreshold.magnitude or 
                   pressureInput.pressureData.magnitude < minPressureThreshold.magnitude then warningState;
                if temperatureInput.tempData.magnitude > maxTemperatureThreshold.magnitude then immediateShutdown;
                if flowInput.flowData.magnitude >= minFlowThreshold.magnitude and 
                   pressureInput.pressureData.magnitude >= minPressureThreshold.magnitude and
                   temperatureInput.tempData.magnitude <= maxTemperatureThreshold.magnitude then normalOperation;

            state warningState;
            then decide;
                if flowInput.flowData.magnitude >= minFlowThreshold.magnitude and 
                   pressureInput.pressureData.magnitude >= minPressureThreshold.magnitude then normalOperation;
                else delayedShutdown;

            state delayedShutdown;
            then faultState;

            state immediateShutdown;
            then faultState;

            state faultState;
            then done;
        }
    }

    part def Pump {
        in port liquidInlet : LiquidPort;
        out port liquidOutlet : LiquidPort;
        in port control : ControlPort {
            in :>> shutdownCommand : Boolean;
        }

        attribute operatingState : PumpState = PumpState::running;
        attribute ratedFlowRate : FlowRateValue {
            attribute :>> magnitude = 100.0;
        }
        attribute ratedPressure : PressureValue {
            attribute :>> magnitude = 5.0;
        }
        attribute motorPower : Real = 2.2;

        action def StartPump;
        action def StopPump;
        action def ProtectPump;
    }

    part def IsolationValve {
        in port control {
            in closeCommand : Boolean;
        }
        attribute position : Real = 1.0;
        attribute isClosed : Boolean = false;

        action def CloseValve;
        action def OpenValve;
    }

    part def AlarmUnit {
        in port alarmInput {
            in warningActive : Boolean;
            in shutdownActive : Boolean;
        }
        attribute visualAlarmActive : Boolean = false;
        attribute audibleAlarmActive : Boolean = false;

        action def ActivateWarningAlarm;
        action def ActivateShutdownAlarm;
        action def DeactivateAlarms;
    }

    action def MonitorDryRunConditions {
        in flowRate : FlowRateValue;
        in pressure : PressureValue;
        in temperature : TemperatureValue;
        in minFlow : FlowRateValue;
        in minPressure : PressureValue;
        in maxTemp : TemperatureValue;
        out isDryRunning : Boolean;
        out isOverheating : Boolean;
        out requiresShutdown : Boolean;

        first start;
        then action checkFlow {
            out lowFlow : Boolean = flowRate.magnitude < minFlow.magnitude;
        }
        then action checkPressure {
            out lowPressure : Boolean = pressure.magnitude < minPressure.magnitude;
        }
        then action checkTemperature {
            out highTemp : Boolean = temperature.magnitude > maxTemp.magnitude;
        }
        then action evaluateConditions {
            assign isDryRunning = checkFlow.lowFlow or checkPressure.lowPressure;
            assign isOverheating = checkTemperature.highTemp;
            assign requiresShutdown = isDryRunning or isOverheating;
        }
        then done;
    }

    action def ExecuteProtectionSequence {
        in shutdownRequired : Boolean;
        out pumpStopped : Boolean;
        out valveClosed : Boolean;
        out alarmActivated : Boolean;

        first start;
        then decide;
            if shutdownRequired then performShutdown;
            else monitorContinue;

        action performShutdown {
            first action stopPumpAction {
                assign pumpStopped = true;
            }
            then action closeValveAction {
                assign valveClosed = true;
            }
            then action activateAlarmAction {
                assign alarmActivated = true;
            }
        }
        then done;

        action monitorContinue {
            assign pumpStopped = false;
            assign valveClosed = false;
            assign alarmActivated = false;
        }
        then done;
    }

    part dryRunProtectionSystem {
        attribute systemIdentifier : String = "DRP-SYS-001";

        part flowSensor : FlowSensor {
            attribute :>> measurementAccuracy = 0.02;
        }

        part pressureSensor : PressureSensor {
            attribute :>> measurementAccuracy = 0.01;
        }

        part temperatureSensor : TemperatureSensor {
            attribute :>> measurementAccuracy = 0.5;
        }

        part controller : ProtectionController {
            attribute :>> currentState = SystemState::normal;
        }

        part pump : Pump {
            attribute :>> operatingState = PumpState::running;
            attribute :>> motorPower = 2.2;
        }

        part isolationValve : IsolationValve {
            attribute :>> position = 1.0;
            attribute :>> isClosed = false;
        }

        part alarmUnit : AlarmUnit {
            attribute :>> visualAlarmActive = false;
            attribute :>> audibleAlarmActive = false;
        }

        connection flowMonitoring connect 
            flowSensor.sensorOutput.flowReading to controller.flowInput.flowData;

        connection pressureMonitoring connect 
            pressureSensor.sensorOutput.pressureReading to controller.pressureInput.pressureData;

        connection temperatureMonitoring connect 
            temperatureSensor.sensorOutput.temperatureReading to controller.temperatureInput.tempData;

        connection pumpControl connect 
            controller.controlOutput.shutdownCommand to pump.control.shutdownCommand;

        connection valveControl connect 
            controller.controlOutput.shutdownCommand to isolationValve.control.closeCommand;

        connection warningAlarm connect 
            controller.controlOutput.warningCommand to alarmUnit.alarmInput.warningActive;

        connection shutdownAlarm connect 
            controller.controlOutput.shutdownCommand to alarmUnit.alarmInput.shutdownActive;
    }

    requirement <'REQ-DRP-001'> primaryProtectionFunction {
        doc /* The dry running protection system shall automatically detect 
             * and prevent pump operation under dry running conditions by 
             * monitoring flow rate, pressure, and temperature to avoid 
             * equipment damage and ensure safe operation.
             */
        subject system :>> dryRunProtectionSystem;
    }

    requirement <'REQ-DRP-002'> flowRateMonitoring {
        doc /* The system shall continuously monitor liquid flow rate and 
             * detect when flow falls below 5.0 L/min threshold.
             */
        subject system :>> dryRunProtectionSystem;
        assert constraint {
            system.flowSensor.sensorOutput.flowReading.magnitude >= system.controller.minFlowThreshold.magnitude
        }
    }

    requirement <'REQ-DRP-003'> pressureMonitoring {
        doc /* The system shall monitor inlet pressure and detect when 
             * pressure falls below 1.0 bar indicating dry running.
             */
        subject system :>> dryRunProtectionSystem;
        assert constraint {
            system.pressureSensor.sensorOutput.pressureReading.magnitude >= system.controller.minPressureThreshold.magnitude
        }
    }

    requirement <'REQ-DRP-004'> temperatureProtection {
        doc /* The system shall monitor temperature and initiate immediate 
             * shutdown if temperature exceeds 80°C.
             */
        subject system :>> dryRunProtectionSystem;
        assert constraint {
            system.temperatureSensor.sensorOutput.temperatureReading.magnitude <= system.controller.maxTemperatureThreshold.magnitude
        }
    }

    requirement <'REQ-DRP-005'> shutdownResponse {
        doc /* Upon detecting dry running conditions, the system shall 
             * issue warning within 1 second and execute shutdown within 
             * 3 seconds if conditions persist.
             */
        subject system :>> dryRunProtectionSystem;
        assert constraint {
            system.controller.shutdownDelayTime.magnitude <= 3.0
        }
    }

    requirement <'REQ-DRP-006'> valveIsolation {
        doc /* The system shall close the isolation valve when shutdown 
             * is executed to prevent backflow and further damage.
             */
        subject valve :>> dryRunProtectionSystem.isolationValve;
    }

    requirement <'REQ-DRP-007'> alarmNotification {
        doc /* The system shall activate visual and audible alarms when 
             * dry running conditions are detected and during shutdown.
             */
        subject alarm :>> dryRunProtectionSystem.alarmUnit;
    }

    satisfy primaryProtectionFunction by dryRunProtectionSystem;
    satisfy flowRateMonitoring by dryRunProtectionSystem.controller;
    satisfy pressureMonitoring by dryRunProtectionSystem.controller;
    satisfy temperatureProtection by dryRunProtectionSystem.controller;
    satisfy shutdownResponse by dryRunProtectionSystem.controller;
    satisfy valveIsolation by dryRunProtectionSystem.isolationValve;
    satisfy alarmNotification by dryRunProtectionSystem.alarmUnit;
}
