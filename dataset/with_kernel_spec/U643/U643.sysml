package 'Current Sensing Unit' {
    import ScalarValues::*;
    
    attribute def PowerOnSignal;
    attribute def InitCompleteSignal;
    attribute def TriggerSignal;
    attribute def FaultSignal;
    attribute def MeasurementDoneSignal;
    attribute def ResetSignal;
    
    attribute def CurrentValue :> Real;
    attribute def VoltageValue :> Real;
    attribute def ResistanceValue :> Real;
    attribute def DigitalValue :> Integer;
    attribute def Timestamp :> Real;
    
    item def MeasuredCurrent {
        attribute current : CurrentValue;
        attribute timestamp : Timestamp;
        attribute valid : Boolean;
    }
    
    requirement def CurrentSensingUnitRequirement {
        text = "The Current Sensing Unit shall accurately measure electrical current flowing through a circuit and report it as a digital value via a standard communication protocol.";
    }
    
    action def PerformSelfTest;
    action def RunDiagnostics;
    
    action def TakeMeasurement {
        action sense;
        action amplify;
        action convert;
        action process;
        action transmit;
    }
    
    part def ShuntResistor {
        attribute resistance : ResistanceValue = 0.01;
        in port currentIn : CurrentValue;
        out port voltageOut : VoltageValue;
        in port powerIn : Real;
    }
    
    part def Amplifier {
        attribute gain : Real = 50.0;
        in port voltageIn : VoltageValue;
        out port voltageOut : VoltageValue;
        in port powerIn : Real;
    }
    
    part def ADC {
        attribute resolution : Integer = 16;
        attribute samplingRate : Real = 1000.0;
        in port voltageIn : VoltageValue;
        out port digitalOut : DigitalValue;
        in port powerIn : Real;
    }
    
    part def Microcontroller {
        in port digitalIn : DigitalValue;
        out port dataOut : MeasuredCurrent;
        in port powerIn : Real;
    }
    
    part def DataInterface {
        in port dataIn : MeasuredCurrent;
        out port spiOut : MeasuredCurrent;
        in port powerIn : Real;
    }
    
    part def PowerSupply {
        out port powerOut : Real;
    }
    
    state def CurrentSensingUnitStates;
    
    part def CurrentSensingUnit {
        in port currentInput : CurrentValue;
        out port measurementOut : MeasuredCurrent;
        
        perform action takeMeasurement : TakeMeasurement[*] ordered;
        
        part shunt : ShuntResistor {
            perform takeMeasurement.sense;
        }
        part amp : Amplifier {
            perform takeMeasurement.amplify;
        }
        part adc : ADC {
            perform takeMeasurement.convert;
        }
        part mcu : Microcontroller {
            perform takeMeasurement.process;
        }
        part iface : DataInterface {
            perform takeMeasurement.transmit;
        }
        part psu : PowerSupply;
        
        connection currentToShunt connect currentInput to shunt.currentIn;
        connection shuntToAmp connect shunt.voltageOut to amp.voltageIn;
        connection ampToAdc connect amp.voltageOut to adc.voltageIn;
        connection adcToMcu connect adc.digitalOut to mcu.digitalIn;
        connection mcuToIface connect mcu.dataOut to iface.dataIn;
        connection ifaceOut connect iface.spiOut to measurementOut;
        
        connection psuToShunt connect psu.powerOut to shunt.powerIn;
        connection psuToAmp connect psu.powerOut to amp.powerIn;
        connection psuToAdc connect psu.powerOut to adc.powerIn;
        connection psuToMcu connect psu.powerOut to mcu.powerIn;
        connection psuToIface connect psu.powerOut to iface.powerIn;
        
        state unitStates : CurrentSensingUnitStates {
            entry; then offline;
            state offline;
            accept PowerOnSignal 
                then initializing;
            state initializing {
                entry PerformSelfTest;
            }
            accept InitCompleteSignal 
                then ready;
            accept FaultSignal 
                then error;
            state ready;
            accept TriggerSignal 
                then measuring;
            state measuring {
                do takeMeasurement;
            }
            accept MeasurementDoneSignal 
                then ready;
            accept FaultSignal 
                then error;
            state error {
                entry RunDiagnostics;
            }
            accept ResetSignal 
                then offline;
        }
    }
}
