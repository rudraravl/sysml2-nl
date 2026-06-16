package ChernobylDisasterModel {
    import ScalarValues::*;
    import SI::*;

    attribute def ThermalPower :> Real {
        :>> unit = W;
    }

    attribute def ElectricPower :> Real {
        :>> unit = W;
    }

    attribute def Temperature :> Real {
        :>> unit = K;
    }

    attribute def Pressure :> Real {
        :>> unit = Pa;
    }

    attribute def FlowRate :> Real {
        :>> unit = kg / s;
    }

    attribute def Reactivity :> Real {
        :>> unit = one;
    }

    attribute def RadiationDoseRate :> Real {
        :>> unit = Sv / h;
    }

    attribute def RodInsertionFraction :> Real {
        :>> unit = one;
    }

    item def Steam {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute massFlow : FlowRate;
    }

    item def CoolingWater {
        attribute temperature : Temperature;
        attribute pressure : Pressure;
        attribute massFlow : FlowRate;
    }

    item def ElectricalEnergy {
        attribute netPower : ElectricPower;
        attribute frequency : Real;
    }

    item def NeutronPopulation {
        attribute fluxLevel : Real;
        attribute reactivityMargin : Reactivity;
    }

    item def RadioactiveRelease {
        attribute iodine131DoseRate : RadiationDoseRate;
        attribute cesium137DoseRate : RadiationDoseRate;
        attribute releaseRate : FlowRate;
    }

    item def OperatorCommand {
        attribute requestedPower : ElectricPower;
        attribute emergencyShutdownRequested : Boolean;
        attribute turbineTestModeRequested : Boolean;
    }

    item def AlarmSignal {
        attribute highPowerAlarm : Boolean;
        attribute lowFlowAlarm : Boolean;
        attribute highPressureAlarm : Boolean;
        attribute radiationAlarm : Boolean;
        attribute voidCoefficientHazardAlarm : Boolean;
    }

    port def CoolantPort {
        inout item coolant : CoolingWater;
    }

    port def SteamPort {
        out item steam : Steam;
    }

    port def ElectricalPort {
        out item electricity : ElectricalEnergy;
    }

    port def NeutronControlPort {
        inout item neutronState : NeutronPopulation;
    }

    port def CommandPort {
        in item command : OperatorCommand;
    }

    port def AlarmPort {
        out item alarm : AlarmSignal;
    }

    port def ReleasePort {
        out item release : RadioactiveRelease;
    }

    part def RBMKReactorCore {
        attribute nominalThermalPower : ThermalPower = 3200e6 [W];
        attribute currentThermalPower : ThermalPower;
        attribute coreTemperature : Temperature;
        attribute coolantVoidFraction : Real;
        attribute positiveVoidCoefficient : Reactivity;
        attribute graphiteModeratorTemperature : Temperature;

        port coolantIn : CoolantPort;
        port steamOut : SteamPort;
        port neutronControl : NeutronControlPort;
        port releaseOut : ReleasePort;

        part fuelChannels[1661] : FuelChannel;
        part graphiteModerator : GraphiteModerator;
        part pressureTubes[1661] : PressureTube;

        action heatCoolant {
            in item coolantInput : CoolingWater;
            in item neutronInput : NeutronPopulation;
            out item steamOutput : Steam;
        }

        state reactorCoreState {
            entry; then subcritical;

            state subcritical;
            state criticalStable;
            state unstableLowPower;
            state powerExcursion;
            state coreDamage;
            state radioactiveRelease;

            transition subcritical_to_critical
                first subcritical
                accept OperatorCommand
                if command.requestedPower > 0 [W]
                then criticalStable;

            transition critical_to_unstable
                first criticalStable
                if coolantVoidFraction > 0.25 and positiveVoidCoefficient > 0.0
                then unstableLowPower;

            transition unstable_to_excursion
                first unstableLowPower
                if neutronControl.neutronState.reactivityMargin > 0.01
                then powerExcursion;

            transition excursion_to_damage
                first powerExcursion
                if currentThermalPower > 5000e6 [W]
                then coreDamage;

            transition damage_to_release
                first coreDamage
                if coreTemperature > 2500 [K]
                then radioactiveRelease;
        }
    }

    part def FuelChannel {
        attribute fuelTemperature : Temperature;
        attribute localPower : ThermalPower;
        attribute coolantFlow : FlowRate;
    }

    part def PressureTube {
        attribute tubePressure : Pressure;
        attribute tubeTemperature : Temperature;
        attribute ruptureLimit : Pressure = 10e6 [Pa];
        attribute ruptured : Boolean;
    }

    part def GraphiteModerator {
        attribute moderatorTemperature : Temperature;
        attribute storedHeat : ThermalPower;
        attribute burning : Boolean;
    }

    part def ControlRodSystem {
        attribute totalRods : Integer = 211;
        attribute insertedRods : Integer;
        attribute averageInsertion : RodInsertionFraction;
        attribute scramInsertionTime : Real;
        attribute graphiteTipEffectPresent : Boolean = true;

        port commandIn : CommandPort;
        port neutronControl : NeutronControlPort;
        port alarmOut : AlarmPort;

        action regulateReactivity {
            in item command : OperatorCommand;
            inout item neutronState : NeutronPopulation;
            out item alarm : AlarmSignal;
        }

        action emergencyShutdown {
            in item command : OperatorCommand;
            inout item neutronState : NeutronPopulation;
        }

        state rodControlState {
            entry; then automaticRegulation;

            state automaticRegulation;
            state manualWithdrawal;
            state emergencyInsertion;
            state insertionDelayed;
            state shutdownAchieved;
            state shutdownFailed;

            transition auto_to_manual
                first automaticRegulation
                accept OperatorCommand
                if command.turbineTestModeRequested
                then manualWithdrawal;

            transition manual_to_scram
                first manualWithdrawal
                accept OperatorCommand
                if command.emergencyShutdownRequested
                then emergencyInsertion;

            transition scram_to_delayed
                first emergencyInsertion
                if scramInsertionTime > 10.0
                then insertionDelayed;

            transition delayed_to_failed
                first insertionDelayed
                if neutronControl.neutronState.reactivityMargin > 0.0
                then shutdownFailed;

            transition scram_to_shutdown
                first emergencyInsertion
                if neutronControl.neutronState.reactivityMargin <= 0.0
                then shutdownAchieved;
        }
    }

    part def PrimaryCoolingSystem {
        attribute totalCoolantFlow : FlowRate;
        attribute inletTemperature : Temperature;
        attribute outletTemperature : Temperature;
        attribute drumSeparatorPressure : Pressure;

        port coreIn : CoolantPort;
        port coreOut : SteamPort;

        part mainCirculationPumps[8] : CirculationPump;
        part drumSeparators[4] : DrumSeparator;

        action removeCoreHeat {
            in item heatedSteam : Steam;
            out item cooledWater : CoolingWater;
        }
    }

    part def CirculationPump {
        attribute pumpFlow : FlowRate;
        attribute powered : Boolean;
        attribute cavitating : Boolean;
    }

    part def DrumSeparator {
        attribute waterLevel : Real;
        attribute steamPressure : Pressure;
    }

    part def TurbineGeneratorSystem {
        attribute generatedPower : ElectricPower;
        attribute turbineSpeed : Real;
        attribute generatorConnectedToGrid : Boolean;

        port steamIn : SteamPort;
        port electricalOut : ElectricalPort;
        port commandIn : CommandPort;

        action convertSteamToElectricity {
            in item steam : Steam;
            out item electricity : ElectricalEnergy;
        }

        state turbineTestState {
            entry; then gridConnected;

            state gridConnected;
            state rundownTest;
            state lowPumpPower;
            state testTerminated;

            transition connected_to_test
                first gridConnected
                accept OperatorCommand
                if command.turbineTestModeRequested
                then rundownTest;

            transition test_to_low_pump_power
                first rundownTest
                if turbineSpeed < 0.7
                then lowPumpPower;

            transition test_to_terminated
                first rundownTest
                accept OperatorCommand
                if command.emergencyShutdownRequested
                then testTerminated;
        }
    }

    part def InstrumentationAndAlarmSystem {
        attribute indicatedPower : ThermalPower;
        attribute indicatedCoolantFlow : FlowRate;
        attribute indicatedPressure : Pressure;
        attribute indicatedDoseRate : RadiationDoseRate;

        port commandIn : CommandPort;
        port alarmOut : AlarmPort;

        action monitorPlant {
            out item alarm : AlarmSignal;
        }
    }

    part def EmergencyResponseAndContainmentSystem {
        attribute exclusionZoneRadius : Real;
        attribute evacuationActive : Boolean;
        attribute fireSuppressionActive : Boolean;
        attribute releaseMitigated : Boolean;

        port releaseIn : ReleasePort;
        port alarmIn : AlarmPort;

        action isolateArea {
            in item alarm : AlarmSignal;
        }

        action suppressGraphiteFire {
            in item release : RadioactiveRelease;
        }

        action evacuatePopulation {
            in item alarm : AlarmSignal;
        }

        state responseState {
            entry; then normalMonitoring;

            state normalMonitoring;
            state plantEmergency;
            state fireResponse;
            state radiologicalRelease;
            state evacuation;
            state longTermContainment;

            transition normal_to_emergency
                first normalMonitoring
                accept AlarmSignal
                if alarm.highPowerAlarm or alarm.highPressureAlarm
                then plantEmergency;

            transition emergency_to_fire
                first plantEmergency
                accept RadioactiveRelease
                if release.releaseRate > 0.0 [kg / s]
                then fireResponse;

            transition fire_to_release
                first fireResponse
                if releaseIn.release.iodine131DoseRate > 0.001 [Sv / h]
                then radiologicalRelease;

            transition release_to_evacuation
                first radiologicalRelease
                if releaseIn.release.cesium137DoseRate > 0.001 [Sv / h]
                then evacuation;

            transition evacuation_to_containment
                first evacuation
                if evacuationActive == true
                then longTermContainment;
        }
    }

    part def ChernobylUnit4DisasterSystem {
        attribute primaryFunction : String =
            "Generate electrical power by controlled nuclear fission, transfer heat to steam, convert steam energy to grid electricity, and maintain reactor conditions within safe limits.";

        attribute accidentScenario : String =
            "A low-power turbine rundown test created unstable reactor conditions in an RBMK-1000 core with positive void coefficient, reduced safety margins, delayed shutdown effectiveness, power excursion, pressure-tube rupture, graphite fire, and radioactive release.";

        port operatorCommands : CommandPort;
        port gridOutput : ElectricalPort;
        port publicHazardRelease : ReleasePort;
        port plantAlarm : AlarmPort;

        part reactorCore : RBMKReactorCore;
        part controlRods : ControlRodSystem;
        part coolingSystem : PrimaryCoolingSystem;
        part turbineGenerator : TurbineGeneratorSystem;
        part instrumentation : InstrumentationAndAlarmSystem;
        part emergencyResponse : EmergencyResponseAndContainmentSystem;

        connection coolantLoop1 connect coolingSystem.coreIn to reactorCore.coolantIn;
        connection steamPath connect reactorCore.steamOut to coolingSystem.coreOut;
        connection steamToTurbine connect reactorCore.steamOut to turbineGenerator.steamIn;
        connection electricalExport connect turbineGenerator.electricalOut to gridOutput;
        connection rodNeutronControl connect controlRods.neutronControl to reactorCore.neutronControl;
        connection operatorToRods connect operatorCommands to controlRods.commandIn;
        connection operatorToTurbine connect operatorCommands to turbineGenerator.commandIn;
        connection operatorToInstrumentation connect operatorCommands to instrumentation.commandIn;
        connection reactorReleaseToEnvironment connect reactorCore.releaseOut to publicHazardRelease;
        connection reactorReleaseToEmergency connect reactorCore.releaseOut to emergencyResponse.releaseIn;
        connection alarmToPlant connect instrumentation.alarmOut to plantAlarm;
        connection alarmToEmergency connect instrumentation.alarmOut to emergencyResponse.alarmIn;

        action performPrimaryFunction {
            in item operatorCommand : OperatorCommand;
            out item electricity : ElectricalEnergy;

            first startReactor;
            then regulatePower;
            then circulateCoolant;
            then generateSteam;
            then produceElectricity;
            then monitorSafety;

            action startReactor;
            action regulatePower;
            action circulateCoolant;
            action generateSteam;
            action produceElectricity;
            action monitorSafety;
        }

        action executeAccidentResponse {
            in item alarm : AlarmSignal;
            in item release : RadioactiveRelease;

            first detectHazard;
            then initiateShutdown;
            then isolatePlantArea;
            then suppressFire;
            then evacuatePopulation;
            then stabilizeLongTermContainment;

            action detectHazard;
            action initiateShutdown;
            action isolatePlantArea;
            action suppressFire;
            action evacuatePopulation;
            action stabilizeLongTermContainment;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject plant : ChernobylUnit4DisasterSystem;

        doc
            /* The plant shall generate electrical power from controlled nuclear fission while maintaining reactor power, coolant flow, pressure, and radiation release within safe operating limits. */

        require constraint {
            plant.reactorCore.currentThermalPower <= plant.reactorCore.nominalThermalPower
        }
    }

    requirement def ReactivityControlRequirement {
        subject rods : ControlRodSystem;

        doc
            /* The control rod system shall provide sufficient negative reactivity to shut down the reactor under abnormal operating conditions. */

        require constraint {
            rods.averageInsertion >= 0.9
        }
    }

    requirement def CoolingRequirement {
        subject cooling : PrimaryCoolingSystem;

        doc
            /* The primary cooling system shall remove reactor heat at a rate sufficient to prevent fuel-channel overheating. */

        require constraint {
            cooling.totalCoolantFlow > 0.0 [kg / s]
        }
    }

    requirement def AlarmRequirement {
        subject alarmSystem : InstrumentationAndAlarmSystem;

        doc
            /* The instrumentation system shall detect hazardous reactor power, coolant flow, pressure, and radiation conditions and issue alarms. */

        require constraint {
            alarmSystem.indicatedPower >= 0.0 [W]
        }
    }

    requirement def RadioactiveReleaseMitigationRequirement {
        subject response : EmergencyResponseAndContainmentSystem;

        doc
            /* The emergency response system shall reduce public exposure by isolation, fire suppression, evacuation, and long-term containment after radioactive release. */

        require constraint {
            response.releaseMitigated == true
        }
    }

    requirement def ChernobylAccidentHazardRequirement {
        subject plant : ChernobylUnit4DisasterSystem;

        doc
            /* The model shall represent the hazardous progression observed in the Chernobyl Unit 4 disaster: unstable low-power operation, positive void coefficient effects, delayed shutdown effectiveness, power excursion, core damage, and radiological release. */

        require constraint {
            plant.reactorCore.positiveVoidCoefficient > 0.0
        }
    }
}