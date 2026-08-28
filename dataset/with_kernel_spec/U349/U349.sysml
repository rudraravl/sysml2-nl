package PeakExpiratoryFlowMeter {
    private import ScalarValues::*;
    private import ISQ::*;

    unit LiterPerMinute;

    attribute def FlowRateValue :> Real {
        doc /* Volumetric flow rate in liters per minute. */
    }
    attribute def PressureValue :> Real {
        doc /* Pressure in pascals. */
    }
    attribute def TimeValue :> Real {
        doc /* Time in seconds. */
    }

    item def Air;

    item def SensorSample {
        attribute flowRate : FlowRateValue;
        attribute pressure : PressureValue;
        attribute timestamp : TimeValue;
    }

    item def PeakReading {
        attribute peakFlow : FlowRateValue;
        attribute isValid : Boolean;
        attribute timestamp : TimeValue;
    }

    attribute def BreathDetected;
    attribute def ExhalationComplete;
    attribute def ResetSignal;

    port def AirPort {
        item air : Air;
    }
    port def DataPort {
        item sample : SensorSample;
    }
    port def ReadingPort {
        item reading : PeakReading;
    }

    action def SenseFlow {
        in item air : Air;
        out item sample : SensorSample;
    }

    action def AnalyzePeak {
        in item samples : SensorSample[*];
        out item reading : PeakReading;
    }

    action def ShowReading {
        in item reading : PeakReading;
    }

    calc def FindPeakValue {
        in samples : SensorSample[*];
        return peak : FlowRateValue;
    }

    part def Mouthpiece {
        port airIn : AirPort;
        port airOut : AirPort;
    }

    part def FlowSensor {
        port airIn : AirPort;
        port dataOut : DataPort;
        perform action sense : SenseFlow;
    }

    part def SignalProcessor {
        port dataIn : DataPort;
        port displayOut : ReadingPort;
        perform action analyze : AnalyzePeak;
    }

    part def DisplayUnit {
        port readingIn : ReadingPort;
        perform action show : ShowReading;
    }

    part def PeakFlowMeter {
        part mouthpiece : Mouthpiece;
        part flowSensor : FlowSensor;
        part processor : SignalProcessor;
        part display : DisplayUnit;

        connect mouthpiece.airOut to flowSensor.airIn;
        connect flowSensor.dataOut to processor.dataIn;
        connect processor.displayOut to display.readingIn;

        exhibit state deviceStates {
            entry; then idle;

            state idle;
            accept BreathDetected then measuring;

            state measuring {
                do flowSensor.sense;
            }
            accept ExhalationComplete then analyzing;

            state analyzing {
                do processor.analyze;
            }
            then displaying;

            state displaying {
                do display.show;
            }
            accept ResetSignal then idle;
        }
    }

    requirement def MeasurePeakFlow {
        subject device : PeakFlowMeter;
        doc /* The device shall measure the peak expiratory flow rate of a patient during exhalation. */
    }

    requirement def MeasurementRange {
        subject device : PeakFlowMeter;
        attribute minRange : FlowRateValue := 60;
        attribute maxRange : FlowRateValue := 800;
        doc /* The device shall measure peak expiratory flow rates from 60 to 800 liters per minute. */
    }

    requirement def DisplayResult {
        subject device : PeakFlowMeter;
        doc /* The device shall display the highest measured expiratory flow rate after each measurement cycle. */
    }
}
