package MassSpringDamperSystem {

    import ScalarValues::*;

    // ===== Value Types with Units =====

    attribute def Length :> Real {
        attribute unit : String = "m";
    }

    attribute def MassValue :> Real {
        attribute unit : String = "kg";
    }

    attribute def Force :> Real {
        attribute unit : String = "N";
    }

    attribute def Velocity :> Real {
        attribute unit : String = "m/s";
    }

    attribute def Acceleration :> Real {
        attribute unit : String = "m/s^2";
    }

    attribute def Stiffness :> Real {
        attribute unit : String = "N/m";
    }

    attribute def DampingCoeff :> Real {
        attribute unit : String = "N*s/m";
    }

    attribute def TimeValue :> Real {
        attribute unit : String = "s";
    }

    attribute def Pressure :> Real {
        attribute unit : String = "Pa";
    }

    attribute def Energy :> Real {
        attribute unit : String = "J";
    }

    attribute def Frequency :> Real {
        attribute unit : String = "Hz";
    }

    attribute def Power :> Real {
        attribute unit : String = "W";
    }

    // ===== Item Types =====

    item def MechanicalEnergy {
        attribute potentialEnergy : Energy;
        attribute kineticEnergy : Energy;
        attribute totalEnergy : Energy;
        attribute dissipatedEnergy : Energy;
    }

    item def SpringStateInfo {
        attribute displacement : Length;
        attribute currentLength : Length;
        attribute restoringForce : Force;
        attribute storedEnergy : Energy;
        attribute stateName : String;
    }

    // ===== Port Definitions =====

    port def MechanicalPort {
        attribute position : Length;
        flow force : Force;
    }

    connection def MechanicalLink {
        end end1 : MechanicalPort;
        end end2 : MechanicalPort;
        attribute positionDifference : Length;
        attribute transmittedForce : Force;
    }

    // ===== Requirements =====

    requirement def OscillationRequirement {
        doc /* The system shall exhibit simple harmonic motion when the mass is displaced from equilibrium. */
        attribute maxDisplacement : Length;
        attribute expectedFrequency : Frequency;
        attribute period : TimeValue;
        constraint { expectedFrequency == (1 / (2 * 3.14159)) * sqrt(50 / 2) }
        constraint { period == 1 / expectedFrequency }
    }

    requirement def EnergyStorageRequirement {
        doc /* The spring shall store and release mechanical energy during oscillation cycles. */
        attribute maxStoredEnergy : Energy;
        constraint { maxStoredEnergy == 0.5 * 50 * 0.3 * 0.3 }
    }

    requirement def DampingRequirement {
        doc /* The system shall account for a damping factor representing energy loss, causing oscillations to gradually decrease over time. */
        attribute dampingRatio : Real;
        attribute dampingCoefficient : DampingCoeff;
        constraint { dampingRatio >= 0 and dampingRatio < 1 }
        constraint { dampingCoefficient == dampingRatio * 2 * sqrt(2 * 50) }
    }

    requirement def OperationalLimitRequirement {
        doc /* The spring shall not be compressed or extended beyond its operational limits without permanent damage. */
        attribute maxCompression : Length;
        attribute maxExtension : Length;
        constraint { maxCompression > 0 }
        constraint { maxExtension > 0 }
    }

    requirement def SimulationRequirement {
        doc /* The system behavior shall be simulated over a period of time to analyze the position and motion of the mass. */
        attribute simulationDuration : TimeValue;
        attribute timeStep : TimeValue;
        attribute outputPosition : Length;
        attribute outputVelocity : Velocity;
        constraint { timeStep < simulationDuration / 100 }
    }

    // ===== Part Definitions =====

    part def FixedMountingPoint {
        doc /* A stationary anchor in space to which one end of the spring is attached, providing a stable reference for the system's motion. */
        attribute anchorPosition : Length = 0;
        attribute isFixed : Boolean = true;
        port mechanicalInterface : MechanicalPort {
            attribute position = 0;
            flow force : Force;
        }
    }

    part def HelicalSpring {
        doc /* A helical spring connecting the mass to the fixed anchor, with intrinsic physical properties and operational limits. */

        // Intrinsic physical properties
        attribute springConstant : Stiffness;
        attribute naturalLength : Length;
        attribute elasticModulus : Pressure;
        attribute tensileStrength : Pressure;
        attribute wireDiameter : Length;
        attribute coilDiameter : Length;
        attribute numCoils : Integer;

        // Operational limits
        attribute maxCompression : Length;
        attribute maxExtension : Length;

        // Current state variables
        attribute currentLength : Length;
        attribute displacement : Length;
        attribute restoringForce : Force;
        attribute storedEnergy : Energy;
        attribute stress : Pressure;

        // Ports
        port anchorEnd : MechanicalPort;
        port massEnd : MechanicalPort;

        // State machine for spring states
        exhibit SpringStateBehavior;

        // Physics constraints
        constraint springForceLaw { restoringForce == -springConstant * displacement }
        constraint springEnergy { storedEnergy == 0.5 * springConstant * displacement * displacement }
        constraint springLength { currentLength == naturalLength + displacement }
        constraint operationalLimits { displacement >= -maxCompression and displacement <= maxExtension }
        constraint stressLimit { stress <= tensileStrength }
    }

    // ===== Spring State Machine =====

    state def SpringStateBehavior {
        doc /* Spring transitions through equilibrium, compressed, and extended states, generating restoring force in non-equilibrium states. */

        initial transition to Equilibrium;

        state Equilibrium {
            doc /* Spring is at its natural resting length with zero restoring force. */
            entry { restoringForce = 0; }
            transition to Compressed when displacement < 0;
            transition to Extended when displacement > 0;
        }

        state Compressed {
            doc /* Spring is compressed below natural length, actively generating restoring force pushing mass away from anchor. */
            do { restoringForce = -springConstant * displacement; }
            transition to Equilibrium when displacement == 0;
            transition to Extended when displacement > 0;
        }

        state Extended {
            doc /* Spring is extended beyond natural length, actively generating restoring force pulling mass toward anchor. */
            do { restoringForce = -springConstant * displacement; }
            transition to Equilibrium when displacement == 0;
            transition to Compressed when displacement < 0;
        }
    }

    part def Mass {
        doc /* A physical object with defined weight whose position, velocity, and acceleration are tracked as it oscillates. */

        attribute massValue : MassValue;
        attribute weight : Force;
        attribute gravity : Acceleration = 9.81;

        // Tracked motion states
        attribute position : Length;
        attribute velocity : Velocity;
        attribute acceleration : Acceleration;
        attribute kineticEnergy : Energy;

        // Port
        port connectionPort : MechanicalPort;

        // Physics constraints
        constraint weightDef { weight == massValue * gravity }
        constraint kineticEnergyDef { kineticEnergy == 0.5 * massValue * velocity * velocity }
        constraint newtonsSecondLaw { acceleration == connectionPort.force / massValue }
    }

    // ===== System Assembly =====

    part def MassSpringDamperSystem {
        doc /* A classic mass-spring-damper system demonstrating simple harmonic motion with energy storage and release. */

        // System parameters
        attribute dampingFactor : DampingCoeff = 0.4;
        attribute simulationTime : TimeValue = 0;
        attribute timeStep : TimeValue = 0.001;
        attribute equilibriumPosition : Length = 0;
        attribute totalEnergy : Energy = 0;
        attribute dissipatedEnergy : Energy = 0;
        attribute naturalFrequency : Frequency;
        attribute dampingRatio : Real;
        attribute dampedFrequency : Frequency;
        attribute period : TimeValue;

        // Energy tracking item
        item systemEnergy : MechanicalEnergy;

        // Sub-parts
        part anchor : FixedMountingPoint {
            attribute anchorPosition = 0;
        }

        part spring : HelicalSpring {
            attribute springConstant = 50;
            attribute naturalLength = 0.5;
            attribute elasticModulus = 200000000000;
            attribute tensileStrength = 500000000;
            attribute wireDiameter = 0.002;
            attribute coilDiameter = 0.02;
            attribute numCoils = 25;
            attribute maxCompression = 0.2;
            attribute maxExtension = 0.3;
            attribute currentLength = 0.5;
            attribute displacement = 0;
            attribute restoringForce = 0;
            attribute storedEnergy = 0;
            attribute stress = 0;
        }

        part mass : Mass {
            attribute massValue = 2;
            attribute weight = 19.62;
            attribute position = 0;
            attribute velocity = 0;
            attribute acceleration = 0;
            attribute kineticEnergy = 0;
        }

        // Connections
        connection: MechanicalLink anchorToSpring connect anchor.mechanicalInterface to spring.anchorEnd;
        connection: MechanicalLink springToMass connect spring.massEnd to mass.connectionPort;

        // System constraints
        constraint naturalFreqDef { naturalFrequency == (1 / (2 * 3.14159)) * sqrt(spring.springConstant / mass.massValue) }
        constraint dampingRatioDef { dampingRatio == dampingFactor / (2 * sqrt(mass.massValue * spring.springConstant)) }
        constraint dampedFreqDef { dampedFrequency == naturalFrequency * sqrt(1 - dampingRatio * dampingRatio) }
        constraint periodDef { period == 1 / naturalFrequency }
        constraint totalEnergyDef { totalEnergy == spring.storedEnergy + mass.kineticEnergy }
        constraint energyDissipationDef { dissipatedEnergy == dampingFactor * mass.velocity * mass.velocity * simulationTime }

        // Requirements satisfaction
        satisfy OscillationRequirement;
        satisfy EnergyStorageRequirement;
        satisfy DampingRequirement;
        satisfy OperationalLimitRequirement;
        satisfy SimulationRequirement;

        // Simulation behavior
        perform SimulateOscillation;
    }

    // ===== Simulation Action Definition =====

    action def SimulateOscillation {
        doc /* Simulates the mass-spring-damper system over a period of time to analyze position and motion of the mass. */

        in initialDisplacement : Length;
        in simulationDuration : TimeValue;
        in dt : TimeValue;

        // Local variables
        attribute currentNetForce : Force;
        attribute currentDampingForce : Force;
        attribute withinLimits : Boolean;

        // Initialize system state
        action initialize {
            doc /* Set initial conditions: displace mass from equilibrium, zero initial velocity. */
        }

        // Compute spring displacement from mass position
        action computeSpringDisplacement {
            doc /* Calculate spring displacement as difference between mass position and equilibrium position. */
        }

        // Compute spring restoring force using Hooke's law
        action computeSpringForce {
            doc /* Calculate spring restoring force: F = -k * x. */
        }

        // Compute damping force
        action computeDampingForce {
            doc /* Calculate damping force proportional to velocity: F = -c * v. */
        }

        // Compute net force on mass
        action computeNetForce {
            doc /* Sum spring restoring force and damping force to obtain net force on mass. */
        }

        // Update mass dynamics using Newton's second law
        action updateMassDynamics {
            doc /* Update mass acceleration (a = F/m), velocity (v = v + a*dt), and position (x = x + v*dt). */
        }

        // Compute system energies
        action computeEnergies {
            doc /* Compute spring potential energy (0.5*k*x^2), mass kinetic energy (0.5*m*v^2), and total energy. */
        }

        // Verify spring is within operational limits
        action verifyOperationalLimits {
            doc /* Check that spring displacement is within maximum compression and extension limits. */
        }

        // Update spring state machine
        action updateSpringState {
            doc /* Trigger spring state transitions based on current displacement value. */
        }

        // Record simulation output
        action recordOutput {
            doc /* Record current position, velocity, and energy values for analysis. */
        }

        // Single simulation step
        action step {
            doc /* Execute one time step: compute forces, update dynamics, compute energies, verify limits. */
            computeSpringDisplacement();
            computeSpringForce();
            computeDampingForce();
            computeNetForce();
            updateMassDynamics();
            computeEnergies();
            verifyOperationalLimits();
            updateSpringState();
            recordOutput();
        }

        // Main simulation loop
        action run {
            doc /* Run simulation from initial conditions for specified duration. */
            initialize();
            while (simulationTime < simulationDuration) {
                step();
                simulationTime = simulationTime + dt;
            }
        }
    }
}
