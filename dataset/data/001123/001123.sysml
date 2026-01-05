package LiquidCapacitiveInclinometerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def AngleValue :> ISQ::PlaneAngleValue;
    attribute def CapacitanceValue :> ISQ::CapacitanceValue;
    attribute def VoltageValue :> ISQ::ElectricPotentialValue;
    attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
    attribute def FrequencyValue :> ISQ::FrequencyValue;
    attribute def PowerValue :> ISQ::PowerValue;
    
    item def DielectricFluid {
        attribute dielectricConstant : Real;
        attribute density : Real;
        attribute viscosity : Real;
        attribute thermalExpansion : Real;
    }
    
    item def CapacitanceSignal {
        attribute value : CapacitanceValue;
        attribute timestamp : Real;
    }
    
    item def VoltageSignal {
        attribute value : VoltageValue;
        attribute timestamp : Real;
    }
    
    item def AngleData {
        attribute angle : AngleValue;
        attribute quality : Real;
        attribute timestamp : Real;
    }
    
    port def CapacitancePort {
        out signal : CapacitanceSignal;
    }
    
    port def VoltagePort {
        in signal : VoltageSignal;
        out signal : VoltageSignal;
    }
    
    port def DataPort {
        out data : AngleData;
    }
    
    port def PowerPort {
        in power : PowerValue;
    }
    
    part def CapacitivePlate {
        attribute area : Real;
        attribute material : String;
        port electricalConnection : CapacitancePort;
    }
    
    part def SealedChamber {
        attribute volume : Real;
        attribute sealIntegrity : Real;
        attribute housingMaterial : String;
        
        part upperPlate : CapacitivePlate {
            attribute :>> area = 150.0;
            attribute :>> material = "Gold-plated copper";
        }
        
        part lowerPlate : CapacitivePlate {
            attribute :>> area = 150.0;
            attribute :>> material = "Gold-plated copper";
        }
        
        part fluid : DielectricFluid {
            attribute :>> dielectricConstant = 2.2;
            attribute :>> density = 920.0;
            attribute :>> viscosity = 0.8;
            attribute :>> thermalExpansion = 0.0007;
        }
        
        assert constraint fluidVolume {
            volume * 0.6 <= 10.0
        }
    }
    
    part def ExcitationCircuit {
        port powerInput : PowerPort;
        port excitationOutput : VoltagePort;
        
        attribute excitationFrequency : FrequencyValue = 10000.0 [Hz];
        attribute excitationAmplitude : VoltageValue = 5.0 [V];
        attribute powerConsumption : PowerValue = 0.025 [W];
    }
    
    part def CapacitanceBridge {
        port upperInput : CapacitancePort;
        port lowerInput : CapacitancePort;
        port voltageOutput : VoltagePort;
        
        attribute bridgeBalance : Real;
        attribute sensitivity : Real = 0.5;
        
        action def MeasureCapacitanceDifference {
            in upperCap : CapacitanceValue;
            in lowerCap : CapacitanceValue;
            out diffVoltage : VoltageValue;
        }
    }
    
    part def SignalConditioner {
        port analogInput : VoltagePort;
        port conditionedOutput : VoltagePort;
        
        attribute gain : Real = 100.0;
        attribute filterCutoff : FrequencyValue = 50.0 [Hz];
        attribute offsetVoltage : VoltageValue = 0.0 [V];
        
        action def AmplifyAndFilter {
            in rawSignal : VoltageValue;
            out conditionedSignal : VoltageValue;
        }
    }
    
    part def AnalogToDigitalConverter {
        port analogInput : VoltagePort;
        
        attribute resolution : Integer = 16;
        attribute samplingRate : FrequencyValue = 1000.0 [Hz];
        attribute referenceVoltage : VoltageValue = 3.3 [V];
        
        action def ConvertSignal {
            in analogValue : VoltageValue;
            out digitalValue : Integer;
        }
    }
    
    part def TemperatureSensor {
        attribute currentTemperature : TemperatureValue;
        attribute accuracy : TemperatureValue = 0.5 [K];
        
        action def MeasureTemperature {
            out temp : TemperatureValue;
        }
    }
    
    part def ProcessingUnit {
        port dataOutput : DataPort;
        
        attribute calibrationMatrix : Real[9];
        attribute temperatureCoefficients : Real[3];
        attribute updateRate : FrequencyValue = 100.0 [Hz];
        
        action def ComputeInclination {
            in digitalValue : Integer;
            in temperature : TemperatureValue;
            out angle : AngleValue;
            
            first start;
            then action normalizeInput {
                in rawValue = digitalValue;
                out normalizedValue : Real;
            }
            then action applyTemperatureCompensation {
                in value = normalizeInput.normalizedValue;
                in temp = temperature;
                out compensatedValue : Real;
            }
            then action calculateAngle {
                in value = applyTemperatureCompensation.compensatedValue;
                out computedAngle : AngleValue;
            }
            then action validateResult {
                in angle = calculateAngle.computedAngle;
                out validatedAngle : AngleValue;
            }
            then done;
        }
    }
    
    part def CommunicationInterface {
        port angleInput : DataPort;
        
        attribute protocol : String = "RS485";
        attribute baudRate : Integer = 115200;
        attribute updateInterval : Real = 10.0;
        
        action def TransmitData {
            in angleData : AngleData;
        }
    }
    
    state def InclinometerOperatingStates {
        entry; then initialization;
        
        state initialization {
            entry action performSelfTest;
            entry action loadCalibration;
            entry action checkFluidLevel;
        }
        then operational;
        
        state operational {
            entry; then idle;
            
            state idle;
            
            state measuring {
                entry action startMeasurement;
                do action continuousSampling;
                exit action stopMeasurement;
            }
            
            transition idleToMeasuring
                first idle
                accept MeasurementTrigger
                then measuring;
            
            state processing {
                entry action processData;
                do action applyCompensation;
            }
            
            transition measuringToProcessing
                first measuring
                accept DataReady
                then processing;
            
            state transmitting {
                entry action sendData;
            }
            
            transition processingToTransmitting
                first processing
                accept ProcessingComplete
                then transmitting;
            
            transition transmittingToIdle
                first transmitting
                accept TransmissionComplete
                then idle;
        }
        
        state calibration {
            entry action enterCalibrationMode;
            do action collectCalibrationData;
            exit action saveCalibration;
        }
        
        transition operationalToCalibration
            first operational
            accept CalibrationRequest
            then calibration;
        
        transition calibrationToOperational
            first calibration
            accept CalibrationComplete
            then operational;
        
        state fault {
            entry action logFault;
            entry action notifyError;
            do action attemptRecovery;
        }
        
        transition operationalToFault
            first operational
            accept FaultDetected
            then fault;
        
        transition faultToInitialization
            first fault
            accept SystemReset
            then initialization;
    }
    
    part def LiquidCapacitiveInclinometer {
        doc /* 
         * A precision inclinometer that measures tilt angle by detecting 
         * capacitance changes caused by dielectric fluid redistribution 
         * within a sealed chamber under gravitational influence.
         */
        
        attribute measurementRange : AngleValue[2] = (-60.0 [deg], 60.0 [deg]);
        attribute accuracy : AngleValue = 0.05 [deg];
        attribute resolution : AngleValue = 0.01 [deg];
        attribute responseTime : Real = 50.0;
        attribute operatingTemperature : TemperatureValue[2] = (253.15 [K], 358.15 [K]);
        attribute totalPowerConsumption : PowerValue;
        
        port systemOutput : DataPort;
        port powerInput : PowerPort;
        
        part sensingChamber : SealedChamber {
            attribute :>> volume = 20.0;
            attribute :>> sealIntegrity = 0.999;
            attribute :>> housingMaterial = "Anodized aluminum";
        }
        
        part excitation : ExcitationCircuit;
        
        part bridge : CapacitanceBridge {
            attribute :>> bridgeBalance = 0.0;
        }
        
        part conditioner : SignalConditioner;
        
        part adc : AnalogToDigitalConverter;
        
        part tempSensor : TemperatureSensor;
        
        part processor : ProcessingUnit {
            attribute :>> calibrationMatrix = (1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0);
            attribute :>> temperatureCoefficients = (1.0, -0.002, 0.00001);
        }
        
        part commInterface : CommunicationInterface;
        
        connection powerToExcitation
            connect powerInput to excitation.powerInput;
        
        connection upperPlateTobridge
            connect sensingChamber.upperPlate.electricalConnection to bridge.upperInput;
        
        connection lowerPlateToBridge
            connect sensingChamber.lowerPlate.electricalConnection to bridge.lowerInput;
        
        connection bridgeToConditioner
            connect bridge.voltageOutput to conditioner.analogInput;
        
        connection conditionerToADC
            connect conditioner.conditionedOutput to adc.analogInput;
        
        connection processorToComm
            connect processor.dataOutput to commInterface.angleInput;
        
        connection commToSystem
            connect commInterface.angleInput to systemOutput;
        
        assert constraint powerBudget {
            totalPowerConsumption == excitation.powerConsumption + 0.05 [W]
        }
        
        assert constraint powerLimit {
            totalPowerConsumption <= 0.1 [W]
        }
        
        perform action measureTiltAngle {
            doc /* 
             * Primary measurement cycle that continuously monitors 
             * capacitance changes and converts them to tilt angle.
             */
            
            first start;
            then merge continuousCycle;
            
            then action exciteCapacitors {
                doc /* Apply AC excitation to capacitive plates */
                perform by excitation;
            }
            
            then action senseCapacitance {
                doc /* Measure differential capacitance between plates */
                perform by bridge;
            }
            
            then action conditionSignal {
                doc /* Amplify and filter the bridge output signal */
                perform by conditioner;
            }
            
            then action digitizeSignal {
                doc /* Convert conditioned analog signal to digital */
                perform by adc;
            }
            
            then action measureTemperature {
                doc /* Acquire current temperature for compensation */
                perform by tempSensor;
            }
            
            then action computeAngle {
                doc /* Calculate tilt angle with temperature compensation */
                perform by processor;
            }
            
            then action transmitAngle {
                doc /* Send computed angle via communication interface */
                perform by commInterface;
            }
            
            then continuousCycle;
        }
    }
    
    requirement <'REQ-INC-100'> primaryFunction {
        doc /* 
         * The liquid capacitive inclinometer system shall measure the 
         * angle of inclination relative to the gravitational vertical 
         * by detecting capacitance variations caused by the redistribution 
         * of a dielectric fluid within a sealed chamber containing two 
         * parallel capacitive plates.
         */
        subject inclinometer : LiquidCapacitiveInclinometer;
    }
    
    requirement <'REQ-INC-101'> measurementRangeRequirement {
        doc /* 
         * The inclinometer shall measure tilt angles within the range 
         * of ±60 degrees from horizontal.
         */
        subject inclinometer : LiquidCapacitiveInclinometer;
        assert constraint {
            inclinometer.measurementRange[1] >= -60.0 [deg] and
            inclinometer.measurementRange[2] <= 60.0 [deg]
        }
    }
    
    requirement <'REQ-INC-102'> accuracyRequirement {
        doc /* 
         * The inclinometer shall provide angle measurements with 
         * an accuracy of ±0.05 degrees or better.
         */
        subject inclinometer : LiquidCapacitiveInclinometer;
        assert constraint {
            inclinometer.accuracy <= 0.05 [deg]
        }
    }
    
    requirement <'REQ-INC-103'> resolutionRequirement {
        doc /* 
         * The inclinometer shall have a measurement resolution 
         * of 0.01 degrees or finer.
         */
        subject inclinometer : LiquidCapacitiveInclinometer;
        assert constraint {
            inclinometer.resolution <= 0.01 [deg]
        }
    }
    
    requirement <'REQ-INC-104'> responseTimeRequirement {
        doc /* 
         * The inclinometer shall provide updated measurements with 
         * a response time not exceeding 50 milliseconds.
         */
        subject inclinometer : LiquidCapacitiveInclinometer;
        assert constraint {
            inclinometer.responseTime <= 50.0
        }
    }
    
    requirement <'REQ-INC-105'> temperatureCompensation {
        doc /* 
         * The inclinometer shall compensate for temperature effects 
         * on fluid properties and sensor characteristics across the 
         * operating temperature range of -20°C to +85°C.
         */
        subject inclinometer : LiquidCapacitiveInclinometer;
        require tempSensor : inclinometer.tempSensor;
        assert constraint {
            inclinometer.operatingTemperature[1] <= 253.15 [K] and
            inclinometer.operatingTemperature[2] >= 358.15 [K]
        }
    }
    
    requirement <'REQ-INC-106'> powerConsumptionRequirement {
        doc /* 
         * The total power consumption of the inclinometer system 
         * shall not exceed 100 milliwatts during normal operation.
         */
        subject inclinometer : LiquidCapacitiveInclinometer;
        assert constraint {
            inclinometer.totalPowerConsumption <= 0.1 [W]
        }
    }
    
    part inclinometerSystem : LiquidCapacitiveInclinometer {
        attribute :>> measurementRange = (-60.0 [deg], 60.0 [deg]);
        attribute :>> accuracy = 0.05 [deg];
        attribute :>> resolution = 0.01 [deg];
        attribute :>> responseTime = 50.0;
        attribute :>> operatingTemperature = (253.15 [K], 358.15 [K]);
        attribute :>> totalPowerConsumption = 0.075 [W];
    }
    
    satisfy primaryFunction by inclinometerSystem;
    satisfy measurementRangeRequirement by inclinometerSystem;
    satisfy accuracyRequirement by inclinometerSystem;
    satisfy resolutionRequirement by inclinometerSystem;
    satisfy responseTimeRequirement by inclinometerSystem;
    satisfy temperatureCompensation by inclinometerSystem;
    satisfy powerConsumptionRequirement by inclinometerSystem;
}
