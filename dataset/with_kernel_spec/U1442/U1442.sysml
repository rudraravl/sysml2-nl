package 'Automated Liquid Cooling System' {
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        attribute def CoolantTemperature :> ISQ::TemperatureValue;
        attribute def FlowRateValue :> ISQ::VolumeFlowRateValue;
        attribute def HeatLoadValue :> ISQ::PowerValue;

        attribute def TemperatureReading {
            attribute value : CoolantTemperature;
        }
        attribute def ValvePositionCommand {
            attribute opening : Real;
        }
        attribute def PumpStandbyCommand;
        attribute def PumpNormalCommand;
        attribute def PumpHighCommand;
        attribute def ShutdownSignal;
        attribute def SystemResetSignal;

        item def Coolant {
            attribute temperature : CoolantTemperature;
            attribute flowRate : FlowRateValue;
        }

        requirement def 'Safe Operating Temperature' {
            doc /* The heat source shall remain below its critical temperature. */
        }
        requirement def 'Temperature Regulation' {
            doc /* The controller shall adjust pump speed and valve position to maintain target temperature. */
        }

        state def PumpStates;
        state def ControllerStates;

        action def 'Circulate Coolant';
        action def 'Circulate Coolant Max';
        action def 'Absorb Heat' {
            inout coolant : Coolant;
            in heatLoad : HeatLoadValue;
        }
        action def 'Dissipate Heat' {
            inout coolant : Coolant;
            in ambientTemperature : CoolantTemperature;
        }
        action def 'Sense Temperature' {
            out reading : TemperatureReading;
        }
        action def 'Monitor Temperature';
        action def 'Regulate Flow Valve' {
            in command : ValvePositionCommand;
        }
        action def 'Send Shutdown Signal';

        part def CoolantPump {
            port coolantIn { in coolant : Coolant; }
            port coolantOut { out coolant : Coolant; }
            port standbyCmdPort { in command : PumpStandbyCommand; }
            port normalCmdPort { in command : PumpNormalCommand; }
            port highCmdPort { in command : PumpHighCommand; }
            port shutdownPort { in signal : ShutdownSignal; }

            perform action 'circulate coolant' : 'Circulate Coolant';
            perform action 'circulate coolant max' : 'Circulate Coolant Max';

            exhibit state 'pump states' : PumpStates {
                entry; then standby;
                state standby {
                    do 'circulate coolant';
                }
                accept PumpStandbyCommand then standby;
                accept PumpNormalCommand then normal;
                accept PumpHighCommand then highSpeed;
                accept ShutdownSignal then shutdown;

                state normal {
                    do 'circulate coolant';
                }
                accept PumpStandbyCommand then standby;
                accept PumpHighCommand then highSpeed;
                accept ShutdownSignal then shutdown;

                state highSpeed {
                    do 'circulate coolant max';
                }
                accept PumpStandbyCommand then standby;
                accept PumpNormalCommand then normal;
                accept ShutdownSignal then shutdown;

                state shutdown;
                accept PumpStandbyCommand then standby;
            }
        }

        part def HeatSource {
            port coolantIn { in coolant : Coolant; }
            port coolantOut { out coolant : Coolant; }
            attribute heatLoad : HeatLoadValue;

            perform action 'absorb heat' : 'Absorb Heat';
        }

        part def TemperatureSensor {
            port readingOut { out reading : TemperatureReading; }

            perform action 'sense temperature' : 'Sense Temperature';
        }

        part def FlowValve {
            port coolantIn { in coolant : Coolant; }
            port coolantOut { out coolant : Coolant; }
            port controlPort { in command : ValvePositionCommand; }

            perform action 'regulate flow valve' : 'Regulate Flow Valve';
        }

        part def HeatExchanger {
            port coolantIn { in coolant : Coolant; }
            port coolantOut { out coolant : Coolant; }
            attribute ambientTemperature : CoolantTemperature;

            perform action 'dissipate heat' : 'Dissipate Heat';
        }

        part def CoolingController {
            port sensorInput { in reading : TemperatureReading; }
            port standbyCmdOut { out command : PumpStandbyCommand; }
            port normalCmdOut { out command : PumpNormalCommand; }
            port highCmdOut { out command : PumpHighCommand; }
            port valveControlOut { out command : ValvePositionCommand; }
            port shutdownOut { out signal : ShutdownSignal; }
            port resetIn { in reset : SystemResetSignal; }

            attribute targetTemperature : CoolantTemperature = 300.0;
            attribute maxSafeTemperature : CoolantTemperature = 340.0;
            attribute criticalTemperature : CoolantTemperature = 360.0;
            attribute hysteresisBand : CoolantTemperature = 5.0;

            perform action 'monitor temperature' : 'Monitor Temperature';
            perform action 'regulate flow valve' : 'Regulate Flow Valve';
            perform action 'send shutdown signal' : 'Send Shutdown Signal';

            exhibit state 'controller states' : ControllerStates {
                entry; then monitoring;

                state monitoring {
                    do 'monitor temperature';
                }
                accept reading : TemperatureReading
                    if reading.value > criticalTemperature
                    do send new ShutdownSignal() to shutdownOut
                    then shutdown;
                accept reading : TemperatureReading
                    if reading.value > targetTemperature
                    do action activateNormal {
                        send new PumpNormalCommand() to normalCmdOut;
                        send new ValvePositionCommand(opening = 0.7) to valveControlOut;
                    }
                    then coolingActive;

                state coolingActive {
                    do 'regulate flow valve';
                }
                accept reading : TemperatureReading
                    if reading.value > criticalTemperature
                    do send new ShutdownSignal() to shutdownOut
                    then shutdown;
                accept reading : TemperatureReading
                    if reading.value <= targetTemperature - hysteresisBand
                    do send new PumpStandbyCommand() to standbyCmdOut
                    then monitoring;
                accept reading : TemperatureReading
                    if reading.value > maxSafeTemperature
                    do action activateMax {
                        send new PumpHighCommand() to highCmdOut;
                        send new ValvePositionCommand(opening = 1.0) to valveControlOut;
                    }
                    then maxCooling;

                state maxCooling {
                    do 'monitor temperature';
                }
                accept reading : TemperatureReading
                    if reading.value > criticalTemperature
                    do send new ShutdownSignal() to shutdownOut
                    then shutdown;
                accept reading : TemperatureReading
                    if reading.value <= maxSafeTemperature - hysteresisBand
                    do send new PumpNormalCommand() to normalCmdOut
                    then coolingActive;

                state shutdown {
                    do 'send shutdown signal';
                }
                accept SystemResetSignal
                    do send new PumpStandbyCommand() to standbyCmdOut
                    then monitoring;
            }
        }

        part def CoolingSystem {
            part pump : CoolantPump;
            part heatSource : HeatSource;
            part sensor : TemperatureSensor;
            part valve : FlowValve;
            part heatExchanger : HeatExchanger;
            part controller : CoolingController;

            flow coolantFromPumpToSource of Coolant
                from pump.coolantOut.coolant to heatSource.coolantIn.coolant;
            flow coolantFromSourceToValve of Coolant
                from heatSource.coolantOut.coolant to valve.coolantIn.coolant;
            flow coolantFromValveToExchanger of Coolant
                from valve.coolantOut.coolant to heatExchanger.coolantIn.coolant;
            flow coolantFromExchangerToPump of Coolant
                from heatExchanger.coolantOut.coolant to pump.coolantIn.coolant;

            flow temperatureReadingFlow of TemperatureReading
                from sensor.readingOut.reading to controller.sensorInput.reading;
            flow standbyCmdFlow of PumpStandbyCommand
                from controller.standbyCmdOut.command to pump.standbyCmdPort.command;
            flow normalCmdFlow of PumpNormalCommand
                from controller.normalCmdOut.command to pump.normalCmdPort.command;
            flow highCmdFlow of PumpHighCommand
                from controller.highCmdOut.command to pump.highCmdPort.command;
            flow valveControlFlow of ValvePositionCommand
                from controller.valveControlOut.command to valve.controlPort.command;
            flow shutdownFlow of ShutdownSignal
                from controller.shutdownOut.signal to pump.shutdownPort.signal;
        }
    }

    package Usages {
        private import Definitions::*;

        part coolingSystem : CoolingSystem;

        requirement 'safe operating temp' : 'Safe Operating Temperature';
        requirement 'temperature regulation' : 'Temperature Regulation';
    }
}
