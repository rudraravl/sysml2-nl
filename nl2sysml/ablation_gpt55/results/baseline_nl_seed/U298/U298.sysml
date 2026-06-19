package MedicalGasSupplyModel {
    import ScalarValues::*;

    enum def GasKind {
        enum oxygen;
        enum medicalAir;
        enum vacuum;
    }

    enum def SourceSelectionKind {
        enum primaryBank;
        enum reserveBank;
        enum emergencyInlet;
    }

    enum def AlarmSeverityKind {
        enum advisory;
        enum warning;
        enum critical;
    }

    attribute def Pressure :> Real {
        attribute unitSymbol: String = "kPa";
    }

    attribute def VolumetricFlowRate :> Real {
        attribute unitSymbol: String = "L/min";
    }

    attribute def Volume :> Real {
        attribute unitSymbol: String = "L";
    }

    attribute def Fraction :> Real {
        attribute unitSymbol: String = "1";
    }

    attribute def Temperature :> Real {
        attribute unitSymbol: String = "degC";
    }

    attribute def Voltage :> Real {
        attribute unitSymbol: String = "V";
    }

    attribute def ElectricCurrent :> Real {
        attribute unitSymbol: String = "A";
    }

    attribute def Duration :> Real {
        attribute unitSymbol: String = "s";
    }

    item def MedicalGas {
        attribute kind: GasKind;
        attribute oxygenFraction: Fraction;
        attribute waterVaporFraction: Fraction;
        attribute contaminantFraction: Fraction;
        attribute temperature: Temperature;
    }

    item def ElectricalPower {
        attribute voltage: Voltage;
        attribute current: ElectricCurrent;
    }

    item def AlarmMessage {
        attribute severity: AlarmSeverityKind;
        attribute messageText: String;
        attribute active: Boolean;
    }

    port def GasPort {
        inout item gas: MedicalGas;
        attribute pressure: Pressure;
        attribute flowRate: VolumetricFlowRate;
    }

    port def ElectricalPowerPort {
        in item power: ElectricalPower;
        attribute voltage: Voltage;
        attribute current: ElectricCurrent;
    }

    port def AlarmPort {
        out item alarm: AlarmMessage;
    }

    port def ControlPort {
        inout item command: AlarmMessage;
    }

    part def GasCylinderBank {
        attribute suppliedGasKind: GasKind = GasKind::oxygen;
        attribute cylinderCount: Integer = 12;
        attribute cylinderWaterVolume: Volume = 50.0;
        attribute nominalStoragePressure: Pressure = 13700.0;
        attribute minimumUsablePressure: Pressure = 700.0;
        attribute isolationValveOpen: Boolean = true;
        port outlet: GasPort;
    }

    part def EmergencySupplyInlet {
        attribute suppliedGasKind: GasKind = GasKind::oxygen;
        attribute connected: Boolean = false;
        attribute maximumInletPressure: Pressure = 14000.0;
        port inlet: GasPort;
        port outlet: GasPort;
    }

    part def SourceManifold {
        attribute selectedSource: SourceSelectionKind = SourceSelectionKind::primaryBank;
        attribute changeoverPressure: Pressure = 900.0;
        attribute reliefSetPressure: Pressure = 1700.0;
        attribute checkValvesHealthy: Boolean = true;
        port primaryInlet: GasPort;
        port reserveInlet: GasPort;
        port emergencyInlet: GasPort;
        port outlet: GasPort;
        port vent: GasPort;
    }

    part def PressureRegulator {
        attribute setPressure: Pressure = 800.0;
        attribute allowableDroop: Pressure = 50.0;
        attribute reliefSetPressure: Pressure = 1000.0;
        attribute regulatorHealthy: Boolean = true;
        port inlet: GasPort;
        port outlet: GasPort;
        port vent: GasPort;
    }

    part def LinePressureRegulator {
        attribute setPressure: Pressure = 400.0;
        attribute allowableOutletBandLow: Pressure = 380.0;
        attribute allowableOutletBandHigh: Pressure = 420.0;
        attribute regulatorHealthy: Boolean = true;
        port inlet: GasPort;
        port outlet: GasPort;
        port vent: GasPort;
    }

    part def GasFilter {
        attribute particulateRemovalRating: Fraction = 0.999;
        attribute maximumPressureDrop: Pressure = 25.0;
        attribute filterElementInstalled: Boolean = true;
        port inlet: GasPort;
        port outlet: GasPort;
    }

    part def PressureSensor {
        attribute measuredPressure: Pressure = 400.0;
        attribute lowAlarmThreshold: Pressure = 340.0;
        attribute highAlarmThreshold: Pressure = 480.0;
        attribute sensorHealthy: Boolean = true;
        port sample: GasPort;
        port alarm: AlarmPort;
    }

    part def FlowSensor {
        attribute measuredFlowRate: VolumetricFlowRate = 0.0;
        attribute maximumContinuousFlowRate: VolumetricFlowRate = 1200.0;
        attribute sensorHealthy: Boolean = true;
        port sample: GasPort;
        port alarm: AlarmPort;
    }

    part def OxygenAnalyzer {
        attribute measuredOxygenFraction: Fraction = 0.995;
        attribute minimumOxygenFraction: Fraction = 0.990;
        attribute maximumContaminantFraction: Fraction = 0.001;
        attribute analyzerHealthy: Boolean = true;
        port sample: GasPort;
        port alarm: AlarmPort;
    }

    part def DistributionHeader {
        attribute nominalHeaderPressure: Pressure = 400.0;
        attribute maximumHeaderFlowRate: VolumetricFlowRate = 1500.0;
        port inlet: GasPort;
        port outletWardA: GasPort;
        port outletWardB: GasPort;
        port outletICU: GasPort;
    }

    part def ZoneValveBox {
        attribute zoneName: String;
        attribute valveOpen: Boolean = true;
        attribute localIsolationAvailable: Boolean = true;
        port inlet: GasPort;
        port outlet: GasPort;
        port alarm: AlarmPort;
    }

    part def TerminalOutlet {
        attribute clinicalArea: String;
        attribute nominalOutletPressure: Pressure = 400.0;
        attribute maximumDemandFlowRate: VolumetricFlowRate = 250.0;
        attribute quickConnectHealthy: Boolean = true;
        port inlet: GasPort;
        port patientConnection: GasPort;
    }

    part def AlarmPanel {
        attribute audibleEnabled: Boolean = true;
        attribute visualEnabled: Boolean = true;
        attribute activeCriticalAlarmCount: Integer = 0;
        port power: ElectricalPowerPort;
        port sourcePressureAlarmIn: AlarmPort;
        port linePressureAlarmIn: AlarmPort;
        port flowAlarmIn: AlarmPort;
        port qualityAlarmIn: AlarmPort;
        port zoneAlarmIn: AlarmPort;
        port annunciatorOut: AlarmPort;
    }

    part def ControlUnit {
        attribute automaticChangeoverEnabled: Boolean = true;
        attribute commandedSource: SourceSelectionKind = SourceSelectionKind::primaryBank;
        attribute selfTestInterval: Duration = 86400.0;
        port power: ElectricalPowerPort;
        port control: ControlPort;
        port alarm: AlarmPort;
    }

    part def PowerSupply {
        attribute nominalVoltage: Voltage = 24.0;
        attribute maximumCurrent: ElectricCurrent = 5.0;
        attribute backupDuration: Duration = 7200.0;
        attribute backupAvailable: Boolean = true;
        port output: ElectricalPowerPort;
    }

    action def SenseSourcePressure {
        in sourcePressure: Pressure;
        out sourceAvailable: Boolean;
    }

    action def SelectAvailableSource {
        in primaryAvailable: Boolean;
        in reserveAvailable: Boolean;
        in emergencyAvailable: Boolean;
        out selectedSource: SourceSelectionKind;
    }

    action def ReduceAndRegulatePressure {
        in inletPressure: Pressure;
        in setPressure: Pressure;
        out regulatedPressure: Pressure;
    }

    action def MonitorGasQuality {
        in sampledGas: MedicalGas;
        out oxygenFraction: Fraction;
        out contaminationDetected: Boolean;
    }

    action def AnnunciateUnsafeCondition {
        in severity: AlarmSeverityKind;
        in alarmText: String;
        out alarmActive: Boolean;
    }

    action def SupplyRegulatedMedicalGas {
        in requestedFlowRate: VolumetricFlowRate;
        in primarySourcePressure: Pressure;
        in reserveSourcePressure: Pressure;
        in emergencySourcePressure: Pressure;
        out deliveredFlowRate: VolumetricFlowRate;
        out deliveredPressure: Pressure;
        out deliveredGas: MedicalGas;

        action sensePrimary: SenseSourcePressure;
        action senseReserve: SenseSourcePressure;
        action senseEmergency: SenseSourcePressure;
        action selectSource: SelectAvailableSource;
        action regulateFirstStage: ReduceAndRegulatePressure;
        action regulateLine: ReduceAndRegulatePressure;
        action verifyGasQuality: MonitorGasQuality;
    }

    state def SupplyModeBehavior {
        state off;
        state standby;
        state normalSupply;
        state sourceChangeover;
        state alarmedSupply;
        state maintenance;

        transition energize first off then standby;
        transition beginSupply first standby then normalSupply;
        transition lossOfActiveSource first normalSupply then sourceChangeover;
        transition changeoverComplete first sourceChangeover then normalSupply;
        transition unsafeConditionDetected first normalSupply then alarmedSupply;
        transition alarmCleared first alarmedSupply then normalSupply;
        transition isolateForService first standby then maintenance;
        transition returnFromService first maintenance then standby;
    }

    part def MedicalGasSupplySystem {
        attribute systemName: String = "Hospital Oxygen Medical Gas Supply";
        attribute primaryFunctionStatement: String = "Provide a continuous, monitored, pressure-regulated supply of medical oxygen from redundant source banks to clinical terminal outlets for patient care.";
        attribute primaryFunctionDefined: Boolean = true;
        attribute deliveredGasKind: GasKind = GasKind::oxygen;
        attribute requiredNominalOutletPressure: Pressure = 400.0;
        attribute minimumOutletPressure: Pressure = 380.0;
        attribute maximumOutletPressure: Pressure = 420.0;
        attribute maximumSystemFlowRate: VolumetricFlowRate = 1500.0;
        attribute hasPrimarySource: Boolean = true;
        attribute hasReserveSource: Boolean = true;
        attribute hasEmergencyConnection: Boolean = true;
        attribute alarmMonitoringEnabled: Boolean = true;

        part sourceBankA: GasCylinderBank {
            :>> suppliedGasKind = GasKind::oxygen;
            :>> cylinderCount = 16;
            :>> nominalStoragePressure = 13700.0;
        }

        part sourceBankB: GasCylinderBank {
            :>> suppliedGasKind = GasKind::oxygen;
            :>> cylinderCount = 16;
            :>> nominalStoragePressure = 13700.0;
        }

        part emergencyInlet: EmergencySupplyInlet;
        part sourceManifold: SourceManifold;
        part firstStageRegulator: PressureRegulator {
            :>> setPressure = 800.0;
        }

        part finalLineRegulator: LinePressureRegulator {
            :>> setPressure = 400.0;
        }

        part particulateFilter: GasFilter;
        part sourcePressureSensor: PressureSensor {
            :>> lowAlarmThreshold = 900.0;
            :>> highAlarmThreshold = 15000.0;
        }

        part linePressureSensor: PressureSensor {
            :>> lowAlarmThreshold = 340.0;
            :>> highAlarmThreshold = 480.0;
        }

        part totalFlowSensor: FlowSensor;
        part oxygenAnalyzer: OxygenAnalyzer;
        part distributionHeader: DistributionHeader;

        part wardAZoneValve: ZoneValveBox {
            :>> zoneName = "Ward A";
        }

        part wardBZoneValve: ZoneValveBox {
            :>> zoneName = "Ward B";
        }

        part icuZoneValve: ZoneValveBox {
            :>> zoneName = "Intensive Care Unit";
        }

        part terminalOutletWardA: TerminalOutlet {
            :>> clinicalArea = "Ward A Bedhead Rail";
            :>> maximumDemandFlowRate = 250.0;
        }

        part terminalOutletWardB: TerminalOutlet {
            :>> clinicalArea = "Ward B Bedhead Rail";
            :>> maximumDemandFlowRate = 250.0;
        }

        part terminalOutletICU: TerminalOutlet {
            :>> clinicalArea = "ICU Ventilator Pendant";
            :>> maximumDemandFlowRate = 500.0;
        }

        part controlUnit: ControlUnit;
        part alarmPanel: AlarmPanel;
        part powerSupply: PowerSupply;

        connect sourceBankA.outlet to sourceManifold.primaryInlet;
        connect sourceBankB.outlet to sourceManifold.reserveInlet;
        connect emergencyInlet.outlet to sourceManifold.emergencyInlet;
        connect sourceManifold.outlet to firstStageRegulator.inlet;
        connect sourceManifold.outlet to sourcePressureSensor.sample;
        connect firstStageRegulator.outlet to particulateFilter.inlet;
        connect particulateFilter.outlet to finalLineRegulator.inlet;
        connect finalLineRegulator.outlet to distributionHeader.inlet;
        connect finalLineRegulator.outlet to linePressureSensor.sample;
        connect finalLineRegulator.outlet to totalFlowSensor.sample;
        connect finalLineRegulator.outlet to oxygenAnalyzer.sample;
        connect distributionHeader.outletWardA to wardAZoneValve.inlet;
        connect distributionHeader.outletWardB to wardBZoneValve.inlet;
        connect distributionHeader.outletICU to icuZoneValve.inlet;
        connect wardAZoneValve.outlet to terminalOutletWardA.inlet;
        connect wardBZoneValve.outlet to terminalOutletWardB.inlet;
        connect icuZoneValve.outlet to terminalOutletICU.inlet;
        connect powerSupply.output to controlUnit.power;
        connect powerSupply.output to alarmPanel.power;
        connect sourcePressureSensor.alarm to alarmPanel.sourcePressureAlarmIn;
        connect linePressureSensor.alarm to alarmPanel.linePressureAlarmIn;
        connect totalFlowSensor.alarm to alarmPanel.flowAlarmIn;
        connect oxygenAnalyzer.alarm to alarmPanel.qualityAlarmIn;
        connect wardAZoneValve.alarm to alarmPanel.zoneAlarmIn;
        connect controlUnit.alarm to alarmPanel.annunciatorOut;

        perform action primarySupplyFunction: SupplyRegulatedMedicalGas;
        exhibit state supplyMode: SupplyModeBehavior;
    }

    requirement def PrimaryMedicalGasSupplyFunctionRequirement {
        subject suppliedSystem: MedicalGasSupplySystem;
        attribute requiredFunctionStatement: String = "The system shall receive medical oxygen from redundant supply sources, regulate pressure, monitor supply condition and gas quality, and distribute the gas to clinical terminal outlets for patient care.";
        require constraint primaryFunctionIsDefined {
            suppliedSystem.primaryFunctionDefined == true;
        }
    }

    requirement def OutletPressureRequirement {
        subject suppliedSystem: MedicalGasSupplySystem;
        attribute minimumAllowedPressure: Pressure = 380.0;
        attribute maximumAllowedPressure: Pressure = 420.0;
        require constraint wardAOutletPressureInRange {
            suppliedSystem.terminalOutletWardA.nominalOutletPressure >= minimumAllowedPressure and suppliedSystem.terminalOutletWardA.nominalOutletPressure <= maximumAllowedPressure;
        }
        require constraint wardBOutletPressureInRange {
            suppliedSystem.terminalOutletWardB.nominalOutletPressure >= minimumAllowedPressure and suppliedSystem.terminalOutletWardB.nominalOutletPressure <= maximumAllowedPressure;
        }
        require constraint icuOutletPressureInRange {
            suppliedSystem.terminalOutletICU.nominalOutletPressure >= minimumAllowedPressure and suppliedSystem.terminalOutletICU.nominalOutletPressure <= maximumAllowedPressure;
        }
    }

    requirement def SourceRedundancyRequirement {
        subject suppliedSystem: MedicalGasSupplySystem;
        require constraint redundantSourcesProvided {
            suppliedSystem.hasPrimarySource == true and suppliedSystem.hasReserveSource == true and suppliedSystem.hasEmergencyConnection == true;
        }
    }

    requirement def AlarmMonitoringRequirement {
        subject suppliedSystem: MedicalGasSupplySystem;
        require constraint monitoredUnsafeConditions {
            suppliedSystem.alarmMonitoringEnabled == true;
        }
    }

    part hospitalMedicalGasSupply: MedicalGasSupplySystem;

    requirement primaryFunctionRequirement: PrimaryMedicalGasSupplyFunctionRequirement {
        subject suppliedSystem = hospitalMedicalGasSupply;
    }

    requirement outletPressureRequirement: OutletPressureRequirement {
        subject suppliedSystem = hospitalMedicalGasSupply;
    }

    requirement sourceRedundancyRequirement: SourceRedundancyRequirement {
        subject suppliedSystem = hospitalMedicalGasSupply;
    }

    requirement alarmMonitoringRequirement: AlarmMonitoringRequirement {
        subject suppliedSystem = hospitalMedicalGasSupply;
    }
}
