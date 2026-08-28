package HighPerformanceSiliconeRubberSystem {
    private import ScalarValues::*;
    private import Quantities::*;
    private import MeasurementReferences::*;
    private import SI::*;
    private import ISQ::*;

    attribute def TensileStrengthUnit :> DerivedUnit {
        private attribute lengthPF: QuantityPowerFactor[1] { :>> quantity = isq.L; :>> exponent = -1; }
        private attribute massPF: QuantityPowerFactor[1] { :>> quantity = isq.M; :>> exponent = 1; }
        private attribute durationPF: QuantityPowerFactor[1] { :>> quantity = isq.T; :>> exponent = -2; }
        attribute :>> quantityDimension { :>> quantityPowerFactors = (lengthPF, massPF, durationPF); }
    }
    attribute def TensileStrengthValue :> ScalarQuantityValue {
        attribute :>> num: Real;
        attribute :>> mRef: TensileStrengthUnit;
    }
    attribute <'N/mm²'> 'newton per square millimetre' : TensileStrengthUnit = N / mm^2;

    attribute def ElongationValue :> DimensionOneValue {
        attribute :>> num: Real;
    }

    attribute def ShoreHardnessValue {
        attribute value: Real;
        attribute scale: String = "Shore A";
    }

    attribute def CompressionSetValue :> DimensionOneValue {
        attribute :>> num: Real;
    }

    part def Substance;
    part def Material :> Substance;

    part def PolymerBase :> Material;
    part def ReinforcingFiller :> Material;
    part def CuringAgent :> Material;

    attribute def MaterialFraction {
        ref material: Material[1];
        attribute massFraction: MassFractionValue[1];
    }
    attribute def MassFractionValue :> DimensionOneValue;

    part def CompositeMaterial :> Material {
        attribute fractions: MaterialFraction[2..*];
    }

    individual def VinylTerminatedPDMS :> PolymerBase;
    individual def NanoSilica :> ReinforcingFiller;
    individual def PlatinumCuringAgent :> CuringAgent;

    part def HighPerformanceSiliconeRubber :> CompositeMaterial {
        attribute fraction1 :> fractions {
            ref :>> material : VinylTerminatedPDMS;
            attribute :>> massFraction = 0.85[one];
        }
        attribute fraction2 :> fractions {
            ref :>> material : NanoSilica;
            attribute :>> massFraction = 0.12[one];
        }
        attribute fraction3 :> fractions {
            ref :>> material : PlatinumCuringAgent;
            attribute :>> massFraction = 0.03[one];
        }

        attribute minOperatingTemp: TemperatureValue = -60 ['°C'];
        attribute maxOperatingTemp: TemperatureValue = 250 ['°C'];
        attribute tensileStrength: TensileStrengthValue = 10 ['N/mm²'];
        attribute elongationAtBreak: ElongationValue = 4.0[one];
        attribute hardness: ShoreHardnessValue { :>> value = 55; }
        attribute compressionSet: CompressionSetValue = 0.15[one];
    }

    action def MixingAction {
        in base: PolymerBase;
        in filler: ReinforcingFiller;
        in agent: CuringAgent;
        out composite: CompositeMaterial;
    }

    action def HeatCuringAction {
        in uncured: CompositeMaterial;
        out cured: CompositeMaterial;
    }

    action def PostCuringAction {
        in cured: CompositeMaterial;
        out finished: CompositeMaterial;
    }

    state def SiliconeLifecycle {
        entry; then RawComponents;

        state RawComponents;
        state Mixed;
        state HeatCured;
        state PostCured;
        state ReadyForService;
        state Operational;
        state Aging;
        state EndOfLife;

        transition from RawComponents to Mixed;
        transition from Mixed to HeatCured;
        transition from HeatCured to PostCured;
        transition from PostCured to ReadyForService;
        transition from ReadyForService to Operational;
        transition from Operational to Aging;
        transition from Aging to EndOfLife;
    }

    port def FluidPort {
        attribute pressure: PressureValue;
        attribute temperature: TemperatureValue;
    }
    port def MechanicalInterfacePort {
        attribute force: ForceValue;
    }
    port def ThermalInterfacePort {
        attribute temperature: TemperatureValue;
    }

    part def ElastomericComponent {
        part material: HighPerformanceSiliconeRubber[1];
        port mechInterface: MechanicalInterfacePort;
        port thermalInterface: ThermalInterfacePort;
        exhibit state lifecycle: SiliconeLifecycle;
    }

    part def ORingSeal :> ElastomericComponent {
        attribute innerDiameter: LengthValue;
        attribute crossSectionDiameter: LengthValue;
        port sealedFluid: FluidPort;
    }

    part def FlatGasket :> ElastomericComponent {
        attribute thickness: LengthValue;
        attribute outerDiameter: LengthValue;
        port fluidSideA: FluidPort;
        port fluidSideB: FluidPort;
    }

    part def FlexibleHose :> ElastomericComponent {
        port inlet: FluidPort;
        port outlet: FluidPort;
        attribute length: LengthValue;
        attribute innerDiameter: LengthValue;
    }

    part def FluidSource {
        port fluidPort: FluidPort;
        attribute pressure: PressureValue;
    }
    part def CompressionPlate {
        port loadPort: MechanicalInterfacePort;
        attribute force: ForceValue;
    }
    part def ThermalEnvironment {
        port thermalPort: ThermalInterfacePort;
        attribute temperature: TemperatureValue;
    }

    requirement def ElastomericBarrierRequirement {
        doc /* The material shall provide a flexible, durable, and reliable elastomeric barrier
               that maintains its integrity across extreme temperatures and under mechanical stress. */
    }

    requirement def ThermalStabilityRequirement :> ElastomericBarrierRequirement {
        subject material: HighPerformanceSiliconeRubber;
        doc 'The material must maintain integrity across extreme temperatures.';
        attribute minTemp: TemperatureValue = -60 ['°C'];
        attribute maxTemp: TemperatureValue = 250 ['°C'];
        constraint { material.minOperatingTemp <= minTemp and material.maxOperatingTemp >= maxTemp }
    }

    requirement def MechanicalPropertiesRequirement :> ElastomericBarrierRequirement {
        subject material: HighPerformanceSiliconeRubber;
        doc 'The material must possess high tensile strength, elongation, and specific hardness.';
        attribute minTensileStrength: TensileStrengthValue = 9 ['N/mm²'];
        attribute minElongation: ElongationValue = 4.0[one];
        attribute targetHardness: ShoreHardnessValue { :>> value = 55; }
        constraint { material.tensileStrength >= minTensileStrength }
        constraint { material.elongationAtBreak >= minElongation }
        constraint { material.hardness.value == targetHardness.value }
    }

    requirement def SealingEffectivenessRequirement :> ElastomericBarrierRequirement {
        subject material: HighPerformanceSiliconeRubber;
        doc 'The material must return to original shape after compression.';
        attribute maxCompressionSet: CompressionSetValue = 0.20[one];
        constraint { material.compressionSet <= maxCompressionSet }
    }

    requirement def ComponentSealingRequirement {
        subject component: ElastomericComponent;
        doc /* Components made from the material shall prevent leaks and convey fluids
               while withstanding mechanical, thermal, and chemical loads. */
    }

    part def System {
        part oRing: ORingSeal;
        part gasket: FlatGasket;
        part hose: FlexibleHose;
        part fluidSource: FluidSource;
        part compressionPlate: CompressionPlate;
        part thermalEnv: ThermalEnvironment;

        connect fluidSource.fluidPort to oRing.sealedFluid;
        connect compressionPlate.loadPort to oRing.mechInterface;
        connect thermalEnv.thermalPort to oRing.thermalInterface;

        satisfy requirement thermalReq: ThermalStabilityRequirement by oRing.material;
        satisfy requirement mechReq: MechanicalPropertiesRequirement by gasket.material;
        satisfy requirement sealReq: SealingEffectivenessRequirement by hose.material;
        satisfy requirement componentSealReq1: ComponentSealingRequirement by oRing;
        satisfy requirement componentSealReq2: ComponentSealingRequirement by gasket;
        satisfy requirement componentSealReq3: ComponentSealingRequirement by hose;
    }
}
