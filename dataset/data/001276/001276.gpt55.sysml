package TEOM_Microbalance_System_Model {

    enum def MassUnit {
        enum microgram;
        enum milligram;
        enum gram;
        enum kilogram;
    }

    enum def LengthUnit {
        enum micrometer;
        enum millimeter;
        enum meter;
    }

    enum def TimeUnit {
        enum second;
        enum minute;
        enum hour;
    }

    enum def TemperatureUnit {
        enum degreeCelsius;
        enum kelvin;
    }

    enum def PressureUnit {
        enum pascal;
        enum kilopascal;
    }

    enum def FrequencyUnit {
        enum hertz;
    }

    enum def FlowRateUnit {
        enum literPerMinute;
        enum cubicMeterPerHour;
    }

    enum def ConcentrationUnit {
        enum microgramPerCubicMeter;
        enum milligramPerCubicMeter;
    }

    enum def ElectricalUnit {
        enum volt;
        enum ampere;
        enum watt;
    }

    enum def PercentUnit {
        enum percent;
    }

    enum def OperatingModeKind {
        enum off;
        enum warmUp;
        enum zeroCheck;
        enum flowStabilization;
        enum baselineTracking;
        enum sampling;
        enum calculating;
        enum reporting;
        enum maintenance;
        enum fault;
    }

    enum def ParticleFractionKind {
        enum PM1;
        enum PM2_5;
        enum PM10;
        enum TSP;
    }

    enum def AlarmKind {
        enum none;
        enum lowFlow;
        enum highFlow;
        enum filterLoaded;
        enum oscillatorUnlocked;
        enum temperatureOutOfRange;
        enum pressureSensorFault;
        enum dataStorageFull;
        enum serviceDoorOpen;
    }

    enum def CommandKind {
        enum start;
        enum stop;
        enum zeroCheck;
        enum spanCheck;
        enum replaceFilter;
        enum clearAlarm;
        enum exportData;
        enum setAveragingPeriod;
    }

    attribute def MassValue {
        attribute magnitude: Real;
        attribute unit: MassUnit;
    }

    attribute def LengthValue {
        attribute magnitude: Real;
        attribute unit: LengthUnit;
    }

    attribute def TimeValue {
        attribute magnitude: Real;
        attribute unit: TimeUnit;
    }

    attribute def TemperatureValue {
        attribute magnitude: Real;
        attribute unit: TemperatureUnit;
    }

    attribute def PressureValue {
        attribute magnitude: Real;
        attribute unit: PressureUnit;
    }

    attribute def FrequencyValue {
        attribute magnitude: Real;
        attribute unit: FrequencyUnit;
    }

    attribute def FlowRateValue {
        attribute magnitude: Real;
        attribute unit: FlowRateUnit;
    }

    attribute def ConcentrationValue {
        attribute magnitude: Real;
        attribute unit: ConcentrationUnit;
    }

    attribute def ElectricalPotentialValue {
        attribute magnitude: Real;
        attribute unit: ElectricalUnit;
    }

    attribute def ElectricalPowerValue {
        attribute magnitude: Real;
        attribute unit: ElectricalUnit;
    }

    attribute def FractionValue {
        attribute magnitude: Real;
        attribute unit: PercentUnit;
    }

    attribute def CalibrationCoefficientValue {
        attribute magnitude: Real;
        attribute unit: String;
    }

    item def AmbientAerosolSample {
        attribute particleFraction: ParticleFractionKind;
        attribute volumetricFlow: FlowRateValue;
        attribute temperature: TemperatureValue;
        attribute absolutePressure: PressureValue;
        attribute relativeHumidity: FractionValue;
        attribute expectedParticleDiameterCut: LengthValue;
    }

    item def ConditionedAerosolSample {
        attribute particleFraction: ParticleFractionKind;
        attribute volumetricFlow: FlowRateValue;
        attribute conditionerTemperature: TemperatureValue;
        attribute absolutePressure: PressureValue;
        attribute waterLossFraction: FractionValue;
    }

    item def FilteredAirStream {
        attribute volumetricFlow: FlowRateValue;
        attribute temperature: TemperatureValue;
        attribute absolutePressure: PressureValue;
        attribute residualParticleMassConcentration: ConcentrationValue;
    }

    item def DepositedParticleMass {
        attribute accumulatedMass: MassValue;
        attribute incrementalMass: MassValue;
        attribute collectionInterval: TimeValue;
    }

    item def OscillationDriveSignal {
        attribute driveVoltage: ElectricalPotentialValue;
        attribute driveFrequency: FrequencyValue;
        attribute drivePower: ElectricalPowerValue;
    }

    item def OscillationMotionSignal {
        attribute measuredFrequency: FrequencyValue;
        attribute amplitudeMicrometer: LengthValue;
        attribute signalQuality: FractionValue;
    }

    item def FrequencyMeasurement {
        attribute currentFrequency: FrequencyValue;
        attribute baselineFrequency: FrequencyValue;
        attribute frequencyShift: FrequencyValue;
        attribute measurementInterval: TimeValue;
    }

    item def FlowMeasurement {
        attribute actualFlow: FlowRateValue;
        attribute targetFlow: FlowRateValue;
        attribute deviation: FractionValue;
    }

    item def TemperatureMeasurement {
        attribute measuredTemperature: TemperatureValue;
        attribute targetTemperature: TemperatureValue;
        attribute deviation: TemperatureValue;
    }

    item def PressureMeasurement {
        attribute measuredPressure: PressureValue;
    }

    item def ControlCommand {
        attribute command: CommandKind;
        attribute requestedAveragingPeriod: TimeValue;
        attribute operatorId: String;
    }

    item def AlarmNotification {
        attribute alarm: AlarmKind;
        attribute severity: Integer;
        attribute message: String;
    }

    item def ParticulateMeasurementReport {
        attribute particleFraction: ParticleFractionKind;
        attribute averagedMassConcentration: ConcentrationValue;
        attribute instantaneousMassConcentration: ConcentrationValue;
        attribute accumulatedFilterMass: MassValue;
        attribute sampleVolumeCubicMeter: Real;
        attribute sampleStartTimeIso8601: String;
        attribute sampleEndTimeIso8601: String;
        attribute dataValid: Boolean;
        attribute activeAlarm: AlarmKind;
    }

    port def AerosolInletPort {
        in item sample: AmbientAerosolSample;
    }

    port def AerosolTransferPort {
        in item inletSample: AmbientAerosolSample;
        out item outletSample: ConditionedAerosolSample;
    }

    port def ConditionedAerosolPort {
        in item sampleIn: ConditionedAerosolSample;
        out item sampleOut: ConditionedAerosolSample;
    }

    port def FilterInletPort {
        in item aerosol: ConditionedAerosolSample;
    }

    port def FilterOutletPort {
        out item cleanAir: FilteredAirStream;
    }

    port def MassLoadPort {
        out item depositedMass: DepositedParticleMass;
    }

    port def MechanicalMassInputPort {
        in item depositedMass: DepositedParticleMass;
    }

    port def DriveOutputPort {
        out item drive: OscillationDriveSignal;
    }

    port def DriveInputPort {
        in item drive: OscillationDriveSignal;
    }

    port def MotionOutputPort {
        out item motion: OscillationMotionSignal;
    }

    port def MotionInputPort {
        in item motion: OscillationMotionSignal;
    }

    port def FrequencyOutputPort {
        out item frequency: FrequencyMeasurement;
    }

    port def FrequencyInputPort {
        in item frequency: FrequencyMeasurement;
    }

    port def FlowSensorOutputPort {
        out item flow: FlowMeasurement;
    }

    port def FlowSensorInputPort {
        in item flow: FlowMeasurement;
    }

    port def TemperatureOutputPort {
        out item temperature: TemperatureMeasurement;
    }

    port def TemperatureInputPort {
        in item temperature: TemperatureMeasurement;
    }

    port def PressureOutputPort {
        out item pressure: PressureMeasurement;
    }

    port def PressureInputPort {
        in item pressure: PressureMeasurement;
    }

    port def DataServicePort {
        in item command: ControlCommand;
        out item report: ParticulateMeasurementReport;
        out item alarm: AlarmNotification;
    }

    port def PowerInputPort {
        in item supplyVoltage: ElectricalPotentialValue;
    }

    port def ExhaustPort {
        out item exhaust: FilteredAirStream;
    }

    constraint def FrequencyToMassConstraint {
        in baselineFrequencyHz: Real;
        in currentFrequencyHz: Real;
        in calibrationCoefficientMicrogramHertzSquared: Real;
        out incrementalMassMicrogram: Real;
        constraint {
            incrementalMassMicrogram ==
                calibrationCoefficientMicrogramHertzSquared *
                ((1.0 / (currentFrequencyHz * currentFrequencyHz)) -
                 (1.0 / (baselineFrequencyHz * baselineFrequencyHz)));
        }
    }

    constraint def SampleVolumeConstraint {
        in flowLiterPerMinute: Real;
        in durationMinute: Real;
        out volumeCubicMeter: Real;
        constraint {
            volumeCubicMeter == (flowLiterPerMinute * durationMinute) / 1000.0;
        }
    }

    constraint def ConcentrationConstraint {
        in incrementalMassMicrogram: Real;
        in volumeCubicMeter: Real;
        out concentrationMicrogramPerCubicMeter: Real;
        constraint {
            concentrationMicrogramPerCubicMeter == incrementalMassMicrogram / volumeCubicMeter;
        }
    }

    constraint def FlowValidityConstraint {
        in targetFlowLiterPerMinute: Real;
        in actualFlowLiterPerMinute: Real;
        out valid: Boolean;
        constraint {
            valid == ((actualFlowLiterPerMinute >= targetFlowLiterPerMinute * 0.95) and
                      (actualFlowLiterPerMinute <= targetFlowLiterPerMinute * 1.05));
        }
    }

    constraint def TemperatureValidityConstraint {
        in targetTemperatureCelsius: Real;
        in actualTemperatureCelsius: Real;
        out valid: Boolean;
        constraint {
            valid == ((actualTemperatureCelsius >= targetTemperatureCelsius - 1.0) and
                      (actualTemperatureCelsius <= targetTemperatureCelsius + 1.0));
        }
    }

    part def SizeSelectiveInlet {
        attribute selectedFraction: ParticleFractionKind = ParticleFractionKind::PM10;
        attribute aerodynamicCutDiameter: LengthValue = (magnitude = 10.0, unit = LengthUnit::micrometer);
        attribute nominalInletFlow: FlowRateValue = (magnitude = 16.67, unit = FlowRateUnit::literPerMinute);
        port rawAmbientAir: AerosolInletPort;
        port classifiedAerosol: AerosolTransferPort;
    }

    part def HeatedSampleConditioner {
        attribute targetTemperature: TemperatureValue = (magnitude = 50.0, unit = TemperatureUnit::degreeCelsius);
        attribute warmUpTime: TimeValue = (magnitude = 30.0, unit = TimeUnit::minute);
        attribute maximumAllowedTemperatureDeviation: TemperatureValue = (magnitude = 1.0, unit = TemperatureUnit::degreeCelsius);
        port samplePath: ConditionedAerosolPort;
        port temperatureStatus: TemperatureOutputPort;
    }

    part def MainFlowController {
        attribute targetMainFlow: FlowRateValue = (magnitude = 3.00, unit = FlowRateUnit::literPerMinute);
        attribute allowedDeviation: FractionValue = (magnitude = 5.0, unit = PercentUnit::percent);
        port aerosolPath: ConditionedAerosolPort;
        port measuredFlow: FlowSensorOutputPort;
    }

    part def BypassFlowController {
        attribute targetBypassFlow: FlowRateValue = (magnitude = 13.67, unit = FlowRateUnit::literPerMinute);
        attribute allowedDeviation: FractionValue = (magnitude = 5.0, unit = PercentUnit::percent);
        port measuredFlow: FlowSensorOutputPort;
    }

    part def FilterCartridge {
        attribute filterDiameter: LengthValue = (magnitude = 13.0, unit = LengthUnit::millimeter);
        attribute maximumParticleLoading: MassValue = (magnitude = 5000.0, unit = MassUnit::microgram);
        attribute initialFilterMass: MassValue = (magnitude = 120.0, unit = MassUnit::milligram);
        attribute replacementInterval: TimeValue = (magnitude = 30.0, unit = TimeUnit::day);
        port aerosolIn: FilterInletPort;
        port cleanAirOut: FilterOutletPort;
        port massLoadOut: MassLoadPort;
    }

    part def TaperedElementAssembly {
        attribute material: String = "hollow tapered glass tube";
        attribute unloadedNaturalFrequency: FrequencyValue = (magnitude = 205.0, unit = FrequencyUnit::hertz);
        attribute operatingAmplitude: LengthValue = (magnitude = 50.0, unit = LengthUnit::micrometer);
        attribute calibrationCoefficient: CalibrationCoefficientValue = (magnitude = 4250000.0, unit = "microgram*hertz^2");
        attribute effectiveSpringConstantNewtonPerMeter: Real = 42.0;
        port massInput: MechanicalMassInputPort;
        port driveInput: DriveInputPort;
        port motionOutput: MotionOutputPort;
    }

    part def ElectromagneticOscillatorDriver {
        attribute nominalDriveVoltage: ElectricalPotentialValue = (magnitude = 2.5, unit = ElectricalUnit::volt);
        attribute maximumDrivePower: ElectricalPowerValue = (magnitude = 1.0, unit = ElectricalUnit::watt);
        port driveOut: DriveOutputPort;
    }

    part def OpticalFrequencySensor {
        attribute frequencyResolution: FrequencyValue = (magnitude = 0.0001, unit = FrequencyUnit::hertz);
        attribute minimumSignalQuality: FractionValue = (magnitude = 90.0, unit = PercentUnit::percent);
        port motionIn: MotionInputPort;
        port frequencyOut: FrequencyOutputPort;
    }

    part def TemperatureController {
        attribute controllerSetPoint: TemperatureValue = (magnitude = 50.0, unit = TemperatureUnit::degreeCelsius);
        attribute maximumHeaterPower: ElectricalPowerValue = (magnitude = 35.0, unit = ElectricalUnit::watt);
        port temperatureIn: TemperatureInputPort;
    }

    part def BarometricPressureSensor {
        attribute pressureRangeLow: PressureValue = (magnitude = 70.0, unit = PressureUnit::kilopascal);
        attribute pressureRangeHigh: PressureValue = (magnitude = 110.0, unit = PressureUnit::kilopascal);
        port pressureOut: PressureOutputPort;
    }

    part def SignalProcessor {
        attribute frequencyAveragingWindow: TimeValue = (magnitude = 6.0, unit = TimeUnit::second);
        attribute baselineUpdatePeriod: TimeValue = (magnitude = 60.0, unit = TimeUnit::minute);
        attribute oscillatorLockRequired: Boolean = true;
        port frequencyIn: FrequencyInputPort;
        port flowIn: FlowSensorInputPort;
        port temperatureIn: TemperatureInputPort;
        port pressureIn: PressureInputPort;
        port processedFrequencyOut: FrequencyOutputPort;
    }

    part def ConcentrationCalculator {
        attribute defaultAveragingPeriod: TimeValue = (magnitude = 60.0, unit = TimeUnit::minute);
        attribute minimumValidSampleVolumeCubicMeter: Real = 0.001;
        attribute reportingUnit: ConcentrationUnit = ConcentrationUnit::microgramPerCubicMeter;
        port frequencyIn: FrequencyInputPort;
        port flowIn: FlowSensorInputPort;
        port dataOut: DataServicePort;
    }

    part def DataLoggerAndInterface {
        attribute storageCapacityRecords: Integer = 525600;
        attribute communicationProtocol: String = "Ethernet Modbus TCP and USB CSV export";
        attribute reportInterval: TimeValue = (magnitude = 1.0, unit = TimeUnit::minute);
        port service: DataServicePort;
    }

    part def PumpAndExhaustAssembly {
        attribute pumpCapacity: FlowRateValue = (magnitude = 20.0, unit = FlowRateUnit::literPerMinute);
        attribute nominalVacuumPressureDrop: PressureValue = (magnitude = 18.0, unit = PressureUnit::kilopascal);
        port filteredAirIn: FilterOutletPort;
        port exhaustOut: ExhaustPort;
    }

    part def EnvironmentalEnclosure {
        attribute ingressProtectionRating: String = "IP54";
        attribute operatingTemperatureLow: TemperatureValue = (magnitude = -20.0, unit = TemperatureUnit::degreeCelsius);
        attribute operatingTemperatureHigh: TemperatureValue = (magnitude = 45.0, unit = TemperatureUnit::degreeCelsius);
        attribute supplyVoltageNominal: ElectricalPotentialValue = (magnitude = 120.0, unit = ElectricalUnit::volt);
        port powerIn: PowerInputPort;
    }

    action def EstablishThermalControl {
        in item measuredTemperature: TemperatureMeasurement;
        out item controlledTemperature: TemperatureMeasurement;
        attribute targetTemperature: TemperatureValue = (magnitude = 50.0, unit = TemperatureUnit::degreeCelsius);
        attribute stabilizationCriterion: TemperatureValue = (magnitude = 1.0, unit = TemperatureUnit::degreeCelsius);
    }

    action def StabilizeSampleFlow {
        in item rawFlow: FlowMeasurement;
        out item stableFlow: FlowMeasurement;
        attribute targetMainFlow: FlowRateValue = (magnitude = 3.00, unit = FlowRateUnit::literPerMinute);
        attribute stabilizationTime: TimeValue = (magnitude = 120.0, unit = TimeUnit::second);
    }

    action def CollectParticlesOnFilter {
        in item conditionedSample: ConditionedAerosolSample;
        out item depositedMass: DepositedParticleMass;
        attribute collectionInterval: TimeValue = (magnitude = 60.0, unit = TimeUnit::second);
    }

    action def MaintainTaperedElementOscillation {
        in item drive: OscillationDriveSignal;
        out item motion: OscillationMotionSignal;
        attribute lockFrequencyBandLow: FrequencyValue = (magnitude = 190.0, unit = FrequencyUnit::hertz);
        attribute lockFrequencyBandHigh: FrequencyValue = (magnitude = 220.0, unit = FrequencyUnit::hertz);
    }

    action def MeasureFrequencyShift {
        in item motion: OscillationMotionSignal;
        out item frequency: FrequencyMeasurement;
        attribute resolution: FrequencyValue = (magnitude = 0.0001, unit = FrequencyUnit::hertz);
    }

    action def CalculateMassAndConcentration {
        in item frequency: FrequencyMeasurement;
        in item flow: FlowMeasurement;
        out item report: ParticulateMeasurementReport;
        attribute massCalibrationCoefficient: CalibrationCoefficientValue = (magnitude = 4250000.0, unit = "microgram*hertz^2");
    }

    action def PublishMeasurementReport {
        in item report: ParticulateMeasurementReport;
        out item transmittedReport: ParticulateMeasurementReport;
        attribute protocol: String = "Modbus TCP register map and timestamped CSV";
    }

    action def PerformTEOMMeasurementCycle {
        in item ambientSample: AmbientAerosolSample;
        in item operatorCommand: ControlCommand;
        out item report: ParticulateMeasurementReport;
        out item alarm: AlarmNotification;

        action thermalControl: EstablishThermalControl;
        action flowControl: StabilizeSampleFlow;
        action particleCollection: CollectParticlesOnFilter;
        action oscillationControl: MaintainTaperedElementOscillation;
        action frequencyMeasurement: MeasureFrequencyShift;
        action concentrationComputation: CalculateMassAndConcentration;
        action publication: PublishMeasurementReport;

        flow particleCollection.depositedMass to concentrationComputation.report;
        flow frequencyMeasurement.frequency to concentrationComputation.frequency;
        flow concentrationComputation.report to publication.report;

        succession thermalControl then flowControl;
        succession flowControl then particleCollection;
        succession particleCollection then oscillationControl;
        succession oscillationControl then frequencyMeasurement;
        succession frequencyMeasurement then concentrationComputation;
        succession concentrationComputation then publication;
    }

    state def TEOMOperatingStateMachine {
        state unpowered;
        state warmingUp;
        state zeroChecking;
        state stabilizingFlow;
        state acquiringBaseline;
        state sampling;
        state computingConcentration;
        state reporting;
        state maintenanceMode;
        state faulted;

        transition initialTransition first start then unpowered;

        transition powerApplied
            first unpowered
            accept ControlCommand[command == CommandKind::start]
            then warmingUp;

        transition warmUpComplete
            first warmingUp
            if true
            then stabilizingFlow;

        transition zeroCheckRequested
            first stabilizingFlow
            accept ControlCommand[command == CommandKind::zeroCheck]
            then zeroChecking;

        transition zeroCheckComplete
            first zeroChecking
            then acquiringBaseline;

        transition flowStable
            first stabilizingFlow
            then acquiringBaseline;

        transition baselineValid
            first acquiringBaseline
            then sampling;

        transition sampleIntervalComplete
            first sampling
            then computingConcentration;

        transition calculationComplete
            first computingConcentration
            then reporting;

        transition reportPublished
            first reporting
            then sampling;

        transition filterReplacementRequested
            first sampling
            accept ControlCommand[command == CommandKind::replaceFilter]
            then maintenanceMode;

        transition maintenanceComplete
            first maintenanceMode
            accept ControlCommand[command == CommandKind::start]
            then warmingUp;

        transition alarmDetectedFromWarmUp
            first warmingUp
            accept AlarmNotification[alarm != AlarmKind::none]
            then faulted;

        transition alarmDetectedFromSampling
            first sampling
            accept AlarmNotification[alarm != AlarmKind::none]
            then faulted;

        transition alarmDetectedFromComputation
            first computingConcentration
            accept AlarmNotification[alarm != AlarmKind::none]
            then faulted;

        transition faultCleared
            first faulted
            accept ControlCommand[command == CommandKind::clearAlarm]
            then stabilizingFlow;

        transition shutdown
            first sampling
            accept ControlCommand[command == CommandKind::stop]
            then unpowered;
    }

    part def TaperedElementOscillatingMicrobalanceMonitor {
        attribute systemName: String = "Tapered Element Oscillating Microbalance Ambient Particulate Monitor";
        attribute primaryFunctionStatement: String =
            "Continuously measure airborne particulate matter mass concentration by collecting particles on a filter attached to an oscillating tapered element and converting oscillation frequency change into mass per sampled air volume.";
        attribute selectedParticleFraction: ParticleFractionKind = ParticleFractionKind::PM10;
        attribute operatingMode: OperatingModeKind = OperatingModeKind::off;
        attribute nominalMainFlow: FlowRateValue = (magnitude = 3.00, unit = FlowRateUnit::literPerMinute);
        attribute nominalTotalInletFlow: FlowRateValue = (magnitude = 16.67, unit = FlowRateUnit::literPerMinute);
        attribute nominalOperatingTemperature: TemperatureValue = (magnitude = 50.0, unit = TemperatureUnit::degreeCelsius);
        attribute measurementReportingPeriod: TimeValue = (magnitude = 1.0, unit = TimeUnit::minute);
        attribute regulatoryAveragingPeriod: TimeValue = (magnitude = 60.0, unit = TimeUnit::minute);
        attribute currentMassConcentration: ConcentrationValue = (magnitude = 0.0, unit = ConcentrationUnit::microgramPerCubicMeter);
        attribute currentAccumulatedFilterMass: MassValue = (magnitude = 0.0, unit = MassUnit::microgram);
        attribute primaryFunctionEnabled: Boolean = true;

        port ambientAirIn: AerosolInletPort;
        port exhaustOut: ExhaustPort;
        port dataService: DataServicePort;
        port powerInput: PowerInputPort;

        part enclosure: EnvironmentalEnclosure;
        part inlet: SizeSelectiveInlet;
        part conditioner: HeatedSampleConditioner;
        part mainFlowController: MainFlowController;
        part bypassFlowController: BypassFlowController;
        part filter: FilterCartridge;
        part taperedElement: TaperedElementAssembly;
        part oscillatorDriver: ElectromagneticOscillatorDriver;
        part frequencySensor: OpticalFrequencySensor;
        part temperatureController: TemperatureController;
        part pressureSensor: BarometricPressureSensor;
        part signalProcessor: SignalProcessor;
        part concentrationCalculator: ConcentrationCalculator;
        part dataLogger: DataLoggerAndInterface;
        part pump: PumpAndExhaustAssembly;

        connect powerInput to enclosure.powerIn;
        connect ambientAirIn to inlet.rawAmbientAir;
        connect inlet.classifiedAerosol to conditioner.samplePath;
        connect conditioner.samplePath to mainFlowController.aerosolPath;
        connect mainFlowController.aerosolPath to filter.aerosolIn;
        connect filter.cleanAirOut to pump.filteredAirIn;
        connect pump.exhaustOut to exhaustOut;

        connect filter.massLoadOut to taperedElement.massInput;
        connect oscillatorDriver.driveOut to taperedElement.driveInput;
        connect taperedElement.motionOutput to frequencySensor.motionIn;
        connect frequencySensor.frequencyOut to signalProcessor.frequencyIn;
        connect signalProcessor.processedFrequencyOut to concentrationCalculator.frequencyIn;

        connect mainFlowController.measuredFlow to signalProcessor.flowIn;
        connect mainFlowController.measuredFlow to concentrationCalculator.flowIn;
        connect conditioner.temperatureStatus to temperatureController.temperatureIn;
        connect conditioner.temperatureStatus to signalProcessor.temperatureIn;
        connect pressureSensor.pressureOut to signalProcessor.pressureIn;

        connect concentrationCalculator.dataOut to dataLogger.service;
        connect dataLogger.service to dataService;

        perform measurementCycle: PerformTEOMMeasurementCycle;

        state operatingState: TEOMOperatingStateMachine;
    }

    requirement def PrimaryFunctionRequirement {
        subject system: TaperedElementOscillatingMicrobalanceMonitor;
        doc /* The system shall provide the high-level primary function of a tapered element oscillating microbalance: draw a controlled ambient aerosol sample, collect particulate matter on a filter mounted on an oscillating tapered element, detect the oscillation frequency decrease caused by deposited mass, and report particulate mass concentration in micrograms per cubic meter. */
        require constraint {
            system.primaryFunctionEnabled == true;
        }
    }

    requirement def ControlledFlowRequirement {
        subject system: TaperedElementOscillatingMicrobalanceMonitor;
        doc /* The system shall maintain the main sample flow through the filter at 3.00 L/min within plus or minus 5 percent during valid measurement operation. */
        require constraint {
            system.nominalMainFlow.magnitude == 3.00;
        }
    }

    requirement def SizeSelectiveSamplingRequirement {
        subject system: TaperedElementOscillatingMicrobalanceMonitor;
        doc /* The inlet shall select the configured particulate fraction before the aerosol reaches the measurement filter. */
        require constraint {
            system.inlet.aerodynamicCutDiameter.magnitude == 10.0;
        }
    }

    requirement def HeatedConditioningRequirement {
        subject system: TaperedElementOscillatingMicrobalanceMonitor;
        doc /* The sample conditioner shall hold the filter and sample stream at 50 degrees Celsius within plus or minus 1 degree Celsius to reduce volatile water interference and maintain stable mass measurement conditions. */
        require constraint {
            system.nominalOperatingTemperature.magnitude == 50.0;
        }
    }

    requirement def FrequencyBasedMassDeterminationRequirement {
        subject system: TaperedElementOscillatingMicrobalanceMonitor;
        doc /* The system shall determine collected particle mass from the change between baseline and current tapered-element oscillation frequency using a stored calibration coefficient. */
        require constraint {
            system.taperedElement.calibrationCoefficient.magnitude > 0.0;
        }
    }

    requirement def ConcentrationReportingRequirement {
        subject system: TaperedElementOscillatingMicrobalanceMonitor;
        doc /* The system shall report averaged and instantaneous particulate mass concentration with units of micrograms per cubic meter and shall flag reports invalid when flow, temperature, or oscillator lock criteria are not met. */
        require constraint {
            system.currentMassConcentration.unit == ConcentrationUnit::microgramPerCubicMeter;
        }
    }

    requirement def AlarmRequirement {
        subject system: TaperedElementOscillatingMicrobalanceMonitor;
        doc /* The system shall enter a faulted state and issue an alarm notification when flow deviation, temperature deviation, oscillator unlock, excessive filter loading, pressure sensor fault, or data storage failure prevents valid concentration reporting. */
        require constraint {
            system.operatingMode != OperatingModeKind::fault or system.primaryFunctionEnabled == false;
        }
    }

    part teomAmbientParticulateMonitor: TaperedElementOscillatingMicrobalanceMonitor;

    requirement primaryFunction: PrimaryFunctionRequirement {
        subject system = teomAmbientParticulateMonitor;
    }

    requirement controlledFlow: ControlledFlowRequirement {
        subject system = teomAmbientParticulateMonitor;
    }

    requirement sizeSelectiveSampling: SizeSelectiveSamplingRequirement {
        subject system = teomAmbientParticulateMonitor;
    }

    requirement heatedConditioning: HeatedConditioningRequirement {
        subject system = teomAmbientParticulateMonitor;
    }

    requirement frequencyBasedMassDetermination: FrequencyBasedMassDeterminationRequirement {
        subject system = teomAmbientParticulateMonitor;
    }

    requirement concentrationReporting: ConcentrationReportingRequirement {
        subject system = teomAmbientParticulateMonitor;
    }

    requirement alarmHandling: AlarmRequirement {
        subject system = teomAmbientParticulateMonitor;
    }

    satisfy primaryFunction by teomAmbientParticulateMonitor;
    satisfy controlledFlow by teomAmbientParticulateMonitor.mainFlowController;
    satisfy sizeSelectiveSampling by teomAmbientParticulateMonitor.inlet;
    satisfy heatedConditioning by teomAmbientParticulateMonitor.conditioner;
    satisfy frequencyBasedMassDetermination by teomAmbientParticulateMonitor.taperedElement;
    satisfy frequencyBasedMassDetermination by teomAmbientParticulateMonitor.frequencySensor;
    satisfy concentrationReporting by teomAmbientParticulateMonitor.concentrationCalculator;
    satisfy alarmHandling by teomAmbientParticulateMonitor.signalProcessor;
}
