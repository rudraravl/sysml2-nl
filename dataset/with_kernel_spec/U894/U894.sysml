package StrainMeasurementSystem {
    private import ScalarValues::Real;
    private import ScalarValues::Integer;
    private import SI::s;
    private import SI::V;
    private import SI::Ohm;
    private import SI::C;

    item def ResistanceChange {
        attribute value : Real [Ohm];
    }
    item def BridgeVoltage {
        attribute value : Real [V];
    }
    item def ConditionedVoltage {
        attribute value : Real [V];
    }
    item def DigitalSample {
        attribute counts : Integer;
        attribute timestamp : Real [s];
    }
    item def StrainMeasurement {
        attribute strain : Real;
        attribute temperature : Real [C];
        attribute timestamp : Real [s];
    }
    item def TemperatureReading {
        attribute value : Real [C];
    }

    port def ResistanceOutPort {
        out item resistance : ResistanceChange;
    }
    port def ResistanceInPort {
        in item resistance : ResistanceChange;
    }
    port def VoltageOutPort {
        out item voltage : BridgeVoltage;
    }
    port def VoltageInPort {
        in item voltage : BridgeVoltage;
    }
    port def ConditionedOutPort {
        out item voltage : ConditionedVoltage;
    }
    port def ConditionedInPort {
        in item voltage : ConditionedVoltage;
    }
    port def DigitalOutPort {
        out item data : DigitalSample;
    }
    port def DigitalInPort {
        in item data : DigitalSample;
    }
    port def TempOutPort {
        out item temp : TemperatureReading;
    }
    port def TempInPort {
        in item temp : TemperatureReading;
    }
    port def StrainOutPort {
        out item measurement : StrainMeasurement;
    }

    attribute def StartCalibrationSignal;
    attribute def CalibrationCompleteSignal;
    attribute def StopSignal;

    requirement def AccuracyRequirement {
        attribute targetAccuracy : Real;
    }
    requirement def SpeedRequirement {
        attribute minUpdateRate : Real;
    }
    requirement def TemperatureStabilityRequirement {
        attribute minTemp : Real;
        attribute maxTemp : Real;
    }
    requirement def NoiseRejectionRequirement {
        attribute minCMRR : Real;
    }

    part def StrainGauge {
        attribute nominalResistance : Real [Ohm];
        attribute gaugeFactor : Real;
        out port resistanceOut : ResistanceOutPort;
        action senseStrain;
    }

    part def WheatstoneBridge {
        in port resistanceIn : ResistanceInPort;
        out port voltageOut : VoltageOutPort;
        attribute excitationVoltage : Real [V];
        action convertResistanceToVoltage;
    }

    part def SignalConditioner {
        in port voltageIn : VoltageInPort;
        out port conditionedOut : ConditionedOutPort;
        attribute gain : Real;
        attribute lowCutoffFreq : Real;
        attribute highCutoffFreq : Real;
        action amplifyAndFilter;
    }

    part def ADC {
        in port analogIn : ConditionedInPort;
        out port digitalOut : DigitalOutPort;
        attribute resolutionBits : Integer;
        attribute samplingRate : Real;
        attribute referenceVoltage : Real [V];
        action convertToDigital;
    }

    part def TemperatureSensor {
        out port tempOut : TempOutPort;
        action readTemperature;
    }

    part def DataProcessor {
        in port digitalIn : DigitalInPort;
        in port tempIn : TempInPort;
        out port strainOut : StrainOutPort;
        attribute calibrationFactor : Real;
        attribute tempCoefficient : Real;
        action processData;
    }

    state def SystemStates {
        state idle;
        state calibrating {
            entry action performCalibration;
        }
        state measuring {
            do action continuousMeasurement;
        }
        transition first idle accept StartCalibrationSignal then calibrating;
        transition first calibrating accept CalibrationCompleteSignal then measuring;
        transition first measuring accept StopSignal then idle;
        transition first measuring accept StartCalibrationSignal then calibrating;
    }

    part def StrainMeasurementSystem {
        part strainGauge : StrainGauge;
        part wheatstoneBridge : WheatstoneBridge;
        part signalConditioner : SignalConditioner;
        part adc : ADC;
        part tempSensor : TemperatureSensor;
        part dataProcessor : DataProcessor;

        connect strainGauge.resistanceOut to wheatstoneBridge.resistanceIn;
        connect wheatstoneBridge.voltageOut to signalConditioner.voltageIn;
        connect signalConditioner.conditionedOut to adc.analogIn;
        connect adc.digitalOut to dataProcessor.digitalIn;
        connect tempSensor.tempOut to dataProcessor.tempIn;

        out port systemStrainOut : StrainOutPort;
        connect dataProcessor.strainOut to systemStrainOut;

        exhibit SystemStates;

        requirement accuracyReq : AccuracyRequirement {
            :>> targetAccuracy = 0.001;
        }
        requirement speedReq : SpeedRequirement {
            :>> minUpdateRate = 1000.0;
        }
        requirement stabilityReq : TemperatureStabilityRequirement {
            :>> minTemp = -40.0;
            :>> maxTemp = 85.0;
        }
        requirement noiseReq : NoiseRejectionRequirement {
            :>> minCMRR = 80.0;
        }

        satisfy accuracyReq by dataProcessor;
        satisfy speedReq by adc;
        satisfy stabilityReq by tempSensor;
        satisfy noiseReq by signalConditioner;
    }
}
