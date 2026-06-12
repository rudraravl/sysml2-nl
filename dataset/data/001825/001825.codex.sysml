package OrificePlateFlowMeasurementSystem {

    import ScalarValues::*;
    import SI::*;

    attribute def Pressure {
        :> scalarValues::Real;
        unit = "Pa";
    }

    attribute def DifferentialPressure {
        :> Pressure;
    }

    attribute def Temperature {
        :> scalarValues::Real;
        unit = "K";
    }

    attribute def MassFlowRate {
        :> scalarValues::Real;
        unit = "kg/s";
    }

    attribute def VolumetricFlowRate {
        :> scalarValues::Real;
        unit = "m^3/s";
    }

    attribute def Diameter {
        :> scalarValues::Real;
        unit = "m";
    }

    attribute def Area {
        :> scalarValues::Real;
        unit = "m^2";
    }

    attribute def Density {
        :> scalarValues::Real;
        unit = "kg/m^3";
    }

    attribute def Ratio {
        :> scalarValues::Real;
    }

    attribute def DischargeCoefficient {
        :> Ratio;
    }

    attribute def SignalCurrent {
        :> scalarValues::Real;
        unit = "mA";
    }

    item def ProcessFluid {
        attribute staticPressure : Pressure;
        attribute temperature : Temperature;
        attribute density : Density;
        attribute massFlow : MassFlowRate;
        attribute volumetricFlow : VolumetricFlowRate;
    }

    item def PressureImpulse {
        attribute sensedPressure : Pressure;
        attribute tapLocation : String;
    }

    item def DifferentialPressureSignal {
        attribute differentialPressure : DifferentialPressure;
        attribute lowSidePressure : Pressure;
        attribute highSidePressure : Pressure;
    }

    item def FlowMeasurementSignal {
        attribute measuredMassFlow : MassFlowRate;
        attribute measuredVolumetricFlow : VolumetricFlowRate;
        attribute differentialPressure : DifferentialPressure;
        attribute signalCurrent : SignalCurrent;
        attribute valid : Boolean;
    }

    port def FluidPort {
        inout item fluid : ProcessFluid;
    }

    port def PressureTapPort {
        out item pressureImpulse : PressureImpulse;
    }

    port def DifferentialPressurePort {
        in item dpSignal : DifferentialPressureSignal;
    }

    port def MeasurementOutputPort {
        out item flowSignal : FlowMeasurementSignal;
    }

    action def GeneratePressureDrop {
        in item inletFluid : ProcessFluid;
        out item outletFluid : ProcessFluid;
        out highPressure : Pressure;
        out lowPressure : Pressure;

        attribute boreDiameter : Diameter;
        attribute pipeDiameter : Diameter;
        attribute betaRatio : Ratio;
        attribute permanentPressureLoss : Pressure;
    }

    action def SenseStaticPressures {
        in highPressure : Pressure;
        in lowPressure : Pressure;
        out item differentialPressureSignal : DifferentialPressureSignal;

        attribute tapSpacingUpstream : Diameter;
        attribute tapSpacingDownstream : Diameter;
    }

    action def CalculateFlowRate {
        in item differentialPressureSignal : DifferentialPressureSignal;
        in density : Density;
        in boreArea : Area;
        out item measurement : FlowMeasurementSignal;

        attribute dischargeCoefficient : DischargeCoefficient;
        attribute expansibilityFactor : Ratio;
        attribute betaRatio : Ratio;
    }

    action def ValidateMeasurement {
        in item rawMeasurement : FlowMeasurementSignal;
        out item validatedMeasurement : FlowMeasurementSignal;

        attribute minimumDifferentialPressure : DifferentialPressure = 250.0;
        attribute maximumDifferentialPressure : DifferentialPressure = 100000.0;
        attribute minimumSignalCurrent : SignalCurrent = 4.0;
        attribute maximumSignalCurrent : SignalCurrent = 20.0;
    }

    part def OrificePlateAssembly {
        attribute pipeInternalDiameter : Diameter = 0.1541;
        attribute orificeBoreDiameter : Diameter = 0.0925;
        attribute betaRatio : Ratio = 0.600;
        attribute boreArea : Area = 0.00672;
        attribute plateThickness : Diameter = 0.0030;
        attribute dischargeCoefficient : DischargeCoefficient = 0.610;
        attribute nominalPressureRating : Pressure = 1000000.0;

        port upstreamFluidPort : FluidPort;
        port downstreamFluidPort : FluidPort;
        port upstreamPressureTap : PressureTapPort;
        port downstreamPressureTap : PressureTapPort;

        action pressureDropGeneration : GeneratePressureDrop {
            boreDiameter = orificeBoreDiameter;
            pipeDiameter = pipeInternalDiameter;
            betaRatio = betaRatio;
        }
    }

    part def PressureTapPair {
        attribute upstreamTapDistance : Diameter = 0.1541;
        attribute downstreamTapDistance : Diameter = 0.07705;

        port highPressureTap : PressureTapPort;
        port lowPressureTap : PressureTapPort;
        port differentialPressureOutput : DifferentialPressurePort;

        action pressureSensing : SenseStaticPressures {
            tapSpacingUpstream = upstreamTapDistance;
            tapSpacingDownstream = downstreamTapDistance;
        }
    }

    part def DifferentialPressureTransmitter {
        attribute lowerRangeLimit : DifferentialPressure = 0.0;
        attribute upperRangeLimit : DifferentialPressure = 50000.0;
        attribute outputLowCurrent : SignalCurrent = 4.0;
        attribute outputHighCurrent : SignalCurrent = 20.0;
        attribute measurementUncertainty : Ratio = 0.0025;

        port differentialPressureInput : DifferentialPressurePort;
        port measurementOutput : MeasurementOutputPort;

        action flowComputation : CalculateFlowRate {
            dischargeCoefficient = 0.610;
            expansibilityFactor = 0.998;
            betaRatio = 0.600;
        }

        action measurementValidation : ValidateMeasurement;
    }

    part def FlowComputer {
        attribute fluidDensityReference : Density = 998.2;
        attribute updatePeriod : Real = 1.0;

        port transmitterInput : MeasurementOutputPort;
        port plantOutput : MeasurementOutputPort;
    }

    part def OrificePlateFlowMeter {
        doc /* Primary function: create a predictable pressure differential across a precision restriction in a pipe and convert that differential pressure into a high-level flow-rate measurement for monitoring or control. */

        attribute designPipeDiameter : Diameter = 0.1541;
        attribute designBoreDiameter : Diameter = 0.0925;
        attribute designBetaRatio : Ratio = 0.600;
        attribute designFluidDensity : Density = 998.2;
        attribute designMaximumFlow : MassFlowRate = 24.0;
        attribute designMinimumFlow : MassFlowRate = 1.5;

        port processInlet : FluidPort;
        port processOutlet : FluidPort;
        port measuredFlowOutput : MeasurementOutputPort;

        part plateAssembly : OrificePlateAssembly;
        part taps : PressureTapPair;
        part transmitter : DifferentialPressureTransmitter;
        part computer : FlowComputer;

        connect processInlet to plateAssembly.upstreamFluidPort;
        connect plateAssembly.downstreamFluidPort to processOutlet;
        connect plateAssembly.upstreamPressureTap to taps.highPressureTap;
        connect plateAssembly.downstreamPressureTap to taps.lowPressureTap;
        connect taps.differentialPressureOutput to transmitter.differentialPressureInput;
        connect transmitter.measurementOutput to computer.transmitterInput;
        connect computer.plantOutput to measuredFlowOutput;

        state def OperatingState {
            state idle;
            state flowing;
            state lowSignalFault;
            state overRangeFault;
            state maintenanceBypass;

            entry; then idle;

            transition idle_to_flowing
                first idle
                accept item fluid : ProcessFluid
                if fluid.massFlow > 0.0
                then flowing;

            transition flowing_to_lowSignalFault
                first flowing
                if transmitter.measurementOutput.flowSignal.differentialPressure < 250.0
                then lowSignalFault;

            transition flowing_to_overRangeFault
                first flowing
                if transmitter.measurementOutput.flowSignal.differentialPressure > 50000.0
                then overRangeFault;

            transition fault_to_flowing
                first lowSignalFault
                accept reset
                then flowing;

            transition overRange_to_flowing
                first overRangeFault
                accept reset
                then flowing;

            transition flowing_to_maintenance
                first flowing
                accept maintenanceRequested
                then maintenanceBypass;

            transition maintenance_to_idle
                first maintenanceBypass
                accept maintenanceComplete
                then idle;
        }

        perform action measureFlow {
            first plateAssembly.pressureDropGeneration;
            then taps.pressureSensing;
            then transmitter.flowComputation;
            then transmitter.measurementValidation;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject meter : OrificePlateFlowMeter;

        require constraint {
            meter.measuredFlowOutput.flowSignal.valid == true
        }

        doc /* The system shall infer flow rate by producing and measuring a pressure drop across the orifice plate. */
    }

    requirement def PressureDropRequirement {
        subject assembly : OrificePlateAssembly;

        require constraint {
            assembly.betaRatio >= 0.20 and assembly.betaRatio <= 0.75
        }

        doc /* The orifice bore shall be sized to create a stable measurable differential pressure over the operating flow range. */
    }

    requirement def MeasurementOutputRequirement {
        subject transmitter : DifferentialPressureTransmitter;

        require constraint {
            transmitter.outputLowCurrent == 4.0 and transmitter.outputHighCurrent == 20.0
        }

        doc /* The transmitter shall convert differential pressure into a normalized 4 mA to 20 mA flow measurement signal. */
    }

    requirement def FlowRangeRequirement {
        subject meter : OrificePlateFlowMeter;

        require constraint {
            meter.designMinimumFlow >= 1.5 and meter.designMaximumFlow <= 24.0
        }

        doc /* The meter shall support the specified process mass flow range without exceeding the calibrated differential pressure range. */
    }

    requirement def InstallationRequirement {
        subject meter : OrificePlateFlowMeter;

        require constraint {
            meter.plateAssembly.pipeInternalDiameter == meter.designPipeDiameter and
            meter.plateAssembly.orificeBoreDiameter == meter.designBoreDiameter
        }

        doc /* The installed plate bore and pipe diameter shall match the calibrated metering geometry. */
    }

    requirement def ValidityRequirement {
        subject transmitter : DifferentialPressureTransmitter;

        require constraint {
            transmitter.lowerRangeLimit >= 0.0 and
            transmitter.upperRangeLimit == 50000.0
        }

        doc /* Differential pressure measurements outside the calibrated range shall be identified as invalid or faulted. */
    }

    part orificePlateFlowMeasurementSystem : OrificePlateFlowMeter;

    satisfy PrimaryFunctionRequirement by orificePlateFlowMeasurementSystem;
    satisfy PressureDropRequirement by orificePlateFlowMeasurementSystem.plateAssembly;
    satisfy MeasurementOutputRequirement by orificePlateFlowMeasurementSystem.transmitter;
    satisfy FlowRangeRequirement by orificePlateFlowMeasurementSystem;
    satisfy InstallationRequirement by orificePlateFlowMeasurementSystem;
    satisfy ValidityRequirement by orificePlateFlowMeasurementSystem.transmitter;
}