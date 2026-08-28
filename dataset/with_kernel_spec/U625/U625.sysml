package 'Capacitive Displacement Sensor' {
    private import ScalarValues::*;
    private import ISQ::*;
    
    attribute def CapacitanceValue :> ISQ::CapacitanceValue;
    attribute def VoltageValue :> ISQ::ElectricPotentialValue;
    attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
    attribute def DigitalSample :> Integer;
    
    attribute def StartCmd;
    attribute def StopCmd;
    attribute def TriggerCmd;
    attribute def FaultEvent;
    attribute def CalibrationSuccess;
    attribute def RecoveryCmd;
    
    port def CapacitancePort { signal : CapacitanceValue; }
    port def VoltagePort { signal : VoltageValue; }
    port def DigitalPort { signal : DigitalSample; }
    port def DisplacementPort { signal : LengthValue; }
    port def TemperaturePort { signal : TemperatureValue; }
    port def PowerPort { signal : VoltageValue; }
    port def CommandPort { signal : String; }
    
    requirement def 'High Precision Measurement' {
        doc /* The sensor must measure displacement with high precision. */
        attribute precision : LengthValue;
    }
    
    requirement def 'Non-Contact Sensing' {
        doc /* The sensor must measure distance without physical contact. */
    }
    
    action def 'Generate Capacitance' { out rawCapacitance : CapacitanceValue; }
    action def 'Condition Signal' { in rawCapacitance : CapacitanceValue; out conditionedVoltage : VoltageValue; }
    action def 'Convert Analog to Digital' { in conditionedVoltage : VoltageValue; out digitalSample : DigitalSample; }
    action def 'Process Digital Signal' { in digitalSample : DigitalSample; in temp : TemperatureValue; out displacement : LengthValue; }
    
    part def 'Capacitive Sensor Probe' {
        out port rawCapacitanceOut : CapacitancePort;
        perform action 'generate capacitance' : 'Generate Capacitance' {
            out rawCapacitance = rawCapacitanceOut.signal;
        }
    }
    
    part def 'Signal Conditioning Circuit' {
        in port rawCapacitanceIn : CapacitancePort;
        out port conditionedVoltageOut : VoltagePort;
        perform action 'condition signal' : 'Condition Signal' {
            in rawCapacitance = rawCapacitanceIn.signal;
            out conditionedVoltage = conditionedVoltageOut.signal;
        }
    }
    
    part def 'Analog-to-Digital Converter' {
        in port conditionedVoltageIn : VoltagePort;
        out port digitalSampleOut : DigitalPort;
        perform action 'convert analog to digital' : 'Convert Analog to Digital' {
            in conditionedVoltage = conditionedVoltageIn.signal;
            out digitalSample = digitalSampleOut.signal;
        }
    }
    
    part def 'Digital Signal Processor' {
        in port digitalSampleIn : DigitalPort;
        in port tempIn : TemperaturePort;
        out port displacementOut : DisplacementPort;
        perform action 'process digital signal' : 'Process Digital Signal' {
            in digitalSample = digitalSampleIn.signal;
            in temp = tempIn.signal;
            out displacement = displacementOut.signal;
        }
    }
    
    part def 'Capacitive Displacement Sensing Unit' {
        in port powerIn : PowerPort;
        in port commandIn : CommandPort;
        out port measurementOut : DisplacementPort;
        
        part probe : 'Capacitive Sensor Probe';
        part conditioner : 'Signal Conditioning Circuit';
        part adc : 'Analog-to-Digital Converter';
        part dsp : 'Digital Signal Processor';
        
        connect probe.rawCapacitanceOut to conditioner.rawCapacitanceIn;
        connect conditioner.conditionedVoltageOut to adc.conditionedVoltageIn;
        connect adc.digitalSampleOut to dsp.digitalSampleIn;
        connect dsp.displacementOut to measurementOut;
        
        exhibit state 'operating states' {
            entry; then startup;
            state startup {
                entry action 'perform self-test and calibration';
            }
            transition startup_to_ready
                first startup
                accept CalibrationSuccess
                then ready;
            
            state ready;
            transition ready_to_active
                first ready
                accept StartCmd
                then active;
            
            state active {
                state continuous;
                state triggered;
                transition continuous_to_triggered
                    first continuous
                    accept TriggerCmd
                    then triggered;
                transition triggered_to_continuous
                    first triggered
                    accept TriggerCmd
                    then continuous;
            }
            transition active_to_ready
                first active
                accept StopCmd
                then ready;
            
            state fault {
                entry action 'log fault';
            }
            transition active_to_fault
                first active
                accept FaultEvent
                then fault;
            transition ready_to_fault
                first ready
                accept FaultEvent
                then fault;
            transition fault_to_startup
                first fault
                accept RecoveryCmd
                then startup;
        }
    }
}
