package HeadacheHatTherapySystem {
    import ScalarValues::*;
    import Quantities::*;
    import MeasurementReferences::*;

    attribute def Temperature {
        attribute value : Real;
        attribute unit : String = "degC";
    }

    attribute def Duration {
        attribute value : Real;
        attribute unit : String = "min";
    }

    attribute def Pressure {
        attribute value : Real;
        attribute unit : String = "kPa";
    }

    attribute def Mass {
        attribute value : Real;
        attribute unit : String = "g";
    }

    attribute def Energy {
        attribute value : Real;
        attribute unit : String = "Wh";
    }

    attribute def Percentage {
        attribute value : Real;
        attribute unit : String = "%";
    }

    item def ThermalEnergy {
        attribute heatFlowRate : Real;
        attribute heatFlowUnit : String = "W";
    }

    item def UserCommand {
        attribute requestedMode : TherapyMode;
        attribute requestedDuration : Duration;
        attribute requestedCompression : Pressure;
    }

    item def TherapyStatus {
        attribute activeMode : TherapyMode;
        attribute elapsedTime : Duration;
        attribute remainingTime : Duration;
        attribute averagePadTemperature : Temperature;
        attribute batteryStateOfCharge : Percentage;
    }

    item def AlertSignal {
        attribute alertKind : AlertKind;
        attribute severity : AlertSeverity;
    }

    enum def TherapyMode {
        enum none;
        enum cooling;
        enum gentleCompression;
        enum coolingAndCompression;
        enum standby;
    }

    enum def AlertKind {
        enum temperatureTooLow;
        enum temperatureTooHigh;
        enum sessionComplete;
        enum batteryLow;
        enum sensorFault;
        enum fitAdjustmentNeeded;
    }

    enum def AlertSeverity {
        enum advisory;
        enum caution;
        enum stopTherapy;
    }

    port def ThermalInterfacePort {
        out item thermalEnergy : ThermalEnergy;
        attribute contactTemperature : Temperature;
        attribute contactArea : Real;
    }

    port def CommandPort {
        in item command : UserCommand;
    }

    port def StatusPort {
        out item status : TherapyStatus;
        out item alert : AlertSignal;
    }

    port def PowerPort {
        in item electricalEnergy : Energy;
        attribute voltage : Real;
        attribute voltageUnit : String = "V";
        attribute current : Real;
        attribute currentUnit : String = "A";
    }

    port def SensorPort {
        out attribute measuredTemperature : Temperature;
        out attribute measuredPressure : Pressure;
        out attribute sensorHealthy : Boolean;
    }

    part def HeadacheHatSystem {
        attribute systemMassLimit : Mass = (value = 650.0; unit = "g");
        attribute nominalTherapyDuration : Duration = (value = 20.0; unit = "min");
        attribute safeMinimumTemperature : Temperature = (value = 4.0; unit = "degC");
        attribute safeMaximumTemperature : Temperature = (value = 18.0; unit = "degC");
        attribute maximumCompressionPressure : Pressure = (value = 8.0; unit = "kPa");

        port userCommands : CommandPort;
        port userFeedback : StatusPort;
        port externalPower : PowerPort;

        part wearableHat : WearableTherapyHat;
        part controller : TherapyController;
        part powerSubsystem : PowerSubsystem;
        part userInterface : UserInterface;
        part safetyMonitor : SafetyMonitor;

        connect userCommands to userInterface.commandInput;
        connect userInterface.controllerCommand to controller.commandInput;
        connect controller.statusOutput to userInterface.statusInput;
        connect userInterface.statusOutput to userFeedback;

        connect externalPower to powerSubsystem.chargeInput;
        connect powerSubsystem.controlPower to controller.powerInput;
        connect powerSubsystem.therapyPower to wearableHat.powerInput;
        connect wearableHat.sensorOutput to safetyMonitor.sensorInput;
        connect controller.controlOutput to wearableHat.controlInput;
        connect safetyMonitor.safetyStatus to controller.safetyInput;
        connect controller.statusOutput to safetyMonitor.controllerStatusInput;
    }

    part def WearableTherapyHat {
        attribute totalMass : Mass = (value = 520.0; unit = "g");
        attribute headCoverageFraction : Percentage = (value = 82.0; unit = "%");
        attribute adjustableCircumferenceMin : Real = 52.0;
        attribute adjustableCircumferenceMax : Real = 62.0;
        attribute circumferenceUnit : String = "cm";

        port powerInput : PowerPort;
        port controlInput : CommandPort;
        port sensorOutput : SensorPort;
        port foreheadThermalContact : ThermalInterfacePort;
        port crownThermalContact : ThermalInterfacePort;
        port templeThermalContact : ThermalInterfacePort;

        part textileShell : InsulatedTextileShell;
        part coolingLiner : CoolingLiner;
        part compressionBand : CompressionBand;
        part temperatureSensorForehead : TemperatureSensor;
        part temperatureSensorCrown : TemperatureSensor;
        part pressureSensorBand : PressureSensor;

        connect coolingLiner.foreheadPad to foreheadThermalContact;
        connect coolingLiner.crownPad to crownThermalContact;
        connect coolingLiner.templePad to templeThermalContact;
        connect temperatureSensorForehead.sensorPort to sensorOutput;
        connect pressureSensorBand.sensorPort to sensorOutput;
    }

    part def InsulatedTextileShell {
        attribute outerLayerMaterial : String = "stretch nylon";
        attribute innerLayerMaterial : String = "soft antimicrobial fabric";
        attribute thermalResistance : Real = 0.42;
        attribute thermalResistanceUnit : String = "m2*K/W";
        attribute washable : Boolean = true;
    }

    part def CoolingLiner {
        attribute phaseChangeTemperature : Temperature = (value = 10.0; unit = "degC");
        attribute coolingCapacity : Energy = (value = 18.0; unit = "Wh");
        attribute reusable : Boolean = true;

        port foreheadPad : ThermalInterfacePort;
        port crownPad : ThermalInterfacePort;
        port templePad : ThermalInterfacePort;

        part gelChannels : GelChannel[12];
        part thermalSpreader : FlexibleThermalSpreader;
    }

    part def GelChannel {
        attribute gelMass : Mass = (value = 24.0; unit = "g");
        attribute targetTemperature : Temperature = (value = 10.0; unit = "degC");
        attribute minimumAllowedTemperature : Temperature = (value = 4.0; unit = "degC");
    }

    part def FlexibleThermalSpreader {
        attribute material : String = "graphite polymer laminate";
        attribute thickness : Real = 0.6;
        attribute thicknessUnit : String = "mm";
        attribute conductivity : Real = 6.5;
        attribute conductivityUnit : String = "W/(m*K)";
    }

    part def CompressionBand {
        attribute minimumPressure : Pressure = (value = 1.0; unit = "kPa");
        attribute nominalPressure : Pressure = (value = 4.0; unit = "kPa");
        attribute maximumPressure : Pressure = (value = 8.0; unit = "kPa");
        attribute adjustmentType : String = "elastic strap with micro-ratchet";

        part leftTempleZone : CompressionZone;
        part rightTempleZone : CompressionZone;
        part foreheadZone : CompressionZone;
    }

    part def CompressionZone {
        attribute appliedPressure : Pressure;
        attribute contactWidth : Real;
        attribute contactWidthUnit : String = "cm";
    }

    part def TemperatureSensor {
        attribute accuracy : Temperature = (value = 0.5; unit = "degC");
        attribute samplePeriod : Real = 1.0;
        attribute samplePeriodUnit : String = "s";
        port sensorPort : SensorPort;
    }

    part def PressureSensor {
        attribute accuracy : Pressure = (value = 0.3; unit = "kPa");
        attribute samplePeriod : Real = 1.0;
        attribute samplePeriodUnit : String = "s";
        port sensorPort : SensorPort;
    }

    part def TherapyController {
        attribute selectedMode : TherapyMode = TherapyMode::standby;
        attribute sessionDuration : Duration = (value = 20.0; unit = "min");
        attribute elapsedSessionTime : Duration = (value = 0.0; unit = "min");

        port commandInput : CommandPort;
        port controlOutput : CommandPort;
        port statusOutput : StatusPort;
        port safetyInput : StatusPort;
        port powerInput : PowerPort;

        perform action provideHeadacheTherapy : ProvideHeadacheTherapy;
        exhibit state therapyStateMachine : TherapyOperatingStates;
    }

    part def SafetyMonitor {
        attribute lowTemperatureLimit : Temperature = (value = 4.0; unit = "degC");
        attribute highTemperatureLimit : Temperature = (value = 18.0; unit = "degC");
        attribute pressureLimit : Pressure = (value = 8.0; unit = "kPa");

        port sensorInput : SensorPort;
        port controllerStatusInput : StatusPort;
        port safetyStatus : StatusPort;

        perform action evaluateSafety : EvaluateTherapySafety;
    }

    part def UserInterface {
        attribute hasModeButton : Boolean = true;
        attribute hasDurationButton : Boolean = true;
        attribute hasStatusLight : Boolean = true;
        attribute hasHapticFeedback : Boolean = true;

        port commandInput : CommandPort;
        port controllerCommand : CommandPort;
        port statusInput : StatusPort;
        port statusOutput : StatusPort;
    }

    part def PowerSubsystem {
        attribute batteryCapacity : Energy = (value = 9.0; unit = "Wh");
        attribute lowBatteryThreshold : Percentage = (value = 15.0; unit = "%");
        attribute nominalVoltage : Real = 3.7;
        attribute voltageUnit : String = "V";

        port chargeInput : PowerPort;
        port controlPower : PowerPort;
        port therapyPower : PowerPort;

        part battery : RechargeableBattery;
        part powerManager : PowerManager;
    }

    part def RechargeableBattery {
        attribute chemistry : String = "lithium-ion";
        attribute capacity : Energy = (value = 9.0; unit = "Wh");
        attribute stateOfCharge : Percentage;
        attribute rechargeable : Boolean = true;
    }

    part def PowerManager {
        attribute overCurrentProtected : Boolean = true;
        attribute chargeLimited : Boolean = true;
        attribute outputVoltage : Real = 3.7;
        attribute voltageUnit : String = "V";
    }

    action def ProvideHeadacheTherapy {
        in item command : UserCommand;
        in attribute sensedTemperature : Temperature;
        in attribute sensedPressure : Pressure;
        out item status : TherapyStatus;
        out item alert : AlertSignal;

        first startSession;
        then selectRequestedMode;
        then regulateCoolingContact;
        then regulateCompressionFit;
        then monitorComfortAndSafety;
        then completeSession;

        action startSession;
        action selectRequestedMode;
        action regulateCoolingContact;
        action regulateCompressionFit;
        action monitorComfortAndSafety;
        action completeSession;
    }

    action def EvaluateTherapySafety {
        in attribute measuredTemperature : Temperature;
        in attribute measuredPressure : Pressure;
        in attribute sensorHealthy : Boolean;
        out item alert : AlertSignal;

        first checkSensorHealth;
        then checkTemperatureRange;
        then checkPressureRange;
        then issueSafetyStatus;

        action checkSensorHealth;
        action checkTemperatureRange;
        action checkPressureRange;
        action issueSafetyStatus;
    }

    state def TherapyOperatingStates {
        entry; then Standby;

        state Standby;
        state Fitting;
        state CoolingReady;
        state ActiveTherapy;
        state Paused;
        state Completed;
        state Fault;

        transition Standby_to_Fitting
            first Standby
            accept UserCommand
            if command.requestedMode != TherapyMode::none
            then Fitting;

        transition Fitting_to_CoolingReady
            first Fitting
            if fitPressureWithinRange
            then CoolingReady;

        transition CoolingReady_to_ActiveTherapy
            first CoolingReady
            if averagePadTemperatureWithinTherapyRange
            then ActiveTherapy;

        transition ActiveTherapy_to_Paused
            first ActiveTherapy
            accept UserCommand
            if command.requestedMode == TherapyMode::standby
            then Paused;

        transition Paused_to_ActiveTherapy
            first Paused
            accept UserCommand
            if command.requestedMode == TherapyMode::coolingAndCompression
            then ActiveTherapy;

        transition ActiveTherapy_to_Completed
            first ActiveTherapy
            if elapsedSessionTime >= sessionDuration
            then Completed;

        transition ActiveTherapy_to_Fault
            first ActiveTherapy
            if temperatureOutOfSafeRange or pressureOutOfSafeRange or sensorFaultDetected
            then Fault;

        transition Fault_to_Standby
            first Fault
            accept UserCommand
            if command.requestedMode == TherapyMode::none
            then Standby;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : HeadacheHatSystem;

        doc /* The Headache Hat shall provide a wearable, reusable therapy system whose primary high-level function is to reduce headache discomfort by applying controlled cooling and gentle, adjustable compression to the user's forehead, temples, and crown while monitoring temperature, pressure, duration, power, and safety status. */

        require constraint {
            system.nominalTherapyDuration.value >= 10.0 and
            system.nominalTherapyDuration.value <= 30.0
        }
    }

    requirement def CoolingSafetyRequirement {
        subject system : HeadacheHatSystem;

        require constraint {
            system.safeMinimumTemperature.value >= 4.0 and
            system.safeMaximumTemperature.value <= 18.0
        }
    }

    requirement def CompressionSafetyRequirement {
        subject system : HeadacheHatSystem;

        require constraint {
            system.maximumCompressionPressure.value <= 8.0
        }
    }

    requirement def WearabilityRequirement {
        subject hat : WearableTherapyHat;

        require constraint {
            hat.totalMass.value <= 650.0 and
            hat.headCoverageFraction.value >= 75.0
        }
    }

    requirement def ReusableTherapyRequirement {
        subject liner : CoolingLiner;

        require constraint {
            liner.reusable == true and
            liner.coolingCapacity.value >= 12.0
        }
    }

    requirement def UserFeedbackRequirement {
        subject interface : UserInterface;

        require constraint {
            interface.hasStatusLight == true and
            interface.hasHapticFeedback == true
        }
    }

    requirement def PowerRequirement {
        subject power : PowerSubsystem;

        require constraint {
            power.batteryCapacity.value >= 8.0 and
            power.lowBatteryThreshold.value <= 20.0
        }
    }

    satisfy PrimaryFunctionRequirement by HeadacheHatSystem;
    satisfy CoolingSafetyRequirement by HeadacheHatSystem;
    satisfy CompressionSafetyRequirement by HeadacheHatSystem;
    satisfy WearabilityRequirement by WearableTherapyHat;
    satisfy ReusableTherapyRequirement by CoolingLiner;
    satisfy UserFeedbackRequirement by UserInterface;
    satisfy PowerRequirement by PowerSubsystem;

    part headacheHatProduct : HeadacheHatSystem;
}