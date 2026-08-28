package H2S_Sensing_Unit {
    private import ScalarValues::*;
    private import ISQ::*;
    private import Time::*;

    package Definitions {
        attribute def Voltage :> ScalarValues::Real;
        attribute def Temperature :> ScalarValues::Real;
        attribute def Concentration :> ScalarValues::Real;
        attribute def DigitalValue :> ScalarValues::Integer;

        item def H2S_Gas;
        attribute def CalibrationData;
        attribute def AlarmSignal;
        item def DataReading {
            attribute concentration: Concentration;
            attribute temperature: Temperature;
            attribute timestamp: Time::DateTime;
        }

        attribute def SetupComplete;
        attribute def StartMeasuring;
        attribute def Reset;

        port def GasIntakePort {
            in item airSample: H2S_Gas;
        }
        port def PowerPort {
            in power: Voltage;
        }
        port def DataPort {
            out reading: DataReading;
        }
        port def AlarmPort {
            out alarm: AlarmSignal;
        }

        port def AnalogSignalPort {
            out voltage: Voltage;
        }
        port def DigitalSignalPort {
            out value: DigitalValue;
        }
        port def TempPort {
            out temp: Temperature;
        }
        port def RegulatedPowerPort {
            out voltage: Voltage;
        }

        part def ElectrochemicalCell {
            port signalOut: AnalogSignalPort;
        }
        part def SignalAmplifier {
            port signalIn: AnalogSignalPort;
            port signalOut: AnalogSignalPort;
        }
        part def ADC {
            port signalIn: AnalogSignalPort;
            port signalOut: DigitalSignalPort;
        }
        part def TemperatureCompensator {
            port tempOut: TempPort;
        }
        part def PowerRegulator {
            port powerIn: PowerPort;
            port regulatedPowerOut: RegulatedPowerPort;
        }

        action def CalculateConcentration {
            in digitalValue: DigitalValue;
            in temp: Temperature;
            in calibration: CalibrationData;
            out concentration: Concentration;
        }
        action def CheckThresholds {
            in concentration: Concentration;
            in lowThreshold: Concentration;
            in highThreshold: Concentration;
            out alarmTriggered: Boolean;
        }
        action def OutputData {
            in concentration: Concentration;
            in temp: Temperature;
            out reading: DataReading;
        }
        action def TriggerAlarm {
            out alarm: AlarmSignal;
        }
        action def MeasureCycle;

        part def Microprocessor {
            port digitalIn: DigitalSignalPort;
            port tempIn: TempPort;
            port dataOut: DataPort;
            port alarmOut: AlarmPort;
            attribute calibration: CalibrationData;
        }

        part def H2S_Sensor {
            attribute responseTime: ScalarValues::Real = 30.0;
            attribute operationalLifetime: ScalarValues::Real = 1.0;
            attribute lowThreshold: Concentration;
            attribute highThreshold: Concentration;
            attribute concentration: Concentration;

            port gasIntake: GasIntakePort;
            port powerIn: PowerPort;
            port dataOut: DataPort;
            port alarmOut: AlarmPort;

            part cell: ElectrochemicalCell;
            part amplifier: SignalAmplifier;
            part adc: ADC;
            part tempComp: TemperatureCompensator;
            part powerReg: PowerRegulator;
            part processor: Microprocessor;

            connect powerIn to powerReg.powerIn;
            connect cell.signalOut to amplifier.signalIn;
            connect amplifier.signalOut to adc.signalIn;
            connect adc.signalOut to processor.digitalIn;
            connect tempComp.tempOut to processor.tempIn;
            connect processor.dataOut to dataOut;
            connect processor.alarmOut to alarmOut;

            action 'calculate concentration': CalculateConcentration;
            action 'check thresholds': CheckThresholds;
            action 'output data': OutputData;
            action 'trigger alarm': TriggerAlarm;
            action 'measure cycle': MeasureCycle;

            exhibit state sensorStates {
                entry; then PowerOn;
                state PowerOn;
                accept SetupComplete then Standby;
                state Standby;
                accept StartMeasuring then Active;
                state Active {
                    do 'measure cycle';
                }
                accept when concentration > highThreshold then Alarm;
                state Alarm {
                    do 'trigger alarm';
                }
                accept Reset then Standby;
            }
        }
    }

    package Usages {
        private import Definitions::*;

        part h2sSensor: H2S_Sensor;

        requirement def ResponseTimeRequirement {
            doc /* The sensor must respond to gas concentration changes within 30 seconds. */
            attribute maxResponseTime: ScalarValues::Real = 30.0;
            subject sensor : H2S_Sensor;
            assert constraint { sensor.responseTime <= maxResponseTime }
        }

        requirement def LifetimeRequirement {
            doc /* The sensor must have an operational lifetime of at least 1 year. */
            attribute minLifetime: ScalarValues::Real = 1.0;
            subject sensor : H2S_Sensor;
            assert constraint { sensor.operationalLifetime >= minLifetime }
        }

        requirement responseTimeReq: ResponseTimeRequirement {
            subject = h2sSensor;
        }
        requirement lifetimeReq: LifetimeRequirement {
            subject = h2sSensor;
        }
    }
}
