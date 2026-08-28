package PhotoelectricSensor {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    item def ElectricalPower {
        attribute voltage : ElectricPotentialValue;
    }
    item def LightBeam {
        attribute wavelength : LengthValue;
        attribute intensity : PowerValue;
    }
    item def ReflectedLight {
        attribute intensity : PowerValue;
    }
    item def ElectricalSignal {
        attribute voltage : ElectricPotentialValue;
    }
    item def DigitalDetection {
        attribute objectDetected : Boolean;
    }

    port def PowerPort {
        in item power : ElectricalPower;
    }
    port def OpticalPort {
        out item emittedBeam : LightBeam;
        in item reflectedBeam : ReflectedLight;
    }
    port def OutputPort {
        out item digital : DigitalDetection;
        out item analog : ElectricalSignal;
    }
    port def InternalEmitterPort {
        out item beam : LightBeam;
    }
    port def InternalDetectorPort {
        in item reflection : ReflectedLight;
    }
    port def SignalOutPort {
        out item raw : ElectricalSignal;
    }
    port def SignalInPort {
        in item raw : ElectricalSignal;
    }

    action def EmitBeam {
        in power : ElectricalPower;
        in targetWavelength : LengthValue;
        in targetIntensity : PowerValue;
        out beam : LightBeam;
    }
    action def CaptureReflection {
        in reflection : ReflectedLight;
        in sensitivity : Real;
        out signal : ElectricalSignal;
    }
    action def Amplify {
        in raw : ElectricalSignal;
        in factor : Real;
        out amplified : ElectricalSignal;
    }
    action def CompareThreshold {
        in amplified : ElectricalSignal;
        in threshold : ElectricPotentialValue;
        out detected : Boolean;
    }
    action def GenerateOutputs {
        in detected : Boolean;
        in amplified : ElectricalSignal;
        out digital : DigitalDetection;
        out analog : ElectricalSignal;
    }

    attribute def PowerOnSignal;
    attribute def PowerOffSignal;
    attribute def FaultSignal;
    attribute def ResetSignal;
    attribute def ObjectDetectedEvent;
    attribute def ObjectClearedEvent;

    state def SensorStates {
        entry; then idle;
        state idle;
        accept PowerOnSignal then active;
        state active {
            entry; then detecting;
            state detecting;
            accept ObjectDetectedEvent then detected;
            state detected;
            accept ObjectClearedEvent then detecting;
        }
        accept PowerOffSignal then idle;
        accept FaultSignal then fault;
        state fault;
        accept ResetSignal then idle;
    }

    part def LightEmitter {
        port powerIn : PowerPort;
        port opticalOut : InternalEmitterPort;
        attribute targetWavelength : LengthValue;
        attribute targetIntensity : PowerValue;
        perform action emitBeam : EmitBeam;
    }
    part def Photodetector {
        port opticalIn : InternalDetectorPort;
        port signalOut : SignalOutPort;
        attribute sensitivity : Real;
        perform action captureReflection : CaptureReflection;
    }
    part def SignalProcessor {
        port signalIn : SignalInPort;
        port output : OutputPort;
        attribute amplificationFactor : Real;
        attribute threshold : ElectricPotentialValue;
        perform action amplify : Amplify;
        perform action compareThreshold : CompareThreshold;
        perform action generateOutputs : GenerateOutputs;
    }
    part def PhotoelectricSensorUnit {
        port mainPower : PowerPort;
        port mainOptical : OpticalPort;
        port mainOutput : OutputPort;
        attribute threshold : ElectricPotentialValue;
        attribute sensitivity : Real;
        exhibit state sensorStates : SensorStates;
    }

    requirement def WavelengthRequirement {
        doc "The emitted light shall have a wavelength of 850 nm."
    }
    requirement def DetectionRequirement {
        doc "The sensor shall detect a target object when the reflected light intensity exceeds the predefined threshold."
    }
    requirement def OutputRequirement {
        doc "The sensor shall provide both a digital detection output and an analog voltage level."
    }
    requirement def StateRequirement {
        doc "The sensor shall operate in idle, active, detected, and fault states."
    }
    requirement def SensitivityRequirement {
        doc "The photodetector shall convert reflected light intensity into an electrical signal proportional to the detected intensity and sensitivity."
    }

    part sensorUnit : PhotoelectricSensorUnit {
        attribute threshold : ElectricPotentialValue := 2.5 [V];
        attribute sensitivity : Real := 0.8;

        part emitter : LightEmitter {
            attribute targetWavelength : LengthValue := 850e-9 [m];
            attribute targetIntensity : PowerValue := 0.005 [W];
        }
        part detector : Photodetector {
            attribute sensitivity : Real := sensorUnit.sensitivity;
        }
        part processor : SignalProcessor {
            attribute amplificationFactor : Real := 100.0;
            attribute threshold : ElectricPotentialValue := sensorUnit.threshold;
        }

        connect mainPower to emitter.powerIn;
        flow emitter.opticalOut.beam to mainOptical.emittedBeam;
        flow mainOptical.reflectedBeam to detector.opticalIn.reflection;
        flow detector.signalOut.raw to processor.signalIn.raw;
        connect processor.output to mainOutput;

        requirement reqWavelength : WavelengthRequirement;
        requirement reqDetection : DetectionRequirement;
        requirement reqOutput : OutputRequirement;
        requirement reqState : StateRequirement;
        requirement reqSensitivity : SensitivityRequirement;

        satisfy reqWavelength by emitter;
        satisfy reqDetection by processor;
        satisfy reqOutput by sensorUnit;
        satisfy reqState by sensorUnit;
        satisfy reqSensitivity by detector;
    }
}
