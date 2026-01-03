package PowerLineCommunicationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def DataRateValue {
        attribute value: Real;
        attribute unit: String = "Mbps";
    }
    
    attribute def FrequencyBandValue {
        attribute lowerBound: ISQ::FrequencyValue;
        attribute upperBound: ISQ::FrequencyValue;
    }
    
    attribute def SignalStrengthValue {
        attribute value: Real;
        attribute unit: String = "dBm";
    }
    
    attribute def ModulationScheme;
    attribute def DataPacket {
        attribute payload: String;
        attribute sourceAddress: String;
        attribute destinationAddress: String;
        attribute checksum: Integer;
    }
    
    item def PLCSignal {
        attribute carrierFrequency: ISQ::FrequencyValue;
        attribute signalStrength: SignalStrengthValue;
        attribute modulatedData: DataPacket;
    }
    
    port def PowerLinePort {
        inout voltage: ISQ::VoltageValue;
        inout current: ISQ::CurrentValue;
        inout plcSignal: PLCSignal;
    }
    
    port def DataInterfacePort {
        inout dataPacket: DataPacket;
        attribute dataRate: DataRateValue;
    }
    
    part def PLCModem {
        attribute operatingFrequency: FrequencyBandValue;
        attribute maxDataRate: DataRateValue;
        attribute transmitPower: SignalStrengthValue;
        
        port powerLineInterface: PowerLinePort;
        port dataInterface: DataInterfacePort;
        
        part modulationUnit {
            attribute scheme: ModulationScheme;
        }
        
        part demodulationUnit {
            attribute scheme: ModulationScheme;
        }
        
        part couplingCircuit {
            attribute couplingCapacitance: ISQ::CapacitanceValue;
            attribute isolationVoltage: ISQ::VoltageValue;
        }
    }
    
    part def AnalogFrontEnd {
        port lineConnection: PowerLinePort;
        port modemConnection: PowerLinePort;
        
        part signalCoupler {
            attribute capacitance: ISQ::CapacitanceValue = 100.0e-9 [SI::F];
            attribute voltageRating: ISQ::VoltageValue = 1000.0 [SI::V];
        }
        
        part bandPassFilter {
            attribute lowerCutoff: ISQ::FrequencyValue = 2.0e6 [SI::Hz];
            attribute upperCutoff: ISQ::FrequencyValue = 30.0e6 [SI::Hz];
            attribute attenuation: Real = -40.0;
        }
        
        part lineDriver {
            attribute outputPower: ISQ::PowerValue = 10.0 [SI::W];
        }
    }
    
    part def PowerLineChannel {
        attribute lineVoltage: ISQ::VoltageValue;
        attribute lineFrequency: ISQ::FrequencyValue;
        attribute lineImpedance: Real;
        attribute lineLength: ISQ::LengthValue;
        attribute attenuationPerMeter: Real;
        
        port endpoint1: PowerLinePort;
        port endpoint2: PowerLinePort;
    }
    
    action def ModulateDataOntoCarrier {
        in inputData: DataPacket;
        in carrierFrequency: ISQ::FrequencyValue;
        in modulationScheme: ModulationScheme;
        out modulatedSignal: PLCSignal;
    }
    
    action def DemodulateCarrierSignal {
        in receivedSignal: PLCSignal;
        in modulationScheme: ModulationScheme;
        out outputData: DataPacket;
        out signalQuality: Real;
    }
    
    action def CoupleSignalToLine {
        in modulatedSignal: PLCSignal;
        in lineVoltage: ISQ::VoltageValue;
        out coupledSignal: PLCSignal;
    }
    
    action def DecoupleSignalFromLine {
        in lineVoltage: ISQ::VoltageValue;
        in lineNoise: Real;
        out receivedSignal: PLCSignal;
    }
    
    action def ApplyErrorCorrection {
        in rawData: DataPacket;
        out correctedData: DataPacket;
        out errorCount: Integer;
    }
    
    action def TransmitDataOverPowerLine {
        in dataToSend: DataPacket;
        in carrierFreq: ISQ::FrequencyValue;
        in modScheme: ModulationScheme;
        out transmittedSignal: PLCSignal;
        
        first start;
        
        then action modulate: ModulateDataOntoCarrier {
            in inputData = dataToSend;
            in carrierFrequency = carrierFreq;
            in modulationScheme = modScheme;
            out modulatedSignal;
        }
        
        then action couple: CoupleSignalToLine {
            in modulatedSignal = modulate.modulatedSignal;
            in lineVoltage;
            out coupledSignal;
        }
        
        then assign transmittedSignal := couple.coupledSignal;
        then done;
    }
    
    action def ReceiveDataFromPowerLine {
        in lineNoise: Real;
        in modScheme: ModulationScheme;
        out receivedData: DataPacket;
        out quality: Real;
        
        first start;
        
        then action decouple: DecoupleSignalFromLine {
            in lineVoltage;
            in lineNoise = ReceiveDataFromPowerLine::lineNoise;
            out receivedSignal;
        }
        
        then action demodulate: DemodulateCarrierSignal {
            in receivedSignal = decouple.receivedSignal;
            in modulationScheme = modScheme;
            out outputData;
            out signalQuality;
        }
        
        then action correctErrors: ApplyErrorCorrection {
            in rawData = demodulate.outputData;
            out correctedData;
            out errorCount;
        }
        
        then assign receivedData := correctErrors.correctedData;
        then assign quality := demodulate.signalQuality;
        then done;
    }
    
    action def CommunicateViaPowerLine {
        in transmitPacket: DataPacket;
        in carrierFrequency: ISQ::FrequencyValue;
        in modulationScheme: ModulationScheme;
        in channelNoise: Real;
        out receivePacket: DataPacket;
        out communicationQuality: Real;
        
        first start;
        
        then action transmit: TransmitDataOverPowerLine {
            in dataToSend = transmitPacket;
            in carrierFreq = carrierFrequency;
            in modScheme = modulationScheme;
            out transmittedSignal;
        }
        
        then action propagate {
            in signal = transmit.transmittedSignal;
            out propagatedSignal = signal;
        }
        
        then action receive: ReceiveDataFromPowerLine {
            in lineNoise = channelNoise;
            in modScheme = modulationScheme;
            out receivedData;
            out quality;
        }
        
        then assign receivePacket := receive.receivedData;
        then assign communicationQuality := receive.quality;
        then done;
    }
    
    part plcCommunicationSystem {
        part transmitterModem: PLCModem {
            attribute operatingFrequency: FrequencyBandValue {
                attribute lowerBound = 2.0e6 [SI::Hz];
                attribute upperBound = 30.0e6 [SI::Hz];
            }
            attribute maxDataRate: DataRateValue {
                attribute value = 200.0;
            }
            attribute transmitPower: SignalStrengthValue {
                attribute value = -40.0;
            }
        }
        
        part transmitterAFE: AnalogFrontEnd {
            part signalCoupler {
                attribute capacitance = 100.0e-9 [SI::F];
                attribute voltageRating = 1000.0 [SI::V];
            }
            part bandPassFilter {
                attribute lowerCutoff = 2.0e6 [SI::Hz];
                attribute upperCutoff = 30.0e6 [SI::Hz];
                attribute attenuation = -40.0;
            }
            part lineDriver {
                attribute outputPower = 10.0 [SI::W];
            }
        }
        
        part powerLineChannel: PowerLineChannel {
            attribute lineVoltage = 230.0 [SI::V];
            attribute lineFrequency = 50.0 [SI::Hz];
            attribute lineImpedance = 50.0;
            attribute lineLength = 300.0 [SI::m];
            attribute attenuationPerMeter = 0.1;
        }
        
        part receiverAFE: AnalogFrontEnd {
            part signalCoupler {
                attribute capacitance = 100.0e-9 [SI::F];
                attribute voltageRating = 1000.0 [SI::V];
            }
            part bandPassFilter {
                attribute lowerCutoff = 2.0e6 [SI::Hz];
                attribute upperCutoff = 30.0e6 [SI::Hz];
                attribute attenuation = -40.0;
            }
        }
        
        part receiverModem: PLCModem {
            attribute operatingFrequency: FrequencyBandValue {
                attribute lowerBound = 2.0e6 [SI::Hz];
                attribute upperBound = 30.0e6 [SI::Hz];
            }
            attribute maxDataRate: DataRateValue {
                attribute value = 200.0;
            }
            attribute transmitPower: SignalStrengthValue {
                attribute value = -60.0;
            }
        }
        
        connect transmitterModem.powerLineInterface to transmitterAFE.modemConnection;
        connect transmitterAFE.lineConnection to powerLineChannel.endpoint1;
        connect powerLineChannel.endpoint2 to receiverAFE.lineConnection;
        connect receiverAFE.modemConnection to receiverModem.powerLineInterface;
    }
    
    requirement <'PLC-REQ-001'> primaryCommunicationFunction {
        doc /* The power-line communication system shall enable 
             * bidirectional digital data transmission over existing 
             * electrical power distribution infrastructure without 
             * disrupting normal power delivery operations.
            */
        subject system :> plcCommunicationSystem;
    }
    
    requirement <'PLC-REQ-002'> operatingFrequencyCompliance {
        subject txModem :> plcCommunicationSystem.transmitterModem;
        subject rxModem :> plcCommunicationSystem.receiverModem;
        
        assert constraint {
            txModem.operatingFrequency.lowerBound >= 2.0e6 [SI::Hz] and
            txModem.operatingFrequency.upperBound <= 30.0e6 [SI::Hz] and
            rxModem.operatingFrequency.lowerBound >= 2.0e6 [SI::Hz] and
            rxModem.operatingFrequency.upperBound <= 30.0e6 [SI::Hz]
        }
    }
    
    requirement <'PLC-REQ-003'> minimumDataThroughput {
        subject txModem :> plcCommunicationSystem.transmitterModem;
        subject rxModem :> plcCommunicationSystem.receiverModem;
        
        assert constraint {
            txModem.maxDataRate.value >= 100.0 and
            rxModem.maxDataRate.value >= 100.0
        }
    }
    
    requirement <'PLC-REQ-004'> signalCouplingIsolation {
        subject txAFE :> plcCommunicationSystem.transmitterAFE;
        subject rxAFE :> plcCommunicationSystem.receiverAFE;
        
        assert constraint {
            txAFE.signalCoupler.voltageRating >= 1000.0 [SI::V] and
            rxAFE.signalCoupler.voltageRating >= 1000.0 [SI::V]
        }
    }
    
    requirement <'PLC-REQ-005'> powerLineCompatibility {
        subject channel :> plcCommunicationSystem.powerLineChannel;
        
        assert constraint {
            channel.lineVoltage >= 110.0 [SI::V] and
            channel.lineVoltage <= 240.0 [SI::V] and
            (channel.lineFrequency == 50.0 [SI::Hz] or channel.lineFrequency == 60.0 [SI::Hz])
        }
    }
    
    requirement <'PLC-REQ-006'> maximumCommunicationRange {
        subject channel :> plcCommunicationSystem.powerLineChannel;
        
        assert constraint {
            channel.lineLength <= 300.0 [SI::m]
        }
    }
    
    satisfy primaryCommunicationFunction by plcCommunicationSystem;
    satisfy operatingFrequencyCompliance by plcCommunicationSystem.transmitterModem;
    satisfy operatingFrequencyCompliance by plcCommunicationSystem.receiverModem;
    satisfy minimumDataThroughput by plcCommunicationSystem.transmitterModem;
    satisfy minimumDataThroughput by plcCommunicationSystem.receiverModem;
    satisfy signalCouplingIsolation by plcCommunicationSystem.transmitterAFE;
    satisfy signalCouplingIsolation by plcCommunicationSystem.receiverAFE;
    satisfy powerLineCompatibility by plcCommunicationSystem.powerLineChannel;
    satisfy maximumCommunicationRange by plcCommunicationSystem.powerLineChannel;
}
