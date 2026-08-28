package IndustrialPressureTransducerSystem {
    private import ScalarValues::*;
    private import ISQ::*;

    attribute def PressureSignal :> Real;
    attribute def RawElectricalSignal :> Real;
    attribute def ConditionedVoltage :> Real;
    attribute def Power24VDC :> Real;
    attribute def StartCmd;
    attribute def PowerOffCmd;

    attribute def ResponseTime_ms :> Real;
    attribute def EfficiencyPercent :> Real;
    attribute def TemperatureC :> Real;

    part def SensingElement {
        attribute responseTime : ResponseTime_ms := 0.5;
        in power : Power24VDC;
        out pressureChange : PressureSignal;
    }

    part def ConversionElement {
        in power : Power24VDC;
        in pressureChange : PressureSignal;
        out rawSignal : RawElectricalSignal;
    }

    part def SignalProcessor {
        in power : Power24VDC;
        in rawSignal : RawElectricalSignal;
        out voltageOutput : ConditionedVoltage;
        attribute gain : Real := 100.0;
        attribute bandwidth : Real := 10000.0;
    }

    part def PowerSupply {
        out power : Power24VDC;
        attribute outputVoltage : Real := 24.0;
        attribute regulation : Real := 0.02;
    }

    state def TransducerStates;

    action def SensePressure;
    action def ConvertToSignal;
    action def ProcessSignal;
    action def TransmitVoltage;
    action def InitializeComponents;
    action def SelfCalibrate;

    requirement def ResponseTimeRequirement {
        doc /* The sensing element shall respond to pressure changes within 1 millisecond. */
        subject sensingElement : SensingElement;
        attribute maxResponseTime : ResponseTime_ms := 1.0;
        constraint { sensingElement.responseTime < maxResponseTime }
    }

    requirement def TemperatureRangeRequirement {
        doc /* The system shall function across a temperature range from -40°C to +125°C. */
        subject transducer : PressureTransducer;
        attribute minTemp : TemperatureC := -40.0;
        attribute maxTemp : TemperatureC := 125.0;
        constraint { transducer.operatingTemp >= minTemp and transducer.operatingTemp <= maxTemp }
    }

    requirement def EfficiencyRequirement {
        doc /* The system shall operate with an efficiency exceeding 88%. */
        subject transducer : PressureTransducer;
        attribute minEfficiency : EfficiencyPercent := 88.0;
        constraint { transducer.efficiency > minEfficiency }
    }

    requirement def AccuracyRequirement {
        doc /* The system shall maintain measurement accuracy within ±0.5% of full scale. */
        subject transducer : PressureTransducer;
        attribute maxAccuracyError : Real := 0.5;
        constraint { transducer.accuracy <= maxAccuracyError }
    }

    part def PressureTransducer {
        attribute operatingTemp : TemperatureC;
        attribute efficiency : EfficiencyPercent;
        attribute accuracy : Real := 0.5;

        part sensingElement : SensingElement;
        part conversionElement : ConversionElement;
        part signalProcessor : SignalProcessor;
        part powerSupply : PowerSupply;

        connect powerSupply.power to sensingElement.power;
        connect powerSupply.power to conversionElement.power;
        connect powerSupply.power to signalProcessor.power;
        connect sensingElement.pressureChange to conversionElement.pressureChange;
        connect conversionElement.rawSignal to signalProcessor.rawSignal;

        exhibit state transducerStates : TransducerStates;

        satisfy ResponseTimeRequirement by sensingElement;
        satisfy TemperatureRangeRequirement by this;
        satisfy EfficiencyRequirement by this;
        satisfy AccuracyRequirement by this;
    }

    part transducer : PressureTransducer;

    action sensePressure : SensePressure;
    action convertToSignal : ConvertToSignal;
    action processSignal : ProcessSignal;
    action transmitVoltage : TransmitVoltage;
    action initializeComponents : InitializeComponents;
    action selfCalibrate : SelfCalibrate;

    state transducerStates : TransducerStates {
        entry; then off;
        state off;
        accept StartCmd
            then startup;
        state startup {
            entry initializeComponents;
        }
        then calibrating;
        state calibrating {
            entry selfCalibrate;
        }
        then operational;
        state operational {
            entry; then sensing;
            state sensing {
                entry sensePressure;
            }
            then converting;
            state converting {
                entry convertToSignal;
            }
            then processing;
            state processing {
                entry processSignal;
            }
            then transmitting;
            state transmitting {
                entry transmitVoltage;
            }
            then sensing;
        }
        accept PowerOffCmd
            then off;
    }
}
