package 'Precision Hydrometer System' {
    private import ISQ::*;
    private import SI::*;
    private import MeasurementReferences::DimensionOneValue;
    private import ScalarValues::*;

    attribute def SpecificGravity :> DimensionOneValue;

    part def TestFluid {
        attribute density :> ISQ::DensityValue;
        attribute temperature :> ISQ::TemperatureValue;
        attribute specificGravity :> SpecificGravity;
    }

    part def FluidContainer {
        ref part containedFluid : TestFluid;
        attribute capacity :> ISQ::VolumeValue;
        port fluidPort : FluidInterfacePort;
    }

    part def CalibratedFloat {
        attribute mass :> ISQ::MassValue;
        attribute volume :> ISQ::VolumeValue;
        attribute stemLength :> ISQ::LengthValue;
        attribute stemDiameter :> ISQ::LengthValue;
    }

    part def MeasurementScale {
        attribute minSpecificGravity :> SpecificGravity;
        attribute maxSpecificGravity :> SpecificGravity;
        attribute graduationInterval :> SpecificGravity;
        attribute rawReading :> SpecificGravity;
    }

    part def TemperatureSensor {
        attribute accuracy :> ISQ::TemperatureValue;
        attribute responseTime :> ISQ::TimeValue;
        out tempReading : ISQ::TemperatureValue;
    }

    port def FluidInterfacePort {
        out fluidDensity : ISQ::DensityValue;
        out fluidTemperature : ISQ::TemperatureValue;
    }

    port def ReadingPort {
        out rawSpecificGravity : SpecificGravity;
    }

    port def TempDataPort {
        out temperature : ISQ::TemperatureValue;
    }

    part def Hydrometer {
        part float : CalibratedFloat;
        part scale : MeasurementScale;
        part tempSensor : TemperatureSensor;
        port fluidInterface : FluidInterfacePort;
        port readingOutput : ReadingPort;
        port tempOutput : TempDataPort;
        out rawSpecificGravity : SpecificGravity;
        out fluidTemperature : ISQ::TemperatureValue;
        out compensatedSpecificGravity : SpecificGravity;
        out compensatedDensity : ISQ::DensityValue;
    }

    calc def TemperatureCompensation {
        in rawSG : SpecificGravity;
        in measuredTemp : ISQ::TemperatureValue;
        in referenceTemp : ISQ::TemperatureValue;
        in thermalCoeff : DimensionOneValue;
        return correctedSG : SpecificGravity = rawSG * (1.0 + thermalCoeff * (referenceTemp - measuredTemp));
    }

    action def MeasurementProcess {
        in part testFluid : TestFluid;
        in part hydrometer : Hydrometer;
        out compensatedSG : SpecificGravity;
        out compensatedDensity : ISQ::DensityValue;

        action immerseHydrometer {
            in part hydrometer;
            in part testFluid;
        }
        then action stabilizeFloat {
            in part hydrometer;
            in part testFluid;
            out equilibriumDepth : ISQ::LengthValue;
        }
        then action readRawSpecificGravity {
            in part hydrometer;
            out rawReading : SpecificGravity = hydrometer.rawSpecificGravity;
        }
        then action measureTemperature {
            in part hydrometer;
            out tempReading : ISQ::TemperatureValue = hydrometer.tempSensor.tempReading;
        }
        then action compensateReading {
            in rawReading : SpecificGravity = readRawSpecificGravity.rawReading;
            in tempReading : ISQ::TemperatureValue = measureTemperature.tempReading;
            out compensatedReading : SpecificGravity = rawReading * (1.0 + 0.0002 * (293.15 [K] - tempReading));
            out compensatedDensityValue : ISQ::DensityValue = compensatedReading * 998.2 [kg/m^3];
        }
        bind compensatedSG = compensateReading.compensatedReading;
        bind compensatedDensity = compensateReading.compensatedDensityValue;
    }

    state def MeasurementState {
        state Idle;
        state Immersing;
        state Stabilizing;
        state Reading;
        state Compensating;
        state Complete;
        state Done;

        transition Idle to Immersing;
        transition Immersing to Stabilizing after (1 [s]);
        transition Stabilizing to Reading;
        transition Reading to Compensating;
        transition Compensating to Complete;
        transition Complete to Done;
    }

    requirement def SpecificGravityAccuracyRequirement {
        doc /* The compensated specific gravity shall be accurate within +/- 0.001 relative to the standard fluid at reference temperature. */
        attribute compensatedSpecificGravity :> SpecificGravity;
        attribute referenceTemperature :> ISQ::TemperatureValue = 293.15 [K];
        require constraint {
            compensatedSpecificGravity > 0.999 and compensatedSpecificGravity < 1.001
        }
    }

    requirement def TemperatureCompensationRequirement {
        doc /* The system shall compensate specific gravity readings based on fluid temperature relative to a 20C reference. */
        attribute referenceTemp :> ISQ::TemperatureValue;
        require constraint { referenceTemp == 293.15 [K] }
    }

    requirement def MeasurementRangeRequirement {
        doc /* The measurement scale shall cover a specific gravity range from 0.700 to 2.000. */
        attribute minSG :> SpecificGravity;
        attribute maxSG :> SpecificGravity;
        require constraint { minSG == 0.700 and maxSG == 2.000 }
    }

    requirement def ResponseTimeRequirement {
        doc /* The entire measurement process shall complete within 30 seconds. */
        attribute maxTime :> ISQ::TimeValue;
        require constraint { maxTime <= 30 [s] }
    }

    part def HydrometerSystem {
        part hydrometer : Hydrometer;
        part container : FluidContainer;

        perform action measurementProcess : MeasurementProcess {
            in part testFluid : TestFluid = container.containedFluid;
            in part hydrometerInst : Hydrometer = hydrometer;
        }
    }

    part hydrometerSystem : HydrometerSystem {
        requirement sgAccuracyReq : SpecificGravityAccuracyRequirement {
            subject hydrometer;
            :>> compensatedSpecificGravity = hydrometer.compensatedSpecificGravity;
        }

        requirement tempCompReq : TemperatureCompensationRequirement {
            :>> referenceTemp = 293.15 [K];
        }

        requirement rangeReq : MeasurementRangeRequirement {
            :>> minSG = hydrometer.scale.minSpecificGravity;
            :>> maxSG = hydrometer.scale.maxSpecificGravity;
        }

        requirement responseReq : ResponseTimeRequirement {
            :>> maxTime = 30 [s];
        }

        part hydrometer : Hydrometer {
            part float : CalibratedFloat {
                :>> mass = 0.05 [kg];
                :>> volume = 5e-5 [m^3];
                :>> stemLength = 0.15 [m];
                :>> stemDiameter = 0.005 [m];
            }
            part scale : MeasurementScale {
                :>> minSpecificGravity = 0.700;
                :>> maxSpecificGravity = 2.000;
                :>> graduationInterval = 0.001;
            }
            part tempSensor : TemperatureSensor {
                :>> accuracy = 0.1 [K];
                :>> responseTime = 2 [s];
            }
        }

        part container : FluidContainer {
            :>> capacity = 5e-4 [m^3];
            ref part containedFluid : TestFluid {
                :>> density = 998.2 [kg/m^3];
                :>> temperature = 298.15 [K];
                :>> specificGravity = 0.997;
            }
        }

        connect hydrometer.fluidInterface to container.fluidPort;
    }
}
