package 'Ultra-Wideband Positioning System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def FrequencyValue :> ISQ::FrequencyValue;
    attribute def BandwidthValue :> ISQ::FrequencyValue;
    attribute def PowerValue :> ISQ::PowerValue;
    attribute def DistanceValue :> ISQ::LengthValue;
    attribute def TimeValue :> ISQ::TimeValue;
    attribute def AccuracyValue :> ISQ::LengthValue;
    
    value type Position3D {
        attribute x : DistanceValue;
        attribute y : DistanceValue;
        attribute z : DistanceValue;
    }
    
    item def UWBPulse {
        attribute centerFrequency : FrequencyValue;
        attribute bandwidth : BandwidthValue;
        attribute transmitTime : TimeValue;
        attribute pulseId : ScalarValues::String;
    }
    
    item def RangingMeasurement {
        attribute distance : DistanceValue;
        attribute accuracy : AccuracyValue;
        attribute timestamp : TimeValue;
        attribute anchorId : ScalarValues::String;
        attribute tagId : ScalarValues::String;
    }
    
    attribute def StartRanging;
    attribute def StopRanging;
    attribute def StartPositioning;
    attribute def StopPositioning;
    attribute def CalibrationCmd;
    attribute def SystemReset;
    
    port def UWBRadioPort {
        out txPulse : UWBPulse;
        in rxPulse : UWBPulse;
    }
    
    port def DataPort {
        out rangingData : RangingMeasurement;
        in positionRequest : ScalarValues::String;
        out positionData : Position3D;
    }
    
    port def PowerPort {
        in supply : PowerValue;
    }
    
    port def ControlPort {
        in command : ScalarValues::String;
        out status : ScalarValues::String;
    }
    
    action def GeneratePulse {
        in frequency : FrequencyValue;
        in bw : BandwidthValue;
        out pulse : UWBPulse;
    }
    
    action def TransmitPulse {
        in pulse : UWBPulse;
        in power : PowerValue;
        out transmittedPulse : UWBPulse;
    }
    
    action def ReceivePulse {
        in incomingPulse : UWBPulse;
        out receivedPulse : UWBPulse;
        out receiveTime : TimeValue;
    }
    
    action def CalculateTimeOfFlight {
        in txTime : TimeValue;
        in rxTime : TimeValue;
        out tof : TimeValue;
    }
    
    action def ComputeRange {
        in timeOfFlight : TimeValue;
        out range : DistanceValue;
        private attribute speedOfLight : ISQ::SpeedValue := 299792458.0 * (m / s);
    }
    
    action def TrilaterationCalculation {
        in measurements : RangingMeasurement[3];
        in anchorPositions : Position3D[3];
        out calculatedPosition : Position3D;
    }
    
    action def RangingSequence {
        in anchorId : ScalarValues::String;
        in tagId : ScalarValues::String;
        out measurement : RangingMeasurement;
        
        first start;
        then action generate : GeneratePulse {
            in frequency = 6489.6e6 * Hz;
            in bw = 499.2e6 * Hz;
            out pulse;
        }
        then action transmit : TransmitPulse {
            in pulse = generate.pulse;
            in power = 0.5e-3 * W;
            out transmittedPulse;
        }
        then action receive : ReceivePulse {
            in incomingPulse;
            out receivedPulse;
            out receiveTime;
        }
        then action calcTOF : CalculateTimeOfFlight {
            in txTime = transmit.transmittedPulse.transmitTime;
            in rxTime = receive.receiveTime;
            out tof;
        }
        then action computeRange : ComputeRange {
            in timeOfFlight = calcTOF.tof;
            out range;
        }
        then done;
    }
    
    action def PositioningCycle {
        in anchorIds : ScalarValues::String[4];
        in anchorLocs : Position3D[4];
        in tagId : ScalarValues::String;
        out position : Position3D;
        
        first start;
        then action ranging1 : RangingSequence {
            in anchorId = anchorIds[1];
            in tagId = tagId;
            out measurement;
        }
        then action ranging2 : RangingSequence {
            in anchorId = anchorIds[2];
            in tagId = tagId;
            out measurement;
        }
        then action ranging3 : RangingSequence {
            in anchorId = anchorIds[3];
            in tagId = tagId;
            out measurement;
        }
        then action calculatePosition : TrilaterationCalculation {
            in measurements = (ranging1.measurement, ranging2.measurement, ranging3.measurement);
            in anchorPositions = (anchorLocs[1], anchorLocs[2], anchorLocs[3]);
            out calculatedPosition;
        }
        then done;
    }
    
    part def UWBTag {
        attribute tagId : ScalarValues::String;
        
        port radio : UWBRadioPort;
        port data : DataPort;
        port power : PowerPort;
        port control : ControlPort;
        
        part pulseGenerator {
            perform action generate : GeneratePulse;
        }
        
        part transmitter {
            perform action transmit : TransmitPulse;
        }
        
        part receiver {
            perform action receive : ReceivePulse;
        }
        
        part processor {
            perform action process : ComputeRange;
        }
    }
    
    part def UWBAnchor {
        attribute anchorId : ScalarValues::String;
        attribute position : Position3D;
        
        port radio : UWBRadioPort;
        port data : DataPort;
        port power : PowerPort;
        port control : ControlPort;
        
        part pulseGenerator {
            perform action generate : GeneratePulse;
        }
        
        part transmitter {
            perform action transmit : TransmitPulse;
        }
        
        part receiver {
            perform action receive : ReceivePulse;
        }
        
        part timestampUnit {
            perform action timestamp : CalculateTimeOfFlight;
        }
    }
    
    part def PositioningEngine {
        port dataInputs : DataPort[4];
        port positionOutput : DataPort;
        port control : ControlPort;
        
        perform action computePosition : TrilaterationCalculation;
    }
    
    part def UWBChannel {
        port nodes : UWBRadioPort[*];
    }
    
    state def UWBSystemStates {
        entry; then idle;
        
        state idle {
            entry assign systemMode := "Idle";
        }
        
        transition idle_to_calibration
            first idle
            accept calibrate : CalibrationCmd
            then calibrating;
        
        state calibrating {
            entry assign systemMode := "Calibrating";
        }
        
        transition calibration_to_ready
            first calibrating
            then ready;
        
        state ready {
            entry assign systemMode := "Ready";
        }
        
        transition ready_to_ranging
            first ready
            accept startRange : StartRanging
            then ranging;
        
        state ranging {
            entry assign systemMode := "Ranging";
            do action performRanging : RangingSequence;
        }
        
        transition ranging_to_ready
            first ranging
            accept stopRange : StopRanging
            then ready;
        
        transition ready_to_positioning
            first ready
            accept startPos : StartPositioning
            then positioning;
        
        state positioning {
            entry assign systemMode := "Positioning";
            do action performPositioning : PositioningCycle;
        }
        
        transition positioning_to_ready
            first positioning
            accept stopPos : StopPositioning
            then ready;
        
        transition all_to_idle
            first idle
            accept reset : SystemReset
            then idle;
        
        attribute systemMode : ScalarValues::String;
    }
    
    part def UWBPositioningSystem {
        part tag : UWBTag;
        part anchors : UWBAnchor[4];
        part engine : PositioningEngine;
        part channel : UWBChannel;
        part powerSupply;
    }
    
    part uwbPositioningSystem : UWBPositioningSystem {
        doc /*
            An Ultra-Wideband Real-Time Location System that determines the precise 
            three-dimensional position of mobile tags using time-of-flight measurements 
            from multiple fixed anchor points. The system transmits extremely short-duration 
            radio pulses across a wide frequency spectrum to achieve centimeter-level 
            positioning accuracy in indoor and outdoor environments.
        */
        
        part redefines tag : UWBTag {
            attribute :>> tagId = "TAG-001";
        }
        
        part redefines anchors : UWBAnchor[4];
        
        part redefines engine : PositioningEngine;
        
        part redefines channel : UWBChannel;
        
        part redefines powerSupply {
            port output : PowerPort;
        }
        
        connect tag.radio to channel.nodes;
        connect anchors[1].radio to channel.nodes;
        connect anchors[2].radio to channel.nodes;
        connect anchors[3].radio to channel.nodes;
        connect anchors[4].radio to channel.nodes;
        
        connect anchors[1].data to engine.dataInputs[1];
        connect anchors[2].data to engine.dataInputs[2];
        connect anchors[3].data to engine.dataInputs[3];
        connect anchors[4].data to engine.dataInputs[4];
        
        connect powerSupply.output to tag.power;
        connect powerSupply.output to anchors[1].power;
        connect powerSupply.output to anchors[2].power;
        connect powerSupply.output to anchors[3].power;
        connect powerSupply.output to anchors[4].power;
        
        perform action locateTag {
            first start;
            then merge positioningLoop;
            then action positioning : PositioningCycle {
                in anchorIds = ("ANCHOR-1", "ANCHOR-2", "ANCHOR-3", "ANCHOR-4");
                in anchorLocs;
                in tagId = tag.tagId;
                out position;
            }
            then positioningLoop;
        }
        
        exhibit state systemState : UWBSystemStates;
    }
    
    requirement def PerformanceRequirement;
    requirement def FunctionalRequirement;
    requirement def RegulatoryRequirement;
    
    requirement <'UWB-REQ-001'> positioningAccuracy : PerformanceRequirement {
        doc /*
            The UWB positioning system shall determine the 3D position of a tag 
            with an accuracy of 10 centimeters or better within the calibrated area.
        */
        subject uwbPositioningSystem;
    }
    
    requirement <'UWB-REQ-002'> updateRate : PerformanceRequirement {
        doc /*
            The system shall provide position updates at a minimum rate of 10 Hz 
            for each active tag.
        */
        subject uwbPositioningSystem;
    }
    
    requirement <'UWB-REQ-003'> rangingDistance : PerformanceRequirement {
        doc /*
            The system shall support ranging measurements up to 100 meters 
            line-of-sight distance between tag and anchor.
        */
        subject uwbPositioningSystem;
    }
    
    requirement <'UWB-REQ-004'> bandwidthCompliance : RegulatoryRequirement {
        doc /*
            The UWB system shall operate with a minimum bandwidth of 500 MHz 
            centered at 6.5 GHz in compliance with FCC Part 15 regulations.
        */
        subject uwbPositioningSystem;
    }
    
    requirement <'UWB-REQ-005'> powerConsumption : PerformanceRequirement {
        doc /*
            Each tag shall consume less than 100 milliwatts average power 
            during active positioning operations.
        */
        subject uwbPositioningSystem.tag;
    }
    
    requirement <'UWB-REQ-006'> multiTagSupport : FunctionalRequirement {
        doc /*
            The system shall support simultaneous tracking of at least 50 tags 
            within the coverage area without degradation in accuracy.
        */
        subject uwbPositioningSystem;
    }
    
    requirement <'UWB-REQ-007'> primaryFunction : FunctionalRequirement {
        doc /*
            The UWB positioning system shall use time-of-flight measurements 
            from ultra-wideband radio pulses to determine precise 3D positions 
            of mobile tags relative to fixed anchor points through trilateration.
        */
        subject uwbPositioningSystem;
        
        require positioningAccuracy;
        require updateRate;
        require rangingDistance;
    }
    
    requirement systemMission {
        doc /*
            The Ultra-Wideband Positioning System shall provide real-time, 
            high-precision indoor and outdoor location tracking for assets, 
            personnel, and equipment using ultra-wideband radio technology 
            to enable applications in manufacturing, logistics, healthcare, 
            and safety monitoring.
        */
        
        require primaryFunction;
        require bandwidthCompliance;
        require powerConsumption;
        require multiTagSupport;
    }
}
