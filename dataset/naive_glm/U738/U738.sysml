package LightToDigitalSensor {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types =====
    value type Illuminance > Real { unit "lx"; }
    value type Photocurrent > Real { unit "A"; }
    value type Voltage > Real { unit "V"; }
    value type DigitalCount > Integer;
    value type CalibratedReading > Real { unit "lx"; }
    value type Temperature > Real { unit "degC"; }
    value type SupplyVoltage > Real { unit "V"; }
    value type Power > Real { unit "W"; }
    value type Frequency > Real { unit "Hz"; }
    value type Time > Real { unit "s"; }
    value type Resistance > Real { unit "ohm"; }
    value type Capacitance > Real { unit "F"; }
    value type Gain > Real;

    // ===== Item Types =====
    item def LightFlux {
        attribute illuminance : Illuminance;
    }

    item def AnalogSignal {
        attribute voltage : Voltage;
    }

    item def CurrentSignal {
        attribute current : Photocurrent;
    }

    item def RawDigitalSample {
        attribute count : DigitalCount;
        attribute timestamp : Time;
    }

    item def CalibratedMeasurement {
        attribute reading : CalibratedReading;
        attribute timestamp : Time;
        attribute valid : Boolean;
    }

    item def ElectricalPower {
        attribute voltage : SupplyVoltage;
        attribute power : Power;
    }

    // ===== Port Definitions =====
    port def LightInputPort {
        attribute illuminance : Illuminance;
        in item light : LightFlux;
    }

    port def CurrentOutputPort {
        out item currentSignal : CurrentSignal;
    }

    port def VoltageOutputPort {
        out item signal : AnalogSignal;
    }

    port def VoltageInputPort {
        in item signal : AnalogSignal;
    }

    port def DigitalOutputPort {
        out item sample : RawDigitalSample;
    }

    port def DigitalInputPort {
        in item sample : RawDigitalSample;
    }

    port def MeasurementOutputPort {
        out item measurement : CalibratedMeasurement;
    }

    port def HostInterfacePort {
        in item measurement : CalibratedMeasurement;
    }

    port def PowerInputPort {
        in item power : ElectricalPower;
    }

    port def PowerOutputPort {
        out item power : ElectricalPower;
    }

    // ===== Part Definitions =====

    part def LEDPhotodetector {
        attribute wavelength : Real { unit "nm"; }
        attribute activeArea : Real { unit "m^2"; }
        attribute responsivity : Real { unit "A/lx"; }

        port lightIn : LightInputPort;
        port currentOut : CurrentOutputPort;

        action def GeneratePhotocurrent {
            in light : LightFlux;
            out current : CurrentSignal;
        }

        perform GeneratePhotocurrent {
            in light = lightIn.light;
            out current = currentOut.currentSignal;
        }
    }

    part def TransimpedanceAmplifier {
        attribute feedbackResistance : Resistance;
        attribute bandwidth : Frequency;
        attribute offsetVoltage : Voltage;

        port currentIn : CurrentOutputPort;
        port voltageOut : VoltageOutputPort;

        action def ConvertCurrentToVoltage {
            in current : CurrentSignal;
            out voltage : AnalogSignal;
        }

        perform ConvertCurrentToVoltage {
            in current = currentIn.currentSignal;
            out voltage = voltageOut.signal;
        }
    }

    part def InstrumentationAmplifier {
        attribute gain : Gain;
        attribute commonModeRejection : Real { unit "dB"; }
        attribute bandwidth : Frequency;

        port voltageIn : VoltageInputPort;
        port voltageOut : VoltageOutputPort;

        action def AmplifyVoltage {
            in inputSignal : AnalogSignal;
            out outputSignal : AnalogSignal;
        }

        perform AmplifyVoltage {
            in inputSignal = voltageIn.signal;
            out outputSignal = voltageOut.signal;
        }
    }

    part def LowPassFilter {
        attribute cutoffFrequency : Frequency;
        attribute order : Integer;
        attribute capacitance : Capacitance;
        attribute resistance : Resistance;

        port voltageIn : VoltageInputPort;
        port voltageOut : VoltageOutputPort;

        action def FilterNoise {
            in inputSignal : AnalogSignal;
            out outputSignal : AnalogSignal;
        }

        perform FilterNoise {
            in inputSignal = voltageIn.signal;
            out outputSignal = voltageOut.signal;
        }
    }

    part def AnalogToDigitalConverter {
        attribute resolutionBits : Integer;
        attribute samplingRate : Frequency;
        attribute referenceVoltage : Voltage;
        attribute inputRange : Voltage;

        port voltageIn : VoltageInputPort;
        port digitalOut : DigitalOutputPort;

        action def SampleAndConvert {
            in analogSignal : AnalogSignal;
            out digitalSample : RawDigitalSample;
        }

        perform SampleAndConvert {
            in analogSignal = voltageIn.signal;
            out digitalSample = digitalOut.sample;
        }
    }

    part def SignalProcessor {
        attribute clockFrequency : Frequency;
        attribute calibrationCoefficients : Array(Real);
        attribute filterTaps : Integer;

        port digitalIn : DigitalInputPort;
        port measurementOut : MeasurementOutputPort;

        action def ProcessDigitalData {
            in rawSample : RawDigitalSample;
            out measurement : CalibratedMeasurement;
        }

        perform ProcessDigitalData {
            in rawSample = digitalIn.sample;
            out measurement = measurementOut.measurement;
        }
    }

    part def PowerDistributionUnit {
        attribute inputVoltageRange : SupplyVoltage;
        attribute efficiency : Real;
        attribute outputVoltage : SupplyVoltage;

        port powerIn : PowerInputPort;
        port powerToLED : PowerOutputPort;
        port powerToTIA : PowerOutputPort;
        port powerToInAmp : PowerOutputPort;
        port powerToFilter : PowerOutputPort;
        port powerToADC : PowerOutputPort;
        port powerToDSP : PowerOutputPort;

        action def DistributePower {
            in inputPower : ElectricalPower;
            out ledPower : ElectricalPower;
            out tiaPower : ElectricalPower;
            out inAmpPower : ElectricalPower;
            out filterPower : ElectricalPower;
            out adcPower : ElectricalPower;
            out dspPower : ElectricalPower;
        }

        perform DistributePower {
            in inputPower = powerIn.power;
            out ledPower = powerToLED.power;
            out tiaPower = powerToTIA.power;
            out inAmpPower = powerToInAmp.power;
            out filterPower = powerToFilter.power;
            out adcPower = powerToADC.power;
            out dspPower = powerToDSP.power;
        }
    }

    // ===== System-Level Part =====
    part def LightToDigitalSensorSystem {
        attribute manufacturer : String;
        attribute modelNumber : String;
        attribute operatingTemperatureMin : Temperature = -40 [degC];
        attribute operatingTemperatureMax : Temperature = 85 [degC];
        attribute supplyVoltageMin : SupplyVoltage = 3.0 [V];
        attribute supplyVoltageMax : SupplyVoltage = 5.5 [V];

        port externalLightInput : LightInputPort;
        port hostInterface : HostInterfacePort;
        port externalPowerInput : PowerInputPort;

        part ledPhotodetector : LEDPhotodetector {
            attribute wavelength = 550 [Real, "nm"];
            attribute responsivity = 2.5e-9 [Real, "A/lx"];
        }

        part transimpedanceAmplifier : TransimpedanceAmplifier {
            attribute feedbackResistance = 1.0e6 [Resistance];
            attribute bandwidth = 10000 [Frequency];
        }

        part instrumentationAmplifier : InstrumentationAmplifier {
            attribute gain = 100.0 [Gain];
            attribute commonModeRejection = 90 [Real, "dB"];
        }

        part lowPassFilter : LowPassFilter {
            attribute cutoffFrequency = 1000 [Frequency];
            attribute order = 4;
        }

        part adc : AnalogToDigitalConverter {
            attribute resolutionBits = 16;
            attribute samplingRate = 1000 [Frequency];
            attribute referenceVoltage = 3.3 [Voltage];
        }

        part signalProcessor : SignalProcessor {
            attribute clockFrequency = 16e6 [Frequency];
            attribute filterTaps = 32;
        }

        part powerDistribution : PowerDistributionUnit {
            attribute inputVoltageRange = (3.0, 5.5) [SupplyVoltage];
            attribute outputVoltage = 3.3 [SupplyVoltage];
            attribute efficiency = 0.90;
        }

        // Internal connections
        connection ledToTIA connect ledPhotodetector.currentOut to transimpedanceAmplifier.currentIn;
        connection tiaToInAmp connect transimpedanceAmplifier.voltageOut to instrumentationAmplifier.voltageIn;
        connection inAmpToFilter connect instrumentationAmplifier.voltageOut to lowPassFilter.voltageIn;
        connection filterToADC connect lowPassFilter.voltageOut to adc.voltageIn;
        connection adcToDSP connect adc.digitalOut to signalProcessor.digitalIn;

        // External light input to LED
        connection lightPath connect externalLightInput to ledPhotodetector.lightIn;

        // DSP output to host interface
        connection dspToHost connect signalProcessor.measurementOut to hostInterface;

        // Power distribution
        connection powerInput connect externalPowerInput to powerDistribution.powerIn;
        connection powerToLED connect powerDistribution.powerToLED to ledPhotodetector.powerIn;
        connection powerToTIA connect powerDistribution.powerToTIA to transimpedanceAmplifier.powerIn;
        connection powerToInAmp connect powerDistribution.powerToInAmp to instrumentationAmplifier.powerIn;
        connection powerToFilter connect powerDistribution.powerToFilter to lowPassFilter.powerIn;
        connection powerToADC connect powerDistribution.powerToADC to adc.powerIn;
        connection powerToDSP connect powerDistribution.powerToDSP to signalProcessor.powerIn;

        // ===== State Machine =====
        state def SensorStates {
            entry action;
            exit action;
        }

        state def StandbyMode :> SensorStates {
            entry action {
                // Disable active sensing components, maintain minimal power
            }
        }

        state def ActiveSensingMode :> SensorStates {
            entry action {
                // Enable LED, amplifiers, filter, ADC, and DSP
            }
        }

        state def DataTransmissionMode :> SensorStates {
            entry action {
                // Transmit calibrated measurement to host
            }
        }

        state def FaultState :> SensorStates {
            entry action {
                // Log fault, disable outputs, assert error flag
            }
        }

        state machine SensorStateMachine {
            state standby : StandbyMode;
            state activeSensing : ActiveSensingMode;
            state dataTransmission : DataTransmissionMode;
            state fault : FaultState;

            transition standby_to_active
                from standby to activeSensing
                when (externalLightInput.illuminance > 0 [Illuminance]);

            transition active_to_transmit
                from activeSensing to dataTransmission
                when (signalProcessor.measurementOut.measurement.valid == true);

            transition transmit_to_active
                from dataTransmission to activeSensing
                when (hostInterface.measurement.received == true);

            transition active_to_standby
                from activeSensing to standby
                when (externalLightInput.illuminance == 0 [Illuminance]);

            transition any_to_fault
                from standby to fault
                when (powerDistribution.powerIn.power.voltage < supplyVoltageMin);

            transition active_to_fault
                from activeSensing to fault
                when (adc.voltageIn.signal.voltage > adc.inputRange);

            transition transmit_to_fault
                from dataTransmission to fault
                when (signalProcessor.measurementOut.measurement.valid == false);

            transition fault_to_standby
                from fault to standby
                when (powerDistribution.powerIn.power.voltage >= supplyVoltageMin
                      and powerDistribution.powerIn.power.voltage <= supplyVoltageMax);
        }

        exhibit state machine SensorStateMachine;

        // ===== Requirements =====
        requirement def MeasurementAccuracyRequirement {
            attribute maxErrorPercent : Real = 2.0;
            subject sensor : LightToDigitalSensorSystem;
            require {
                sensor.signalProcessor.measurementOut.measurement.reading
                    within +/- (maxErrorPercent / 100.0) * sensor.externalLightInput.illuminance
            }
        }

        requirement def MeasurementRangeRequirement {
            attribute minIlluminance : Illuminance = 0.1 [Illuminance];
            attribute maxIlluminance : Illuminance = 100000 [Illuminance];
            subject sensor : LightToDigitalSensorSystem;
            require {
                sensor.externalLightInput.illuminance >= minIlluminance
                and sensor.externalLightInput.illuminance <= maxIlluminance
            }
        }

        requirement def ResponseTimeRequirement {
            attribute maxResponseTime : Time = 0.01 [Time];
            subject sensor : LightToDigitalSensorSystem;
            require {
                // Time from light input change to valid measurement output
                // must not exceed maxResponseTime
            }
        }

        requirement def OperatingTemperatureRequirement {
            attribute minTemp : Temperature = -40 [Temperature];
            attribute maxTemp : Temperature = 85 [Temperature];
            subject sensor : LightToDigitalSensorSystem;
            require {
                sensor.operatingTemperatureMin >= minTemp
                and sensor.operatingTemperatureMax <= maxTemp
            }
        }

        requirement def SupplyVoltageRequirement {
            attribute minVoltage : SupplyVoltage = 3.0 [SupplyVoltage];
            attribute maxVoltage : SupplyVoltage = 5.5 [SupplyVoltage];
            subject sensor : LightToDigitalSensorSystem;
            require {
                sensor.supplyVoltageMin >= minVoltage
                and sensor.supplyVoltageMax <= maxVoltage
            }
        }

        requirement def PowerConsumptionRequirement {
            attribute maxPower : Power = 0.5 [Power];
            subject sensor : LightToDigitalSensorSystem;
            require {
                sensor.powerDistribution.powerIn.power.power <= maxPower
            }
        }

        // Satisfy requirements
        satisfy MeasurementAccuracyRequirement by signalProcessor;
        satisfy MeasurementRangeRequirement by ledPhotodetector;
        satisfy ResponseTimeRequirement by adc;
        satisfy OperatingTemperatureRequirement by LightToDigitalSensorSystem;
        satisfy SupplyVoltageRequirement by powerDistribution;
        satisfy PowerConsumptionRequirement by powerDistribution;
    }
}
