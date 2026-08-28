package WirelessCommSystem {
    import ScalarValues::*;
    
    package Units {
        unit GHz;
        unit W;
        unit mW;
        unit km;
        unit s;
        unit ms;
        unit Mb_per_s;
        unit byte;
    }
    
    package ValueTypes {
        value type FrequencyGHz :> Real {
            :>> unit = GHz;
        }
        value type PowerWatts :> Real {
            :>> unit = W;
        }
        value type PowerDBm :> Real {
            :>> unit = mW;
        }
        value type DistanceKm :> Real {
            :>> unit = km;
        }
        value type DataRateMbps :> Real {
            :>> unit = Mb_per_s;
        }
        value type LatencyMs :> Real {
            :>> unit = ms;
        }
        value type DurationMs :> Real {
            :>> unit = ms;
        }
        value type TimestampS :> Real {
            :>> unit = s;
        }
        value type DataSizeBytes :> Real {
            :>> unit = byte;
        }
        value type Probability :> Real;
        value type Percent :> Real;
        value type Address :> String;
    }
    
    package DataFrames {
        item def DataFrame {
            attribute sourceAddress : Address;
            attribute destinationAddress : Address;
            attribute payload : String;
            attribute size : DataSizeBytes;
            attribute timestamp : TimestampS;
            attribute sequenceNumber : Integer;
            attribute requiresAck : Boolean;
        }
        
        item def AckFrame {
            attribute sourceAddress : Address;
            attribute destinationAddress : Address;
            attribute ackSequenceNumber : Integer;
            attribute timestamp : TimestampS;
        }
        
        item def BeaconFrame {
            attribute baseStationId : Address;
            attribute networkName : String;
            attribute timestamp : TimestampS;
            attribute availableCapacity : Integer;
        }
        
        item def ConnectionRequestFrame {
            attribute sourceAddress : Address;
            attribute deviceCapabilities : String;
        }
        
        item def ConnectionResponseFrame {
            attribute accepted : Boolean;
            attribute assignedId : Address;
            attribute networkParams : String;
        }
        
        item def TerminationFrame {
            attribute sourceAddress : Address;
            attribute destinationAddress : Address;
            attribute reason : String;
        }
        
        item def RadioSignal {
            attribute carrierFrequency : FrequencyGHz;
            attribute signalPower : PowerWatts;
            attribute modulationType : String;
            attribute payloadFrame : DataFrame;
        }
    }
    
    package Ports {
        port def AirRadioPort {
            attribute operatingFrequency : FrequencyGHz;
            inout radioSignal : RadioSignal;
        }
        
        port def InternalRadioPort {
            inout rfSignal : RadioSignal;
        }
        
        port def BasebandPort {
            inout basebandDataFrame : DataFrame;
        }
        
        port def MacPort {
            inout macDataFrame : DataFrame;
        }
        
        port def AppDataPort {
            inout appDataFrame : DataFrame;
        }
        
        port def BackhaulPort {
            attribute interfaceType : String;
            attribute maxThroughput : DataRateMbps;
            inout backhaulDataFrame : DataFrame;
        }
    }
    
    package Components {
        part def Antenna {
            attribute antennaGain : Real;
            attribute maxRangeKm : DistanceKm;
            
            port airInterface : AirRadioPort;
            port rfOutput : InternalRadioPort;
            
            action transmitRF {
                in signal : RadioSignal;
            }
            action receiveRF {
                out signal : RadioSignal;
            }
        }
        
        part def RadioTransceiver {
            attribute operatingFrequency : FrequencyGHz;
            attribute transmitPower : PowerWatts;
            attribute receiverSensitivity : PowerWatts;
            attribute maxBandwidth : DataRateMbps;
            
            port antennaIF : InternalRadioPort;
            port processorIF : BasebandPort;
            
            action upconvert {
                in dataFrame : DataFrame;
                out rfSignal : RadioSignal;
            }
            action downconvert {
                in rfSignal : RadioSignal;
                out dataFrame : DataFrame;
            }
        }
        
        part def SignalProcessor {
            attribute modulationScheme : String;
            attribute supportedModulations : String;
            attribute processingLatency : LatencyMs;
            attribute codeRate : Real;
            
            port radioIF : BasebandPort;
            port macIF : MacPort;
            
            action modulate {
                in dataFrame : DataFrame;
                out basebandFrame : DataFrame;
            }
            action demodulate {
                in basebandFrame : DataFrame;
                out dataFrame : DataFrame;
            }
            action applyOFDM {
                in dataFrame : DataFrame;
                out ofdmSignal : DataFrame;
            }
        }
        
        part def MACUnit {
            attribute maxRetransmissions : Integer;
            attribute contentionWindowMinMs : DurationMs;
            attribute contentionWindowMaxMs : DurationMs;
            attribute interframeSpaceMs : DurationMs;
            
            port processorIF : MacPort;
            port appIF : AppDataPort;
            
            state machine MACState {
                state idle;
                state sensing;
                state backoff;
                state transmitting;
                state awaitingAck;
                state retransmitting;
                state receiving;
                
                transition t1 from idle to sensing when dataQueued;
                transition t2 from sensing to transmitting when channelFree;
                transition t3 from sensing to backoff when channelBusy;
                transition t4 from backoff to sensing when backoffTimerExpired;
                transition t5 from transmitting to awaitingAck when txComplete;
                transition t6 from awaitingAck to idle when ackReceived;
                transition t7 from awaitingAck to retransmitting when ackTimeout;
                transition t8 from retransmitting to sensing when retryCountLessThanMax;
                transition t9 from retransmitting to idle when retryCountExceeded;
                transition t10 from idle to receiving when incomingFrameDetected;
                transition t11 from receiving to idle when rxComplete;
            }
            
            action listenBeforeTalk {
                out channelBusy : Boolean;
            }
            action handleRetransmission {
                in frame : DataFrame;
                in attempt : Integer;
            }
        }
    }
    
    package Devices {
        part def BaseStation {
            attribute baseStationId : Address;
            attribute maxConnectedDevices : Integer;
            attribute currentConnectedDevices : Integer := 0;
            attribute coverageRadiusKm : DistanceKm;
            attribute throughputCapacity : DataRateMbps;
            attribute targetReliability : Probability;
            attribute maxSupportedLatency : LatencyMs;
            
            port backhaul : BackhaulPort;
            port airInterface : AirRadioPort;
            
            part antenna : Antenna;
            part radio : RadioTransceiver;
            part signalProcessor : SignalProcessor;
            part mac : MACUnit;
            
            connection bsAntRx connect antenna.rfOutput to radio.antennaIF;
            connection bsAntTx connect radio.antennaIF to antenna.rfOutput;
            connection bsRadioProcRx connect radio.processorIF to signalProcessor.radioIF;
            connection bsProcRadioTx connect signalProcessor.radioIF to radio.processorIF;
            connection bsProcMacRx connect signalProcessor.macIF to mac.processorIF;
            connection bsMacProcTx connect mac.processorIF to signalProcessor.macIF;
            connection bsMacBackhaul connect mac.appIF to backhaul;
            
            state machine BaseStationOperationalState {
                state idle {
                    entry / broadcastBeacon();
                }
                state active {
                    entry / acceptNewConnections();
                }
                state error {
                    entry / logError();
                    do / attemptRecovery();
                }
                
                transition t1 from idle to active when deviceConnected;
                transition t2 from active to idle when allDevicesDisconnected;
                transition t3 from active to error on hardwareFailure;
                transition t4 from idle to error on selfTestFailed;
                transition t5 from error to idle when recoveryComplete;
            }
            
            action broadcastBeacon {
                out beacon : BeaconFrame;
            }
            action acceptNewConnections {
                in request : ConnectionRequestFrame;
                out response : ConnectionResponseFrame;
            }
            action logError;
            action attemptRecovery;
        }
        
        part def WirelessDevice {
            attribute deviceId : Address;
            attribute maxSupportedDataRate : DataRateMbps;
            attribute batteryLevel : Percent;
            attribute isPowered : Boolean;
            attribute deviceType : String;
            
            port airInterface : AirRadioPort;
            port appPort : AppDataPort;
            
            part antenna : Antenna;
            part radio : RadioTransceiver;
            part signalProcessor : SignalProcessor;
            part mac : MACUnit;
            
            connection wdAntRx connect antenna.rfOutput to radio.antennaIF;
            connection wdAntTx connect radio.antennaIF to antenna.rfOutput;
            connection wdRadioProcRx connect radio.processorIF to signalProcessor.radioIF;
            connection wdProcRadioTx connect signalProcessor.radioIF to radio.processorIF;
            connection wdProcMacRx connect signalProcessor.macIF to mac.processorIF;
            connection wdMacProcTx connect mac.processorIF to signalProcessor.macIF;
            connection wdMac2App connect mac.appIF to appPort;
            
            state machine DeviceConnectionLifecycle {
                state disconnected {
                    entry / scanForNetworks();
                }
                state connecting {
                    entry / sendConnectionRequest();
                }
                state associated;
                state dataTransfer;
                state terminating {
                    entry / sendDisconnectFrame();
                }
                state suspended;
                
                transition t1 from disconnected to connecting on initiateConnection;
                transition t2 from connecting to associated on receiveAcceptResponse;
                transition t3 from connecting to disconnected on receiveRejectResponse;
                transition t4 from associated to dataTransfer when dataToSend;
                transition t5 from dataTransfer to dataTransfer on receiveDataFrame;
                transition t6 from dataTransfer to associated when noMoreData;
                transition t7 from associated to terminating on initiateTermination;
                transition t8 from dataTransfer to terminating on initiateTermination;
                transition t9 from terminating to disconnected on connectionClosed;
                transition t10 from dataTransfer to suspended on signalLost;
                transition t11 from suspended to disconnected when signalLostTimeout;
            }
            
            action scanForNetworks;
            action sendConnectionRequest {
                out request : ConnectionRequestFrame;
            }
            action sendDisconnectFrame;
        }
    }
    
    package Network {
        part def WirelessNetwork {
            attribute networkName : String;
            attribute operatingFrequency : FrequencyGHz;
            attribute maxConcurrentDevices : Integer;
            
            port externalBackhaul : BackhaulPort;
            
            part baseStation : BaseStation;
            part devices[*] : WirelessDevice;
            
            connection wirelessLinks connect baseStation.airInterface to devices.airInterface;
            connection backhaulLink connect baseStation.backhaul to externalBackhaul;
        }
    }
    
    package Requirements {
        requirement def CoverageRangeRequirement {
            subject bs : BaseStation;
            attribute requiredRangeKm : DistanceKm;
            require bs.coverageRadiusKm >= requiredRangeKm;
        }
        
        requirement def ThroughputRequirement {
            subject bs : BaseStation;
            attribute requiredThroughputMbps : DataRateMbps;
            require bs.throughputCapacity >= requiredThroughputMbps;
        }
        
        requirement def ReliabilityRequirement {
            subject bs : BaseStation;
            attribute maxPacketLoss : Percent;
            require bs.targetReliability >= (1.0 - maxPacketLoss);
        }
        
        requirement def LatencyRequirement {
            subject bs : BaseStation;
            attribute maxLatencyMs : LatencyMs;
            require bs.maxSupportedLatency <= maxLatencyMs;
        }
        
        requirement def ConnectedDeviceCapacityRequirement {
            subject bs : BaseStation;
            attribute minMaxDevices : Integer;
            require bs.maxConnectedDevices >= minMaxDevices;
        }
        
        part def ConfiguredNetwork :> WirelessNetwork {
            :>> networkName = "WirelessNet-01";
            :>> operatingFrequency = 2.4;
            :>> maxConcurrentDevices = 64;
            
            :>> baseStation.baseStationId = "BS-001";
            :>> baseStation.maxConnectedDevices = 64;
            :>> baseStation.coverageRadiusKm = 1.5;
            :>> baseStation.throughputCapacity = 100;
            :>> baseStation.targetReliability = 0.95;
            :>> baseStation.maxSupportedLatency = 50;
            
            requirement coverageReq : CoverageRangeRequirement {
                :>> requiredRangeKm = 1.0;
            }
            requirement throughputReq : ThroughputRequirement {
                :>> requiredThroughputMbps = 100;
            }
            requirement reliabilityReq : ReliabilityRequirement {
                :>> maxPacketLoss = 0.05;
            }
            requirement latencyReq : LatencyRequirement {
                :>> maxLatencyMs = 50;
            }
            requirement capacityReq : ConnectedDeviceCapacityRequirement {
                :>> minMaxDevices = 64;
            }
            
            satisfy coverageReq by baseStation;
            satisfy throughputReq by baseStation;
            satisfy reliabilityReq by baseStation;
            satisfy latencyReq by baseStation;
            satisfy capacityReq by baseStation;
        }
    }
}
