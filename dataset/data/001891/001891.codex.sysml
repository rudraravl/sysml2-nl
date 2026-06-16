package WaterTurbineSystemModel {

    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def Pressure {
        :> ISQ::pressure;
        unit = SI::pascal;
    }

    attribute def FlowRate {
        :> ISQ::volumeFlowRate;
        unit = SI::cubicMetrePerSecond;
    }

    attribute def RotationalSpeed {
        :> ISQ::angularVelocity;
        unit = SI::radianPerSecond;
    }

    attribute def Torque {
        :> ISQ::torque;
        unit = SI::newtonMetre;
    }

    attribute def Power {
        :> ISQ::power;
        unit = SI::watt;
    }

    attribute def Efficiency {
        :> ScalarValues::Real;
    }

    attribute def Temperature {
        :> ISQ::thermodynamicTemperature;
        unit = SI::kelvin;
    }

    item def Water {
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
        attribute temperature : Temperature;
        attribute sedimentFraction : Real;
    }

    item def MechanicalRotation {
        attribute speed : RotationalSpeed;
        attribute torque : Torque;
        attribute shaftPower : Power;
    }

    item def ElectricalPower {
        attribute voltage : ISQ::electricPotential;
        attribute current : ISQ::electricCurrent;
        attribute frequency : ISQ::frequency;
        attribute realPower : Power;
    }

    item def ControlSignal {
        attribute commandValue : Real;
        attribute valid : Boolean;
    }

    item def SensorReading {
        attribute measuredValue : Real;
        attribute healthy : Boolean;
    }

    port def WaterInletPort {
        in item incomingWater : Water;
    }

    port def WaterOutletPort {
        out item dischargedWater : Water;
    }

    port def ShaftPort {
        out item rotation : MechanicalRotation;
    }

    port def ElectricalPort {
        out item generatedPower : ElectricalPower;
    }

    port def ControlInputPort {
        in item control : ControlSignal;
    }

    port def SensorOutputPort {
        out item reading : SensorReading;
    }

    part def Intake {
        port source : WaterInletPort;
        port penstockOutlet : WaterOutletPort;

        attribute inletPressure : Pressure;
        attribute outletPressure : Pressure;
        attribute flowCapacity : FlowRate = 42.0 [SI::cubicMetrePerSecond];
        attribute trashRackClearance : Real = 0.92;
    }

    part def GuideVaneAssembly {
        port waterIn : WaterInletPort;
        port waterOut : WaterOutletPort;
        port vaneCommand : ControlInputPort;
        port positionFeedback : SensorOutputPort;

        attribute openingFraction : Real;
        attribute minimumOpening : Real = 0.05;
        attribute maximumOpening : Real = 1.00;
        attribute actuationTime : ISQ::time = 8.0 [SI::second];
    }

    part def Runner {
        port waterIn : WaterInletPort;
        port waterOut : WaterOutletPort;
        port shaftOut : ShaftPort;

        attribute bladeCount : Integer = 18;
        attribute designHead : ISQ::length = 85.0 [SI::metre];
        attribute designFlow : FlowRate = 36.0 [SI::cubicMetrePerSecond];
        attribute nominalSpeed : RotationalSpeed = 31.4 [SI::radianPerSecond];
        attribute hydraulicEfficiency : Efficiency = 0.93;
        attribute producedTorque : Torque;
    }

    part def DraftTube {
        port waterIn : WaterInletPort;
        port tailraceOut : WaterOutletPort;

        attribute pressureRecoveryEfficiency : Efficiency = 0.82;
        attribute cavitationMargin : Pressure;
    }

    part def ShaftTrain {
        port runnerInput : ShaftPort;
        port generatorOutput : ShaftPort;

        attribute torsionalStiffness : Real;
        attribute bearingTemperature : Temperature;
        attribute vibrationAmplitude : ISQ::length;
        attribute mechanicalEfficiency : Efficiency = 0.985;
    }

    part def Generator {
        port shaftInput : ShaftPort;
        port electricalOut : ElectricalPort;
        port excitationCommand : ControlInputPort;
        port powerFeedback : SensorOutputPort;

        attribute ratedPower : Power = 25000000.0 [SI::watt];
        attribute ratedVoltage : ISQ::electricPotential = 13800.0 [SI::volt];
        attribute ratedFrequency : ISQ::frequency = 60.0 [SI::hertz];
        attribute generatorEfficiency : Efficiency = 0.975;
    }

    part def CoolingAndLubricationSystem {
        port startCommand : ControlInputPort;
        port healthFeedback : SensorOutputPort;

        attribute oilPressure : Pressure;
        attribute oilTemperature : Temperature;
        attribute coolantFlow : FlowRate;
        attribute available : Boolean;
    }

    part def GovernorController {
        port speedFeedback : SensorOutputPort;
        port powerFeedback : SensorOutputPort;
        port vaneOutput : ControlInputPort;
        port excitationOutput : ControlInputPort;

        attribute targetPower : Power;
        attribute targetSpeed : RotationalSpeed;
        attribute droopSetting : Real = 0.04;
        attribute controlMode : String;
    }

    part def ProtectionSystem {
        port speedInput : SensorOutputPort;
        port vibrationInput : SensorOutputPort;
        port temperatureInput : SensorOutputPort;
        port tripOutput : ControlInputPort;

        attribute overspeedLimit : RotationalSpeed = 39.3 [SI::radianPerSecond];
        attribute maximumBearingTemperature : Temperature = 358.15 [SI::kelvin];
        attribute maximumVibration : ISQ::length = 0.00025 [SI::metre];
        attribute tripActive : Boolean;
    }

    action def ConvertHydraulicEnergyToMechanicalRotation {
        in item inletWater : Water;
        out item outletWater : Water;
        out item shaftRotation : MechanicalRotation;

        attribute netHead : ISQ::length;
        attribute flow : FlowRate;
        attribute efficiency : Efficiency;

        objective {
            shaftRotation.shaftPower == efficiency * inletWater.flowRate * inletWater.pressure;
        }
    }

    action def RegulateWaterFlow {
        in item powerDemand : ElectricalPower;
        in item measuredSpeed : SensorReading;
        out item vaneCommand : ControlSignal;

        attribute speedError : Real;
        attribute powerError : Real;
    }

    action def GenerateElectricity {
        in item shaftRotation : MechanicalRotation;
        out item electricPower : ElectricalPower;

        attribute conversionEfficiency : Efficiency;

        objective {
            electricPower.realPower == shaftRotation.shaftPower * conversionEfficiency;
        }
    }

    action def EmergencyShutdown {
        out item closeVanes : ControlSignal;
        out item removeExcitation : ControlSignal;

        attribute shutdownTime : ISQ::time = 6.0 [SI::second];
    }

    state def TurbineOperationalState {
        state Off;
        state Starting;
        state Synchronizing;
        state Generating;
        state LoadFollowing;
        state ShuttingDown;
        state Tripped;

        transition first Off;

        transition Off_to_Starting
            first Off
            then Starting
            accept ControlSignal
            if control.commandValue > 0.5 and control.valid;

        transition Starting_to_Synchronizing
            first Starting
            then Synchronizing
            if true;

        transition Synchronizing_to_Generating
            first Synchronizing
            then Generating
            if true;

        transition Generating_to_LoadFollowing
            first Generating
            then LoadFollowing
            if true;

        transition LoadFollowing_to_ShuttingDown
            first LoadFollowing
            then ShuttingDown
            accept ControlSignal
            if control.commandValue < 0.1 and control.valid;

        transition Any_to_Tripped
            first Generating
            then Tripped
            if true;

        transition ShuttingDown_to_Off
            first ShuttingDown
            then Off
            if true;
    }

    part def WaterTurbinePowerUnit {
        doc /* Primary function: convert controlled hydraulic energy from flowing water into regulated mechanical shaft rotation and then electrical power while safely discharging water downstream. */

        port upstreamWater : WaterInletPort;
        port downstreamWater : WaterOutletPort;
        port gridPower : ElectricalPort;
        port operatorCommand : ControlInputPort;

        part intake : Intake;
        part guideVanes : GuideVaneAssembly;
        part runner : Runner;
        part draftTube : DraftTube;
        part shaftTrain : ShaftTrain;
        part generator : Generator;
        part coolingLubrication : CoolingAndLubricationSystem;
        part governor : GovernorController;
        part protection : ProtectionSystem;

        attribute ratedHydraulicHead : ISQ::length = 85.0 [SI::metre];
        attribute ratedFlow : FlowRate = 36.0 [SI::cubicMetrePerSecond];
        attribute ratedMechanicalPower : Power = 25500000.0 [SI::watt];
        attribute ratedElectricalPower : Power = 25000000.0 [SI::watt];
        attribute overallEfficiency : Efficiency = 0.91;
        attribute minimumOperatingFlow : FlowRate = 7.5 [SI::cubicMetrePerSecond];
        attribute maximumOperatingFlow : FlowRate = 42.0 [SI::cubicMetrePerSecond];

        connect upstreamWater to intake.source;
        connect intake.penstockOutlet to guideVanes.waterIn;
        connect guideVanes.waterOut to runner.waterIn;
        connect runner.waterOut to draftTube.waterIn;
        connect draftTube.tailraceOut to downstreamWater;

        connect runner.shaftOut to shaftTrain.runnerInput;
        connect shaftTrain.generatorOutput to generator.shaftInput;
        connect generator.electricalOut to gridPower;

        connect operatorCommand to coolingLubrication.startCommand;
        connect governor.vaneOutput to guideVanes.vaneCommand;
        connect governor.excitationOutput to generator.excitationCommand;
        connect generator.powerFeedback to governor.powerFeedback;
        connect guideVanes.positionFeedback to governor.speedFeedback;

        connect guideVanes.positionFeedback to protection.speedInput;
        connect coolingLubrication.healthFeedback to protection.temperatureInput;
        connect protection.tripOutput to guideVanes.vaneCommand;

        perform action convert : ConvertHydraulicEnergyToMechanicalRotation {
            in inletWater = guideVanes.waterOut.incomingWater;
            out outletWater = runner.waterOut.dischargedWater;
            out shaftRotation = runner.shaftOut.rotation;
        }

        perform action regulate : RegulateWaterFlow {
            out vaneCommand = governor.vaneOutput.control;
        }

        perform action generate : GenerateElectricity {
            in shaftRotation = shaftTrain.generatorOutput.rotation;
            out electricPower = generator.electricalOut.generatedPower;
        }

        perform action trip : EmergencyShutdown {
            out closeVanes = protection.tripOutput.control;
            out removeExcitation = governor.excitationOutput.control;
        }

        exhibit state operationalState : TurbineOperationalState;
    }

    requirement def HydraulicEnergyConversionRequirement {
        doc /* The turbine shall convert hydraulic energy from incoming water into mechanical shaft power for electricity generation. */

        subject turbine : WaterTurbinePowerUnit;

        require constraint {
            turbine.overallEfficiency >= 0.88
        }
    }

    requirement def RatedPowerRequirement {
        doc /* The turbine power unit shall deliver at least 25 MW of electrical power at rated head and rated flow. */

        subject turbine : WaterTurbinePowerUnit;

        require constraint {
            turbine.ratedElectricalPower >= 25000000.0 [SI::watt]
        }
    }

    requirement def FlowControlRequirement {
        doc /* The guide vane system shall regulate water flow across the runner to match power demand while remaining within allowable flow limits. */

        subject turbine : WaterTurbinePowerUnit;

        require constraint {
            turbine.minimumOperatingFlow <= turbine.ratedFlow and turbine.ratedFlow <= turbine.maximumOperatingFlow
        }
    }

    requirement def SafeShutdownRequirement {
        doc /* The protection system shall command shutdown when overspeed, excessive vibration, or excessive bearing temperature is detected. */

        subject turbine : WaterTurbinePowerUnit;

        require constraint {
            turbine.protection.tripActive implies turbine.guideVanes.openingFraction <= turbine.guideVanes.minimumOpening
        }
    }

    requirement def CavitationProtectionRequirement {
        doc /* The draft tube and runner shall maintain sufficient pressure margin to reduce cavitation during normal generation. */

        subject turbine : WaterTurbinePowerUnit;

        require constraint {
            turbine.draftTube.pressureRecoveryEfficiency >= 0.75
        }
    }

    requirement def GridInterfaceRequirement {
        doc /* The generator shall provide electrical output compatible with a 13.8 kV, 60 Hz grid connection. */

        subject turbine : WaterTurbinePowerUnit;

        require constraint {
            turbine.generator.ratedVoltage == 13800.0 [SI::volt] and
            turbine.generator.ratedFrequency == 60.0 [SI::hertz]
        }
    }

    satisfy HydraulicEnergyConversionRequirement by WaterTurbinePowerUnit;
    satisfy RatedPowerRequirement by WaterTurbinePowerUnit;
    satisfy FlowControlRequirement by WaterTurbinePowerUnit;
    satisfy SafeShutdownRequirement by WaterTurbinePowerUnit;
    satisfy CavitationProtectionRequirement by WaterTurbinePowerUnit;
    satisfy GridInterfaceRequirement by WaterTurbinePowerUnit;

    part waterTurbinePlant : WaterTurbinePowerUnit;

}