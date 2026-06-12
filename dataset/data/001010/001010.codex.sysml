package ChemicalFieldEffectTransistorSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def ElectricPotential :> ISQ::electricPotential {
        unit = SI::volt;
    }

    attribute def ElectricCurrent :> ISQ::electricCurrent {
        unit = SI::ampere;
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = SI::kelvin;
    }

    attribute def Length :> ISQ::length {
        unit = SI::metre;
    }

    attribute def Concentration {
        unit = SI::mole / SI::metre^3;
    }

    attribute def HydrogenIonActivity {
        :> ScalarValues::Real;
    }

    attribute def PHValue {
        :> ScalarValues::Real;
    }

    attribute def Sensitivity {
        unit = SI::volt;
    }

    attribute def Time {
        unit = SI::second;
    }

    item def ChemicalSample {
        attribute analyteConcentration : Concentration;
        attribute hydrogenIonActivity : HydrogenIonActivity;
        attribute pH : PHValue;
        attribute temperature : Temperature;
        attribute ionicStrength : Concentration;
    }

    item def GateSurfaceCharge {
        attribute surfacePotential : ElectricPotential;
        attribute chargeDensity;
        attribute boundAnalyteFraction : Real;
    }

    item def ElectricalBias {
        attribute drainVoltage : ElectricPotential;
        attribute sourceVoltage : ElectricPotential;
        attribute referenceElectrodeVoltage : ElectricPotential;
        attribute substrateVoltage : ElectricPotential;
    }

    item def DrainSourceCurrent {
        attribute value : ElectricCurrent;
        attribute noise : ElectricCurrent;
        attribute timestamp : Time;
    }

    item def SensorReading {
        attribute measuredPH : PHValue;
        attribute analyteConcentrationEstimate : Concentration;
        attribute confidence : Real;
        attribute responseTime : Time;
    }

    port def FluidPort {
        in item sample : ChemicalSample;
    }

    port def ChemicalInterfacePort {
        in item sample : ChemicalSample;
        out item gateCharge : GateSurfaceCharge;
    }

    port def BiasPort {
        in item bias : ElectricalBias;
    }

    port def CurrentPort {
        out item current : DrainSourceCurrent;
    }

    port def DataPort {
        out item reading : SensorReading;
    }

    part def IonSensitiveLayer {
        attribute thickness : Length = 50e-9 [SI::metre];
        attribute siteDensity;
        attribute selectivityCoefficient : Real = 0.98;
        attribute nominalSensitivity : Sensitivity = 0.059 [SI::volt];

        port chemicalPort : ChemicalInterfacePort;

        action bindAnalyte {
            in item sample : ChemicalSample;
            out item charge : GateSurfaceCharge;

            first start;
            then computeSurfaceEquilibrium;
            then updateSurfacePotential;
            then done;

            action computeSurfaceEquilibrium;
            action updateSurfacePotential;
        }
    }

    part def ReferenceElectrode {
        attribute stablePotential : ElectricPotential = 0.205 [SI::volt];
        attribute driftRate : ElectricPotential = 1.0e-6 [SI::volt];

        port fluidPort : FluidPort;
        port biasPort : BiasPort;
    }

    part def SemiconductorChannel {
        attribute length : Length = 10e-6 [SI::metre];
        attribute width : Length = 100e-6 [SI::metre];
        attribute thresholdVoltage : ElectricPotential = 0.7 [SI::volt];
        attribute transconductance;
        attribute mobility;
        attribute oxideCapacitance;

        port gateChemicalPort : ChemicalInterfacePort;
        port biasPort : BiasPort;
        port currentPort : CurrentPort;

        action modulateCurrent {
            in item charge : GateSurfaceCharge;
            in item bias : ElectricalBias;
            out item drainCurrent : DrainSourceCurrent;

            first receiveGatePotential;
            then calculateEffectiveGateVoltage;
            then calculateDrainSourceCurrent;
            then publishCurrent;
            then done;

            action receiveGatePotential;
            action calculateEffectiveGateVoltage;
            action calculateDrainSourceCurrent;
            action publishCurrent;
        }
    }

    part def SignalConditioner {
        attribute currentGain : Real = 1000000.0;
        attribute lowPassCutoffFrequency;
        attribute inputCurrentRange : ElectricCurrent = 1.0e-3 [SI::ampere];

        port currentInput : CurrentPort;
        port dataOutput : DataPort;

        action convertCurrentToReading {
            in item current : DrainSourceCurrent;
            out item reading : SensorReading;

            first sampleCurrent;
            then filterNoise;
            then compensateTemperature;
            then estimateAnalyteLevel;
            then done;

            action sampleCurrent;
            action filterNoise;
            action compensateTemperature;
            action estimateAnalyteLevel;
        }
    }

    part def BiasController {
        attribute nominalDrainVoltage : ElectricPotential = 1.0 [SI::volt];
        attribute nominalReferenceVoltage : ElectricPotential = 0.0 [SI::volt];
        attribute allowableRipple : ElectricPotential = 0.001 [SI::volt];

        port biasOutput : BiasPort;

        action regulateBias {
            out item bias : ElectricalBias;

            first initializeBias;
            then maintainStableBias;
            then done;

            action initializeBias;
            action maintainStableBias;
        }
    }

    part def MicrofluidicCell {
        attribute sampleVolume;
        attribute channelHeight : Length = 100e-6 [SI::metre];
        attribute channelWidth : Length = 1.0e-3 [SI::metre];

        port inlet : FluidPort;
        port sensingInterface : ChemicalInterfacePort;

        action deliverSample {
            in item sample : ChemicalSample;
            out item conditionedSample : ChemicalSample;

            first acceptSample;
            then stabilizeFlow;
            then exposeGateSurface;
            then done;

            action acceptSample;
            action stabilizeFlow;
            action exposeGateSurface;
        }
    }

    part def ChemicalFETSensor {
        attribute primaryFunction : String = "Convert chemical activity at an ion-sensitive gate into a modulated drain-source current and report the corresponding chemical concentration or pH.";
        attribute operatingTemperature : Temperature = 298.15 [SI::kelvin];
        attribute measurementRangeLowPH : PHValue = 2.0;
        attribute measurementRangeHighPH : PHValue = 12.0;
        attribute targetResponseTime : Time = 5.0 [SI::second];

        port sampleInput : FluidPort;
        port measurementOutput : DataPort;

        part microfluidicCell : MicrofluidicCell;
        part ionSensitiveLayer : IonSensitiveLayer;
        part referenceElectrode : ReferenceElectrode;
        part semiconductorChannel : SemiconductorChannel;
        part biasController : BiasController;
        part signalConditioner : SignalConditioner;

        connect sampleInput to microfluidicCell.inlet;
        connect microfluidicCell.sensingInterface to ionSensitiveLayer.chemicalPort;
        connect ionSensitiveLayer.chemicalPort to semiconductorChannel.gateChemicalPort;
        connect microfluidicCell.inlet to referenceElectrode.fluidPort;
        connect biasController.biasOutput to semiconductorChannel.biasPort;
        connect biasController.biasOutput to referenceElectrode.biasPort;
        connect semiconductorChannel.currentPort to signalConditioner.currentInput;
        connect signalConditioner.dataOutput to measurementOutput;

        state def MeasurementLifecycle {
            state idle;
            state sampleLoaded;
            state surfaceEquilibrating;
            state currentStabilizing;
            state measuring;
            state reporting;
            state fault;

            transition first idle;
            transition idle to sampleLoaded
                accept sampleReceived;

            transition sampleLoaded to surfaceEquilibrating
                do microfluidicCell.deliverSample;

            transition surfaceEquilibrating to currentStabilizing
                do ionSensitiveLayer.bindAnalyte;

            transition currentStabilizing to measuring
                do semiconductorChannel.modulateCurrent;

            transition measuring to reporting
                do signalConditioner.convertCurrentToReading;

            transition reporting to idle
                accept readingDelivered;

            transition idle to fault
                accept biasOutOfRange;

            transition sampleLoaded to fault
                accept sampleTemperatureOutOfRange;

            transition measuring to fault
                accept currentSaturationDetected;

            transition fault to idle
                accept reset;
        }

        action performMeasurement {
            in item sample : ChemicalSample;
            out item reading : SensorReading;

            first loadSample;
            then establishReferencePotential;
            then formGateSurfaceCharge;
            then modulateChannelConductance;
            then senseDrainSourceCurrent;
            then computeChemicalReading;
            then publishReading;
            then done;

            action loadSample;
            action establishReferencePotential;
            action formGateSurfaceCharge;
            action modulateChannelConductance;
            action senseDrainSourceCurrent;
            action computeChemicalReading;
            action publishReading;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject sensor : ChemicalFETSensor;

        doc /* The ChemicalFET sensor shall provide a high-level chemical-to-electrical transduction function by exposing an ion-sensitive gate to a liquid sample, converting analyte activity into surface potential, modulating semiconductor channel current, and reporting a chemical reading. */

        require constraint {
            sensor.targetResponseTime <= 5.0 [SI::second]
        }
    }

    requirement def MeasurementRangeRequirement {
        subject sensor : ChemicalFETSensor;

        doc /* The ChemicalFET sensor shall measure sample pH across the operating range required for aqueous chemical analysis. */

        require constraint {
            sensor.measurementRangeLowPH <= 2.0 and sensor.measurementRangeHighPH >= 12.0
        }
    }

    requirement def BiasStabilityRequirement {
        subject controller : BiasController;

        doc /* The bias controller shall maintain drain and reference electrode potentials sufficiently stable to prevent electrical drift from dominating chemical response. */

        require constraint {
            controller.allowableRipple <= 0.001 [SI::volt]
        }
    }

    requirement def GateSensitivityRequirement {
        subject layer : IonSensitiveLayer;

        doc /* The ion-sensitive layer shall provide near-Nernstian sensitivity for hydrogen ion activity at room temperature. */

        require constraint {
            layer.nominalSensitivity >= 0.050 [SI::volt] and layer.nominalSensitivity <= 0.065 [SI::volt]
        }
    }

    requirement def NonDestructiveSampleRequirement {
        subject sensor : ChemicalFETSensor;

        doc /* The ChemicalFET sensing process shall infer chemical activity from field-effect modulation without consuming the sample as a reactant in the transduction mechanism. */
    }

    part chemicalFETSystem : ChemicalFETSensor;

    satisfy PrimaryFunctionRequirement by chemicalFETSystem;
    satisfy MeasurementRangeRequirement by chemicalFETSystem;
    satisfy BiasStabilityRequirement by chemicalFETSystem.biasController;
    satisfy GateSensitivityRequirement by chemicalFETSystem.ionSensitiveLayer;
    satisfy NonDestructiveSampleRequirement by chemicalFETSystem;
}