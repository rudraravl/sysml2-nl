package MicroneedlePatchSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQVolume::*;
    import ISQPressure::*;
    import ISQTime::*;

    // ---- Value types with units ----
    attribute def NeedleLength :> Real { unit = "um"; }
    attribute def NeedleCount :> Integer;
    attribute def FlowRate :> Real { unit = "uL/min"; }
    attribute def DoseVolume :> VolumeValue;
    attribute def DeliveredVolume :> VolumeValue;
    attribute def WearDuration :> TimeValue;
    attribute def ApplicationPressure :> PressureValue;
    attribute def ReservoirCapacity :> VolumeValue;

    // ---- Item types ----
    item def TherapeuticDrug {
        attribute concentration : Real;
        attribute formulation : String;
    }

    // ---- Requirements ----
    requirement def PainlessPenetrationRequirement {
        doc /* Needles must be short enough to avoid nerves. */
        constraint { needleLength <= 800 [um] }
    }

    requirement def WearDurationRequirement {
        doc /* Patch must adhere for up to 24 hours. */
        constraint { wearDuration <= 24 [h] }
    }

    requirement def ControlledDeliveryRequirement {
        doc /* Drug delivery must be controlled at a precise rate. */
        constraint { flowRate >= 0.1 [uL/min] and flowRate <= 50.0 [uL/min] }
    }

    requirement def SingleUseRequirement {
        doc /* Reservoir is single-use and non-refillable. */
        constraint { refillable == false }
    }

    requirement def FullDoseRequirement {
        doc /* System must deliver the full prescribed dose. */
        constraint { deliveredVolume == prescribedDose }
    }

    // ---- Parts ----

    part def MicroneedleArray {
        attribute needleLength : NeedleLength = 600 [um];
        attribute needleCount : NeedleCount = 200;
        port skinInterfacePort;
        port drugInPort;
        requirement PainlessPenetrationRequirement {
            attribute needleLength = 600 [um];
        }
    }

    part def AdhesiveBacking {
        attribute adhesiveStrength : Real;
        attribute wearDuration : WearDuration = 24 [h];
        port skinContactPort;
        requirement WearDurationRequirement {
            attribute wearDuration = 24 [h];
        }
    }

    part def DrugReservoir {
        attribute capacity : ReservoirCapacity = 2.0 [mL];
        attribute refillable : Boolean = false;
        attribute remainingVolume : VolumeValue;
        item drug : TherapeuticDrug;
        port drugOutPort;
        requirement SingleUseRequirement {
            attribute refillable = false;
        }
    }

    part def MicrofluidicPump {
        attribute nominalFlowRate : FlowRate = 5.0 [uL/min];
        attribute active : Boolean = false;
        port drugInPort;
        port drugOutPort;
        port commandPort;
        action def PumpOperation {
            in drugIn : TherapeuticDrug;
            in flowRateCmd : FlowRate;
            out drugOut : TherapeuticDrug;
        }
    }

    part def PressureSensor {
        attribute measuredPressure : PressureValue;
        attribute threshold : PressureValue = 20.0 [kPa];
        port pressureReadPort;
        action def SensePressure {
            out pressure : PressureValue;
        }
    }

    part def FlowController {
        attribute prescribedDose : DoseVolume = 1.0 [mL];
        attribute targetFlowRate : FlowRate = 5.0 [uL/min];
        attribute deliveredVolume : DeliveredVolume = 0.0 [mL];
        attribute doseComplete : Boolean = false;
        port pressureInPort;
        port pumpCommandPort;
        port statusPort;

        action def ComputeDeliveryCommand {
            in pressure : PressureValue;
            in delivered : DeliveredVolume;
            in prescribed : DoseVolume;
            out pumpActive : Boolean;
            out flowRateCmd : FlowRate;
        }

        state def ControllerStates {
            entry; then Idle;

            state Idle {
                entry; then wait;
                transition wait then Applied
                    when pressureInPort.pressure >= 20.0 [kPa];
            }

            state Applied {
                entry; then check;
                action check {
                    // Confirm skin penetration via pressure
                }
                transition check then Delivering
                    when pressureInPort.pressure >= 20.0 [kPa];
            }

            state Delivering {
                entry; then activate;
                action activate {
                    send pumpCommandPort.command(start, targetFlowRate);
                }
                do {
                    deliveredVolume := deliveredVolume + (targetFlowRate * dt);
                    if deliveredVolume >= prescribedDose then
                        doseComplete := true;
                }
                transition then Complete
                    when doseComplete == true;
            }

            state Complete {
                entry; then stop;
                action stop {
                    send pumpCommandPort.command(stop, 0.0 [uL/min]);
                }
                transition then Disposed;
            }

            state Disposed {
                entry;
            }
        }
    }

    // ---- Top-level system ----
    part def WearableMicroneedlePatch {
        part microneedleArray : MicroneedleArray;
        part adhesiveBacking : AdhesiveBacking;
        part drugReservoir : DrugReservoir;
        part microfluidicPump : MicrofluidicPump;
        part pressureSensor : PressureSensor;
        part flowController : FlowController;

        // Connections
        connection drugReservoir.drugOutPort to microfluidicPump.drugInPort;
        connection microfluidicPump.drugOutPort to microneedleArray.drugInPort;
        connection pressureSensor.pressureReadPort to flowController.pressureInPort;
        connection flowController.pumpCommandPort to microfluidicPump.commandPort;

        // Skin interface
        port skinInterfacePort;
        connection adhesiveBacking.skinContactPort to skinInterfacePort;
        connection microneedleArray.skinInterfacePort to skinInterfacePort;

        // Requirements at system level
        requirement ControlledDeliveryRequirement {
            attribute flowRate = 5.0 [uL/min];
        }
        requirement FullDoseRequirement {
            attribute deliveredVolume = 1.0 [mL];
            attribute prescribedDose = 1.0 [mL];
        }
    }
}
