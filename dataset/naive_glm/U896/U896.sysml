package StretchSensingUnit {

    import ScalarValues::*;

    // ===== Value Types =====

    value type Resistance :> Real { unit "ohm"; }
    value type Voltage :> Real { unit "V"; }
    value type Length :> Real { unit "m"; }
    value type Strain :> Real { unit "1"; }
    value type Displacement :> Real { unit "m"; }
    value type Frequency :> Real { unit "Hz"; }
    value type TimeValue :> Real { unit "s"; }
    value type Power :> Real { unit "W"; }
    value type Temperature :> Real { unit "K"; }
    value type Current :> Real { unit "A"; }
    value type DigitalCode :> Integer;

    // ===== Enumerations =====

    enum def MeasurementQuality {
        high;
        medium;
        low;
        invalid;
    }

    enum def FaultType {
        none;
        overStretch;
        openCircuit;
        shortCircuit;
        adcError;
        processorError;
        powerFault;
    }

    enum def SensorMaterial {
        conductivePolymer;
        carbonElastomer;
        liquidMetal;
    }

    enum def PowerState {
        off;
        lowPower;
        active;
    }

    // ===== Item Definitions =====

    item def RawResistanceSignal {
        attribute resistance : Resistance;
        attribute timestamp : TimeValue;
        attribute valid : Boolean;
    }

    item def ConditionedVoltageSignal {
        attribute voltage : Voltage;
        attribute timestamp : TimeValue;
        attribute valid : Boolean;
    }

    item def DigitalSample {
        attribute code : DigitalCode;
        attribute timestamp : TimeValue;
        attribute valid : Boolean;
        attribute overrange : Boolean;
    }

    item def MeasurementData {
        attribute strain : Strain;
        attribute displacement : Displacement;
        attribute resistance : Resistance;
        attribute timestamp : TimeValue;
        attribute valid : Boolean;
        attribute quality : MeasurementQuality;
    }

    item def CalibrationParameters {
        attribute originalLength : Length;
        attribute baselineResistance : Resistance;
        attribute gaugeFactor : Real;
        attribute gain : Real;
        attribute offset : Real;
    }

    item def FaultEvent {
        attribute faultType : FaultType;
        attribute timestamp : TimeValue;
        attribute description : String;
    }

    item def PowerStatus {
        attribute state : PowerState;
        attribute voltage : Voltage;
        attribute current : Current;
    }

    item def SensorHealth {
        attribute resistance : Resistance;
        attribute withinRange : Boolean;
        attribute faultType : FaultType;
    }

    // ===== Port Definitions =====

    port def PhysicalAttachmentPort {
        attribute attached : Boolean;
        attribute attachmentStrain : Strain;
    }

    port def ResistanceOutPort {
        out signal : RawResistanceSignal;
    }

    port def ResistanceInPort {
        in signal : RawResistanceSignal;
    }

    port def VoltageOutPort {
        out signal : ConditionedVoltageSignal;
    }

    port def VoltageInPort {
        in signal : ConditionedVoltageSignal;
    }

    port def DigitalOutPort {
        out sample : DigitalSample;
    }

    port def DigitalInPort {
        in sample : DigitalSample;
    }

    port def MeasurementOutputPort {
        out data : MeasurementData;
        out fault : FaultEvent;
    }

    port def PowerInputPort {
        attribute supplyVoltage : Voltage;
        attribute supplyCurrent : Current;
        attribute powerState : PowerState;
    }

    // ===== Action Definitions =====

    action def SenseStretch {
        in physicalStrain : Strain;
        in baselineResistance : Resistance;
        in gaugeFactor : Real;
        out rawSignal : RawResistanceSignal;
    }

    action def ConditionSignal {
        in rawSignal : RawResistanceSignal;
        in gain : Real;
        in offset : Real;
        out conditionedSignal : ConditionedVoltageSignal;
    }

    action def ConvertAnalogToDigital {
        in conditionedSignal : ConditionedVoltageSignal;
        in referenceVoltage : Voltage;
        in resolutionBits : Integer;
        out digitalSample : DigitalSample;
    }

    action def CalculateMeasurement {
        in digitalSample : DigitalSample;
        in calibration : CalibrationParameters;
        in referenceVoltage : Voltage;
        in resolutionBits : Integer;
        out measurement : MeasurementData;
    }

    action def ValidateMeasurement {
        in measurement : MeasurementData;
        in maxStrain : Strain;
        in maxResistance : Resistance;
        in minResistance : Resistance;
        out validatedMeasurement : MeasurementData;
        out fault : FaultEvent;
    }

    action def PerformCalibration {
        in rawSignal : RawResistanceSignal;
        in originalLength : Length;
        out calibration : CalibrationParameters;
    }

    action def DetectFault {
        in measurement : MeasurementData;
        in maxStrain : Strain;
        in maxResistance : Resistance;
        in minResistance : Resistance;
        out fault : FaultEvent;
    }

    action def PowerUpSequence {
        out powerStatus : PowerStatus;
    }

    action def InitializeHardware {
        in calibration : CalibrationParameters;
        out status : Boolean;
    }

    action def StabilizePowerRails {
        out stable : Boolean;
    }

    action def ConfigureADC {
        in samplingRate : Frequency;
        in resolutionBits : Integer;
        out configured : Boolean;
    }

    action def ConfigureSignalConditioning {
        in gain : Real;
        in offset : Real;
        out configured : Boolean;
    }

    action def ConfigureProcessor {
        in calibration : CalibrationParameters;
        out configured : Boolean;
    }

    action def MeasureBaselineResistance {
        out baselineResistance : Resistance;
    }

    action def ComputeOffset {
        in baselineResistance : Resistance;
        out offset : Real;
    }

    action def VerifySensorIntegrity {
        in resistance : Resistance;
        in minResistance : Resistance;
        in maxResistance : Resistance;
        out healthy : Boolean;
    }

    action def StartContinuousSampling {
        out sampling : Boolean;
    }

    action def ProcessSamples {
        in sample : DigitalSample;
        out measurement : MeasurementData;
    }

    action def OutputMeasurements {
        in measurement : MeasurementData;
    }

    action def StopSampling {
        out stopped : Boolean;
    }

    action def EnterLowPowerMode {
        out powerState : PowerState;
    }

    action def MonitorForRequests {
        out requestReceived : Boolean;
    }

    action def WakeUp {
        out awake : Boolean;
    }

    action def LogFault {
        in fault : FaultEvent;
    }

    action def DisableOutput {
        out disabled : Boolean;
    }

    action def AttemptRecovery {
        out recovered : Boolean;
    }

    action def ClearFault {
        out cleared : Boolean;
    }

    action def DisableAllComponents {
        out disabled : Boolean;
    }

    action def VerifyPowerRails {
        out verified : Boolean;
    }

    action def SetReadyFlag {
        out ready : Boolean;
    }

    action def StartCalibration {
        out started : Boolean;
    }

    action def StoreCalibration {
        in calibration : CalibrationParameters;
        out stored : Boolean;
    }

    action def LoadCalibrationParameters {
        out calibration : CalibrationParameters;
    }

    // ===== Part Definitions =====

    part def StretchSensorElement {
        port attachmentPort : PhysicalAttachmentPort;
        port outputPort : ResistanceOutPort;
        port powerPort : PowerInputPort;

        attribute material : SensorMaterial = SensorMaterial::conductivePolymer;
        attribute nominalResistance : Resistance = 1000;
        attribute maxStrain : Strain = 0.5;
        attribute maxResistance : Resistance = 2000;
        attribute minResistance : Resistance = 500;
        attribute originalLength : Length = 0.1;
        attribute currentLength : Length = 0.1;
        attribute currentResistance : Resistance = 1000;
        attribute gaugeFactor : Real = 2.0;
        attribute minOperatingTemperature : Temperature = 263.15;
        attribute maxOperatingTemperature : Temperature = 358.15;

        constraint resistanceStrainRelation {
            doc /* The resistance of the sensor is proportional to the strain:
                  R = R0 * (1 + GF * strain) where strain = (L - L0) / L0 */;
            currentResistance == nominalResistance * (1 + gaugeFactor * (currentLength - originalLength) / originalLength);
        }

        constraint resistanceRange {
            currentResistance >= minResistance and currentResistance <= maxResistance;
        }

        action def updateResistance {
            in strain : Strain;
            out resistance : Resistance;
        }
    }

    part def SignalConditioningCircuit {
        port inputPort : ResistanceInPort;
        port outputPort : VoltageOutPort;
        port powerPort : PowerInputPort;

        attribute gain : Real = 100.0;
        attribute offset : Real = 0.0;
        attribute bandwidth : Frequency = 10000;
        attribute noiseFloor : Voltage = 0.001;
        attribute inputImpedance : Resistance = 1000000;
        attribute supplyVoltage : Voltage = 3.3;
        attribute powerConsumption : Power = 0.005;

        constraint voltageOutput {
            doc /* The output voltage is proportional to the resistance change:
                  V = gain * (R - R0) / R0 + offset */;
            outputPort.signal.voltage == gain * (inputPort.signal.resistance - 1000) / 1000 + offset;
        }

        action def condition {
            in rawSignal : RawResistanceSignal;
            out conditionedSignal : ConditionedVoltageSignal;
        }
    }

    part def AnalogToDigitalConverter {
        port inputPort : VoltageInPort;
        port outputPort : DigitalOutPort;
        port powerPort : PowerInputPort;

        attribute samplingRate : Frequency = 1000;
        attribute resolutionBits : Integer = 16;
        attribute referenceVoltage : Voltage = 3.3;
        attribute lsbVoltage : Voltage = 0.000050354;
        attribute conversionTime : TimeValue = 0.0001;
        attribute powerConsumption : Power = 0.005;

        constraint digitalConversion {
            doc /* The digital code is proportional to the input voltage:
                  code = V * 2^bits / Vref */;
            outputPort.sample.code == (inputPort.signal.voltage * (2 ^ resolutionBits)) / referenceVoltage;
        }

        constraint samplingConstraint {
            samplingRate <= 1 / conversionTime;
        }

        action def convert {
            in conditionedSignal : ConditionedVoltageSignal;
            out digitalSample : DigitalSample;
        }
    }

    part def MeasurementProcessor {
        port inputPort : DigitalInPort;
        port outputPort : MeasurementOutputPort;
        port powerPort : PowerInputPort;

        attribute calibration : CalibrationParameters;
        attribute clockFrequency : Frequency = 8000000;
        attribute processingLatency : TimeValue = 0.001;
        attribute maxStrain : Strain = 0.5;
        attribute maxResistance : Resistance = 2000;
        attribute minResistance : Resistance = 500;
        attribute firmwareVersion : String = "1.0.0";
        attribute powerConsumption : Power = 0.02;

        constraint strainCalculation {
            doc /* Strain is calculated from the measured resistance:
                  strain = (R - R0) / (R0 * GF) */;
            outputPort.data.strain == (outputPort.data.resistance - calibration.baselineResistance) /
                (calibration.baselineResistance * calibration.gaugeFactor);
        }

        constraint displacementCalculation {
            doc /* Displacement is the total change in length:
                  displacement = strain * originalLength */;
            outputPort.data.displacement == outputPort.data.strain * calibration.originalLength;
        }

        action def calculate {
            in digitalSample : DigitalSample;
            out measurement : MeasurementData;
        }

        action def validate {
            in measurement : MeasurementData;
            out validated : MeasurementData;
            out fault : FaultEvent;
        }
    }

    // ===== State Machine Definition =====

    state def SensingUnitStateMachine {
        entry; then Off;

        state Off {
            entry action DisableAllComponents();
            attribute powerState : PowerState = PowerState::off;
        }

        transition
            first Off
            then PoweringUp
            when powerApplied;

        state PoweringUp {
            entry action PowerUpSequence();
            do action StabilizePowerRails();
            exit action VerifyPowerRails();
        }

        transition
            first PoweringUp
            then Initializing
            when powerUpComplete;

        transition
            first PoweringUp
            then FaultDetected
            when faultDetected;

        state Initializing {
            entry action LoadCalibrationParameters();
            do action ConfigureADC();
            do action ConfigureSignalConditioning();
            do action ConfigureProcessor();
            exit action SetReadyFlag();
        }

        transition
            first Initializing
            then Calibrating
            when initializationComplete;

        transition
            first Initializing
            then FaultDetected
            when faultDetected;

        state Calibrating {
            entry action StartCalibration();
            do action MeasureBaselineResistance();
            do action ComputeOffset();
            do action VerifySensorIntegrity();
            exit action StoreCalibration();
        }

        transition
            first Calibrating
            then Ready
            when calibrationComplete;

        transition
            first Calibrating
            then FaultDetected
            when faultDetected;

        state Ready {
            entry action EnterLowPowerMode();
            do action MonitorForRequests();
            exit action WakeUp();
        }

        transition
            first Ready
            then Measuring
            when measurementRequested;

        transition
            first Ready
            then FaultDetected
            when faultDetected;

        transition
            first Ready
            then Off
            when shutdownRequested;

        state Measuring {
            entry action StartContinuousSampling();
            do action ProcessSamples();
            do action OutputMeasurements();
            exit action StopSampling();
        }

        transition
            first Measuring
            then Ready
            when measurementStopped;

        transition
            first Measuring
            then FaultDetected
            when faultDetected;

        transition
            first Measuring
            then Off
            when shutdownRequested;

        state FaultDetected {
            entry action LogFault();
            entry action DisableOutput();
            do action AttemptRecovery();
            exit action ClearFault();
        }

        transition
            first FaultDetected
            then Calibrating
            when recoverySuccessful;

        transition
            first FaultDetected
            then Off
            when shutdownRequested;
    }

    // ===== Main Sensing Unit =====

    part def StretchSensingUnit {
        port powerInput : PowerInputPort;
        port measurementOutput : MeasurementOutputPort;
        port attachmentPort : PhysicalAttachmentPort;

        attribute unitName : String = "StretchSensingUnit-v1";
        attribute totalPowerConsumption : Power = 0.05;
        attribute measurementRate : Frequency = 1000;
        attribute accuracy : Strain = 0.0001;
        attribute resolution : Strain = 0.00001;
        attribute minOperatingTemperature : Temperature = 263.15;
        attribute maxOperatingTemperature : Temperature = 358.15;
        attribute maxSampleRate : Frequency = 10000;

        attribute powerApplied : Boolean = false;
        attribute powerUpComplete : Boolean = false;
        attribute initializationComplete : Boolean = false;
        attribute calibrationComplete : Boolean = false;
        attribute measurementRequested : Boolean = false;
        attribute measurementStopped : Boolean = false;
        attribute faultDetected : Boolean = false;
        attribute recoverySuccessful : Boolean = false;
        attribute shutdownRequested : Boolean = false;

        part sensorElement : StretchSensorElement {
            attribute material : SensorMaterial = SensorMaterial::conductivePolymer;
            attribute nominalResistance : Resistance = 1000;
            attribute maxStrain : Strain = 0.5;
            attribute originalLength : Length = 0.1;
            attribute gaugeFactor : Real = 2.0;
        }

        part conditioningCircuit : SignalConditioningCircuit {
            attribute gain : Real = 100.0;
            attribute bandwidth : Frequency = 10000;
            attribute noiseFloor : Voltage = 0.001;
        }

        part adc : AnalogToDigitalConverter {
            attribute samplingRate : Frequency = 1000;
            attribute resolutionBits : Integer = 16;
            attribute referenceVoltage : Voltage = 3.3;
        }

        part processor : MeasurementProcessor {
            attribute clockFrequency : Frequency = 8000000;
            attribute maxStrain : Strain = 0.5;
            attribute maxResistance : Resistance = 2000;
            attribute minResistance : Resistance = 500;
        }

        connect sensorElement.outputPort to conditioningCircuit.inputPort;
        connect conditioningCircuit.outputPort to adc.inputPort;
        connect adc.outputPort to processor.inputPort;
        connect processor.outputPort to measurementOutput;
        connect powerInput to sensorElement.powerPort;
        connect powerInput to conditioningCircuit.powerPort;
        connect powerInput to adc.powerPort;
        connect powerInput to processor.powerPort;
        connect sensorElement.attachmentPort to attachmentPort;

        exhibit SensingUnitStateMachine;
    }

    // ===== Requirements =====

    requirement def StretchSensingRequirement {
        subject sensingUnit : StretchSensingUnit;
        doc /* The stretch sensing unit shall measure physical stretch and deformation
              of an object using a resistive stretch sensor and provide digital
              measurement data including strain and displacement. */;
    }

    requirement def PowerUpRequirement {
        subject sensingUnit : StretchSensingUnit;
        doc /* The unit shall power up and initialize within 500 ms of power application. */;
        attribute maxPowerUpTime : TimeValue = 0.5;
    }

    requirement def MeasurementAccuracyRequirement {
        subject sensingUnit : StretchSensingUnit;
        doc /* The unit shall measure strain with an accuracy of at least 0.01 percent. */;
        attribute minAccuracy : Strain = 0.0001;
    }

    requirement def MeasurementRateRequirement {
        subject sensingUnit : StretchSensingUnit;
        doc /* The unit shall provide validated measurement data at a rate of at least 1 kHz. */;
        attribute minRate : Frequency = 1000;
    }

    requirement def PowerConsumptionRequirement {
        subject sensingUnit : StretchSensingUnit;
        doc /* The unit shall consume no more than 100 mW during continuous measurement mode. */;
        attribute maxPower : Power = 0.1;
    }

    requirement def FaultDetectionRequirement {
        subject sensingUnit : StretchSensingUnit;
        doc /* The unit shall detect over-stretch conditions and electrical faults
              including open circuit and short circuit, and enter a fault state,
              ceasing measurement output until recovery. */;
    }

    requirement def CalibrationRequirement {
        subject sensingUnit : StretchSensingUnit;
        doc /* The unit shall perform a calibration phase using baseline resistance
              and original length to establish reference values for strain calculation. */;
    }

    requirement def DataOutputRequirement {
        subject sensingUnit : StretchSensingUnit;
        doc /* The unit shall output validated measurement data including strain,
              displacement, resistance, timestamp, and measurement quality via
              the measurement output port. */;
    }

    requirement def ResolutionRequirement {
        subject sensingUnit : StretchSensingUnit;
        doc /* The ADC shall have at least 16-bit resolution to ensure high-resolution
              measurements. */;
        attribute minResolutionBits : Integer = 16;
    }

    requirement def OperatingTemperatureRequirement {
        subject sensingUnit : StretchSensingUnit;
        doc /* The unit shall operate over a temperature range of minus 10 degrees C
              to plus 85 degrees C. */;
        attribute minTemperature : Temperature = 263.15;
        attribute maxTemperature : Temperature = 358.15;
    }

    requirement def SensorRangeRequirement {
        subject sensingUnit : StretchSensingUnit;
        doc /* The stretch sensor shall measure strains up to 50 percent without
              permanent deformation. */;
        attribute maxStrain : Strain = 0.5;
    }

    requirement def StateMachineRequirement {
        subject sensingUnit : StretchSensingUnit;
        doc /* The unit shall operate through the states of Off, PoweringUp,
              Initializing, Calibrating, Ready, Measuring, and FaultDetected,
              with transitions governed by power application, initialization
              completion, calibration completion, measurement requests, and
              fault detection. */;
    }

    requirement def LowPowerRequirement {
        subject sensingUnit : StretchSensingUnit;
        doc /* The unit shall enter a low-power mode when in the Ready state
              and wake up upon receiving a measurement request. */;
    }

    requirement def TimestampRequirement {
        subject sensingUnit : StretchSensingUnit;
        doc /* All measurement data output by the unit shall include a timestamp
              indicating the time of measurement. */;
    }

    requirement sensingUnitRequirement : StretchSensingRequirement {
        subject :> sensingUnit;
    }

    requirement powerUpReq : PowerUpRequirement {
        subject :> sensingUnit;
    }

    requirement accuracyReq : MeasurementAccuracyRequirement {
        subject :> sensingUnit;
    }

    requirement rateReq : MeasurementRateRequirement {
        subject :> sensingUnit;
    }

    requirement powerReq : PowerConsumptionRequirement {
        subject :> sensingUnit;
    }

    requirement faultReq : FaultDetectionRequirement {
        subject :> sensingUnit;
    }

    requirement calibrationReq : CalibrationRequirement {
        subject :> sensingUnit;
    }

    requirement dataOutputReq : DataOutputRequirement {
        subject :> sensingUnit;
    }

    requirement resolutionReq : ResolutionRequirement {
        subject :> sensingUnit;
    }

    requirement tempReq : OperatingTemperatureRequirement {
        subject :> sensingUnit;
    }

    requirement sensorRangeReq : SensorRangeRequirement {
        subject :> sensingUnit;
    }

    requirement stateMachineReq : StateMachineRequirement {
        subject :> sensingUnit;
    }

    requirement lowPowerReq : LowPowerRequirement {
        subject :> sensingUnit;
    }

    requirement timestampReq : TimestampRequirement {
        subject :> sensingUnit;
    }

}
