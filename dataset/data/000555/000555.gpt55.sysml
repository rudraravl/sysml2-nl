package BootBasedProtectiveFootwearModel {
    import ScalarValues::*;

    attribute def Length_mm :> Real {
        doc "Length measured in millimeters.";
        attribute unit: String = "mm";
    }

    attribute def Area_cm2 :> Real {
        doc "Area measured in square centimeters.";
        attribute unit: String = "cm^2";
    }

    attribute def Mass_kg :> Real {
        doc "Mass measured in kilograms.";
        attribute unit: String = "kg";
    }

    attribute def Force_N :> Real {
        doc "Force measured in newtons.";
        attribute unit: String = "N";
    }

    attribute def Pressure_kPa :> Real {
        doc "Pressure measured in kilopascals.";
        attribute unit: String = "kPa";
    }

    attribute def Energy_J :> Real {
        doc "Energy measured in joules.";
        attribute unit: String = "J";
    }

    attribute def Temperature_C :> Real {
        doc "Temperature measured in degrees Celsius.";
        attribute unit: String = "degC";
    }

    attribute def Time_s :> Real {
        doc "Time measured in seconds.";
        attribute unit: String = "s";
    }

    attribute def Speed_mps :> Real {
        doc "Speed measured in meters per second.";
        attribute unit: String = "m/s";
    }

    attribute def Coefficient :> Real {
        doc "Dimensionless coefficient.";
        attribute unit: String = "1";
    }

    attribute def Percent :> Real {
        doc "Percentage value.";
        attribute unit: String = "%";
    }

    enum def BootUseMode {
        enum unworn;
        enum donning;
        enum fitted;
        enum walking;
        enum climbing;
        enum standing;
        enum removing;
        enum maintenance;
    }

    enum def TerrainClass {
        enum dryFlat;
        enum wetFlat;
        enum gravel;
        enum mud;
        enum snow;
        enum oilContaminated;
        enum ladderRung;
        enum rocky;
    }

    enum def ClosureState {
        enum open;
        enum partiallyClosed;
        enum fullyClosed;
        enum locked;
    }

    enum def WearCondition {
        enum new;
        enum serviceable;
        enum worn;
        enum replaceSoon;
        enum unsafe;
    }

    item def FootLoad {
        attribute verticalLoad: Force_N;
        attribute foreAftShearLoad: Force_N;
        attribute lateralShearLoad: Force_N;
        attribute contactPressure: Pressure_kPa;
        attribute stanceDuration: Time_s;
    }

    item def SupportReaction {
        attribute archSupportForce: Force_N;
        attribute heelCupReaction: Force_N;
        attribute ankleSupportMomentEquivalent: Force_N;
        attribute residualPressure: Pressure_kPa;
    }

    item def TerrainContact {
        attribute terrain: TerrainClass;
        attribute normalReaction: Force_N;
        attribute availableFrictionCoefficient: Coefficient;
        attribute surfaceTemperature: Temperature_C;
        attribute waterDepth: Length_mm;
        attribute penetrationDepth: Length_mm;
    }

    item def TractionResponse {
        attribute generatedFrictionCoefficient: Coefficient;
        attribute slipSpeed: Speed_mps;
        attribute treadPenetration: Length_mm;
        attribute stableContact: Boolean;
    }

    item def ImpactEvent {
        attribute incomingEnergy: Energy_J;
        attribute peakHeelForce: Force_N;
        attribute impactDuration: Time_s;
    }

    item def ImpactMitigation {
        attribute absorbedEnergy: Energy_J;
        attribute transmittedEnergy: Energy_J;
        attribute peakTransmittedForce: Force_N;
    }

    item def MoistureIntrusion {
        attribute waterPressure: Pressure_kPa;
        attribute waterDepth: Length_mm;
        attribute exposureDuration: Time_s;
    }

    item def InternalComfortCondition {
        attribute internalTemperature: Temperature_C;
        attribute humidityPercent: Percent;
        attribute pressureHotSpot: Pressure_kPa;
        attribute perceivedFitStable: Boolean;
    }

    item def BootHealthStatus {
        attribute outsoleWearPercent: Percent;
        attribute closureIntegrityPercent: Percent;
        attribute waterproofIntegrityPercent: Percent;
        attribute linerCompressionPercent: Percent;
        attribute condition: WearCondition;
    }

    item def DonningCommand {
        attribute requestedSize: Length_mm;
        attribute closureTensionTarget: Force_N;
    }

    item def RemovalCommand {
        attribute releaseClosure: Boolean;
    }

    item def ProtectedStep {
        attribute footSupported: Boolean;
        attribute slipPrevented: Boolean;
        attribute impactReduced: Boolean;
        attribute waterRejected: Boolean;
        attribute comfortMaintained: Boolean;
    }

    port def FootInterfacePort {
        in item loadFromFoot: FootLoad;
        out item reactionToFoot: SupportReaction;
        out item comfort: InternalComfortCondition;
    }

    port def GroundInterfacePort {
        in item terrainContact: TerrainContact;
        out item traction: TractionResponse;
        in item impact: ImpactEvent;
        out item impactMitigation: ImpactMitigation;
    }

    port def EnvironmentInterfacePort {
        in item moisture: MoistureIntrusion;
        out item healthStatus: BootHealthStatus;
    }

    port def UserControlPort {
        in item donning: DonningCommand;
        in item removal: RemovalCommand;
        out item healthStatus: BootHealthStatus;
    }

    port def InternalMechanicalPort {
        in item load: FootLoad;
        out item reaction: SupportReaction;
    }

    port def InternalImpactPort {
        in item impact: ImpactEvent;
        out item mitigation: ImpactMitigation;
    }

    port def InternalTractionPort {
        in item terrain: TerrainContact;
        out item response: TractionResponse;
    }

    port def InternalMoisturePort {
        in item intrusion: MoistureIntrusion;
        out item status: BootHealthStatus;
    }

    action def ReceiveFootLoad {
        in item footLoad: FootLoad;
        out item distributedLoad: FootLoad;
        doc "Receives load from the wearer's foot and distributes it over the insole and upper interfaces.";
    }

    action def CushionImpact {
        in item impact: ImpactEvent;
        out item mitigation: ImpactMitigation;
        doc "Absorbs heel and forefoot impact energy through sole and midsole compliance.";
    }

    action def StabilizeFootAndAnkle {
        in item distributedLoad: FootLoad;
        out item support: SupportReaction;
        doc "Provides arch, heel, and ankle support to keep the foot aligned during standing and gait.";
    }

    action def GenerateTraction {
        in item terrain: TerrainContact;
        out item traction: TractionResponse;
        doc "Uses tread geometry and outsole material friction to create stable ground contact.";
    }

    action def RejectMoisture {
        in item intrusion: MoistureIntrusion;
        out item status: BootHealthStatus;
        doc "Limits water entry through upper material, seams, gusseted tongue, and sole bond.";
    }

    action def MaintainComfort {
        in item support: SupportReaction;
        out item comfort: InternalComfortCondition;
        doc "Maintains acceptable internal pressure and thermal comfort while the boot is worn.";
    }

    action def AssessBootHealth {
        in item traction: TractionResponse;
        in item status: BootHealthStatus;
        out item reportedStatus: BootHealthStatus;
        doc "Combines wear, closure, waterproofing, and traction indicators into a usable condition status.";
    }

    action def ProvideProtectedMobility {
        in item footLoad: FootLoad;
        in item terrain: TerrainContact;
        in item impact: ImpactEvent;
        in item intrusion: MoistureIntrusion;
        out item protectedStep: ProtectedStep;
        action receive: ReceiveFootLoad;
        action cushion: CushionImpact;
        action stabilize: StabilizeFootAndAnkle;
        action grip: GenerateTraction;
        action seal: RejectMoisture;
        action comfort: MaintainComfort;
        action assess: AssessBootHealth;
        flow footLoad to receive.footLoad;
        flow receive.distributedLoad to stabilize.distributedLoad;
        flow impact to cushion.impact;
        flow terrain to grip.terrain;
        flow intrusion to seal.intrusion;
        flow stabilize.support to comfort.support;
        flow grip.traction to assess.traction;
        flow seal.status to assess.status;
        doc "Primary high-level behavior: protect, support, and stabilize the wearer's foot while enabling safe contact with the ground.";
    }

    action def OpenClosure {
        out attribute closureState: ClosureState = ClosureState::open;
    }

    action def TightenClosure {
        in item command: DonningCommand;
        out attribute closureState: ClosureState = ClosureState::locked;
    }

    action def ReleaseClosure {
        in item command: RemovalCommand;
        out attribute closureState: ClosureState = ClosureState::open;
    }

    action def InspectForServiceability {
        in item health: BootHealthStatus;
        out item reportedHealth: BootHealthStatus;
    }

    state def BootOperationalStateMachine {
        entry action InspectForServiceability;
        state unworn;
        state donning {
            entry action OpenClosure;
            do action TightenClosure;
        }
        state fitted;
        state standing {
            do action StabilizeFootAndAnkle;
        }
        state walking {
            do action ProvideProtectedMobility;
        }
        state climbing {
            do action GenerateTraction;
            do action StabilizeFootAndAnkle;
        }
        state removing {
            entry action ReleaseClosure;
        }
        state maintenance {
            do action InspectForServiceability;
        }
        transition first unworn;
        transition unworn then donning accept DonningCommand;
        transition donning then fitted;
        transition fitted then standing;
        transition standing then walking;
        transition walking then standing;
        transition standing then climbing;
        transition climbing then standing;
        transition fitted then removing accept RemovalCommand;
        transition standing then removing accept RemovalCommand;
        transition removing then unworn;
        transition unworn then maintenance;
        transition maintenance then unworn;
    }

    constraint def MaximumTransmittedImpactConstraint {
        in attribute transmittedForce: Force_N;
        in attribute allowableForce: Force_N;
        transmittedForce <= allowableForce;
    }

    constraint def MinimumTractionConstraint {
        in attribute generatedFriction: Coefficient;
        in attribute requiredFriction: Coefficient;
        generatedFriction >= requiredFriction;
    }

    constraint def WaterproofConstraint {
        in attribute waterDepth: Length_mm;
        in attribute ratedDepth: Length_mm;
        in attribute exposure: Time_s;
        in attribute ratedExposure: Time_s;
        waterDepth <= ratedDepth and exposure <= ratedExposure;
    }

    constraint def FitPressureConstraint {
        in attribute internalPressure: Pressure_kPa;
        in attribute maxAllowedPressure: Pressure_kPa;
        internalPressure <= maxAllowedPressure;
    }

    constraint def BootMassConstraint {
        in attribute bootMass: Mass_kg;
        in attribute maxBootMass: Mass_kg;
        bootMass <= maxBootMass;
    }

    part def ToeCap {
        attribute materialName: String = "composite reinforced polymer";
        attribute protectedToeWidth: Length_mm = 108.0;
        attribute protectedToeHeight: Length_mm = 48.0;
        attribute mass: Mass_kg = 0.18;
        attribute crushResistance: Force_N = 15000.0;
        port footSide: InternalMechanicalPort;
        port shellSide: InternalMechanicalPort;
    }

    part def UpperAssembly {
        attribute materialName: String = "full-grain treated leather with abrasion textile panels";
        attribute shaftHeight: Length_mm = 210.0;
        attribute flexZoneLength: Length_mm = 82.0;
        attribute waterVaporTransmissionArea: Area_cm2 = 420.0;
        attribute abrasionResistanceCycles: Real = 75000.0;
        attribute mass: Mass_kg = 0.54;
        port interiorSide: InternalMechanicalPort;
        port exteriorMoistureSide: InternalMoisturePort;
    }

    part def GussetedTongue {
        attribute materialName: String = "padded waterproof textile";
        attribute gussetHeight: Length_mm = 165.0;
        attribute paddingThickness: Length_mm = 8.0;
        attribute mass: Mass_kg = 0.07;
        port moistureBarrier: InternalMoisturePort;
        port footPressureSide: InternalMechanicalPort;
    }

    part def ClosureSystem {
        attribute laceMaterialName: String = "aramid fiber lace";
        attribute eyeletMaterialName: String = "corrosion resistant steel";
        attribute maximumTension: Force_N = 420.0;
        attribute nominalTension: Force_N = 160.0;
        attribute closureState: ClosureState = ClosureState::open;
        attribute mass: Mass_kg = 0.11;
        port userControl: UserControlPort;
        port upperLoadPath: InternalMechanicalPort;
    }

    part def Liner {
        attribute materialName: String = "moisture wicking antimicrobial fabric";
        attribute thickness: Length_mm = 3.5;
        attribute comfortTemperatureMin: Temperature_C = -10.0;
        attribute comfortTemperatureMax: Temperature_C = 35.0;
        attribute mass: Mass_kg = 0.12;
        port footSide: FootInterfacePort;
        port shellSide: InternalMechanicalPort;
        port comfortSide: FootInterfacePort;
    }

    part def Insole {
        attribute materialName: String = "contoured polyurethane foam";
        attribute archHeight: Length_mm = 24.0;
        attribute heelCupDepth: Length_mm = 16.0;
        attribute maximumPressure: Pressure_kPa = 85.0;
        attribute mass: Mass_kg = 0.09;
        port footSide: FootInterfacePort;
        port midsoleSide: InternalMechanicalPort;
    }

    part def Midsole {
        attribute materialName: String = "dual-density ethylene vinyl acetate";
        attribute heelThickness: Length_mm = 32.0;
        attribute forefootThickness: Length_mm = 18.0;
        attribute absorbedEnergyPerStep: Energy_J = 22.0;
        attribute maximumTransmittedImpactForce: Force_N = 3200.0;
        attribute mass: Mass_kg = 0.26;
        port upperSide: InternalMechanicalPort;
        port groundSideImpact: InternalImpactPort;
    }

    part def Shank {
        attribute materialName: String = "glass fiber reinforced nylon";
        attribute length: Length_mm = 142.0;
        attribute torsionalStiffnessEquivalent: Force_N = 900.0;
        attribute mass: Mass_kg = 0.08;
        port heelSide: InternalMechanicalPort;
        port forefootSide: InternalMechanicalPort;
    }

    part def Outsole {
        attribute materialName: String = "oil-resistant nitrile rubber";
        attribute treadDepth: Length_mm = 6.5;
        attribute contactArea: Area_cm2 = 185.0;
        attribute dryFrictionCoefficient: Coefficient = 0.82;
        attribute wetFrictionCoefficient: Coefficient = 0.58;
        attribute oilFrictionCoefficient: Coefficient = 0.42;
        attribute punctureResistance: Force_N = 1200.0;
        attribute mass: Mass_kg = 0.36;
        port midsoleImpactSide: InternalImpactPort;
        port groundSide: GroundInterfacePort;
        port tractionSide: InternalTractionPort;
    }

    part def HeelCounter {
        attribute materialName: String = "thermoplastic heel stabilizer";
        attribute height: Length_mm = 72.0;
        attribute lateralSupportForce: Force_N = 650.0;
        attribute mass: Mass_kg = 0.10;
        port linerSide: InternalMechanicalPort;
        port upperSide: InternalMechanicalPort;
    }

    part def WaterproofMembrane {
        attribute materialName: String = "microporous polyurethane membrane";
        attribute ratedWaterDepth: Length_mm = 100.0;
        attribute ratedExposureDuration: Time_s = 1800.0;
        attribute hydrostaticResistance: Pressure_kPa = 25.0;
        attribute mass: Mass_kg = 0.06;
        port externalMoisture: InternalMoisturePort;
        port internalStatus: InternalMoisturePort;
    }

    part def WearIndicator {
        attribute minimumSafeTreadDepth: Length_mm = 2.0;
        attribute measuredTreadDepth: Length_mm = 6.5;
        attribute outsoleWearPercent: Percent = 0.0;
        attribute closureIntegrityPercent: Percent = 100.0;
        attribute waterproofIntegrityPercent: Percent = 100.0;
        attribute linerCompressionPercent: Percent = 0.0;
        port sensedBootCondition: EnvironmentInterfacePort;
    }

    part def ProtectiveBootSystem {
        doc "A boot-based system whose primary function is to protect, support, stabilize, and comfort a wearer's foot while transferring walking and standing loads to the ground with adequate traction.";
        attribute modelName: String = "High Support Protective Boot";
        attribute nominalSizeMondopoint: Length_mm = 275.0;
        attribute totalMass: Mass_kg = 1.77;
        attribute shaftHeight: Length_mm = 210.0;
        attribute primaryFunctionProvided: Boolean = true;
        attribute operationalMode: BootUseMode = BootUseMode::unworn;
        attribute allowablePeakTransmittedImpactForce: Force_N = 3500.0;
        attribute minimumRequiredFrictionCoefficient: Coefficient = 0.40;
        attribute maximumInternalPressure: Pressure_kPa = 95.0;
        attribute maximumAllowedMass: Mass_kg = 2.20;
        attribute ratedWaterDepth: Length_mm = 100.0;
        attribute ratedWaterExposureDuration: Time_s = 1800.0;

        port footInterface: FootInterfacePort;
        port groundInterface: GroundInterfacePort;
        port environmentInterface: EnvironmentInterfacePort;
        port userInterface: UserControlPort;

        part toeCap: ToeCap;
        part upper: UpperAssembly;
        part tongue: GussetedTongue;
        part closure: ClosureSystem;
        part liner: Liner;
        part insole: Insole;
        part midsole: Midsole;
        part shank: Shank;
        part outsole: Outsole;
        part heelCounter: HeelCounter;
        part membrane: WaterproofMembrane;
        part wearIndicator: WearIndicator;

        perform action primaryFunction: ProvideProtectedMobility;
        exhibit state usageState: BootOperationalStateMachine;

        connect footInterface to liner.footSide;
        connect liner.shellSide to insole.footSide;
        connect insole.midsoleSide to midsole.upperSide;
        connect midsole.groundSideImpact to outsole.midsoleImpactSide;
        connect outsole.groundSide to groundInterface;
        connect outsole.tractionSide to groundInterface;
        connect upper.interiorSide to liner.shellSide;
        connect toeCap.footSide to liner.shellSide;
        connect toeCap.shellSide to upper.interiorSide;
        connect heelCounter.linerSide to liner.shellSide;
        connect heelCounter.upperSide to upper.interiorSide;
        connect closure.userControl to userInterface;
        connect closure.upperLoadPath to upper.interiorSide;
        connect tongue.footPressureSide to liner.shellSide;
        connect tongue.moistureBarrier to membrane.internalStatus;
        connect upper.exteriorMoistureSide to membrane.externalMoisture;
        connect membrane.internalStatus to environmentInterface;
        connect wearIndicator.sensedBootCondition to environmentInterface;
        connect shank.heelSide to midsole.upperSide;
        connect shank.forefootSide to insole.midsoleSide;
    }

    requirement def PrimaryFunctionRequirement {
        doc "The boot shall provide a high-level primary function of protecting and supporting the wearer's foot while enabling stable mobility over expected terrain.";
        subject boot: ProtectiveBootSystem;
        require constraint {
            boot.primaryFunctionProvided == true
        }
    }

    requirement def ImpactProtectionRequirement {
        doc "The boot shall limit peak transmitted impact force during a normal heel strike.";
        subject boot: ProtectiveBootSystem;
        require constraint MaximumTransmittedImpactConstraint {
            transmittedForce = boot.midsole.maximumTransmittedImpactForce;
            allowableForce = boot.allowablePeakTransmittedImpactForce;
        }
    }

    requirement def TractionRequirement {
        doc "The outsole shall provide sufficient friction on wet flat terrain for controlled walking.";
        subject boot: ProtectiveBootSystem;
        require constraint MinimumTractionConstraint {
            generatedFriction = boot.outsole.wetFrictionCoefficient;
            requiredFriction = boot.minimumRequiredFrictionCoefficient;
        }
    }

    requirement def WaterproofRequirement {
        doc "The boot shall resist water intrusion at the rated depth for the rated exposure duration.";
        subject boot: ProtectiveBootSystem;
        require constraint WaterproofConstraint {
            waterDepth = boot.ratedWaterDepth;
            ratedDepth = boot.membrane.ratedWaterDepth;
            exposure = boot.ratedWaterExposureDuration;
            ratedExposure = boot.membrane.ratedExposureDuration;
        }
    }

    requirement def ComfortPressureRequirement {
        doc "The insole and liner shall limit internal pressure hotspots to preserve wearer comfort.";
        subject boot: ProtectiveBootSystem;
        require constraint FitPressureConstraint {
            internalPressure = boot.insole.maximumPressure;
            maxAllowedPressure = boot.maximumInternalPressure;
        }
    }

    requirement def MassRequirement {
        doc "The complete boot shall remain light enough for repeated walking and standing use.";
        subject boot: ProtectiveBootSystem;
        require constraint BootMassConstraint {
            bootMass = boot.totalMass;
            maxBootMass = boot.maximumAllowedMass;
        }
    }

    requirement def ToeProtectionRequirement {
        doc "The toe cap shall resist crushing loads associated with common dropped-object hazards.";
        subject boot: ProtectiveBootSystem;
        require constraint {
            boot.toeCap.crushResistance >= 15000.0
        }
    }

    requirement def ClosureRetentionRequirement {
        doc "The closure system shall maintain a locked fitted state under nominal walking loads.";
        subject boot: ProtectiveBootSystem;
        require constraint {
            boot.closure.maximumTension >= 2.0 * boot.closure.nominalTension
        }
    }

    requirement def ServiceabilityRequirement {
        doc "The boot shall indicate serviceability based on tread depth, closure integrity, waterproof integrity, and liner compression.";
        subject boot: ProtectiveBootSystem;
        require constraint {
            boot.wearIndicator.measuredTreadDepth >= boot.wearIndicator.minimumSafeTreadDepth and
            boot.wearIndicator.closureIntegrityPercent >= 80.0 and
            boot.wearIndicator.waterproofIntegrityPercent >= 80.0 and
            boot.wearIndicator.linerCompressionPercent <= 60.0
        }
    }

    satisfy PrimaryFunctionRequirement by ProtectiveBootSystem::primaryFunction;
    satisfy ImpactProtectionRequirement by ProtectiveBootSystem::midsole;
    satisfy TractionRequirement by ProtectiveBootSystem::outsole;
    satisfy WaterproofRequirement by ProtectiveBootSystem::membrane;
    satisfy ComfortPressureRequirement by ProtectiveBootSystem::insole;
    satisfy MassRequirement by ProtectiveBootSystem;
    satisfy ToeProtectionRequirement by ProtectiveBootSystem::toeCap;
    satisfy ClosureRetentionRequirement by ProtectiveBootSystem::closure;
    satisfy ServiceabilityRequirement by ProtectiveBootSystem::wearIndicator;

    part fieldBoot: ProtectiveBootSystem {
        attribute modelName = "Field Protective Boot";
        attribute nominalSizeMondopoint = 275.0;
        attribute totalMass = 1.77;
        attribute primaryFunctionProvided = true;
        attribute operationalMode = BootUseMode::fitted;
    }
}
