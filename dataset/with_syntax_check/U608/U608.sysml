package BarographSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def AtmosphericPressureValue :> PressureValue;
    attribute def DisplacementValue :> LengthValue;
    attribute def RotationAngleValue :> DimensionOneValue;
    attribute def TimeIntervalValue :> TimeValue;
    
    item def PressureMeasurement {
        attribute pressure : AtmosphericPressureValue;
        attribute timestamp : TimeValue;
        attribute chartPosition : LengthValue;
    }
    
    port def PressureInputPort {
        in item ambientPressure : AtmosphericPressureValue;
    }
    
    port def MechanicalDisplacementPort {
        out item displacement : DisplacementValue;
    }
    
    port def ChartPositionPort {
        in item drumAngle : RotationAngleValue;
        in item penPosition : DisplacementValue;
    }
    
    part def AneroidCapsule {
        doc /* Evacuated metal capsule that expands and contracts with atmospheric pressure changes */
        
        attribute capsuleDiameter : LengthValue;
        attribute springConstant : Real;
        attribute referenceVacuum : PressureValue;
        
        port pressureIn : PressureInputPort;
        port mechanicalOut : MechanicalDisplacementPort;
        
        perform action respondToPressure : ConvertPressureToDisplacement {
            in pressure = pressureIn.ambientPressure;
            out displacement = mechanicalOut.displacement;
        }
    }
    
    part def MechanicalLinkage {
        doc /* Lever system that amplifies capsule movement */
        
        attribute leverRatio : Real;
        attribute pivotFriction : Real;
        
        port displacementIn : ~MechanicalDisplacementPort;
        port amplifiedOut : MechanicalDisplacementPort;
        
        perform action amplifyMovement : AmplifyDisplacement {
            in inputDisplacement = displacementIn.displacement;
            out amplifiedDisplacement = amplifiedOut.displacement;
        }
    }
    
    part def RecordingArm {
        doc /* Pen arm that traces pressure variations on rotating chart */
        
        attribute armLength : LengthValue;
        attribute penInkReservoir : Real;
        
        port penPositionIn : ~MechanicalDisplacementPort;
        
        perform action markChart : TraceOnChart {
            in penDisplacement = penPositionIn.displacement;
        }
    }
    
    part def ClockworkDrum {
        doc /* Spring-driven rotating drum holding chart paper */
        
        attribute rotationPeriod : TimeValue;
        attribute drumDiameter : LengthValue;
        attribute springTension : Real;
        
        port chartPosition : ChartPositionPort;
        
        perform action rotateDrum : AdvanceChart {
            out currentAngle : RotationAngleValue;
        }
    }
    
    part def ChartPaper {
        doc /* Calibrated paper chart for recording pressure trace */
        
        attribute chartDuration : TimeValue;
        attribute pressureScale : Real;
        attribute timeScale : Real;
    }
    
    action def ConvertPressureToDisplacement {
        doc /* Convert atmospheric pressure to mechanical displacement via aneroid capsule */
        
        in pressure : AtmosphericPressureValue;
        out displacement : DisplacementValue;
    }
    
    action def AmplifyDisplacement {
        doc /* Amplify small capsule movement through lever mechanism */
        
        in inputDisplacement : DisplacementValue;
        out amplifiedDisplacement : DisplacementValue;
    }
    
    action def TraceOnChart {
        doc /* Mark current pressure position on rotating chart */
        
        in penDisplacement : DisplacementValue;
    }
    
    action def AdvanceChart {
        doc /* Continuously rotate drum to advance chart paper */
        
        out currentAngle : RotationAngleValue;
    }
    
    action def RecordAtmosphericPressure {
        doc /* Continuously sense, amplify, and record atmospheric pressure variations */
        
        in ambientPressure : AtmosphericPressureValue;
        out pressureTrace : PressureMeasurement[*];
        
        private attribute currentTime : TimeValue := 0.0 [s];
        private attribute recordedData : PressureMeasurement[*] := ();
        
        first start;
        then merge continuousOperation;
        
        action sensePressure : ConvertPressureToDisplacement {
            in pressure = ambientPressure;
            out displacement : DisplacementValue;
        }
        
        flow sensePressure.displacement to amplifyAction.inputDisplacement;
        
        action amplifyAction : AmplifyDisplacement {
            in inputDisplacement : DisplacementValue;
            out amplifiedDisplacement : DisplacementValue;
        }
        
        then parallel {
            action trace : TraceOnChart {
                in penDisplacement = amplifyAction.amplifiedDisplacement;
            }
            
            action advance : AdvanceChart {
                out currentAngle : RotationAngleValue;
            }
        }
        
        action recordMeasurement {
            private attribute newMeasurement : PressureMeasurement;
        }
        
        then assign recordedData := recordedData->including(recordMeasurement.newMeasurement);
        then assign currentTime := currentTime + 1.0 [s];
        
        then decide;
            if currentTime < 604800.0 [s] then continuousOperation;
            if currentTime >= 604800.0 [s] then complete;
        
        action complete;
        then done;
    }
    
    state def BarographOperationalStates {
        doc /* State machine governing barograph operational modes */
        
        entry; then idle;
        
        state idle {
            doc /* Barograph is powered down or not recording */
            entry assign isRecording := false;
        }
        
        transition idle_to_recording
            first idle
            accept StartRecording
            then recording;
        
        state recording {
            doc /* Barograph is actively measuring and recording pressure */
            entry assign isRecording := true;
            do action continuousRecording : RecordAtmosphericPressure;
        }
        
        state parallel recordingSubstates {
            state sensingPressure {
                doc /* Aneroid capsule responding to pressure changes */
            }
            
            state advancingChart {
                doc /* Clockwork mechanism rotating drum */
            }
        }
        
        transition recording_to_maintenance
            first recording
            accept ChartFull
            then maintenance;
        
        state maintenance {
            doc /* Chart replacement or mechanism servicing */
            entry assign isRecording := false;
            do action replaceChart;
        }
        
        transition maintenance_to_idle
            first maintenance
            accept MaintenanceComplete
            then idle;
        
        transition recording_to_idle
            first recording
            accept StopRecording
            then idle;
    }
    
    part def Barograph {
        doc /* 
            A barograph is a meteorological instrument that continuously measures 
            and records atmospheric pressure variations over time. It uses an aneroid 
            capsule to sense pressure changes, amplifies the resulting mechanical 
            displacement through a lever system, and traces these variations onto 
            a rotating chart driven by clockwork mechanism. The resulting graphical 
            record enables analysis of weather patterns and altitude changes.
        */
        
        attribute operatingRange : PressureValue[2];
        attribute measurementAccuracy : PressureValue;
        attribute recordingDuration : TimeValue;
        attribute calibrationDate : String;
        
        part capsule : AneroidCapsule {
            :>> capsuleDiameter = 50.0 [mm];
            :>> springConstant = 0.5;
            :>> referenceVacuum = 0.0 [Pa];
        }
        
        part linkage : MechanicalLinkage {
            :>> leverRatio = 10.0;
            :>> pivotFriction = 0.02;
        }
        
        part arm : RecordingArm {
            :>> armLength = 150.0 [mm];
            :>> penInkReservoir = 5.0;
        }
        
        part drum : ClockworkDrum {
            :>> rotationPeriod = 604800.0 [s];
            :>> drumDiameter = 100.0 [mm];
            :>> springTension = 2.5;
        }
        
        part chart : ChartPaper {
            :>> chartDuration = 168.0 [h];
            :>> pressureScale = 1.0;
            :>> timeScale = 1.0;
        }
        
        port atmosphericInput : PressureInputPort;
        
        connection capsuleToLinkage : FlowConnection 
            connect capsule.mechanicalOut to linkage.displacementIn;
        
        connection linkageToArm : FlowConnection 
            connect linkage.amplifiedOut to arm.penPositionIn;
        
        perform action barographOperation : RecordAtmosphericPressure {
            in ambientPressure = atmosphericInput.ambientPressure;
            out pressureTrace : PressureMeasurement[*];
        }
        
        exhibit state operationalBehavior : BarographOperationalStates;
    }
    
    requirement def <'BR-001'> ContinuousPressureRecording {
        doc /* 
            The barograph shall continuously record atmospheric pressure variations 
            on a rotating chart for a minimum duration of seven days.
        */
        
        subject barograph : Barograph;
        
        require constraint {
            barograph.recordingDuration >= 604800.0 [s]
        }
    }
    
    requirement def <'BR-002'> MeasurementPrecision {
        doc /* 
            The barograph shall measure atmospheric pressure with accuracy 
            sufficient to detect meteorologically significant variations.
        */
        
        subject barograph : Barograph;
        
        require constraint {
            barograph.measurementAccuracy <= 100.0 [Pa]
        }
    }
    
    requirement def <'BR-003'> MechanicalAmplification {
        doc /* 
            The barograph shall amplify aneroid capsule displacement to produce 
            readable trace on chart paper.
        */
        
        subject barograph : Barograph;
        
        require constraint {
            barograph.linkage.leverRatio >= 5.0
        }
    }
    
    requirement def <'BR-004'> ChartRotationAccuracy {
        doc /* 
            The barograph drum shall rotate at constant rate to ensure 
            accurate time correlation of pressure measurements.
        */
        
        subject barograph : Barograph;
        
        require constraint {
            barograph.drum.rotationPeriod == 604800.0 [s]
        }
    }
    
    requirement <'BR-SYS'> barographSystemRequirement {
        doc /* 
            The barograph system shall provide continuous, accurate recording 
            of atmospheric pressure variations for meteorological observation 
            and weather pattern analysis.
        */
        
        subject system : Barograph;
        
        require ContinuousPressureRecording;
        require MeasurementPrecision;
        require MechanicalAmplification;
        require ChartRotationAccuracy;
    }
    
    part barographInstrument : Barograph {
        :>> operatingRange = (95000.0 [Pa], 105000.0 [Pa]);
        :>> measurementAccuracy = 50.0 [Pa];
        :>> recordingDuration = 604800.0 [s];
        :>> calibrationDate = "2024-01-15";
        
        satisfy barographSystemRequirement;
    }
}
