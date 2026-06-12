package DigitalSubscriberLineModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Frequency {
        :>> quantityKind = ISQ::frequency;
        :>> unit = SI::hertz;
    }

    attribute def DataRate {
        :>> quantityKind = ISQ::bitRate;
        :>> unit = SI::bitPerSecond;
    }

    attribute def Length {
        :>> quantityKind = ISQ::length;
        :>> unit = SI::metre;
    }

    attribute def Power {
        :>> quantityKind = ISQ::power;
        :>> unit = SI::watt;
    }

    attribute def Voltage {
        :>> quantityKind = ISQ::electricPotential;
        :>> unit = SI::volt;
    }

    attribute def Attenuation {
        :>> quantityKind = ISQ::dimensionless;
        :>> unit = SI::decibel;
    }

    attribute def SignalToNoiseRatio {
        :>> quantityKind = ISQ::dimensionless;
        :>> unit = SI::decibel;
    }

    item def AnalogLineSignal {
        attribute carrierFrequency : Frequency;
        attribute bandwidth : Frequency;
        attribute transmitPower : Power;
        attribute lineVoltage : Voltage;
        attribute snr : SignalToNoiseRatio;
    }

    item def DigitalUserData {
        attribute payloadRate : DataRate;
        attribute encodedFrameSize : Integer;
    }

    item def EthernetFrame {
        attribute frameSizeOctets : Integer;
        attribute payloadRate : DataRate;
    }

    item def ManagementMessage {
        attribute messageCode : Integer;
        attribute severity : Integer;
    }

    port def EthernetPort {
        inout item frames : EthernetFrame;
    }

    port def TwistedPairPort {
        inout item signal : AnalogLineSignal;
    }

    port def ManagementPort {
        inout item messages : ManagementMessage;
    }

    port def DataServicePort {
        inout item data : DigitalUserData;
    }

    action def InitializeDslLink {
        in attribute requestedDownstreamRate : DataRate;
        in attribute requestedUpstreamRate : DataRate;
        out attribute trainedDownstreamRate : DataRate;
        out attribute trainedUpstreamRate : DataRate;
    }

    action def ModulateUserData {
        in item userData : DigitalUserData;
        out item lineSignal : AnalogLineSignal;
    }

    action def DemodulateLineSignal {
        in item lineSignal : AnalogLineSignal;
        out item userData : DigitalUserData;
    }

    action def MonitorLineQuality {
        in item lineSignal : AnalogLineSignal;
        out attribute measuredSnr : SignalToNoiseRatio;
        out attribute measuredAttenuation : Attenuation;
    }

    action def ReportFault {
        in attribute faultCode : Integer;
        out item alarm : ManagementMessage;
    }

    state def DslLinkStateMachine {
        entry action InitializeDslLink;

        state poweredOff;
        state selfTest;
        state idle;
        state training;
        state showtime;
        state degraded;
        state fault;

        transition first poweredOff;

        transition powerApplied
            first poweredOff
            then selfTest;

        transition selfTestPassed
            first selfTest
            then idle;

        transition serviceRequested
            first idle
            then training;

        transition trainingComplete
            first training
            then showtime;

        transition lowSnrDetected
            first showtime
            then degraded;

        transition snrRecovered
            first degraded
            then showtime;

        transition retrainRequired
            first degraded
            then training;

        transition unrecoverableLineFault
            first training
            then fault;

        transition lineFaultDuringService
            first showtime
            then fault;

        transition resetCommanded
            first fault
            then selfTest;

        transition powerRemoved
            first idle
            then poweredOff;
    }

    part def CustomerPremisesEquipment {
        attribute maxDownstreamRate : DataRate = 100000000 [SI::bitPerSecond];
        attribute maxUpstreamRate : DataRate = 40000000 [SI::bitPerSecond];
        attribute transmitPower : Power = 0.1 [SI::watt];

        port subscriberEthernet : EthernetPort;
        port copperLoop : TwistedPairPort;
        port localManagement : ManagementPort;

        part modem;
        part splitter;
        part router;

        perform action ModulateUserData;
        perform action DemodulateLineSignal;
        perform action MonitorLineQuality;
    }

    part def CentralOfficeDslAccessMultiplexer {
        attribute aggregateBackhaulRate : DataRate = 10000000000 [SI::bitPerSecond];
        attribute supportedSubscriberCount : Integer = 384;
        attribute downstreamSpectrumUpperBound : Frequency = 30000000 [SI::hertz];

        port subscriberLoop : TwistedPairPort;
        port providerBackhaul : DataServicePort;
        port networkManagement : ManagementPort;

        part lineCard;
        part portController;
        part spectrumManager;

        perform action InitializeDslLink;
        perform action MonitorLineQuality;
    }

    part def CopperSubscriberLoop {
        attribute loopLength : Length = 1200 [SI::metre];
        attribute characteristicImpedance : Real = 100.0;
        attribute attenuationAt1MHz : Attenuation = 13 [SI::decibel];
        attribute noiseMargin : SignalToNoiseRatio = 6 [SI::decibel];

        port customerEnd : TwistedPairPort;
        port officeEnd : TwistedPairPort;
    }

    part def InternetServiceEdge {
        attribute minimumProvisionedRate : DataRate = 25000000 [SI::bitPerSecond];
        attribute maximumProvisionedRate : DataRate = 100000000 [SI::bitPerSecond];

        port subscriberTraffic : DataServicePort;
        port operations : ManagementPort;
    }

    part def DigitalSubscriberLineSystem {
        attribute provisionedDownstreamRate : DataRate = 50000000 [SI::bitPerSecond];
        attribute provisionedUpstreamRate : DataRate = 10000000 [SI::bitPerSecond];
        attribute downstreamFrequencyStart : Frequency = 138000 [SI::hertz];
        attribute downstreamFrequencyEnd : Frequency = 17664000 [SI::hertz];
        attribute upstreamFrequencyStart : Frequency = 25000 [SI::hertz];
        attribute upstreamFrequencyEnd : Frequency = 138000 [SI::hertz];
        attribute minimumOperationalSnrMargin : SignalToNoiseRatio = 6 [SI::decibel];

        port customerData : EthernetPort;
        port providerData : DataServicePort;
        port operationsAccess : ManagementPort;

        part cpe : CustomerPremisesEquipment;
        part copperLoop : CopperSubscriberLoop;
        part dslam : CentralOfficeDslAccessMultiplexer;
        part serviceEdge : InternetServiceEdge;

        connect customerData to cpe.subscriberEthernet;
        connect cpe.copperLoop to copperLoop.customerEnd;
        connect copperLoop.officeEnd to dslam.subscriberLoop;
        connect dslam.providerBackhaul to serviceEdge.subscriberTraffic;
        connect operationsAccess to dslam.networkManagement;
        connect cpe.localManagement to serviceEdge.operations;

        perform action InitializeDslLink;
        perform action ModulateUserData;
        perform action DemodulateLineSignal;
        perform action MonitorLineQuality;

        exhibit state DslLinkStateMachine;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The Digital Subscriber Line system shall provide bidirectional broadband digital data service over an existing copper twisted-pair subscriber loop by modulating digital user traffic onto frequency-separated analog line signals while preserving manageable line operation. */

        subject dsl : DigitalSubscriberLineSystem;

        require constraint {
            dsl.provisionedDownstreamRate >= 25000000 [SI::bitPerSecond] and
            dsl.provisionedUpstreamRate >= 5000000 [SI::bitPerSecond]
        }
    }

    requirement def CopperLoopCompatibilityRequirement {
        doc /* The system shall operate over a copper subscriber loop of at least 1000 metres while maintaining the minimum operational signal-to-noise margin. */

        subject dsl : DigitalSubscriberLineSystem;

        require constraint {
            dsl.copperLoop.loopLength >= 1000 [SI::metre] and
            dsl.minimumOperationalSnrMargin >= 6 [SI::decibel]
        }
    }

    requirement def FrequencySeparationRequirement {
        doc /* The system shall separate upstream and downstream transmission bands to support simultaneous bidirectional communication. */

        subject dsl : DigitalSubscriberLineSystem;

        require constraint {
            dsl.upstreamFrequencyEnd <= dsl.downstreamFrequencyStart
        }
    }

    requirement def ManagementRequirement {
        doc /* The system shall expose management messaging for initialization, performance monitoring, retraining, and fault reporting. */

        subject dsl : DigitalSubscriberLineSystem;

        require constraint {
            dsl.operationsAccess.messages.messageCode >= 0
        }
    }

    satisfy PrimaryFunctionRequirement by DigitalSubscriberLineSystem;
    satisfy CopperLoopCompatibilityRequirement by DigitalSubscriberLineSystem;
    satisfy FrequencySeparationRequirement by DigitalSubscriberLineSystem;
    satisfy ManagementRequirement by DigitalSubscriberLineSystem;

    part dslService : DigitalSubscriberLineSystem;

}