package EIS_pH_Sensing_Unit {
    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    // ===== Value Types =====
    value type Capacitance :> ISQ::Capacitance;
    value type Voltage :> ISQ::ElectricPotential;
    value type Temperature :> ISQ::ThermodynamicTemperature {
        unit degC = 1 [kelvin] (offset 273.15);
    }
    value type Duration :> ISQ::Time;
    value type pHValue :> Real;
    value type FilmThickness :> ISQ::Length;
    value type DeviceArea :> ISQ::Area;
    value type ElectricCurrent :> ISQ::ElectricCurrent;
    value type SignalFrequency :> ISQ::Frequency;

    // ===== Signal Definitions =====
    signal def PowerOn;
    signal def PowerOff;
    signal def SampleDetected;
    signal def MeasurementComplete;
    signal def ResultReady;
    signal def SensorFault;
    signal def ProcessingFault;
    signal def ResetSignal;

    // ===== Item Definitions =====
    item def LiquidSample {
        attribute expectedPH : pHValue;
        attribute sampleTemperature : Temperature;
        attribute ionicStrength : Real;
    }

    item def AnalogSignal {
        attribute capacitance : Capacitance;
        attribute noiseLevel : Capacitance;
        attribute signalIntegrity : Real;
    }

    item def DigitalData {
        attribute rawCapacitance : Capacitance;
        attribute timestamp : Duration;
        attribute resolutionBits : Integer;
        attribute sampleId : Integer;
    }

    item def TemperatureData {
        attribute value : Temperature;
        attribute timestamp : Duration;
        attribute sensorId : String;
    }

    item def pHResult {
        attribute pH : pHValue;
        attribute temperature : Temperature;
        attribute measurementTime : Duration;
        attribute confidenceLevel : Real;
        attribute isValid : Boolean;
        attribute sensorId : String;
    }

    item def PowerParameters {
        attribute voltage : Voltage;
        attribute maxCurrent : ElectricCurrent;
        attribute isRegulated : Boolean;
    }

    // ===== Port Definitions =====
    port def LiquidSamplePort {
        attribute sample : LiquidSample;
    }

    port def AnalogSignalPort {
        attribute signal : AnalogSignal;
    }

    port def DigitalDataPort {
        attribute data : DigitalData;
    }

    port def TemperatureDataPort {
        attribute data : TemperatureData;
    }

    port def ResultPort {
        attribute result : pHResult;
    }

    port def PowerPort {
        attribute parameters : PowerParameters;
    }

    // ===== EIS Sensor Components =====
    part def PTypeSiliconSubstrate {
        attribute dopingConcentration : Real = 1e15;
        attribute thickness : FilmThickness = 500e-9 [meter];
        attribute resistivity : Real = 10;
        attribute crystalOrientation : String = "(100)";
    }

    part def SiO2InsulatingLayer {
        attribute thickness : FilmThickness = 30e-9 [meter];
        attribute dielectricConstant : Real = 3.9;
        attribute area : DeviceArea = 1e-4 [meter * meter];
        attribute defectDensity : Real = 1e10;
    }

    part def AgAgClReferenceElectrode {
        attribute standardPotential : Voltage = 222e-3 [volt];
        attribute chlorideConcentration : Real = 1.0;
        attribute electrodeDiameter : FilmThickness = 1e-3 [meter];
    }

    part def EISSensorElement {
        part substrate : PTypeSiliconSubstrate;
        part insulator : SiO2InsulatingLayer;
        part referenceElectrode : AgAgClReferenceElectrode;

        port sampleInterface : LiquidSamplePort;
        port capacitanceOutput : AnalogSignalPort;
        port powerInput : PowerPort;

        attribute surfacePotential : Voltage;
        attribute measuredCapacitance : Capacitance;
        attribute operatingTemperature : Temperature;
        attribute isCalibrated : Boolean = false;
        attribute calibrationOffset : Capacitance = 0 [farad];
        attribute baseCapacitance : Capacitance = 100e-9 [farad];

        action detectCapacitance {
            in sample : LiquidSample;
            in temperature : Temperature;
            out signal : AnalogSignal;
        }

        action calibrateSensor {
            in referenceCapacitance : Capacitance;
            out offset : Capacitance;
        }

        action measureSurfacePotential {
            in sample : LiquidSample;
            out potential : Voltage;
        }
    }

    // ===== Temperature Sensor =====
    part def TemperatureSensor {
        port output : TemperatureDataPort;
        port powerInput : PowerPort;

        attribute accuracy : Temperature = 0.1 [degC];
        attribute operatingRangeMin : Temperature = -20 [degC];
        attribute operatingRangeMax : Temperature = 100 [degC];
        attribute responseTime : Duration = 500e-3 [second];
        attribute isStable : Boolean = false;
        attribute currentReading : Temperature;

        action measureTemperature {
            in environmentTemp : Temperature;
            out tempData : TemperatureData;
        }

        action stabilize {
            out stable : Boolean;
        }
    }

    // ===== Signal Conditioner =====
    part def SignalConditioner {
        port rawInput : AnalogSignalPort;
        port digitalOutput : DigitalDataPort;
        port powerInput : PowerPort;

        attribute gain : Real = 100;
        attribute filterCutoff : SignalFrequency = 1000 [hertz];
        attribute samplingRate : SignalFrequency = 10000 [hertz];
        attribute resolutionBits : Integer = 16;
        attribute inputImpedance : Real = 1e6;
        attribute isOperational : Boolean = false;

        action amplify {
            in signal : AnalogSignal;
            out amplified : AnalogSignal;
        }

        action filter {
            in signal : AnalogSignal;
            out filtered : AnalogSignal;
        }

        action digitize {
            in signal : AnalogSignal;
            out digital : DigitalData;
        }

        action conditionSignal {
            in raw : AnalogSignal;
            out processed : DigitalData;
        }
    }

    // ===== Power Supply =====
    part def PowerSupply {
        port powerOutput : PowerPort;

        attribute outputVoltage : Voltage = 5 [volt];
        attribute maxCurrent : ElectricCurrent = 100e-3 [ampere];
        attribute efficiency : Real = 0.85;
        attribute enabled : Boolean = false;
        attribute rippleNoise : Voltage = 5e-3 [volt];
        attribute thermalShutdown : Boolean = false;

        action regulateVoltage {
            in targetVoltage : Voltage;
            out regulatedVoltage : Voltage;
        }

        action enablePower {
            out params : PowerParameters;
        }

        action disablePower {
            out status : Boolean;
        }
    }

    // ===== Processing Unit =====
    part def ProcessingUnit {
        port dataInput : DigitalDataPort;
        port temperatureInput : TemperatureDataPort;
        port resultOutput : ResultPort;
        port powerInput : PowerPort;

        attribute calibrationSlope : Real = -57.7;
        attribute calibrationOffset : Real = 2045.5;
        attribute temperatureCompensationFactor : Real = 0.003;
        attribute measurementBuffer : DigitalData;
        attribute temperatureBuffer : TemperatureData;
        attribute processingBuffer : pHResult;
        attribute isProcessing : Boolean = false;

        action calculatepH {
            in rawCapacitance : Capacitance;
            in temperature : Temperature;
            out result : pHResult;
        }

        action timestampMeasurement {
            out time : Duration;
        }

        action validateMeasurement {
            in result : pHResult;
            out valid : Boolean;
        }

        action outputResult {
            in result : pHResult;
            out finalResult : pHResult;
        }

        action applyTemperatureCompensation {
            in rawPH : pHValue;
            in temperature : Temperature;
            out compensatedPH : pHValue;
        }
    }

    // ===== Top-Level Assembly =====
    part def EIS_pH_SensingUnit {
        part powerSupply : PowerSupply;
        part eisSensor : EISSensorElement;
        part temperatureSensor : TemperatureSensor;
        part signalConditioner : SignalConditioner;
        part processingUnit : ProcessingUnit;

        port samplePort : LiquidSamplePort;
        port outputPort : ResultPort;

        // Power distribution connections
        connection powerToSensor connect powerSupply.powerOutput to eisSensor.powerInput;
        connection powerToTempSensor connect powerSupply.powerOutput to temperatureSensor.powerInput;
        connection powerToConditioner connect powerSupply.powerOutput to signalConditioner.powerInput;
        connection powerToProcessor connect powerSupply.powerOutput to processingUnit.powerInput;

        // Signal flow connections
        connection sampleToSensor connect samplePort to eisSensor.sampleInterface;
        connection sensorToConditioner connect eisSensor.capacitanceOutput to signalConditioner.rawInput;
        connection conditionerToProcessor connect signalConditioner.digitalOutput to processingUnit.dataInput;
        connection tempToProcessor connect temperatureSensor.output to processingUnit.temperatureInput;
        connection processorToOutput connect processingUnit.resultOutput to outputPort;

        // Operational parameters
        attribute warmUpDuration : Duration = 30 [second];
        attribute measurementTimeout : Duration = 10 [second];
        attribute processingTimeout : Duration = 5 [second];
        attribute systemEnabled : Boolean = false;
        attribute currentErrorCode : Integer = 0;
        attribute totalMeasurements : Integer = 0;

        // Behaviors
        action initializeSystem {
            powerSupply.enabled = true;
            signalConditioner.isOperational = true;
            systemEnabled = true;
        }

        action performWarmUpSequence {
            perform eisSensor.calibrateSensor;
            perform temperatureSensor.stabilize;
            temperatureSensor.isStable = true;
            eisSensor.isCalibrated = true;
        }

        action awaitSample {
            perform eisSensor.measureSurfacePotential;
        }

        action captureRawData {
            perform eisSensor.detectCapacitance;
            perform temperatureSensor.measureTemperature;
            perform signalConditioner.conditionSignal;
        }

        action processMeasurement {
            perform processingUnit.calculatepH;
            perform processingUnit.applyTemperatureCompensation;
            perform processingUnit.timestampMeasurement;
            perform processingUnit.validateMeasurement;
            perform processingUnit.outputResult;
            totalMeasurements = totalMeasurements + 1;
        }

        action logError {
            currentErrorCode = 1;
            systemEnabled = false;
        }

        action performReset {
            currentErrorCode = 0;
            powerSupply.enabled = true;
            systemEnabled = true;
        }

        // State machine
        state machine OperationState {
            initial state Off;

            state WarmUp {
                entry { perform initializeSystem; }
                do { perform performWarmUpSequence; }
            }

            state Ready {
                entry {
                    eisSensor.measuredCapacitance = 0 [farad];
                    eisSensor.surfacePotential = 0 [volt];
                }
                do { perform awaitSample; }
            }

            state Measuring {
                entry { perform captureRawData; }
            }

            state Processing {
                entry { perform processMeasurement; }
            }

            state Error {
                entry { perform logError; }
            }

            // Transitions
            transition from Off to WarmUp on PowerOn;
            transition from WarmUp to Ready after warmUpDuration;
            transition from WarmUp to Error on SensorFault;

            transition from Ready to Measuring on SampleDetected;
            transition from Ready to Error on SensorFault;

            transition from Measuring to Processing on MeasurementComplete;
            transition from Measuring to Error on SensorFault;

            transition from Processing to Ready on ResultReady;
            transition from Processing to Error on ProcessingFault;

            transition from Error to Ready on ResetSignal {
                entry { perform performReset; }
            }
            transition from Error to Off on PowerOff;
        }

        // Requirements satisfaction
        satisfy AccuratepHSensing;
        satisfy TemperatureCompensation;
        satisfy FastResponse;
        satisfy WarmUpStability;
        satisfy ErrorHandlingCapability;
        satisfy ContinuousOperationCapability;
        satisfy EISConstructionRequirement;
        satisfy SignalConditioningRequirement;
        satisfy PowerProvisionRequirement;
    }

    // ===== Requirements =====
    requirement def AccuratepHSensing {
        doc /** The system shall measure pH with an accuracy of 0.1 pH units or better over the range 0 to 14. */;
    }

    requirement def TemperatureCompensation {
        doc /** The system shall compensate pH measurements for temperature variations between 0 and 80 degrees Celsius using an integrated temperature sensor. */;
    }

    requirement def FastResponse {
        doc /** The system shall complete a single measurement cycle within 10 seconds of sample introduction. */;
    }

    requirement def WarmUpStability {
        doc /** The system shall achieve sensor stability within 30 seconds of power-on before entering the ready state. */;
    }

    requirement def ErrorHandlingCapability {
        doc /** The system shall detect sensor faults and enter a safe error state, requiring manual reset to resume operation. */;
    }

    requirement def ContinuousOperationCapability {
        doc /** The system shall support continuous measurement cycles, returning to ready state after each result is output. */;
    }

    requirement def EISConstructionRequirement {
        doc /** The EIS sensor shall use a p-type silicon substrate, SiO2 insulator, and Ag/AgCl reference electrode for capacitance-based pH detection. */;
    }

    requirement def SignalConditioningRequirement {
        doc /** The signal conditioner shall amplify, filter, and digitize the raw EIS sensor signal to produce digital data for processing. */;
    }

    requirement def PowerProvisionRequirement {
        doc /** An internal power supply shall provide regulated voltage to all system components including the EIS sensor, temperature sensor, signal conditioner, and processing unit. */;
    }
}
