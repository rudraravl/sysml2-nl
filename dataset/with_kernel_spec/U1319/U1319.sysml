package VacuumCleanerModel {
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        private import ScalarValues::*;
        private import ISQ::*;

        attribute def PowerOn;
        attribute def PowerOff;
        attribute def ModeSelect;
        attribute def StartCleaning;
        attribute def StopCleaning;
        attribute def DustFullAlert;
        attribute def FilterCloggedAlert;
        attribute def BatteryLowAlert;
        attribute def ChamberEmptied;
        attribute def FilterCleaned;
        attribute def BatteryCharged;

        enum def OperatingMode {
            eco;
            normal;
            turbo;
        }

        enum def SurfaceType {
            hardFloor;
            carpet;
            upholstery;
        }

        item def DirtyAir {
            attribute debrisConcentration : Real;
            attribute flowRate : Real;
        }

        item def CleanAir {
            attribute flowRate : Real;
        }

        item def Debris {
            attribute mass : Real;
        }

        item def ElectricalPower {
            attribute voltage : Real;
            attribute current : Real;
        }

        port def AirFlowPort {
            in item incomingAir;
            out item outgoingAir;
        }

        port def PowerPort {
            out item power : ElectricalPower;
        }

        port def ControlPort {
            in attribute mode : OperatingMode;
            out attribute surfaceType : SurfaceType;
            out attribute dustLevel : Real;
            out attribute filterStatus : Real;
            out attribute batteryLevel : Real;
        }

        action def GenerateSuction {
            in item dirtyAir : DirtyAir;
            out item suctionAir : DirtyAir;
            in attribute motorSpeed : Real;
        }

        action def AgitateSurface {
            in attribute brushSpeed : Real;
            out item dislodgedDebris : Debris;
        }

        action def SeparateDebris {
            in item dirtyAir : DirtyAir;
            out item debris : Debris;
            out item filteredAir : DirtyAir;
        }

        action def FilterAir {
            in item dirtyAir : DirtyAir;
            out item cleanAir : CleanAir;
            in attribute filterStage : Integer;
        }

        action def ExhaustAir {
            in item cleanAir : CleanAir;
        }

        action def SenseDustLevel {
            out attribute dustLevel : Real;
        }

        action def SenseFilterStatus {
            out attribute filterStatus : Real;
        }

        action def SenseBatteryLevel {
            out attribute batteryLevel : Real;
        }

        action def DetectSurface {
            out attribute surfaceType : SurfaceType;
        }

        action def AdjustPower {
            in attribute surfaceType : SurfaceType;
            in attribute mode : OperatingMode;
            out attribute motorSpeed : Real;
            out attribute brushSpeed : Real;
        }

        state def VacuumStates;
        state def ControllerStates;

        part def SuctionMotor {
            attribute maxSpeed : Real;
            attribute currentSpeed : Real;
            attribute powerConsumption : Real;
            port powerInput : PowerPort;
            port airOutput : AirFlowPort;
            perform action generateSuction : GenerateSuction;
        }

        part def ImpellerFan {
            attribute bladeCount : Integer;
            attribute diameter : Real;
            port airInput : AirFlowPort;
            port airOutput : AirFlowPort;
        }

        part def BatteryPack {
            attribute capacity : Real;
            attribute currentCharge : Real;
            attribute voltage : Real;
            attribute maxDischargeRate : Real;
            port powerOutput : PowerPort;
            perform action senseBatteryLevel : SenseBatteryLevel;
            assert constraint { currentCharge <= capacity }
        }

        part def CleaningHead {
            attribute brushSpeed : Real;
            port airIntake : AirFlowPort;
            port debrisOutput : AirFlowPort;
            part brushRoll {
                attribute speed : Real;
                attribute bristleType : String;
                perform action agitateSurface : AgitateSurface;
            }
            part nozzle {
                port airIntake : AirFlowPort;
            }
        }

        part def DustChamber {
            attribute capacity : Real;
            attribute currentFill : Real;
            attribute maxFillLevel : Real;
            port dirtyAirInput : AirFlowPort;
            port debrisOutput : AirFlowPort;
            perform action separateDebris : SeparateDebris;
            perform action senseDustLevel : SenseDustLevel;
            assert constraint { currentFill <= capacity }
        }

        part def PreFilter {
            attribute efficiency : Real;
            attribute clogLevel : Real;
            port dirtyAirInput : AirFlowPort;
            port filteredAirOutput : AirFlowPort;
            perform action filterAir : FilterAir;
            perform action senseFilterStatus : SenseFilterStatus;
        }

        part def HepaFilter {
            attribute efficiency : Real;
            attribute clogLevel : Real;
            port dirtyAirInput : AirFlowPort;
            port cleanAirOutput : AirFlowPort;
            perform action filterAir : FilterAir;
            perform action senseFilterStatus : SenseFilterStatus;
        }

        part def ExhaustPort {
            port cleanAirInput : AirFlowPort;
            perform action exhaustAir : ExhaustAir;
        }

        part def ControlModule {
            attribute selectedMode : OperatingMode;
            attribute detectedSurface : SurfaceType;
            port controlPort : ControlPort;
            port motorControl : ControlPort;
            port brushControl : ControlPort;
            port batteryMonitor : ControlPort;
            port dustMonitor : ControlPort;
            port filterMonitor : ControlPort;
            exhibit state controllerStates : ControllerStates;
            perform action detectSurface : DetectSurface;
            perform action adjustPower : AdjustPower;
        }

        part def VacuumCleaner {
            attribute totalMass : Real;
            attribute maxRuntime : Real;
            attribute suctionPower : Real;
            attribute dustChamberCapacity : Real;
            attribute hepaEfficiency : Real;

            port userInterface : ControlPort;

            part suctionMotor : SuctionMotor;
            part impellerFan : ImpellerFan;
            part batteryPack : BatteryPack;
            part cleaningHead : CleaningHead;
            part dustChamber : DustChamber;
            part preFilter : PreFilter;
            part hepaFilter : HepaFilter;
            part exhaustPort : ExhaustPort;
            part controlModule : ControlModule;

            connector batteryToMotor from batteryPack.powerOutput to suctionMotor.powerInput;
            connector motorToFan from suctionMotor.airOutput to impellerFan.airInput;
            connector fanToHead from impellerFan.airOutput to cleaningHead.airIntake;
            connector headToChamber from cleaningHead.debrisOutput to dustChamber.dirtyAirInput;
            connector chamberToPreFilter from dustChamber.debrisOutput to preFilter.dirtyAirInput;
            connector preFilterToHepa from preFilter.filteredAirOutput to hepaFilter.dirtyAirInput;
            connector hepaToExhaust from hepaFilter.cleanAirOutput to exhaustPort.cleanAirInput;

            message dustFullMsg of DustFullAlert from dustChamber to controlModule;
            message filterCloggedMsg of FilterCloggedAlert from preFilter to controlModule;
            message hepaCloggedMsg of FilterCloggedAlert from hepaFilter to controlModule;
            message batteryLowMsg of BatteryLowAlert from batteryPack to controlModule;

            exhibit state vacuumStates : VacuumStates;
        }

        requirement def RuntimeRequirement {
            doc /* The vacuum must provide sufficient runtime for typical cleaning tasks. */
            attribute minRuntime : Real;
        }

        requirement def SuctionPowerRequirement {
            doc /* The vacuum must generate sufficient suction power for effective cleaning. */
            attribute minSuctionPower : Real;
        }

        requirement def FiltrationEfficiencyRequirement {
            doc /* The HEPA filter must capture fine dust and allergens. */
            attribute minEfficiency : Real;
        }

        requirement def PortabilityRequirement {
            doc /* The vacuum must be lightweight and portable. */
            attribute maxMass : Real;
        }

        requirement def DustChamberCapacityRequirement {
            doc /* The dust chamber must hold sufficient debris for typical cleaning. */
            attribute minCapacity : Real;
        }
    }

    package Usages {
        private import Definitions::*;
        private import ScalarValues::*;
        private import ISQ::*;

        action generateSuction : GenerateSuction;
        action agitateSurface : AgitateSurface;
        action separateDebris : SeparateDebris;
        action filterAir : FilterAir;
        action exhaustAir : ExhaustAir;
        action senseDustLevel : SenseDustLevel;
        action senseFilterStatus : SenseFilterStatus;
        action senseBatteryLevel : SenseBatteryLevel;
        action detectSurface : DetectSurface;
        action adjustPower : AdjustPower;

        part vacuumCleaner : VacuumCleaner {
            attribute totalMass = 3.2;
            attribute maxRuntime = 40;
            attribute suctionPower = 250;
            attribute dustChamberCapacity = 1.0;
            attribute hepaEfficiency = 0.999;

            part suctionMotor : SuctionMotor {
                attribute maxSpeed = 125000;
                attribute currentSpeed = 0;
                attribute powerConsumption = 250;
            }

            part impellerFan : ImpellerFan {
                attribute bladeCount = 9;
                attribute diameter = 0.12;
            }

            part batteryPack : BatteryPack {
                attribute capacity = 108000;
                attribute currentCharge = 108000;
                attribute voltage = 25;
                attribute maxDischargeRate = 15;
            }

            part cleaningHead : CleaningHead {
                attribute brushSpeed = 0;
                part brushRoll {
                    attribute speed = 0;
                    attribute bristleType = "nylon";
                }
            }

            part dustChamber : DustChamber {
                attribute capacity = 1.0;
                attribute currentFill = 0.0;
                attribute maxFillLevel = 0.9;
            }

            part preFilter : PreFilter {
                attribute efficiency = 0.85;
                attribute clogLevel = 0.0;
            }

            part hepaFilter : HepaFilter {
                attribute efficiency = 0.999;
                attribute clogLevel = 0.0;
            }

            part controlModule : ControlModule {
                attribute selectedMode = OperatingMode::normal;
                attribute detectedSurface = SurfaceType::hardFloor;
            }
        }

        state vacuumStates : VacuumStates parallel {
            state 'operational states' {
                entry; then off;
                state off;
                accept PowerOn then idle;
                state idle;
                accept ModeSelect then standby;
                state standby;
                accept StartCleaning then active;
                state active {
                    entry detectSurface;
                    do generateSuction;
                    do agitateSurface;
                    do separateDebris;
                    do filterAir;
                    do exhaustAir;
                }
                accept StopCleaning then standby;
                accept PowerOff then off;
            }

            state 'health states' {
                entry; then normal;
                do senseDustLevel { out dustLevel; }
                do senseFilterStatus { out filterStatus; }
                do senseBatteryLevel { out batteryLevel; }

                state normal;
                accept when senseDustLevel.dustLevel > vacuumCleaner.dustChamber.maxFillLevel
                    do send new DustFullAlert() to vacuumCleaner.controlModule
                    then dustFull;
                accept when senseFilterStatus.filterStatus > 0.8
                    do send new FilterCloggedAlert() to vacuumCleaner.controlModule
                    then filterClogged;
                accept when senseBatteryLevel.batteryLevel < 0.2
                    do send new BatteryLowAlert() to vacuumCleaner.controlModule
                    then batteryLow;

                state dustFull;
                accept ChamberEmptied then normal;

                state filterClogged;
                accept FilterCleaned then normal;

                state batteryLow;
                accept BatteryCharged then normal;
            }
        }

        state controllerStates : ControllerStates parallel {
            state 'mode management' {
                entry; then modeSet;
                state modeSet {
                    do adjustPower;
                }
                accept ModeSelect then modeSet;
            }

            state 'surface adaptation' {
                entry; then adapting;
                state adapting {
                    do detectSurface;
                    do adjustPower;
                }
            }
        }

        requirement runtimeReq : RuntimeRequirement {
            attribute minRuntime = 40;
            assert constraint { vacuumCleaner.maxRuntime >= minRuntime }
        }

        requirement suctionPowerReq : SuctionPowerRequirement {
            attribute minSuctionPower = 250;
            assert constraint { vacuumCleaner.suctionPower >= minSuctionPower }
        }

        requirement filtrationReq : FiltrationEfficiencyRequirement {
            attribute minEfficiency = 0.999;
            assert constraint { vacuumCleaner.hepaFilter.efficiency >= minEfficiency }
        }

        requirement portabilityReq : PortabilityRequirement {
            attribute maxMass = 3.5;
            assert constraint { vacuumCleaner.totalMass <= maxMass }
        }

        requirement dustCapacityReq : DustChamberCapacityRequirement {
            attribute minCapacity = 1.0;
            assert constraint { vacuumCleaner.dustChamber.capacity >= minCapacity }
        }
    }
}
