package SiphonSystem {
    import ScalarValues::*;

    // ===== Value Types with Units =====
    value def Length = Real { unit "m"; }
    value def Volume = Real { unit "m^3"; }
    value def Pressure = Real { unit "Pa"; }
    value def VolumetricFlowRate = Real { unit "m^3/s"; }
    value def Diameter = Real { unit "m"; }
    value def Area = Real { unit "m^2"; }
    value def Velocity = Real { unit "m/s"; }
    value def Duration = Real { unit "s"; }
    value def Density = Real { unit "kg/m^3"; }
    value def Elevation = Real { unit "m"; }
    value def Mass = Real { unit "kg"; }

    // ===== Physical Constants =====
    attribute gravity: Real = 9.81 { unit "m/s^2"; }
    attribute atmosphericPressure: Pressure = 101325 [Pa];
    attribute waterDensity: Density = 1000 [kg/m^3];

    // ===== Item Definitions =====
    item def Fluid {
        attribute density: Density = 1000 [kg/m^3];
        attribute viscosity: Real = 0.001 { unit "Pa*s"; }
    }

    item def Water :> Fluid {
        attribute density: Density = 1000 [kg/m^3];
        attribute viscosity: Real = 0.001 { unit "Pa*s"; }
    }

    // ===== Port Definitions =====
    port def FluidPort {
        in item incomingFluid: Fluid;
        out item outgoingFluid: Fluid;
    }

    // ===== Part Definitions =====
    part def Reservoir {
        attribute capacity: Volume;
        attribute currentVolume: Volume;
        attribute surfaceElevation: Elevation;
        attribute baseElevation: Elevation;
        attribute maxElevation: Elevation;
        attribute crossSectionalArea: Area;

        port fluidPort: FluidPort;

        action def updateVolume(in deltaVolume: Volume) {
            // currentVolume = currentVolume + deltaVolume
            // constrained between 0 and capacity
        }

        action def computeSurfaceElevation() {
            // surfaceElevation = baseElevation + currentVolume / crossSectionalArea
        }
    }

    part def UpperReservoir :> Reservoir {
        attribute capacity: Volume = 10 [m^3];
        attribute currentVolume: Volume = 8 [m^3];
        attribute baseElevation: Elevation = 5 [m];
        attribute maxElevation: Elevation = 10 [m];
        attribute crossSectionalArea: Area = 2 [m^2];
        attribute surfaceElevation: Elevation = 9 [m];
    }

    part def LowerReservoir :> Reservoir {
        attribute capacity: Volume = 10 [m^3];
        attribute currentVolume: Volume = 2 [m^3];
        attribute baseElevation: Elevation = 0 [m];
        attribute maxElevation: Elevation = 5 [m];
        attribute crossSectionalArea: Area = 2 [m^2];
        attribute surfaceElevation: Elevation = 1 [m];
    }

    part def SiphonTube {
        attribute diameter: Diameter = 0.05 [m];
        attribute tubeLength: Length = 15 [m];
        attribute apexElevation: Elevation = 12 [m];
        attribute intakeElevation: Elevation = 6 [m];
        attribute dischargeElevation: Elevation = 1 [m];
        attribute crossSectionalArea: Area = 0.001963 [m^2];
        attribute isPrimed: Boolean = false;
        attribute isFull: Boolean = false;
        attribute containsAir: Boolean = true;

        port intakePort: FluidPort;
        port dischargePort: FluidPort;

        action def computeCrossSectionalArea() {
            // crossSectionalArea = (pi / 4) * diameter^2
        }
    }

    // ===== Connection Definitions =====
    connection def FluidConnection {
        end source: FluidPort;
        end target: FluidPort;
        item transferredFluid: Fluid;
    }

    // ===== Action Definitions =====
    action def CalculateFlowRate {
        in heightDifference: Length;
        in tubeDiameter: Diameter;
        in tubeArea: Area;
        out flowRate: VolumetricFlowRate;

        // Torricelli's theorem for siphon flow:
        // v = sqrt(2 * g * h)
        // Q = A * v = A * sqrt(2 * g * h)
        // where g = 9.81 m/s^2, h = height difference, A = cross-sectional area
    }

    action def PrimeSiphon {
        in tube: SiphonTube;
        in primingFluid: Fluid;
        out success: Boolean;

        // Completely fill the connecting tube with fluid
        // Remove all air from the tube
        // Set tube.isPrimed = true
        // Set tube.containsAir = false
        // Set tube.isFull = true
    }

    action def CheckSiphonConditions {
        in upperSurfaceElevation: Elevation;
        in tubeIntakeElevation: Elevation;
        in heightDifference: Length;
        out conditionsMet: Boolean;

        // conditionsMet = (upperSurfaceElevation > tubeIntakeElevation)
        //                 and (heightDifference > 0)
        // If upper fluid level drops below tube intake, siphon breaks
        // If height difference becomes zero, no pressure differential
    }

    action def UpdateReservoirLevels {
        in flowRate: VolumetricFlowRate;
        in deltaTime: Duration;
        out upperVolumeChange: Volume;
        out lowerVolumeChange: Volume;

        // upperVolumeChange = -flowRate * deltaTime
        // lowerVolumeChange = +flowRate * deltaTime
        // Upper reservoir level decreases
        // Lower reservoir level rises
    }

    action def InitiateFlow {
        in heightDifference: Length;
        in tubeDiameter: Diameter;
        out initialFlowRate: VolumetricFlowRate;

        // Pressure difference from column of fluid in descending leg
        // initiates continuous gravity-driven flow
    }

    // ===== State Machine Definition =====
    state def SiphonOperation {
        attribute isPrimed: Boolean = false;
        attribute currentFlowRate: VolumetricFlowRate = 0 [m^3/s];
        attribute heightDifference: Length;
        attribute primingCommandReceived: Boolean = false;
        attribute primingSuccessful: Boolean = false;
        attribute primingFailed: Boolean = false;
        attribute flowStartCommand: Boolean = false;
        attribute stopConditionMet: Boolean = false;
        attribute manualStopCommand: Boolean = false;
        attribute resetCommand: Boolean = false;
        attribute upperLevelBelowIntake: Boolean = false;
        attribute heightDifferenceZero: Boolean = false;

        state idle {
            entry action { /* System idle, waiting for priming command */ }
            do action { /* Monitor for priming command or manual start */ }
        }

        state priming {
            entry action { /* Begin filling tube with fluid to remove all air */ }
            do action {
                /* Completely fill the connecting tube with fluid */
                /* Ensure all air is expelled from the tube */
                /* Verify tube is full and primed */
            }
            exit action { /* Set isPrimed flag based on priming result */ }
        }

        state primed {
            entry action { /* Tube filled with fluid, ready to initiate flow */ }
            do action { /* Wait for flow start command */ }
        }

        state flowing {
            entry action {
                /* Pressure difference from fluid column in descending leg */
                /* initiates continuous gravity-driven flow */
            }
            do action {
                /* Continuously calculate flow rate based on height difference */
                /* and tube diameter using Torricelli's theorem */
                /* Transfer fluid from upper reservoir to lower reservoir */
                /* Decrease upper reservoir level, increase lower reservoir level */
                /* Check if upper level drops below tube intake */
                /* Check if height difference becomes zero */
            }
            exit action { /* Cease flow, record final state */ }
        }

        state stopped {
            entry action { /* Siphon stopped, either automatically or manually */ }
            do action { /* Await reset command */ }
        }

        transition idle_to_priming
            first idle then priming
            when primingCommandReceived;

        transition priming_to_primed
            first priming then primed
            when primingSuccessful [isPrimed == true];

        transition priming_to_idle
            first priming then idle
            when primingFailed [isPrimed == false];

        transition primed_to_flowing
            first primed then flowing
            when flowStartCommand;

        transition flowing_to_stopped_auto_intake
            first flowing then stopped
            when upperLevelBelowIntake;

        transition flowing_to_stopped_auto_height
            first flowing then stopped
            when heightDifferenceZero;

        transition flowing_to_stopped_manual
            first flowing then stopped
            when manualStopCommand;

        transition stopped_to_idle
            first stopped then idle
            when resetCommand;
    }

    // ===== Main System Part =====
    part def SiphonSystem {
        part upperReservoir: UpperReservoir {
            attribute capacity: Volume = 10 [m^3];
            attribute currentVolume: Volume = 8 [m^3];
            attribute baseElevation: Elevation = 5 [m];
            attribute maxElevation: Elevation = 10 [m];
            attribute crossSectionalArea: Area = 2 [m^2];
            attribute surfaceElevation: Elevation = 9 [m];
        }

        part lowerReservoir: LowerReservoir {
            attribute capacity: Volume = 10 [m^3];
            attribute currentVolume: Volume = 2 [m^3];
            attribute baseElevation: Elevation = 0 [m];
            attribute maxElevation: Elevation = 5 [m];
            attribute crossSectionalArea: Area = 2 [m^2];
            attribute surfaceElevation: Elevation = 1 [m];
        }

        part tube: SiphonTube {
            attribute diameter: Diameter = 0.05 [m];
            attribute tubeLength: Length = 15 [m];
            attribute apexElevation: Elevation = 12 [m];
            attribute intakeElevation: Elevation = 6 [m];
            attribute dischargeElevation: Elevation = 1 [m];
            attribute crossSectionalArea: Area = 0.001963 [m^2];
        }

        connection connUpperToTube: FluidConnection
            connect upperReservoir.fluidPort to tube.intakePort;

        connection connTubeToLower: FluidConnection
            connect tube.dischargePort to lowerReservoir.fluidPort;

        attribute heightDifference: Length = 8 [m];
        attribute currentFlowRate: VolumetricFlowRate = 0 [m^3/s];
        attribute systemActive: Boolean = false;
        attribute totalTransferredVolume: Volume = 0 [m^3];
        attribute operatingTime: Duration = 0 [s];

        exhibit state operation: SiphonOperation;

        action flowCalculation: CalculateFlowRate {
            in heightDifference = heightDifference;
            in tubeDiameter = tube.diameter;
            in tubeArea = tube.crossSectionalArea;
            out flowRate = currentFlowRate;
        }

        action conditionCheck: CheckSiphonConditions {
            in upperSurfaceElevation = upperReservoir.surfaceElevation;
            in tubeIntakeElevation = tube.intakeElevation;
            in heightDifference = heightDifference;
        }

        action levelUpdate: UpdateReservoirLevels {
            in flowRate = currentFlowRate;
        }
    }

    // ===== Requirement Definitions =====
    requirement def SiphonSystemRequirements {
        subject siphonSystem: SiphonSystem;

        requirement GravityDrivenTransfer {
            doc /* The siphon shall transfer fluid from the upper reservoir to the lower reservoir using only gravitational potential energy and atmospheric pressure, without any mechanical pumps. */;
        }

        requirement PrimingCapability {
            doc /* The system shall support a priming operation that completely fills the connecting tube with fluid to remove all air before flow begins. */;
        }

        requirement ContinuousFlowInitiation {
            doc /* Once successfully primed, the pressure difference created by the column of fluid in the tube descending leg shall initiate a continuous gravity-driven flow. */;
        }

        requirement FlowRateCalculation {
            doc /* While flowing, the system shall continuously calculate the flow rate based on the height difference between the two reservoirs and the tube diameter. */;
        }

        requirement ReservoirLevelMonitoring {
            doc /* The system shall monitor and update the fluid level in the upper reservoir, which decreases, and the lower reservoir, which rises, as fluid is transferred. */;
        }

        requirement AutomaticStopOnIntakeExposure {
            doc /* The system shall automatically stop the siphon if the fluid level in the upper reservoir drops below the tube intake. */;
        }

        requirement AutomaticStopOnZeroHeightDifference {
            doc /* The system shall automatically stop the siphon if the height difference between the two reservoirs becomes zero. */;
        }

        requirement ManualStopCapability {
            doc /* The system shall support manual stopping of the siphon transfer at any time during operation. */;
        }

        requirement TubeGeometry {
            doc /* The connecting tube shall be positioned so that it arches up and over the edge of the upper reservoir, with its highest point (apex) above the fluid surface, before descending into the lower reservoir. */;
        }

        requirement IdleInitialState {
            doc /* The system shall start in an idle state before any priming or transfer operation begins. */;
        }

        requirement PrimedState {
            doc /* After successful priming, the system shall enter a primed state indicating the tube is full of fluid and ready for flow. */;
        }
    }

    // ===== Satisfaction Relationships =====
    satisfy SiphonSystemRequirements::GravityDrivenTransfer by SiphonSystem;
    satisfy SiphonSystemRequirements::PrimingCapability by SiphonSystem;
    satisfy SiphonSystemRequirements::ContinuousFlowInitiation by SiphonSystem;
    satisfy SiphonSystemRequirements::FlowRateCalculation by SiphonSystem;
    satisfy SiphonSystemRequirements::ReservoirLevelMonitoring by SiphonSystem;
    satisfy SiphonSystemRequirements::AutomaticStopOnIntakeExposure by SiphonSystem;
    satisfy SiphonSystemRequirements::AutomaticStopOnZeroHeightDifference by SiphonSystem;
    satisfy SiphonSystemRequirements::ManualStopCapability by SiphonSystem;
    satisfy SiphonSystemRequirements::TubeGeometry by SiphonSystem::tube;
    satisfy SiphonSystemRequirements::IdleInitialState by SiphonSystem;
    satisfy SiphonSystemRequirements::PrimedState by SiphonSystem;
}
