package IonacoSystem {
    public import Definitions::*;
    public import ISQ::*;
    public import ScalarValues::*;

    package Definitions {
        public import AttributeDefinitions::*;
        public import ItemDefinitions::*;
        public import SignalDefinitions::*;
        public import PortDefinitions::*;
        public import InterfaceDefinitions::*;
        public import ActionDefinitions::*;
        public import PartDefinitions::*;
        public import RequirementDefinitions::*;

        package AttributeDefinitions {
            public import ScalarValues::*;
            item def AirPurityIndex :> Real;
            item def IonConcentration :> Real;
            item def ParticulateCount :> Real;
            item def FanRPM :> Real;
            item def IonizationLevel :> Real;
            item def FiltrationEfficiency :> Real;
            item def PowerEfficiency :> Real;
        }

        package ItemDefinitions {
            item def AmbientAir {
                attribute purityIndex : AirPurityIndex;
                attribute temperature :> ISQ::temperature;
                attribute particulateCount : ParticulateCount;
            }
            item def FilteredAir {
                attribute purityIndex : AirPurityIndex;
                attribute particulateCount : ParticulateCount;
            }
            item def IonizedAir {
                attribute purityIndex : AirPurityIndex;
                attribute ionConcentration : IonConcentration;
            }
            item def ElectricalPower {
                attribute voltage :> ISQ::electricPotential;
                attribute frequency :> ISQ::frequency;
            }
            item def DCPower {
                attribute voltage :> ISQ::electricPotential;
                attribute power :> ISQ::power;
            }
        }

        package SignalDefinitions {
            item def PowerOnSignal;
            item def PowerOffSignal;
            item def StandbySignal;
            item def ActivateSignal;
            item def MaintenanceSignal;
            item def MaintenanceCompleteSignal;

            enum def ModeKind {
                low;
                medium;
                high;
                auto;
            }

            item def ModeSelectSignal {
                attribute mode : ModeKind;
            }
            item def FanSpeedCommand {
                attribute rpm : FanRPM;
            }
            item def IonizationCommand {
                attribute level : IonizationLevel;
            }
            item def AirQualityReading {
                attribute purityIndex : AirPurityIndex;
            }
            item def IonReading {
                attribute concentration : IonConcentration;
            }
        }

        package PortDefinitions {
            port def AmbientAirInPort {
                in item air : AmbientAir;
            }
            port def AmbientAirOutPort {
                out item air : AmbientAir;
            }
            port def FilteredAirInPort {
                in item air : FilteredAir;
            }
            port def FilteredAirOutPort {
                out item air : FilteredAir;
            }
            port def IonizedAirInPort {
                in item air : IonizedAir;
            }
            port def IonizedAirOutPort {
                out item air : IonizedAir;
            }
            port def ACPowerInPort {
                in item power : ElectricalPower;
            }
            port def DCPowerInPort {
                in item power : DCPower;
            }
            port def DCPowerOutPort {
                out item power : DCPower;
            }
            port def ControlInputPort {
                in powerOn : PowerOnSignal;
                in powerOff : PowerOffSignal;
                in standby : StandbySignal;
                in activate : ActivateSignal;
                in maintenance : MaintenanceSignal;
                in maintenanceComplete : MaintenanceCompleteSignal;
                in modeSelect : ModeSelectSignal;
            }
            port def FanCommandInPort {
                in command : FanSpeedCommand;
            }
            port def FanCommandOutPort {
                out command : FanSpeedCommand;
            }
            port def IonCommandInPort {
                in command : IonizationCommand;
            }
            port def IonCommandOutPort {
                out command : IonizationCommand;
            }
            port def AirQualityOutPort {
                out reading : AirQualityReading;
            }
            port def AirQualityInPort {
                in reading : AirQualityReading;
            }
            port def IonOutPort {
                out reading : IonReading;
            }
            port def IonInPort {
                in reading : IonReading;
            }
        }

        package InterfaceDefinitions {
            interface def AmbientAirFlow {
                end supplier : AmbientAirOutPort;
                end consumer : AmbientAirInPort;
            }
            interface def FilteredAirFlow {
                end supplier : FilteredAirOutPort;
                end consumer : FilteredAirInPort;
            }
            interface def IonizedAirFlow {
                end supplier : IonizedAirOutPort;
                end consumer : IonizedAirInPort;
            }
            interface def DCPowerFlow {
                end supplier : DCPowerOutPort;
                end consumer : DCPowerInPort;
            }
            interface def FanCommandFlow {
                end supplier : FanCommandOutPort;
                end consumer : FanCommandInPort;
            }
            interface def IonCommandFlow {
                end supplier : IonCommandOutPort;
                end consumer : IonCommandInPort;
            }
            interface def AirQualityFeedback {
                end supplier : AirQualityOutPort;
                end consumer : AirQualityInPort;
            }
            interface def IonFeedback {
                end supplier : IonOutPort;
                end consumer : IonInPort;
            }
        }

        package ActionDefinitions {
            action def drawAir {
                in item inAir : AmbientAir;
                out item outAir : AmbientAir;
            }
            action def filterAir {
                in item inAir : AmbientAir;
                out item outAir : FilteredAir;
            }
            action def ionizeAir {
                in item inAir : FilteredAir;
                out item outAir : IonizedAir;
            }
            action def distributeAir {
                in item inAir : IonizedAir;
                out item outAir : IonizedAir;
            }
            action def senseAirQuality {
                out reading : AirQualityReading;
            }
            action def senseIonConcentration {
                out reading : IonReading;
            }
            action def computeControl {
                in airQuality : AirQualityReading;
                in ionLevel : IonReading;
                out fanCmd : FanSpeedCommand;
                out ionCmd : IonizationCommand;
            }
            action def convertPower {
                in item inPower : ElectricalPower;
                out item outPower : DCPower;
            }
            action def enterStandby;
            action def activateSystem;
            action def monitorStandby;
            action def operateLow;
            action def operateMedium;
            action def operateHigh;
            action def operateAuto;
            action def performMaintenance;
            action def performSelfTest;
        }

        package PartDefinitions {
            part def IntakeFan {
                attribute speed : FanRPM;
                attribute maxSpeed : FanRPM;
                port airIntake : AmbientAirInPort;
                port airOutput : AmbientAirOutPort;
                port powerIn : DCPowerInPort;
                port cmdIn : FanCommandInPort;
                perform action drawAir;
            }

            part def HEPAFilter {
                attribute efficiency : FiltrationEfficiency;
                attribute maxParticulateSize :> ISQ::length;
                port airInput : AmbientAirInPort;
                port airOutput : FilteredAirOutPort;
                perform action filterAir;
            }

            part def IonizationModule {
                attribute electrodeVoltage :> ISQ::electricPotential;
                attribute ionizationLevel : IonizationLevel;
                attribute maxIonConcentration : IonConcentration;
                port airInput : FilteredAirInPort;
                port airOutput : IonizedAirOutPort;
                port powerIn : DCPowerInPort;
                port cmdIn : IonCommandInPort;
                perform action ionizeAir;
            }

            part def DistributionFan {
                attribute speed : FanRPM;
                attribute oscillating : ScalarValues::Boolean;
                attribute maxSpeed : FanRPM;
                port airInput : IonizedAirInPort;
                port airOutput : IonizedAirOutPort;
                port powerIn : DCPowerInPort;
                port cmdIn : FanCommandInPort;
                perform action distributeAir;
            }

            part def ControlProcessor {
                attribute targetPurity : AirPurityIndex;
                attribute targetIonConcentration : IonConcentration;
                attribute currentMode : ModeKind;
                port airQualityIn : AirQualityInPort;
                port ionIn : IonInPort;
                port controlInput : ControlInputPort;
                port fanCmdOut : FanCommandOutPort;
                port distFanCmdOut : FanCommandOutPort;
                port ionCmdOut : IonCommandOutPort;
                port powerIn : DCPowerInPort;
                perform action computeControl;
                exhibit state controllerStates {
                    entry action initial;
                    state idle;
                    state controlling {
                        do computeControl;
                    }
                    state adjusting;
                    transition initial then idle;
                    transition idle_to_controlling
                        first idle
                        accept modeSig : ModeSelectSignal via controlInput
                        then controlling;
                    transition controlling_to_adjusting
                        first controlling
                        accept airQ : AirQualityReading via airQualityIn
                        then adjusting;
                    transition adjusting_to_controlling
                        first adjusting
                        accept ionR : IonReading via ionIn
                        then controlling;
                    transition controlling_to_idle
                        first controlling
                        accept StandbySignal via controlInput
                        then idle;
                }
            }

            part def AirQualitySensor {
                attribute purityIndex : AirPurityIndex;
                attribute samplingRate :> ISQ::frequency;
                port feedback : AirQualityOutPort;
                port powerIn : DCPowerInPort;
                perform action senseAirQuality;
            }

            part def IonSensor {
                attribute concentration : IonConcentration;
                attribute samplingRate :> ISQ::frequency;
                port feedback : IonOutPort;
                port powerIn : DCPowerInPort;
                perform action senseIonConcentration;
            }

            part def PowerManagementUnit {
                attribute inputVoltage :> ISQ::electricPotential;
                attribute outputVoltage :> ISQ::electricPotential;
                attribute maxPower :> ISQ::power;
                attribute efficiency : PowerEfficiency;
                port acInput : ACPowerInPort;
                port fanPower1 : DCPowerOutPort;
                port fanPower2 : DCPowerOutPort;
                port ionPower : DCPowerOutPort;
                port sensorPower1 : DCPowerOutPort;
                port sensorPower2 : DCPowerOutPort;
                port controllerPower : DCPowerOutPort;
                perform action convertPower;
            }

            part def Ionaco {
                attribute roomVolume :> ISQ::volume;
                attribute currentMode : ModeKind;
                attribute targetPurity : AirPurityIndex;
                attribute targetIonConcentration : IonConcentration;

                port airIntake : AmbientAirInPort;
                port airExhaust : IonizedAirOutPort;
                port powerInput : ACPowerInPort;
                port controlInput : ControlInputPort;

                perform action enterStandby;
                perform action activateSystem;
                perform action monitorStandby;
                perform action operateLow;
                perform action operateMedium;
                perform action operateHigh;
                perform action operateAuto;
                perform action performMaintenance;
                perform action performSelfTest;

                part intakeFan : IntakeFan;
                part hepaFilter : HEPAFilter;
                part ionizationModule : IonizationModule;
                part distributionFan : DistributionFan;
                part controlProcessor : ControlProcessor;
                part airQualitySensor : AirQualitySensor;
                part ionSensor : IonSensor;
                part powerManagement : PowerManagementUnit;

                connect airIntake to intakeFan.airIntake;
                connect intakeFan.airOutput to hepaFilter.airInput;
                connect hepaFilter.airOutput to ionizationModule.airInput;
                connect ionizationModule.airOutput to distributionFan.airInput;
                connect distributionFan.airOutput to airExhaust;

                connect powerInput to powerManagement.acInput;
                connect powerManagement.fanPower1 to intakeFan.powerIn;
                connect powerManagement.fanPower2 to distributionFan.powerIn;
                connect powerManagement.ionPower to ionizationModule.powerIn;
                connect powerManagement.sensorPower1 to airQualitySensor.powerIn;
                connect powerManagement.sensorPower2 to ionSensor.powerIn;
                connect powerManagement.controllerPower to controlProcessor.powerIn;

                connect controlInput to controlProcessor.controlInput;
                connect controlProcessor.fanCmdOut to intakeFan.cmdIn;
                connect controlProcessor.distFanCmdOut to distributionFan.cmdIn;
                connect controlProcessor.ionCmdOut to ionizationModule.cmdIn;

                connect airQualitySensor.feedback to controlProcessor.airQualityIn;
                connect ionSensor.feedback to controlProcessor.ionIn;

                exhibit state operatingStates {
                    entry action initial;

                    state off;

                    state standby {
                        entry enterStandby;
                        do monitorStandby;
                    }

                    state active {
                        entry activateSystem;

                        state low {
                            do operateLow;
                        }
                        state medium {
                            do operateMedium;
                        }
                        state high {
                            do operateHigh;
                        }
                        state auto {
                            do operateAuto;
                        }

                        transition initial then low;
                        transition low_to_medium
                            first low
                            accept modeSig : ModeSelectSignal via controlInput
                                if modeSig.mode == ModeKind::medium
                            then medium;
                        transition low_to_high
                            first low
                            accept modeSig : ModeSelectSignal via controlInput
                                if modeSig.mode == ModeKind::high
                            then high;
                        transition low_to_auto
                            first low
                            accept modeSig : ModeSelectSignal via controlInput
                                if modeSig.mode == ModeKind::auto
                            then auto;
                        transition medium_to_low
                            first medium
                            accept modeSig : ModeSelectSignal via controlInput
                                if modeSig.mode == ModeKind::low
                            then low;
                        transition medium_to_high
                            first medium
                            accept modeSig : ModeSelectSignal via controlInput
                                if modeSig.mode == ModeKind::high
                            then high;
                        transition medium_to_auto
                            first medium
                            accept modeSig : ModeSelectSignal via controlInput
                                if modeSig.mode == ModeKind::auto
                            then auto;
                        transition high_to_low
                            first high
                            accept modeSig : ModeSelectSignal via controlInput
                                if modeSig.mode == ModeKind::low
                            then low;
                        transition high_to_medium
                            first high
                            accept modeSig : ModeSelectSignal via controlInput
                                if modeSig.mode == ModeKind::medium
                            then medium;
                        transition high_to_auto
                            first high
                            accept modeSig : ModeSelectSignal via controlInput
                                if modeSig.mode == ModeKind::auto
                            then auto;
                        transition auto_to_low
                            first auto
                            accept modeSig : ModeSelectSignal via controlInput
                                if modeSig.mode == ModeKind::low
                            then low;
                        transition auto_to_medium
                            first auto
                            accept modeSig : ModeSelectSignal via controlInput
                                if modeSig.mode == ModeKind::medium
                            then medium;
                        transition auto_to_high
                            first auto
                            accept modeSig : ModeSelectSignal via controlInput
                                if modeSig.mode == ModeKind::high
                            then high;
                    }

                    state maintenance {
                        entry performSelfTest;
                        do performMaintenance;
                    }

                    transition initial then off;

                    transition off_to_standby
                        first off
                        accept PowerOnSignal via controlInput
                        then standby;

                    transition standby_to_off
                        first standby
                        accept PowerOffSignal via controlInput
                        then off;

                    transition standby_to_active
                        first standby
                        accept modeSig : ModeSelectSignal via controlInput
                            if modeSig.mode == ModeKind::low or modeSig.mode == ModeKind::medium or
                               modeSig.mode == ModeKind::high or modeSig.mode == ModeKind::auto
                        then active;

                    transition active_to_standby
                        first active
                        accept StandbySignal via controlInput
                        then standby;

                    transition active_to_maintenance
                        first active
                        accept MaintenanceSignal via controlInput
                        then maintenance;

                    transition maintenance_to_standby
                        first maintenance
                        accept MaintenanceCompleteSignal via controlInput
                        then standby;
                }
            }
        }

        package RequirementDefinitions {
            requirement def PurificationRequirement {
                attribute minOutputPurity : AirPurityIndex = 85;
                constraint { minOutputPurity >= 85 }
            }

            requirement def IonOutputRequirement {
                attribute minIonConcentration : IonConcentration = 1000000;
                constraint { minIonConcentration >= 1000000 }
            }

            requirement def ParticulateReductionRequirement {
                attribute minEfficiency : FiltrationEfficiency = 0.99;
                constraint { minEfficiency >= 0.99 }
            }

            requirement def PowerEfficiencyRequirement {
                attribute minEfficiency : PowerEfficiency = 0.90;
                constraint { minEfficiency >= 0.90 }
            }

            requirement def ModeCoverageRequirement {
                attribute supportedModeCount : Integer = 4;
                constraint { supportedModeCount >= 4 }
            }

            requirement def AutoModeRequirement {
                attribute optimalPurity : AirPurityIndex = 90;
                constraint { optimalPurity >= 85 }
            }
        }
    }
}
