package DSL_System {

    import ScalarValues::*;

    // ===== Unit Definitions =====
    unit Mbps;
    unit km;
    unit dB;
    unit MHz;
    unit sec;
    unit pct;

    // ===== Value Type Definitions =====
    value type DataRate > Real {
        :>> unit = Mbps;
    }

    value type Distance > Real {
        :>> unit = km;
    }

    value type AttenuationValue > Real {
        :>> unit = dB;
    }

    value type SNRValue > Real {
        :>> unit = dB;
    }

    value type BitErrorRate > Real;

    value type AvailabilityValue > Real {
        :>> unit = pct;
    }

    value type TimeDuration > Real {
        :>> unit = sec;
    }

    value type FrequencyValue > Real {
        :>> unit = MHz;
    }

    // ===== Item Definitions =====
    item def DigitalData {
        attribute packetSize : Integer;
        attribute sequenceNumber : Integer;
    }

    item def AnalogSignal {
        attribute carrierFrequency : FrequencyValue;
        attribute powerLevel : Real;
        attribute measuredSNR : SNRValue;
    }

    item def AggregatedData {
        attribute streamId : Integer;
        attribute subscriberCount : Integer;
    }

    item def BackboneData {
        attribute routingPrefix : String;
        attribute packetCount : Integer;
    }

    // ===== Port Definitions =====
    port def EthernetPort {
        out item txData : DigitalData;
        in item rxData : DigitalData;
    }

    port def LinePort {
        out item txSignal : AnalogSignal;
        in item rxSignal : AnalogSignal;
    }

    port def InternalPort {
        out item txAggregated : AggregatedData;
        in item rxAggregated : AggregatedData;
    }

    port def BackbonePort {
        out item txBackbone : BackboneData;
        in item rxBackbone : BackboneData;
    }

    // ===== Action Definitions =====
    action def SelfTest {
        out attribute result : Boolean;
    }

    action def HardwareCheck {
        out attribute status : Boolean;
    }

    action def NegotiateParameters {
        in attribute lineSNR : SNRValue;
        in attribute lineAttenuation : AttenuationValue;
        out attribute negotiatedDownstream : DataRate;
        out attribute negotiatedUpstream : DataRate;
        out attribute syncEstablished : Boolean;
    }

    action def MeasureLineQuality {
        out attribute measuredSNR : SNRValue;
        out attribute measuredAttenuation : AttenuationValue;
    }

    action def ActivateDataTransfer {
        in attribute downstream : DataRate;
        in attribute upstream : DataRate;
    }

    action def TransmitData {
        in item data : DigitalData;
        out item signal : AnalogSignal;
    }

    action def Encode {
        in item digitalIn : DigitalData;
        out item analogOut : AnalogSignal;
    }

    action def Decode {
        in item analogIn : AnalogSignal;
        out item digitalOut : DigitalData;
    }

    action def FECEncode {
        in item dataIn : DigitalData;
        out item dataOut : DigitalData;
    }

    action def FECDecode {
        in item dataIn : DigitalData;
        out item dataOut : DigitalData;
    }

    action def Multiplex {
        in item streams : AggregatedData[0..*];
        out item combined : BackboneData;
    }

    action def Demultiplex {
        in item combined : BackboneData;
        out item streams : AggregatedData[0..*];
    }

    // ===== DSL Modem Definition =====
    part def DSLModem {
        port ethernet : EthernetPort;
        port line : LinePort;

        attribute downstreamRate : DataRate := 0.0;
        attribute upstreamRate : DataRate := 0.0;
        attribute currentSNR : SNRValue := 0.0;
        attribute currentAttenuation : AttenuationValue := 0.0;
        attribute synchronized : Boolean := false;
        attribute signalLost : Boolean := false;
        attribute selfTestComplete : Boolean := false;
        attribute hardwareOk : Boolean := false;
        attribute bitErrorRate : BitErrorRate := 0.0;
        attribute reconnectTime : TimeDuration := 0.0;

        part modulator {
            in item digitalIn : DigitalData;
            out item analogOut : AnalogSignal;
            perform Encode;
        }

        part demodulator {
            in item analogIn : AnalogSignal;
            out item digitalOut : DigitalData;
            perform Decode;
        }

        part txErrorCorrection {
            in item dataIn : DigitalData;
            out item dataOut : DigitalData;
            perform FECEncode;
        }

        part rxErrorCorrection {
            in item dataIn : DigitalData;
            out item dataOut : DigitalData;
            perform FECDecode;
        }

        // TX path: LAN -> error correction -> modulator -> line
        connect ethernet.rxData to txErrorCorrection.dataIn;
        connect txErrorCorrection.dataOut to modulator.digitalIn;
        connect modulator.analogOut to line.txSignal;

        // RX path: line -> demodulator -> error correction -> LAN
        connect line.rxSignal to demodulator.analogIn;
        connect demodulator.digitalOut to rxErrorCorrection.dataIn;
        connect rxErrorCorrection.dataOut to ethernet.txData;

        // Operational state machine
        state modemOperation {
            entry;

            state initialization {
                entry perform SelfTest;
                do perform HardwareCheck;
                transition source initialization target training
                    when selfTestComplete == true and hardwareOk == true;
            }

            state training {
                entry perform NegotiateParameters;
                do perform MeasureLineQuality;
                transition source training target showtime
                    when synchronized == true;
                transition source training target initialization
                    when signalLost == true;
            }

            state showtime {
                entry perform ActivateDataTransfer;
                do perform TransmitData;
                transition source showtime target training
                    when signalLost == true;
            }

            transition initial to initialization;
        }
    }

    // ===== Twisted-Pair Cable Definition =====
    part def TwistedPairCable {
        port customerEnd : LinePort;
        port centralOfficeEnd : LinePort;

        attribute length : Distance;
        attribute attenuation : AttenuationValue;
        attribute maxDistance : Distance := 5.0;
        attribute qualityFactor : Real := 1.0;

        // Bidirectional signal propagation
        connect customerEnd.txSignal to centralOfficeEnd.rxSignal;
        connect centralOfficeEnd.txSignal to customerEnd.rxSignal;
    }

    // ===== DSLAM Line Card Definition =====
    part def LineCard {
        port subscriberLine : LinePort;
        port internalBus : InternalPort;

        attribute cardId : Integer;
        attribute active : Boolean := false;
        attribute subscriberDownstream : DataRate;
        attribute subscriberUpstream : DataRate;

        perform Encode;
        perform Decode;
    }

    // ===== DSLAM Definition =====
    part def DSLAM {
        port subscriberPorts : LinePort[0..*];
        port backbonePort : BackbonePort;

        attribute totalSubscribers : Integer;
        attribute aggregateDownstream : DataRate;
        attribute aggregateUpstream : DataRate;
        attribute maxCapacity : DataRate := 1000.0;

        part lineCards : LineCard[0..*];

        part muxDemux {
            port subscriberSide : InternalPort[0..*];
            port backboneSide : BackbonePort;
            perform Multiplex;
            perform Demultiplex;
        }

        // Connect subscriber ports to corresponding line cards
        connect subscriberPorts to lineCards.subscriberLine;
        // Connect line cards to mux/demux aggregator
        connect lineCards.internalBus to muxDemux.subscriberSide;
        // Connect mux/demux backbone side to DSLAM backbone port
        connect muxDemux.backboneSide to backbonePort;
    }

    // ===== Network Backbone Definition =====
    part def NetworkBackbone {
        port dslamInterface : BackbonePort;

        attribute capacity : DataRate := 10000.0;
        attribute latency : TimeDuration;
        attribute provider : String;
    }

    // ===== DSL System Definition =====
    part def DSLSystem {
        part modem : DSLModem;
        part cable : TwistedPairCable;
        part dslam : DSLAM;
        part backbone : NetworkBackbone;

        // System-level connections
        connect modem.line to cable.customerEnd;
        connect cable.centralOfficeEnd to dslam.subscriberPorts;
        connect dslam.backbonePort to backbone.dslamInterface;

        attribute systemAvailability : AvailabilityValue := 99.5;
    }

    // ===== Requirement Definitions =====
    requirement def MinDownstreamRate {
        subject modem : DSLModem;
        constraint { modem.downstreamRate >= 25.0 }
    }

    requirement def MinUpstreamRate {
        subject modem : DSLModem;
        constraint { modem.upstreamRate >= 5.0 }
    }

    requirement def MaxOperationalDistance {
        subject cable : TwistedPairCable;
        constraint { cable.length <= 5.0 }
    }

    requirement def MaxBitErrorRateReq {
        subject modem : DSLModem;
        constraint { modem.bitErrorRate <= 1.0e-6 }
    }

    requirement def MinAvailabilityReq {
        subject system : DSLSystem;
        constraint { system.systemAvailability >= 99.5 }
    }

    requirement def MaxReconnectTimeReq {
        subject modem : DSLModem;
        constraint { modem.reconnectTime <= 30.0 }
    }

    // ===== Composite System Requirements =====
    requirement def DSLPerformanceRequirements {
        subject system : DSLSystem;

        requirement minDownstream : MinDownstreamRate {
            subject modem = system.modem;
        }

        requirement minUpstream : MinUpstreamRate {
            subject modem = system.modem;
        }

        requirement maxDistance : MaxOperationalDistance {
            subject cable = system.cable;
        }

        requirement lowBER : MaxBitErrorRateReq {
            subject modem = system.modem;
        }

        requirement highAvailability : MinAvailabilityReq {
            subject system = system;
        }

        requirement rapidReconnect : MaxReconnectTimeReq {
            subject modem = system.modem;
        }
    }
}
