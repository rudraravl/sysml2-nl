package IonizationChamberSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def ElectricCharge :> ISQ::electricCharge {
        unit = SI::coulomb;
    }

    attribute def ElectricCurrent :> ISQ::electricCurrent {
        unit = SI::ampere;
    }

    attribute def ElectricPotential :> ISQ::electricPotential {
        unit = SI::volt;
    }

    attribute def ElectricFieldStrength {
        :>> unit = SI::volt / SI::metre;
    }

    attribute def AbsorbedDoseRate {
        :>> unit = SI::gray / SI::second;
    }

    attribute def ExposureRate {
        :>> unit = SI::coulomb / SI::kilogram / SI::second;
    }

    attribute def GasPressure :> ISQ::pressure {
        unit = SI::pascal;
    }

    attribute def GasTemperature :> ISQ::thermodynamicTemperature {
        unit = SI::kelvin;
    }

    attribute def Length :> ISQ::length {
        unit = SI::metre;
    }

    attribute def Volume :> ISQ::volume {
        unit = SI::cubicMetre;
    }

    attribute def Resistance :> ISQ::resistance {
        unit = SI::ohm;
    }

    attribute def Capacitance :> ISQ::capacitance {
        unit = SI::farad;
    }

    attribute def ResponseTime :> ISQ::time {
        unit = SI::second;
    }

    enum def ChamberOperatingMode {
        enum standby;
        enum biasStabilization;
        enum measurement;
        enum saturationCheck;
        enum faultIsolation;
        enum calibration;
        enum shutdown;
    }

    enum def RadiationKind {
        enum alpha;
        enum beta;
        enum gamma;
        enum xRay;
        enum neutron;
        enum mixedField;
    }

    enum def FaultKind {
        enum none;
        enum highVoltageOutOfRange;
        enum electrometerSaturated;
        enum leakageCurrentHigh;
        enum pressureOutOfRange;
        enum temperatureOutOfRange;
        enum guardContinuityLost;
        enum chamberOpenCircuit;
    }

    item def IonizingRadiation {
        attribute kind : RadiationKind;
        attribute doseRate : AbsorbedDoseRate;
        attribute exposureRate : ExposureRate;
        attribute photonEnergy : ISQ::energy;
        attribute fieldUniformity : Real;
    }

    item def IonPairCloud {
        attribute positiveIonCharge : ElectricCharge;
        attribute electronCharge : ElectricCharge;
        attribute ionPairCount : Integer;
        attribute creationRate : Integer;
        attribute recombinationFraction : Real;
    }

    item def BiasPower {
        attribute voltage : ElectricPotential;
        attribute ripple : ElectricPotential;
        attribute currentLimit : ElectricCurrent;
    }

    item def ChamberCurrentSignal {
        attribute signalCurrent : ElectricCurrent;
        attribute leakageCurrent : ElectricCurrent;
        attribute compensatedCurrent : ElectricCurrent;
        attribute integrationInterval : ResponseTime;
    }

    item def DoseRateEstimate {
        attribute measuredDoseRate : AbsorbedDoseRate;
        attribute uncertaintyFraction : Real;
        attribute timestamp : ISQ::time;
        attribute valid : Boolean;
    }

    item def EnvironmentalCondition {
        attribute pressure : GasPressure;
        attribute temperature : GasTemperature;
        attribute humidityFraction : Real;
    }

    item def DiagnosticStatus {
        attribute fault : FaultKind;
        attribute healthy : Boolean;
        attribute messageCode : Integer;
    }

    port def RadiationInputPort {
        in radiation : IonizingRadiation;
    }

    port def GasConditionPort {
        in environment : EnvironmentalCondition;
    }

    port def BiasSupplyPort {
        in biasPower : BiasPower;
    }

    port def IonCollectionPort {
        out ionCloud : IonPairCloud;
    }

    port def CurrentSignalPort {
        out currentSignal : ChamberCurrentSignal;
    }

    port def DoseOutputPort {
        out doseRate : DoseRateEstimate;
    }

    port def DiagnosticPort {
        out status : DiagnosticStatus;
    }

    port def ControlPort {
        in enableMeasurement : Boolean;
        in requestCalibration : Boolean;
        in requestShutdown : Boolean;
    }

    part def GasFilledSensitiveVolume {
        attribute activeVolume : Volume = 8.0e-4 [SI::cubicMetre];
        attribute electrodeSpacing : Length = 0.012 [SI::metre];
        attribute fillPressure : GasPressure = 101325 [SI::pascal];
        attribute fillTemperature : GasTemperature = 293.15 [SI::kelvin];
        attribute recombinationLimitFraction : Real = 0.01;

        port radiationIn : RadiationInputPort;
        port environmentIn : GasConditionPort;
        port ionPairsOut : IonCollectionPort;

        action ionizeGas {
            in radiation : IonizingRadiation;
            in environment : EnvironmentalCondition;
            out ionCloud : IonPairCloud;

            first start;
            then computeIonPairRate;
            then compensateGasDensity;
            then produceIonPairCloud;
            then done;

            action computeIonPairRate;
            action compensateGasDensity;
            action produceIonPairCloud;
        }
    }

    part def ElectrodeAssembly {
        attribute collectingElectrodeArea : ISQ::area = 0.018 [SI::squareMetre];
        attribute guardRingResistance : Resistance = 1.0e12 [SI::ohm];
        attribute nominalFieldStrength : ElectricFieldStrength = 41667 [SI::volt / SI::metre];
        attribute plateCapacitance : Capacitance = 22.0e-12 [SI::farad];

        port biasIn : BiasSupplyPort;
        port ionPairsIn : IonCollectionPort;
        port currentOut : CurrentSignalPort;

        action collectCharge {
            in ionCloud : IonPairCloud;
            in biasPower : BiasPower;
            out currentSignal : ChamberCurrentSignal;

            first start;
            then driftElectronsAndIons;
            then suppressRecombination;
            then sumCollectedCharge;
            then outputCurrent;
            then done;

            action driftElectronsAndIons;
            action suppressRecombination;
            action sumCollectedCharge;
            action outputCurrent;
        }
    }

    part def HighVoltageBiasSupply {
        attribute commandedVoltage : ElectricPotential = 500 [SI::volt];
        attribute allowableVoltageLow : ElectricPotential = 475 [SI::volt];
        attribute allowableVoltageHigh : ElectricPotential = 525 [SI::volt];
        attribute maximumOutputCurrent : ElectricCurrent = 5.0e-6 [SI::ampere];
        attribute voltageRippleLimit : ElectricPotential = 0.25 [SI::volt];

        port controlIn : ControlPort;
        port biasOut : BiasSupplyPort;
        port diagnosticsOut : DiagnosticPort;

        state def BiasSupplyStateMachine {
            state off;
            state ramping;
            state regulated;
            state faulted;

            initial then off;

            transition off_to_ramping
                first off
                accept enableMeasurement
                then ramping;

            transition ramping_to_regulated
                first ramping
                if commandedVoltage >= allowableVoltageLow and commandedVoltage <= allowableVoltageHigh
                then regulated;

            transition regulated_to_faulted
                first regulated
                if commandedVoltage < allowableVoltageLow or commandedVoltage > allowableVoltageHigh
                then faulted;

            transition regulated_to_off
                first regulated
                accept requestShutdown
                then off;

            transition faulted_to_off
                first faulted
                accept requestShutdown
                then off;
        }
    }

    part def LowNoiseElectrometer {
        attribute inputBiasCurrent : ElectricCurrent = 2.0e-15 [SI::ampere];
        attribute currentNoiseDensity : ElectricCurrent = 1.0e-15 [SI::ampere];
        attribute fullScaleCurrent : ElectricCurrent = 1.0e-8 [SI::ampere];
        attribute integrationTime : ResponseTime = 1.0 [SI::second];
        attribute leakageCurrentLimit : ElectricCurrent = 5.0e-14 [SI::ampere];

        port currentIn : CurrentSignalPort;
        port diagnosticsOut : DiagnosticPort;
        port doseSignalOut : DoseOutputPort;

        action convertCurrentToDoseRate {
            in currentSignal : ChamberCurrentSignal;
            out doseRate : DoseRateEstimate;

            first start;
            then subtractLeakageCurrent;
            then applyCalibrationFactor;
            then estimateUncertainty;
            then validateRange;
            then done;

            action subtractLeakageCurrent;
            action applyCalibrationFactor;
            action estimateUncertainty;
            action validateRange;
        }
    }

    part def EnvironmentalCompensator {
        attribute referencePressure : GasPressure = 101325 [SI::pascal];
        attribute referenceTemperature : GasTemperature = 293.15 [SI::kelvin];
        attribute minimumPressure : GasPressure = 85000 [SI::pascal];
        attribute maximumPressure : GasPressure = 110000 [SI::pascal];
        attribute minimumTemperature : GasTemperature = 273.15 [SI::kelvin];
        attribute maximumTemperature : GasTemperature = 323.15 [SI::kelvin];

        port environmentIn : GasConditionPort;
        port diagnosticsOut : DiagnosticPort;

        action computeDensityCorrection {
            in environment : EnvironmentalCondition;
            out correctionFactor : Real;

            first start;
            then readPressure;
            then readTemperature;
            then calculatePressureTemperatureRatio;
            then done;

            action readPressure;
            action readTemperature;
            action calculatePressureTemperatureRatio;
        }
    }

    part def CalibrationManager {
        attribute nominalCalibrationFactor : Real = 3.60e7;
        attribute calibrationUncertaintyFraction : Real = 0.025;
        attribute calibrationInterval : ISQ::time = 31557600 [SI::second];
        attribute lastCalibrationAge : ISQ::time;

        port controlIn : ControlPort;
        port diagnosticsOut : DiagnosticPort;

        action performCalibrationCheck {
            first start;
            then applyReferenceRadiation;
            then measureReferenceCurrent;
            then compareWithExpectedResponse;
            then updateCalibrationStatus;
            then done;

            action applyReferenceRadiation;
            action measureReferenceCurrent;
            action compareWithExpectedResponse;
            action updateCalibrationStatus;
        }
    }

    part def IonizationChamberSystem {
        attribute primaryFunction : String = "Measure ionizing radiation by converting ion-pair charge produced in a gas-filled volume into a compensated electrical current and reporting dose rate.";
        attribute operatingMode : ChamberOperatingMode;
        attribute systemResponseTime : ResponseTime = 1.5 [SI::second];
        attribute minimumMeasurableCurrent : ElectricCurrent = 1.0e-14 [SI::ampere];
        attribute maximumMeasurableCurrent : ElectricCurrent = 1.0e-8 [SI::ampere];

        port radiationInput : RadiationInputPort;
        port environmentInput : GasConditionPort;
        port controlInput : ControlPort;
        port doseRateOutput : DoseOutputPort;
        port diagnosticOutput : DiagnosticPort;

        part sensitiveVolume : GasFilledSensitiveVolume;
        part electrodes : ElectrodeAssembly;
        part biasSupply : HighVoltageBiasSupply;
        part electrometer : LowNoiseElectrometer;
        part compensator : EnvironmentalCompensator;
        part calibrationManager : CalibrationManager;

        connect radiationInput to sensitiveVolume.radiationIn;
        connect environmentInput to sensitiveVolume.environmentIn;
        connect environmentInput to compensator.environmentIn;
        connect controlInput to biasSupply.controlIn;
        connect controlInput to calibrationManager.controlIn;
        connect biasSupply.biasOut to electrodes.biasIn;
        connect sensitiveVolume.ionPairsOut to electrodes.ionPairsIn;
        connect electrodes.currentOut to electrometer.currentIn;
        connect electrometer.doseSignalOut to doseRateOutput;
        connect biasSupply.diagnosticsOut to diagnosticOutput;
        connect electrometer.diagnosticsOut to diagnosticOutput;
        connect compensator.diagnosticsOut to diagnosticOutput;
        connect calibrationManager.diagnosticsOut to diagnosticOutput;

        state def ChamberSystemStateMachine {
            state unpowered;
            state standby;
            state biasStabilization;
            state measuring;
            state calibration;
            state fault;
            state shutdown;

            initial then unpowered;

            transition powerApplied
                first unpowered
                then standby;

            transition startMeasurement
                first standby
                accept enableMeasurement
                then biasStabilization;

            transition biasReady
                first biasStabilization
                if biasSupply.commandedVoltage >= biasSupply.allowableVoltageLow and biasSupply.commandedVoltage <= biasSupply.allowableVoltageHigh
                then measuring;

            transition requestCalibrationMode
                first standby
                accept requestCalibration
                then calibration;

            transition calibrationComplete
                first calibration
                then standby;

            transition measurementFault
                first measuring
                if electrometer.inputBiasCurrent > electrometer.leakageCurrentLimit
                then fault;

            transition environmentFault
                first measuring
                if compensator.referencePressure < compensator.minimumPressure or compensator.referencePressure > compensator.maximumPressure
                then fault;

            transition shutdownFromStandby
                first standby
                accept requestShutdown
                then shutdown;

            transition shutdownFromMeasurement
                first measuring
                accept requestShutdown
                then shutdown;

            transition shutdownComplete
                first shutdown
                then unpowered;
        }

        action measureIonizingRadiation {
            in radiation : IonizingRadiation;
            in environment : EnvironmentalCondition;
            out doseRate : DoseRateEstimate;
            out status : DiagnosticStatus;

            first receiveRadiation;
            then generateIonPairs;
            then applyElectricField;
            then collectCharge;
            then measureCurrent;
            then compensateForEnvironment;
            then calculateDoseRate;
            then reportResult;
            then done;

            action receiveRadiation;
            action generateIonPairs;
            action applyElectricField;
            action collectCharge;
            action measureCurrent;
            action compensateForEnvironment;
            action calculateDoseRate;
            action reportResult;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject chamberSystem : IonizationChamberSystem;

        doc /* The ionization chamber system shall detect ionizing radiation entering the sensitive gas volume, separate and collect the generated ion pairs using an applied electric field, convert the collected charge into a low-noise current measurement, compensate the result for environmental conditions, and output a dose-rate estimate. */
    }

    requirement def SaturationRegionRequirement {
        subject chamberSystem : IonizationChamberSystem;

        doc /* The chamber shall operate with bias voltage sufficient to maintain the ion recombination fraction at or below 0.01 during normal measurement. */
    }

    requirement def MeasurementRangeRequirement {
        subject chamberSystem : IonizationChamberSystem;

        doc /* The electrometer shall measure compensated chamber current from 1.0e-14 ampere to 1.0e-8 ampere without saturation during normal operation. */
    }

    requirement def BiasStabilityRequirement {
        subject chamberSystem : IonizationChamberSystem;

        doc /* The high-voltage bias supply shall regulate electrode bias between 475 volt and 525 volt with ripple no greater than 0.25 volt during measurement. */
    }

    requirement def EnvironmentalCompensationRequirement {
        subject chamberSystem : IonizationChamberSystem;

        doc /* The system shall compensate dose-rate output for gas pressure and temperature relative to 101325 pascal and 293.15 kelvin. */
    }

    requirement def DiagnosticRequirement {
        subject chamberSystem : IonizationChamberSystem;

        doc /* The system shall report diagnostic status for high-voltage faults, electrometer saturation, excessive leakage current, environmental range faults, guard continuity loss, and chamber open-circuit faults. */
    }

    requirement def ResponseTimeRequirement {
        subject chamberSystem : IonizationChamberSystem;

        doc /* The system shall produce a valid dose-rate output within 1.5 second after stable radiation exposure and valid operating conditions are established. */
    }

    requirement def CalibrationRequirement {
        subject chamberSystem : IonizationChamberSystem;

        doc /* The system shall support calibration verification using a known reference radiation field and maintain calibration uncertainty no greater than 0.025 fractional uncertainty. */
    }

    satisfy PrimaryFunctionRequirement by IonizationChamberSystem;
    satisfy SaturationRegionRequirement by IonizationChamberSystem::electrodes;
    satisfy MeasurementRangeRequirement by IonizationChamberSystem::electrometer;
    satisfy BiasStabilityRequirement by IonizationChamberSystem::biasSupply;
    satisfy EnvironmentalCompensationRequirement by IonizationChamberSystem::compensator;
    satisfy DiagnosticRequirement by IonizationChamberSystem;
    satisfy ResponseTimeRequirement by IonizationChamberSystem;
    satisfy CalibrationRequirement by IonizationChamberSystem::calibrationManager;
}