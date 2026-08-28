package ChernobylUnit4 {
    import Definitions::*;
    private import ISQ::*;
    private import ScalarValues::*;
    private import Time::*;

    package Definitions {
        private import ISQ::*;
        private import ScalarValues::*;
        private import Time::*;

        item def Fuel {
            attribute enrichment : Real;
            attribute mass : MassValue;
        }
        item def Graphite {
            attribute density : Real;
        }
        item def Water {
            attribute temperature : TemperatureValue;
            attribute mass : MassValue;
        }
        item def Steam {
            attribute pressure : Real;
            attribute temperature : TemperatureValue;
        }
        item def SteamWaterMixture {
            attribute quality : Real;
            attribute pressure : Real;
        }
        item def BoronCarbide;
        item def Electricity;

        attribute def VoidCoefficient :> Real;
        attribute def Reactivity :> Real;
        attribute def DelayValue :> DurationValue;

        attribute def StartSafetyTestSignal;
        attribute def TestBeginSignal;
        attribute def PowerSurgeDetectedSignal;
        attribute def AZ5ScramSignal;
        attribute def SteamExplosionSignal;
        attribute def GraphiteFireSignal;

        port def CoolantPort {
            attribute flowRate : Real;
            attribute temperature : TemperatureValue;
            out item coolant : Water;
        }
        port def MixturePort {
            attribute pressure : Real;
            out item mixture : SteamWaterMixture;
        }
        port def SteamPort {
            attribute pressure : Real;
            attribute temperature : TemperatureValue;
            out item steam : Steam;
        }
        port def ElectricalPort {
            attribute power : Real;
            out item electricity : Electricity;
        }

        part def FuelChannel {
            attribute fuelMass : MassValue;
            ref item fuel : Fuel;
            attribute powerDensity : Real;
        }
        part def GraphiteModerator {
            attribute mass : MassValue;
            ref item graphite : Graphite;
            attribute temperature : TemperatureValue;
        }
        part def ReactorCore {
            attribute nominalThermalPower : Real = 3200e6;
            attribute currentThermalPower : Real;
            attribute voidCoefficient : VoidCoefficient;
            attribute reactivity : Reactivity;
            attribute voidFraction : Real;
            attribute fuelChannelCount : Integer = 1661;
            part fuelChannels : FuelChannel[1661];
            part moderator : GraphiteModerator;
            port coolantInlet : ~CoolantPort;
            port coolantOutlet : MixturePort;
            constraint { voidCoefficient > 0 }
        }
        part def ControlRod {
            part absorberSection {
                ref item boronCarbide : BoronCarbide;
            }
            part displacerTip {
                ref item graphiteTip : Graphite;
                attribute length : LengthValue;
            }
            attribute insertionLevel : Real;
        }
        part def ControlRodAssembly {
            attribute rodCount : Integer = 211;
            part rods : ControlRod[211];
            attribute graphiteTipLength : LengthValue;
            constraint { graphiteTipLength > 0 }
        }
        part def CoolantPump {
            attribute nominalFlowRate : Real;
            attribute currentFlowRate : Real;
            attribute operational : Boolean;
        }
        part def PrimaryCoolantCircuit {
            attribute systemPressure : Real;
            attribute totalFlowRate : Real;
            part pumps : CoolantPump[8];
            port coreInlet : CoolantPort;
            port drumReturn : ~CoolantPort;
        }
        part def SteamSeparatorDrum {
            attribute operatingPressure : Real;
            attribute waterLevel : LengthValue;
            port mixtureInlet : ~MixturePort;
            port steamOutlet : SteamPort;
            port waterOutlet : CoolantPort;
        }
        part def Turbine {
            attribute rotationalSpeed : Real;
            port steamInlet : ~SteamPort;
        }
        part def Generator {
            attribute outputPower : Real;
            port electricalOutput : ElectricalPort;
        }
        part def TurbineGeneratorSet {
            part turbine : Turbine;
            part generator : Generator;
            port steamInlet : ~SteamPort;
            port electricalOutput : ElectricalPort;
        }
        part def OperatorControlRoom {
            attribute operatorsPresent : Integer;
            attribute safetySystemsOverride : Boolean;
            attribute scramPressed : Boolean;
        }
        part def EmergencyProtectionSystem {
            attribute enabled : Boolean;
            attribute autoScramActive : Boolean;
            attribute powerThreshold : Real;
            attribute minFlowThreshold : Real;
        }
        part def RBMK1000 {
            attribute designation : String = "Chernobyl Unit 4";
            attribute totalMass : MassValue;
            part core : ReactorCore;
            part controlRods : ControlRodAssembly;
            part coolantCircuit : PrimaryCoolantCircuit;
            part steamDrum1 : SteamSeparatorDrum;
            part steamDrum2 : SteamSeparatorDrum;
            part turbineGenerator : TurbineGeneratorSet;
            part controlRoom : OperatorControlRoom;
            part eps : EmergencyProtectionSystem;
            port gridConnection : ElectricalPort;
        }

        action def GeneratePower;
        action def ReduceReactorPower;
        action def DisableSafetySystems;
        action def InitiateScram;
        action def DetectOverpower;
        action def SteamExplosion;
        action def RuptureReactor;
        action def ExplodeAndRupture;
        action def GraphiteFireAction;
        action def SpreadContamination;
        action def MonitorVoids;

        state def ReactorStates;

        requirement def RBMKDesignRequirement {
            doc /* Base requirement for RBMK-1000 reactor design. */
        }
        requirement def NominalPowerRequirement :> RBMKDesignRequirement {
            doc /* The reactor shall produce 3200 MW thermal power at nominal operation. */
            attribute nominalPower : Real = 3200e6;
        }
        requirement def VoidCoefficientRequirement :> RBMKDesignRequirement {
            doc /* The reactor exhibits a positive void coefficient causing instability at low power. */
            attribute voidCoefficient : VoidCoefficient;
            constraint { voidCoefficient > 0 }
        }
        requirement def ControlRodFlawRequirement :> RBMKDesignRequirement {
            doc /* Control rods include graphite displacer tips causing reactivity surge on insertion. */
            attribute graphiteTipPresent : Boolean = true;
        }
        requirement def EPSRequirement :> RBMKDesignRequirement {
            doc /* The EPS shall automatically scram the reactor on overpower or low coolant flow. */
            attribute powerThreshold : Real = 3200e6;
        }
    }

    package Usage {
        private import Definitions::*;

        part unit4 : RBMK1000 {
            attribute ::> totalMass;

            part core : ReactorCore {
                attribute ::> nominalThermalPower = 3200e6;
                attribute ::> currentThermalPower = 3200e6;
                attribute ::> voidCoefficient = 4.7e-5;
                attribute ::> voidFraction = 0.0;
                attribute ::> reactivity = 0.0;
                part fuelChannels : FuelChannel[1661];
                part moderator : GraphiteModerator {
                    attribute ::> mass = 1700e3 [kg];
                }
            }

            part controlRods : ControlRodAssembly {
                attribute ::> rodCount = 211;
                attribute ::> graphiteTipLength = 4.5 [m];
                part rods : ControlRod[211];
            }

            part coolantCircuit : PrimaryCoolantCircuit {
                attribute ::> systemPressure = 7e6;
                part pumps : CoolantPump[8];
            }

            part steamDrum1 : SteamSeparatorDrum;
            part steamDrum2 : SteamSeparatorDrum;
            part turbineGenerator : TurbineGeneratorSet;

            part controlRoom : OperatorControlRoom {
                attribute ::> operatorsPresent = 4;
                attribute ::> safetySystemsOverride = false;
                attribute ::> scramPressed = false;
            }

            part eps : EmergencyProtectionSystem {
                attribute ::> enabled = true;
                attribute ::> autoScramActive = true;
                attribute ::> powerThreshold = 3200e6;
            }

            connect core.coolantOutlet to steamDrum1.mixtureInlet;
            connect core.coolantOutlet to steamDrum2.mixtureInlet;
            connect steamDrum1.steamOutlet to turbineGenerator.steamInlet;
            connect steamDrum2.steamOutlet to turbineGenerator.steamInlet;
            connect steamDrum1.waterOutlet to coolantCircuit.drumReturn;
            connect steamDrum2.waterOutlet to coolantCircuit.drumReturn;
            connect coolantCircuit.coreInlet to core.coolantInlet;
            connect turbineGenerator.electricalOutput to gridConnection;
        }

        action generatePower : GeneratePower;
        action reducePower : ReduceReactorPower;
        action disableSafety : DisableSafetySystems;
        action initiateScram : InitiateScram;
        action detectOverpower : DetectOverpower;
        action steamExplosion : SteamExplosion;
        action ruptureReactor : RuptureReactor;
        action explodeAndRupture : ExplodeAndRupture;
        action graphiteFire : GraphiteFireAction;
        action spreadContamination : SpreadContamination;
        action monitorVoids : MonitorVoids;

        attribute secondExplosionDelay : DelayValue = 3 [s];
        attribute fireStartDelay : DelayValue = 1 [s];

        state reactorBehavior : ReactorStates {
            in reactor : RBMK1000 = unit4;

            entry; then off;

            state off;

            accept StartSafetyTestSignal
                then reducing;

            state reducing {
                entry reducePower;
            }

            accept TestBeginSignal
                then lowPowerUnstable;

            state lowPowerUnstable {
                entry disableSafety;
                do monitorVoids;
            }

            accept when reactor.core.voidFraction > 0.1
                do send new PowerSurgeDetectedSignal() to reactor.controlRoom
                then powerSurge;

            state powerSurge {
                entry detectOverpower;
            }

            accept AZ5ScramSignal
                then scramInitiated;

            state scramInitiated {
                entry initiateScram;
            }

            accept when reactor.core.reactivity > 0
                then powerSpike;

            state powerSpike;

            accept when reactor.core.currentThermalPower > 100e9
                then explosion;

            state explosion {
                entry explodeAndRupture;
            }

            accept after secondExplosionDelay
                then secondExplosion;

            state secondExplosion {
                entry steamExplosion;
            }

            accept after fireStartDelay
                then fire;

            state fire {
                entry graphiteFire;
                do spreadContamination;
            }
        }

        requirement designReq : RBMKDesignRequirement;
        requirement powerReq : NominalPowerRequirement;
        requirement voidCoeffReq : VoidCoefficientRequirement {
            attribute ::> voidCoefficient = 4.7e-5;
        }
        requirement rodFlawReq : ControlRodFlawRequirement;
        requirement epsReq : EPSRequirement;

        satisfy powerReq by unit4;
        satisfy voidCoeffReq by unit4.core;
        satisfy rodFlawReq by unit4.controlRods;
        satisfy epsReq by unit4.eps;
    }
}
