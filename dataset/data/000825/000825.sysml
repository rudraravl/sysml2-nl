package VonFreyHairSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ForceValue :> ISQ::ForceValue;
    attribute def LengthValue :> ISQ::LengthValue;
    attribute def DiameterValue :> LengthValue;
    
    enum def MaterialType {
        nylon;
        horsehair;
        synthetic;
        metal;
    }
    
    enum def ResponseType {
        noResponse;
        withdrawal;
        vocalization;
        detected;
    }
    
    item def Filament {
        attribute material : MaterialType;
        attribute length : LengthValue;
        attribute diameter : DiameterValue;
        attribute bucklingForce : ForceValue;
        
        assert constraint validForce {
            bucklingForce > 0.0 [N] and bucklingForce <= 300.0 [N]
        }
    }
    
    item def Handle {
        attribute length : LengthValue;
        attribute gripDiameter : DiameterValue;
    }
    
    item def TestSubject {
        attribute sensitivityThreshold : ForceValue;
    }
    
    part def VonFreyHair {
        doc /* A Von Frey hair is a calibrated monofilament instrument that 
             * buckles at a specific force threshold, used to assess tactile 
             * sensitivity and mechanical nociception in biological subjects.
             */
        
        attribute calibratedForce : ForceValue;
        
        part filament : Filament {
            attribute :>> bucklingForce = calibratedForce;
        }
        
        part handle : Handle {
            attribute :>> length = 100.0 [mm];
            attribute :>> gripDiameter = 8.0 [mm];
        }
        
        port contactPoint {
            out appliedForce : ForceValue;
        }
        
        assert constraint forceCalibration {
            filament.bucklingForce == calibratedForce
        }
    }
    
    part def SensoryTestingSystem {
        doc /* A system for quantitative assessment of mechanical sensitivity 
             * using calibrated force application through Von Frey hairs.
             */
        
        attribute currentForce : ForceValue;
        attribute detectedResponse : ResponseType;
        attribute thresholdForce : ForceValue;
        
        part vonFreyInstrument : VonFreyHair {
            attribute :>> calibratedForce : ForceValue;
        }
        
        part subject : TestSubject;
        
        port stimulusPort {
            out stimulus : ForceValue;
        }
        
        port responsePort {
            in response : ResponseType;
        }
        
        connection stimulusConnection connect vonFreyInstrument.contactPoint.appliedForce to stimulusPort.stimulus;
    }
    
    action def PositionInstrument {
        doc /* Position the Von Frey hair perpendicular to the test surface */
        in instrument : VonFreyHair;
        in targetLocation;
    }
    
    action def ApplyForce {
        doc /* Apply force gradually until filament buckles */
        in targetForce : ForceValue;
        out actualForce : ForceValue;
        out buckled : Boolean;
    }
    
    action def ObserveResponse {
        doc /* Observe and record subject response to stimulus */
        in appliedForce : ForceValue;
        in subjectThreshold : ForceValue;
        out response : ResponseType;
    }
    
    action def RecordMeasurement {
        doc /* Record the force and response data */
        in force : ForceValue;
        in response : ResponseType;
    }
    
    action def PerformSensitivityTest {
        doc /* Execute a complete sensory threshold assessment using the 
             * Von Frey hair to determine mechanical sensitivity threshold.
             */
        
        in testInstrument : VonFreyHair;
        in testSubject : TestSubject;
        out thresholdForce : ForceValue;
        out finalResponse : ResponseType;
        
        first start;
        then merge prepareTest;
        
        action position : PositionInstrument {
            in instrument = testInstrument;
        }
        
        then applyForce : ApplyForce {
            in targetForce = testInstrument.calibratedForce;
            out actualForce : ForceValue;
            out buckled : Boolean;
        }
        
        then decide checkBuckling;
            if applyForce.buckled then observeResponse;
            if not applyForce.buckled then increaseForce;
        
        action increaseForce {
            doc /* Increase applied force until filament buckles */
        }
        then prepareTest;
        
        action observeResponse : ObserveResponse {
            in appliedForce = applyForce.actualForce;
            in subjectThreshold = testSubject.sensitivityThreshold;
            out response : ResponseType;
        }
        
        then recordMeasurement : RecordMeasurement {
            in force = applyForce.actualForce;
            in response = observeResponse.response;
        }
        
        then decide evaluateResponse;
            if observeResponse.response == ResponseType::noResponse then selectNextFilament;
            if observeResponse.response != ResponseType::noResponse then determineThreshold;
        
        action selectNextFilament {
            doc /* Select filament with higher calibrated force */
        }
        then prepareTest;
        
        action determineThreshold {
            doc /* Calculate sensory threshold from test series */
        }
        then done;
    }
    
    state def TestingStateMachine {
        entry; then idle;
        
        state idle {
            doc /* Instrument at rest, not in contact */
        }
        
        state positioning {
            doc /* Positioning instrument for test */
        }
        
        state applying {
            doc /* Applying force to subject */
        }
        
        state buckled {
            doc /* Filament has buckled at threshold */
        }
        
        state observing {
            doc /* Observing subject response */
        }
        
        state recording {
            doc /* Recording measurement data */
        }
        
        transition idle_to_positioning
            first idle
            accept StartTest
            then positioning;
        
        transition positioning_to_applying
            first positioning
            accept ContactEstablished
            then applying;
        
        transition applying_to_buckled
            first applying
            accept BucklingDetected
            then buckled;
        
        transition buckled_to_observing
            first buckled
            accept ForceStabilized
            then observing;
        
        transition observing_to_recording
            first observing
            accept ResponseDetected
            then recording;
        
        transition recording_to_idle
            first recording
            accept DataRecorded
            then idle;
    }
    
    part sensoryTestingSystem : SensoryTestingSystem {
        attribute :>> currentForce : ForceValue;
        
        part redefines vonFreyInstrument {
            attribute :>> calibratedForce = 0.16 [N];
            part redefines filament {
                attribute :>> material = MaterialType::nylon;
                attribute :>> length = 38.0 [mm];
                attribute :>> diameter = 0.5 [mm];
            }
        }
        
        part redefines subject {
            attribute :>> sensitivityThreshold = 0.1 [N];
        }
        
        perform action testSequence : PerformSensitivityTest {
            in testInstrument = vonFreyInstrument;
            in testSubject = subject;
        }
        
        exhibit state testBehavior : TestingStateMachine;
    }
    
    requirement <'REQ-VF-001'> primaryFunction {
        doc /* The Von Frey hair system shall deliver calibrated mechanical 
             * stimuli to assess tactile sensitivity and pain thresholds in 
             * biological subjects through controlled force application.
             */
        subject vonFreySystem : VonFreyHair;
    }
    
    requirement <'REQ-VF-002'> forceCalibrationAccuracy {
        doc /* The filament shall buckle at a force within ±5% of the 
             * specified calibrated threshold value to ensure measurement 
             * accuracy.
             */
        subject filament : Filament;
        
        assert constraint {
            filament.bucklingForce >= 0.95 * filament.bucklingForce and
            filament.bucklingForce <= 1.05 * filament.bucklingForce
        }
    }
    
    requirement <'REQ-VF-003'> forceRange {
        doc /* The system shall provide filaments spanning a force range from 
             * 0.008 N to 300 N to assess varying sensitivity levels across 
             * different applications.
             */
        subject system : SensoryTestingSystem;
        
        assert constraint {
            system.vonFreyInstrument.calibratedForce >= 0.008 [N] and
            system.vonFreyInstrument.calibratedForce <= 300.0 [N]
        }
    }
    
    requirement <'REQ-VF-004'> repeatableApplication {
        doc /* The system shall deliver consistent force application across 
             * multiple test repetitions to ensure reliable threshold 
             * determination and reproducible results.
             */
        subject system : SensoryTestingSystem;
    }
    
    requirement <'REQ-VF-005'> thresholdDetection {
        doc /* The system shall accurately determine the minimum force at 
             * which the subject exhibits a detectable response.
             */
        subject system : SensoryTestingSystem;
        
        assert constraint {
            system.thresholdForce == system.subject.sensitivityThreshold
        }
    }
    
    satisfy primaryFunction by sensoryTestingSystem.vonFreyInstrument;
    satisfy forceCalibrationAccuracy by sensoryTestingSystem.vonFreyInstrument.filament;
    satisfy forceRange by sensoryTestingSystem;
    satisfy repeatableApplication by sensoryTestingSystem.testSequence;
    satisfy thresholdDetection by sensoryTestingSystem;
}
