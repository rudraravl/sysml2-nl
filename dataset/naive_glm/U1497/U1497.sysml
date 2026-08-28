package SiliconeRubberComposite {
    import ScalarValues::*;

    // ===== Value Types =====

    value type TemperatureCelsius :> Real {
        attribute unit : String = "degC";
    }

    value type PressureMPa :> Real {
        attribute unit : String = "MPa";
    }

    value type TensileStrengthMPa :> Real {
        attribute unit : String = "MPa";
    }

    value type ElongationPercent :> Real {
        attribute unit : String = "%";
    }

    value type CompressionSetPercent :> Real {
        attribute unit : String = "%";
    }

    value type ShoreAHardness :> Real {
        attribute unit : String = "Shore A";
    }

    value type ParticleSizeNm :> Real {
        attribute unit : String = "nm";
    }

    value type ViscosityPaS :> Real {
        attribute unit : String = "Pa*s";
    }

    value type LengthMm :> Real {
        attribute unit : String = "mm";
    }

    value type SurfaceAreaM2PerG :> Real {
        attribute unit : String = "m2/g";
    }

    value type ConcentrationPpm :> Real {
        attribute unit : String = "ppm";
    }

    value type DurationHours :> Real {
        attribute unit : String = "h";
    }

    value type MassFractionPercent :> Real {
        attribute unit : String = "%";
    }

    // ===== Item Definitions =====

    item def VinylTerminatedPDMS {
        doc /* Vinyl-terminated polydimethylsiloxane base polymer providing flexibility and thermal stability. */;
        attribute viscosity : ViscosityPaS;
        attribute description : String = "Vinyl-terminated PDMS";
    }

    item def NanoSilicaFiller {
        doc /* Nano-sized silica reinforcing filler for improved strength, hardness, and tear resistance. */;
        attribute particleSize : ParticleSizeNm;
        attribute specificSurfaceArea : SurfaceAreaM2PerG;
        attribute description : String = "Nano-sized silica particles";
    }

    item def PlatinumCuringAgent {
        doc /* Platinum-based addition cure catalyst for cross-linking the polymer matrix. */;
        attribute concentration : ConcentrationPpm;
        attribute description : String = "Platinum-based catalyst";
    }

    item def UncuredCompound {
        doc /* Homogeneous mixture of base polymer, filler, and curing agent prior to heat activation. */;
        attribute description : String = "Uncured silicone compound";
    }

    item def CuredSiliconeRubber {
        doc /* Cross-linked solid silicone rubber after initial heat cure. */;
        attribute description : String = "Cured silicone rubber";
    }

    item def PostCuredRubber {
        doc /* Post-cured silicone rubber with final material properties achieved. */;
        attribute description : String = "Post-cured silicone rubber";
    }

    item def IndustrialFluid {
        doc /* Industrial fluid encountered during sealing or conveyance service. */;
        attribute fluidName : String;
        attribute chemicalClass : String;
    }

    // ===== Port Definitions =====

    port def ThermalInterfacePort {
        attribute ambientTemperature : TemperatureCelsius;
        attribute description : String = "Thermal environment interface";
    }

    port def MechanicalInterfacePort {
        attribute contactPressure : PressureMPa;
        attribute description : String = "Mechanical loading interface";
    }

    port def FluidInterfacePort {
        attribute fluidType : String;
        attribute fluidPressure : PressureMPa;
        attribute description : String = "Fluid conveyance or sealing interface";
    }

    // ===== Composite Material Definition =====

    part def SiliconeRubberMaterial {
        doc /* High-performance silicone rubber composite material engineered for demanding industrial applications including sealing, gasketing, and fluid transfer. */;

        // Material properties
        attribute shoreAHardness : ShoreAHardness = 55;
        attribute tensileStrength : TensileStrengthMPa = 10;
        attribute elongationAtBreak : ElongationPercent = 400;
        attribute compressionSet : CompressionSetPercent = 15;
        attribute minOperatingTemp : TemperatureCelsius = -60;
        attribute maxOperatingTemp : TemperatureCelsius = 250;
        attribute ratedServiceLife : DurationHours = 10000;
        attribute description : String = "Platinum-cured silicone rubber composite";

        // Interface ports
        port thermalPort : ThermalInterfacePort;
        port mechanicalPort : MechanicalInterfacePort;

        // Composite constituents
        item polymerBase : VinylTerminatedPDMS[1] {
            attribute viscosity : ViscosityPaS = 50;
        }

        item reinforcingFiller : NanoSilicaFiller[1] {
            attribute particleSize : ParticleSizeNm = 20;
            attribute specificSurfaceArea : SurfaceAreaM2PerG = 200;
        }

        item curingAgent : PlatinumCuringAgent[1] {
            attribute concentration : ConcentrationPpm = 10;
        }

        // Lifecycle state machine
        exhibit state lifecycle {
            entry; then mixing;

            state mixing {
                doc /* Raw chemical components—vinyl-terminated PDMS base, nano-silica filler, and platinum curing agent—are combined into a homogeneous uncured compound. */;
                entry action mixComponents {
                    doc /* Blend polymer base, reinforcing filler, and curing agent under controlled conditions. */;
                }
            }

            state curing {
                doc /* Heat activates the platinum catalyst, initiating addition-cure cross-linking that transforms the liquid compound into a solid elastomeric matrix. */;
                entry action applyHeatCure {
                    doc /* Apply elevated temperature to activate platinum catalyst and form cross-linked molecular structure. */;
                }
            }

            state postCuring {
                doc /* Post-cure bake removes residual volatiles and stabilizes final mechanical and chemical properties. */;
                entry action postCureBake {
                    doc /* Bake cured rubber at elevated temperature to achieve final material properties. */;
                }
            }

            state inService {
                doc /* The manufactured component performs its sealing or fluid conveyance function while withstanding mechanical forces, thermal cycling, and chemical exposure. */;
                entry action beginService {
                    doc /* Component enters operational service in its installed application. */;
                }
            }

            state aging {
                doc /* The material gradually degrades under cumulative operational stresses including thermal cycling, mechanical fatigue, and chemical exposure. */;
                entry action degrade {
                    doc /* Material properties progressively deteriorate under service conditions. */;
                }
            }

            state endOfLife {
                doc /* The material reaches the end of its serviceable life and the component must be replaced. */;
                entry action decommission {
                    doc /* Remove component from service and dispose of or recycle material. */;
                }
            }

            transition from mixing to curing;
            transition from curing to postCuring;
            transition from postCuring to inService;
            transition from inService to aging;
            transition from aging to endOfLife;
        }
    }

    // ===== Component Definitions =====

    part def ORingSeal :> SiliconeRubberMaterial {
        doc /* Toroidal O-ring seal for preventing fluid leaks at static and dynamic interfaces. */;

        attribute innerDiameter : LengthMm;
        attribute crossSectionDiameter : LengthMm;

        port fluidPort : FluidInterfacePort;

        action seal {
            doc /* Maintain compressive contact at the sealing interface to prevent fluid leakage under pressure and temperature. */;
        }
    }

    part def FlatGasket :> SiliconeRubberMaterial {
        doc /* Flat annular gasket for creating a tight seal between mating machine flange surfaces. */;

        attribute outerDiameter : LengthMm;
        attribute innerDiameter : LengthMm;
        attribute thickness : LengthMm;

        port fluidPort : FluidInterfacePort;

        action seal {
            doc /* Compress between mating surfaces to fill surface irregularities and create a leak-tight seal. */;
        }
    }

    part def FlexibleHose :> SiliconeRubberMaterial {
        doc /* Flexible tubular hose for conveying fluids under pressure while accommodating movement and vibration. */;

        attribute innerDiameter : LengthMm;
        attribute outerDiameter : LengthMm;
        attribute length : LengthMm;
        attribute bendRadius : LengthMm;

        port inletPort : FluidInterfacePort;
        port outletPort : FluidInterfacePort;

        action conveyFluid {
            doc /* Convey fluid from inlet to outlet under pressure while maintaining structural integrity and flexibility. */;
        }
    }

    // ===== Application System =====

    part def IndustrialSealingSystem {
        doc /* Industrial sealing system comprising O-ring, gasket, and hose components operating in a shared thermal, mechanical, and fluid environment. */;

        port externalThermalPort : ThermalInterfacePort;
        port externalMechanicalPort : MechanicalInterfacePort;
        port externalFluidPort : FluidInterfacePort;

        part oRing : ORingSeal[1] {
            attribute innerDiameter : LengthMm = 50;
            attribute crossSectionDiameter : LengthMm = 3;
        }

        part gasket : FlatGasket[1] {
            attribute outerDiameter : LengthMm = 100;
            attribute innerDiameter : LengthMm = 50;
            attribute thickness : LengthMm = 2;
        }

        part hose : FlexibleHose[1] {
            attribute innerDiameter : LengthMm = 12;
            attribute outerDiameter : LengthMm = 18;
            attribute length : LengthMm = 500;
            attribute bendRadius : LengthMm = 50;
        }

        // Inter-component connections
        connection oRingGasketMechanicalConnection {
            oRing.mechanicalPort <-> gasket.mechanicalPort;
        }

        connection hoseGasketFluidConnection {
            hose.outletPort <-> gasket.fluidPort;
        }

        // Environment-to-component connections
        connection thermalEnvironmentToORing {
            externalThermalPort <-> oRing.thermalPort;
        }

        connection thermalEnvironmentToGasket {
            externalThermalPort <-> gasket.thermalPort;
        }

        connection thermalEnvironmentToHose {
            externalThermalPort <-> hose.thermalPort;
        }

        connection mechanicalEnvironmentToGasket {
            externalMechanicalPort <-> gasket.mechanicalPort;
        }

        connection fluidEnvironmentToHose {
            externalFluidPort <-> hose.inletPort;
        }
    }

    // ===== Requirement Definitions =====

    requirement def ThermalStabilityRequirement {
        doc /* The material shall maintain structural integrity and sealing effectiveness across the operating temperature range from -60 degC to 250 degC. */;

        subject material : SiliconeRubberMaterial;

        attribute requiredMinTemp : TemperatureCelsius = -60;
        attribute requiredMaxTemp : TemperatureCelsius = 250;

        require {
            material.minOperatingTemp <= requiredMinTemp;
            material.maxOperatingTemp >= requiredMaxTemp;
        }
    }

    requirement def MechanicalStrengthRequirement {
        doc /* The material shall meet minimum mechanical property thresholds for tensile strength, elongation at break, and Shore A hardness. */;

        subject material : SiliconeRubberMaterial;

        attribute requiredMinTensileStrength : TensileStrengthMPa = 8;
        attribute requiredMinElongation : ElongationPercent = 400;
        attribute requiredHardness : ShoreAHardness = 55;

        require {
            material.tensileStrength >= requiredMinTensileStrength;
            material.elongationAtBreak >= requiredMinElongation;
            material.shoreAHardness == requiredHardness;
        }
    }

    requirement def CompressionSetRequirement {
        doc /* The material shall exhibit low compression set to ensure seals return to original shape after prolonged compression, maintaining sealing effectiveness. */;

        subject material : SiliconeRubberMaterial;

        attribute maxAllowableCompressionSet : CompressionSetPercent = 25;

        require {
            material.compressionSet <= maxAllowableCompressionSet;
        }
    }

    requirement def CompositeCompositionRequirement {
        doc /* The material shall be formulated as a composite of vinyl-terminated PDMS base, nano-silica filler, and platinum curing agent. */;

        subject material : SiliconeRubberMaterial;

        require {
            material.polymerBase.viscosity > 0;
            material.reinforcingFiller.particleSize > 0;
            material.curingAgent.concentration > 0;
        }
    }

    requirement def CrossLinkingRequirement {
        doc /* The platinum curing agent shall create a cross-linked molecular structure that transforms the liquid compound into a solid, stable rubber when activated by heat. */;

        subject material : SiliconeRubberMaterial;
    }

    requirement def SealingFunctionRequirement {
        doc /* O-ring seals and flat gaskets shall prevent fluid leakage under specified pressure and temperature conditions throughout their service life. */;

        subject oRing : ORingSeal;
        subject gasket : FlatGasket;
    }

    requirement def FluidConveyanceRequirement {
        doc /* Flexible hoses shall convey fluids under pressure without rupture, leakage, or excessive deformation. */;

        subject hose : FlexibleHose;
    }

    requirement def LifecycleRequirement {
        doc /* The material shall progress through defined lifecycle stages: mixing, curing, post-curing, in-service, aging, and end-of-life. */;

        subject material : SiliconeRubberMaterial;
    }

    requirement def ChemicalResistanceRequirement {
        doc /* The material shall resist chemical degradation from industrial fluids, oils, and solvents encountered during service. */;

        subject material : SiliconeRubberMaterial;
    }

    requirement def ThermalCyclingResistanceRequirement {
        doc /* The material shall withstand repeated thermal cycling between extreme cold and heat without cracking, embrittlement, or loss of sealing force. */;

        subject material : SiliconeRubberMaterial;
    }

    requirement def TearResistanceRequirement {
        doc /* The material shall resist tear propagation initiated at stress concentration points, ensuring durable performance in demanding mechanical applications. */;

        subject material : SiliconeRubberMaterial;
    }

    // ===== Requirement Usages and Satisfactions =====

    part siliconeMaterial : SiliconeRubberMaterial;
    part sealingSystem : IndustrialSealingSystem;

    requirement thermalStabReq : ThermalStabilityRequirement;
    requirement mechStrengthReq : MechanicalStrengthRequirement;
    requirement compSetReq : CompressionSetRequirement;
    requirement compCompReq : CompositeCompositionRequirement;
    requirement crossLinkReq : CrossLinkingRequirement;
    requirement sealFuncReq : SealingFunctionRequirement;
    requirement fluidConvReq : FluidConveyanceRequirement;
    requirement lifecycleReq : LifecycleRequirement;
    requirement chemResistReq : ChemicalResistanceRequirement;
    requirement thermalCycleReq : ThermalCyclingResistanceRequirement;
    requirement tearResistReq : TearResistanceRequirement;

    satisfaction thermalStabReq by siliconeMaterial;
    satisfaction mechStrengthReq by siliconeMaterial;
    satisfaction compSetReq by siliconeMaterial;
    satisfaction compCompReq by siliconeMaterial;
    satisfaction crossLinkReq by siliconeMaterial;
    satisfaction sealFuncReq by sealingSystem.oRing;
    satisfaction sealFuncReq by sealingSystem.gasket;
    satisfaction fluidConvReq by sealingSystem.hose;
    satisfaction lifecycleReq by siliconeMaterial;
    satisfaction chemResistReq by siliconeMaterial;
    satisfaction thermalCycleReq by siliconeMaterial;
    satisfaction tearResistReq by siliconeMaterial;
}
