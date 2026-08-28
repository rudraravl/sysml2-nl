package DisplacementReceiverModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    // ===== Units =====

    unit mm :> LengthUnit;
    unit um :> LengthUnit;
    unit mV :> ElectricPotentialUnit;
    unit V :> ElectricPotentialUnit;
    unit Hz :> FrequencyUnit;
    unit ms :> TimeUnit;

    // ===== Value Types =====

    value type Displacement :> Real {
        :>> unit = mm;
    }

    value type MicroDisplacement :> Real {
        :>> unit = um;
    }

    value type AnalogVoltage :> Real {
        :>> unit = mV;
    }

    value type VoltageRange :> Real {
        :>> unit = V;
    }

    value type SamplingFrequency :> Real {
        :>> unit = Hz;
    }

    value type TimeDelay :> Real {
        :>> unit = ms;
    }

    // ===== Enumerations =====

    enum def SystemCommand {
        START_MEASURING;
        STOP_MEASURING;
        ENTER_CALIBRATION;
        EXIT_CALIBRATION;
        RESET_FAULT;
    }

    enum def FaultCode {
        NONE;
        SENSOR_FAILURE;
        ADC_OVERFLOW;
        CALIBRATION_ERROR;
        PROCESSING_TIMEOUT;
    }

    // ===== Item Definitions =====

    item def RawAnalogSignal {
        attribute value : AnalogVoltage;
        attribute timestamp : Real;
        attribute noiseAmplitude : AnalogVoltage;
    }

    item def ConditionedSignal {
        attribute value : AnalogVoltage;
        attribute timestamp : Real;
        attribute noiseLevel : AnalogVoltage;
        attribute gainApplied : Real;
    }

    item def DigitalSample {
        attribute rawValue : Integer;
        attribute timestamp : Real;
        attribute resolutionBits : Integer;
        attribute sampleCount : Integer;
    }

    item def PositionData {
        attribute displacement : Displacement;
        attribute timestamp : Real;
        attribute uncertainty : Displacement;
        attribute valid : Boolean;
        attribute sampleCount : Integer;
    }

    item def CalibrationCoefficients {
        attribute offset : Real;
        attribute gain : Real;
        attribute secondOrderCoeff : Real;
        attribute thirdOrderCoeff : Real;
    }

    // ===== Port Definitions =====

    port def RawAnalogOutput {
        out signal : RawAnalogSignal;
    }

    port def RawAnalogInput {
        in signal : RawAnalogSignal;
    }

    port def ConditionedOutput {
        out signal : ConditionedSignal;
    }

    port def ConditionedInput {
        in signal : ConditionedSignal;
    }

    port def DigitalOutput {
        out sample : DigitalSample;
    }

    port def DigitalInput {
        in sample : DigitalSample;
    }

    port def PositionOutput {
        out data : PositionData;
    }

    port def CommandInput {
        in command : SystemCommand;
    }

    // ===== Action Definitions =====

    action def SenseDisplacement {
        in displacement : Displacement;
        in sensitivity : Real;
        out signal : RawAnalogSignal;
    }

    action def ConditionSignal {
        in input : RawAnalogSignal;
        in gain : Real;
        in cutoffFreq : Real;
        out output : ConditionedSignal;
    }

    action def ConvertAnalogToDigital {
        in input : ConditionedSignal;
        in resolutionBits : Integer;
        in sampleRate : Real;
        out output : DigitalSample;
    }

    action def ProcessDigitalSample {
        in sample : DigitalSample;
        in coefficients : CalibrationCoefficients;
        out position : PositionData;
    }

    action def PerformSelfTest {
        out status : Boolean;
        out fault : FaultCode;
    }

    // ===== State Machine Definition =====

    state def OperationalStateMachine {
        entry; then initialization;

        state initialization {
            entry {
                // Power-on sequence: initialize all components and run self-test
            }
            do {
                // Perform component-level diagnostics and calibration load
            }
            transition to ready {
                when self.initComplete == true;
            }
        }

        state ready {
            entry {
                // Enter idle state, await commands from host controller
            }
            transition to activeMeasuring {
                when self.command == SystemCommand::START_MEASURING;
            }
            transition to calibrationMode {
                when self.command == SystemCommand::ENTER_CALIBRATION;
            }
        }

        state activeMeasuring {
            entry {
                // Enable sensor, conditioner, ADC, and processor for continuous measurement
            }
            do {
                // Continuously sense, condition, digitize, and process displacement
            }
            transition to ready {
                when self.command == SystemCommand::STOP_MEASURING;
            }
            transition to faultState {
                when self.errorDetected == true;
            }
        }

        state calibrationMode {
            entry {
                // Prepare calibration fixtures and enter calibration sequence
            }
            do {
                // Acquire reference samples, compute new calibration coefficients
            }
            transition to ready {
                when self.command == SystemCommand::EXIT_CALIBRATION;
            }
            transition to faultState {
                when self.errorDetected == true;
            }
        }

        state faultState {
            entry {
                // Record fault code, halt all processing, assert safe state
            }
            transition to initialization {
                when self.command == SystemCommand::RESET_FAULT;
            }
        }
    }

    // ===== Part Definitions =====

    part def SensorCore {
        doc /* Primary sensing component that physically detects mechanical displacement
             and converts it to a raw, low-level analog electrical signal. */

        attribute sensitivity : Real;
        attribute linearRange : Displacement;
        attribute maxNonlinearity : Real;
        attribute operatingTempMin : Real;
        attribute operatingTempMax : Real;

        port analogOutput : RawAnalogOutput;

        action sense : SenseDisplacement;
    }

    part def SignalConditioner {
        doc /* Signal conditioning stage that filters electrical noise and amplifies
             the raw analog signal from the sensor for robust downstream processing. */

        attribute gain : Real;
        attribute cutoffFrequency : SamplingFrequency;
        attribute inputImpedance : Real;
        attribute noiseFloor : AnalogVoltage;

        port rawInput : RawAnalogInput;
        port conditionedOutput : ConditionedOutput;

        action condition : ConditionSignal;
    }

    part def AnalogToDigitalConverter {
        doc /* Analog-to-Digital Converter that samples the conditioned signal at
             a specific rate and resolution, producing a stream of discrete values. */

        attribute resolutionBits : Integer;
        attribute sampleRate : SamplingFrequency;
        attribute inputRangeMin : VoltageRange;
        attribute inputRangeMax : VoltageRange;
        attribute conversionLatency : TimeDelay;

        port conditionedInput : ConditionedInput;
        port digitalOutput : DigitalOutput;

        action convert : ConvertAnalogToDigital;
    }

    part def DataProcessor {
        doc /* Data processing component that applies calibration coefficients to
             digital samples and computes the precise position output. */

        attribute calibrationCoefficients : CalibrationCoefficients;
        attribute processingLatency : TimeDelay;
        attribute maxBufferDepth : Integer;

        port digitalInput : DigitalInput;
        port positionOutput : PositionOutput;

        action process : ProcessDigitalSample;
    }

    // ===== Top-Level System Part Definition =====

    part def DisplacementReceiver {
        doc /* High-precision displacement receiver system that measures physical movement
             through a multi-stage process and outputs calibrated digital position data. */

        // System-level performance attributes
        attribute measurementRange : Displacement;
        attribute accuracy : MicroDisplacement;
        attribute repeatability : MicroDisplacement;
        attribute samplingRate : SamplingFrequency;
        attribute resolutionBits : Integer;
        attribute powerOnTime : TimeDelay;

        // State machine control attributes
        attribute command : SystemCommand;
        attribute initComplete : Boolean;
        attribute errorDetected : Boolean;
        attribute currentFault : FaultCode;

        // External interface ports
        port commandPort : CommandInput;
        port dataOutput : PositionOutput;

        // Subcomponents with configured attribute values
        part sensorCore : SensorCore {
            attribute :>> sensitivity = 10.0;
            attribute :>> linearRange = 50.0;
            attribute :>> maxNonlinearity = 0.1;
            attribute :>> operatingTempMin = -40.0;
            attribute :>> operatingTempMax = 85.0;
        }

        part signalConditioner : SignalConditioner {
            attribute :>> gain = 100.0;
            attribute :>> cutoffFrequency = 10000.0;
            attribute :>> inputImpedance = 10000.0;
            attribute :>> noiseFloor = 0.05;
        }

        part adc : AnalogToDigitalConverter {
            attribute :>> resolutionBits = 16;
            attribute :>> sampleRate = 1000.0;
            attribute :>> inputRangeMin = -5.0;
            attribute :>> inputRangeMax = 5.0;
            attribute :>> conversionLatency = 0.5;
        }

        part dataProcessor : DataProcessor {
            attribute :>> calibrationCoefficients : CalibrationCoefficients;
            attribute :>> processingLatency = 1.0;
            attribute :>> maxBufferDepth = 256;
        }

        // Internal connections between subcomponents
        connection connect sensorCore.analogOutput to signalConditioner.rawInput;
        connection connect signalConditioner.conditionedOutput to adc.conditionedInput;
        connection connect adc.digitalOutput to dataProcessor.digitalInput;

        // Connect internal output to external port
        connection connect dataProcessor.positionOutput to dataOutput;

        // State machine
        state machine : OperationalStateMachine;
    }

    // ===== System Instance =====

    part displacementReceiver : DisplacementReceiver {
        attribute :>> measurementRange = 50.0;
        attribute :>> accuracy = 5.0;
        attribute :>> repeatability = 2.0;
        attribute :>> samplingRate = 1000.0;
        attribute :>> resolutionBits = 16;
        attribute :>> powerOnTime = 50.0;
        attribute :>> command = SystemCommand::START_MEASURING;
        attribute :>> initComplete = false;
        attribute :>> errorDetected = false;
        attribute :>> currentFault = FaultCode::NONE;
    }

    // ===== Requirements =====

    requirement def MeasurementRangeRequirement {
        doc /* The system shall measure displacement over the full specified range
             without degradation of accuracy or linearity. */
        subject system : DisplacementReceiver;
        attribute requiredRange : Displacement = 50.0;
        constraint { system.measurementRange >= requiredRange }
    }

    requirement def AccuracyRequirement {
        doc /* The system shall achieve measurement accuracy better than the
             specified maximum error across the entire measurement range. */
        subject system : DisplacementReceiver;
        attribute requiredAccuracy : MicroDisplacement = 5.0;
        constraint { system.accuracy <= requiredAccuracy }
    }

    requirement def RepeatabilityRequirement {
        doc /* The system shall achieve measurement repeatability better than
             the specified maximum variation under identical conditions. */
        subject system : DisplacementReceiver;
        attribute requiredRepeatability : MicroDisplacement = 2.0;
        constraint { system.repeatability <= requiredRepeatability }
    }

    requirement def SamplingRateRequirement {
        doc /* The system shall provide digital output at a minimum sampling rate
             sufficient for real-time industrial and robotic applications. */
        subject system : DisplacementReceiver;
        attribute requiredRate : SamplingFrequency = 1000.0;
        constraint { system.samplingRate >= requiredRate }
    }

    requirement def ResolutionRequirement {
        doc /* The ADC shall provide at least 16-bit resolution to ensure
             adequate dynamic range for high-precision displacement measurement. */
        subject system : DisplacementReceiver;
        attribute requiredBits : Integer = 16;
        constraint { system.resolutionBits >= requiredBits }
    }

    requirement def StartupTimeRequirement {
        doc /* The system shall complete initialization within the specified time
             from power-on to ensure rapid availability in industrial applications. */
        subject system : DisplacementReceiver;
        attribute maxStartupTime : TimeDelay = 100.0;
        constraint { system.powerOnTime <= maxStartupTime }
    }

    // ===== Satisfaction =====

    satisfy MeasurementRangeRequirement by displacementReceiver;
    satisfy AccuracyRequirement by displacementReceiver;
    satisfy RepeatabilityRequirement by displacementReceiver;
    satisfy SamplingRateRequirement by displacementReceiver;
    satisfy ResolutionRequirement by displacementReceiver;
    satisfy StartupTimeRequirement by displacementReceiver;
}
