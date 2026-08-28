package TrigeminalNerveStimulationSystem {
    import ISQ::*;
    import ScalarValues::*;
    
    unit def VoltageUnit :> ElectricPotential { }
    unit def CurrentUnit :> ElectricCurrent { }
    unit def ImpedanceUnit :> ElectricResistance { }
    unit def FrequencyUnit :> Frequency { }
    unit def DurationUnit :> Time { }
    
    value type Voltage :> Real { unit VoltageUnit; }
    value type Current :> Real { unit CurrentUnit; }
    value type Impedance :> Real { unit ImpedanceUnit; }
    value type Frequency :> Real { unit FrequencyUnit; }
    value type Duration :> Real { unit DurationUnit; }
    
    enum StimulationMode { continuous = 0, burst = 1 }
    enum SystemState { off, standby, calibrating, active, fault }
    
    item def ElectricalPulse {
        attr amplitude : Voltage;
        attr frequency : Frequency;
        attr pulseWidth : Duration;
        attr mode : StimulationMode;
    }
    
    item def NeuralFeedback {
        attr tissueImpedance : Impedance;
        attr nervePotential : Voltage;
    }
    
    port def PowerOutPort {
        out attr voltage : Voltage;
        out attr current : Current;
    }
    port def PowerInPort {
        in attr voltage : Voltage;
        in attr current : Current;
    }
    port def ControlOutPort {
        out attr command : String;
        in attr status : String;
    }
    port def ControlInPort {
        in attr command : String;
        out attr status : String;
    }
    port def StimOutPort {
        out item pulse : ElectricalPulse;
    }
    port def StimInPort {
        in item pulse : ElectricalPulse;
    }
    port def FeedbackOutPort {
        out item feedback : NeuralFeedback;
    }
    port def FeedbackInPort {
        in item feedback : NeuralFeedback;
    }
    
    requirement def SafetyLimits {
        subject stim : ElectricalPulse;
        constraint { stim.amplitude <= 10.0 [VoltageUnit] }
        constraint { stim.frequency <= 200.0 [FrequencyUnit] }
    }
    
    requirement def TherapyDelivery {
        subject system : TrigeminalNerveStimulationSystem;
        constraint { system.controlProcessor.state == SystemState::active }
    }
    
    part def ControlProcessor {
        port powerIn : PowerInPort;
        port genControl : ControlOutPort;
        port sensorControl : ControlOutPort;
        port feedbackIn : FeedbackInPort;
        
        attr state : SystemState = SystemState::off;
        attr sessionDuration : Duration;
        attr sessionIntensity : Voltage;
        attr clinicianStart : Boolean = false;
        attr calibrationComplete : Boolean = false;
        attr shutdown : Boolean = false;
        
        action def Calibrate {
            // measure baseline
        }
        
        action def Monitor {
            // check feedback
        }
        
        exhibit state behavior {
            initial off;
            state off;
            state standby;
            state calibrating {
                entry do Calibrate;
            }
            state active {
                entry do Monitor;
            }
            state fault;
            
            transition off -> standby when powerIn.voltage > 0.0;
            transition standby -> calibrating when clinicianStart;
            transition calibrating -> active when calibrationComplete;
            transition active -> fault when feedbackIn.feedback.tissueImpedance > 10000.0 [ImpedanceUnit] or feedbackIn.feedback.tissueImpedance < 100.0 [ImpedanceUnit];
            transition fault -> off when shutdown;
        }
    }
    
    part def PowerModule {
        port powerOut : PowerOutPort;
        attr batteryLevel : Real;
    }
    
    part def SignalGenerator {
        port powerIn : PowerInPort;
        port controlIn : ControlInPort;
        port stimOut : StimOutPort;
        
        action def GeneratePulse {
            in mode : StimulationMode;
            out pulse : ElectricalPulse;
        }
    }
    
    part def ElectrodeArray {
        port stimIn : StimInPort;
        port tissueOut : StimOutPort; 
        attr numContacts : Integer = 4;
    }
    
    part def FeedbackSensor {
        port powerIn : PowerInPort;
        port controlIn : ControlInPort;
        port feedbackOut : FeedbackOutPort;
        port tissueIn : FeedbackInPort;
        
        action def Sense {
            out feedback : NeuralFeedback;
        }
    }
    
    part def TrigeminalNerveStimulationSystem {
        part controlProcessor : ControlProcessor;
        part powerModule : PowerModule;
        part signalGenerator : SignalGenerator;
        part electrodeArray : ElectrodeArray;
        part feedbackSensor : FeedbackSensor;
        
        port patientStimInterface : StimOutPort;
        port patientFeedbackInterface : FeedbackInPort;
        
        connection powerToProcessor connect powerModule.powerOut to controlProcessor.powerIn;
        connection powerToGenerator connect powerModule.powerOut to signalGenerator.powerIn;
        connection powerToSensor connect powerModule.powerOut to feedbackSensor.powerIn;
        
        connection controlToGenerator connect controlProcessor.genControl to signalGenerator.controlIn;
        connection controlToSensor connect controlProcessor.sensorControl to feedbackSensor.controlIn;
        
        connection generatorToElectrode connect signalGenerator.stimOut to electrodeArray.stimIn;
        connection electrodeToPatient connect electrodeArray.tissueOut to patientStimInterface;
        
        connection patientToSensor connect patientFeedbackInterface to feedbackSensor.tissueIn;
        connection sensorFeedbackToProcessor connect feedbackSensor.feedbackOut to controlProcessor.feedbackIn;
    }
}
