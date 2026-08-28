package 'Temperature Monitoring System' {
    public import Definitions::*;
    public import Usages::*;

    package Definitions {
        private import ScalarValues::*;

        attribute def Resistance :> Real;
        attribute def Voltage :> Real;
        attribute def Temperature :> Real;
        attribute def DigitalValue :> Integer;
        attribute def PowerSignal;
        attribute def OutOfRangeAlert;
        attribute def SelfTestCommand;
        attribute def CalibrateCommand;
        attribute def SystemReset;

        part def Thermistor {
            attribute type: String = "NTC";
            in power: PowerSignal;
            out resistance: Resistance;
        }

        part def VoltageDivider {
            in power: PowerSignal;
            in resistance: Resistance;
            out voltage: Voltage;
            attribute fixedResistance: Resistance = 10000.0;
        }

        part def SignalConditioner {
            in power: PowerSignal;
            in voltage: Voltage;
            out conditionedVoltage: Voltage;
        }

        part def ADC {
            in power: PowerSignal;
            in conditionedVoltage: Voltage;
            out digitalValue: DigitalValue;
        }

        part def Microcontroller {
            in power: PowerSignal;
            in digitalValue: DigitalValue;
            attribute calibrationOffset: Temperature = 0.0;
            attribute measuredTemp: Temperature;
            out temperature: Temperature;
        }

        part def OutputInterface {
            in power: PowerSignal;
            in temperature: Temperature;
        }

        part def PowerManagementUnit {
            in externalPower: PowerSignal;
            out regulatedPower: PowerSignal;
        }

        part def TemperatureMonitoringSystem {
            part thermistor: Thermistor;
            part voltageDivider: VoltageDivider;
            part signalConditioner: SignalConditioner;
            part adc: ADC;
            part microcontroller: Microcontroller;
            part outputInterface: OutputInterface;
            part powerUnit: PowerManagementUnit;

            flow powerUnit.regulatedPower to thermistor.power;
            flow powerUnit.regulatedPower to voltageDivider.power;
            flow powerUnit.regulatedPower to signalConditioner.power;
            flow powerUnit.regulatedPower to adc.power;
            flow powerUnit.regulatedPower to microcontroller.power;
            flow powerUnit.regulatedPower to outputInterface.power;

            flow thermistor.resistance to voltageDivider.resistance;
            flow voltageDivider.voltage to signalConditioner.voltage;
            flow signalConditioner.conditionedVoltage to adc.conditionedVoltage;
            flow adc.digitalValue to microcontroller.digitalValue;
            flow microcontroller.temperature to outputInterface.temperature;
        }

        action def 'Measure Resistance' { out resistance: Resistance; }
        action def 'Convert to Voltage' { in resistance: Resistance; out voltage: Voltage; }
        action def 'Condition Signal' { in voltage: Voltage; out conditionedVoltage: Voltage; }
        action def 'Convert to Digital' { in conditionedVoltage: Voltage; out digitalValue: DigitalValue; }
        action def 'Calculate Temperature' { in digitalValue: DigitalValue; out temperature: Temperature; }
        action def 'Apply Calibration' { in temperature: Temperature; in offset: Temperature; out calibratedTemperature: Temperature; }
        action def 'Output Data' { in temperature: Temperature; }
        action def 'Perform Self Test' { out passed: Boolean; }
        action def 'Perform Calibration' { in referenceTemp: Temperature; out newOffset: Temperature; }

        state def 'System States';

        requirement def 'Req_Accuracy' {
            doc "The system shall measure ambient temperature within ±0.5°C accuracy.";
        }
        requirement def 'Req_OperatingRange' {
            doc "The system shall operate within -40°C to 125°C.";
        }
        requirement def 'Req_PowerStability' {
            doc "The power management unit shall provide stable regulated voltage to all components.";
        }
        requirement def 'Req_OutOfRangeDetection' {
            doc "The system shall detect out-of-range temperature readings and issue an alert.";
        }
        requirement def 'Req_SelfTest' {
            doc "The system shall perform a self-test on initialization and upon command.";
        }
        requirement def 'Req_Calibration' {
            doc "The system shall support calibration adjustment upon command.";
        }
    }

    package Usages {
        private import Definitions::*;

        requirement 'req_accuracy': 'Req_Accuracy';
        requirement 'req_operating_range': 'Req_OperatingRange';
        requirement 'req_power_stability': 'Req_PowerStability';
        requirement 'req_out_of_range': 'Req_OutOfRangeDetection';
        requirement 'req_self_test': 'Req_SelfTest';
        requirement 'req_calibration': 'Req_Calibration';

        part 'temp system': TemperatureMonitoringSystem {
            exhibit state 'system states': 'System States' {
                entry; then 'Initializing';

                state 'Initializing' {
                    do action 'self test': 'Perform Self Test';
                }
                transition first 'Initializing' then 'Measuring';

                state 'Measuring';
                transition first 'Measuring' then 'Processing';

                state 'Processing';
                transition first 'Processing'
                    if microcontroller.measuredTemp > 125.0
                    then 'Out of Range Handling';
                transition first 'Processing'
                    if microcontroller.measuredTemp < -40.0
                    then 'Out of Range Handling';
                transition first 'Processing'
                    then 'Outputting';

                state 'Outputting' {
                    do action 'output': 'Output Data';
                }
                transition first 'Outputting' then 'Measuring';

                state 'Out of Range Handling' {
                    do send new OutOfRangeAlert() to microcontroller;
                }
                transition first 'Out of Range Handling'
                    accept reset: SystemReset
                    then 'Measuring';

                transition first 'Measuring'
                    accept st: SelfTestCommand
                    then 'Self Test Mode';
                state 'Self Test Mode' {
                    do action 'run self test': 'Perform Self Test';
                }
                transition first 'Self Test Mode' then 'Initializing';

                transition first 'Measuring'
                    accept cal: CalibrateCommand
                    then 'Calibration Mode';
                state 'Calibration Mode' {
                    do action 'run calibration': 'Perform Calibration';
                }
                transition first 'Calibration Mode' then 'Initializing';
            }
        }

        satisfy 'req_accuracy' by 'temp system'::microcontroller;
        satisfy 'req_operating_range' by 'temp system'::thermistor;
        satisfy 'req_power_stability' by 'temp system'::powerUnit;
        satisfy 'req_out_of_range' by 'temp system'::microcontroller;
        satisfy 'req_self_test' by 'temp system'::microcontroller;
        satisfy 'req_calibration' by 'temp system'::microcontroller;
    }
}
