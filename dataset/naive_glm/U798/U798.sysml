package OxygenSensingUnitModel {
    import ScalarValues::*;

    // Units
    unit K;
    unit V;
    unit Percent;

    // Value Types
    value type TemperatureValue :> Real { unit K; }
    value type VoltageValue :> Real { unit V; }
    value type ConcentrationValue :> Real { unit Percent; }
    value type ConfidenceValue :> Real { unit Percent; }
    
    // Enums
    enum def SensorStatus {
        INITIALIZING;
        WARMING_UP;
        READY;
        MEASURING;
        CALIBRATING;
        ERROR;
    }

    // Items
    item def GasSample;
    item def ElectricalPower;
    item def AnalogSignal {
        value voltage : VoltageValue;
    }
    item def DigitalSignal {
        value rawValue : Integer;
    }
    item def OxygenReading {
        value concentration : ConcentrationValue;
        value confidence : ConfidenceValue;
        value status : SensorStatus;
    }

    // Ports
    port def GasInletPort {
        in item gas : GasSample;
    }
    port def PowerInputPort {
        in item power : ElectricalPower;
    }
    port def DigitalOutputPort {
        out item reading : OxygenReading;
    }
    port def AnalogSignalPort {
        out item signal : AnalogSignal;
    }
    port def DigitalSignalPort {
        out item signal : DigitalSignal;
    }
    port def RegulatedPowerPort {
        out item power : ElectricalPower;
    }

    // Requirements
    requirement def MeasurementAccuracyRequirement {
        doc "The system shall measure oxygen concentration accurately."
        attribute targetAccuracy : ConcentrationValue = 0.1;
    }
    requirement def OperatingTemperatureRequirement {
        doc "The Zirconia sensing element shall operate at 650C (923.15K)."
        attribute targetTemperature : TemperatureValue = 923.15;
    }
    
    requirement TempReq : OperatingTemperatureRequirement;
    requirement AccReq : MeasurementAccuracyRequirement;

    // Parts
    part def HeatingElement {
        port heaterPowerIn : RegulatedPowerPort;
        attribute targetTemp : TemperatureValue = 923.15;
        attribute currentTemp : TemperatureValue;
    }

    part def SensingElement {
        port gasIn : GasInletPort;
        port signalOut : AnalogSignalPort;
        attribute operatingTemp : TemperatureValue;
    }

    part def ZirconiaOxygenSensor {
        port gasIn : GasInletPort;
        port sensorPowerIn : RegulatedPowerPort;
        port signalOut : AnalogSignalPort;
        
        part heatingElement : HeatingElement;
        part sensingElement : SensingElement;
        
        connection heatingPowerConn connect sensorPowerIn to heatingElement.heaterPowerIn;
        connection gasConn connect gasIn to sensingElement.gasIn;
        connection signalConn connect sensingElement.signalOut to signalOut;
    }

    part def SignalAmplifier {
        port signalIn : AnalogSignalPort;
        port signalOut : AnalogSignalPort;
    }

    part def ADC {
        port analogIn : AnalogSignalPort;
        port digitalOut : DigitalSignalPort;
    }

    part def CalibrationMemory {
        attribute calibrationData : String;
    }

    part def Microcontroller {
        port digitalIn : DigitalSignalPort;
        port readingOut : DigitalOutputPort;
        part calibrationMemory : CalibrationMemory;
        
        action def CalculateConcentration {
            in digitalValue : DigitalSignal;
            out reading : OxygenReading;
        }
    }

    part def SignalProcessor {
        port analogIn : AnalogSignalPort;
        port processorPowerIn : RegulatedPowerPort;
        port readingOut : DigitalOutputPort;
        
        part adc : ADC;
        part microcontroller : Microcontroller;
        
        connection adcConn connect analogIn to adc.analogIn;
        connection digitalConn connect adc.digitalOut to microcontroller.digitalIn;
        connection readingConn connect microcontroller.readingOut to readingOut;
    }

    part def PowerModule {
        port mainPowerIn : PowerInputPort;
        port heaterPowerOut : RegulatedPowerPort;
        port electronicsPowerOut : RegulatedPowerPort;
    }

    part def OxygenSensingUnit {
        port gasIn : GasInletPort;
        port powerIn : PowerInputPort;
        port readingOut : DigitalOutputPort;
        
        part powerModule : PowerModule;
        part sensor : ZirconiaOxygenSensor;
        part amplifier : SignalAmplifier;
        part processor : SignalProcessor;
        
        attribute measurementTriggered : Boolean = false;
        attribute calibrationTriggered : Boolean = false;
        attribute measurementComplete : Boolean = false;
        attribute calibrationComplete : Boolean = false;
        attribute faultDetected : Boolean = false;
        
        connection powerInputConn connect powerIn to powerModule.mainPowerIn;
        connection heaterPowerConn connect powerModule.heaterPowerOut to sensor.sensorPowerIn;
        connection electronicsPowerConn connect powerModule.electronicsPowerOut to processor.processorPowerIn;
        
        connection gasInputConn connect gasIn to sensor.gasIn;
        connection sensorToAmpConn connect sensor.signalOut to amplifier.signalIn;
        connection ampToProcessorConn connect amplifier.signalOut to processor.analogIn;
        connection processorOutputConn connect processor.readingOut to readingOut;
        
        attribute status : SensorStatus = SensorStatus::INITIALIZING;
        
        state def Lifecycle {
            entry; then Initializing;
            
            state Initializing;
            transition init_to_warming first Initializing then WarmingUp;
                
            state WarmingUp;
            transition warming_to_ready 
                first WarmingUp 
                then Ready 
                when sensor.heatingElement.currentTemp >= sensor.heatingElement.targetTemp;
                
            state Ready;
            transition ready_to_measuring 
                first Ready 
                then Measuring 
                when measurementTriggered;
            transition ready_to_calibrating 
                first Ready 
                then Calibrating 
                when calibrationTriggered;
                
            state Measuring;
            transition measuring_to_ready 
                first Measuring 
                then Ready 
                when measurementComplete;
                
            state Calibrating;
            transition calibrating_to_ready 
                first Calibrating 
                then Ready 
                when calibrationComplete;
                
            state Error;
            transition any_to_error 
                first Initializing, WarmingUp, Ready, Measuring, Calibrating 
                then Error 
                when faultDetected;
        }
        
        satisfy TempReq by sensor.heatingElement;
        satisfy AccReq by processor.microcontroller;
    }
}
