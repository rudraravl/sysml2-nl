package ChemiresistorGasDetectionSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    
    attribute def Resistance :> Real;
    attribute def Voltage :> Real;
    attribute def Concentration :> Real;
    attribute def DigitalValue :> Integer;
    attribute def Gain :> Real;
    attribute def SensitivityFactor :> Real;
    attribute def CalibrationSlope :> Real;
    attribute def CalibrationOffset :> Real;
    
    item def Air;
    item def Gas {
        attribute gasType : String;
    }
    item def GasAirMixture {
        item air : Air;
        item gas : Gas;
        attribute concentration : Concentration;
    }
    item def RawAnalogSignal {
        attribute voltage : Voltage;
    }
    item def AmplifiedAnalogSignal {
        attribute voltage : Voltage;
    }
    item def DigitalData {
        attribute value : DigitalValue;
    }
    item def AlarmActivation;
    item def MeasurementLog {
        attribute concentration : Concentration;
        attribute timestamp : String;
    }
    item def DigitalDataReceived;
    item def AlarmActivationReceived;
    
    port def GasInPort {
        in item gasAir : GasAirMixture;
    }
    port def AnalogOutPort {
        out item signal : RawAnalogSignal;
    }
    port def AnalogInPort {
        in item signal : RawAnalogSignal;
    }
    port def AmplifiedOutPort {
        out item signal : AmplifiedAnalogSignal;
    }
    port def AmplifiedInPort {
        in item signal : AmplifiedAnalogSignal;
    }
    port def DigitalOutPort {
        out item data : DigitalData;
    }
    port def DigitalInPort {
        in item data : DigitalData;
    }
    port def AlarmOutPort {
        out item activation : AlarmActivation;
    }
    port def AlarmInPort {
        in item activation : AlarmActivation;
    }
    port def PowerInPort {
        in item power : Voltage;
    }
    port def PowerOutPort {
        out item power : Voltage;
    }
    port def LogOutPort {
        out item log : MeasurementLog;
    }
    
    part def ChemiresistiveSensor {
        port gasPort : GasInPort;
        port signalPort : AnalogOutPort;
        port powerPort : PowerInPort;
        attribute baseResistance : Resistance := 1000.0;
        attribute sensitivityFactor : SensitivityFactor := 10.0;
        attribute currentResistance : Resistance;
        perform action senseGas {
            assign currentResistance := baseResistance + sensitivityFactor * gasPort.gasAir.concentration;
            assign signalPort.signal.voltage := currentResistance * 0.001;
        }
    }
    
    part def SignalProcessor {
        port inPort : AnalogInPort;
        port outPort : AmplifiedOutPort;
        port powerPort : PowerInPort;
        attribute gain : Gain := 100.0;
        attribute noiseFilterCutoff : Real := 60.0;
        perform action processSignal {
            assign outPort.signal.voltage := gain * inPort.signal.voltage;
        }
    }
    
    part def AnalogToDigitalConverter {
        port inPort : AmplifiedInPort;
        port outPort : DigitalOutPort;
        port powerPort : PowerInPort;
        attribute resolutionBits : Integer := 10;
        attribute referenceVoltage : Voltage := 5.0;
        perform action convert {
            assign outPort.data.value := 
                (inPort.signal.voltage / referenceVoltage) * 1023;
        }
    }
    
    part def Microcontroller {
        port inPort : DigitalInPort;
        port alarmPort : AlarmOutPort;
        port logPort : LogOutPort;
        port powerPort : PowerInPort;
        attribute threshold : Concentration := 50.0;
        attribute calibrationSlope : CalibrationSlope := 10.0;
        attribute calibrationOffset : CalibrationOffset := 2.0;
        attribute currentConcentration : Concentration;
        attribute lastReadingTime : String := "2023-10-01T12:00:00Z";
        
        perform action calculateConcentration {
            assign currentConcentration := (inPort.data.value - calibrationOffset) / calibrationSlope;
            assign logPort.log.concentration := currentConcentration;
            assign logPort.log.timestamp := lastReadingTime;
        }
        
        perform action evaluateThreshold;
        
        exhibit state ControllerStates {
            entry assign currentConcentration := 0.0;
            then state idle;
            accept DigitalDataReceived
                then processing;
            state processing {
                do calculateConcentration;
            }
            then if currentConcentration > threshold then alarmActive else idle;
            state alarmActive {
                do evaluateThreshold;
            }
            then idle;
        }
    }
    
    part def AlarmIndicator {
        port alarmPort : AlarmInPort;
        port powerPort : PowerInPort;
        attribute soundLevel : Real := 85.0;
        attribute strobeActive : Boolean := false;
        attribute sirenActive : Boolean := false;
        perform action triggerAlarm {
            assign strobeActive := true;
            assign sirenActive := true;
        }
        perform action deactivateAlarm {
            assign strobeActive := false;
            assign sirenActive := false;
        }
        exhibit state AlarmStates {
            then state silent;
            accept AlarmActivationReceived
                then alarming;
            state alarming {
                do triggerAlarm;
            }
            then silent;
        }
    }
    
    part def PowerManagement {
        port inPort : PowerInPort;
        port outPort : PowerOutPort;
        attribute regulatedVoltage : Voltage := 5.0;
        attribute inputVoltageMin : Voltage := 9.0;
        attribute inputVoltageMax : Voltage := 24.0;
        perform action regulate {
            assign outPort.power := regulatedVoltage;
        }
    }
    
    part def GasDetector {
        port gasPort : GasInPort;
        port powerPort : PowerInPort;
        port logPort : LogOutPort;
        
        part sensor : ChemiresistiveSensor;
        part processor : SignalProcessor;
        part adc : AnalogToDigitalConverter;
        part controller : Microcontroller;
        part alarm : AlarmIndicator;
        part power : PowerManagement;
        
        flow gasFlow of GasAirMixture 
            from gasPort.gasAir to sensor.gasPort.gasAir;
        flow rawSignalFlow of RawAnalogSignal 
            from sensor.signalPort.signal to processor.inPort.signal;
        flow amplifiedSignalFlow of AmplifiedAnalogSignal 
            from processor.outPort.signal to adc.inPort.signal;
        flow digitalDataFlow of DigitalData 
            from adc.outPort.data to controller.inPort.data;
        flow alarmActivationFlow of AlarmActivation 
            from controller.alarmPort.activation to alarm.alarmPort.activation;
        flow logFlow of MeasurementLog 
            from controller.logPort.log to logPort.log;
            
        flow powerFlowIn of Voltage 
            from powerPort.power to power.inPort.power;
        flow powerFlowSensor of Voltage 
            from power.outPort.power to sensor.powerPort.power;
        flow powerFlowProc of Voltage 
            from power.outPort.power to processor.powerPort.power;
        flow powerFlowAdc of Voltage 
            from power.outPort.power to adc.powerPort.power;
        flow powerFlowCtrl of Voltage 
            from power.outPort.power to controller.powerPort.power;
        flow powerFlowAlarm of Voltage 
            from power.outPort.power to alarm.powerPort.power;
    }
    
    requirement def DetectGasRequirement {
        doc /* The system shall detect hazardous gases including Carbon Monoxide. */
        subject detector : GasDetector;
        attribute targetGas : String := "CO";
        attribute minDetectableConcentration : Concentration := 0.0;
        attribute maxDetectableConcentration : Concentration := 1000.0;
        constraint { 
            detector.controller.currentConcentration >= minDetectableConcentration and
            detector.controller.currentConcentration <= maxDetectableConcentration
        }
    }
    
    requirement def AlarmThresholdRequirement {
        doc /* The system shall trigger an alarm when gas concentration exceeds threshold. */
        subject detector : GasDetector;
        attribute alarmThreshold : Concentration := 50.0;
        constraint { detector.controller.threshold == alarmThreshold }
    }
    
    requirement def ResponseTimeRequirement {
        doc /* The system shall trigger the alarm within 30 seconds of exceeding threshold. */
        subject detector : GasDetector;
        attribute maxResponseTime : Real := 30.0;
    }
    
    requirement def PowerStabilityRequirement {
        doc /* The system shall provide stable regulated voltage to all components. */
        subject detector : GasDetector;
        attribute requiredVoltage : Voltage := 5.0;
        attribute maxRipple : Voltage := 0.1;
        constraint { detector.power.regulatedVoltage == requiredVoltage }
    }
    
    requirement def AlarmOutputRequirement {
        doc /* The alarm shall produce a visual strobe and audible siren of at least 85 dB. */
        subject detector : GasDetector;
        attribute minSoundLevel : Real := 85.0;
        constraint { detector.alarm.soundLevel >= minSoundLevel }
    }
    
    requirement def AccuracyRequirement {
        doc /* The measured concentration shall be accurate within ±5% of the true value. */
        subject detector : GasDetector;
        attribute tolerance : Real := 0.05;
    }
    
    part def Atmosphere {
        port samplePort : GasInPort;
        attribute carbonMonoxidePPM : Concentration := 35.0;
        perform action emitSample {
            assign samplePort.gasAir.concentration := carbonMonoxidePPM;
        }
    }
    
    part def GasMonitoringContext {
        part air : Atmosphere;
        part detector : GasDetector;
        flow ambientGasFlow of GasAirMixture 
            from air.samplePort.gasAir to detector.gasPort.gasAir;
    }
    
    part monitoringContext : GasMonitoringContext;
}
