package HypothermiaCapSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ---- Value Types ----

    value def TemperatureValue :> Real {
        unit '°C';
    }

    value def PressureValue :> Real {
        unit 'kPa';
    }

    value def FlowRateValue :> Real {
        unit 'L/min';
    }

    value def PowerValue :> Real {
        unit 'W';
    }

    value def DurationValue :> Real {
        unit 'min';
    }

    // ---- Item Definitions ----

    item def Coolant {
        attribute density : Real = 1.05 [kg/L];
        attribute specificHeat : Real = 3.5 [kJ/(kg*K)];
        attribute viscosity : Real = 0.002 [Pa*s];
    }

    item def ScalpTemperatureReading {
        attribute value : TemperatureValue;
        attribute timestamp : Real;
    }

    item def PressureReading {
        attribute value : PressureValue;
        attribute timestamp : Real;
    }

    item def ControlCommand {
        attribute pumpSpeed : Real = 0.0;
        attribute coolingPower : PowerValue;
        attribute valvePosition : Real = 0.5;
    }

    item def TreatmentPlan {
        attribute targetMin : TemperatureValue = 18 [°C];
        attribute targetMax : TemperatureValue = 22 [°C];
        attribute safetyMin : TemperatureValue = 15 [°C];
        attribute sessionDuration : DurationValue = 120 [min];
        attribute maxPressure : PressureValue = 15 [kPa];
    }

    item def AlarmSignal {
        attribute severity : Integer;
        attribute message : String;
        attribute timestamp : Real;
    }

    // ---- Port Definitions ----

    port def CoolantPort {
        attribute flowDirection : String;
        out item coolantOut : Coolant;
        in item coolantIn : Coolant;
    }

    port def SignalPort {
        out item signalOut;
        in item signalIn;
    }

    port def CommandPort {
        out item commandOut : ControlCommand;
        in item feedbackIn;
    }

    // ---- Part Definitions ----

    part def TherapeuticHypothermiaSystem {

        part controlConsole : ControlConsole;

        part wearableCap : WearableCap;

        connection coolantCircuit : CoolantFlow connect
            controlConsole.coolantSupply to wearableCap.coolantInlet,
            wearableCap.coolantOutlet to controlConsole.coolantReturn;

        connection tempFeedback : SignalLink connect
            wearableCap.scalpSensor.dataOut to controlConsole.controller.sensorIn;

        connection pressureFeedback : SignalLink connect
            wearableCap.pressureSensor.dataOut to controlConsole.controller.pressureIn;

        connection commandLink : CommandLink connect
            controlConsole.controller.commandOut to wearableCap.actuatorInterface.commandIn;

        connection alarmLink : SignalLink connect
            controlConsole.controller.alarmOut to controlConsole.displayPanel.alarmIn;

        connection displayLink : SignalLink connect
            controlConsole.controller.statusOut to controlConsole.displayPanel.statusIn;

        requirement override {
            subject system : TherapeuticHypothermiaSystem;
            objective {
                doc /* The system shall prevent chemotherapy-induced alopecia by maintaining scalp temperature in the therapeutic window. */
            }
        }
    }

    part def ControlConsole {

        part pump : CirculationPump;

        part coolingUnit : CoolingUnit;

        part controller : ControlModule;

        part displayPanel : DisplayPanel;

        part reservoir : CoolantReservoir;

        port coolantSupply : CoolantPort;
        port coolantReturn : CoolantPort;

        connection pumpToCooling : CoolantFlow connect
            pump.outletPort to coolingUnit.inletPort;

        connection coolingToSupply : CoolantFlow connect
            coolingUnit.outletPort to coolantSupply;

        connection returnToReservoir : CoolantFlow connect
            coolantReturn to reservoir.inletPort;

        connection reservoirToPump : CoolantFlow connect
            reservoir.outletPort to pump.inletPort;

        connection pumpCommand : CommandLink connect
            controller.pumpCommandOut to pump.commandIn;

        connection coolingCommand : CommandLink connect
            controller.coolingCommandOut to coolingUnit.commandIn;

        connection pumpFeedback : SignalLink connect
            pump.feedbackOut to controller.pumpFeedbackIn;

        connection coolingFeedback : SignalLink connect
            coolingUnit.feedbackOut to controller.coolingFeedbackIn;
    }

    part def WearableCap {

        part capShell : CapShell {
            attribute material : String = "Medical-grade silicone";
            attribute channelCount : Integer = 24;
            attribute channelDiameter : Real = 1.5 [mm];
        }

        part coolantChannels : CoolantChannels;

        part scalpSensor : ScalpTemperatureSensor;

        part pressureSensor : CoolantPressureSensor;

        part actuatorInterface : ActuatorInterface;

        port coolantInlet : CoolantPort;
        port coolantOutlet : CoolantPort;

        connection inletToChannels : CoolantFlow connect
            coolantInlet to coolantChannels.distributor;

        connection channelsToOutlet : CoolantFlow connect
            coolantChannels.collector to coolantOutlet;

        connection channelPressure : SignalLink connect
            coolantChannels.pressureTap to pressureSensor.dataIn;
    }

    part def CirculationPump {
        port inletPort : CoolantPort;
        port outletPort : CoolantPort;
        port commandIn : CommandPort;
        port feedbackOut : SignalPort;

        attribute maxFlowRate : FlowRateValue = 2.0 [L/min];
        attribute currentFlowRate : FlowRateValue;
        attribute powerConsumption : PowerValue;

        action def executePumpAction {
            in command : ControlCommand;
            out flowRate : FlowRateValue;
            out feedback;
        }

        perform executePumpAction;

        requirement pumpRequirement {
            subject p : CirculationPump;
            objective {
                doc /* The pump shall provide adjustable coolant flow from 0 to 2.0 L/min with 5% accuracy. */
            }
        }
    }

    part def CoolingUnit {
        port inletPort : CoolantPort;
        port outletPort : CoolantPort;
        port commandIn : CommandPort;
        port feedbackOut : SignalPort;

        attribute maxCoolingPower : PowerValue = 200 [W];
        attribute currentCoolingPower : PowerValue;
        attribute coolantTempOut : TemperatureValue;

        action def executeCooling {
            in command : ControlCommand;
            in warmCoolant : Coolant;
            out chilledCoolant : Coolant;
            out feedback;
        }

        perform executeCooling;

        requirement coolingRequirement {
            subject c : CoolingUnit;
            objective {
                doc /* The cooling unit shall chill coolant to between 5°C and 10°C at the outlet. */
            }
        }
    }

    part def CoolantReservoir {
        port inletPort : CoolantPort;
        port outletPort : CoolantPort;

        attribute capacity : Real = 0.5 [L];
        attribute currentLevel : Real;
        attribute coolantType : Coolant;
    }

    part def CapShell;

    part def CoolantChannels {
        part distributor;
        part collector;
        part pressureTap;

        attribute totalChannelLength : Real = 3.0 [m];
        attribute heatTransferArea : Real = 0.015 [m²];
    }

    part def ScalpTemperatureSensor {
        port dataOut : SignalPort;

        attribute accuracy : Real = 0.1 [°C];
        attribute samplingRate : Real = 1.0 [Hz];

        action def readTemperature {
            out reading : ScalpTemperatureReading;
        }

        perform readTemperature;

        requirement sensorAccuracy {
            subject s : ScalpTemperatureSensor;
            objective {
                doc /* The scalp temperature sensor shall measure temperature with ±0.1°C accuracy at 1 Hz sampling rate. */
            }
        }
    }

    part def CoolantPressureSensor {
        port dataOut : SignalPort;

        attribute range : Real = 0 to 20 [kPa];
        attribute accuracy : Real = 0.2 [kPa];

        action def readPressure {
            out reading : PressureReading;
        }

        perform readPressure;
    }

    part def ActuatorInterface {
        port commandIn : CommandPort;
    }

    part def DisplayPanel {
        port alarmIn : SignalPort;
        port statusIn : SignalPort;

        attribute displayType : String = "Touchscreen LCD";
        attribute alarmVolume : Real = 80 [dB];
    }

    // ---- Control Module with State Machine ----

    part def ControlModule {

        port sensorIn : SignalPort;
        port pressureIn : SignalPort;
        port pumpFeedbackIn : SignalPort;
        port coolingFeedbackIn : SignalPort;
        port commandOut : CommandPort;
        port pumpCommandOut : CommandPort;
        port coolingCommandOut : CommandPort;
        port alarmOut : SignalPort;
        port statusOut : SignalPort;

        attribute currentScalpTemp : TemperatureValue;
        attribute currentPressure : PressureValue;
        attribute targetMin : TemperatureValue = 18 [°C];
        attribute targetMax : TemperatureValue = 22 [°C];
        attribute safetyMin : TemperatureValue = 15 [°C];
        attribute safetyMax : TemperatureValue = 25 [°C];
        attribute maxPressure : PressureValue = 15 [kPa];
        attribute sessionElapsed : DurationValue = 0 [min];
        attribute sessionDuration : DurationValue = 120 [min];

        action def computeControlOutput {
            in scalpTemp : TemperatureValue;
            in pressure : PressureValue;
            in plan : TreatmentPlan;
            out command : ControlCommand;
        }

        perform computeControlOutput;

        state def ControlStateMachine {

            entry action initializeController {
                doc /* Initialize controller parameters and load treatment plan. */
            }

            state idle {
                entry action enterIdle {
                    doc /* System idle, awaiting treatment start command. */
                }
                do action waitForStart;
                exit action leaveIdle;
            }

            state cooling {
                entry action enterCooling {
                    doc /* Actively lower scalp temperature to therapeutic range. */
                }
                do action rampCooling {
                    doc /* Set pump to high flow and cooling unit to maximum power. */
                }
                exit action leaveCooling;
            }

            state maintaining {
                entry action enterMaintaining {
                    doc /* Maintain scalp temperature within therapeutic window. */
                }
                do action fineTuneControl {
                    doc /* Make small adjustments to cooling power and flow rate. */
                }
                exit action leaveMaintaining;
            }

            state alarm {
                entry action enterAlarm {
                    doc /* Trigger alarm and initiate safety procedures. */
                }
                do action alertStaff {
                    doc /* Send alarm signal to display panel and reduce cooling power. */
                }
                exit action leaveAlarm;
            }

            state completed {
                entry action enterCompleted {
                    doc /* Treatment session complete, perform safe shutdown. */
                }
                do action safeShutdown;
            }

            transition t1_idle_to_cooling
                from idle to cooling
                when sensorIn.signalIn ?= "startTreatment";

            transition t2_cooling_to_maintaining
                from cooling to maintaining
                when (currentScalpTemp >= targetMin) and (currentScalpTemp <= targetMax);

            transition t3_maintaining_to_cooling
                from maintaining to cooling
                when currentScalpTemp > targetMax;

            transition t4_maintaining_to_completed
                from maintaining to completed
                when sessionElapsed >= sessionDuration;

            transition t5_any_to_alarm
                from cooling to alarm
                when currentScalpTemp < safetyMin;

            transition t6_maintaining_to_alarm
                from maintaining to alarm
                when currentScalpTemp < safetyMin;

            transition t7_pressure_alarm
                from maintaining to alarm
                when currentPressure > maxPressure;

            transition t8_pressure_alarm_cooling
                from cooling to alarm
                when currentPressure > maxPressure;

            transition t9_alarm_to_idle
                from alarm to idle
                when sensorIn.signalIn ?= "acknowledgeAlarm";

            transition t10_completed_to_idle
                from completed to idle
                when sensorIn.signalIn ?= "reset";
        }

        exhibit ControlStateMachine;

        requirement controllerRequirement {
            subject cm : ControlModule;
            objective {
                doc /* The controller shall maintain scalp temperature between 18°C and 22°C and never allow it to drop below 15°C. */
            }
        }

        requirement responseTimeRequirement {
            subject cm : ControlModule;
            objective {
                doc /* The controller shall respond to temperature deviations within 2 seconds. */
            }
        }
    }

    // ---- Connection Definitions ----

    connection def CoolantFlow {
        end : CoolantPort;
        end : CoolantPort;
        flow coolantFlow : Coolant;
    }

    connection def SignalLink {
        end : SignalPort;
        end : SignalPort;
        flow signal;
    }

    connection def CommandLink {
        end : CommandPort;
        end : CommandPort;
        flow command : ControlCommand;
    }

    // ---- Top-Level Requirements ----

    requirement def TherapeuticEfficacyRequirement {
        subject system : TherapeuticHypothermiaSystem;
        objective {
            doc /* The system shall maintain scalp temperature between 18°C and 22°C for the duration of the chemotherapy session to prevent alopecia. */
        }
    }

    requirement def SafetyRequirement {
        subject system : TherapeuticHypothermiaSystem;
        objective {
            doc /* The system shall never allow scalp temperature to drop below 15°C to prevent tissue damage. */
        }
    }

    requirement def PressureComfortRequirement {
        subject system : TherapeuticHypothermiaSystem;
        objective {
            doc /* The system shall maintain coolant pressure below 15 kPa to ensure patient comfort during long treatment sessions. */
        }
    }

    requirement def AlarmRequirement {
        subject system : TherapeuticHypothermiaSystem;
        objective {
            doc /* The system shall trigger an audible and visual alarm if scalp temperature drops below 15°C or coolant pressure exceeds 15 kPa. */
        }
    }

    requirement def CoolingPhaseRequirement {
        subject system : TherapeuticHypothermiaSystem;
        objective {
            doc /* The system shall transition from cooling to maintaining phase once the target therapeutic temperature range is achieved. */
        }
    }

    requirement def ClosedLoopRequirement {
        subject system : TherapeuticHypothermiaSystem;
        objective {
            doc /* The system shall implement a closed-loop coolant circuit with continuous recirculation through the cap channels. */
        }
    }

    requirement def TreatmentPlanRequirement {
        subject system : TherapeuticHypothermiaSystem;
        objective {
            doc /* The system shall execute a pre-set treatment plan defining target temperature range, safety thresholds, and session duration. */
        }
    }

    // ---- Requirement Satisfaction ----

    satisfaction satisfyEfficacy by TherapeuticHypothermiaSystem.override {
        subject system : TherapeuticHypothermiaSystem;
        objective TherapeuticEfficacyRequirement;
    }

    satisfaction satisfySafety by TherapeuticHypothermiaSystem.override {
        subject system : TherapeuticHypothermiaSystem;
        objective SafetyRequirement;
    }

    satisfaction satisfyPressure by TherapeuticHypothermiaSystem.override {
        subject system : TherapeuticHypothermiaSystem;
        objective PressureComfortRequirement;
    }

    satisfaction satisfyAlarm by TherapeuticHypothermiaSystem.override {
        subject system : TherapeuticHypothermiaSystem;
        objective AlarmRequirement;
    }

    satisfaction satisfyCoolingPhase by TherapeuticHypothermiaSystem.override {
        subject system : TherapeuticHypothermiaSystem;
        objective CoolingPhaseRequirement;
    }

    satisfaction satisfyClosedLoop by TherapeuticHypothermiaSystem.override {
        subject system : TherapeuticHypothermiaSystem;
        objective ClosedLoopRequirement;
    }

    satisfaction satisfyTreatmentPlan by TherapeuticHypothermiaSystem.override {
        subject system : TherapeuticHypothermiaSystem;
        objective TreatmentPlanRequirement;
    }

}
