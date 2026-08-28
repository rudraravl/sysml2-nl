package UltrasonicParkingSensor {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    package Definitions {
        private import ScalarValues::*;
        private import ISQ::*;
        private import SI::*;
        
        attribute def DistanceValue :> ISQ::length;
        attribute def TimeValue :> ISQ::time;
        attribute def TemperatureValue :> ISQ::temperature;
        attribute def FrequencyValue :> ISQ::frequency;
        attribute def ConfidenceScore :> ScalarValues::Real;
        attribute def VoltageValue :> ScalarValues::Real;
        
        item def PowerSignal {
            attribute voltage : VoltageValue;
        }
        item def TriggerSignal;
        item def UltrasonicPulse {
            attribute frequency : FrequencyValue;
        }
        item def EchoSignal {
            attribute amplitude : ScalarValues::Real;
            attribute timeOfFlight : TimeValue;
        }
        
        enum def DetectionStatus {
            obstaclePresent;
            noObstacle;
            unknown;
        }
        enum def ErrorCode {
            none;
            hardwareFault;
            outOfRange;
        }
        
        item def MeasurementData {
            attribute distance : DistanceValue;
            attribute status : DetectionStatus;
            attribute confidence : ConfidenceScore;
        }
        item def DiagnosticData {
            attribute temperature : TemperatureValue;
            attribute errorCode : ErrorCode;
        }
        
        attribute def Activate;
        attribute def Fault;
        attribute def Recover;
        
        port def PowerPort { in power : PowerSignal; }
        port def DataPort { out data : MeasurementData; }
        port def DiagnosticPort { out diag : DiagnosticData; }
        port def TransducerPort { out pulse : UltrasonicPulse; in echo : EchoSignal; }
        port def TempSensorPort { out temp : TemperatureValue; }
        port def SignalProcPort { in echo : EchoSignal; out timeOfFlight : TimeValue; out echoStrength : ScalarValues::Real; }
        port def ControlUnitPort { in timeOfFlight : TimeValue; in echoStrength : ScalarValues::Real; in temp : TemperatureValue; }
        port def ControlToTransducerPort { out trigger : TriggerSignal; }
        port def TransducerControlPort { in trigger : TriggerSignal; }
        
        action def TransmitPulse { out pulse : UltrasonicPulse; }
        action def ListenEcho { in echo : EchoSignal; out timeOfFlight : TimeValue; out echoStrength : ScalarValues::Real; }
        action def CalculateDistance { in timeOfFlight : TimeValue; in temp : TemperatureValue; out distance : DistanceValue; }
        action def ValidateMeasurement { in distance : DistanceValue; in echoStrength : ScalarValues::Real; out status : DetectionStatus; out confidence : ConfidenceScore; }
        action def SenseTemperature { out temp : TemperatureValue; }
        
        state def SensorStates;
        
        part def UltrasonicTransducer {
            attribute frequency : FrequencyValue;
            port transducerPort : TransducerPort;
            port controlPort : TransducerControlPort;
            perform action transmitPulse : TransmitPulse;
            perform action listenEcho : ListenEcho;
        }
        part def SignalProcessor {
            port procPort : SignalProcPort;
            perform action calculateDistance : CalculateDistance;
            perform action validateMeasurement : ValidateMeasurement;
        }
        part def ControlUnit {
            port dataPort : DataPort;
            port diagPort : DiagnosticPort;
            port cuPort : ControlUnitPort;
            port transducerControlPort : ControlToTransducerPort;
            exhibit state sensorStates : SensorStates;
        }
        part def TemperatureSensor {
            port tempPort : TempSensorPort;
            perform action senseTemperature : SenseTemperature;
        }
        part def ParkingSensorUnit {
            attribute minRange : DistanceValue;
            attribute maxRange : DistanceValue;
            attribute accuracy : DistanceValue;
            attribute minOperatingTemp : TemperatureValue;
            attribute maxOperatingTemp : TemperatureValue;
            
            port powerPort : PowerPort;
            port dataPort : DataPort;
            port diagPort : DiagnosticPort;
            
            part transducer : UltrasonicTransducer;
            part signalProcessor : SignalProcessor;
            part controlUnit : ControlUnit;
            part tempSensor : TemperatureSensor;
            
            flow triggerFlow of TriggerSignal from controlUnit.transducerControlPort.trigger to transducer.controlPort.trigger;
            flow echoFlow of EchoSignal from transducer.transducerPort.echo to signalProcessor.procPort.echo;
            flow tempFlow of TemperatureValue from tempSensor.tempPort.temp to controlUnit.cuPort.temp;
        }
        
        requirement def FrequencyRangeReq {
            attribute minFreq : FrequencyValue = 40 [kHz];
            attribute maxFreq : FrequencyValue = 48 [kHz];
            subject sensor : ParkingSensorUnit;
            require constraint { sensor.transducer.frequency >= minFreq and sensor.transducer.frequency <= maxFreq }
        }
        requirement def DetectionRangeReq {
            attribute minDist : DistanceValue = 15 [cm];
            attribute maxDist : DistanceValue = 2.5 [m];
            subject sensor : ParkingSensorUnit;
            require constraint { sensor.maxRange <= maxDist and sensor.minRange >= minDist }
        }
        requirement def AccuracyReq {
            attribute maxError : DistanceValue = 3 [cm];
            subject sensor : ParkingSensorUnit;
            require constraint { sensor.accuracy <= maxError }
        }
        requirement def TempRangeReq {
            attribute minTemp : TemperatureValue = -40 [degC];
            attribute maxTemp : TemperatureValue = 85 [degC];
            subject sensor : ParkingSensorUnit;
            require constraint { sensor.maxOperatingTemp <= maxTemp and sensor.minOperatingTemp >= minTemp }
        }
    }
    
    package Usages {
        private import Definitions::*;
        
        action 'transmit pulse' : TransmitPulse;
        action 'listen echo' : ListenEcho;
        action 'calculate distance' : CalculateDistance;
        action 'validate measurement' : ValidateMeasurement;
        
        state 'sensor states' : SensorStates {
            entry; then idle;
            state idle;
            accept Activate then active;
            state active {
                entry 'transmit pulse';
                do 'listen echo';
            }
            accept Fault then fault;
            state fault;
            accept Recover then idle;
        }
        
        part rearParkingSensor : ParkingSensorUnit {
            attribute minRange : DistanceValue = 15 [cm];
            attribute maxRange : DistanceValue = 2.5 [m];
            attribute accuracy : DistanceValue = 3 [cm];
            attribute minOperatingTemp : TemperatureValue = -40 [degC];
            attribute maxOperatingTemp : TemperatureValue = 85 [degC];
            
            part transducer : UltrasonicTransducer {
                attribute frequency : FrequencyValue = 40 [kHz];
            }
        }
        
        requirement freqReq : FrequencyRangeReq;
        requirement rangeReq : DetectionRangeReq;
        requirement accReq : AccuracyReq;
        requirement tempReq : TempRangeReq;
        
        satisfy freqReq by rearParkingSensor;
        satisfy rangeReq by rearParkingSensor;
        satisfy accReq by rearParkingSensor;
        satisfy tempReq by rearParkingSensor;
    }
}
