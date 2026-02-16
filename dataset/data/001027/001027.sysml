package 'Displacement Receiver System' {
    private import ScalarValues::*;
    private import ISQ::*;
    
    attribute def DisplacementSignal;
    attribute def VoltageSignal;
    attribute def DigitalData;
    attribute def PositionOutput;
    
    item def SensorCore {
        attribute sensitivity : Real;
        attribute linearRange : LengthValue;
        attribute excitationVoltage : ElectricPotentialValue;
    }
    
    item def SignalConditioner {
        attribute gain : Real;
        attribute filterCutoff : FrequencyValue;
        attribute noiseRejection : Real;
    }
    
    item def AnalogToDigitalConverter {
        attribute resolution : Integer;
        attribute samplingRate : FrequencyValue;
        attribute conversionTime : TimeValue;
    }
    
    item def DataProcessor {
        attribute calibrationCoefficients : Real[*];
        attribute processingLatency : TimeValue;
    }
    
    port def MechanicalInputPort {
        in displacement : LengthValue;
    }
    
    port def AnalogSignalPort {
        out voltage : ElectricPotentialValue;
    }
    
    port def ConditionedSignalPort {
        out conditionedVoltage : ElectricPotentialValue;
    }
    
    port def DigitalDataPort {
        out digitalValue : Integer;
    }
    
    port def PositionDataPort {
        out position : LengthValue;
    }
    
    action def SenseDisplacement {
        in mechanicalDisplacement : LengthValue;
        in excitation : ElectricPotentialValue;
        out analogOutput : ElectricPotentialValue;
    }
    
    action def ConditionSignal {
        in rawVoltage : ElectricPotentialValue;
        out conditionedVoltage : ElectricPotentialValue;
    }
    
    action def DigitizeSignal {
        in analogInput : ElectricPotentialValue;
        out digitalOutput : Integer;
    }
    
    action def ComputePosition {
        in digitalInput : Integer;
        in calibration : Real[*];
        out computedPosition : LengthValue;
    }
    
    action def MeasureAndReportDisplacement {
        doc /* 
            Primary measurement action that coordinates the complete signal chain
            from mechanical displacement input to digital position output.
        */
        
        in mechanicalInput : LengthValue;
        in calibrationData : Real[*];
        out positionResult : LengthValue;
        
        first start;
        then merge continuousMeasurement;
        
        then action sense : SenseDisplacement {
            in mechanicalDisplacement = mechanicalInput;
            in excitation;
            out analogOutput : ElectricPotentialValue;
        }
        
        flow sense.analogOutput to condition.rawVoltage;
        
        then action condition : ConditionSignal {
            in rawVoltage : ElectricPotentialValue;
            out conditionedVoltage : ElectricPotentialValue;
        }
        
        flow condition.conditionedVoltage to digitize.analogInput;
        
        then action digitize : DigitizeSignal {
            in analogInput : ElectricPotentialValue;
            out digitalOutput : Integer;
        }
        
        flow digitize.digitalOutput to compute.digitalInput;
        
        then action compute : ComputePosition {
            in digitalInput : Integer;
            in calibration = calibrationData;
            out computedPosition : LengthValue;
        }
        
        then assign positionResult := compute.computedPosition;
        then continuousMeasurement;
    }
    
    state def DisplacementReceiverOperationalStates {
        entry; then initialization;
        
        state initialization;
        then ready;
        
        state ready;
        
        accept startMeasurement;
        then state measuring;
        
        accept stopMeasurement;
        then ready;
        
        accept calibrationCommand;
        then state calibrating;
        then ready;
        
        accept faultDetected;
        then state fault;
        
        accept faultCleared;
        then initialization;
    }
    
    part def DisplacementReceiver {
        doc /* 
            A displacement receiver system that converts mechanical displacement 
            into accurate digital position measurements through a multi-stage 
            signal processing chain.
        */
        
        attribute measurementRange : LengthValue;
        attribute accuracy : LengthValue;
        attribute repeatability : LengthValue;
        attribute operatingTemperature : TemperatureValue[2];
        attribute powerSupply : ElectricPotentialValue;
        
        port mechanicalInput : MechanicalInputPort;
        port positionOutput : PositionDataPort;
        
        part sensorCore : SensorCore {
            attribute sensitivity = 100.0;
            attribute linearRange : LengthValue;
            attribute excitationVoltage : ElectricPotentialValue;
        }
        
        part signalConditioner : SignalConditioner {
            attribute gain = 10.0;
            attribute filterCutoff : FrequencyValue;
            attribute noiseRejection = 60.0;
        }
        
        part adc : AnalogToDigitalConverter {
            attribute resolution = 16;
            attribute samplingRate : FrequencyValue;
            attribute conversionTime : TimeValue;
        }
        
        part dataProcessor : DataProcessor {
            attribute calibrationCoefficients : Real[*];
            attribute processingLatency : TimeValue;
        }
        
        connection sensorToConditioner connect sensorCore to signalConditioner;
        connection conditionerToADC connect signalConditioner to adc;
        connection adcToProcessor connect adc to dataProcessor;
    }
    
    part displacementReceiverSystem : DisplacementReceiver {
        doc /* 
            The displacement receiver system continuously monitors mechanical 
            displacement and converts it into precise digital position data. 
            The system operates by sensing physical displacement through a 
            high-sensitivity sensor core, conditioning the resulting analog 
            signal to remove noise and amplify the measurement, digitizing 
            the conditioned signal with high resolution, and processing the 
            digital data using calibration algorithms to produce accurate 
            position output suitable for control systems, data acquisition, 
            or monitoring applications.
        */
        
        attribute measurementRange : LengthValue;
        attribute accuracy : LengthValue;
        attribute repeatability : LengthValue;
        attribute operatingTemperature : TemperatureValue[2];
        attribute powerSupply : ElectricPotentialValue;
        
        perform action measurementCycle[*] ordered references MeasureAndReportDisplacement;
        
        part sensorCore : SensorCore {
            perform measurementCycle.sense;
            attribute sensitivity = 100.0;
            attribute linearRange : LengthValue;
            attribute excitationVoltage : ElectricPotentialValue;
        }
        
        part signalConditioner : SignalConditioner {
            perform measurementCycle.condition;
            attribute gain = 10.0;
            attribute filterCutoff : FrequencyValue;
            attribute noiseRejection = 60.0;
        }
        
        part adc : AnalogToDigitalConverter {
            perform measurementCycle.digitize;
            attribute resolution = 16;
            attribute samplingRate : FrequencyValue;
            attribute conversionTime : TimeValue;
        }
        
        part dataProcessor : DataProcessor {
            perform measurementCycle.compute;
            attribute calibrationCoefficients : Real[*];
            attribute processingLatency : TimeValue;
        }
    }
    
    requirement def AccuracyRequirement {
        doc /* The displacement receiver shall achieve specified measurement accuracy. */
        
        subject receiver : DisplacementReceiver;
    }
    
    requirement def RangeRequirement {
        doc /* The displacement receiver shall measure over the specified range. */
        
        subject receiver : DisplacementReceiver;
    }
    
    requirement def SamplingRateRequirement {
        doc /* The system shall sample at minimum specified rate for dynamic measurements. */
        
        subject receiver : DisplacementReceiver;
    }
    
    requirement def ResolutionRequirement {
        doc /* The ADC shall provide sufficient resolution for required accuracy. */
        
        subject receiver : DisplacementReceiver;
    }
    
    requirement displacementReceiverRequirements {
        doc /* 
            Top-level requirements for the displacement receiver system 
            ensuring accurate, reliable position measurement capability.
        */
        
        require accuracyReq : AccuracyRequirement;
        require rangeReq : RangeRequirement;
        require samplingReq : SamplingRateRequirement;
        require resolutionReq : ResolutionRequirement;
    }
    
    satisfy accuracyReq by displacementReceiverSystem;
    satisfy rangeReq by displacementReceiverSystem;
    satisfy samplingReq by displacementReceiverSystem;
    satisfy resolutionReq by displacementReceiverSystem;
}
