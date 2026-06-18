package TransitionEdgeSensorSensingUnitModel {

    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    enum def DetectorTechnology {
        enum transitionEdgeSensor;
        enum bolometer;
        enum semiconductorDiode;
        enum photomultiplier;
    }

    enum def HealthState {
        enum nominal;
        enum warning;
        enum fault;
        enum saturated;
    }

    enum def QuantityKind {
        enum incidentRadiationEnergy;
        enum absorbedPower;
        enum photonArrivalTime;
    }

    attribute def ThermodynamicTemperature :> ISQ::TemperatureValue;
    attribute def TemperatureChange :> ISQ::TemperatureValue;
    attribute def Energy :> ISQ::EnergyValue;
    attribute def Power :> ISQ::PowerValue;
    attribute def Time :> ISQ::TimeValue;
    attribute def Frequency :> ISQ::FrequencyValue;
    attribute def ElectricCurrent :> ISQ::ElectricCurrentValue;
    attribute def ElectricVoltage :> ISQ::VoltageValue;
    attribute def ElectricalResistance :> ISQ::ResistanceValue;
    attribute def ThermalConductance :> ScalarValues::Real;
    attribute def HeatCapacity :> ScalarValues::Real;
    attribute def DimensionlessRatio :> ScalarValues::Real;
    attribute def DigitalCount :> ScalarValues::Integer;

    item def IncidentRadiation {
        attribute quantity : QuantityKind = QuantityKind::incidentRadiationEnergy;
        attribute photonEnergy : Energy = 1.60e-18 [J];
        attribute arrivalTime : Time = 0.0 [s];
        attribute wavelength : ISQ::LengthValue = 1.24e-7 [m];
    }

    item def AbsorbedThermalPulse {
        attribute depositedEnergy : Energy;
        attribute peakTemperatureRise : TemperatureChange;
        attribute riseTime : Time = 2.0e-6 [s];
        attribute decayTime : Time = 2.5e-4 [s];
    }

    item def BiasCurrent {
        attribute current : ElectricCurrent = 8.0e-6 [A];
        attribute voltage : ElectricVoltage = 3.0e-6 [V];
    }

    item def TESCurrentPulse {
        attribute baselineCurrent : ElectricCurrent = 8.0e-6 [A];
        attribute peakCurrentChange : ElectricCurrent;
        attribute pulseStartTime : Time;
        attribute pulseRiseTime : Time = 2.0e-6 [s];
        attribute pulseDecayTime : Time = 2.5e-4 [s];
        attribute samplingFrequency : Frequency = 2.0e6 [Hz];
    }

    item def CryogenicHeatFlow {
        attribute heatPower : Power;
        attribute sourceTemperature : ThermodynamicTemperature;
        attribute sinkTemperature : ThermodynamicTemperature;
    }

    item def DigitalEnergyMeasurement {
        attribute measuredQuantity : QuantityKind = QuantityKind::incidentRadiationEnergy;
        attribute estimatedEnergy : Energy;
        attribute measurementTime : Time;
        attribute energyUncertainty : Energy = 8.0e-19 [J];
        attribute quality : DimensionlessRatio = 0.99;
        attribute saturated : Boolean = false;
    }

    item def ControlCommand {
        attribute enable : Boolean;
        attribute requestCalibration : Boolean;
        attribute resetFault : Boolean;
        attribute targetBiasVoltage : ElectricVoltage = 3.0e-6 [V];
        attribute targetBathTemperature : ThermodynamicTemperature = 7.5e-2 [K];
    }

    item def SensorStatus {
        attribute health : HealthState = HealthState::nominal;
        attribute bathTemperature : ThermodynamicTemperature;
        attribute tesTemperature : ThermodynamicTemperature;
        attribute biasVoltage : ElectricVoltage;
        attribute eventRate : Frequency;
    }

    port def RadiationInputPort {
        in item radiation : IncidentRadiation;
    }

    port def BiasInputPort {
        in item bias : BiasCurrent;
    }

    port def CurrentSignalOutputPort {
        out item pulse : TESCurrentPulse;
    }

    port def ThermalPort {
        inout item heat : CryogenicHeatFlow;
    }

    port def DigitalMeasurementPort {
        out item measurement : DigitalEnergyMeasurement;
    }

    port def CommandPort {
        in item command : ControlCommand;
    }

    port def StatusPort {
        out item status : SensorStatus;
    }

    port def PowerPort {
        in item supplyPower : Power;
    }

    constraint def ThermalPulseEquation {
        in depositedEnergy : Energy;
        in heatCapacity : HeatCapacity;
        in peakTemperatureRise : TemperatureChange;
        constraint { peakTemperatureRise == depositedEnergy / heatCapacity }
    }

    constraint def ThermalRelaxationEquation {
        in heatCapacity : HeatCapacity;
        in thermalConductance : ThermalConductance;
        in decayTime : Time;
        constraint { decayTime == heatCapacity / thermalConductance }
    }

    constraint def TransitionOperatingWindow {
        in tesTemperature : ThermodynamicTemperature;
        in lowerTransitionTemperature : ThermodynamicTemperature;
        in upperTransitionTemperature : ThermodynamicTemperature;
        constraint { tesTemperature >= lowerTransitionTemperature and tesTemperature <= upperTransitionTemperature }
    }

    constraint def EnergyMeasurementRange {
        in estimatedEnergy : Energy;
        in minimumEnergy : Energy;
        in maximumEnergy : Energy;
        constraint { estimatedEnergy >= minimumEnergy and estimatedEnergy <= maximumEnergy }
    }

    action def AbsorbRadiationEnergy {
        in item incomingRadiation : IncidentRadiation;
        out item thermalPulse : AbsorbedThermalPulse;

        attribute absorberEfficiency : DimensionlessRatio = 0.98;
        attribute absorberHeatCapacity : HeatCapacity = 6.0e-13 [J/K];

        constraint thermalConversion : ThermalPulseEquation {
            in depositedEnergy = incomingRadiation.photonEnergy * absorberEfficiency;
            in heatCapacity = absorberHeatCapacity;
            in peakTemperatureRise = thermalPulse.peakTemperatureRise;
        }
    }

    action def ConvertThermalPulseToCurrentPulse {
        in item thermalPulse : AbsorbedThermalPulse;
        in item bias : BiasCurrent;
        out item tesPulse : TESCurrentPulse;

        attribute transitionSlopeAlpha : DimensionlessRatio = 80.0;
        attribute normalResistance : ElectricalResistance = 1.0e-2 [Ohm];
        attribute operatingTemperature : ThermodynamicTemperature = 9.0e-2 [K];
        attribute currentResponsivity : DimensionlessRatio = 4.0e6;

        constraint { tesPulse.peakCurrentChange == thermalPulse.depositedEnergy * currentResponsivity * 1.0 [A/J] }
    }

    action def DigitizeAndEstimateEnergy {
        in item currentPulse : TESCurrentPulse;
        out item measurement : DigitalEnergyMeasurement;

        attribute adcResolution : DigitalCount = 18;
        attribute samplingFrequency : Frequency = 2.0e6 [Hz];
        attribute digitalFilterLength : Time = 1.0e-3 [s];
        attribute calibrationGain : DimensionlessRatio = 2.5e-7;

        constraint { measurement.estimatedEnergy == currentPulse.peakCurrentChange * calibrationGain * 1.0 [J/A] }
        constraint { measurement.measurementTime == currentPulse.pulseStartTime }
    }

    action def MeasureIncidentRadiationEnergy {
        in item incomingRadiation : IncidentRadiation;
        in item bias : BiasCurrent;
        out item measurement : DigitalEnergyMeasurement;

        action absorb : AbsorbRadiationEnergy {
            in incomingRadiation = incomingRadiation;
        }

        action transduce : ConvertThermalPulseToCurrentPulse {
            in thermalPulse = absorb.thermalPulse;
            in bias = bias;
        }

        action estimate : DigitizeAndEstimateEnergy {
            in currentPulse = transduce.tesPulse;
            out measurement = measurement;
        }
    }

    action def CalibrateWithReferencePulse {
        in referenceEnergy : Energy;
        out calibrationAccepted : Boolean;

        attribute allowedCalibrationError : Energy = 3.2e-19 [J];
        attribute lastMeasuredReferenceEnergy : Energy;

        constraint { calibrationAccepted == (abs(lastMeasuredReferenceEnergy - referenceEnergy) <= allowedCalibrationError) }
    }

    state def SensingUnitOperatingStates {
        in item command : ControlCommand;
        in item status : SensorStatus;
        in pulseDetected : Boolean;
        in saturationDetected : Boolean;
        in thermalStable : Boolean;
        in biasStable : Boolean;

        state off;
        state cooling;
        state biasing;
        state ready;
        state measuring;
        state calibrating;
        state saturated;
        state fault;

        transition initial then off;

        transition startCooling
            first off
            accept command
            if command.enable
            then cooling;

        transition coolingComplete
            first cooling
            if thermalStable
            then biasing;

        transition biasComplete
            first biasing
            if biasStable
            then ready;

        transition detectPulse
            first ready
            if pulseDetected
            then measuring;

        transition measurementComplete
            first measuring
            then ready;

        transition requestCalibration
            first ready
            accept command
            if command.requestCalibration
            then calibrating;

        transition calibrationComplete
            first calibrating
            then ready;

        transition saturation
            first measuring
            if saturationDetected
            then saturated;

        transition clearSaturation
            first saturated
            accept command
            if command.resetFault
            then biasing;

        transition disable
            first ready
            accept command
            if not command.enable
            then off;

        transition failFromCooling
            first cooling
            if status.health == HealthState::fault
            then fault;

        transition failFromBiasing
            first biasing
            if status.health == HealthState::fault
            then fault;

        transition failFromReady
            first ready
            if status.health == HealthState::fault
            then fault;

        transition resetFault
            first fault
            accept command
            if command.resetFault
            then off;
    }

    part def RadiationAbsorber {
        port radiationIn : RadiationInputPort;
        port thermalOut : ThermalPort;

        attribute material : String = "gold absorber on silicon nitride membrane";
        attribute absorptionEfficiency : DimensionlessRatio = 0.98;
        attribute heatCapacity : HeatCapacity = 6.0e-13 [J/K];
        attribute activeArea : ISQ::AreaValue = 2.5e-10 [m^2];
        attribute thickness : ISQ::LengthValue = 2.0e-7 [m];
    }

    part def SuperconductingTransitionFilm {
        port thermalIn : ThermalPort;
        port biasIn : BiasInputPort;
        port currentOut : CurrentSignalOutputPort;

        attribute material : String = "molybdenum-gold bilayer";
        attribute technology : DetectorTechnology = DetectorTechnology::transitionEdgeSensor;
        attribute criticalTemperature : ThermodynamicTemperature = 9.0e-2 [K];
        attribute transitionLowerTemperature : ThermodynamicTemperature = 8.95e-2 [K];
        attribute transitionUpperTemperature : ThermodynamicTemperature = 9.05e-2 [K];
        attribute operatingTemperature : ThermodynamicTemperature = 9.0e-2 [K];
        attribute normalResistance : ElectricalResistance = 1.0e-2 [Ohm];
        attribute operatingResistance : ElectricalResistance = 3.0e-3 [Ohm];
        attribute transitionWidth : TemperatureChange = 1.0e-3 [K];
        attribute transitionSlopeAlpha : DimensionlessRatio = 80.0;

        constraint withinTransition : TransitionOperatingWindow {
            in tesTemperature = operatingTemperature;
            in lowerTransitionTemperature = transitionLowerTemperature;
            in upperTransitionTemperature = transitionUpperTemperature;
        }
    }

    part def WeakThermalLink {
        port detectorSide : ThermalPort;
        port bathSide : ThermalPort;

        attribute material : String = "silicon nitride support legs";
        attribute thermalConductance : ThermalConductance = 2.4e-9 [W/K];
        attribute heatCapacityCoupled : HeatCapacity = 6.0e-13 [J/K];
        attribute thermalTimeConstant : Time = 2.5e-4 [s];

        constraint relaxation : ThermalRelaxationEquation {
            in heatCapacity = heatCapacityCoupled;
            in thermalConductance = thermalConductance;
            in decayTime = thermalTimeConstant;
        }
    }

    part def TransitionEdgeSensor {
        port radiationIn : RadiationInputPort;
        port biasIn : BiasInputPort;
        port signalOut : CurrentSignalOutputPort;
        port thermalBath : ThermalPort;

        part absorber : RadiationAbsorber;
        part superconductingFilm : SuperconductingTransitionFilm;
        part weakThermalLink : WeakThermalLink;

        attribute technology : DetectorTechnology = DetectorTechnology::transitionEdgeSensor;
        attribute measuredQuantity : QuantityKind = QuantityKind::incidentRadiationEnergy;
        attribute minimumMeasurableEnergy : Energy = 1.0e-19 [J];
        attribute maximumMeasurableEnergy : Energy = 1.0e-15 [J];
        attribute nominalEnergyResolution : Energy = 8.0e-19 [J];
        attribute maximumPulseTemperatureRise : TemperatureChange = 1.7e-3 [K];

        connection incidentPath connect radiationIn to absorber.radiationIn;
        connection absorberToFilmThermalCoupling connect absorber.thermalOut to superconductingFilm.thermalIn;
        connection filmToThermalLink connect superconductingFilm.thermalIn to weakThermalLink.detectorSide;
        connection linkToBath connect weakThermalLink.bathSide to thermalBath;
        connection biasPath connect biasIn to superconductingFilm.biasIn;
        connection signalPath connect superconductingFilm.currentOut to signalOut;

        constraint maximumThermalPulse : ThermalPulseEquation {
            in depositedEnergy = maximumMeasurableEnergy;
            in heatCapacity = absorber.heatCapacity;
            in peakTemperatureRise = maximumPulseTemperatureRise;
        }

        perform action measureEnergy : MeasureIncidentRadiationEnergy;
    }

    part def VoltageBiasSource {
        port biasOut : BiasInputPort;
        port commandIn : CommandPort;
        port powerIn : PowerPort;

        attribute outputVoltage : ElectricVoltage = 3.0e-6 [V];
        attribute biasCurrent : ElectricCurrent = 8.0e-6 [A];
        attribute stability : DimensionlessRatio = 1.0e-5;
        attribute shuntResistance : ElectricalResistance = 3.0e-4 [Ohm];
    }

    part def SQUIDCurrentReadout {
        port signalIn : CurrentSignalOutputPort;
        port signalOut : CurrentSignalOutputPort;
        port powerIn : PowerPort;

        attribute inputCurrentNoiseRms : ElectricCurrent = 5.0e-9 [A];
        attribute bandwidth : Frequency = 1.0e6 [Hz];
        attribute transimpedanceGain : DimensionlessRatio = 1.0e5;
        attribute dynamicRange : ElectricCurrent = 5.0e-5 [A];
        attribute operatingTemperature : ThermodynamicTemperature = 4.0 [K];
    }

    part def AnalogToDigitalConverter {
        port analogIn : CurrentSignalOutputPort;
        port digitalOut : DigitalMeasurementPort;
        port powerIn : PowerPort;

        attribute resolution : DigitalCount = 18;
        attribute samplingFrequency : Frequency = 2.0e6 [Hz];
        attribute inputBandwidth : Frequency = 1.0e6 [Hz];
        attribute conversionLatency : Time = 5.0e-6 [s];
    }

    part def DigitalPulseProcessor {
        port measurementIn : DigitalMeasurementPort;
        port measurementOut : DigitalMeasurementPort;
        port commandIn : CommandPort;
        port statusOut : StatusPort;

        attribute filterType : String = "optimal matched pulse filter";
        attribute processingLatency : Time = 2.0e-3 [s];
        attribute baselineWindow : Time = 5.0e-3 [s];
        attribute maximumEventRate : Frequency = 1.0e3 [Hz];
        attribute calibrationReferenceEnergy : Energy = 9.6e-18 [J];

        perform action calibration : CalibrateWithReferencePulse;
    }

    part def CryogenicBath {
        port thermalInterface : ThermalPort;
        port powerIn : PowerPort;
        port statusOut : StatusPort;

        attribute bathTemperature : ThermodynamicTemperature = 7.5e-2 [K];
        attribute temperatureStability : TemperatureChange = 5.0e-5 [K];
        attribute coolingPower : Power = 1.0e-6 [W];
        attribute cooldownTime : Time = 1800.0 [s];
    }

    part def MagneticShield {
        attribute material : String = "superconducting niobium shield with mu-metal outer layer";
        attribute attenuationFactor : DimensionlessRatio = 1.0e5;
        attribute residualField : ScalarValues::Real = 1.0e-9;
    }

    part def VacuumHousing {
        port radiationAperture : RadiationInputPort;
        port powerFeedthrough : PowerPort;
        port commandFeedthrough : CommandPort;
        port dataFeedthrough : DigitalMeasurementPort;
        port statusFeedthrough : StatusPort;

        attribute internalPressure : ScalarValues::Real = 1.0e-6;
        attribute windowMaterial : String = "silicon nitride radiation window";
        attribute thermalLeak : Power = 2.0e-8 [W];
    }

    part def TransitionEdgeSensingUnit {
        port radiationIn : RadiationInputPort;
        port powerIn : PowerPort;
        port commandIn : CommandPort;
        port measurementOut : DigitalMeasurementPort;
        port statusOut : StatusPort;

        part housing : VacuumHousing;
        part tes : TransitionEdgeSensor;
        part biasSource : VoltageBiasSource;
        part squidReadout : SQUIDCurrentReadout;
        part adc : AnalogToDigitalConverter;
        part processor : DigitalPulseProcessor;
        part cryogenicBath : CryogenicBath;
        part magneticShield : MagneticShield;

        attribute measuredQuantity : QuantityKind = QuantityKind::incidentRadiationEnergy;
        attribute primarySensingTechnology : DetectorTechnology = DetectorTechnology::transitionEdgeSensor;
        attribute minimumEnergy : Energy = 1.0e-19 [J];
        attribute maximumEnergy : Energy = 1.0e-15 [J];
        attribute requiredEnergyResolution : Energy = 1.0e-18 [J];
        attribute outputLatency : Time = 2.5e-3 [s];
        attribute nominalOperatingTemperature : ThermodynamicTemperature = 9.0e-2 [K];
        attribute bathTemperature : ThermodynamicTemperature = 7.5e-2 [K];
        attribute health : HealthState = HealthState::nominal;

        connection externalRadiationToHousing connect radiationIn to housing.radiationAperture;
        connection housingToTesRadiationPath connect housing.radiationAperture to tes.radiationIn;

        connection externalPowerToHousing connect powerIn to housing.powerFeedthrough;
        connection powerToBias connect housing.powerFeedthrough to biasSource.powerIn;
        connection powerToReadout connect housing.powerFeedthrough to squidReadout.powerIn;
        connection powerToAdc connect housing.powerFeedthrough to adc.powerIn;
        connection powerToCryogenicBath connect housing.powerFeedthrough to cryogenicBath.powerIn;

        connection externalCommandToHousing connect commandIn to housing.commandFeedthrough;
        connection commandToBias connect housing.commandFeedthrough to biasSource.commandIn;
        connection commandToProcessor connect housing.commandFeedthrough to processor.commandIn;

        connection biasToTes connect biasSource.biasOut to tes.biasIn;
        connection tesSignalToSquid connect tes.signalOut to squidReadout.signalIn;
        connection squidToAdc connect squidReadout.signalOut to adc.analogIn;
        connection adcToProcessor connect adc.digitalOut to processor.measurementIn;
        connection processorToHousingData connect processor.measurementOut to housing.dataFeedthrough;
        connection housingDataToExternal connect housing.dataFeedthrough to measurementOut;

        connection tesThermalToBath connect tes.thermalBath to cryogenicBath.thermalInterface;

        connection cryostatStatusToHousing connect cryogenicBath.statusOut to housing.statusFeedthrough;
        connection processorStatusToExternal connect processor.statusOut to statusOut;
        connection housingStatusToExternal connect housing.statusFeedthrough to statusOut;

        perform state operatingStates : SensingUnitOperatingStates;
        perform action measure : MeasureIncidentRadiationEnergy;

        constraint measurementRange : EnergyMeasurementRange {
            in estimatedEnergy = measure.measurement.estimatedEnergy;
            in minimumEnergy = minimumEnergy;
            in maximumEnergy = maximumEnergy;
        }
    }

    requirement def UseTransitionEdgeSensorRequirement {
        subject unit : TransitionEdgeSensingUnit;
        require constraint { unit.primarySensingTechnology == DetectorTechnology::transitionEdgeSensor }
    }

    requirement def MeasureRelevantQuantityRequirement {
        subject unit : TransitionEdgeSensingUnit;
        require constraint { unit.measuredQuantity == QuantityKind::incidentRadiationEnergy }
    }

    requirement def EnergyRangeRequirement {
        subject unit : TransitionEdgeSensingUnit;
        require constraint { unit.minimumEnergy <= 1.0e-19 [J] and unit.maximumEnergy >= 1.0e-15 [J] }
    }

    requirement def EnergyResolutionRequirement {
        subject unit : TransitionEdgeSensingUnit;
        require constraint { unit.requiredEnergyResolution <= 1.0e-18 [J] }
    }

    requirement def CryogenicOperationRequirement {
        subject unit : TransitionEdgeSensingUnit;
        require constraint { unit.bathTemperature <= 8.0e-2 [K] and unit.nominalOperatingTemperature >= 8.95e-2 [K] and unit.nominalOperatingTemperature <= 9.05e-2 [K] }
    }

    requirement def DigitalOutputLatencyRequirement {
        subject unit : TransitionEdgeSensingUnit;
        require constraint { unit.outputLatency <= 1.0e-2 [s] }
    }

    requirement def SensingUnitRequirementSet {
        subject unit : TransitionEdgeSensingUnit;

        requirement useTES : UseTransitionEdgeSensorRequirement {
            subject unit = unit;
        }

        requirement measureEnergy : MeasureRelevantQuantityRequirement {
            subject unit = unit;
        }

        requirement range : EnergyRangeRequirement {
            subject unit = unit;
        }

        requirement resolution : EnergyResolutionRequirement {
            subject unit = unit;
        }

        requirement cryogenic : CryogenicOperationRequirement {
            subject unit = unit;
        }

        requirement latency : DigitalOutputLatencyRequirement {
            subject unit = unit;
        }
    }

    part tesSensingUnit : TransitionEdgeSensingUnit;

    requirement tesSensingUnitRequirements : SensingUnitRequirementSet {
        subject unit = tesSensingUnit;
    }

    satisfy tesSensingUnitRequirements.useTES by tesSensingUnit.tes;
    satisfy tesSensingUnitRequirements.measureEnergy by tesSensingUnit;
    satisfy tesSensingUnitRequirements.range by tesSensingUnit.tes;
    satisfy tesSensingUnitRequirements.resolution by tesSensingUnit.processor;
    satisfy tesSensingUnitRequirements.cryogenic by tesSensingUnit.cryogenicBath;
    satisfy tesSensingUnitRequirements.latency by tesSensingUnit.processor;
}
