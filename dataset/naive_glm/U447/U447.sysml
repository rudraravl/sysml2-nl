package SensoryTestingSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ---- Value types with units ----
    value def ForceValue :> Real {
        unit 'mN';
    }
    value def LengthValue :> Real {
        unit 'mm';
    }
    value def DurationValue :> Real {
        unit 's';
    }

    // ---- Item definitions ----
    item def Response {
        attribute detected : Boolean;
        attribute kind : String; // "withdrawal", "flinch", "vocalization"
    }

    item def TestOutcome {
        attribute responded : Boolean;
        attribute appliedForce : ForceValue;
        attribute hairIndex : Integer;
        attribute timestamp : String;
    }

    // ---- Requirements ----
    requirement def CalibratedBucklingForce {
        subject filament : Filament;
        attribute targetForce : ForceValue;
        constraint { filament.calibratedBucklingForce == targetForce }
    }

    requirement def ConsistentStimulusDelivery {
        subject hair : VonFreyHair;
        constraint {
            hair.filament.buckles == true implies
            deliveredForce == hair.filament.calibratedBucklingForce
        }
    }

    requirement def ThresholdIdentification {
        subject test : ThresholdTest;
        constraint {
            test.detectedThreshold == min(
                test.record.outcomes.select(o | o.responded == true).appliedForce
            )
        }
    }

    requirement def FullForceRangeCoverage {
        subject set : FilamentSet;
        constraint {
            set.hairs.size >= 2 and
            set.forceRangeMin == set.hairs.first.filament.calibratedBucklingForce and
            set.forceRangeMax == set.hairs.last.filament.calibratedBucklingForce
        }
    }

    // ---- Part definitions ----
    part def Handle {
        attribute material : String default "plastic";
        attribute length : LengthValue default 100.0;
        port def GripPort;
        port grip : GripPort;
    }

    part def Filament {
        attribute material : String default "nylon";
        attribute calibratedBucklingForce : ForceValue;
        attribute tipDiameter : LengthValue;
        attribute length : LengthValue;
        attribute buckles : Boolean default false;

        port def TipContactPort;
        port tip : TipContactPort;

        action def ApplyForce {
            in appliedForce : ForceValue;
            out buckled : Boolean;
            // Buckling occurs when applied force reaches calibrated value
            action buckle {
                in force : ForceValue = appliedForce;
                out result : Boolean = buckled;
            }
        }

        satisfy CalibratedBucklingForce by self {
            attribute targetForce = calibratedBucklingForce;
        }
    }

    part def VonFreyHair {
        attribute index : Integer;
        part handle : Handle;
        part filament : Filament;

        connection handleToFilament : Handle ~~ Filament;

        satisfy ConsistentStimulusDelivery by self;
    }

    part def FilamentSet {
        part hairs : VonFreyHair[2..*] ordered;
        attribute forceRangeMin : ForceValue;
        attribute forceRangeMax : ForceValue;

        satisfy FullForceRangeCoverage by self;
    }

    part def BiologicalSubject {
        attribute id : String;
        attribute species : String;
        attribute testSite : String;

        port def SkinContactPort;
        port skin : SkinContactPort;

        action def ExhibitResponse {
            out response : Response;
        }
    }

    part def Operator {
        attribute name : String;
        attribute selectedHairIndex : Integer default 0;

        action def SelectHair {
            in set : FilamentSet;
            in startIndex : Integer;
            out selected : VonFreyHair;
        }

        action def PositionInstrument {
            in hair : VonFreyHair;
            in subject : BiologicalSubject;
            out positioned : Boolean;
        }

        action def ApplyForceUntilBuckle {
            in hair : VonFreyHair;
            out buckled : Boolean;
            out appliedForce : ForceValue;
        }

        action def ObserveResponse {
            in subject : BiologicalSubject;
            out response : Response;
        }

        action def RecordOutcome {
            in outcome : TestOutcome;
            out recorded : Boolean;
        }

        action def EvaluateThreshold {
            in record : TestRecord;
            out threshold : ForceValue optional;
            out complete : Boolean;
        }
    }

    part def TestRecord {
        attribute subjectId : String;
        attribute outcomes : TestOutcome[0..*];
        attribute detectedThreshold : ForceValue optional;

        action def AddOutcome {
            in outcome : TestOutcome;
            out updated : Boolean;
        }
    }

    // ---- Composite system ----
    part def ThresholdTest {
        part operator : Operator;
        part filamentSet : FilamentSet;
        part subject : BiologicalSubject;
        part record : TestRecord;

        attribute currentHairIndex : Integer default 0;
        attribute lastResponse : Response;
        attribute testComplete : Boolean default false;

        connection operatorToSubject : Operator ~~ BiologicalSubject;
        connection operatorToFilamentSet : Operator ~~ FilamentSet;
        connection operatorToRecord : Operator ~~ TestRecord;

        // Flow items
        flow selectedHair : VonFreyHair;
        flow positionedFlag : Boolean;
        flow buckledFlag : Boolean;
        flow appliedForceFlow : ForceValue;
        flow responseFlow : Response;
        flow outcomeFlow : TestOutcome;
        flow thresholdFlow : ForceValue optional;

        // Composite action describing the test procedure
        action def ConductTest {
            in set : FilamentSet;
            in subj : BiologicalSubject;
            in rec : TestRecord;
            out threshold : ForceValue optional;

            action selectHair : Operator::SelectHair {
                in set = ConductTest.set;
                in startIndex = currentHairIndex;
                out selected = selectedHair;
            }

            action positionInstrument : Operator::PositionInstrument {
                in hair = selectedHair;
                in subject = ConductTest.subj;
                out positioned = positionedFlag;
            }

            action applyForce : Operator::ApplyForceUntilBuckle {
                in hair = selectedHair;
                out buckled = buckledFlag;
                out appliedForce = appliedForceFlow;
            }

            action observe : Operator::ObserveResponse {
                in subject = ConductTest.subj;
                out response = responseFlow;
            }

            action recordOutcome : Operator::RecordOutcome {
                in outcome = outcomeFlow;
                out recorded;
            }

            action evaluate : Operator::EvaluateThreshold {
                in record = ConductTest.rec;
                out threshold = thresholdFlow;
                out complete = testComplete;
            }

            // Construct outcome from observed response and applied force
            action buildOutcome {
                in resp : Response = responseFlow;
                in force : ForceValue = appliedForceFlow;
                in idx : Integer = currentHairIndex;
                out outcome : TestOutcome = outcomeFlow;
            }

            succession selectHair then positionInstrument;
            succession positionInstrument then applyForce;
            succession applyForce then observe;
            succession observe then buildOutcome;
            succession buildOutcome then recordOutcome;
            succession recordOutcome then evaluate;
        }

        // State machine governing the overall test lifecycle
        state def TestLifecycle {
            attribute positioned : Boolean;
            attribute buckled : Boolean;
            attribute responded : Boolean;
            attribute complete : Boolean;

            entry action initialize {
                // Reset record and index
            }

            state selecting {
                do action selectNextHair : Operator::SelectHair;
            }

            state positioning {
                do action position : Operator::PositionInstrument;
            }

            state applying {
                do action apply : Operator::ApplyForceUntilBuckle;
            }

            state observing {
                do action observe : Operator::ObserveResponse;
            }

            state recording {
                do action record : Operator::RecordOutcome;
            }

            state evaluating {
                do action evaluate : Operator::EvaluateThreshold;
            }

            state completed;

            transition init_to_selecting initial -> selecting;

            transition selecting_to_positioning selecting -> positioning
                when selectedHair != null;

            transition positioning_to_applying positioning -> applying
                when positioned == true;

            transition applying_to_observing applying -> observing
                when buckled == true;

            transition observing_to_recording observing -> recording;

            transition recording_to_evaluating recording -> evaluating;

            transition evaluating_to_selecting evaluating -> selecting
                when responded == false and currentHairIndex < filamentSet.hairs.size;

            transition evaluating_to_completed evaluating -> completed
                when responded == true and complete == true;
        }

        perform action lifecycle : TestLifecycle;

        satisfy ThresholdIdentification by self;
    }

    part def SensoryTestingSystem {
        part test : ThresholdTest;
        part operator : Operator := test.operator;
        part filamentSet : FilamentSet := test.filamentSet;
        part subject : BiologicalSubject := test.subject;
        part record : TestRecord := test.record;
    }
}
