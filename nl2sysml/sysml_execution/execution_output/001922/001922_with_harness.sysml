package NASA_DeepSpaceNetwork_System {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def FrequencyValue :> Real;
    attribute def DataRateValue :> Real;
    attribute def AngleValue :> Real;
    attribute def DistanceValue :> LengthValue;
    attribute def TemperatureValue :> Real;
    attribute def GainValue :> Real;
    attribute def VoltageValue :> Real;
    attribute def CurrentValue :> Real;
    
    enum def AntennaSize {
        small_34m;
        large_70m;
    }
    
    enum def FrequencyBand {
        s_band;
        x_band;
        ka_band;
    }
    
    enum def TrackingStatus {
        idle;
        acquiring;
        tracking;
        lost_signal;
    }
    
    enum def OperationalMode {
        receive_only;
        transmit_only;
        duplex;
        standby;
    }
    
    item def SpacecraftSignal {
        attribute frequency : FrequencyValue;
        attribute dataRate : DataRateValue;
        attribute signalStrength : Real;
        attribute timestamp : Real;
    }
    
    item def GroundCommand {
        attribute commandId : String;
        attribute targetSpacecraft : String;
        attribute priority : Real;
        attribute transmitPower : PowerValue;
    }
    
    item def TelemetryData {
        attribute spacecraftId : String;
        attribute dataVolume : Real;
        attribute receivedTime : Real;
        attribute quality : Real;
    }
    
    port def RFPort {
        in uplinkSignal : GroundCommand;
        out downlinkSignal : SpacecraftSignal;
    }
    
    port def DataPort {
        in commandData : GroundCommand;
        out telemetryData : TelemetryData;
    }
    
    port def PowerPort {
        out voltage : VoltageValue;
        out current : CurrentValue;
        out power : PowerValue;
    }
    
    port def ControlPort {
        in pointingCommand : AngleValue;
        in modeCommand : OperationalMode;
        out status : TrackingStatus;
    }
    
    part def AntennaSubsystem {
        attribute diameter : LengthValue;
        attribute azimuthAngle : AngleValue;
        attribute elevationAngle : AngleValue;
        attribute gain : GainValue;
        attribute pointingAccuracy : AngleValue;
        
        part reflectorDish {
            attribute surfaceAccuracy : LengthValue;
            attribute efficiency : Real;
        }
        
        part feedHorn {
            attribute operatingBand : FrequencyBand;
            attribute beamwidth : AngleValue;
        }
        
        part positioner {
            attribute azimuthRange : AngleValue;
            attribute elevationRange : AngleValue;
            attribute slewRate : Real;
        }
    }
    
    part def TransmitterSubsystem {
        attribute outputPower : PowerValue;
        attribute frequency : FrequencyValue;
        attribute efficiency : Real;
        
        part klystronAmplifier {
            attribute maxPower : PowerValue;
            attribute operatingTemp : TemperatureValue;
        }
        
        part upconverter {
            attribute inputFrequency : FrequencyValue;
            attribute outputFrequency : FrequencyValue;
        }
        
        part waveguide {
            attribute loss : Real;
            attribute length : LengthValue;
        }
    }
    
    part def ReceiverSubsystem {
        attribute sensitivity : Real;
        attribute noiseTemperature : TemperatureValue;
        attribute bandwidth : FrequencyValue;
        
        part lowNoiseAmplifier {
            attribute gain : GainValue;
            attribute noiseTemp : TemperatureValue;
        }
        
        part downconverter {
            attribute inputFrequency : FrequencyValue;
            attribute outputFrequency : FrequencyValue;
        }
        
        part demodulator {
            attribute dataRate : DataRateValue;
            attribute bitErrorRate : Real;
        }
    }
    
    part def SignalProcessingSubsystem {
        attribute processingCapacity : DataRateValue;
        
        part digitizer {
            attribute samplingRate : FrequencyValue;
            attribute resolution : Real;
        }
        
        part decoder {
            attribute supportedFormats : String;
            attribute throughput : DataRateValue;
        }
        
        part dataRecorder {
            attribute storageCapacity : Real;
            attribute writeSpeed : DataRateValue;
        }
    }
    
    part def TrackingSubsystem {
        attribute trackingAccuracy : AngleValue;
        
        part radioMetric {
            attribute rangeAccuracy : DistanceValue;
            attribute dopplerAccuracy : Real;
        }
        
        part angleTracking {
            attribute azimuthAccuracy : AngleValue;
            attribute elevationAccuracy : AngleValue;
        }
        
        part predictor {
            attribute ephemerisAccuracy : DistanceValue;
        }
    }
    
    part def MonitorControlSubsystem {
        attribute responseTime : Real;
        
        part stationController {
            attribute processingSpeed : Real;
            attribute memory : Real;
        }
        
        part healthMonitor {
            attribute sensorCount : Real;
            attribute updateRate : Real;
        }
        
        part scheduler {
            attribute maxTracks : Real;
        }
    }
    
    action def AcquireSpacecraft {
        in spacecraftEphemeris : Real;
        in frequency : FrequencyValue;
        out acquisitionSuccess : Boolean;
        out signalLock : Boolean;
    }
    
    action def TrackSpacecraft {
        in currentPosition : AngleValue;
        in predictedPosition : AngleValue;
        out azimuthCommand : AngleValue;
        out elevationCommand : AngleValue;
    }
    
    action def ReceiveTelemetry {
        in signal : SpacecraftSignal;
        out telemetry : TelemetryData;
        out dataQuality : Real;
    }
    
    action def TransmitCommand {
        in command : GroundCommand;
        in targetAzimuth : AngleValue;
        in targetElevation : AngleValue;
        out transmitSuccess : Boolean;
    }
    
    action def ProcessSignal {
        in rawSignal : SpacecraftSignal;
        out decodedData : TelemetryData;
        out signalMetrics : Real;
    }
    
    action def MonitorHealth {
        in subsystemStatus : TrackingStatus;
        out healthReport : Boolean;
        out alertLevel : Real;
    }
    
    action def DeepSpaceNetworkOperations {
        first start;
        then merge continuousOperations;
        
        then action healthCheck : MonitorHealth {
            in subsystemStatus;
            out healthReport;
            out alertLevel;
        }
        
        then decide;
            if healthReport and trackScheduled then beginTracking;
            if healthReport and not trackScheduled then standbyMode;
            if not healthReport then safeModeOperations;
        
        action beginTracking {
            first action acquireTarget : AcquireSpacecraft {
                in spacecraftEphemeris;
                in frequency;
                out acquisitionSuccess;
                out signalLock;
            }
            
            then action trackTarget : TrackSpacecraft {
                in currentPosition;
                in predictedPosition;
                out azimuthCommand;
                out elevationCommand;
            }
            
            then merge dataOperations;
            
            then action receiveData : ReceiveTelemetry {
                in signal;
                out telemetry;
                out dataQuality;
            }
            
            then action processData : ProcessSignal {
                in rawSignal = signal;
                out decodedData;
                out signalMetrics;
            }
            
            then decide;
                if commandRequired then transmitCommands;
                else dataOperations;
            
            action transmitCommands : TransmitCommand {
                in command;
                in targetAzimuth = trackTarget.azimuthCommand;
                in targetElevation = trackTarget.elevationCommand;
                out transmitSuccess;
            }
            then dataOperations;
        }
        then continuousOperations;
        
        action standbyMode {
            do action monitor : MonitorHealth;
        }
        then continuousOperations;
        
        action safeModeOperations {
            do action diagnostics;
        }
        then continuousOperations;
        
        attribute subsystemStatus : TrackingStatus;
        attribute trackScheduled : Boolean;
        attribute commandRequired : Boolean;
        attribute spacecraftEphemeris : Real;
        attribute frequency : FrequencyValue;
        attribute currentPosition : AngleValue;
        attribute predictedPosition : AngleValue;
        attribute signal : SpacecraftSignal;
        attribute command : GroundCommand;
    }
    
    requirement def SystemRequirement;
    requirement systemRequirements : SystemRequirement[*] nonunique;
    
    requirement <'DSN-REQ-001'> primaryMissionFunction : SystemRequirement {
        doc /* The Deep Space Network shall provide continuous two-way 
             * radio communications with spacecraft exploring the solar 
             * system and beyond, enabling command uplink and science 
             * data downlink capabilities.
             */
        subject dsnStation : DeepSpaceNetworkStation;
    }
    
    requirement <'DSN-REQ-002'> antennaPerformance : SystemRequirement {
        doc /* The antenna subsystem shall provide a minimum gain of 
             * 63 dBi at X-band frequencies with pointing accuracy 
             * better than 0.01 degrees.
             */
        subject antenna : AntennaSubsystem;
        assert constraint {
            antenna.gain >= 63 and
            antenna.pointingAccuracy <= 0.01
        }
    }
    
    requirement <'DSN-REQ-003'> receiverSensitivity : SystemRequirement {
        doc /* The receiver subsystem shall achieve a system noise 
             * temperature not exceeding 20 Kelvin at X-band to enable 
             * detection of weak signals from distant spacecraft.
             */
        subject receiver : ReceiverSubsystem;
        assert constraint {
            receiver.noiseTemperature <= 20
        }
    }
    
    requirement <'DSN-REQ-004'> transmitterPower : SystemRequirement {
        doc /* The transmitter subsystem shall provide a minimum output 
             * power of 20 kilowatts for uplink commands to spacecraft 
             * at interplanetary distances.
             */
        subject transmitter : TransmitterSubsystem;
        assert constraint {
            transmitter.outputPower >= 20000[W]
        }
    }
    
    requirement <'DSN-REQ-005'> dataProcessingCapacity : SystemRequirement {
        doc /* The signal processing subsystem shall support data rates 
             * up to 1 Gbps for high-volume science data return from 
             * deep space missions.
             */
        subject signalProc : SignalProcessingSubsystem;
        assert constraint {
            signalProc.processingCapacity >= 1000
        }
    }
    
    requirement <'DSN-REQ-006'> trackingAccuracy : SystemRequirement {
        doc /* The tracking subsystem shall provide spacecraft range 
             * measurements accurate to within 1 meter and velocity 
             * measurements accurate to 0.1 mm/s.
             */
        subject tracking : TrackingSubsystem;
        assert constraint {
            tracking.radioMetric.rangeAccuracy <= 1[m]
        }
    }
    
    requirement <'DSN-REQ-007'> operationalAvailability : SystemRequirement {
        doc /* The station shall maintain operational availability of 
             * at least 95% to support critical mission phases and 
             * scheduled tracking passes.
             */
        subject dsnStation : DeepSpaceNetworkStation;
    }
    
    part def DeepSpaceNetworkStation {
        attribute stationId : String;
        attribute location : String;
        attribute operationalStatus : OperationalMode;
        attribute availability : Real;
        
        perform action operations : DeepSpaceNetworkOperations;
        
        part antenna : AntennaSubsystem {
            attribute :>> diameter = 70[m];
            attribute :>> azimuthAngle = 0;
            attribute :>> elevationAngle = 45;
            attribute :>> gain = 74;
            attribute :>> pointingAccuracy = 0.005;
            
            part :>> reflectorDish {
                attribute :>> surfaceAccuracy = 0.0005[m];
                attribute :>> efficiency = 0.65;
            }
            
            part :>> feedHorn {
                attribute :>> operatingBand = FrequencyBand::x_band;
                attribute :>> beamwidth = 0.1;
            }
            
            part :>> positioner {
                attribute :>> azimuthRange = 360;
                attribute :>> elevationRange = 90;
                attribute :>> slewRate = 0.25;
            }
        }
        
        part transmitter : TransmitterSubsystem {
            attribute :>> outputPower = 20000[W];
            attribute :>> frequency = 7145;
            attribute :>> efficiency = 0.55;
            
            part :>> klystronAmplifier {
                attribute :>> maxPower = 25000[W];
                attribute :>> operatingTemp = 323;
            }
            
            part :>> upconverter {
                attribute :>> inputFrequency = 300;
                attribute :>> outputFrequency = 7145;
            }
            
            part :>> waveguide {
                attribute :>> loss = 0.5;
                attribute :>> length = 50[m];
            }
            
            perform operations.beginTracking.transmitCommands;
        }
        
        part receiver : ReceiverSubsystem {
            attribute :>> sensitivity = -180;
            attribute :>> noiseTemperature = 18;
            attribute :>> bandwidth = 500;
            
            part :>> lowNoiseAmplifier {
                attribute :>> gain = 60;
                attribute :>> noiseTemp = 15;
            }
            
            part :>> downconverter {
                attribute :>> inputFrequency = 8400;
                attribute :>> outputFrequency = 300;
            }
            
            part :>> demodulator {
                attribute :>> dataRate = 1000;
                attribute :>> bitErrorRate = 0.000001;
            }
            
            perform operations.beginTracking.receiveData;
        }
        
        part signalProcessing : SignalProcessingSubsystem {
            attribute :>> processingCapacity = 1200;
            
            part :>> digitizer {
                attribute :>> samplingRate = 2000;
                attribute :>> resolution = 16;
            }
            
            part :>> decoder {
                attribute :>> supportedFormats = "CCSDS";
                attribute :>> throughput = 1200;
            }
            
            part :>> dataRecorder {
                attribute :>> storageCapacity = 100000;
                attribute :>> writeSpeed = 1500;
            }
            
            perform operations.beginTracking.processData;
        }
        
        part tracking : TrackingSubsystem {
            attribute :>> trackingAccuracy = 0.001;
            
            part :>> radioMetric {
                attribute :>> rangeAccuracy = 0.5[m];
                attribute :>> dopplerAccuracy = 0.05;
            }
            
            part :>> angleTracking {
                attribute :>> azimuthAccuracy = 0.002;
                attribute :>> elevationAccuracy = 0.002;
            }
            
            part :>> predictor {
                attribute :>> ephemerisAccuracy = 10[m];
            }
            
            perform operations.beginTracking.trackTarget;
        }
        
        part monitorControl : MonitorControlSubsystem {
            attribute :>> responseTime = 0.1;
            
            part :>> stationController {
                attribute :>> processingSpeed = 3000;
                attribute :>> memory = 128;
            }
            
            part :>> healthMonitor {
                attribute :>> sensorCount = 500;
                attribute :>> updateRate = 10;
            }
            
            part :>> scheduler {
                attribute :>> maxTracks = 20;
            }
            
            perform operations.healthCheck;
        }
        
        port rfInterface : RFPort;
        port dataInterface : DataPort;
        port powerInterface : PowerPort;
        port controlInterface : ControlPort;
        
        connection antennaToTransmitter connect antenna to transmitter;
        connection antennaToReceiver connect antenna to receiver;
        connection receiverToSignalProc connect receiver to signalProcessing;
        connection signalProcToData connect signalProcessing.dataRecorder to dataInterface;
        connection trackingToAntenna connect tracking to antenna.positioner;
        connection monitorToAll connect monitorControl to antenna;
    }
    
    part goldstoneStation : DeepSpaceNetworkStation {
        attribute :>> stationId = "DSS-14";
        attribute :>> location = "Goldstone, California";
        attribute :>> operationalStatus = OperationalMode::duplex;
        attribute :>> availability = 0.97;
    }
    
    satisfy primaryMissionFunction by goldstoneStation;
    satisfy antennaPerformance by goldstoneStation.antenna;
    satisfy receiverSensitivity by goldstoneStation.receiver;
    satisfy transmitterPower by goldstoneStation.transmitter;
    satisfy dataProcessingCapacity by goldstoneStation.signalProcessing;
    satisfy trackingAccuracy by goldstoneStation.tracking;
    satisfy operationalAvailability by goldstoneStation;
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    private import NASA_DeepSpaceNetwork_System::*;

    action orchestrator {
        item testCommand : GroundCommand {
            attribute commandId = "";
            attribute targetSpacecraft = "";
            attribute priority = 0.0;
            attribute transmitPower : PowerValue;
        }
        attribute testTargetAzimuth : AngleValue = 0.0;
        attribute testTargetElevation : AngleValue = 0.0;
        action transmitCommandsProbe : TransmitCommand {
            in command = testCommand;
            in targetAzimuth = testTargetAzimuth;
            in targetElevation = testTargetElevation;
        }
        first transmitCommandsProbe;
    }
}
