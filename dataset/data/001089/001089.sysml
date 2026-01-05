package HydrometerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def SpecificGravity :> Real;
    attribute def FluidType;
    attribute def CalibrationMark;
    
    item def Fluid {
        attribute fluidType : FluidType;
        attribute temperature : ISQ::ThermodynamicTemperatureValue;
        attribute density : ISQ::DensityValue;
    }
    
    item def ReferenceFluid :> Fluid {
        attribute referenceDensity : ISQ::DensityValue := 1000.0[SI::kg/(SI::m**3)];
        attribute referenceTemperature : ISQ::ThermodynamicTemperatureValue := 293.15[SI::K];
    }
    
    part def HydrometerFloat {
        attribute mass : ISQ::MassValue;
        attribute volume : ISQ::VolumeValue;
        attribute stemCrossSectionalArea : ISQ::AreaValue;
        attribute calibrationMarks : CalibrationMark[*] ordered;
    }
    
    part def MeasurementScale {
        attribute minSpecificGravity : SpecificGravity;
        attribute maxSpecificGravity : SpecificGravity;
        attribute graduationInterval : Real;
        attribute scaleLength : ISQ::LengthValue;
    }
    
    part def FluidContainer {
        attribute containerVolume : ISQ::VolumeValue;
        attribute containerHeight : ISQ::LengthValue;
        port fluidInterface;
    }
    
    part def TemperatureSensor {
        attribute accuracy : ISQ::ThermodynamicTemperatureValue;
        port sensorInterface;
    }
    
    action def MeasureFluidDensity {
        in testFluid : Fluid;
        in referenceFluid : ReferenceFluid;
        out specificGravity : SpecificGravity;
        out fluidDensity : ISQ::DensityValue;
    }
    
    part def Hydrometer {
        part hydrometerFloat : HydrometerFloat;
        part measurementScale : MeasurementScale;
        part tempSensor : TemperatureSensor;
        port fluidContact;
        
        perform action measureSpecificGravity[*] ordered references measureDensity;
        
        action measureDensity : MeasureFluidDensity;
    }
    
    action def ImmerseSensor {
        in testFluid : Fluid;
        in floatMass : ISQ::MassValue;
        in floatVolume : ISQ::VolumeValue;
        out immersionDepth : ISQ::LengthValue;
    }
    
    action def ReadScale {
        in immersionDepth : ISQ::LengthValue;
        in scaleCalibration : MeasurementScale;
        out rawSpecificGravity : SpecificGravity;
    }
    
    action def MeasureTemperature {
        in testFluid : Fluid;
        out fluidTemperature : ISQ::ThermodynamicTemperatureValue;
    }
    
    action def CalculateSpecificGravity {
        in rawSpecificGravity : SpecificGravity;
        in fluidDensity : ISQ::DensityValue;
        in referenceDensity : ISQ::DensityValue;
        out specificGravity : SpecificGravity;
    }
    
    action def CompensateTemperature {
        in measuredSpecificGravity : SpecificGravity;
        in currentTemperature : ISQ::ThermodynamicTemperatureValue;
        in referenceTemperature : ISQ::ThermodynamicTemperatureValue;
        out correctedSpecificGravity : SpecificGravity;
    }
    
    action def RecordMeasurement {
        in specificGravity : SpecificGravity;
        in fluidDensity : ISQ::DensityValue;
        in measurementTemperature : ISQ::ThermodynamicTemperatureValue;
        out measurementRecord;
    }
    
    action measureFluidDensityAction : MeasureFluidDensity {
        in testFluid : Fluid;
        in referenceFluid : ReferenceFluid;
        out specificGravity : SpecificGravity;
        out fluidDensity : ISQ::DensityValue;
        
        first start;
        then action immerse : ImmerseSensor {
            in testFluid = measureFluidDensityAction::testFluid;
            in floatMass;
            in floatVolume;
            out immersionDepth;
        }
        then action readScale : ReadScale {
            in immersionDepth = immerse.immersionDepth;
            in scaleCalibration;
            out rawSpecificGravity;
        }
        then action measureTemp : MeasureTemperature {
            in testFluid = measureFluidDensityAction::testFluid;
            out fluidTemperature;
        }
        then action calculate : CalculateSpecificGravity {
            in rawSpecificGravity = readScale.rawSpecificGravity;
            in fluidDensity;
            in referenceDensity = referenceFluid.referenceDensity;
            out specificGravity;
        }
        then action compensate : CompensateTemperature {
            in measuredSpecificGravity = calculate.specificGravity;
            in currentTemperature = measureTemp.fluidTemperature;
            in referenceTemperature = referenceFluid.referenceTemperature;
            out correctedSpecificGravity;
        }
        then action record : RecordMeasurement {
            in specificGravity = compensate.correctedSpecificGravity;
            in fluidDensity = measureFluidDensityAction::fluidDensity;
            in measurementTemperature = measureTemp.fluidTemperature;
            out measurementRecord;
        }
        then done;
    }
    
    requirement def PrimaryFunctionRequirement {
        doc /* The hydrometer system shall measure the specific gravity of a fluid sample 
               by determining the ratio of the fluid's density to the density of a reference 
               fluid (typically water at standard conditions). */
        
        subject hydrometer : Hydrometer;
    }
    
    requirement def MeasurementAccuracyRequirement {
        doc /* The hydrometer shall measure specific gravity with an accuracy of ±0.002 
               within the calibrated range. */
        
        subject hydrometer : Hydrometer;
        
        assume constraint accuracyTolerance {
            attribute measuredValue : SpecificGravity;
            attribute trueValue : SpecificGravity;
            attribute tolerance : Real = 0.002;
            
            doc /* Measured value must be within tolerance of true value. */
        }
    }
    
    requirement def TemperatureCompensationRequirement {
        doc /* The hydrometer system shall compensate for temperature variations 
               between 10°C and 40°C to provide accurate readings. */
        
        subject hydrometer : Hydrometer;
        
        assume constraint temperatureRange {
            attribute operatingTemp : ISQ::ThermodynamicTemperatureValue;
            attribute minTemp : ISQ::ThermodynamicTemperatureValue := 283.15[SI::K];
            attribute maxTemp : ISQ::ThermodynamicTemperatureValue := 313.15[SI::K];
            
            doc /* Operating temperature must be within specified range. */
        }
    }
    
    requirement def FloatStabilityRequirement {
        doc /* The hydrometer float shall achieve stable equilibrium within 10 seconds 
               of immersion in the test fluid. */
        
        subject hydrometerFloat : HydrometerFloat;
        
        assume constraint stabilizationTime {
            attribute timeToStable : ISQ::TimeValue;
            attribute maxTime : ISQ::TimeValue := 10.0[SI::s];
            
            doc /* Stabilization time must not exceed maximum time. */
        }
    }
    
    part hydrometerSystem : Hydrometer {
        part float : HydrometerFloat {
            attribute mass = 20.0[SI::g];
            attribute volume = 25.0[SI::cm**3];
            attribute stemCrossSectionalArea = 0.3[SI::cm**2];
        }
        
        part scale : MeasurementScale {
            attribute minSpecificGravity = 0.700;
            attribute maxSpecificGravity = 2.000;
            attribute graduationInterval = 0.002;
            attribute scaleLength = 120.0[SI::mm];
        }
        
        part tempSensor : TemperatureSensor {
            attribute accuracy = 0.5[SI::K];
        }
        
        part container : FluidContainer {
            attribute containerVolume = 500.0[SI::cm**3];
            attribute containerHeight = 200.0[SI::mm];
        }
        
        perform action measureDensity : MeasureFluidDensity {
            in testFluid : Fluid;
            in referenceFluid : ReferenceFluid {
                attribute referenceDensity = 1000.0[SI::kg/(SI::m**3)];
                attribute referenceTemperature = 293.15[SI::K];
            }
            out specificGravity : SpecificGravity;
            out fluidDensity : ISQ::DensityValue;
        }
        
        connection floatToFluid connect float to container.fluidInterface;
        connection sensorToFluid connect tempSensor.sensorInterface to container.fluidInterface;
        
        satisfy primaryFunction : PrimaryFunctionRequirement;
        satisfy measurementAccuracy : MeasurementAccuracyRequirement;
        satisfy temperatureCompensation : TemperatureCompensationRequirement;
        satisfy floatStability : FloatStabilityRequirement;
    }
    
    state def HydrometerOperationalStates {
        entry; then idle;
        
        state idle {
            entry assign systemReady := true;
        }
        
        transition idle_to_immersing
            first idle
            accept immersionCommand
            then immersing;
        
        state immersing {
            do action immerseFloat : ImmerseSensor;
        }
        
        transition immersing_to_stabilizing
            first immersing
            if floatImmersed
            then stabilizing;
        
        state stabilizing {
            do action waitForEquilibrium;
        }
        
        transition stabilizing_to_measuring
            first stabilizing
            if equilibriumReached
            then measuring;
        
        state measuring {
            do action readMeasurement : ReadScale;
        }
        
        transition measuring_to_compensating
            first measuring
            then compensating;
        
        state compensating {
            do action applyTemperatureCorrection : CompensateTemperature;
        }
        
        transition compensating_to_recording
            first compensating
            then recording;
        
        state recording {
            do action saveResult : RecordMeasurement;
        }
        
        transition recording_to_idle
            first recording
            then idle;
    }
    
    action def OperateHydrometer {
        in sampleFluid : Fluid;
        in reference : ReferenceFluid;
        out finalSpecificGravity : SpecificGravity;
        
        first start;
        then merge checkReady;
        then decide;
            if systemReady then performMeasurement;
            if not systemReady then waitForReady;
        
        action waitForReady;
        then checkReady;
        
        action performMeasurement : MeasureFluidDensity {
            in testFluid = sampleFluid;
            in referenceFluid = reference;
            out specificGravity;
            out fluidDensity;
        }
        then assign finalSpecificGravity := performMeasurement.specificGravity;
        then done;
    }
}
