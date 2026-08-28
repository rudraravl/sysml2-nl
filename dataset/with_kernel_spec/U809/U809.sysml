package OpticalDetectionSystemModel {
    private import ScalarValues::*;

    attribute def OpticalPower :> Real;
    attribute def Photocurrent :> Real;
    attribute def AmplifiedVoltage :> Real;
    attribute def ResistanceValue :> Real;
    attribute def SamplingFrequency :> Real;
    attribute def DigitalValue :> Integer;
    attribute def ThresholdValue :> DigitalValue;

    port def OpticalInPort { in light : OpticalPower; }
    port def CurrentOutPort { out current : Photocurrent; }
    port def CurrentInPort { in current : Photocurrent; }
    port def VoltageOutPort { out voltage : AmplifiedVoltage; }
    port def VoltageInPort { in voltage : AmplifiedVoltage; }
    port def DigitalOutPort { out digitalValue : DigitalValue; }

    part def PhotodiodeSensor {
        doc /* Semiconductor device generating current proportional to incident light. */
        attribute darkCurrent : Photocurrent;
        attribute responsivity : Real;
        port opticalIn : OpticalInPort;
        port currentOut : CurrentOutPort;
    }

    part def LoadResistor {
        doc /* Simple electronic component forming the initial sensing circuit. */
        attribute resistance : ResistanceValue;
        port currentIn : CurrentInPort;
        port currentOut : CurrentOutPort;
    }

    part def TransimpedanceAmplifier {
        doc /* Converts weak input current into a measurable voltage signal. */
        attribute gain : ResistanceValue;
        port currentIn : CurrentInPort;
        port voltageOut : VoltageOutPort;
    }

    part def SignalProcessor {
        doc /* Filters, samples, and converts analog voltage to a 12-bit digital value. */
        attribute samplingRate : SamplingFrequency;
        attribute bitDepth : Integer = 12;
        port voltageIn : VoltageInPort;
        port digitalOut : DigitalOutPort;
    }

    action def ProcessOpticalSignal {
        action sense {
            in light : OpticalPower;
            out current : Photocurrent;
        }
        action load {
            in current : Photocurrent;
            out loadCurrent : Photocurrent;
        }
        action amplify {
            in current : Photocurrent;
            out voltage : AmplifiedVoltage;
        }
        action digitize {
            in voltage : AmplifiedVoltage;
            out value : DigitalValue;
        }
        flow sense.current to load.current;
        flow load.loadCurrent to amplify.current;
        flow amplify.voltage to digitize.voltage;
    }

    requirement def OpticalDetectionRequirement {
        subject detectionSystem : OpticalDetectionSystem;
        attribute requiredBitDepth : Integer = 12;
        require constraint { detectionSystem.processor.bitDepth >= requiredBitDepth }
    }

    part def OpticalDetectionSystem {
        attribute detectionThreshold : ThresholdValue;
        port opticalIn : OpticalInPort;
        port digitalOut : DigitalOutPort;
        item recordedMeasurements : DigitalValue[*];

        perform processOpticalSignal : ProcessOpticalSignal;

        part photodiode : PhotodiodeSensor {
            perform processOpticalSignal.sense;
        }
        part loadResistor : LoadResistor {
            perform processOpticalSignal.load;
        }
        part amplifier : TransimpedanceAmplifier {
            perform processOpticalSignal.amplify;
        }
        part processor : SignalProcessor {
            perform processOpticalSignal.digitize;
        }

        connect opticalIn to photodiode.opticalIn;
        connect photodiode.currentOut to loadResistor.currentIn;
        connect loadResistor.currentOut to amplifier.currentIn;
        connect amplifier.voltageOut to processor.voltageIn;
        connect processor.digitalOut to digitalOut;

        state machine detectionStateMachine {
            state Monitoring;
            state Recording {
                entry action recordValue {
                    in value : DigitalValue = processor.digitalOut.digitalValue;
                    out recorded : DigitalValue :> recordedMeasurements;
                }
            }
            transition monitor_to_record from Monitoring to Recording guard processor.digitalOut.digitalValue > detectionThreshold;
            transition record_to_monitor from Recording to Monitoring guard processor.digitalOut.digitalValue <= detectionThreshold;
        }
    }
}
