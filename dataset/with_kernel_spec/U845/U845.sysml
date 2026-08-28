package HandheldRadarGun {
    import ScalarValues::*;
    
    attribute def FrequencyValue;
    attribute def SpeedValue;
    attribute def DistanceValue;
    attribute def VoltageValue;
    attribute def CurrentValue;
    attribute def DurationValue;
    
    item def TriggerSignal;
    item def PowerOnSignal;
    item def PowerOffSignal;
    item def MeasurementCompleteSignal;
    
    item def PowerFlow {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }
    
    item def RadarPulse {
        attribute frequency : FrequencyValue;
        attribute transmitTime : DurationValue;
    }
    
    item def EchoSignal {
        attribute frequency : FrequencyValue;
        attribute receiveTime : DurationValue;
    }
    
    item def ProcessedEcho {
        attribute amplitude : Real;
    }
    
    item def SpeedReading {
        attribute speed : SpeedValue;
        attribute distance : DistanceValue;
        attribute isValid : Boolean;
        attribute errorCode : Integer;
    }
    
    action def GeneratePulse {
        out item pulse : RadarPulse;
        out item pulseData : RadarPulse;
    }
    
    action def ReceiveAndAmplify {
        in item echo : EchoSignal;
        out item amplifiedEcho : ProcessedEcho;
    }
    
    action def ProcessSignal {
        in item pulseData : RadarPulse;
        in item amplifiedEcho : ProcessedEcho;
        out item result : SpeedReading;
        out item complete : MeasurementCompleteSignal;
    }
    
    action def ShowResult {
        in item result : SpeedReading;
    }
    
    state def ControlUnitStates;
    
    part def PowerSupply {
        port powerOutPort {
            out item power : PowerFlow;
        }
    }
    
    part def ControlUnit {
        port powerInPort {
            in item power : PowerFlow;
        }
        port powerSwitchIn {
            in item powerOn : PowerOnSignal;
            in item powerOff : PowerOffSignal;
        }
        port triggerIn {
            in item trigger : TriggerSignal;
        }
        port txCtrlPort {
            out item fireSignal : TriggerSignal;
        }
        port completionIn {
            in item complete : MeasurementCompleteSignal;
        }
        state controlUnitStates : ControlUnitStates {
            entry; then off;
            state off;
            accept PowerOnSignal then on;
            state on;
            accept TriggerSignal then measuring;
            accept PowerOffSignal then off;
            state measuring;
            accept MeasurementCompleteSignal then on;
        }
    }
    
    part def TransmitterModule {
        port powerInPort {
            in item power : PowerFlow;
        }
        port ctrlPort {
            in item fireSignal : TriggerSignal;
        }
        port txPort {
            out item pulse : RadarPulse;
        }
        port txDataPort {
            out item pulseData : RadarPulse;
        }
        perform action generatePulse : GeneratePulse {
            out pulse = txPort.pulse;
            out pulseData = txDataPort.pulseData;
        }
    }
    
    part def Antenna {
        port txPort {
            in item pulse : RadarPulse;
        }
        port rxPort {
            out item echo : EchoSignal;
        }
    }
    
    part def ReceiverModule {
        port powerInPort {
            in item power : PowerFlow;
        }
        port rxPort {
            in item echo : EchoSignal;
        }
        port rxDataPort {
            out item amplifiedEcho : ProcessedEcho;
        }
        perform action receiveAndAmplify : ReceiveAndAmplify {
            in echo = rxPort.echo;
            out amplifiedEcho = rxDataPort.amplifiedEcho;
        }
    }
    
    part def SignalProcessingUnit {
        port powerInPort {
            in item power : PowerFlow;
        }
        port txDataPort {
            in item pulseData : RadarPulse;
        }
        port rxDataPort {
            in item amplifiedEcho : ProcessedEcho;
        }
        port resultPort {
            out item result : SpeedReading;
            out item complete : MeasurementCompleteSignal;
        }
        perform action processSignal : ProcessSignal {
            in pulseData = txDataPort.pulseData;
            in amplifiedEcho = rxDataPort.amplifiedEcho;
            out result = resultPort.result;
            out complete = resultPort.complete;
            
            first start;
            then action compareSignals;
            then action calculateDopplerShift;
            then action estimateDistance;
            then action validateMeasurement;
            then done;
        }
    }
    
    part def DisplayModule {
        port powerInPort {
            in item power : PowerFlow;
        }
        port resultPort {
            in item result : SpeedReading;
        }
        perform action showResult : ShowResult {
            in result = resultPort.result;
        }
    }
    
    part def RadarGun {
        part powerSupply : PowerSupply;
        part controlUnit : ControlUnit;
        part transmitter : TransmitterModule;
        part antenna : Antenna;
        part receiver : ReceiverModule;
        part signalProcessor : SignalProcessingUnit;
        part display : DisplayModule;
        
        connect powerSupply.powerOutPort to controlUnit.powerInPort;
        connect powerSupply.powerOutPort to transmitter.powerInPort;
        connect powerSupply.powerOutPort to receiver.powerInPort;
        connect powerSupply.powerOutPort to signalProcessor.powerInPort;
        connect powerSupply.powerOutPort to display.powerInPort;
        
        connect controlUnit.txCtrlPort to transmitter.ctrlPort;
        
        connect transmitter.txPort to antenna.txPort;
        connect antenna.rxPort to receiver.rxPort;
        
        connect transmitter.txDataPort to signalProcessor.txDataPort;
        connect receiver.rxDataPort to signalProcessor.rxDataPort;
        
        connect signalProcessor.resultPort to display.resultPort;
        connect signalProcessor.resultPort to controlUnit.completionIn;
    }
    
    requirement def DetectionRangeRequirement {
        doc /* The radar gun must detect targets up to 500 meters away. */
        attribute maxRange : DistanceValue;
    }
    
    requirement def SpeedRangeRequirement {
        doc /* The radar gun must measure speeds from 1.4 m/s to 111 m/s. */
        attribute minSpeed : SpeedValue;
        attribute maxSpeed : SpeedValue;
    }
    
    requirement def OperatingFrequencyRequirement {
        doc /* The transmitter shall operate at a radio frequency of approximately 24.15 GHz. */
        attribute frequency : FrequencyValue;
    }
    
    requirement detectionRange : DetectionRangeRequirement {
        :>> maxRange = 500;
    }
    
    requirement speedRange : SpeedRangeRequirement {
        :>> minSpeed = 1.4;
        :>> maxSpeed = 111;
    }
    
    requirement operatingFrequency : OperatingFrequencyRequirement {
        :>> frequency = 24.15;
    }
    
    part handheldRadarGun : RadarGun {
        satisfy detectionRange;
        satisfy speedRange;
        satisfy operatingFrequency;
    }
}
