package StrainMeasurementSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ---- Value Types with Units ----
    value def Resistance :> Real { unit 'ohm'; }
    value def Voltage :> Real { unit 'V'; }
    value def Strain :> Real { unit 'µε'; }
    value def Temperature :> Real { unit '°C'; }
    value def Frequency :> Real { unit 'Hz'; }
    value def DigitalCount :> Integer;
    value def Gain :> Real;
    value def Duration :> Real { unit 's'; }
    value def SampleRate :> Real { unit 'Hz'; }

    // ---- Item Definitions ----
    item def MechanicalLoad {
        attribute magnitude : Real;
    }

    item def AnalogSignal {
        attribute voltage : Voltage;
        attribute noiseFloor : Voltage;
    }

    item def DigitalSample {
        attribute count : DigitalCount;
        attribute timestamp : Duration;
    }

    item def StrainResult {
        attribute strain : Strain;
        attribute temperature : Temperature;
        attribute timestamp : Duration;
        attribute valid : Boolean;
    }

    // ---- Port Definitions ----
    port def MechanicalPort {
        in item load : MechanicalLoad;
    }

    port def AnalogOutPort {
        out item signal : AnalogSignal;
    }

    port def AnalogInPort {
        in item signal : AnalogSignal;
    }

    port def DigitalOutPort {
        out item sample : DigitalSample;
    }

    port def DigitalInPort {
        in item sample : DigitalSample;
    }

    port def ResultOutPort {
        out item result : StrainResult;
    }

    // ---- Component Part Definitions ----

    part def StrainGauge {
        attribute nominalResistance : Resistance = 350 [ohm];
        attribute gaugeFactor : Real = 2.0;
        attribute operatingTempRange : Temperature[2] = (-40, 85) ['°C'];

        port mechanicalIn : MechanicalPort;
        port electricalOut : AnalogOutPort;

        attribute currentResistance : Resistance;

        action def UpdateResistance {
            in load : MechanicalLoad;
            out resistance : Resistance;
        }

        perform UpdateResistance {
            // resistance change proportional to strain via gauge factor
        }
    }

    part def WheatstoneBridge {
        attribute bridgeSupplyVoltage : Voltage = 5.0 [V];
        attribute bridgeResistance : Resistance = 350 [ohm];
        attribute sensitivity : Real = 1.0;

        port analogIn : AnalogInPort;
        port analogOut : AnalogOutPort;

        action def ConvertResistanceToVoltage {
            in signal : AnalogSignal;
            out output : AnalogSignal;
        }

        perform ConvertResistanceToVoltage;
    }

    part def SignalConditioner {
        attribute amplifierGain : Gain = 1000.0;
        attribute lowCutoffFreq : Frequency = 0.5 [Hz];
        attribute highCutoffFreq : Frequency = 10000 [Hz];

        port analogIn : AnalogInPort;
        port analogOut : AnalogOutPort;

        action def AmplifyAndFilter {
            in signal : AnalogSignal;
            out output : AnalogSignal;
        }

        perform AmplifyAndFilter;
    }

    part def AnalogToDigitalConverter {
        attribute resolutionBits : Integer = 24;
        attribute sampleRate : SampleRate = 1000 [Hz];
        attribute inputRange : Voltage[2] = (-5.0, 5.0) ['V'];

        port analogIn : AnalogInPort;
        port digitalOut : DigitalOutPort;

        action def ConvertAnalogToDigital {
            in signal : AnalogSignal;
            out sample : DigitalSample;
        }

        perform ConvertAnalogToDigital;
    }

    part def DataProcessor {
        attribute calibrationFactor : Real = 1.0;
        attribute temperatureCoefficient : Real = 0.01;
        attribute referenceTemperature : Temperature = 25 [°C];
        attribute zeroOffset : DigitalCount = 0;

        port digitalIn : DigitalInPort;
        port resultOut : ResultOutPort;

        action def ProcessSample {
            in sample : DigitalSample;
            in temperature : Temperature;
            out result : StrainResult;
        }

        action def ApplyCalibration {
            in sample : DigitalSample;
            out calibrated : DigitalCount;
        }

        action def TemperatureCompensate {
            in calibrated : DigitalCount;
            in temperature : Temperature;
            out compensated : DigitalCount;
        }

        action def ComputeStrain {
            in compensated : DigitalCount;
            out strain : Strain;
        }

        perform ProcessSample {
            then ApplyCalibration;
            then TemperatureCompensate;
            then ComputeStrain;
        }
    }

    // ---- System Assembly ----
    part def StrainMeasurementSystem {

        port mechanicalInput : MechanicalPort;
        port dataOutput : ResultOutPort;
        port temperatureInput : ~port {
            in item temp : Temperature;
        }

        part gauge : StrainGauge {
            port mechanicalIn : MechanicalPort;
            port electricalOut : AnalogOutPort;
        }

        part bridge : WheatstoneBridge {
            port analogIn : AnalogInPort;
            port analogOut : AnalogOutPort;
        }

        part conditioner : SignalConditioner {
            port analogIn : AnalogInPort;
            port analogOut : AnalogOutPort;
        }

        part adc : AnalogToDigitalConverter {
            port analogIn : AnalogInPort;
            port digitalOut : DigitalOutPort;
        }

        part processor : DataProcessor {
            port digitalIn : DigitalInPort;
            port resultOut : ResultOutPort;
        }

        connection mechanicalConn connect mechanicalInput to gauge.mechanicalIn;
        connection bridgeConn connect gauge.electricalOut to bridge.analogIn;
        connection conditionConn connect bridge.analogOut to conditioner.analogIn;
        connection adcConn connect conditioner.analogOut to adc.analogIn;
        connection digitalConn connect adc.digitalOut to processor.digitalIn;
        connection outputConn connect processor.resultOut to dataOutput;

        // ---- State Machine ----
        state def SystemStates {
            entry; then Idle;

            state Idle {
                entry { /* system powered, not measuring */ }
                transition Idle_to_Calibration
                    first Idle
                    if (calibrationCommand)
                    then Calibration;
            }

            state Calibration {
                entry { /* set zero-point reference */ }
                do { processor.zeroOffset = adc.digitalOut.sample.count; }
                transition Calibration_to_Active
                    first Calibration
                    if (calibrationComplete)
                    then Active;
                transition Calibration_to_Idle
                    first Calibration
                    if (abortCommand)
                    then Idle;
            }

            state Active {
                entry { /* begin continuous measurement */ }
                do { send StrainResult to dataOutput; }
                transition Active_to_Idle
                    first Active
                    if (stopCommand)
                    then Idle;
            }
        }

        attribute calibrationCommand : Boolean;
        attribute calibrationComplete : Boolean;
        attribute abortCommand : Boolean;
        attribute stopCommand : Boolean;

        exhibit SystemStates;
    }

    // ---- Requirements ----
    requirement def AccuracyRequirement {
        attribute maxError : Strain = 1 [µε];
        subject :> StrainMeasurementSystem;
        require { |measuredStrain - trueStrain| <= maxError }
    }

    requirement def SamplingSpeedRequirement {
        attribute minSampleRate : SampleRate = 1000 [Hz];
        subject :> StrainMeasurementSystem;
        require { adc.sampleRate >= minSampleRate }
    }

    requirement def TemperatureStabilityRequirement {
        attribute operatingRange : Temperature[2] = (-40, 85) ['°C'];
        attribute maxDrift : Strain = 2 [µε];
        subject :> StrainMeasurementSystem;
        require { for all t in operatingRange { |drift(t)| <= maxDrift } }
    }

    requirement def StabilityRequirement {
        attribute longTermDrift : Strain = 5 [µε];
        attribute duration : Duration = 86400 [s];
        subject :> StrainMeasurementSystem;
        require { driftOverDuration <= longTermDrift }
    }

    requirement def SystemPerformanceRequirements {
        requirement accuracy : AccuracyRequirement;
        requirement speed : SamplingSpeedRequirement;
        requirement tempStability : TemperatureStabilityRequirement;
        requirement longStability : StabilityRequirement;
    }

    requirement systemMeetsPerformance : SystemPerformanceRequirements {
        subject : StrainMeasurementSystem;
    }

}
