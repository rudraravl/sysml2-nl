package SteamTurbineSystemModel {

    import ScalarValues::*;
    import ISQ::*;

    attribute def Pressure :> ScalarValues::Real {
        unit = "MPa";
    }

    attribute def Temperature :> ScalarValues::Real {
        unit = "degC";
    }

    attribute def MassFlowRate :> ScalarValues::Real {
        unit = "kg/s";
    }

    attribute def Power :> ScalarValues::Real {
        unit = "MW";
    }

    attribute def RotationalSpeed :> ScalarValues::Real {
        unit = "rpm";
    }

    attribute def Efficiency :> ScalarValues::Real {
        unit = "1";
    }

    attribute def Torque :> ScalarValues::Real {
        unit = "kN*m";
    }

    attribute def VibrationLevel :> ScalarValues::Real {
        unit = "mm/s";
    }

    attribute def ValvePosition :> ScalarValues::Real {
        unit = "%";
    }

    item def Steam {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute massFlow : MassFlowRate;
        attribute specificEnthalpy : ScalarValues::Real {
            unit = "kJ/kg";
        }
        attribute drynessFraction : Efficiency;
    }

    item def ExhaustSteam :> Steam {
        attribute condenserBackPressure : Pressure;
    }

    item def ShaftPower {
        attribute generatedPower : Power;
        attribute speed : RotationalSpeed;
        attribute torque : Torque;
    }

    item def ControlSignal {
        attribute demandPower : Power;
        attribute governorValveCommand : ValvePosition;
        attribute tripCommand : ScalarValues::Boolean;
    }

    item def SensorSignal {
        attribute measuredSpeed : RotationalSpeed;
        attribute measuredPower : Power;
        attribute measuredVibration : VibrationLevel;
        attribute measuredInletPressure : Pressure;
        attribute measuredExhaustPressure : Pressure;
    }

    port def SteamInletPort {
        in item steamIn : Steam;
    }

    port def SteamOutletPort {
        out item steamOut : ExhaustSteam;
    }

    port def ShaftPort {
        out item mechanicalPower : ShaftPower;
    }

    port def ControlPort {
        in item command : ControlSignal;
        out item feedback : SensorSignal;
    }

    part def SteamTurbineSystem {
        attribute ratedPower : Power = 500.0;
        attribute ratedSpeed : RotationalSpeed = 3600.0;
        attribute ratedInletPressure : Pressure = 16.5;
        attribute ratedInletTemperature : Temperature = 540.0;
        attribute minimumExhaustPressure : Pressure = 0.008;
        attribute designEfficiency : Efficiency = 0.88;

        port steamSupply : SteamInletPort;
        port exhaustDischarge : SteamOutletPort;
        port shaftOutput : ShaftPort;
        port controlInterface : ControlPort;

        part steamAdmissionSystem : SteamAdmissionSystem;
        part turbineCasing : TurbineCasing;
        part rotorAssembly : RotorAssembly;
        part bladePath : BladePath;
        part bearings : BearingSystem;
        part lubricationSystem : LubricationSystem;
        part sealingSystem : SealingSystem;
        part exhaustHood : ExhaustHood;
        part governorControl : GovernorControlSystem;
        part protectionSystem : TurbineProtectionSystem;

        connect steamSupply.steamIn to steamAdmissionSystem.inlet.steamIn;
        connect steamAdmissionSystem.outlet.steamOut to bladePath.inlet.steamIn;
        connect bladePath.exhaust.steamOut to exhaustHood.inlet.steamIn;
        connect exhaustHood.outlet.steamOut to exhaustDischarge.steamOut;

        connect bladePath.rotorPower.mechanicalPower to rotorAssembly.inputPower.mechanicalPower;
        connect rotorAssembly.outputPower.mechanicalPower to shaftOutput.mechanicalPower;

        connect governorControl.valveCommand.command to steamAdmissionSystem.control.command;
        connect protectionSystem.tripOutput.command to steamAdmissionSystem.tripInput.command;
        connect rotorAssembly.sensorOutput.feedback to governorControl.sensorInput.feedback;
        connect bearings.sensorOutput.feedback to protectionSystem.sensorInput.feedback;
        connect steamAdmissionSystem.sensorOutput.feedback to protectionSystem.sensorInput.feedback;

        perform action ConvertSteamEnergyToMechanicalPower {
            in item inletSteam : Steam = steamSupply.steamIn;
            out item exhaustSteam : ExhaustSteam = exhaustDischarge.steamOut;
            out item shaftPower : ShaftPower = shaftOutput.mechanicalPower;

            first start;
            then regulateSteamAdmission;
            then expandSteamThroughBladePath;
            then transferTorqueToRotor;
            then dischargeExhaustSteam;
            then provideMechanicalPower;

            action regulateSteamAdmission {
                in item command : ControlSignal = controlInterface.command;
                out item admittedSteam : Steam;
            }

            action expandSteamThroughBladePath {
                in item admittedSteam : Steam;
                out item expandedSteam : ExhaustSteam;
                out item extractedPower : ShaftPower;
            }

            action transferTorqueToRotor {
                in item extractedPower : ShaftPower;
                out item rotatingPower : ShaftPower;
            }

            action dischargeExhaustSteam {
                in item expandedSteam : ExhaustSteam;
                out item exhaustSteam : ExhaustSteam;
            }

            action provideMechanicalPower {
                in item rotatingPower : ShaftPower;
                out item shaftPower : ShaftPower;
            }
        }

        state def TurbineOperatingState {
            state Off;
            state Startup;
            state Synchronizing;
            state LoadedOperation;
            state ControlledShutdown;
            state EmergencyTrip;
            state Coastdown;

            entry Off;

            transition Off_to_Startup
                first Off
                then Startup
                accept ControlSignal
                if command.tripCommand == false;

            transition Startup_to_Synchronizing
                first Startup
                then Synchronizing
                if rotorAssembly.speed >= 0.95 * ratedSpeed;

            transition Synchronizing_to_LoadedOperation
                first Synchronizing
                then LoadedOperation
                if shaftOutput.mechanicalPower.generatedPower > 0.05 * ratedPower;

            transition LoadedOperation_to_ControlledShutdown
                first LoadedOperation
                then ControlledShutdown
                accept ControlSignal
                if command.demandPower <= 0.0;

            transition ControlledShutdown_to_Coastdown
                first ControlledShutdown
                then Coastdown
                if steamAdmissionSystem.mainStopValve.position == 0.0;

            transition Coastdown_to_Off
                first Coastdown
                then Off
                if rotorAssembly.speed < 50.0;

            transition Any_to_EmergencyTrip
                first Off
                then EmergencyTrip
                accept ControlSignal
                if command.tripCommand == true;

            transition EmergencyTrip_to_Coastdown
                first EmergencyTrip
                then Coastdown
                if steamAdmissionSystem.mainStopValve.position == 0.0;
        }
    }

    part def SteamAdmissionSystem {
        port inlet : SteamInletPort;
        port outlet : SteamOutletPort;
        port control : ControlPort;
        port tripInput : ControlPort;
        port sensorOutput : ControlPort;

        attribute inletPressure : Pressure;
        attribute inletTemperature : Temperature;
        attribute admittedMassFlow : MassFlowRate;

        part mainStopValve : StopValve;
        part governorValve : ControlValve;
        part steamChest : SteamChest;

        connect inlet.steamIn to mainStopValve.inlet.steamIn;
        connect mainStopValve.outlet.steamOut to governorValve.inlet.steamIn;
        connect governorValve.outlet.steamOut to steamChest.inlet.steamIn;
        connect steamChest.outlet.steamOut to outlet.steamOut;

        action regulateAdmission {
            in item command : ControlSignal = control.command;
            out item admittedSteam : Steam = outlet.steamOut;
        }
    }

    part def StopValve {
        port inlet : SteamInletPort;
        port outlet : SteamOutletPort;

        attribute position : ValvePosition = 100.0;
        attribute closingTime : ScalarValues::Real {
            unit = "s";
        } = 0.3;

        action closeOnTrip {
            out attribute position : ValvePosition = 0.0;
        }
    }

    part def ControlValve {
        port inlet : SteamInletPort;
        port outlet : SteamOutletPort;

        attribute position : ValvePosition;
        attribute flowCoefficient : ScalarValues::Real {
            unit = "kg/(s*sqrt(MPa))";
        }

        action modulateFlow {
            in item command : ControlSignal;
            out attribute position : ValvePosition;
        }
    }

    part def SteamChest {
        port inlet : SteamInletPort;
        port outlet : SteamOutletPort;

        attribute chestPressure : Pressure;
        attribute chestTemperature : Temperature;
    }

    part def TurbineCasing {
        attribute designPressure : Pressure = 18.0;
        attribute designTemperature : Temperature = 565.0;
        attribute casingExpansion : ScalarValues::Real {
            unit = "mm";
        }

        part highPressureCasing : PressureCasing;
        part intermediatePressureCasing : PressureCasing;
        part lowPressureCasing : PressureCasing;
    }

    part def PressureCasing {
        attribute allowablePressure : Pressure;
        attribute metalTemperature : Temperature;
        attribute thermalExpansion : ScalarValues::Real {
            unit = "mm";
        }
    }

    part def BladePath {
        port inlet : SteamInletPort;
        port exhaust : SteamOutletPort;
        port rotorPower : ShaftPort;

        attribute stageEfficiency : Efficiency = 0.90;
        attribute pressureRatio : ScalarValues::Real = 1200.0;
        attribute convertedPower : Power;

        part highPressureStage : TurbineStage {
            attribute nominalPressureDrop : Pressure = 8.0;
        }

        part intermediatePressureStage : TurbineStage {
            attribute nominalPressureDrop : Pressure = 5.0;
        }

        part lowPressureStage : TurbineStage {
            attribute nominalPressureDrop : Pressure = 3.0;
        }

        connect inlet.steamIn to highPressureStage.inlet.steamIn;
        connect highPressureStage.outlet.steamOut to intermediatePressureStage.inlet.steamIn;
        connect intermediatePressureStage.outlet.steamOut to lowPressureStage.inlet.steamIn;
        connect lowPressureStage.outlet.steamOut to exhaust.steamOut;
        connect lowPressureStage.powerOut.mechanicalPower to rotorPower.mechanicalPower;

        action expandSteam {
            in item inletSteam : Steam = inlet.steamIn;
            out item exhaustSteam : ExhaustSteam = exhaust.steamOut;
            out item power : ShaftPower = rotorPower.mechanicalPower;
        }
    }

    part def TurbineStage {
        port inlet : SteamInletPort;
        port outlet : SteamOutletPort;
        port powerOut : ShaftPort;

        attribute nominalPressureDrop : Pressure;
        attribute nominalTemperatureDrop : Temperature;
        attribute isentropicEfficiency : Efficiency = 0.89;

        part stationaryNozzles : NozzleRow;
        part rotatingBlades : BladeRow;

        action convertThermalEnergy {
            in item steam : Steam = inlet.steamIn;
            out item expandedSteam : ExhaustSteam = outlet.steamOut;
            out item stagePower : ShaftPower = powerOut.mechanicalPower;
        }
    }

    part def NozzleRow {
        attribute throatArea : ScalarValues::Real {
            unit = "m^2";
        }
        attribute exitVelocity : ScalarValues::Real {
            unit = "m/s";
        }
    }

    part def BladeRow {
        attribute bladeHeight : ScalarValues::Real {
            unit = "m";
        }
        attribute bladeSpeed : ScalarValues::Real {
            unit = "m/s";
        }
        attribute reactionRatio : ScalarValues::Real;
    }

    part def RotorAssembly {
        port inputPower : ShaftPort;
        port outputPower : ShaftPort;
        port sensorOutput : ControlPort;

        attribute speed : RotationalSpeed;
        attribute torque : Torque;
        attribute axialPosition : ScalarValues::Real {
            unit = "mm";
        }

        part shaft : TurbineShaft;
        part coupling : ShaftCoupling;
        part thrustCollar : ThrustCollar;

        connect inputPower.mechanicalPower to shaft.inputPower.mechanicalPower;
        connect shaft.outputPower.mechanicalPower to coupling.inputPower.mechanicalPower;
        connect coupling.outputPower.mechanicalPower to outputPower.mechanicalPower;

        action transmitPower {
            in item turbinePower : ShaftPower = inputPower.mechanicalPower;
            out item deliveredPower : ShaftPower = outputPower.mechanicalPower;
        }
    }

    part def TurbineShaft {
        port inputPower : ShaftPort;
        port outputPower : ShaftPort;

        attribute criticalSpeedMargin : Efficiency = 0.20;
        attribute shaftStress : ScalarValues::Real {
            unit = "MPa";
        }
    }

    part def ShaftCoupling {
        port inputPower : ShaftPort;
        port outputPower : ShaftPort;

        attribute couplingEfficiency : Efficiency = 0.995;
        attribute alignmentOffset : ScalarValues::Real {
            unit = "mm";
        }
    }

    part def ThrustCollar {
        attribute axialLoad : ScalarValues::Real {
            unit = "kN";
        }
    }

    part def BearingSystem {
        port sensorOutput : ControlPort;

        attribute journalBearingTemperature : Temperature;
        attribute thrustBearingTemperature : Temperature;
        attribute vibration : VibrationLevel;

        part frontJournalBearing : JournalBearing;
        part rearJournalBearing : JournalBearing;
        part thrustBearing : ThrustBearing;
    }

    part def JournalBearing {
        attribute oilFilmPressure : Pressure;
        attribute metalTemperature : Temperature;
        attribute vibration : VibrationLevel;
    }

    part def ThrustBearing {
        attribute thrustLoad : ScalarValues::Real {
            unit = "kN";
        }
        attribute padTemperature : Temperature;
    }

    part def LubricationSystem {
        attribute oilSupplyPressure : Pressure = 0.35;
        attribute oilSupplyTemperature : Temperature = 45.0;
        attribute oilFlowRate : MassFlowRate;

        part mainOilPump : OilPump;
        part emergencyOilPump : OilPump;
        part oilCooler : OilCooler;
        part oilFilter : OilFilter;
    }

    part def OilPump {
        attribute dischargePressure : Pressure;
        attribute flowRate : MassFlowRate;
        attribute running : ScalarValues::Boolean;
    }

    part def OilCooler {
        attribute inletOilTemperature : Temperature;
        attribute outletOilTemperature : Temperature;
        attribute coolingDuty : Power;
    }

    part def OilFilter {
        attribute differentialPressure : Pressure;
        attribute filtrationRating : ScalarValues::Real {
            unit = "micrometer";
        } = 10.0;
    }

    part def SealingSystem {
        attribute glandSteamPressure : Pressure = 0.12;
        attribute airIngressRate : MassFlowRate;

        part highPressureGlandSeal : GlandSeal;
        part lowPressureGlandSeal : GlandSeal;
    }

    part def GlandSeal {
        attribute sealSteamPressure : Pressure;
        attribute leakageFlow : MassFlowRate;
    }

    part def ExhaustHood {
        port inlet : SteamInletPort;
        port outlet : SteamOutletPort;

        attribute exhaustPressure : Pressure;
        attribute exhaustTemperature : Temperature;
        attribute pressureLoss : Pressure;

        action diffuseExhaustFlow {
            in item expandedSteam : Steam = inlet.steamIn;
            out item exhaustSteam : ExhaustSteam = outlet.steamOut;
        }
    }

    part def GovernorControlSystem {
        port sensorInput : ControlPort;
        port valveCommand : ControlPort;

        attribute speedSetpoint : RotationalSpeed = 3600.0;
        attribute loadSetpoint : Power;
        attribute speedDroop : Efficiency = 0.04;
        attribute governorValveDemand : ValvePosition;

        action computeValveDemand {
            in item feedback : SensorSignal = sensorInput.feedback;
            out item command : ControlSignal = valveCommand.command;
        }

        state def GovernorMode {
            state SpeedControl;
            state LoadControl;
            state Runback;
            state TripLatched;

            entry SpeedControl;

            transition SpeedControl_to_LoadControl
                first SpeedControl
                then LoadControl
                if sensorInput.feedback.measuredPower > 25.0;

            transition LoadControl_to_Runback
                first LoadControl
                then Runback
                if sensorInput.feedback.measuredVibration > 7.1;

            transition Runback_to_LoadControl
                first Runback
                then LoadControl
                if sensorInput.feedback.measuredVibration < 4.5;

            transition Any_to_TripLatched
                first SpeedControl
                then TripLatched
                if sensorInput.feedback.measuredSpeed > 3960.0;
        }
    }

    part def TurbineProtectionSystem {
        port sensorInput : ControlPort;
        port tripOutput : ControlPort;

        attribute overspeedTripSetpoint : RotationalSpeed = 3960.0;
        attribute highVibrationTripSetpoint : VibrationLevel = 11.2;
        attribute lowOilPressureTripSetpoint : Pressure = 0.12;
        attribute highExhaustPressureTripSetpoint : Pressure = 0.025;
        attribute tripLatched : ScalarValues::Boolean = false;

        action evaluateTripConditions {
            in item feedback : SensorSignal = sensorInput.feedback;
            out item command : ControlSignal = tripOutput.command;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject turbine : SteamTurbineSystem;

        doc /* The steam turbine system shall convert thermal energy and pressure energy contained in high-pressure, high-temperature steam into controlled rotating mechanical shaft power suitable for driving an electric generator or other industrial load. */

        require constraint {
            turbine.shaftOutput.mechanicalPower.generatedPower <= turbine.ratedPower
        }

        require constraint {
            turbine.steamSupply.steamIn.pressure <= turbine.ratedInletPressure
        }

        require constraint {
            turbine.steamSupply.steamIn.temperature <= turbine.ratedInletTemperature
        }
    }

    requirement def PowerRegulationRequirement {
        subject turbine : SteamTurbineSystem;

        doc /* The turbine governor shall regulate admitted steam flow to maintain shaft speed during startup and to track load demand during synchronized operation. */

        require constraint {
            turbine.rotorAssembly.speed <= 1.10 * turbine.ratedSpeed
        }
    }

    requirement def SafeTripRequirement {
        subject turbine : SteamTurbineSystem;

        doc /* The protection system shall command immediate closure of the main stop valve when overspeed, excessive vibration, low lubricating oil pressure, or excessive exhaust pressure is detected. */

        require constraint {
            turbine.protectionSystem.tripLatched implies turbine.steamAdmissionSystem.mainStopValve.position == 0.0
        }
    }

    requirement def ExhaustConditionRequirement {
        subject turbine : SteamTurbineSystem;

        doc /* The exhaust hood shall discharge expanded steam to the condenser while maintaining exhaust back pressure within the specified operating range. */

        require constraint {
            turbine.exhaustDischarge.steamOut.condenserBackPressure >= turbine.minimumExhaustPressure
        }
    }

    requirement def LubricationRequirement {
        subject turbine : SteamTurbineSystem;

        doc /* The lubrication system shall provide continuous filtered and cooled oil to journal and thrust bearings during startup, operation, shutdown, and coastdown. */

        require constraint {
            turbine.lubricationSystem.oilSupplyPressure >= turbine.protectionSystem.lowOilPressureTripSetpoint
        }
    }

    requirement def EfficiencyRequirement {
        subject turbine : SteamTurbineSystem;

        doc /* The turbine blade path shall achieve the specified design conversion efficiency at rated inlet conditions and rated shaft speed. */

        require constraint {
            turbine.bladePath.stageEfficiency >= turbine.designEfficiency
        }
    }

    part steamTurbinePlant : SteamTurbineSystem {
        attribute ratedPower = 500.0;
        attribute ratedSpeed = 3600.0;
        attribute ratedInletPressure = 16.5;
        attribute ratedInletTemperature = 540.0;
        attribute minimumExhaustPressure = 0.008;
        attribute designEfficiency = 0.88;
    }

    satisfy PrimaryFunctionRequirement by steamTurbinePlant;
    satisfy PowerRegulationRequirement by steamTurbinePlant.governorControl;
    satisfy SafeTripRequirement by steamTurbinePlant.protectionSystem;
    satisfy ExhaustConditionRequirement by steamTurbinePlant.exhaustHood;
    satisfy LubricationRequirement by steamTurbinePlant.lubricationSystem;
    satisfy EfficiencyRequirement by steamTurbinePlant.bladePath;
}