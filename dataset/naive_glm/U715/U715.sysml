package PrecisionHydrometerSystem {
    import ISQ::*;
    import ScalarValues::*;
    import SI::*;

    // ===== Value Types =====
    value type SpecificGravityValue :> Real {
        doc /* Dimensionless ratio of fluid density to reference water density at 20 degrees Celsius */
    }

    value type DensityValue :> MassDensity {
        doc /* Mass density of fluid in kg per cubic metre */
    }

    value type TemperatureValue :> ThermodynamicTemperature {
        doc /* Fluid temperature in Kelvin */
    }

    value type MassValue :> Mass {
        doc /* Mass in kilograms */
    }

    value type VolumeValue :> Volume {
        doc /* Volume in cubic metres */
    }

    value type LengthValue :> Length {
        doc /* Length in metres */
    }

    value type TimeValue :> Time {
        doc /* Duration in seconds */
    }

    value type ExpansionCoefficientValue :> Real {
        doc /* Volumetric thermal expansion coefficient per Kelvin */
    }

    // ===== Item Definitions =====
    item def Fluid {
        attribute density : DensityValue;
        attribute temperature : TemperatureValue;
        attribute specificGravity : SpecificGravityValue;
        attribute expansionCoefficient : ExpansionCoefficientValue;
    }

    item def FluidSample :> Fluid {
        attribute sampleVolume : VolumeValue;
    }

    item def ReferenceWater :> Fluid {
        attribute density : DensityValue = 998.2 [kg/m^3];
        attribute temperature : TemperatureValue = 293.15 [K];
        attribute specificGravity : SpecificGravityValue = 1.0;
        attribute expansionCoefficient : ExpansionCoefficientValue = 0.00021;
    }

    item def MeasurementResult {
        attribute rawSpecificGravity : SpecificGravityValue;
        attribute measuredTemperature : TemperatureValue;
        attribute correctedSpecificGravity : SpecificGravityValue;
        attribute computedDensity : DensityValue;
        attribute measurementDuration : TimeValue;
    }

    // ===== Port Definitions =====
    port def FluidInteractionPort {
        in attribute fluidDensity : DensityValue;
        in attribute fluidTemperature : TemperatureValue;
        in attribute fluidExpansionCoeff : ExpansionCoefficientValue;
        out attribute immersionDepth : LengthValue;
        out attribute equilibriumReached : Boolean;
    }

    port def MeasurementOutputPort {
        out attribute result : MeasurementResult;
    }

    // ===== Action Definitions =====
    action def ImmerseFloatAction {
        in floatMass : MassValue;
        in fluidDensity : DensityValue;
        out immersionDepth : LengthValue;
    }

    action def StabilizeAction {
        in fluidDensity : DensityValue;
        in floatMass : MassValue;
        in floatVolume : VolumeValue;
        out stable : Boolean;
        out equilibriumDepth : LengthValue;
    }

    action def ReadScaleAction {
        in immersionDepth : LengthValue;
        in scaleRangeMin : SpecificGravityValue;
        in scaleRangeMax : SpecificGravityValue;
        out rawReading : SpecificGravityValue;
    }

    action def MeasureTemperatureAction {
        in fluidTemperature : TemperatureValue;
        out measuredTemperature : TemperatureValue;
    }

    action def CompensateTemperatureAction {
        in rawSG : SpecificGravityValue;
        in measuredTemp : TemperatureValue;
        in standardTemp : TemperatureValue;
        in expansionCoeff : ExpansionCoefficientValue;
        out correctedSG : SpecificGravityValue;
    }

    action def ComputeDensityAction {
        in specificGravity : SpecificGravityValue;
        in referenceDensity : DensityValue;
        out density : DensityValue;
    }

    // ===== Part Definitions =====
    part def MeasurementScale {
        doc /* Finely graduated scale on the hydrometer stem indicating specific gravity values */
        attribute rangeMin : SpecificGravityValue = 0.900;
        attribute rangeMax : SpecificGravityValue = 1.200;
        attribute graduationInterval : SpecificGravityValue = 0.001;
        attribute scaleLength : LengthValue = 0.15 [m];
        attribute currentImmersionDepth : LengthValue;
        attribute rawReading : SpecificGravityValue;

        action readScale : ReadScaleAction;
    }

    part def TemperatureSensor {
        doc /* Integrated temperature sensor for simultaneous fluid temperature measurement */
        attribute accuracy : TemperatureValue = 0.1 [K];
        attribute minRange : TemperatureValue = 273.15 [K];
        attribute maxRange : TemperatureValue = 373.15 [K];
        attribute measuredTemperature : TemperatureValue;

        action measureTemperature : MeasureTemperatureAction;
    }

    part def HydrometerFloat {
        doc /* Weighted sealed float with specific mass and volume designed for fluid immersion */
        attribute mass : MassValue = 0.050 [kg];
        attribute bulbVolume : VolumeValue = 0.000050 [m^3];
        attribute stemDiameter : LengthValue = 0.005 [m];
        attribute stemLength : LengthValue = 0.15 [m];
        attribute sealed : Boolean = true;
        attribute calibrated : Boolean = true;
        attribute equilibriumDepth : LengthValue;
        attribute isStable : Boolean = false;

        port fluidInterface : FluidInteractionPort;

        part scale : MeasurementScale;
        part tempSensor : TemperatureSensor;

        action immerse : ImmerseFloatAction;
        action stabilize : StabilizeAction;
    }

    part def FluidContainer {
        doc /* Dedicated container holding the test fluid sample for hydrometer immersion */
        attribute capacity : VolumeValue = 0.001 [m^3];
        attribute fillLevel : VolumeValue;

        port fluidPort : ~FluidInteractionPort;

        item heldFluid : FluidSample;
    }

    part def Hydrometer {
        doc /* Precision hydrometer instrument composed of calibrated float scale and temperature sensor */
        attribute calibrationStandardTemp : TemperatureValue = 293.15 [K];
        attribute referenceFluidDensity : DensityValue = 998.2 [kg/m^3];
        attribute defaultExpansionCoeff : ExpansionCoefficientValue = 0.00021;
        attribute rawSpecificGravity : SpecificGravityValue;
        attribute measuredTemperature : TemperatureValue;
        attribute correctedSpecificGravity : SpecificGravityValue;
        attribute computedDensity : DensityValue;

        port outputPort : MeasurementOutputPort;

        part float : HydrometerFloat;

        action compensate : CompensateTemperatureAction;
        action computeDensity : ComputeDensityAction;
    }

    part def HydrometerSystem {
        doc /* Complete precision hydrometer measurement system */
        attribute measurementTimeout : TimeValue = 30 [s];
        attribute measurementComplete : Boolean = false;
        attribute finalResult : MeasurementResult;

        part hydrometer : Hydrometer;
        part container : FluidContainer;

        connection fluidConnection connect hydrometer.float.fluidInterface to container.fluidPort;

        state measurementProcess {
            doc /* State machine governing immersion stabilization reading and compensation */

            state Idle {
                entry action initializeMeasurement {
                    measurementComplete = false;
                }
            }

            state Immersion {
                entry action performImmersion {
                    hydrometer.float.immerse;
                }
            }

            state Stabilization {
                entry action performStabilization {
                    hydrometer.float.stabilize;
                }
            }

            state Reading {
                entry action performReading {
                    hydrometer.float.scale.readScale;
                    hydrometer.float.tempSensor.measureTemperature;
                    hydrometer.rawSpecificGravity = hydrometer.float.scale.rawReading;
                    hydrometer.measuredTemperature = hydrometer.float.tempSensor.measuredTemperature;
                }
            }

            state Compensation {
                entry action performCompensation {
                    hydrometer.compensate;
                    hydrometer.computeDensity;
                }
            }

            state Complete {
                entry action finalizeResult {
                    finalResult.rawSpecificGravity = hydrometer.rawSpecificGravity;
                    finalResult.measuredTemperature = hydrometer.measuredTemperature;
                    finalResult.correctedSpecificGravity = hydrometer.correctedSpecificGravity;
                    finalResult.computedDensity = hydrometer.computedDensity;
                    measurementComplete = true;
                }
            }

            transition from Idle to Immersion
                when container.fillLevel > 0 [m^3];

            transition from Immersion to Stabilization
                when hydrometer.float.equilibriumDepth > 0 [m];

            transition from Stabilization to Reading
                when hydrometer.float.isStable == true;

            transition from Reading to Compensation
                when hydrometer.rawSpecificGravity > 0;

            transition from Compensation to Complete
                when hydrometer.correctedSpecificGravity > 0;
        }
    }

    // ===== Requirements =====
    requirement def MeasureSpecificGravityRequirement {
        doc /* The system shall measure the specific gravity of a test fluid */
        subject hydrometerSystem : HydrometerSystem;
        objective {
            doc /* The system provides a specific gravity reading within the range 0.900 to 1.200 */
        }
    }

    requirement def MeasureDensityRequirement {
        doc /* The system shall determine the density of a test fluid from the specific gravity measurement */
        subject hydrometerSystem : HydrometerSystem;
        objective {
            doc /* The system provides a density value referenced to water density at 20 degrees Celsius */
        }
    }

    requirement def TemperatureCompensationRequirement {
        doc /* The system shall compensate the specific gravity reading for fluid temperature variations */
        subject hydrometerSystem : HydrometerSystem;
        objective {
            doc /* The corrected reading is referenced to the standard temperature of 20 degrees Celsius equivalent to 293.15 K */
        }
    }

    requirement def MeasurementTimeRequirement {
        doc /* The measurement process shall be completed quickly within 30 seconds */
        subject hydrometerSystem : HydrometerSystem;
        objective {
            doc /* Total elapsed time from immersion to final result is less than or equal to 30 seconds */
        }
    }

    requirement def AccuracyRequirement {
        doc /* The system shall achieve high measurement accuracy */
        subject hydrometerSystem : HydrometerSystem;
        objective {
            doc /* The corrected specific gravity reading is within plus or minus 0.001 of the true specific gravity value */
        }
    }

    requirement def ReliabilityRequirement {
        doc /* The system shall reliably complete the measurement process without failure */
        subject hydrometerSystem : HydrometerSystem;
        objective {
            doc /* The system achieves a measurement completion rate of at least 99 percent under normal operating conditions */
        }
    }

    requirement def BuoyantEquilibriumRequirement {
        doc /* The float shall achieve stable buoyant equilibrium based on fluid density */
        subject hydrometerFloat : HydrometerFloat;
        objective {
            doc /* The float reaches a stable equilibrium depth where buoyant force equals gravitational force on the float */
        }
    }

    requirement def IntegratedTemperatureSensorRequirement {
        doc /* The hydrometer shall include an integrated temperature sensor for simultaneous temperature measurement */
        subject hydrometerFloat : HydrometerFloat;
        objective {
            doc /* Temperature is measured simultaneously with the specific gravity reading during the same measurement cycle */
        }
    }

    requirement def SealedFloatRequirement {
        doc /* The hydrometer float shall be a sealed weighted instrument */
        subject hydrometerFloat : HydrometerFloat;
        objective {
            doc /* The float is sealed against fluid ingress and weighted to achieve proper orientation when immersed */
        }
    }

    requirement hydrometerSystemRequirements {
        doc /* Top-level requirements group for the precision hydrometer system */
        requirement measureSG : MeasureSpecificGravityRequirement;
        requirement measureDensity : MeasureDensityRequirement;
        requirement tempCompensation : TemperatureCompensationRequirement;
        requirement measurementTime : MeasurementTimeRequirement;
        requirement accuracy : AccuracyRequirement;
        requirement reliability : ReliabilityRequirement;
        requirement buoyantEquilibrium : BuoyantEquilibriumRequirement;
        requirement integratedTempSensor : IntegratedTemperatureSensorRequirement;
        requirement sealedFloat : SealedFloatRequirement;
    }
}
