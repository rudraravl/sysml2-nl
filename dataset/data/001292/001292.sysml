package TransducerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    enum def EnergyDomain {
        mechanical;
        electrical;
        thermal;
        optical;
        magnetic;
        acoustic;
    }
    
    attribute def Sensitivity :> Real;
    attribute def Efficiency :> Real;
    
    port def InputPort {
        attribute signalLevel : Real;
        attribute domain : EnergyDomain;
    }
    
    port def OutputPort {
        attribute signalLevel : Real;
        attribute domain : EnergyDomain;
    }
    
    port def PowerPort {
        attribute voltage : VoltageValue;
        attribute current : ElectricCurrentValue;
    }
    
    part def SensingElement {
        doc /* Physical element that responds to input stimulus */
        attribute responseTime : TimeValue;
        port input : InputPort;
    }
    
    part def ConversionElement {
        doc /* Core element that performs energy domain conversion */
        attribute conversionGain : Real;
        attribute linearityError : Real;
    }
    
    part def SignalProcessor {
        doc /* Conditions and amplifies the transduced signal */
        attribute gain : Real;
        attribute bandwidth : Real;
        port input : InputPort;
        port output : OutputPort;
    }
    
    part def PowerSupply {
        doc /* Provides regulated power to transducer components */
        attribute outputVoltage : VoltageValue;
        attribute outputCurrent : ElectricCurrentValue;
        port powerOut : PowerPort;
    }
    
    part def Transducer {
        doc /* Converts energy from one physical domain to another,
             * enabling measurement and signal transformation */
        
        attribute inputDomain : EnergyDomain;
        attribute outputDomain : EnergyDomain;
        attribute sensitivity : Sensitivity;
        attribute efficiency : Efficiency;
        attribute operatingTempMin : ThermodynamicTemperatureValue;
        attribute operatingTempMax : ThermodynamicTemperatureValue;
        
        port signalIn : InputPort {
            attribute :>> domain = inputDomain;
        }
        port signalOut : OutputPort {
            attribute :>> domain = outputDomain;
        }
        port power : PowerPort;
        
        part sensor : SensingElement {
            attribute :>> responseTime = 0.001 [s];
        }
        
        part converter : ConversionElement {
            attribute :>> conversionGain = 0.05;
            attribute :>> linearityError = 0.02;
        }
        
        part processor : SignalProcessor {
            attribute :>> gain = 100.0;
            attribute :>> bandwidth = 10000.0;
        }
        
        connection sensorToConverter connect sensor.input to signalIn;
        connection processorToOutput connect processor.output to signalOut;
    }
    
    action def InitializeTransducer {
        out initialized : Boolean;
    }
    
    action def CalibrateTransducer {
        in referenceValue : Real;
        out calibrationFactor : Real;
    }
    
    action def ConvertSignal {
        in inputSignal : Real;
        in inputDomain : EnergyDomain;
        out outputSignal : Real;
        out outputDomain : EnergyDomain;
    }
    
    action def ProcessSignal {
        in rawSignal : Real;
        in gainValue : Real;
        out processedSignal : Real;
    }
    
    action def TransmitOutput {
        in signal : Real;
    }
    
    state def TransducerStates {
        entry; then powerUp;
        
        state powerUp;
        accept at powerUp then initializing;
        
        state initializing {
            entry; then performInit;
        }
        
        state performInit;
        accept at performInit then calibrating;
        
        state calibrating {
            entry; then performCalibration;
        }
        
        state performCalibration;
        accept at performCalibration then operational;
        
        state operational {
            entry; then sensing;
        }
        
        state sensing;
        accept at sensing then converting;
        
        state converting {
            entry; then performConversion;
        }
        
        state performConversion;
        accept at performConversion then processing;
        
        state processing {
            entry; then performProcessing;
        }
        
        state performProcessing;
        accept at performProcessing then transmitting;
        
        state transmitting {
            entry; then sendOutput;
        }
        
        state sendOutput;
        accept at sendOutput then operational;
    }
    
    action def TransducerOperation {
        first start;
        then action init : InitializeTransducer {
            out initialized : Boolean;
        }
        then merge operationCycle;
        
        action calibrate : CalibrateTransducer {
            in referenceValue : Real;
            out calibrationFactor : Real;
        }
        
        then action convert : ConvertSignal {
            in inputSignal : Real;
            in inputDomain : EnergyDomain;
            out outputSignal : Real;
            out outputDomain : EnergyDomain;
        }
        
        then action process : ProcessSignal {
            in rawSignal = convert.outputSignal;
            in gainValue : Real;
            out processedSignal : Real;
        }
        
        then action transmit : TransmitOutput {
            in signal = process.processedSignal;
        }
        
        then operationCycle;
    }
    
    part pressureTransducerSystem : Transducer {
        doc /* Pressure measurement transducer system converting mechanical
             * pressure into electrical voltage for industrial monitoring */
        
        attribute :>> inputDomain = EnergyDomain::mechanical;
        attribute :>> outputDomain = EnergyDomain::electrical;
        attribute :>> sensitivity = 0.01;
        attribute :>> efficiency = 0.88;
        attribute :>> operatingTempMin = 233.15 [K];
        attribute :>> operatingTempMax = 398.15 [K];
        
        part :>> sensor {
            attribute :>> responseTime = 0.0005 [s];
        }
        
        part :>> converter {
            attribute :>> conversionGain = 0.01;
            attribute :>> linearityError = 0.015;
        }
        
        part :>> processor {
            attribute :>> gain = 150.0;
            attribute :>> bandwidth = 15000.0;
        }
        
        part powerModule : PowerSupply {
            attribute :>> outputVoltage = 24.0 [V];
            attribute :>> outputCurrent = 0.1 [A];
        }
        
        connection powerConnection connect powerModule.powerOut to power;
        
        perform action operation : TransducerOperation;
    }
    
    requirement <'REQ-T001'> primaryFunction {
        doc /* The transducer system shall convert mechanical pressure signals
             * into proportional electrical voltage signals for measurement,
             * monitoring, and control applications */
        subject system :> pressureTransducerSystem;
    }
    
    requirement <'REQ-T002'> conversionEfficiency {
        doc /* The transducer shall maintain energy conversion efficiency
             * of at least 85% across the operating range */
        subject system :> pressureTransducerSystem;
        
        require constraint {
            system.efficiency >= 0.85
        }
    }
    
    requirement <'REQ-T003'> sensitivity {
        doc /* The transducer shall provide minimum sensitivity of 0.01 V/Pa
             * for accurate pressure measurement */
        subject system :> pressureTransducerSystem;
        
        require constraint {
            system.sensitivity >= 0.01
        }
    }
    
    requirement <'REQ-T004'> operatingTemperature {
        doc /* The transducer shall operate reliably across temperature
             * range from -40°C to +125°C */
        subject system :> pressureTransducerSystem;
        
        require constraint {
            system.operatingTempMin <= 233.15 [K] and
            system.operatingTempMax >= 398.15 [K]
        }
    }
    
    requirement <'REQ-T005'> responseTime {
        doc /* The sensing element shall respond to input changes
             * within 1 millisecond */
        subject sensor :> pressureTransducerSystem.sensor;
        
        require constraint {
            sensor.responseTime <= 0.001 [s]
        }
    }
    
    requirement <'REQ-T006'> signalProcessing {
        doc /* The signal processor shall provide adjustable gain
             * with minimum bandwidth of 10 kHz */
        subject processor :> pressureTransducerSystem.processor;
        
        require constraint {
            processor.gain >= 50.0 and
            processor.bandwidth >= 10000.0
        }
    }
    
    requirement systemRequirements {
        doc /* Complete transducer system requirements for pressure
             * measurement and signal conversion */
        
        assume constraint inputAvailable {
            doc /* Mechanical pressure input is available within
                 * specified operating range */
        }
        
        require primaryFunction;
        require conversionEfficiency;
        require sensitivity;
        require operatingTemperature;
        require responseTime;
        require signalProcessing;
    }
    
    satisfy systemRequirements by pressureTransducerSystem;
}
