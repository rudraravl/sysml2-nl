package ContinuousTrackSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    value def Force :> Real { unit = "N"; }
    value def Pressure :> Real { unit = "Pa"; }
    value def Length :> Real { unit = "m"; }
    value def Mass :> Real { unit = "kg"; }
    value def Velocity :> Real { unit = "m/s"; }
    value def Torque :> Real { unit = "N*m"; }
    value def WearRate :> Real { unit = "1/s"; }
    value def Tension :> Force;
    value def Dimensionless :> Real;

    // ===== Item Types =====
    item def GroundContact;
    item def PowerInput;
    item def ServiceSignal;
    item def TerrainData {
        attribute coefficientOfFriction : Dimensionless;
        attribute surfaceRoughness : Dimensionless;
    }

    // ===== Enumerations =====
    enum def OperatingState {
        parked;
        tensioned;
        driving;
        braking;
        maintenance;
    }

    enum def TerrainType {
        mud;
        sand;
        uneven;
        hardpan;
    }

    // ===== Interfaces =====
    port def PowerPort {
        out torque : Torque;
        out rotationalSpeed : Velocity;
    }

    port def TensionFeedbackPort {
        out measuredTension : Tension;
    }

    port def ServicePort {
        out serviceRequest : ServiceSignal;
    }

    // ===== Requirements =====
    requirement def PropulsionRequirement {
        doc /* The system shall provide propulsion by transmitting engine torque to the track. */
        subject trackSystem : ContinuousTrackSystem;
        objective {
            /* Transmit torque from sprocket to track chain */
        }
    }

    requirement def WeightDistributionRequirement {
        doc /* The system shall distribute vehicle weight evenly across all road wheels. */
        subject trackSystem : ContinuousTrackSystem;
        objective {
            /* Each road wheel carries no more than 1/8 of total weight plus 10% tolerance */
        }
    }

    requirement def TensionControlRequirement {
        doc /* The system shall maintain track tension within an optimal range. */
        subject trackSystem : ContinuousTrackSystem;
        attribute minTension : Tension = 15000 [N];
        attribute maxTension : Tension = 25000 [N];
        objective {
            /* Measured tension shall remain between minTension and maxTension during operation */
        }
    }

    requirement def WearMonitoringRequirement {
        doc /* The system shall evaluate track wear rate and signal service when excessive. */
        subject trackSystem : ContinuousTrackSystem;
        attribute wearThreshold : Dimensionless = 0.8;
        objective {
            /* Signal service when cumulative wear exceeds wearThreshold */
        }
    }

    // ===== Part Definitions =====
    part def TrackFrame {
        doc /* High-strength steel chassis for all track components. */
        attribute material : String = "High-Strength Steel";
        attribute length : Length = 4.2 [m];
        attribute width : Length = 0.6 [m];
        attribute mass : Mass = 1200 [kg];
    }

    part def DriveSprocket {
        doc /* Toothed drive wheel receiving engine power. */
        attribute teethCount : Integer = 12;
        attribute pitchDiameter : Length = 0.45 [m];
        port powerIn : PowerPort;
        port torqueOut : PowerPort;
    }

    part def IdlerWheel {
        doc /* Unpowered guide wheel used for tension adjustment. */
        attribute diameter : Length = 0.5 [m];
        attribute position : String; // "front" or "rear"
        port tensionAdjust : TensionFeedbackPort;
    }

    part def RoadWheel {
        doc /* Load-bearing wheel running along inside of track. */
        attribute diameter : Length = 0.35 [m];
        attribute index : Integer;
        part suspension : Suspension;
        port loadPort {
            out loadForce : Force;
        }
    }

    part def Suspension {
        doc /* Independent suspension for each road wheel. */
        attribute springRate : Force = 250000 [N/m];
        attribute dampingCoeff : Real = 8000;
        attribute deflection : Length = 0 [m];
    }

    part def TrackLink {
        doc /* Individual metal track link. */
        attribute pitch : Length = 0.15 [m];
        attribute mass : Mass = 8 [kg];
        part pad : TrackPad;
    }

    part def TrackPad {
        doc /* Outer ground-contact pad fitted to each link. */
        attribute width : Length = 0.5 [m];
        attribute treadDepth : Length = 0.03 [m];
        attribute wearFraction : Dimensionless = 0;
    }

    part def TrackChain {
        doc /* Heavy chain composed of 120 individual links. */
        attribute linkCount : Integer = 120;
        attribute totalMass : Mass = 960 [kg];
        part links : TrackLink[120];
        port tensionPort : TensionFeedbackPort;
    }

    part def TensioningMechanism {
        doc /* Dedicated mechanism that actively monitors and adjusts track tension. */
        attribute targetTension : Tension = 20000 [N];
        attribute tolerance : Tension = 2000 [N];
        port feedback : TensionFeedbackPort;
        port serviceOut : ServicePort;
    }

    // ===== Top-level System =====
    part def ContinuousTrackSystem {
        doc /* Complete continuous track system for heavy vehicles. */

        satisfy PropulsionRequirement;
        satisfy WeightDistributionRequirement;
        satisfy TensionControlRequirement;
        satisfy WearMonitoringRequirement;

        attribute vehicleWeight : Force = 400000 [N];
        attribute groundContactArea : Pressure = 0.0 [Pa];
        attribute currentSpeed : Velocity = 0 [m/s];
        attribute currentState : OperatingState = OperatingState::parked;
        attribute cumulativeWear : Dimensionless = 0;
        attribute overloadDetected : Boolean = false;

        part frame : TrackFrame;
        part driveSprocket : DriveSprocket;
        part frontIdler : IdlerWheel { attribute position = "front"; }
        part rearIdler : IdlerWheel { attribute position = "rear"; }
        part roadWheels : RoadWheel[8] {
            for i in 1..8 {
                RoadWheel { attribute index = i; }
            }
        }
        part trackChain : TrackChain;
        part tensioner : TensioningMechanism;

        // Connections
        connection drivePower : PowerInput connect driveSprocket.powerIn to driveSprocket.torqueOut;
        connection tensionFeedback : Tension connect trackChain.tensionPort to tensioner.feedback;
        connection serviceLink : ServiceSignal connect tensioner.serviceOut to self.servicePort;

        port servicePort : ServicePort;

        // ===== State Machine =====
        behavior stateMachine :> StateMachine {
            state parked {
                entry action {
                    currentSpeed = 0 [m/s];
                    currentState = OperatingState::parked;
                }
            }
            state tensioned {
                entry action {
                    currentState = OperatingState::tensioned;
                }
                do action {
                    /* Verify tension within range */
                    if (trackChain.tensionPort.measuredTension < tensioner.targetTension - tensioner.tolerance) {
                        tensioner.targetTension := tensioner.targetTension + 500 [N];
                    }
                }
            }
            state driving {
                entry action {
                    currentState = OperatingState::driving;
                }
                do action calculateTraction {
                    /* Calculate traction based on weight and ground contact */
                    attribute tractionForce : Force;
                    tractionForce = vehicleWeight * 0.6;
                    /* Distribute load evenly across road wheels */
                    for wheel in roadWheels {
                        wheel.loadPort.loadForce = vehicleWeight / 8;
                    }
                }
                do action evaluateWear {
                    /* Evaluate wear based on speed and terrain */
                    attribute wearIncrement : WearRate;
                    wearIncrement = currentSpeed * 0.0001 [1/s];
                    cumulativeWear = cumulativeWear + wearIncrement;
                    if (cumulativeWear > 0.8) {
                        overloadDetected = true;
                        servicePort.serviceRequest = ServiceSignal{};
                    }
                }
            }
            state braking {
                entry action {
                    currentState = OperatingState::braking;
                }
                do action {
                    currentSpeed = currentSpeed * 0.9;
                    if (currentSpeed < 0.1 [m/s]) {
                        currentSpeed = 0 [m/s];
                    }
                }
            }
            state maintenance {
                entry action {
                    currentState = OperatingState::maintenance;
                    currentSpeed = 0 [m/s];
                }
            }

            transition parked->tensioned {
                when (trackChain.tensionPort.measuredTension >= tensioner.targetTension - tensioner.tolerance)
            }
            transition tensioned->driving {
                when (driveSprocket.powerIn.torque > 0 [N*m])
            }
            transition driving->braking {
                when (driveSprocket.powerIn.torque < 0 [N*m])
            }
            transition braking->driving {
                when (driveSprocket.powerIn.torque > 0 [N*m])
            }
            transition braking->parked {
                when (currentSpeed == 0 [m/s])
            }
            transition any->maintenance {
                when (cumulativeWear > 0.8 or overloadDetected)
            }
            transition maintenance->parked {
                when (cumulativeWear < 0.1)
            }
        }
    }
}
