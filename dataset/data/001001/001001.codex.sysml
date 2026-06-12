package CapacitiveDisplacementSensingUnit {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Length :> ISQ::length {
        unit = SI::metre;
    }

    attribute def GapDistance :> Length {
        doc /* Separation between sensing electrode and conductive target. */
    }

    attribute def Capacitance :> ISQ::capacitance {
        unit = SI::farad;
    }

    attribute def Voltage :> ISQ::electricPotential {
        unit = SI::volt;
    }

    attribute def Current :> ISQ::electricCurrent {
        unit = SI::ampere;
    }

    attribute def Frequency :> ISQ::frequency {
        unit = SI::hertz;
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = SI::kelvin;
    }

    attribute def TimeInterval :> ISQ::time {
        unit = SI::second;
    }

    attribute def Resolution :> Length {
        doc /* Smallest displacement increment resolved by the unit. */
    }

    attribute def LinearityError {
        :>> scalar : Real;
        doc /* Percent of full-scale displacement span. */
    }

    attribute def SignalToNoiseRatio {
        :>> scalar : Real;
        doc /* Ratio in decibels. */
    }

    attribute def DigitalCount {
        :>> scalar : Integer;
    }

    attribute def DisplacementEstimate :> Length {
        doc /* Computed displacement relative to calibrated zero position. */
    }

    item def MechanicalGap {
        attribute distance : GapDistance;
        attribute targetArea : ISQ::area;
        attribute dielectricRelativePermittivity : Real;
        attribute temperature : Temperature;
    }

    item def ElectrodeExcitation {
        attribute amplitude : Voltage;
        attribute frequency : Frequency;
        attribute phase : Real;
    }

    item def SenseCurrent {
        attribute rmsCurrent : Current;
        attribute frequency : Frequency;
        attribute phase : Real;
    }

    item def CapacitanceMeasurement {
        attribute measuredCapacitance : Capacitance;
        attribute parasiticCompensatedCapacitance : Capacitance;
        attribute acquisitionTime : TimeInterval;
        attribute temperatureAtMeasurement : Temperature;
    }

    item def DisplacementSample {
        attribute displacement : DisplacementEstimate;
        attribute capacitance : Capacitance;
        attribute timestamp : TimeInterval;
        attribute validity : Boolean;
    }

    item def DiagnosticReport {
        attribute sensorConnected : Boolean;
        attribute excitationStable : Boolean;
        attribute adcSaturated : Boolean;
        attribute temperatureInRange : Boolean;
        attribute calibrationValid : Boolean;
        attribute faultCode : DigitalCount;
    }

    port def MechanicalGapPort {
        in item gap : MechanicalGap;
    }

    port def ExcitationPort {
        out item excitation : ElectrodeExcitation;
    }

    port def SenseSignalPort {
        in item current : SenseCurrent;
    }

    port def CapacitanceDataPort {
        out item capacitanceData : CapacitanceMeasurement;
    }

    port def DisplacementDataPort {
        out item sample : DisplacementSample;
    }

    port def DiagnosticPort {
        out item report : DiagnosticReport;
    }

    port def PowerPort {
        in item supplyVoltage : Voltage;
        in item supplyCurrent : Current;
    }

    port def DigitalCommandPort {
        in item startMeasurement : Boolean;
        in item zeroCalibrationCommand : Boolean;
        in item selfTestCommand : Boolean;
    }

    part def GuardRing {
        attribute drivenVoltage : Voltage;
        attribute shieldLeakageCurrent : Current;
        port excitationIn : ExcitationPort;
    }

    part def CapacitiveProbe {
        attribute electrodeArea : ISQ::area = 2.5e-4 [SI::metre^2];
        attribute nominalGap : GapDistance = 1.0e-3 [SI::metre];
        attribute nominalCapacitance : Capacitance = 2.2e-12 [SI::farad];
        attribute parasiticCapacitance : Capacitance = 0.8e-12 [SI::farad];
        attribute maximumGap : GapDistance = 2.0e-3 [SI::metre];
        attribute minimumGap : GapDistance = 0.1e-3 [SI::metre];

        port measuredGap : MechanicalGapPort;
        port excitationIn : ExcitationPort;
        port senseOut : SenseSignalPort;

        part guard : GuardRing;

        connect excitationIn to guard.excitationIn;
    }

    part def OscillatorExcitationSource {
        attribute excitationAmplitude : Voltage = 5.0 [SI::volt];
        attribute excitationFrequency : Frequency = 100.0e3 [SI::hertz];
        attribute amplitudeTolerance : Real = 0.005;
        attribute frequencyTolerance : Real = 0.001;

        port excitationOut : ExcitationPort;
        port powerIn : PowerPort;
    }

    part def ChargeAmplifier {
        attribute feedbackCapacitance : Capacitance = 10.0e-12 [SI::farad];
        attribute feedbackResistance : Real = 10.0e6;
        attribute inputBiasCurrent : Current = 5.0e-12 [SI::ampere];
        attribute outputNoise : Voltage = 50.0e-6 [SI::volt];

        port senseIn : SenseSignalPort;
        port analogVoltageOut : CapacitanceDataPort;
        port powerIn : PowerPort;
    }

    part def DemodulatorAndFilter {
        attribute lowPassCutoff : Frequency = 500.0 [SI::hertz];
        attribute settlingTime : TimeInterval = 0.010 [SI::second];
        attribute rippleVoltage : Voltage = 1.0e-3 [SI::volt];

        port capacitanceIn : CapacitanceDataPort;
        port capacitanceOut : CapacitanceDataPort;
    }

    part def TemperatureSensor {
        attribute measurementRangeMin : Temperature = 253.15 [SI::kelvin];
        attribute measurementRangeMax : Temperature = 358.15 [SI::kelvin];
        attribute accuracy : Temperature = 0.5 [SI::kelvin];

        port powerIn : PowerPort;
        port diagnosticOut : DiagnosticPort;
    }

    part def AnalogToDigitalConverter {
        attribute resolutionBits : DigitalCount = 24;
        attribute sampleRate : Frequency = 2000.0 [SI::hertz];
        attribute referenceVoltage : Voltage = 4.096 [SI::volt];
        attribute inputRange : Voltage = 4.096 [SI::volt];

        port analogIn : CapacitanceDataPort;
        port digitalOut : CapacitanceDataPort;
        port powerIn : PowerPort;
    }

    part def SignalProcessor {
        attribute zeroOffsetCapacitance : Capacitance = 2.2e-12 [SI::farad];
        attribute scaleFactor : Real = -4.55e8;
        attribute fullScaleRange : Length = 1.9e-3 [SI::metre];
        attribute updatePeriod : TimeInterval = 0.001 [SI::second];
        attribute configuredResolution : Resolution = 20.0e-9 [SI::metre];

        port capacitanceIn : CapacitanceDataPort;
        port commands : DigitalCommandPort;
        port displacementOut : DisplacementDataPort;
        port diagnosticsOut : DiagnosticPort;
    }

    part def PowerConditioner {
        attribute inputVoltageNominal : Voltage = 24.0 [SI::volt];
        attribute regulatedAnalogVoltage : Voltage = 5.0 [SI::volt];
        attribute regulatedDigitalVoltage : Voltage = 3.3 [SI::volt];
        attribute maximumSupplyCurrent : Current = 0.150 [SI::ampere];

        port externalPower : PowerPort;
        port conditionedPower : PowerPort;
    }

    action def AcquireCapacitance {
        in item gap : MechanicalGap;
        in item excitation : ElectrodeExcitation;
        out item measurement : CapacitanceMeasurement;

        attribute epsilon0 : Real = 8.8541878128e-12;
        attribute parasitic : Capacitance = 0.8e-12 [SI::farad];

        objective {
            doc /* Convert target displacement into a compensated capacitance measurement by exciting the electrode and measuring displacement-dependent charge current. */
        }
    }

    action def ConvertCapacitanceToDisplacement {
        in item measurement : CapacitanceMeasurement;
        out item sample : DisplacementSample;

        attribute zeroCapacitance : Capacitance = 2.2e-12 [SI::farad];
        attribute sensitivity : Real = -4.55e8;

        objective {
            doc /* Compute displacement estimate from calibrated inverse capacitance response and mark sample invalid when input is out of calibrated range. */
        }
    }

    action def PerformZeroCalibration {
        in item measurement : CapacitanceMeasurement;
        out item zeroOffset : Capacitance;

        objective {
            doc /* Store the present compensated capacitance as the zero displacement reference when the target is held at the mechanical datum. */
        }
    }

    state def MeasurementController {
        state off;
        state initializing;
        state selfTesting;
        state idle;
        state measuring;
        state calibratingZero;
        state fault;

        transition first off then initializing;

        transition initializing then selfTesting
            accept after 0.100 [SI::second];

        transition selfTesting then idle
            if diagnosticsOk;

        transition selfTesting then fault
            if not diagnosticsOk;

        transition idle then measuring
            accept startMeasurement;

        transition measuring then idle
            accept not startMeasurement;

        transition idle then calibratingZero
            accept zeroCalibrationCommand;

        transition calibratingZero then idle
            accept after 0.050 [SI::second];

        transition idle then selfTesting
            accept selfTestCommand;

        transition measuring then fault
            if adcSaturated or not excitationStable or not sensorConnected;

        transition fault then selfTesting
            accept selfTestCommand;
    }

    part def CapacitiveDisplacementSensingUnit {
        attribute measurementRangeMin : Length = 0.1e-3 [SI::metre];
        attribute measurementRangeMax : Length = 2.0e-3 [SI::metre];
        attribute displacementResolution : Resolution = 20.0e-9 [SI::metre];
        attribute maximumLinearityError : LinearityError = 0.5;
        attribute minimumSignalToNoiseRatio : SignalToNoiseRatio = 60.0;
        attribute updateRate : Frequency = 1000.0 [SI::hertz];
        attribute operatingTemperatureMin : Temperature = 253.15 [SI::kelvin];
        attribute operatingTemperatureMax : Temperature = 358.15 [SI::kelvin];

        port targetGapIn : MechanicalGapPort;
        port powerIn : PowerPort;
        port commandIn : DigitalCommandPort;
        port displacementOut : DisplacementDataPort;
        port diagnosticOut : DiagnosticPort;

        part power : PowerConditioner;
        part excitation : OscillatorExcitationSource;
        part probe : CapacitiveProbe;
        part amplifier : ChargeAmplifier;
        part demodulator : DemodulatorAndFilter;
        part adc : AnalogToDigitalConverter;
        part temperatureSensor : TemperatureSensor;
        part processor : SignalProcessor;

        perform action acquire : AcquireCapacitance;
        perform action convert : ConvertCapacitanceToDisplacement;
        perform action zeroCal : PerformZeroCalibration;

        exhibit state controller : MeasurementController;

        connect powerIn to power.externalPower;
        connect power.conditionedPower to excitation.powerIn;
        connect power.conditionedPower to amplifier.powerIn;
        connect power.conditionedPower to adc.powerIn;
        connect power.conditionedPower to temperatureSensor.powerIn;

        connect targetGapIn to probe.measuredGap;
        connect excitation.excitationOut to probe.excitationIn;
        connect probe.senseOut to amplifier.senseIn;
        connect amplifier.analogVoltageOut to demodulator.capacitanceIn;
        connect demodulator.capacitanceOut to adc.analogIn;
        connect adc.digitalOut to processor.capacitanceIn;
        connect commandIn to processor.commands;
        connect processor.displacementOut to displacementOut;
        connect processor.diagnosticsOut to diagnosticOut;
        connect temperatureSensor.diagnosticOut to diagnosticOut;
    }

    requirement def MeasureDisplacementRequirement {
        subject unit : CapacitiveDisplacementSensingUnit;

        require constraint {
            unit.measurementRangeMin <= unit.targetGapIn.gap.distance and
            unit.targetGapIn.gap.distance <= unit.measurementRangeMax
        }

        doc /* The sensing unit shall measure target displacement over the calibrated capacitive probe gap range. */
    }

    requirement def ResolutionRequirement {
        subject unit : CapacitiveDisplacementSensingUnit;

        require constraint {
            unit.displacementResolution <= 20.0e-9 [SI::metre]
        }

        doc /* The sensing unit shall resolve displacement changes of 20 nm or smaller. */
    }

    requirement def UpdateRateRequirement {
        subject unit : CapacitiveDisplacementSensingUnit;

        require constraint {
            unit.updateRate >= 1000.0 [SI::hertz]
        }

        doc /* The sensing unit shall publish displacement samples at no less than 1 kHz during measurement mode. */
    }

    requirement def LinearityRequirement {
        subject unit : CapacitiveDisplacementSensingUnit;

        require constraint {
            unit.maximumLinearityError <= 0.5
        }

        doc /* The sensing unit shall limit linearity error to 0.5 percent of full scale after calibration. */
    }

    requirement def ExcitationStabilityRequirement {
        subject source : OscillatorExcitationSource;

        require constraint {
            source.excitationAmplitude == 5.0 [SI::volt] and
            source.excitationFrequency == 100.0e3 [SI::hertz] and
            source.amplitudeTolerance <= 0.005 and
            source.frequencyTolerance <= 0.001
        }

        doc /* The excitation source shall provide stable sinusoidal drive for capacitance measurement. */
    }

    requirement def TemperatureOperatingRequirement {
        subject unit : CapacitiveDisplacementSensingUnit;

        require constraint {
            unit.operatingTemperatureMin <= unit.targetGapIn.gap.temperature and
            unit.targetGapIn.gap.temperature <= unit.operatingTemperatureMax
        }

        doc /* The sensing unit shall operate across the specified industrial temperature range. */
    }

    requirement def DiagnosticsRequirement {
        subject unit : CapacitiveDisplacementSensingUnit;

        require constraint {
            unit.diagnosticOut.report.sensorConnected and
            unit.diagnosticOut.report.excitationStable and
            not unit.diagnosticOut.report.adcSaturated and
            unit.diagnosticOut.report.temperatureInRange and
            unit.diagnosticOut.report.calibrationValid
        }

        doc /* The sensing unit shall report sensor connection, excitation stability, ADC saturation, temperature validity, and calibration validity. */
    }

    requirement def PowerRequirement {
        subject unit : CapacitiveDisplacementSensingUnit;

        require constraint {
            unit.powerIn.supplyVoltage == 24.0 [SI::volt] and
            unit.powerIn.supplyCurrent <= 0.150 [SI::ampere]
        }

        doc /* The sensing unit shall operate from a 24 V supply and draw no more than 150 mA. */
    }

    satisfy MeasureDisplacementRequirement by CapacitiveDisplacementSensingUnit;
    satisfy ResolutionRequirement by CapacitiveDisplacementSensingUnit;
    satisfy UpdateRateRequirement by CapacitiveDisplacementSensingUnit;
    satisfy LinearityRequirement by CapacitiveDisplacementSensingUnit;
    satisfy TemperatureOperatingRequirement by CapacitiveDisplacementSensingUnit;
    satisfy DiagnosticsRequirement by CapacitiveDisplacementSensingUnit;
    satisfy PowerRequirement by CapacitiveDisplacementSensingUnit;
    satisfy ExcitationStabilityRequirement by OscillatorExcitationSource;

}