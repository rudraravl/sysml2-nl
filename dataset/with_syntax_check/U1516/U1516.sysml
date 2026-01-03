package TotalPressureSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;
    
    doc /* 
     * This model describes a Total Pressure Measurement System used in fluid dynamics
     * applications such as aircraft pitot-static systems. The system measures total
     * (stagnation) pressure in a flowing fluid and computes derived quantities including
     * static pressure, dynamic pressure, and fluid velocity. The primary function is to
     * continuously monitor total pressure and provide accurate flow velocity data for
     * navigation, control, and safety systems.
     */
    
    attribute def TotalPressureValue :> PressureValue;
    attribute def StaticPressureValue :> PressureValue;
    attribute def DynamicPressureValue :> PressureValue;
    attribute def FluidVelocityValue :> SpeedValue;
    attribute def FluidDensityValue :> DensityValue;
    
    port def PressurePort {
        attribute pressure : PressureValue;
    }
    
    port def VelocityPort {
        attribute velocity : FluidVelocityValue;
    }
    
    port def DataOutputPort {
        attribute totalPressure : TotalPressureValue;
        attribute staticPressure : StaticPressureValue;
        attribute dynamicPressure : DynamicPressureValue;
        attribute velocity : FluidVelocityValue;
    }
    
    part def PitotProbe {
        doc /* Measures total (stagnation) pressure by facing directly into the flow. */
        attribute sensorAccuracy : Real;
        attribute calibrationFactor : Real;
        port totalPressureOut : PressurePort;
    }
    
    part def StaticPressureProbe {
        doc /* Measures static pressure perpendicular to flow direction. */
        attribute sensorAccuracy : Real;
        attribute calibrationFactor : Real;
        port staticPressureOut : PressurePort;
    }
    
    part def FluidMedium {
        doc /* Represents the fluid medium being measured. */
        attribute density : FluidDensityValue;
        attribute temperature : ThermodynamicTemperatureValue;
        attribute viscosity : Real;
    }
    
    part def PressureTransducer {
        doc /* Converts mechanical pressure to electrical signal. */
        in attribute inputPressure : PressureValue;
        out attribute outputVoltage : Real;
        attribute sensitivity : Real;
        attribute range : PressureValue;
    }
    
    part def DataProcessor {
        doc /* Processes pressure measurements and computes derived quantities. */
        in attribute totalPressureInput : TotalPressureValue;
        in attribute staticPressureInput : StaticPressureValue;
        in attribute fluidDensity : FluidDensityValue;
        out attribute computedDynamicPressure : DynamicPressureValue;
        out attribute computedVelocity : FluidVelocityValue;
        
        port dataIn : DataOutputPort;
        port dataOut : DataOutputPort;
        
        assert constraint dynamicPressureRelation {
            doc /* Dynamic pressure equals total pressure minus static pressure. */
            computedDynamicPressure == totalPressureInput - staticPressureInput
        }
        
        assert constraint velocityFromDynamicPressure {
            doc /* Velocity computed from Bernoulli equation: q = 0.5 * rho * v^2 */
            computedDynamicPressure == 0.5 * fluidDensity * (computedVelocity ** 2)
        }
    }
    
    part def DisplayUnit {
        doc /* Displays pressure and velocity data to operators. */
        in attribute totalPressure : TotalPressureValue;
        in attribute staticPressure : StaticPressureValue;
        in attribute dynamicPressure : DynamicPressureValue;
        in attribute velocity : FluidVelocityValue;
        
        port displayInput : DataOutputPort;
        
        attribute updateRate : FrequencyValue;
        attribute displayResolution : Real;
    }
    
    part def DataLogger {
        doc /* Records pressure and velocity data for analysis. */
        in attribute totalPressure : TotalPressureValue;
        in attribute velocity : FluidVelocityValue;
        
        attribute samplingRate : FrequencyValue;
        attribute storageCapacity : Real;
        
        port loggerInput : DataOutputPort;
    }
    
    action def MeasureTotalPressure {
        doc /* Action to acquire total pressure from pitot probe. */
        out totalPressure : TotalPressureValue;
    }
    
    action def MeasureStaticPressure {
        doc /* Action to acquire static pressure from static probe. */
        out staticPressure : StaticPressureValue;
    }
    
    action def ComputeDynamicPressure {
        doc /* Action to calculate dynamic pressure from total and static. */
        in totalPressure : TotalPressureValue;
        in staticPressure : StaticPressureValue;
        out dynamicPressure : DynamicPressureValue;
    }
    
    action def ComputeVelocity {
        doc /* Action to calculate fluid velocity from dynamic pressure. */
        in dynamicPressure : DynamicPressureValue;
        in fluidDensity : FluidDensityValue;
        out velocity : FluidVelocityValue;
    }
    
    action def TransmitData {
        doc /* Action to transmit computed data to output systems. */
        in totalPressure : TotalPressureValue;
        in staticPressure : StaticPressureValue;
        in dynamicPressure : DynamicPressureValue;
        in velocity : FluidVelocityValue;
    }
    
    action def MonitorTotalPressureSystem {
        doc /* Continuous monitoring cycle for total pressure system. */
        first start;
        then merge continuousMonitoring;
        
        then action measureTotal : MeasureTotalPressure {
            out totalPressureValue : TotalPressureValue;
        }
        
        then action measureStatic : MeasureStaticPressure {
            out staticPressureValue : StaticPressureValue;
        }
        
        then action computeDynamic : ComputeDynamicPressure {
            in totalPressure = measureTotal.totalPressureValue;
            in staticPressure = measureStatic.staticPressureValue;
            out dynamicPressureValue : DynamicPressureValue;
        }
        
        then action computeVel : ComputeVelocity {
            in dynamicPressure = computeDynamic.dynamicPressureValue;
            in fluidDensity : FluidDensityValue;
            out velocityValue : FluidVelocityValue;
        }
        
        then action transmit : TransmitData {
            in totalPressure = measureTotal.totalPressureValue;
            in staticPressure = measureStatic.staticPressureValue;
            in dynamicPressure = computeDynamic.dynamicPressureValue;
            in velocity = computeVel.velocityValue;
        }
        
        then continuousMonitoring;
    }
    
    attribute def SystemReady;
    attribute def StartMeasurement;
    attribute def DataAcquired;
    attribute def ComputationComplete;
    attribute def TransmissionComplete;
    attribute def StopMeasurement;
    attribute def FaultDetected;
    attribute def SystemReset;
    
    state def SystemOperationalStates {
        doc /* State machine governing system operational modes. */
        entry; then initialization;
        
        state initialization {
            doc /* System initialization and self-test. */
        }
        
        transition initialization_to_standby
            first initialization
            accept at SystemReady
            then standby;
        
        state standby {
            doc /* System ready but not actively measuring. */
        }
        
        transition standby_to_active
            first standby
            accept at StartMeasurement
            then active;
        
        state active {
            doc /* System actively measuring and computing. */
            entry; then acquiring;
            
            state acquiring {
                doc /* Acquiring pressure measurements. */
            }
            
            transition acquiring_to_processing
                first acquiring
                accept at DataAcquired
                then processing;
            
            state processing {
                doc /* Processing and computing derived values. */
            }
            
            transition processing_to_transmitting
                first processing
                accept at ComputationComplete
                then transmitting;
            
            state transmitting {
                doc /* Transmitting data to output systems. */
            }
            
            transition transmitting_to_acquiring
                first transmitting
                accept at TransmissionComplete
                then acquiring;
        }
        
        transition active_to_standby
            first active
            accept at StopMeasurement
            then standby;
        
        state fault {
            doc /* System fault state requiring intervention. */
        }
        
        transition active_to_fault
            first active
            accept at FaultDetected
            then fault;
        
        transition fault_to_initialization
            first fault
            accept at SystemReset
            then initialization;
    }
    
    part def TotalPressureSystemDef {
        doc /* Complete total pressure measurement system assembly. */
        
        attribute operatingAltitude : LengthValue;
        attribute operatingTemperatureRange : ThermodynamicTemperatureValue[2];
        attribute measurementFrequency : FrequencyValue = 10 [Hz];
        
        part fluid : FluidMedium {
            attribute :>> density = 1.225 [kg/(m**3)];
            attribute :>> temperature = 288.15 [K];
            attribute :>> viscosity = 1.81e-5;
        }
        
        part pitot : PitotProbe {
            attribute :>> sensorAccuracy = 0.005;
            attribute :>> calibrationFactor = 1.0;
        }
        
        part staticProbe : StaticPressureProbe {
            attribute :>> sensorAccuracy = 0.005;
            attribute :>> calibrationFactor = 1.0;
        }
        
        part totalTransducer : PressureTransducer {
            attribute :>> sensitivity = 0.01;
            attribute :>> range = 150000 [Pa];
        }
        
        part staticTransducer : PressureTransducer {
            attribute :>> sensitivity = 0.01;
            attribute :>> range = 120000 [Pa];
        }
        
        part processor : DataProcessor {
            in :>> fluidDensity = fluid.density;
        }
        
        part display : DisplayUnit {
            attribute :>> updateRate = 5 [Hz];
            attribute :>> displayResolution = 0.1;
        }
        
        part logger : DataLogger {
            attribute :>> samplingRate = 10 [Hz];
            attribute :>> storageCapacity = 1000000;
        }
        
        connection pitotConnection connect
            pitot.totalPressureOut to totalTransducer;
        
        connection staticConnection connect
            staticProbe.staticPressureOut to staticTransducer;
        
        connection processorInputTotal connect
            totalTransducer to processor.dataIn;
        
        connection processorInputStatic connect
            staticTransducer to processor.dataIn;
        
        connection displayConnection connect
            processor.dataOut to display.displayInput;
        
        connection loggerConnection connect
            processor.dataOut to logger.loggerInput;
        
        state operationalState : SystemOperationalStates;
        
        perform action monitoring : MonitorTotalPressureSystem;
    }
    
    part totalPressureSystem : TotalPressureSystemDef;
    
    requirement def TotalPressureMeasurementCapability {
        doc /* The system shall measure total pressure in flowing fluids. */
        subject system : TotalPressureSystemDef;
    }
    
    requirement <'REQ-TP-001'> measureTotalPressure : TotalPressureMeasurementCapability {
        doc /* The system shall continuously measure total pressure with accuracy better than 0.5%. */
        subject system :>> totalPressureSystem;
        
        assert constraint accuracyRequirement {
            system.pitot.sensorAccuracy <= 0.005
        }
    }
    
    requirement <'REQ-TP-002'> computeVelocity {
        doc /* The system shall compute fluid velocity from pressure differential. */
        subject proc :>> totalPressureSystem.processor;
        
        assert constraint velocityComputation {
            proc.computedDynamicPressure == 0.5 * proc.fluidDensity * (proc.computedVelocity ** 2)
        }
    }
    
    requirement <'REQ-TP-003'> measurementFrequency {
        doc /* The system shall update measurements at minimum 10 Hz. */
        subject system :>> totalPressureSystem;
        
        assert constraint updateRate {
            system.measurementFrequency >= 10 [Hz]
        }
    }
    
    requirement <'REQ-TP-004'> operatingRange {
        doc /* The system shall operate across pressure range 0-150 kPa. */
        subject transducer :>> totalPressureSystem.totalTransducer;
        
        assert constraint pressureRange {
            transducer.range >= 150000 [Pa]
        }
    }
    
    requirement <'REQ-TP-005'> dataLogging {
        doc /* The system shall log pressure and velocity data for post-analysis. */
        subject logger :>> totalPressureSystem.logger;
        
        assert constraint loggingRate {
            logger.samplingRate >= 10 [Hz]
        }
    }
    
    satisfy measureTotalPressure by totalPressureSystem;
    satisfy computeVelocity by totalPressureSystem.processor;
    satisfy measurementFrequency by totalPressureSystem;
    satisfy operatingRange by totalPressureSystem.totalTransducer;
    satisfy dataLogging by totalPressureSystem.logger;
}
