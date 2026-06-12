package PiraniGaugeSystemModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def ElectricPotential :> ISQ::electricPotential {
        unit = V;
    }

    attribute def ElectricCurrent :> ISQ::electricCurrent {
        unit = A;
    }

    attribute def ElectricResistance :> ISQ::electricResistance {
        unit = Ohm;
    }

    attribute def Power :> ISQ::power {
        unit = W;
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = K;
    }

    attribute def Pressure :> ISQ::pressure {
        unit = Pa;
    }

    attribute def Time :> ISQ::time {
        unit = s;
    }

    attribute def HeatTransferCoefficient {
        :>> scalarType = Real;
        unit = W/(m^2*K);
    }

    attribute def DigitalCount {
        :>> scalarType = Integer;
    }

    attribute def CalibrationCoefficient {
        :>> scalarType = Real;
    }

    item def GasSample {
        attribute pressure : Pressure;
        attribute gasTemperature : Temperature;
        attribute gasComposition : String;
        attribute thermalConductivity : Real;
    }

    item def ElectricalPower {
        attribute voltage : ElectricPotential;
        attribute current : ElectricCurrent;
        attribute frequency : Real;
    }

    item def ResistanceSignal {
        attribute resistance : ElectricResistance;
        attribute bridgeVoltage : ElectricPotential;
        attribute sensorTemperature : Temperature;
    }

    item def PressureMeasurement {
        attribute pressure : Pressure;
        attribute uncertainty : Pressure;
        attribute valid : Boolean;
        attribute timestamp : Time;
    }

    item def DiagnosticStatus {
        attribute healthy : Boolean;
        attribute overTemperature : Boolean;
        attribute filamentOpenCircuit : Boolean;
        attribute pressureOutOfRange : Boolean;
        attribute calibrationDue : Boolean;
    }

    port def GasExposurePort {
        in item gas : GasSample;
    }

    port def PowerInputPort {
        in item supply : ElectricalPower;
    }

    port def AnalogSignalPort {
        out item signal : ResistanceSignal;
    }

    port def MeasurementOutputPort {
        out item measurement : PressureMeasurement;
    }

    port def DiagnosticOutputPort {
        out item status : DiagnosticStatus;
    }

    port def ThermalCouplingPort {
        inout item gas : GasSample;
    }

    part def PiraniGaugeSystem {
        attribute primaryFunction : String = "Measure low vacuum pressure by heating a filament and inferring gas pressure from pressure-dependent heat loss to the surrounding gas.";
        attribute minimumMeasurablePressure : Pressure = 0.1 [Pa];
        attribute maximumMeasurablePressure : Pressure = 100000 [Pa];
        attribute nominalSupplyVoltage : ElectricPotential = 24 [V];
        attribute updatePeriod : Time = 0.1 [s];

        port gasIn : GasExposurePort;
        port powerIn : PowerInputPort;
        port pressureOut : MeasurementOutputPort;
        port diagnosticsOut : DiagnosticOutputPort;

        part sensingCell : SensingCell;
        part heaterControl : ConstantTemperatureController;
        part bridgeCircuit : WheatstoneBridge;
        part signalConditioner : SignalConditioner;
        part pressureEstimator : PressureEstimator;
        part diagnostics : GaugeDiagnostics;
        part housing : VacuumCompatibleHousing;

        connect gasIn to sensingCell.gasPort;
        connect powerIn to heaterControl.powerPort;
        connect heaterControl.heaterDrive to sensingCell.heaterPort;
        connect sensingCell.resistancePort to bridgeCircuit.sensorInput;
        connect bridgeCircuit.bridgeOutput to signalConditioner.rawSignalInput;
        connect signalConditioner.conditionedOutput to pressureEstimator.resistanceInput;
        connect pressureEstimator.measurementOutput to pressureOut;
        connect sensingCell.healthOutput to diagnostics.sensorHealthInput;
        connect pressureEstimator.measurementOutput to diagnostics.measurementInput;
        connect diagnostics.statusOutput to diagnosticsOut;
        connect housing.processGasInterface to sensingCell.gasPort;

        perform action initializeGauge;
        perform action regulateFilamentTemperature;
        perform action estimatePressure;
        exhibit state gaugeOperationalStates;
    }

    part def SensingCell {
        attribute filamentMaterial : String = "tungsten";
        attribute filamentNominalResistance : ElectricResistance = 120 [Ohm];
        attribute filamentReferenceTemperature : Temperature = 293.15 [K];
        attribute operatingFilamentTemperature : Temperature = 423.15 [K];
        attribute maximumFilamentTemperature : Temperature = 473.15 [K];
        attribute gasHeatTransferCoefficient : HeatTransferCoefficient;
        attribute filamentPower : Power;

        port gasPort : GasExposurePort;
        port heaterPort {
            in item heaterPower : ElectricalPower;
        }
        port resistancePort : AnalogSignalPort;
        port healthOutput : DiagnosticOutputPort;

        part heatedFilament : HeatedFilament;
        part thermalPathToGas : GasThermalPath;
        part sensorEnvelope : VacuumEnvelope;

        connect gasPort to thermalPathToGas.gasCoupling;
        connect heaterPort to heatedFilament.electricalInput;
        connect heatedFilament.thermalInterface to thermalPathToGas.filamentCoupling;
        connect heatedFilament.resistanceOutput to resistancePort;
    }

    part def HeatedFilament {
        attribute material : String = "tungsten";
        attribute resistanceAtReference : ElectricResistance = 120 [Ohm];
        attribute temperatureCoefficientOfResistance : Real = 0.0045;
        attribute temperature : Temperature;
        attribute resistance : ElectricResistance;
        attribute dissipatedPower : Power;

        port electricalInput {
            in item heaterPower : ElectricalPower;
        }
        port thermalInterface : ThermalCouplingPort;
        port resistanceOutput : AnalogSignalPort;

        action updateResistance {
            in attribute measuredBridgeVoltage : ElectricPotential;
            out attribute calculatedResistance : ElectricResistance;
            out attribute calculatedTemperature : Temperature;
        }
    }

    part def GasThermalPath {
        attribute effectiveArea : Real = 0.00003;
        attribute accommodationCoefficient : Real = 0.85;
        attribute heatLossToGas : Power;

        port gasCoupling : GasExposurePort;
        port filamentCoupling : ThermalCouplingPort;

        action computeHeatLoss {
            in attribute filamentTemperature : Temperature;
            in attribute gasTemperature : Temperature;
            in attribute gasPressure : Pressure;
            out attribute heatLoss : Power;
        }
    }

    part def VacuumEnvelope {
        attribute internalVolume : Real = 0.00001;
        attribute leakRate : Real = 1.0e-10;
        attribute material : String = "stainless steel";
    }

    part def ConstantTemperatureController {
        attribute targetTemperature : Temperature = 423.15 [K];
        attribute proportionalGain : Real = 0.8;
        attribute integralGain : Real = 0.15;
        attribute maximumHeaterPower : Power = 2.5 [W];
        attribute minimumHeaterPower : Power = 0.0 [W];

        port powerPort : PowerInputPort;
        port heaterDrive {
            out item heaterPower : ElectricalPower;
        }

        action regulate {
            in attribute measuredFilamentTemperature : Temperature;
            out attribute commandedVoltage : ElectricPotential;
            out attribute commandedCurrent : ElectricCurrent;
        }
    }

    part def WheatstoneBridge {
        attribute referenceResistance1 : ElectricResistance = 120 [Ohm];
        attribute referenceResistance2 : ElectricResistance = 120 [Ohm];
        attribute trimResistance : ElectricResistance = 10 [Ohm];
        attribute excitationVoltage : ElectricPotential = 5 [V];

        port sensorInput : AnalogSignalPort;
        port bridgeOutput {
            out item signal : ResistanceSignal;
        }

        action measureBridgeImbalance {
            in attribute sensorResistance : ElectricResistance;
            out attribute bridgeVoltage : ElectricPotential;
        }
    }

    part def SignalConditioner {
        attribute amplifierGain : Real = 100.0;
        attribute adcResolution : DigitalCount = 4096;
        attribute lowPassCutoffFrequency : Real = 10.0;

        port rawSignalInput {
            in item signal : ResistanceSignal;
        }
        port conditionedOutput : AnalogSignalPort;

        action conditionSignal {
            in attribute bridgeVoltage : ElectricPotential;
            out attribute filteredVoltage : ElectricPotential;
            out attribute inferredResistance : ElectricResistance;
        }
    }

    part def PressureEstimator {
        attribute coefficientA : CalibrationCoefficient = -2.85;
        attribute coefficientB : CalibrationCoefficient = 1.42;
        attribute coefficientC : CalibrationCoefficient = 0.06;
        attribute gasCorrectionFactor : Real = 1.0;
        attribute lowerPressureLimit : Pressure = 0.1 [Pa];
        attribute upperPressureLimit : Pressure = 100000 [Pa];

        port resistanceInput : AnalogSignalPort;
        port measurementOutput : MeasurementOutputPort;

        action convertResistanceToPressure {
            in attribute filamentResistance : ElectricResistance;
            in attribute filamentTemperature : Temperature;
            out attribute estimatedPressure : Pressure;
            out attribute estimatedUncertainty : Pressure;
        }

        action applyGasCorrection {
            in attribute uncorrectedPressure : Pressure;
            in attribute gasComposition : String;
            out attribute correctedPressure : Pressure;
        }
    }

    part def GaugeDiagnostics {
        attribute maximumAllowedTemperature : Temperature = 473.15 [K];
        attribute minimumValidResistance : ElectricResistance = 80 [Ohm];
        attribute maximumValidResistance : ElectricResistance = 220 [Ohm];
        attribute calibrationInterval : Time = 31536000 [s];

        port sensorHealthInput : DiagnosticOutputPort;
        port measurementInput : MeasurementOutputPort;
        port statusOutput : DiagnosticOutputPort;

        action evaluateHealth {
            in attribute resistance : ElectricResistance;
            in attribute temperature : Temperature;
            in attribute pressure : Pressure;
            out attribute status : DiagnosticStatus;
        }
    }

    part def VacuumCompatibleHousing {
        attribute flangeType : String = "KF16";
        attribute sealMaterial : String = "FKM";
        attribute maximumBakeoutTemperature : Temperature = 373.15 [K];
        attribute pressureBoundaryRating : Pressure = 200000 [Pa];

        port processGasInterface : GasExposurePort;
    }

    action def InitializeGauge {
        out attribute initialized : Boolean;

        first start;
        then verifySupply;
        then zeroBridge;
        then loadCalibration;
        then ready;

        action verifySupply {
            in attribute supplyVoltage : ElectricPotential;
            out attribute supplyAccepted : Boolean;
        }

        action zeroBridge {
            out attribute bridgeOffset : ElectricPotential;
        }

        action loadCalibration {
            out attribute calibrationLoaded : Boolean;
        }
    }

    action def RegulateFilamentTemperature {
        in attribute measuredTemperature : Temperature;
        in attribute targetTemperature : Temperature;
        out attribute heaterPower : Power;

        action calculateError {
            out attribute temperatureError : Temperature;
        }

        action limitPower {
            in attribute requestedPower : Power;
            out attribute boundedPower : Power;
        }
    }

    action def EstimatePressure {
        in item gas : GasSample;
        in item signal : ResistanceSignal;
        out item measurement : PressureMeasurement;

        action inferThermalConductance {
            in attribute filamentPower : Power;
            in attribute filamentTemperature : Temperature;
            in attribute gasTemperature : Temperature;
            out attribute conductanceEstimate : HeatTransferCoefficient;
        }

        action mapConductanceToPressure {
            in attribute conductanceEstimate : HeatTransferCoefficient;
            out attribute pressure : Pressure;
        }

        action validateRange {
            in attribute pressure : Pressure;
            out attribute valid : Boolean;
        }
    }

    state def GaugeOperationalStates {
        entry action InitializeGauge;

        state Off;
        state Startup;
        state Warmup;
        state Measuring;
        state Fault;
        state Calibration;

        transition first Off;
        transition Off_to_Startup
            first Off
            then Startup
            accept PowerApplied;

        transition Startup_to_Warmup
            first Startup
            then Warmup
            accept InitializationComplete;

        transition Warmup_to_Measuring
            first Warmup
            then Measuring
            if filamentTemperatureStable;

        transition Measuring_to_Calibration
            first Measuring
            then Calibration
            accept CalibrationRequested;

        transition Calibration_to_Measuring
            first Calibration
            then Measuring
            accept CalibrationComplete;

        transition Measuring_to_Fault
            first Measuring
            then Fault
            if diagnosticFaultDetected;

        transition Warmup_to_Fault
            first Warmup
            then Fault
            if overTemperatureDetected;

        transition Fault_to_Startup
            first Fault
            then Startup
            accept FaultReset;
    }

    requirement def MeasureVacuumPressure {
        doc /* The system shall estimate gas pressure in a vacuum process volume using the heat loss from a heated Pirani filament. */
        subject gauge : PiraniGaugeSystem;
        require constraint {
            gauge.minimumMeasurablePressure <= 0.1 [Pa] and
            gauge.maximumMeasurablePressure >= 100000 [Pa]
        }
    }

    requirement def MaintainFilamentTemperature {
        doc /* The controller shall maintain the heated filament at a controlled temperature during measurement operation. */
        subject controller : ConstantTemperatureController;
        require constraint {
            controller.targetTemperature == 423.15 [K] and
            controller.maximumHeaterPower <= 2.5 [W]
        }
    }

    requirement def ProvidePressureOutput {
        doc /* The gauge shall provide a pressure measurement containing pressure, uncertainty, validity, and timestamp. */
        subject output : PressureMeasurement;
        require constraint {
            output.uncertainty >= 0 [Pa]
        }
    }

    requirement def DetectUnsafeSensorConditions {
        doc /* The gauge shall report diagnostic faults for over-temperature, open filament, invalid pressure range, and calibration status. */
        subject status : DiagnosticStatus;
        require constraint {
            status.healthy == not(status.overTemperature or status.filamentOpenCircuit or status.pressureOutOfRange)
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The primary function of the Pirani gauge system is high-level vacuum pressure measurement based on gas thermal conductivity. */
        subject gauge : PiraniGaugeSystem;
        require constraint {
            gauge.updatePeriod <= 0.1 [s]
        }
    }

    satisfy MeasureVacuumPressure by PiraniGaugeSystem;
    satisfy MaintainFilamentTemperature by ConstantTemperatureController;
    satisfy ProvidePressureOutput by PressureEstimator;
    satisfy DetectUnsafeSensorConditions by GaugeDiagnostics;
    satisfy PrimaryFunctionRequirement by PiraniGaugeSystem;

    part piraniGauge : PiraniGaugeSystem {
        attribute minimumMeasurablePressure = 0.1 [Pa];
        attribute maximumMeasurablePressure = 100000 [Pa];
        attribute nominalSupplyVoltage = 24 [V];
        attribute updatePeriod = 0.1 [s];
    }
}