package BeerEngineSystemModel {

    import ScalarValues::*;
    import ISQ::*;

    attribute def Volume;
    attribute def Pressure;
    attribute def FlowRate;
    attribute def Temperature;
    attribute def Force;
    attribute def Length;
    attribute def Time;

    enum def EngineOperatingMode {
        enum idle;
        enum priming;
        enum dispensing;
        enum recovering;
        enum cleaning;
        enum faulted;
    }

    enum def BeerCondition {
        enum still;
        enum conditioned;
        enum aerated;
        enum foaming;
        enum depleted;
    }

    item def CaskAle {
        attribute volume : Volume;
        attribute temperature : Temperature;
        attribute dissolvedCO2Pressure : Pressure;
        attribute condition : BeerCondition;
    }

    item def AmbientAir {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
    }

    item def CleaningFluid {
        attribute volume : Volume;
        attribute temperature : Temperature;
    }

    item def DispensedBeer {
        attribute volume : Volume;
        attribute temperature : Temperature;
        attribute dispenseFlowRate : FlowRate;
        attribute condition : BeerCondition;
    }

    port def BeerIntakePort {
        in item aleIn : CaskAle;
    }

    port def BeerOutletPort {
        out item aleOut : DispensedBeer;
    }

    port def AirVentPort {
        in item airIn : AmbientAir;
    }

    port def CleaningPort {
        in item cleanerIn : CleaningFluid;
    }

    part def HandleAssembly {
        attribute handleStrokeLength : Length = 0.32 [m];
        attribute maximumOperatorForce : Force = 90 [N];
        attribute returnSpringForce : Force = 28 [N];

        port operatorInput;
        port mechanicalDrive;

        action pullHandle {
            in attribute appliedForce : Force;
            out attribute pistonDisplacement : Length;
        }

        action returnHandle {
            out attribute pistonDisplacement : Length;
        }

        state def HandleState {
            state rest;
            state pulled;
            state returning;

            transition first rest;
            transition rest_to_pulled
                first rest
                then pulled;

            transition pulled_to_returning
                first pulled
                then returning;

            transition returning_to_rest
                first returning
                then rest;
        }
    }

    part def PumpCylinder {
        attribute sweptVolumePerStroke : Volume = 0.000284 [m^3];
        attribute chamberPressure : Pressure = 101325 [Pa];
        attribute minimumSealPressure : Pressure = 98000 [Pa];
        attribute maximumWorkingPressure : Pressure = 185000 [Pa];

        port mechanicalDrive;
        port suctionPort : BeerIntakePort;
        port deliveryPort : BeerOutletPort;

        action createSuction {
            out item drawnAle : CaskAle;
            out attribute suctionPressure : Pressure;
        }

        action pressurizeCharge {
            in item drawnAle : CaskAle;
            out item pressurizedAle : CaskAle;
            out attribute deliveryPressure : Pressure;
        }
    }

    part def CheckValve {
        attribute crackingPressure : Pressure = 1200 [Pa];
        attribute reverseLeakageFlow : FlowRate = 0.0000002 [m^3/s];

        port upstream;
        port downstream;

        action openForwardFlow {
            in attribute upstreamPressure : Pressure;
            in attribute downstreamPressure : Pressure;
            out attribute permittedFlow : FlowRate;
        }

        action blockReverseFlow {
            in attribute downstreamPressure : Pressure;
            in attribute upstreamPressure : Pressure;
            out attribute reverseFlow : FlowRate;
        }
    }

    part def Cask {
        attribute containedVolume : Volume = 0.0409 [m^3];
        attribute servingTemperature : Temperature = 285.15 [K];
        attribute headspacePressure : Pressure = 101325 [Pa];

        port beerOutlet : BeerIntakePort;
        port airInlet : AirVentPort;

        item storedAle : CaskAle;

        action supplyAle {
            out item aleCharge : CaskAle;
        }

        action admitAirToReplaceVolume {
            in item air : AmbientAir;
            in attribute removedVolume : Volume;
        }
    }

    part def StillageAndVent {
        attribute ventPressure : Pressure = 101325 [Pa];
        attribute maximumTiltAngle : Real = 8.0;

        port caskAirPort : AirVentPort;
        port roomAirPort : AirVentPort;

        item replacementAir : AmbientAir;
    }

    part def SuctionLine {
        attribute internalVolume : Volume = 0.00045 [m^3];
        attribute nominalFlowRate : FlowRate = 0.000025 [m^3/s];

        port caskEnd : BeerIntakePort;
        port pumpEnd : BeerIntakePort;
    }

    part def DeliveryLine {
        attribute internalVolume : Volume = 0.00032 [m^3];
        attribute nominalFlowRate : FlowRate = 0.00003 [m^3/s];

        port pumpEnd : BeerOutletPort;
        port tapEnd : BeerOutletPort;
    }

    part def SparklerNozzle {
        attribute orificeCount : Integer = 24;
        attribute totalOpenArea : Real = 0.000018;
        attribute aerationPressureDrop : Pressure = 18000 [Pa];

        port inlet : BeerOutletPort;
        port outlet : BeerOutletPort;

        action conditionBeer {
            in item incomingAle : DispensedBeer;
            out item conditionedAle : DispensedBeer;
        }
    }

    part def TapSpout {
        attribute servingFlowRate : FlowRate = 0.000028 [m^3/s];
        attribute dispenseTemperature : Temperature = 285.15 [K];

        port inlet : BeerOutletPort;
        port glassOutlet : BeerOutletPort;

        action pourPint {
            in item conditionedAle : DispensedBeer;
            out item servedAle : DispensedBeer;
        }
    }

    part def DripTray {
        attribute captureVolume : Volume = 0.0015 [m^3];

        port wasteIn;
    }

    part def BeerEngine {
        attribute targetServingVolume : Volume = 0.000568 [m^3];
        attribute strokesPerPint : Integer = 2;
        attribute operatingMode : EngineOperatingMode;
        attribute normalServingTemperature : Temperature = 285.15 [K];

        port caskConnection : BeerIntakePort;
        port ambientVent : AirVentPort;
        port serviceCleaningPort : CleaningPort;
        port dispenseOutlet : BeerOutletPort;

        part handle : HandleAssembly;
        part cylinder : PumpCylinder;
        part inletValve : CheckValve;
        part outletValve : CheckValve;
        part suctionLine : SuctionLine;
        part deliveryLine : DeliveryLine;
        part sparkler : SparklerNozzle;
        part spout : TapSpout;
        part dripTray : DripTray;

        connect caskConnection to suctionLine.caskEnd;
        connect suctionLine.pumpEnd to inletValve.upstream;
        connect inletValve.downstream to cylinder.suctionPort;
        connect cylinder.deliveryPort to outletValve.upstream;
        connect outletValve.downstream to deliveryLine.pumpEnd;
        connect deliveryLine.tapEnd to sparkler.inlet;
        connect sparkler.outlet to spout.inlet;
        connect spout.glassOutlet to dispenseOutlet;
        connect handle.mechanicalDrive to cylinder.mechanicalDrive;

        action dispenseServing {
            in item aleFromCask : CaskAle;
            out item servedBeer : DispensedBeer;

            first start;
            then pullHandle;
            then drawAle;
            then pressurizeAle;
            then deliverAle;
            then conditionAle;
            then pourAle;
            then finish;

            action start {
                out attribute mode : EngineOperatingMode = EngineOperatingMode::dispensing;
            }

            action pullHandle {
                in attribute force : Force = 65 [N];
                out attribute stroke : Length = 0.32 [m];
            }

            action drawAle {
                in item sourceAle : CaskAle;
                out item chamberCharge : CaskAle;
            }

            action pressurizeAle {
                in item chamberCharge : CaskAle;
                out item pressurizedCharge : CaskAle;
            }

            action deliverAle {
                in item pressurizedCharge : CaskAle;
                out item flowingBeer : DispensedBeer;
            }

            action conditionAle {
                in item flowingBeer : DispensedBeer;
                out item conditionedBeer : DispensedBeer;
            }

            action pourAle {
                in item conditionedBeer : DispensedBeer;
                out item servedBeer : DispensedBeer;
            }

            action finish {
                out attribute mode : EngineOperatingMode = EngineOperatingMode::idle;
            }
        }

        state def BeerEngineState {
            state idle;
            state priming;
            state ready;
            state dispensing;
            state recovering;
            state cleaning;
            state faulted;

            transition initial_to_idle
                first idle;

            transition idle_to_priming
                first idle
                then priming;

            transition priming_to_ready
                first priming
                then ready;

            transition ready_to_dispensing
                first ready
                then dispensing;

            transition dispensing_to_recovering
                first dispensing
                then recovering;

            transition recovering_to_ready
                first recovering
                then ready;

            transition ready_to_cleaning
                first ready
                then cleaning;

            transition cleaning_to_idle
                first cleaning
                then idle;

            transition any_to_faulted
                first ready
                then faulted;
        }
    }

    part beerEngineInstallation {
        part engine : BeerEngine;
        part cask : Cask;
        part vent : StillageAndVent;

        port glassService : BeerOutletPort;

        connect cask.beerOutlet to engine.caskConnection;
        connect vent.caskAirPort to cask.airInlet;
        connect engine.dispenseOutlet to glassService;

        item servedPint : DispensedBeer;

        requirement primaryFunction {
            subject engine : BeerEngine;

            doc
            /*
             * The BeerEngine shall manually draw cask-conditioned ale from a vented cask
             * by operator handle motion, raise the ale through a pump cylinder and check
             * valve arrangement, condition it through the delivery nozzle, and dispense
             * a controlled serving into a drinking vessel without external gas pressure.
             */

            require constraint {
                engine.targetServingVolume == 0.000568 [m^3]
            }
        }

        requirement manualOperation {
            subject engine : BeerEngine;

            doc
            /*
             * The BeerEngine shall complete one nominal pint serving using no more than
             * two full handle strokes under normal cellar temperature and vented cask
             * conditions.
             */

            require constraint {
                engine.strokesPerPint <= 2
            }
        }

        requirement cellarTemperatureServing {
            subject cask : Cask;

            doc
            /*
             * The cask ale supplied to the BeerEngine shall be maintained at cellar
             * serving temperature before dispensing.
             */

            require constraint {
                cask.servingTemperature >= 283.15 [K] and cask.servingTemperature <= 287.15 [K]
            }
        }

        requirement lowPressureCaskService {
            subject cask : Cask;

            doc
            /*
             * The system shall serve ale from a naturally vented cask without applying
             * external carbon dioxide or nitrogen dispense pressure to the cask.
             */

            require constraint {
                cask.headspacePressure == 101325 [Pa]
            }
        }

        requirement reverseFlowPrevention {
            subject engine : BeerEngine;

            doc
            /*
             * The inlet and outlet check valves shall prevent delivered beer from flowing
             * backward into the pump chamber or cask during handle recovery.
             */

            require constraint {
                engine.inletValve.reverseLeakageFlow <= 0.0000002 [m^3/s] and
                engine.outletValve.reverseLeakageFlow <= 0.0000002 [m^3/s]
            }
        }
    }
}