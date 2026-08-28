package 'Precision Force Measurement System' {
    private import ScalarValues::*;

    attribute def ForceValue :> Real;
    attribute def VoltageValue :> Real;
    attribute def TemperatureValue :> Real;
    attribute def ResistanceValue :> Real;
    attribute def FrequencyValue :> Real;
    attribute def DigitalValue :> Integer;

    item def AppliedForce;
    item def AnalogSignal;
    item def DigitalData;
    item def MeasuredForce;

    port def ForceInputPort {
        in item force : AppliedForce;
    }
    port def AnalogOutputPort {
        out item signal : AnalogSignal;
    }
    port def AnalogInputPort {
        in item signal : AnalogSignal;
    }
    port def DigitalOutputPort {
        out item data : DigitalData;
    }
    port def DigitalInputPort {
        in item data : DigitalData;
    }
    port def ForceOutputPort {
        out item force : MeasuredForce;
    }
    port def ForceDisplayInputPort {
        in item force : MeasuredForce;
    }

    action def ConvertForceToVoltage {
        in item force : AppliedForce;
        out item signal : AnalogSignal;
    }
    action def AmplifySignal {
        in item signalIn : AnalogSignal;
        out item signalOut : AnalogSignal;
    }
    action def DigitizeSignal {
        in item signal : AnalogSignal;
        out item data : DigitalData;
    }
    action def CalculateForce {
        in item data : DigitalData;
        out item force : MeasuredForce;
    }
    action def DisplayForce {
        in item force : MeasuredForce;
    }

    part def StrainGauge {
        attribute nominalResistance : ResistanceValue := 350.0;
        attribute currentResistance : ResistanceValue;
    }

    part def WheatstoneBridge {
        attribute excitationVoltage : VoltageValue := 5.0;
        attribute bridgeOutput : VoltageValue;
        part gauges : StrainGauge[4];
    }

    part def SignalAmplifier {
        attribute gain : Real := 1000.0;
    }

    part def LoadCell {
        port forceIn : ForceInputPort;
        port analogOut : AnalogOutputPort;
        attribute maxCapacity : ForceValue := 5000.0;

        part strainGauges : StrainGauge[4];
        part wheatstoneBridge : WheatstoneBridge;
        part signalAmplifier : SignalAmplifier;

        action convert : ConvertForceToVoltage;
        action amplify : AmplifySignal;

        flow forceIn.force to convert.force;
        flow convert.signal to amplify.signalIn;
        flow amplify.signalOut to analogOut.signal;
    }

    part def ADC {
        attribute resolution : Integer := 24;
        attribute sampleRate : FrequencyValue := 1000.0;
    }

    part def DataAcquisitionUnit {
        port analogIn : AnalogInputPort;
        port digitalOut : DigitalOutputPort;

        part adc : ADC;

        action digitize : DigitizeSignal;

        flow analogIn.signal to digitize.signal;
        flow digitize.data to digitalOut.data;
    }

    part def Microcontroller {
        port digitalIn : DigitalInputPort;
        port forceOut : ForceOutputPort;

        attribute calibrationConstant : Real;

        action calculate : CalculateForce;

        flow digitalIn.data to calculate.data;
        flow calculate.force to forceOut.force;
    }

    part def DisplayUnit {
        port forceIn : ForceDisplayInputPort;

        attribute updateRate : FrequencyValue := 10.0;

        action display : DisplayForce;

        flow forceIn.force to display.force;
    }

    part def ForceMeasurementSystem {
        port systemForceIn : ForceInputPort;

        part loadCell : LoadCell;
        part daq : DataAcquisitionUnit;
        part microcontroller : Microcontroller;
        part displayUnit : DisplayUnit;

        connect systemForceIn to loadCell.forceIn;
        connect loadCell.analogOut to daq.analogIn;
        connect daq.digitalOut to microcontroller.digitalIn;
        connect microcontroller.forceOut to displayUnit.forceIn;

        state def MeasurementProcess {
            entry assign microcontroller.calibrationConstant := 2.5;
            then state idle;
            state idle;
            accept AppliedForce then measuring;
            state measuring {
                do loadCell.convert;
                do loadCell.amplify;
                do daq.digitize;
                do microcontroller.calculate;
                do displayUnit.display;
            }
            then idle;
        }

        state measurementProcess : MeasurementProcess;
    }

    requirement def MaxForceRequirement {
        doc /* The system shall accurately measure forces up to 5000 Newtons. */
        attribute maxForce : ForceValue := 5000.0;
    }

    requirement def AccuracyRequirement {
        doc /* The system shall maintain high precision and linearity. */
        attribute maxErrorPercentage : Real := 0.1;
        attribute maxLinearityErrorPercentage : Real := 0.2;
    }

    requirement def TemperatureRangeRequirement {
        doc /* The system shall operate reliably between -10 degrees Celsius and +60 degrees Celsius. */
        attribute minTemp : TemperatureValue := -10.0;
        attribute maxTemp : TemperatureValue := 60.0;
    }

    requirement maxForceReq : MaxForceRequirement;
    requirement accuracyReq : AccuracyRequirement;
    requirement tempRangeReq : TemperatureRangeRequirement;

    satisfy maxForceReq by LoadCell;
    satisfy accuracyReq by ForceMeasurementSystem;
    satisfy tempRangeReq by ForceMeasurementSystem;
}
