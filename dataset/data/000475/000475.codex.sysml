package N95RespiratorSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Percent :> Real {
        doc /* Percentage value from 0 to 100. */
    }

    attribute def PressureDrop :> Real {
        doc /* Differential pressure across respirator media. */
        unit = "Pa";
    }

    attribute def FlowRate :> Real {
        doc /* Volumetric breathing airflow rate. */
        unit = "L/min";
    }

    attribute def ParticleDiameter :> Real {
        doc /* Aerodynamic particle diameter. */
        unit = "um";
    }

    attribute def FitFactor :> Real {
        doc /* Ratio of ambient challenge aerosol concentration to in-mask concentration. */
    }

    item def AmbientAir {
        attribute oxygenFraction : Percent;
        attribute carbonDioxideFraction : Percent;
        attribute relativeHumidity : Percent;
        attribute particleConcentration : Real;
        attribute representativeParticleDiameter : ParticleDiameter;
    }

    item def InhaledAir {
        attribute oxygenFraction : Percent;
        attribute carbonDioxideFraction : Percent;
        attribute residualParticleConcentration : Real;
        attribute filtrationEfficiency : Percent;
    }

    item def ExhaledAir {
        attribute carbonDioxideFraction : Percent;
        attribute waterVaporContent : Percent;
        attribute outwardParticleConcentration : Real;
    }

    item def AerosolParticle {
        attribute aerodynamicDiameter : ParticleDiameter;
        attribute captured : Boolean;
    }

    port def AirIntakePort {
        in item ambientAir : AmbientAir;
    }

    port def FilteredAirPort {
        out item inhaledAir : InhaledAir;
    }

    port def ExhalationPort {
        in item exhaledAir : ExhaledAir;
    }

    port def LeakagePort {
        in item unfilteredAmbientAir : AmbientAir;
        out item leakedExhaledAir : ExhaledAir;
    }

    part def N95Respirator {
        attribute nominalFiltrationEfficiency : Percent = 95.0;
        attribute mostPenetratingParticleSize : ParticleDiameter = 0.3;
        attribute maximumAllowedInhalationResistance : PressureDrop = 343.0;
        attribute maximumAllowedExhalationResistance : PressureDrop = 245.0;
        attribute requiredFitFactor : FitFactor = 100.0;
        attribute reusable : Boolean = false;

        port intake : AirIntakePort;
        port breathingInterface : FilteredAirPort;
        port exhalationInterface : ExhalationPort;
        port faceSealLeakage : LeakagePort;

        part filteringFacepiece : FilteringFacepiece;
        part noseClip : NoseClip;
        part headStraps : HeadStrapAssembly;
        part faceSeal : FaceSeal;
        part innerComfortLayer : ComfortLayer;
        part userInterface : RespiratorUserInterface;

        connect intake.ambientAir to filteringFacepiece.upstreamAir.ambientAir;
        connect filteringFacepiece.downstreamAir.inhaledAir to breathingInterface.inhaledAir;
        connect exhalationInterface.exhaledAir to filteringFacepiece.exhaledAirInput.exhaledAir;
        connect faceSealLeakage.unfilteredAmbientAir to faceSeal.leakageIngress.unfilteredAmbientAir;
        connect faceSeal.leakageEgress.leakedExhaledAir to faceSealLeakage.leakedExhaledAir;

        perform action filterIncomingAir;
        perform action supportUserBreathing;
        perform action maintainSealToFace;

        state machine lifecycle {
            state Unused;
            state Donned;
            state Filtering;
            state Saturated;
            state Removed;
            state Disposed;

            initial then Unused;

            transition firstUse
                first Unused
                then Donned;

            transition inhaleCycle
                first Donned
                then Filtering;

            transition continueUse
                first Filtering
                then Filtering;

            transition loadingLimitReached
                first Filtering
                then Saturated;

            transition doff
                first Donned
                then Removed;

            transition doffAfterUse
                first Filtering
                then Removed;

            transition discardUnused
                first Unused
                then Disposed;

            transition discardUsed
                first Removed
                then Disposed;

            transition discardSaturated
                first Saturated
                then Disposed;
        }
    }

    part def FilteringFacepiece {
        attribute mediaLayerCount : Integer = 4;
        attribute electrostaticChargePresent : Boolean = true;
        attribute inhalationPressureDropAt85Lpm : PressureDrop;
        attribute exhalationPressureDropAt85Lpm : PressureDrop;
        attribute particleCaptureEfficiencyAt03um : Percent;

        port upstreamAir : AirIntakePort;
        port downstreamAir : FilteredAirPort;
        port exhaledAirInput : ExhalationPort;

        part outerProtectiveLayer : NonwovenLayer {
            attribute hydrophobic : Boolean = true;
        }

        part electrostaticMeltblownLayer : ElectretFilterLayer {
            attribute captureMechanisms = "inertial impaction, interception, diffusion, electrostatic attraction";
        }

        part structuralLayer : NonwovenLayer {
            attribute shapeRetaining : Boolean = true;
        }

        part innerLayer : NonwovenLayer {
            attribute skinContactCompatible : Boolean = true;
        }

        perform action captureAerosolParticles;
        perform action passBreathableAir;
        perform action ventExhaledAirThroughMedia;
    }

    part def ElectretFilterLayer {
        attribute captureMechanisms : String;
        attribute minimumEfficiencyAtMPPS : Percent = 95.0;
        attribute chargeRetentionRequired : Boolean = true;
    }

    part def NonwovenLayer {
        attribute hydrophobic : Boolean = false;
        attribute shapeRetaining : Boolean = false;
        attribute skinContactCompatible : Boolean = false;
    }

    part def NoseClip {
        attribute material : String = "malleable aluminum or equivalent";
        attribute adjustable : Boolean = true;
        attribute conformsToNasalBridge : Boolean = true;

        perform action reduceNasalLeakage;
    }

    part def HeadStrapAssembly {
        attribute strapCount : Integer = 2;
        attribute maintainsTension : Boolean = true;
        attribute latexFree : Boolean = true;

        part upperStrap : ElasticStrap {
            attribute placement = "crown of head";
        }

        part lowerStrap : ElasticStrap {
            attribute placement = "below ears around neck";
        }

        perform action applyRetentionForce;
    }

    part def ElasticStrap {
        attribute placement : String;
        attribute elasticRecovery : Percent;
        attribute nominalTension : Real;
    }

    part def FaceSeal {
        attribute continuousContactRequired : Boolean = true;
        attribute sealIntegrity : Percent;
        attribute expectedFitFactor : FitFactor;

        port leakageIngress : LeakagePort;
        port leakageEgress : LeakagePort;

        perform action conformToFace;
        perform action limitBypassLeakage;
    }

    part def ComfortLayer {
        attribute softTouch : Boolean = true;
        attribute abrasionReducing : Boolean = true;
        attribute moistureAbsorbing : Boolean = false;
    }

    part def RespiratorUserInterface {
        attribute coversNose : Boolean = true;
        attribute coversMouth : Boolean = true;
        attribute permitsSpeech : Boolean = true;
        attribute permitsNormalBreathing : Boolean = true;
    }

    action def filterIncomingAir {
        in item ambientAir : AmbientAir;
        out item inhaledAir : InhaledAir;

        attribute requiredEfficiency : Percent = 95.0;
        attribute targetParticleDiameter : ParticleDiameter = 0.3;

        first start;
        then separateParticles;
        then deliverFilteredAir;
        then done;

        action separateParticles {
            in item airWithAerosols : AmbientAir;
            out item retainedParticles : AerosolParticle;
        }

        action deliverFilteredAir {
            out item cleanBreathableAir : InhaledAir;
        }
    }

    action def supportUserBreathing {
        in attribute inhalationFlow : FlowRate;
        in attribute exhalationFlow : FlowRate;
        out attribute breathingSupported : Boolean;

        attribute nominalTestFlow : FlowRate = 85.0;
        attribute inhalationResistanceLimit : PressureDrop = 343.0;
        attribute exhalationResistanceLimit : PressureDrop = 245.0;
    }

    action def maintainSealToFace {
        in attribute strapTensionAdequate : Boolean;
        in attribute noseClipAdjusted : Boolean;
        out attribute bypassLeakageControlled : Boolean;

        attribute minimumFitFactor : FitFactor = 100.0;
    }

    action def captureAerosolParticles {
        in item particles : AerosolParticle;
        out item capturedParticles : AerosolParticle;

        attribute minimumCaptureEfficiencyAtMPPS : Percent = 95.0;
    }

    action def passBreathableAir {
        in item upstreamAir : AmbientAir;
        out item downstreamAir : InhaledAir;

        attribute oxygenTransferMaintained : Boolean = true;
    }

    action def ventExhaledAirThroughMedia {
        in item exhaledAir : ExhaledAir;
        out item dischargedAir : ExhaledAir;

        attribute outwardFiltrationProvided : Boolean = true;
    }

    action def reduceNasalLeakage {
        in attribute clipConformed : Boolean;
        out attribute nasalLeakageReduced : Boolean;
    }

    action def applyRetentionForce {
        in attribute strapsPositionedCorrectly : Boolean;
        out attribute respiratorHeldAgainstFace : Boolean;
    }

    action def conformToFace {
        in attribute faceContactAchieved : Boolean;
        out attribute continuousSealFormed : Boolean;
    }

    action def limitBypassLeakage {
        in item ambientAirAtSeal : AmbientAir;
        out attribute leakageBelowFitLimit : Boolean;
    }

    requirement def PrimaryFunctionRequirement {
        subject respirator : N95Respirator;

        doc /* The N95 respirator shall reduce the wearer's inhalation exposure to airborne particulate matter by filtering inhaled ambient air while maintaining a seal over the nose and mouth. */

        require constraint {
            respirator.nominalFiltrationEfficiency >= 95.0
        }
    }

    requirement def ParticleFiltrationRequirement {
        subject respirator : N95Respirator;

        doc /* The respirator filter media shall remove at least 95 percent of airborne particles at the most penetrating particle size under specified test conditions. */

        require constraint {
            respirator.filteringFacepiece.particleCaptureEfficiencyAt03um >= 95.0
        }
    }

    requirement def BreathingResistanceRequirement {
        subject respirator : N95Respirator;

        doc /* The respirator shall allow breathing without exceeding inhalation and exhalation resistance limits at the nominal test flow. */

        require constraint {
            respirator.filteringFacepiece.inhalationPressureDropAt85Lpm <= respirator.maximumAllowedInhalationResistance
        }

        require constraint {
            respirator.filteringFacepiece.exhalationPressureDropAt85Lpm <= respirator.maximumAllowedExhalationResistance
        }
    }

    requirement def FitRequirement {
        subject respirator : N95Respirator;

        doc /* The respirator shall maintain a face seal that limits unfiltered bypass leakage during intended use. */

        require constraint {
            respirator.faceSeal.expectedFitFactor >= respirator.requiredFitFactor
        }
    }

    requirement def CoverageRequirement {
        subject respirator : N95Respirator;

        doc /* The respirator shall cover the user's nose and mouth during operation. */

        require constraint {
            respirator.userInterface.coversNose == true
        }

        require constraint {
            respirator.userInterface.coversMouth == true
        }
    }

    part n95RespiratorSystem : N95Respirator {
        attribute nominalFiltrationEfficiency = 95.0;
        attribute mostPenetratingParticleSize = 0.3;
        attribute maximumAllowedInhalationResistance = 343.0;
        attribute maximumAllowedExhalationResistance = 245.0;
        attribute requiredFitFactor = 100.0;

        part filteringFacepiece {
            attribute inhalationPressureDropAt85Lpm = 250.0;
            attribute exhalationPressureDropAt85Lpm = 180.0;
            attribute particleCaptureEfficiencyAt03um = 95.5;
        }

        part faceSeal {
            attribute sealIntegrity = 98.0;
            attribute expectedFitFactor = 120.0;
        }

        part headStraps {
            part upperStrap {
                attribute elasticRecovery = 92.0;
                attribute nominalTension = 3.5;
            }

            part lowerStrap {
                attribute elasticRecovery = 92.0;
                attribute nominalTension = 3.5;
            }
        }
    }

    satisfy PrimaryFunctionRequirement by n95RespiratorSystem;
    satisfy ParticleFiltrationRequirement by n95RespiratorSystem.filteringFacepiece;
    satisfy BreathingResistanceRequirement by n95RespiratorSystem.filteringFacepiece;
    satisfy FitRequirement by n95RespiratorSystem.faceSeal;
    satisfy CoverageRequirement by n95RespiratorSystem.userInterface;
}