package BoostGaugeSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Pressure {
        :> scalarValues::Real;
        unit = "kPa";
    }

    attribute def Voltage {
        :> scalarValues::Real;
        unit = "V";
    }

    attribute def Current {
        :> scalarValues::Real;
        unit = "A";
    }

    attribute def Temperature {
        :> scalarValues::Real;
        unit = "degC";
    }

    attribute def TimeDuration {
        :> scalarValues::Real;
        unit = "ms";
    }

    attribute def Percent {
        :> scalarValues::Real;
        unit = "%";
    }

    attribute def Angle {
        :> scalarValues::Real;
        unit = "deg";
    }

    attribute def IlluminanceLevel {
        :> scalarValues::Real;
        unit = "%";
    }

    item def ManifoldPressureSignal {
        attribute absolutePressure : Pressure;
        attribute gaugePressure : Pressure;
        attribute sampleAge : TimeDuration;
        attribute signalValid : Boolean;
    }

    item def BoostReading {
        attribute boostPressure : Pressure;
        attribute vacuumPressure : Pressure;
        attribute normalizedNeedlePosition : Percent;
        attribute overBoostActive : Boolean;
        attribute warningActive : Boolean;
    }

    item def ElectricalPower {
        attribute supplyVoltage : Voltage;
        attribute supplyCurrent : Current;
        attribute groundReference : Voltage;
    }

    item def DriverVisualInformation {
        attribute indicatedBoost : Pressure;
        attribute needleAngle : Angle;
        attribute backlightLevel : IlluminanceLevel;
        attribute warningLampOn : Boolean;
    }

    item def DiagnosticMessage {
        attribute sensorFault : Boolean;
        attribute powerFault : Boolean;
        attribute displayFault : Boolean;
        attribute overBoostEvent : Boolean;
        attribute messageAge : TimeDuration;
    }

    port def PressureSensePort {
        in item manifoldPressure : ManifoldPressureSignal;
    }

    port def PowerInputPort {
        in item power : ElectricalPower;
    }

    port def ReadingOutputPort {
        out item reading : BoostReading;
    }

    port def VisualDisplayPort {
        out item visualInfo : DriverVisualInformation;
    }

    port def DiagnosticPort {
        out item diagnostic : DiagnosticMessage;
    }

    part def IntakeManifold {
        attribute absolutePressure : Pressure = 101.3;
        attribute ambientPressure : Pressure = 101.3;
        attribute boostPressure : Pressure = 0.0;
        attribute manifoldTemperature : Temperature = 35.0;

        port pressureOutput : PressureSensePort;

        action updateManifoldPressure {
            in attribute compressorOutletPressure : Pressure;
            in attribute throttleCondition : Percent;
            out item pressureSignal : ManifoldPressureSignal;

            assign absolutePressure := ambientPressure + boostPressure;
            assign pressureSignal.absolutePressure := absolutePressure;
            assign pressureSignal.gaugePressure := absolutePressure - ambientPressure;
            assign pressureSignal.sampleAge := 0.0;
            assign pressureSignal.signalValid := true;
        }
    }

    part def BoostPressureSensor {
        attribute measurementRangeMin : Pressure = 20.0;
        attribute measurementRangeMax : Pressure = 300.0;
        attribute outputVoltageMin : Voltage = 0.5;
        attribute outputVoltageMax : Voltage = 4.5;
        attribute sensorTemperature : Temperature = 30.0;
        attribute sensorFaultDetected : Boolean = false;

        port sensedPressureIn : PressureSensePort;
        port conditionedSignalOut : ReadingOutputPort;
        port diagnosticOut : DiagnosticPort;

        action sensePressure {
            in item rawPressure : ManifoldPressureSignal;
            out item filteredReading : BoostReading;
            out item diagnosticStatus : DiagnosticMessage;

            assign sensorFaultDetected :=
                rawPressure.absolutePressure < measurementRangeMin or
                rawPressure.absolutePressure > measurementRangeMax or
                not rawPressure.signalValid;

            assign filteredReading.boostPressure :=
                if rawPressure.gaugePressure > 0.0 then rawPressure.gaugePressure else 0.0;

            assign filteredReading.vacuumPressure :=
                if rawPressure.gaugePressure < 0.0 then -rawPressure.gaugePressure else 0.0;

            assign filteredReading.overBoostActive := rawPressure.gaugePressure > 150.0;
            assign filteredReading.warningActive := rawPressure.gaugePressure > 130.0;
            assign filteredReading.normalizedNeedlePosition :=
                min(100.0, max(0.0, (rawPressure.gaugePressure + 100.0) / 250.0 * 100.0));

            assign diagnosticStatus.sensorFault := sensorFaultDetected;
            assign diagnosticStatus.powerFault := false;
            assign diagnosticStatus.displayFault := false;
            assign diagnosticStatus.overBoostEvent := filteredReading.overBoostActive;
            assign diagnosticStatus.messageAge := 0.0;
        }
    }

    part def GaugeController {
        attribute ambientPressureEstimate : Pressure = 101.3;
        attribute warningThreshold : Pressure = 130.0;
        attribute overBoostThreshold : Pressure = 150.0;
        attribute updatePeriod : TimeDuration = 20.0;
        attribute controllerHealthy : Boolean = true;
        attribute ignitionOn : Boolean = false;

        port powerIn : PowerInputPort;
        port pressureReadingIn : ReadingOutputPort;
        port displayCommandOut : VisualDisplayPort;
        port diagnosticOut : DiagnosticPort;

        action computeBoostIndication {
            in item sensorReading : BoostReading;
            in item suppliedPower : ElectricalPower;
            out item visualCommand : DriverVisualInformation;
            out item controllerDiagnostic : DiagnosticMessage;

            assign controllerHealthy :=
                suppliedPower.supplyVoltage >= 9.0 and suppliedPower.supplyVoltage <= 16.0;

            assign ignitionOn := suppliedPower.supplyVoltage > 9.0;

            assign visualCommand.indicatedBoost := sensorReading.boostPressure;
            assign visualCommand.needleAngle :=
                -120.0 + sensorReading.normalizedNeedlePosition * 2.4;
            assign visualCommand.backlightLevel :=
                if ignitionOn then 80.0 else 0.0;
            assign visualCommand.warningLampOn :=
                sensorReading.warningActive or sensorReading.overBoostActive;

            assign controllerDiagnostic.sensorFault := false;
            assign controllerDiagnostic.powerFault := not controllerHealthy;
            assign controllerDiagnostic.displayFault := false;
            assign controllerDiagnostic.overBoostEvent := sensorReading.overBoostActive;
            assign controllerDiagnostic.messageAge := 0.0;
        }

        state def ControllerOperatingState {
            entry action initializeGauge;
            state Off;
            state SelfTest;
            state NormalDisplay;
            state WarningDisplay;
            state FaultDisplay;

            transition initial then Off;

            transition Off_to_SelfTest
                first Off
                accept when ignitionOn
                then SelfTest;

            transition SelfTest_to_Normal
                first SelfTest
                accept after 1000.0
                then NormalDisplay;

            transition Normal_to_Warning
                first NormalDisplay
                accept when pressureReadingIn.reading.warningActive
                then WarningDisplay;

            transition Warning_to_Normal
                first WarningDisplay
                accept when not pressureReadingIn.reading.warningActive
                then NormalDisplay;

            transition Any_to_Fault
                first NormalDisplay
                accept when not controllerHealthy
                then FaultDisplay;

            transition Warning_to_Fault
                first WarningDisplay
                accept when not controllerHealthy
                then FaultDisplay;

            transition Fault_to_Off
                first FaultDisplay
                accept when not ignitionOn
                then Off;
        }
    }

    part def AnalogNeedleDisplay {
        attribute minimumAngle : Angle = -120.0;
        attribute maximumAngle : Angle = 120.0;
        attribute currentNeedleAngle : Angle = -120.0;
        attribute faceMinimumPressure : Pressure = -100.0;
        attribute faceMaximumPressure : Pressure = 150.0;
        attribute displayFaultDetected : Boolean = false;

        port commandIn : VisualDisplayPort;
        port driverViewOut : VisualDisplayPort;
        port diagnosticOut : DiagnosticPort;

        action positionNeedle {
            in item command : DriverVisualInformation;
            out item displayedInfo : DriverVisualInformation;
            out item displayDiagnostic : DiagnosticMessage;

            assign currentNeedleAngle :=
                min(maximumAngle, max(minimumAngle, command.needleAngle));

            assign displayedInfo.indicatedBoost := command.indicatedBoost;
            assign displayedInfo.needleAngle := currentNeedleAngle;
            assign displayedInfo.backlightLevel := command.backlightLevel;
            assign displayedInfo.warningLampOn := command.warningLampOn;

            assign displayDiagnostic.sensorFault := false;
            assign displayDiagnostic.powerFault := false;
            assign displayDiagnostic.displayFault := displayFaultDetected;
            assign displayDiagnostic.overBoostEvent := command.warningLampOn;
            assign displayDiagnostic.messageAge := 0.0;
        }
    }

    part def WarningIndicator {
        attribute lampIntensity : IlluminanceLevel = 0.0;
        attribute audibleAlertEnabled : Boolean = false;

        port warningCommandIn : VisualDisplayPort;
        port warningVisualOut : VisualDisplayPort;

        action updateWarning {
            in item command : DriverVisualInformation;
            out item warningOutput : DriverVisualInformation;

            assign lampIntensity := if command.warningLampOn then 100.0 else 0.0;
            assign audibleAlertEnabled := command.indicatedBoost > 150.0;

            assign warningOutput.indicatedBoost := command.indicatedBoost;
            assign warningOutput.needleAngle := command.needleAngle;
            assign warningOutput.backlightLevel := command.backlightLevel;
            assign warningOutput.warningLampOn := command.warningLampOn;
        }
    }

    part def VehicleElectricalSupply {
        attribute nominalVoltage : Voltage = 12.0;
        attribute operatingVoltage : Voltage = 13.8;
        attribute maximumCurrent : Current = 2.0;
        attribute supplyHealthy : Boolean = true;

        port powerOut : PowerInputPort;

        action providePower {
            out item suppliedPower : ElectricalPower;

            assign suppliedPower.supplyVoltage := operatingVoltage;
            assign suppliedPower.supplyCurrent := 0.35;
            assign suppliedPower.groundReference := 0.0;
        }
    }

    part def Driver {
        attribute perceivedBoost : Pressure = 0.0;
        attribute warningPerceived : Boolean = false;

        port visualInput : VisualDisplayPort;

        action observeGauge {
            in item visualInformation : DriverVisualInformation;

            assign perceivedBoost := visualInformation.indicatedBoost;
            assign warningPerceived := visualInformation.warningLampOn;
        }
    }

    part def BoostGaugeSystem {
        attribute primaryFunction : String =
            "Measure intake manifold pressure relative to ambient pressure and present the resulting boost or vacuum indication to the driver in real time.";
        attribute operatingPressureMinimum : Pressure = -100.0;
        attribute operatingPressureMaximum : Pressure = 150.0;
        attribute displayUpdatePeriod : TimeDuration = 20.0;
        attribute nominalSupplyVoltage : Voltage = 12.0;

        part manifold : IntakeManifold;
        part pressureSensor : BoostPressureSensor;
        part controller : GaugeController;
        part display : AnalogNeedleDisplay;
        part warningIndicator : WarningIndicator;
        part electricalSupply : VehicleElectricalSupply;
        part driver : Driver;

        port manifoldPressurePort : PressureSensePort;
        port powerPort : PowerInputPort;
        port boostReadingPort : ReadingOutputPort;
        port displayPort : VisualDisplayPort;
        port diagnosticPort : DiagnosticPort;

        connect manifold.pressureOutput to pressureSensor.sensedPressureIn;
        connect pressureSensor.conditionedSignalOut to controller.pressureReadingIn;
        connect electricalSupply.powerOut to controller.powerIn;
        connect controller.displayCommandOut to display.commandIn;
        connect controller.displayCommandOut to warningIndicator.warningCommandIn;
        connect display.driverViewOut to driver.visualInput;
        connect pressureSensor.diagnosticOut to diagnosticPort;
        connect controller.diagnosticOut to diagnosticPort;
        connect display.diagnosticOut to diagnosticPort;

        perform action normalOperation {
            first electricalSupply.providePower;
            then manifold.updateManifoldPressure;
            then pressureSensor.sensePressure;
            then controller.computeBoostIndication;
            then display.positionNeedle;
            then warningIndicator.updateWarning;
            then driver.observeGauge;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject gaugeSystem : BoostGaugeSystem;

        doc /* The boost gauge system shall measure intake manifold pressure relative to ambient pressure and provide a clear real-time indication of boost or vacuum to the driver. */

        require constraint {
            gaugeSystem.displayUpdatePeriod <= 50.0
        }
    }

    requirement def PressureRangeRequirement {
        subject gaugeSystem : BoostGaugeSystem;

        doc /* The boost gauge shall indicate pressures from full vacuum through maximum expected boost without saturating during normal operation. */

        require constraint {
            gaugeSystem.operatingPressureMinimum <= -100.0 and
            gaugeSystem.operatingPressureMaximum >= 150.0
        }
    }

    requirement def WarningRequirement {
        subject gaugeSystem : BoostGaugeSystem;

        doc /* The boost gauge shall provide a visible warning when indicated boost exceeds the configured warning threshold. */

        require constraint {
            gaugeSystem.controller.warningThreshold < gaugeSystem.controller.overBoostThreshold
        }
    }

    requirement def ElectricalCompatibilityRequirement {
        subject gaugeSystem : BoostGaugeSystem;

        doc /* The boost gauge shall operate from a nominal 12 V vehicle electrical supply. */

        require constraint {
            gaugeSystem.nominalSupplyVoltage == 12.0
        }
    }

    requirement def FaultReportingRequirement {
        subject gaugeSystem : BoostGaugeSystem;

        doc /* The boost gauge shall report sensor, power, display, and over-boost diagnostic conditions. */

        require constraint {
            gaugeSystem.pressureSensor.sensorFaultDetected implies
            gaugeSystem.diagnosticPort.diagnostic.sensorFault
        }
    }

    satisfy PrimaryFunctionRequirement by BoostGaugeSystem;
    satisfy PressureRangeRequirement by BoostGaugeSystem;
    satisfy WarningRequirement by BoostGaugeSystem;
    satisfy ElectricalCompatibilityRequirement by BoostGaugeSystem;
    satisfy FaultReportingRequirement by BoostGaugeSystem;

}