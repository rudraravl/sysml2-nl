package PeakExpiratoryFlowMeter {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    value type FlowRate :> Real {
        unit "L/min";
        doc "Volumetric flow rate of exhaled air in liters per minute.";
    }

    value type AirPressure :> Real {
        unit "Pa";
        doc "Pressure of exhaled air in pascals.";
    }

    value type TimeStamp :> Real {
        unit "ms";
        doc "Elapsed time since device power-on in milliseconds.";
    }

    // ===== Item Definitions =====
    item def ExhaledAir {
        attribute flowRate : FlowRate;
        attribute pressure : AirPressure;
    }

    item def SensorData {
        attribute flowRate : FlowRate;
        attribute pressure : AirPressure;
        attribute timestamp : TimeStamp;
    }

    item def PeakReading {
        attribute peakFlowRate : FlowRate;
        attribute isValid : Boolean;
        attribute timestamp : TimeStamp;
    }

    // ===== Port Definitions =====
    port def AirInPort {
        in item air : ExhaledAir;
    }

    port def AirOutPort {
        out item air : ExhaledAir;
    }

    port def SensorDataOutPort {
        out item data : SensorData;
    }

    port def SensorDataInPort {
        in item data : SensorData;
    }

    port def ReadingOutPort {
        out item reading : PeakReading;
    }

    port def ReadingInPort {
        in item reading : PeakReading;
    }

    // ===== Part Definitions =====
    part def Mouthpiece {
        port airIn : AirInPort;
        port airOut : AirOutPort;

        attribute isAttached : Boolean = false;

        action def ChannelAir {
            in item incoming : ExhaledAir;
            out item outgoing : ExhaledAir;
        }

        action channelAir : ChannelAir;
    }

    part def FlowSensor {
        port airIn : AirInPort;
        port dataOut : SensorDataOutPort;

        attribute measuredFlowRate : FlowRate;
        attribute measuredPressure : AirPressure;
        attribute samplingInterval : TimeStamp = 1.0;

        action def SenseFlow {
            in item air : ExhaledAir;
            out item data : SensorData;
        }

        action senseFlow : SenseFlow;
    }

    part def SignalProcessor {
        port dataIn : SensorDataInPort;
        port readingOut : ReadingOutPort;

        attribute peakFlowRate : FlowRate;
        attribute isMeasurementValid : Boolean;
        attribute dataBuffer : SensorData[0..*];

        action def ProcessData {
            in item dataStream : SensorData;
            out item peak : PeakReading;
        }

        action processData : ProcessData;
    }

    part def DisplayUnit {
        port readingIn : ReadingInPort;

        attribute displayedValue : FlowRate;
        attribute backlightOn : Boolean = true;

        action def ShowResult {
            in item reading : PeakReading;
        }

        action showResult : ShowResult;
    }

    // ===== System Definition =====
    part def DigitalPeakFlowMeter {
        attribute deviceName : String = "DigitalPeakFlowMeter";
        attribute isPoweredOn : Boolean = true;

        part mouthpiece : Mouthpiece;
        part flowSensor : FlowSensor;
        part signalProcessor : SignalProcessor;
        part displayUnit : DisplayUnit;

        connection : AirFlow connect mouthpiece.airOut to flowSensor.airIn;
        connection : SensorDataFlow connect flowSensor.dataOut to signalProcessor.dataIn;
        connection : ReadingFlow connect signalProcessor.readingOut to displayUnit.readingIn;

        // ===== State Machine =====
        state def DeviceStateMachine {
            attribute breathDetected : Boolean;
            attribute exhalationComplete : Boolean;
            attribute peakDetermined : Boolean;
            attribute resetRequested : Boolean;

            state Idle {
                entry { /* Device ready, waiting for user */ }
                do { /* Monitor for breath onset */ }
            }

            state Measuring {
                entry { /* Begin capturing sensor data */ }
                do { /* Continuously sample flow rate and pressure */ }
            }

            state Analyzing {
                entry { /* Process captured data stream */ }
                do { /* Identify maximum flow rate value */ }
            }

            state Displaying {
                entry { /* Send peak reading to display */ }
                do { /* Show numerical result */ }
            }

            transition from Idle to Measuring when breathDetected;
            transition from Measuring to Analyzing when exhalationComplete;
            transition from Analyzing to Displaying when peakDetermined;
            transition from Displaying to Idle when resetRequested;
        }

        exhibit DeviceStateMachine;
    }

    // ===== Requirements =====
    requirement def MeasurePeakExpiratoryFlow {
        doc "The device shall measure the maximum speed at which a person can exhale.";
        subject device : DigitalPeakFlowMeter;
    }

    requirement def DetectBreath {
        doc "The device shall detect when a patient begins exhaling into the mouthpiece and transition from Idle to Measuring.";
        subject device : DigitalPeakFlowMeter;
    }

    requirement def CaptureSensorData {
        doc "The flow sensor shall measure the rate and pressure of the airflow and convert it into electronic data.";
        subject sensor : FlowSensor;
    }

    requirement def IdentifyPeakFlow {
        doc "The signal processor shall analyze the continuous data stream in real-time to identify the single highest flow rate achieved during exhalation.";
        subject processor : SignalProcessor;
    }

    requirement def ValidateMeasurement {
        doc "The signal processor shall validate the measurement before sending the final reading to the display.";
        subject processor : SignalProcessor;
    }

    requirement def DisplayResult {
        doc "The display unit shall show the numerical peak flow result to the patient or healthcare provider.";
        subject display : DisplayUnit;
    }

    requirement def DetachableMouthpiece {
        doc "The mouthpiece shall be detachable for hygiene, cleaning, or replacement.";
        subject mouthpiece : Mouthpiece;
    }

    requirement def StateSequence {
        doc "The device shall operate through the states: Idle, Measuring, Analyzing, Displaying, and return to Idle upon reset.";
        subject device : DigitalPeakFlowMeter;
    }

    // ===== Requirement Satisfaction =====
    satisfaction MeasurePeakExpiratoryFlow by DigitalPeakFlowMeter;
    satisfaction DetectBreath by DigitalPeakFlowMeter;
    satisfaction CaptureSensorData by FlowSensor;
    satisfaction IdentifyPeakFlow by SignalProcessor;
    satisfaction ValidateMeasurement by SignalProcessor;
    satisfaction DisplayResult by DisplayUnit;
    satisfaction DetachableMouthpiece by Mouthpiece;
    satisfaction StateSequence by DigitalPeakFlowMeter;
}
