package 'PLC System' {
    private import ScalarValues::*;
    
    attribute def FrequencyValue :> Real;
    attribute def ElectricPotentialValue :> Real;
    attribute def LengthValue :> Real;
    attribute def DataRateValue :> Real;
    
    unit Hz;
    unit MHz;
    unit V;
    unit m;
    unit Mbps;
    
    item def DataPacket;
    item def ModulatedSignal {
        attribute carrierFrequency : FrequencyValue;
        attribute bandwidth : FrequencyValue;
    }
    
    port def DataPort {
        in item dataIn : DataPacket;
        out item dataOut : DataPacket;
    }
    
    port def AnalogPort {
        in item signalIn : ModulatedSignal;
        out item signalOut : ModulatedSignal;
    }
    
    port def PowerLinePort {
        in item lineSignalIn : ModulatedSignal;
        out item lineSignalOut : ModulatedSignal;
    }
    
    requirement def 'Frequency Range Constraint' {
        subject modem : PLCModem;
        doc /* The PLC modem shall operate in the 2-30 MHz frequency range to avoid interference with 50/60 Hz power. */
        attribute minFreq : FrequencyValue = 2 [MHz];
        attribute maxFreq : FrequencyValue = 30 [MHz];
        assert constraint {
            modem.operatingFreqMin >= 2 [MHz] and
            modem.operatingFreqMax <= 30 [MHz]
        }
    }
    
    requirement def 'Data Rate Constraint' {
        subject modem : PLCModem;
        doc /* The modem shall support data rates up to 200 Mbps. */
        attribute maxRate : DataRateValue = 200 [Mbps];
        assert constraint { modem.maxDataRate <= 200 [Mbps] }
    }
    
    requirement def 'Voltage Isolation' {
        subject coupler : SignalCoupler;
        doc /* The signal coupler shall isolate the modem from line voltages up to 1000V. */
        attribute maxVoltage : ElectricPotentialValue = 1000 [V];
        assert constraint { coupler.isolationVoltage >= 1000 [V] }
    }
    
    requirement def 'Transmission Distance' {
        subject driver : LineDriver;
        doc /* The line driver shall amplify the signal to travel up to 300 meters. */
        attribute maxDistance : LengthValue = 300 [m];
        assert constraint { driver.maxDriveDistance >= 300 [m] }
    }
    
    requirement def 'Bidirectional Communication' {
        subject system : 'PLC System Assembly';
        doc /* The system shall support bidirectional communication over power lines. */
    }
    
    requirement def 'No Electrical Interference' {
        subject system : 'PLC System Assembly';
        doc /* The system shall not interfere with the normal delivery of electricity. */
    }
    
    part def PLCModem {
        attribute operatingFreqMin : FrequencyValue = 2 [MHz];
        attribute operatingFreqMax : FrequencyValue = 30 [MHz];
        attribute maxDataRate : DataRateValue = 200 [Mbps];
        
        port dataInterface : DataPort;
        port analogInterface : AnalogPort;
        
        action modulate {
            in item inputData : DataPacket;
            out item outputSignal : ModulatedSignal;
        }
        
        action demodulate {
            in item inputSignal : ModulatedSignal;
            out item outputData : DataPacket;
        }
        
        state modemBehavior {
            state idle;
            state modulating;
            state demodulating;
            
            transition idle -> modulating;
            transition modulating -> idle;
            transition idle -> demodulating;
            transition demodulating -> idle;
        }
    }
    
    part def SignalCoupler {
        attribute isolationVoltage : ElectricPotentialValue = 1000 [V];
        port modemSide : AnalogPort;
        port lineSide : PowerLinePort;
        
        action coupleSignal {
            in item inputSignal : ModulatedSignal;
            out item outputSignal : ModulatedSignal;
        }
        
        action extractSignal {
            in item inputSignal : ModulatedSignal;
            out item outputSignal : ModulatedSignal;
        }
    }
    
    part def BandPassFilter {
        attribute passBandMin : FrequencyValue = 2 [MHz];
        attribute passBandMax : FrequencyValue = 30 [MHz];
        port input : AnalogPort;
        port output : AnalogPort;
        
        action filterSignal {
            in item inputSignal : ModulatedSignal;
            out item outputSignal : ModulatedSignal;
        }
    }
    
    part def LineDriver {
        attribute maxDriveDistance : LengthValue = 300 [m];
        attribute gain : Real;
        port input : AnalogPort;
        port output : AnalogPort;
        
        action amplify {
            in item inputSignal : ModulatedSignal;
            out item outputSignal : ModulatedSignal;
        }
    }
    
    part def AnalogFrontEnd {
        port modemInterface : AnalogPort;
        port lineInterface : PowerLinePort;
        
        part coupler : SignalCoupler;
        part bandPassFilter : BandPassFilter;
        part driver : LineDriver;
        
        connect modemInterface to driver.input;
        connect driver.output to bandPassFilter.input;
        connect bandPassFilter.output to coupler.modemSide;
        connect coupler.lineSide to lineInterface;
    }
    
    part def PowerLine {
        port endA : PowerLinePort;
        port endB : PowerLinePort;
        attribute length : LengthValue;
        attribute lineVoltage : ElectricPotentialValue;
        attribute lineFrequency : FrequencyValue = 50 [Hz];
        attribute attenuation : Real;
    }
    
    part def TransmitterUnit {
        part modem : PLCModem;
        part afe : AnalogFrontEnd;
        port networkPort : DataPort;
        port powerLinePort : PowerLinePort;
        
        connect modem.dataInterface to networkPort;
        connect modem.analogInterface to afe.modemInterface;
        connect afe.lineInterface to powerLinePort;
    }
    
    part def ReceiverUnit {
        part modem : PLCModem;
        part afe : AnalogFrontEnd;
        port networkPort : DataPort;
        port powerLinePort : PowerLinePort;
        
        connect modem.dataInterface to networkPort;
        connect modem.analogInterface to afe.modemInterface;
        connect afe.lineInterface to powerLinePort;
    }
    
    part 'PLC System Assembly' {
        part transmitter : TransmitterUnit;
        part receiver : ReceiverUnit;
        part powerLine : PowerLine;
        
        connect transmitter.powerLinePort to powerLine.endA;
        connect receiver.powerLinePort to powerLine.endB;
        
        satisfy 'Bidirectional Communication';
        satisfy 'No Electrical Interference';
        
        perform action communicationFlow {
            action 'modulate data' :>> transmitter.modem.modulate {
                in inputData = transmitter.networkPort.dataIn;
                out outputSignal = transmitter.modem.analogInterface.signalOut;
            }
            then action 'amplify signal' :>> transmitter.afe.driver.amplify {
                in inputSignal = transmitter.modem.analogInterface.signalOut;
                out outputSignal = transmitter.afe.driver.output.signalOut;
            }
            then action 'filter signal' :>> transmitter.afe.bandPassFilter.filterSignal {
                in inputSignal = transmitter.afe.driver.output.signalOut;
                out outputSignal = transmitter.afe.bandPassFilter.output.signalOut;
            }
            then action 'couple to line' :>> transmitter.afe.coupler.coupleSignal {
                in inputSignal = transmitter.afe.bandPassFilter.output.signalOut;
                out outputSignal = powerLine.endA.lineSignalOut;
            }
            then action 'propagate over power line' {
                doc /* Signal travels through the power line channel to the receiver. */
            }
            then action 'extract from line' :>> receiver.afe.coupler.extractSignal {
                in inputSignal = powerLine.endB.lineSignalIn;
                out outputSignal = receiver.afe.coupler.modemSide.signalOut;
            }
            then action 'filter received signal' :>> receiver.afe.bandPassFilter.filterSignal {
                in inputSignal = receiver.afe.coupler.modemSide.signalOut;
                out outputSignal = receiver.afe.bandPassFilter.output.signalOut;
            }
            then action 'demodulate signal' :>> receiver.modem.demodulate {
                in inputSignal = receiver.afe.modemInterface.signalIn;
                out outputData = receiver.networkPort.dataOut;
            }
        }
    }
    
    satisfy 'Frequency Range Constraint' by 'PLC System Assembly'::transmitter::modem;
    satisfy 'Frequency Range Constraint' by 'PLC System Assembly'::receiver::modem;
    satisfy 'Data Rate Constraint' by 'PLC System Assembly'::transmitter::modem;
    satisfy 'Data Rate Constraint' by 'PLC System Assembly'::receiver::modem;
    satisfy 'Voltage Isolation' by 'PLC System Assembly'::transmitter::afe::coupler;
    satisfy 'Voltage Isolation' by 'PLC System Assembly'::receiver::afe::coupler;
    satisfy 'Transmission Distance' by 'PLC System Assembly'::transmitter::afe::driver;
    satisfy 'Transmission Distance' by 'PLC System Assembly'::receiver::afe::driver;
}
