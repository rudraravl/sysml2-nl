package N95RespiratorModel {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Units and Value Types =====
    package Units {
        unit um : LengthUnit { identity 'micrometer'; }
        unit percent : Real { identity '%'; }
        unit newton : ForceUnit { identity 'N'; }
        unit pascal : PressureUnit { identity 'Pa'; }
        unit literPerMin : Real { identity 'L/min'; }
        unit count : Real { identity 'count'; }
    }

    package ValueTypes {
        import Units::*;
        value def ParticleSize :> Real { unit um; }
        value def FiltrationEfficiency :> Real { unit percent; }
        value def StrapTension :> Real { unit newton; }
        value def BreathingResistance :> Real { unit pascal; }
        value def FlowRate :> Real { unit literPerMin; }
        value def ParticleConcentration :> Real { unit count; }
    }

    // ===== Items =====
    package Items {
        import ValueTypes::*;

        item def Particle {
            attribute diameter : ParticleSize;
            attribute hazardous : Boolean;
        }

        item def Air {
            attribute temperature : Real;
            attribute humidity : Real;
        }

        item def ContaminatedAir :> Air {
            ref part particles : Particle[*];
            attribute particleCount : ParticleConcentration;
        }

        item def FilteredAir :> Air {
            ref part particles : Particle[0..*];
        }

        item def ExhaledAir :> Air {
            attribute moisture : Real;
            attribute heat : Real;
        }
    }

    // ===== Requirements =====
    package Requirements {
        import ValueTypes::*;
        import Items::*;

        requirement def FiltrationRequirement {
            doc /* The respirator must filter at least 95% of particles 0.3 micrometers and larger. */
            attribute minEfficiency : FiltrationEfficiency = 95.0;
            attribute targetParticleSize : ParticleSize = 0.3;
            subject filter : ContaminatedAir;
            assert {
                filter.particles->select(p | p.diameter >= targetParticleSize)->size() * 100.0 / filter.particles->size() >= minEfficiency
            }
        }

        requirement def BreathingResistanceRequirement {
            doc /* The respirator must maintain low resistance to inhalation and exhalation. */
            attribute maxInhalationResistance : BreathingResistance = 343.0;
            attribute maxExhalationResistance : BreathingResistance = 245.0;
            attribute nominalFlow : FlowRate = 85.0;
        }

        requirement def FacialSealRequirement {
            doc /* The respirator must form a tight seal against the wearer's face. */
            attribute minStrapTension : StrapTension = 2.5;
            attribute maxStrapTension : StrapTension = 8.0;
        }

        requirement def ExhalationValveRequirement {
            doc /* The exhalation valve must open during exhalation and close during inhalation. */
        }
    }

    // ===== Filter Layers =====
    package FilterMedia {
        import Items::*;
        import ValueTypes::*;

        port def AirInPort {
            in air : ContaminatedAir;
        }

        port def AirOutPort {
            out air : FilteredAir;
        }

        port def IntermediateAirPort {
            in inAir : Air;
            out outAir : Air;
        }

        part def FilterLayer {
            attribute efficiency : FiltrationEfficiency;
            attribute resistance : BreathingResistance;
            port in airIn : AirInPort;
            port out airOut : AirOutPort;
            flow airFlow : Air from airIn.air to airOut.air;
        }

        part def MechanicalFilterLayer :> FilterLayer {
            doc /* Provides structural support and pre-filters larger particles. */
            attribute minParticleCapture : ParticleSize = 10.0;
        }

        part def ElectrostaticFilterLayer :> FilterLayer {
            doc /* Core filtration layer using electrostatic charge to capture fine particles. */
            attribute charge : Real;
            attribute minEfficiency : FiltrationEfficiency = 95.0;
            attribute minParticleCapture : ParticleSize = 0.3;
        }

        part def MultiLayerFiltrationSystem {
            part outerLayer : MechanicalFilterLayer {
                attribute efficiency = 60.0;
                attribute resistance = 30.0;
            }
            part electrostaticLayer : ElectrostaticFilterLayer {
                attribute efficiency = 95.0;
                attribute resistance = 50.0;
                attribute charge = 1.2e-6;
            }
            part innerLayer : MechanicalFilterLayer {
                attribute efficiency = 40.0;
                attribute resistance = 25.0;
            }

            port in systemAirIn : AirInPort;
            port out systemAirOut : AirOutPort;

            connection outerToElectrostatic connect outerLayer.airOut to electrostaticLayer.airIn;
            connection electrostaticToInner connect electrostaticLayer.airOut to innerLayer.airIn;
            connection inletConnect connect systemAirIn to outerLayer.airIn;
            connection outletConnect connect innerLayer.airOut to systemAirOut;

            flow filteredAirFlow : ContaminatedAir from systemAirIn.air to systemAirOut.air;
        }
    }

    // ===== Facial Seal Assembly =====
    package FacialSeal {
        import ValueTypes::*;

        part def FacialSealSection {
            attribute contactArea : Real;
            attribute sealPressure : Real;
        }

        part def NoseSection :> FacialSealSection {
            attribute contactArea = 12.0;
            attribute sealPressure = 1.5;
        }

        part def CheekSection :> FacialSealSection {
            attribute contactArea = 20.0;
            attribute sealPressure = 1.2;
        }

        part def ChinSection :> FacialSealSection {
            attribute contactArea = 15.0;
            attribute sealPressure = 1.3;
        }

        part def NoseClip {
            doc /* Adjustable metal nose clip to conform mask to facial contours. */
            attribute material : String = "aluminum";
            attribute adjustable : Boolean = true;
            attribute appliedForce : Real;
        }

        part def FacialSealAssembly {
            part noseSection : NoseSection;
            part cheekSection : CheekSection;
            part chinSection : ChinSection;
            part noseClip : NoseClip;

            attribute sealIntegrity : Boolean;
        }
    }

    // ===== Retention Strap System =====
    package RetentionSystem {
        import ValueTypes::*;

        part def ElasticHeadband {
            attribute elasticity : Real;
            attribute length : Real;
            attribute appliedTension : StrapTension;
        }

        part def RetentionStrapSystem {
            part upperBand : ElasticHeadband {
                attribute elasticity = 0.8;
                attribute length = 25.0;
                attribute appliedTension = 3.5;
            }
            part lowerBand : ElasticHeadband {
                attribute elasticity = 0.8;
                attribute length = 25.0;
                attribute appliedTension = 3.5;
            }
            attribute totalTension : StrapTension = 7.0;
        }
    }

    // ===== Exhalation Valve =====
    package ExhalationValve {
        import Items::*;

        port def InhalePort {
            in air : ContaminatedAir;
        }

        port def ExhalePort {
            out air : ExhaledAir;
        }

        enum ValveState { closed; open; }

        part def ExhalationValvePart {
            doc /* One-way valve that opens on exhalation and closes on inhalation. */
            attribute state : ValveState = ValveState::closed;
            port in inhalePort : InhalePort;
            port out exhalePort : ExhalePort;

            state machine valveBehavior {
                entry; then closed;

                state closed {
                    doc /* Valve closed during inhalation; all air passes through filter media. */
                    entry action { state = ValveState::closed; }
                }

                state open {
                    doc /* Valve open during exhalation; reduces heat and moisture buildup. */
                    entry action { state = ValveState::open; }
                }

                transition closedToOpen
                    first closed
                    accept ExhalationEvent
                    then open;

                transition openToClosed
                    first open
                    accept InhalationEvent
                    then closed;
            }

            occurrence def ExhalationEvent;
            occurrence def InhalationEvent;
        }
    }

    // ===== N95 Respirator Assembly =====
    package RespiratorAssembly {
        import FilterMedia::*;
        import FacialSeal::*;
        import RetentionSystem::*;
        import ExhalationValve::*;
        import Items::*;
        import ValueTypes::*;
        import Requirements::*;

        part def N95Respirator {
            doc /* Personal protective device filtering hazardous airborne particles before inhalation. */

            part filtrationSystem : MultiLayerFiltrationSystem;
            part facialSeal : FacialSealAssembly;
            part retentionSystem : RetentionStrapSystem;
            part exhalationValve : ExhalationValvePart;

            port in ambientAirIn : AirInPort;
            port out userAirOut : AirOutPort;
            port out exhaledAirOut : ExhalePort;

            connection ambientToFiltration connect ambientAirIn to filtrationSystem.systemAirIn;
            connection filtrationToUser connect filtrationSystem.systemAirOut to userAirOut;

            attribute overallFiltrationEfficiency : FiltrationEfficiency = 95.0;
            attribute inhalationResistance : BreathingResistance = 105.0;
            attribute exhalationResistance : BreathingResistance = 60.0;
            attribute nominalFlowRate : FlowRate = 85.0;

            satisfy FiltrationRequirement by filtrationSystem.electrostaticLayer;
            satisfy BreathingResistanceRequirement by N95Respirator::inhalationResistance, N95Respirator::exhalationResistance;
            satisfy FacialSealRequirement by retentionSystem;
            satisfy ExhalationValveRequirement by exhalationValve;

            state machine usageState {
                entry; then idle;

                state idle {
                    doc /* Respirator at rest, no airflow. */
                }

                state inhaling {
                    doc /* User inhaling; exhalation valve closed; air passes through filter media. */
                    entry action { exhalationValve.valveBehavior.send(ExhalationValvePart::InhalationEvent); }
                }

                state exhaling {
                    doc /* User exhaling; exhalation valve opens to release warm moist air. */
                    entry action { exhalationValve.valveBehavior.send(ExhalationValvePart::ExhalationEvent); }
                }

                transition startInhale
                    first idle
                    accept Occurrence
                    then inhaling;

                transition switchToExhale
                    first inhaling
                    accept Occurrence
                    then exhaling;

                transition returnToIdle
                    first exhaling
                    accept Occurrence
                    then idle;
            }
        }
    }
}
