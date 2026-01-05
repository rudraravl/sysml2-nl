package CapacitanceProbeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def DielectricConstant :> Real;
    
    attribute def CapacitanceValue :> Real;
    
    attribute def VoltageValue :> Real;
    
    attribute def CurrentValue :> Real;
    
    attribute def FrequencyValue :> Real;
    
    attribute def DistanceValue :> Real;
    
    item def ExcitationSignal {
        attribute voltage : VoltageValue;
        attribute frequency : FrequencyValue;
    }
    
    item def CapacitanceReading {
        attribute capacitance : CapacitanceValue;
        attribute timestamp : Real;
    }
    
    item def ProcessedData {
        attribute materialThickness : DistanceValue;
        attribute dielectricConstant : DielectricConstant;
        attribute quality : Real;
    }
    
    port def ExcitationPort {
        out signal : ExcitationSignal;
    }
    
    port def SensingPort {
        in excitation : ExcitationSignal;
        out reading : CapacitanceReading;
    }
    
    port def DataPort {
        in rawData : CapacitanceReading;
        out processedData : ProcessedData;
    }
    
    port def PowerPort {
        in voltage : VoltageValue;
        in current : CurrentValue;
    }
    
    part def OscillatorCircuit {
        attribute outputFrequency : FrequencyValue;
        attribute outputAmplitude : VoltageValue;
        
        port excitationOut : ExcitationPort;
        port power : PowerPort;
    }
    
    part def ProbeSensor {
        attribute sensorArea : Real;
        attribute plateSpacing : DistanceValue;
        attribute sensitivity : Real;
        
        port sensing : SensingPort;
    }
    
    part def SignalProcessor {
        attribute gain : Real;
        attribute filterBandwidth : FrequencyValue;
        
        port dataIn : ~SensingPort;
        port dataOut : DataPort;
        port power : PowerPort;
    }
    
    part def PowerSupplyUnit {
        attribute nominalVoltage : VoltageValue;
        attribute maxCurrent : CurrentValue;
        
        port powerOut : PowerPort;
    }
    
    part def DisplayInterface {
        attribute updateRate : Real;
        
        port dataInput : ~DataPort;
    }
    
    action def GenerateExcitationSignal {
        in frequency : FrequencyValue;
        in amplitude : VoltageValue;
        out excitationSignal : ExcitationSignal;
    }
    
    action def MeasureCapacitance {
        in excitation : ExcitationSignal;
        in targetDielectric : DielectricConstant;
        in targetDistance : DistanceValue;
        out capacitanceReading : CapacitanceReading;
    }
    
    action def ProcessCapacitanceData {
        in rawReading : CapacitanceReading;
        in calibrationFactor : Real;
        out thickness : DistanceValue;
        out dielectric : DielectricConstant;
    }
    
    action def ValidateMeasurement {
        in reading : CapacitanceReading;
        out isValid : Boolean;
    }
    
    action def PerformCapacitiveMeasurement {
        in targetMaterialDielectric : DielectricConstant;
        in nominalDistance : DistanceValue;
        out finalResult : ProcessedData;
        
        first start;
        then merge continuousMeasurement;
        
        then action generateSignal : GenerateExcitationSignal {
            in frequency = 100.0;
            in amplitude = 5.0;
            out excitationSignal;
        }
        
        then action measure : MeasureCapacitance {
            in excitation = generateSignal.excitationSignal;
            in targetDielectric = targetMaterialDielectric;
            in targetDistance = nominalDistance;
            out capacitanceReading;
        }
        
        then action validate : ValidateMeasurement {
            in reading = measure.capacitanceReading;
            out isValid;
        }
        
        then decide;
            if validate.isValid then processData;
            if not validate.isValid then recalibrate;
        
        action processData : ProcessCapacitanceData {
            in rawReading = measure.capacitanceReading;
            in calibrationFactor = 1.0;
            out thickness;
            out dielectric;
        }
        then assign finalResult.materialThickness := processData.thickness;
        then assign finalResult.dielectricConstant := processData.dielectric;
        then assign finalResult.quality := 1.0;
        then continuousMeasurement;
        
        action recalibrate;
        then continuousMeasurement;
    }
    
    state def ProbeSystemStates {
        entry; then powerOff;
        
        state powerOff;
        accept systemPowerOn;
        then initialization;
        
        state initialization;
        accept testComplete;
        then standby;
        
        state standby;
        accept startMeasurement;
        then active;
        
        state active;
        accept pauseMeasurement;
        then standby;
        
        accept systemShutdown;
        then powerOff;
    }
    
    part capacitanceProbeSystem {
        doc /* A capacitance probe system that measures material properties by detecting 
                changes in capacitance between a probe electrode and a target surface. The system 
                generates an AC excitation signal, measures the resulting capacitance, and processes 
                the data to determine material thickness, dielectric properties, and proximity. */
        
        attribute systemState : String;
        attribute currentMeasurement : ProcessedData;
        
        perform action measurementOperation[*] ordered 
            references performCapacitiveMeasurement;
        
        part oscillator : OscillatorCircuit {
            attribute :>> outputFrequency = 100.0;
            attribute :>> outputAmplitude = 5.0;
            
            perform measurementOperation.generateSignal;
        }
        
        part probe : ProbeSensor {
            attribute :>> sensorArea = 0.001;
            attribute :>> plateSpacing = 0.002;
            attribute :>> sensitivity = 0.98;
            
            perform measurementOperation.measure;
        }
        
        part processor : SignalProcessor {
            attribute :>> gain = 50.0;
            attribute :>> filterBandwidth = 10.0;
            
            perform measurementOperation.processData;
        }
        
        part powerSupply : PowerSupplyUnit {
            attribute :>> nominalVoltage = 24.0;
            attribute :>> maxCurrent = 0.5;
        }
        
        part display : DisplayInterface {
            attribute :>> updateRate = 10.0;
        }
        
        connect oscillator.excitationOut to probe.sensing;
        connect probe.sensing to processor.dataIn;
        connect processor.dataOut to display.dataInput;
        connect powerSupply.powerOut to oscillator.power;
        connect powerSupply.powerOut to processor.power;
    }
    
    requirement def AccuracyRequirement {
        doc /* The measurement accuracy shall be within specified tolerance. */
    }
    
    requirement def ResponseTimeRequirement {
        doc /* The system shall provide measurement updates at a minimum rate. */
    }
    
    requirement def RangeRequirement {
        doc /* The system shall operate over a specified capacitance range. */
    }
    
    requirement <'SYS-REQ-001'> primaryMeasurementCapability {
        doc /* The capacitance probe system shall measure the dielectric properties, thickness, 
                and proximity of materials by detecting capacitance variations between the probe 
                electrode and target surface, enabling non-contact material characterization and 
                displacement sensing. */
        
        subject capacitanceProbeSystem;
        
        require accuracy : AccuracyRequirement;
        require responseTime : ResponseTimeRequirement;
        require operatingRange : RangeRequirement;
    }
    
    satisfy primaryMeasurementCapability by capacitanceProbeSystem.measurementOperation;
}
