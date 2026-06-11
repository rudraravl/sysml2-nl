package JetAeratorSystemModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def FlowRate {
        :> scalarValues::Real;
        unit = "m^3/s";
    }

    attribute def Pressure {
        :> scalarValues::Real;
        unit = "Pa";
    }

    attribute def Power {
        :> scalarValues::Real;
        unit = "W";
    }

    attribute def RotationalSpeed {
        :> scalarValues::Real;
        unit = "rpm";
    }

    attribute def DissolvedOxygenConcentration {
        :> scalarValues::Real;
        unit = "mg/L";
    }

    attribute def OxygenTransferRate {
        :> scalarValues::Real;
        unit = "kgO2/h";
    }

    attribute def Temperature {
        :> scalarValues::Real;
        unit = "degC";
    }

    attribute def Length {
        :> scalarValues::Real;
        unit = "m";
    }

    attribute def Efficiency {
        :> scalarValues::Real;
        unit = "percent";
    }

    item def Wastewater {
        attribute temperature : Temperature;
        attribute dissolvedOxygen : DissolvedOxygenConcentration;
        attribute suspendedSolidsConcentration : scalarValues::Real;
    }

    item def Air {
        attribute oxygenFraction : scalarValues::Real = 0.209;
        attribute pressure : Pressure;
        attribute temperature : Temperature;
    }

    item def AirWaterMixture {
        attribute mixtureFlowRate : FlowRate;
        attribute entrainedAirFlowRate : FlowRate;
        attribute oxygenContent : scalarValues::Real;
    }

    port def LiquidInletPort {
        in item influent : Wastewater;
    }

    port def LiquidOutletPort {
        out item effluent : Wastewater;
    }

    port def AirInletPort {
        in item intakeAir : Air;
    }

    port def MixturePort {
        out item dischargeMixture : AirWaterMixture;
    }

    port def ElectricalPowerPort {
        in attribute voltage : scalarValues::Real;
        in attribute current : scalarValues::Real;
        in attribute suppliedPower : Power;
    }

    port def ControlPort {
        in attribute startCommand : Boolean;
        in attribute stopCommand : Boolean;
        in attribute speedSetpoint : RotationalSpeed;
        out attribute runningStatus : Boolean;
        out attribute faultStatus : Boolean;
    }

    part def ElectricMotor {
        port powerPort : ElectricalPowerPort;
        port controlPort : ControlPort;

        attribute ratedPower : Power = 15000;
        attribute ratedSpeed : RotationalSpeed = 1750;
        attribute actualSpeed : RotationalSpeed;
        attribute motorEfficiency : Efficiency = 91.0;
        attribute windingTemperature : Temperature;

        state def MotorOperatingState {
            state off;
            state starting;
            state running;
            state faulted;

            transition off_to_starting
                first off
                then starting
                if controlPort.startCommand;

            transition starting_to_running
                first starting
                then running
                if actualSpeed >= 0.95 * ratedSpeed;

            transition running_to_off
                first running
                then off
                if controlPort.stopCommand;

            transition any_to_faulted
                first running
                then faulted
                if windingTemperature > 120;

            transition faulted_to_off
                first faulted
                then off
                if controlPort.stopCommand;
        }

        perform action regulateSpeed {
            in attribute targetSpeed : RotationalSpeed;
            out attribute commandedTorque : scalarValues::Real;
        }
    }

    part def PumpImpeller {
        port liquidInlet : LiquidInletPort;
        port liquidOutlet : LiquidOutletPort;

        attribute diameter : Length = 0.32;
        attribute rotationalSpeed : RotationalSpeed;
        attribute liquidFlowRate : FlowRate;
        attribute developedPressure : Pressure;
        attribute hydraulicEfficiency : Efficiency = 76.0;

        perform action accelerateWastewater {
            in item inletWater : Wastewater;
            out item pressurizedWater : Wastewater;
            out attribute generatedFlow : FlowRate;
        }
    }

    part def JetNozzle {
        port liquidInlet : LiquidInletPort;
        port mixtureOutlet : MixturePort;

        attribute throatDiameter : Length = 0.075;
        attribute dischargeVelocity : scalarValues::Real;
        attribute nozzlePressureDrop : Pressure;

        perform action formHighVelocityJet {
            in item pressurizedWater : Wastewater;
            out item liquidJet : Wastewater;
        }
    }

    part def VenturiAirInjector {
        port airInlet : AirInletPort;
        port liquidInlet : LiquidInletPort;
        port mixtureOutlet : MixturePort;

        attribute suctionPressure : Pressure;
        attribute entrainedAirFlowRate : FlowRate;
        attribute airToWaterRatio : scalarValues::Real = 0.18;

        perform action entrainAtmosphericAir {
            in item motiveWater : Wastewater;
            in item ambientAir : Air;
            out item aeratedMixture : AirWaterMixture;
        }
    }

    part def DiffuserOutlet {
        port mixtureInlet : MixturePort;
        port liquidOutlet : LiquidOutletPort;

        attribute bubbleMeanDiameter : Length = 0.003;
        attribute oxygenTransferEfficiency : Efficiency = 24.0;
        attribute dischargeDepth : Length = 2.5;

        perform action disperseBubbles {
            in item aeratedMixture : AirWaterMixture;
            out item oxygenatedWastewater : Wastewater;
            out attribute oxygenTransferRate : OxygenTransferRate;
        }
    }

    part def DissolvedOxygenSensor {
        port measuredLiquid : LiquidInletPort;

        attribute measuredDO : DissolvedOxygenConcentration;
        attribute measurementRangeMinimum : DissolvedOxygenConcentration = 0.0;
        attribute measurementRangeMaximum : DissolvedOxygenConcentration = 20.0;
        attribute responseTime : scalarValues::Real = 30.0;
    }

    part def Controller {
        port controlOutput : ControlPort;

        attribute dissolvedOxygenSetpoint : DissolvedOxygenConcentration = 2.0;
        attribute minimumMotorSpeed : RotationalSpeed = 900;
        attribute maximumMotorSpeed : RotationalSpeed = 1750;
        attribute commandedSpeed : RotationalSpeed;
        attribute alarmActive : Boolean;

        perform action computeAerationDemand {
            in attribute measuredDO : DissolvedOxygenConcentration;
            in attribute targetDO : DissolvedOxygenConcentration;
            out attribute speedDemand : RotationalSpeed;
        }

        state def ControlState {
            state idle;
            state automaticAeration;
            state shutdown;
            state alarm;

            transition idle_to_automatic
                first idle
                then automaticAeration
                if controlOutput.startCommand;

            transition automatic_to_shutdown
                first automaticAeration
                then shutdown
                if controlOutput.stopCommand;

            transition automatic_to_alarm
                first automaticAeration
                then alarm
                if alarmActive;

            transition alarm_to_idle
                first alarm
                then idle
                if controlOutput.stopCommand;
        }
    }

    part def JetAerator {
        port wastewaterInlet : LiquidInletPort;
        port wastewaterOutlet : LiquidOutletPort;
        port atmosphericAirInlet : AirInletPort;
        port electricalSupply : ElectricalPowerPort;
        port supervisoryControl : ControlPort;

        part motor : ElectricMotor;
        part impeller : PumpImpeller;
        part nozzle : JetNozzle;
        part airInjector : VenturiAirInjector;
        part diffuser : DiffuserOutlet;
        part doSensor : DissolvedOxygenSensor;
        part controller : Controller;

        attribute ratedLiquidFlowRate : FlowRate = 0.085;
        attribute ratedAirFlowRate : FlowRate = 0.015;
        attribute ratedOxygenTransferRate : OxygenTransferRate = 8.5;
        attribute minimumOperatingDepth : Length = 1.2;
        attribute maximumOperatingDepth : Length = 6.0;
        attribute systemPowerDemand : Power;
        attribute outletDissolvedOxygen : DissolvedOxygenConcentration;

        connect electricalSupply to motor.powerPort;
        connect supervisoryControl to controller.controlOutput;
        connect controller.controlOutput to motor.controlPort;
        connect wastewaterInlet to impeller.liquidInlet;
        connect impeller.liquidOutlet to nozzle.liquidInlet;
        connect nozzle.mixtureOutlet to airInjector.liquidInlet;
        connect atmosphericAirInlet to airInjector.airInlet;
        connect airInjector.mixtureOutlet to diffuser.mixtureInlet;
        connect diffuser.liquidOutlet to wastewaterOutlet;
        connect wastewaterOutlet to doSensor.measuredLiquid;

        perform action aerateWastewater {
            in item incomingWastewater : Wastewater;
            in item ambientAir : Air;
            in attribute electricalPower : Power;
            out item treatedWastewater : Wastewater;
            out attribute transferredOxygen : OxygenTransferRate;

            first motor.regulateSpeed(
                targetSpeed = controller.commandedSpeed,
                commandedTorque = ?
            );

            then impeller.accelerateWastewater(
                inletWater = incomingWastewater,
                pressurizedWater = ?,
                generatedFlow = ratedLiquidFlowRate
            );

            then airInjector.entrainAtmosphericAir(
                motiveWater = ?,
                ambientAir = ambientAir,
                aeratedMixture = ?
            );

            then diffuser.disperseBubbles(
                aeratedMixture = ?,
                oxygenatedWastewater = treatedWastewater,
                oxygenTransferRate = transferredOxygen
            );
        }

        state def JetAeratorLifecycle {
            state stopped;
            state priming;
            state aerating;
            state lowOxygenBoost;
            state standby;
            state fault;

            transition stopped_to_priming
                first stopped
                then priming
                if supervisoryControl.startCommand;

            transition priming_to_aerating
                first priming
                then aerating
                if impeller.liquidFlowRate > 0.75 * ratedLiquidFlowRate;

            transition aerating_to_boost
                first aerating
                then lowOxygenBoost
                if doSensor.measuredDO < 1.5;

            transition boost_to_aerating
                first lowOxygenBoost
                then aerating
                if doSensor.measuredDO >= controller.dissolvedOxygenSetpoint;

            transition aerating_to_standby
                first aerating
                then standby
                if doSensor.measuredDO > 3.0;

            transition standby_to_aerating
                first standby
                then aerating
                if doSensor.measuredDO < controller.dissolvedOxygenSetpoint;

            transition operating_to_stopped
                first aerating
                then stopped
                if supervisoryControl.stopCommand;

            transition aerating_to_fault
                first aerating
                then fault
                if motor.controlPort.faultStatus;

            transition fault_to_stopped
                first fault
                then stopped
                if supervisoryControl.stopCommand;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc
        /* The jet aerator shall transfer oxygen from atmospheric air into wastewater by using a motor-driven liquid jet to create suction, entrain air through a venturi injector, shear the air into fine bubbles, and disperse the resulting air-water mixture into the basin. */
    }

    requirement def OxygenTransferRequirement {
        attribute minimumOxygenTransferRate : OxygenTransferRate = 8.0;
        subject aerator : JetAerator;

        require constraint {
            aerator.ratedOxygenTransferRate >= minimumOxygenTransferRate
        }
    }

    requirement def DissolvedOxygenControlRequirement {
        attribute targetDissolvedOxygen : DissolvedOxygenConcentration = 2.0;
        attribute tolerance : DissolvedOxygenConcentration = 0.3;
        subject aerator : JetAerator;

        require constraint {
            aerator.outletDissolvedOxygen >= targetDissolvedOxygen - tolerance
        }
    }

    requirement def AirEntrainmentRequirement {
        attribute minimumAirFlowRate : FlowRate = 0.012;
        subject aerator : JetAerator;

        require constraint {
            aerator.ratedAirFlowRate >= minimumAirFlowRate
        }
    }

    requirement def OperatingDepthRequirement {
        attribute requiredMinimumDepth : Length = 1.2;
        attribute requiredMaximumDepth : Length = 6.0;
        subject aerator : JetAerator;

        require constraint {
            aerator.minimumOperatingDepth <= requiredMinimumDepth and
            aerator.maximumOperatingDepth >= requiredMaximumDepth
        }
    }

    requirement def EnergyEfficiencyRequirement {
        attribute maximumSpecificPower : scalarValues::Real = 2.2;
        subject aerator : JetAerator;

        require constraint {
            aerator.systemPowerDemand / aerator.ratedOxygenTransferRate <= maximumSpecificPower
        }
    }

    part jetAeratorSystem : JetAerator {
        attribute ratedLiquidFlowRate = 0.085;
        attribute ratedAirFlowRate = 0.015;
        attribute ratedOxygenTransferRate = 8.5;
        attribute systemPowerDemand = 15000;
        attribute outletDissolvedOxygen = 2.4;
    }

    satisfy PrimaryFunctionRequirement by jetAeratorSystem;
    satisfy OxygenTransferRequirement by jetAeratorSystem;
    satisfy DissolvedOxygenControlRequirement by jetAeratorSystem;
    satisfy AirEntrainmentRequirement by jetAeratorSystem;
    satisfy OperatingDepthRequirement by jetAeratorSystem;
    satisfy EnergyEfficiencyRequirement by jetAeratorSystem;
}