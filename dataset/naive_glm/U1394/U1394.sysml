package CheckWeigherSystem {

    import ScalarValues::*;
    import ISQ::*;
    import ISQ::Mass;
    import ISQ::Speed;
    import ISQ::Force;

    //-----------------------------------------------------------------------
    // Units
    //-----------------------------------------------------------------------
    unit gram;
    unit m_per_s;
    unit newton;

    //-----------------------------------------------------------------------
    // Value Types
    //-----------------------------------------------------------------------
    value type WeightMeasure :> Real {
        unit gram;
    }

    value type SpeedMeasure :> Real {
        unit m_per_s;
    }

    value type ForceMeasure :> Real {
        unit newton;
    }

    value type ToleranceValue :> Real {
        unit gram;
    }

    //-----------------------------------------------------------------------
    // Enumerations
    //-----------------------------------------------------------------------
    enumeration def VerdictType {
        enum underweight;
        enum acceptable;
        enum overweight;
    }

    //-----------------------------------------------------------------------
    // Items
    //-----------------------------------------------------------------------
    item def Product {
        attribute serialId : String;
        attribute batchNumber : String;
    }

    item def MeasurementData {
        attribute productId : String;
        attribute measuredWeight : WeightMeasure;
        attribute timestamp : Integer;
    }

    item def EvaluationResult {
        attribute productId : String;
        attribute measuredWeight : WeightMeasure;
        attribute targetWeight : WeightMeasure;
        attribute lowerBound : WeightMeasure;
        attribute upperBound : WeightMeasure;
        attribute verdict : VerdictType;
    }

    item def RejectCommand {
        attribute shouldReject : Boolean;
        attribute verdict : VerdictType;
        attribute actuationForce : ForceMeasure;
    }

    //-----------------------------------------------------------------------
    // Port Definitions
    //-----------------------------------------------------------------------
    port def ProductInPort {
        in item incomingProduct : Product;
    }

    port def ProductOutPort {
        out item outgoingProduct : Product;
    }

    port def MeasurementOutPort {
        out item measurement : MeasurementData;
    }

    port def MeasurementInPort {
        in item measurement : MeasurementData;
    }

    port def CommandOutPort {
        out item command : RejectCommand;
    }

    port def CommandInPort {
        in item command : RejectCommand;
    }

    //-----------------------------------------------------------------------
    // Action Definitions
    //-----------------------------------------------------------------------
    action def TransportProduct {
        in item inProduct : Product;
        out item outProduct : Product;
    }

    action def MeasureWeight {
        in item product : Product;
        out item measurement : MeasurementData;
    }

    action def EvaluateWeight {
        in item measurement : MeasurementData;
        in attribute targetWeight : WeightMeasure;
        in attribute tolerance : ToleranceValue;
        out item result : EvaluationResult;
    }

    action def DecideReject {
        in item result : EvaluationResult;
        out item command : RejectCommand;
    }

    action def DivertProduct {
        in item product : Product;
        in item command : RejectCommand;
        out item acceptedProduct : Product;
        out item rejectedProduct : Product;
    }

    //-----------------------------------------------------------------------
    // State Machine Definition
    //-----------------------------------------------------------------------
    state def CheckWeigherStates {
        attribute isRunning : Boolean = false;

        state idle {
            entry { isRunning = false; }
        }

        state active {
            entry { isRunning = true; }

            state weighing {
                entry { /* Begin in-motion weight measurement on load cell */ }
            }

            state evaluating {
                entry { /* Compare measured weight against target and tolerances */ }
            }

            state sorting {
                entry { /* Activate or bypass reject mechanism based on verdict */ }
            }

            transition from weighing to evaluating;
            transition from evaluating to sorting;
        }

        transition from idle to active;
        transition from active to idle;
    }

    //-----------------------------------------------------------------------
    // Part Definitions
    //-----------------------------------------------------------------------
    part def InfeedConveyor {
        doc "Transports products from the infeed point to the weighing station at a controlled, constant speed.";
        attribute speed : SpeedMeasure = 0.5 [m_per_s];
        port productIn : ProductInPort;
        port productOut : ProductOutPort;

        action transport : TransportProduct;
    }

    part def WeighingStation {
        doc "A specialized conveyor section equipped with a high-precision load cell for in-motion weight measurement.";
        attribute scalePrecision : WeightMeasure = 0.1 [gram];
        attribute responseTime_ms : Integer = 10;
        port productIn : ProductInPort;
        port productOut : ProductOutPort;
        port measurementOut : MeasurementOutPort;

        action weigh : MeasureWeight;
    }

    part def ControlUnit {
        doc "Central controller comparing measured weight against a pre-set target with upper and lower tolerances and issuing reject commands.";
        attribute targetWeight : WeightMeasure = 500 [gram];
        attribute tolerance : ToleranceValue = 5 [gram];
        attribute lowerLimit : WeightMeasure = targetWeight - tolerance;
        attribute upperLimit : WeightMeasure = targetWeight + tolerance;
        port measurementIn : MeasurementInPort;
        port commandOut : CommandOutPort;

        action evaluate : EvaluateWeight;
        action decide : DecideReject;
    }

    part def RejectMechanism {
        doc "Downstream mechanism that diverts non-compliant products off the main line onto the reject conveyor.";
        attribute mechanismType : String;
        attribute actuationForce : ForceMeasure = 50 [newton];
        attribute responseDelay_ms : Integer = 5;
        port commandIn : CommandInPort;
        port productIn : ProductInPort;
        port productPassOut : ProductOutPort;
        port productRejectOut : ProductOutPort;

        action divert : DivertProduct;
    }

    part def PneumaticPusher :> RejectMechanism {
        doc "Pneumatic pusher reject mechanism — a pneumatically driven arm pushes rejected products sideways.";
        :>> mechanismType = "PneumaticPusher";
        :>> actuationForce = 80 [newton];
    }

    part def AirJet :> RejectMechanism {
        doc "Air jet reject mechanism — a blast of compressed air blows rejected products off the line.";
        :>> mechanismType = "AirJet";
        :>> actuationForce = 30 [newton];
    }

    part def DropFlap :> RejectMechanism {
        doc "Drop flap reject mechanism — a hinged flap opens to let rejected products fall through to the reject conveyor.";
        :>> mechanismType = "DropFlap";
        :>> actuationForce = 0 [newton];
    }

    part def AcceptConveyor {
        doc "Carries weight-compliant products onward to the next processing stage.";
        attribute speed : SpeedMeasure = 0.5 [m_per_s];
        port productIn : ProductInPort;
        port productOut : ProductOutPort;

        action transport : TransportProduct;
    }

    part def RejectConveyor {
        doc "Collects rejected products for subsequent inspection or disposal.";
        attribute speed : SpeedMeasure = 0.3 [m_per_s];
        port productIn : ProductInPort;
        port productOut : ProductOutPort;

        action transport : TransportProduct;
    }

    //-----------------------------------------------------------------------
    // Requirement Definitions
    //-----------------------------------------------------------------------
    requirement def CheckWeigherSystemRequirement {
        doc "The automated in-line check weigher system shall weigh products in motion and sort them by weight compliance.";
    }

    requirement def InfeedTransportRequirement :> CheckWeigherSystemRequirement {
        doc "The infeed conveyor shall transport products at a controlled, constant speed.";
        attribute minSpeed : SpeedMeasure = 0.1 [m_per_s];
        attribute maxSpeed : SpeedMeasure = 1.0 [m_per_s];
        constraint { minSpeed <= maxSpeed }
    }

    requirement def WeightAccuracyRequirement :> CheckWeigherSystemRequirement {
        doc "The weighing station shall measure product weight with a precision of 0.1 g or better.";
        attribute requiredPrecision : WeightMeasure = 0.1 [gram];
        constraint { requiredPrecision <= 0.1 [gram] }
    }

    requirement def WeightComparisonRequirement :> CheckWeigherSystemRequirement {
        doc "The control unit shall compare measured weight against a target weight with configurable upper and lower tolerances.";
        attribute targetWeight : WeightMeasure = 500 [gram];
        attribute tolerance : ToleranceValue = 5 [gram];
        attribute lowerLimit : WeightMeasure = targetWeight - tolerance;
        attribute upperLimit : WeightMeasure = targetWeight + tolerance;
        constraint { lowerLimit < upperLimit }
    }

    requirement def RejectSortingRequirement :> CheckWeigherSystemRequirement {
        doc "The reject mechanism shall divert any product whose weight falls outside the acceptable range.";
        attribute measuredWeight : WeightMeasure;
        attribute lowerLimit : WeightMeasure;
        attribute upperLimit : WeightMeasure;
        attribute shouldReject : Boolean;
        constraint {
            (measuredWeight < lowerLimit or measuredWeight > upperLimit)
            implies shouldReject
        }
    }

    requirement def AcceptPassRequirement :> CheckWeigherSystemRequirement {
        doc "Products within the acceptable weight range shall pass the reject mechanism untouched and continue onto the accept conveyor.";
        attribute measuredWeight : WeightMeasure;
        attribute lowerLimit : WeightMeasure;
        attribute upperLimit : WeightMeasure;
        attribute shouldReject : Boolean;
        constraint {
            (measuredWeight >= lowerLimit and measuredWeight <= upperLimit)
            implies !shouldReject
        }
    }

    requirement def ContinuousOperationRequirement :> CheckWeigherSystemRequirement {
        doc "The system shall operate in a continuous cycle between idle and active states for each product that passes through.";
    }

    requirement def RejectConveyorRequirement :> CheckWeigherSystemRequirement {
        doc "Rejected products shall be channeled onto a separate reject conveyor for inspection or disposal.";
    }

    //-----------------------------------------------------------------------
    // Top-Level Assembly
    //-----------------------------------------------------------------------
    part def CheckWeigherAssembly {
        doc "Complete automated in-line check weigher system assembly.";

        //--- Sub-parts ---
        part infeedConveyor : InfeedConveyor;
        part weighingStation : WeighingStation;
        part controlUnit : ControlUnit;
        part rejectMechanism : RejectMechanism;
        part acceptConveyor : AcceptConveyor;
        part rejectConveyor : RejectConveyor;

        //--- External ports on the assembly ---
        port externalProductIn : ProductInPort;
        port acceptProductOut : ProductOutPort;
        port rejectProductOut : ProductOutPort;

        //--- Connections: product flow and data/command flow ---
        connection externalProductIn to infeedConveyor.productIn;
        connection infeedConveyor.productOut to weighingStation.productIn;
        connection weighingStation.productOut to rejectMechanism.productIn;
        connection weighingStation.measurementOut to controlUnit.measurementIn;
        connection controlUnit.commandOut to rejectMechanism.commandIn;
        connection rejectMechanism.productPassOut to acceptConveyor.productIn;
        connection rejectMechanism.productRejectOut to rejectConveyor.productIn;
        connection acceptConveyor.productOut to acceptProductOut;
        connection rejectConveyor.productOut to rejectProductOut;

        //--- State machine ---
        state operationState : CheckWeigherStates;
    }

    //-----------------------------------------------------------------------
    // Instantiated System
    //-----------------------------------------------------------------------
    part checkWeigherSystem : CheckWeigherAssembly {
        doc "Instantiated check weigher system ready for deployment on a production and packaging line.";
    }
}
