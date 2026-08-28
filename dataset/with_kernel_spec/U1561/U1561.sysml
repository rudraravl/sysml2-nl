package DSNGroundStation {
    private import ISQ::*;
    private import ScalarValues::String;
    private import ScalarValues::Boolean;
    
    alias Length for ISQ::LengthValue;
    alias Power for ISQ::PowerValue;
    alias Distance for ISQ::LengthValue;
    alias Velocity for ISQ::SpeedValue;
    alias Frequency for ISQ::FrequencyValue;
    alias Angle for ISQ::AngleValue;
    alias Temperature for ISQ::ThermodynamicTemperatureValue;
    
    attribute def SpacecraftCommand;
    attribute def TelemetryData;
    attribute def HealthStatus;
    
    attribute def AntennaPosition {
        attribute azimuth : Angle;
        attribute elevation : Angle;
    }
    
    attribute def RadioSignal {
        attribute power : Power;
        attribute frequency : Frequency;
    }
    
    attribute def TrackingMetrics {
        attribute distance : Distance;
        attribute velocity : Velocity;
    }
    
    attribute def SigActivate;
    attribute def SigDeactivate;
    attribute def SigReceiveOnly;
    attribute def SigTransmitOnly;
    attribute def SigDuplex;
    
    requirement def HighAvailabilityRequirement {
        doc /* The entire facility is engineered for high availability to support critical mission events at any time. */
    }
    
    requirement def TrackingAccuracyRequirement {
        doc /* The tracking subsystem must lock onto the signal and measure distance and velocity with extreme accuracy. */
    }
    
    requirement def ReceiveSensitivityRequirement {
        doc /* The receiver subsystem must detect incredibly faint signals using a cryogenically cooled low-noise amplifier. */
    }
    
    requirement def AntennaSpecRequirement {
        doc /* The primary antenna shall be a 70-meter steerable dish. */
        attribute diameter : Length;
        constraint diameter == 70 [m];
    }
    
    requirement def TransmitterSpecRequirement {
        doc /* The transmitter subsystem shall utilize a 20-kilowatt klystron amplifier. */
        attribute power : Power;
        constraint power == 20 [kW];
    }
    
    part def GroundStation {
        attribute stationId : String;
        
        part antenna : Antenna {
            satisfy AntennaSpecRequirement;
        }
        part positioningSystem : PositioningSystem;
        part monitorControl : MonitorControl;
        part trackingSubsystem : TrackingSubsystem {
            satisfy TrackingAccuracyRequirement;
        }
        part transmitter : Transmitter {
            satisfy TransmitterSpecRequirement;
        }
        part receiver : Receiver {
            satisfy ReceiveSensitivityRequirement;
        }
        part signalProcessor : SignalProcessor;
        
        flow commandFlow of SpacecraftCommand 
            from monitorControl.commandPort.command to transmitter.commandPort.command;
        flow trackingPositionFlow of AntennaPosition 
            from trackingSubsystem.positionPort.position to positioningSystem.commandPort.command;
        flow antennaControlFlow of AntennaPosition 
            from positioningSystem.outPort.position to antenna.commandPort.position;
        flow rfTransmitFlow of RadioSignal 
            from transmitter.rfOutPort.rfOut to antenna.rfInPort.rfIn;
        flow rfReceiveFlow of RadioSignal 
            from antenna.rfOutPort.rfOut to receiver.rfInPort.rfIn;
        flow rfTrackingFlow of RadioSignal
            from antenna.rfOutPort.rfOut to trackingSubsystem.rfPort.rfSignal;
        flow telemetryFlow of TelemetryData 
            from receiver.telemetryPort.telemetry to signalProcessor.telemetryPort.telemetry;
        flow processedTelemetryFlow of TelemetryData 
            from signalProcessor.dataPort.data to monitorControl.telemetryPort.telemetry;
        flow trackingMetricsFlow of TrackingMetrics 
            from trackingSubsystem.metricsPort.metrics to monitorControl.metricsPort.metrics;
        
        state stationStates {
            entry; then off;
            state off;
            accept SigActivate then standby;
            state standby;
            accept SigReceiveOnly then receiveOnly;
            accept SigTransmitOnly then transmitOnly;
            accept SigDuplex then duplex;
            accept SigDeactivate then off;
            
            state receiveOnly {
                do action receiveData;
            }
            state transmitOnly {
                do action transmitCommands;
            }
            state duplex {
                do action receiveData;
                do action transmitCommands;
            }
        }
        
        action receiveData;
        action transmitCommands;
    }
    
    part def Antenna {
        attribute diameter : Length = 70 [m];
        port rfInPort {
            in rfIn : RadioSignal;
        }
        port rfOutPort {
            out rfOut : RadioSignal;
        }
        port commandPort {
            in position : AntennaPosition;
        }
        attribute health : HealthStatus;
        action aim;
    }
    
    part def PositioningSystem {
        port commandPort {
            in command : AntennaPosition;
        }
        port outPort {
            out position : AntennaPosition;
        }
        action aimAntenna;
    }
    
    part def MonitorControl {
        port telemetryPort {
            in telemetry : TelemetryData;
        }
        port metricsPort {
            in metrics : TrackingMetrics;
        }
        port commandPort {
            out command : SpacecraftCommand;
        }
        action scheduleTrackingPass;
        action checkHealth;
    }
    
    part def TrackingSubsystem {
        port rfPort {
            in rfSignal : RadioSignal;
        }
        port metricsPort {
            out metrics : TrackingMetrics;
        }
        port positionPort {
            out position : AntennaPosition;
        }
        action acquireSignal;
        action lockOnSignal;
    }
    
    part def Transmitter {
        attribute power : Power = 20 [kW];
        port commandPort {
            in command : SpacecraftCommand;
        }
        port rfOutPort {
            out rfOut : RadioSignal;
        }
        part klystronAmplifier {
            attribute powerRating : Power = 20 [kW];
            action amplify;
        }
        action generateSignal;
    }
    
    part def Receiver {
        port rfInPort {
            in rfIn : RadioSignal;
        }
        port telemetryPort {
            out telemetry : TelemetryData;
        }
        part lowNoiseAmplifier {
            attribute isCryogenicallyCooled : Boolean = true;
            attribute coolingTemperature : Temperature = 4.0 [K];
            action amplifySignal;
        }
        action detectSignal;
    }
    
    part def SignalProcessor {
        port telemetryPort {
            in telemetry : TelemetryData;
        }
        port dataPort {
            out data : TelemetryData;
        }
        action digitize;
        action decode;
        action record;
    }
    
    part groundStation : GroundStation {
        satisfy HighAvailabilityRequirement;
    }
}
