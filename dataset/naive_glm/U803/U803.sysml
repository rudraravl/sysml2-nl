package PIR_Sensing_Unit {
    import ISQ::*;
    import ScalarValues::*;

    value type Voltage :> Real {
        unit 'V';
    }
    value type Power :> Real {
        unit 'W';
    }

    item def InfraredRadiation;
    item def AnalogSignal {
        attribute voltage : Voltage;
    }
    item def DigitalOutput {
        attribute state : Boolean;
    }

    port def OpticalPort {
        out item ir : InfraredRadiation;
    }
    port def AnalogOutPort {
        out item signal : AnalogSignal;
    }
    port def AnalogInPort {
        in item signal : AnalogSignal;
    }
    port def DigitalOutPort {
        out item signal : DigitalOutput;
    }
    port def PowerInPort {
        in attribute voltage : Voltage;
    }
    port def PowerOutPort {
        out attribute voltage : Voltage;
    }

    requirement def DetectMotionReq {
        doc /* The unit shall detect the movement of warm bodies by sensing changes in infrared radiation. */
    }
    requirement def AmplifySignalReq {
        doc /* The unit shall amplify the weak voltage from the pyroelectric sensors to an analyzable level. */
    }
    requirement def ProcessSignalReq {
        doc /* The unit shall filter the amplified signal and compare it against a threshold to generate a digital output. */
    }
    requirement def PowerRegulationReq {
        doc /* The unit shall regulate external power to provide stable voltage to all components. */
    }

    part def FresnelLensArray {
        port opticalIn : OpticalPort;
        port opticalOut : OpticalPort;
        attribute fieldOfView : Real { unit 'deg'; }
    }

    part def PyroelectricSensorElement {
        port opticalIn : OpticalPort;
        port electricalOut : AnalogOutPort;
        port powerIn : PowerInPort;
    }

    part def PyroelectricSensorPair {
        port opticalIn : OpticalPort;
        port electricalOut : AnalogOutPort;
        port powerIn : PowerInPort;
        
        part element1 : PyroelectricSensorElement;
        part element2 : PyroelectricSensorElement;
        
        connection opticalConn1 connect opticalIn to element1.opticalIn;
        connection opticalConn2 connect opticalIn to element2.opticalIn;
        connection electricalConn1 connect element1.electricalOut to electricalOut;
        connection electricalConn2 connect element2.electricalOut to electricalOut;
        connection powerConn1 connect powerIn to element1.powerIn;
        connection powerConn2 connect powerIn to element2.powerIn;
    }

    part def SignalAmplifier {
        port electricalIn : AnalogInPort;
        port electricalOut : AnalogOutPort;
        port powerIn : PowerInPort;
        attribute gain : Real;
    }

    part def SignalProcessor {
        port electricalIn : AnalogInPort;
        port digitalOut : DigitalOutPort;
        port powerIn : PowerInPort;
        attribute threshold : Voltage;
    }

    part def VoltageRegulator {
        port powerIn : PowerInPort;
        port powerOut : PowerOutPort;
        attribute outputVoltage : Voltage;
    }

    part def PIRSensorUnit {
        satisfy DetectMotionReq;
        satisfy AmplifySignalReq;
        satisfy ProcessSignalReq;
        satisfy PowerRegulationReq;

        port externalPower : PowerInPort;
        port motionOutput : DigitalOutPort;
        port irInput : OpticalPort;

        attribute warmUpComplete : Boolean = false;
        attribute motionDetected : Boolean = false;
        attribute processingComplete : Boolean = false;

        part lens : FresnelLensArray;
        part sensors : PyroelectricSensorPair;
        part amplifier : SignalAmplifier;
        part processor : SignalProcessor;
        part regulator : VoltageRegulator;

        connection powerInConn connect externalPower to regulator.powerIn;
        connection powerToSensors connect regulator.powerOut to sensors.powerIn;
        connection powerToAmplifier connect regulator.powerOut to amplifier.powerIn;
        connection powerToProcessor connect regulator.powerOut to processor.powerIn;

        connection irToLens connect irInput to lens.opticalIn;
        connection lensToSensors connect lens.opticalOut to sensors.opticalIn;
        connection sensorsToAmplifier connect sensors.electricalOut to amplifier.electricalIn;
        connection amplifierToProcessor connect amplifier.electricalOut to processor.electricalIn;
        connection processorToOutput connect processor.digitalOut to motionOutput;

        state def PIRBehavior {
            state WarmUp {
                entry action { /* Initialize components and stabilize voltage */ }
            }
            state Monitoring {
                // Continuously monitor infrared changes
            }
            state DetectionAndProcessing {
                entry action { /* Filter signal, compare threshold, generate output */ }
            }
            
            transition initial to WarmUp;
            transition WarmUp to Monitoring when (warmUpComplete);
            transition Monitoring to DetectionAndProcessing when (motionDetected);
            transition DetectionAndProcessing to Monitoring when (processingComplete);
        }
    }
}
