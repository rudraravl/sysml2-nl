package DopplerRadarSystem {
    private import ScalarValues::Real;
    private import ScalarValues::String;
    private import ScalarValues::Boolean;
    private import Quantities::ScalarQuantityValue;

    attribute def DistanceValue :> ScalarQuantityValue;
    attribute def VelocityValue :> ScalarQuantityValue;
    attribute def FrequencyValue :> ScalarQuantityValue;
    attribute def PowerValue :> ScalarQuantityValue;
    attribute def DurationValue :> ScalarQuantityValue;
    attribute def SignalStrengthValue :> ScalarQuantityValue;
    attribute def RateValue :> ScalarQuantityValue;

    item def TrackCommand;
    item def ScanCommand;
    item def PulseCommand;

    item def ModeCommand {
        attribute mode : String;
    }

    item def RFSignal {
        attribute frequency : FrequencyValue;
        attribute power : PowerValue;
    }

    item def EchoSignal {
        attribute frequency : FrequencyValue;
        attribute power : PowerValue;
        attribute timeDelay : DurationValue;
    }

    item def RadarData {
        attribute range : DistanceValue;
        attribute velocity : VelocityValue;
        attribute signalStrength : SignalStrengthValue;
    }

    part def SystemController {
        port controlPort {
            out modeCmd : ModeCommand;
        }
        
        state def ControllerBehavior {
            entry; then Scanning;
            state Scanning;
            accept TrackCommand then Tracking;
            state Tracking;
            accept ScanCommand then Scanning;
            accept PulseCommand then Pulsing;
            state Pulsing;
            accept ScanCommand then Scanning;
        }
        
        state controllerState : ControllerBehavior;
    }

    part def RFTransmitter {
        port controlPort {
            in modeCmd : ModeCommand;
        }
        port txPort {
            out txSignal : RFSignal;
        }
        port refPort {
            out refSignal : RFSignal;
        }
        
        action generateSignal {
            out signal : RFSignal;
        }
    }

    part def AntennaAssembly {
        port txPort {
            in txSignal : RFSignal;
        }
        port rxPort {
            out rxSignal : EchoSignal;
        }
    }

    part def RFReceiver {
        port rxPort {
            in rxSignal : EchoSignal;
        }
        port echoPort {
            out echoSignal : EchoSignal;
        }
        
        action processEcho {
            in rawEcho : EchoSignal;
            out cleanEcho : EchoSignal;
        }
    }

    part def DopplerProcessor {
        port refPort {
            in refSignal : RFSignal;
        }
        port echoPort {
            in echoSignal : EchoSignal;
        }
        port dataPort {
            out data : RadarData;
        }
        
        action calculateRange {
            in echo : EchoSignal;
            out range : DistanceValue;
        }
        
        action calculateVelocity {
            in ref : RFSignal;
            in echo : EchoSignal;
            out velocity : VelocityValue;
        }
        
        action assessConfidence {
            in echo : EchoSignal;
            out strength : SignalStrengthValue;
        }
        
        action processData {
            in ref : RFSignal;
            in echo : EchoSignal;
            out data : RadarData;
            
            perform calcRange : calculateRange {
                in echo = echo;
                out range = data.range;
            }
            then perform calcVel : calculateVelocity {
                in ref = ref;
                in echo = echo;
                out velocity = data.velocity;
            }
            then perform calcConf : assessConfidence {
                in echo = echo;
                out strength = data.signalStrength;
            }
        }
    }

    part def DisplayUnit {
        port dataPort {
            in data : RadarData;
        }
        
        action displayData {
            in data : RadarData;
        }
    }

    part def DopplerRadar {
        part controller : SystemController;
        part transmitter : RFTransmitter;
        part antenna : AntennaAssembly;
        part receiver : RFReceiver;
        part processor : DopplerProcessor;
        part display : DisplayUnit;
        
        flow controlFlow of ModeCommand from controller.controlPort.modeCmd to transmitter.controlPort.modeCmd;
        flow txFlow of RFSignal from transmitter.txPort.txSignal to antenna.txPort.txSignal;
        flow rxFlow of EchoSignal from antenna.rxPort.rxSignal to receiver.rxPort.rxSignal;
        flow refFlow of RFSignal from transmitter.refPort.refSignal to processor.refPort.refSignal;
        flow echoFlow of EchoSignal from receiver.echoPort.echoSignal to processor.echoPort.echoSignal;
        flow dataFlow of RadarData from processor.dataPort.data to display.dataPort.data;
    }

    requirement def RealTimeTracking {
        attribute updateRate : Real;
        constraint { updateRate >= 20 }
    }

    requirement def OperationalRange {
        attribute maxRange : Real;
        constraint { maxRange <= 10 }
    }

    requirement radarRequirements {
        requirement realTimeTracking : RealTimeTracking;
        requirement operationalRange : OperationalRange;
    }
}
