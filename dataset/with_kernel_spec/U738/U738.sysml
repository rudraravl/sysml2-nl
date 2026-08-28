package LightToDigitalSensor {
    private import SI::*;
    private import ISQ::*;
    private import ScalarValues::*;

    item def LightInput {
        attribute illuminance : ISQ::IlluminanceValue;
    }
    item def PhotocurrentSignal {
        attribute current : ISQ::ElectricCurrentValue;
    }
    item def VoltageSignal {
        attribute voltage : ISQ::ElectricPotentialValue;
    }
    item def RawDigitalValue {
        attribute counts : ScalarValues::Integer;
    }
    item def CalibratedLightOutput {
        attribute illuminance : ISQ::IlluminanceValue;
    }
    item def ElectricalPower {
        attribute voltage : ISQ::ElectricPotentialValue;
        attribute current : ISQ::ElectricCurrentValue;
    }

    attribute def DurationValue :> ISQ::duration;

    attribute def MeasurementCommand;
    attribute def ConversionComplete;
    attribute def DataTransmissionRequest;
    attribute def DataTransmissionComplete;
    attribute def FaultCondition;
    attribute def PowerGood;

    part def LEDPhotodetector {
        in item incidentLight : LightInput;
        in item supplyPower : ElectricalPower;
        out item photocurrent : PhotocurrentSignal;
        attribute responsivity : ScalarValues::Real := 0.45;
    }
    part def TransimpedanceAmplifier {
        in item inputCurrent : PhotocurrentSignal;
        in item supplyPower : ElectricalPower;
        out item outputVoltage : VoltageSignal;
        attribute transimpedanceGain : ScalarValues::Real := 100000.0;
    }
    part def InstrumentationAmplifier {
        in item inputVoltage : VoltageSignal;
        in item supplyPower : ElectricalPower;
        out item outputVoltage : VoltageSignal;
        attribute voltageGain : ScalarValues::Real := 10.0;
    }
    part def LowPassFilter {
        in item inputVoltage : VoltageSignal;
        in item supplyPower : ElectricalPower;
        out item filteredVoltage : VoltageSignal;
        attribute cutoffFrequency : ISQ::FrequencyValue := 100.0 [Hz];
    }
    part def ADC {
        in item analogInput : VoltageSignal;
        in item supplyPower : ElectricalPower;
        out item digitalOutput : RawDigitalValue;
        attribute resolutionBits : ScalarValues::Integer := 16;
    }
    part def SignalProcessor {
        in item rawInput : RawDigitalValue;
        in item supplyPower : ElectricalPower;
        out item calibratedOutput : CalibratedLightOutput;
        attribute calibrationGain : ScalarValues::Real := 1.0;
        attribute calibrationOffset : ScalarValues::Real := 0.0;
        action processSample {
            in raw : RawDigitalValue;
            out calibrated : CalibratedLightOutput;
            assign calibrated.illuminance := calibrationGain * raw.counts + calibrationOffset;
        }
    }
    part def PowerDistribution {
        in item externalPower : ElectricalPower;
        out item ledPower : ElectricalPower;
        out item tiaPower : ElectricalPower;
        out item inAmpPower : ElectricalPower;
        out item filterPower : ElectricalPower;
        out item adcPower : ElectricalPower;
        out item processorPower : ElectricalPower;
    }

    state def LightSensorModes {
        entry;
        then standby;
        state standby;
        state sensingConverting {
            state sensing;
            state converting;
            transition first sensing
                accept ConversionComplete
                then converting;
        }
        state transmitting;
        state fault;
        transition first standby
            accept MeasurementCommand
            then sensingConverting.sensing;
        transition first sensingConverting.converting
            accept DataTransmissionRequest
            then transmitting;
        transition first transmitting
            accept DataTransmissionComplete
            then standby;
        transition first sensingConverting.sensing
            accept FaultCondition
            then fault;
        transition first sensingConverting.converting
            accept FaultCondition
            then fault;
        transition first fault
            accept PowerGood
            then standby;
    }

    part def LightSensor {
        in item ambientLight : LightInput;
        in item externalPower : ElectricalPower;
        out item lightReading : CalibratedLightOutput;

        part led : LEDPhotodetector;
        part tia : TransimpedanceAmplifier;
        part inAmp : InstrumentationAmplifier;
        part lpf : LowPassFilter;
        part adc : ADC;
        part processor : SignalProcessor;
        part powerDistribution : PowerDistribution;

        flow self.ambientLight to led.incidentLight;
        flow led.photocurrent to tia.inputCurrent;
        flow tia.outputVoltage to inAmp.inputVoltage;
        flow inAmp.outputVoltage to lpf.inputVoltage;
        flow lpf.filteredVoltage to adc.analogInput;
        flow adc.digitalOutput to processor.rawInput;
        flow processor.calibratedOutput to self.lightReading;

        flow self.externalPower to powerDistribution.externalPower;
        flow powerDistribution.ledPower to led.supplyPower;
        flow powerDistribution.tiaPower to tia.supplyPower;
        flow powerDistribution.inAmpPower to inAmp.supplyPower;
        flow powerDistribution.filterPower to lpf.supplyPower;
        flow powerDistribution.adcPower to adc.supplyPower;
        flow powerDistribution.processorPower to processor.supplyPower;

        state operatingState : LightSensorModes;
    }

    requirement def AccuracyRequirement {
        attribute maxErrorPercent : ScalarValues::Real;
    }
    requirement def MeasurementRangeRequirement {
        attribute minIlluminance : ISQ::IlluminanceValue;
        attribute maxIlluminance : ISQ::IlluminanceValue;
    }
    requirement def ResponseTimeRequirement {
        attribute maxSettlingTime : DurationValue;
    }
    requirement def OperatingEnvironmentRequirement {
        attribute minTemperature : ISQ::ThermodynamicTemperatureValue;
        attribute maxTemperature : ISQ::ThermodynamicTemperatureValue;
        attribute minSupplyVoltage : ISQ::ElectricPotentialValue;
        attribute maxSupplyVoltage : ISQ::ElectricPotentialValue;
    }

    requirement accuracyRequirement : AccuracyRequirement {
        :>> maxErrorPercent = 2.0;
    }
    requirement measurementRangeRequirement : MeasurementRangeRequirement {
        :>> minIlluminance = 0.0 [lx];
        :>> maxIlluminance = 20000.0 [lx];
    }
    requirement responseTimeRequirement : ResponseTimeRequirement {
        :>> maxSettlingTime = 0.05 [s];
    }
    requirement operatingEnvironmentRequirement : OperatingEnvironmentRequirement {
        :>> minTemperature = 233.15 [K];
        :>> maxTemperature = 358.15 [K];
        :>> minSupplyVoltage = 3.0 [V];
        :>> maxSupplyVoltage = 5.5 [V];
    }
}
