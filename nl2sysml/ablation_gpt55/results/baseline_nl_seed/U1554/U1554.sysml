package ExtraVehicularActivityMissionModel {
    import ScalarValues::*;

    attribute def MassValue :> Real {
        attribute unit: String = "kg";
    }

    attribute def PressureValue :> Real {
        attribute unit: String = "kPa";
    }

    attribute def TemperatureValue :> Real {
        attribute unit: String = "degC";
    }

    attribute def DurationValue :> Real {
        attribute unit: String = "min";
    }

    attribute def FlowRateValue :> Real {
        attribute unit: String = "L/min";
    }

    attribute def EnergyValue :> Real {
        attribute unit: String = "Wh";
    }

    attribute def PowerValue :> Real {
        attribute unit: String = "W";
    }

    attribute def DistanceValue :> Real {
        attribute unit: String = "m";
    }

    attribute def VelocityValue :> Real {
        attribute unit: String = "m/s";
    }

    attribute def DataRateValue :> Real {
        attribute unit: String = "kb/s";
    }

    attribute def PercentValue :> Real {
        attribute unit: String = "percent";
    }

    attribute def RadiationDoseValue :> Real {
        attribute unit: String = "mSv";
    }

    item def Oxygen {
        attribute storagePressure: PressureValue;
        attribute availableMass: MassValue;
        attribute purity: PercentValue;
    }

    item def CarbonDioxide {
        attribute partialPressure: PressureValue;
        attribute removedMass: MassValue;
    }

    item def CoolingWater {
        attribute massFlow: FlowRateValue;
        attribute inletTemperature: TemperatureValue;
        attribute outletTemperature: TemperatureValue;
    }

    item def ElectricPower {
        attribute deliveredPower: PowerValue;
        attribute availableEnergy: EnergyValue;
    }

    item def VoiceData {
        attribute dataRate: DataRateValue;
        attribute latency: DurationValue;
    }

    item def TelemetryData {
        attribute suitPressure: PressureValue;
        attribute oxygenRemaining: PercentValue;
        attribute carbonDioxideLevel: PressureValue;
        attribute batteryRemaining: PercentValue;
        attribute coolingLoopTemperature: TemperatureValue;
        attribute dataRate: DataRateValue;
    }

    item def MissionCommand {
        attribute commandCode: String;
        attribute priority: Integer;
    }

    item def BiometricData {
        attribute heartRate: Real;
        attribute coreTemperature: TemperatureValue;
        attribute metabolicHeat: PowerValue;
    }

    item def NavigationData {
        attribute rangeFromAirlock: DistanceValue;
        attribute relativeVelocity: VelocityValue;
        attribute locationQuality: PercentValue;
    }

    item def ToolCommand {
        attribute commandName: String;
        attribute torqueRequest: Real;
    }

    item def ToolStatus {
        attribute ready: Boolean;
        attribute consumedEnergy: EnergyValue;
    }

    item def SampleMaterial {
        attribute sampleMass: MassValue;
        attribute containmentTemperature: TemperatureValue;
    }

    item def SuitStatus {
        attribute sealed: Boolean;
        attribute pressurized: Boolean;
        attribute cautionActive: Boolean;
        attribute warningActive: Boolean;
    }

    item def CrewMotion {
        attribute jointDemand: PercentValue;
        attribute handControllerDemand: PercentValue;
    }

    item def MissionPlan {
        attribute plannedDuration: DurationValue;
        attribute plannedRange: DistanceValue;
        attribute plannedSampleMass: MassValue;
    }

    item def MissionReport {
        attribute actualDuration: DurationValue;
        attribute maximumRange: DistanceValue;
        attribute collectedSampleMass: MassValue;
        attribute anomalies: Integer;
    }

    port def CrewSuitInterfacePort {
        out item crewMotion: CrewMotion;
        out item biometricData: BiometricData;
        in item suitStatus: SuitStatus;
    }

    port def GarmentCrewInterfacePort {
        in item crewMotion: CrewMotion;
        in item biometricData: BiometricData;
        out item suitStatus: SuitStatus;
    }

    port def SuitLifeSupportPort {
        in item oxygen: Oxygen;
        out item carbonDioxide: CarbonDioxide;
        in item coolingWaterSupply: CoolingWater;
        out item coolingWaterReturn: CoolingWater;
        in item power: ElectricPower;
    }

    port def LifeSupportSuitPort {
        out item oxygen: Oxygen;
        in item carbonDioxide: CarbonDioxide;
        out item coolingWaterSupply: CoolingWater;
        in item coolingWaterReturn: CoolingWater;
        out item power: ElectricPower;
    }

    port def SuitCommunicationPort {
        out item voiceData: VoiceData;
        out item telemetryData: TelemetryData;
        in item missionCommand: MissionCommand;
    }

    port def CommunicationSuitPort {
        in item voiceData: VoiceData;
        in item telemetryData: TelemetryData;
        out item missionCommand: MissionCommand;
    }

    port def GatewayCommunicationPort {
        in item voiceData: VoiceData;
        in item telemetryData: TelemetryData;
        out item missionCommand: MissionCommand;
    }

    port def SuitNavigationPort {
        out item biometricData: BiometricData;
        in item navigationData: NavigationData;
    }

    port def NavigationSuitPort {
        in item biometricData: BiometricData;
        out item navigationData: NavigationData;
    }

    port def GatewayNavigationPort {
        in item navigationData: NavigationData;
    }

    port def ToolUserPort {
        out item toolCommand: ToolCommand;
        in item toolStatus: ToolStatus;
        in item sampleMaterial: SampleMaterial;
    }

    port def ToolEquipmentPort {
        in item toolCommand: ToolCommand;
        out item toolStatus: ToolStatus;
        out item sampleMaterial: SampleMaterial;
    }

    port def AirlockEVAPort {
        out item oxygenPurge: Oxygen;
        in item suitStatus: SuitStatus;
        out item missionCommand: MissionCommand;
    }

    port def SuitAirlockPort {
        in item oxygenPurge: Oxygen;
        out item suitStatus: SuitStatus;
        in item missionCommand: MissionCommand;
    }

    port def TetherSuitPort {
        in item navigationData: NavigationData;
    }

    port def SuitTetherPort {
        out item navigationData: NavigationData;
    }

    part def CrewMember {
        attribute bodyMass: MassValue = 82.0;
        attribute nominalMetabolicHeat: PowerValue = 350.0;
        attribute peakMetabolicHeat: PowerValue = 900.0;
        attribute nominalCoreTemperature: TemperatureValue = 37.0;
        port suitPort: CrewSuitInterfacePort;
    }

    part def PressureGarment {
        attribute garmentMass: MassValue = 47.0;
        attribute nominalPressure: PressureValue = 29.6;
        attribute minimumSafePressure: PressureValue = 27.5;
        attribute maximumLeakRate: FlowRateValue = 0.15;
        attribute mobilityEfficiency: PercentValue = 72.0;
        attribute radiationShieldingDoseLimit: RadiationDoseValue = 25.0;
        port crewPort: GarmentCrewInterfacePort;
        port lifeSupportPort: SuitLifeSupportPort;
        port commPort: SuitCommunicationPort;
        port navPort: SuitNavigationPort;
        port toolPort: ToolUserPort;
        port airlockPort: SuitAirlockPort;
        port tetherPort: SuitTetherPort;
    }

    part def OxygenTank {
        attribute storedOxygenMass: MassValue = 1.2;
        attribute storagePressure: PressureValue = 20700.0;
        attribute usableFraction: PercentValue = 95.0;
    }

    part def CarbonDioxideScrubber {
        attribute scrubberMass: MassValue = 2.8;
        attribute maximumRemovalRate: FlowRateValue = 4.0;
        attribute cartridgeDuration: DurationValue = 540.0;
    }

    part def BatteryAssembly {
        attribute batteryMass: MassValue = 5.6;
        attribute capacity: EnergyValue = 1600.0;
        attribute nominalOutputPower: PowerValue = 260.0;
        attribute peakOutputPower: PowerValue = 600.0;
    }

    part def ThermalControlLoop {
        attribute coolingWaterMass: MassValue = 4.5;
        attribute heatRejectionCapacity: PowerValue = 950.0;
        attribute nominalSupplyTemperature: TemperatureValue = 10.0;
        attribute maximumReturnTemperature: TemperatureValue = 32.0;
    }

    part def PortableLifeSupportSubsystem {
        attribute plssMass: MassValue = 38.0;
        attribute nominalDuration: DurationValue = 480.0;
        attribute contingencyDuration: DurationValue = 30.0;
        attribute oxygenDeliveryRate: FlowRateValue = 1.8;
        attribute carbonDioxideLimit: PressureValue = 1.0;
        part primaryOxygenTank: OxygenTank;
        part secondaryOxygenTank: OxygenTank;
        part carbonDioxideScrubber: CarbonDioxideScrubber;
        part battery: BatteryAssembly;
        part thermalControlLoop: ThermalControlLoop;
        port suitPort: LifeSupportSuitPort;
        port telemetryPort: SuitCommunicationPort;
    }

    part def CommunicationSubsystem {
        attribute radioMass: MassValue = 3.1;
        attribute nominalDataRate: DataRateValue = 512.0;
        attribute emergencyDataRate: DataRateValue = 64.0;
        attribute nominalRange: DistanceValue = 1500.0;
        port suitPort: CommunicationSuitPort;
        port plssPort: CommunicationSuitPort;
        port gatewayPort: SuitCommunicationPort;
    }

    part def NavigationSubsystem {
        attribute navigationMass: MassValue = 1.8;
        attribute locationAccuracy: DistanceValue = 0.5;
        attribute maximumTrackedRange: DistanceValue = 2000.0;
        port suitPort: NavigationSuitPort;
        port gatewayPort: SuitNavigationPort;
    }

    part def ToolCarrier {
        attribute carrierMass: MassValue = 7.5;
        attribute maximumToolPower: PowerValue = 200.0;
        attribute sampleCapacity: MassValue = 5.0;
        port toolPort: ToolEquipmentPort;
    }

    part def AirlockInterface {
        attribute prebreatheDuration: DurationValue = 60.0;
        attribute depressurizationDuration: DurationValue = 30.0;
        attribute repressurizationDuration: DurationValue = 20.0;
        attribute hatchDiameter: DistanceValue = 1.0;
        port evaPort: AirlockEVAPort;
    }

    part def SafetyTether {
        attribute tetherLength: DistanceValue = 30.0;
        attribute ratedLoad: Real = 2200.0;
        attribute reelMass: MassValue = 4.2;
        port suitPort: TetherSuitPort;
    }

    part def HabitatGateway {
        attribute gatewayMass: MassValue = 12.0;
        attribute relayRange: DistanceValue = 3000.0;
        attribute recordedTelemetryCapacity: EnergyValue = 240.0;
        port commPort: GatewayCommunicationPort;
        port navPort: GatewayNavigationPort;
    }

    action def PrepareSuitForEgress {
        in item missionPlan: MissionPlan;
        in item crewBiometrics: BiometricData;
        out item suitStatus: SuitStatus;
        attribute leakCheckPressure: PressureValue = 29.6;
        attribute requiredPrebreatheTime: DurationValue = 60.0;
    }

    action def DepressurizeAndOpenAirlock {
        in item suitStatus: SuitStatus;
        out item missionCommand: MissionCommand;
        attribute targetAirlockPressure: PressureValue = 0.7;
        attribute nominalDepressTime: DurationValue = 30.0;
    }

    action def TraverseToExternalWorksite {
        in item navigationData: NavigationData;
        out item telemetryData: TelemetryData;
        attribute maximumTraverseRange: DistanceValue = 1000.0;
        attribute maximumTraverseVelocity: VelocityValue = 0.25;
    }

    action def PerformExternalMaintenance {
        in item toolCommand: ToolCommand;
        out item toolStatus: ToolStatus;
        out item sampleMaterial: SampleMaterial;
        attribute maximumContinuousToolUse: DurationValue = 45.0;
    }

    action def ManageLifeSupport {
        in item biometricData: BiometricData;
        in item carbonDioxide: CarbonDioxide;
        out item oxygen: Oxygen;
        out item coolingWaterSupply: CoolingWater;
        out item telemetryData: TelemetryData;
        attribute targetSuitPressure: PressureValue = 29.6;
        attribute maximumCarbonDioxidePartialPressure: PressureValue = 1.0;
        attribute targetCoolingTemperature: TemperatureValue = 10.0;
    }

    action def RespondToContingency {
        in item telemetryData: TelemetryData;
        out item missionCommand: MissionCommand;
        attribute reserveDuration: DurationValue = 30.0;
        attribute emergencyReturnRange: DistanceValue = 1000.0;
    }

    action def IngressAndRepressurize {
        in item suitStatus: SuitStatus;
        out item missionReport: MissionReport;
        attribute nominalIngressTime: DurationValue = 15.0;
        attribute targetCabinPressure: PressureValue = 101.3;
    }

    action def ConductExtraVehicularActivity {
        in item missionPlan: MissionPlan;
        out item missionReport: MissionReport;
        out item returnedSamples: SampleMaterial;
        action prepareSuit: PrepareSuitForEgress;
        action depressurizeAirlock: DepressurizeAndOpenAirlock;
        action manageLifeSupport: ManageLifeSupport;
        action traverseToWorksite: TraverseToExternalWorksite;
        action performMaintenance: PerformExternalMaintenance;
        action contingencyResponse: RespondToContingency;
        action ingressAndRepressurize: IngressAndRepressurize;
    }

    state def EVAMissionLifecycle {
        state suitedCheckout;
        state airlockDepressurization;
        state egress;
        state externalOperations;
        state sampleAndToolOperations;
        state contingencyReturn;
        state ingress;
        state repressurization;
        state complete;

        transition startCheckout first suitedCheckout;
        transition checkoutToDepressurization first suitedCheckout then airlockDepressurization;
        transition depressurizationToEgress first airlockDepressurization then egress;
        transition egressToExternalOperations first egress then externalOperations;
        transition externalOperationsToSampleAndToolOperations first externalOperations then sampleAndToolOperations;
        transition nominalReturn first sampleAndToolOperations then ingress;
        transition externalOpsContingency first externalOperations then contingencyReturn;
        transition toolOpsContingency first sampleAndToolOperations then contingencyReturn;
        transition contingencyToIngress first contingencyReturn then ingress;
        transition ingressToRepressurization first ingress then repressurization;
        transition finishMission first repressurization then complete;
    }

    part def EVASystem {
        attribute missionIdentifier: String = "EVA-High-Level-Primary-Function";
        attribute maximumCrewOutsideDuration: DurationValue = 480.0;
        attribute requiredContingencyDuration: DurationValue = 30.0;
        attribute maximumOperatingRangeFromAirlock: DistanceValue = 1000.0;
        attribute primaryFunction: String = "Enable one crew member to safely operate outside a pressurized habitat by providing pressure, oxygen, carbon dioxide removal, thermal control, power, communications, navigation, tool support, and emergency return capability.";

        part crewMember: CrewMember;
        part pressureGarment: PressureGarment;
        part lifeSupport: PortableLifeSupportSubsystem;
        part communication: CommunicationSubsystem;
        part navigation: NavigationSubsystem;
        part toolCarrier: ToolCarrier;
        part airlockInterface: AirlockInterface;
        part safetyTether: SafetyTether;
        part habitatGateway: HabitatGateway;

        action evaBehavior: ConductExtraVehicularActivity;
        state missionLifecycle: EVAMissionLifecycle;

        connection crewToGarment connect crewMember.suitPort to pressureGarment.crewPort;
        connection garmentToLifeSupport connect pressureGarment.lifeSupportPort to lifeSupport.suitPort;
        connection garmentToCommunications connect pressureGarment.commPort to communication.suitPort;
        connection plssTelemetryToCommunications connect lifeSupport.telemetryPort to communication.plssPort;
        connection communicationToGateway connect communication.gatewayPort to habitatGateway.commPort;
        connection garmentToNavigation connect pressureGarment.navPort to navigation.suitPort;
        connection navigationToGateway connect navigation.gatewayPort to habitatGateway.navPort;
        connection garmentToTools connect pressureGarment.toolPort to toolCarrier.toolPort;
        connection airlockToGarment connect airlockInterface.evaPort to pressureGarment.airlockPort;
        connection tetherToGarment connect safetyTether.suitPort to pressureGarment.tetherPort;
    }

    requirement def PrimaryFunctionRequirement {
        subject evaSystem: EVASystem;
        attribute minimumOperationalDuration: DurationValue = 480.0;
        attribute minimumContingencyDuration: DurationValue = 30.0;
        attribute minimumOperatingRange: DistanceValue = 1000.0;
        require constraint {
            evaSystem.maximumCrewOutsideDuration >= minimumOperationalDuration
        }
        require constraint {
            evaSystem.requiredContingencyDuration >= minimumContingencyDuration
        }
        require constraint {
            evaSystem.maximumOperatingRangeFromAirlock >= minimumOperatingRange
        }
    }

    requirement def SuitPressureRequirement {
        subject garment: PressureGarment;
        attribute requiredMinimumPressure: PressureValue = 27.5;
        attribute requiredNominalPressure: PressureValue = 29.6;
        require constraint {
            garment.minimumSafePressure >= requiredMinimumPressure
        }
        require constraint {
            garment.nominalPressure >= requiredNominalPressure
        }
    }

    requirement def LifeSupportEnduranceRequirement {
        subject plss: PortableLifeSupportSubsystem;
        attribute requiredNominalDuration: DurationValue = 480.0;
        attribute requiredEmergencyReserve: DurationValue = 30.0;
        require constraint {
            plss.nominalDuration >= requiredNominalDuration
        }
        require constraint {
            plss.contingencyDuration >= requiredEmergencyReserve
        }
    }

    requirement def CommunicationRequirement {
        subject comm: CommunicationSubsystem;
        attribute minimumNominalDataRate: DataRateValue = 256.0;
        attribute minimumEmergencyDataRate: DataRateValue = 32.0;
        attribute requiredRelayRange: DistanceValue = 1500.0;
        require constraint {
            comm.nominalDataRate >= minimumNominalDataRate
        }
        require constraint {
            comm.emergencyDataRate >= minimumEmergencyDataRate
        }
        require constraint {
            comm.nominalRange >= requiredRelayRange
        }
    }

    requirement def NavigationRequirement {
        subject nav: NavigationSubsystem;
        attribute maximumPermittedLocationError: DistanceValue = 1.0;
        attribute requiredTrackedRange: DistanceValue = 1000.0;
        require constraint {
            nav.locationAccuracy <= maximumPermittedLocationError
        }
        require constraint {
            nav.maximumTrackedRange >= requiredTrackedRange
        }
    }

    part evaMissionSystem: EVASystem;

    requirement primaryFunctionRequirement: PrimaryFunctionRequirement {
        subject evaSystem = evaMissionSystem;
    }

    requirement suitPressureRequirement: SuitPressureRequirement {
        subject garment = evaMissionSystem.pressureGarment;
    }

    requirement lifeSupportEnduranceRequirement: LifeSupportEnduranceRequirement {
        subject plss = evaMissionSystem.lifeSupport;
    }

    requirement communicationRequirement: CommunicationRequirement {
        subject comm = evaMissionSystem.communication;
    }

    requirement navigationRequirement: NavigationRequirement {
        subject nav = evaMissionSystem.navigation;
    }
}
