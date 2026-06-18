package SiliconeRubberBasedSystem {

    import ScalarValues::*;

    attribute def Length_mm :> Real {
        attribute unitSymbol : String = "mm";
        attribute quantityKind : String = "length";
    }

    attribute def Area_mm2 :> Real {
        attribute unitSymbol : String = "mm^2";
        attribute quantityKind : String = "area";
    }

    attribute def Volume_cm3 :> Real {
        attribute unitSymbol : String = "cm^3";
        attribute quantityKind : String = "volume";
    }

    attribute def Mass_g :> Real {
        attribute unitSymbol : String = "g";
        attribute quantityKind : String = "mass";
    }

    attribute def Density_g_per_cm3 :> Real {
        attribute unitSymbol : String = "g/cm^3";
        attribute quantityKind : String = "density";
    }

    attribute def Temperature_C :> Real {
        attribute unitSymbol : String = "degC";
        attribute quantityKind : String = "temperature";
    }

    attribute def Pressure_kPa :> Real {
        attribute unitSymbol : String = "kPa";
        attribute quantityKind : String = "pressure";
    }

    attribute def Force_N :> Real {
        attribute unitSymbol : String = "N";
        attribute quantityKind : String = "force";
    }

    attribute def Stiffness_N_per_mm :> Real {
        attribute unitSymbol : String = "N/mm";
        attribute quantityKind : String = "linear stiffness";
    }

    attribute def Hardness_ShoreA :> Real {
        attribute unitSymbol : String = "Shore A";
        attribute quantityKind : String = "elastomer hardness";
    }

    attribute def Percent :> Real {
        attribute unitSymbol : String = "%";
        attribute quantityKind : String = "ratio";
    }

    attribute def LeakRate_mL_per_min :> Real {
        attribute unitSymbol : String = "mL/min";
        attribute quantityKind : String = "volumetric leakage rate";
    }

    attribute def ThermalConductivity_W_per_mK :> Real {
        attribute unitSymbol : String = "W/(m*K)";
        attribute quantityKind : String = "thermal conductivity";
    }

    attribute def UVExposure_kJ_per_m2 :> Real {
        attribute unitSymbol : String = "kJ/m^2";
        attribute quantityKind : String = "ultraviolet radiant exposure";
    }

    attribute def Time_h :> Real {
        attribute unitSymbol : String = "h";
        attribute quantityKind : String = "time";
    }

    attribute def BooleanValue :> Boolean;

    item def Water {
        attribute temperature: Temperature_C;
        attribute pressure: Pressure_kPa;
    }

    item def DustParticle {
        attribute equivalentDiameter: Length_mm;
        attribute mass: Mass_g;
    }

    item def AmbientAir {
        attribute temperature: Temperature_C;
        attribute pressure: Pressure_kPa;
        attribute relativeHumidity: Percent;
    }

    item def CompressionLoad {
        attribute magnitude: Force_N;
        attribute contactArea: Area_mm2;
    }

    item def HeatFlow {
        attribute interfaceTemperature: Temperature_C;
        attribute heatFluxDensity: Real;
        attribute heatFluxUnit: String = "W/m^2";
    }

    item def SiliconeRubberCompound {
        attribute basePolymer: String = "polydimethylsiloxane silicone rubber";
        attribute curingSystem: String = "platinum-cured addition system";
        attribute filler: String = "fumed silica reinforcement";
        attribute color: String = "translucent red";
        attribute density: Density_g_per_cm3 = 1.18;
        attribute hardness: Hardness_ShoreA = 50.0;
        attribute minimumServiceTemperature: Temperature_C = -55.0;
        attribute maximumServiceTemperature: Temperature_C = 200.0;
        attribute thermalConductivity: ThermalConductivity_W_per_mK = 0.24;
        attribute compressionSetAfter22hAt175C: Percent = 18.0;
        attribute siliconeRubberMassFraction: Percent = 93.0;
    }

    item def ProtectedPayload {
        attribute description: String = "electronics and dry interior volume protected by the silicone rubber seal";
        attribute moistureSensitive: BooleanValue = true;
    }

    port def MechanicalCompressionPort {
        in load: CompressionLoad;
        in displacement: Length_mm;
        out reactionForce: Force_N;
        out compressionPercent: Percent;
    }

    port def SealingContactPort {
        in contactPressure: Pressure_kPa;
        in surfaceRoughness: Length_mm;
        out leakageRate: LeakRate_mL_per_min;
        out sealed: BooleanValue;
    }

    port def EnvironmentalExposurePort {
        in water: Water;
        in dust: DustParticle;
        in air: AmbientAir;
        in uvExposure: UVExposure_kJ_per_m2;
        out rejectedWaterLeakageRate: LeakRate_mL_per_min;
        out rejectedDust: BooleanValue;
    }

    port def ProtectedVolumePort {
        out payload: ProtectedPayload;
        in allowedLeakageRate: LeakRate_mL_per_min;
        out internalHumidity: Percent;
        out protectedVolumeDry: BooleanValue;
    }

    port def ThermalPort {
        in heatFlow: HeatFlow;
        out interfaceTemperature: Temperature_C;
    }

    interface def CompressionTransferInterface {
        end source: MechanicalCompressionPort;
        end target: MechanicalCompressionPort;
    }

    interface def SealingInterface {
        end gasketSide: SealingContactPort;
        end rigidSide: SealingContactPort;
    }

    interface def EnvironmentalBarrierInterface {
        end exposedSide: EnvironmentalExposurePort;
        end protectedSide: ProtectedVolumePort;
    }

    part def MoldedSiliconeRubberGasket {
        attribute name: String = "continuous molded silicone rubber gasket";
        attribute crossSectionWidth: Length_mm = 6.0;
        attribute crossSectionHeight: Length_mm = 4.0;
        attribute freeHeight: Length_mm = 4.0;
        attribute compressedHeight: Length_mm = 3.1;
        attribute nominalCompression: Percent = 22.5;
        attribute perimeterLength: Length_mm = 420.0;
        attribute contactArea: Area_mm2 = 2520.0;
        attribute mass: Mass_g = 18.5;
        attribute linearStiffness: Stiffness_N_per_mm = 14.0;
        attribute minimumRecommendedCompression: Percent = 15.0;
        attribute maximumRecommendedCompression: Percent = 30.0;
        attribute nominalContactPressure: Pressure_kPa = 85.0;
        attribute nominalLeakageRate: LeakRate_mL_per_min = 0.02;
        attribute retainedElasticityAfterAging: Percent = 82.0;

        item compound: SiliconeRubberCompound;

        port upperContact: SealingContactPort;
        port lowerContact: SealingContactPort;
        port compressionPort: MechanicalCompressionPort;
        port environmentSide: EnvironmentalExposurePort;
        port protectedSide: ProtectedVolumePort;
        port thermalPort: ThermalPort;
    }

    part def RigidHousing {
        attribute material: String = "anodized aluminum";
        attribute grooveWidth: Length_mm = 6.4;
        attribute grooveDepth: Length_mm = 2.8;
        attribute grooveCornerRadius: Length_mm = 0.8;
        attribute matingSurfaceRoughness: Length_mm = 0.003;
        attribute flatnessTolerance: Length_mm = 0.08;

        port grooveContact: SealingContactPort;
        port externalExposure: EnvironmentalExposurePort;
        port internalVolume: ProtectedVolumePort;
        port thermalPort: ThermalPort;
    }

    part def CoverPlate {
        attribute material: String = "glass-filled polycarbonate";
        attribute flangeWidth: Length_mm = 12.0;
        attribute matingSurfaceRoughness: Length_mm = 0.006;
        attribute flatnessTolerance: Length_mm = 0.10;

        port flangeContact: SealingContactPort;
        port clampInput: MechanicalCompressionPort;
        port thermalPort: ThermalPort;
    }

    part def CompressionLimiter {
        attribute material: String = "stainless steel";
        attribute installedHeight: Length_mm = 3.1;
        attribute outsideDiameter: Length_mm = 5.0;
        attribute insideDiameter: Length_mm = 3.2;
        attribute quantity: Integer = 8;
        attribute maximumClampForcePerLimiter: Force_N = 120.0;

        port clampPath: MechanicalCompressionPort;
    }

    part def FastenerSet {
        attribute fastenerType: String = "M3 socket head cap screw";
        attribute quantity: Integer = 8;
        attribute installationTorque_Nm: Real = 0.55;
        attribute preloadPerFastener: Force_N = 95.0;
        attribute totalNominalClampForce: Force_N = 760.0;

        port preloadOutput: MechanicalCompressionPort;
    }

    part def SiliconePrimerFilm {
        attribute material: String = "silane adhesion promoter compatible with silicone rubber";
        attribute dryFilmThickness: Length_mm = 0.015;
        attribute coverageArea: Area_mm2 = 2520.0;
        attribute cureTime: Time_h = 1.0;

        port bondedInterface: SealingContactPort;
    }

    part def SealConditionMonitor {
        attribute samplePeriod: Time_h = 1.0;
        attribute leakAlarmThreshold: LeakRate_mL_per_min = 0.05;
        attribute highTemperatureAlarm: Temperature_C = 180.0;
        attribute highHumidityAlarm: Percent = 70.0;

        port protectedVolumeInput: ProtectedVolumePort;
        port thermalInput: ThermalPort;

        action evaluateSealHealth: EvaluateSealHealth;
    }

    constraint def CompressionWithinRecommendedRange {
        in compression: Percent;
        in minimumCompression: Percent;
        in maximumCompression: Percent;
        compression >= minimumCompression and compression <= maximumCompression
    }

    constraint def LeakageBelowLimit {
        in leakage: LeakRate_mL_per_min;
        in allowedLeakage: LeakRate_mL_per_min;
        leakage <= allowedLeakage
    }

    constraint def TemperatureWithinSiliconeCapability {
        in operatingTemperature: Temperature_C;
        in minimumTemperature: Temperature_C;
        in maximumTemperature: Temperature_C;
        operatingTemperature >= minimumTemperature and operatingTemperature <= maximumTemperature
    }

    constraint def SiliconeRubberDominantMaterial {
        in siliconeRubberMassFraction: Percent;
        siliconeRubberMassFraction >= 90.0
    }

    action def ProvideFlexibleEnvironmentalSeal {
        in externalWater: Water;
        in externalDust: DustParticle;
        in ambientAir: AmbientAir;
        in appliedCompressionLoad: CompressionLoad;
        in surfaceGap: Length_mm;
        out protectedVolumeDry: BooleanValue;
        out achievedLeakageRate: LeakRate_mL_per_min;
        out achievedCompression: Percent;

        action receiveCompressionLoad;
        action elasticallyDeformSiliconeRubber;
        action conformToSurfaceIrregularities;
        action generateContinuousContactPressure;
        action blockLiquidWaterAndDust;
        action accommodateThermalExpansionMismatch;
        action reportHighLevelSealResult;

        first receiveCompressionLoad;
        then elasticallyDeformSiliconeRubber;
        then conformToSurfaceIrregularities;
        then generateContinuousContactPressure;
        then blockLiquidWaterAndDust;
        then accommodateThermalExpansionMismatch;
        then reportHighLevelSealResult;
    }

    action def EvaluateSealHealth {
        in measuredLeakageRate: LeakRate_mL_per_min;
        in measuredTemperature: Temperature_C;
        in internalHumidity: Percent;
        out serviceable: BooleanValue;
        out alarmActive: BooleanValue;

        action compareLeakRateToThreshold;
        action compareTemperatureToLimit;
        action compareHumidityToLimit;
        action setSealHealthState;

        first compareLeakRateToThreshold;
        then compareTemperatureToLimit;
        then compareHumidityToLimit;
        then setSealHealthState;
    }

    action def InstallSiliconeRubberSeal {
        in gasketFreeHeight: Length_mm;
        in limiterHeight: Length_mm;
        in clampForce: Force_N;
        out installedCompression: Percent;
        out installationAccepted: BooleanValue;

        action placeGasketInGroove;
        action applyPrimerFilm;
        action alignCoverPlate;
        action tightenFastenersInCrossPattern;
        action verifyCompressionAgainstLimiters;

        first placeGasketInGroove;
        then applyPrimerFilm;
        then alignCoverPlate;
        then tightenFastenersInCrossPattern;
        then verifyCompressionAgainstLimiters;
    }

    state def SiliconeSealLifecycle {
        in compression: Percent;
        in leakageRate: LeakRate_mL_per_min;
        in operatingTemperature: Temperature_C;
        in tearDepth: Length_mm;

        state MoldedUninstalled;
        state InstalledUncompressed;
        state CompressedSealing;
        state ThermalCyclingService;
        state AgedServiceable;
        state Degraded;
        state FailedOpenLeakPath;

        transition initial then MoldedUninstalled;

        transition install
            first MoldedUninstalled
            then InstalledUncompressed
            accept InstallSiliconeRubberSeal;

        transition applyClamp
            first InstalledUncompressed
            then CompressedSealing
            if compression >= 15.0 and compression <= 30.0;

        transition enterThermalCycling
            first CompressedSealing
            then ThermalCyclingService
            if operatingTemperature >= -55.0 and operatingTemperature <= 200.0;

        transition ageInService
            first ThermalCyclingService
            then AgedServiceable
            if leakageRate <= 0.05;

        transition detectDegradation
            first AgedServiceable
            then Degraded
            if leakageRate > 0.05 or tearDepth > 0.5;

        transition loseSeal
            first Degraded
            then FailedOpenLeakPath
            if leakageRate > 0.50 or tearDepth > 2.0;
    }

    requirement def PrimaryFunctionRequirement {
        subject sealSystem: SiliconeRubberEnvironmentalSealSystem;
        attribute id: String = "SRSS-REQ-001";
        attribute text: String = "The silicone-rubber-based system shall provide a high-level primary function of forming a flexible, resilient environmental barrier between a rigid housing and cover so that water and dust are prevented from entering the protected internal volume while allowing thermal expansion and repeated compression.";
        require constraint {
            sealSystem.nominalLeakageRate <= sealSystem.allowedLeakageRate
        }
    }

    requirement def SiliconeRubberBasisRequirement {
        subject sealSystem: SiliconeRubberEnvironmentalSealSystem;
        attribute id: String = "SRSS-REQ-002";
        attribute text: String = "The functional sealing element of the system shall be predominantly silicone rubber.";
        require constraint {
            sealSystem.gasket.compound.siliconeRubberMassFraction >= 90.0
        }
    }

    requirement def CompressionRequirement {
        subject sealSystem: SiliconeRubberEnvironmentalSealSystem;
        attribute id: String = "SRSS-REQ-003";
        attribute text: String = "The installed gasket compression shall remain between 15 percent and 30 percent to maintain sealing without excessive compression set.";
        require constraint {
            sealSystem.installedCompression >= 15.0 and sealSystem.installedCompression <= 30.0
        }
    }

    requirement def TemperatureRequirement {
        subject sealSystem: SiliconeRubberEnvironmentalSealSystem;
        attribute id: String = "SRSS-REQ-004";
        attribute text: String = "The silicone rubber seal system shall remain serviceable over the specified operating temperature range.";
        require constraint {
            sealSystem.minimumOperatingTemperature >= sealSystem.gasket.compound.minimumServiceTemperature and
            sealSystem.maximumOperatingTemperature <= sealSystem.gasket.compound.maximumServiceTemperature
        }
    }

    requirement def LeakageRequirement {
        subject sealSystem: SiliconeRubberEnvironmentalSealSystem;
        attribute id: String = "SRSS-REQ-005";
        attribute text: String = "The protected volume leakage rate shall not exceed the allowed high-level environmental ingress limit.";
        require constraint {
            sealSystem.nominalLeakageRate <= 0.05
        }
    }

    part def SiliconeRubberEnvironmentalSealSystem {
        attribute systemName: String = "Silicone Rubber Environmental Seal System";
        attribute primaryFunction: String = "Provide a compliant silicone rubber barrier that seals a protected volume from water and dust while accommodating mechanical compression and temperature variation.";
        attribute allowedLeakageRate: LeakRate_mL_per_min = 0.05;
        attribute nominalLeakageRate: LeakRate_mL_per_min = 0.02;
        attribute installedCompression: Percent = 22.5;
        attribute minimumOperatingTemperature: Temperature_C = -40.0;
        attribute maximumOperatingTemperature: Temperature_C = 125.0;
        attribute designLife: Time_h = 35040.0;
        attribute expectedProtectedVolumeHumidity: Percent = 45.0;

        part gasket: MoldedSiliconeRubberGasket;
        part housing: RigidHousing;
        part cover: CoverPlate;
        part limiters: CompressionLimiter;
        part fasteners: FastenerSet;
        part primer: SiliconePrimerFilm;
        part monitor: SealConditionMonitor;

        item protectedPayload: ProtectedPayload;

        port externalEnvironment: EnvironmentalExposurePort;
        port protectedVolume: ProtectedVolumePort;
        port clampInterface: MechanicalCompressionPort;
        port heatInterface: ThermalPort;

        connect fasteners.preloadOutput to cover.clampInput;
        connect cover.clampInput to limiters.clampPath;
        connect limiters.clampPath to gasket.compressionPort;
        connect gasket.lowerContact to housing.grooveContact;
        connect gasket.upperContact to cover.flangeContact;
        connect primer.bondedInterface to gasket.lowerContact;
        connect housing.externalExposure to externalEnvironment;
        connect gasket.environmentSide to externalEnvironment;
        connect gasket.protectedSide to protectedVolume;
        connect housing.internalVolume to protectedVolume;
        connect monitor.protectedVolumeInput to protectedVolume;
        connect gasket.thermalPort to heatInterface;
        connect housing.thermalPort to heatInterface;
        connect cover.thermalPort to heatInterface;
        connect monitor.thermalInput to heatInterface;

        interface compressionPath: CompressionTransferInterface connect fasteners.preloadOutput to gasket.compressionPort;
        interface lowerSealPath: SealingInterface connect gasket.lowerContact to housing.grooveContact;
        interface upperSealPath: SealingInterface connect gasket.upperContact to cover.flangeContact;
        interface barrierPath: EnvironmentalBarrierInterface connect gasket.environmentSide to gasket.protectedSide;

        constraint compressionDesignCheck: CompressionWithinRecommendedRange {
            in compression = installedCompression;
            in minimumCompression = gasket.minimumRecommendedCompression;
            in maximumCompression = gasket.maximumRecommendedCompression;
        }

        constraint leakageDesignCheck: LeakageBelowLimit {
            in leakage = nominalLeakageRate;
            in allowedLeakage = allowedLeakageRate;
        }

        constraint temperatureDesignCheckLow: TemperatureWithinSiliconeCapability {
            in operatingTemperature = minimumOperatingTemperature;
            in minimumTemperature = gasket.compound.minimumServiceTemperature;
            in maximumTemperature = gasket.compound.maximumServiceTemperature;
        }

        constraint temperatureDesignCheckHigh: TemperatureWithinSiliconeCapability {
            in operatingTemperature = maximumOperatingTemperature;
            in minimumTemperature = gasket.compound.minimumServiceTemperature;
            in maximumTemperature = gasket.compound.maximumServiceTemperature;
        }

        constraint materialBasisCheck: SiliconeRubberDominantMaterial {
            in siliconeRubberMassFraction = gasket.compound.siliconeRubberMassFraction;
        }

        action providePrimaryFunction: ProvideFlexibleEnvironmentalSeal;
        action installSeal: InstallSiliconeRubberSeal;
        action evaluateCondition: EvaluateSealHealth;

        exhibit state lifecycle: SiliconeSealLifecycle;

        requirement primaryFunctionReq: PrimaryFunctionRequirement {
            subject sealSystem = this;
        }

        requirement materialBasisReq: SiliconeRubberBasisRequirement {
            subject sealSystem = this;
        }

        requirement compressionReq: CompressionRequirement {
            subject sealSystem = this;
        }

        requirement temperatureReq: TemperatureRequirement {
            subject sealSystem = this;
        }

        requirement leakageReq: LeakageRequirement {
            subject sealSystem = this;
        }

        satisfy primaryFunctionReq by gasket;
        satisfy primaryFunctionReq by housing;
        satisfy primaryFunctionReq by cover;
        satisfy materialBasisReq by gasket;
        satisfy compressionReq by fasteners;
        satisfy compressionReq by limiters;
        satisfy temperatureReq by gasket;
        satisfy leakageReq by gasket;
    }

    part siliconeRubberSealSystem: SiliconeRubberEnvironmentalSealSystem {
        attribute systemName = "Silicone Rubber Based Flexible Environmental Barrier";
        attribute allowedLeakageRate = 0.05;
        attribute nominalLeakageRate = 0.02;
        attribute installedCompression = 22.5;
        attribute minimumOperatingTemperature = -40.0;
        attribute maximumOperatingTemperature = 125.0;
    }
}
