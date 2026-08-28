package MEMS_Accelerometer_Model {
    import ScalarValues::*;
    import SI::*;

    // ============================================================
    // Value Types with Units
    // ============================================================

    value type AccelerationValue :> Real {
        unit m/(s^2);
    }

    value type VoltageValue :> Real {
        unit V;
    }

    value type CapacitanceValue :> Real {
        unit F;
    }

    value type DisplacementValue :> Real {
        unit m;
    }

    value type FrequencyValue :> Real {
        unit Hz;
    }

    value type CurrentValue :> Real {
        unit A;
    }

    value type MassValue :> Real {
        unit kg;
    }

    value type SpringConstant :> Real {
        unit N/m;
    }

    value type TimestampValue :> Integer {
        unit ms;
    }

    value type TemperatureValue :> Real {
        unit K;
    }

    value type DigitalCount :> Integer;

    // ============================================================
    // Item Definitions
    // ============================================================

    item def AccelerationInput {
        attribute magnitude : AccelerationValue;
        attribute axisId : String;
    }

    item def MechanicalDisplacement {
        attribute delta : DisplacementValue;
        attribute axisId : String;
    }

    item def CapacitanceDelta {
        attribute deltaC : CapacitanceValue;
        attribute axisId : String;
    }

    item def RawAnalogVoltage {
        attribute level : VoltageValue;
        attribute axisId : String;
    }

    item def FilteredVoltage {
        attribute level : VoltageValue;
        attribute axisId : String;
    }

    item def DigitalSample {
        attribute count : DigitalCount;
        attribute axisId : String;
        attribute sampleTimestamp : TimestampValue;
    }

    item def CalibratedAccelerationData {
        attribute accelX : AccelerationValue;
        attribute accelY : AccelerationValue;
        attribute accelZ : AccelerationValue;
        attribute timestamp : TimestampValue;
        attribute sequenceNumber : Integer;
    }

    item def RawPowerInput {
        attribute voltage : VoltageValue;
        attribute maxCurrent : CurrentValue;
    }

    item def RegulatedSupply {
        attribute voltage : VoltageValue;
        attribute ripple : VoltageValue;
    }

    item def DigitalCommand {
        attribute commandCode : DigitalCount;
        attribute payload : String;
    }

    item def SelfTestResult {
        attribute passed : Boolean;
        attribute errorCode : DigitalCount;
    }

    // ============================================================
    // Port Definitions
    // ============================================================

    port def MechanicalInputPort {
        out item : AccelerationInput;
    }

    port def DisplacementOutputPort {
        out item : MechanicalDisplacement;
    }

    port def CapacitanceOutputPort {
        out item : CapacitanceDelta;
    }

    port def AnalogVoltageOutputPort {
        out item : RawAnalogVoltage;
    }

    port def FilteredVoltageOutputPort {
        out item : FilteredVoltage;
    }

    port def DigitalSampleOutputPort {
        out item : DigitalSample;
    }

    port def CalibratedDataOutputPort {
        out item : CalibratedAccelerationData;
    }

    port def RawPowerInputPort {
        in item : RawPowerInput;
    }

    port def RegulatedPowerOutputPort {
        out item : RegulatedSupply;
    }

    port def RegulatedPowerInputPort {
        in item : RegulatedSupply;
    }

    port def CommandInputPort {
        in item : DigitalCommand;
    }

    port def DataInterfaceOutputPort {
        out item : CalibratedAccelerationData;
    }

    // ============================================================
    // Part Definitions — Physical Sensing Elements
    // ============================================================

    part def ProofMass {
        attribute massValue : MassValue = 1.0e-9;
        attribute maxTravel : DisplacementValue = 2.0e-6;

        port displacementOut : DisplacementOutputPort;

        action def RespondToAcceleration {
            in acceleration : AccelerationInput;
            out displacement : MechanicalDisplacement;
        }
    }

    part def SuspensionSystem {
        attribute springK : SpringConstant = 0.5;
        attribute dampingCoeff : Real = 1.0e-6;
    }

    part def FixedElectrode {
        attribute baseCapacitance : CapacitanceValue = 1.0e-12;
        attribute gap : DisplacementValue = 2.0e-6;
    }

    part def SensingElement {
        attribute axisLabel : String;
        attribute sensitivity : Real = 0.1;
        attribute noiseFloor : AccelerationValue = 1.0e-4;

        part proofMass : ProofMass;
        part suspension : SuspensionSystem;
        part fixedElectrode : FixedElectrode;

        port mechanicalIn : MechanicalInputPort;
        port capacitanceOut : CapacitanceOutputPort;

        action def SenseAcceleration {
            in accel : AccelerationInput;
            out capDelta : CapacitanceDelta;

            action computeDisplacement {
                in acceleration : AccelerationInput;
                out displacement : MechanicalDisplacement;
            }

            action computeCapacitance {
                in displacement : MechanicalDisplacement;
                out capDelta : CapacitanceDelta;
            }

            flow from computeDisplacement.displacement to computeCapacitance.displacement;
        }

        connection internalMech connect mechanicalIn.item to proofMass.displacementOut.item;
    }

    // ============================================================
    // Part Definitions — Signal Processing Chain
    // ============================================================

    part def ChargeAmplifier {
        attribute gain : Real = 1.0e12;
        attribute bandwidth : FrequencyValue = 10000.0;
        attribute offsetVoltage : VoltageValue = 0.001;

        port capIn : CapacitanceOutputPort;
        port voltageOut : AnalogVoltageOutputPort;
        port powerIn : RegulatedPowerInputPort;

        action def ConvertCapacitanceToVoltage {
            in capDelta : CapacitanceDelta;
            out voltage : RawAnalogVoltage;
        }
    }

    part def LowPassFilter {
        attribute cutoffFreq : FrequencyValue = 500.0;
        attribute filterOrder : Integer = 4;
        attribute stopbandAttenuation : Real = 40.0;

        port voltageIn : AnalogVoltageOutputPort;
        port voltageOut : FilteredVoltageOutputPort;
        port powerIn : RegulatedPowerInputPort;

        action def FilterHighFrequencyNoise {
            in rawVoltage : RawAnalogVoltage;
            out filteredVoltage : FilteredVoltage;
        }
    }

    part def AnalogToDigitalConverter {
        attribute resolutionBits : Integer = 16;
        attribute samplingRate : FrequencyValue = 1000.0;
        attribute referenceVoltage : VoltageValue = 3.3;
        attribute inputRange : VoltageValue = 3.3;

        port voltageIn : FilteredVoltageOutputPort;
        port sampleOut : DigitalSampleOutputPort;
        port powerIn : RegulatedPowerInputPort;

        action def SampleAndConvert {
            in voltage : FilteredVoltage;
            out sample : DigitalSample;
        }
    }

    part def DigitalSignalProcessor {
        attribute clockRate : FrequencyValue = 1000000.0;
        attribute calibrationOffsetX : AccelerationValue = 0.0;
        attribute calibrationOffsetY : AccelerationValue = 0.0;
        attribute calibrationOffsetZ : AccelerationValue = 0.0;
        attribute scaleFactorX : Real = 1.0;
        attribute scaleFactorY : Real = 1.0;
        attribute scaleFactorZ : Real = 1.0;
        attribute sequenceCounter : Integer = 0;

        port sampleInX : DigitalSampleOutputPort;
        port sampleInY : DigitalSampleOutputPort;
        port sampleInZ : DigitalSampleOutputPort;
        port dataOut : CalibratedDataOutputPort;
        port powerIn : RegulatedPowerInputPort;
        port commandIn : CommandInputPort;

        action def ApplyCalibration {
            in rawX : DigitalSample;
            in rawY : DigitalSample;
            in rawZ : DigitalSample;
            out calibratedX : AccelerationValue;
            out calibratedY : AccelerationValue;
            out calibratedZ : AccelerationValue;

            action scaleAndOffsetX {
                in sample : DigitalSample;
                out accel : AccelerationValue;
            }

            action scaleAndOffsetY {
                in sample : DigitalSample;
                out accel : AccelerationValue;
            }

            action scaleAndOffsetZ {
                in sample : DigitalSample;
                out accel : AccelerationValue;
            }
        }

        action def PackageData {
            in accelX : AccelerationValue;
            in accelY : AccelerationValue;
            in accelZ : AccelerationValue;
            out data : CalibratedAccelerationData;
        }
    }

    // ============================================================
    // Part Definition — Power System
    // ============================================================

    part def VoltageRegulator {
        attribute outputVoltage : VoltageValue = 3.3;
        attribute maxOutputCurrent : CurrentValue = 0.05;
        attribute lineRegulation : Real = 0.01;
        attribute loadRegulation : Real = 0.005;
        attribute dropoutVoltage : VoltageValue = 0.2;
        attribute thermalShutdownTemp : TemperatureValue = 423.15;

        port powerIn : RawPowerInputPort;
        port powerOut : RegulatedPowerOutputPort;

        action def Regulate {
            in rawPower : RawPowerInput;
            out regulated : RegulatedSupply;
        }
    }

    // ============================================================
    // State Machine — Operational Lifecycle
    // ============================================================

    state def AccelerometerLifecycle {

        entry; then Off;

        state Off {
            attribute description : String = "Device unpowered";
        }

        transition PowerOn
            first Off
            accept PowerApplied
            then Initializing;

        state Initializing {
            entry; then RunSelfTest;

            attribute description : String = "Performing initialization and self-test";

            state RunSelfTest;

            action def ExecuteSelfTest {
                out result : SelfTestResult;
            }

            transition SelfTestPassed
                first RunSelfTest
                accept SelfTestComplete
                if result.passed == true
                then Idle;

            transition SelfTestFailed
                first RunSelfTest
                accept SelfTestComplete
                if result.passed == false
                then Error;
        }

        transition InitTimeout
            first Initializing
            accept Timeout
            then Error;

        state Idle {
            attribute description : String = "Awaiting measurement command";
        }

        transition StartMeasurement
            first Idle
            accept StartCommand
            then Measuring;

        transition EnterLowPowerFromIdle
            first Idle
            accept LowPowerCommand
            then LowPower;

        state Measuring {
            entry; then Sensing;

            attribute description : String = "Continuous measurement loop";

            state Sensing {
                attribute description : String = "Proof mass displacement and capacitance sensing";
            }

            transition SenseToProcess
                first Sensing
                accept SensingComplete
                then Processing;

            state Processing {
                attribute description : String = "Signal amplification, filtering, ADC, and DSP calibration";
            }

            transition ProcessToTransmit
                first Processing
                accept ProcessingComplete
                then Transmitting;

            state Transmitting {
                attribute description : String = "Packaging and outputting calibrated data";
            }

            transition TransmitToSense
                first Transmitting
                accept TransmitComplete
                then Sensing;
        }

        transition StopMeasurement
            first Measuring
            accept StopCommand
            then Idle;

        transition EnterLowPowerFromMeasuring
            first Measuring
            accept LowPowerCommand
            then LowPower;

        transition FaultDuringMeasurement
            first Measuring
            accept FaultDetected
            then Error;

        state LowPower {
            attribute description : String = "Reduced power consumption, sensing elements disabled";
        }

        transition WakeFromLowPower
            first LowPower
            accept WakeUpCommand
            then Idle;

        transition FaultDuringLowPower
            first LowPower
            accept FaultDetected
            then Error;

        state Error {
            attribute description : String = "Fault condition, requires reset";
        }

        transition ResetFromError
            first Error
            accept ResetCommand
            then Resetting;

        transition PowerOffFromError
            first Error
            accept PowerRemoved
            then Off;

        state Resetting {
            entry; then Off;

            attribute description : String = "Performing system reset";
        }
    }

    // ============================================================
    // Top-Level Part — Three-Axis MEMS Accelerometer
    // ============================================================

    part def ThreeAxisMEMSAccelerometer {

        attribute deviceName : String = "MEMS-3AX-001";
        attribute measurementRange : AccelerationValue = 157.0;
        attribute noiseDensity : Real = 1.5e-4;
        attribute operatingTempMin : TemperatureValue = 243.15;
        attribute operatingTempMax : TemperatureValue = 358.15;
        attribute supplyVoltage : VoltageValue = 3.3;

        port rawPowerPort : RawPowerInputPort;
        port commandPort : CommandInputPort;
        port dataInterfacePort : DataInterfaceOutputPort;

        // --- Power Subsystem ---
        part voltageRegulator : VoltageRegulator;

        // --- X-Axis Signal Chain ---
        part sensingElementX : SensingElement {
            attribute axisLabel = "X";
        }
        part chargeAmplifierX : ChargeAmplifier;
        part lowPassFilterX : LowPassFilter;
        part adcX : AnalogToDigitalConverter;

        // --- Y-Axis Signal Chain ---
        part sensingElementY : SensingElement {
            attribute axisLabel = "Y";
        }
        part chargeAmplifierY : ChargeAmplifier;
        part lowPassFilterY : LowPassFilter;
        part adcY : AnalogToDigitalConverter;

        // --- Z-Axis Signal Chain ---
        part sensingElementZ : SensingElement {
            attribute axisLabel = "Z";
        }
        part chargeAmplifierZ : ChargeAmplifier;
        part lowPassFilterZ : LowPassFilter;
        part adcZ : AnalogToDigitalConverter;

        // --- Digital Processing ---
        part dsp : DigitalSignalProcessor;

        // ========================================================
        // Connections — Power Distribution
        // ========================================================

        connection rawPowerFeed connect rawPowerPort.item to voltageRegulator.powerIn.item;

        connection powerToAmpX connect voltageRegulator.powerOut.item to chargeAmplifierX.powerIn.item;
        connection powerToAmpY connect voltageRegulator.powerOut.item to chargeAmplifierY.powerIn.item;
        connection powerToAmpZ connect voltageRegulator.powerOut.item to chargeAmplifierZ.powerIn.item;

        connection powerToFilterX connect voltageRegulator.powerOut.item to lowPassFilterX.powerIn.item;
        connection powerToFilterY connect voltageRegulator.powerOut.item to lowPassFilterY.powerIn.item;
        connection powerToFilterZ connect voltageRegulator.powerOut.item to lowPassFilterZ.powerIn.item;

        connection powerToAdcX connect voltageRegulator.powerOut.item to adcX.powerIn.item;
        connection powerToAdcY connect voltageRegulator.powerOut.item to adcY.powerIn.item;
        connection powerToAdcZ connect voltageRegulator.powerOut.item to adcZ.powerIn.item;

        connection powerToDsp connect voltageRegulator.powerOut.item to dsp.powerIn.item;

        // ========================================================
        // Connections — X-Axis Signal Chain
        // ========================================================

        connection xCapToAmp connect sensingElementX.capacitanceOut.item to chargeAmplifierX.capIn.item;
        connection xAmpToFilter connect chargeAmplifierX.voltageOut.item to lowPassFilterX.voltageIn.item;
        connection xFilterToAdc connect lowPassFilterX.voltageOut.item to adcX.voltageIn.item;
        connection xAdcToDsp connect adcX.sampleOut.item to dsp.sampleInX.item;

        // ========================================================
        // Connections — Y-Axis Signal Chain
        // ========================================================

        connection yCapToAmp connect sensingElementY.capacitanceOut.item to chargeAmplifierY.capIn.item;
        connection yAmpToFilter connect chargeAmplifierY.voltageOut.item to lowPassFilterY.voltageIn.item;
        connection yFilterToAdc connect lowPassFilterY.voltageOut.item to adcY.voltageIn.item;
        connection yAdcToDsp connect adcY.sampleOut.item to dsp.sampleInY.item;

        // ========================================================
        // Connections — Z-Axis Signal Chain
        // ========================================================

        connection zCapToAmp connect sensingElementZ.capacitanceOut.item to chargeAmplifierZ.capIn.item;
        connection zAmpToFilter connect chargeAmplifierZ.voltageOut.item to lowPassFilterZ.voltageIn.item;
        connection zFilterToAdc connect lowPassFilterZ.voltageOut.item to adcZ.voltageIn.item;
        connection zAdcToDsp connect adcZ.sampleOut.item to dsp.sampleInZ.item;

        // ========================================================
        // Connections — Data Output and Command
        // ========================================================

        connection dspToInterface connect dsp.dataOut.item to dataInterfacePort.item;
        connection commandToDsp connect commandPort.item to dsp.commandIn.item;

        // ========================================================
        // Behavioral State Machine
        // ========================================================

        exhibit AccelerometerLifecycle;
    }

    // ============================================================
    // Requirements
    // ============================================================

    requirement def ThreeAxisMeasurementRequirement {
        doc /* The accelerometer shall measure linear acceleration along three orthogonal axes (X, Y, Z) simultaneously. */
        subject : accelerometer :> ThreeAxisMEMSAccelerometer;
        objective : AccelerationValue {
            :>> magnitude <= 157.0;
        }
    }

    requirement def SensingElementRequirement {
        doc /* Each sensing element shall contain a proof mass suspended by a spring-like suspension and a fixed electrode forming a variable capacitor whose capacitance changes proportionally with applied acceleration. */
        subject : sensingElement :> SensingElement;
        objective : CapacitanceValue {
            :>> deltaC >= 0.0;
        }
    }

    requirement def SignalChainRequirement {
        doc /* The signal processing chain shall convert capacitance changes into calibrated digital acceleration data through a charge amplifier, low-pass filter, analog-to-digital converter, and digital signal processor. */
        subject : accelerometer :> ThreeAxisMEMSAccelerometer;
        objective : CalibratedAccelerationData;
    }

    requirement def ChargeAmplifierRequirement {
        doc /* The charge amplifier shall convert capacitance changes from each sensing element into a proportional analog voltage signal. */
        subject : amplifier :> ChargeAmplifier;
        objective : VoltageValue {
            :>> level >= 0.0;
            :>> level <= 3.3;
        }
    }

    requirement def LowPassFilterRequirement {
        doc /* The low-pass filter shall attenuate high-frequency noise above the cutoff frequency from the analog voltage signal. */
        subject : filter :> LowPassFilter;
        objective : FrequencyValue {
            :>> cutoffFreq == 500.0;
        }
    }

    requirement def ADCRequirement {
        doc /* The ADC shall sample the filtered analog signal at the specified sampling rate and resolution, producing a raw digital value. */
        subject : adc :> AnalogToDigitalConverter;
        objective : Integer {
            :>> resolutionBits == 16;
        }
    }

    requirement def DSPCalibrationRequirement {
        doc /* The DSP shall apply calibration offsets and scaling factors to raw digital samples and package calibrated acceleration data for X, Y, and Z axes with a timestamp. */
        subject : dsp :> DigitalSignalProcessor;
        objective : CalibratedAccelerationData;
    }

    requirement def PowerStabilityRequirement {
        doc /* The voltage regulator shall provide a stable, clean power supply to all internal components within specified tolerance. */
        subject : regulator :> VoltageRegulator;
        objective : VoltageValue {
            :>> outputVoltage == 3.3;
            :>> tolerance == 0.033;
        }
    }

    requirement def LifecycleRequirement {
        doc /* The accelerometer shall follow a defined operational lifecycle: Off, Initializing (with self-test), Idle, Measuring (continuous sensing-processing-transmitting loop), LowPower, Error, and Resetting states, with defined transitions between them. */
        subject : accelerometer :> ThreeAxisMEMSAccelerometer;
        objective : AccelerometerLifecycle;
    }

    requirement def DataInterfaceRequirement {
        doc /* The system shall make calibrated acceleration data available through a digital data interface. */
        subject : accelerometer :> ThreeAxisMEMSAccelerometer;
        objective : CalibratedAccelerationData;
    }

    requirement def SelfTestRequirement {
        doc /* Upon power-up, the accelerometer shall perform a self-test to verify functionality of all sensing elements and signal processing components before entering Idle state. */
        subject : accelerometer :> ThreeAxisMEMSAccelerometer;
        objective : SelfTestResult {
            :>> passed == true;
        }
    }

    requirement def LowPowerModeRequirement {
        doc /* The accelerometer shall support a low-power mode to conserve energy while maintaining the ability to wake on command. */
        subject : accelerometer :> ThreeAxisMEMSAccelerometer;
        objective : Boolean;
    }

    requirement def ErrorHandlingRequirement {
        doc /* The accelerometer shall enter an Error state upon fault detection and support reset to recover from fault conditions. */
        subject : accelerometer :> ThreeAxisMEMSAccelerometer;
        objective : Boolean;
    }

    // ============================================================
    // Requirement Verification Package
    // ============================================================

    package Verification {
        use def ThreeAxisMeasurementRequirement;
        use def SensingElementRequirement;
        use def SignalChainRequirement;
        use def ChargeAmplifierRequirement;
        use def LowPassFilterRequirement;
        use def ADCRequirement;
        use def DSPCalibrationRequirement;
        use def PowerStabilityRequirement;
        use def LifecycleRequirement;
        use def DataInterfaceRequirement;
        use def SelfTestRequirement;
        use def LowPowerModeRequirement;
        use def ErrorHandlingRequirement;
    }
}
