package MagneticFieldControlSystem {
    import ScalarValues::*;

    // ===== Value Types =====
    value type MagneticFluxDensity :> Real {
        :>> unit = "T";
    }

    value type ElectricCurrent :> Real {
        :>> unit = "A";
    }

    value type Voltage :> Real {
        :>> unit = "V";
    }

    value type Power :> Real {
        :>> unit = "W";
    }

    value type Temperature :> Real {
        :>> unit = "K";
    }

    value type TimeValue :> Real {
        :>> unit = "s";
    }

    value type Resistance :> Real {
        :>> unit = "ohm";
    }

    value type Inductance :> Real {
        :>> unit = "H";
    }

    value type Frequency :> Real {
        :>> unit = "Hz";
    }

    value type CurrentRampRate :> Real {
        :>> unit = "A/s";
    }

    // ===== Item Definitions =====
    item def FieldMeasurement {
        timestamp : TimeValue;
        fieldStrength : MagneticFluxDensity;
        vectorX : MagneticFluxDensity;
        vectorY : MagneticFluxDensity;
        vectorZ : MagneticFluxDensity;
        confidence : Real;
    }

    item def CurrentCommand {
        targetCurrent : ElectricCurrent;
        rampRate : CurrentRampRate;
        priority : Integer;
    }

    item def PowerTelemetry {
        outputVoltage : Voltage;
        outputCurrent : ElectricCurrent;
        temperature : Temperature;
        faultActive : Boolean;
        timestamp : TimeValue;
    }

    // ===== Port Definitions =====
    port def MeasurementOutPort {
        out measurement : FieldMeasurement;
    }

    port def MeasurementInPort {
        in measurement : FieldMeasurement;
    }

    port def CommandOutPort {
        out command : CurrentCommand;
    }

    port def CommandInPort {
        in command : CurrentCommand;
    }

    port def PowerOutPort {
        out voltage : Voltage;
        out current : ElectricCurrent;
    }

    port def PowerInPort {
        in voltage : Voltage;
        in current : ElectricCurrent;
    }

    port def TelemetryOutPort {
        out telemetry : PowerTelemetry;
    }

    port def TelemetryInPort {
        in telemetry : PowerTelemetry;
    }

    // ===== Connection Definitions =====
    connection def PowerConnection {
        end supplier : PowerOutPort;
        end consumer : PowerInPort;
    }

    connection def MeasurementLink {
        end source : MeasurementOutPort;
        end destination : MeasurementInPort;
    }

    connection def CommandLink {
        end source : CommandOutPort;
        end destination : CommandInPort;
    }

    connection def TelemetryLink {
        end source : TelemetryOutPort;
        end destination : TelemetryInPort;
    }

    // ===== Action Definitions =====
    action def ComputeCorrection {
        in measurement : FieldMeasurement;
        in target : MagneticFluxDensity;
        in previousError : MagneticFluxDensity;
        in integralError : Real;
        in kp : Real;
        in ki : Real;
        in kd : Real;
        out command : CurrentCommand;
        out newError : MagneticFluxDensity;
        out newIntegral : Real;

        local error : MagneticFluxDensity;
        local derivative : MagneticFluxDensity;
        local correctionCurrent : ElectricCurrent;

        action calculateError {
            in tgt : MagneticFluxDensity;
            in meas : MagneticFluxDensity;
            out err : MagneticFluxDensity;
        }

        action calculateDerivative {
            in currentErr : MagneticFluxDensity;
            in prevErr : MagneticFluxDensity;
            out deriv : MagneticFluxDensity;
        }

        action applyPID {
            in p : MagneticFluxDensity;
            in i : Real;
            in d : MagneticFluxDensity;
            in pGain : Real;
            in iGain : Real;
            in dGain : Real;
            out current : ElectricCurrent;
        }

        action assembleCommand {
            in current : ElectricCurrent;
            out cmd : CurrentCommand;
        }
    }

    action def RegulateOutput {
        in command : CurrentCommand;
        out voltage : Voltage;
        out current : ElectricCurrent;
    }

    action def MeasureFieldAction {
        in actualField : MagneticFluxDensity;
        out measurement : FieldMeasurement;
    }

    action def GenerateFieldAction {
        in inputCurrent : ElectricCurrent;
        out generatedField : MagneticFluxDensity;
    }

    action def AttenuateField {
        in externalField : MagneticFluxDensity;
        out residualField : MagneticFluxDensity;
    }

    // ===== Electromagnet =====
    part def Electromagnet {
        port powerInput : PowerInPort;
        port commandInput : CommandInPort;

        attribute coilResistance : Resistance = 0.5;
        attribute coilInductance : Inductance = 2.5;
        attribute turns : Integer = 1000;
        attribute maxFieldStrength : MagneticFluxDensity = 3.0;
        attribute saturationField : MagneticFluxDensity = 3.5;
        attribute fieldConstant : Real = 0.015;
        attribute presentCurrent : ElectricCurrent = 0.0;
        attribute presentField : MagneticFluxDensity = 0.0;
        attribute coilTemperature : Temperature = 293.15;
        attribute maxCoilTemperature : Temperature = 340.0;

        action generateField : GenerateFieldAction;

        action rampCurrent {
            in cmd : CurrentCommand;
            out achievedCurrent : ElectricCurrent;
        }

        action monitorCoilTemperature {
            out temperature : Temperature;
        }
    }

    // ===== Power Supply =====
    part def PowerSupply {
        port powerOutput : PowerOutPort;
        port telemetryOutput : TelemetryOutPort;
        port commandInput : CommandInPort;

        attribute maxOutputVoltage : Voltage = 100.0;
        attribute maxOutputCurrent : ElectricCurrent = 200.0;
        attribute efficiency : Real = 0.95;
        attribute outputVoltage : Voltage = 0.0;
        attribute outputCurrent : ElectricCurrent = 0.0;
        attribute internalTemperature : Temperature = 293.15;
        attribute overTemperatureLimit : Temperature = 350.0;
        attribute rippleNoise : Voltage = 0.01;

        action regulateOutput : RegulateOutput;

        action monitorHealth {
            out telemetry : PowerTelemetry;
        }

        action emergencyShutdown {
            out telemetry : PowerTelemetry;
        }

        action softStart {
            in targetCurrent : ElectricCurrent;
            out achievedCurrent : ElectricCurrent;
        }
    }

    // ===== Field Sensor =====
    part def FieldSensor {
        port measurementOutput : MeasurementOutPort;

        attribute sensitivity : MagneticFluxDensity = 0.000001;
        attribute samplingRate : Frequency = 1000.0;
        attribute measurementRange : MagneticFluxDensity = 5.0;
        attribute noiseFloor : MagneticFluxDensity = 0.0000005;
        attribute accuracy : Real = 0.9999;
        attribute warmupTime : TimeValue = 30.0;
        attribute calibrated : Boolean = false;

        action measureField : MeasureFieldAction;

        action calibrate {
            in referenceField : MagneticFluxDensity;
            out success : Boolean;
        }

        action selfTest {
            out pass : Boolean;
        }

        action timestampMeasurement {
            in rawField : MagneticFluxDensity;
            out timestampedMeasurement : FieldMeasurement;
        }
    }

    // ===== Field Controller =====
    part def FieldController {
        port measurementInput : MeasurementInPort;
        port commandOutput : CommandOutPort;
        port telemetryInput : TelemetryInPort;

        attribute targetField : MagneticFluxDensity = 0.0;
        attribute previousTarget : MagneticFluxDensity = 0.0;
        attribute tolerance : MagneticFluxDensity = 0.00001;
        attribute proportionalGain : Real = 1.5;
        attribute integralGain : Real = 0.2;
        attribute derivativeGain : Real = 0.05;
        attribute maxRampRate : CurrentRampRate = 10.0;
        attribute integralError : Real = 0.0;
        attribute previousError : MagneticFluxDensity = 0.0;
        attribute controlLoopPeriod : TimeValue = 0.001;
        attribute safetyCheckEnabled : Boolean = true;

        action computeCorrection : ComputeCorrection;

        action updateTarget {
            in newTarget : MagneticFluxDensity;
        }

        action evaluateSafety {
            in telemetry : PowerTelemetry;
            out safe : Boolean;
        }

        action sendEnergizeCommand;
        action sendStableCommand;
        action sendAdjustCommand;
        action sendDeenergizeCommand;
        action resetController;
        action handleFault;

        state controllerStateMachine {
            entry; then off;

            state off {
                entry / resetController();
            }

            transition off_to_energizing
                first off
                if targetField > 0.0
                then energizing;

            state energizing {
                entry / sendEnergizeCommand();
            }

            transition energizing_to_stable
                first energizing
                if abs(measurementInput.measurement.fieldStrength - targetField) <= tolerance
                then stable;

            state stable {
                entry / sendStableCommand();
            }

            transition stable_to_adjusting
                first stable
                if targetField != previousTarget and targetField > 0.0
                then adjusting;

            state adjusting {
                entry / sendAdjustCommand();
            }

            transition adjusting_to_stable
                first adjusting
                if abs(measurementInput.measurement.fieldStrength - targetField) <= tolerance
                then stable;

            transition stable_to_deenergizing
                first stable
                if targetField == 0.0
                then deenergizing;

            state deenergizing {
                entry / sendDeenergizeCommand();
            }

            transition deenergizing_to_off
                first deenergizing
                if measurementInput.measurement.fieldStrength <= tolerance
                then off;

            transition energizing_emergency
                first energizing
                if telemetryInput.telemetry.faultActive == true
                then off;

            transition stable_emergency
                first stable
                if telemetryInput.telemetry.faultActive == true
                then off;

            transition adjusting_emergency
                first adjusting
                if telemetryInput.telemetry.faultActive == true
                then off;

            transition deenergizing_emergency
                first deenergizing
                if telemetryInput.telemetry.faultActive == true
                then off;
        }
    }

    // ===== Shielding Enclosure =====
    part def ShieldingEnclosure {
        attribute shieldingFactor : Real = 1000.0;
        attribute maxExternalField : MagneticFluxDensity = 0.001;
        attribute material : String = "Mu-metal";
        attribute wallThickness : Real = 0.005;
        attribute internalVolume : Real = 1.0;
        attribute attenuationBandwidth : Frequency = 100000.0;
        attribute leakageField : MagneticFluxDensity = 0.000003;

        action attenuateExternalField : AttenuateField;

        action containInternalField {
            in internalField : MagneticFluxDensity;
            out leakage : MagneticFluxDensity;
        }

        action verifyIntegrity {
            out intact : Boolean;
        }
    }

    // ===== System Assembly =====
    part def MagneticFieldControlSystem {
        part electromagnet : Electromagnet;
        part powerSupply : PowerSupply;
        part fieldSensor : FieldSensor;
        part fieldController : FieldController;
        part shieldingEnclosure : ShieldingEnclosure;

        connection powerLink : PowerConnection
            connect powerSupply.powerOutput to electromagnet.powerInput;

        connection sensorToController : MeasurementLink
            connect fieldSensor.measurementOutput to fieldController.measurementInput;

        connection controllerToElectromagnet : CommandLink
            connect fieldController.commandOutput to electromagnet.commandInput;

        connection controllerToPowerSupply : CommandLink
            connect fieldController.commandOutput to powerSupply.commandInput;

        connection powerSupplyToController : TelemetryLink
            connect powerSupply.telemetryOutput to fieldController.telemetryInput;
    }

    // ===== Requirements =====
    requirement def FieldStabilityRequirement {
        subject system : MagneticFieldControlSystem;
        :>> requiredStability : MagneticFluxDensity = 0.00001;
        :>> measurementWindow : TimeValue = 60.0;
        require constraint {
            abs(system.fieldController.measurementInput.measurement.fieldStrength
                - system.fieldController.targetField) <= requiredStability
        }
    }

    requirement def FieldRangeRequirement {
        subject system : MagneticFieldControlSystem;
        :>> minField : MagneticFluxDensity = 0.0;
        :>> maxField : MagneticFluxDensity = 3.0;
        require constraint {
            system.fieldController.targetField >= minField
            and system.fieldController.targetField <= maxField
        }
    }

    requirement def ShieldingEffectivenessRequirement {
        subject enclosure : ShieldingEnclosure;
        :>> minShieldingFactor : Real = 1000.0;
        :>> maxResidualField : MagneticFluxDensity = 0.000001;
        require constraint {
            enclosure.shieldingFactor >= minShieldingFactor
        }
    }

    requirement def RampRateSafetyRequirement {
        subject system : MagneticFieldControlSystem;
        :>> maxSafeRampRate : CurrentRampRate = 10.0;
        require constraint {
            system.fieldController.maxRampRate <= maxSafeRampRate
        }
    }

    requirement def PowerSupplyCapacityRequirement {
        subject supply : PowerSupply;
        :>> requiredMaxCurrent : ElectricCurrent = 200.0;
        :>> requiredMaxVoltage : Voltage = 100.0;
        require constraint {
            supply.maxOutputCurrent >= requiredMaxCurrent
            and supply.maxOutputVoltage >= requiredMaxVoltage
        }
    }

    requirement def SensorAccuracyRequirement {
        subject sensor : FieldSensor;
        :>> requiredSensitivity : MagneticFluxDensity = 0.000001;
        :>> requiredSamplingRate : Frequency = 1000.0;
        require constraint {
            sensor.sensitivity <= requiredSensitivity
            and sensor.samplingRate >= requiredSamplingRate
        }
    }

    requirement def OperationalStateMachineRequirement {
        subject system : MagneticFieldControlSystem;
        :>> requiredStates : String = "off, energizing, stable, adjusting, deenergizing";
        :>> maxEnergizingTime : TimeValue = 300.0;
        :>> maxDeenergizingTime : TimeValue = 300.0;
        require constraint {
            system.fieldController.targetField >= 0.0
        }
    }

    requirement def FaultToleranceRequirement {
        subject system : MagneticFieldControlSystem;
        :>> faultResponseTime : TimeValue = 0.1;
        require constraint {
            system.powerSupply.telemetryOutput.telemetry.faultActive implies
            system.fieldController.targetField >= 0.0
        }
    }

    requirement def ThermalSafetyRequirement {
        subject magnet : Electromagnet;
        :>> maxSafeCoilTemperature : Temperature = 340.0;
        require constraint {
            magnet.coilTemperature <= maxSafeCoilTemperature
        }
    }

    // ===== Verification =====
    verification def VerifyFieldStability {
        subject system : MagneticFieldControlSystem;
        objective {
            doc /* Verify that the system maintains field strength within required stability tolerance */
        }
        require FieldStabilityRequirement;
    }

    verification def VerifyShieldingEffectiveness {
        subject enclosure : ShieldingEnclosure;
        objective {
            doc /* Verify that the shielding enclosure meets the minimum shielding factor */
        }
        require ShieldingEffectivenessRequirement;
    }

    verification def VerifyRampRateSafety {
        subject system : MagneticFieldControlSystem;
        objective {
            doc /* Verify that the ramp rate does not exceed the safe maximum */
        }
        require RampRateSafetyRequirement;
    }

    verification def VerifyPowerSupplyCapacity {
        subject supply : PowerSupply;
        objective {
            doc /* Verify that the power supply can deliver the required current and voltage */
        }
        require PowerSupplyCapacityRequirement;
    }

    verification def VerifySensorAccuracy {
        subject sensor : FieldSensor;
        objective {
            doc /* Verify that the field sensor meets sensitivity and sampling rate requirements */
        }
        require SensorAccuracyRequirement;
    }
}
