package SphygmomanometerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def BloodPressureReading {
        attribute systolic : PressureValue;
        attribute diastolic : PressureValue;
        attribute meanArterialPressure : PressureValue;
        attribute pulseRate : FrequencyValue;
    }
    
    attribute def CuffPressure :> PressureValue;
    attribute def OscillationAmplitude :> PressureValue;
    attribute def DeflationRate :> ISQ::VolumeFlowRateValue;
    
    item def CompressedAir;
    item def ElectricalPower;
    
    port def PneumaticPort {
        out item airFlow : CompressedAir;
        attribute pressure : CuffPressure;
    }
    
    port def ElectricalPort {
        in item power : ElectricalPower;
        attribute voltage : Real;
    }
    
    port def SensorDataPort {
        out attribute pressureSignal : PressureValue;
        out attribute oscillationSignal : OscillationAmplitude;
    }
    
    port def UserInterfacePort {
        in attribute startCommand : Boolean;
        out attribute displayData : BloodPressureReading;
    }
    
    part def InflatableCuff {
        port pneumaticIn : PneumaticPort;
        
        attribute currentPressure : CuffPressure;
        attribute armCircumference : ISQ::LengthValue;
        attribute maxSafePressure : PressureValue;
        attribute cuffCompliance : Real;
    }
    
    part def PneumaticPump {
        port airOut : PneumaticPort;
        port powerIn : ElectricalPort;
        
        attribute maxPressure : PressureValue;
        attribute flowRate : ISQ::VolumeFlowRateValue;
        attribute isActive : Boolean;
    }
    
    part def PressureTransducer {
        port sensorOut : SensorDataPort;
        port pneumaticMonitor : PneumaticPort;
        
        attribute sensitivity : Real;
        attribute accuracy : PressureValue;
        attribute samplingRate : FrequencyValue;
    }
    
    part def OscillationDetector {
        port sensorOut : SensorDataPort;
        
        attribute detectionThreshold : OscillationAmplitude;
        attribute filterCutoffFrequency : FrequencyValue;
    }
    
    part def ExhaustValve {
        port pneumaticRelease : PneumaticPort;
        
        attribute deflationRate : DeflationRate;
        attribute isOpen : Boolean;
        attribute valvePosition : Real;
    }
    
    part def MicroprocessorUnit {
        port powerIn : ElectricalPort;
        port pressureDataIn : SensorDataPort;
        port oscillationDataIn : SensorDataPort;
        port userInterface : UserInterfacePort;
        
        attribute currentState : MeasurementState;
        attribute storedReading : BloodPressureReading;
        attribute oscillationBuffer : OscillationAmplitude[*];
    }
    
    part def LCDDisplay {
        port dataIn : UserInterfacePort;
        port powerIn : ElectricalPort;
        
        attribute brightness : Real;
        attribute displayedReading : BloodPressureReading;
        attribute batteryLevel : Real;
    }
    
    part def ControlButton {
        port userInterface : UserInterfacePort;
        
        attribute isPressed : Boolean;
    }
    
    enum def MeasurementState {
        idle;
        initializing;
        inflating;
        measuring;
        deflating;
        analyzing;
        displaying;
        error;
    }
    
    action def InflateCuffAction {
        in targetPressure : PressureValue;
        in currentPressure : PressureValue;
        out finalPressure : PressureValue;
        out inflationComplete : Boolean;
    }
    
    action def MonitorPressureAction {
        in cuffPressure : PressureValue;
        out pressureReading : PressureValue;
        out oscillationAmplitude : OscillationAmplitude;
    }
    
    action def DetectOscillometricPeakAction {
        in pressureHistory : PressureValue[*];
        in oscillationHistory : OscillationAmplitude[*];
        out maxOscillationPressure : PressureValue;
        out maxOscillationAmplitude : OscillationAmplitude;
    }
    
    action def CalculateBloodPressureAction {
        in maxOscillationPressure : PressureValue;
        in maxOscillationAmplitude : OscillationAmplitude;
        in pressureHistory : PressureValue[*];
        in oscillationHistory : OscillationAmplitude[*];
        out systolic : PressureValue;
        out diastolic : PressureValue;
        out meanArterial : PressureValue;
    }
    
    action def ControlledDeflationAction {
        in deflationRate : DeflationRate;
        in currentPressure : PressureValue;
        out newPressure : PressureValue;
    }
    
    action def DisplayResultsAction {
        in reading : BloodPressureReading;
    }
    
    action def MeasureBloodPressure {
        in targetInflationPressure : PressureValue;
        in controlledDeflationRate : DeflationRate;
        out finalReading : BloodPressureReading;
        
        private attribute pressureHistory : PressureValue[*] := ( );
        private attribute oscillationHistory : OscillationAmplitude[*] := ( );
        private attribute currentPressure : PressureValue;
        private attribute maxOscPressure : PressureValue;
        private attribute maxOscAmplitude : OscillationAmplitude;
        private attribute minimumPressure : PressureValue;
        
        first start;
        then merge beginMeasurement;
        
        then action inflate : InflateCuffAction {
            in targetPressure = targetInflationPressure;
            in currentPressure = 0.0;
            out finalPressure;
            out inflationComplete;
        }
        
        then assign currentPressure := inflate.finalPressure;
        
        then action deflateAndMonitor {
            action monitor : MonitorPressureAction {
                in cuffPressure = currentPressure;
                out pressureReading;
                out oscillationAmplitude;
            }
            then assign pressureHistory := SequenceFunctions::including(pressureHistory, monitor.pressureReading);
            then assign oscillationHistory := SequenceFunctions::including(oscillationHistory, monitor.oscillationAmplitude);
            
            then action deflate : ControlledDeflationAction {
                in deflationRate = controlledDeflationRate;
                in currentPressure = currentPressure;
                out newPressure;
            }
            then assign currentPressure := deflate.newPressure;
        }
        
        then action detectPeak : DetectOscillometricPeakAction {
            in pressureHistory = pressureHistory;
            in oscillationHistory = oscillationHistory;
            out maxOscillationPressure = maxOscPressure;
            out maxOscillationAmplitude = maxOscAmplitude;
        }
        
        then action calculate : CalculateBloodPressureAction {
            in maxOscillationPressure = maxOscPressure;
            in maxOscillationAmplitude = maxOscAmplitude;
            in pressureHistory = pressureHistory;
            in oscillationHistory = oscillationHistory;
            out systolic;
            out diastolic;
            out meanArterial;
        }
        
        then action assignResults {
            assign finalReading.systolic := calculate.systolic;
            assign finalReading.diastolic := calculate.diastolic;
            assign finalReading.meanArterialPressure := calculate.meanArterial;
            assign finalReading.pulseRate := 72.0;
        }
        
        then action display : DisplayResultsAction {
            in reading = finalReading;
        }
        
        then done;
    }
    
    part def Sphygmomanometer {
        part pump : PneumaticPump {
            attribute :>> maxPressure = 300.0;
            attribute :>> flowRate = 800.0;
        }
        
        part cuff : InflatableCuff {
            attribute :>> maxSafePressure = 300.0;
            attribute :>> armCircumference = 30.0;
        }
        
        part pressureTransducer : PressureTransducer {
            attribute :>> sensitivity = 0.1;
            attribute :>> accuracy = 2.0;
            attribute :>> samplingRate = 200.0;
        }
        
        part oscillationDetector : OscillationDetector {
            attribute :>> detectionThreshold = 1.0;
            attribute :>> filterCutoffFrequency = 20.0;
        }
        
        part valve : ExhaustValve {
            attribute :>> deflationRate = 3.0;
            attribute :>> isOpen = false;
        }
        
        part processor : MicroprocessorUnit {
            perform action measurementProcess : MeasureBloodPressure {
                in targetInflationPressure = 180.0;
                in controlledDeflationRate = 3.0;
                out finalReading;
            }
        }
        
        part display : LCDDisplay {
            attribute :>> brightness = 0.85;
        }
        
        part startButton : ControlButton;
        
        connection pumpToCuff connect pump.airOut to cuff.pneumaticIn;
        connection cuffToTransducer connect cuff.pneumaticIn to pressureTransducer.pneumaticMonitor;
        connection cuffToValve connect cuff.pneumaticIn to valve.pneumaticRelease;
        connection transducerToProcessor connect pressureTransducer.sensorOut to processor.pressureDataIn;
        connection oscillationToProcessor connect oscillationDetector.sensorOut to processor.oscillationDataIn;
        connection processorToDisplay connect processor.userInterface to display.dataIn;
        connection buttonToProcessor connect startButton.userInterface to processor.userInterface;
    }
    
    part sphygmomanometerDevice : Sphygmomanometer;
    
    requirement def AccuracyRequirement {
        doc /* The blood pressure measurement shall be accurate within ±3 mmHg 
                for systolic and diastolic pressure readings across the range 
                of 60 mmHg to 260 mmHg. */
        
        subject device : Sphygmomanometer;
        
        require constraint {
            device.pressureTransducer.accuracy <= 3.0
        }
    }
    
    requirement def SafetyRequirement {
        doc /* The cuff pressure shall not exceed 300 mmHg during any phase 
                of operation to ensure patient safety and prevent tissue damage. */
        
        subject device : Sphygmomanometer;
        
        require constraint {
            device.cuff.currentPressure <= device.cuff.maxSafePressure and
            device.cuff.maxSafePressure <= 300.0
        }
    }
    
    requirement def MeasurementTimeRequirement {
        doc /* The complete blood pressure measurement cycle, from initiation 
                to display of results, shall complete within 60 seconds under 
                normal operating conditions. */
        
        subject measurement : MeasureBloodPressure;
    }
    
    requirement def OscillometricMethodRequirement {
        doc /* The system shall employ the oscillometric method to determine 
                blood pressure by detecting arterial wall oscillations during 
                controlled cuff deflation. */
        
        subject device : Sphygmomanometer;
        
        require constraint {
            device.oscillationDetector.detectionThreshold <= 2.0
        }
    }
    
    requirement <'SPHYG-REQ-001'> primaryFunctionRequirement {
        doc /* The sphygmomanometer system shall non-invasively measure and display 
                arterial blood pressure (systolic, diastolic, and mean arterial pressure) 
                and pulse rate by inflating an arm cuff to occlude blood flow, then 
                detecting oscillometric pressure variations during controlled deflation 
                to determine cardiovascular parameters with clinical-grade accuracy. */
        
        subject system : Sphygmomanometer;
        
        require accuracyReq : AccuracyRequirement;
        require safetyReq : SafetyRequirement;
        require timeReq : MeasurementTimeRequirement;
        require methodReq : OscillometricMethodRequirement;
        
        assume constraint validPatientConditions {
            system.cuff.armCircumference >= 22.0 and
            system.cuff.armCircumference <= 42.0
        }
        
        assume constraint environmentalConditions {
            doc /* Measurements shall be performed in controlled environment 
                    with temperature 15-35°C and relative humidity 15-85%. */
        }
    }
}
