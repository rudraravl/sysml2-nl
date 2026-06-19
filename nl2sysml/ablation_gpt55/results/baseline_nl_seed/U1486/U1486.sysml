package RotaryEngineSystemModel {
    private import ScalarValues::*;

    enum def EngineeringUnit {
        enum one;
        enum rpm;
        enum deg;
        enum kW;
        enum N_m;
        enum kPa;
        enum degC;
        enum L_per_h;
        enum kg_per_h;
        enum g_per_kWh;
        enum cm3;
        enum mm;
        enum V;
        enum A;
    }

    attribute def UnitValue {
        attribute value : Real;
        attribute unit : EngineeringUnit;
    }

    attribute def RatioValue :> UnitValue {
        :>> unit = EngineeringUnit::one;
    }

    attribute def SpeedValue :> UnitValue {
        :>> unit = EngineeringUnit::rpm;
    }

    attribute def AngleValue :> UnitValue {
        :>> unit = EngineeringUnit::deg;
    }

    attribute def PowerValue :> UnitValue {
        :>> unit = EngineeringUnit::kW;
    }

    attribute def TorqueValue :> UnitValue {
        :>> unit = EngineeringUnit::N_m;
    }

    attribute def PressureValue :> UnitValue {
        :>> unit = EngineeringUnit::kPa;
    }

    attribute def TemperatureValue :> UnitValue {
        :>> unit = EngineeringUnit::degC;
    }

    attribute def VolumeValue :> UnitValue {
        :>> unit = EngineeringUnit::cm3;
    }

    attribute def LengthValue :> UnitValue {
        :>> unit = EngineeringUnit::mm;
    }

    attribute def FuelFlowValue :> UnitValue {
        :>> unit = EngineeringUnit::L_per_h;
    }

    attribute def MassFlowValue :> UnitValue {
        :>> unit = EngineeringUnit::kg_per_h;
    }

    attribute def SpecificFuelConsumptionValue :> UnitValue {
        :>> unit = EngineeringUnit::g_per_kWh;
    }

    attribute def VoltageValue :> UnitValue {
        :>> unit = EngineeringUnit::V;
    }

    attribute def CurrentValue :> UnitValue {
        :>> unit = EngineeringUnit::A;
    }

    item def Gasoline {
        attribute researchOctaneNumber : Integer = 95;
        attribute lowerHeatingValue : Real = 43.0;
        attribute commandedFuelFlow : FuelFlowValue {
            :>> value = 0.0;
            :>> unit = EngineeringUnit::L_per_h;
        }
    }

    item def IntakeAir {
        attribute inletPressure : PressureValue {
            :>> value = 101.3;
            :>> unit = EngineeringUnit::kPa;
        }
        attribute inletTemperature : TemperatureValue {
            :>> value = 25.0;
            :>> unit = EngineeringUnit::degC;
        }
        attribute massFlow : MassFlowValue {
            :>> value = 0.0;
            :>> unit = EngineeringUnit::kg_per_h;
        }
    }

    item def MeteredAirFuelMixture {
        attribute equivalenceRatio : RatioValue {
            :>> value = 1.0;
            :>> unit = EngineeringUnit::one;
        }
        attribute mixturePressure : PressureValue {
            :>> value = 95.0;
            :>> unit = EngineeringUnit::kPa;
        }
        attribute mixtureTemperature : TemperatureValue {
            :>> value = 35.0;
            :>> unit = EngineeringUnit::degC;
        }
    }

    item def IgnitionSpark {
        attribute advanceAngle : AngleValue {
            :>> value = 18.0;
            :>> unit = EngineeringUnit::deg;
        }
        attribute enabled : Boolean = false;
    }

    item def CombustionGas {
        attribute gasPressure : PressureValue {
            :>> value = 850.0;
            :>> unit = EngineeringUnit::kPa;
        }
        attribute gasTemperature : TemperatureValue {
            :>> value = 850.0;
            :>> unit = EngineeringUnit::degC;
        }
    }

    item def ExhaustGas {
        attribute outletTemperature : TemperatureValue {
            :>> value = 720.0;
            :>> unit = EngineeringUnit::degC;
        }
        attribute outletPressure : PressureValue {
            :>> value = 112.0;
            :>> unit = EngineeringUnit::kPa;
        }
    }

    item def Coolant {
        attribute temperature : TemperatureValue {
            :>> value = 90.0;
            :>> unit = EngineeringUnit::degC;
        }
        attribute pressure : PressureValue {
            :>> value = 120.0;
            :>> unit = EngineeringUnit::kPa;
        }
    }

    item def LubricatingOil {
        attribute oilPressure : PressureValue {
            :>> value = 420.0;
            :>> unit = EngineeringUnit::kPa;
        }
        attribute oilTemperature : TemperatureValue {
            :>> value = 95.0;
            :>> unit = EngineeringUnit::degC;
        }
    }

    item def RotaryTorque {
        attribute torque : TorqueValue {
            :>> value = 220.0;
            :>> unit = EngineeringUnit::N_m;
        }
        attribute rotorSpeed : SpeedValue {
            :>> value = 6000.0;
            :>> unit = EngineeringUnit::rpm;
        }
    }

    item def RotaryShaftPower {
        attribute power : PowerValue {
            :>> value = 170.0;
            :>> unit = EngineeringUnit::kW;
        }
        attribute speed : SpeedValue {
            :>> value = 6000.0;
            :>> unit = EngineeringUnit::rpm;
        }
        attribute torque : TorqueValue {
            :>> value = 220.0;
            :>> unit = EngineeringUnit::N_m;
        }
    }

    item def EngineCommand {
        attribute startRequested : Boolean = false;
        attribute stopRequested : Boolean = false;
        attribute throttleDemand : RatioValue {
            :>> value = 0.0;
            :>> unit = EngineeringUnit::one;
        }
        attribute targetSpeed : SpeedValue {
            :>> value = 0.0;
            :>> unit = EngineeringUnit::rpm;
        }
    }

    item def EngineStatus {
        attribute running : Boolean = false;
        attribute faultPresent : Boolean = false;
        attribute measuredSpeed : SpeedValue {
            :>> value = 0.0;
            :>> unit = EngineeringUnit::rpm;
        }
        attribute deliveredPower : PowerValue {
            :>> value = 0.0;
            :>> unit = EngineeringUnit::kW;
        }
    }

    item def StartCommand :> EngineCommand;
    item def StopCommand :> EngineCommand;
    item def StableIdleDetected :> EngineStatus;
    item def OverspeedDetected :> EngineStatus;
    item def FaultDetected :> EngineStatus;

    port def FuelInPort {
        in item fuel : Gasoline;
    }

    port def FuelOutPort {
        out item fuel : Gasoline;
    }

    port def AirInPort {
        in item air : IntakeAir;
    }

    port def AirOutPort {
        out item air : IntakeAir;
    }

    port def MixtureInPort {
        in item mixture : MeteredAirFuelMixture;
    }

    port def MixtureOutPort {
        out item mixture : MeteredAirFuelMixture;
    }

    port def SparkInPort {
        in item spark : IgnitionSpark;
    }

    port def SparkOutPort {
        out item spark : IgnitionSpark;
    }

    port def CombustionGasOutPort {
        out item combustionGas : CombustionGas;
    }

    port def CombustionGasInPort {
        in item combustionGas : CombustionGas;
    }

    port def ExhaustOutPort {
        out item exhaust : ExhaustGas;
    }

    port def CoolantInPort {
        in item coolant : Coolant;
    }

    port def CoolantOutPort {
        out item coolant : Coolant;
    }

    port def OilInPort {
        in item oil : LubricatingOil;
    }

    port def OilOutPort {
        out item oil : LubricatingOil;
    }

    port def TorqueInPort {
        in item torque : RotaryTorque;
    }

    port def TorqueOutPort {
        out item torque : RotaryTorque;
    }

    port def ShaftPowerOutPort {
        out item shaftPower : RotaryShaftPower;
    }

    port def CommandInPort {
        in item command : EngineCommand;
    }

    port def CommandOutPort {
        out item command : EngineCommand;
    }

    port def StatusOutPort {
        out item status : EngineStatus;
    }

    port def StatusInPort {
        in item status : EngineStatus;
    }

    action def MeterFuelAndAir {
        in item fuel : Gasoline;
        in item air : IntakeAir;
        in item command : EngineCommand;
        out item mixture : MeteredAirFuelMixture;
    }

    action def CompressMixtureInRotorChamber {
        in item mixture : MeteredAirFuelMixture;
        out item compressedMixture : MeteredAirFuelMixture;
    }

    action def IgniteAndExpandCombustion {
        in item compressedMixture : MeteredAirFuelMixture;
        in item spark : IgnitionSpark;
        out item combustionGas : CombustionGas;
        out item torque : RotaryTorque;
    }

    action def ExhaustCombustionProducts {
        in item combustionGas : CombustionGas;
        out item exhaust : ExhaustGas;
    }

    action def ConvertFuelAndAirToRotaryOutput {
        in item suppliedFuel : Gasoline;
        in item suppliedAir : IntakeAir;
        in item engineCommand : EngineCommand;
        out item deliveredShaftPower : RotaryShaftPower;
        out item dischargedExhaust : ExhaustGas;

        action meter : MeterFuelAndAir;
        action compress : CompressMixtureInRotorChamber;
        action burnAndExpand : IgniteAndExpandCombustion;
        action exhaust : ExhaustCombustionProducts;

        succession meter then compress;
        succession compress then burnAndExpand;
        succession burnAndExpand then exhaust;
    }

    state def RotaryEngineLifecycle {
        state stopped;
        state starting;
        state idle;
        state producingPower;
        state shuttingDown;
        state faulted;

        transition initial_to_stopped then stopped;

        transition start_engine
            first stopped
            accept StartCommand
            then starting;

        transition stabilized_idle
            first starting
            accept StableIdleDetected
            then idle;

        transition throttle_applied
            first idle
            accept EngineCommand
            then producingPower;

        transition return_to_idle
            first producingPower
            accept EngineCommand
            then idle;

        transition commanded_shutdown_from_idle
            first idle
            accept StopCommand
            then shuttingDown;

        transition commanded_shutdown_from_power
            first producingPower
            accept StopCommand
            then shuttingDown;

        transition shutdown_complete
            first shuttingDown
            accept EngineStatus
            then stopped;

        transition overspeed_fault
            first producingPower
            accept OverspeedDetected
            then faulted;

        transition general_fault
            first starting
            accept FaultDetected
            then faulted;

        transition fault_reset
            first faulted
            accept StopCommand
            then stopped;
    }

    part def AirFilter {
        port airIn : AirInPort;
        port airOut : AirOutPort;

        attribute pressureDrop : PressureValue {
            :>> value = 2.5;
            :>> unit = EngineeringUnit::kPa;
        }
    }

    part def ThrottleBody {
        port airIn : AirInPort;
        port airOut : AirOutPort;
        port commandIn : CommandInPort;

        attribute throttlePlateAngle : AngleValue {
            :>> value = 0.0;
            :>> unit = EngineeringUnit::deg;
        }
        attribute boreDiameter : LengthValue {
            :>> value = 70.0;
            :>> unit = EngineeringUnit::mm;
        }
    }

    part def FuelMeteringUnit {
        port fuelIn : FuelInPort;
        port airIn : AirInPort;
        port mixtureOut : MixtureOutPort;
        port commandIn : CommandInPort;

        attribute maximumFuelFlow : FuelFlowValue {
            :>> value = 115.0;
            :>> unit = EngineeringUnit::L_per_h;
        }

        perform action metering : MeterFuelAndAir;
    }

    part def IgnitionSystem {
        port commandIn : CommandInPort;
        port sparkOut : SparkOutPort;

        attribute coilVoltage : VoltageValue {
            :>> value = 12.0;
            :>> unit = EngineeringUnit::V;
        }
        attribute maximumSparkAdvance : AngleValue {
            :>> value = 32.0;
            :>> unit = EngineeringUnit::deg;
        }
    }

    part def StarterMotor {
        port commandIn : CommandInPort;
        port torqueOut : TorqueOutPort;

        attribute supplyVoltage : VoltageValue {
            :>> value = 12.0;
            :>> unit = EngineeringUnit::V;
        }
        attribute crankingCurrent : CurrentValue {
            :>> value = 180.0;
            :>> unit = EngineeringUnit::A;
        }
        attribute crankingSpeed : SpeedValue {
            :>> value = 280.0;
            :>> unit = EngineeringUnit::rpm;
        }
    }

    part def TrochoidHousing {
        port mixtureIn : MixtureInPort;
        port sparkIn : SparkInPort;
        port coolantIn : CoolantInPort;
        port coolantOut : CoolantOutPort;
        port oilIn : OilInPort;
        port combustionGasOut : CombustionGasOutPort;
        port torqueOut : TorqueOutPort;

        attribute chamberDisplacement : VolumeValue {
            :>> value = 654.0;
            :>> unit = EngineeringUnit::cm3;
        }
        attribute compressionRatio : RatioValue {
            :>> value = 9.4;
            :>> unit = EngineeringUnit::one;
        }
        attribute rotorCount : Integer = 2;
        attribute nominalRotorEccentricity : LengthValue {
            :>> value = 15.0;
            :>> unit = EngineeringUnit::mm;
        }

        perform action compression : CompressMixtureInRotorChamber;
        perform action combustionExpansion : IgniteAndExpandCombustion;
    }

    part def EccentricShaft {
        port torqueIn : TorqueInPort;
        port starterTorqueIn : TorqueInPort;
        port shaftPowerOut : ShaftPowerOutPort;

        attribute maximumContinuousSpeed : SpeedValue {
            :>> value = 8000.0;
            :>> unit = EngineeringUnit::rpm;
        }
        attribute ratedOutputTorque : TorqueValue {
            :>> value = 220.0;
            :>> unit = EngineeringUnit::N_m;
        }
    }

    part def CoolingCircuit {
        port hotCoolantIn : CoolantInPort;
        port cooledCoolantOut : CoolantOutPort;

        attribute regulatedTemperature : TemperatureValue {
            :>> value = 90.0;
            :>> unit = EngineeringUnit::degC;
        }
        attribute pressureCapSetting : PressureValue {
            :>> value = 125.0;
            :>> unit = EngineeringUnit::kPa;
        }
    }

    part def LubricationCircuit {
        port oilOut : OilOutPort;
        port oilReturn : OilInPort;

        attribute regulatedOilPressure : PressureValue {
            :>> value = 420.0;
            :>> unit = EngineeringUnit::kPa;
        }
        attribute meteredOilInjectionEnabled : Boolean = true;
    }

    part def ExhaustManifold {
        port combustionGasIn : CombustionGasInPort;
        port exhaustOut : ExhaustOutPort;

        attribute backPressureAtRatedPower : PressureValue {
            :>> value = 18.0;
            :>> unit = EngineeringUnit::kPa;
        }

        perform action exhausting : ExhaustCombustionProducts;
    }

    part def EngineController {
        port commandIn : CommandInPort;
        port statusIn : StatusInPort;
        port statusOut : StatusOutPort;
        port throttleCommandOut : CommandOutPort;
        port fuelCommandOut : CommandOutPort;
        port ignitionCommandOut : CommandOutPort;
        port starterCommandOut : CommandOutPort;

        attribute idleSpeedCommand : SpeedValue {
            :>> value = 900.0;
            :>> unit = EngineeringUnit::rpm;
        }
        attribute maximumSpeedLimit : SpeedValue {
            :>> value = 8200.0;
            :>> unit = EngineeringUnit::rpm;
        }
    }

    part def RotaryEngineSystem {
        port fuelIn : FuelInPort;
        port airIn : AirInPort;
        port exhaustOut : ExhaustOutPort;
        port outputShaft : ShaftPowerOutPort;
        port commandIn : CommandInPort;
        port statusOut : StatusOutPort;

        attribute primaryFunctionDescription : String =
            "Convert chemical energy in a metered gasoline-air mixture into controlled rotary mechanical power at the eccentric shaft while discharging exhaust gas and managing cooling, lubrication, ignition, and control.";

        attribute ratedMaximumPower : PowerValue {
            :>> value = 170.0;
            :>> unit = EngineeringUnit::kW;
        }
        attribute ratedSpeed : SpeedValue {
            :>> value = 6500.0;
            :>> unit = EngineeringUnit::rpm;
        }
        attribute peakTorque : TorqueValue {
            :>> value = 220.0;
            :>> unit = EngineeringUnit::N_m;
        }
        attribute brakeSpecificFuelConsumption : SpecificFuelConsumptionValue {
            :>> value = 285.0;
            :>> unit = EngineeringUnit::g_per_kWh;
        }
        attribute outputPowerAvailable : Boolean = true;

        part airFilter : AirFilter;
        part throttleBody : ThrottleBody;
        part fuelMeteringUnit : FuelMeteringUnit;
        part ignitionSystem : IgnitionSystem;
        part starterMotor : StarterMotor;
        part rotorHousing : TrochoidHousing;
        part eccentricShaft : EccentricShaft;
        part coolingCircuit : CoolingCircuit;
        part lubricationCircuit : LubricationCircuit;
        part exhaustManifold : ExhaustManifold;
        part controller : EngineController;

        connect airIn to airFilter.airIn;
        connect airFilter.airOut to throttleBody.airIn;
        connect throttleBody.airOut to fuelMeteringUnit.airIn;
        connect fuelIn to fuelMeteringUnit.fuelIn;
        connect fuelMeteringUnit.mixtureOut to rotorHousing.mixtureIn;
        connect ignitionSystem.sparkOut to rotorHousing.sparkIn;
        connect rotorHousing.torqueOut to eccentricShaft.torqueIn;
        connect starterMotor.torqueOut to eccentricShaft.starterTorqueIn;
        connect eccentricShaft.shaftPowerOut to outputShaft;
        connect rotorHousing.combustionGasOut to exhaustManifold.combustionGasIn;
        connect exhaustManifold.exhaustOut to exhaustOut;
        connect coolingCircuit.cooledCoolantOut to rotorHousing.coolantIn;
        connect rotorHousing.coolantOut to coolingCircuit.hotCoolantIn;
        connect lubricationCircuit.oilOut to rotorHousing.oilIn;
        connect commandIn to controller.commandIn;
        connect controller.throttleCommandOut to throttleBody.commandIn;
        connect controller.fuelCommandOut to fuelMeteringUnit.commandIn;
        connect controller.ignitionCommandOut to ignitionSystem.commandIn;
        connect controller.starterCommandOut to starterMotor.commandIn;
        connect controller.statusOut to statusOut;

        perform action primaryFunction : ConvertFuelAndAirToRotaryOutput;
        exhibit state lifecycle : RotaryEngineLifecycle;
    }

    requirement def PrimaryFunctionRequirement {
        subject engine : RotaryEngineSystem;

        attribute requiredFunction : String =
            "The rotary engine system shall provide a high-level function of converting supplied gasoline and intake air into regulated rotary shaft power.";

        require constraint primaryFunctionPresent {
            engine.outputPowerAvailable == true
        }

        require constraint minimumRatedPower {
            engine.ratedMaximumPower.value >= 150.0
        }

        require constraint minimumRatedSpeed {
            engine.ratedSpeed.value >= 6000.0
        }
    }

    requirement def CoolingAndLubricationRequirement {
        subject engine : RotaryEngineSystem;

        require constraint controlledCoolantTemperature {
            engine.coolingCircuit.regulatedTemperature.value <= 105.0
        }

        require constraint controlledOilPressure {
            engine.lubricationCircuit.regulatedOilPressure.value >= 300.0
        }
    }

    requirement def OverspeedProtectionRequirement {
        subject engine : RotaryEngineSystem;

        require constraint speedLimitBelowMechanicalMaximum {
            engine.controller.maximumSpeedLimit.value <= engine.eccentricShaft.maximumContinuousSpeed.value + 300.0
        }
    }

    part rotaryEngine : RotaryEngineSystem;

    requirement primaryFunctionRequirement : PrimaryFunctionRequirement {
        subject engine = rotaryEngine;
    }

    requirement coolingAndLubricationRequirement : CoolingAndLubricationRequirement {
        subject engine = rotaryEngine;
    }

    requirement overspeedProtectionRequirement : OverspeedProtectionRequirement {
        subject engine = rotaryEngine;
    }

    satisfy primaryFunctionRequirement by rotaryEngine;
    satisfy coolingAndLubricationRequirement by rotaryEngine;
    satisfy overspeedProtectionRequirement by rotaryEngine;
}
