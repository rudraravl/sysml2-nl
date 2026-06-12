package PiezoelectricSensingUnitModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def ElectricCharge {
        :> scalarValue;
        unit = "C";
    }

    attribute def ElectricPotential {
        :> scalarValue;
        unit = "V";
    }

    attribute def ElectricCurrent {
        :> scalarValue;
        unit = "A";
    }

    attribute def Capacitance {
        :> scalarValue;
        unit = "F";
    }

    attribute def Resistance {
        :> scalarValue;
        unit = "ohm";
    }

    attribute def Force {
        :> scalarValue;
        unit = "N";
    }

    attribute def Pressure {
        :> scalarValue;
        unit = "Pa";
    }

    attribute def Frequency {
        :> scalarValue;
        unit = "Hz";
    }

    attribute def Temperature {
        :> scalarValue;
        unit = "degC";
    }

    attribute def TimeDuration {
        :> scalarValue;
        unit = "s";
    }

    attribute def DigitalCount {
        :> scalarValue;
        unit = "count";
    }

    attribute def Sensitivity {
        :> scalarValue;
        unit = "C/N";
    }

    attribute def SignalToNoiseRatio {
        :> scalarValue;
        unit = "dB";
    }

    item def MechanicalStimulus {
        attribute appliedForce : Force;
        attribute contactPressure : Pressure;
        attribute stimulusFrequency : Frequency;
        attribute duration : TimeDuration;
    }

    item def PiezoelectricChargeSignal {
        attribute charge : ElectricCharge;
        attribute leakageCurrent : ElectricCurrent;
        attribute sourceCapacitance : Capacitance;
    }

    item def AnalogVoltageSignal {
        attribute voltage : ElectricPotential;
        attribute frequency : Frequency;
        attribute noiseRms : ElectricPotential;
    }

    item def DigitalMeasurement {
        attribute sampleCount : DigitalCount;
        attribute measuredForce : Force;
        attribute measuredPressure : Pressure;
        attribute sampleTime : TimeDuration;
        attribute validity : Boolean;
    }

    item def Power {
        attribute supplyVoltage : ElectricPotential;
        attribute supplyCurrent : ElectricCurrent;
    }

    port def MechanicalInputPort {
        in item stimulus : MechanicalStimulus;
    }

    port def ChargeSignalPort {
        out item chargeSignal : PiezoelectricChargeSignal;
    }

    port def AnalogSignalPort {
        inout item analogSignal : AnalogVoltageSignal;
    }

    port def DigitalDataPort {
        out item measurement : DigitalMeasurement;
    }

    port def PowerPort {
        in item power : Power;
    }

    port def DiagnosticPort {
        out item status : DigitalMeasurement;
    }

    part def PiezoelectricSensor {
        attribute sensingArea : Area = 25 [mm^2];
        attribute stiffness : Real = 8.0e7;
        attribute capacitance : Capacitance = 1.2 [nF];
        attribute chargeSensitivity : Sensitivity = 22 [pC/N];
        attribute maxForce : Force = 500 [N];
        attribute minDetectableForce : Force = 0.05 [N];
        attribute operatingTemperatureMin : Temperature = -20 [degC];
        attribute operatingTemperatureMax : Temperature = 85 [degC];

        port mechanicalIn : MechanicalInputPort;
        port chargeOut : ChargeSignalPort;

        action generateCharge {
            in item inputStimulus : MechanicalStimulus;
            out item generatedSignal : PiezoelectricChargeSignal;

            attribute computedCharge : ElectricCharge;
            attribute computedLeakage : ElectricCurrent;

            first start;
            then computeCharge;

            action computeCharge {
                computedCharge = inputStimulus.appliedForce * chargeSensitivity;
                computedLeakage = computedCharge / 1000 [s];
            }

            then emitSignal;

            action emitSignal {
                generatedSignal.charge = computedCharge;
                generatedSignal.leakageCurrent = computedLeakage;
                generatedSignal.sourceCapacitance = capacitance;
            }

            then done;
        }

        state sensorOperating {
            entry action initializeCrystal;
            state idle;
            state stressed;
            state saturated;
            state faulted;

            transition first idle;
            transition idle_to_stressed
                first idle
                accept MechanicalStimulus
                if stimulus.appliedForce >= minDetectableForce and stimulus.appliedForce <= maxForce
                then stressed;

            transition stressed_to_idle
                first stressed
                accept MechanicalStimulus
                if stimulus.appliedForce < minDetectableForce
                then idle;

            transition stressed_to_saturated
                first stressed
                accept MechanicalStimulus
                if stimulus.appliedForce > maxForce
                then saturated;

            transition saturated_to_faulted
                first saturated
                accept MechanicalStimulus
                if stimulus.appliedForce > 1.25 * maxForce
                then faulted;

            transition saturated_to_idle
                first saturated
                accept MechanicalStimulus
                if stimulus.appliedForce <= maxForce
                then idle;
        }
    }

    part def ChargeAmplifier {
        attribute feedbackCapacitance : Capacitance = 4.7 [nF];
        attribute feedbackResistance : Resistance = 100 [Mohm];
        attribute inputBiasCurrent : ElectricCurrent = 2 [pA];
        attribute outputVoltageLimit : ElectricPotential = 3.0 [V];

        port chargeIn : ChargeSignalPort;
        port analogOut : AnalogSignalPort;
        port powerIn : PowerPort;

        action convertChargeToVoltage {
            in item chargeInput : PiezoelectricChargeSignal;
            out item voltageOutput : AnalogVoltageSignal;

            attribute idealVoltage : ElectricPotential;
            attribute limitedVoltage : ElectricPotential;

            first start;
            then computeVoltage;

            action computeVoltage {
                idealVoltage = chargeInput.charge / feedbackCapacitance;
            }

            then limitOutput;

            action limitOutput {
                if idealVoltage > outputVoltageLimit then {
                    limitedVoltage = outputVoltageLimit;
                } else if idealVoltage < -outputVoltageLimit then {
                    limitedVoltage = -outputVoltageLimit;
                } else {
                    limitedVoltage = idealVoltage;
                }
            }

            then emitVoltage;

            action emitVoltage {
                voltageOutput.voltage = limitedVoltage;
                voltageOutput.frequency = 0 [Hz];
                voltageOutput.noiseRms = 0.8 [mV];
            }

            then done;
        }
    }

    part def AntiAliasFilter {
        attribute cutoffFrequency : Frequency = 1000 [Hz];
        attribute attenuationAtNyquist : SignalToNoiseRatio = 48 [dB];
        attribute passbandRipple : Real = 0.5;

        port analogIn : AnalogSignalPort;
        port analogOut : AnalogSignalPort;

        action filterSignal {
            in item rawSignal : AnalogVoltageSignal;
            out item filteredSignal : AnalogVoltageSignal;

            first start;
            then applyLowPass;

            action applyLowPass {
                filteredSignal.voltage = rawSignal.voltage;
                filteredSignal.frequency = rawSignal.frequency;
                filteredSignal.noiseRms = rawSignal.noiseRms * 0.45;
            }

            then done;
        }
    }

    part def AnalogToDigitalConverter {
        attribute resolution : DigitalCount = 4096 [count];
        attribute referenceVoltage : ElectricPotential = 3.3 [V];
        attribute samplingFrequency : Frequency = 4000 [Hz];
        attribute conversionTime : TimeDuration = 8 [us];

        port analogIn : AnalogSignalPort;
        port digitalOut : DigitalDataPort;
        port powerIn : PowerPort;

        action sampleAndConvert {
            in item signal : AnalogVoltageSignal;
            out item sample : DigitalMeasurement;

            attribute normalized : Real;
            attribute countValue : DigitalCount;

            first start;
            then sampleInput;

            action sampleInput {
                normalized = (signal.voltage + referenceVoltage / 2) / referenceVoltage;
                countValue = normalized * resolution;
            }

            then emitSample;

            action emitSample {
                sample.sampleCount = countValue;
                sample.sampleTime = 1 [s] / samplingFrequency;
                sample.validity = countValue >= 0 [count] and countValue <= resolution;
            }

            then done;
        }
    }

    part def MeasurementProcessor {
        attribute calibrationGain : Real = 1.000;
        attribute calibrationOffset : Force = 0.0 [N];
        attribute pressureArea : Area = 25 [mm^2];
        attribute overloadThreshold : Force = 500 [N];
        attribute zeroForceThreshold : Force = 0.05 [N];

        port digitalIn : DigitalDataPort;
        port measurementOut : DigitalDataPort;
        port diagnosticOut : DiagnosticPort;

        action calculateMeasurement {
            in item adcSample : DigitalMeasurement;
            out item measurement : DigitalMeasurement;

            attribute reconstructedVoltage : ElectricPotential;
            attribute reconstructedCharge : ElectricCharge;
            attribute reconstructedForce : Force;

            first start;
            then reconstruct;

            action reconstruct {
                reconstructedVoltage = ((adcSample.sampleCount / 4096 [count]) * 3.3 [V]) - 1.65 [V];
                reconstructedCharge = reconstructedVoltage * 4.7 [nF];
                reconstructedForce = (reconstructedCharge / 22 [pC/N]) * calibrationGain + calibrationOffset;
            }

            then publish;

            action publish {
                measurement.sampleCount = adcSample.sampleCount;
                measurement.measuredForce = reconstructedForce;
                measurement.measuredPressure = reconstructedForce / pressureArea;
                measurement.sampleTime = adcSample.sampleTime;
                measurement.validity = adcSample.validity and reconstructedForce <= overloadThreshold;
            }

            then done;
        }

        state measurementStateMachine {
            state boot;
            state selfTest;
            state measuring;
            state overload;
            state degraded;
            state failed;

            transition first boot;
            transition boot_to_selfTest
                first boot
                then selfTest;

            transition selfTest_to_measuring
                first selfTest
                if calibrationGain > 0.95 and calibrationGain < 1.05
                then measuring;

            transition selfTest_to_failed
                first selfTest
                if calibrationGain <= 0.95 or calibrationGain >= 1.05
                then failed;

            transition measuring_to_overload
                first measuring
                accept DigitalMeasurement
                if measurement.measuredForce > overloadThreshold
                then overload;

            transition overload_to_measuring
                first overload
                accept DigitalMeasurement
                if measurement.measuredForce <= overloadThreshold
                then measuring;

            transition measuring_to_degraded
                first measuring
                accept DigitalMeasurement
                if measurement.validity == false
                then degraded;

            transition degraded_to_failed
                first degraded
                accept DigitalMeasurement
                if measurement.validity == false
                then failed;

            transition degraded_to_measuring
                first degraded
                accept DigitalMeasurement
                if measurement.validity == true
                then measuring;
        }
    }

    part def PowerConditioner {
        attribute inputVoltageMin : ElectricPotential = 4.5 [V];
        attribute inputVoltageMax : ElectricPotential = 5.5 [V];
        attribute regulatedVoltage : ElectricPotential = 3.3 [V];
        attribute quiescentCurrent : ElectricCurrent = 4 [mA];

        port externalPowerIn : PowerPort;
        port regulatedPowerOut : PowerPort;

        action regulatePower {
            in item externalPower : Power;
            out item regulatedPower : Power;

            first start;
            then regulate;

            action regulate {
                regulatedPower.supplyVoltage = regulatedVoltage;
                regulatedPower.supplyCurrent = externalPower.supplyCurrent + quiescentCurrent;
            }

            then done;
        }
    }

    part def PiezoelectricSensingUnit {
        attribute measurementRangeMin : Force = 0.05 [N];
        attribute measurementRangeMax : Force = 500 [N];
        attribute pressureRangeMax : Pressure = 20 [MPa];
        attribute bandwidth : Frequency = 1000 [Hz];
        attribute updatePeriod : TimeDuration = 0.25 [ms];

        port stimulusIn : MechanicalInputPort;
        port powerIn : PowerPort;
        port measurementOut : DigitalDataPort;
        port diagnosticOut : DiagnosticPort;

        part sensor : PiezoelectricSensor;
        part chargeAmplifier : ChargeAmplifier;
        part antiAliasFilter : AntiAliasFilter;
        part adc : AnalogToDigitalConverter;
        part processor : MeasurementProcessor;
        part powerConditioner : PowerConditioner;

        connect stimulusIn to sensor.mechanicalIn;
        connect sensor.chargeOut to chargeAmplifier.chargeIn;
        connect chargeAmplifier.analogOut to antiAliasFilter.analogIn;
        connect antiAliasFilter.analogOut to adc.analogIn;
        connect adc.digitalOut to processor.digitalIn;
        connect processor.measurementOut to measurementOut;
        connect processor.diagnosticOut to diagnosticOut;
        connect powerIn to powerConditioner.externalPowerIn;
        connect powerConditioner.regulatedPowerOut to chargeAmplifier.powerIn;
        connect powerConditioner.regulatedPowerOut to adc.powerIn;

        action performMeasurementCycle {
            in item appliedStimulus : MechanicalStimulus;
            out item finalMeasurement : DigitalMeasurement;

            item chargeSignal : PiezoelectricChargeSignal;
            item amplifiedSignal : AnalogVoltageSignal;
            item filteredSignal : AnalogVoltageSignal;
            item adcSample : DigitalMeasurement;

            first start;
            then sense;

            action sense {
                sensor.generateCharge(appliedStimulus, chargeSignal);
            }

            then amplify;

            action amplify {
                chargeAmplifier.convertChargeToVoltage(chargeSignal, amplifiedSignal);
            }

            then filter;

            action filter {
                antiAliasFilter.filterSignal(amplifiedSignal, filteredSignal);
            }

            then convert;

            action convert {
                adc.sampleAndConvert(filteredSignal, adcSample);
            }

            then compute;

            action compute {
                processor.calculateMeasurement(adcSample, finalMeasurement);
            }

            then done;
        }
    }

    requirement def PiezoelectricSensingRequirement {
        subject sensingUnit : PiezoelectricSensingUnit;

        require constraint {
            sensingUnit.measurementRangeMin <= 0.05 [N]
        }

        require constraint {
            sensingUnit.measurementRangeMax >= 500 [N]
        }

        require constraint {
            sensingUnit.bandwidth >= 1000 [Hz]
        }

        require constraint {
            sensingUnit.updatePeriod <= 0.25 [ms]
        }

        require constraint {
            sensingUnit.sensor.chargeSensitivity >= 20 [pC/N]
        }

        require constraint {
            sensingUnit.chargeAmplifier.outputVoltageLimit >= 3.0 [V]
        }

        doc /* The sensing unit shall measure mechanical force and derived pressure using a piezoelectric sensor as the primary transduction element. */
    }

    requirement def SignalConditioningRequirement {
        subject sensingUnit : PiezoelectricSensingUnit;

        require constraint {
            sensingUnit.antiAliasFilter.cutoffFrequency <= sensingUnit.adc.samplingFrequency / 2
        }

        require constraint {
            sensingUnit.antiAliasFilter.attenuationAtNyquist >= 40 [dB]
        }

        require constraint {
            sensingUnit.adc.resolution >= 4096 [count]
        }

        doc /* The charge signal generated by the piezoelectric element shall be converted, filtered, and digitized before measurement reporting. */
    }

    requirement def SafetyAndValidityRequirement {
        subject sensingUnit : PiezoelectricSensingUnit;

        require constraint {
            sensingUnit.processor.overloadThreshold <= sensingUnit.measurementRangeMax
        }

        require constraint {
            sensingUnit.sensor.maxForce >= sensingUnit.measurementRangeMax
        }

        require constraint {
            sensingUnit.sensor.operatingTemperatureMin <= -20 [degC]
        }

        require constraint {
            sensingUnit.sensor.operatingTemperatureMax >= 85 [degC]
        }

        doc /* The sensing unit shall detect invalid samples, overload conditions, and sensor operating limits. */
    }

    satisfy PiezoelectricSensingRequirement by PiezoelectricSensingUnit;
    satisfy SignalConditioningRequirement by PiezoelectricSensingUnit;
    satisfy SafetyAndValidityRequirement by PiezoelectricSensingUnit;

    part sensingUnit : PiezoelectricSensingUnit {
        attribute measurementRangeMin = 0.05 [N];
        attribute measurementRangeMax = 500 [N];
        attribute pressureRangeMax = 20 [MPa];
        attribute bandwidth = 1000 [Hz];
        attribute updatePeriod = 0.25 [ms];
    }

    item nominalStimulus : MechanicalStimulus {
        attribute appliedForce = 125 [N];
        attribute contactPressure = 5 [MPa];
        attribute stimulusFrequency = 50 [Hz];
        attribute duration = 1 [s];
    }

    item nominalPower : Power {
        attribute supplyVoltage = 5 [V];
        attribute supplyCurrent = 30 [mA];
    }
}