package 'N95 Respirator Model' {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    attribute def FiltrationEfficiency :> Real;
    attribute def ParticleSize :> Real;
    attribute def BreathingResistance :> Real;
    attribute def TensionForce :> Real;

    item def Air;
    item def Particle {
        attribute size : ParticleSize;
    }

    port def AirPort;

    connection def AirFlow {
        end : AirPort;
        end : AirPort;
    }

    part def MechanicalFilterLayer {
        attribute structuralSupport : Boolean;
        attribute poreSize : ParticleSize;
        port airIn : AirPort;
        port airOut : AirPort;
    }

    part def ElectrostaticFilterLayer {
        attribute captureEfficiency : FiltrationEfficiency;
        attribute minParticleSize : ParticleSize;
        attribute chargeDensity : Real;
        port airIn : AirPort;
        port airOut : AirPort;
    }

    part def FiltrationMedia {
        part outerLayer : MechanicalFilterLayer;
        part electrostaticLayer : ElectrostaticFilterLayer;
        part innerLayer : MechanicalFilterLayer;
        port airIn : AirPort;
        port airOut : AirPort;

        connection c1 : AirFlow connect airIn to outerLayer.airIn;
        connection c2 : AirFlow connect outerLayer.airOut to electrostaticLayer.airIn;
        connection c3 : AirFlow connect electrostaticLayer.airOut to innerLayer.airIn;
        connection c4 : AirFlow connect innerLayer.airOut to airOut;

        action filterAir {
            action passThroughOuter;
            then action passThroughElectrostatic;
            then action passThroughInner;
        }
    }

    part def NoseSeal;
    part def CheekSeal;
    part def ChinSeal;

    part def NoseClip {
        attribute material : String;
        action adjustClip;
    }

    part def FacialSeal {
        part noseSection : NoseSeal;
        part leftCheekSection : CheekSeal;
        part rightCheekSection : CheekSeal;
        part chinSection : ChinSeal;
        part noseClip : NoseClip;
        action conformToFace;
    }

    part def ElasticHeadband {
        attribute elasticity : Real;
        attribute tension : TensionForce;
    }

    part def RetentionStrapSystem {
        part upperStrap : ElasticHeadband;
        part lowerStrap : ElasticHeadband;
        attribute totalTension : TensionForce;
        action applyTension;
    }

    part def ExhalationValve {
        port inlet : AirPort;
        port outlet : AirPort;
        attribute isExhaling : Boolean;
        action ensureAirPassesThroughFilter;
        action releaseExhaledAir;
        state machine valveStates {
            state Closed;
            state Open;
            transition Closed -> Open when isExhaling == true;
            transition Open -> Closed when isExhaling == false;
        }
    }

    part def N95Respirator {
        part filtrationMedia : FiltrationMedia;
        part facialSeal : FacialSeal;
        part strapSystem : RetentionStrapSystem;
        part exhalationValve : ExhalationValve;
        port ambientAirIn : AirPort;
        port breathedAir : AirPort;
        port exhaledAirOut : AirPort;
        attribute inhalationResistance : BreathingResistance;
        attribute exhalationResistance : BreathingResistance;

        connection ambientToFilter : AirFlow connect ambientAirIn to filtrationMedia.airIn;
        connection filterToBreath : AirFlow connect filtrationMedia.airOut to breathedAir;
        connection breathToValve : AirFlow connect breathedAir to exhalationValve.inlet;
        connection valveToExhaust : AirFlow connect exhalationValve.outlet to exhaledAirOut;
    }

    requirement def <'1'> FiltrationRequirement {
        doc /* The respirator shall filter at least 95 percent of particles 0.3 micrometers or larger. */
        attribute minEfficiency : FiltrationEfficiency = 95;
        attribute targetParticleSize : ParticleSize = 0.0000003;
        attribute actualEfficiency : FiltrationEfficiency;
        require constraint {
            actualEfficiency >= minEfficiency
        }
    }

    requirement def <'2'> BreathingResistanceRequirement {
        doc /* The respirator shall maintain low resistance to both inhalation and exhalation. */
        attribute maxInhalationResistance : BreathingResistance = 50;
        attribute maxExhalationResistance : BreathingResistance = 50;
        attribute actualInhalationResistance : BreathingResistance;
        attribute actualExhalationResistance : BreathingResistance;
        require constraint {
            actualInhalationResistance <= maxInhalationResistance and
            actualExhalationResistance <= maxExhalationResistance
        }
    }

    requirement def <'3'> FacialSealRequirement {
        doc /* The respirator shall form a tight seal against the wearer face. */
        attribute requiredTension : TensionForce = 10;
        attribute actualTension : TensionForce;
        require constraint {
            actualTension >= requiredTension
        }
    }

    part n95Respirator : N95Respirator {
        part filtrationMedia : FiltrationMedia {
            part outerLayer : MechanicalFilterLayer {
                attribute :>> structuralSupport = true;
                attribute :>> poreSize = 0.00001;
            }
            part electrostaticLayer : ElectrostaticFilterLayer {
                attribute :>> captureEfficiency = 95;
                attribute :>> minParticleSize = 0.0000003;
                attribute :>> chargeDensity = 0.5;
            }
            part innerLayer : MechanicalFilterLayer {
                attribute :>> structuralSupport = true;
                attribute :>> poreSize = 0.000005;
            }
        }
        part facialSeal : FacialSeal {
            part noseClip : NoseClip {
                attribute :>> material = "Metal";
            }
        }
        part strapSystem : RetentionStrapSystem {
            part upperStrap : ElasticHeadband {
                attribute :>> tension = 6;
            }
            part lowerStrap : ElasticHeadband {
                attribute :>> tension = 6;
            }
            attribute :>> totalTension = 12;
        }
        part exhalationValve : ExhalationValve {
            attribute :>> isExhaling = false;
        }

        attribute :>> inhalationResistance = 40;
        attribute :>> exhalationResistance = 30;
    }

    requirement <'1.1'> filReq : FiltrationRequirement {
        subject respirator : N95Respirator;
        attribute :>> actualEfficiency = respirator.filtrationMedia.electrostaticLayer.captureEfficiency;
    }

    requirement <'2.1'> brReq : BreathingResistanceRequirement {
        subject respirator : N95Respirator;
        attribute :>> actualInhalationResistance = respirator.inhalationResistance;
        attribute :>> actualExhalationResistance = respirator.exhalationResistance;
    }

    requirement <'3.1'> fsReq : FacialSealRequirement {
        subject respirator : N95Respirator;
        attribute :>> actualTension = respirator.strapSystem.totalTension;
    }
}
