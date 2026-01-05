package ResistanceThermometerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def TemperatureCoefficient :> Real;
    
    item def ElectricalSignal {
        attribute voltage : ISQ::VoltageValue;
        attribute current : ISQ::ElectricCurrentValue;
        attribute resistance : ISQ::ElectricalResistanceValue;
    }
    
    item def TemperatureReading {
        attribute temperature : ISQ::ThermodynamicTemperatureValue;
        attribute timestamp : ISQ::TimeValue;
        attribute accuracy : ISQ::ThermodynamicTemperatureValue;
    }
    
    port def SensingPort {
        out item signal : ElectricalSignal;
    }
    
    port def ExcitationPort {
        in item excitation : ElectricalSignal;
    }
    
    port def OutputPort {
        out item reading : TemperatureReading;
    }
    
    part def RTDSensor {
        attribute nominalResistance : ISQ::ElectricalResistanceValue;
        attribute temperatureCoefficient : TemperatureCoefficient;
        attribute referenceTemperature : ISQ::ThermodynamicTemperatureValue;
        
        port sensingPort : SensingPort;
        port excitationPort : ExcitationPort;
        
        action sense {
            in appliedVoltage : ISQ::VoltageValue;
            in ambientTemperature : ISQ::ThermodynamicTemperatureValue;
            out measuredResistance : ISQ::ElectricalResistanceValue;
        }
    }
    
    part def SignalConditioner {
        port inputPort : SensingPort;
        port outputPort {
            out item conditionedSignal : ElectricalSignal;
        }
        
        action amplify {
            in rawSignal : ElectricalSignal;
            out amplifiedSignal : ElectricalSignal;
        }
        
        action filterSignal {
            in noisySignal : ElectricalSignal;
            out filteredSignal : ElectricalSignal;
        }
    }
    
    part def TemperatureConverter {
        attribute calibrationCurve : Real[*];
        
        port inputPort {
            in item signal : ElectricalSignal;
        }
        port outputPort : OutputPort;
        
        action convertResistanceToTemperature {
            in resistance : ISQ::ElectricalResistanceValue;
            in nominalR : ISQ::ElectricalResistanceValue;
            in alpha : TemperatureCoefficient;
            in refTemp : ISQ::ThermodynamicTemperatureValue;
            out temperature : ISQ::ThermodynamicTemperatureValue;
        }
    }
    
    part def ExcitationSource {
        attribute constantCurrent : ISQ::ElectricCurrentValue;
        
        port outputPort : ExcitationPort;
        
        action provideExcitation {
            out excitationCurrent : ISQ::ElectricCurrentValue;
        }
    }
    
    part def Display {
        port inputPort {
            in item reading : TemperatureReading;
        }
        
        action displayTemperature {
            in reading : TemperatureReading;
        }
    }
    
    requirement def MeasurementAccuracyRequirement {
        doc /* The temperature measurement accuracy shall be within specified tolerance. */
        
        subject thermometer : ResistanceThermometer;
        attribute tolerance : ISQ::ThermodynamicTemperatureValue;
        
        require constraint {
            tolerance <= thermometer.requiredAccuracy
        }
    }
    
    requirement def ResponseTimeRequirement {
        doc /* The system shall respond to temperature changes within specified time. */
        
        subject thermometer : ResistanceThermometer;
        
        require constraint {
            thermometer.maxResponseTime <= 2.0
        }
    }
    
    requirement def OperatingRangeRequirement {
        doc /* The system shall operate within specified temperature range. */
        
        subject thermometer : ResistanceThermometer;
        
        require constraint {
            thermometer.minOperatingTemp >= -200.0 and
            thermometer.maxOperatingTemp <= 850.0
        }
    }
    
    part def ResistanceThermometer {
        attribute requiredAccuracy : ISQ::ThermodynamicTemperatureValue;
        attribute maxResponseTime : ISQ::TimeValue;
        attribute minOperatingTemp : Real;
        attribute maxOperatingTemp : Real;
        
        part rtdSensor : RTDSensor {
            attribute :>> nominalResistance = 100.0;
            attribute :>> temperatureCoefficient = 0.00385;
            attribute :>> referenceTemperature = 273.15;
        }
        
        part excitationSource : ExcitationSource {
            attribute :>> constantCurrent = 0.001;
        }
        
        part signalConditioner : SignalConditioner;
        
        part converter : TemperatureConverter;
        
        part display : Display;
        
        connect excitationSource.outputPort to rtdSensor.excitationPort;
        connect rtdSensor.sensingPort to signalConditioner.inputPort;
        connect signalConditioner.outputPort to converter.inputPort;
        connect converter.outputPort to display.inputPort;
        
        perform action measureTemperature;
    }
    
    action def MeasureTemperature {
        first start;
        then action applyExcitation {
            out excitationSignal : ElectricalSignal;
        }
        then action senseResistance {
            in excitation : ElectricalSignal;
            out resistanceSignal : ElectricalSignal;
        }
        then action conditionSignal {
            in rawSignal : ElectricalSignal;
            out conditionedSignal : ElectricalSignal;
        }
        then action convertToTemperature {
            in signal : ElectricalSignal;
            out temperatureReading : TemperatureReading;
        }
        then action displayReading {
            in reading : TemperatureReading;
        }
        then done;
    }
    
    part resistanceThermometerSystem : ResistanceThermometer {
        attribute :>> requiredAccuracy = 0.1;
        attribute :>> maxResponseTime = 1.5;
        attribute :>> minOperatingTemp = -200.0;
        attribute :>> maxOperatingTemp = 850.0;
        
        perform action measureTemperature : MeasureTemperature {
            first applyExcitation;
            then senseResistance;
            then conditionSignal;
            then convertToTemperature;
            then displayReading;
        }
        
        part :>> rtdSensor {
            perform measureTemperature.senseResistance;
        }
        
        part :>> excitationSource {
            perform measureTemperature.applyExcitation;
        }
        
        part :>> signalConditioner {
            perform measureTemperature.conditionSignal;
        }
        
        part :>> converter {
            perform measureTemperature.convertToTemperature;
        }
        
        part :>> display {
            perform measureTemperature.displayReading;
        }
        
        satisfy measurementAccuracy : MeasurementAccuracyRequirement;
        satisfy responseTime : ResponseTimeRequirement;
        satisfy operatingRange : OperatingRangeRequirement;
    }
    
    state def ThermometerOperatingStates {
        entry; then idle;
        
        state idle;
        transition idle_to_measuring
            first idle
            then measuring;
        
        state measuring {
            entry; then applyingExcitation;
            
            state applyingExcitation;
            transition applyingExcitation_to_sensing
                first applyingExcitation
                then sensing;
            
            state sensing;
            transition sensing_to_converting
                first sensing
                then converting;
            
            state converting;
            transition converting_to_displaying
                first converting
                then displaying;
            
            state displaying;
        }
        
        transition measuring_to_idle
            first measuring.displaying
            then idle;
    }
    
    part thermometerWithStates : ResistanceThermometer {
        exhibit state operatingStates : ThermometerOperatingStates;
    }
}
