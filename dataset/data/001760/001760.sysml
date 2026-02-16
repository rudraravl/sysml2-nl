package CheckWeigherSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def WeightSpecification {
        attribute targetWeight : MassValue;
        attribute lowerTolerance : MassValue;
        attribute upperTolerance : MassValue;
    }
    
    attribute def MeasurementResult {
        attribute measuredWeight : MassValue;
        attribute withinSpec : Boolean;
        attribute deviation : MassValue;
    }
    
    item def Product {
        attribute productID : String;
        attribute actualMass : MassValue;
        attribute batchNumber : String;
    }
    
    port def ProductInputPort {
        in item incomingProduct : Product;
    }
    
    port def ProductOutputPort {
        out item outgoingProduct : Product;
    }
    
    port def WeightDataPort {
        out attribute weight : MassValue;
    }
    
    port def ControlSignalPort {
        out attribute rejectSignal : Boolean;
    }
    
    part def InfeedConveyor {
        attribute speed : SpeedValue;
        port productOut : ProductOutputPort;
        
        perform action transportProduct {
            out item deliveredProduct : Product;
        }
    }
    
    part def WeighingStation {
        attribute calibrationOffset : MassValue;
        attribute measurementAccuracy : MassValue;
        
        port productIn : ProductInputPort;
        port productOut : ProductOutputPort;
        port weightData : WeightDataPort;
        
        perform action weighProduct {
            in item productToWeigh : Product;
            out weight : MassValue;
            out item weighedProduct : Product;
        }
    }
    
    part def ControlUnit {
        attribute specification : WeightSpecification;
        
        perform action evaluateWeight {
            in measuredWeight : MassValue;
            in spec : WeightSpecification;
            out result : MeasurementResult;
        }
    }
    
    part def RejectMechanism {
        attribute actuationDelay : TimeValue;
        
        port productIn : ProductInputPort;
        port rejectOut : ProductOutputPort;
        port controlSignal : ControlSignalPort;
        
        perform action divertProduct {
            in item productToDivert : Product;
            in shouldReject : Boolean;
            out item divertedProduct : Product;
        }
    }
    
    part def AcceptConveyor {
        attribute speed : SpeedValue;
        port productIn : ProductInputPort;
        port productOut : ProductOutputPort;
        
        perform action collectAccepted {
            in item acceptedProduct : Product;
        }
    }
    
    part def RejectConveyor {
        attribute speed : SpeedValue;
        port productIn : ProductInputPort;
        port productOut : ProductOutputPort;
        
        perform action collectRejected {
            in item rejectedProduct : Product;
        }
    }
    
    action def CheckWeighingCycle {
        first start;
        
        then action receiveProduct {
            out item receivedProduct : Product;
        }
        
        then action performWeighing {
            in item product = receiveProduct.receivedProduct;
            out measuredWeight : MassValue;
            out item weighedProduct : Product;
        }
        
        then action evaluateMeasurement {
            in weight = performWeighing.measuredWeight;
            in specification : WeightSpecification;
            out isAcceptable : Boolean;
            out result : MeasurementResult;
        }
        
        then decide;
            if evaluateMeasurement.isAcceptable then acceptProduct;
            if not evaluateMeasurement.isAcceptable then rejectProduct;
        
        action acceptProduct {
            in item product = performWeighing.weighedProduct;
            out item acceptedProduct : Product = product;
        }
        then recordAcceptance;
        
        action rejectProduct {
            in item product = performWeighing.weighedProduct;
            out item rejectedProduct : Product = product;
        }
        then recordRejection;
        
        action recordAcceptance {
            in result = evaluateMeasurement.result;
        }
        then done;
        
        action recordRejection {
            in result = evaluateMeasurement.result;
        }
        then done;
    }
    
    state def CheckWeigherOperationalStates {
        entry; then idle;
        
        state idle;
        
        transition idle_to_active
            first idle
            then active;
        
        state active {
            entry; then weighing;
            
            state weighing;
            
            transition weighing_to_evaluating
                first weighing
                then evaluating;
            
            state evaluating;
            
            transition evaluating_to_sorting
                first evaluating
                then sorting;
            
            state sorting;
            
            transition sorting_to_complete
                first sorting
                then complete;
            
            state complete;
        }
        
        transition active_to_idle
            first active.complete
            then idle;
        
        state fault;
        
        transition fault_to_idle
            first fault
            then idle;
    }
    
    part def CheckWeigher {
        attribute weightSpec : WeightSpecification {
            attribute :>> targetWeight = 500.0[g];
            attribute :>> lowerTolerance = 5.0[g];
            attribute :>> upperTolerance = 5.0[g];
        }
        
        attribute totalProcessed : Integer;
        attribute totalAccepted : Integer;
        attribute totalRejected : Integer;
        
        port systemInput : ProductInputPort;
        port acceptedOutput : ProductOutputPort;
        port rejectedOutput : ProductOutputPort;
        
        part infeed : InfeedConveyor {
            attribute :>> speed = 0.5[m/s];
        }
        
        part weighStation : WeighingStation {
            attribute :>> calibrationOffset = 0.0[g];
            attribute :>> measurementAccuracy = 0.1[g];
        }
        
        part controller : ControlUnit {
            attribute :>> specification = weightSpec;
        }
        
        part rejector : RejectMechanism {
            attribute :>> actuationDelay = 0.05[s];
        }
        
        part acceptPath : AcceptConveyor {
            attribute :>> speed = 0.5[m/s];
        }
        
        part rejectPath : RejectConveyor {
            attribute :>> speed = 0.5[m/s];
        }
        
        connect systemInput to infeed.productOut;
        connect infeed.productOut to weighStation.productIn;
        connect weighStation.weightData to controller;
        connect weighStation.productOut to rejector.productIn;
        connect controller to rejector.controlSignal;
        connect rejector.productOut to acceptPath.productIn;
        connect rejector.rejectOut to rejectPath.productIn;
        connect acceptPath.productOut to acceptedOutput;
        connect rejectPath.productOut to rejectedOutput;
        
        perform action checkWeighingCycle : CheckWeighingCycle[*] ordered;
    }
    
    part checkWeigherSystem : CheckWeigher;
    
    requirement def FunctionalRequirement;
    requirement def PerformanceRequirement;
    requirement def AccuracyRequirement;
    
    requirement <'CW-REQ-001'> primaryFunction : FunctionalRequirement {
        doc /* 
            The check weigher system shall automatically weigh products in continuous motion 
            and segregate them into accept and reject streams based on whether their measured 
            weight falls within specified tolerance limits around a target weight.
        */
        
        subject system : CheckWeigher;
        
        assume constraint continuousFlow {
            doc /* Products arrive continuously on the infeed conveyor. */
        }
        
        require constraint automaticWeighing {
            doc /* Each product shall be weighed automatically without stopping the conveyor. */
        }
        
        require constraint weightBasedSorting {
            doc /* Products shall be sorted based on weight measurement against specification. */
            system.weightSpec.targetWeight - system.weightSpec.lowerTolerance <= 
                system.weighStation.weightData.weight and
            system.weighStation.weightData.weight <= 
                system.weightSpec.targetWeight + system.weightSpec.upperTolerance
        }
        
        require constraint physicalSegregation {
            doc /* Accepted and rejected products shall be physically separated into different output paths. */
        }
    }
    
    requirement <'CW-REQ-002'> measurementAccuracy : AccuracyRequirement {
        doc /* 
            The weighing station shall measure product weight with an accuracy of ±0.1 grams 
            or better to ensure reliable quality control.
        */
        
        subject station : WeighingStation;
        
        require constraint precisionLimit {
            station.measurementAccuracy <= 0.1[g]
        }
    }
    
    requirement <'CW-REQ-003'> throughputPerformance : PerformanceRequirement {
        doc /* 
            The system shall maintain a minimum throughput rate to support production requirements.
        */
        
        subject system : CheckWeigher;
        
        require constraint minimumSpeed {
            system.infeed.speed >= 0.3[m/s]
        }
        
        require constraint responseTime {
            system.rejector.actuationDelay <= 0.1[s]
        }
    }
}
