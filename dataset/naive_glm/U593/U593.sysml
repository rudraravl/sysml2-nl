package AFRMeterSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQ::Temperature;
    import ISQ::ElectricPotential;
    import ISQ::Time;

    item def ExhaustGas {
        attribute temp : Temperature;
        attribute o2Concentration : Real;
    }
    item def RawVoltageSignal {
        attribute voltage : ElectricPotential;
    }
    item def ConditionedVoltageSignal {
        attribute voltage : ElectricPotential;
    }
    item def AFRData {
        attribute afr : Real;
        attribute lambda : Real;
        attribute isLean : Boolean;
        attribute isRich : Boolean;
    }

    requirement def ResponseTimeRequirement {
        attribute maxResponseTime : Time = 100 [ms];
        subject :>> system;
        constraint { system.updateTime <= maxResponseTime }
    }
    requirement def AccuracyRequirement {
        attribute minTemp : Temperature = 200 [K];
        attribute maxTemp : Temperature = 1200 [K];
        subject :>> system;
        constraint { system.operatingTemp >= minTemp and system.operatingTemp <= maxTemp }
    }

    part def Heater {
        attribute targetTemp : Temperature = 600 [K];
        attribute currentTemp : Temperature = 300 [K];
        attribute isAtOperatingTemp : Boolean = false;
    }

    part def WidebandOxygenSensor {
        port exhaustIn : in ExhaustGas;
        port rawSignalOut : out RawVoltageSignal;
        
        attribute operatingTemp : Temperature;
        attribute updateTime : Time;
        
        part heater : Heater;
        
        state def SensorStates {
            entry; then Heating;
            state Heating {
                entry { assign heater.isAtOperatingTemp = false; }
                do { assign heater.currentTemp = heater.currentTemp + 10 [K]; }
            }
            transition Heating to Active when heater.currentTemp >= heater.targetTemp;
            state Active {
                entry { assign heater.isAtOperatingTemp = true; }
                do { send RawVoltageSignal(voltage = 0.5 [V]) to rawSignalOut; }
            }
        }
        exhibit state SensorStates;
    }

    part def SignalConditioner {
        port rawSignalIn : in RawVoltageSignal;
        port conditionedSignalOut : out ConditionedVoltageSignal;
        
        action def ConditionSignal {
            in raw : RawVoltageSignal;
            out conditioned : ConditionedVoltageSignal;
            
            action FilterSignal {
                in rawIn : RawVoltageSignal;
                out filteredOut : RawVoltageSignal;
            }
            action AmplifySignal {
                in filteredIn : RawVoltageSignal;
                out amplifiedOut : ConditionedVoltageSignal;
            }
            
            flow raw to FilterSignal.rawIn;
            flow FilterSignal.filteredOut to AmplifySignal.filteredIn;
            flow AmplifySignal.amplifiedOut to conditioned;
        }
    }

    part def AFRProcessor {
        port conditionedSignalIn : in ConditionedVoltageSignal;
        port afrDataOut : out AFRData;
        
        attribute afrLookupTable : Real [0..*] [0..*];
        
        action def ProcessAFR {
            in signal : ConditionedVoltageSignal;
            out data : AFRData;
            
            do {
                assign data.afr = 14.7;
                assign data.lambda = 1.0;
                assign data.isLean = false;
                assign data.isRich = false;
            }
        }
    }

    part def DisplayController {
        port afrDataIn : in AFRData;
        
        attribute displayValue : Real;
        attribute leanIndicatorOn : Boolean = false;
        attribute richIndicatorOn : Boolean = false;
        
        action def UpdateDisplay {
            in data : AFRData;
            
            do {
                assign displayValue = data.afr;
                assign leanIndicatorOn = data.isLean;
                assign richIndicatorOn = data.isRich;
            }
        }
    }

    part def AFRMeterSystem {
        port exhaustIn : in ExhaustGas;
        
        attribute operatingTemp : Temperature = 800 [K];
        attribute updateTime : Time = 50 [ms];
        
        requirement responseTimeReq : ResponseTimeRequirement {
            subject :>> system = this;
        }
        requirement accuracyReq : AccuracyRequirement {
            subject :>> system = this;
        }
        
        part sensor : WidebandOxygenSensor;
        part conditioner : SignalConditioner;
        part processor : AFRProcessor;
        part display : DisplayController;
        
        connect exhaustIn to sensor.exhaustIn;
        connect sensor.rawSignalOut to conditioner.rawSignalIn;
        connect conditioner.conditionedSignalOut to processor.conditionedSignalIn;
        connect processor.afrDataOut to display.afrDataIn;
    }
}
