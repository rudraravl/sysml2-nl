package StretchSensingUnit {
    private import SI::*;
    private import ISQ::*;
    private import ScalarValues::*;

    item def RawResistanceSample {
        attribute resistance :> ISQ::resistance;
        attribute timestamp :> ISQ::time;
    }

    item def ConditionedVoltageSample {
        attribute voltage :> ISQ::electricPotential;
        attribute timestamp :> ISQ::time;
    }

    item def DigitalSample {
        attribute count : ScalarValues::Integer;
        attribute timestamp :> ISQ::time;
    }

    item def CalibrationData {
        attribute originalLength :> ISQ::length;
        attribute baselineResistance :> ISQ::resistance;
        attribute gaugeFactor : ScalarValues::Real;
    }

    item def MeasurementData {
        attribute strain : ScalarValues::Real;
        attribute displacement :> ISQ::length;
        attribute timestamp :> ISQ::time;
        attribute valid : Boolean;
    }

    item def FaultSignal {
        attribute faultType : ScalarValues::String;
        attribute timestamp :> ISQ::time;
    }

    attribute def PowerOnSignal;
    attribute def InitializationComplete;
    attribute def CalibrationComplete;
    attribute def StartMeasurement;
    attribute def StopMeasurement;
    attribute def OverStretchSignal;
    attribute def ElectricalFaultSignal;
    attribute def ResetSignal;

    port def ResistanceOutPort {
        out item sample : RawResistanceSample;
    }
    port def ResistanceInPort {
        in item sample : RawResistanceSample;
    }
    port def VoltageOutPort {
        out item sample : ConditionedVoltageSample;
    }
    port def VoltageInPort {
        in item sample : ConditionedVoltageSample;
    }
    port def DigitalOutPort {
        out item sample : DigitalSample;
    }
    port def DigitalInPort {
        in item sample : DigitalSample;
    }
    port def MeasurementOutPort {
        out item data : MeasurementData;
        out item fault : FaultSignal;
    }
    port def CalibrationInPort {
        in item calData : CalibrationData;
    }

    action def InitializeAction;
    action def CalibrateAction {
        in item calData : CalibrationData;
    }
    action def CalculateMeasurements {
        in item sample : DigitalSample;
        in item calibration : CalibrationData;
        out item measurement : MeasurementData;
    }
    action def ValidateMeasurement {
        in item measurement : MeasurementData;
        out item validated : MeasurementData;
    }
    action def DetectFaultAction;
    action def LogFaultAction {
        out item fault : FaultSignal;
    }

    state def SensingUnitStates {
        entry; then off;

        state off;
        transition off_to_initializing
            first off
            accept PowerOnSignal
            do initialize : InitializeAction
            then initializing;

        state initializing;
        transition initializing_to_calibrating
            first initializing
            accept InitializationComplete
            then calibrating;

        state calibrating;
        transition calibrating_to_ready
            first calibrating
            accept CalibrationComplete
            then ready;

        state ready;
        transition ready_to_measuring
            first ready
            accept StartMeasurement
            then measuring;

        state measuring {
            do calculateMeasurements : CalculateMeasurements;
            do validateMeasurement : ValidateMeasurement;
        }
        transition measuring_to_ready
            first measuring
            accept StopMeasurement
            then ready;
        transition measuring_to_fault_overstretch
            first measuring
            accept OverStretchSignal
            do logFault : LogFaultAction
            then fault;
        transition measuring_to_fault_electrical
            first measuring
            accept ElectricalFaultSignal
            do logFault : LogFaultAction
            then fault;

        state fault {
            do detectFault : DetectFaultAction;
        }
        transition fault_to_ready
            first fault
            accept ResetSignal
            then ready;
    }

    part def StretchSensorElement {
        attribute originalLength :> ISQ::length;
        attribute baselineResistance :> ISQ::resistance;
        attribute currentResistance :> ISQ::resistance;
        attribute elongation :> ISQ::length;
        out port resistanceOut : ResistanceOutPort;
    }

    part def SignalConditioningCircuit {
        attribute gain : ScalarValues::Real;
        attribute offsetVoltage :> ISQ::electricPotential;
        in port resistanceIn : ResistanceInPort;
        out port voltageOut : VoltageOutPort;
    }

    part def AnalogToDigitalConverter {
        attribute samplingRate :> ISQ::frequency;
        attribute resolutionBits : ScalarValues::Integer;
        attribute referenceVoltage :> ISQ::electricPotential;
        in port voltageIn : VoltageInPort;
        out port digitalOut : DigitalOutPort;
    }

    part def MeasurementProcessor {
        attribute calibration : CalibrationData;
        attribute maxStrain : ScalarValues::Real;
        in port digitalIn : DigitalInPort;
        in port calIn : CalibrationInPort;
        out port measurementOut : MeasurementOutPort;
        perform action calculateMeasurements : CalculateMeasurements;
        perform action validateMeasurement : ValidateMeasurement;
        perform action detectFault : DetectFaultAction;
        perform action logFault : LogFaultAction;
        exhibit state processorStates : SensingUnitStates;
    }

    part def StretchSensingUnit {
        attribute powerConsumption :> ISQ::power;
        attribute maxOperatingStrain : ScalarValues::Real;
        part stretchSensor : StretchSensorElement;
        part conditioningCircuit : SignalConditioningCircuit;
        part adc : AnalogToDigitalConverter;
        part processor : MeasurementProcessor;

        connect stretchSensor.resistanceOut to conditioningCircuit.resistanceIn;
        connect conditioningCircuit.voltageOut to adc.voltageIn;
        connect adc.digitalOut to processor.digitalIn;

        port calibrationPort : CalibrationInPort;
        port unitMeasurementPort : MeasurementOutPort;

        connect calibrationPort to processor.calIn;
        connect processor.measurementOut to unitMeasurementPort;

        exhibit state unitStates : SensingUnitStates;
    }

    requirement def LowPowerRequirement {
        subject unit : StretchSensingUnit;
        doc /* The unit shall operate with low power consumption during continuous measurement. */
        attribute maxPower :> ISQ::power = 0.05 [W];
        require { unit.powerConsumption <= maxPower }
    }

    requirement def AccuracyRequirement {
        subject unit : StretchSensingUnit;
        doc /* The unit shall provide strain measurements accurate to within 0.1% of full scale. */
        attribute maxError : ScalarValues::Real = 0.001;
        require { maxError <= 0.001 }
    }

    requirement def HighResolutionRequirement {
        subject adc : AnalogToDigitalConverter;
        doc /* The ADC shall provide at least 16 bits of resolution. */
        attribute minResolution : ScalarValues::Integer = 16;
        require { adc.resolutionBits >= minResolution }
    }

    requirement def RapidSamplingRequirement {
        subject adc : AnalogToDigitalConverter;
        doc /* The ADC shall sample at a rate of at least 1 kHz. */
        attribute minSamplingRate :> ISQ::frequency = 1000 [Hz];
        require { adc.samplingRate >= minSamplingRate }
    }

    requirement def OverStretchProtectionRequirement {
        subject unit : StretchSensingUnit;
        doc /* The unit shall detect over-stretch conditions and enter a fault state. */
        attribute maxStrainThreshold : ScalarValues::Real = 0.5;
        require { unit.maxOperatingStrain <= maxStrainThreshold }
    }

    part sensingUnit : StretchSensingUnit {
        attribute redefines powerConsumption = 0.04 [W];
    }

    satisfy LowPowerRequirement by sensingUnit;
    satisfy AccuracyRequirement by sensingUnit;
    satisfy HighResolutionRequirement by sensingUnit.adc;
    satisfy RapidSamplingRequirement by sensingUnit.adc;
    satisfy OverStretchProtectionRequirement by sensingUnit;
}
