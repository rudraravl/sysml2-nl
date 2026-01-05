package ReflexHammerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def StimulusIntensity;
    attribute def ReflexMagnitude;
    
    enum def ReflexType {
        patellar;
        achilles;
        biceps;
        triceps;
        brachioradialis;
    }
    
    enum def ResponseGrade {
        absent = 0;
        diminished = 1;
        normal = 2;
        brisk = 3;
        hyperactive = 4;
    }
    
    item def MechanicalStimulus {
        attribute impactForce : ForceValue;
        attribute impactDuration : TimeValue;
        attribute impactVelocity : SpeedValue;
    }
    
    item def ReflexResponse {
        attribute responseGrade : ResponseGrade;
        attribute latency : TimeValue;
        attribute magnitude : ReflexMagnitude;
    }
    
    port def GripPort;
    
    port def ImpactPort {
        out stimulus : MechanicalStimulus;
    }
    
    port def TendonPort {
        in stimulus : MechanicalStimulus;
        out response : ReflexResponse;
    }
    
    part def HammerHead {
        attribute mass : MassValue;
        attribute length : LengthValue;
        attribute material : String;
        attribute hardness : Real;
        attribute impactSurfaceArea : AreaValue;
    }
    
    part def HammerHandle {
        attribute mass : MassValue;
        attribute length : LengthValue;
        attribute diameter : LengthValue;
        attribute gripMaterial : String;
        port grip : GripPort;
    }
    
    part def ReflexHammer {
        attribute totalMass : MassValue;
        attribute totalLength : LengthValue;
        
        part head : HammerHead {
            attribute :>> mass : MassValue;
            attribute :>> length : LengthValue;
            attribute :>> material = "medical grade rubber";
            attribute :>> hardness = 0.70;
            attribute :>> impactSurfaceArea : AreaValue;
        }
        
        part handle : HammerHandle {
            attribute :>> mass : MassValue;
            attribute :>> length : LengthValue;
            attribute :>> diameter : LengthValue;
            attribute :>> gripMaterial = "textured rubber";
        }
        
        port grip : GripPort = handle.grip;
        port impactor : ImpactPort;
        
        assert constraint massBalance {
            totalMass == head.mass + handle.mass
        }
        
        assert constraint lengthBalance {
            totalLength == head.length + handle.length
        }
    }
    
    part def Clinician {
        attribute name : String;
        attribute experience : Real;
        port hand : GripPort;
    }
    
    part def Patient {
        attribute patientID : String;
        attribute age : Real;
        port tendon : TendonPort;
    }
    
    action def PositionHammer {
        in targetTendon : TendonPort;
        in hammer : ReflexHammer;
        out positioned : Boolean;
    }
    
    action def DeliverStrike {
        in hammer : ReflexHammer;
        in targetTendon : TendonPort;
        out stimulus : MechanicalStimulus;
    }
    
    action def ObserveReflex {
        in patient : Patient;
        in expectedLatency : TimeValue;
        out response : ReflexResponse;
    }
    
    action def AssessResponse {
        in response : ReflexResponse;
        in reflexType : ReflexType;
        out grade : ResponseGrade;
        out assessment : String;
    }
    
    action def PerformReflexExamination {
        in hammer : ReflexHammer;
        in clinician : Clinician;
        in patient : Patient;
        in reflexType : ReflexType;
        out finalGrade : ResponseGrade;
        out examinationComplete : Boolean;
        
        first start;
        
        then action position : PositionHammer {
            in targetTendon = patient.tendon;
            in hammer = hammer;
            out positioned;
        }
        
        then decide;
            if position.positioned then strike;
            if !position.positioned then reposition;
        
        action reposition;
        then position;
        
        action strike : DeliverStrike {
            in hammer = hammer;
            in targetTendon = patient.tendon;
            out stimulus;
        }
        
        then action observe : ObserveReflex {
            in patient = patient;
            in expectedLatency = 0.025 [s];
            out response;
        }
        
        then action assess : AssessResponse {
            in response = observe.response;
            in reflexType = reflexType;
            out grade;
            out assessment;
        }
        
        then action recordResults {
            in grade = assess.grade;
            in assessment = assess.assessment;
            out recorded : Boolean;
        }
        
        then decide;
            if recordResults.recorded then complete;
            if !recordResults.recorded then strike;
        
        action complete {
            assign finalGrade = assess.grade;
            assign examinationComplete = true;
        }
        
        then done;
    }
    
    requirement def FunctionalRequirement;
    requirement def PerformanceRequirement;
    requirement def SafetyRequirement;
    requirement def UsabilityRequirement;
    
    requirement <'REQ-RH-001'> primaryFunction : FunctionalRequirement {
        doc /* The Reflex Hammer System shall enable a clinician to elicit 
             * and assess deep tendon reflexes by delivering controlled 
             * mechanical stimulation to specific tendons and observing 
             * the resulting involuntary muscle contractions.
             */
        subject system : ReflexHammerSystem;
    }
    
    requirement <'REQ-RH-002'> impactForceRange : PerformanceRequirement {
        doc /* The reflex hammer shall deliver an impact force between 
             * 8 N and 25 N to adequately stimulate tendon reflexes 
             * without causing patient discomfort or tissue damage.
             */
        subject hammer : ReflexHammer;
        attribute strikeForce : ForceValue;
        
        require constraint {
            strikeForce >= 8.0 [N] and strikeForce <= 25.0 [N]
        }
    }
    
    requirement <'REQ-RH-003'> hammerMassLimit : PerformanceRequirement {
        doc /* The total mass of the reflex hammer shall not exceed 
             * 200 grams to ensure precise control and minimize 
             * clinician fatigue during repeated examinations.
             */
        subject hammer : ReflexHammer;
        
        require constraint {
            hammer.totalMass <= 200.0 [g]
        }
    }
    
    requirement <'REQ-RH-004'> impactSurfaceSafety : SafetyRequirement {
        doc /* The hammer head impact surface shall be constructed of 
             * medical-grade elastomeric material with hardness between 
             * 60 and 80 Shore A to prevent tissue trauma.
             */
        subject head : HammerHead;
        
        require constraint {
            head.hardness >= 0.60 and head.hardness <= 0.80
        }
    }
    
    requirement <'REQ-RH-005'> responseDetection : FunctionalRequirement {
        doc /* The system shall enable detection and grading of reflex 
             * responses across five standardized levels from absent (0) 
             * to hyperactive (4+) according to clinical standards.
             */
        subject examination : PerformReflexExamination;
    }
    
    requirement <'REQ-RH-006'> ergonomicDesign : UsabilityRequirement {
        doc /* The hammer handle shall provide a secure, comfortable grip 
             * with length between 150 mm and 200 mm and diameter between 
             * 12 mm and 18 mm for optimal control.
             */
        subject handle : HammerHandle;
        
        require constraint {
            handle.length >= 150.0 [mm] and handle.length <= 200.0 [mm] and
            handle.diameter >= 12.0 [mm] and handle.diameter <= 18.0 [mm]
        }
    }
    
    part def ReflexHammerSystem {
        part hammer : ReflexHammer {
            attribute :>> totalMass = 185.0 [g];
            attribute :>> totalLength = 240.0 [mm];
            
            part :>> head {
                attribute :>> mass = 95.0 [g];
                attribute :>> length = 55.0 [mm];
                attribute :>> impactSurfaceArea = 450.0 [mm^2];
            }
            
            part :>> handle {
                attribute :>> mass = 90.0 [g];
                attribute :>> length = 185.0 [mm];
                attribute :>> diameter = 15.0 [mm];
            }
        }
        
        part clinician : Clinician {
            attribute :>> name = "Dr. Smith";
            attribute :>> experience = 12.0;
        }
        
        part patient : Patient {
            attribute :>> patientID = "PT-2024-001";
            attribute :>> age = 45.0;
        }
        
        connect clinician.hand to hammer.grip;
        
        connect hammer.impactor to patient.tendon {
            item flow mechanicalStimulus : MechanicalStimulus
                from hammer.impactor to patient.tendon;
            item flow reflexResponse : ReflexResponse
                from patient.tendon to hammer.impactor;
        }
        
        perform action examination : PerformReflexExamination {
            in hammer = hammer;
            in clinician = clinician;
            in patient = patient;
            in reflexType = ReflexType::patellar;
            out finalGrade;
            out examinationComplete;
        }
    }
    
    part reflexHammerSystem : ReflexHammerSystem;
    
    satisfy primaryFunction by reflexHammerSystem;
    satisfy impactForceRange by reflexHammerSystem.hammer;
    satisfy hammerMassLimit by reflexHammerSystem.hammer;
    satisfy impactSurfaceSafety by reflexHammerSystem.hammer.head;
    satisfy responseDetection by reflexHammerSystem.examination;
    satisfy ergonomicDesign by reflexHammerSystem.hammer.handle;
}
