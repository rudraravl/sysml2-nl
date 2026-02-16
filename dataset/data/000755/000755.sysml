package 'Schiotz Tonometer System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def mmHgUnit :> PressureUnit;
    attribute def gramUnit :> MassUnit;
    attribute def millimeterUnit :> LengthUnit;
    
    attribute def IntraocularPressure :> PressureValue {
        attribute :>> num : Real;
        attribute :>> mRef : PressureUnit;
    }
    
    attribute def PlungerWeight :> MassValue {
        attribute :>> num : Real;
        attribute :>> mRef : MassUnit;
    }
    
    attribute def IndentationDepth :> LengthValue {
        attribute :>> num : Real;
        attribute :>> mRef : LengthUnit;
    }
    
    attribute def ScaleReading :> Real {
        doc /* Dimensionless scale reading from 0 to 20 units. */
    }
    
    attribute def AppliedForce :> ForceValue {
        attribute :>> num : Real;
        attribute :>> mRef : ForceUnit;
    }
    
    port def CornealContactPort {
        in appliedForce : AppliedForce;
        out indentation : IndentationDepth;
    }
    
    port def PlungerPort {
        out force : AppliedForce;
        in displacement : IndentationDepth;
    }
    
    port def ScalePort {
        in indentation : IndentationDepth;
        out reading : ScaleReading;
    }
    
    part def Eye {
        doc /* The patient's eye being examined. */
        attribute intraocularpressure : IntraocularPressure;
        port cornea : CornealContactPort;
    }
    
    part def Footplate {
        doc /* Curved platform that rests on the cornea and provides stable contact surface. */
        attribute contactDiameter : LengthValue;
        port cornealContact : CornealContactPort;
        port plungerGuide : PlungerPort;
    }
    
    part def Plunger {
        doc /* Weighted rod that indents the cornea through the footplate. */
        attribute baseMass : PlungerWeight;
        attribute diameter : LengthValue;
        port guide : PlungerPort;
    }
    
    part def WeightSet {
        doc /* Interchangeable weights that modify total plunger mass. */
        attribute availableWeights : PlungerWeight[*];
        attribute selectedWeight : PlungerWeight;
    }
    
    part def LeverMechanism {
        doc /* Mechanical linkage that amplifies plunger displacement. */
        attribute leverRatio : Real;
        port plungerInput : PlungerPort;
        port scaleOutput : ScalePort;
    }
    
    part def ScaleIndicator {
        doc /* Calibrated scale displaying indentation measurement. */
        attribute currentReading : ScaleReading;
        attribute calibrationTable : Real[*];
        port measurement : ScalePort;
    }
    
    part def HousingFrame {
        doc /* Structural frame supporting all components. */
        port plungerMount;
        port footplateMount;
        port leverMount;
    }
    
    action def PositionOnCornea {
        in targetEye : Eye;
        out isPositioned : Boolean;
        out contactEstablished : Boolean;
    }
    
    action def ApplyWeightedForce {
        in plungerMass : PlungerWeight;
        in additionalWeight : PlungerWeight;
        in gravitationalAcceleration : AccelerationValue;
        out totalForce : AppliedForce;
    }
    
    action def IndentCornea {
        in appliedForce : AppliedForce;
        in cornealResistance : IntraocularPressure;
        in cornealRigidity : Real;
        out indentationDepth : IndentationDepth;
    }
    
    action def AmplifyDisplacement {
        in plungerDisplacement : IndentationDepth;
        in leverRatio : Real;
        out amplifiedDisplacement : IndentationDepth;
    }
    
    action def ReadScale {
        in displacement : IndentationDepth;
        out scaleValue : ScaleReading;
    }
    
    action def ConvertToIOPressure {
        in scaleReading : ScaleReading;
        in appliedWeight : PlungerWeight;
        in calibrationData : Real[*];
        out ioPressure : IntraocularPressure;
    }
    
    action def MeasureIntraocularPressure {
        doc /* Complete measurement cycle to determine intraocular pressure. */
        in patientEye : Eye;
        in selectedWeight : PlungerWeight;
        in plungerBaseMass : PlungerWeight;
        in leverRatio : Real;
        in calibrationTable : Real[*];
        out measuredPressure : IntraocularPressure;
        out finalScaleReading : ScaleReading;
        
        first start;
        then action position : PositionOnCornea {
            in targetEye = patientEye;
            out isPositioned;
            out contactEstablished;
        }
        then decide;
            if position.isPositioned then applyForce;
        
        action applyForce : ApplyWeightedForce {
            in plungerMass = plungerBaseMass;
            in additionalWeight = selectedWeight;
            in gravitationalAcceleration = 9.81 [SI::m/SI::s^2];
            out totalForce;
        }
        then action indent : IndentCornea {
            in appliedForce = applyForce.totalForce;
            in cornealResistance = patientEye.intraocularpressure;
            in cornealRigidity = 0.0215;
            out indentationDepth;
        }
        then action amplify : AmplifyDisplacement {
            in plungerDisplacement = indent.indentationDepth;
            in leverRatio = leverRatio;
            out amplifiedDisplacement;
        }
        then action readScale : ReadScale {
            in displacement = amplify.amplifiedDisplacement;
            out scaleValue;
        }
        then action convert : ConvertToIOPressure {
            in scaleReading = readScale.scaleValue;
            in appliedWeight = selectedWeight;
            in calibrationData = calibrationTable;
            out ioPressure;
        }
        then assign measuredPressure := convert.ioPressure;
        then assign finalScaleReading := readScale.scaleValue;
        then done;
    }
    
    state def TonometerOperationalState {
        entry; then idle;
        
        state idle {
            doc /* Tonometer at rest, ready for measurement. */
        }
        state positioning {
            doc /* Aligning footplate with corneal surface. */
        }
        state measuring {
            doc /* Applying force and recording indentation. */
        }
        state reading {
            doc /* Displaying scale value for conversion. */
        }
        state complete {
            doc /* Measurement cycle finished. */
        }
        
        transition startPositioning
            first idle
            then positioning;
        
        transition beginMeasurement
            first positioning
            then measuring;
        
        transition recordReading
            first measuring
            then reading;
        
        transition finishMeasurement
            first reading
            then complete;
        
        transition reset
            first complete
            then idle;
    }
    
    requirement def FunctionalRequirement;
    requirement def AccuracyRequirement;
    requirement def SafetyRequirement;
    requirement def CalibrationRequirement;
    
    part def SchiotzTonometer {
        doc /* 
            The Schiøtz tonometer is an indentation tonometer used to measure 
            intraocular pressure (IOP) in the eye. Its primary function is to 
            determine the pressure inside the eye by measuring how deeply a 
            weighted plunger indents the cornea. The instrument applies a known 
            force to the corneal surface through a footplate-mounted plunger. 
            Higher intraocular pressure resists indentation more strongly, 
            resulting in less plunger displacement. A lever mechanism amplifies 
            this small displacement and displays it on a calibrated scale. The 
            scale reading is then converted to pressure units (mmHg) using 
            standardized calibration tables specific to the applied weight.
        */
        
        attribute measuredIOP : IntraocularPressure;
        attribute actualIOP : IntraocularPressure;
        attribute maxAppliedForce : AppliedForce;
        
        part housing : HousingFrame;
        
        part footplate : Footplate {
            attribute :>> contactDiameter = 3.06 [millimeterUnit];
        }
        
        part plunger : Plunger {
            attribute :>> baseMass = 5.5 [gramUnit];
            attribute :>> diameter = 1.5 [millimeterUnit];
        }
        
        part weights : WeightSet {
            attribute :>> availableWeights = (5.5, 7.5, 10.0, 15.0) [gramUnit];
            attribute :>> selectedWeight = 5.5 [gramUnit];
        }
        
        part lever : LeverMechanism {
            attribute :>> leverRatio = 20.0;
        }
        
        part scale : ScaleIndicator {
            attribute :>> currentReading;
            attribute :>> calibrationTable = (
                0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0,
                5.5, 6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0, 9.5, 10.0
            );
        }
        
        perform action measureIOP[*] ordered references MeasureIntraocularPressure {
            in patientEye;
            in selectedWeight = weights.selectedWeight;
            in plungerBaseMass = plunger.baseMass;
            in leverRatio = lever.leverRatio;
            in calibrationTable = scale.calibrationTable;
            out measuredPressure;
            out finalScaleReading;
        }
        
        state operationalState : TonometerOperationalState;
        
        connection footplateToPlunger connect 
            footplate.plungerGuide to plunger.guide;
        
        connection plungerToLever connect 
            plunger.guide to lever.plungerInput;
        
        connection leverToScale connect 
            lever.scaleOutput to scale.measurement;
        
        connection housingToFootplate connect 
            housing.footplateMount to footplate;
        
        connection housingToPlunger connect 
            housing.plungerMount to plunger;
        
        connection housingToLever connect 
            housing.leverMount to lever;
    }
    
    requirement primaryFunction : FunctionalRequirement {
        doc /* The Schiøtz tonometer shall measure intraocular pressure by indenting 
             the cornea with a known weight and converting the resulting indentation 
             depth to pressure units using calibrated scale readings. */
        subject tonometer : SchiotzTonometer;
    }
    
    requirement measurementAccuracy : AccuracyRequirement {
        doc /* The tonometer shall measure intraocular pressure with accuracy 
             within ±2.5 mmHg for pressures in the range 10-30 mmHg. */
        subject tonometer : SchiotzTonometer;
    }
    
    requirement cornealSafety : SafetyRequirement {
        doc /* The tonometer shall not apply force exceeding safe limits 
             to prevent corneal damage during measurement. */
        subject tonometer : SchiotzTonometer;
    }
    
    requirement calibrationStandard : CalibrationRequirement {
        doc /* The tonometer shall be calibrated against standard reference 
             pressures traceable to national standards. */
        subject tonometer : SchiotzTonometer;
    }
    
    part tonometerSystem {
        doc /* Complete measurement system including tonometer and patient eye. */
        
        part patientEye : Eye {
            attribute :>> intraocularpressure = 15.0 [mmHgUnit];
        }
        
        part instrument : SchiotzTonometer;
        
        perform action measurementCycle : MeasureIntraocularPressure {
            in patientEye = tonometerSystem.patientEye;
            in selectedWeight = instrument.weights.selectedWeight;
            in plungerBaseMass = instrument.plunger.baseMass;
            in leverRatio = instrument.lever.leverRatio;
            in calibrationTable = instrument.scale.calibrationTable;
            out measuredPressure;
            out finalScaleReading;
        }
        
        connection eyeToFootplate connect 
            patientEye.cornea to instrument.footplate.cornealContact;
    }
    
    requirement systemRequirements {
        doc /* Top-level requirements for Schiøtz tonometer system. */
        require primaryFunction;
        require measurementAccuracy;
        require cornealSafety;
        require calibrationStandard;
    }
}
