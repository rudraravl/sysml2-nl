package ElectromagneticRelayModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    // ========================================================
    // Value Types
    // ========================================================

    value type ControlVoltage :> ElectricPotential;
    value type ControlCurrent :> ElectricCurrent;
    value type LoadVoltage :> ElectricPotential;
    value type LoadCurrent :> ElectricCurrent;
    value type ContactPowerRating :> Power;
    value type MagneticFluxValue :> MagneticFlux;
    value type MagneticForceValue :> Force;
    value type SpringForceValue :> Force;
    value type ReactionForceValue :> Force;
    value type GapDistance :> Length;
    value value type SpringCompression :> Length;
    value type SwitchingDuration :> Duration;
    value type CoilResistance :> ElectricResistance;
    value type CoilInductance :> Inductance;
    value type ContactResistanceValue :> ElectricResistance;
    value type ArmatureMass :> Mass;
    value type SpringRate :> Real;

    // ========================================================
    // Enumerations
    // ========================================================

    enum def ContactPosition {
        OPEN;
        CLOSED;
    }

    // ========================================================
    // Item Definitions
    // ========================================================

    item def ControlSignal {
        doc "Low-power electrical signal applied to the relay coil terminals to energize or de-energize the relay.";
        attribute voltage : ControlVoltage;
        attribute current : ControlCurrent;
    }

    item def MagneticField {
        doc "Magnetic field produced by the energized coil, exerting attractive force on the armature.";
        attribute flux : MagneticFluxValue;
    }

    item def ArmatureMotion {
        doc "Mechanical displacement of the armature measured as the air gap between armature and coil pole face.";
        attribute gap : GapDistance;
    }

    item def SpringDisplacement {
        doc "Compression displacement of the return spring from its free length.";
        attribute compression : SpringCompression;
    }

    item def LoadCircuitFlow {
        doc "Current and voltage on the load circuit side flowing through the contact set.";
        attribute current : LoadCurrent;
        attribute voltage : LoadVoltage;
    }

    // ========================================================
    // Port Definitions
    // ========================================================

    port def ControlCircuitPort {
        doc "Port for the low-power control circuit interface.";
        in signal : ControlSignal;
    }

    port def MagneticEmissionPort {
        doc "Port through which the coil emits a magnetic field into the air gap.";
        out field : MagneticField;
    }

    port def MagneticReceptionPort {
        doc "Port through which the armature receives the magnetic field.";
        in field : MagneticField;
    }

    port def MechanicalDrivePort {
        doc "Port providing mechanical displacement to a driven component and receiving reaction force in return.";
        out displacement : ArmatureMotion;
        in reactionForce : ReactionForceValue;
    }

    port def MechanicalDrivenPort {
        doc "Port receiving mechanical displacement from a driving component and providing reaction force in return.";
        in displacement : ArmatureMotion;
        out reactionForce : ReactionForceValue;
    }

    port def LoadCircuitPort {
        doc "Port for the load circuit interface through the contact set.";
        in loadFlow : LoadCircuitFlow;
    }

    // ========================================================
    // Connection Definitions
    // ========================================================

    connection def ControlCircuitLink {
        doc "Electrical connection from the external control source to the coil.";
        end source : ControlCircuitPort;
        end target : ControlCircuitPort;
    }

    connection def MagneticFluxPath {
        doc "Magnetic coupling path from coil to armature across the air gap.";
        end source : MagneticEmissionPort;
        end target : MagneticReceptionPort;
    }

    connection def MechanicalActuationLink {
        doc "Mechanical linkage transmitting armature displacement and receiving reaction force.";
        end source : MechanicalDrivePort;
        end target : MechanicalDrivenPort;
    }

    connection def LoadCircuitLink {
        doc "Electrical connection from the contact set to the external load circuit.";
        end source : LoadCircuitPort;
        end target : LoadCircuitPort;
    }

    // ========================================================
    // Part Definitions — Components
    // ========================================================

    part def ElectromagneticCoil {
        doc "An electromagnetic coil that generates a magnetic field when a control voltage is applied across its terminals. The magnetic field attracts the armature to actuate the switch.";

        attribute resistance : CoilResistance;
        attribute inductance : CoilInductance;
        attribute ratedVoltage : ControlVoltage;
        attribute turnCount : Integer;

        port controlInput : ControlCircuitPort;
        port magneticOutput : MagneticEmissionPort;

        action def generateMagneticField {
            doc "Converts the applied electrical control signal into a magnetic field across the air gap.";
            in controlSignal : ControlSignal;
            out field : MagneticField;
        }
    }

    part def Armature {
        doc "A movable metallic lever that is attracted by the magnetic field produced by the coil. The armature physically transfers motion to the contact set and compresses the return spring.";

        attribute mass : ArmatureMass;
        attribute restGap : GapDistance;
        attribute actuatedGap : GapDistance;
        attribute currentGap : GapDistance;

        port magneticInput : MagneticReceptionPort;
        port mechanicalOutput : MechanicalDrivePort;

        action def moveTowardCoil {
            doc "Armature displacement toward the coil under magnetic attraction, overcoming the spring force.";
            in field : MagneticField;
            in springForce : SpringForceValue;
            out displacement : ArmatureMotion;
        }

        action def returnToRestPosition {
            doc "Armature returns to its rest position under the restoring force of the return spring.";
            in restoringForce : SpringForceValue;
            out displacement : ArmatureMotion;
        }
    }

    part def ReturnSpring {
        doc "A mechanical spring that holds the armature in its default normal position when the coil is not energized. Upon de-energization, it returns the armature to rest and restores contacts to their normal state.";

        attribute springRate : SpringRate;
        attribute freeLength : GapDistance;
        attribute maxCompression : SpringCompression;
        attribute currentCompression : SpringCompression;

        port mechanicalLink : MechanicalDrivenPort;

        action def exertRestoringForce {
            doc "Computes the restoring force based on the current compression of the spring.";
            in displacement : ArmatureMotion;
            out force : SpringForceValue;
        }
    }

    part def ContactSet {
        doc "The electrical switch terminals, typically made of a silver alloy, that are physically opened or closed by the armature movement. The contact set carries the load circuit current.";

        attribute maxPower : ContactPowerRating;
        attribute contactResistance : ContactResistanceValue;
        attribute normallyOpen : Boolean;
        attribute position : ContactPosition;

        port loadCircuit : LoadCircuitPort;
        port mechanicalInput : MechanicalDrivenPort;

        action def closeContacts {
            doc "Closes the contact pair, allowing current to flow through the load circuit.";
            in displacement : ArmatureMotion;
        }

        action def openContacts {
            doc "Opens the contact pair, interrupting current flow through the load circuit.";
            in displacement : ArmatureMotion;
        }
    }

    // ========================================================
    // Relay Assembly
    // ========================================================

    part def ElectromagneticRelay {
        doc "An electromagnetic relay: an electrically operated switch that uses a small electrical control signal to control a separate, often much higher-power electrical circuit while maintaining electrical isolation between the two circuits.";

        // Design specifications
        attribute activationVoltage : ControlVoltage = 9.0;
        attribute releaseVoltage : ControlVoltage = 1.0;
        attribute maxSwitchingTime : SwitchingDuration;
        attribute ratedContactPower : ContactPowerRating;
        attribute dielectricWithstand : LoadVoltage;
        attribute isNormallyOpen : Boolean = true;

        // Sub-parts with configured values
        part coil : ElectromagneticCoil {
            attribute resistance = 72 [Ohm];
            attribute inductance = 0.015 [H];
            attribute ratedVoltage = 12 [V];
            attribute turnCount = 8000;
        }

        part armature : Armature {
            attribute mass = 0.005 [kg];
            attribute restGap = 0.002 [m];
            attribute actuatedGap = 0.0 [m];
            attribute currentGap = 0.002 [m];
        }

        part returnSpring : ReturnSpring {
            attribute springRate = 150.0;
            attribute freeLength = 0.02 [m];
            attribute maxCompression = 0.005 [m];
            attribute currentCompression = 0.0 [m];
        }

        part contacts : ContactSet {
            attribute maxPower = 2000 [W];
            attribute contactResistance = 0.05 [Ohm];
            attribute normallyOpen = true;
            attribute position = ContactPosition::OPEN;
        }

        // External interface ports
        port controlTerminal : ControlCircuitPort;
        port loadTerminal : LoadCircuitPort;

        // Internal connections
        connection controlWiring : ControlCircuitLink
            connect controlTerminal to coil.controlInput;

        connection magneticCoupling : MagneticFluxPath
            connect coil.magneticOutput to armature.magneticInput;

        connection armatureToContactsLinkage : MechanicalActuationLink
            connect armature.mechanicalOutput to contacts.mechanicalInput;

        connection armatureToSpringLinkage : MechanicalActuationLink
            connect armature.mechanicalOutput to returnSpring.mechanicalLink;

        connection loadWiring : LoadCircuitLink
            connect contacts.loadCircuit to loadTerminal;

        // State machine behavior
        state machine relayStateMachine {
            state de-energized {
                doc "Rest state: coil unpowered, armature at rest gap, spring uncompressed, contacts in normal position.";
                entry {
                    contacts.position = ContactPosition::OPEN;
                    armature.currentGap = armature.restGap;
                    returnSpring.currentCompression = 0.0 [m];
                }
            }

            state energizing {
                doc "Transient state: control voltage applied, magnetic field building, armature accelerating toward coil, overcoming spring force.";
                entry {
                    // Armature begins moving toward coil under magnetic attraction
                }
            }

            state energized {
                doc "Active state: armature fully seated against coil pole, contacts switched to actuated position, load circuit connected.";
                entry {
                    contacts.position = ContactPosition::CLOSED;
                    armature.currentGap = armature.actuatedGap;
                }
            }

            state releasing {
                doc "Transient state: control voltage removed, magnetic field collapsing, return spring pushing armature back to rest.";
                entry {
                    // Spring restoring force drives armature back toward rest position
                }
            }

            transition de-energized to energizing
                when controlTerminal.signal.voltage >= activationVoltage;

            transition energizing to energized
                when armature.currentGap <= armature.actuatedGap;

            transition energized to releasing
                when controlTerminal.signal.voltage < releaseVoltage;

            transition releasing to de-energized
                when armature.currentGap >= armature.restGap;
        }
    }

    // ========================================================
    // Requirements
    // ========================================================

    requirement def RelayFunctionalSpecs {
        doc "Functional and performance requirements governing the design and operation of the electromagnetic relay.";

        requirement controlLoadIsolation {
            doc "The control circuit and the load circuit shall remain electrically isolated from each other at all times during relay operation. No galvanic connection shall exist between the coil circuit and the contact circuit.";
        }

        requirement activationThresholdSpec {
            doc "The relay shall transition from the de-energized state to the energizing state when the control voltage applied to the coil terminals reaches or exceeds the specified activation voltage.";
            attribute minActivationVoltage : ControlVoltage = 9.0;
        }

        requirement releaseThresholdSpec {
            doc "The relay shall transition from the energized state to the releasing state when the control voltage across the coil falls below the specified release voltage.";
            attribute maxReleaseVoltage : ControlVoltage = 1.0;
        }

        requirement switchingTimeSpec {
            doc "The relay shall complete a full switching cycle, defined as the transition from the de-energized state through energizing to the energized state and subsequently through releasing back to the de-energized state, within the specified maximum switching time.";
            attribute maxSwitchingTime : SwitchingDuration;
        }

        requirement contactPowerRatingSpec {
            doc "The contact set shall be rated to safely carry and interrupt the maximum specified load power without contact welding, arcing damage, or performance degradation exceeding the rated number of switching cycles.";
            attribute ratedPower : ContactPowerRating = 2000 [W];
        }

        requirement springReturnSpec {
            doc "Upon removal of the control voltage, the return spring shall exert sufficient restoring force to return the armature to its rest position, thereby restoring all contacts to their normal state without external assistance.";
        }

        requirement defaultContactStateSpec {
            doc "In the de-energized state, the relay contacts shall be in their normal position: normally open contacts shall be open and normally closed contacts shall be closed.";
        }

        requirement dielectricIsolationSpec {
            doc "The relay shall maintain a minimum dielectric withstand voltage between the control circuit and the load circuit to guarantee electrical isolation under specified operating conditions.";
            attribute minDielectricStrength : LoadVoltage;
        }
    }

    requirement relayDesignRequirements : RelayFunctionalSpecs {
        doc "Design requirements binding the electromagnetic relay implementation to its functional and performance specifications.";
        subject relay : ElectromagneticRelay;
    }
}
