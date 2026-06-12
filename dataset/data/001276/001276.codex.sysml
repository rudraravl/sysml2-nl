package TEOM_Microbalance_System {

    value type second;
    value type hertz;
    value type microgram;
    value type cubicMeter;
    value type degreeCelsius;
    value type literPerMinute;
    value type pascal;
    value type volt;
    value type percent;

    value type Mass = microgram;
    value type Volume = cubicMeter;
    value type Frequency = hertz;
    value type Time = second;
    value type Temperature = degreeCelsius;
    value type FlowRate = literPerMinute;
    value type Pressure = pascal;
    value type Voltage = volt;
    value type RelativeHumidity = percent;
    value type MassConcentration = microgram / cubicMeter;

    item def AmbientAerosol {
        attribute particulateMass: Mass;
        attribute carrierAirVolume: Volume;
        attribute humidity: RelativeHumidity;
        attribute temperature: Temperature;
    }

    item def ConditionedAirSample {
        attribute particulateMass: Mass;
        attribute volumetricFlow: FlowRate;
        attribute temperature: Temperature;
        attribute pressure: Pressure;
    }

    item def DepositedParticulateMass {
        attribute accumulatedMass: Mass;
        attribute depositionTime: Time;
    }

    item def OscillationSignal {
        attribute resonantFrequency: Frequency;
        attribute amplitudeVoltage: Voltage;
        attribute signalQuality: percent;
    }

    item def ConcentrationReport {
        attribute sampleMass: Mass;
        attribute sampleVolume: Volume;
        attribute massConcentration: MassConcentration;
        attribute averagingPeriod: Time;
        attribute valid: Boolean;
    }

    port def AerosolInletPort {
        in item aerosol: AmbientAerosol;
    }

    port def ConditionedSamplePort {
        out item sample: ConditionedAirSample;
    }

    port def SampleTransferPort {
        inout item sample: ConditionedAirSample;
    }

    port def ParticleDepositPort {
        out item deposit: DepositedParticulateMass;
    }

    port def OscillationPort {
        out item signal: OscillationSignal;
    }

    port def DataPort {
        out item report: ConcentrationReport;
    }

    port def ControlPort {
        in item command: ControlCommand;
        out item status: InstrumentStatus;
    }

    item def ControlCommand {
        attribute startMeasurement: Boolean;
        attribute stopMeasurement: Boolean;
        attribute calibrateZero: Boolean;
        attribute setFlow: FlowRate;
        attribute setFilterTemperature: Temperature;
    }

    item def InstrumentStatus {
        attribute powered: Boolean;
        attribute measuring: Boolean;
        attribute faultActive: Boolean;
        attribute currentFlow: FlowRate;
        attribute filterTemperature: Temperature;
        attribute resonantFrequency: Frequency;
    }

    part def SampleInlet {
        port ambientIn: AerosolInletPort;
        port conditionedOut: ConditionedSamplePort;
        attribute particleCutSize: Length;
        attribute inletPressureDrop: Pressure;
    }

    part def FlowController {
        port sampleIn: SampleTransferPort;
        port sampleOut: SampleTransferPort;
        port control: ControlPort;
        attribute targetFlow: FlowRate = 3.0;
        attribute measuredFlow: FlowRate;
        attribute flowTolerance: FlowRate = 0.1;
    }

    part def SampleConditioner {
        port sampleIn: SampleTransferPort;
        port sampleOut: SampleTransferPort;
        attribute heaterTemperatureSetpoint: Temperature = 50.0;
        attribute measuredTemperature: Temperature;
        attribute maximumHumidity: RelativeHumidity = 20.0;
    }

    part def FilterCartridge {
        port sampleIn: SampleTransferPort;
        port cleanedAirOut: SampleTransferPort;
        port massDeposit: ParticleDepositPort;
        attribute filterMassCapacity: Mass = 100000.0;
        attribute currentDepositedMass: Mass;
        attribute collectionEfficiency: percent = 99.5;
    }

    part def TaperedOscillatingElement {
        port massInput: ParticleDepositPort;
        port oscillationOutput: OscillationPort;
        attribute unloadedFrequency: Frequency;
        attribute currentFrequency: Frequency;
        attribute springConstant: Real;
        attribute effectiveOscillatingMass: Mass;
        attribute frequencyToMassSensitivity: Mass / hertz;
    }

    part def FrequencyMeasurementElectronics {
        port oscillationInput: OscillationPort;
        port dataOut: DataPort;
        attribute frequencyResolution: Frequency = 0.01;
        attribute minimumSignalQuality: percent = 80.0;
    }

    part def ConcentrationProcessor {
        port measurementDataIn: DataPort;
        port reportOut: DataPort;
        attribute averagingPeriod: Time = 3600.0;
        attribute sampleVolumeIntegrated: Volume;
        attribute massIncrement: Mass;
        attribute calculatedConcentration: MassConcentration;
    }

    part def UserInterface {
        port control: ControlPort;
        port reportIn: DataPort;
        attribute displayConcentration: MassConcentration;
        attribute alarmEnabled: Boolean = true;
        attribute alarmThreshold: MassConcentration = 35.0;
    }

    action def DrawSampleAir {
        in item inletAerosol: AmbientAerosol;
        in targetFlow: FlowRate;
        out item conditionedFlow: ConditionedAirSample;
    }

    action def ConditionSample {
        in item rawSample: ConditionedAirSample;
        in targetTemperature: Temperature;
        out item drySample: ConditionedAirSample;
    }

    action def DepositParticlesOnFilter {
        in item drySample: ConditionedAirSample;
        out item depositedMass: DepositedParticulateMass;
        out item exhaustAir: ConditionedAirSample;
    }

    action def MaintainOscillation {
        in item depositedMass: DepositedParticulateMass;
        out item oscillation: OscillationSignal;
    }

    action def ConvertFrequencyShiftToMass {
        in baselineFrequency: Frequency;
        in measuredFrequency: Frequency;
        in sensitivity: Mass / hertz;
        out measuredMass: Mass;
    }

    action def ComputeMassConcentration {
        in measuredMass: Mass;
        in sampledVolume: Volume;
        out concentration: MassConcentration;
    }

    action def TEOMMeasurementCycle {
        in item ambientAerosol: AmbientAerosol;
        out item concentrationReport: ConcentrationReport;

        action draw: DrawSampleAir;
        action condition: ConditionSample;
        action collect: DepositParticlesOnFilter;
        action oscillate: MaintainOscillation;
        action convert: ConvertFrequencyShiftToMass;
        action compute: ComputeMassConcentration;

        flow ambientAerosol to draw.inletAerosol;
        flow draw.conditionedFlow to condition.rawSample;
        flow condition.drySample to collect.drySample;
        flow collect.depositedMass to oscillate.depositedMass;
        flow oscillate.oscillation.resonantFrequency to convert.measuredFrequency;
        flow convert.measuredMass to compute.measuredMass;
        flow compute.concentration to concentrationReport.massConcentration;
    }

    state def TEOMOperatingState {
        entry action initializeInstrument;

        state Off;
        state WarmUp;
        state ZeroCalibration;
        state FlowStabilization;
        state Measuring;
        state Reporting;
        state Fault;
        state Shutdown;

        transition first Off;

        transition Off_to_WarmUp
            first Off
            then WarmUp
            accept ControlCommand
            if command.startMeasurement;

        transition WarmUp_to_ZeroCalibration
            first WarmUp
            then ZeroCalibration
            if filterTemperatureStable and oscillatorLocked;

        transition ZeroCalibration_to_FlowStabilization
            first ZeroCalibration
            then FlowStabilization
            if baselineFrequencyStored;

        transition FlowStabilization_to_Measuring
            first FlowStabilization
            then Measuring
            if flowWithinTolerance;

        transition Measuring_to_Reporting
            first Measuring
            then Reporting
            if averagingPeriodComplete;

        transition Reporting_to_Measuring
            first Reporting
            then Measuring
            if reportPublished;

        transition Any_to_Fault
            first WarmUp, ZeroCalibration, FlowStabilization, Measuring, Reporting
            then Fault
            if flowFailure or heaterFailure or oscillatorSignalLost;

        transition Fault_to_Shutdown
            first Fault
            then Shutdown
            accept ControlCommand
            if command.stopMeasurement;

        transition Measuring_to_Shutdown
            first Measuring
            then Shutdown
            accept ControlCommand
            if command.stopMeasurement;

        transition Shutdown_to_Off
            first Shutdown
            then Off
            if pumpsStopped and heaterOff;
    }

    part def TaperedElementOscillatingMicrobalance {
        port ambientAerosolIn: AerosolInletPort;
        port operatorControl: ControlPort;
        port concentrationOut: DataPort;

        part inlet: SampleInlet;
        part conditioner: SampleConditioner;
        part flowController: FlowController;
        part filter: FilterCartridge;
        part taperedElement: TaperedOscillatingElement;
        part electronics: FrequencyMeasurementElectronics;
        part processor: ConcentrationProcessor;
        part interface: UserInterface;

        attribute primaryFunction: String = "Continuously determine airborne particulate matter mass concentration by collecting particles on a filter attached to a tapered oscillating element and converting the resulting resonant-frequency decrease into deposited mass per sampled air volume.";
        attribute nominalSampleFlow: FlowRate = 3.0;
        attribute nominalFilterTemperature: Temperature = 50.0;
        attribute minimumDetectableMass: Mass = 1.0;
        attribute measurementUpdatePeriod: Time = 60.0;

        perform action measurementCycle: TEOMMeasurementCycle;
        exhibit state operatingState: TEOMOperatingState;

        connect ambientAerosolIn to inlet.ambientIn;
        connect inlet.conditionedOut to conditioner.sampleIn;
        connect conditioner.sampleOut to flowController.sampleIn;
        connect flowController.sampleOut to filter.sampleIn;
        connect filter.massDeposit to taperedElement.massInput;
        connect taperedElement.oscillationOutput to electronics.oscillationInput;
        connect electronics.dataOut to processor.measurementDataIn;
        connect processor.reportOut to concentrationOut;
        connect operatorControl to interface.control;
        connect interface.reportIn to processor.reportOut;
    }

    requirement def PrimaryFunctionRequirement {
        doc "The system shall provide a continuous high-level measurement of airborne particulate matter mass concentration using a tapered element oscillating microbalance principle.";
        subject teom: TaperedElementOscillatingMicrobalance;
        require constraint {
            teom.nominalSampleFlow > 0.0 and
            teom.minimumDetectableMass <= 1.0
        }
    }

    requirement def StableFlowRequirement {
        doc "The system shall regulate sample flow to support accurate conversion of collected particulate mass to sampled air volume.";
        subject controller: FlowController;
        require constraint {
            abs(controller.measuredFlow - controller.targetFlow) <= controller.flowTolerance
        }
    }

    requirement def SampleConditioningRequirement {
        doc "The system shall condition the sampled aerosol stream before particle collection to reduce humidity-driven mass measurement error.";
        subject conditioner: SampleConditioner;
        require constraint {
            conditioner.measuredTemperature >= 45.0 and
            conditioner.measuredTemperature <= 55.0
        }
    }

    requirement def OscillationMeasurementRequirement {
        doc "The tapered element shall produce a measurable resonant-frequency signal whose shift corresponds to collected particulate mass.";
        subject element: TaperedOscillatingElement;
        require constraint {
            element.currentFrequency > 0.0 and
            element.frequencyToMassSensitivity > 0.0
        }
    }

    requirement def ReportingRequirement {
        doc "The system shall report particulate mass concentration over a defined averaging period with validity status.";
        subject processor: ConcentrationProcessor;
        require constraint {
            processor.averagingPeriod >= 60.0 and
            processor.sampleVolumeIntegrated > 0.0
        }
    }

    satisfy PrimaryFunctionRequirement by TaperedElementOscillatingMicrobalance;
    satisfy StableFlowRequirement by FlowController;
    satisfy SampleConditioningRequirement by SampleConditioner;
    satisfy OscillationMeasurementRequirement by TaperedOscillatingElement;
    satisfy ReportingRequirement by ConcentrationProcessor;
}