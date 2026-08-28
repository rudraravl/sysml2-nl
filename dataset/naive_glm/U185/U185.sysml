package CerebralShunt {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpaceTime::*;
    import ISQMechanics::*;

    // ─────────────────────────────────────────────
    // Value types with units
    // ─────────────────────────────────────────────
    value def PressureValue :> Real { unit 'Pa'; }
    value def FlowRateValue :> Real { unit 'mL/h'; }
    value def VolumeValue :> Real { unit 'mL'; }
    value def LengthValue :> Real { unit 'mm'; }
    value def DiameterValue :> Real { unit 'mm'; }

    // ─────────────────────────────────────────────
    // Items
    // ─────────────────────────────────────────────
    item def CSF;

    // ─────────────────────────────────────────────
    // Port definitions
    // ─────────────────────────────────────────────
    port def CSFInPort {
        in item csf : CSF;
        ref attribute pressure : PressureValue;
    }

    port def CSFOutPort {
        out item csf : CSF;
        ref attribute pressure : PressureValue;
        ref attribute flowRate : FlowRateValue;
    }

    // ─────────────────────────────────────────────
    // Requirements
    // ─────────────────────────────────────────────
    requirement def DrainExcessCSF {
        doc {
            The cerebral shunt system shall drain excess cerebrospinal fluid
            from the brain ventricles to a distal drainage site in the body
            when intracranial pressure exceeds a safe threshold.
        }
        subject shuntSystem : CerebralShuntSystem;
        objective {
            shuntSystem.transferredVolume > 0
        }
    }

    requirement def RegulatePressure {
        doc {
            The pressure-regulating valve shall open automatically when
            intracranial pressure exceeds the opening threshold and shall
            close when pressure falls below the closing threshold.
        }
        subject valve : PressureRegulatingValve;
        attribute openingThreshold : PressureValue = 1500 [Pa];
        attribute closingThreshold : PressureValue = 800 [Pa];
        objective {
            if valve.upstreamPressure > openingThreshold {
                valve.isOpen == true
            }
            if valve.upstreamPressure < closingThreshold {
                valve.isOpen == false
            }
        }
    }

    requirement def PreventBackflow {
        doc {
            The shunt shall prevent retrograde flow of fluid from the
            distal drainage site back into the ventricles.
        }
        subject shuntSystem : CerebralShuntSystem;
        objective {
            shuntSystem.backflowPrevented == true
        }
    }

    requirement def PassiveOperation {
        doc {
            The shunt shall operate continuously and passively without
            requiring external electrical power.
        }
        subject shuntSystem : CerebralShuntSystem;
        objective {
            shuntSystem.requiresExternalPower == false
        }
    }

    requirement def PermitSampling {
        doc {
            The optional CSF reservoir shall allow clinicians to sample
            fluid or directly measure intracranial pressure.
        }
        subject reservoir : CSFReservoir;
        objective {
            reservoir.sampleable == true
        }
    }

    // ─────────────────────────────────────────────
    // Component part definitions
    // ─────────────────────────────────────────────
    part def VentricularCatheter {
        doc {
            A thin, flexible tube placed into a brain ventricle to collect
            excess cerebrospinal fluid.
        }
        attribute length : LengthValue = 80 [mm];
        attribute innerDiameter : DiameterValue = 1.2 [mm];
        attribute outerDiameter : DiameterValue = 2.5 [mm];

        port proximalPort : CSFInPort;
        port distalPort : CSFOutPort;

        attribute collectedVolume : VolumeValue = 0 [mL];

        action def ConductCSF :> Action {
            in csfIn : CSF;
            out csfOut : CSF;
        }

        perform action conductCSF : ConductCSF {
            in csfIn = proximalPort.csf;
            out csfOut = distalPort.csf;
        }
    }

    part def CSFReservoir {
        doc {
            An optional chamber between the ventricular catheter and the
            pressure-regulating valve that permits fluid sampling and
            direct pressure measurement.
        }
        attribute capacity : VolumeValue = 0.5 [mL];
        attribute sampleable : Boolean = true;
        attribute currentVolume : VolumeValue = 0 [mL];

        port proximalPort : CSFInPort;
        port distalPort : CSFOutPort;
        port samplingPort : CSFOutPort;

        action def BufferCSF :> Action {
            in csfIn : CSF;
            out csfOut : CSF;
        }

        perform action bufferCSF : BufferCSF {
            in csfIn = proximalPort.csf;
            out csfOut = distalPort.csf;
        }
    }

    part def PressureRegulatingValve {
        doc {
            The core control element of the shunt. A one-way valve that
            opens when intracranial pressure exceeds a threshold and
            closes when pressure returns to a safe lower level.
        }
        attribute openingThreshold : PressureValue = 1500 [Pa];
        attribute closingThreshold : PressureValue = 800 [Pa];
        attribute isOpen : Boolean = false;
        attribute upstreamPressure : PressureValue = 0 [Pa];
        attribute downstreamPressure : PressureValue = 0 [Pa];
        attribute flowRate : FlowRateValue = 0 [mL/h];

        port proximalPort : CSFInPort;
        port distalPort : CSFOutPort;

        action def EvaluatePressure :> Action {
            in pressure : PressureValue;
            out openCommand : Boolean;
        }

        perform action evaluatePressure : EvaluatePressure {
            in pressure = upstreamPressure;
            out openCommand;
        }

        stateMachine valveState {
            attribute isOpen : Boolean;

            initial state Closed {
                entry {
                    isOpen := false;
                    flowRate := 0 [mL/h];
                }
                transition to Opened
                    when upstreamPressure > openingThreshold;
            }

            state Opened {
                entry {
                    isOpen := true;
                    flowRate := 20 [mL/h];
                }
                transition to Closed
                    when upstreamPressure < closingThreshold;
            }

            state Blocked {
                entry {
                    isOpen := false;
                    flowRate := 0 [mL/h];
                }
                transition to Closed
                    when upstreamPressure < closingThreshold
                    and obstructionCleared == true;
            }

            attribute obstructionCleared : Boolean = false;

            transition Closed to Blocked
                when obstructionDetected == true;
            transition Opened to Blocked
                when obstructionDetected == true;

            attribute obstructionDetected : Boolean = false;
        }
    }

    part def DistalCatheter {
        doc {
            A long tube that channels excess CSF from the valve to its
            final drainage site, such as the abdominal cavity.
        }
        attribute length : LengthValue = 400 [mm];
        attribute innerDiameter : DiameterValue = 1.3 [mm];
        attribute outerDiameter : DiameterValue = 2.6 [mm];

        port proximalPort : CSFInPort;
        port distalPort : CSFOutPort;

        attribute deliveredVolume : VolumeValue = 0 [mL];

        action def DeliverCSF :> Action {
            in csfIn : CSF;
            out csfOut : CSF;
        }

        perform action deliverCSF : DeliverCSF {
            in csfIn = proximalPort.csf;
            out csfOut = distalPort.csf;
        }
    }

    // ─────────────────────────────────────────────
    // System definition
    // ─────────────────────────────────────────────
    part def CerebralShuntSystem {
        doc {
            A cerebral shunt, a medical device surgically implanted to treat
            hydrocephalus by managing intracranial pressure. The system
            drains excess cerebrospinal fluid from the ventricles of the
            brain to another part of the body where it can be safely
            absorbed, such as the abdominal cavity.
        }

        satisfy DrainExcessCSF;
        satisfy PreventBackflow;
        satisfy PassiveOperation;

        attribute requiresExternalPower : Boolean = false;
        attribute backflowPrevented : Boolean = true;
        attribute transferredVolume : VolumeValue = 0 [mL];

        port ventricularPort : CSFInPort;
        port distalPort : CSFOutPort;

        part ventricularCatheter : VentricularCatheter {
            port proximalPort : CSFInPort;
            port distalPort : CSFOutPort;
        }

        part reservoir : CSFReservoir {
            port proximalPort : CSFInPort;
            port distalPort : CSFOutPort;
            port samplingPort : CSFOutPort;
        }

        part valve : PressureRegulatingValve {
            port proximalPort : CSFInPort;
            port distalPort : CSFOutPort;
        }

        part distalCatheter : DistalCatheter {
            port proximalPort : CSFInPort;
            port distalPort : CSFOutPort;
        }

        connection ventricularToReservoir connect ventricularCatheter.distalPort to reservoir.proximalPort {
            item csfFlow : CSF;
        }

        connection reservoirToValve connect reservoir.distalPort to valve.proximalPort {
            item csfFlow : CSF;
        }

        connection valveToDistal connect valve.distalPort to distalCatheter.proximalPort {
            item csfFlow : CSF;
        }

        connection externalInflow connect ventricularPort to ventricularCatheter.proximalPort {
            item csfFlow : CSF;
        }

        connection externalOutflow connect distalCatheter.distalPort to distalPort {
            item csfFlow : CSF;
        }

        // ─────────────────────────────────────────
        // System-level state machine
        // ─────────────────────────────────────────
        stateMachine shuntOperation {
            attribute systemPressure : PressureValue = 0 [Pa];
            attribute obstructionDetected : Boolean = false;

            initial state Normal {
                doc {
                    In the normal state, intracranial pressure is within
                    safe limits and the valve remains closed.
                }
                entry {
                    valve.isOpen := false;
                }
                transition to Draining
                    when systemPressure > valve.openingThreshold;
                transition to Blocked
                    when obstructionDetected == true;
            }

            state Draining {
                doc {
                    When intracranial pressure rises above the threshold,
                    the valve opens and CSF drains to the distal site.
                }
                entry {
                    valve.isOpen := true;
                }
                do {
                    transferredVolume := transferredVolume + 0.05 [mL];
                }
                transition to Normal
                    when systemPressure < valve.closingThreshold;
                transition to Blocked
                    when obstructionDetected == true;
            }

            state Blocked {
                doc {
                    A failure mode in which the shunt pathway is obstructed
                    and CSF cannot drain, requiring clinical intervention.
                }
                entry {
                    valve.isOpen := false;
                }
                transition to Normal
                    when obstructionDetected == false
                    and systemPressure < valve.closingThreshold;
            }
        }
    }

    // ─────────────────────────────────────────────
    // Verification use case
    // ─────────────────────────────────────────────
    verification VerifyPressureRegulation {
        subject testValve : PressureRegulatingValve;
        objective {
            testValve.upstreamPressure := 1600 [Pa];
            assert testValve.isOpen == true;
            testValve.upstreamPressure := 700 [Pa];
            assert testValve.isOpen == false;
        }
    }
}
