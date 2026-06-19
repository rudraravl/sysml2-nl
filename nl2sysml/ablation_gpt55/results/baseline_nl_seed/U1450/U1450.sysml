package MechanicalEnergyBasedSystemModel {
    import ScalarValues::*;

    enum def OperatingMode {
        enum stopped;
        enum charging;
        enum storing;
        enum discharging;
        enum braking;
        enum faulted;
    }

    enum def EnergyFlowDirection {
        enum intoSystem;
        enum outOfSystem;
        enum circulatingInternal;
        enum dissipated;
    }

    enum def FaultCode {
        enum none;
        enum overspeed;
        enum overtorque;
        enum highBearingTemperature;
        enum lowVacuum;
        enum controllerFailure;
        enum brakeFailure;
    }

    attribute def MechanicalEnergyJ {
        attribute value : Real;
        attribute unit : String = "J";
    }

    attribute def MechanicalPowerW {
        attribute value : Real;
        attribute unit : String = "W";
    }

    attribute def TorqueNm {
        attribute value : Real;
        attribute unit : String = "N*m";
    }

    attribute def AngularSpeedRadPerSec {
        attribute value : Real;
        attribute unit : String = "rad/s";
    }

    attribute def RotationalInertiaKgM2 {
        attribute value : Real;
        attribute unit : String = "kg*m^2";
    }

    attribute def MassKg {
        attribute value : Real;
        attribute unit : String = "kg";
    }

    attribute def TemperatureK {
        attribute value : Real;
        attribute unit : String = "K";
    }

    attribute def PressurePa {
        attribute value : Real;
        attribute unit : String = "Pa";
    }

    attribute def TimeS {
        attribute value : Real;
        attribute unit : String = "s";
    }

    attribute def VoltageV {
        attribute value : Real;
        attribute unit : String = "V";
    }

    attribute def CurrentA {
        attribute value : Real;
        attribute unit : String = "A";
    }

    attribute def EfficiencyRatio {
        attribute value : Real;
        attribute unit : String = "1";
    }

    attribute def GearRatio {
        attribute value : Real;
        attribute unit : String = "1";
    }

    item def RotationalMechanicalEnergyFlow {
        attribute energyIncrement : MechanicalEnergyJ;
        attribute power : MechanicalPowerW;
        attribute torque : TorqueNm;
        attribute angularSpeed : AngularSpeedRadPerSec;
        attribute direction : EnergyFlowDirection;
    }

    item def ThermalEnergyFlow {
        attribute heatRate : MechanicalPowerW;
        attribute sourceTemperature : TemperatureK;
        attribute sinkTemperature : TemperatureK;
    }

    item def ElectricalPowerFlow {
        attribute voltage : VoltageV;
        attribute current : CurrentA;
        attribute power : MechanicalPowerW;
    }

    item def ControlCommand {
        attribute commandIdentifier : Integer;
        attribute requestedMode : OperatingMode;
        attribute requestedOutputPower : MechanicalPowerW;
        attribute requestedOutputSpeed : AngularSpeedRadPerSec;
        attribute enableOutputClutch : Boolean;
        attribute enableBrake : Boolean;
    }

    item def SystemStatus {
        attribute currentMode : OperatingMode;
        attribute storedEnergy : MechanicalEnergyJ;
        attribute measuredRotorSpeed : AngularSpeedRadPerSec;
        attribute measuredOutputTorque : TorqueNm;
        attribute measuredBearingTemperature : TemperatureK;
        attribute measuredVacuumPressure : PressurePa;
        attribute faultActive : Boolean;
        attribute activeFaultCode : FaultCode;
    }

    port def RotationalMechanicalPort {
        inout item rotationalEnergyFlow : RotationalMechanicalEnergyFlow;
    }

    port def ElectricalPowerPort {
        inout item electricalPowerFlow : ElectricalPowerFlow;
    }

    port def ThermalPort {
        out item rejectedHeat : ThermalEnergyFlow;
    }

    port def ControlPort {
        in item command : ControlCommand;
        out item status : SystemStatus;
    }

    port def MeasurementPort {
        out item status : SystemStatus;
    }

    part def FlywheelRotor {
        attribute rotorMass : MassKg;
        attribute polarMomentOfInertia : RotationalInertiaKgM2;
        attribute maximumStoredEnergy : MechanicalEnergyJ;
        attribute nominalStoredEnergy : MechanicalEnergyJ;
        attribute maximumAngularSpeed : AngularSpeedRadPerSec;
        attribute minimumUsableAngularSpeed : AngularSpeedRadPerSec;
        attribute allowableTorque : TorqueNm;
        port hub : RotationalMechanicalPort;
        port telemetry : MeasurementPort;
    }

    part def MagneticBearingSet {
        attribute supportedMass : MassKg;
        attribute maximumBearingTemperature : TemperatureK;
        attribute nominalLossPower : MechanicalPowerW;
        port rotorInterface : RotationalMechanicalPort;
        port heatRejection : ThermalPort;
        port telemetry : MeasurementPort;
    }

    part def VacuumContainmentHousing {
        attribute internalPressure : PressurePa;
        attribute maximumAllowedPressure : PressurePa;
        attribute containmentMass : MassKg;
        attribute maximumWallTemperature : TemperatureK;
        port enclosedRotorInterface : RotationalMechanicalPort;
        port heatRejection : ThermalPort;
        port telemetry : MeasurementPort;
    }

    part def BidirectionalMotorGenerator {
        attribute peakMechanicalPower : MechanicalPowerW;
        attribute continuousMechanicalPower : MechanicalPowerW;
        attribute peakTorque : TorqueNm;
        attribute conversionEfficiency : EfficiencyRatio;
        port rotorSide : RotationalMechanicalPort;
        port dcElectricalSide : ElectricalPowerPort;
        port controllerSide : ControlPort;
        port heatRejection : ThermalPort;
    }

    part def TorqueCoupling {
        attribute maximumTransmittedTorque : TorqueNm;
        attribute engagementTime : TimeS;
        attribute engagedEfficiency : EfficiencyRatio;
        port sideA : RotationalMechanicalPort;
        port sideB : RotationalMechanicalPort;
        port controllerSide : ControlPort;
    }

    part def MechanicalGearbox {
        attribute inputOutputRatio : GearRatio;
        attribute ratedInputTorque : TorqueNm;
        attribute ratedOutputTorque : TorqueNm;
        attribute ratedPower : MechanicalPowerW;
        attribute mechanicalEfficiency : EfficiencyRatio;
        port highSpeedSide : RotationalMechanicalPort;
        port lowSpeedSide : RotationalMechanicalPort;
        port heatRejection : ThermalPort;
    }

    part def DynamicBrake {
        attribute brakingTorqueCapacity : TorqueNm;
        attribute brakingPowerCapacity : MechanicalPowerW;
        attribute maximumBrakeTemperature : TemperatureK;
        port frictionInterface : RotationalMechanicalPort;
        port controllerSide : ControlPort;
        port heatRejection : ThermalPort;
    }

    part def SpeedSensor {
        attribute measurementRange : AngularSpeedRadPerSec;
        attribute responseTime : TimeS;
        port measuredShaft : RotationalMechanicalPort;
        port telemetry : MeasurementPort;
    }

    part def TorqueSensor {
        attribute measurementRange : TorqueNm;
        attribute responseTime : TimeS;
        port measuredShaft : RotationalMechanicalPort;
        port telemetry : MeasurementPort;
    }

    part def ThermalManagementUnit {
        attribute heatRemovalCapacity : MechanicalPowerW;
        attribute nominalCoolantTemperature : TemperatureK;
        port heatInputFromMotorGenerator : ThermalPort;
        port heatInputFromBearings : ThermalPort;
        port heatInputFromHousing : ThermalPort;
        port heatInputFromBrake : ThermalPort;
    }

    action def StoreAndDeliverMechanicalEnergy {
        in command : ControlCommand;
        in chargeFlow : RotationalMechanicalEnergyFlow;
        out deliveredFlow : RotationalMechanicalEnergyFlow;
        out status : SystemStatus;
    }

    action def RegulateRotorSpeed {
        in requestedSpeed : AngularSpeedRadPerSec;
        in measuredSpeed : AngularSpeedRadPerSec;
        out commandedTorque : TorqueNm;
    }

    action def ProtectAgainstUnsafeMechanicalEnergy {
        in measuredSpeed : AngularSpeedRadPerSec;
        in measuredTorque : TorqueNm;
        in measuredBearingTemperature : TemperatureK;
        in measuredVacuumPressure : PressurePa;
        out protectiveCommand : ControlCommand;
    }

    action def ConvertStoredKineticEnergyToOutputShaftPower {
        in storedEnergy : MechanicalEnergyJ;
        in requestedPower : MechanicalPowerW;
        out outputFlow : RotationalMechanicalEnergyFlow;
    }

    state def MechanicalEnergyOperatingStates {
        entry; then stopped;

        state stopped;
        state charging;
        state storing;
        state discharging;
        state braking;
        state faulted;

        transition stoppedToCharging
            first stopped
            then charging;

        transition chargingToStoring
            first charging
            then storing;

        transition storingToDischarging
            first storing
            then discharging;

        transition dischargingToStoring
            first discharging
            then storing;

        transition chargingToBraking
            first charging
            then braking;

        transition dischargingToBraking
            first discharging
            then braking;

        transition brakingToStopped
            first braking
            then stopped;

        transition stoppedToFaulted
            first stopped
            then faulted;

        transition chargingToFaulted
            first charging
            then faulted;

        transition storingToFaulted
            first storing
            then faulted;

        transition dischargingToFaulted
            first discharging
            then faulted;

        transition brakingToFaulted
            first braking
            then faulted;
    }

    part def FlywheelMechanicalEnergySystem {
        attribute primaryFunctionDescription : String = "Store mechanical energy as rotational kinetic energy in a flywheel and deliver regulated rotational mechanical power through an output shaft.";
        attribute ratedStoredEnergy : MechanicalEnergyJ;
        attribute minimumUsableStoredEnergy : MechanicalEnergyJ;
        attribute ratedOutputPower : MechanicalPowerW;
        attribute minimumContinuousOutputPower : MechanicalPowerW;
        attribute peakOutputTorque : TorqueNm;
        attribute ratedRotorSpeed : AngularSpeedRadPerSec;
        attribute maximumSafeRotorSpeed : AngularSpeedRadPerSec;
        attribute roundTripMechanicalEfficiency : EfficiencyRatio;
        attribute maximumHousingPressure : PressurePa;
        attribute maximumBearingTemperature : TemperatureK;

        port chargeDrivePort : RotationalMechanicalPort;
        port outputDrivePort : RotationalMechanicalPort;
        port auxiliaryElectricalPort : ElectricalPowerPort;
        port commandAndStatusPort : ControlPort;
        port rejectedHeatPort : ThermalPort;

        part rotor : FlywheelRotor;
        part bearings : MagneticBearingSet;
        part vacuumHousing : VacuumContainmentHousing;
        part motorGenerator : BidirectionalMotorGenerator;
        part inputCoupling : TorqueCoupling;
        part outputCoupling : TorqueCoupling;
        part outputGearbox : MechanicalGearbox;
        part brake : DynamicBrake;
        part speedSensor : SpeedSensor;
        part torqueSensor : TorqueSensor;
        part thermalManagement : ThermalManagementUnit;

        connect chargeDrivePort to inputCoupling.sideA;
        connect inputCoupling.sideB to rotor.hub;
        connect rotor.hub to bearings.rotorInterface;
        connect rotor.hub to vacuumHousing.enclosedRotorInterface;
        connect rotor.hub to motorGenerator.rotorSide;
        connect motorGenerator.dcElectricalSide to auxiliaryElectricalPort;
        connect rotor.hub to outputCoupling.sideA;
        connect outputCoupling.sideB to outputGearbox.highSpeedSide;
        connect outputGearbox.lowSpeedSide to outputDrivePort;
        connect rotor.hub to brake.frictionInterface;
        connect rotor.hub to speedSensor.measuredShaft;
        connect outputGearbox.lowSpeedSide to torqueSensor.measuredShaft;
        connect commandAndStatusPort to motorGenerator.controllerSide;
        connect commandAndStatusPort to inputCoupling.controllerSide;
        connect commandAndStatusPort to outputCoupling.controllerSide;
        connect commandAndStatusPort to brake.controllerSide;
        connect motorGenerator.heatRejection to thermalManagement.heatInputFromMotorGenerator;
        connect bearings.heatRejection to thermalManagement.heatInputFromBearings;
        connect vacuumHousing.heatRejection to thermalManagement.heatInputFromHousing;
        connect brake.heatRejection to thermalManagement.heatInputFromBrake;

        perform action primaryEnergyFunction : StoreAndDeliverMechanicalEnergy;
        perform action speedRegulation : RegulateRotorSpeed;
        perform action protectionFunction : ProtectAgainstUnsafeMechanicalEnergy;
        perform action dischargeConversion : ConvertStoredKineticEnergyToOutputShaftPower;

        exhibit state operatingStates : MechanicalEnergyOperatingStates;
    }

    requirement def PrimaryMechanicalEnergyFunctionRequirement {
        subject system : FlywheelMechanicalEnergySystem;
        attribute statement : String = "The system shall use mechanical rotational energy as its basis by storing kinetic energy in the flywheel rotor and delivering controlled mechanical shaft power at the output drive port.";
        require constraint mechanicalEnergyCapacity {
            system.ratedStoredEnergy.value >= system.minimumUsableStoredEnergy.value
        }
        require constraint outputPowerCapability {
            system.ratedOutputPower.value >= system.minimumContinuousOutputPower.value
        }
        require constraint safeRotorSpeed {
            system.maximumSafeRotorSpeed.value >= system.ratedRotorSpeed.value
        }
    }

    requirement def ControlledOutputRequirement {
        subject system : FlywheelMechanicalEnergySystem;
        attribute statement : String = "The system shall regulate output torque and speed while transitioning among charging, storing, discharging, braking, and faulted operating modes.";
        require constraint torqueCapability {
            system.peakOutputTorque.value > 0.0
        }
        require constraint efficiencyPositive {
            system.roundTripMechanicalEfficiency.value > 0.0
        }
    }

    requirement def ContainmentAndThermalSafetyRequirement {
        subject system : FlywheelMechanicalEnergySystem;
        attribute statement : String = "The system shall maintain safe containment pressure and bearing temperature while mechanical energy is stored in the rotor.";
        require constraint pressureLimitDefined {
            system.maximumHousingPressure.value > 0.0
        }
        require constraint temperatureLimitDefined {
            system.maximumBearingTemperature.value > 0.0
        }
    }

    part mechanicalEnergyStorageSystem : FlywheelMechanicalEnergySystem;
}
