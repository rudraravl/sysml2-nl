package DopplerRadarSystem {
    import ISQ::*;
    import ScalarValues::*;

    value def Distance :> Real { unit 'm'; }
    value def Velocity :> Real { unit 'm/s'; }
    value def Frequency :> Real { unit 'Hz'; }
    value def Power :> Real { unit 'W'; }
    value def Time :> Real { unit 's'; }
    value def Dimensionless :> Real { }
    value def UpdateRate :> Real { unit 'Hz'; }

    enum def RadarMode {
        continuousScanning;
        pulsing;
        tracking;
    }

    item def RFSignal {
        attribute frequency : Frequency;
        attribute power : Power;
        attribute phase : Real;
    }
    
    item def EchoSignal {
        attribute frequency : Frequency;
        attribute power : Power;
        attribute phase : Real;
        attribute timeOfFlight : Time;
    }
    
    item def TargetData {
        attribute range : Distance;
        attribute radialVelocity : Velocity;
        attribute signalStrength : Power;
        attribute confidence : Dimensionless;
    }
    
    item def ControlCommand {
        attribute mode : RadarMode;
    }

    requirement def RadarSystemRequirements {
        requirement operationalRange {
            doc "The system must detect targets up to 10 km."
            attribute maxRange : Distance = 10000 [m];
        }
        requirement updateRate {
            doc "The system must update at least 20 times per second."
            attribute minUpdateRate : UpdateRate = 20 [Hz];
        }
    }

    part def DopplerRadar {
        satisfy RadarSystemRequirements;
        
        part controller : SystemController;
        part transmitter : RFTransmitter;
        part antenna : AntennaAssembly;
        part receiver : RFReceiver;
        part processor : DopplerProcessor;
        part display : DisplayUnit;
        
        connect controller.cmdPort to transmitter.cmdPort;
        connect controller.cmdPort to processor.cmdPort;
        
        connect transmitter.refPort to processor.refPort;
        connect transmitter.outPort to antenna.txPort;
        
        connect antenna.rxPort to receiver.inPort;
        connect receiver.outPort to processor.echoPort;
        
        connect processor.dataPort to display.dataPort;
    }

    part def SystemController {
        attribute currentMode : RadarMode = RadarMode::continuousScanning;
        
        port cmdPort : out ControlCommand;
        
        exhibit state ControllerBehavior {
            entry; then chooseMode;
            
            state chooseMode;
            
            transition from chooseMode to continuousScanningMode when currentMode == RadarMode::continuousScanning;
            transition from chooseMode to pulsingMode when currentMode == RadarMode::pulsing;
            transition from chooseMode to trackingMode when currentMode == RadarMode::tracking;
            
            state continuousScanningMode {
                entry action sendContinuousCommand {
                    cmdPort.send(ControlCommand{mode = RadarMode::continuousScanning});
                }
            }
            state pulsingMode {
                entry action sendPulseCommand {
                    cmdPort.send(ControlCommand{mode = RadarMode::pulsing});
                }
            }
            state trackingMode {
                entry action sendTrackingCommand {
                    cmdPort.send(ControlCommand{mode = RadarMode::tracking});
                }
            }
        }
    }

    part def RFTransmitter {
        port cmdPort : in ControlCommand;
        port outPort : out RFSignal;
        port refPort : out RFSignal;
        
        attribute transmitPower : Power = 100 [W];
        attribute transmitFrequency : Frequency = 10e9 [Hz];
        
        exhibit action GenerateSignal {
            in cmd : ControlCommand;
            out signal : RFSignal;
            out ref : RFSignal;
            
            action generateRF {
                out signal = RFSignal{frequency = transmitFrequency, power = transmitPower, phase = 0.0};
                out ref = RFSignal{frequency = transmitFrequency, power = transmitPower, phase = 0.0};
            }
        }
    }

    part def AntennaAssembly {
        port txPort : in RFSignal;
        port rxPort : out EchoSignal;
        
        exhibit action DirectAndCapture {
            in txSignal : RFSignal;
            out rxSignal : EchoSignal;
            
            action radiate {
                in txSignal;
            }
            action capture {
                out rxSignal;
            }
        }
    }

    part def RFReceiver {
        port inPort : in EchoSignal;
        port outPort : out EchoSignal;
        
        exhibit action ProcessEcho {
            in rawEcho : EchoSignal;
            out cleanEcho : EchoSignal;
            
            action amplify {
                in rawEcho;
                out amplified : EchoSignal;
            }
            action filter {
                in amplified;
                out cleanEcho;
            }
            
            flow amplify.amplified to filter.amplified;
        }
    }

    part def DopplerProcessor {
        port cmdPort : in ControlCommand;
        port refPort : in RFSignal;
        port echoPort : in EchoSignal;
        port dataPort : out TargetData;
        
        exhibit action CalculateTargetData {
            in refSignal : RFSignal;
            in echoSignal : EchoSignal;
            out targetData : TargetData;
            
            attribute speedOfLight : Velocity = 299792458 [m/s];
            
            action calculateRange {
                in tof : Time = echoSignal.timeOfFlight;
                out range : Distance = (tof * speedOfLight) / 2;
            }
            action calculateVelocity {
                in fRef : Frequency = refSignal.frequency;
                in fEcho : Frequency = echoSignal.frequency;
                out radialVelocity : Velocity = ((fEcho - fRef) * speedOfLight) / (2 * fRef);
            }
            action calculateConfidence {
                in power : Power = echoSignal.power;
                out confidence : Dimensionless = power / 1e-12 [W];
            }
            action assembleData {
                in range : Distance;
                in radialVelocity : Velocity;
                in signalStrength : Power = echoSignal.power;
                in confidence : Dimensionless;
                out targetData = TargetData{range = range, radialVelocity = radialVelocity, signalStrength = signalStrength, confidence = confidence};
            }
            
            flow calculateRange.range to assembleData.range;
            flow calculateVelocity.radialVelocity to assembleData.radialVelocity;
            flow calculateConfidence.confidence to assembleData.confidence;
        }
    }

    part def DisplayUnit {
        port dataPort : in TargetData;
        
        exhibit action DisplayData {
            in data : TargetData;
            
            action render {
                in data;
            }
        }
    }
}
