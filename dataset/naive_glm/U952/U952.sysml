package GasSensorUnit {
    import ScalarValues::*;
    
    // Value Types
    value type Concentration {
        value : Real;
        unit "ppm";
    }
    value type ElectricalResistance {
        value : Real;
        unit "Ohm";
    }
    value type Voltage {
        value : Real;
        unit "V";
    }
    value type Temperature {
        value : Real;
        unit "degC";
    }
    value type DigitalValue {
        value : Integer;
    }
    value type TimeStamp {
        value : Real;
        unit "s";
    }
    value type Duration {
        value : Real;
        unit "s";
    }
    
    // Item Types
    item def Gas;
    item def RawSignal;
    item def ConditionedSignal;
    item def DigitalData;
    item def ProcessedData {
        attr concentration : Concentration;
        attr resistance : ElectricalResistance;
        attr timestamp : TimeStamp;
    }
    item def Power;
    
    // Port Definitions
    port def GasPort {
        out item gas : Gas;
    }
    port def RawSignalPort {
        out item signal : RawSignal;
    }
    port def ConditionedSignalPort {
        out item signal : ConditionedSignal;
    }
    port def DigitalDataPort {
        out item data : DigitalData;
    }
    port def ProcessedDataPort {
        out item data : ProcessedData;
    }
    port def PowerPort {
        out item power : Power;
    }
    port def ControlPort {
        out item temp : Temperature;
    }
    
    // Parts
    part def ZnONanorodSensingElement {
        port gasIn : GasPort;
        port rawOut : RawSignalPort;
        port tempIn : ControlPort;
        
        attr operatingTemp : Temperature = 300 [degC];
        attr currentResistance : ElectricalResistance = 1000 [Ohm];
        
        action def SenseGas {
            in gas : Gas;
            out signal : RawSignal;
        }
    }
    
    part def TemperatureController {
        port tempOut : ControlPort;
        port powerIn : PowerPort;
        
        attr targetTemp : Temperature = 300 [degC];
        
        action def ControlTemperature {
            out temp : Temperature;
        }
    }
    
    part def SignalConditioner {
        port rawIn : RawSignalPort;
        port conditionedOut : ConditionedSignalPort;
        port powerIn : PowerPort;
        
        action def AmplifyAndFilter {
            in raw : RawSignal;
            out conditioned : ConditionedSignal;
        }
    }
    
    part def AnalogToDigitalConverter {
        port conditionedIn : ConditionedSignalPort;
        port digitalOut : DigitalDataPort;
        port powerIn : PowerPort;
        
        attr samplingRate : Real = 1000; // Hz
        
        action def Convert {
            in analog : ConditionedSignal;
            out digital : DigitalData;
        }
    }
    
    part def Microcontroller {
        port digitalIn : DigitalDataPort;
        port dataOut : ProcessedDataPort;
        port powerIn : PowerPort;
        
        attr calibrationTable : String = "stored_calibration_data";
        
        action def ProcessData {
            in digital : DigitalData;
            out processed : ProcessedData;
        }
    }
    
    part def PowerSupply {
        port powerOut : PowerPort;
        
        attr outputVoltage : Voltage = 5 [V];
        
        action def SupplyPower {
            out power : Power;
        }
    }
    
    part def GasSensorUnit {
        port gasInput : GasPort;
        port dataOutput : ProcessedDataPort;
        
        part sensingElement : ZnONanorodSensingElement;
        part tempController : TemperatureController;
        part signalConditioner : SignalConditioner;
        part adc : AnalogToDigitalConverter;
        part microcontroller : Microcontroller;
        part powerSupply : PowerSupply;
        
        connection gasConn connect gasInput to sensingElement.gasIn;
        connection tempConn connect tempController.tempOut to sensingElement.tempIn;
        connection rawConn connect sensingElement.rawOut to signalConditioner.rawIn;
        connection condConn connect signalConditioner.conditionedOut to adc.conditionedIn;
        connection digConn connect adc.digitalOut to microcontroller.digitalIn;
        connection dataConn connect microcontroller.dataOut to dataOutput;
        
        connection power1 connect powerSupply.powerOut to tempController.powerIn;
        connection power2 connect powerSupply.powerOut to signalConditioner.powerIn;
        connection power3 connect powerSupply.powerOut to adc.powerIn;
        connection power4 connect powerSupply.powerOut to microcontroller.powerIn;
        
        state def OperationalStates {
            initial idle;
            state warmingUp;
            state measuring;
            state processing;
            
            transition from idle to warmingUp after 5 [s];
            transition from warmingUp to measuring after 10 [s];
            transition from measuring to processing after 1 [s];
            transition from processing to idle after 1 [s];
        }
        
        exhibit state operational : OperationalStates;
    }
}
