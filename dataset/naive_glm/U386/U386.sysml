package ElectrodeGelSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ---- Value types with units ----
    attribute def Conductivity :> Real {
        unit = "S/m";
    }
    attribute def Viscosity :> Real {
        unit = "Pa.s";
    }
    attribute def pHValue :> Real {
        unit = "pH";
    }
    attribute def Impedance :> Real {
        unit = "ohm";
    }
    attribute def Thickness :> Real {
        unit = "mm";
    }
    attribute def Voltage :> Real {
        unit = "mV";
    }
    attribute def Frequency :> Real {
        unit = "Hz";
    }
    attribute def SNR :> Real {
        unit = "dB";
    }
    attribute def Duration :> Real {
        unit = "min";
    }
    attribute def Area :> Real {
        unit = "cm2";
    }

    // ---- Item definitions ----
    item def BioelectricSignal {
        attribute amplitude : Voltage;
        attribute frequency : Frequency;
        attribute source : String;
    }

    item def GelFormulation {
        attribute conductivity : Conductivity;
        attribute viscosity : Viscosity;
        attribute pH : pHValue;
        attribute biocompatible : Boolean;
    }

    // ---- Port definitions ----
    port def SignalPort {
        out signal : BioelectricSignal;
    }

    port def BidirectionalSignalPort {
        in inSignal : BioelectricSignal;
        out outSignal : BioelectricSignal;
    }

    port def GelDispensePort {
        out formulation : GelFormulation;
    }

    // ---- Part definitions ----
    part def Skin {
        port outerSurface : BidirectionalSignalPort;
        attribute dryImpedance : Impedance;
        attribute contactArea : Area;
    }

    part def Electrode {
        port contact : BidirectionalSignalPort;
        port output : SignalPort;
        attribute electrodeImpedance : Impedance;
    }

    part def GelLayer {
        port skinSide : BidirectionalSignalPort;
        port electrodeSide : BidirectionalSignalPort;
        attribute formulation : GelFormulation;
        attribute thickness : Thickness;
        attribute effectiveImpedance : Impedance;
        attribute measuredSNR : SNR;
        attribute activeDuration : Duration;

        state machine Lifecycle {
            initial start;
            state Stored {
                entry action enterStored;
                attribute stable : Boolean = true;
            }
            state Active {
                entry action enterActive;
                attribute conducting : Boolean = true;
            }
            state Degrading {
                entry action enterDegrading;
                attribute conductivityFalling : Boolean = true;
            }
            state Depleted {
                entry action enterDepleted;
                attribute conductive : Boolean = false;
            }

            transition Stored -> Active
                on applyGel
                to action applyGelAction {
                    in layer : GelLayer;
                    in skin : Skin;
                };

            transition Active -> Degrading
                when activeDuration > 30.0;

            transition Degrading -> Depleted
                when effectiveImpedance > 5000.0;

            transition Depleted -> Stored
                on cleanAndReplace
                to action cleanAndReplaceAction {
                    in layer : GelLayer;
                    in container : GelContainer;
                };
        }
    }

    part def GelContainer {
        port dispense : GelDispensePort;
        attribute storedGel : GelFormulation;
        attribute remainingVolume : Real { unit = "mL"; }
    }

    part def MeasurementDevice {
        port input : SignalPort;
        attribute measuredSignal : BioelectricSignal;
        attribute displaySNR : SNR;
    }

    // ---- Connection definitions ----
    connection def SignalFlow {
        end source : BidirectionalSignalPort;
        end target : BidirectionalSignalPort;
        attribute transferred : BioelectricSignal;
    }

    connection def GelTransfer {
        end source : GelDispensePort;
        end target : GelLayer;
        attribute transferred : GelFormulation;
    }

    // ---- Action definitions ----
    action def ApplyGel {
        in skin : Skin;
        in container : GelContainer;
        out layer : GelLayer;
        attribute appliedThickness : Thickness;
    }

    action def ConductSignal {
        in layer : GelLayer;
        in bodySignal : BioelectricSignal;
        out coupledSignal : BioelectricSignal;
        attribute reducedImpedance : Impedance;
    }

    action def DegradeGel {
        in layer : GelLayer;
        out degraded : Boolean;
        attribute exposureTime : Duration;
    }

    action def CleanAndReplace {
        in layer : GelLayer;
        in container : GelContainer;
        out newLayer : GelLayer;
    }

    // ---- Requirements ----
    requirement def HighConductivity {
        subject gel : GelFormulation;
        require gel.conductivity >= 1.0;
        doc "The gel must have high electrical conductivity to transmit faint bioelectric signals.";
    }

    requirement def BalancedViscosity {
        subject gel : GelFormulation;
        require gel.viscosity >= 1.0 and gel.viscosity <= 10.0;
        doc "The gel viscosity must allow easy application while remaining in place.";
    }

    requirement def Biocompatibility {
        subject gel : GelFormulation;
        require gel.biocompatible == true;
        require gel.pH >= 6.5 and gel.pH <= 7.5;
        doc "The gel must be biocompatible with a neutral pH to avoid skin irritation.";
    }

    requirement def ImpedanceReduction {
        subject layer : GelLayer;
        subject skin : Skin;
        require layer.effectiveImpedance <= 1000.0;
        require layer.effectiveImpedance < skin.dryImpedance;
        doc "The gel layer must reduce skin impedance to create a low-resistance path.";
    }

    requirement def SignalCoupling {
        subject layer : GelLayer;
        require layer.measuredSNR >= 40.0;
        doc "The gel must couple bioelectric signals with a good signal-to-noise ratio.";
    }

    requirement def LifecycleStability {
        subject layer : GelLayer;
        require layer.activeDuration >= 30.0;
        doc "The gel must remain conductive for at least 30 minutes after application.";
    }

    // ---- System assembly ----
    part def ElectrodeGelAssembly {
        part skin : Skin {
            dryImpedance = 50000.0;
            contactArea = 10.0;
        }
        part gel : GelLayer {
            formulation = GelFormulation {
                conductivity = 5.0;
                viscosity = 4.5;
                pH = 7.0;
                biocompatible = true;
            };
            thickness = 0.5;
            effectiveImpedance = 800.0;
            measuredSNR = 45.0;
            activeDuration = 0.0;
        }
        part electrode : Electrode {
            electrodeImpedance = 100.0;
        }
        part container : GelContainer {
            storedGel = gel.formulation;
            remainingVolume = 50.0;
        }
        part device : MeasurementDevice {
            displaySNR = gel.measuredSNR;
        }

        connection skinToGel : SignalFlow connect skin.outerSurface to gel.skinSide;
        connection gelToElectrode : SignalFlow connect gel.electrodeSide to electrode.contact;
        connection electrodeToDevice : SignalFlow connect electrode.output to device.input;
        connection dispenseToGel : GelTransfer connect container.dispense to gel;

        // Behavioral allocation
        action applyGelAction : ApplyGel {
            in skin = skin;
            in container = container;
            out layer = gel;
        }
        action conductSignalAction : ConductSignal {
            in layer = gel;
            in bodySignal = skin.outerSurface.inSignal;
            out coupledSignal = electrode.output.signal;
        }
        action degradeGelAction : DegradeGel {
            in layer = gel;
            out degraded;
        }
        action cleanAndReplaceAction : CleanAndReplace {
            in layer = gel;
            in container = container;
            out newLayer = gel;
        }

        // Requirement satisfaction
        satisfy HighConductivity by gel.formulation;
        satisfy BalancedViscosity by gel.formulation;
        satisfy Biocompatibility by gel.formulation;
        satisfy ImpedanceReduction by gel;
        satisfy SignalCoupling by gel;
        satisfy LifecycleStability by gel;
    }
}
