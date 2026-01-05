package WartenbergWheelNeurologicalSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def PressureValue :> Real;
    attribute def RotationRateValue :> Real;
    attribute def SensoryResponseLevel :> Real;
    
    attribute def ForceValue :> ISQ::force;
    attribute def AngleValue :> ISQ::angle;
    
    item def StimulusEvent {
        attribute location : String;
        attribute intensity : PressureValue;
        attribute timestamp : Real;
    }
    
    item def PatientResponse {
        attribute responseDetected : Boolean;
        attribute responseIntensity : SensoryResponseLevel;
        attribute responseLocation : String;
    }
    
    port def MechanicalInputPort {
        in appliedForce : ForceValue;
        in rotationRate : RotationRateValue;
    }
    
    port def StimulusOutputPort {
        out stimulusEvent : StimulusEvent;
    }
    
    port def ResponseInputPort {
        in patientResponse : PatientResponse;
    }
    
    part def Pin {
        attribute length : LengthValue;
        attribute tipDiameter : LengthValue;
        attribute sharpness : Real;
        
        port contactInterface {
            in normalForce : ForceValue;
            out contactPressure : PressureValue;
        }
    }
    
    part def RotatingWheel {
        attribute diameter : LengthValue;
        attribute thickness : LengthValue;
        attribute pinCount : Integer;
        attribute currentAngle : AngleValue;
        
        part pins : Pin[pinCount] {
            attribute :>> length = 2.5 [mm];
            attribute :>> tipDiameter = 0.3 [mm];
        }
        
        port rotationInterface {
            in torque : Real;
            out angularVelocity : Real;
        }
        
        port stimulusOutput : StimulusOutputPort;
    }
    
    part def HandleAssembly {
        attribute handleLength : LengthValue;
        attribute gripDiameter : LengthValue;
        attribute ergonomicDesign : Boolean;
        
        port userInterface : MechanicalInputPort;
        
        port transmissionInterface {
            out transmittedForce : ForceValue;
            out transmittedTorque : Real;
        }
    }
    
    part def Axle {
        attribute axleDiameter : LengthValue;
        attribute axleLength : LengthValue;
        attribute bearingType : String;
        
        port driveInput {
            in inputTorque : Real;
        }
        
        port driveOutput {
            out outputTorque : Real;
        }
    }
    
    part def SkinContactSurface {
        attribute surfaceArea : AreaValue;
        attribute sensitivity : Real;
        
        port contactPort {
            in appliedStimulus : StimulusEvent;
            out mechanicalResponse : PatientResponse;
        }
    }
    
    part def WartenbergWheelDevice {
        attribute totalMass : MassValue;
        attribute overallLength : LengthValue;
        attribute wheelDiameter : LengthValue = 22.0 [mm];
        attribute numberOfPins : Integer = 20;
        attribute maxAppliedForce : ForceValue;
        
        part handle : HandleAssembly {
            attribute :>> handleLength = 140.0 [mm];
            attribute :>> gripDiameter = 10.0 [mm];
            attribute :>> ergonomicDesign = true;
        }
        
        part axle : Axle {
            attribute :>> axleDiameter = 2.5 [mm];
            attribute :>> axleLength = 15.0 [mm];
            attribute :>> bearingType = "low-friction";
        }
        
        part wheel : RotatingWheel {
            attribute :>> diameter = wheelDiameter;
            attribute :>> thickness = 3.0 [mm];
            attribute :>> pinCount = numberOfPins;
        }
        
        part skinSurface : SkinContactSurface {
            attribute :>> surfaceArea = 100.0 [mm^2];
            attribute :>> sensitivity = 0.8;
        }
        
        connection handleToAxle connect handle.transmissionInterface.transmittedTorque to axle.driveInput.inputTorque;
        connection axleToWheel connect axle.driveOutput.outputTorque to wheel.rotationInterface.torque;
        connection wheelToSkin connect wheel.stimulusOutput.stimulusEvent to skinSurface.contactPort.appliedStimulus;
        
        assert constraint deviceMassLimit {
            totalMass <= 60.0 [g]
        }
        
        assert constraint forceLimit {
            maxAppliedForce <= 2.0 [N]
        }
        
        assert constraint pinCountRange {
            numberOfPins >= 18 and numberOfPins <= 24
        }
    }
    
    action def PositionDevice {
        in targetLocation : String;
        out devicePositioned : Boolean;
        
        first start;
        then done;
    }
    
    action def ApplyControlledPressure {
        in desiredForce : ForceValue;
        out actualPressure : PressureValue;
        
        first start;
        then done;
    }
    
    action def RollWheelAcrossSkin {
        in rollingSpeed : RotationRateValue;
        in pathLength : LengthValue;
        out stimuliGenerated : StimulusEvent[*];
        
        first start;
        then done;
    }
    
    action def MonitorPatientResponse {
        in stimulusApplied : StimulusEvent;
        out responseData : PatientResponse;
        
        first start;
        then done;
    }
    
    action def DocumentFindings {
        in responses : PatientResponse[*];
        out clinicalReport : String;
        
        first start;
        then done;
    }
    
    action def PerformSensoryNerveAssessment {
        in assessmentLocation : String;
        in targetPressure : ForceValue;
        in rollingDistance : LengthValue;
        out assessmentComplete : Boolean;
        out collectedResponses : PatientResponse[*];
        
        first start;
        
        then position : PositionDevice {
            in targetLocation = assessmentLocation;
        }
        
        then applyPressure : ApplyControlledPressure {
            in desiredForce = targetPressure;
        }
        
        then merge continuousAssessment;
        
        then action rollWheel : RollWheelAcrossSkin {
            in rollingSpeed : RotationRateValue = 5.0;
            in pathLength = rollingDistance;
            out stimuliGenerated : StimulusEvent[*];
        }
        
        then monitor : MonitorPatientResponse {
            in stimulusApplied : StimulusEvent;
            out responseData : PatientResponse;
        }
        
        then decide evaluationDecision;
        
        if evaluationDecision.continueRolling then continuousAssessment;
        if evaluationDecision.assessmentComplete then document;
        
        decision evaluationDecision {
            out continueRolling : Boolean;
            out assessmentComplete : Boolean;
        }
        
        action document : DocumentFindings {
            in responses = collectedResponses;
            out clinicalReport : String;
        }
        
        then done;
    }
    
    state def DeviceOperationalStates {
        entry; then ready;
        
        state ready {
            doc /* Device is prepared for use but not in contact with patient. */
        }
        
        transition ready_to_positioned
            first ready
            accept DevicePositioned
            then positioned;
        
        state positioned {
            doc /* Device is positioned on skin surface with initial contact. */
            entry action establishContact;
        }
        
        transition positioned_to_stimulating
            first positioned
            accept RollingInitiated
            then stimulating;
        
        state stimulating {
            doc /* Wheel is actively rolling and generating tactile stimuli. */
            entry action beginStimulation;
            do action generateContinuousStimuli;
            exit action endStimulation;
        }
        
        transition stimulating_to_positioned
            first stimulating
            accept RollingPaused
            then positioned;
        
        transition positioned_to_ready
            first positioned
            accept DeviceLifted
            then ready;
        
        transition stimulating_to_ready
            first stimulating
            accept DeviceLifted
            then ready;
    }
    
    requirement def PrimaryFunctionRequirement;
    requirement def SafetyRequirement;
    requirement def PerformanceRequirement;
    
    requirement <'REQ-WW-100'> primaryNeurologicalFunction : PrimaryFunctionRequirement {
        doc /* The Wartenberg wheel system shall provide controlled, repeatable 
             * tactile stimulation to assess peripheral sensory nerve function by 
             * rolling a spiked wheel across the patient's skin surface to evaluate 
             * sensory perception, nerve integrity, and dermatome mapping.
             */
        subject device : WartenbergWheelDevice;
    }
    
    requirement <'REQ-WW-101'> stimulusDelivery : PerformanceRequirement {
        doc /* The system shall deliver discrete tactile stimuli through sequential 
             * pin contacts as the wheel rotates, with each pin providing consistent 
             * pressure to the skin surface.
             */
        subject wheel :>> WartenbergWheelDevice::wheel;
        require primaryNeurologicalFunction;
    }
    
    requirement <'REQ-WW-102'> wheelGeometrySpecification : PerformanceRequirement {
        doc /* The rotating wheel shall have a diameter between 20-25mm with 
             * 18-24 evenly spaced pins to provide optimal stimulus frequency 
             * during clinical examination.
             */
        subject wheel :>> WartenbergWheelDevice::wheel;
        
        assert constraint {
            wheel.diameter >= 20.0 [mm] and
            wheel.diameter <= 25.0 [mm] and
            wheel.pinCount >= 18 and
            wheel.pinCount <= 24
        }
    }
    
    requirement <'REQ-WW-103'> pinDesignSpecification : SafetyRequirement {
        doc /* Each pin shall have a length of 2-3mm with a blunt tip diameter 
             * of at least 0.2mm to provide adequate sensory stimulus while 
             * preventing skin puncture or tissue damage.
             */
        subject pins :>> WartenbergWheelDevice::wheel.pins;
        
        assert constraint {
            pins.length >= 2.0 [mm] and
            pins.length <= 3.0 [mm] and
            pins.tipDiameter >= 0.2 [mm]
        }
    }
    
    requirement <'REQ-WW-104'> forceApplicationLimit : SafetyRequirement {
        doc /* The maximum force applied to the patient's skin shall not exceed 
             * 2.0 Newtons to ensure patient comfort and prevent tissue trauma 
             * during neurological assessment.
             */
        subject device :>> WartenbergWheelDevice;
        
        assert constraint {
            device.maxAppliedForce <= 2.0 [N]
        }
    }
    
    requirement <'REQ-WW-105'> devicePortability : PerformanceRequirement {
        doc /* The complete device shall have a total mass not exceeding 60 grams 
             * and an overall length of 130-150mm to ensure ease of handling, 
             * precise control, and portability for clinical use.
             */
        subject device :>> WartenbergWheelDevice;
        
        assert constraint {
            device.totalMass <= 60.0 [g] and
            device.overallLength >= 130.0 [mm] and
            device.overallLength <= 150.0 [mm]
        }
    }
    
    part clinicalWartenbergWheel : WartenbergWheelDevice {
        attribute :>> totalMass = 45.0 [g];
        attribute :>> overallLength = 142.0 [mm];
        attribute :>> wheelDiameter = 22.0 [mm];
        attribute :>> numberOfPins = 20;
        attribute :>> maxAppliedForce = 1.5 [N];
        
        perform action sensoryExamination[*] references PerformSensoryNerveAssessment;
        
        exhibit state operationalBehavior : DeviceOperationalStates;
    }
    
    satisfy primaryNeurologicalFunction by clinicalWartenbergWheel;
    satisfy stimulusDelivery by clinicalWartenbergWheel.wheel;
    satisfy wheelGeometrySpecification by clinicalWartenbergWheel.wheel;
    satisfy pinDesignSpecification by clinicalWartenbergWheel.wheel.pins;
    satisfy forceApplicationLimit by clinicalWartenbergWheel;
    satisfy devicePortability by clinicalWartenbergWheel;
}
