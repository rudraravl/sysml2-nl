package AFRMeterSystem {
    private import ScalarValues::*;
    
    attribute def VoltageValue :> Real;
    attribute def TemperatureValue :> Real;
    attribute def DurationValue :> Real;
    attribute def PowerValue :> Real;
    attribute def AFRValueType :> Real;
    attribute def LambdaValueType :> Real;
    
    enum def MixtureCondition {
        lean;
        rich;
        stoichiometric;
    }
    
    item def RawVoltageSignal {
        attribute value : VoltageValue;
    }
    item def ConditionedVoltageSignal {
        attribute value : VoltageValue;
    }
    item def AFRData {
        attribute afr : AFRValueType;
        attribute lambda : LambdaValueType;
        attribute condition : MixtureCondition;
    }
    
    port def RawVoltageOutPort {
        out signal : RawVoltageSignal;
    }
    port def RawVoltageInPort {
        in signal : RawVoltageSignal;
    }
    port def ConditionedVoltageOutPort {
        out signal : ConditionedVoltageSignal;
    }
    port def ConditionedVoltageInPort {
        in signal : ConditionedVoltageSignal;
    }
    port def AFRDataOutPort {
        out data : AFRData;
    }
    port def AFRDataInPort {
        in data : AFRData;
    }
    
    action def MeasureOxygen {
        out voltage : VoltageValue;
    }
    action def FilterNoise {
        in raw : VoltageValue;
        out filtered : VoltageValue;
    }
    action def AmplifySignal {
        in filtered : VoltageValue;
        out amplified : VoltageValue;
    }
    action def ConvertVoltageToAFR {
        in voltage : VoltageValue;
        out afr : AFRValueType;
        out lambda : LambdaValueType;
        out condition : MixtureCondition;
    }
    action def FormatDisplay {
        in afr : AFRValueType;
        in lambda : LambdaValueType;
        in condition : MixtureCondition;
    }
    action def UpdateIndicators {
        in condition : MixtureCondition;
    }
    action def RefreshDisplay :> Action {
        in afr : AFRValueType;
        in lambda : LambdaValueType;
        in condition : MixtureCondition;
        then action format : FormatDisplay {
            in afr = RefreshDisplay::afr;
            in lambda = RefreshDisplay::lambda;
            in condition = RefreshDisplay::condition;
        }
        then action updateIndicators : UpdateIndicators {
            in condition = RefreshDisplay::condition;
        }
    }
    action def HeatUp {
        out heatGenerated : PowerValue;
    }
    
    state def SensorStates;
    state def ProcessorStates;
    state def DisplayStates;
    
    part def Heater {
        attribute power : PowerValue;
        perform action heatUp : HeatUp;
    }
    
    part def WidebandOxygenSensor {
        attribute operatingTemp : TemperatureValue = 300;
        attribute currentTemp : TemperatureValue;
        part heater : Heater;
        port rawOut : RawVoltageOutPort;
        perform action measureOxygen : MeasureOxygen;
        exhibit state sensorStates : SensorStates {
            entry; then cold;
            state cold {
                do heater.heatUp;
            }
            accept when currentTemp >= operatingTemp then active;
            state active {
                do measureOxygen;
            }
        }
    }
    
    part def SignalConditioner {
        port rawIn : RawVoltageInPort;
        port condOut : ConditionedVoltageOutPort;
        perform action filterSignal : FilterNoise;
        perform action amplify : AmplifySignal;
    }
    
    part def AFRProcessor {
        port condIn : ConditionedVoltageInPort;
        port afrOut : AFRDataOutPort;
        perform action convert : ConvertVoltageToAFR;
        exhibit state processorStates : ProcessorStates {
            entry; then idle;
            state idle;
            accept ConditionedVoltageSignal then processing;
            state processing {
                do convert;
            }
        }
    }
    
    part def DisplayController {
        port afrIn : AFRDataInPort;
        perform action refresh : RefreshDisplay;
        exhibit state displayStates : DisplayStates {
            entry; then standby;
            state standby;
            accept AFRData then active;
            state active {
                do refresh;
            }
        }
    }
    
    requirement def ResponseTimeRequirement {
        attribute maxResponseTime : DurationValue = 0.1;
        attribute responseTime : DurationValue;
        assert constraint { responseTime <= maxResponseTime }
    }
    
    requirement def AccuracyRequirement {
        attribute minTemp : TemperatureValue = 200;
        attribute maxTemp : TemperatureValue = 1000;
        attribute afrError : AFRValueType;
        attribute maxError : AFRValueType = 0.1;
        assert constraint { afrError <= maxError }
    }
    
    part def AFRMeterAssembly {
        part sensor : WidebandOxygenSensor;
        part conditioner : SignalConditioner;
        part processor : AFRProcessor;
        part display : DisplayController;
        
        flow rawVoltageFlow of RawVoltageSignal 
            from sensor.rawOut.signal to conditioner.rawIn.signal;
        flow conditionedVoltageFlow of ConditionedVoltageSignal 
            from conditioner.condOut.signal to processor.condIn.signal;
        flow afrDataFlow of AFRData 
            from processor.afrOut.data to display.afrIn.data;
        
        requirement respTimeReq : ResponseTimeRequirement {
            attribute responseTime = 0.05;
        }
        requirement accReq : AccuracyRequirement {
            attribute afrError = 0.05;
        }
        
        satisfy respTimeReq by display;
        satisfy accReq by processor;
    }
    
    part afrMeter : AFRMeterAssembly {
        part :>> sensor {
            attribute :>> currentTemp = 350;
        }
        part :>> conditioner;
        part :>> processor;
        part :>> display;
    }
}
