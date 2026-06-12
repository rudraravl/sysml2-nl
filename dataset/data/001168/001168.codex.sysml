package OscillatingUTubeSystemModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def LengthValue :> Real {
        unit = "m";
    }

    attribute def AreaValue :> Real {
        unit = "m^2";
    }

    attribute def VolumeValue :> Real {
        unit = "m^3";
    }

    attribute def DensityValue :> Real {
        unit = "kg/m^3";
    }

    attribute def PressureValue :> Real {
        unit = "Pa";
    }

    attribute def MassValue :> Real {
        unit = "kg";
    }

    attribute def TimeValue :> Real {
        unit = "s";
    }

    attribute def FrequencyValue :> Real {
        unit = "Hz";
    }

    attribute def VelocityValue :> Real {
        unit = "m/s";
    }

    attribute def AccelerationValue :> Real {
        unit = "m/s^2";
    }

    attribute def DampingValue :> Real {
        unit = "N*s/m";
    }

    attribute def StiffnessValue :> Real {
        unit = "N/m";
    }

    item def WorkingFluid {
        attribute density : DensityValue;
        attribute dynamicViscosity : Real {
            unit = "Pa*s";
        }
        attribute vaporPressure : PressureValue;
    }

    item def AirVolume {
        attribute pressure : PressureValue;
        attribute volume : VolumeValue;
    }

    item def FluidColumnState {
        attribute displacementFromEquilibrium : LengthValue;
        attribute velocity : VelocityValue;
        attribute acceleration : AccelerationValue;
        attribute oscillationPeriod : TimeValue;
        attribute oscillationFrequency : FrequencyValue;
        attribute peakAmplitude : LengthValue;
    }

    item def ExcitationPulse {
        attribute imposedLevelDifference : LengthValue;
        attribute duration : TimeValue;
    }

    item def MeasurementSignal {
        attribute measuredLevelDifference : LengthValue;
        attribute measuredPeriod : TimeValue;
        attribute estimatedFrequency : FrequencyValue;
    }

    port def FluidPort {
        inout fluid : WorkingFluid;
        attribute pressure : PressureValue;
    }

    port def GasPort {
        inout gas : AirVolume;
        attribute pressure : PressureValue;
    }

    port def MechanicalExcitationPort {
        in excitation : ExcitationPulse;
    }

    port def MeasurementPort {
        out signal : MeasurementSignal;
    }

    part def VerticalTubeLeg {
        attribute innerDiameter : LengthValue;
        attribute height : LengthValue;
        attribute crossSectionArea : AreaValue;
        attribute wallRoughness : LengthValue;
        attribute containedFluidHeight : LengthValue;
        port bottomFluidPort : FluidPort;
        port topGasPort : GasPort;
    }

    part def CurvedBottomSection {
        attribute bendRadius : LengthValue;
        attribute hydraulicLength : LengthValue;
        attribute internalVolume : VolumeValue;
        attribute pressureLossCoefficient : Real;
        port leftFluidPort : FluidPort;
        port rightFluidPort : FluidPort;
    }

    part def UTubeChannel {
        attribute totalHydraulicLength : LengthValue;
        attribute uniformCrossSectionArea : AreaValue;
        attribute internalVolume : VolumeValue;

        part leftLeg : VerticalTubeLeg {
            attribute innerDiameter = 0.020;
            attribute height = 0.600;
            attribute crossSectionArea = 3.14159e-4;
            attribute wallRoughness = 1.5e-6;
            attribute containedFluidHeight = 0.350;
        }

        part rightLeg : VerticalTubeLeg {
            attribute innerDiameter = 0.020;
            attribute height = 0.600;
            attribute crossSectionArea = 3.14159e-4;
            attribute wallRoughness = 1.5e-6;
            attribute containedFluidHeight = 0.350;
        }

        part bottomBend : CurvedBottomSection {
            attribute bendRadius = 0.050;
            attribute hydraulicLength = 0.157;
            attribute internalVolume = 4.93e-5;
            attribute pressureLossCoefficient = 0.35;
        }

        connect leftLeg.bottomFluidPort to bottomBend.leftFluidPort;
        connect rightLeg.bottomFluidPort to bottomBend.rightFluidPort;
    }

    part def FluidColumn {
        attribute fluidMass : MassValue;
        attribute equilibriumHeightEachLeg : LengthValue;
        attribute levelDifference : LengthValue;
        attribute amplitude : LengthValue;
        attribute velocity : VelocityValue;
        attribute effectiveMovingLength : LengthValue;
        attribute hydrostaticRestoringStiffness : StiffnessValue;
        attribute viscousDampingCoefficient : DampingValue;
        attribute naturalPeriod : TimeValue;
        attribute naturalFrequency : FrequencyValue;

        item workingFluid : WorkingFluid {
            attribute density = 998.2;
            attribute dynamicViscosity = 0.001002;
            attribute vaporPressure = 2339.0;
        }

        item state : FluidColumnState;

        port leftInterface : FluidPort;
        port rightInterface : FluidPort;
    }

    part def AtmosphereReference {
        attribute ambientPressure : PressureValue;
        attribute ambientTemperature : Real {
            unit = "K";
        }

        item leftHeadspace : AirVolume {
            attribute pressure = 101325.0;
            attribute volume = 7.85e-5;
        }

        item rightHeadspace : AirVolume {
            attribute pressure = 101325.0;
            attribute volume = 7.85e-5;
        }

        port leftGasPort : GasPort;
        port rightGasPort : GasPort;
    }

    part def LevelSensor {
        attribute resolution : LengthValue;
        attribute samplePeriod : TimeValue;
        attribute measurableRange : LengthValue;

        port observedLeftFluid : FluidPort;
        port observedRightFluid : FluidPort;
        port measurementOut : MeasurementPort;
    }

    part def Exciter {
        attribute maximumInitialDisplacement : LengthValue;
        attribute releaseTime : TimeValue;

        port excitationOut : MechanicalExcitationPort;
    }

    action def DisplaceFluidColumn {
        in pulse : ExcitationPulse;
        inout columnState : FluidColumnState;
        out accepted : Boolean;

        first start;
        then checkRange;

        action checkRange {
            accepted = pulse.imposedLevelDifference <= 0.200;
        }

        then applyInitialCondition if accepted;
        action applyInitialCondition {
            columnState.displacementFromEquilibrium = pulse.imposedLevelDifference;
            columnState.velocity = 0.0;
        }

        then done;
    }

    action def OscillateFluidColumn {
        inout columnState : FluidColumnState;
        in density : DensityValue;
        in area : AreaValue;
        in effectiveLength : LengthValue;
        in dampingCoefficient : DampingValue;
        out signal : MeasurementSignal;

        first computeRestoringMotion;

        action computeRestoringMotion {
            columnState.acceleration =
                -1.0 * 9.80665 * columnState.displacementFromEquilibrium / effectiveLength;
            columnState.oscillationPeriod =
                2.0 * 3.14159 * sqrt(effectiveLength / (2.0 * 9.80665));
            columnState.oscillationFrequency = 1.0 / columnState.oscillationPeriod;
        }

        then publishMeasurement;

        action publishMeasurement {
            signal.measuredLevelDifference = columnState.displacementFromEquilibrium;
            signal.measuredPeriod = columnState.oscillationPeriod;
            signal.estimatedFrequency = columnState.oscillationFrequency;
        }

        then done;
    }

    action def MeasureOscillation {
        in columnState : FluidColumnState;
        out measurement : MeasurementSignal;

        first sampleLevel;
        action sampleLevel {
            measurement.measuredLevelDifference = columnState.displacementFromEquilibrium;
            measurement.measuredPeriod = columnState.oscillationPeriod;
            measurement.estimatedFrequency = columnState.oscillationFrequency;
        }
        then done;
    }

    state def OscillatingUTubeOperatingState {
        entry; then Equilibrated;

        state Equilibrated;
        state Excited;
        state Oscillating;
        state DampedSettling;
        state MeasurementAvailable;

        transition Equilibrated_to_Excited
            first Equilibrated
            accept ExcitationPulse
            then Excited;

        transition Excited_to_Oscillating
            first Excited
            then Oscillating;

        transition Oscillating_to_DampedSettling
            first Oscillating
            if amplitudeBelowThreshold
            then DampedSettling;

        transition DampedSettling_to_MeasurementAvailable
            first DampedSettling
            then MeasurementAvailable;

        transition MeasurementAvailable_to_Equilibrated
            first MeasurementAvailable
            then Equilibrated;

        constraint amplitudeBelowThreshold {
            doc /* The oscillation is considered settled when the peak level difference is less than 1 mm. */
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall convert an initial displacement of liquid in a U-shaped tube into a measurable damped oscillatory motion governed primarily by gravity, liquid density, tube geometry, and viscous losses. */
    }

    requirement def ContainmentRequirement {
        doc /* The system shall contain the working fluid within the U-tube channel without leakage during excitation and oscillation. */
    }

    requirement def OscillationRequirement {
        doc /* The system shall support free oscillation of the liquid column after release from an imposed level difference. */
        attribute minimumInitialLevelDifference : LengthValue = 0.010;
        attribute maximumInitialLevelDifference : LengthValue = 0.200;
    }

    requirement def MeasurementRequirement {
        doc /* The system shall measure liquid level difference and estimate oscillation period with sufficient resolution for high-level characterization of U-tube dynamics. */
        attribute maximumLevelResolution : LengthValue = 0.001;
        attribute maximumPeriodError : TimeValue = 0.020;
    }

    requirement def AtmosphericReferenceRequirement {
        doc /* Both free surfaces shall remain referenced to a common ambient gas pressure during normal operation so that hydrostatic restoring force dominates the motion. */
        attribute nominalAmbientPressure : PressureValue = 101325.0;
    }

    part def OscillatingUTubeSystem {
        doc /* Primary high-level function: demonstrate and measure the gravity-driven oscillation of a liquid column in an open U-tube after an initial level displacement. */

        attribute gravitationalAcceleration : AccelerationValue = 9.80665;
        attribute nominalInnerDiameter : LengthValue = 0.020;
        attribute nominalLegHeight : LengthValue = 0.600;
        attribute nominalEquilibriumFluidHeight : LengthValue = 0.350;
        attribute nominalTotalMovingLength : LengthValue = 0.857;
        attribute nominalCrossSectionArea : AreaValue = 3.14159e-4;
        attribute nominalFluidMass : MassValue = 0.269;
        attribute nominalNaturalPeriod : TimeValue = 1.314;
        attribute nominalNaturalFrequency : FrequencyValue = 0.761;
        attribute nominalDampingCoefficient : DampingValue = 0.040;

        part tube : UTubeChannel {
            attribute totalHydraulicLength = 0.857;
            attribute uniformCrossSectionArea = 3.14159e-4;
            attribute internalVolume = 2.69e-4;
        }

        part column : FluidColumn {
            attribute fluidMass = 0.269;
            attribute equilibriumHeightEachLeg = 0.350;
            attribute levelDifference = 0.000;
            attribute amplitude = 0.050;
            attribute velocity = 0.000;
            attribute effectiveMovingLength = 0.857;
            attribute hydrostaticRestoringStiffness = 6.15;
            attribute viscousDampingCoefficient = 0.040;
            attribute naturalPeriod = 1.314;
            attribute naturalFrequency = 0.761;
        }

        part atmosphere : AtmosphereReference {
            attribute ambientPressure = 101325.0;
            attribute ambientTemperature = 293.15;
        }

        part exciter : Exciter {
            attribute maximumInitialDisplacement = 0.200;
            attribute releaseTime = 0.050;
        }

        part levelSensor : LevelSensor {
            attribute resolution = 0.0005;
            attribute samplePeriod = 0.010;
            attribute measurableRange = 0.300;
        }

        port excitationInput : MechanicalExcitationPort;
        port measurementOutput : MeasurementPort;

        connect excitationInput to exciter.excitationOut;
        connect column.leftInterface to tube.leftLeg.bottomFluidPort;
        connect column.rightInterface to tube.rightLeg.bottomFluidPort;
        connect atmosphere.leftGasPort to tube.leftLeg.topGasPort;
        connect atmosphere.rightGasPort to tube.rightLeg.topGasPort;
        connect levelSensor.observedLeftFluid to column.leftInterface;
        connect levelSensor.observedRightFluid to column.rightInterface;
        connect levelSensor.measurementOut to measurementOutput;

        perform action displace : DisplaceFluidColumn {
            in pulse = excitationInput.excitation;
            inout columnState = column.state;
        }

        perform action oscillate : OscillateFluidColumn {
            inout columnState = column.state;
            in density = column.workingFluid.density;
            in area = nominalCrossSectionArea;
            in effectiveLength = nominalTotalMovingLength;
            in dampingCoefficient = nominalDampingCoefficient;
            out signal = measurementOutput.signal;
        }

        perform action measure : MeasureOscillation {
            in columnState = column.state;
            out measurement = measurementOutput.signal;
        }

        exhibit state operatingState : OscillatingUTubeOperatingState;

        satisfy PrimaryFunctionRequirement;
        satisfy ContainmentRequirement;
        satisfy OscillationRequirement;
        satisfy MeasurementRequirement;
        satisfy AtmosphericReferenceRequirement;

        constraint geometryConsistency {
            nominalCrossSectionArea == 3.14159 * nominalInnerDiameter * nominalInnerDiameter / 4.0;
        }

        constraint naturalPeriodEstimate {
            nominalNaturalPeriod == 2.0 * 3.14159 * sqrt(nominalTotalMovingLength / (2.0 * gravitationalAcceleration));
        }

        constraint naturalFrequencyEstimate {
            nominalNaturalFrequency == 1.0 / nominalNaturalPeriod;
        }

        constraint commonAmbientPressure {
            atmosphere.leftHeadspace.pressure == atmosphere.rightHeadspace.pressure;
        }

        constraint sensorAdequacy {
            levelSensor.resolution <= 0.001;
        }
    }

    view def HighLevelFunctionalView {
        expose OscillatingUTubeSystem;
        expose PrimaryFunctionRequirement;
        expose OscillationRequirement;
        expose MeasurementRequirement;
    }
}