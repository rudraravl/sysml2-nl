package DisplacementSensingUnitModel {

    import ScalarValues::*;

    package ValueTypes {
        value type DisplacementValue :> Real {
            unit mm;
        }
        value type VoltageValue :> Real {
            unit V;
        }
        value type FrequencyValue :> Real {
            unit Hz;
        }
        value type GainValue :> Real {
            unit dimensionless;
        }
        value type AccuracyValue :> Real {
            unit mm;
        }
        value type TimestampValue :> Integer {
            unit ms;
        }
        value type SNRValue :> Real {
            unit dB;
        }
        value type SensitivityValue :> Real {
            unit V/mm;
        }
    }

    package Items {
        import ValueTypes::*;

        item def RawAnalogSignal {
            value voltage : VoltageValue;
            value noiseLevel : VoltageValue;
            value sourceDisplacement : DisplacementValue;
        }

        item def ConditionedAnalogSignal {
            value voltage : VoltageValue;
            value signalToNoiseRatio : SNRValue;
            value bandwidth : FrequencyValue;
        }

        item def DisplacementReading {
            value displacement : DisplacementValue;
            value timestamp : TimestampValue;
            value sampleIndex : Integer;
            value qualityFlag : Boolean;
        }
    }

    package Ports {
        import Items::*;

        port def MechanicalInputPort {
            in displacement : DisplacementValue;
        }

        port def RawSignalOutputPort {
            out signal : RawAnalogSignal;
        }

        port def RawSignalInputPort {
            in signal : RawAnalogSignal;
        }

        port def ConditionedSignalOutputPort {
            out signal : ConditionedAnalogSignal;
        }

        port def ConditionedSignalInputPort {
            in signal : ConditionedAnalogSignal;
        }

        port def DigitalDataOutputPort {
            out reading : DisplacementReading;
        }
    }

    package Interfaces {
        import Ports::*;

        interface def RawSignalInterface {
            end source : RawSignalOutputPort;
            end target : RawSignalInputPort;
        }

        interface def ConditionedSignalInterface {
            end source : ConditionedSignalOutputPort;
            end target : ConditionedSignalInputPort;
        }
    }

    package Components {
        import ValueTypes::*;
        import Items::*;
        import Ports::*;

        part def DisplacementSensor {
            attribute measurementRange : DisplacementValue = 100 [mm];
            attribute accuracy : AccuracyValue = 0.01 [mm];
            attribute sensitivity : SensitivityValue = 0.05 [V/mm];
            attribute powered : Boolean = false;

            port mechanicalInput : MechanicalInputPort;
            port rawOutput : RawSignalOutputPort;

            action transduce {
                in physicalDisplacement : DisplacementValue = mechanicalInput.displacement;
                out rawSignal : RawAnalogSignal = rawOutput.signal;
            }

            state sensorOperation {
                state Off;
                state Active;
                transition initial to Off;
                transition Off to Active when powered == true;
                transition Active to Off when powered == false;
                do in Active transduce;
            }
        }

        part def SignalConditioner {
            attribute gain : GainValue = 10;
            attribute cutoffFrequency : FrequencyValue = 500 [Hz];
            attribute filterOrder : Integer = 4;
            attribute enabled : Boolean = false;

            port rawInput : RawSignalInputPort;
            port conditionedOutput : ConditionedSignalOutputPort;

            action amplify {
                in inputSignal : RawAnalogSignal = rawInput.signal;
                out amplifiedVoltage : VoltageValue;
            }

            action filter {
                in amplifiedVoltage : VoltageValue;
                out filteredSignal : ConditionedAnalogSignal = conditionedOutput.signal;
            }

            state conditionerOperation {
                state Standby;
                state Conditioning;
                transition initial to Standby;
                transition Standby to Conditioning when enabled == true;
                transition Conditioning to Standby when enabled == false;
                do in Conditioning { amplify; then filter; }
            }
        }

        part def MeasurementProcessor {
            attribute samplingRate : FrequencyValue = 1000 [Hz];
            attribute resolutionBits : Integer = 16;
            attribute calibrationOffset : DisplacementValue = 0 [mm];
            attribute running : Boolean = false;
            attribute sampleCounter : Integer = 0;

            port conditionedInput : ConditionedSignalInputPort;
            port digitalOutput : DigitalDataOutputPort;

            action sample {
                in conditionedSignal : ConditionedAnalogSignal = conditionedInput.signal;
                out sampledVoltage : VoltageValue;
            }

            action convert {
                in sampledVoltage : VoltageValue;
                out displacementValue : DisplacementValue;
            }

            action package {
                in displacementValue : DisplacementValue;
                in timestamp : TimestampValue;
                out reading : DisplacementReading = digitalOutput.reading;
            }

            state processorOperation {
                state Idle;
                state Sampling;
                state Converting;
                state Packaging;
                transition initial to Idle;
                transition Idle to Sampling when running == true;
                transition Sampling to Converting when true;
                transition Converting to Packaging when true;
                transition Packaging to Sampling when running == true;
                transition Sampling to Idle when running == false;
                do in Sampling sample;
                do in Converting convert;
                do in Packaging package;
            }
        }
    }

    package Assembly {
        import Components::*;
        import Ports::*;
        import Interfaces::*;

        part def DisplacementSensingUnit {
            attribute unitId : String;
            attribute operational : Boolean = false;
            attribute applicationDomain : String;

            port mechanicalInput : MechanicalInputPort;
            port digitalOutput : DigitalDataOutputPort;

            part sensor : DisplacementSensor;
            part conditioner : SignalConditioner;
            part processor : MeasurementProcessor;

            connection mechanicalConnection connect mechanicalInput to sensor.mechanicalInput;
            interface rawSignalLink : RawSignalInterface connect sensor.rawOutput to conditioner.rawInput;
            interface conditionedSignalLink : ConditionedSignalInterface connect conditioner.conditionedOutput to processor.conditionedInput;
            connection digitalDataConnection connect processor.digitalOutput to digitalOutput;

            state unitOperation {
                state PoweredOff;
                state Initializing;
                state Measuring;
                state Faulted;

                transition initial to PoweredOff;
                transition PoweredOff to Initializing when operational == true;
                transition Initializing to Measuring when sensor.powered == true && conditioner.enabled == true && processor.running == true;
                transition Measuring to Faulted when sensor.powered == false;
                transition Measuring to PoweredOff when operational == false;
                transition Faulted to PoweredOff when operational == false;
            }
        }
    }

    package Requirements {
        import ValueTypes::*;
        import Components::*;
        import Assembly::*;

        requirement def MeasurementRangeRequirement {
            subject unit : DisplacementSensingUnit;
            requirement constraint {
                unit.sensor.measurementRange <= 100 [mm]
            }
        }

        requirement def MeasurementAccuracyRequirement {
            subject unit : DisplacementSensingUnit;
            requirement constraint {
                unit.sensor.accuracy <= 0.01 [mm]
            }
        }

        requirement def AmplificationGainRequirement {
            subject conditioner : SignalConditioner;
            requirement constraint {
                conditioner.gain == 10
            }
        }

        requirement def SamplingRateRequirement {
            subject processor : MeasurementProcessor;
            requirement constraint {
                processor.samplingRate >= 1000 [Hz]
            }
        }

        requirement def DigitalOutputRequirement {
            subject unit : DisplacementSensingUnit;
            requirement constraint {
                unit.digitalOutput.reading.displacement.unit == mm &&
                unit.digitalOutput.reading.timestamp.unit == ms
            }
        }

        requirement def SignalConditioningRequirement {
            subject conditioner : SignalConditioner;
            requirement constraint {
                conditioner.cutoffFrequency >= 500 [Hz] &&
                conditioner.filterOrder >= 2
            }
        }

        requirement def DisplacementSensingUnitRequirements {
            requirement rangeReq : MeasurementRangeRequirement;
            requirement accuracyReq : MeasurementAccuracyRequirement;
            requirement gainReq : AmplificationGainRequirement;
            requirement samplingReq : SamplingRateRequirement;
            requirement outputReq : DigitalOutputRequirement;
            requirement conditioningReq : SignalConditioningRequirement;
        }

        verification RangeVerification {
            subject unit : DisplacementSensingUnit;
            objective {
                requirement constraint { unit.sensor.measurementRange == 100 [mm] }
            }
        }

        verification AccuracyVerification {
            subject unit : DisplacementSensingUnit;
            objective {
                requirement constraint { unit.sensor.accuracy == 0.01 [mm] }
            }
        }

        verification GainVerification {
            subject conditioner : SignalConditioner;
            objective {
                requirement constraint { conditioner.gain == 10 }
            }
        }

        verification SamplingRateVerification {
            subject processor : MeasurementProcessor;
            objective {
                requirement constraint { processor.samplingRate == 1000 [Hz] }
            }
        }

        verification OutputVerification {
            subject unit : DisplacementSensingUnit;
            objective {
                requirement constraint { unit.digitalOutput.reading.displacement.unit == mm }
            }
        }
    }

    package Instances {
        import Assembly::*;

        part displacementSensingUnit_Instance : DisplacementSensingUnit {
            attribute unitId = "DSU-001";
            attribute applicationDomain = "Industrial Automation";
            attribute operational = true;

            redefines sensor {
                attribute powered = true;
            }
            redefines conditioner {
                attribute enabled = true;
            }
            redefines processor {
                attribute running = true;
            }
        }
    }
}
