package BeerEngine {
    import ISQ::*;
    import SI::*;
    import ScalarValues::*;

    // ---- Item definitions ----
    item def Beer;
    item def CaskConditionedAle :> Beer {
        attribute carbonationLevel : Real = 1.0; // relative, dimensionless
    }

    // ---- Value types and constants ----
    attribute def cellarTemperature : Temperature = 11 [Cel];
    attribute def atmosphericPressure : Pressure = 101.3 [kPa];
    attribute def halfPint : Volume = 0.284 [L];
    attribute def fullPint : Volume = 0.568 [L];
    attribute def handleLength : Length = 0.9 [m];
    attribute def cylinderBore : Length = 0.05 [m];
    attribute def pistonStroke : Length = 0.15 [m];

    // ---- Port definitions ----
    port def BeerFlowPort {
        out itemFlow : Beer;
        in itemFlowReverse : Beer;
    }
    port def MechanicalPort {
        in appliedForce : Force;
        out transmittedForce : Force;
    }
    port def PressurePort {
        out pressureValue : Pressure;
    }

    // ---- Part definitions ----
    part def Cask {
        attribute aleTemperature : Temperature = cellarTemperature;
        attribute headspacePressure : Pressure = atmosphericPressure;
        port beerOutlet : BeerFlowPort;
        item storedAle : CaskConditionedAle;
    }

    part def BeerLine {
        attribute lineLength : Length;
        attribute innerDiameter : Length;
        port beerInlet : BeerFlowPort;
        port beerOutlet : BeerFlowPort;
        flow from beerInlet.itemFlow to beerOutlet.itemFlow;
    }

    part def Handle {
        attribute length : Length = handleLength;
        attribute pullAngle : Real = 0.0; // degrees from rest
        attribute isPulled : Boolean = false;
        port mechanicalOutput : MechanicalPort;
        action def pull :> Action {
            out force : Force;
        }
        action def release :> Action {
            out force : Force;
        }
    }

    part def Piston {
        attribute position : Length = 0.0; // measured from bottom dead center
        attribute strokeLength : Length = pistonStroke;
        attribute diameter : Length = cylinderBore;
        attribute atTopDeadCenter : Boolean = false;
        attribute atBottomDeadCenter : Boolean = true;
        port mechanicalInput : MechanicalPort;
        port pressureOutput : PressurePort;
    }

    part def OneWayValve {
        attribute isOpen : Boolean = false;
        attribute crackingPressure : Pressure = 5.0 [kPa];
        port beerInlet : BeerFlowPort;
        port beerOutlet : BeerFlowPort;
        port actuationPressure : PressurePort;
        action def open :> Action { in pressure : Pressure; }
        action def close :> Action { in pressure : Pressure; }
    }

    part def PumpCylinder {
        attribute chamberVolume : Volume = 0.0 [L];
        attribute nominalChamberVolume : Volume = halfPint;
        port handleInput : MechanicalPort;
        port beerInlet : BeerFlowPort;
        port beerOutlet : BeerFlowPort;
        part piston : Piston;
        part inletValve : OneWayValve;
        part outletValve : OneWayValve;
        flow from beerInlet.itemFlow to inletValve.beerInlet.itemFlow;
        flow from inletValve.beerOutlet.itemFlow to beerOutlet.itemFlow;
        flow from outletValve.beerOutlet.itemFlow to beerOutlet.itemFlow;
    }

    part def Tap {
        attribute isOpen : Boolean = false;
        port beerInlet : BeerFlowPort;
        port beerOutlet : BeerFlowPort;
        flow from beerInlet.itemFlow to beerOutlet.itemFlow;
    }

    part def Glass {
        attribute fillVolume : Volume = 0.0 [L];
        attribute targetVolume : Volume = fullPint;
        port beerInlet : BeerFlowPort;
    }

    // ---- Top-level system ----
    part def BeerEngine {
        attribute dispensedVolume : Volume = 0.0 [L];
        attribute strokeCount : Integer = 0;

        part cask : Cask {
            redefinition aleTemperature = cellarTemperature;
            redefinition headspacePressure = atmosphericPressure;
        }
        part suctionLine : BeerLine {
            attribute redefinition lineLength = 3.0 [m];
            attribute redefinition innerDiameter = 0.012 [m];
        }
        part deliveryLine : BeerLine {
            attribute redefinition lineLength = 0.5 [m];
            attribute redefinition innerDiameter = 0.010 [m];
        }
        part pump : PumpCylinder;
        part handle : Handle;
        part tap : Tap;
        part glass : Glass;

        connection caskToSuction : Beer connect cask.beerOutlet.itemFlow to suctionLine.beerInlet.itemFlow;
        connection suctionToPump : Beer connect suctionLine.beerOutlet.itemFlow to pump.beerInlet.itemFlow;
        connection handleToPump : Force connect handle.mechanicalOutput.transmittedForce to pump.handleInput.appliedForce;
        connection pumpToDelivery : Beer connect pump.beerOutlet.itemFlow to deliveryLine.beerInlet.itemFlow;
        connection deliveryToTap : Beer connect deliveryLine.beerOutlet.itemFlow to tap.beerInlet.itemFlow;
        connection tapToGlass : Beer connect tap.beerOutlet.itemFlow to glass.beerInlet.itemFlow;

        // ---- Behavior: state machine governing the pull-and-push cycle ----
        state machine PumpCycle {
            attribute currentStrokeVolume : Volume = 0.0 [L];

            state Idle {
                entry assign pump.inletValve.isOpen = false;
                entry assign pump.outletValve.isOpen = false;
                entry assign handle.isPulled = false;
            }
            state PullStroke {
                entry assign handle.isPulled = true;
                entry assign pump.piston.atBottomDeadCenter = false;
                do action createVacuum {
                    // Piston moves upward, chamber pressure drops below cellar pressure
                    pump.piston.position := pump.piston.position + pump.piston.strokeLength;
                    pump.chamberVolume := pump.nominalChamberVolume;
                }
                do action openInlet {
                    pump.inletValve.isOpen := true;
                    pump.outletValve.isOpen := false;
                }
                exit assign pump.piston.atTopDeadCenter = true;
            }
            state PushStroke {
                entry assign handle.isPulled = false;
                entry assign pump.piston.atTopDeadCenter = false;
                do action pressurizeChamber {
                    // Piston moves downward, chamber pressure rises
                    pump.piston.position := pump.piston.position - pump.piston.strokeLength;
                }
                do action openOutlet {
                    pump.inletValve.isOpen := false;
                    pump.outletValve.isOpen := true;
                    tap.isOpen := true;
                }
                do action dispenseBeer {
                    dispensedVolume := dispensedVolume + halfPint;
                    glass.fillVolume := glass.fillVolume + halfPint;
                    strokeCount := strokeCount + 1;
                }
                exit assign tap.isOpen = false;
                exit assign pump.piston.atBottomDeadCenter = true;
            }

            transition Idle -> PullStroke when handle.isPulled == true;
            transition PullStroke -> PushStroke when pump.piston.atTopDeadCenter == true;
            transition PushStroke -> Idle when pump.piston.atBottomDeadCenter == true;
        }

        // ---- Action: full pint pour requires two strokes ----
        action pourFullPint {
            attribute poured : Volume = 0.0 [L];
            perform PumpCycle;
            perform PumpCycle;
            assert poured >= fullPint;
        }
    }

    // ---- Requirements ----
    requirement def DispenseWithoutGasRequirement {
        subject engine : BeerEngine;
        require {
            engine must dispense beer from cask to glass
            without use of pressurized gas
        }
        verify by engine.cask.headspacePressure == atmosphericPressure;
    }

    requirement def HalfPintPerCycleRequirement {
        subject pump : PumpCylinder;
        require {
            pump shall dispense a volume equal to halfPint
            per complete pull-and-push cycle of the handle
        }
        verify by pump.nominalChamberVolume == halfPint;
    }

    requirement def FullPintRequiresTwoStrokesRequirement {
        subject engine : BeerEngine;
        require {
            pouring a full pint shall require exactly two
            complete strokes of the handle
        }
        verify by engine.strokeCount == 2 implies engine.dispensedVolume >= fullPint;
    }

    requirement def PreserveCarbonationRequirement {
        subject ale : CaskConditionedAle;
        require {
            dispensing shall preserve the delicate carbonation
            and flavor profile of the cask-conditioned ale
        }
        verify by ale.carbonationLevel >= 0.95;
    }

    requirement def CellarTemperatureRequirement {
        subject cask : Cask;
        require {
            cask shall hold conditioned ale at cellarTemperature
            and near-atmospheric pressure
        }
        verify by cask.aleTemperature == cellarTemperature
            and cask.headspacePressure == atmosphericPressure;
    }

    // ---- Requirement satisfaction ----
    satisfaction satisfyDispenseWithoutGas : DispenseWithoutGasRequirement {
        subject engine : BeerEngine;
    }
    satisfaction satisfyHalfPintPerCycle : HalfPintPerCycleRequirement {
        subject pump : PumpCylinder;
    }
    satisfaction satisfyFullPintTwoStrokes : FullPintRequiresTwoStrokesRequirement {
        subject engine : BeerEngine;
    }
    satisfaction satisfyPreserveCarbonation : PreserveCarbonationRequirement {
        subject ale : CaskConditionedAle;
    }
    satisfaction satisfyCellarTemperature : CellarTemperatureRequirement {
        subject cask : Cask;
    }
}
