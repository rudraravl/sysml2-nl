package InfusionPumpModel {

    // ============================================================
    // Units
    // ============================================================
    unit mL;
    unit h;
    unit mL_per_h = mL / h;
    unit hPa;
    unit V;
    unit Ah;
    unit percent;

    // ============================================================
    // Value Types
    // ============================================================
    value type Volume :> Real { unit : mL; }
    value type FlowRate :> Real { unit : mL_per_h; }
    value type Pressure :> Real { unit : hPa; }
    value type Voltage :> Real { unit : V; }
    value type BatteryCapacity :> Real { unit : Ah; }
    value type Level :> Real { unit : percent; }
    value type Duration :> Real { unit : h; }

    // ============================================================
    // Items
    // ============================================================
    item def TherapeuticFluid;
    item def FluidSample;
    item def AirBubble;
    item def ElectricalPower;
    item def AlarmCommand;

    attribute def PressureReading { attr value : Pressure; }
    attribute def FlowReading { attr value : FlowRate; }
    attribute def AirReading { attr detected : Boolean; }
    attribute def LevelReading { attr value : Level; }
    attribute def PumpCommand { attr targetRate : FlowRate; attr enable : Boolean; }
    attribute def StatusReport {
        attr volumeDelivered : Volume;
        attr currentRate : FlowRate;
        attr activeAlarm : String;
    }
    attribute def ProgramParameters {
        attr targetRate : FlowRate;
        attr targetVolume : Volume;
        attr bolusVolume : Volume;
    }

    // ============================================================
    // Port Definitions
    // ============================================================
    port def FluidInPort {
        in item fluid : TherapeuticFluid;
    }
    port def FluidOutPort {
        out item fluid : TherapeuticFluid;
    }
    port def PressureOutPort { out attribute reading : PressureReading; }
    port def FlowOutPort { out attribute reading : FlowReading; }
    port def AirOutPort { out attribute reading : AirReading; }
    port def LevelOutPort { out attribute reading : LevelReading; }
    port def PumpCommandPort { out attribute command : PumpCommand; }
    port def StatusPort { out attribute status : StatusReport; }
    port def ProgramPort { in attribute program : ProgramParameters; }
    port def AlarmCommandPort { out attribute command : AlarmCommand; }
    port def PowerOutPort { out item power : ElectricalPower; }
    port def PowerInPort { in item power : ElectricalPower; }

    // ============================================================
    // Interface Definitions
    // ============================================================
    interface def FluidFlowInterface {
        end supplier : FluidOutPort;
        end consumer : FluidInPort;
        flow of TherapeuticFluid from supplier.fluid to consumer.fluid;
    }
    interface def PressureInterface {
        end supplier : PressureOutPort;
        end consumer : Port { in attribute reading : PressureReading; }
    }
    interface def FlowInterface {
        end supplier : FlowOutPort;
        end consumer : Port { in attribute reading : FlowReading; }
    }
    interface def AirInterface {
        end supplier : AirOutPort;
        end consumer : Port { in attribute reading : AirReading; }
    }
    interface def LevelInterface {
        end supplier : LevelOutPort;
        end consumer : Port { in attribute reading : LevelReading; }
    }
    interface def PumpControlInterface {
        end supplier : PumpCommandPort;
        end consumer : Port { in attribute command : PumpCommand; }
    }
    interface def StatusInterface {
        end supplier : StatusPort;
        end consumer : Port { in attribute status : StatusReport; }
    }
    interface def ProgramInterface {
        end supplier : Port { out attribute program : ProgramParameters; };
        end consumer : ProgramPort;
    }
    interface def AlarmInterface {
        end supplier : AlarmCommandPort;
        end consumer : Port { in attribute command : AlarmCommand; }
    }
    interface def PowerInterface {
        end supplier : PowerOutPort;
        end consumer : PowerInPort;
        flow of ElectricalPower from supplier.power to consumer.power;
    }

    // ============================================================
    // Part Definitions - Components
    // ============================================================

    part def FluidReservoir {
        attribute capacity : Volume = 250 [mL];
        attribute currentVolume : Volume;
        port fluidOut : FluidOutPort;
        port levelOut : LevelOutPort;

        action def SenseLevel {
            out reading : LevelReading;
        }
        private action senseLevel : SenseLevel;
    }

    part def PumpingMechanism {
        attribute type : String = "peristaltic";
        attribute currentRate : FlowRate;
        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;
        port commandIn : Port { in attribute command : PumpCommand; }

        action def Pump {
            in cmd : PumpCommand;
            out rate : FlowRate;
        }
        private action pump : Pump;
    }

    part def PressureSensor {
        attribute threshold : Pressure = 800 [hPa];
        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;
        port readingOut : PressureOutPort;

        action def MeasurePressure {
            in fluid : TherapeuticFluid;
            out reading : PressureReading;
        }
        private action measure : MeasurePressure;
    }

    part def FlowSensor {
        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;
        port readingOut : FlowOutPort;

        action def MeasureFlow {
            in fluid : TherapeuticFluid;
            out reading : FlowReading;
        }
        private action measure : MeasureFlow;
    }

    part def AirDetector {
        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;
        port readingOut : AirOutPort;

        action def DetectAir {
            in fluid : TherapeuticFluid;
            out reading : AirReading;
        }
        private action detect : DetectAir;
    }

    part def ControlProcessor {
        attribute targetRate : FlowRate;
        attribute targetVolume : Volume;
        attribute volumeDelivered : Volume = 0 [mL];
        attribute alarmActive : Boolean = false;

        port pressureIn : Port { in attribute reading : PressureReading; }
        port flowIn : Port { in attribute reading : FlowReading; }
        port airIn : Port { in attribute reading : AirReading; }
        port levelIn : Port { in attribute reading : LevelReading; }
        port programIn : ProgramPort;
        port pumpCommandOut : PumpCommandPort;
        port statusOut : StatusPort;
        port alarmCommandOut : AlarmCommandPort;

        action def EvaluateSafety {
            in pressure : PressureReading;
            in flow : FlowReading;
            in air : AirReading;
            in level : LevelReading;
            out alarm : Boolean;
        }
        action def AdjustPump {
            in flow : FlowReading;
            in target : FlowRate;
            out command : PumpCommand;
        }
        action def ReportStatus {
            out status : StatusReport;
        }

        private action evaluate : EvaluateSafety;
        private action adjust : AdjustPump;
        private action report : ReportStatus;
    }

    part def UserInterface {
        port programOut : Port { out attribute program : ProgramParameters; };
        port statusIn : Port { in attribute status : StatusReport; };

        action def AcceptInput {
            out program : ProgramParameters;
        }
        action def DisplayStatus {
            in status : StatusReport;
        }
        private action acceptInput : AcceptInput;
        private action display : DisplayStatus;
    }

    part def AlarmSubsystem {
        attribute audibleEnabled : Boolean = true;
        attribute visualEnabled : Boolean = true;
        port commandIn : Port { in attribute command : AlarmCommand; };

        action def SoundAlarm {
            in cmd : AlarmCommand;
        }
        action def FlashLight {
            in cmd : AlarmCommand;
        }
        private action sound : SoundAlarm;
        private action flash : FlashLight;
    }

    part def PowerManagementUnit {
        attribute mainsConnected : Boolean;
        attribute batteryCapacity : BatteryCapacity = 2.5 [Ah];
        attribute batteryLevel : Level;
        attribute outputVoltage : Voltage = 12 [V];
        port powerOut : PowerOutPort;

        action def ManagePower {
            out power : ElectricalPower;
        }
        private action manage : ManagePower;
    }

    // ============================================================
    // Patient (external)
    // ============================================================
    part def Patient {
        port fluidIn : FluidInPort;
    }

    // ============================================================
    // Top-level Infusion Pump System
    // ============================================================
    part def InfusionPump {

        part reservoir : FluidReservoir;
        part pump : PumpingMechanism;
        part pressureSensor : PressureSensor;
        part flowSensor : FlowSensor;
        part airDetector : AirDetector;
        part controller : ControlProcessor;
        part ui : UserInterface;
        part alarm : AlarmSubsystem;
        part power : PowerManagementUnit;
        part patient : Patient;

        // Fluid path connections
        connection : FluidFlowInterface connect reservoir.fluidOut to pump.fluidIn;
        connection : FluidFlowInterface connect pump.fluidOut to pressureSensor.fluidIn;
        connection : FluidFlowInterface connect pressureSensor.fluidOut to flowSensor.fluidIn;
        connection : FluidFlowInterface connect flowSensor.fluidOut to airDetector.fluidIn;
        connection : FluidFlowInterface connect airDetector.fluidOut to patient.fluidIn;

        // Sensor signal connections
        connection : PressureInterface connect pressureSensor.readingOut to controller.pressureIn;
        connection : FlowInterface connect flowSensor.readingOut to controller.flowIn;
        connection : AirInterface connect airDetector.readingOut to controller.airIn;
        connection : LevelInterface connect reservoir.levelOut to controller.levelIn;

        // Control connections
        connection : PumpControlInterface connect controller.pumpCommandOut to pump.commandIn;
        connection : StatusInterface connect controller.statusOut to ui.statusIn;
        connection : ProgramInterface connect ui.programOut to controller.programIn;
        connection : AlarmInterface connect controller.alarmCommandOut to alarm.commandIn;

        // Power distribution
        connection : PowerInterface connect power.powerOut to controller;
        connection : PowerInterface connect power.powerOut to pump;
        connection : PowerInterface connect power.powerOut to ui;
        connection : PowerInterface connect power.powerOut to alarm;

        // ============================================================
        // State Machine Behavior
        // ============================================================
        state def PumpStateMachine {

            attribute poweredOn : Boolean = false;
            attribute selfTestPassed : Boolean = false;
            attribute deliveryActive : Boolean = false;
            attribute primingComplete : Boolean = false;

            entry; then off;

            state off {
                entry action { poweredOn = false; }
            }

            transition from off to selfTest
                when power.mainsConnected or power.batteryLevel > 0 [percent]
                accept PowerOn;

            state selfTest {
                entry action {
                    selfTestPassed = (reservoir.currentVolume > 0 [mL]) and
                                     (power.outputVoltage > 10 [V]);
                }
                do action {
                    if selfTestPassed {
                        send SelfTestResult(true);
                    } else {
                        send SelfTestResult(false);
                    }
                }
            }

            transition from selfTest to alarmState
                when not selfTestPassed;
            transition from selfTest to standby
                when selfTestPassed;

            state standby {
                entry action {
                    deliveryActive = false;
                    primingComplete = false;
                }
            }

            transition from standby to priming
                accept ProgramDelivery(program : ProgramParameters)
                when program.targetRate > 0 [mL_per_h];

            state priming {
                entry action {
                    pump.currentRate = 50 [mL_per_h];
                }
                do action {
                    if airDetector.detect.reading.detected == false {
                        primingComplete = true;
                    }
                }
            }

            transition from priming to active
                when primingComplete;
            transition from priming to alarmState
                when airDetector.detect.reading.detected == true;

            state active {
                entry action {
                    deliveryActive = true;
                    pump.currentRate = controller.targetRate;
                }
                do action {
                    controller.evaluate(
                        pressureSensor.measure.reading,
                        flowSensor.measure.reading,
                        airDetector.detect.reading,
                        reservoir.senseLevel.reading
                    );
                    controller.adjust(
                        flowSensor.measure.reading,
                        controller.targetRate
                    );
                    controller.report();
                }
            }

            transition from active to paused accept Pause;
            transition from active to alarmState
                when controller.evaluate.alarm == true;
            transition from active to completed
                when controller.volumeDelivered >= controller.targetVolume;

            state paused {
                entry action {
                    deliveryActive = false;
                    pump.currentRate = 0 [mL_per_h];
                }
            }

            transition from paused to active accept Resume;
            transition from paused to standby accept Stop;

            state alarmState {
                entry action {
                    deliveryActive = false;
                    pump.currentRate = 0 [mL_per_h];
                    alarm.sound(controller.alarmCommandOut.command);
                    alarm.flash(controller.alarmCommandOut.command);
                }
            }

            transition from alarmState to standby accept AcknowledgeAlarm
                when not controller.evaluate.alarm;

            state completed {
                entry action {
                    deliveryActive = false;
                    pump.currentRate = 0 [mL_per_h];
                }
            }

            transition from completed to standby accept Reset;
        }

        private state machine : PumpStateMachine;

        // Signal definitions for events
        signal def PowerOn;
        signal def ProgramDelivery { attr program : ProgramParameters; }
        signal def Pause;
        signal def Resume;
        signal def Stop;
        signal def AcknowledgeAlarm;
        signal def Reset;
        signal def SelfTestResult { attr passed : Boolean; }
    }

    // ============================================================
    // Requirements
    // ============================================================
    requirement def ID_RQ_001_PreciseFlowRate {
        doc /* The infusion pump shall deliver therapeutic fluid at a flow rate
               within +/-5% of the programmed target rate. */
        subject : InfusionPump;
        objective {
            flowSensor.measure.reading.value >= controller.targetRate * 0.95 and
            flowSensor.measure.reading.value <= controller.targetRate * 1.05
        }
    }

    requirement def ID_RQ_002_VolumeAccuracy {
        doc /* The total volume delivered shall be within +/-2% of the programmed
               target volume. */
        subject : InfusionPump;
        objective {
            controller.volumeDelivered >= controller.targetVolume * 0.98 and
            controller.volumeDelivered <= controller.targetVolume * 1.02
        }
    }

    requirement def ID_RQ_003_OcclusionDetection {
        doc /* The pump shall detect line occlusions when line pressure exceeds
               the threshold and halt delivery within 2 seconds. */
        subject : InfusionPump;
        objective {
            pressureSensor.measure.reading.value > pressureSensor.threshold implies
            pump.currentRate == 0 [mL_per_h]
        }
    }

    requirement def ID_RQ_004_AirDetection {
        doc /* The pump shall detect air bubbles in the fluid path and halt
               delivery before air reaches the patient. */
        subject : InfusionPump;
        objective {
            airDetector.detect.reading.detected == true implies
            pump.currentRate == 0 [mL_per_h]
        }
    }

    requirement def ID_RQ_005_EmptyReservoir {
        doc /* The pump shall alert the user and halt delivery when the reservoir
               level falls below 5%. */
        subject : InfusionPump;
        objective {
            reservoir.senseLevel.reading.value < 5 [percent] implies
            pump.currentRate == 0 [mL_per_h]
        }
    }

    requirement def ID_RQ_006_AlarmIndication {
        doc /* The alarm subsystem shall provide both audible and visual alerts
               for all safety alarm conditions. */
        subject : AlarmSubsystem;
        objective {
            alarm.audibleEnabled == true and alarm.visualEnabled == true
        }
    }

    requirement def ID_RQ_007_BatteryBackup {
        doc /* The pump shall operate for at least 4 hours on battery power alone
               at nominal delivery rate. */
        subject : PowerManagementUnit;
        objective {
            power.batteryCapacity >= 2.0 [Ah]
        }
    }

    requirement def ID_RQ_008_StateTransitions {
        doc /* The pump shall transition through off, selfTest, standby, priming,
               active, paused, alarmState, and completed states as defined. */
        subject : InfusionPump;
        objective {
            exists state machine : PumpStateMachine
        }
    }

    requirement def ID_RQ_009_UserInterface {
        doc /* The user interface shall accept programmed delivery parameters and
               display status including volume delivered and active alarms. */
        subject : UserInterface;
        objective {
            ui.acceptInput.program.targetRate > 0 [mL_per_h] and
            ui.display.status.volumeDelivered >= 0 [mL]
        }
    }

    requirement def ID_RQ_010_PrimeSequence {
        doc /* The pump shall perform a priming sequence to fill tubing and remove
               air before active delivery. */
        subject : InfusionPump;
        objective {
            primingComplete == true before active.entry
        }
    }

    // ============================================================
    // Requirement Satisfaction
    // ============================================================
    satisfaction satisfy ID_RQ_001_PreciseFlowRate by InfusionPump;
    satisfaction satisfy ID_RQ_002_VolumeAccuracy by InfusionPump;
    satisfaction satisfy ID_RQ_003_OcclusionDetection by InfusionPump;
    satisfaction satisfy ID_RQ_004_AirDetection by InfusionPump;
    satisfaction satisfy ID_RQ_005_EmptyReservoir by InfusionPump;
    satisfaction satisfy ID_RQ_006_AlarmIndication by AlarmSubsystem;
    satisfaction satisfy ID_RQ_007_BatteryBackup by PowerManagementUnit;
    satisfaction satisfy ID_RQ_008_StateTransitions by InfusionPump;
    satisfaction satisfy ID_RQ_009_UserInterface by UserInterface;
    satisfaction satisfy ID_RQ_010_PrimeSequence by InfusionPump;

}
