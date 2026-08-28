package DspSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def VoltageValue :> ScalarValues::Real;
    attribute def CurrentValue :> ScalarValues::Real;
    attribute def FrequencyValue :> ScalarValues::Real;

    item def AnalogSignal {
        attribute amplitude : VoltageValue;
        attribute frequency : FrequencyValue;
    }

    item def DigitalSample {
        attribute code : Integer;
    }

    item def PowerSignal {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }

    port def AnalogSignalPort {
        in signal : AnalogSignal;
        out signal : AnalogSignal;
    }
    port def DigitalSamplePort {
        in data : DigitalSample;
        out data : DigitalSample;
    }
    port def PowerPort {
        in power : PowerSignal;
        out power : PowerSignal;
    }
    port def CommandPort;

    attribute def PowerOnSignal;
    attribute def ShutdownSignal;
    attribute def InputDetectedSignal;

    action def InitializeAction;
    action def EnterLowPowerAction;
    action def ShutdownAction;

    action def AmplifyAction {
        in inputSignal : AnalogSignal;
        out outputSignal : AnalogSignal;
    }
    action def FilterAction {
        in inputSignal : AnalogSignal;
        out outputSignal : AnalogSignal;
    }
    action def AnalogToDigitalConversionAction {
        in inputSignal : AnalogSignal;
        out outputData : DigitalSample;
    }
    action def DigitalProcessingAction {
        in inputData : DigitalSample;
        out outputData : DigitalSample;
    }
    action def DigitalToAnalogConversionAction {
        in inputData : DigitalSample;
        out outputSignal : AnalogSignal;
    }
    action def OutputBufferingAction {
        in inputSignal : AnalogSignal;
        out outputSignal : AnalogSignal;
    }
    action def RegulatePowerAction {
        in inputPower : PowerSignal;
        out outputPower : PowerSignal;
    }
    action def SampleInputAction;
    action def ComputeResultAction;
    action def TransmitOutputAction;

    state def DspOperationalStates;

    part def Amplifier {
        port inputSignal : AnalogSignalPort;
        port outputSignal : AnalogSignalPort;
        port power : PowerPort;
        perform action amplify : AmplifyAction;
    }
    part def SignalFilter {
        port inputSignal : AnalogSignalPort;
        port outputSignal : AnalogSignalPort;
        port power : PowerPort;
        perform action doFilter : FilterAction;
    }
    part def AnalogToDigitalConverter {
        port inputSignal : AnalogSignalPort;
        port outputData : DigitalSamplePort;
        port power : PowerPort;
        perform action convert : AnalogToDigitalConversionAction;
    }
    part def Microcontroller {
        port inputData : DigitalSamplePort;
        port outputData : DigitalSamplePort;
        port power : PowerPort;
        perform action process : DigitalProcessingAction;
    }
    part def DigitalToAnalogConverter {
        port inputData : DigitalSamplePort;
        port outputSignal : AnalogSignalPort;
        port power : PowerPort;
        perform action convert : DigitalToAnalogConversionAction;
    }
    part def OutputBuffer {
        port inputSignal : AnalogSignalPort;
        port outputSignal : AnalogSignalPort;
        port power : PowerPort;
        perform action buffer : OutputBufferingAction;
    }
    part def PowerRegulator {
        port inputPower : PowerPort;
        port outputPower : PowerPort;
        perform action regulate : RegulatePowerAction;
    }

    part def DspModule {
        part amp : Amplifier;
        part filt : SignalFilter;
        part adc : AnalogToDigitalConverter;
        part mcu : Microcontroller;
        part dac : DigitalToAnalogConverter;
        part outBuf : OutputBuffer;
        part reg : PowerRegulator;

        port powerIn : PowerPort;
        port sensorInput : AnalogSignalPort;
        port actuatorOutput : AnalogSignalPort;
        port commandPort : CommandPort;

        attribute minInputVoltage : VoltageValue = 9.0 [SI::V];
        attribute maxInputVoltage : VoltageValue = 15.0 [SI::V];
        attribute regulatedVoltage : VoltageValue = 5.0 [SI::V];

        action initialize : InitializeAction;
        action enterLowPower : EnterLowPowerAction;
        action shutdown : ShutdownAction;
        action sampleInput : SampleInputAction;
        action computeResult : ComputeResultAction;
        action transmitOutput : TransmitOutputAction;

        connect powerIn to reg.inputPower;
        connect reg.outputPower to amp.power;
        connect reg.outputPower to filt.power;
        connect reg.outputPower to adc.power;
        connect reg.outputPower to mcu.power;
        connect reg.outputPower to dac.power;
        connect reg.outputPower to outBuf.power;

        connect sensorInput to amp.inputSignal;
        connect amp.outputSignal to filt.inputSignal;
        connect filt.outputSignal to adc.inputSignal;
        connect adc.outputData to mcu.inputData;
        connect mcu.outputData to dac.inputData;
        connect dac.outputSignal to outBuf.inputSignal;
        connect outBuf.outputSignal to actuatorOutput;

        exhibit state operationalStates : DspOperationalStates {
            entry; then off;
            state off;
            accept PowerOnSignal via commandPort
                then initializing;
            state initializing {
                entry initialize;
            }
            accept after 0.1 [SI::s]
                then standby;
            state standby {
                entry enterLowPower;
            }
            accept InputDetectedSignal
                then active;
            accept ShutdownSignal via commandPort
                do shutdown
                then off;
            state active {
                entry; then sampling;
                state sampling {
                    entry sampleInput;
                }
                accept after 0.001 [SI::s]
                    then computing;
                state computing {
                    entry computeResult;
                }
                accept after 0.002 [SI::s]
                    then transmitting;
                state transmitting {
                    entry transmitOutput;
                }
                accept after 0.001 [SI::s]
                    then sampling;
            }
            accept after 5 [SI::s]
                then standby;
            accept ShutdownSignal via commandPort
                do shutdown
                then off;
        }
    }

    part def PowerSource {
        port outputPower : PowerPort;
        attribute outputVoltage : VoltageValue = 12.0 [SI::V];
    }

    part def ExternalSensor {
        port outputSignal : AnalogSignalPort;
        attribute outputFrequency : FrequencyValue = 1000.0 [SI::Hz];
    }

    part def Actuator {
        port inputSignal : AnalogSignalPort;
    }

    part powerSupply : PowerSource;
    part sensor : ExternalSensor;
    part actuator : Actuator;
    part dsp : DspModule;

    connect powerSupply.outputPower to dsp.powerIn;
    connect sensor.outputSignal to dsp.sensorInput;
    connect dsp.actuatorOutput to actuator.inputSignal;

    requirement 'Stable Power Supply' {
        doc /* The power regulator shall accept a 9 V to 15 V DC input and provide a regulated 5 V DC supply to all internal components. */
    }

    requirement 'Signal Processing Order' {
        doc /* The DSP module shall process signals in the order: amplifier, filter, ADC, microcontroller, DAC, and output buffer. */
    }

    requirement 'State Behavior Requirement' {
        doc /* The system shall transition from standby to active upon signal detection, cycle through sampling, computing, and transmitting in active mode, and return to standby after an idle timeout. */
    }
}
