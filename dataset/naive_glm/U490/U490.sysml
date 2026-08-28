package DryRunningProtectionSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;
    import ISQThermodynamics::*;

    // ---------- Value Types with Units ----------

    attribute def LiterPerMinute :> Unit {
        doc : "Liters per minute volumetric flow unit.";
    }

    attribute def Bar :> Unit {
        doc : "Bar pressure unit.";
    }

    attribute def DegCelsius :> Unit {
        doc : "Degree Celsius temperature unit.";
    }

    attribute def FlowRate :> Real {
        doc : "Volumetric flow rate of liquid.";
        unit LiterPerMinute;
    }

    attribute def LiquidPressure :> Real {
        doc : "Gauge pressure of liquid in bar.";
        unit Bar;
    }

    attribute def LiquidTemperature :> Real {
        doc : "Temperature of liquid in degrees Celsius.";
        unit DegCelsius;
    }

    attribute def ElapsedTime :> Real {
        doc : "Elapsed warning time in seconds.";
        unit 's';
    }

    // ---------- Item and Signal Definitions ----------

    item def Liquid {
        doc : "Generic process liquid protected by the dry-running system.";
    }

    item def LiquidStream {
        doc : "Flowing liquid in the piping system.";
        : liquid : Liquid;
    }

    item def FlowReading {
        doc : "Real-time flow measurement signal.";
        flow : FlowRate;
    }

    item def PressureReading {
        doc : "Real-time pressure measurement signal.";
        pressure : LiquidPressure;
    }

    item def TemperatureReading {
        doc : "Real-time temperature measurement signal.";
        temperature : LiquidTemperature;
    }

    item def PumpStatus {
        doc : "Pump operating status reported to controller.";
        running : Boolean;
    }

    // ---------- Command and State Enums ----------

    enum def PumpCommand {
        doc : "Commanded operating state of the pump.";
        START;
        STOP;
    }

    enum def ValveCommand {
        doc : "Commanded operating state of the isolation valve.";
        OPEN;
        CLOSE;
    }

    enum def AlarmLevel {
        doc : "Alarm condition level.";
        OFF;
        WARNING;
        CRITICAL;
    }

    enum def OperationalMode {
        doc : "Top-level operational mode of the protection system.";
        NORMAL;
        WARNING;
        SHUTDOWN;
    }

    // ---------- Port Definitions ----------

    port def LiquidFlowPort {
        doc : "Port carrying liquid flow between connected parts.";
        out item stream : LiquidStream;
    }

    port def FlowSignalPort {
        doc : "Output port carrying flow measurements.";
        out item reading : FlowReading;
    }

    port def PressureSignalPort {
        doc : "Output port carrying pressure measurements.";
        out item reading : PressureReading;
    }

    port def TemperatureSignalPort {
        doc : "Output port carrying temperature measurements.";
        out item reading : TemperatureReading;
    }

    port def PumpCmdPort {
        doc : "Port carrying pump commands from controller.";
        in item command : PumpCommand;
    }

    port def ValveCmdPort {
        doc : "Port carrying valve commands from controller.";
        in item command : ValveCommand;
    }

    port def AlarmCmdPort {
        doc : "Port carrying alarm commands from controller.";
        in item command : AlarmLevel;
    }

    port def PumpFeedbackPort {
        doc : "Port carrying pump status feedback to controller.";
        out item status : PumpStatus;
    }

    // ---------- Requirements ----------

    requirement def DryRunProtectionRequirement {
        doc : "The system shall protect the liquid pump from damage caused by operation without sufficient fluid.";
    }

    requirement def ContinuousMonitoringRequirement {
        doc : "The controller shall continuously monitor flow, pressure, and temperature.";
        requirement {
            subject : controller;
            predicate : (monitorFlow == true) and (monitorPressure == true) and (monitorTemperature == true);
        }
    }

    requirement def LowFlowWarningRequirement {
        doc : "If flow drops below 5.0 L/min, the system shall enter warning state.";
        constraint { flow < 5.0 [LiterPerMinute]; }
    }

    requirement def LowPressureWarningRequirement {
        doc : "If pressure drops below 1.0 bar, the system shall enter warning state.";
        constraint { pressure < 1.0 [Bar]; }
    }

    requirement def WarningPersistenceRequirement {
        doc : "If warning conditions persist for a few seconds, the controller shall initiate protective shutdown.";
        constraint { warningDuration > 0 [s]; }
    }

    requirement def HighTemperatureShutdownRequirement {
        doc : "If liquid temperature exceeds 80 degC, the controller shall trigger an immediate shutdown.";
        constraint { temperature > 80.0 [DegCelsius]; }
    }

    requirement def CoordinatedShutdownRequirement {
        doc : "Shutdown shall stop the pump, close the isolation valve, and activate the alarm.";
        requirement {
            subject : controller;
            predicate : (pumpCommand == PumpCommand::STOP) and (valveCommand == ValveCommand::CLOSE) and (alarmCommand == AlarmLevel::CRITICAL);
        }
    }

    requirement def AlarmIndicationRequirement {
        doc : "The alarm unit shall provide both visual and audible alerts upon activation.";
        requirement {
            subject : alarmUnit;
            predicate : (visualActive == true) and (audibleActive == true);
        }
    }

    // ---------- Part Definitions ----------

    part def LiquidPump {
        doc : "Centrifugal liquid pump protected by the dry-running system.";
        attribute isRunning : Boolean = false;
        attribute nominalFlow : FlowRate = 20.0 [LiterPerMinute];
        attribute nominalPressure : LiquidPressure = 3.0 [Bar];

        port flowOut : LiquidFlowPort;
        port commandIn : PumpCmdPort;
        port feedbackOut : PumpFeedbackPort;

        action def startPump {
            doc : "Energize the pump and begin liquid delivery.";
        }

        action def stopPump {
            doc : "De-energize the pump and cease liquid delivery.";
        }

        action def generateFlow {
            doc : "Continuously produce a liquid stream when running.";
            if (isRunning) {
                flowOut.stream :>> stream;
            }
        }

        action handleCommand : PumpCommand {
            when commandIn.command {
                if (commandIn.command == PumpCommand::START) {
                    then startPump;
                    isRunning = true;
                } else {
                    then stopPump;
                    isRunning = false;
                }
            }
        }

        action reportStatus {
            feedbackOut.status.running = isRunning;
        }
    }

    part def FlowSensor {
        doc : "Measures volumetric flow rate of liquid.";
        attribute measuredFlow : FlowRate = 0.0 [LiterPerMinute];
        attribute minDetectable : FlowRate = 0.1 [LiterPerMinute];
        attribute maxDetectable : FlowRate = 100.0 [LiterPerMinute];

        port liquidIn : LiquidFlowPort;
        port signalOut : FlowSignalPort;

        action def sample {
            doc : "Sample the incoming liquid stream and produce a flow reading.";
            measuredFlow = liquidIn.stream.flow;
            signalOut.reading.flow = measuredFlow;
        }

        action measureAndEmit {
            doc : "Continuously measure flow and emit readings.";
            while (true) {
                then sample;
            }
        }
    }

    part def PressureSensor {
        doc : "Measures gauge pressure of liquid.";
        attribute measuredPressure : LiquidPressure = 0.0 [Bar];
        attribute minDetectable : LiquidPressure = 0.0 [Bar];
        attribute maxDetectable : LiquidPressure = 25.0 [Bar];

        port liquidIn : LiquidFlowPort;
        port signalOut : PressureSignalPort;

        action def sample {
            doc : "Sample the incoming liquid stream and produce a pressure reading.";
            measuredPressure = liquidIn.stream.pressure;
            signalOut.reading.pressure = measuredPressure;
        }

        action measureAndEmit {
            doc : "Continuously measure pressure and emit readings.";
            while (true) {
                then sample;
            }
        }
    }

    part def TemperatureSensor {
        doc : "Measures temperature of liquid.";
        attribute measuredTemp : LiquidTemperature = 25.0 [DegCelsius];
        attribute minDetectable : LiquidTemperature = -20.0 [DegCelsius];
        attribute maxDetectable : LiquidTemperature = 150.0 [DegCelsius];

        port liquidIn : LiquidFlowPort;
        port signalOut : TemperatureSignalPort;

        action def sample {
            doc : "Sample the incoming liquid stream and produce a temperature reading.";
            measuredTemp = liquidIn.stream.temperature;
            signalOut.reading.temperature = measuredTemp;
        }

        action measureAndEmit {
            doc : "Continuously measure temperature and emit readings.";
            while (true) {
                then sample;
            }
        }
    }

    part def IsolationValve {
        doc : "Solenoid-actuated isolation valve to prevent backflow during shutdown.";
        attribute isOpen : Boolean = true;
        attribute strokeTime : ElapsedTime = 0.5 [s];

        port liquidIn : LiquidFlowPort;
        port liquidOut : LiquidFlowPort;
        port commandIn : ValveCmdPort;

        action def open {
            doc : "Open the isolation valve.";
            isOpen = true;
        }

        action def close {
            doc : "Close the isolation valve.";
            isOpen = false;
        }

        action handleCommand : ValveCommand {
            when commandIn.command {
                if (commandIn.command == ValveCommand::OPEN) {
                    then open;
                } else {
                    then close;
                }
            }
        }

        action passFlow {
            doc : "Pass liquid through when open.";
            if (isOpen) {
                liquidOut.stream = liquidIn.stream;
            }
        }
    }

    part def AlarmUnit {
        doc : "Visual and audible alarm indicator unit.";
        attribute visualActive : Boolean = false;
        attribute audibleActive : Boolean = false;

        port commandIn : AlarmCmdPort;

        action def activateVisual {
            doc : "Activate the visual alarm indicator.";
            visualActive = true;
        }

        action def activateAudible {
            doc : "Activate the audible alarm indicator.";
            audibleActive = true;
        }

        action def deactivateAll {
            doc : "Deactivate all alarm indicators.";
            visualActive = false;
            audibleActive = false;
        }

        action handleCommand : AlarmLevel {
            when commandIn.command {
                if (commandIn.command == AlarmLevel::OFF) {
                    then deactivateAll;
                } else {
                    then activateVisual;
                    then activateAudible;
                }
            }
        }
    }

    // ---------- Controller with State Machine ----------

    part def ProtectionController {
        doc : "Central protection controller that monitors sensor data and coordinates protective actions.";

        attribute monitorFlow : Boolean = true;
        attribute monitorPressure : Boolean = true;
        attribute monitorTemperature : Boolean = true;

        attribute currentFlow : FlowRate = 20.0 [LiterPerMinute];
        attribute currentPressure : LiquidPressure = 3.0 [Bar];
        attribute currentTemp : LiquidTemperature = 25.0 [DegCelsius];

        attribute lowFlowThreshold : FlowRate = 5.0 [LiterPerMinute];
        attribute lowPressureThreshold : LiquidPressure = 1.0 [Bar];
        attribute highTempThreshold : LiquidTemperature = 80.0 [DegCelsius];

        attribute warningTimeout : ElapsedTime = 3.0 [s];
        attribute warningElapsed : ElapsedTime = 0.0 [s];
        attribute mode : OperationalMode = OperationalMode::NORMAL;

        attribute lastPumpCommand : PumpCommand = PumpCommand::START;
        attribute lastValveCommand : ValveCommand = ValveCommand::OPEN;
        attribute lastAlarmCommand : AlarmLevel = AlarmLevel::OFF;

        port flowInput : ~FlowSignalPort;
        port pressureInput : ~PressureSignalPort;
        port tempInput : ~TemperatureSignalPort;
        port pumpCmdOut : PumpCmdPort;
        port valveCmdOut : ValveCmdPort;
        port alarmCmdOut : AlarmCmdPort;
        port pumpFeedbackIn : ~PumpFeedbackPort;

        action def ingestSensors {
            doc : "Update internal sensor cache from connected sensor ports.";
            currentFlow = flowInput.reading.flow;
            currentPressure = pressureInput.reading.pressure;
            currentTemp = tempInput.reading.temperature;
        }

        action def issueNormalCommands {
            doc : "Issue normal operating commands.";
            lastPumpCommand = PumpCommand::START;
            lastValveCommand = ValveCommand::OPEN;
            lastAlarmCommand = AlarmLevel::OFF;
            pumpCmdOut.command = lastPumpCommand;
            valveCmdOut.command = lastValveCommand;
            alarmCmdOut.command = lastAlarmCommand;
        }

        action def issueWarningCommands {
            doc : "Issue warning operating commands (continue running, light alarm).";
            lastPumpCommand = PumpCommand::START;
            lastValveCommand = ValveCommand::OPEN;
            lastAlarmCommand = AlarmLevel::WARNING;
            pumpCmdOut.command = lastPumpCommand;
            valveCmdOut.command = lastValveCommand;
            alarmCmdOut.command = lastAlarmCommand;
        }

        action def issueShutdownCommands {
            doc : "Issue coordinated shutdown commands.";
            lastPumpCommand = PumpCommand::STOP;
            lastValveCommand = ValveCommand::CLOSE;
            lastAlarmCommand = AlarmLevel::CRITICAL;
            pumpCmdOut.command = lastPumpCommand;
            valveCmdOut.command = lastValveCommand;
            alarmCmdOut.command = lastAlarmCommand;
        }

        action def resetWarningTimer {
            warningElapsed = 0.0 [s];
        }

        action def advanceWarningTimer {
            warningElapsed = warningElapsed + 1.0 [s];
        }

        // State Machine

        state protectionStateMachine {
            doc : "Controller operational state machine.";

            state Normal {
                doc : "Normal operating state; pump runs, valve open, alarm off.";
                entry {
                    then resetWarningTimer;
                    then issueNormalCommands;
                }
                do {
                    while (true) {
                        then ingestSensors;
                    }
                }
            }

            state Warning {
                doc : "Warning state; low flow or low pressure detected but not yet persistent.";
                entry {
                    then issueWarningCommands;
                }
                do {
                    while (true) {
                        then ingestSensors;
                        then advanceWarningTimer;
                    }
                }
            }

            state Shutdown {
                doc : "Protective shutdown state; pump stopped, valve closed, alarm active.";
                entry {
                    then issueShutdownCommands;
                }
                do {
                    while (true) {
                        then ingestSensors;
                    }
                }
            }

            transition tr_NormalToWarning {
                doc : "Enter warning when low-flow or low-pressure condition is detected.";
                from Normal;
                to Warning;
                guard { (currentFlow < lowFlowThreshold) or (currentPressure < lowPressureThreshold); }
            }

            transition tr_NormalToShutdown {
                doc : "Immediate shutdown when liquid temperature exceeds the high-temperature threshold.";
                from Normal;
                to Shutdown;
                guard { currentTemp > highTempThreshold; }
            }

            transition tr_WarningToShutdown {
                doc : "Escalate from warning to shutdown when warning conditions persist beyond timeout.";
                from Warning;
                to Shutdown;
                guard { warningElapsed >= warningTimeout; }
            }

            transition tr_WarningToShutdownCritical {
                doc : "Escalate from warning to shutdown when a high-temperature condition occurs during warning.";
                from Warning;
                to Shutdown;
                guard { currentTemp > highTempThreshold; }
            }

            transition tr_WarningToNormal {
                doc : "Return to normal when warning conditions clear.";
                from Warning;
                to Normal;
                guard { (currentFlow >= lowFlowThreshold) and (currentPressure >= lowPressureThreshold); }
            }

            transition tr_ShutdownToNormal {
                doc : "Recover from shutdown only after all conditions have returned to normal and operator reset.";
                from Shutdown;
                to Normal;
                guard {
                    (currentFlow >= lowFlowThreshold)
                    and (currentPressure >= lowPressureThreshold)
                    and (currentTemp <= highTempThreshold)
                    and (pumpFeedbackIn.status.running == false);
                }
            }
        }

        action runController {
            doc : "Top-level controller execution.";
            then protectionStateMachine;
        }
    }

    // ---------- Top-Level Assembly ----------

    part def DryRunningProtectionSystem {
        doc : "Complete dry-running protection system assembly.";

        satisfy DryRunProtectionRequirement;
        satisfy ContinuousMonitoringRequirement;
        satisfy LowFlowWarningRequirement;
        satisfy LowPressureWarningRequirement;
        satisfy WarningPersistenceRequirement;
        satisfy HighTemperatureShutdownRequirement;
        satisfy CoordinatedShutdownRequirement;
        satisfy AlarmIndicationRequirement;

        part pump : LiquidPump {
            doc : "The protected liquid pump.";
        }

        part isolationValve : IsolationValve {
            doc : "Isolation valve preventing backflow during shutdown.";
        }

        part flowSensor : FlowSensor {
            doc : "Flow measurement sensor.";
        }

        part pressureSensor : PressureSensor {
            doc : "Pressure measurement sensor.";
        }

        part temperatureSensor : TemperatureSensor {
            doc : "Temperature measurement sensor.";
        }

        part controller : ProtectionController {
            doc : "Central protection controller.";
        }

        part alarmUnit : AlarmUnit {
            doc : "Visual and audible alarm unit.";
        }

        // Liquid piping connections
        connection pumpToValve connect pump.flowOut to isolationValve.liquidIn;
        connection valveToFlowSensor connect isolationValve.liquidOut to flowSensor.liquidIn;
        connection valveToPressureSensor connect isolationValve.liquidOut to pressureSensor.liquidIn;
        connection valveToTempSensor connect isolationValve.liquidOut to temperatureSensor.liquidIn;

        // Sensor signal connections
        connection flowSignal connect flowSensor.signalOut to controller.flowInput;
        connection pressureSignal connect pressureSensor.signalOut to controller.pressureInput;
        connection tempSignal connect temperatureSensor.signalOut to controller.tempInput;

        // Command connections
        connection pumpCommand connect controller.pumpCmdOut to pump.commandIn;
        connection valveCommand connect controller.valveCmdOut to isolationValve.commandIn;
        connection alarmCommand connect controller.alarmCmdOut to alarmUnit.commandIn;

        // Pump feedback connection
        connection pumpFeedback connect pump.feedbackOut to controller.pumpFeedbackIn;

        // System-level initial action
        action initialize {
            doc : "Initialize the dry-running protection system into normal operation.";
            then controller.runController;
        }
    }
}
