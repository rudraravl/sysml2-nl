package SSIESModel {
    attribute def PlasmaDensityValue :> ScalarValues::Real;
    attribute def PlasmaTemperatureValue :> ISQ::temperature;
    attribute def DriftVelocityValue :> ISQ::speed;
    attribute def ElectronEnergyValue :> ISQ::energy;
    attribute def ScintillationAmplitudeValue :> ScalarValues::Real;
    attribute def ScintillationFrequencyValue :> ISQ::frequency;
    attribute def PhaseVariationValue :> ScalarValues::Real;
    attribute def RegulatedPowerValue :> ISQ::power;
    attribute def BusVoltageValue :> ScalarValues::Real;
    attribute def TimestampValue :> Time::DateTime;
    attribute def InstrumentStatusValue :> ScalarValues::String;
    attribute def IonCompositionValue :> ScalarValues::String;

    attribute def StandbyCommand;
    attribute def ContinuousMeasurementCommand;
    attribute def CalibrationCommand;
    attribute def SafeModeCommand;
    attribute def FaultSignal;
    attribute def CalibrationComplete;

    item def IonMeasurement {
        attribute ionDensity : PlasmaDensityValue;
        attribute ionTemperature : PlasmaTemperatureValue;
        attribute ionComposition : IonCompositionValue;
        attribute driftVelocity : DriftVelocityValue;
    }

    item def ElectronMeasurement {
        attribute electronDensity : PlasmaDensityValue;
        attribute electronTemperature : PlasmaTemperatureValue;
        attribute electronEnergy : ElectronEnergyValue;
    }

    item def ScintillationData {
        attribute amplitude : ScintillationAmplitudeValue;
        attribute frequency : ScintillationFrequencyValue;
        attribute phaseVariation : PhaseVariationValue;
    }

    item def TelemetryPacket {
        attribute timestamp : TimestampValue;
        attribute status : InstrumentStatusValue;
        attribute ionData : IonMeasurement;
        attribute electronData : ElectronMeasurement;
        attribute scintillation : ScintillationData;
    }

    item def PowerSupply {
        attribute voltage : BusVoltageValue;
        attribute power : RegulatedPowerValue;
    }

    port def IonDataPort {
        out ionData : IonMeasurement;
    }

    port def ElectronDataPort {
        out electronData : ElectronMeasurement;
    }

    port def ScintillationDataPort {
        out scintillationData : ScintillationData;
    }

    port def TelemetryPort {
        out telemetry : TelemetryPacket;
    }

    port def PowerPort {
        out power : PowerSupply;
    }

    port def CommandPort {
        in standbyCmd : StandbyCommand;
        in continuousCmd : ContinuousMeasurementCommand;
        in calibrationCmd : CalibrationCommand;
        in safeCmd : SafeModeCommand;
    }

    action def MeasureIons {
        out ionData : IonMeasurement;
    }

    action def MeasureElectrons {
        out electronData : ElectronMeasurement;
    }

    action def AnalyzeScintillation {
        in ionData : IonMeasurement;
        in electronData : ElectronMeasurement;
        out scintillationData : ScintillationData;
    }

    action def GatherSensorData {
        in ionData : IonMeasurement;
        in electronData : ElectronMeasurement;
        out gatheredIon : IonMeasurement;
        out gatheredElectron : ElectronMeasurement;
    }

    action def PackageTelemetry {
        in ionData : IonMeasurement;
        in electronData : ElectronMeasurement;
        in scintillationData : ScintillationData;
        out packet : TelemetryPacket;
    }

    action def TransmitTelemetry {
        in packet : TelemetryPacket;
    }

    action def RegulatePower {
        in inputPower : PowerSupply;
        out outputPower : PowerSupply;
    }

    action def RunCalibration;
    action def EnterSafeMode;
    action def WaitStandby;

    action def ContinuousMeasurementCycle {
        action gather : GatherSensorData;
        action analyze : AnalyzeScintillation;
        action pkg : PackageTelemetry;
        action transmit : TransmitTelemetry;
    }

    state def DPUStates {
        entry; then Standby;

        state Standby {
            do action waitInStandby : WaitStandby;
        }

        state ContinuousMeasurement {
            do action runCycle : ContinuousMeasurementCycle;
        }

        state Calibration {
            do action runCal : RunCalibration;
        }

        state SafeMode {
            do action enterSafe : EnterSafeMode;
        }

        transition first Standby
            accept ContinuousMeasurementCommand
            then ContinuousMeasurement;
        transition first Standby
            accept CalibrationCommand
            then Calibration;
        transition first Standby
            accept FaultSignal
            then SafeMode;

        transition first ContinuousMeasurement
            accept StandbyCommand
            then Standby;
        transition first ContinuousMeasurement
            accept FaultSignal
            then SafeMode;

        transition first Calibration
            accept CalibrationComplete
            then Standby;
        transition first Calibration
            accept StandbyCommand
            then Standby;
        transition first Calibration
            accept FaultSignal
            then SafeMode;

        transition first SafeMode
            accept StandbyCommand
            then Standby;
    }

    part def Spacecraft {
        port powerOut : PowerPort;
        port commandOut : ~CommandPort;
        port telemetryIn : ~TelemetryPort;
    }

    part def SSIES {
        port powerInput : ~PowerPort;
        port commandInput : CommandPort;
        port telemetryOutput : TelemetryPort;
    }

    part def IonDriftMeter {
        port dataOut : IonDataPort;
        port powerIn : ~PowerPort;
        perform action measureIons : MeasureIons;
    }

    part def RPA {
        port dataOut : ElectronDataPort;
        port powerIn : ~PowerPort;
        perform action measureElectrons : MeasureElectrons;
    }

    part def ScintillationMonitor {
        port ionIn : ~IonDataPort;
        port electronIn : ~ElectronDataPort;
        port dataOut : ScintillationDataPort;
        port powerIn : ~PowerPort;
        perform action analyzeScintillation : AnalyzeScintillation;
    }

    part def DPU {
        port ionIn : ~IonDataPort;
        port electronIn : ~ElectronDataPort;
        port ionOut : IonDataPort;
        port electronOut : ElectronDataPort;
        port scintillationIn : ~ScintillationDataPort;
        port telemetryOut : TelemetryPort;
        port commandIn : CommandPort;
        port powerIn : ~PowerPort;

        perform action gatherData : GatherSensorData;
        perform action packageTelemetry : PackageTelemetry;
        perform action transmitTelemetry : TransmitTelemetry;

        exhibit state dpuStates : DPUStates;
    }

    part def PowerRegulator {
        port powerIn : ~PowerPort;
        port powerOut : PowerPort;
        perform action regulatePower : RegulatePower;
    }

    requirement def SSIESPerformanceRequirements {
        doc
        /*
         * Performance requirements for the Special Sensor -
         * Ionospheric and Electron Scintillation (SSIES) instrument.
         */

        requirement IonDensityAccuracy {
            doc
            /*
             * The Ion Drift Meter shall measure ion density
             * with an error not exceeding the specified maximum.
             */
            attribute maxError : PlasmaDensityValue;
        }

        requirement ElectronDensityAccuracy {
            doc
            /*
             * The Retarding Potential Analyzer shall measure
             * electron density with an error not exceeding
             * the specified maximum.
             */
            attribute maxError : PlasmaDensityValue;
        }

        requirement ScintillationDetectionSensitivity {
            doc
            /*
             * The Scintillation Monitor shall detect scintillation
             * events above the minimum amplitude threshold within
             * the specified frequency range.
             */
            attribute minAmplitude : ScintillationAmplitudeValue;
            attribute minFrequency : ScintillationFrequencyValue;
        }

        requirement PowerBudgetLimit {
            doc
            /*
             * The SSIES instrument total power consumption
             * shall not exceed the allocated power budget
             * from the spacecraft bus.
             */
            attribute maxPower : RegulatedPowerValue;
        }

        requirement TelemetryGenerationRate {
            doc
            /*
             * The DPU shall generate and transmit telemetry
             * packets at or above the minimum specified rate
             * during continuous measurement mode.
             */
            attribute minRate : ISQ::frequency;
        }

        requirement SafeModeResponse {
            doc
            /*
             * The DPU shall transition to SafeMode upon
             * detection of a fault within the instrument.
             */
        }
    }

    part spacecraftBus : Spacecraft;

    part ssies : SSIES {
        part ionDriftMeter : IonDriftMeter;
        part rpa : RPA;
        part scintillationMonitor : ScintillationMonitor;
        part dpu : DPU;
        part powerRegulator : PowerRegulator;

        bind powerInput = powerRegulator.powerIn;
        bind commandInput = dpu.commandIn;
        bind telemetryOutput = dpu.telemetryOut;

        flow ionDataToDPU of IonMeasurement
            from ionDriftMeter.dataOut.ionData to dpu.ionIn.ionData;
        flow electronDataToDPU of ElectronMeasurement
            from rpa.dataOut.electronData to dpu.electronIn.electronData;
        flow ionDataToScint of IonMeasurement
            from dpu.ionOut.ionData to scintillationMonitor.ionIn.ionData;
        flow electronDataToScint of ElectronMeasurement
            from dpu.electronOut.electronData to scintillationMonitor.electronIn.electronData;
        flow scintDataToDPU of ScintillationData
            from scintillationMonitor.dataOut.scintillationData to dpu.scintillationIn.scintillationData;
        flow powerToIDM of PowerSupply
            from powerRegulator.powerOut.power to ionDriftMeter.powerIn.power;
        flow powerToRPA of PowerSupply
            from powerRegulator.powerOut.power to rpa.powerIn.power;
        flow powerToScint of PowerSupply
            from powerRegulator.powerOut.power to scintillationMonitor.powerIn.power;
        flow powerToDPU of PowerSupply
            from powerRegulator.powerOut.power to dpu.powerIn.power;
    }

    interface spacecraftToSSIESPower
        connect spacecraftBus.powerOut to ssies.powerInput {
            flow spacecraftPowerFlow of PowerSupply
                from spacecraftBus.powerOut.power to ssies.powerInput.power;
        }

    interface spacecraftToSSIESCommand
        connect spacecraftBus.commandOut to ssies.commandInput;

    interface ssiestoSpacecraftTelemetry
        connect ssies.telemetryOutput to spacecraftBus.telemetryIn {
            flow telemetryFlow of TelemetryPacket
                from ssies.telemetryOutput.telemetry to spacecraftBus.telemetryIn.telemetry;
        }

    requirement ssiesPerfReqs : SSIESPerformanceRequirements;

    satisfy ssiesPerfReqs by ssies;
}
