package CylinderHeadTemperatureGaugeModel {

    import ScalarValues::*;
    import Quantities::*;
    import SI::*;

    attribute def Temperature {
        :> scalar;
        unit = "degC";
    }

    attribute def TimeDuration {
        :> scalar;
        unit = "s";
    }

    attribute def ElectricPotential {
        :> scalar;
        unit = "V";
    }

    attribute def ElectricCurrent {
        :> scalar;
        unit = "A";
    }

    attribute def Resistance {
        :> scalar;
        unit = "ohm";
    }

    attribute def Percent {
        :> scalar;
        unit = "%";
    }

    attribute def Luminance {
        :> scalar;
        unit = "cd/m^2";
    }

    enum def GaugeOperatingMode {
        enum nominal;
        enum sensorFault;
        enum overTemperatureWarning;
        enum powerOff;
    }

    enum def DisplayScale {
        enum celsius;
        enum fahrenheit;
    }

    item def ThermalContact {
        attribute measuredTemperature : Temperature;
        attribute thermalResponseTime : TimeDuration;
    }

    item def SensorSignal {
        attribute resistance : Resistance;
        attribute sensedTemperature : Temperature;
        attribute valid : Boolean;
    }

    item def ConditionedTemperatureSignal {
        attribute temperature : Temperature;
        attribute confidence : Percent;
        attribute valid : Boolean;
    }

    item def DisplayCommand {
        attribute indicatedTemperature : Temperature;
        attribute mode : GaugeOperatingMode;
        attribute scale : DisplayScale;
        attribute warningActive : Boolean;
    }

    item def ElectricalPower {
        attribute voltage : ElectricPotential;
        attribute current : ElectricCurrent;
        attribute available : Boolean;
    }

    port def ThermalSensePort {
        in item thermalInput : ThermalContact;
    }

    port def SensorOutputPort {
        out item signal : SensorSignal;
    }

    port def SensorInputPort {
        in item signal : SensorSignal;
    }

    port def ConditionedSignalOutputPort {
        out item signal : ConditionedTemperatureSignal;
    }

    port def ConditionedSignalInputPort {
        in item signal : ConditionedTemperatureSignal;
    }

    port def DisplayCommandPort {
        in item command : DisplayCommand;
    }

    port def PowerInputPort {
        in item power : ElectricalPower;
    }

    port def PowerOutputPort {
        out item power : ElectricalPower;
    }

    port def VisualIndicationPort {
        out item command : DisplayCommand;
    }

    action def SenseCylinderHeadTemperature {
        in item thermalInput : ThermalContact;
        out item sensorSignal : SensorSignal;

        objective {
            doc "Convert cylinder head thermal contact temperature into an electrical sensor signal suitable for conditioning.";
        }
    }

    action def ConditionTemperatureSignal {
        in item sensorSignal : SensorSignal;
        out item conditionedSignal : ConditionedTemperatureSignal;

        objective {
            doc "Filter, linearize, validate, and scale the sensor signal into an engineering temperature value.";
        }
    }

    action def DetermineGaugeMode {
        in item conditionedSignal : ConditionedTemperatureSignal;
        in attribute warningThreshold : Temperature;
        out item displayCommand : DisplayCommand;

        objective {
            doc "Determine whether the displayed cylinder head temperature is nominal, warning, or sensor fault.";
        }
    }

    action def DisplayCylinderHeadTemperature {
        in item displayCommand : DisplayCommand;

        objective {
            doc "Present the current cylinder head temperature and warning state to the operator.";
        }
    }

    state def GaugePowerState {
        entry action initializeGauge;

        state powerOff;
        state selfTest;
        state normalOperation;
        state warningIndication;
        state faultIndication;

        transition first powerOff;

        transition powerOn
            first powerOff
            then selfTest;

        transition selfTestPassed
            first selfTest
            then normalOperation;

        transition temperatureAboveLimit
            first normalOperation
            then warningIndication;

        transition temperatureRecovered
            first warningIndication
            then normalOperation;

        transition invalidSensorDetected
            first normalOperation
            then faultIndication;

        transition invalidSensorDuringWarning
            first warningIndication
            then faultIndication;

        transition sensorRecovered
            first faultIndication
            then normalOperation;

        transition powerRemovedFromNormal
            first normalOperation
            then powerOff;

        transition powerRemovedFromWarning
            first warningIndication
            then powerOff;

        transition powerRemovedFromFault
            first faultIndication
            then powerOff;
    }

    part def CylinderHead {
        attribute actualHeadTemperature : Temperature;
        attribute normalOperatingTemperatureMin : Temperature = 120;
        attribute normalOperatingTemperatureMax : Temperature = 220;
        attribute maximumAllowableTemperature : Temperature = 260;

        port thermalInterface : ThermalSensePort;
    }

    part def TemperatureProbe {
        attribute measurementRangeMin : Temperature = 50;
        attribute measurementRangeMax : Temperature = 350;
        attribute accuracy : Temperature = 5;
        attribute responseTime : TimeDuration = 3;
        attribute nominalResistanceAt25C : Resistance = 1000;

        port thermalInput : ThermalSensePort;
        port electricalOutput : SensorOutputPort;

        perform action sense : SenseCylinderHeadTemperature {
            in thermalInput = thermalInput.thermalInput;
            out sensorSignal = electricalOutput.signal;
        }
    }

    part def SignalConditioner {
        attribute filterTimeConstant : TimeDuration = 0.5;
        attribute openCircuitResistanceLimit : Resistance = 1000000;
        attribute shortCircuitResistanceLimit : Resistance = 5;
        attribute outputUpdatePeriod : TimeDuration = 0.1;

        port sensorInput : SensorInputPort;
        port conditionedOutput : ConditionedSignalOutputPort;
        port powerInput : PowerInputPort;

        perform action condition : ConditionTemperatureSignal {
            in sensorSignal = sensorInput.signal;
            out conditionedSignal = conditionedOutput.signal;
        }
    }

    part def GaugeController {
        attribute warningThreshold : Temperature = 240;
        attribute warningHysteresis : Temperature = 10;
        attribute faultConfidenceMinimum : Percent = 80;
        attribute selectedScale : DisplayScale = DisplayScale::celsius;
        attribute currentMode : GaugeOperatingMode;

        port conditionedInput : ConditionedSignalInputPort;
        port displayOutput : VisualIndicationPort;
        port powerInput : PowerInputPort;

        exhibit state behavior : GaugePowerState;

        perform action determineMode : DetermineGaugeMode {
            in conditionedSignal = conditionedInput.signal;
            in warningThreshold = warningThreshold;
            out displayCommand = displayOutput.command;
        }
    }

    part def AnalogPointerDisplay {
        attribute indicatedMinimum : Temperature = 50;
        attribute indicatedMaximum : Temperature = 350;
        attribute pointerSettlingTime : TimeDuration = 1.0;
        attribute illumination : Luminance = 250;

        port commandInput : DisplayCommandPort;
        port powerInput : PowerInputPort;

        perform action displayTemperature : DisplayCylinderHeadTemperature {
            in displayCommand = commandInput.command;
        }
    }

    part def WarningAnnunciator {
        attribute activationTemperature : Temperature = 240;
        attribute minimumVisibleLuminance : Luminance = 500;

        port commandInput : DisplayCommandPort;
        port powerInput : PowerInputPort;
    }

    part def AircraftElectricalBus {
        attribute nominalVoltage : ElectricPotential = 28;
        attribute minimumOperatingVoltage : ElectricPotential = 18;
        attribute maximumOperatingVoltage : ElectricPotential = 32;
        attribute availableCurrent : ElectricCurrent = 2;

        port gaugePower : PowerOutputPort;
    }

    part def CylinderHeadTemperatureGaugeSystem {
        attribute indicatedTemperature : Temperature;
        attribute operatingMode : GaugeOperatingMode;
        attribute primaryFunction : String = "Measure cylinder head temperature and provide a clear operator indication, including warning and fault states.";

        part cylinderHead : CylinderHead;
        part probe : TemperatureProbe;
        part conditioner : SignalConditioner;
        part controller : GaugeController;
        part pointerDisplay : AnalogPointerDisplay;
        part annunciator : WarningAnnunciator;
        part electricalBus : AircraftElectricalBus;

        port sensedThermalInput : ThermalSensePort;
        port displayedIndication : VisualIndicationPort;

        connect cylinderHead.thermalInterface to probe.thermalInput;
        connect probe.electricalOutput to conditioner.sensorInput;
        connect conditioner.conditionedOutput to controller.conditionedInput;
        connect controller.displayOutput to pointerDisplay.commandInput;
        connect controller.displayOutput to annunciator.commandInput;
        connect controller.displayOutput to displayedIndication;
        connect electricalBus.gaugePower to conditioner.powerInput;
        connect electricalBus.gaugePower to controller.powerInput;
        connect electricalBus.gaugePower to pointerDisplay.powerInput;
        connect electricalBus.gaugePower to annunciator.powerInput;
        connect sensedThermalInput to probe.thermalInput;

        perform action endToEndTemperatureIndication {
            first start;
            then sense : SenseCylinderHeadTemperature {
                in thermalInput = probe.thermalInput.thermalInput;
                out sensorSignal = probe.electricalOutput.signal;
            }
            then condition : ConditionTemperatureSignal {
                in sensorSignal = conditioner.sensorInput.signal;
                out conditionedSignal = conditioner.conditionedOutput.signal;
            }
            then decide : DetermineGaugeMode {
                in conditionedSignal = controller.conditionedInput.signal;
                in warningThreshold = controller.warningThreshold;
                out displayCommand = controller.displayOutput.command;
            }
            then display : DisplayCylinderHeadTemperature {
                in displayCommand = pointerDisplay.commandInput.command;
            }
            then done;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc "The Cylinder Head Temperature gauge shall measure cylinder head temperature and display the current value to the operator at a high level suitable for engine thermal monitoring.";
    }

    requirement def MeasurementRangeRequirement {
        doc "The gauge shall indicate cylinder head temperatures from 50 degC to 350 degC.";
        require constraint {
            CylinderHeadTemperatureGaugeSystem::probe.measurementRangeMin <= 50 and
            CylinderHeadTemperatureGaugeSystem::probe.measurementRangeMax >= 350
        }
    }

    requirement def AccuracyRequirement {
        doc "The gauge shall report cylinder head temperature within plus or minus 5 degC under normal operating conditions.";
        require constraint {
            CylinderHeadTemperatureGaugeSystem::probe.accuracy <= 5
        }
    }

    requirement def WarningRequirement {
        doc "The gauge shall enter over-temperature warning mode when conditioned cylinder head temperature is at or above 240 degC.";
        require constraint {
            CylinderHeadTemperatureGaugeSystem::controller.warningThreshold == 240
        }
    }

    requirement def SensorFaultRequirement {
        doc "The gauge shall identify invalid sensor input and command a sensor fault indication instead of a normal temperature indication.";
    }

    requirement def PowerRequirement {
        doc "The gauge shall operate from a 28 VDC aircraft electrical bus over the voltage range of 18 VDC to 32 VDC.";
        require constraint {
            CylinderHeadTemperatureGaugeSystem::electricalBus.minimumOperatingVoltage <= 18 and
            CylinderHeadTemperatureGaugeSystem::electricalBus.maximumOperatingVoltage >= 32
        }
    }

    requirement def UpdateRateRequirement {
        doc "The gauge shall update the conditioned temperature indication at least once every 0.5 seconds.";
        require constraint {
            CylinderHeadTemperatureGaugeSystem::conditioner.outputUpdatePeriod <= 0.5
        }
    }

    satisfy PrimaryFunctionRequirement by CylinderHeadTemperatureGaugeSystem;
    satisfy MeasurementRangeRequirement by CylinderHeadTemperatureGaugeSystem::probe;
    satisfy AccuracyRequirement by CylinderHeadTemperatureGaugeSystem::probe;
    satisfy WarningRequirement by CylinderHeadTemperatureGaugeSystem::controller;
    satisfy SensorFaultRequirement by CylinderHeadTemperatureGaugeSystem::controller;
    satisfy PowerRequirement by CylinderHeadTemperatureGaugeSystem::electricalBus;
    satisfy UpdateRateRequirement by CylinderHeadTemperatureGaugeSystem::conditioner;

    view def HighLevelFunctionalView {
        expose CylinderHeadTemperatureGaugeSystem;
        expose CylinderHeadTemperatureGaugeSystem::cylinderHead;
        expose CylinderHeadTemperatureGaugeSystem::probe;
        expose CylinderHeadTemperatureGaugeSystem::conditioner;
        expose CylinderHeadTemperatureGaugeSystem::controller;
        expose CylinderHeadTemperatureGaugeSystem::pointerDisplay;
        expose CylinderHeadTemperatureGaugeSystem::annunciator;
    }

}