package ThermistorTemperatureSensingSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def TemperatureValue :> ThermodynamicTemperatureValue;
    attribute def ResistanceValue :> ElectricalResistanceValue;
    attribute def VoltageValue :> ElectricPotentialValue;
    attribute def CurrentValue :> ElectricCurrentValue;
    
    enum def ThermistorType {
        NTC {
            doc /* Negative Temperature Coefficient - resistance decreases with temperature increase */
        }
        PTC {
            doc /* Positive Temperature Coefficient - resistance increases with temperature increase */
        }
    }
    
    enum def SystemState {
        initializing;
        measuring;
        processing;
        outputting;
        error;
    }
    
    item def TemperatureReading {
        attribute value : TemperatureValue;
        attribute timestamp : TimeInstantValue;
        attribute valid : Boolean;
    }
    
    item def ResistanceReading {
        attribute value : ResistanceValue;
        attribute timestamp : TimeInstantValue;
    }
    
    port def SensorPort {
        out resistance : ResistanceReading;
    }
    
    port def AnalogPort {
        in voltage : VoltageValue;
        out current : CurrentValue;
    }
    
    port def DataPort {
        out reading : TemperatureReading;
    }
    
    port def PowerPort {
        in supplyVoltage : VoltageValue;
        out groundConnection : Boolean;
    }
    
    part def ThermistorElement {
        doc /* The thermistor is a temperature-sensitive resistor whose resistance 
             * varies predictably with temperature changes. */
        
        attribute thermistorType : ThermistorType;
        attribute nominalResistance : ResistanceValue;
        attribute betaCoefficient : Real;
        attribute referenceTemperature : TemperatureValue;
        attribute currentResistance : ResistanceValue;
        attribute tolerance : Real;
        
        port sensorOutput : SensorPort;
        port analogInterface : AnalogPort;
    }
    
    part def VoltageDividerCircuit {
        doc /* Converts thermistor resistance variation into measurable voltage changes. */
        
        attribute referenceResistance : ResistanceValue;
        attribute supplyVoltage : VoltageValue;
        attribute outputVoltage : VoltageValue;
        
        port thermistorInput : AnalogPort;
        port voltageOutput : AnalogPort;
        port power : PowerPort;
        
        assert constraint voltageDividerEquation {
            outputVoltage == supplyVoltage * (referenceResistance / (referenceResistance + thermistorInput.current))
        }
    }
    
    part def SignalConditioner {
        doc /* Amplifies and filters the voltage signal for accurate conversion. */
        
        attribute gain : Real;
        attribute filterCutoffFrequency : Real;
        attribute inputVoltage : VoltageValue;
        attribute outputVoltage : VoltageValue;
        
        port analogInput : AnalogPort;
        port analogOutput : AnalogPort;
        port power : PowerPort;
    }
    
    part def AnalogToDigitalConverter {
        doc /* Converts analog voltage to digital value for processing. */
        
        attribute resolution : Integer;
        attribute samplingRate : Real;
        attribute referenceVoltage : VoltageValue;
        attribute digitalOutput : Integer;
        
        port analogInput : AnalogPort;
        port power : PowerPort;
    }
    
    part def Microcontroller {
        doc /* Processes digital data and calculates temperature using thermistor equations. */
        
        attribute processorSpeed : Real;
        attribute calculatedTemperature : TemperatureValue;
        attribute calibrationOffset : TemperatureValue;
        
        port dataInput;
        port dataOutput : DataPort;
        port power : PowerPort;
        
        perform action processTemperature : CalculateTemperature;
    }
    
    part def OutputInterface {
        doc /* Displays or transmits temperature readings to external systems. */
        
        attribute displayResolution : Real;
        attribute updateRate : Real;
        attribute currentReading : TemperatureValue;
        
        port dataInput : DataPort;
        port power : PowerPort;
    }
    
    part def PowerManagement {
        doc /* Provides regulated power to all system components. */
        
        attribute inputVoltage : VoltageValue;
        attribute outputVoltage : VoltageValue;
        attribute maxCurrent : CurrentValue;
        attribute efficiency : Real;
        
        port powerInput : PowerPort;
        port powerOutput : PowerPort[5];
    }
    
    action def MeasureResistance {
        in appliedVoltage : VoltageValue;
        in measuredCurrent : CurrentValue;
        out resistance : ResistanceValue;
        
        first start;
        then action calculateResistance {
            resistance = appliedVoltage / measuredCurrent;
        }
        then done;
    }
    
    action def CalculateTemperature {
        in resistance : ResistanceValue;
        in nominalResistance : ResistanceValue;
        in betaValue : Real;
        in referenceTemp : TemperatureValue;
        out temperature : TemperatureValue;
        
        first start;
        then action computeSteinhart;
        then action applyCalibration;
        then action validateRange;
        then done;
    }
    
    action def AcquireData {
        in samplingInterval : DurationValue;
        out dataReady : Boolean;
        
        first start;
        then action waitForSample;
        then action triggerConversion;
        then action readDigitalValue {
            dataReady = true;
        }
        then done;
    }
    
    action def SystemOperation {
        first start;
        then merge continuousMonitoring;
        
        then action initialize {
            doc /* Initialize all system components and perform self-test */
        }
        
        then action measureResistance : MeasureResistance;
        
        then action convertSignal : AcquireData {
            in samplingInterval = 1.0 [s];
        }
        
        then action calculateTemp : CalculateTemperature;
        
        then action outputReading;
        
        then decide;
            if calculateTemp.temperature >= -40.0 [Celsius] and 
               calculateTemp.temperature <= 125.0 [Celsius] 
            then continuousMonitoring;
            if calculateTemp.temperature < -40.0 [Celsius] or 
               calculateTemp.temperature > 125.0 [Celsius] 
            then handleError;
        
        action handleError;
        then continuousMonitoring;
    }
    
    state def ThermistorSystemStateMachine {
        entry; then powerOn;
        
        state powerOn {
            entry assign currentState = SystemState::initializing;
        }
        then initialization;
        
        state initialization {
            do action selfTest;
        }
        then decide;
            if selfTest.passed then operationalMode;
            if not selfTest.passed then errorMode;
        
        state operationalMode {
            entry assign currentState = SystemState::measuring;
            
            state measuring {
                do action acquireSample;
            }
            then processing;
            
            state processing {
                entry assign currentState = SystemState::processing;
                do action computeTemperature;
            }
            then outputting;
            
            state outputting {
                entry assign currentState = SystemState::outputting;
                do action transmitReading;
            }
            then measuring;
        }
        accept calibrationRequest then calibrationMode;
        
        state calibrationMode {
            do action performCalibration;
        }
        then operationalMode;
        
        state errorMode {
            entry assign currentState = SystemState::error;
        }
        accept resetCommand then initialization;
    }
    
    part thermistorSystem : ThermistorSystem {
        doc /* Complete temperature sensing system using thermistor technology 
             * for accurate ambient temperature measurement and monitoring. */
        
        attribute systemState : SystemState = SystemState::initializing;
        attribute operatingTemperatureRange : TemperatureValue[2];
        attribute measurementAccuracy : TemperatureValue;
        
        part sensor : ThermistorElement {
            attribute :>> thermistorType = ThermistorType::NTC;
            attribute :>> nominalResistance = 10000.0 [ohm];
            attribute :>> betaCoefficient = 3950.0;
            attribute :>> referenceTemperature = 25.0 [Celsius];
            attribute :>> tolerance = 0.01;
        }
        
        part divider : VoltageDividerCircuit {
            attribute :>> referenceResistance = 10000.0 [ohm];
            attribute :>> supplyVoltage = 5.0 [V];
        }
        
        part conditioner : SignalConditioner {
            attribute :>> gain = 2.0;
            attribute :>> filterCutoffFrequency = 100.0;
        }
        
        part adc : AnalogToDigitalConverter {
            attribute :>> resolution = 12;
            attribute :>> samplingRate = 10.0;
            attribute :>> referenceVoltage = 5.0 [V];
        }
        
        part processor : Microcontroller {
            attribute :>> processorSpeed = 16000000.0;
            attribute :>> calibrationOffset = 0.0 [Celsius];
        }
        
        part output : OutputInterface {
            attribute :>> displayResolution = 0.1;
            attribute :>> updateRate = 1.0;
        }
        
        part powerMgmt : PowerManagement {
            attribute :>> inputVoltage = 12.0 [V];
            attribute :>> outputVoltage = 5.0 [V];
            attribute :>> maxCurrent = 0.5 [A];
            attribute :>> efficiency = 0.85;
        }
        
        connection sensorToDivider 
            connect sensor.analogInterface to divider.thermistorInput;
        
        connection dividerToConditioner 
            connect divider.voltageOutput to conditioner.analogInput;
        
        connection conditionerToADC 
            connect conditioner.analogOutput to adc.analogInput;
        
        connection adcToProcessor 
            connect adc to processor.dataInput;
        
        connection processorToOutput 
            connect processor.dataOutput to output.dataInput;
        
        connection powerToSensor 
            connect powerMgmt.powerOutput[0] to sensor;
        
        connection powerToDivider 
            connect powerMgmt.powerOutput[1] to divider.power;
        
        connection powerToConditioner 
            connect powerMgmt.powerOutput[2] to conditioner.power;
        
        connection powerToADC 
            connect powerMgmt.powerOutput[3] to adc.power;
        
        connection powerToProcessor 
            connect powerMgmt.powerOutput[4] to processor.power;
        
        perform action systemOp : SystemOperation;
    }
    
    requirement <'SYS-REQ-001'> primaryFunction {
        doc /* The thermistor-based system shall continuously sense ambient temperature 
             * by measuring the temperature-dependent resistance change of the thermistor 
             * element and converting this physical property into accurate, calibrated 
             * temperature readings suitable for monitoring and control applications. */
        
        subject system :> thermistorSystem;
        
        require accuracyRequirement;
        require rangeRequirement;
        require responseTimeRequirement;
        require powerRequirement;
    }
    
    requirement <'SYS-REQ-002'> accuracyRequirement {
        doc /* The system shall provide temperature measurements with an accuracy 
             * of ±0.5°C over the specified operating range. */
        
        subject system :> thermistorSystem;
        
        assert constraint {
            system.measurementAccuracy <= 0.5 [Celsius]
        }
    }
    
    requirement <'SYS-REQ-003'> rangeRequirement {
        doc /* The system shall measure temperatures across the range of 
             * -40°C to +125°C. */
        
        subject system :> thermistorSystem;
        
        assert constraint {
            system.operatingTemperatureRange[0] == -40.0 [Celsius] and
            system.operatingTemperatureRange[1] == 125.0 [Celsius]
        }
    }
    
    requirement <'SYS-REQ-004'> responseTimeRequirement {
        doc /* The thermistor sensor shall respond to 63.2% of a step temperature 
             * change within 2 seconds. */
        
        subject sensor :> thermistorSystem.sensor;
    }
    
    requirement <'SYS-REQ-005'> powerRequirement {
        doc /* The system shall operate from a 12V DC power source and consume 
             * no more than 0.5A during normal operation. */
        
        subject power :> thermistorSystem.powerMgmt;
        
        assert constraint {
            power.inputVoltage == 12.0 [V] and
            power.maxCurrent <= 0.5 [A]
        }
    }
    
    requirement <'SYS-REQ-006'> samplingRequirement {
        doc /* The system shall acquire and process temperature readings at a 
             * minimum rate of 1 Hz. */
        
        subject adc :> thermistorSystem.adc;
        
        assert constraint {
            adc.samplingRate >= 1.0
        }
    }
    
    requirement <'SYS-REQ-007'> resolutionRequirement {
        doc /* The ADC shall provide at least 12-bit resolution for accurate 
             * temperature conversion. */
        
        subject adc :> thermistorSystem.adc;
        
        assert constraint {
            adc.resolution >= 12
        }
    }
    
    satisfy primaryFunction by thermistorSystem;
}
