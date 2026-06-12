package MagneticFieldBasedSystemModel {

    import ScalarValues::*;

    attribute def Length {
        attribute value : Real;
        attribute unit : String = "m";
    }

    attribute def Area {
        attribute value : Real;
        attribute unit : String = "m^2";
    }

    attribute def Time {
        attribute value : Real;
        attribute unit : String = "s";
    }

    attribute def Frequency {
        attribute value : Real;
        attribute unit : String = "Hz";
    }

    attribute def ElectricCurrent {
        attribute value : Real;
        attribute unit : String = "A";
    }

    attribute def ElectricVoltage {
        attribute value : Real;
        attribute unit : String = "V";
    }

    attribute def ElectricalPower {
        attribute value : Real;
        attribute unit : String = "W";
    }

    attribute def Temperature {
        attribute value : Real;
        attribute unit : String = "degC";
    }

    attribute def MagneticFluxDensity {
        attribute value : Real;
        attribute unit : String = "T";
    }

    attribute def MagneticFieldStrength {
        attribute value : Real;
        attribute unit : String = "A/m";
    }

    attribute def MagneticFlux {
        attribute value : Real;
        attribute unit : String = "Wb";
    }

    attribute def Position3D {
        attribute x : Length;
        attribute y : Length;
        attribute z : Length;
    }

    attribute def Vector3D {
        attribute x : Real;
        attribute y : Real;
        attribute z : Real;
    }

    attribute def FieldVector {
        attribute fluxDensity : MagneticFluxDensity;
        attribute direction : Vector3D;
        attribute position : Position3D;
    }

    attribute def ControlMode {
        attribute name : String;
    }

    item def ElectricalEnergy {
        attribute voltage : ElectricVoltage;
        attribute current : ElectricCurrent;
        attribute power : ElectricalPower;
    }

    item def MagneticField {
        attribute fluxDensity : MagneticFluxDensity;
        attribute fieldStrength : MagneticFieldStrength;
        attribute flux : MagneticFlux;
        attribute direction : Vector3D;
        attribute fieldCenter : Position3D;
        attribute effectiveRadius : Length;
        attribute excitationFrequency : Frequency;
    }

    item def FieldCommand {
        attribute targetFluxDensity : MagneticFluxDensity;
        attribute targetFieldCenter : Position3D;
        attribute targetFrequency : Frequency;
        attribute mode : ControlMode;
    }

    item def FieldMeasurement {
        attribute measuredField : MagneticField;
        attribute sensorPosition : Position3D;
        attribute sampleTime : Time;
    }

    item def ThermalStatus {
        attribute coilTemperature : Temperature;
        attribute driverTemperature : Temperature;
        attribute heatSinkTemperature : Temperature;
    }

    item def HealthStatus {
        attribute ready : Boolean;
        attribute faultActive : Boolean;
        attribute faultCode : String;
    }

    port def PowerInputPort {
        in item powerIn : ElectricalEnergy;
    }

    port def CommandInputPort {
        in item commandIn : FieldCommand;
    }

    port def StatusOutputPort {
        out item statusOut : HealthStatus;
    }

    port def MagneticFieldOutputPort {
        out item fieldOut : MagneticField;
    }

    port def MagneticFieldInputPort {
        in item fieldIn : MagneticField;
    }

    port def MeasurementOutputPort {
        out item measurementOut : FieldMeasurement;
    }

    port def ThermalOutputPort {
        out item thermalOut : ThermalStatus;
    }

    part def CoilWinding {
        attribute turns : Integer;
        attribute wireGauge : String;
        attribute resistance : Real;
        attribute inductance : Real;
        attribute maxCurrent : ElectricCurrent;
        attribute windingArea : Area;

        port electricalInput : PowerInputPort;
        port magneticOutput : MagneticFieldOutputPort;
        port thermalOutput : ThermalOutputPort;
    }

    part def FerromagneticCore {
        attribute relativePermeability : Real;
        attribute saturationFluxDensity : MagneticFluxDensity;
        attribute coreLength : Length;
        attribute poleFaceArea : Area;

        port magneticInput : MagneticFieldInputPort;
        port shapedFieldOutput : MagneticFieldOutputPort;
    }

    part def PowerDriver {
        attribute dcBusVoltage : ElectricVoltage;
        attribute continuousPowerLimit : ElectricalPower;
        attribute switchingFrequency : Frequency;
        attribute currentLimit : ElectricCurrent;

        port supplyInput : PowerInputPort;
        port driveOutput : PowerInputPort;
        port statusOutput : StatusOutputPort;
    }

    part def MagneticSensor {
        attribute sensitivity : Real;
        attribute measurementRange : MagneticFluxDensity;
        attribute sampleRate : Frequency;
        attribute location : Position3D;

        port sensedFieldInput : MagneticFieldInputPort;
        port measurementOutput : MeasurementOutputPort;
    }

    part def FieldController {
        attribute controlLoopRate : Frequency;
        attribute nominalFluxDensity : MagneticFluxDensity;
        attribute maximumFluxDensity : MagneticFluxDensity;
        attribute regulationTolerance : MagneticFluxDensity;
        attribute activeMode : ControlMode;

        port commandInput : CommandInputPort;
        port measurementInput : MeasurementOutputPort;
        port driverCommandOutput : PowerInputPort;
        port statusOutput : StatusOutputPort;
    }

    part def ThermalManager {
        attribute fanStartTemperature : Temperature;
        attribute shutdownTemperature : Temperature;
        attribute coolantFlowEnabled : Boolean;

        port thermalInput : ThermalOutputPort;
        port statusOutput : StatusOutputPort;
    }

    part def MagneticShield {
        attribute shieldingFactor : Real;
        attribute enclosureThickness : Length;
        attribute leakageLimit : MagneticFluxDensity;

        port internalFieldInput : MagneticFieldInputPort;
        port attenuatedFieldOutput : MagneticFieldOutputPort;
    }

    action def ConvertElectricalPowerToMagnetomotiveForce {
        in item suppliedEnergy : ElectricalEnergy;
        in attribute windingTurns : Integer;
        out attribute coilCurrent : ElectricCurrent;
        out attribute magnetomotiveForce : Real;
    }

    action def GenerateMagneticField {
        in attribute coilCurrent : ElectricCurrent;
        in attribute corePermeability : Real;
        in attribute poleArea : Area;
        out item generatedField : MagneticField;
    }

    action def ShapeMagneticField {
        in item rawField : MagneticField;
        in attribute saturationLimit : MagneticFluxDensity;
        out item shapedField : MagneticField;
    }

    action def MeasureMagneticField {
        in item localField : MagneticField;
        in attribute sensorLocation : Position3D;
        out item measurement : FieldMeasurement;
    }

    action def RegulateMagneticField {
        in item command : FieldCommand;
        in item measurement : FieldMeasurement;
        out item driveEnergy : ElectricalEnergy;
        out item controllerStatus : HealthStatus;
    }

    action def ProtectFromOverTemperature {
        in item thermalStatus : ThermalStatus;
        in attribute shutdownLimit : Temperature;
        out item health : HealthStatus;
    }

    state def MagneticFieldSystemStateMachine {
        entry action initialize {
            out item initialStatus : HealthStatus;
        }

        state Off;
        state Initializing;
        state Standby;
        state Energizing;
        state RegulatingField;
        state Derating;
        state Faulted;
        state Shutdown;

        transition initial then Off;

        transition PowerApplied
            first Off
            accept item power : ElectricalEnergy
            then Initializing;

        transition InitializationComplete
            first Initializing
            if initialStatus.ready
            then Standby;

        transition CommandReceived
            first Standby
            accept item command : FieldCommand
            then Energizing;

        transition FieldDetected
            first Energizing
            then RegulatingField;

        transition ThermalDerateRequired
            first RegulatingField
            if true
            then Derating;

        transition ThermalRecovered
            first Derating
            then RegulatingField;

        transition FaultDetectedFromStandby
            first Standby
            then Faulted;

        transition FaultDetectedFromEnergizing
            first Energizing
            then Faulted;

        transition FaultDetectedFromRegulating
            first RegulatingField
            then Faulted;

        transition ResetFault
            first Faulted
            then Standby;

        transition PowerRemoved
            first Standby
            then Shutdown;

        transition ShutdownComplete
            first Shutdown
            then Off;
    }

    part def MagneticFieldBasedSystem {
        attribute primaryFunction : String =
            "Generate, shape, sense, and regulate a controlled magnetic field for contactless energy transfer, positioning, or actuation within a defined operating zone.";

        attribute operatingFieldCenter : Position3D {
            :>> x.value = 0.0;
            :>> y.value = 0.0;
            :>> z.value = 0.05;
        }

        attribute nominalField : MagneticFluxDensity {
            :>> value = 0.08;
        }

        attribute maximumField : MagneticFluxDensity {
            :>> value = 0.20;
        }

        attribute leakageFieldLimit : MagneticFluxDensity {
            :>> value = 0.0005;
        }

        attribute maximumCoilTemperature : Temperature {
            :>> value = 85.0;
        }

        port powerInput : PowerInputPort;
        port commandInput : CommandInputPort;
        port regulatedFieldOutput : MagneticFieldOutputPort;
        port statusOutput : StatusOutputPort;

        part driver : PowerDriver {
            :>> dcBusVoltage.value = 48.0;
            :>> continuousPowerLimit.value = 1200.0;
            :>> switchingFrequency.value = 20000.0;
            :>> currentLimit.value = 25.0;
        }

        part winding : CoilWinding {
            :>> turns = 420;
            :>> wireGauge = "AWG 14";
            :>> resistance = 1.8;
            :>> inductance = 0.042;
            :>> maxCurrent.value = 20.0;
            :>> windingArea.value = 0.012;
        }

        part core : FerromagneticCore {
            :>> relativePermeability = 1800.0;
            :>> saturationFluxDensity.value = 1.45;
            :>> coreLength.value = 0.18;
            :>> poleFaceArea.value = 0.009;
        }

        part sensorA : MagneticSensor {
            :>> sensitivity = 0.00001;
            :>> measurementRange.value = 0.30;
            :>> sampleRate.value = 2000.0;
            :>> location.x.value = -0.04;
            :>> location.y.value = 0.0;
            :>> location.z.value = 0.05;
        }

        part sensorB : MagneticSensor {
            :>> sensitivity = 0.00001;
            :>> measurementRange.value = 0.30;
            :>> sampleRate.value = 2000.0;
            :>> location.x.value = 0.04;
            :>> location.y.value = 0.0;
            :>> location.z.value = 0.05;
        }

        part controller : FieldController {
            :>> controlLoopRate.value = 1000.0;
            :>> nominalFluxDensity.value = 0.08;
            :>> maximumFluxDensity.value = 0.20;
            :>> regulationTolerance.value = 0.002;
            :>> activeMode.name = "ClosedLoopFieldRegulation";
        }

        part thermalManager : ThermalManager {
            :>> fanStartTemperature.value = 55.0;
            :>> shutdownTemperature.value = 85.0;
            :>> coolantFlowEnabled = true;
        }

        part shield : MagneticShield {
            :>> shieldingFactor = 120.0;
            :>> enclosureThickness.value = 0.003;
            :>> leakageLimit.value = 0.0005;
        }

        connection supplyToDriver connect powerInput to driver.supplyInput;
        connection commandToController connect commandInput to controller.commandInput;
        connection controllerToDriver connect controller.driverCommandOutput to driver.driveOutput;
        connection driverToCoil connect driver.driveOutput to winding.electricalInput;
        connection coilToCore connect winding.magneticOutput to core.magneticInput;
        connection coreToSensorA connect core.shapedFieldOutput to sensorA.sensedFieldInput;
        connection coreToSensorB connect core.shapedFieldOutput to sensorB.sensedFieldInput;
        connection sensorAToController connect sensorA.measurementOutput to controller.measurementInput;
        connection sensorBToController connect sensorB.measurementOutput to controller.measurementInput;
        connection coilThermalToManager connect winding.thermalOutput to thermalManager.thermalInput;
        connection coreToShield connect core.shapedFieldOutput to shield.internalFieldInput;
        connection shieldedOutput connect shield.attenuatedFieldOutput to regulatedFieldOutput;
        connection controllerStatus connect controller.statusOutput to statusOutput;

        perform action regulateField {
            first start;
            then action convert : ConvertElectricalPowerToMagnetomotiveForce;
            then action generate : GenerateMagneticField;
            then action shape : ShapeMagneticField;
            then action measureA : MeasureMagneticField;
            then action measureB : MeasureMagneticField;
            then action regulate : RegulateMagneticField;
            then done;
        }

        exhibit state systemBehavior : MagneticFieldSystemStateMachine;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : MagneticFieldBasedSystem;

        require constraint {
            system.primaryFunction ==
            "Generate, shape, sense, and regulate a controlled magnetic field for contactless energy transfer, positioning, or actuation within a defined operating zone."
        }
    }

    requirement def NominalFieldRequirement {
        subject system : MagneticFieldBasedSystem;

        require constraint {
            system.nominalField.value >= 0.05 and system.nominalField.value <= 0.10
        }
    }

    requirement def MaximumFieldRequirement {
        subject system : MagneticFieldBasedSystem;

        require constraint {
            system.maximumField.value <= 0.20
        }
    }

    requirement def LeakageFieldRequirement {
        subject system : MagneticFieldBasedSystem;

        require constraint {
            system.leakageFieldLimit.value <= 0.0005
        }
    }

    requirement def ThermalSafetyRequirement {
        subject system : MagneticFieldBasedSystem;

        require constraint {
            system.maximumCoilTemperature.value <= 85.0
        }
    }

    requirement def ClosedLoopControlRequirement {
        subject system : MagneticFieldBasedSystem;

        require constraint {
            system.controller.controlLoopRate.value >= 1000.0 and
            system.controller.regulationTolerance.value <= 0.002
        }
    }

    requirement def SensorCoverageRequirement {
        subject system : MagneticFieldBasedSystem;

        require constraint {
            system.sensorA.sampleRate.value >= 2000.0 and
            system.sensorB.sampleRate.value >= 2000.0 and
            system.sensorA.measurementRange.value >= system.maximumField.value and
            system.sensorB.measurementRange.value >= system.maximumField.value
        }
    }

    part magneticFieldSystem : MagneticFieldBasedSystem;

    satisfy PrimaryFunctionRequirement by magneticFieldSystem;
    satisfy NominalFieldRequirement by magneticFieldSystem;
    satisfy MaximumFieldRequirement by magneticFieldSystem;
    satisfy LeakageFieldRequirement by magneticFieldSystem;
    satisfy ThermalSafetyRequirement by magneticFieldSystem;
    satisfy ClosedLoopControlRequirement by magneticFieldSystem;
    satisfy SensorCoverageRequirement by magneticFieldSystem;
}